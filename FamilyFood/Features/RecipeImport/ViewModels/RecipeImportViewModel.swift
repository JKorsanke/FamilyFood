import SwiftUI

@MainActor
final class RecipeImportViewModel: ObservableObject {
    @Published var draft: RecipeDraft?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var anthropicService: AnthropicService {
        AnthropicService(apiKey: AnthropicKeyStore().effectiveKey)
    }

    func importFromURL(_ urlString: String, databaseService: RecipeDatabaseService) async -> Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Ungültige URL."
            return false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if databaseService.recipeExists(withURL: url.absoluteString) {
                errorMessage = "Dieses Rezept ist bereits in deiner Datenbank."
                return false
            }
            let result = try await WebScrapeParser(anthropicService: anthropicService).parse(url: url)
            if result.isConfident {
                try await databaseService.save(result.draft)
                return true              // saved directly — caller dismisses the sheet
            } else {
                draft = result.draft     // show review screen
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func importFromOCR(_ image: UIImage) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            draft = try await OCRRecipeParser(anthropicService: anthropicService).parse(image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
