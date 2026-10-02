import SwiftUI

/// The first-run onboarding container. Owns the step VM, draws the shared top progress
/// chrome and the Weiter/Überspringen bar for data steps, and persists the draft on finish.
/// `onFinish` (from `RootView`) flips `hasCompletedOnboarding` and selects the landing tab.
struct OnboardingFlowView: View {
    @StateObject private var vm: OnboardingViewModel
    @AppStorage("userSettings") private var settings = UserSettings()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onFinish: (AppTab) -> Void

    private let dataStepCount = OnboardingCopy.dataSteps.count   // 5

    init(initialSettings: UserSettings, onFinish: @escaping (AppTab) -> Void) {
        _vm = StateObject(wrappedValue: OnboardingViewModel(settings: initialSettings))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            if (1...(dataStepCount + 1)).contains(vm.stepIndex) {
                FFProgressHeader(step: min(vm.stepIndex, dataStepCount),
                                 total: dataStepCount,
                                 onBack: { vm.back() },
                                 onSelect: { vm.jumpTo($0) })
                    .padding(.horizontal, AppTheme.Spacing.s24)
                    .padding(.top, AppTheme.Spacing.s8)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, AppTheme.Spacing.s24)
                .padding(.top, AppTheme.Spacing.s24)

            if (1...dataStepCount).contains(vm.stepIndex) {
                VStack(spacing: AppTheme.Spacing.s8) {
                    FFButton(title: OnboardingCopy.weiter, kind: .primary) { vm.advance() }
                    FFButton(title: OnboardingCopy.ueberspringen, kind: .tertiary) { vm.skip() }
                }
                .padding(.horizontal, AppTheme.Spacing.s24)
                .padding(.bottom, AppTheme.Spacing.s8)
            }
        }
        .background(AppTheme.Colors.surface.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: vm.stepIndex)
    }

    @ViewBuilder private var content: some View {
        switch vm.stepIndex {
        case 0:
            WelcomeStep(onStart: { vm.advance() }, onSkip: { finish(.mealPlan) })
        case 1...5:
            dataStepScreen
        case 6:
            ReadyStep(vm: vm, onContinue: { vm.advance() })
        default:
            NextActionStep(onKita: { finish(.kitaImport) },
                           onRecipe: { finish(.recipes) },
                           onLater: { finish(.mealPlan) })
        }
    }

    private var dataStepScreen: some View {
        let page = OnboardingCopy.dataSteps[vm.stepIndex - 1]
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s24) {
                FFOnboardingIllustration(name: page.illustration)
                    .padding(.vertical, AppTheme.Spacing.s40)   // Extra air around the hero
                FFScreenTitle(title: page.title, subtitle: page.subtitle)
                dataInput
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var dataInput: some View {
        switch vm.stepIndex {
        case 1: GoalsStep(vm: vm)
        case 2: HouseholdStep(vm: vm)
        case 3: DietStep(vm: vm)
        case 4: AllergensStep(vm: vm)
        default: WarmMealDaysStep(vm: vm)
        }
    }

    private func finish(_ tab: AppTab) {
        settings = vm.committedSettings()
        onFinish(tab)
    }
}
