import XCTest
@testable import FamilyFood

/// Test double for everything that consumes `AnthropicParsing` — replaces
/// the old `apiKey == "test"` magic-key hook that lived in the production path.
struct MockAnthropicParser: AnthropicParsing {
    var mealPlan: KitaMealPlan = .mock
    var recipeDraft = RecipeDraft()

    func parseMealPlan(from ocrText: String) async throws -> KitaMealPlan { mealPlan }
    func parseRecipe(from text: String, sourceURL: String?, source: RecipeSource) async throws -> RecipeDraft { recipeDraft }
}

final class AnthropicServiceTests: XCTestCase {

    // MARK: — API response handling (content extraction, truncation, fences)

    private func apiResponse(text: String, stopReason: String = "end_turn") -> Data {
        let payload: [String: Any] = [
            "id": "msg_test",
            "content": [["type": "text", "text": text]],
            "stop_reason": stopReason
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    func test_completionText_returns_content_text() throws {
        let data = apiResponse(text: "{\"weekOf\": null}")
        XCTAssertEqual(try AnthropicService.completionText(fromResponseData: data), "{\"weekOf\": null}")
    }

    func test_completionText_strips_markdown_fences() throws {
        let data = apiResponse(text: "```json\n{\"weekOf\": null}\n```")
        XCTAssertEqual(try AnthropicService.completionText(fromResponseData: data), "{\"weekOf\": null}")
    }

    func test_completionText_throws_truncated_on_max_tokens_stop() {
        let data = apiResponse(text: "{\"title\": \"Lasag", stopReason: "max_tokens")
        XCTAssertThrowsError(try AnthropicService.completionText(fromResponseData: data)) { error in
            guard case AnthropicService.AnthropicError.truncated = error else {
                return XCTFail("expected .truncated, got \(error)")
            }
            // Acceptance: truncation is a user-readable German error, not a cryptic parse failure.
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    func test_completionText_throws_invalidResponse_without_content_text() {
        let data = try! JSONSerialization.data(withJSONObject: ["type": "error", "error": ["message": "overloaded"]])
        XCTAssertThrowsError(try AnthropicService.completionText(fromResponseData: data)) { error in
            guard case AnthropicService.AnthropicError.invalidResponse = error else {
                return XCTFail("expected .invalidResponse, got \(error)")
            }
        }
    }

    // MARK: — Meal-plan mapping (model text → KitaMealPlan)

    func test_mealPlan_maps_days_and_mainIngredient() throws {
        let text = """
        {"weekOf": "05.05.",
         "monday":    {"date": "05.05.", "meal": "Spaghetti Bolognese", "main_ingredient": "Pasta"},
         "tuesday":   {"date": "06.05.", "meal": null, "main_ingredient": null},
         "wednesday": null,
         "thursday":  {"date": null, "meal": "Fischstäbchen", "main_ingredient": "Fisch"},
         "friday":    {"date": "09.05.", "meal": "Gemüsesuppe", "main_ingredient": "Gemüse"}}
        """
        let plan = try AnthropicService.mealPlan(fromModelText: text)
        XCTAssertEqual(plan.weekOf, "05.05.")
        XCTAssertEqual(plan.monday.meal, "Spaghetti Bolognese")
        XCTAssertEqual(plan.monday.mainIngredient, "Pasta")
        XCTAssertNil(plan.tuesday.meal)
        XCTAssertNil(plan.wednesday.date)
        XCTAssertNil(plan.wednesday.meal)
        XCTAssertEqual(plan.thursday.meal, "Fischstäbchen")
        XCTAssertNil(plan.thursday.date)
        XCTAssertEqual(plan.friday.mainIngredient, "Gemüse")
    }

    func test_mealPlan_throws_parseError_on_non_json() {
        XCTAssertThrowsError(try AnthropicService.mealPlan(fromModelText: "Es tut mir leid, ich kann das nicht lesen.")) { error in
            guard case AnthropicService.AnthropicError.parseError = error else {
                return XCTFail("expected .parseError, got \(error)")
            }
        }
    }

    // MARK: — Recipe mapping (model text → RecipeDraft)

    func test_recipeDraft_maps_fields_and_groups() throws {
        let text = """
        {"title": "Linsencurry", "summary": "Cremig und schnell.",
         "servings": "4", "servings_unit": "Portionen",
         "prep_time": 10, "cook_time": 20, "total_time": 30,
         "diet_style": "vegan", "is_family_friendly": true,
         "main_ingredient": "Hülsenfrüchte",
         "allergen_tags": ["Soja"],
         "ingredient_groups": [
           {"name": "", "ingredients": [
             {"amount": "200", "unit": "g", "name": "Rote Linsen", "notes": ""},
             {"amount": "1", "unit": "Dose", "name": "Kokosmilch", "notes": "ungesüßt"}
           ]}
         ]}
        """
        let draft = try AnthropicService.recipeDraft(fromModelText: text,
                                                     sourceURL: "https://example.org/r",
                                                     source: .webScrape)
        XCTAssertEqual(draft.title, "Linsencurry")
        XCTAssertEqual(draft.summary, "Cremig und schnell.")
        XCTAssertEqual(draft.servings, "4")
        XCTAssertEqual(draft.servingsUnit, "Portionen")
        XCTAssertEqual(draft.prepTime, 10)
        XCTAssertEqual(draft.cookTime, 20)
        XCTAssertEqual(draft.totalTime, 30)
        XCTAssertEqual(draft.dietStyle, .vegan)
        XCTAssertTrue(draft.isFamilyFriendly)
        XCTAssertEqual(draft.mainIngredient, "Hülsenfrüchte")
        XCTAssertEqual(draft.allergenTags, ["Soja"])
        XCTAssertEqual(draft.sourceURL, "https://example.org/r")
        XCTAssertEqual(draft.source, .webScrape)
        XCTAssertEqual(draft.ingredientGroups.count, 1)
        XCTAssertEqual(draft.ingredientGroups[0].ingredients.map(\.name), ["Rote Linsen", "Kokosmilch"])
        XCTAssertEqual(draft.ingredientGroups[0].ingredients[1].notes, "ungesüßt")
    }

    func test_recipeDraft_defaults_unknown_diet_and_missing_optionals() throws {
        let draft = try AnthropicService.recipeDraft(fromModelText: "{\"title\": \"Brot\"}",
                                                     sourceURL: nil,
                                                     source: .ocr)
        XCTAssertEqual(draft.title, "Brot")
        XCTAssertEqual(draft.dietStyle, .unknown)
        XCTAssertFalse(draft.isFamilyFriendly)
        XCTAssertTrue(draft.ingredientGroups.isEmpty)
        XCTAssertTrue(draft.allergenTags.isEmpty)
        XCTAssertNil(draft.sourceURL)
        XCTAssertEqual(draft.source, .ocr)
    }

    func test_recipeDraft_throws_parseError_on_non_json() {
        XCTAssertThrowsError(try AnthropicService.recipeDraft(fromModelText: "kein JSON", sourceURL: nil, source: .manual)) { error in
            guard case AnthropicService.AnthropicError.parseError = error else {
                return XCTFail("expected .parseError, got \(error)")
            }
        }
    }

    // MARK: — Missing-key guard (single chokepoint for every LLM path)

    func test_parseMealPlan_throws_missingKey_for_empty_key() async {
        do {
            _ = try await AnthropicService(apiKey: "").parseMealPlan(from: "Speiseplan KW 27")
            XCTFail("expected .missingKey")
        } catch {
            guard case AnthropicService.AnthropicError.missingKey = error else {
                return XCTFail("expected .missingKey, got \(error)")
            }
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    func test_parseRecipe_throws_missingKey_for_empty_key() async {
        do {
            _ = try await AnthropicService(apiKey: "").parseRecipe(from: "Zutaten: 200 g Mehl", sourceURL: nil, source: .manual)
            XCTFail("expected .missingKey")
        } catch {
            guard case AnthropicService.AnthropicError.missingKey = error else {
                return XCTFail("expected .missingKey, got \(error)")
            }
        }
    }

    /// The key is entered in Settings only, so the message has to send the user there.
    func test_missingKey_message_points_to_settings() {
        let message = AnthropicService.AnthropicError.missingKey.errorDescription ?? ""
        XCTAssertTrue(message.contains("Einstellungen"), "got: \(message)")
    }
}
