import XCTest
@testable import FamilyFood

/// Counts `save()` calls so tests can pin "exactly one context save per generation".
private final class SaveSpy: ModelSaving {
    private(set) var saveCount = 0
    func save() throws { saveCount += 1 }
}

final class SuggestionEngineTests: XCTestCase {
    // Week 24 of 2026 (Mon 08.06.) — fixed so Kita `weekOf` strings can be made to
    // match or miss it deterministically.
    private let week = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 24)

    private let fixedNow: Date = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "dd.MM.yyyy"
        return fmt.date(from: "10.06.2026")!
    }()

    private func makeEngine(spy: SaveSpy = SaveSpy(),
                            noise: @escaping () -> Double = { 0 }) -> SuggestionEngine {
        SuggestionEngine(modelContext: spy, now: { self.fixedNow }, noise: noise)
    }

    private func makeSettings(diet: DietStyle = .omnivore,
                              allergens: [String] = [],
                              warmDays: Set<Weekday> = [.monday],
                              maxCookTime: Int? = nil) -> UserSettings {
        UserSettings(maxCookTimeMinutes: maxCookTime,
                     dietStyle: diet,
                     allergens: allergens,
                     warmMealDays: warmDays)
    }

    private func makeRecipe(_ title: String,
                            main: MainIngredient? = nil,
                            diet: DietStyle = .omnivore,
                            allergens: [String] = [],
                            favourite: Bool = false,
                            lastRecommended: Date? = nil,
                            swapCount: Int = 0,
                            totalTime: Int? = nil) -> RecipeModel {
        RecipeModel(title: title,
                    totalTime: totalTime,
                    dietStyle: diet,
                    isFavourite: favourite,
                    mainIngredient: main?.rawValue,
                    lastRecommendedDate: lastRecommended,
                    swapCount: swapCount,
                    allergenTags: allergens)
    }

    /// A Kita plan in the same week as `week`, with the given Monday main ingredient.
    private func makeKita(mondayMain: MainIngredient, weekOf: String = "08.06.2026") -> KitaMealPlan {
        KitaMealPlan(weekOf: weekOf,
                     monday: KitaMealPlan.Day(date: nil, meal: "Kita-Essen",
                                              mainIngredient: mondayMain.rawValue))
    }

    private func assignedIds(_ plan: WeeklyPlan) -> [UUID] {
        plan.slots.compactMap { $0.meal?.recipeId }
    }

    private func generate(recipes: [RecipeModel],
                          kitaPlans: [KitaMealPlan] = [],
                          settings: UserSettings,
                          spy: SaveSpy = SaveSpy(),
                          noise: @escaping () -> Double = { 0 }) -> WeeklyPlan {
        makeEngine(spy: spy, noise: noise).generateWeeklyPlan(
            recipes: recipes, kitaPlans: kitaPlans, settings: settings, week: week)
    }

    // MARK: - Hard exclusions

    func test_allergen_recipes_are_never_assigned() {
        let pfannkuchen = makeRecipe("Pfannkuchen", allergens: ["Ei", "Milch"], favourite: true)
        let curry = makeRecipe("Gemüsecurry")
        let plan = generate(recipes: [pfannkuchen, curry],
                            settings: makeSettings(allergens: ["Ei"]))
        XCTAssertEqual(assignedIds(plan), [curry.id])
    }

    func test_allergen_recipe_stays_excluded_even_as_the_only_candidate() {
        let pfannkuchen = makeRecipe("Pfannkuchen", allergens: ["Ei"])
        let plan = generate(recipes: [pfannkuchen],
                            settings: makeSettings(allergens: ["Ei"]))
        XCTAssertTrue(assignedIds(plan).isEmpty)
    }

    func test_vegetarian_household_gets_vegetarian_and_vegan_recipes_only() {
        let veggie = makeRecipe("Gemüselasagne", main: .gemuese, diet: .vegetarian)
        let vegan = makeRecipe("Linsencurry", main: .huelsenfruchte, diet: .vegan)
        let meat = makeRecipe("Gulasch", main: .fleisch, diet: .omnivore)
        let unknown = makeRecipe("Überraschung", main: .sonstiges, diet: .unknown)
        let plan = generate(recipes: [veggie, vegan, meat, unknown],
                            settings: makeSettings(diet: .vegetarian,
                                                   warmDays: [.monday, .tuesday]))
        XCTAssertEqual(Set(assignedIds(plan)), Set([veggie.id, vegan.id]))
    }

    func test_vegan_household_excludes_vegetarian_and_unknown_diet_recipes() {
        let vegan = makeRecipe("Linsencurry", diet: .vegan)
        let veggie = makeRecipe("Käsespätzle", diet: .vegetarian)
        let unknown = makeRecipe("Überraschung", diet: .unknown)
        let plan = generate(recipes: [vegan, veggie, unknown],
                            settings: makeSettings(diet: .vegan,
                                                   warmDays: [.monday, .tuesday]))
        // Only one eligible recipe — pass 3 repeats it rather than admitting the others.
        XCTAssertEqual(Set(assignedIds(plan)), Set([vegan.id]))
        XCTAssertEqual(assignedIds(plan).count, 2)
    }

    func test_max_cook_time_excludes_slower_recipes() {
        let slow = makeRecipe("Braten", favourite: true, totalTime: 90)
        let fast = makeRecipe("Omelett", totalTime: 20)
        let plan = generate(recipes: [slow, fast],
                            settings: makeSettings(maxCookTime: 30))
        XCTAssertEqual(assignedIds(plan), [fast.id])
    }

    // MARK: - Kita main-ingredient blocking

    func test_kita_main_ingredient_blocks_matching_recipes() {
        let pasta = makeRecipe("Spaghetti", main: .pasta, favourite: true)
        let reis = makeRecipe("Reispfanne", main: .reis)
        let plan = generate(recipes: [pasta, reis],
                            kitaPlans: [makeKita(mondayMain: .pasta)],
                            settings: makeSettings())
        XCTAssertEqual(assignedIds(plan), [reis.id])
    }

    func test_kita_sonstiges_blocks_nothing() {
        let sonstiges = makeRecipe("Auflauf", main: .sonstiges, favourite: true)
        let reis = makeRecipe("Reispfanne", main: .reis)
        let plan = generate(recipes: [sonstiges, reis],
                            kitaPlans: [makeKita(mondayMain: .sonstiges)],
                            settings: makeSettings())
        XCTAssertEqual(assignedIds(plan), [sonstiges.id])
    }

    func test_kita_plan_for_another_week_blocks_nothing() {
        let pasta = makeRecipe("Spaghetti", main: .pasta, favourite: true)
        let reis = makeRecipe("Reispfanne", main: .reis)
        let plan = generate(recipes: [pasta, reis],
                            kitaPlans: [makeKita(mondayMain: .pasta, weekOf: "15.06.2026")],
                            settings: makeSettings())
        XCTAssertEqual(assignedIds(plan), [pasta.id])
    }

    // MARK: - Scoring order

    func test_favourite_bonus_outranks_an_otherwise_equal_recipe() {
        let favourite = makeRecipe("Lieblingsessen", favourite: true)
        let plain = makeRecipe("Alltagsessen")
        let plan = generate(recipes: [plain, favourite], settings: makeSettings())
        XCTAssertEqual(assignedIds(plan), [favourite.id])
    }

    func test_recently_recommended_recipes_rank_below_fresh_ones() {
        let yesterday = fixedNow.addingTimeInterval(-86_400)
        let recent = makeRecipe("Schon gesehen", lastRecommended: yesterday)
        let fresh = makeRecipe("Lange nicht gekocht")
        let plan = generate(recipes: [recent, fresh], settings: makeSettings())
        XCTAssertEqual(assignedIds(plan), [fresh.id])
    }

    func test_swap_penalty_ranks_often_swapped_recipes_lower() {
        let swapped = makeRecipe("Oft getauscht", swapCount: 3)
        let kept = makeRecipe("Nie getauscht")
        let plan = generate(recipes: [swapped, kept], settings: makeSettings())
        XCTAssertEqual(assignedIds(plan), [kept.id])
    }

    // MARK: - Relaxation order (variety → repeat-ingredient → repeat-recipe)

    func test_pass1_prefers_distinct_main_ingredients() {
        let pastaTop = makeRecipe("Spaghetti", main: .pasta, favourite: true)
        let pastaAlt = makeRecipe("Penne", main: .pasta)
        let reis = makeRecipe("Reispfanne", main: .reis)
        let plan = generate(recipes: [pastaTop, pastaAlt, reis],
                            settings: makeSettings(warmDays: [.monday, .tuesday]))
        XCTAssertEqual(Set(assignedIds(plan)), Set([pastaTop.id, reis.id]))
    }

    func test_pass2_repeats_an_ingredient_before_leaving_a_slot_empty() {
        let pastaTop = makeRecipe("Spaghetti", main: .pasta, favourite: true)
        let pastaAlt = makeRecipe("Penne", main: .pasta)
        let plan = generate(recipes: [pastaTop, pastaAlt],
                            settings: makeSettings(warmDays: [.monday, .tuesday]))
        XCTAssertEqual(Set(assignedIds(plan)), Set([pastaTop.id, pastaAlt.id]))
    }

    func test_pass3_repeats_a_recipe_before_leaving_a_slot_empty() {
        let only = makeRecipe("Einziges Rezept", main: .pasta)
        let plan = generate(recipes: [only],
                            settings: makeSettings(warmDays: [.monday, .tuesday]))
        XCTAssertEqual(assignedIds(plan), [only.id, only.id])
    }

    // MARK: - Persistence of recommendation stamps

    func test_exactly_one_save_per_generation() {
        let spy = SaveSpy()
        let recipes = [
            makeRecipe("A", main: .pasta),
            makeRecipe("B", main: .reis),
            makeRecipe("C", main: .gemuese),
        ]
        _ = generate(recipes: recipes,
                     settings: makeSettings(warmDays: Set(Weekday.allCases)),
                     spy: spy)
        XCTAssertEqual(spy.saveCount, 1)
    }

    func test_no_save_when_nothing_was_assigned() {
        let spy = SaveSpy()
        _ = generate(recipes: [], settings: makeSettings(), spy: spy)
        XCTAssertEqual(spy.saveCount, 0)
    }

    func test_assigned_recipes_are_stamped_with_the_injected_now() {
        let recipe = makeRecipe("Spaghetti")
        _ = generate(recipes: [recipe], settings: makeSettings())
        XCTAssertEqual(recipe.lastRecommendedDate, fixedNow)
    }
}
