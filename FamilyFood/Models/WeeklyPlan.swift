import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .monday:    return "Montag"
        case .tuesday:   return "Dienstag"
        case .wednesday: return "Mittwoch"
        case .thursday:  return "Donnerstag"
        case .friday:    return "Freitag"
        case .saturday:  return "Samstag"
        case .sunday:    return "Sonntag"
        }
    }

    var shortName: String {
        switch self {
        case .monday:    return "Mo"
        case .tuesday:   return "Di"
        case .wednesday: return "Mi"
        case .thursday:  return "Do"
        case .friday:    return "Fr"
        case .saturday:  return "Sa"
        case .sunday:    return "So"
        }
    }
    var isWeekend: Bool { self == .saturday || self == .sunday }
}

enum MealType: String, Codable {
    case lunch, dinner
    var displayName: String { self == .lunch ? "Mittag" : "Abend" }
}

/// What occupies a meal slot. One value instead of the old four quasi-exclusive flags
/// (`recipeId`/`isAbendbrot`/`isExtern`/`isAuto`), so illegal combinations like
/// "Abendbrot and Extern at once" are unrepresentable.
enum MealKind: Codable, Equatable {
    /// A recipe from the database. `engineId` is set when the suggestion engine placed
    /// it (used for swap detection) and nil for manual picks.
    case recipe(id: UUID, engineId: UUID?)
    /// Cold evening meal. `auto` marks slots placed by the warm-meal-day settings
    /// (kept in sync on settings changes); user-chosen Brotzeit is never touched.
    case abendbrot(auto: Bool)
    /// Eating elsewhere — slot intentionally not planned.
    case extern
    /// A free-text meal without a recipe reference.
    case custom
}

struct PlannedMeal: Identifiable, Codable {
    let id: UUID
    var name: String   // display snapshot (recipe title, "Abendbrot", "Extern", or free text)
    var kind: MealKind

    init(id: UUID = UUID(), name: String, kind: MealKind = .custom) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    // MARK: Derived state (read-only views onto `kind`)

    var recipeId: UUID? {
        if case .recipe(let id, _) = kind { return id }
        return nil
    }
    var engineRecipeId: UUID? {
        if case .recipe(_, let engineId) = kind { return engineId }
        return nil
    }
    var isAbendbrot: Bool {
        if case .abendbrot = kind { return true }
        return false
    }
    var isExtern: Bool { kind == .extern }
    var isAuto: Bool {
        if case .abendbrot(auto: true) = kind { return true }
        return false
    }

    // MARK: Codable (with legacy flag-shaped migration)

    private enum CodingKeys: String, CodingKey {
        case id, name, kind
        case recipeId, isAbendbrot, isExtern, engineRecipeId, isAuto   // legacy, decode-only
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        if let kind = try c.decodeIfPresent(MealKind.self, forKey: .kind) {
            self.kind = kind
        } else {
            // Old flag-based records. Priority mirrors the old UI derivation
            // (MealActionSheet.slotState): extern > abendbrot > recipe > custom.
            let isExtern = try c.decodeIfPresent(Bool.self, forKey: .isExtern) ?? false
            let isAbendbrot = try c.decodeIfPresent(Bool.self, forKey: .isAbendbrot) ?? false
            let isAuto = try c.decodeIfPresent(Bool.self, forKey: .isAuto) ?? false
            let recipeId = try c.decodeIfPresent(UUID.self, forKey: .recipeId)
            let engineId = try c.decodeIfPresent(UUID.self, forKey: .engineRecipeId)
            if isExtern {
                kind = .extern
            } else if isAbendbrot {
                kind = .abendbrot(auto: isAuto)
            } else if let recipeId {
                kind = .recipe(id: recipeId, engineId: engineId)
            } else {
                kind = .custom
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(kind, forKey: .kind)
    }
}

struct DaySlot: Identifiable, Codable {
    let id: UUID
    var weekday: Weekday
    var mealType: MealType
    var meal: PlannedMeal?
    var isEmpty: Bool { meal == nil }

    init(id: UUID = UUID(), weekday: Weekday, mealType: MealType = .dinner, meal: PlannedMeal? = nil) {
        self.id = id
        self.weekday = weekday
        self.mealType = mealType
        self.meal = meal
    }
}

struct WeeklyPlan: Identifiable, Codable {
    let id: UUID
    var weekKey: WeekKey
    var slots: [DaySlot]

    /// Monday of this week in the current timezone — display only, never identity.
    var weekStartDate: Date { weekKey.startDate }

    init(id: UUID = UUID(), weekKey: WeekKey = .current) {
        self.id = id
        self.weekKey = weekKey
        self.slots = Weekday.allCases.map { DaySlot(weekday: $0) }
    }

    /// Reflects the user's warm-meal-day preference: days that are *not* warm-meal days get
    /// an automatic Abendbrot, warm-meal days stay open for a recipe. Re-derivable — calling
    /// it again after the settings change keeps the layout in sync in both directions:
    /// a day turned warm clears its auto-Abendbrot, a day turned non-warm gains one. Only
    /// empty and auto-placed slots are touched; user-set meals (recipes, manual Brotzeit,
    /// Extern) are always preserved.
    mutating func applyWarmMealLayout(_ warmMealDays: Set<Weekday>) {
        for i in slots.indices {
            let isWarm = warmMealDays.contains(slots[i].weekday)
            switch slots[i].meal {
            case .none:
                if !isWarm {
                    slots[i].meal = PlannedMeal(name: "Abendbrot", kind: .abendbrot(auto: true))
                }
            case .some(let meal) where meal.isAuto:
                slots[i].meal = isWarm ? nil : PlannedMeal(name: "Abendbrot", kind: .abendbrot(auto: true))
            case .some:
                break   // user-set meal — leave untouched
            }
        }
    }

    // MARK: - Codable (with legacy weekStartDate migration)

    /// Half a week. Legacy files stored the week as a Monday-midnight instant recorded in
    /// an unknown timezone; shifting it to mid-week before deriving the `WeekKey` makes the
    /// derived week identical in every timezone on earth (±14 h offset ≪ ±84 h of slack).
    static let legacyMidWeekShift: TimeInterval = 3.5 * 86400

    private enum CodingKeys: String, CodingKey { case id, weekKey, weekStartDate, slots }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        slots = try c.decode([DaySlot].self, forKey: .slots)
        if let key = try c.decodeIfPresent(WeekKey.self, forKey: .weekKey) {
            weekKey = key
        } else {
            let legacyStart = try c.decode(Date.self, forKey: .weekStartDate)
            weekKey = WeekKey(containing: legacyStart.addingTimeInterval(Self.legacyMidWeekShift))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(weekKey, forKey: .weekKey)
        try c.encode(slots, forKey: .slots)
    }
}
