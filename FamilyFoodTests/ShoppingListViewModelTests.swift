import XCTest
import SwiftData
@testable import FamilyFood

@MainActor
final class ShoppingListViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var planDir: URL!
    private var listDir: URL!
    private var planStore: PlanStore!
    private var listStore: ShoppingListStore!

    override func setUp() async throws {
        container = try ModelContainer(for: RecipeModel.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        planDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        listDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        planStore = PlanStore(directory: planDir)
        listStore = ShoppingListStore(directory: listDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: planDir)
        try? FileManager.default.removeItem(at: listDir)
    }

    private func makeVM() -> ShoppingListViewModel {
        ShoppingListViewModel(planStore: planStore, store: listStore)
    }

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

    private func savePlan(_ recipeIds: [UUID], week: WeekKey = .current) {
        var plan = WeeklyPlan(weekKey: week)
        for (i, id) in recipeIds.enumerated() where i < plan.slots.count {
            plan.slots[i].meal = PlannedMeal(name: "R", kind: .recipe(id: id, engineId: nil))
        }
        planStore.saveWeeklyPlans([plan])
    }

    func test_refresh_lists_current_week_recipes_and_their_ingredients() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        let b = recipe("Kuchen", [("50", "g", "Zucker")])
        savePlan([a.id, b.id])

        let vm = makeVM()
        vm.refresh(recipes: [a, b])

        XCTAssertEqual(vm.displayedRecipes.map(\.id), [a.id, b.id])
        XCTAssertEqual(vm.items.map(\.name), ["Mehl", "Zucker"])
    }

    func test_refresh_ignores_recipes_planned_in_other_weeks() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        savePlan([a.id], week: .current.advanced(by: 1))

        let vm = makeVM()
        vm.refresh(recipes: [a])

        XCTAssertTrue(vm.displayedRecipes.isEmpty)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func test_recipe_planned_twice_is_listed_once() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        savePlan([a.id, a.id])

        let vm = makeVM()
        vm.refresh(recipes: [a])

        XCTAssertEqual(vm.displayedRecipes.count, 1)
    }

    func test_removeRecipe_drops_it_and_its_ingredients() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        let b = recipe("Kuchen", [("50", "g", "Zucker")])
        savePlan([a.id, b.id])
        let vm = makeVM()
        vm.refresh(recipes: [a, b])

        vm.removeRecipe(a.id)

        XCTAssertEqual(vm.displayedRecipes.map(\.id), [b.id])
        XCTAssertEqual(vm.items.map(\.name), ["Zucker"])
    }

    func test_removeRecipe_does_not_modify_the_weekly_plan() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        savePlan([a.id])
        let vm = makeVM()
        vm.refresh(recipes: [a])

        vm.removeRecipe(a.id)

        let planRecipeIds = planStore.loadWeeklyPlans()
            .first { $0.weekKey == .current }?
            .slots.compactMap { $0.meal?.recipeId } ?? []
        XCTAssertEqual(planRecipeIds, [a.id])   // still planned for the week
    }

    func test_clearAll_empties_the_list() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        let b = recipe("Kuchen", [("50", "g", "Zucker")])
        savePlan([a.id, b.id])
        let vm = makeVM()
        vm.refresh(recipes: [a, b])

        vm.clearAll()

        XCTAssertTrue(vm.displayedRecipes.isEmpty)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func test_toggleChecked_marks_item_and_survives_a_refresh() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        savePlan([a.id])
        let vm = makeVM()
        vm.refresh(recipes: [a])
        let item = try! XCTUnwrap(vm.items.first)

        vm.toggleChecked(item)
        XCTAssertEqual(vm.items.first?.isChecked, true)

        vm.refresh(recipes: [a])
        XCTAssertEqual(vm.items.first?.isChecked, true)   // checked state persisted, not lost on re-derive
    }

    func test_exclusions_persist_across_view_model_instances() {
        let a = recipe("Pasta", [("100", "g", "Mehl")])
        let b = recipe("Kuchen", [("50", "g", "Zucker")])
        savePlan([a.id, b.id])
        makeVM().removeRecipe(a.id)   // first instance removes, then is discarded

        let vm2 = makeVM()
        vm2.refresh(recipes: [a, b])

        XCTAssertEqual(vm2.displayedRecipes.map(\.id), [b.id])
    }
}
