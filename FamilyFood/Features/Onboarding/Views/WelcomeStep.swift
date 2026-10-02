import SwiftUI

/// 00 — Willkommen: value proposition. No progress chrome; carries its own actions.
struct WelcomeStep: View {
    var onStart: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.s16) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.s24) {
                    FFBrandHeader()

                    FFOnboardingIllustration(name: "onb-00-welcome", maxHeight: 140)
                        .padding(.vertical, AppTheme.Spacing.s10)   // +10pt breathing room top & below

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.s12) {
                        Text(OnboardingCopy.Welcome.headline)
                            .appText(.display)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(OnboardingCopy.Welcome.subhead)
                            .appText(.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: AppTheme.Spacing.s16) {
                        ForEach(OnboardingCopy.Welcome.benefits, id: \.label) { benefit in
                            FFFeatureRow(icon: benefit.icon, title: benefit.label)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: AppTheme.Spacing.s8) {
                FFButton(title: OnboardingCopy.Welcome.primary, kind: .primary, action: onStart)
                FFButton(title: OnboardingCopy.ueberspringen, kind: .tertiary, action: onSkip)
            }
        }
    }
}
