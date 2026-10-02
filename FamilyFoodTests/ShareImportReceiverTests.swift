import XCTest
import UniformTypeIdentifiers
@testable import FamilyFood

final class ShareImportReceiverTests: XCTestCase {

    /// Stand-in for NSItemProvider.
    final class FakeProvider: SharedItemProviding {
        let types: [String]
        let pdf: Data?
        let url: URL?
        init(types: [String], pdf: Data? = nil, url: URL? = nil) {
            self.types = types; self.pdf = pdf; self.url = url
        }
        func hasItem(conformingTo type: UTType) -> Bool { types.contains(type.identifier) }
        func loadData(for type: UTType) async throws -> Data { pdf ?? Data() }
        func loadURL() async throws -> URL { url! }
    }

    private func makeInbox() -> SharedImportInbox {
        SharedImportInbox(baseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    func test_pdf_provider_enqueues_pdf() async throws {
        let inbox = makeInbox()
        let receiver = ShareImportReceiver(inbox: inbox)
        let provider = FakeProvider(types: [UTType.pdf.identifier], pdf: Data("%PDF".utf8))
        try await receiver.receive(provider)
        XCTAssertEqual(inbox.pending().first?.descriptor.kind, .pdf)
    }

    func test_url_provider_enqueues_url() async throws {
        let inbox = makeInbox()
        let receiver = ShareImportReceiver(inbox: inbox)
        let provider = FakeProvider(types: [UTType.url.identifier], url: URL(string: "https://x.test/r")!)
        try await receiver.receive(provider)
        XCTAssertEqual(inbox.pending().first?.descriptor.sourceURL, "https://x.test/r")
        XCTAssertEqual(inbox.pending().first?.descriptor.kind, .url)
    }

    func test_unsupported_throws() async {
        let inbox = makeInbox()
        let receiver = ShareImportReceiver(inbox: inbox)
        let provider = FakeProvider(types: [UTType.image.identifier])
        do {
            try await receiver.receive(provider)
            XCTFail("should throw for unsupported type")
        } catch {
            XCTAssertEqual(inbox.pending().count, 0)
        }
    }
}
