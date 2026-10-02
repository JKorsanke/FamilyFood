import XCTest
import UIKit
@testable import FamilyFood

/// The Wochenplan "Generieren" toolbar glyph. Whisk is the active icon; the
/// spoon stays prepared as a one-line `current` flip (no new art, no layout work).
final class MealPlanGenerateIconTests: XCTestCase {

    func test_current_is_whisk() {
        XCTAssertEqual(MealPlanGenerateIcon.current, .whisk)
    }

    func test_each_icon_maps_to_expected_asset_name() {
        XCTAssertEqual(MealPlanGenerateIcon.spoon.assetName, "ic-generate-spoon")
        XCTAssertEqual(MealPlanGenerateIcon.whisk.assetName, "ic-generate-whisk")
    }

    /// The asset name must resolve to a real, bundled catalog image — a typo in the enum or a
    /// missing/misnamed imageset would otherwise render an *invisible* toolbar button at runtime
    /// rather than failing loudly. Tests are hosted by FamilyFood.app, so `UIImage(named:)` sees
    /// the app's asset catalog.
    func test_each_icon_asset_is_bundled() {
        for icon in [MealPlanGenerateIcon.spoon, .whisk] {
            XCTAssertNotNil(UIImage(named: icon.assetName),
                            "No catalog asset for \(icon) (expected imageset \"\(icon.assetName)\")")
        }
    }

    /// Each art has its own aspect ratio; sizes fit a 40-pt box.
    func test_each_icon_fits_specified_size() {
        XCTAssertEqual(MealPlanGenerateIcon.spoon.size, CGSize(width: 40, height: 39))
        XCTAssertEqual(MealPlanGenerateIcon.whisk.size, CGSize(width: 28, height: 40))
    }
}
