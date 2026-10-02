import Foundation
import SwiftData

// MARK: — Enums

enum DietStyle: String, Codable, CaseIterable {
    case vegan, vegetarian, omnivore, unknown

    var displayName: String {
        switch self {
        case .vegan:      return "Vegan"
        case .vegetarian: return "Vegetarisch"
        case .omnivore:   return "Mit Fleisch"
        case .unknown:    return "Unbekannt"
        }
    }

    var systemImage: String {
        switch self {
        case .vegan:      return "leaf.fill"
        case .vegetarian: return "leaf"
        case .omnivore:   return "fork.knife"
        case .unknown:    return "questionmark.circle"
        }
    }

    // Cases shown in the manual entry picker — unknown is not a valid choice there
    static var manualCases: [DietStyle] { [.vegan, .vegetarian, .omnivore] }
}

enum RecipeSource: String, Codable {
    case bundled, webScrape, ocr, manual
}

// MARK: — SwiftData models

@Model
final class RecipeModel {
    @Attribute(.unique) var id: UUID

    // Identifiers carried over from a bundled seed record (nil for imported and manual recipes)
    var sourcePostId: Int?
    var sourceRecipeId: Int?

    // Core
    var title: String
    var sourceURL: String?
    var summary: String?

    // Servings
    var servings: String?
    var servingsUnit: String?

    // Times in minutes — nil means unknown
    var prepTime: Int?
    var cookTime: Int?
    var totalTime: Int?

    // Image — all sources store to Documents/RecipeImages/{id}.jpg
    var imageLocalPath: String?
    var imageRemoteURL: String?

    // Classification
    var dietStyle: DietStyle
    var isFamilyFriendly: Bool

    // User state
    var isFavourite: Bool
    var dateFavourited: Date?

    // Suggestion engine
    var mainIngredient: String?
    var lastRecommendedDate: Date?
    var swapCount: Int = 0
    var allergenTagsCSV: String = ""

    // Nutrition per serving — nil when the source has no data
    var calories: Double?
    var carbohydrates: Double?
    var protein: Double?
    var fat: Double?
    var fiber: Double?

    // Provenance
    var source: RecipeSource
    var dateAdded: Date

    @Relationship(deleteRule: .cascade) var ingredientGroups: [IngredientGroupModel] = []

    // Falls back to prepTime + cookTime when totalTime is nil
    var displayTotalTime: Int? {
        if let t = totalTime { return t }
        if let p = prepTime, let c = cookTime { return p + c }
        return nil
    }

    init(
        id: UUID = UUID(),
        sourcePostId: Int? = nil,
        sourceRecipeId: Int? = nil,
        title: String,
        sourceURL: String? = nil,
        summary: String? = nil,
        servings: String? = nil,
        servingsUnit: String? = nil,
        prepTime: Int? = nil,
        cookTime: Int? = nil,
        totalTime: Int? = nil,
        imageLocalPath: String? = nil,
        imageRemoteURL: String? = nil,
        dietStyle: DietStyle = .unknown,
        isFamilyFriendly: Bool = false,
        isFavourite: Bool = false,
        dateFavourited: Date? = nil,
        mainIngredient: String? = nil,
        lastRecommendedDate: Date? = nil,
        swapCount: Int = 0,
        allergenTags: [String] = [],
        calories: Double? = nil,
        carbohydrates: Double? = nil,
        protein: Double? = nil,
        fat: Double? = nil,
        fiber: Double? = nil,
        source: RecipeSource = .manual,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.sourcePostId = sourcePostId
        self.sourceRecipeId = sourceRecipeId
        self.title = title
        self.sourceURL = sourceURL
        self.summary = summary
        self.servings = servings
        self.servingsUnit = servingsUnit
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.imageLocalPath = imageLocalPath
        self.imageRemoteURL = imageRemoteURL
        self.dietStyle = dietStyle
        self.isFamilyFriendly = isFamilyFriendly
        self.isFavourite = isFavourite
        self.dateFavourited = dateFavourited
        self.mainIngredient = mainIngredient
        self.lastRecommendedDate = lastRecommendedDate
        self.swapCount = swapCount
        self.allergenTagsCSV = allergenTags.joined(separator: "|")
        self.calories = calories
        self.carbohydrates = carbohydrates
        self.protein = protein
        self.fat = fat
        self.fiber = fiber
        self.source = source
        self.dateAdded = dateAdded
    }
}

extension RecipeModel {
    var allergenTags: [String] {
        get { allergenTagsCSV.isEmpty ? [] : allergenTagsCSV.components(separatedBy: "|") }
        set { allergenTagsCSV = newValue.joined(separator: "|") }
    }
}

@Model
final class IngredientGroupModel {
    var name: String
    var sortOrder: Int
    var recipe: RecipeModel?
    @Relationship(deleteRule: .cascade) var ingredients: [RecipeIngredientModel] = []

    init(name: String, sortOrder: Int) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

@Model
final class RecipeIngredientModel {
    var amount: String
    var unit: String
    var name: String
    var notes: String
    var sortOrder: Int
    var group: IngredientGroupModel?

    init(amount: String, unit: String, name: String, notes: String, sortOrder: Int) {
        self.amount = amount
        self.unit = unit
        self.name = name
        self.notes = notes
        self.sortOrder = sortOrder
    }
}
