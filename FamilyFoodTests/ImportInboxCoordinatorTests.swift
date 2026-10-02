import XCTest
@testable import FamilyFood

final class ImportInboxCoordinatorTests: XCTestCase {
    var tmp: URL!
    var inbox: SharedImportInbox!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        inbox = SharedImportInbox(baseURL: tmp)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    @discardableResult
    private func enqueue(_ marker: String) throws -> InboxDescriptor {
        try inbox.enqueue(payload: Data(marker.utf8), kind: .pdf,
                          originalFilename: "\(marker).pdf", sourceURL: nil)
    }

    @MainActor
    func test_skip_dismisses_the_item_without_representing_it() throws {
        try enqueue("plan")
        let coordinator = ImportInboxCoordinator(inbox: inbox)
        coordinator.drain()
        let item = try XCTUnwrap(coordinator.currentItem)

        coordinator.skip(item)

        XCTAssertNil(coordinator.currentItem)
        XCTAssertEqual(inbox.pending().count, 1) // still queued for a later retry
    }

    @MainActor
    func test_skip_advances_to_the_next_pending_item() throws {
        let first = try enqueue("first")
        Thread.sleep(forTimeInterval: 0.01)
        let second = try enqueue("second")
        let coordinator = ImportInboxCoordinator(inbox: inbox)
        coordinator.drain()
        XCTAssertEqual(coordinator.currentItem?.id, first.id)

        coordinator.skip(try XCTUnwrap(coordinator.currentItem))

        XCTAssertEqual(coordinator.currentItem?.id, second.id)
    }

    @MainActor
    func test_skipped_item_resurfaces_for_a_new_coordinator() throws {
        let desc = try enqueue("plan")
        let session1 = ImportInboxCoordinator(inbox: inbox)
        session1.drain()
        session1.skip(try XCTUnwrap(session1.currentItem))

        let session2 = ImportInboxCoordinator(inbox: inbox)
        session2.drain()

        XCTAssertEqual(session2.currentItem?.id, desc.id)
    }

    @MainActor
    func test_finish_removes_the_item_and_advances() throws {
        let first = try enqueue("first")
        Thread.sleep(forTimeInterval: 0.01)
        let second = try enqueue("second")
        let coordinator = ImportInboxCoordinator(inbox: inbox)
        coordinator.drain()

        coordinator.finish(try XCTUnwrap(coordinator.currentItem))

        XCTAssertEqual(coordinator.currentItem?.id, second.id)
        XCTAssertEqual(inbox.pending().map(\.descriptor.id), [second.id])
        _ = first
    }
}
