import XCTest
@testable import FamilyFood

@MainActor
final class KindergartenImportViewModelTests: XCTestCase {

    // Deleting a plan via the bin icon must also dismiss the
    // "Erkannter Speiseplan" preview, which renders off `mealPlan`.
    func test_deleting_the_detected_plan_clears_the_preview() {
        let vm = KindergartenImportViewModel()
        vm.mealPlan = .mock

        vm.clearDetectedPlan(matching: KitaMealPlan.mock.id)

        XCTAssertNil(vm.mealPlan)
    }

    func test_deleting_a_different_plan_keeps_the_preview() {
        let vm = KindergartenImportViewModel()
        vm.mealPlan = .mock

        vm.clearDetectedPlan(matching: UUID())

        XCTAssertEqual(vm.mealPlan?.id, KitaMealPlan.mock.id)
    }

    // The PDF→plan pipeline lives once in KitaPlanImportService — the VM
    // only orchestrates publish state around it.

    func test_pdf_import_publishes_the_parsed_plan() async {
        let parser = CapturingKitaParser()
        let vm = KindergartenImportViewModel(
            kitaImport: KitaPlanImportService(extractText: { _ in "" }, makeParser: { parser })
        )

        await vm.importMealPlan(pdfData: Data())   // pipeline detail is KitaPlanImportServiceTests' job

        XCTAssertEqual(vm.mealPlan, .mock)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isProcessing)
    }

    func test_pdf_import_failure_publishes_the_error() async {
        let parser = CapturingKitaParser()
        parser.result = .failure(AnthropicService.AnthropicError.missingKey)
        let vm = KindergartenImportViewModel(
            kitaImport: KitaPlanImportService(extractText: { _ in "" }, makeParser: { parser })
        )

        await vm.importMealPlan(pdfData: Data())

        XCTAssertNil(vm.mealPlan)
        XCTAssertEqual(vm.errorMessage,
                       AnthropicService.AnthropicError.missingKey.errorDescription)
        XCTAssertFalse(vm.isProcessing)
    }
}
