import Foundation
import SwiftData

/// The single SwiftData operation the engine performs. Tests inject a spy through it
/// to pin "exactly one save per generation"; production passes the `ModelContext`.
protocol ModelSaving {
    func save() throws
}

extension ModelContext: ModelSaving {}

struct SuggestionEngine {
    private let modelContext: any ModelSaving
    private let now: () -> Date
    private let noise: () -> Double

    /// `now` and `noise` are injectable so scoring is deterministic under test;
    /// production callers take the defaults.
    init(
        modelContext: any ModelSaving,
        now: @escaping () -> Date = Date.init,
        noise: @escaping () -> Double = { Double.random(in: 0.0...0.05) }
    ) {
        self.modelContext = modelContext
        self.now = now
        self.noise = noise
    }

    func generateWeeklyPlan(
        recipes: [RecipeModel],
        kitaPlans: [KitaMealPlan],
        settings: UserSettings,
        week: WeekKey
    ) -> WeeklyPlan {
        var plan = WeeklyPlan(weekKey: week)

        // 3a — Determine slot types (Abendbrot on non-warm-meal days)
        plan.applyWarmMealLayout(settings.warmMealDays)

        // 3b — Collect blocked ingredients from active Kita plans.
        // "Sonstiges" means "couldn't classify" — same as nil; don't let it block recipes.
        let sonstiges = MainIngredient.sonstiges.rawValue.lowercased()
        var blockedIngredients = Set<String>()
        for kitaPlan in kitaPlans {
            guard KitaWeekMatcher.matches(kitaPlan, weekStart: week.startDate) else { continue }
            let dayIngredients = [
                kitaPlan.monday.mainIngredient,
                kitaPlan.tuesday.mainIngredient,
                kitaPlan.wednesday.mainIngredient,
                kitaPlan.thursday.mainIngredient,
                kitaPlan.friday.mainIngredient,
            ]
            for ing in dayIngredients.compactMap({ $0 }) {
                let normalized = ing.lowercased()
                guard normalized != sonstiges else { continue }
                blockedIngredients.insert(normalized)
            }
        }

        // 3c — Score candidates
        let scored: [(recipe: RecipeModel, score: Double)] = recipes.compactMap { recipe in
            guard let s = score(recipe: recipe, settings: settings) else { return nil }
            return (recipe, s)
        }

        // 3d — Assign recipes to warm-meal slots
        var usedIngredients = blockedIngredients
        var assignedIds = Set<UUID>()

        for i in plan.slots.indices {
            guard plan.slots[i].meal == nil else { continue }  // skip Abendbrot slots

            let assigned = assignRecipe(
                from: scored,
                usedIngredients: usedIngredients,
                assignedIds: assignedIds
            )
            guard let recipe = assigned else { continue }

            plan.slots[i].meal = PlannedMeal(
                name: recipe.title,
                kind: .recipe(id: recipe.id, engineId: recipe.id)
            )
            assignedIds.insert(recipe.id)
            if let ing = recipe.mainIngredient {
                usedIngredients.insert(ing.lowercased())
            }
            // Stamped at generation (not cooking) time — accepted for v1: repeated
            // Generate taps tank every suggested recipe's recency score.
            recipe.lastRecommendedDate = now()
        }

        // 3e — Persist the recommendation stamps, once per generation
        if !assignedIds.isEmpty {
            do { try modelContext.save() } catch {
                Log.engine.error("recommendation stamps not persisted: \(error.localizedDescription)")
            }
        }

        return plan
    }

    // MARK: - Scoring

    private func score(recipe: RecipeModel, settings: UserSettings) -> Double? {
        // Hard exclusions
        guard !recipe.allergenTags.contains(where: { settings.allergens.contains($0) }) else { return nil }
        guard settings.dietStyle == .omnivore ||
              recipe.dietStyle == settings.dietStyle ||
              recipe.dietStyle == .vegan else { return nil }
        if let maxTime = settings.maxCookTimeMinutes,
           let recipeTime = recipe.displayTotalTime,
           recipeTime > maxTime { return nil }

        let recencyScore: Double = {
            guard let last = recipe.lastRecommendedDate else { return 1.0 }
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: now()).day ?? 0
            return min(Double(daysSince) / 60.0, 1.0)
        }()

        let favouriteBonus: Double = recipe.isFavourite ? 0.3 : 0.0
        let swapPenalty: Double = min(Double(recipe.swapCount) * 0.1, 0.5)
        let randomNoise: Double = noise()

        return recencyScore + favouriteBonus - swapPenalty + randomNoise
    }

    // MARK: - Assignment with fallback

    private func assignRecipe(
        from scored: [(recipe: RecipeModel, score: Double)],
        usedIngredients: Set<String>,
        assignedIds: Set<UUID>
    ) -> RecipeModel? {
        // Pass 1: respect ingredient variety + already-assigned constraint
        if let best = bestCandidate(from: scored, assignedIds: assignedIds, blockedIngredients: usedIngredients) {
            return best
        }
        // Pass 2: relax ingredient-variety (allow Kita conflicts / repeated ingredients)
        if let best = bestCandidate(from: scored, assignedIds: assignedIds, blockedIngredients: []) {
            return best
        }
        // Pass 3: allow repeats (relax already-assigned)
        return scored.max(by: { $0.score < $1.score })?.recipe
    }

    private func bestCandidate(
        from scored: [(recipe: RecipeModel, score: Double)],
        assignedIds: Set<UUID>,
        blockedIngredients: Set<String>
    ) -> RecipeModel? {
        scored
            .filter { !assignedIds.contains($0.recipe.id) }
            .filter {
                guard let ing = $0.recipe.mainIngredient else { return true }  // nil → "Sonstiges", never blocked
                return !blockedIngredients.contains(ing.lowercased())
            }
            .max(by: { $0.score < $1.score })?
            .recipe
    }
}
