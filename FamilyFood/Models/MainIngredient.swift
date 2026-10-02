import Foundation

// Closed vocabulary for a recipe's main ingredient category.
// The LLM prompt in AnthropicService is generated from these raw values, so the
// picker options in the review screen stay in sync with what the model returns.
// Stored on RecipeModel.mainIngredient as `String?` — nil represents "Unbekannt".
enum MainIngredient: String, CaseIterable {
    case pasta         = "Pasta"
    case reis          = "Reis"
    case kartoffeln    = "Kartoffeln"
    case huelsenfruchte = "Hülsenfrüchte"
    case tofu          = "Tofu"
    case gemuese       = "Gemüse"
    case brotTeig      = "Brot/Teig"
    case ei            = "Ei"
    case fisch         = "Fisch"
    case fleisch       = "Fleisch"
    case sonstiges     = "Sonstiges"

    var displayName: String { rawValue }

    // Comma-separated, quoted list for prompt interpolation:
    //   "Pasta", "Reis", "Kartoffeln", ...
    static var promptVocabulary: String {
        allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")
    }
}
