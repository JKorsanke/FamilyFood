import Foundation
import SwiftData
import UIKit

/// The seed file a build ships with. The repository carries an original sample set
/// (`recipes.json`); a build may additionally bundle a local, untracked
/// `LocalOverlay/recipes.local.json` (with its `RecipeImages/`), which then takes precedence.
enum RecipeSeed {
    /// Resource names without extension, in order of preference.
    static let resourceNames = ["recipes.local", "recipes"]

    static func url(in bundle: Bundle) -> URL? {
        resourceNames.lazy
            .compactMap { bundle.url(forResource: $0, withExtension: "json") }
            .first
    }
}

@MainActor
final class RecipeDatabaseService {
    private let modelContext: ModelContext
    private let imageStorage: ImageStorageService

    init(modelContext: ModelContext, imageStorage: ImageStorageService = .shared) {
        self.modelContext = modelContext
        self.imageStorage = imageStorage
    }

    // MARK: — Seeding

    /// First-launch seeding from the bundle's seed file and its images (if any).
    func seedFromBundle(_ bundle: Bundle = .main) async {
        guard let url = RecipeSeed.url(in: bundle), let data = try? Data(contentsOf: url) else {
            Log.persistence.error("recipe seeding: no readable seed file in the bundle")
            return
        }
        seed(from: data) { filename in
            let stem = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            // Try bundle root first, then RecipeImages subdirectory
            return bundle.url(forResource: stem, withExtension: ext)
                ?? bundle.url(forResource: stem, withExtension: ext, subdirectory: "RecipeImages")
        }
    }

    /// Inserts the recipes encoded in `data` (a JSON array of `BundledRecipe`).
    /// `imageURL` resolves a record's image file name to a readable file, or nil when
    /// the seed carries no image for it.
    func seed(from data: Data, imageURL: (String) -> URL? = { _ in nil }) {
        guard let bundledRecipes = try? JSONDecoder().decode([BundledRecipe].self, from: data) else {
            Log.persistence.error("recipe seeding: seed data undecodable")
            return
        }

        for bundled in bundledRecipes {
            let recipe = RecipeModel.from(bundled: bundled)
            modelContext.insert(recipe)

            var allIngredientNames: [String] = []
            for (gi, group) in bundled.ingredient_groups.enumerated() {
                let groupModel = IngredientGroupModel(name: group.name, sortOrder: gi)
                modelContext.insert(groupModel)
                recipe.ingredientGroups.append(groupModel)

                for (ii, ing) in group.ingredients.enumerated() {
                    let ingModel = RecipeIngredientModel(
                        amount: ing.amount, unit: ing.unit,
                        name: ing.name, notes: ing.notes, sortOrder: ii
                    )
                    modelContext.insert(ingModel)
                    groupModel.ingredients.append(ingModel)
                    allIngredientNames.append(ing.name)
                }
            }

            recipe.allergenTags = inferAllergenTags(from: allIngredientNames)
            copySeedImage(for: bundled, toRecipe: recipe, imageURL: imageURL)
        }

        do { try modelContext.save() } catch {
            Log.persistence.error("recipe seeding: save failed: \(error.localizedDescription)")
        }
    }

    private func copySeedImage(for bundled: BundledRecipe, toRecipe recipe: RecipeModel,
                               imageURL: (String) -> URL?) {
        guard let imagePath = bundled.image else { return }
        let filename = URL(fileURLWithPath: imagePath).lastPathComponent
        guard let sourceURL = imageURL(filename) else { return }

        do { try imageStorage.copyFromBundle(sourceURL, forRecipeId: recipe.id) } catch {
            Log.persistence.error("recipe seeding: bundled image for \(recipe.title) not copied: \(error.localizedDescription)")
        }
        recipe.imageLocalPath = imageStorage.imageURL(for: recipe.id)?.path
    }

    // MARK: — Saving a reviewed draft

    func save(_ draft: RecipeDraft) async throws {
        let recipe = RecipeModel.from(draft: draft)
        modelContext.insert(recipe)

        if draft.allergenTags.isEmpty {
            let allIngredientNames = draft.ingredientGroups.flatMap { $0.ingredients.map { $0.name } }
            recipe.allergenTags = inferAllergenTags(from: allIngredientNames)
        }

        for (gi, group) in draft.ingredientGroups.enumerated() {
            let groupModel = IngredientGroupModel(name: group.name, sortOrder: gi)
            modelContext.insert(groupModel)
            recipe.ingredientGroups.append(groupModel)

            for (ii, ing) in group.ingredients.enumerated() {
                let ingModel = RecipeIngredientModel(
                    amount: ing.amount, unit: ing.unit,
                    name: ing.name, notes: ing.notes, sortOrder: ii
                )
                modelContext.insert(ingModel)
                groupModel.ingredients.append(ingModel)
            }
        }

        // Image failures don't fail the recipe save — the recipe is worth keeping without one.
        do {
            if let imageURLString = draft.imageURL, let remoteURL = URL(string: imageURLString) {
                try await imageStorage.downloadAndSave(from: remoteURL, forRecipeId: recipe.id)
            } else if let data = draft.localImageData, let image = UIImage(data: data) {
                try imageStorage.save(image, forRecipeId: recipe.id)
            }
        } catch {
            Log.persistence.error("recipe image for \(draft.title) not stored: \(error.localizedDescription)")
        }

        if let localURL = imageStorage.imageURL(for: recipe.id) {
            recipe.imageLocalPath = localURL.path
        }

        try modelContext.save()
    }

    // MARK: — Text cleanup

    /// Cleans HTML remnants (tags, entities, invisible characters) out of every
    /// stored recipe's user-visible texts — bundled seed data and earlier web
    /// imports were saved raw. Idempotent; flag-gated to one run in FamilyFoodApp.
    func cleanAllRecipeTexts() throws {
        let recipes = try modelContext.fetch(FetchDescriptor<RecipeModel>())
        for recipe in recipes {
            recipe.title = recipe.title.cleanedRecipeText
            recipe.summary = recipe.summary.map { $0.cleanedRecipeText }
            for group in recipe.ingredientGroups {
                group.name = group.name.cleanedRecipeText
                for ingredient in group.ingredients {
                    ingredient.amount = ingredient.amount.cleanedRecipeText
                    ingredient.unit = ingredient.unit.cleanedRecipeText
                    ingredient.name = ingredient.name.cleanedRecipeText
                    ingredient.notes = ingredient.notes.cleanedRecipeText
                }
            }
        }
        try modelContext.save()
    }

    // MARK: — Mutations

    func toggleFavourite(_ recipe: RecipeModel) {
        recipe.isFavourite.toggle()
        recipe.dateFavourited = recipe.isFavourite ? Date() : nil
        do { try modelContext.save() } catch {
            Log.persistence.error("favourite for \(recipe.title) not persisted: \(error.localizedDescription)")
        }
    }

    func delete(_ recipe: RecipeModel) throws {
        imageStorage.deleteImage(for: recipe.id)
        modelContext.delete(recipe)
        try modelContext.save()
    }

    // MARK: — Deduplication

    func recipeExists(withURL url: String) -> Bool {
        let predicate = #Predicate<RecipeModel> { $0.sourceURL == url }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
