import Foundation
import SwiftData

/// Backs the Einkaufsliste. The list is *derived*: `displayedRecipes` is the current week's
/// planned recipes minus the ones the user removed (`×`), and `items` is those recipes'
/// ingredients aggregated by `ShoppingListBuilder`. The plan stays the single source of truth —
/// this view model only reads it (via `PlanStore`) and never writes it back, so removing a
/// recipe here can never touch the weekly plan. The only persisted state is the user's overrides
/// (removed recipes, ticked items) in `ShoppingListStore`.
@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var displayedRecipes: [RecipeModel] = []
    @Published private(set) var items: [ShoppingItem] = []

    private let planStore: PlanStore
    private let store: ShoppingListStore
    private var state: ShoppingListState
    private var allRecipes: [RecipeModel] = []

    init(planStore: PlanStore = PlanStore(), store: ShoppingListStore = ShoppingListStore()) {
        self.planStore = planStore
        self.store = store
        self.state = store.load()
    }

    /// Re-derive the list from the current week's plan and the supplied recipe database.
    /// Call when the screen appears and whenever the recipe set changes.
    func refresh(recipes: [RecipeModel]) {
        allRecipes = recipes
        recompute()
    }

    /// Remove a recipe from the shopping list only — the weekly plan is untouched.
    func removeRecipe(_ id: UUID) {
        state.excludedRecipeIds.insert(id)
        store.save(state)
        recompute()
    }

    /// Empty the whole list (trash). Clears instantly, no confirmation.
    func clearAll() {
        state.excludedRecipeIds.formUnion(displayedRecipes.map(\.id))
        store.save(state)
        recompute()
    }

    /// Tick / untick an ingredient line.
    func toggleChecked(_ item: ShoppingItem) {
        if state.checkedItemKeys.contains(item.id) {
            state.checkedItemKeys.remove(item.id)
        } else {
            state.checkedItemKeys.insert(item.id)
        }
        store.save(state)
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i].isChecked.toggle()
        }
    }

    // MARK: - Derivation

    private func recompute() {
        let byId = Dictionary(allRecipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let plannedIds = planStore.loadWeeklyPlans()
            .first { $0.weekKey == .current }?
            .slots.compactMap { $0.meal?.recipeId } ?? []

        var seen = Set<UUID>()
        var resolved: [RecipeModel] = []
        for id in plannedIds where !state.excludedRecipeIds.contains(id) {
            guard seen.insert(id).inserted else { continue }   // one card per recipe, even if planned twice
            if let recipe = byId[id] { resolved.append(recipe) }
        }
        displayedRecipes = resolved

        var built = ShoppingListBuilder.aggregate(resolved)
        for i in built.indices {
            built[i].isChecked = state.checkedItemKeys.contains(built[i].id)
        }
        items = built
    }
}
