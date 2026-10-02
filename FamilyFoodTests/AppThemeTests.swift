import XCTest
import SwiftUI
@testable import FamilyFood

/// Design-system token tests.
final class AppThemeColorHexTests: XCTestCase {

    private func rgba(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func testHexInitParsesAccentCobalt() {
        let c = rgba(Color(hex: 0x0040E0))
        XCTAssertEqual(c.r, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 64.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 224.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.01)
    }

    func testHexInitParsesTextPrimary() {
        let c = rgba(Color(hex: 0x0E1116))
        XCTAssertEqual(c.r, 14.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 17.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 22.0 / 255.0, accuracy: 0.01)
    }

    func testHexInitAppliesOpacity() {
        let c = rgba(Color(hex: 0x0040E0, opacity: 0.08))
        XCTAssertEqual(c.a, 0.08, accuracy: 0.01)
    }
}

/// The bundled fonts must actually load.
final class AppFontsTests: XCTestCase {
    func testBundledFontsRegister() {
        AppFonts.registerIfNeeded()
        XCTAssertTrue(UIFont.familyNames.contains("Inter"), "Inter family not registered")
        XCTAssertTrue(UIFont.familyNames.contains("Inter Tight"), "Inter Tight family not registered")
    }
}

/// Token sanity: scale + key colors match the approved spec.
final class AppThemeTokenTests: XCTestCase {
    func testSpacingAndRadiusScale() {
        XCTAssertEqual(AppTheme.Spacing.s16, 16)
        XCTAssertEqual(AppTheme.Spacing.s24, 24)
        XCTAssertEqual(AppTheme.Radius.sm, 12)
        XCTAssertEqual(AppTheme.Radius.md, 14)
        XCTAssertEqual(AppTheme.Radius.lg, 16)
    }

    func testAccentTokenMatchesSpec() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(AppTheme.Colors.accent).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0, accuracy: 0.01)
        XCTAssertEqual(g, 64.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 224.0 / 255.0, accuracy: 0.01)
    }
}

/// The palette has no dark variants, so the app must declare itself light-only —
/// otherwise token text ends up near-black on the dark system background.
final class AppAppearanceTests: XCTestCase {
    func test_app_is_pinned_to_light_appearance() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIUserInterfaceStyle") as? String, "Light")
    }
}
