import Foundation

/// The only mutable shopping-list state. Everything else is derived from the current week's plan,
/// so all we persist is the user's two overrides: recipes they removed from the list (`×`) and
/// ingredient lines they ticked off. On-device JSON, mirroring `PlanStore`; tests inject a dir.
struct ShoppingListState: Codable, Equatable {
    var excludedRecipeIds: Set<UUID> = []
    var checkedItemKeys: Set<String> = []

    static let empty = ShoppingListState()
}

struct ShoppingListStore {
    private let fileURL: URL

    /// Test/injection initializer — `directory` is any writable directory.
    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("shopping_list.json")
    }

    /// Production initializer — `<Application Support>/ShoppingList`.
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directory: base.appendingPathComponent("ShoppingList", isDirectory: true))
    }

    /// Returns the stored state, or `.empty` when there's no file yet or it can't be decoded.
    /// The state is just user overrides on top of derived data, so starting empty is always safe.
    func load() -> ShoppingListState {
        guard let data = try? Data(contentsOf: fileURL) else { return .empty }
        guard let state = try? JSONDecoder().decode(ShoppingListState.self, from: data) else {
            Log.persistence.error("shopping_list.json: undecodable — starting empty")
            return .empty
        }
        return state
    }

    func save(_ state: ShoppingListState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.persistence.error("shopping_list.json: save failed: \(error.localizedDescription)")
        }
    }
}
