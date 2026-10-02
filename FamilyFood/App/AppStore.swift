import SwiftUI

/// Shared app-wide state passed through the environment.
@MainActor
class AppStore: ObservableObject {
    @Published var kitaPlans: [KitaMealPlan] = [] { didSet { persist() } }
    private let store: PlanStore
    private var isLoaded = false   // suppress persistence while loading

    init(store: PlanStore = PlanStore()) {
        self.store = store
        kitaPlans = store.loadKitaPlans()
        isLoaded = true
    }

    private func persist() {
        guard isLoaded else { return }
        store.saveKitaPlans(kitaPlans)
    }
}
