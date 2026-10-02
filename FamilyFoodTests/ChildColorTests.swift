import XCTest
@testable import FamilyFood

final class ChildColorTests: XCTestCase {

    /// Locked expected values derived from the raw UUID bytes. These are stable across
    /// app launches; a `hashValue`-based implementation would produce a per-process
    /// random result and fail this test on most runs.
    func test_index_is_deterministic_from_uuid_bytes() {
        // byte sum = 1 → 1 % 3 = 1
        XCTAssertEqual(ChildColor.index(for: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!), 1)
        // byte sum = 2 → 2 % 3 = 2
        XCTAssertEqual(ChildColor.index(for: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!), 2)
        // byte sum = 3 → 3 % 3 = 0
        XCTAssertEqual(ChildColor.index(for: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!), 0)
    }

    func test_index_is_in_palette_range() {
        for _ in 0..<200 {
            let i = ChildColor.index(for: UUID())
            XCTAssertTrue((0..<ChildColor.palette.count).contains(i))
        }
    }

    func test_same_id_always_maps_to_same_color() {
        let id = UUID()
        XCTAssertEqual(ChildColor.color(for: id), ChildColor.color(for: id))
    }
}
