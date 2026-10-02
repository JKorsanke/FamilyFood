import UIKit

struct OCRRecipeParser {
    private let anthropicService: any AnthropicParsing

    init(anthropicService: any AnthropicParsing) {
        self.anthropicService = anthropicService
    }

    func parse(image: UIImage) async throws -> RecipeDraft {
        let ocrText = try await OCRService().extractText(from: image)
        guard ocrText.count >= 50 else { throw OCRRecipeError.insufficientText }
        return try await anthropicService.parseRecipe(from: ocrText, sourceURL: nil, source: .ocr)
    }

    enum OCRRecipeError: LocalizedError {
        case insufficientText
        var errorDescription: String? {
            "Es konnte kein lesbarer Text erkannt werden. Bitte mache ein deutlicheres Foto."
        }
    }
}
