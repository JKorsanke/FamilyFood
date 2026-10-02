import SwiftUI

/// 07 — Womit starten?: next best action. Each choice finishes onboarding and lands on a tab.
struct NextActionStep: View {
    var onKita: () -> Void
    var onRecipe: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s24) {
            FFScreenTitle(title: OnboardingCopy.NextAction.title,
                          subtitle: OnboardingCopy.NextAction.subtitle)

            VStack(spacing: AppTheme.Spacing.s12) {
                FFActionCard(
                    icon: OnboardingCopy.NextAction.kitaIcon,
                    title: OnboardingCopy.NextAction.kitaTitle,
                    subtitle: OnboardingCopy.NextAction.kitaSubtitle,
                    action: onKita
                )
                FFActionCard(
                    icon: OnboardingCopy.NextAction.recipeIcon,
                    title: OnboardingCopy.NextAction.recipeTitle,
                    subtitle: OnboardingCopy.NextAction.recipeSubtitle,
                    action: onRecipe
                )
            }

            Spacer(minLength: AppTheme.Spacing.s16)

            // Centered to match the tertiary action on every other onboarding screen
            // (this screen's root VStack is .leading, which would otherwise pin it left).
            FFButton(title: OnboardingCopy.NextAction.later, kind: .tertiary, action: onLater)
                .frame(maxWidth: .infinity)
        }
    }
}
