import SwiftUI

/// Core component — **Button**.
/// Variants: `primary` (filled accent), `secondary` (accent tint), `tertiary` (text only).
/// States: default, pressed, disabled. Full-width by default, ≥ 44 pt tall.
struct FFButton: View {
    enum Kind { case primary, secondary, tertiary }

    let title: String
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var action: () -> Void = {}

    var body: some View {
        Button(title, action: action)
            .buttonStyle(FFButtonStyle(kind: kind, fullWidth: fullWidth))
    }
}

struct FFButtonStyle: ButtonStyle {
    var kind: FFButton.Kind = .primary
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        FFButtonSurface(kind: kind, fullWidth: fullWidth, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

private struct FFButtonSurface<Label: View>: View {
    let kind: FFButton.Kind
    let fullWidth: Bool
    let isPressed: Bool
    @ViewBuilder var label: () -> Label
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label()
            .appText(kind == .tertiary ? .label : .cta)
            .foregroundStyle(foreground)
            .frame(maxWidth: (fullWidth && kind != .tertiary) ? .infinity : nil)
            .frame(minHeight: kind == .tertiary ? 44 : 54)
            .padding(.horizontal, kind == .tertiary ? AppTheme.Spacing.s8 : AppTheme.Spacing.s20)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.9 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary:   return isEnabled ? AppTheme.Colors.onAccent     : AppTheme.Colors.textFaded
        case .secondary: return isEnabled ? AppTheme.Colors.accent       : AppTheme.Colors.textFaded
        case .tertiary:  return isEnabled ? AppTheme.Colors.textSecondary : AppTheme.Colors.textFaded
        }
    }

    @ViewBuilder private var backgroundFill: some View {
        switch kind {
        case .primary:   isEnabled ? AppTheme.Colors.accent     : AppTheme.Colors.track
        case .secondary: isEnabled ? AppTheme.Colors.accentTint : AppTheme.Colors.track
        case .tertiary:  Color.clear
        }
    }
}

#Preview("FFButton") {
    let _ = AppFonts.registerIfNeeded()
    VStack(spacing: AppTheme.Spacing.s16) {
        FFButton(title: "Weiter", kind: .primary)
        FFButton(title: "Kita-Plan wählen", kind: .secondary)
        FFButton(title: "Überspringen", kind: .tertiary)
        FFButton(title: "Deaktiviert", kind: .primary).disabled(true)
    }
    .padding(AppTheme.Spacing.s24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.Colors.surface)
}
