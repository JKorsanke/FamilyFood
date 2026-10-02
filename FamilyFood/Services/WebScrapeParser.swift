import Foundation

struct WebScrapeParser {
    private let anthropicService: any AnthropicParsing

    init(anthropicService: any AnthropicParsing) {
        self.anthropicService = anthropicService
    }

    struct ParseResult {
        let draft: RecipeDraft
        let isConfident: Bool   // true = JSON-LD (skip review), false = LLM (show review)
    }

    func parse(url: URL) async throws -> ParseResult {
        let html = try await fetchHTML(from: url)

        // 1. Try JSON-LD structured data first — no LLM needed, high confidence
        if let draft = parseJSONLD(from: html, sourceURL: url.absoluteString) {
            return ParseResult(draft: draft, isConfident: true)
        }

        // 2. Fall back to stripping HTML and sending to Anthropic
        let text = stripHTML(html)
        guard text.count >= 100 else { throw ScrapeError.noRecipeFound }
        let draft = try await anthropicService.parseRecipe(from: text, sourceURL: url.absoluteString, source: .webScrape)
        return ParseResult(draft: draft, isConfident: false)
    }

    // MARK: — HTML fetch

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("FamilyFood/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ScrapeError.fetchFailed
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    // MARK: — JSON-LD parsing (Schema.org Recipe)

    // Internal (not private) so the JSON-LD shapes have direct test coverage.
    func parseJSONLD(from html: String, sourceURL: String) -> RecipeDraft? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#,
            options: [.caseInsensitive]
        ) else { return nil }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let content = nsHTML.substring(with: match.range(at: 1))
            guard let data = content.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: data)
            else { continue }

            // A page can embed a single object or an array of objects
            let candidates: [[String: Any]] = (raw as? [[String: Any]]) ?? ((raw as? [String: Any]).map { [$0] } ?? [])

            for obj in candidates {
                if isRecipeObject(obj), let draft = mapSchemaOrgRecipe(obj, sourceURL: sourceURL) {
                    return draft
                }
                // Handle @graph wrapper
                if let graph = obj["@graph"] as? [[String: Any]] {
                    for node in graph {
                        if isRecipeObject(node), let draft = mapSchemaOrgRecipe(node, sourceURL: sourceURL) {
                            return draft
                        }
                    }
                }
            }
        }
        return nil
    }

    private func isRecipeObject(_ obj: [String: Any]) -> Bool {
        let type_ = obj["@type"]
        if let s = type_ as? String { return s == "Recipe" }
        if let a = type_ as? [String] { return a.contains("Recipe") }
        return false
    }

    private func mapSchemaOrgRecipe(_ json: [String: Any], sourceURL: String) -> RecipeDraft? {
        guard let name = json["name"] as? String, !name.isEmpty else { return nil }

        var draft = RecipeDraft()
        draft.source = .webScrape
        draft.sourceURL = sourceURL
        draft.title = name
        draft.summary = json["description"] as? String

        // Servings
        let yieldRaw = json["recipeYield"]
        if let yStr = yieldRaw as? String {
            let parts = yStr.split(separator: " ", maxSplits: 1).map(String.init)
            draft.servings = parts.first
            draft.servingsUnit = parts.count > 1 ? parts[1] : nil
        } else if let yArr = yieldRaw as? [String], let first = yArr.first {
            draft.servings = first
        }

        // Times
        draft.prepTime = parseDuration(json["prepTime"] as? String)
        draft.cookTime = parseDuration(json["cookTime"] as? String)
        draft.totalTime = parseDuration(json["totalTime"] as? String)

        // Diet style
        let dietRaw = json["suitableForDiet"]
        let dietStrings: [String]
        if let s = dietRaw as? String { dietStrings = [s] }
        else if let a = dietRaw as? [String] { dietStrings = a }
        else { dietStrings = [] }

        if dietStrings.contains(where: { $0.contains("VeganDiet") }) {
            draft.dietStyle = .vegan
        } else if dietStrings.contains(where: { $0.contains("VegetarianDiet") }) {
            draft.dietStyle = .vegetarian
        }

        // Image
        if let imgStr = json["image"] as? String {
            draft.imageURL = imgStr
        } else if let imgObj = json["image"] as? [String: Any] {
            draft.imageURL = imgObj["url"] as? String
        } else if let imgArr = json["image"] as? [[String: Any]], let first = imgArr.first {
            draft.imageURL = first["url"] as? String
        } else if let imgArr = json["image"] as? [String], let first = imgArr.first {
            draft.imageURL = first
        }

        // Ingredients — Schema.org gives flat strings; put into a single unnamed group
        if let ings = json["recipeIngredient"] as? [String], !ings.isEmpty {
            let draftIngs = ings.map { RecipeIngredientDraft(amount: "", unit: "", name: $0, notes: "") }
            draft.ingredientGroups = [IngredientGroupDraft(name: "", ingredients: draftIngs)]
        }

        // JSON-LD values carry raw HTML on real sites
        return draft.cleaningTexts()
    }

    // MARK: — HTML stripping (LLM fallback)

    private func stripHTML(_ html: String) -> String {
        var text = html

        // Remove script/style blocks, comments, and declarations entirely —
        // cleanedRecipeText strips tags but would keep their inner text.
        for pattern in [#"<script[\s\S]*?</script>"#, #"<style[\s\S]*?</style>"#,
                        #"<!--[\s\S]*?-->"#, #"<![^>]*>"#] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
            }
        }

        // Tag stripping, entity decoding, and whitespace normalization are
        // shared with every other recipe-text path.
        return String(text.cleanedRecipeText.prefix(6000))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: — Errors

    enum ScrapeError: LocalizedError {
        case fetchFailed, noRecipeFound

        var errorDescription: String? {
            switch self {
            case .fetchFailed:    return "Die Seite konnte nicht geladen werden."
            case .noRecipeFound:  return "Auf dieser Seite wurde kein Rezept gefunden."
            }
        }
    }
}
