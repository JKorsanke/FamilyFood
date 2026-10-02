import Foundation

struct Child: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct UserSettings: Equatable {
    var maxCookTimeMinutes: Int? = 30
    var dietStyle: DietStyle = .vegetarian
    var allergens: [String] = []
    var warmMealDays: Set<Weekday> = [.monday]
    var children: [Child] = []
    var adults: Int = 1

    /// Renames the child with `id` to a trimmed `newName`. A name that is empty or
    /// whitespace-only removes the child entirely (on-device delete). Unknown ids are ignored.
    mutating func renameChild(id: UUID, to newName: String) {
        guard let idx = children.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            children.remove(at: idx)
        } else {
            children[idx].name = trimmed
        }
    }
}

extension UserSettings: RawRepresentable {
    private struct Storage: Codable {
        var maxCookTimeMinutes: Int?
        var dietStyle: DietStyle
        var allergens: [String]
        var warmMealDays: Set<Weekday>
        var children: [Child]?   // optional so old JSON without this key still decodes
        var adults: Int?         // optional so old JSON without this key still decodes
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let s = try? JSONDecoder().decode(Storage.self, from: data) else { return nil }
        maxCookTimeMinutes = s.maxCookTimeMinutes
        dietStyle = s.dietStyle
        allergens = s.allergens
        warmMealDays = s.warmMealDays
        children = s.children ?? []
        adults = s.adults ?? 1
    }

    var rawValue: String {
        let s = Storage(
            maxCookTimeMinutes: maxCookTimeMinutes,
            dietStyle: dietStyle,
            allergens: allergens,
            warmMealDays: warmMealDays,
            children: children,
            adults: adults
        )
        guard let data = try? JSONEncoder().encode(s) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

let allAllergens = ["Gluten", "Milch", "Ei", "Nüsse", "Erdnüsse", "Fisch", "Schalentiere", "Soja", "Sesam", "Sellerie", "Senf"]
