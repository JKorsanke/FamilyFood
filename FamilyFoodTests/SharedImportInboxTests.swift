import XCTest
@testable import FamilyFood

final class SharedImportInboxTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: — App group id (comes from the build configuration, not from a literal)

    func test_appGroupID_is_read_from_the_info_dictionary() {
        XCTAssertEqual(SharedImportInbox.appGroupID(in: ["FFAppGroupID": "group.org.example.familyfood"]),
                       "group.org.example.familyfood")
    }

    func test_appGroupID_is_nil_when_the_key_is_missing() {
        XCTAssertNil(SharedImportInbox.appGroupID(in: [:]))
        XCTAssertNil(SharedImportInbox.appGroupID(in: nil))
    }

    func test_appGroupID_is_nil_when_the_value_is_blank() {
        XCTAssertNil(SharedImportInbox.appGroupID(in: ["FFAppGroupID": "  "]))
    }

    /// Wiring check: Config/Signing.xcconfig → Info.plist → runtime. The test host is the app itself.
    func test_app_bundle_declares_an_app_group_for_familyfood() throws {
        let id = try XCTUnwrap(SharedImportInbox.appGroupID(in: Bundle.main.infoDictionary))
        XCTAssertTrue(id.hasPrefix("group."), id)
        XCTAssertTrue(id.hasSuffix(".familyfood"), id)
        XCTAssertFalse(id.contains("$("), "build setting was not expanded: \(id)")
    }

    func test_enqueue_pdf_then_pending_returns_item_with_payload() throws {
        let inbox = SharedImportInbox(baseURL: tmp)
        let desc = try inbox.enqueue(payload: Data("%PDF-1.4".utf8), kind: .pdf,
                                     originalFilename: "plan.pdf", sourceURL: nil)
        let pending = inbox.pending()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].descriptor.id, desc.id)
        XCTAssertEqual(pending[0].descriptor.kind, .pdf)
        XCTAssertEqual(pending[0].descriptor.originalFilename, "plan.pdf")
        XCTAssertEqual(try Data(contentsOf: pending[0].payloadURL), Data("%PDF-1.4".utf8))
    }

    func test_remove_deletes_payload_and_descriptor() throws {
        let inbox = SharedImportInbox(baseURL: tmp)
        _ = try inbox.enqueue(payload: Data("https://x.test".utf8), kind: .url,
                              originalFilename: nil, sourceURL: "https://x.test")
        let item = inbox.pending()[0]
        inbox.remove(item)
        XCTAssertEqual(inbox.pending().count, 0)
    }

    func test_pending_is_sorted_oldest_first() throws {
        let inbox = SharedImportInbox(baseURL: tmp)
        let first = try inbox.enqueue(payload: Data("a".utf8), kind: .url, originalFilename: nil, sourceURL: "a")
        Thread.sleep(forTimeInterval: 0.01)
        let second = try inbox.enqueue(payload: Data("b".utf8), kind: .url, originalFilename: nil, sourceURL: "b")
        let pending = inbox.pending()
        XCTAssertEqual(pending.map { $0.descriptor.id }, [first.id, second.id])
    }
}
