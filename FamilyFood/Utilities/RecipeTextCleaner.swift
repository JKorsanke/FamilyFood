import Foundation

// Recipe text fetched from websites (seed data exported from a site,
// JSON-LD scrape, LLM fallback) carries raw HTML fragments — tags and
// entities — that the app rendered verbatim.

extension String {
    /// Removes HTML tags, decodes entities, and normalizes whitespace and
    /// invisible characters. Safe to run on already-clean text.
    var cleanedRecipeText: String {
        var text = self

        // Block breaks become newlines before tags are stripped, so
        // paragraphs don't fuse into one line.
        text = text.replacingOccurrences(of: #"</p\s*>"#, with: "\n\n",
                                         options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<br\s*/?\s*>"#, with: "\n",
                                         options: [.regularExpression, .caseInsensitive])

        // A letter must follow "<" (or "</") so plain "<3" or "< 20" survive.
        text = text.replacingOccurrences(of: #"</?[a-zA-Z][^<>]*>"#, with: "",
                                         options: .regularExpression)

        text = text.decodingHTMLEntities()

        // Invisible characters that read as "wrong symbols" on screen:
        // soft hyphen, zero-widths, BOM, replacement character.
        for invisible in ["\u{00AD}", "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}", "\u{FFFD}"] {
            text = text.replacingOccurrences(of: invisible, with: "")
        }
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")

        text = text.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" ?\n ?"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }
        var text = self

        // Named entities seen on German recipe sites.
        let named: [String: String] = [
            "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&nbsp;": " ",
            "&auml;": "ä", "&ouml;": "ö", "&uuml;": "ü",
            "&Auml;": "Ä", "&Ouml;": "Ö", "&Uuml;": "Ü", "&szlig;": "ß",
            "&eacute;": "é", "&egrave;": "è", "&agrave;": "à", "&ccedil;": "ç",
            "&ndash;": "\u{2013}", "&mdash;": "\u{2014}", "&hellip;": "\u{2026}",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}", "&bdquo;": "\u{201E}",
            "&deg;": "°", "&middot;": "·", "&bull;": "•", "&shy;": "",
            "&frac12;": "½", "&frac14;": "¼", "&frac34;": "¾", "&times;": "×", "&euro;": "€"
        ]
        for (entity, character) in named {
            text = text.replacingOccurrences(of: entity, with: character)
        }

        // Numeric entities, decimal (&#8211;) and hex (&#x27;). Invalid code
        // points are dropped rather than kept as visible garbage.
        while let range = text.range(of: #"&#([0-9]{1,7}|[xX][0-9a-fA-F]{1,6});"#,
                                     options: .regularExpression) {
            let entity = text[range]
            let isHex = entity.hasPrefix("&#x") || entity.hasPrefix("&#X")
            let digits = entity.dropFirst(isHex ? 3 : 2).dropLast()
            let scalar = UInt32(digits, radix: isHex ? 16 : 10).flatMap(Unicode.Scalar.init)
            text.replaceSubrange(range, with: scalar.map { String(Character($0)) } ?? "")
        }

        // "&amp;" last, so double-encoded entities resolve one level per
        // pass instead of jumping straight to the final character.
        return text.replacingOccurrences(of: "&amp;", with: "&")
    }
}

extension RecipeDraft {
    /// Returns a copy with every user-visible text field cleaned. Applied to
    /// drafts coming from web scrape and LLM parsing before review/save.
    func cleaningTexts() -> RecipeDraft {
        var draft = self
        draft.title = title.cleanedRecipeText
        draft.summary = summary.map { $0.cleanedRecipeText }
        draft.ingredientGroups = ingredientGroups.map { group in
            IngredientGroupDraft(
                name: group.name.cleanedRecipeText,
                ingredients: group.ingredients.map {
                    RecipeIngredientDraft(amount: $0.amount.cleanedRecipeText,
                                          unit: $0.unit.cleanedRecipeText,
                                          name: $0.name.cleanedRecipeText,
                                          notes: $0.notes.cleanedRecipeText)
                }
            )
        }
        return draft
    }
}
