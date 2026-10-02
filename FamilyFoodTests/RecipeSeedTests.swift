import XCTest
import SwiftData
@testable import FamilyFood

/// Counts nothing — the engine only needs something to call `save()` on.
private struct NoSave: ModelSaving {
    func save() throws {}
}

@MainActor
final class RecipeSeedTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("seed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ name: String, _ contents: String = "[]") throws {
        try Data(contents.utf8).write(to: tmp.appendingPathComponent(name))
    }

    // MARK: — Which seed file a build uses

    func test_seed_url_falls_back_to_the_sample_file() throws {
        try write("recipes.json")
        let bundle = try XCTUnwrap(Bundle(url: tmp))
        XCTAssertEqual(RecipeSeed.url(in: bundle)?.lastPathComponent, "recipes.json")
    }

    func test_seed_url_prefers_a_local_overlay_file() throws {
        try write("recipes.json")
        try write("recipes.local.json")
        let bundle = try XCTUnwrap(Bundle(url: tmp))
        XCTAssertEqual(RecipeSeed.url(in: bundle)?.lastPathComponent, "recipes.local.json")
    }

    func test_seed_url_is_nil_when_no_seed_file_is_bundled() throws {
        let bundle = try XCTUnwrap(Bundle(url: tmp))
        XCTAssertNil(RecipeSeed.url(in: bundle))
    }

    // MARK: — Mapping a seed record

    private func decode(_ json: String) throws -> BundledRecipe {
        try JSONDecoder().decode(BundledRecipe.self, from: Data(json.utf8))
    }

    func test_bundled_recipe_maps_its_diet_style() throws {
        let bundled = try decode(#"{"id":1,"title":"Rührei","diet_style":"vegetarian","ingredient_groups":[]}"#)
        XCTAssertEqual(RecipeModel.from(bundled: bundled).dietStyle, .vegetarian)
    }

    func test_bundled_recipe_without_diet_style_is_unknown() throws {
        let bundled = try decode(#"{"id":1,"title":"Rührei","ingredient_groups":[]}"#)
        XCTAssertEqual(RecipeModel.from(bundled: bundled).dietStyle, .unknown)
    }

    func test_bundled_recipe_with_unrecognised_diet_style_is_unknown() throws {
        let bundled = try decode(#"{"id":1,"title":"Rührei","diet_style":"paleo","ingredient_groups":[]}"#)
        XCTAssertEqual(RecipeModel.from(bundled: bundled).dietStyle, .unknown)
    }

    // MARK: — Seeding from data (no bundle involved)

    private func makeService() throws -> (RecipeDatabaseService, ModelContainer) {
        let container = try ModelContainer(for: RecipeModel.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let images = ImageStorageService(directory: tmp.appendingPathComponent("images", isDirectory: true))
        return (RecipeDatabaseService(modelContext: container.mainContext, imageStorage: images), container)
    }

    func test_seed_inserts_recipes_with_ingredients_and_inferred_allergens() throws {
        let json = """
        [{"id":1,"title":"Tomatennudeln","diet_style":"vegan","main_ingredient":"Pasta","total_time":"20",
          "ingredient_groups":[{"name":"","ingredients":[
            {"amount":"300","unit":"g","name":"Spaghetti","notes":""},
            {"amount":"1","unit":"Dose","name":"Tomaten","notes":"stückig"}]}]},
         {"id":2,"title":"Rührei","diet_style":"vegetarian","main_ingredient":"Ei",
          "ingredient_groups":[{"name":"","ingredients":[
            {"amount":"4","unit":"","name":"Eier","notes":""}]}]}]
        """
        let (service, container) = try makeService()

        service.seed(from: Data(json.utf8))

        let recipes = try container.mainContext.fetch(FetchDescriptor<RecipeModel>(sortBy: [SortDescriptor(\.title)]))
        XCTAssertEqual(recipes.map(\.title), ["Rührei", "Tomatennudeln"])
        let pasta = try XCTUnwrap(recipes.last)
        XCTAssertEqual(pasta.source, .bundled)
        XCTAssertEqual(pasta.dietStyle, .vegan)
        XCTAssertEqual(pasta.totalTime, 20)
        XCTAssertEqual(pasta.ingredientGroups.first?.ingredients.count, 2)
        XCTAssertEqual(pasta.allergenTags, ["Gluten"])
        XCTAssertEqual(recipes.first?.allergenTags, ["Ei"])
        XCTAssertNil(pasta.imageLocalPath, "a seed record without an image must not claim one")
    }

    func test_seed_with_undecodable_data_inserts_nothing() throws {
        let (service, container) = try makeService()
        service.seed(from: Data("not json".utf8))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<RecipeModel>()), 0)
    }

    // MARK: — The sample set shipped in the repository (`recipes.json`)

    private func sampleRecipes() throws -> [BundledRecipe] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "recipes", withExtension: "json"),
                                "the sample recipes.json must be bundled")
        return try JSONDecoder().decode([BundledRecipe].self, from: Data(contentsOf: url))
    }

    func test_sample_set_is_well_formed() throws {
        let sample = try sampleRecipes()
        XCTAssertGreaterThanOrEqual(sample.count, 20)
        XCTAssertEqual(Set(sample.map(\.id)).count, sample.count, "ids must be unique")
        XCTAssertEqual(Set(sample.map(\.title)).count, sample.count, "titles must be unique")

        let vocabulary = Set(MainIngredient.allCases.map(\.rawValue))
        for recipe in sample {
            XCTAssertTrue(vocabulary.contains(recipe.main_ingredient ?? ""),
                          "\(recipe.title): main_ingredient '\(recipe.main_ingredient ?? "nil")' is not in the vocabulary")
            XCTAssertNotNil(DietStyle(rawValue: recipe.diet_style ?? "").flatMap { DietStyle.manualCases.contains($0) ? $0 : nil },
                            "\(recipe.title): diet_style must be vegan, vegetarian or omnivore")
            XCTAssertNotNil(Int(recipe.total_time ?? ""), "\(recipe.title): total_time must be minutes")
            XCTAssertFalse(recipe.ingredient_groups.flatMap(\.ingredients).isEmpty, "\(recipe.title): no ingredients")
            XCTAssertFalse((recipe.summary ?? "").isEmpty, "\(recipe.title): no summary")
        }
    }

    /// The sample set is original content: it must not point at third-party pages or photos.
    func test_sample_set_references_no_external_source_or_image() throws {
        for recipe in try sampleRecipes() {
            XCTAssertNil(recipe.url, "\(recipe.title) has a source url")
            XCTAssertNil(recipe.image, "\(recipe.title) has an image")
        }
    }

    /// Enough variety that a household can plan seven warm dinners under the default
    /// 30-minute limit, whatever its diet style, without repeating a recipe or a main ingredient.
    func test_sample_set_fills_a_varied_week_for_every_diet_style() throws {
        let recipes = try sampleRecipes().map { RecipeModel.from(bundled: $0) }
        let week = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 24)

        for diet in DietStyle.manualCases {
            let settings = UserSettings(maxCookTimeMinutes: 30, dietStyle: diet,
                                        warmMealDays: Set(Weekday.allCases))
            let plan = SuggestionEngine(modelContext: NoSave(), noise: { 0 })
                .generateWeeklyPlan(recipes: recipes, kitaPlans: [], settings: settings, week: week)

            let ids = plan.slots.compactMap { $0.meal?.recipeId }
            XCTAssertEqual(ids.count, 7, "\(diet): every day needs a recipe")
            XCTAssertEqual(Set(ids).count, 7, "\(diet): no recipe twice")
            let mains = ids.compactMap { id in recipes.first { $0.id == id }?.mainIngredient }
            XCTAssertEqual(Set(mains).count, 7, "\(diet): seven different main ingredients, got \(mains)")
        }
    }
}
