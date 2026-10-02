import XCTest
@testable import FamilyFood

final class ShoppingListStoreTests: XCTestCase {
    private var tmp: URL!
    private var store: ShoppingListStore!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = ShoppingListStore(directory: tmp)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_load_missing_file_returns_empty_state() {
        XCTAssertEqual(store.load(), .empty)
    }

    func test_save_then_load_round_trips_excluded_and_checked() {
        let id = UUID()
        var state = ShoppingListState()
        state.excludedRecipeIds = [id]
        state.checkedItemKeys = ["mehl|g"]

        store.save(state)

        let loaded = store.load()
        XCTAssertEqual(loaded.excludedRecipeIds, [id])
        XCTAssertEqual(loaded.checkedItemKeys, ["mehl|g"])
    }

    func test_load_returns_empty_when_file_is_corrupt() throws {
        try "not json".data(using: .utf8)!.write(to: tmp.appendingPathComponent("shopping_list.json"))
        XCTAssertEqual(store.load(), .empty)
    }
}
