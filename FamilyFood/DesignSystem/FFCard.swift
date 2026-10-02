import SwiftUI

/// Core component — **Card** variant.
/// `standard` = surface + hairline; `emphasized` = filled accent (onboarding 07).
/// Declared outside the generic `FFCard` so the enum is referenceable without inferring `Content`.
enum FFCardKind { case standard, emphasized }

struct FFCard<Content: View>: View {
    var kind: FFCardKind
    var padding: CGFloat
    @ViewBuilder var content: () -> Content

    init(kind: FFCardKind = .standard,
         padding: CGFloat = AppTheme.Spacing.s16,
         @ViewBuilder content: @escaping () -> Content) {
        self.kind = kind
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(kind == .emphasized ? AppTheme.Colors.accent : AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .overlay {
                if kind == .standard {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .stroke(AppTheme.Colors.hairline, lineWidth: 1)
                }
            }
    }
}

/// Common composition: icon tile + title/subtitle + chevron (onboarding 07). Token-composed on FFCard.
struct FFActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var kind: FFCardKind = .standard
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            FFCard(kind: kind, padding: AppTheme.Spacing.s16) {
                HStack(spacing: AppTheme.Spacing.s12) {
                    iconTile
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.s4) {
                        Text(title).appText(.cta).foregroundStyle(titleColor)
                        Text(subtitle).appText(.caption).foregroundStyle(subtitleColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: AppTheme.Spacing.s8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(chevronColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var emphasized: Bool { kind == .emphasized }

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
            .fill(emphasized ? AppTheme.Colors.onAccentTint : AppTheme.Colors.accentTint)
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(emphasized ? AppTheme.Colors.onAccent : AppTheme.Colors.accent)
            )
    }

    private var titleColor: Color { emphasized ? AppTheme.Colors.onAccent : AppTheme.Colors.textPrimary }
    private var subtitleColor: Color { emphasized ? AppTheme.Colors.onAccentSecondary : AppTheme.Colors.textSecondary }
    private var chevronColor: Color { emphasized ? AppTheme.Colors.onAccentSecondary : AppTheme.Colors.hairline }
}

#Preview("FFCard") {
    let _ = AppFonts.registerIfNeeded()
    VStack(spacing: AppTheme.Spacing.s12) {
        FFActionCard(icon: "camera.fill",
                     title: "Kita-Plan hochladen",
                     subtitle: "Fotografiere den Speiseplan – wir übernehmen ihn automatisch.",
                     kind: .emphasized)
        FFActionCard(icon: "fork.knife",
                     title: "Rezept hinzufügen",
                     subtitle: "Füge ein Lieblingsrezept hinzu.")
        FFCard {
            Text("Schlichte Karte").appText(.cta).foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }
    .padding(AppTheme.Spacing.s24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.Colors.surface)
}
