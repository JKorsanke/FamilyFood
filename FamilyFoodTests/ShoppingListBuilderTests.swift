import XCTest
import SwiftData
@testable import FamilyFood

@MainActor
final class ShoppingListBuilderTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: RecipeModel.self, configurations: config)
    }

    /// Build a recipe with a single ingredient group from `(amount, unit, name)` tuples.
    private func recipe(_ title: String, _ ingredients: [(String, String, String)]) -> RecipeModel {
        let r = RecipeModel(title: title)
        container.mainContext.insert(r)
        let group = IngredientGroupModel(name: "Zutaten", sortOrder: 0)
        container.mainContext.insert(group)
        r.ingredientGroups.append(group)
        for (i, ing) in ingredients.enumerated() {
            let model = RecipeIngredientModel(amount: ing.0, unit: ing.1, name: ing.2, notes: "", sortOrder: i)
            container.mainContext.insert(model)
            group.ingredients.append(model)
        }
        return r
    }

    func test_empty_recipes_returns_empty() {
        XCTAssertTrue(ShoppingListBuilder.aggregate([]).isEmpty)
    }

    func test_single_recipe_lists_each_ingredient_with_amount_and_unit() {
        let r = recipe("Nudeln", [("200", "g", "Mehl"), ("2", "Stk", "Eier")])
        let items = ShoppingListBuilder.aggregate([r])

        XCTAssertEqual(items.count, 2)
        let mehl = items.first { $0.name == "Mehl" }
        XCTAssertEqual(mehl?.quantity, "200 g")
        XCTAssertEqual(mehl?.isChecked, false)
        XCTAssertEqual(items.first { $0.name == "Eier" }?.quantity, "2 Stk")
    }

    func test_same_name_and_unit_merge_and_sum_amounts() {
        let a = recipe("Kuchen", [("200", "g", "Mehl")])
        let b = recipe("Brot", [("100", "g", "Mehl")])
        let items = ShoppingListBuilder.aggregate([a, b])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Mehl")
        XCTAssertEqual(items.first?.quantity, "300 g")
    }

    func test_same_name_different_unit_stays_separate() {
        let a = recipe("A", [("200", "g", "Mehl")])
        let b = recipe("B", [("2", "EL", "Mehl")])
        let items = ShoppingListBuilder.aggregate([a, b])

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(Set(items.map(\.quantity)), ["200 g", "2 EL"])
    }

    func test_merge_is_case_and_whitespace_insensitive_and_keeps_first_casing() {
        let a = recipe("A", [("1", "", "Knoblauch")])
        let b = recipe("B", [("2", "", " knoblauch ")])
        let items = ShoppingListBuilder.aggregate([a, b])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Knoblauch")
        XCTAssertEqual(items.first?.quantity, "3")
    }

    func test_comma_decimals_are_summed() {
        let a = recipe("A", [("0,5", "l", "Milch")])
        let b = recipe("B", [("0,5", "l", "Milch")])
        let items = ShoppingListBuilder.aggregate([a, b])

        XCTAssertEqual(items.first?.quantity, "1 l")
    }

    func test_simple_fractions_are_summed() {
        let a = recipe("A", [("1/2", "TL", "Salz")])
        let b = recipe("B", [("1/2", "TL", "Salz")])
        let items = ShoppingListBuilder.aggregate([a, b])

        XCTAssertEqual(items.first?.quantity, "1 TL")
    }

    func test_blank_amount_and_unit_yields_no_quantity() {
        let r = recipe("A", [("", "", "Salz")])
        let items = ShoppingListBuilder.aggregate([r])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Salz")
        XCTAssertEqual(items.first?.quantity, "")
    }

    func test_unparseable_amounts_are_listed_not_dropped() {
        let a = recipe("A", [("etwas", "", "Pfeffer")])
        let b = recipe("B", [("1 Prise", "", "Pfeffer")])
        let items = ShoppingListBuilder.aggregate([a, b])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.quantity, "etwas + 1 Prise")
    }

    func test_empty_named_ingredients_are_skipped() {
        let r = recipe("A", [("1", "g", "   ")])
        XCTAssertTrue(ShoppingListBuilder.aggregate([r]).isEmpty)
    }

    func test_items_are_sorted_alphabetically_by_name() {
        let r = recipe("A", [("1", "", "Zucker"), ("1", "", "Apfel"), ("1", "", "Mehl")])
        let names = ShoppingListBuilder.aggregate([r]).map(\.name)
        XCTAssertEqual(names, ["Apfel", "Mehl", "Zucker"])
    }
}
