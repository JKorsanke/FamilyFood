import XCTest
@testable import FamilyFood

final class MealKindTests: XCTestCase {
    private func decode(_ json: String) throws -> PlannedMeal {
        try JSONDecoder().decode(PlannedMeal.self, from: Data(json.utf8))
    }

    // MARK: - Legacy flag-shaped JSON (pre-MealKind weekly_plans.json)

    func test_legacy_recipe_meal_decodes_to_recipe_kind() throws {
        let recipeId = UUID()
        let engineId = UUID()
        let meal = try decode("""
        {"id": "\(UUID().uuidString)", "name": "Spaghetti", "recipeId": "\(recipeId.uuidString)",
         "isAbendbrot": false, "isExtern": false, "engineRecipeId": "\(engineId.uuidString)", "isAuto": false}
        """)
        XCTAssertEqual(meal.kind, .recipe(id: recipeId, engineId: engineId))
        XCTAssertEqual(meal.name, "Spaghetti")
        XCTAssertEqual(meal.recipeId, recipeId)
        XCTAssertEqual(meal.engineRecipeId, engineId)
    }

    func test_legacy_auto_abendbrot_keeps_auto_flag() throws {
        let meal = try decode("""
        {"id": "\(UUID().uuidString)", "name": "Abendbrot",
         "isAbendbrot": true, "isExtern": false, "isAuto": true}
        """)
        XCTAssertEqual(meal.kind, .abendbrot(auto: true))
        XCTAssertTrue(meal.isAuto)
        XCTAssertTrue(meal.isAbendbrot)
    }

    /// The old flags could represent illegal combinations; the decoder resolves them in
    /// the same priority order the UI used (extern > abendbrot > recipe).
    func test_legacy_illegal_extern_abendbrot_combo_resolves_to_extern() throws {
        let meal = try decode("""
        {"id": "\(UUID().uuidString)", "name": "Egal",
         "isAbendbrot": true, "isExtern": true, "isAuto": false}
        """)
        XCTAssertEqual(meal.kind, .extern)
        XCTAssertTrue(meal.isExtern)
        XCTAssertFalse(meal.isAbendbrot)
    }

    func test_legacy_plain_named_meal_decodes_to_custom() throws {
        let meal = try decode("""
        {"id": "\(UUID().uuidString)", "name": "Omas Eintopf",
         "isAbendbrot": false, "isExtern": false, "isAuto": false}
        """)
        XCTAssertEqual(meal.kind, .custom)
        XCTAssertNil(meal.recipeId)
    }

    // MARK: - New shape

    func test_kind_round_trips_through_codable() throws {
        let meals = [
            PlannedMeal(name: "Spaghetti", kind: .recipe(id: UUID(), engineId: UUID())),
            PlannedMeal(name: "Abendbrot", kind: .abendbrot(auto: true)),
            PlannedMeal(name: "Extern", kind: .extern),
            PlannedMeal(name: "Omas Eintopf", kind: .custom),
        ]
        let data = try JSONEncoder().encode(meals)
        let decoded = try JSONDecoder().decode([PlannedMeal].self, from: data)
        XCTAssertEqual(decoded.map(\.kind), meals.map(\.kind))
        XCTAssertEqual(decoded.map(\.name), meals.map(\.name))
    }
}
