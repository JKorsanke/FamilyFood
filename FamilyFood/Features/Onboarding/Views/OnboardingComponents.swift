import SwiftUI

// Small Onboarding-local components the core set (FFButton/FFCard/FFListRow/
// FFHeader) doesn't cover. Token-composed; the core components are not modified.

/// Onboarding hero illustration. A single-color (template) SVG tinted `accent`, scaled to
/// fit a capped height and centered. Decorative, so hidden from VoiceOver (the copy carries meaning).
/// Data steps + Ready use the default cap; Welcome (00) overrides with a larger hero.
struct FFOnboardingIllustration: View {
    let name: String
    var maxHeight: CGFloat = 120

    var body: some View {
        Image(Artwork.name(name))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .foregroundStyle(AppTheme.Colors.accent)
            .accessibilityHidden(true)
    }
}

/// Multi-select pill (screens 03 Allergene, 04 Warme Mahlzeiten). Selected = accent fill;
/// unselected = surface + hairline. `showsCheck` adds a leading check on chips (03) — day pills
/// (04) stay compact without one.
struct FFTogglePill: View {
    let title: String
    var isSelected: Bool = false
    var showsCheck: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.s6) {
                if showsCheck && isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .appText(.label)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .foregroundStyle(isSelected ? AppTheme.Colors.onAccent : AppTheme.Colors.textPrimary)
            .padding(.horizontal, AppTheme.Spacing.s16)
            .frame(minHeight: 44)
            .background(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : AppTheme.Colors.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Stepper row (screen 02 Haushalt): label (+ optional age sublabel) left, `−  value  +` right.
struct FFStepperRow: View {
    let label: String
    var sublabel: String? = nil
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s12) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s2) {
                Text(label)
                    .appText(.cta)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let sublabel {
                    Text(sublabel)
                        .appText(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppTheme.Spacing.s16) {
                stepButton("minus", enabled: value > range.lowerBound) {
                    if value > range.lowerBound { value -= 1 }
                }
                Text("\(value)")
                    .appText(.cta)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 20)
                stepButton("plus", enabled: value < range.upperBound) {
                    if value < range.upperBound { value += 1 }
                }
            }
        }
        .padding(AppTheme.Spacing.s16)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(AppTheme.Colors.hairline, lineWidth: 1)
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? AppTheme.Colors.accent : AppTheme.Colors.textFaded)
                .frame(width: 36, height: 36)
                .background(enabled ? AppTheme.Colors.accentTint : AppTheme.Colors.track)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Wrapping flow layout for the allergen chip grid (03). iOS 16+ `Layout`.
struct FlowLayout: Layout {
    var spacing: CGFloat = AppTheme.Spacing.s8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, x - spacing)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, x - spacing)
        return CGSize(width: min(maxRowWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
