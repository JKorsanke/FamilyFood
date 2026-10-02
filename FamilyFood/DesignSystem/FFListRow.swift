import SwiftUI

/// Core component — **List row** (selection).
/// Leading icon slot, label, trailing accessory slot. Selected = accent tint + accent border +
/// filled check; unselected = hairline border + empty circle. Fixed-width slots keep rows aligned.
struct FFSelectionRow: View {
    let icon: String
    let title: String
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.s12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                    .frame(width: 24, height: 24)

                Text(title)
                    .appText(.cta)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                accessory
                    .frame(width: 24, height: 24)
            }
            .padding(AppTheme.Spacing.s16)
            .background(isSelected ? AppTheme.Colors.accentTint : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.hairline,
                            lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var accessory: some View {
        if isSelected {
            ZStack {
                Circle().fill(AppTheme.Colors.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.onAccent)
            }
        } else {
            Circle()
                .stroke(AppTheme.Colors.hairline, lineWidth: 1.5)
                .frame(width: 22, height: 22)
        }
    }
}

/// Feature row: icon tile + label, no accessory (onboarding 00 benefit list).
struct FFFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s12) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .fill(AppTheme.Colors.accentTint)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.accent)
                )
            Text(title)
                .appText(.label)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("FFListRow") {
    let _ = AppFonts.registerIfNeeded()
    VStack(spacing: AppTheme.Spacing.s12) {
        FFSelectionRow(icon: "fork.knife", title: "Mit Fleisch", isSelected: true)
        FFSelectionRow(icon: "leaf", title: "Vegetarisch")
        FFSelectionRow(icon: "leaf.fill", title: "Vegan")
        Divider().overlay(AppTheme.Colors.divider)
        FFFeatureRow(icon: "calendar", title: "Wochenplan ohne Kopfzerbrechen")
        FFFeatureRow(icon: "doc.on.doc", title: "Kein Gericht doppelt zum Kita-Essen")
    }
    .padding(AppTheme.Spacing.s24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.Colors.surface)
}
