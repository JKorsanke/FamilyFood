import SwiftUI

/// 06 — Startpunkt: reassurance + recap of the selections, then continue.
struct ReadyStep: View {
    @ObservedObject var vm: OnboardingViewModel
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.s24) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s24) {
                    FFOnboardingIllustration(name: "onb-06-ready")
                        .padding(.vertical, AppTheme.Spacing.s20)   // Extra air around the hero

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.s8) {
                        Text(OnboardingCopy.Ready.headline)
                            .appText(.display)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(OnboardingCopy.Ready.subtext)
                            .appText(.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    FFCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.s8) {
                            Text(OnboardingCopy.Ready.eyebrow.uppercased())
                                .appText(.caption)
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            Text(vm.recapSummary)
                                .appText(.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            FFButton(title: OnboardingCopy.weiter, kind: .primary, action: onContinue)
        }
    }
}
