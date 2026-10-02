import SwiftUI

/// First-run gate: shows the onboarding flow until it's completed, then the tab bar.
/// Owns the selected tab so screen 07 can land the user on the right place.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userSettings") private var settings = UserSettings()
    @State private var selectedTab: AppTab = .mealPlan

    var body: some View {
        if hasCompletedOnboarding {
            ContentView(selection: $selectedTab)
        } else {
            OnboardingFlowView(initialSettings: settings) { tab in
                selectedTab = tab
                hasCompletedOnboarding = true
            }
        }
    }
}
