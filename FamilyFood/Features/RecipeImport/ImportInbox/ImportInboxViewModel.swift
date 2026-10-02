import UIKit

/// Orchestrates parsing for a shared inbox item: owns loading/error state and
/// the PDF pipelines, so `ImportInboxFlow` keeps only presentation state. The Kita-PDF
/// path is the shared `KitaPlanImportService`; the recipe-PDF path renders the first
/// page and reuses `OCRRecipeParser`.
@MainActor
final class ImportInboxViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let kitaImport: KitaPlanImportService
    private let makeParser: () -> any AnthropicParsing

    init(kitaImport: KitaPlanImportService = KitaPlanImportService(),
         makeParser: @escaping () -> any AnthropicParsing = { AnthropicService(apiKey: AnthropicKeyStore().effectiveKey) }) {
        self.kitaImport = kitaImport
        self.makeParser = makeParser
    }

    /// Kita-Speiseplan path — the caller decides child assignment.
    func mealPlan(fromPDFAt url: URL) async -> KitaMealPlan? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "PDF konnte nicht gelesen werden."
            return nil
        }
        do {
            return try await kitaImport.plan(fromPDF: data)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Single-recipe path — first page rendered to an image, then OCR → LLM.
    func recipeDraft(fromPDFAt url: URL) async -> RecipeDraft? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: url),
              let image = PDFImportRenderer(data: data).firstPageImage() else {
            errorMessage = "PDF konnte nicht gelesen werden."
            return nil
        }
        do {
            return try await OCRRecipeParser(anthropicService: makeParser()).parse(image: image)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
