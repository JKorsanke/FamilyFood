import XCTest
import SwiftUI
@testable import FamilyFood

/// Smoke test for the design-system gallery: every token and component must render
/// off-screen without crashing (a missing font or asset would surface here).
@MainActor
final class ThemeGalleryRenderTests: XCTestCase {
    func test_gallery_renders_to_an_image() throws {
        AppFonts.registerIfNeeded()
        let renderer = ImageRenderer(
            content: ThemeGalleryContent().frame(width: 390).background(AppTheme.Colors.surface)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer produced no image")
        XCTAssertEqual(image.size.width, 390, accuracy: 0.5)
        XCTAssertGreaterThan(image.size.height, 390, "the gallery is a long, scrolling page")
    }
}
