import Foundation

/// The LLM-parsing seam every import path depends on. Views/ViewModels and
/// the parser services consume this protocol; tests and previews inject a mock instead
/// of hitting the network.
protocol AnthropicParsing {
    func parseMealPlan(from ocrText: String) async throws -> KitaMealPlan
    func parseRecipe(from text: String, sourceURL: String?, source: RecipeSource) async throws -> RecipeDraft
}

struct AnthropicService: AnthropicParsing {
    /// Single model id for every parsing call.
    static let model = "claude-haiku-4-5-20251001"

    private let apiKey: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: — Meal plan (OCR text → KitaMealPlan)

    func parseMealPlan(from ocrText: String) async throws -> KitaMealPlan {
        let text = try await complete(prompt: Self.mealPlanPrompt(ocrText: ocrText), maxTokens: 512)
        return try Self.mealPlan(fromModelText: text)
    }

    // MARK: — Recipe (OCR text or scraped webpage text → RecipeDraft)

    func parseRecipe(from text: String, sourceURL: String? = nil, source: RecipeSource = .manual) async throws -> RecipeDraft {
        let modelText = try await complete(prompt: Self.recipePrompt(text: text), maxTokens: 1500)
        return try Self.recipeDraft(fromModelText: modelText, sourceURL: sourceURL, source: source)
    }

    // MARK: — The one request/response path

