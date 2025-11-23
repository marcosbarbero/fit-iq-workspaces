
// Models for meal suggestions + dietary restrictions + mood entries

import Foundation

// Represents dietary restrictions/preferences the user may have
public struct DietaryRestrictions: Codable, Equatable {
    public let vegetarian: Bool
    public let vegan: Bool
    public let glutenFree: Bool
    public let dairyFree: Bool
    public let nutFree: Bool
    public let paleo: Bool
    public let keto: Bool
    public let allergies: [String] // free text (e.g. "shellfish", "soy")

    public init(vegetarian: Bool = false,
                vegan: Bool = false,
                glutenFree: Bool = false,
                dairyFree: Bool = false,
                nutFree: Bool = false,
                paleo: Bool = false,
                keto: Bool = false,
                allergies: [String] = []) {
        self.vegetarian = vegetarian
        self.vegan = vegan
        self.glutenFree = glutenFree
        self.dairyFree = dairyFree
        self.nutFree = nutFree
        self.paleo = paleo
        self.keto = keto
        self.allergies = allergies
    }
}

// Single suggested meal returned by AI (high-level + prefilled nutrition)
public struct MealSuggestion: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String             // e.g. "Grilled chicken & broccoli"
    public let description: String       // human readable short text
    public let items: [SuggestedFoodItem]// composable items for editor
    public let estimatedCalories: Int
    public let estimatedProtein: Int
    public let estimatedCarbs: Int
    public let estimatedFat: Int
    public let tags: [String]            // e.g. ["high-protein","low-carb"]
    public let source: String?           // e.g. "ai:coaching" or "template"

    public init(id: UUID = UUID(),
                title: String,
                description: String,
                items: [SuggestedFoodItem],
                estimatedCalories: Int,
                estimatedProtein: Int,
                estimatedCarbs: Int,
                estimatedFat: Int,
                tags: [String] = [],
                source: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.items = items
        self.estimatedCalories = estimatedCalories
        self.estimatedProtein = estimatedProtein
        self.estimatedCarbs = estimatedCarbs
        self.estimatedFat = estimatedFat
        self.tags = tags
        self.source = source
    }
}

public struct SuggestedFoodItem: Codable, Equatable {
    public let name: String        // "Chicken breast"
    public var quantityText: String // "120 g" (editable)
    public var calories: Int?
    public var protein: Double?
    public var carbs: Double?
    public var fat: Double?

    public init(name: String, quantityText: String, calories: Int? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil) {
        self.name = name
        self.quantityText = quantityText
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

// Minimal DTO the AI will receive when asked for suggestions
public struct MealSuggestionRequest: Codable {
    public let goalDescription: String?
    public let dailyTargets: [String: Double]?
    public let restrictions: DietaryRestrictions?
    public let recentMealsSummary: [String]?
    public let locale: String?
}

// The AI's response: list of suggestions
public struct MealSuggestionResponse: Codable {
    public let suggestions: [MealSuggestion]
    public let warnings: [String]?
}
