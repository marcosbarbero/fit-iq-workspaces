//
//  PhotoRecognitionEntities.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Domain entities for photo-based meal logging functionality
//

import Foundation

// MARK: - Photo Recognition Status

/// Processing status for photo recognition
public enum PhotoRecognitionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case confirmed = "confirmed"  // User confirmed and created meal log

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .confirmed: return "Confirmed"
        }
    }

    public var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .processing: return "🔄"
        case .completed: return "✅"
        case .failed: return "❌"
        case .confirmed: return "🎯"
        }
    }
}

// MARK: - Domain Models

/// Recognized food item from photo analysis
/// This is the photo recognition version with additional fields for AI confidence
public struct PhotoRecognizedFoodItem: Identifiable, Codable {
    /// Local UUID for the recognized food item
    public let id: UUID

    /// Name of the recognized food
    public let name: String

    /// Estimated quantity
    public let quantity: Double

    /// Unit of measurement
    public let unit: String

    /// Estimated calories
    public let calories: Int

    /// Protein in grams
    public let proteinG: Double

    /// Carbohydrates in grams
    public let carbsG: Double

    /// Fat in grams
    public let fatG: Double

    /// Fiber in grams (optional)
    public let fiberG: Double?

    /// Sugar in grams (optional)
    public let sugarG: Double?

    /// AI confidence score for this item (0.0-1.0)
    public let confidenceScore: Double

    /// Confidence level category
    public let confidenceLevel: PhotoConfidenceLevel

    /// Order in the recognition results
    public let orderIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unit: String,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double? = nil,
        sugarG: Double? = nil,
        confidenceScore: Double,
        confidenceLevel: PhotoConfidenceLevel,
        orderIndex: Int
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.confidenceScore = confidenceScore
        self.confidenceLevel = confidenceLevel
        self.orderIndex = orderIndex
    }
}

/// Confidence level for photo recognition
public enum PhotoConfidenceLevel: String, Codable {
    case veryHigh = "very_high"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case veryLow = "very_low"

    /// Create confidence level from score
    public static func fromScore(_ score: Double) -> PhotoConfidenceLevel {
        switch score {
        case 0.9...1.0:
            return .veryHigh
        case 0.7..<0.9:
            return .high
        case 0.5..<0.7:
            return .medium
        case 0.3..<0.5:
            return .low
        default:
            return .veryLow
        }
    }

    public var displayName: String {
        switch self {
        case .veryHigh: return "Very High"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .veryLow: return "Very Low"
        }
    }

    public var emoji: String {
        switch self {
        case .veryHigh: return "🎯"
        case .high: return "✅"
        case .medium: return "⚠️"
        case .low: return "❌"
        case .veryLow: return "🚫"
        }
    }
}

/// Domain model for photo recognition request/result
///
/// Represents a meal photo upload and its AI-processed recognition results.
/// The backend analyzes the photo and identifies food items with nutritional information.
public struct PhotoRecognition: Identifiable, Codable {
    /// Local UUID for the photo recognition
    public let id: UUID

    /// User ID who uploaded the photo
    public let userID: String

    /// URL to the stored image (temporary, expires in 24 hours)
    public let imageURL: String?

    /// Meal type (breakfast, lunch, dinner, snack, etc.)
    public let mealType: MealType

    /// Processing status
    public let status: PhotoRecognitionStatus

    /// Overall confidence score from AI recognition (0.0-1.0)
    public let confidenceScore: Double?

    /// Whether the results need user review/confirmation
    public let needsReview: Bool

    /// Recognized food items from the image
    public let recognizedItems: [PhotoRecognizedFoodItem]

    /// Total calories for all recognized items
    public let totalCalories: Int?

    /// Total protein in grams
    public let totalProteinG: Double?

    /// Total carbs in grams
    public let totalCarbsG: Double?

    /// Total fat in grams
    public let totalFatG: Double?

    /// Total fiber in grams
    public let totalFiberG: Double?

    /// Total sugar in grams
    public let totalSugarG: Double?

    /// When the meal was consumed
    public let loggedAt: Date

    /// Optional user notes about the meal
    public let notes: String?

    /// Optional error message if recognition failed
    public let errorMessage: String?

    /// When AI processing started
    public let processingStartedAt: Date?

    /// When AI processing completed
    public let processingCompletedAt: Date?

    /// When the recognition was created locally
    public let createdAt: Date

    /// When the recognition was last updated
    public let updatedAt: Date?

    /// Backend-assigned ID (from API response)
    public let backendID: String?

