import XCTest
import UIKit
@testable import FamilyFood

/// Reference-semantics parser double for asserting what text the pipeline hands to the LLM.
final class CapturingKitaParser: AnthropicParsing, @unchecked Sendable {
    var receivedText: String?
    var result: Result<KitaMealPlan, Error> = .success(.mock)

    func parseMealPlan(from ocrText: String) async throws -> KitaMealPlan {
        receivedText = ocrText
        return try result.get()
    }

    func parseRecipe(from text: String, sourceURL: String?, source: RecipeSource) async throws -> RecipeDraft {
        RecipeDraft()
    }
}

final class KitaPlanImportServiceTests: XCTestCase {

    /// A one-page PDF with a real text layer (drawn via Core Text, so PDFKit can extract it).
    private func pdf(withText text: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 300))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            (text as NSString).draw(at: CGPoint(x: 20, y: 20),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
    }

    func test_pdf_with_text_layer_skips_ocr_and_parses_it() async throws {
        let parser = CapturingKitaParser()
        let service = KitaPlanImportService(
            extractText: { _ in
                XCTFail("OCR must not run when the PDF has a usable text layer")
                return ""
            },
            makeParser: { parser }
        )
        let planText = "Speiseplan KW 27: Montag Spaghetti, Dienstag Gemüsesuppe, Mittwoch Reis"

        let plan = try await service.plan(fromPDF: pdf(withText: planText))

        XCTAssertEqual(plan, .mock)
        XCTAssertEqual(parser.receivedText?.contains("Spaghetti"), true)
    }

    func test_short_text_layer_falls_back_to_ocr() async throws {
        let parser = CapturingKitaParser()
        let service = KitaPlanImportService(
            extractText: { _ in "OCR: Montag Fischstäbchen" },
            makeParser: { parser }
        )

        _ = try await service.plan(fromPDF: pdf(withText: "KW 27"))   // < 50 chars → scanned-PDF path

        XCTAssertEqual(parser.receivedText, "OCR: Montag Fischstäbchen")
    }

    func test_ocr_failure_propagates() async {
        let service = KitaPlanImportService(
            extractText: { _ in throw OCRService.OCRError.invalidImage },
            makeParser: { CapturingKitaParser() }
        )

        do {
            _ = try await service.plan(fromPDF: pdf(withText: "KW 27"))
            XCTFail("expected the OCR error to propagate")
        } catch {
            XCTAssertTrue(error is OCRService.OCRError)
        }
    }

    func test_image_import_goes_through_ocr() async throws {
        let parser = CapturingKitaParser()
        let service = KitaPlanImportService(
            extractText: { _ in "Fototext: Donnerstag Kartoffelgratin" },
            makeParser: { parser }
        )

        let plan = try await service.plan(fromImage: UIImage())

        XCTAssertEqual(plan, .mock)
        XCTAssertEqual(parser.receivedText, "Fototext: Donnerstag Kartoffelgratin")
    }
}
