//
//  MealLogEntities.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Domain entities for meal logging functionality
//

import Foundation

// MARK: - Food Type Classification

/// Food type classification for meal log items
///
/// Used to classify each food item as solid food, caloric beverage, or water.
/// This enables water intake tracking, beverage calorie insights, and better nutrition recommendations.
public enum FoodType: String, Codable, CaseIterable {
    case food = "food"  // Solid foods (chicken, rice, vegetables, etc.)
    case drink = "drink"  // Caloric beverages (juice, milk, soda, coffee with milk)
    case water = "water"  // Water or zero-calorie drinks (water, black coffee, unsweetened tea)

    public var displayName: String {
        switch self {
        case .food: return "Food"
        case .drink: return "Beverage"
        case .water: return "Water"
        }
    }

    public var emoji: String {
        switch self {
        case .food: return "🍽️"
        case .drink: return "☕"
        case .water: return "💧"
        }
    }

    public var color: String {
        switch self {
        case .food: return "#4CAF50"  // Green
        case .drink: return "#FF9800"  // Orange
        case .water: return "#2196F3"  // Blue
        }
    }
}

// MARK: - Meal Log Processing Status

/// Processing status for meal logs (from backend)
public enum MealLogStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    public var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .processing: return "🔄"
        case .completed: return "✅"
        case .failed: return "❌"
        }
    }
}

// MARK: - Domain Models

// Note: SyncStatus is defined in Domain/Entities/Progress/SyncStatus.swift

/// Domain model for a meal log entry
///
/// Represents a user's meal logging request, which may contain one or more food items.
/// The backend processes the natural language input and extracts nutritional information.
public struct MealLog: Identifiable, Codable {
    /// Local UUID for the meal log
    public let id: UUID

    /// User ID who created this meal log
    public let userID: String

    /// Raw natural language input from the user
    public let rawInput: String

    /// Meal type (breakfast, lunch, dinner, snack, etc.)
    public let mealType: MealType

    /// Processing status from backend
    public let status: MealLogStatus

    /// Date/time when the meal was consumed
    public let loggedAt: Date

    /// Parsed meal items (populated after processing completes)
    public let items: [MealLogItem]

    /// Optional notes from user
    public let notes: String?

    /// Total calories from all items (computed by backend)
    public let totalCalories: Int?

    /// Total protein in grams (computed by backend)
    public let totalProteinG: Double?

    /// Total carbs in grams (computed by backend)
    public let totalCarbsG: Double?

    /// Total fat in grams (computed by backend)
    public let totalFatG: Double?

    /// Total fiber in grams (computed by backend, optional)
    public let totalFiberG: Double?

    /// Total sugar in grams (computed by backend, optional)
    public let totalSugarG: Double?

    /// When AI processing started (optional)
    public let processingStartedAt: Date?

    /// When AI processing completed (optional)
    public let processingCompletedAt: Date?

    /// When this entry was created locally
    public let createdAt: Date

    /// When this entry was last updated
    public let updatedAt: Date?

    /// Backend-assigned ID (populated after successful sync)
    public let backendID: String?

    /// Local sync status (pending, synced, failed)
    public let syncStatus: SyncStatus

    /// Optional error message if processing failed
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        userID: String,
        rawInput: String,
        mealType: MealType,
        status: MealLogStatus = .pending,
        loggedAt: Date = Date(),
        items: [MealLogItem] = [],
        notes: String? = nil,
        totalCalories: Int? = nil,
        totalProteinG: Double? = nil,
        totalCarbsG: Double? = nil,
        totalFatG: Double? = nil,
        totalFiberG: Double? = nil,
        totalSugarG: Double? = nil,
        processingStartedAt: Date? = nil,
        processingCompletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.rawInput = rawInput
        self.mealType = mealType
        self.status = status
        self.loggedAt = loggedAt
        self.items = items
        self.notes = notes
        self.totalCalories = totalCalories
        self.totalProteinG = totalProteinG
        self.totalCarbsG = totalCarbsG
        self.totalFatG = totalFatG
        self.totalFiberG = totalFiberG
        self.totalSugarG = totalSugarG
        self.processingStartedAt = processingStartedAt
        self.processingCompletedAt = processingCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
        self.errorMessage = errorMessage
    }
}

/// Domain model for a parsed meal log item (individual food item)
///
/// Represents a single food item extracted from the meal log's natural language input.
/// Contains nutritional information parsed by the backend.
public struct MealLogItem: Identifiable, Codable {
    /// Local UUID for the meal log item
    public let id: UUID

    /// ID of the parent meal log
    public let mealLogID: UUID

    /// Name of the food item
    public let name: String

    /// Quantity/serving size as numeric value (e.g., 100, 1, 2)
    public let quantity: Double

    /// Unit for the quantity (e.g., "g", "cup", "slices", "mL", "L")
    public let unit: String

    /// Calories in kcal
    public let calories: Double

    /// Protein in grams
    public let protein: Double

    /// Carbohydrates in grams
    public let carbs: Double

    /// Fat in grams
    public let fat: Double

    /// Food type classification (food, drink, water)
    public let foodType: FoodType

    /// Fiber in grams (optional - not all foods have fiber data)
    public let fiber: Double?

    /// Sugar in grams (optional - not all foods have sugar data)
    public let sugar: Double?

    /// Confidence score from AI parsing (0.0 to 1.0)
    public let confidence: Double?

    /// Optional notes from AI parsing (e.g., assumptions made)
    public let parsingNotes: String?

    /// Display order (0-based index for sorting items)
    public let orderIndex: Int

    /// When this item was created
    public let createdAt: Date

    /// Backend-assigned ID (populated after successful sync)
    public let backendID: String?

