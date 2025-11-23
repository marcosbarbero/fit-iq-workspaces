import Foundation

// Represents a planned meal item with description and nutritional estimates
public struct PlannedMealItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public let description: String
    public let estimatedCalories: Double
    public let estimatedProtein: Double
    public let estimatedCarbs: Double
    public let estimatedFat: Double
    
    public init(
        id: UUID = UUID(),
        description: String,
        estimatedCalories: Double,
        estimatedProtein: Double,
        estimatedCarbs: Double,
        estimatedFat: Double
    ) {
        self.id = id
        self.description = description
        self.estimatedCalories = estimatedCalories
        self.estimatedProtein = estimatedProtein
        self.estimatedCarbs = estimatedCarbs
        self.estimatedFat = estimatedFat
    }
}

// Represents a complete meal plan for a day
public struct MealPlan: Identifiable, Equatable, Codable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let mealType: MealType
    public let items: [PlannedMealItem]
    public let source: MealPlanSource
    public let createdAt: Date
    public let createdBy: String? // User ID or "ai" or "nutritionist"
    
    public var totalCalories: Double {
        items.reduce(0) { $0 + $1.estimatedCalories }
    }
    
    public var totalProtein: Double {
        items.reduce(0) { $0 + $1.estimatedProtein }
    }
    
    public var totalCarbs: Double {
        items.reduce(0) { $0 + $1.estimatedCarbs }
    }
    
    public var totalFat: Double {
        items.reduce(0) { $0 + $1.estimatedFat }
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        mealType: MealType,
        items: [PlannedMealItem],
        source: MealPlanSource,
        createdAt: Date = Date(),
        createdBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.mealType = mealType
        self.items = items
        self.source = source
        self.createdAt = createdAt
        self.createdBy = createdBy
    }
}

// Source of the meal plan
public enum MealPlanSource: String, Codable {
    case user         // Created by the end user
    case ai           // Suggested by AI companion
    case nutritionist // Created by nutritionist
}