    private struct MessagesRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let maxTokens: Int
        let messages: [Message]
        enum CodingKeys: String, CodingKey {
            case model, messages
            case maxTokens = "max_tokens"
        }
    }

    private struct MessagesResponse: Decodable {
        struct Content: Decodable { let text: String? }
        let content: [Content]
        let stopReason: String?
        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    /// Builds the request, performs it, and hands the raw response to `completionText`.
    /// If requests are ever routed through a proxy, only this function changes.
    private func complete(prompt: String, maxTokens: Int) async throws -> String {
        guard !apiKey.isEmpty else { throw AnthropicError.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            MessagesRequest(model: Self.model, maxTokens: maxTokens,
                            messages: [.init(role: "user", content: prompt)])
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.apiError("Keine Antwort vom Server")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "–"
            throw AnthropicError.apiError("HTTP \(http.statusCode): \(body)")
        }
        return try Self.completionText(fromResponseData: data)
    }

    /// Response handling as a pure function: content extraction, truncation check,
    /// ```json fence stripping. Internal so the decode path has direct test coverage.
    static func completionText(fromResponseData data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(MessagesResponse.self, from: data),
              let text = response.content.first?.text else {
            throw AnthropicError.invalidResponse
        }
        guard response.stopReason != "max_tokens" else { throw AnthropicError.truncated }
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: — Pure mapping (model text → domain values)

    static func mealPlan(fromModelText text: String) throws -> KitaMealPlan {
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(MealPlanResponse.self, from: data) else {
            throw AnthropicError.parseError("Antwort: \(text)")
        }
        return KitaMealPlan(
            weekOf:    parsed.weekOf,
            monday:    KitaMealPlan.Day(date: parsed.monday?.date, meal: parsed.monday?.meal, mainIngredient: parsed.monday?.main_ingredient),
            tuesday:   KitaMealPlan.Day(date: parsed.tuesday?.date, meal: parsed.tuesday?.meal, mainIngredient: parsed.tuesday?.main_ingredient),
            wednesday: KitaMealPlan.Day(date: parsed.wednesday?.date, meal: parsed.wednesday?.meal, mainIngredient: parsed.wednesday?.main_ingredient),
            thursday:  KitaMealPlan.Day(date: parsed.thursday?.date, meal: parsed.thursday?.meal, mainIngredient: parsed.thursday?.main_ingredient),
            friday:    KitaMealPlan.Day(date: parsed.friday?.date, meal: parsed.friday?.meal, mainIngredient: parsed.friday?.main_ingredient)
        )
    }

    static func recipeDraft(fromModelText text: String, sourceURL: String?, source: RecipeSource) throws -> RecipeDraft {
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(RecipeResponse.self, from: data) else {
            throw AnthropicError.parseError("Antwort: \(text)")
        }

        var draft = RecipeDraft()
        draft.title = parsed.title
        draft.summary = parsed.summary
        draft.servings = parsed.servings
        draft.servingsUnit = parsed.servings_unit
        draft.prepTime = parsed.prep_time
        draft.cookTime = parsed.cook_time
        draft.totalTime = parsed.total_time
        draft.dietStyle = DietStyle(rawValue: parsed.diet_style ?? "") ?? .unknown
        draft.isFamilyFriendly = parsed.is_family_friendly ?? false
        draft.mainIngredient = parsed.main_ingredient
        draft.allergenTags = parsed.allergen_tags ?? []
        draft.sourceURL = sourceURL
        draft.source = source
        draft.ingredientGroups = (parsed.ingredient_groups ?? []).map { group in
            IngredientGroupDraft(
                name: group.name,
                ingredients: group.ingredients.map { ing in
                    RecipeIngredientDraft(amount: ing.amount, unit: ing.unit, name: ing.name, notes: ing.notes)
                }
            )
        }
        // The model echoes entities/tags from its input text
        return draft.cleaningTexts()
    }

    // MARK: — Prompts

    private static func mealPlanPrompt(ocrText: String) -> String {
        """
        You receive OCR-extracted text from a German kindergarten meal plan (Kita-Speiseplan).
        Extract the lunch meal and date for each weekday.

        OCR text:
        \(ocrText)

        Return only a JSON object with this exact structure (no other text):
        {
          "weekOf": "DD.MM. or null",
          "monday":    {"date": "DD.MM. or null", "meal": "meal name or null", "main_ingredient": "category or null"},
          "tuesday":   {"date": "DD.MM. or null", "meal": "meal name or null", "main_ingredient": "category or null"},
          "wednesday": {"date": "DD.MM. or null", "meal": "meal name or null", "main_ingredient": "category or null"},
          "thursday":  {"date": "DD.MM. or null", "meal": "meal name or null", "main_ingredient": "category or null"},
          "friday":    {"date": "DD.MM. or null", "meal": "meal name or null", "main_ingredient": "category or null"}
        }

        Rules:
        - Use the exact German meal name from the text
        - Use JSON null (no quotes) when a field is missing or unclear
        - For dates, use DD.MM. format only (e.g. "20.04.") — do not add a year
        - main_ingredient: das Hauptzutaten-Kategorie des Gerichts. Wähle EINEN Begriff aus:
          \(MainIngredient.promptVocabulary)
          Gib null zurück wenn unklar.
        - Return only the JSON, nothing else
        """
    }

    private static func recipePrompt(text: String) -> String {
        """
        Du bist ein Assistent, der Rezeptinformationen aus Text extrahiert.
        Extrahiere das Rezept aus dem folgenden Text und gib es als JSON-Objekt zurück.

        Text:
        \(text)

        Gib NUR ein JSON-Objekt mit genau dieser Struktur zurück (keine anderen Texte):
        {
          "title": "Rezeptname",
          "summary": "Kurzbeschreibung oder null",
          "servings": "4",
          "servings_unit": "Portionen",
          "prep_time": 20,
          "cook_time": 30,
          "total_time": 50,
          "diet_style": "vegan|vegetarian|omnivore|unknown",
          "is_family_friendly": false,
          "main_ingredient": "Pasta",
          "allergen_tags": ["Gluten", "Soja"],
          "ingredient_groups": [
            {
              "name": "",
              "ingredients": [
                {"amount": "200", "unit": "g", "name": "Mehl", "notes": ""}
              ]
            }
          ]
        }

        Regeln:
        - diet_style: "vegan" = nur pflanzliche Zutaten, "vegetarian" = kein Fleisch/Fisch, "omnivore" = mit Fleisch oder Fisch, "unknown" = unklar
        - Zeiten sind ganze Zahlen in Minuten, oder null wenn unbekannt
        - servings: nur die Zahl als String, z.B. "4"
        - Bei Zutaten ohne Gruppenname: verwende "" für den Gruppennamen
        - main_ingredient: das Hauptzutaten-Kategorie des Gerichts. Wähle EINEN Begriff aus:
          \(MainIngredient.promptVocabulary)
        - allergen_tags: Liste der enthaltenen Hauptallergene nach EU-Recht aus:
          Gluten, Milch, Ei, Nüsse, Erdnüsse, Fisch, Schalentiere, Soja, Sesam, Sellerie, Senf
          Gib nur die tatsächlich enthaltenen zurück.
        - Gib NUR das JSON zurück, keine Erläuterungen
        """
    }

    // MARK: — Response DTOs

    private struct MealPlanResponse: Decodable {
        let weekOf: String?
        let monday: DayResponse?
        let tuesday: DayResponse?
        let wednesday: DayResponse?
        let thursday: DayResponse?
        let friday: DayResponse?

        struct DayResponse: Decodable {
            let date: String?
            let meal: String?
            let main_ingredient: String?
        }
    }

    private struct RecipeResponse: Decodable {
        let title: String
        let summary: String?
        let servings: String?
        let servings_unit: String?
        let prep_time: Int?
        let cook_time: Int?
        let total_time: Int?
        let diet_style: String?
        let is_family_friendly: Bool?
        let main_ingredient: String?
        let allergen_tags: [String]?
        let ingredient_groups: [GroupResponse]?

        struct GroupResponse: Decodable {
            let name: String
            let ingredients: [IngredientResponse]
        }
        struct IngredientResponse: Decodable {
            let amount: String
            let unit: String
            let name: String
            let notes: String
        }
    }

    enum AnthropicError: LocalizedError {
        case apiError(String), invalidResponse, parseError(String), truncated, missingKey
        var errorDescription: String? {
            switch self {
            case .apiError(let detail):   return "API-Fehler: \(detail)"
            case .invalidResponse:        return "Ungültige Antwort vom Server."
            case .parseError(let detail): return "Die Antwort konnte nicht gelesen werden. \(detail)"
            case .truncated:              return "Das Dokument ist zu umfangreich — die Antwort wurde abgeschnitten. Bitte versuche es mit einem kürzeren Ausschnitt."
            case .missingKey:             return "Bitte hinterlege zuerst deinen Anthropic API-Schlüssel in den Einstellungen."
            }
        }
    }
}
