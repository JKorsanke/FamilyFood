import XCTest
import SwiftData
@testable import FamilyFood

@MainActor
final class MealPlanViewModelTests: XCTestCase {

    var vm: MealPlanViewModel!

    override func setUp() {
        super.setUp()
        // Inject a throwaway store so tests never touch (or persist to) Application Support.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        vm = MealPlanViewModel(store: PlanStore(directory: tmp))
    }

    // MARK: - setExtern

    func test_setExtern_on_empty_slot_creates_extern_meal() {
        vm.setExtern(for: .monday)
        let slot = vm.slot(for: .monday)
        XCTAssertEqual(slot?.meal?.isExtern, true)
        XCTAssertEqual(slot?.meal?.isAbendbrot, false)
        XCTAssertNil(slot?.meal?.recipeId)
    }

    func test_setExtern_on_filled_slot_clears_recipe_and_brotzeit() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Test", kind: .recipe(id: UUID(), engineId: nil))
        vm.setExtern(for: .monday)
        let slot = vm.slot(for: .monday)
        XCTAssertEqual(slot?.meal?.isExtern, true)
        XCTAssertEqual(slot?.meal?.isAbendbrot, false)
        XCTAssertNil(slot?.meal?.recipeId)
    }

    // MARK: - setBrotzeit

    func test_setBrotzeit_on_empty_slot_creates_brotzeit_meal() {
        vm.setBrotzeit(for: .tuesday)
        let slot = vm.slot(for: .tuesday)
        XCTAssertEqual(slot?.meal?.isAbendbrot, true)
        XCTAssertEqual(slot?.meal?.isExtern, false)
        XCTAssertNil(slot?.meal?.recipeId)
    }

    func test_setBrotzeit_on_extern_slot_clears_extern() {
        vm.setExtern(for: .tuesday)
        vm.setBrotzeit(for: .tuesday)
        let slot = vm.slot(for: .tuesday)
        XCTAssertEqual(slot?.meal?.isAbendbrot, true)
        XCTAssertEqual(slot?.meal?.isExtern, false)
    }

    // MARK: - isCurrentWeek

    func test_isCurrentWeek_true_on_fresh_viewmodel() {
        XCTAssertTrue(vm.isCurrentWeek)
    }

    func test_isCurrentWeek_false_after_next_week() {
        vm.goToNextWeek()
        XCTAssertFalse(vm.isCurrentWeek)
    }

    // MARK: - goToCurrentWeek

    func test_goToCurrentWeek_restores_current_week_plan() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        vm.goToNextWeek()
        XCTAssertNil(vm.slot(for: .monday)?.meal)
        vm.goToCurrentWeek()
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Pasta")
        XCTAssertTrue(vm.isCurrentWeek)
    }

    func test_goToCurrentWeek_is_noop_when_already_on_current_week() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        vm.goToCurrentWeek()
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Pasta")
    }

    // MARK: - moveMeal

    func test_moveMeal_to_empty_clears_source() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        vm.moveMeal(from: .monday, to: .tuesday)
        XCTAssertNil(vm.slot(for: .monday)?.meal)
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.name, "Pasta")
    }

    func test_moveMeal_between_filled_slots_swaps() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        vm.plan.slots[1].meal = PlannedMeal(name: "Suppe")
        vm.moveMeal(from: .monday, to: .tuesday)
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Suppe")
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.name, "Pasta")
    }

    func test_moveMeal_from_empty_to_filled_swaps() {
        vm.plan.slots[1].meal = PlannedMeal(name: "Suppe")
        vm.moveMeal(from: .monday, to: .tuesday)
        XCTAssertNil(vm.slot(for: .tuesday)?.meal)
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Suppe")
    }

    // MARK: - plan(for:)

    func test_plan_for_unknown_date_returns_empty_plan_at_that_date() {
        let target = WeekKey.current.advanced(by: 3)
        let p = vm.plan(for: target)
        XCTAssertEqual(p.weekKey, target)
        XCTAssertTrue(p.slots.allSatisfy { $0.meal == nil })
    }

    func test_plan_for_saved_date_returns_saved_plan() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        let current = vm.plan.weekKey
        vm.goToNextWeek()                 // saves current
        let p = vm.plan(for: current)
        XCTAssertEqual(p.slots[0].meal?.name, "Pasta")
    }

    // MARK: - setCenteredWeek

    func test_setCenteredWeek_swaps_to_target_week() {
        let target = WeekKey.current.advanced(by: 2)
        vm.setCenteredWeek(target)
        XCTAssertEqual(vm.plan.weekKey, target)
    }

    func test_setCenteredWeek_preserves_edits_when_returning() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        let current = vm.plan.weekKey
        let target = current.advanced(by: 1)
        vm.setCenteredWeek(target)
        XCTAssertNil(vm.slot(for: .monday)?.meal)
        vm.setCenteredWeek(current)
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Pasta")
    }

    func test_setCenteredWeek_is_noop_when_already_on_target() {
        vm.plan.slots[0].meal = PlannedMeal(name: "Pasta")
        vm.setCenteredWeek(vm.plan.weekKey)
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Pasta")
    }

    // MARK: - warm-meal-day layout

    func test_applyWarmMealLayout_marks_non_warm_days_as_abendbrot() {
        var settings = UserSettings()
        settings.warmMealDays = [.monday, .wednesday]   // only Mon + Wed are warm
        vm.applyWarmMealLayout(to: .current, settings: settings)

        XCTAssertNil(vm.slot(for: .monday)?.meal)        // warm → stays open
        XCTAssertNil(vm.slot(for: .wednesday)?.meal)
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.isAbendbrot, true)
        XCTAssertEqual(vm.slot(for: .thursday)?.meal?.isAbendbrot, true)
        XCTAssertEqual(vm.slot(for: .friday)?.meal?.isAbendbrot, true)
    }

    func test_refreshWarmMealLayout_updates_current_week_when_settings_change() {
        var settings = UserSettings()
        settings.warmMealDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        vm.applyWarmMealLayout(to: .current, settings: settings)
        XCTAssertNil(vm.slot(for: .tuesday)?.meal)       // warm initially

        // User removes Tuesday from warm days — the current week must now reflect it.
        settings.warmMealDays = [.monday]
        vm.refreshWarmMealLayout(settings: settings)
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.isAbendbrot, true)
    }

    func test_refreshWarmMealLayout_is_reversible() {
        var settings = UserSettings()
        settings.warmMealDays = [.monday]                // Tuesday non-warm → Abendbrot
        vm.applyWarmMealLayout(to: .current, settings: settings)
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.isAbendbrot, true)

        settings.warmMealDays = [.monday, .tuesday]      // Tuesday warm again → cleared
        vm.refreshWarmMealLayout(settings: settings)
        XCTAssertNil(vm.slot(for: .tuesday)?.meal)
    }

    func test_refreshWarmMealLayout_ignores_past_weeks() {
        let lastWeek = WeekKey.current.advanced(by: -1)
        // Materialize a past week, then change settings.
        vm.setCenteredWeek(lastWeek)
        vm.setCenteredWeek(.current)               // saves lastWeek into savedPlans
        var settings = UserSettings()
        settings.warmMealDays = [.monday]
        vm.refreshWarmMealLayout(settings: settings)

        let p = vm.plan(for: lastWeek)
        XCTAssertTrue(p.slots.allSatisfy { $0.meal == nil })   // past week untouched
    }

    func test_applyWarmMealLayout_preserves_user_meals() {
        var settings = UserSettings()
        settings.warmMealDays = [.monday]
        vm.plan.slots[1].meal = PlannedMeal(name: "Pasta")     // Tuesday: user recipe
        vm.applyWarmMealLayout(to: .current, settings: settings)
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.name, "Pasta")   // not overwritten

        // User's manual Abendbrot on a warm day must survive a refresh too.
        vm.setBrotzeit(for: .monday)
        settings.warmMealDays = []
        vm.refreshWarmMealLayout(settings: settings)
        XCTAssertEqual(vm.slot(for: .monday)?.meal?.name, "Abendbrot")
        XCTAssertEqual(vm.slot(for: .tuesday)?.meal?.name, "Pasta")
    }

    func test_applyWarmMealLayout_applies_to_future_saved_week() {
        let future = WeekKey.current.advanced(by: 2)
        var settings = UserSettings()
        settings.warmMealDays = [.monday]
        vm.applyWarmMealLayout(to: future, settings: settings)

        let p = vm.plan(for: future)
        XCTAssertNil(p.slots.first { $0.weekday == .monday }?.meal)
        XCTAssertEqual(p.slots.first { $0.weekday == .tuesday }?.meal?.isAbendbrot, true)
    }

    // MARK: - persistence

    func test_current_week_edits_persist_across_instances() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PlanStore(directory: tmp)

        let vm1 = MealPlanViewModel(store: store)
        vm1.plan.slots[0].meal = PlannedMeal(name: "Lasagne")

        let vm2 = MealPlanViewModel(store: store)
        XCTAssertEqual(vm2.slot(for: .monday)?.meal?.name, "Lasagne")
    }

    func test_other_week_edits_persist_across_instances() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PlanStore(directory: tmp)
        let nextWeek = WeekKey.current.advanced(by: 1)

        let vm1 = MealPlanViewModel(store: store)
        vm1.setCenteredWeek(nextWeek)
        vm1.plan.slots[0].meal = PlannedMeal(name: "Curry")
        vm1.setCenteredWeek(.current)        // saves nextWeek into savedPlans

        let vm2 = MealPlanViewModel(store: store)
        XCTAssertEqual(vm2.plan(for: nextWeek).slots.first?.meal?.name, "Curry")
        XCTAssertTrue(vm2.isCurrentWeek)           // reopens on the current week
    }

    // MARK: - week header formatting

    func test_weekDateRange_within_one_month_collapses_to_a_single_month() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 20)   // Mon 11 – Sun 17 May 2026
        XCTAssertEqual(MealPlanViewModel.weekDateRange(for: key), "11.–17. Mai")
    }

    func test_weekDateRange_spanning_two_months_shows_both_months() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 18)   // Mon 27 Apr – Sun 3 May 2026
        XCTAssertEqual(MealPlanViewModel.weekDateRange(for: key), "27. April – 3. Mai")
    }

    func test_weekDateRange_spanning_year_boundary_shows_both_months() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 1)    // Mon 29 Dec 2025 – Sun 4 Jan 2026
        XCTAssertEqual(MealPlanViewModel.weekDateRange(for: key), "29. Dezember – 4. Januar")
    }

    func test_weekEyebrow_on_current_week_has_diese_woche_prefix() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 20)
        XCTAssertEqual(MealPlanViewModel.weekEyebrow(for: key, isCurrentWeek: true), "DIESE WOCHE · KW 20")
    }

    func test_weekEyebrow_off_current_week_is_kw_only() {
        let key = WeekKey(yearForWeekOfYear: 2026, weekOfYear: 20)
        XCTAssertEqual(MealPlanViewModel.weekEyebrow(for: key, isCurrentWeek: false), "KW 20")
    }

    // MARK: - weekKeys

    func test_weekKeys_span_one_year_each_side_of_today() {
        let keys = vm.weekKeys
        XCTAssertEqual(keys.count, 105)               // 52 past + today + 52 future
        XCTAssertTrue(keys.contains(.current))
        // Strictly increasing
        for i in 1..<keys.count {
            XCTAssertLessThan(keys[i-1], keys[i])
        }
        XCTAssertEqual(keys.first, WeekKey.current.advanced(by: -52))
    }

}
