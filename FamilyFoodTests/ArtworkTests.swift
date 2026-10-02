import XCTest
import UIKit
@testable import FamilyFood

final class ArtworkTests: XCTestCase {

    // MARK: — Name resolution

    func test_name_is_the_base_name_when_no_local_original_exists() {
        XCTAssertEqual(Artwork.name("onb-01-goals", exists: { _ in false }), "onb-01-goals")
    }

    func test_name_prefers_a_local_original() {
        XCTAssertEqual(Artwork.name("onb-01-goals", exists: { $0 == "local/onb-01-goals" }),
                       "local/onb-01-goals")
    }

    func test_only_the_local_namespace_is_probed() {
        var probed: [String] = []
        _ = Artwork.name("ff-whisk-mark", exists: { probed.append($0); return false })
        XCTAssertEqual(probed, ["local/ff-whisk-mark"])
    }

    // MARK: — Catalog contents

    /// Every artwork name the app uses.
    private var names: [String] {
        ["onb-00-welcome", "onb-06-ready", "ff-whisk-mark"]
            + OnboardingCopy.dataSteps.map(\.illustration)
            + [MealPlanGenerateIcon.spoon, .whisk].map(\.assetName)
    }

    /// The repository's own catalog must carry an image under every base name, whether or
    /// not a build adds local originals — otherwise a clean checkout renders blanks.
    func test_the_catalog_has_art_for_every_base_name() {
        for name in names {
            XCTAssertNotNil(UIImage(named: name), "no catalog image named \"\(name)\"")
        }
    }

    func test_every_resolved_name_is_a_bundled_image() {
        for name in names {
            XCTAssertNotNil(UIImage(named: Artwork.name(name)), "\(Artwork.name(name)) does not resolve")
        }
    }
}
