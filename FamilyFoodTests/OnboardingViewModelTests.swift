import XCTest
@testable import FamilyFood

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Navigation

    func test_advance_increments_step() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.advance()
        XCTAssertEqual(vm.stepIndex, 1)
    }

    func test_advance_clamps_at_last_step() {
        let vm = OnboardingViewModel(settings: UserSettings())
        for _ in 0..<20 { vm.advance() }
        XCTAssertEqual(vm.stepIndex, OnboardingViewModel.lastStep)
    }

    func test_back_decrements_step() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.advance(); vm.advance()
        vm.back()
        XCTAssertEqual(vm.stepIndex, 1)
    }

    func test_back_clamps_at_zero() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.back()
        XCTAssertEqual(vm.stepIndex, 0)
    }

    func test_skip_advances_step() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.skip()
        XCTAssertEqual(vm.stepIndex, 1)
    }

    func test_jumpTo_earlier_step_moves_back() {
        let vm = OnboardingViewModel(settings: UserSettings())
        for _ in 0..<4 { vm.advance() }   // at step 4
        vm.jumpTo(1)
        XCTAssertEqual(vm.stepIndex, 1)
    }

    func test_jumpTo_later_step_is_ignored() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.jumpTo(3)
        XCTAssertEqual(vm.stepIndex, 0)
    }

    // MARK: - Cook-time preset mapping

    func test_cookTimePreset_maps_from_minutes() {
        XCTAssertEqual(CookTimePreset(minutes: 30), .schnell)
        XCTAssertEqual(CookTimePreset(minutes: 60), .normal)
        XCTAssertEqual(CookTimePreset(minutes: nil), .egal)
        XCTAssertEqual(CookTimePreset(minutes: 45), .normal)  // off-grid limited value
    }

    // MARK: - Goals (screen 01)

    func test_toggleGoal_adds_then_removes() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.toggleGoal(.abwechslung)
        XCTAssertTrue(vm.goals.contains(.abwechslung))
        vm.toggleGoal(.abwechslung)
        XCTAssertFalse(vm.goals.contains(.abwechslung))
    }

    func test_schnelleZubereitung_keeps_cooktime_at_default_30() {
        // With the 30-min default, the goal no longer changes cook time:
        // it stays 30 whether selected or deselected (priority signal only).
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.toggleGoal(.schnelleZubereitung)
        XCTAssertEqual(vm.draft.maxCookTimeMinutes, 30)
        vm.toggleGoal(.schnelleZubereitung)            // deselect
        XCTAssertEqual(vm.draft.maxCookTimeMinutes, 30)
    }

    func test_other_goals_leave_cooktime_at_default() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.toggleGoal(.saisonaleGerichte)
        XCTAssertEqual(vm.draft.maxCookTimeMinutes, 30)
    }

    func test_goals_do_not_change_chosen_cooktime_through_commit() {
        // Goals are a transient signal: toggling one must NOT overwrite the user's cook-time
        // choice (here a non-default 60) when settings are committed. Locks the new invariant
        // that .schnelleZubereitung no longer derives cook time.
        var settings = UserSettings()
        settings.maxCookTimeMinutes = 60
        let vm = OnboardingViewModel(settings: settings)
        vm.toggleGoal(.schnelleZubereitung)
        XCTAssertEqual(vm.committedSettings().maxCookTimeMinutes, 60)
    }

    // MARK: - Allergens

    func test_selectNoneAllergen_clears_allergens() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.toggleAllergen("Gluten")
        vm.selectNoneAllergen()
        XCTAssertTrue(vm.draft.allergens.isEmpty)
        XCTAssertTrue(vm.isNoneAllergenSelected)
    }

    func test_toggleAllergen_adds_then_removes() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.toggleAllergen("Milch")
        XCTAssertEqual(vm.draft.allergens, ["Milch"])
        vm.toggleAllergen("Milch")
        XCTAssertTrue(vm.draft.allergens.isEmpty)
    }

    func test_selecting_allergen_deselects_none() {
        let vm = OnboardingViewModel(settings: UserSettings())
        XCTAssertTrue(vm.isNoneAllergenSelected)   // empty by default
        vm.toggleAllergen("Ei")
        XCTAssertFalse(vm.isNoneAllergenSelected)
    }

    // MARK: - Warm meal days

    func test_toggleWarmDay_adds_and_removes() {
        let vm = OnboardingViewModel(settings: UserSettings())
        XCTAssertTrue(vm.draft.warmMealDays.contains(.saturday) == false)
        vm.toggleWarmDay(.saturday)
        XCTAssertTrue(vm.draft.warmMealDays.contains(.saturday))
        vm.toggleWarmDay(.monday)
        XCTAssertFalse(vm.draft.warmMealDays.contains(.monday))
    }

    // MARK: - Warm-day range formatting

    func test_formatWarmDays_collapses_contiguous_run() {
        let days: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        XCTAssertEqual(OnboardingViewModel.formatWarmDays(days), "Mo–Fr")
    }

    func test_formatWarmDays_separates_gaps_and_runs() {
        XCTAssertEqual(OnboardingViewModel.formatWarmDays([.monday, .wednesday, .friday]), "Mo, Mi, Fr")
        XCTAssertEqual(OnboardingViewModel.formatWarmDays([.monday, .tuesday, .thursday, .friday]), "Mo–Di, Do–Fr")
        XCTAssertEqual(OnboardingViewModel.formatWarmDays([.wednesday]), "Mi")
        XCTAssertEqual(OnboardingViewModel.formatWarmDays([]), "")
    }

    // MARK: - Warm-day selection summary

    func test_warmMealsSummary_singular_and_plural() {
        XCTAssertEqual(OnboardingCopy.WarmMeals.selectedSummary(1), "1 Tag ausgewählt · jederzeit änderbar")
        XCTAssertEqual(OnboardingCopy.WarmMeals.selectedSummary(5), "5 Tage ausgewählt · jederzeit änderbar")
    }

    // MARK: - Recap summary

    func test_recapSummary_formats_default_draft() {
        let vm = OnboardingViewModel(settings: UserSettings())   // adults 1, 1 Kind default, vegetarisch, Mo, ≤30 Min
        XCTAssertEqual(vm.recapSummary, "1 Erwachsener · 1 Kind · Vegetarisch · Mo warm · ≤ 30 Min")
    }

    func test_recapSummary_handles_singular_and_no_limit() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.draft.adults = 1
        vm.childCount = 0
        vm.draft.dietStyle = .vegan
        vm.draft.warmMealDays = []
        vm.draft.maxCookTimeMinutes = nil
        XCTAssertEqual(vm.recapSummary, "1 Erwachsener · Vegan · Zeit egal")
    }

    // MARK: - Onboarding defaults & commit

    func test_fresh_settings_use_onboarding_defaults() {
        let vm = OnboardingViewModel(settings: UserSettings())
        XCTAssertEqual(vm.childCount, 1)                       // spec default 1 Kind
        XCTAssertEqual(vm.draft.maxCookTimeMinutes, 30)        // spec default ≤30 Min
    }

    func test_initial_childCount_reflects_existing_children() {
        var settings = UserSettings()
        settings.children = [Child(name: "Lena"), Child(name: "Max")]
        let vm = OnboardingViewModel(settings: settings)
        XCTAssertEqual(vm.childCount, 2)
    }

    func test_committedSettings_after_skip_through_yields_defaults() {
        let vm = OnboardingViewModel(settings: UserSettings())
        let s = vm.committedSettings()
        XCTAssertEqual(s.adults, 1)
        XCTAssertEqual(s.children.count, 1)
        XCTAssertEqual(s.children.first?.name, "Kind 1")
        XCTAssertEqual(s.dietStyle, .vegetarian)
        XCTAssertEqual(s.allergens, [])
        XCTAssertEqual(s.warmMealDays, [.monday])
        XCTAssertEqual(s.maxCookTimeMinutes, 30)
    }

    func test_committedSettings_materializes_added_children_as_placeholders() {
        let vm = OnboardingViewModel(settings: UserSettings())
        vm.childCount = 3
        let s = vm.committedSettings()
        XCTAssertEqual(s.children.map(\.name), ["Kind 1", "Kind 2", "Kind 3"])
    }

    func test_committedSettings_preserves_existing_child_names() {
        var settings = UserSettings()
        settings.children = [Child(name: "Lena")]
        let vm = OnboardingViewModel(settings: settings)
        vm.childCount = 2                                   // user bumped count by one
        let s = vm.committedSettings()
        XCTAssertEqual(s.children.map(\.name), ["Lena", "Kind 2"])
    }
}
