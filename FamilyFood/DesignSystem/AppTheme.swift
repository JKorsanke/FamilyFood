import SwiftUI
import UIKit

// MARK: - Color from hex
// Clean design system, single source of truth for tokens.
// Documented in docs/DESIGN-SYSTEM.md.
// Rule: views never use a raw hex, a system-font shortcut, or an off-scale spacing/radius value.
// If a value isn't in AppTheme, it isn't in the app.

extension Color {
    /// Build a Color from a 24-bit RGB hex literal, e.g. `Color(hex: 0x0040E0)`.
    init(hex: UInt, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum AppTheme {

    // MARK: - Colors
    enum Colors {
        // Base
        static let surface           = Color(hex: 0xFFFFFF)
        static let textPrimary       = Color(hex: 0x0E1116)   // 19.1:1 on surface
        static let textSecondary     = Color(hex: 0x5C636B)   // 6.1:1
        static let textPlaceholder   = Color(hex: 0x6E757D)   // AA-safe placeholder (Decision B)
        static let textFaded         = Color(hex: 0xC9CED4)   // disabled / decorative text only
        static let hairline          = Color(hex: 0xC9CED4)   // control & card borders
        static let divider           = Color(hex: 0xC9CED4, opacity: 0.60) // list separators (Decision C)
        static let track             = Color(hex: 0xE6E8EB)   // progress inactive / muted fill
        static let accent            = Color(hex: 0x0040E0)   // 7.5:1
        static let onAccent          = Color(hex: 0xFFFFFF)

        // Tints (semantic fills)
        static let accentTint        = Color(hex: 0x0040E0, opacity: 0.08) // selected fill, icon tiles, badges
        static let neutralTint       = Color(hex: 0x0E1116, opacity: 0.05) // neutral badge
        static let onAccentTint      = Color(hex: 0xFFFFFF, opacity: 0.15) // icon tile on accent
        static let onAccentSecondary = Color(hex: 0xFFFFFF, opacity: 0.80) // secondary text on accent — 5.2:1

        // Semantic states (Decision D)
        static let destructive       = Color(hex: 0xC81E1E)   // 5.7:1
        static let success           = Color(hex: 0x15803D)   // 5.0:1
    }

    // MARK: - Spacing (4-pt grid + retained half-steps: 2, 6, 10, 14)
    enum Spacing {
        static let s2:  CGFloat = 2
        static let s4:  CGFloat = 4
        static let s6:  CGFloat = 6
        static let s8:  CGFloat = 8
        static let s10: CGFloat = 10   // onboarding illustration breathing room — off-grid, design-mandated
        static let s12: CGFloat = 12
        static let s14: CGFloat = 14   // meal-plan row rhythm — off-grid, design-mandated
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24   // screen horizontal margin
        static let s32: CGFloat = 32
        static let s40: CGFloat = 40   // onboarding illustration breathing room
    }

    // MARK: - Corner radius
    enum Radius {
        static let sm:   CGFloat = 12   // icon tiles
        static let md:   CGFloat = 14   // buttons, list/selection rows
        static let lg:   CGFloat = 16   // cards
        static let pill: CGFloat = 999  // badges, chips, progress, radios
    }

    // MARK: - Typography
    enum FontFamily {
        static let display     = "Inter Tight"
        static let text        = "Inter"
        static let handwritten = "Gaegu"        // brand wordmark — matches the app icon
    }

    /// A complete type role: family + size + weight + line height + tracking + Dynamic Type anchor.
    /// Built with `Font.custom(_:size:relativeTo:)` so every role scales with Dynamic Type.
    struct TextRole {
        let family: String
        let size: CGFloat
        let weight: Font.Weight
        let lineHeight: CGFloat
        let tracking: CGFloat        // points (= em × size)
        let relativeTo: Font.TextStyle
        let uppercase: Bool

        var font: Font {
            Font.custom(family, size: size, relativeTo: relativeTo).weight(weight)
        }
        /// Extra leading to approximate the target line height. SwiftUI lineSpacing is additive,
        /// so this only opens up loose roles (body); tight display roles clamp to 0.
        var lineSpacing: CGFloat { max(0, lineHeight - size * 1.32) }

        // The ramp — defined on TextRole so call sites use leading-dot syntax: `.appText(.cta)`.
        static let displayXL = TextRole(family: FontFamily.display, size: 38, weight: .heavy,    lineHeight: 42, tracking: -0.76, relativeTo: .largeTitle,  uppercase: false)
        static let display   = TextRole(family: FontFamily.display, size: 30, weight: .heavy,    lineHeight: 34, tracking: -0.60, relativeTo: .title,       uppercase: false)
        static let headline  = TextRole(family: FontFamily.display, size: 22, weight: .heavy,    lineHeight: 24, tracking: -0.22, relativeTo: .title3,      uppercase: false)
        static let brand     = TextRole(family: FontFamily.handwritten, size: 30, weight: .bold, lineHeight: 34, tracking:  0,    relativeTo: .headline,    uppercase: false)  // hand-drawn wordmark (Gaegu), matches app icon
        static let cta       = TextRole(family: FontFamily.text,    size: 17, weight: .semibold, lineHeight: 22, tracking: -0.17, relativeTo: .headline,    uppercase: false)
        static let body      = TextRole(family: FontFamily.text,    size: 16, weight: .regular,  lineHeight: 24, tracking:  0,    relativeTo: .body,        uppercase: false)
        static let label     = TextRole(family: FontFamily.text,    size: 15, weight: .medium,   lineHeight: 20, tracking:  0,    relativeTo: .subheadline, uppercase: false)
        static let caption   = TextRole(family: FontFamily.text,    size: 13, weight: .regular,  lineHeight: 18, tracking:  0,    relativeTo: .footnote,    uppercase: false)
        static let footnote  = TextRole(family: FontFamily.text,    size: 12, weight: .regular,  lineHeight: 16, tracking:  0,    relativeTo: .caption,     uppercase: false)
        static let overline  = TextRole(family: FontFamily.text,    size: 10, weight: .bold,     lineHeight: 12, tracking:  0.6,  relativeTo: .caption2,    uppercase: true)  // badges (0.06em)
        static let eyebrow   = TextRole(family: FontFamily.text,    size: 10, weight: .bold,     lineHeight: 12, tracking:  1.8,  relativeTo: .caption2,    uppercase: true)  // eyebrows (0.18em)
    }

    // MARK: - Global appearance
    /// Pins the tab bar's scroll-edge appearance to its standard (opaque) appearance, so the bar
    /// stays solid in every scroll state. Without this, iOS's default flips the tab bar to a
    /// transparent `scrollEdgeAppearance` the moment a tab's content scrolls to the bottom edge —
    /// which only the Wochenplan hit, leaving it see-through. Call once at launch.
    static func configureGlobalAppearance() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithDefaultBackground()   // iOS's standard chrome material (what other tabs already show)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }
}

// MARK: - Applying a type role
private struct AppTextModifier: ViewModifier {
    let role: AppTheme.TextRole
    func body(content: Content) -> some View {
        content
            .font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
            .textCase(role.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Apply a design-system type role (font + tracking + line height + casing).
    func appText(_ role: AppTheme.TextRole) -> some View { modifier(AppTextModifier(role: role)) }
}
