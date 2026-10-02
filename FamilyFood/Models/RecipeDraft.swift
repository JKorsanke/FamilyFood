import Foundation

// Intermediate struct used during import review — not a SwiftData model.
struct RecipeDraft {
    var title: String = ""
    var sourceURL: String? = nil
    var summary: String? = nil
    var servings: String? = nil
    var servingsUnit: String? = nil
    var prepTime: Int? = nil
    var cookTime: Int? = nil
    var totalTime: Int? = nil
    var imageURL: String? = nil       // remote URL — downloaded on confirm
    var localImageData: Data? = nil   // from camera / photo picker
    var dietStyle: DietStyle = .unknown
    var isFamilyFriendly: Bool = false
    var source: RecipeSource = .manual
    var dateAdded: Date = Date()
    var ingredientGroups: [IngredientGroupDraft] = []
    var mainIngredient: String? = nil
    var allergenTags: [String] = []

    var effectiveTotalTime: Int? {
        if let t = totalTime { return t }
        if let p = prepTime, let c = cookTime { return p + c }
        return nil
    }
}

struct IngredientGroupDraft {
    var name: String
    var ingredients: [RecipeIngredientDraft]
}

struct RecipeIngredientDraft {
    var amount: String
    var unit: String
    var name: String
    var notes: String
}

// MARK: — Bundled JSON types (first-launch seed data, see `RecipeSeed`)

struct BundledRecipe: Codable {
    let id: Int
    let recipe_id: Int?
    let title: String
    let url: String?
    let summary: String?
    let servings: String?
    let servings_unit: String?
    let prep_time: String?
    let cook_time: String?
    let total_time: String?
    let image: String?
    let main_ingredient: String?   // a `MainIngredient` raw value; nil is treated as unclassified
    let diet_style: String?        // a `DietStyle` raw value; absent or unrecognised maps to `.unknown`
    let ingredient_groups: [BundledIngredientGroup]
    let date_published: String?   // ISO 8601 — absent in older JSON, falls back to Date()
    let nutrition: BundledNutrition?   // per serving; absent/empty for many source recipes
}

struct BundledIngredientGroup: Codable {
    let name: String
    let ingredients: [BundledIngredient]
}

struct BundledIngredient: Codable {
    let amount: String
    let unit: String
    let name: String
    let notes: String
}

// Per-serving nutrition. Written as a JSON object when available, or `null`
// when the source has none (never an empty array — that would fail decoding).
struct BundledNutrition: Codable {
    let calories: Double?
    let carbohydrates: Double?
    let protein: Double?
    let fat: Double?
    let fiber: Double?
}

// MARK: — RecipeModel factory methods

extension RecipeModel {
    static func from(bundled: BundledRecipe) -> RecipeModel {
        RecipeModel(
            sourcePostId: bundled.id,
            sourceRecipeId: bundled.recipe_id,
            title: bundled.title,
            sourceURL: bundled.url,
            summary: bundled.summary,
            servings: bundled.servings,
            servingsUnit: bundled.servings_unit,
            prepTime: Int(bundled.prep_time ?? ""),
            cookTime: Int(bundled.cook_time ?? ""),
            totalTime: Int(bundled.total_time ?? ""),
            dietStyle: DietStyle(rawValue: bundled.diet_style ?? "") ?? .unknown,
            isFamilyFriendly: true,     // seed recipes are curated for families
            mainIngredient: bundled.main_ingredient,
            calories: bundled.nutrition?.calories,
            carbohydrates: bundled.nutrition?.carbohydrates,
            protein: bundled.nutrition?.protein,
            fat: bundled.nutrition?.fat,
            fiber: bundled.nutrition?.fiber,
            source: .bundled,
            dateAdded: parseISO8601Date(bundled.date_published) ?? Date()
        )
    }

    static func from(draft: RecipeDraft) -> RecipeModel {
        RecipeModel(
            title: draft.title,
            sourceURL: draft.sourceURL,
            summary: draft.summary.flatMap { $0.isEmpty ? nil : $0 },
            servings: draft.servings.flatMap { $0.isEmpty ? nil : $0 },
            servingsUnit: draft.servingsUnit.flatMap { $0.isEmpty ? nil : $0 },
            prepTime: draft.prepTime,
            cookTime: draft.cookTime,
            totalTime: draft.totalTime,
            imageRemoteURL: draft.imageURL,
            dietStyle: draft.dietStyle,
            isFamilyFriendly: draft.isFamilyFriendly,
            mainIngredient: draft.mainIngredient,
            allergenTags: draft.allergenTags,
            source: draft.source,
            dateAdded: draft.dateAdded
        )
    }
}

// MARK: — Shared utilities

func parseISO8601Date(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fmt.date(from: string) { return d }
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: string)
}

// Parses ISO 8601 durations: PT30M, PT1H30M, PT1H
func parseDuration(_ duration: String?) -> Int? {
    guard var str = duration, str.hasPrefix("P") else { return nil }
    str = String(str.dropFirst())                          // drop "P"
    guard let tRange = str.range(of: "T") else { return nil }
    str = String(str[tRange.upperBound...])                // keep only time part

    var minutes = 0
    if let hRange = str.range(of: "H") {
        if let h = Int(str[str.startIndex..<hRange.lowerBound]) { minutes += h * 60 }
        str = String(str[hRange.upperBound...])
    }
    if let mRange = str.range(of: "M") {
        if let m = Int(str[str.startIndex..<mRange.lowerBound]) { minutes += m }
    }
    return minutes > 0 ? minutes : nil
}