    public init(
        id: UUID = UUID(),
        mealLogID: UUID,
        name: String,
        quantity: Double,
        unit: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        foodType: FoodType = .food,
        fiber: Double? = nil,
        sugar: Double? = nil,
        confidence: Double? = nil,
        parsingNotes: String? = nil,
        orderIndex: Int = 0,
        createdAt: Date = Date(),
        backendID: String? = nil
    ) {
        self.id = id
        self.mealLogID = mealLogID
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.foodType = foodType
        self.fiber = fiber
        self.sugar = sugar
        self.confidence = confidence
        self.parsingNotes = parsingNotes
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.backendID = backendID
    }
}

// MARK: - Extensions

extension MealLog {
    /// Total calories from all items (computed locally if backend value not available)
    public var computedTotalCalories: Double {
        items.reduce(0) { $0 + $1.calories }
    }

    /// Total protein from all items (computed locally if backend value not available)
    public var computedTotalProtein: Double {
        items.reduce(0) { $0 + $1.protein }
    }

    /// Total carbs from all items (computed locally if backend value not available)
    public var computedTotalCarbs: Double {
        items.reduce(0) { $0 + $1.carbs }
    }

    /// Total fat from all items (computed locally if backend value not available)
    public var computedTotalFat: Double {
        items.reduce(0) { $0 + $1.fat }
    }

    /// Total fiber from all items (computed locally if backend value not available)
    public var computedTotalFiber: Double {
        items.reduce(0) { $0 + ($1.fiber ?? 0) }
    }

    /// Total sugar from all items (computed locally if backend value not available)
    public var computedTotalSugar: Double {
        items.reduce(0) { $0 + ($1.sugar ?? 0) }
    }

    /// Whether this meal log is ready to display (processing completed)
    public var isReady: Bool {
        status == .completed
    }

    /// Whether this meal log needs syncing to backend
    public var needsSync: Bool {
        syncStatus == .pending || syncStatus == .failed
    }

    /// Whether this meal log is pending sync
    public var isPending: Bool {
        syncStatus == .pending
    }

    /// Whether this meal log has been synced successfully
    public var isSynced: Bool {
        syncStatus == .synced
    }

    /// Whether this meal log has a sync error
    public var hasSyncError: Bool {
        syncStatus == .failed
    }

    /// Get sorted items by order_index
    public var sortedItems: [MealLogItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }
}

extension MealLogItem {
    /// Format macros as a readable string (e.g., "P: 25g | C: 30g | F: 10g")
    public var macrosDescription: String {
        String(format: "P: %.1fg | C: %.1fg | F: %.1fg", protein, carbs, fat)
    }

    /// Format quantity with unit (e.g., "200 g", "2 cups", "1 L")
    public var quantityDescription: String {
        // Format quantity based on whether it's a whole number or decimal
        let formattedQuantity: String
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            formattedQuantity = String(format: "%.0f", quantity)
        } else {
            formattedQuantity = String(format: "%.1f", quantity)
        }
        return "\(formattedQuantity) \(unit)"
    }

    /// Confidence level interpretation
    public var confidenceLevel: ConfidenceLevel {
        guard let score = confidence else { return .unknown }
        switch score {
        case 0.8...1.0:
            return .high
        case 0.5..<0.8:
            return .medium
        case 0.0..<0.5:
            return .low
        default:
            return .unknown
        }
    }
}

/// Confidence level for AI-parsed meal items
public enum ConfidenceLevel {
    case high
    case medium
    case low
    case unknown

    public var displayName: String {
        switch self {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        case .unknown: return "Unknown"
        }
    }

    public var emoji: String {
        switch self {
        case .high: return "✅"
        case .medium: return "⚠️"
        case .low: return "❓"
        case .unknown: return "—"
        }
    }
}

// MARK: - MealLog Extensions for Food Type Filtering

extension MealLog {
    /// Filter items by food type
    public func items(ofType foodType: FoodType) -> [MealLogItem] {
        items.filter { $0.foodType == foodType }
    }

    /// Get all food items (solid foods)
    public var foodItems: [MealLogItem] {
        items(ofType: .food)
    }

    /// Get all drink items (caloric beverages)
    public var drinkItems: [MealLogItem] {
        items(ofType: .drink)
    }

    /// Get all water items (water/zero-cal drinks)
    public var waterItems: [MealLogItem] {
        items(ofType: .water)
    }

    /// Total water intake in milliliters
    /// Converts various units to milliliters for accurate tracking
    public var estimatedWaterIntakeMl: Double {
        waterItems.reduce(0) { total, item in
            let value = item.quantity
            let unit = item.unit.lowercased()

            // Convert based on unit
            if unit == "l" || unit == "liter" || unit == "liters" {
                return total + (value * 1000)  // liters to ml
            } else if unit == "ml" || unit == "milliliter" || unit == "milliliters" {
                return total + value  // already in ml
            } else if unit == "cup" || unit == "cups" {
                return total + (value * 240)  // cups to ml (US cup)
            } else if unit == "oz" || unit == "fl oz" || unit == "ounce" || unit == "ounces" {
                return total + (value * 29.5735)  // fl oz to ml
            } else if unit == "glass" || unit == "glasses" {
                return total + (value * 250)  // assume 1 glass ≈ 250 mL
            } else {
                // Default: assume ml if unit is unknown
                return total + value
            }
        }
    }

    /// Total calories from beverages (drinks only, excluding water)
    public var beverageCalories: Double {
        drinkItems.reduce(0) { $0 + $1.calories }
    }

    /// Total calories from solid foods
    public var foodCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }

    /// Percentage of calories from beverages
    public var beverageCaloriePercentage: Double {
        let total = computedTotalCalories
        guard total > 0 else { return 0 }
        return (beverageCalories / total) * 100
    }
}
