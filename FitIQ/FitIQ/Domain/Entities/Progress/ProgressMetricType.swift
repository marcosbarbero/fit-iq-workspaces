//
//  ProgressMetricType.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Biological Sex and Height Improvements
//

import Foundation

/// Type-safe enum for progress metric types
///
/// This enum provides compile-time safety for progress tracking metric types,
/// preventing typos and ensuring only valid metric types are used.
///
/// **Categories:**
/// - Physical metrics: weight, height, body composition
/// - Activity metrics: steps, calories, distance
/// - Wellness metrics: sleep, water, heart rate
/// - Nutrition metrics: calories, macronutrients
///
/// **Backend Compatibility:**
/// The `rawValue` matches the exact string expected by the backend API
/// at POST /api/v1/progress endpoint (uses `logged_at` timestamp).
/// The GET /api/v1/progress endpoint supports `from`, `to`, and pagination parameters.
public enum ProgressMetricType: String, CaseIterable, Codable {

    // MARK: - Physical Metrics

    /// Weight in kilograms
    case weight = "weight"

    /// Height in centimeters
    case height = "height"

    /// Body fat percentage (0-100)
    case bodyFatPercentage = "body_fat_percentage"

    /// Body Mass Index
    case bmi = "bmi"

    // MARK: - Activity Metrics

    /// Step count
    case steps = "steps"

    /// Calories burned (energy expenditure)
    case caloriesOut = "calories_out"

    /// Distance traveled in kilometers
    case distanceKm = "distance_km"

    /// Active minutes (exercise time)
    case activeMinutes = "active_minutes"

    // MARK: - Wellness Metrics

    /// Sleep duration in hours
    case sleepHours = "sleep_hours"

    /// Water intake in liters
    case waterLiters = "water_liters"

    /// Resting heart rate (beats per minute)
    case restingHeartRate = "resting_heart_rate"

    /// Mood score (1-10 scale)
    case moodScore = "mood_score"

    // MARK: - Nutrition Metrics

    /// Calories consumed (energy intake)
    case caloriesIn = "calories_in"

    /// Protein intake in grams
    case proteinG = "protein_g"

    /// Carbohydrates intake in grams
    case carbsG = "carbs_g"

    /// Fat intake in grams
    case fatG = "fat_g"

    // MARK: - Display Properties

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .height: return "Height"
        case .bodyFatPercentage: return "Body Fat %"
        case .bmi: return "BMI"
        case .steps: return "Steps"
        case .caloriesOut: return "Calories Burned"
        case .distanceKm: return "Distance"
        case .activeMinutes: return "Active Minutes"
        case .sleepHours: return "Sleep Duration"
        case .waterLiters: return "Water Intake"
        case .restingHeartRate: return "Resting Heart Rate"
        case .moodScore: return "Mood Score"
        case .caloriesIn: return "Calories Consumed"
        case .proteinG: return "Protein"
        case .carbsG: return "Carbohydrates"
        case .fatG: return "Fat"
        }
    }

    /// Unit of measurement for this metric
    var unit: String {
        switch self {
        case .weight: return "kg"
        case .height: return "cm"
        case .bodyFatPercentage: return "%"
        case .bmi: return ""
        case .steps: return "steps"
        case .caloriesOut, .caloriesIn: return "kcal"
        case .moodScore: return ""
        case .distanceKm: return "km"
        case .activeMinutes: return "min"
        case .sleepHours: return "hrs"
        case .waterLiters: return "L"
        case .restingHeartRate: return "bpm"
        case .proteinG, .carbsG, .fatG: return "g"
        }
    }

    /// Category this metric belongs to
    var category: ProgressMetricCategory {
        switch self {
        case .weight, .height, .bodyFatPercentage, .bmi:
            return .physical
        case .steps, .caloriesOut, .distanceKm, .activeMinutes:
            return .activity
        case .sleepHours, .waterLiters, .restingHeartRate, .moodScore:
            return .wellness
        case .caloriesIn, .proteinG, .carbsG, .fatG:
            return .nutrition
        }
    }

    /// SF Symbol icon name for this metric
    var iconName: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .height: return "arrow.up.arrow.down"
        case .bodyFatPercentage: return "percent"
        case .bmi: return "chart.bar.fill"
        case .steps: return "figure.walk"
        case .caloriesOut: return "flame.fill"
        case .distanceKm: return "location.fill"
        case .activeMinutes: return "timer"
        case .sleepHours: return "bed.double.fill"
        case .waterLiters: return "drop.fill"
        case .restingHeartRate: return "heart.fill"
        case .moodScore: return "face.smiling.fill"
        case .caloriesIn: return "fork.knife"
        case .proteinG: return "leaf.fill"
        case .carbsG: return "flour.fill"
        case .fatG: return "oilcan.fill"
        }
    }

    // MARK: - Validation

    /// Validates if a quantity value is reasonable for this metric type
    ///
    /// - Parameter quantity: The value to validate
    /// - Returns: True if the value is within reasonable bounds
    func isValid(quantity: Double) -> Bool {
        guard quantity >= 0 else { return false }

        switch self {
        case .weight:
            return quantity > 0 && quantity < 500  // kg
        case .height:
            return quantity > 0 && quantity < 300  // cm
        case .bodyFatPercentage:
            return quantity >= 0 && quantity <= 100  // %
        case .bmi:
            return quantity > 0 && quantity < 100
        case .steps:
            return quantity < 1_000_000  // reasonable daily max
        case .caloriesOut, .caloriesIn:
            return quantity < 50_000  // kcal
        case .distanceKm:
            return quantity < 1_000  // km per day
        case .activeMinutes:
            return quantity < 1_440  // minutes in a day
        case .sleepHours:
            return quantity <= 24  // hours
        case .waterLiters:
            return quantity < 50  // liters
        case .restingHeartRate:
            return quantity > 20 && quantity < 300  // bpm
        case .moodScore:
            return quantity >= 1 && quantity <= 10  // 1-10 scale
        case .proteinG, .carbsG, .fatG:
            return quantity < 10_000  // grams
        }
    }
}

// MARK: - Category Enum

/// Categories for grouping progress metrics
public enum ProgressMetricCategory: String, CaseIterable {
    case physical = "Physical"
    case activity = "Activity"
    case wellness = "Wellness"
    case nutrition = "Nutrition"

    /// Display name for the category
    var displayName: String {
        return rawValue
    }

    /// SF Symbol icon for the category
    var iconName: String {
        switch self {
        case .physical: return "figure.arms.open"
        case .activity: return "figure.run"
        case .wellness: return "heart.circle.fill"
        case .nutrition: return "leaf.circle.fill"
        }
    }

    /// All metrics in this category
    var metrics: [ProgressMetricType] {
        ProgressMetricType.allCases.filter { $0.category == self }
    }
}

// MARK: - Convenience Extensions

extension ProgressMetricType {
    /// All physical metrics
    static var physicalMetrics: [ProgressMetricType] {
        allCases.filter { $0.category == .physical }
    }

    /// All activity metrics
    static var activityMetrics: [ProgressMetricType] {
        allCases.filter { $0.category == .activity }
    }

    /// All wellness metrics
    static var wellnessMetrics: [ProgressMetricType] {
        allCases.filter { $0.category == .wellness }
    }

    /// All nutrition metrics
    static var nutritionMetrics: [ProgressMetricType] {
        allCases.filter { $0.category == .nutrition }
    }
}
