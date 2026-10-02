import XCTest
import PDFKit
@testable import FamilyFood

@MainActor
final class ImportRoutingTests: XCTestCase {

    func test_url_item_routes_to_recipe() {
        let item = InboxItem(
            descriptor: .init(id: UUID(), kind: .url, payloadFilename: "x.url",
                              originalFilename: nil, sourceURL: "https://x.test", receivedAt: Date()),
            payloadURL: URL(fileURLWithPath: "/tmp/x.url"))
        XCTAssertEqual(ImportRoute.initial(for: item), .recipeURL("https://x.test"))
    }

    func test_pdf_item_routes_to_chooser() {
        let item = InboxItem(
            descriptor: .init(id: UUID(), kind: .pdf, payloadFilename: "x.pdf",
                              originalFilename: "p.pdf", sourceURL: nil, receivedAt: Date()),
            payloadURL: URL(fileURLWithPath: "/tmp/x.pdf"))
        XCTAssertEqual(ImportRoute.initial(for: item), .pdfChooser)
    }
}

final class PDFImportRendererTests: XCTestCase {

    private func makePDF(text: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 300))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            (text as NSString).draw(at: CGPoint(x: 20, y: 20),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
    }

    func test_extractText_returns_text_layer() throws {
        let renderer = PDFImportRenderer(data: makePDF(text: "Montag Nudeln"))
        XCTAssertTrue(try renderer.extractText().contains("Nudeln"))
    }

    func test_firstPageImage_is_not_nil() throws {
        let renderer = PDFImportRenderer(data: makePDF(text: "x"))
        XCTAssertNotNil(renderer.firstPageImage())
    }
}
