import SwiftUI
import SwiftData

@MainActor
final class MealPlanViewModel: ObservableObject {
    @Published var plan = WeeklyPlan() { didSet { persist() } }
    private var savedPlans: [WeekKey: WeeklyPlan] = [:] { didSet { persist() } }
    private let store: PlanStore
    private var isLoaded = false   // suppress persistence while loading

    init(store: PlanStore = PlanStore()) {
        self.store = store
        load()
    }

    // MARK: - Persistence

    private func load() {
        let all = store.loadWeeklyPlans()
        var byKey: [WeekKey: WeeklyPlan] = [:]
        for stored in all {
            if byKey[stored.weekKey] != nil {
                Log.persistence.error("two stored plans for \(stored.weekKey) — keeping the later record")
            }
            byKey[stored.weekKey] = stored   // later record wins; persist() writes the active plan last
        }
        if let current = byKey.removeValue(forKey: .current) {
            plan = current
        }
        savedPlans = byKey
        isLoaded = true
    }

    /// Persists the current week plus every other materialized week. `plan` is never in
    /// `savedPlans` (invariant), so the union covers each week exactly once.
    private func persist() {
        guard isLoaded else { return }
        store.saveWeeklyPlans(Array(savedPlans.values) + [plan])
    }

    // MARK: - Week navigation

    /// Headline date for the week header, e.g. "11.–17. Mai".
    var weekDateRange: String { Self.weekDateRange(for: plan.weekKey) }

    /// Eyebrow above the headline, e.g. "DIESE WOCHE · KW 20" (current week) or "KW 20".
    var weekEyebrow: String { Self.weekEyebrow(for: plan.weekKey, isCurrentWeek: isCurrentWeek) }

    let weekKeys: [WeekKey] = {
        let base = WeekKey.current
        return (-52...52).map { base.advanced(by: $0) }
    }()

    func goToPreviousWeek() { shiftWeek(by: -1) }
    func goToNextWeek()     { shiftWeek(by:  1) }

    var isCurrentWeek: Bool {
        plan.weekKey == .current
    }

    func goToCurrentWeek() {
        setCenteredWeek(.current)
    }

    func plan(for week: WeekKey) -> WeeklyPlan {
        if week == plan.weekKey { return plan }
        return savedPlans[week] ?? WeeklyPlan(weekKey: week)
    }

    func setCenteredWeek(_ week: WeekKey) {
        guard week != plan.weekKey else { return }
        savedPlans[plan.weekKey] = plan
        plan = savedPlans[week] ?? WeeklyPlan(weekKey: week)
    }

    /// Derives the warm-meal-day layout for a single week from the current settings.
    /// Applied when a week is opened. Never touches past weeks, so their layout stays as
    /// it was. Safe to call repeatedly — it only manages empty / auto slots.
    func applyWarmMealLayout(to week: WeekKey, settings: UserSettings) {
        guard week >= .current else { return }
        if week == plan.weekKey {
            plan.applyWarmMealLayout(settings.warmMealDays)
        } else {
            var weekPlan = savedPlans[week] ?? WeeklyPlan(weekKey: week)
            weekPlan.applyWarmMealLayout(settings.warmMealDays)
            savedPlans[week] = weekPlan
        }
    }

    /// Re-derives the warm-meal-day layout for the current week and every materialized
    /// upcoming week after the warm-meal settings change. Past weeks are left untouched,
    /// so a settings change is reflected on the current and future weeks but not past ones.
    func refreshWarmMealLayout(settings: UserSettings) {
        if plan.weekKey >= .current {
            plan.applyWarmMealLayout(settings.warmMealDays)
        }
        for week in savedPlans.keys where week >= .current {
            savedPlans[week]?.applyWarmMealLayout(settings.warmMealDays)
        }
    }

    private func shiftWeek(by value: Int) {
        setCenteredWeek(plan.weekKey.advanced(by: value))
    }

    // MARK: - Slot editing

    func clearMeal(for weekday: Weekday) {
        guard let i = index(of: weekday) else { return }
        plan.slots[i].meal = nil
    }

