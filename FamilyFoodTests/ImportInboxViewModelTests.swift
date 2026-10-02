import XCTest
import UIKit
@testable import FamilyFood

@MainActor
final class ImportInboxViewModelTests: XCTestCase {

    private func writeTempPDF(text: String) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 300))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            (text as NSString).draw(at: CGPoint(x: 20, y: 20),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("inbox-test-\(UUID().uuidString).pdf")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func test_mealPlan_from_pdf_returns_parsed_plan() async throws {
        let parser = CapturingKitaParser()
        let vm = ImportInboxViewModel(
            kitaImport: KitaPlanImportService(extractText: { _ in "" }, makeParser: { parser }),
            makeParser: { parser }
        )
        let url = try writeTempPDF(text: "Speiseplan KW 27: Montag Spaghetti Bolognese, Dienstag Suppe")

        let plan = await vm.mealPlan(fromPDFAt: url)

        XCTAssertEqual(plan, .mock)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func test_mealPlan_from_unreadable_url_sets_error() async {
        let vm = ImportInboxViewModel(
            kitaImport: KitaPlanImportService(extractText: { _ in "" }, makeParser: { CapturingKitaParser() }),
            makeParser: { CapturingKitaParser() }
        )
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).pdf")

        let plan = await vm.mealPlan(fromPDFAt: missing)

        XCTAssertNil(plan)
        XCTAssertEqual(vm.errorMessage, "PDF konnte nicht gelesen werden.")
    }

    func test_mealPlan_parser_failure_surfaces_error_message() async throws {
        let parser = CapturingKitaParser()
        parser.result = .failure(AnthropicService.AnthropicError.missingKey)
        let vm = ImportInboxViewModel(
            kitaImport: KitaPlanImportService(extractText: { _ in "" }, makeParser: { parser }),
            makeParser: { parser }
        )
        let url = try writeTempPDF(text: "Speiseplan KW 27: Montag Spaghetti Bolognese, Dienstag Suppe")

        let plan = await vm.mealPlan(fromPDFAt: url)

        XCTAssertNil(plan)
        XCTAssertEqual(vm.errorMessage,
                       AnthropicService.AnthropicError.missingKey.errorDescription)
    }

    func test_recipeDraft_from_unreadable_url_sets_error() async {
        let vm = ImportInboxViewModel(
            kitaImport: KitaPlanImportService(extractText: { _ in "" }, makeParser: { CapturingKitaParser() }),
            makeParser: { CapturingKitaParser() }
        )
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).pdf")

        let draft = await vm.recipeDraft(fromPDFAt: missing)

        XCTAssertNil(draft)
        XCTAssertEqual(vm.errorMessage, "PDF konnte nicht gelesen werden.")
    }
}
