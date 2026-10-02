import SwiftUI
import SwiftData

@main
struct FamilyFoodApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var importCoordinator = ImportInboxCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer

    init() {
        AppFonts.registerIfNeeded()
        AppTheme.configureGlobalAppearance()   // keep the tab bar solid in every scroll state
        do {
            let schema = Schema([
                RecipeModel.self,
                IngredientGroupModel.self,
                RecipeIngredientModel.self
            ])
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData ModelContainer could not be created: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(importCoordinator)
                .modelContainer(container)
                .task {
                    await seedIfNeeded()
                    await migrateAllergenTagsIfNeeded()
                    await cleanRecipeTextsIfNeeded()
                    importCoordinator.drain()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { importCoordinator.drain() }
                }
        }
    }

    @MainActor
    private func seedIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: "hasSeededRecipes") else { return }
        await RecipeDatabaseService(modelContext: container.mainContext).seedFromBundle()
        UserDefaults.standard.set(true, forKey: "hasSeededRecipes")
    }

    /// One-time sweep over stored recipes whose texts were saved with raw
    /// HTML remnants — bundled seed data and earlier web imports.
    @MainActor
    private func cleanRecipeTextsIfNeeded() async {
        let flag = "hasCleanedRecipeTextsV1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        do {
            try RecipeDatabaseService(modelContext: container.mainContext).cleanAllRecipeTexts()
        } catch {
            Log.persistence.error("recipe text cleanup: failed — retrying next launch: \(error.localizedDescription)")
            return
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    @MainActor
    private func migrateAllergenTagsIfNeeded() async {
        let flag = "hasAppliedAllergenTagsV1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let descriptor = FetchDescriptor<RecipeModel>()
        guard let recipes = try? container.mainContext.fetch(descriptor) else {
            Log.persistence.error("allergen migration: recipe fetch failed — retrying next launch")
            return
        }
        for recipe in recipes where recipe.allergenTags.isEmpty {
            let names = recipe.ingredientGroups.flatMap { $0.ingredients.map { $0.name } }
            recipe.allergenTags = inferAllergenTags(from: names)
        }
        do { try container.mainContext.save() } catch {
            Log.persistence.error("allergen migration: save failed: \(error.localizedDescription)")
        }
        UserDefaults.standard.set(true, forKey: flag)
    }
}
