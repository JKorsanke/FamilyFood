import Foundation

/// Cook-time presets shown on screen 05 (Kochzeit). Each maps to a concrete
/// `maxCookTimeMinutes` value; `egal` means no limit (`nil`).
enum CookTimePreset: CaseIterable {
    case schnell, normal, egal

    var minutes: Int? {
        switch self {
        case .schnell: return 30
        case .normal:  return 60
        case .egal:    return nil
        }
    }

    /// Which preset a stored minutes value belongs to. Off-grid limited values (e.g. 45, set in
    /// Settings) fall back to `.normal`; only `nil` is `.egal`.
    init(minutes: Int?) {
        switch minutes {
        case .some(30): self = .schnell
        case .none:     self = .egal
        default:        self = .normal
        }
    }
}

/// Drives the first-run onboarding flow: step navigation plus a *draft* `UserSettings`
/// that's committed only when the user finishes. Free of `@AppStorage` so it stays unit-testable;
/// the container view persists `committedSettings()`.
@MainActor
final class OnboardingViewModel: ObservableObject {
    /// Highest step index: 0 Welcome … 5 Kochzeit, 6 Startpunkt, 7 Womit starten.
    static let lastStep = 7

    @Published var stepIndex: Int = 0
    @Published var draft: UserSettings
    /// Captured as a count on screen 01 (names are added later in Settings).
    @Published var childCount: Int
    /// Screen 01 priorities. Transient — not written to `UserSettings` (see `committedSettings`).
    @Published var goals: Set<OnboardingGoal> = []

    init(settings: UserSettings) {
        var draft = settings
        // Defensive default mirroring the model's `maxCookTimeMinutes` (≤30 Min): if settings ever
        // arrive without a limit (egal/nil), onboarding still starts from the ≤30 default rather
        // than "Zeit egal". Kinder defaults to 1 (below).
        if draft.maxCookTimeMinutes == nil { draft.maxCookTimeMinutes = CookTimePreset.schnell.minutes }
        self.draft = draft
        self.childCount = settings.children.isEmpty ? 1 : settings.children.count
    }

    // MARK: - Navigation

    func advance() { stepIndex = min(stepIndex + 1, Self.lastStep) }
    func back()    { stepIndex = max(stepIndex - 1, 0) }
    /// Skipping keeps the step's (default) value — the draft already carries valid defaults.
    func skip()    { advance() }
    /// Jump to a completed/earlier step (backs the tappable progress segments). Later steps ignored.
    func jumpTo(_ index: Int) { if (0...stepIndex).contains(index) { stepIndex = index } }

    // MARK: - Goals (screen 01)

    /// Multi-select priorities (screen 01). Purely a transient priority signal — no goal is
    /// persisted and none changes settings. (Cook time now defaults to ≤30 Min for everyone, so
    /// `.schnelleZubereitung` no longer derives it.)
    func toggleGoal(_ goal: OnboardingGoal) {
        if goals.contains(goal) { goals.remove(goal) } else { goals.insert(goal) }
    }

    // MARK: - Allergene

    var isNoneAllergenSelected: Bool { draft.allergens.isEmpty }
    func selectNoneAllergen() { draft.allergens = [] }
    func toggleAllergen(_ allergen: String) {
        if let i = draft.allergens.firstIndex(of: allergen) {
            draft.allergens.remove(at: i)
        } else {
            draft.allergens.append(allergen)
        }
    }

    // MARK: - Warme Mahlzeiten

    func toggleWarmDay(_ day: Weekday) {
        if draft.warmMealDays.contains(day) {
            draft.warmMealDays.remove(day)
        } else {
            draft.warmMealDays.insert(day)
        }
    }

    /// Collapse a set of days into a compact label, e.g. `{Mo…Fr}` → "Mo–Fr",
    /// `{Mo, Mi, Fr}` → "Mo, Mi, Fr", `{Mo, Di, Do, Fr}` → "Mo–Di, Do–Fr".
    static func formatWarmDays(_ days: Set<Weekday>) -> String {
        let sorted = days.sorted { $0.rawValue < $1.rawValue }
        guard !sorted.isEmpty else { return "" }

        var runs: [[Weekday]] = []
        for day in sorted {
            if let last = runs.last?.last, day.rawValue == last.rawValue + 1 {
                runs[runs.count - 1].append(day)
            } else {
                runs.append([day])
            }
        }
        return runs.map { run in
            run.count >= 2 ? "\(run.first!.shortName)–\(run.last!.shortName)" : run.first!.shortName
        }.joined(separator: ", ")
    }

    // MARK: - Startpunkt recap (06)

    var recapSummary: String {
        var parts: [String] = []
        parts.append(draft.adults == 1 ? "1 Erwachsener" : "\(draft.adults) Erwachsene")
        if childCount == 1 {
            parts.append("1 Kind")
        } else if childCount > 1 {
            parts.append("\(childCount) Kinder")
        }
        parts.append(draft.dietStyle.displayName)
        let warm = Self.formatWarmDays(draft.warmMealDays)
        if !warm.isEmpty { parts.append("\(warm) warm") }
        parts.append(draft.maxCookTimeMinutes.map { "≤ \($0) Min" } ?? "Zeit egal")
        return parts.joined(separator: " · ")
    }

    // MARK: - Commit

    /// The settings to persist on finish. Materializes `childCount` into `Child` entries,
    /// preserving any existing names and naming new ones "Kind N" (renamed later in Settings).
    func committedSettings() -> UserSettings {
        var settings = draft
        let existing = draft.children
        if childCount <= existing.count {
            settings.children = Array(existing.prefix(childCount))
        } else {
            var kids = existing
            for i in existing.count ..< childCount { kids.append(Child(name: "Kind \(i + 1)")) }
            settings.children = kids
        }
        return settings
    }
}
