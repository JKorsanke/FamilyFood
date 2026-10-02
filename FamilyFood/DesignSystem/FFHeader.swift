import SwiftUI

/// Core component — **Header / nav chrome**.
/// Onboarding top chrome: optional back chevron + segmented progress.
struct FFProgressHeader: View {
    let step: Int          // 1-based index of the current step
    let total: Int
    var onBack: (() -> Void)? = nil
    /// When provided, completed/current progress segments become tappable; the closure receives
    /// the 1-based step number to jump to. Nil ⇒ segments are non-interactive (default).
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button { onBack?() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .opacity(onBack == nil ? 0 : 1)
            .disabled(onBack == nil)

            HStack(spacing: AppTheme.Spacing.s6) {
                ForEach(0 ..< max(total, 1), id: \.self) { index in
                    Button { onSelect?(index + 1) } label: {
                        Capsule()
                            .fill(index < step ? AppTheme.Colors.accent : AppTheme.Colors.track)
                            .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil || index + 1 > step)
                    .accessibilityLabel(Text("Zu Schritt \(index + 1)"))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 30)
    }
}

/// Screen title block: display title + optional secondary subtitle.
struct FFScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s8) {
            Text(title)
                .appText(.display)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)   // wrap to all lines, never truncate
            if let subtitle {
                Text(subtitle)
                    .appText(.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tab-root screen header: display title + optional trailing action on the 24pt
/// screen axle. Replaces the iOS large title (which sits at the system inset), so every tab's
/// title shares one position and one type role. Pin it above the screen's scrolling content
/// and hide the navigation bar.
struct FFScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s12) {
            Text(title)
                .appText(.display)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            trailing()
        }
        // Same height with or without an action, so the title sits level across tabs.
        .frame(minHeight: FFHeaderIconButton.slot)
        .padding(.horizontal, AppTheme.Spacing.s24)
        .padding(.vertical, AppTheme.Spacing.s20)
    }
}

extension FFScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// SF Symbol action for `FFScreenHeader`'s trailing slot: one glyph size and one tap
/// slot for every header action. Fades and disables when `isEnabled` is false.
struct FFHeaderIconButton: View {
    static let slot: CGFloat = 40   // tap slot

    let systemImage: String
    let accessibilityLabel: String
    var tint: Color = AppTheme.Colors.textPrimary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isEnabled ? tint : AppTheme.Colors.textFaded)
                .frame(width: Self.slot, height: Self.slot)
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Brand header: app mark + wordmark (onboarding 00).
struct FFBrandHeader: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.s12) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .fill(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(Artwork.name("ff-whisk-mark"))   // brand mark
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(AppTheme.Colors.onAccent)
                )
            Text("FamilyFood")
                .appText(.brand)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("FFHeader") {
    let _ = AppFonts.registerIfNeeded()
    VStack(alignment: .leading, spacing: AppTheme.Spacing.s32) {
        FFProgressHeader(step: 3, total: 5, onBack: {})
        FFBrandHeader()
        FFScreenTitle(title: "Wie ernährt ihr euch?",
                      subtitle: "Wir schlagen passende Gerichte vor.")
        FFScreenHeader(title: "Rezepte") {
            FFHeaderIconButton(systemImage: "plus", accessibilityLabel: "Rezept hinzufügen",
                               tint: AppTheme.Colors.accent) {}
        }
        .padding(.horizontal, -AppTheme.Spacing.s24)   // brings its own screen margin
    }
    .padding(AppTheme.Spacing.s24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(AppTheme.Colors.surface)
}