    /// Sync status with backend
    public let syncStatus: SyncStatus

    /// Associated meal log ID (after confirmation)
    public let mealLogID: UUID?

    public init(
        id: UUID = UUID(),
        userID: String,
        imageURL: String? = nil,
        mealType: MealType,
        status: PhotoRecognitionStatus = .pending,
        confidenceScore: Double? = nil,
        needsReview: Bool = true,
        recognizedItems: [PhotoRecognizedFoodItem] = [],
        totalCalories: Int? = nil,
        totalProteinG: Double? = nil,
        totalCarbsG: Double? = nil,
        totalFatG: Double? = nil,
        totalFiberG: Double? = nil,
        totalSugarG: Double? = nil,
        loggedAt: Date = Date(),
        notes: String? = nil,
        errorMessage: String? = nil,
        processingStartedAt: Date? = nil,
        processingCompletedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending,
        mealLogID: UUID? = nil
    ) {
        self.id = id
        self.userID = userID
        self.imageURL = imageURL
        self.mealType = mealType
        self.status = status
        self.confidenceScore = confidenceScore
        self.needsReview = needsReview
        self.recognizedItems = recognizedItems
        self.totalCalories = totalCalories
        self.totalProteinG = totalProteinG
        self.totalCarbsG = totalCarbsG
        self.totalFatG = totalFatG
        self.totalFiberG = totalFiberG
        self.totalSugarG = totalSugarG
        self.loggedAt = loggedAt
        self.notes = notes
        self.errorMessage = errorMessage
        self.processingStartedAt = processingStartedAt
        self.processingCompletedAt = processingCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
        self.mealLogID = mealLogID
    }
}

// MARK: - Confirmed Food Item (for PATCH request)

/// User-confirmed food item for creating meal log
/// After user reviews and optionally edits recognized items, they are converted to this type
public struct ConfirmedFoodItem: Codable {
    /// Name of the food (user can edit)
    public let name: String

    /// Quantity (user can edit)
    public let quantity: Double

    /// Unit of measurement
    public let unit: String

    /// Calories (user can edit)
    public let calories: Int

    /// Protein in grams (user can edit)
    public let proteinG: Double

    /// Carbohydrates in grams (user can edit)
    public let carbsG: Double

    /// Fat in grams (user can edit)
    public let fatG: Double

    /// Fiber in grams (optional, user can edit)
    public let fiberG: Double?

    /// Sugar in grams (optional, user can edit)
    public let sugarG: Double?

    public init(
        name: String,
        quantity: Double,
        unit: String,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double? = nil,
        sugarG: Double? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
    }
}

// MARK: - Computed Properties

extension PhotoRecognition {
    /// Total calories from recognized items (computed locally if backend value not available)
    public var computedTotalCalories: Double {
        Double(recognizedItems.reduce(0) { $0 + $1.calories })
    }

    /// Total protein from recognized items (computed locally if backend value not available)
    public var computedTotalProtein: Double {
        recognizedItems.reduce(0) { $0 + $1.proteinG }
    }

    /// Total carbs from recognized items (computed locally if backend value not available)
    public var computedTotalCarbs: Double {
        recognizedItems.reduce(0) { $0 + $1.carbsG }
    }

    /// Total fat from recognized items (computed locally if backend value not available)
    public var computedTotalFat: Double {
        recognizedItems.reduce(0) { $0 + $1.fatG }
    }

    /// Total fiber from recognized items (computed locally if backend value not available)
    public var computedTotalFiber: Double {
        recognizedItems.reduce(0) { $0 + ($1.fiberG ?? 0) }
    }

    /// Total sugar from recognized items (computed locally if backend value not available)
    public var computedTotalSugar: Double {
        recognizedItems.reduce(0) { $0 + ($1.sugarG ?? 0) }
    }

    /// Whether the photo recognition is complete and ready for user confirmation
    public var isReadyForConfirmation: Bool {
        status == .completed && !recognizedItems.isEmpty
    }

    /// Whether the photo recognition has been confirmed and meal log created
    public var isConfirmed: Bool {
        status == .confirmed && mealLogID != nil
    }

    /// Whether the photo recognition is still being processed
    public var isProcessing: Bool {
        status == .pending || status == .processing
    }

    /// Whether the photo recognition failed
    public var hasFailed: Bool {
        status == .failed
    }

    /// Processing duration in seconds (if available)
    public var processingDuration: TimeInterval? {
        guard let start = processingStartedAt,
            let end = processingCompletedAt
        else {
            return nil
        }
        return end.timeIntervalSince(start)
    }
}
