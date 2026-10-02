import UIKit

/// The one pipeline from raw import material (a PDF or a photographed image) to a parsed
/// `KitaMealPlan`: PDF text layer → OCR fallback → LLM parse. Both the Kita
/// import tab and the share-inbox flow go through here, so the sequence exists exactly
/// once. Dependencies default to production and are injectable for tests.
struct KitaPlanImportService {
    var extractText: (UIImage) async throws -> String = { try await OCRService().extractText(from: $0) }
    var makeParser: () -> any AnthropicParsing = { AnthropicService(apiKey: AnthropicKeyStore().effectiveKey) }

    /// Uses the PDF's text layer when present, falling back to OCR on the rendered
    /// first page for scanned/image-only PDFs.
    func plan(fromPDF data: Data) async throws -> KitaMealPlan {
        let renderer = PDFImportRenderer(data: data)
        var text = (try? renderer.extractText()) ?? ""
        if text.count < 50, let image = renderer.firstPageImage() {
            text = try await extractText(image)
        }
        return try await makeParser().parseMealPlan(from: text)
    }

    /// Import from a captured / picked photo of the plan.
    func plan(fromImage image: UIImage) async throws -> KitaMealPlan {
        let text = try await extractText(image)
        return try await makeParser().parseMealPlan(from: text)
    }
}
