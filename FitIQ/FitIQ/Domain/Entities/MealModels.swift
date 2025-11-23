import Foundation

public struct RecognizedFoodItem: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let suggestedQuantity: String  // e.g., "100 g", "250 mL", "150 g"
    public let confidence: Double  // 0.0 to 1.0
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    
    public init(
        id: UUID = UUID(),
        name: String,
        suggestedQuantity: String,
        confidence: Double,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) {
        self.id = id
        self.name = name
        self.suggestedQuantity = suggestedQuantity
        self.confidence = confidence
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}


public enum MealProcessingState: String, Codable {
    case pending
    case success
    case failure
}

// Define the MealType enum with 'water'
public enum MealType: String, Codable, CaseIterable, Identifiable, Comparable {
    public static func < (lhs: MealType, rhs: MealType) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }

    public var id: String { self.rawValue }

    var displayString: String {
        switch self {
        case .breakfast: return L10n.Nutrition.MealType.breakfast
        case .lunch: return L10n.Nutrition.MealType.lunch
        case .dinner: return L10n.Nutrition.MealType.dinner
        case .snack: return L10n.Nutrition.MealType.snack
        case .drink: return L10n.Nutrition.MealType.drink
        case .water: return L10n.Nutrition.MealType.water
        case .supplements: return L10n.Nutrition.MealType.supplements
        case .other: return L10n.Nutrition.MealType.other
        }
    }
    
    static func getMealType(displayString: String) -> MealType? {
        // Iterate through all possible cases of the MealType enum.
        for mealType in MealType.allCases {
            // Compare the provided string (lowercased for case-insensitivity)
            // with the display string of each enum case (also lowercased).
            if mealType.displayString.lowercased() == displayString.lowercased() {
                return mealType
            }
        }
        // If no match is found after checking all cases, return nil.
        return nil
    }

    // Add a sort order to control the display order in the UI
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        case .drink: return 4
        case .water: return 5
        case .supplements: return 6
        case .other: return 7
        }
    }

    case breakfast, lunch, dinner, snack, drink, water, supplements, other
}

public struct MealId: Hashable, Codable {
    public let raw: UUID
    public init(_ id: UUID = UUID()) { raw = id }
}

public struct MealItem: Identifiable, Codable {
    public var id: MealId
    public var groupId: UUID
    public var rawInput: String
    public var date: Date
    public var rawText: String
    public var calories: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var parsed: Bool
    public var mealType: MealType
    public var amount: Double? // New property for liquids

    public init(
        id: MealId = MealId(),
        groupId: UUID,
        rawInput: String,
        date: Date = Date(),
        rawText: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        parsed: Bool = false,
        mealType: MealType = .other,
        amount: Double? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.rawInput = rawInput
        self.date = date
        self.rawText = rawText
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.parsed = parsed
        self.mealType = mealType
        self.amount = amount
    }
}

// New struct to group related meal items
struct Meal: Identifiable {
    public var id: UUID { groupId }
    public var groupId: UUID
    public var rawInput: String
    public var date: Date
    public var items: [MealItem]
    public var mealType: MealType
    public var state: MealProcessingState
    
    public var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    public var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    public var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    public var totalFat: Double { items.reduce(0) { $0 + $1.fat } }
    public var totalWater: Double {items.filter {$0.mealType == .water}.reduce(0) { $0 + ($1.amount ?? 0) } }
    
    public init(groupId: UUID, rawInput: String, date: Date, items: [MealItem], mealType: MealType, state: MealProcessingState) {
        self.groupId = groupId
        self.rawInput = rawInput
        self.date = date
        self.items = items
        self.mealType = mealType
        self.state = state
    }
}

extension String {
    func toMealType() -> MealType {
        if let type = MealType(rawValue: self.lowercased()) {
            return type
        }
        return .other
    }
}
