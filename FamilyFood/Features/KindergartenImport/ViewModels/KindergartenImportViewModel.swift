import SwiftUI

@MainActor
class KindergartenImportViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isProcessing = false
    @Published var mealPlan: KitaMealPlan?
    @Published var errorMessage: String?

    private let kitaImport: KitaPlanImportService

    init(kitaImport: KitaPlanImportService = KitaPlanImportService()) {
        self.kitaImport = kitaImport
    }

    /// Dismisses the "Erkannter Speiseplan" preview when the plan it shows
    /// is deleted from the active plans.
    func clearDetectedPlan(matching id: UUID) {
        if mealPlan?.id == id { mealPlan = nil }
    }

    /// Import from a captured / picked image (camera or photo library).
    func importMealPlan() async {
        guard let image = selectedImage else { return }
        let succeeded = await publish { try await self.kitaImport.plan(fromImage: image) }
        if succeeded { selectedImage = nil }
    }

    /// Import directly from a PDF the user already has on their device.
    func importMealPlan(pdfData: Data) async {
        await publish { try await self.kitaImport.plan(fromPDF: pdfData) }
    }

    /// Shared publish contract around the KitaPlanImportService pipeline:
    /// spinner + error state here, the actual PDF/OCR/LLM sequence in the service.
    /// Returns whether a plan was produced. A missing key surfaces as
    /// `AnthropicError.missingKey` from the service — no pre-check needed here.
    @discardableResult
    private func publish(_ makePlan: () async throws -> KitaMealPlan) async -> Bool {
        isProcessing = true
        errorMessage = nil
        mealPlan = nil
        defer { isProcessing = false }

        do {
            mealPlan = try await makePlan()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
