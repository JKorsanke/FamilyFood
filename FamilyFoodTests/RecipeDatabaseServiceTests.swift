import XCTest
import SwiftData
import UIKit
@testable import FamilyFood

@MainActor
final class RecipeDatabaseServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var service: RecipeDatabaseService!
    private var imageDirectory: URL!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: RecipeModel.self, configurations: config)
        // Temp-dir image storage — tests must never write into the real
        // Documents container.
        imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("recipe-images-\(UUID().uuidString)", isDirectory: true)
        service = RecipeDatabaseService(modelContext: container.mainContext,
                                        imageStorage: ImageStorageService(directory: imageDirectory))
    }

    override func tearDown() async throws {
        if let imageDirectory {
            try? FileManager.default.removeItem(at: imageDirectory)
        }
    }

    private func jpegData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    // MARK: — Saving a draft (exercisable only with injected image storage)

    func test_save_writes_recipe_and_local_image_into_injected_directory() async throws {
        var draft = RecipeDraft()
        draft.title = "Pfannkuchen"
        draft.localImageData = jpegData()

        try await service.save(draft)

        let recipes = try container.mainContext.fetch(FetchDescriptor<RecipeModel>())
        XCTAssertEqual(recipes.map(\.title), ["Pfannkuchen"])
        let path = try XCTUnwrap(recipes.first?.imageLocalPath)
        XCTAssertTrue(path.hasPrefix(imageDirectory.path),
                      "image must land in the injected directory, not the real container: \(path)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func test_delete_removes_recipe_and_its_stored_image() async throws {
        var draft = RecipeDraft()
        draft.title = "Shakshuka"
        draft.localImageData = jpegData()
        try await service.save(draft)
        let recipe = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<RecipeModel>()).first)
        let imagePath = try XCTUnwrap(recipe.imageLocalPath)

        try service.delete(recipe)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imagePath))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<RecipeModel>()).isEmpty)
    }

    func test_toggleFavourite_sets_flag_and_stamps_date() {
        let recipe = RecipeModel(title: "Spaghetti")
        container.mainContext.insert(recipe)

        service.toggleFavourite(recipe)

        XCTAssertTrue(recipe.isFavourite)
        XCTAssertNotNil(recipe.dateFavourited)
    }

    // Recipes already in the database (bundled seed, earlier imports)
    // carry raw HTML in their texts — a one-time sweep must clean them in place.
    func test_cleanAllRecipeTexts_cleans_stored_recipe_fields() throws {
        let recipe = RecipeModel(title: "Mac &amp; Cheese",
                                 summary: "<p>Cremig &amp; lecker.</p>")
        container.mainContext.insert(recipe)
        let group = IngredientGroupModel(name: "F&uuml;r die Sauce", sortOrder: 0)
        container.mainContext.insert(group)
        recipe.ingredientGroups.append(group)
        let ingredient = RecipeIngredientModel(amount: "200", unit: "g",
                                               name: "Cashewkerne&nbsp;(roh)",
                                               notes: "&quot;frisch&quot;", sortOrder: 0)
        container.mainContext.insert(ingredient)
        group.ingredients.append(ingredient)

        try service.cleanAllRecipeTexts()

        XCTAssertEqual(recipe.title, "Mac & Cheese")
        XCTAssertEqual(recipe.summary, "Cremig & lecker.")
        XCTAssertEqual(group.name, "Für die Sauce")
        XCTAssertEqual(ingredient.name, "Cashewkerne (roh)")
        XCTAssertEqual(ingredient.notes, "\"frisch\"")
    }

    func test_cleanAllRecipeTexts_leaves_clean_recipes_untouched() throws {
        let recipe = RecipeModel(title: "Kartoffelgratin", summary: "Cremig und schnell.")
        container.mainContext.insert(recipe)

        try service.cleanAllRecipeTexts()

        XCTAssertEqual(recipe.title, "Kartoffelgratin")
        XCTAssertEqual(recipe.summary, "Cremig und schnell.")
    }

    func test_toggleFavourite_back_clears_the_date() {
        let recipe = RecipeModel(title: "Spaghetti", isFavourite: true, dateFavourited: Date())
        container.mainContext.insert(recipe)

        service.toggleFavourite(recipe)

        XCTAssertFalse(recipe.isFavourite)
        XCTAssertNil(recipe.dateFavourited)
    }
}
