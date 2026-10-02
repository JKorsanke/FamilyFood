import SwiftUI

/// The app's tabs. Tags let onboarding (screen 07) land the user on a specific one.
/// `shoppingList` is appended (not inserted) so the existing tags keep their raw values.
enum AppTab: Int {
    case mealPlan, recipes, kitaImport, settings, shoppingList
}

struct ContentView: View {
    @EnvironmentObject private var importCoordinator: ImportInboxCoordinator
    @Binding var selection: AppTab

    var body: some View {
        TabView(selection: $selection) {
            MealPlanView()
                .tabItem { Label("Wochenplan", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.mealPlan)

            RecipeDatabaseView()
                .tabItem { Label("Rezepte", systemImage: "fork.knife") }
                .tag(AppTab.recipes)

            ShoppingListView()
                .tabItem { Label("Einkaufsliste", systemImage: "cart") }
                .tag(AppTab.shoppingList)

            KindergartenImportView()
                .tabItem { Label("Kita-Import", systemImage: "camera") }
                .tag(AppTab.kitaImport)

            UserSettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .background(ImportInboxHostView(coordinator: importCoordinator))
    }
}