    func toggleMealType(for weekday: Weekday) {
        guard weekday.isWeekend, let i = index(of: weekday) else { return }
        plan.slots[i].mealType = plan.slots[i].mealType == .lunch ? .dinner : .lunch
    }

    func setExtern(for weekday: Weekday) {
        guard let i = index(of: weekday) else { return }
        plan.slots[i].meal = PlannedMeal(name: "Extern", kind: .extern)
    }

    func setBrotzeit(for weekday: Weekday) {
        guard let i = index(of: weekday) else { return }
        plan.slots[i].meal = PlannedMeal(name: "Abendbrot", kind: .abendbrot(auto: false))
    }

    func moveMeal(from source: Weekday, to target: Weekday) {
        guard let si = index(of: source), let ti = index(of: target) else { return }
        let sourceMeal = plan.slots[si].meal
        plan.slots[si].meal = plan.slots[ti].meal
        plan.slots[ti].meal = sourceMeal
    }

    // MARK: - Recipe assignment with swap detection

    func assignRecipe(_ recipe: RecipeModel, to weekday: Weekday, modelContext: ModelContext) {
        guard let i = index(of: weekday) else { return }
        let slot = plan.slots[i]

        if let originalId = slot.meal?.engineRecipeId,
           originalId != recipe.id {
            let descriptor = FetchDescriptor<RecipeModel>(
                predicate: #Predicate { $0.id == originalId }
            )
            do {
                if let original = try modelContext.fetch(descriptor).first {
                    original.swapCount += 1
                    try modelContext.save()
                }
            } catch {
                Log.persistence.error("swap count not persisted: \(error.localizedDescription)")
            }
        }

        plan.slots[i].meal = PlannedMeal(
            name: recipe.title,
            kind: .recipe(id: recipe.id, engineId: nil)
        )
    }

    // MARK: - Suggestion engine

    func generatePlan(
        recipes: [RecipeModel],
        kitaPlans: [KitaMealPlan],
        settings: UserSettings,
        modelContext: ModelContext
    ) {
        let engine = SuggestionEngine(modelContext: modelContext)
        plan = engine.generateWeeklyPlan(
            recipes: recipes,
            kitaPlans: kitaPlans,
            settings: settings,
            week: plan.weekKey
        )
    }

    // MARK: - Helpers

    private func index(of weekday: Weekday) -> Int? {
        plan.slots.firstIndex { $0.weekday == weekday }
    }

    func slot(for weekday: Weekday) -> DaySlot? {
        plan.slots.first { $0.weekday == weekday }
    }
}

// MARK: - Week header formatting

extension MealPlanViewModel {

    /// German date range for the week header. Collapses to a single month when the week stays
    /// within one ("11.–17. Mai"); otherwise shows both months ("27. April – 3. Mai").
    static func weekDateRange(for weekKey: WeekKey) -> String {
        let cal = Calendar.mondayFirst
        let start = weekKey.startDate
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let startDay = cal.component(.day, from: start)
        let startMonth = cal.component(.month, from: start)
        let endDay = cal.component(.day, from: end)
        let endMonth = cal.component(.month, from: end)
        let startMonthName = germanMonthSymbols[startMonth - 1]
        if startMonth == endMonth {
            return "\(startDay).–\(endDay). \(startMonthName)"
        }
        let endMonthName = germanMonthSymbols[endMonth - 1]
        return "\(startDay). \(startMonthName) – \(endDay). \(endMonthName)"
    }

    /// Eyebrow line: "DIESE WOCHE · KW 20" on the current week, "KW 20" otherwise. The current-week
    /// prefix is suppressed off-week so a non-current week never mislabels itself as "this week".
    static func weekEyebrow(for weekKey: WeekKey, isCurrentWeek: Bool) -> String {
        let kw = "KW \(weekKey.weekOfYear)"
        return isCurrentWeek ? "DIESE WOCHE · \(kw)" : kw
    }

    /// Full German month names (de_DE), indexed `month - 1`. Cached — building a `DateFormatter`
    /// per header render is wasteful.
    private static let germanMonthSymbols: [String] = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        return fmt.monthSymbols
    }()
}
