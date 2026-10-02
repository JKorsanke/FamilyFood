import SwiftUI

/// Inline search field for screens whose `FFScreenHeader` replaces the navigation
/// bar, where `.searchable` has nowhere to live. Token-composed: neutral fill, magnifier,
/// body text, and a clear button once there is text.
struct FFSearchField: View {
    @Binding var text: String
    var prompt: String = "Suchen"
    /// Draws the value as plain text instead of a live `TextField`. For off-screen rendering
    /// only (ThemeGallery snapshot): `ImageRenderer` can't draw UIKit-backed text fields.
    var isStatic = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if isStatic {
                Text(text.isEmpty ? prompt : text)
                    .appText(.body)
                    .foregroundStyle(text.isEmpty ? AppTheme.Colors.textPlaceholder : AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("", text: $text,
                          prompt: Text(prompt).foregroundStyle(AppTheme.Colors.textPlaceholder))
                    .appText(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .submitLabel(.search)
            }

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPlaceholder)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.s12)
        .frame(height: 44)
        .background(AppTheme.Colors.neutralTint,
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
    }
}

#Preview("FFSearchField") {
    let _ = AppFonts.registerIfNeeded()
    VStack(spacing: AppTheme.Spacing.s16) {
        FFSearchField(text: .constant(""), prompt: "Rezepte suchen")
        FFSearchField(text: .constant("Pancakes"), prompt: "Rezepte suchen")
    }
    .padding(AppTheme.Spacing.s24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(AppTheme.Colors.surface)
}
