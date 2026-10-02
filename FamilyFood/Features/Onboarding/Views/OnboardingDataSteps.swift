import SwiftUI

// The five data-step inputs (01–05). Each renders only its control; the flow container
// supplies the screen title (from OnboardingCopy.dataSteps) and the Weiter/Überspringen bar.

/// 02 — Haushalt: adults + children counts, with age qualifiers.
struct HouseholdStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
            FFStepperRow(label: OnboardingCopy.Household.adults,
                         sublabel: OnboardingCopy.Household.adultsAge,
                         value: $vm.draft.adults, range: 1...9)
            FFStepperRow(label: OnboardingCopy.Household.children,
                         sublabel: OnboardingCopy.Household.childrenAge,
                         value: $vm.childCount, range: 0...9)
            Text(OnboardingCopy.Household.namesHint)
                .appText(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// 03 — Ernährung: single-select diet style, in design order (Mit Fleisch → Vegetarisch → Vegan).
struct DietStep: View {
    @ObservedObject var vm: OnboardingViewModel
    private let orderedStyles: [DietStyle] = [.omnivore, .vegetarian, .vegan]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.s12) {
            ForEach(orderedStyles, id: \.self) { style in
                FFSelectionRow(
                    icon: style.systemImage,
                    title: style.displayName,
                    isSelected: vm.draft.dietStyle == style
                ) { vm.draft.dietStyle = style }
            }
        }
    }
}

/// 04 — Allergene: "Keine" chip + multi-select chip grid.
struct AllergensStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s16) {
            FlowLayout(spacing: AppTheme.Spacing.s8) {
                FFTogglePill(
                    title: OnboardingCopy.Allergens.none,
                    isSelected: vm.isNoneAllergenSelected,
                    showsCheck: true
                ) { vm.selectNoneAllergen() }

                ForEach(allAllergens, id: \.self) { allergen in
                    FFTogglePill(
                        title: allergen,
                        isSelected: vm.draft.allergens.contains(allergen),
                        showsCheck: true
                    ) { vm.toggleAllergen(allergen) }
                }
            }
            Text(OnboardingCopy.Allergens.microcopy)
                .appText(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 04 — Warme Mahlzeiten: multi-select day pills.
struct WarmMealDaysStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        FlowLayout(spacing: AppTheme.Spacing.s8) {
            ForEach(Weekday.allCases) { day in
                FFTogglePill(
                    title: day.shortName,
                    isSelected: vm.draft.warmMealDays.contains(day)
                ) { vm.toggleWarmDay(day) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 01 — Goals: multi-select priorities. Transient signal only — none affect persisted settings.
struct GoalsStep: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        FlowLayout(spacing: AppTheme.Spacing.s8) {
            ForEach(OnboardingGoal.allCases, id: \.self) { goal in
                FFTogglePill(
                    title: goal.displayName,
                    isSelected: vm.goals.contains(goal)
                ) { vm.toggleGoal(goal) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
