//
//  PersistenceHeloper.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import HealthKit  // Need HealthKit for UnitMass/UnitLength

/// Alias to simplify access to Schema types
typealias SDUserProfile = SchemaV11.SDUserProfileV11
typealias SDDietaryAndActivityPreferences = SchemaV11.SDDietaryAndActivityPreferences
typealias SDPhysicalAttribute = SchemaV11.SDPhysicalAttribute
typealias SDActivitySnapshot = SchemaV11.SDActivitySnapshot
typealias SDProgressEntry = SchemaV11.SDProgressEntry
typealias SDOutboxEvent = SchemaV8.SDOutboxEvent
typealias SDSleepSession = SchemaV11.SDSleepSession
typealias SDSleepStage = SchemaV11.SDSleepStage
typealias SDMoodEntry = SchemaV11.SDMoodEntry
typealias SDMeal = SchemaV11.SDMeal
typealias SDMealLog = SchemaV11.SDMeal  // Backward compatibility alias
typealias SDMealLogItem = SchemaV11.SDMealLogItem
typealias SDPhotoRecognition = SchemaV11.SDPhotoRecognition
typealias SDRecognizedFoodItem = SchemaV11.SDRecognizedFoodItem
typealias SDWorkout = SchemaV11.SDWorkout
typealias SDWorkoutTemplate = SchemaV11.SDWorkoutTemplate  // NEW: Workout template management
typealias SDTemplateExercise = SchemaV11.SDTemplateExercise  // NEW: Template exercises

/// Converter between metric and imperial units defined on the SDUserProfile
struct UnitConverter {

    // Helper to convert stored mass (kg) to display value (kg or lbs)
    static func displayMass(fromKg kg: Double, using system: UnitSystem) -> (
        value: Double, unit: String
    ) {
        let mass = Measurement(value: kg, unit: UnitMass.kilograms)

        switch system {
        case .metric:
            return (value: mass.value, unit: "kg")  // Already in kg
        case .imperial:
            let lbs = mass.converted(to: .pounds)
            // Round to a reasonable decimal place for display
            return (value: round(lbs.value * 10) / 10, unit: "lbs")
        }
    }

    // Helper to convert stored length (cm) to display value (cm or inches)
    static func displayLength(fromCm cm: Double, using system: UnitSystem) -> (
        value: Double, unit: String
    ) {
        let length = Measurement(value: cm, unit: UnitLength.centimeters)

        switch system {
        case .metric:
            // Display as meters for common usage (e.g., 1.75 m)
            let meters = length.converted(to: .meters)
            return (value: round(meters.value * 100) / 100, unit: "m")
        case .imperial:
            // Often displayed in total inches or feet and inches.
            // For simplicity here, we'll return total inches.
            let inches = length.converted(to: .inches)
            return (value: round(inches.value * 10) / 10, unit: "in")
        }
    }
}

extension SDActivitySnapshot {
    func toDomain() -> ActivitySnapshot {
        ActivitySnapshot(
            id: self.id,
            activeMinutes: self.activeMinutes,
            activityLevel: self.activityLevel,
            caloriesBurned: self.caloriesBurned,
            date: self.date,
            distanceKm: self.distanceKm,
            heartRateAvg: self.heartRateAvg,
            steps: self.steps,
            workoutDurationMinutes: self.workoutDurationMinutes,
            workoutSessions: self.workoutSessions,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            backendID: self.backendID,
        )
    }
}

// MARK: - Sleep Session Conversions

extension SDSleepSession {
    /// Convert SwiftData model to domain model
    func toDomain() -> SleepSession {
        SleepSession(
            id: self.id,
            userID: self.userProfile?.id.uuidString ?? "",
            date: self.date,
            startTime: self.startTime,
            endTime: self.endTime,
            timeInBedMinutes: self.timeInBedMinutes,
            totalSleepMinutes: self.totalSleepMinutes,
            sleepEfficiency: self.sleepEfficiency,
            source: self.source ?? "HealthKit",
            sourceID: self.sourceID,
            notes: self.notes,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            backendID: self.backendID,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .pending,
            stages: self.stages?.compactMap { $0.toDomain() } ?? []
        )
    }
}

extension SDSleepStage {
    /// Convert SwiftData model to domain model
    func toDomain() -> SleepStage? {
        guard let stageType = SleepStageType(rawValue: self.stage) else {
            return nil
        }
        return SleepStage(
            id: self.id,
            stage: stageType,
            startTime: self.startTime,
            endTime: self.endTime,
            durationMinutes: self.durationMinutes
        )
    }
}

// MARK: - Meal Log Conversions

extension SDMeal {
    /// Convert SwiftData model to domain model
    func toDomain() -> MealLog {
        let domainItems = self.items?.map { $0.toDomain() } ?? []
        let totalCalories =
            domainItems.isEmpty
            ? self.totalCalories : Int(domainItems.reduce(0) { $0 + $1.calories })

        return MealLog(
            id: self.id,
            userID: self.userProfile?.id.uuidString ?? "",
            rawInput: self.rawInput,
            mealType: MealType(rawValue: self.mealType) ?? .snack,
            status: MealLogStatus(rawValue: self.status) ?? .pending,
            loggedAt: self.loggedAt,
            items: domainItems,
            notes: self.notes,
            totalCalories: totalCalories,
            totalProteinG: self.totalProteinG,
            totalCarbsG: self.totalCarbsG,
            totalFatG: self.totalFatG,
            totalFiberG: self.totalFiberG,
            totalSugarG: self.totalSugarG,
            processingStartedAt: self.processingStartedAt,
            processingCompletedAt: self.processingCompletedAt,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            backendID: self.backendID,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .pending,
            errorMessage: self.errorMessage
        )
    }
}

extension SDMealLogItem {
    /// Convert SwiftData model to domain model
    func toDomain() -> MealLogItem {
        MealLogItem(
            id: self.id,
            mealLogID: self.mealLog?.id ?? UUID(),
            name: self.name,
            quantity: self.quantity ?? 0,
            unit: self.unit ?? "",
            calories: self.calories,
            protein: self.protein,
            carbs: self.carbs,
            fat: self.fat,
            foodType: FoodType(rawValue: self.foodType ?? "food") ?? .food,
            fiber: self.fiberG,
            sugar: self.sugarG,
            confidence: self.confidence,
            parsingNotes: self.parsingNotes,
            orderIndex: self.orderIndex,
            createdAt: self.createdAt,
            backendID: self.backendID
        )
    }
}

// MARK: - Photo Recognition Conversions

extension SDPhotoRecognition {
    /// Convert SwiftData model to domain model
    func toDomain() -> PhotoRecognition {
        // Calculate totals from recognized foods
        let recognizedFoods = self.recognizedFoods?.map { $0.toDomain() } ?? []
        let totalCalories =
            recognizedFoods.isEmpty ? nil : Int(recognizedFoods.reduce(0) { $0 + $1.calories })
        let totalProteinG =
            recognizedFoods.isEmpty ? nil : recognizedFoods.reduce(0.0) { $0 + $1.proteinG }
        let totalCarbsG =
            recognizedFoods.isEmpty ? nil : recognizedFoods.reduce(0.0) { $0 + $1.carbsG }
        let totalFatG = recognizedFoods.isEmpty ? nil : recognizedFoods.reduce(0.0) { $0 + $1.fatG }
        let totalFiberG =
            recognizedFoods.isEmpty ? nil : recognizedFoods.reduce(0.0) { $0 + ($1.fiberG ?? 0) }
        let totalSugarG =
            recognizedFoods.isEmpty ? nil : recognizedFoods.reduce(0.0) { $0 + ($1.sugarG ?? 0) }

        // Calculate average confidence
        let confidences = recognizedFoods.compactMap { $0.confidenceScore }
        let confidenceScore =
            confidences.isEmpty ? nil : confidences.reduce(0.0, +) / Double(confidences.count)

        return PhotoRecognition(
            id: self.id,
            userID: self.userProfile?.id.uuidString ?? "",
            imageURL: self.photoFileName ?? "",
            mealType: .snack,  // Default meal type
            status: PhotoRecognitionStatus(rawValue: self.status) ?? .pending,
            confidenceScore: confidenceScore,
            needsReview: (confidenceScore ?? 0) < 0.7,
            recognizedItems: recognizedFoods,
            totalCalories: totalCalories,
            totalProteinG: totalProteinG,
            totalCarbsG: totalCarbsG,
            totalFatG: totalFatG,
            totalFiberG: totalFiberG,
            totalSugarG: totalSugarG,
            loggedAt: self.createdAt,
            notes: nil,
            errorMessage: self.errorMessage,
            processingStartedAt: nil,
            processingCompletedAt: self.processedAt,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            backendID: self.backendID,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .pending,
            mealLogID: nil
        )
    }
}

extension SDRecognizedFoodItem {
    /// Convert SwiftData model to domain model
    func toDomain() -> PhotoRecognizedFoodItem {
        let confidenceScore = self.confidence ?? 0.5

        return PhotoRecognizedFoodItem(
            id: self.id,
            name: self.foodName,
            quantity: self.quantity ?? 1.0,
            unit: self.unit ?? "serving",
            calories: Int(self.calories),
            proteinG: self.proteinG,
            carbsG: self.carbsG,
            fatG: self.fatG,
            fiberG: self.fiberG,
            sugarG: self.sugarG,
            confidenceScore: confidenceScore,
            confidenceLevel: PhotoConfidenceLevel.fromScore(confidenceScore),
            orderIndex: self.orderIndex
        )
    }
}

// MARK: - Workout Conversions

extension SDWorkout {
    /// Convert SwiftData model to domain model
    func toDomain() -> WorkoutEntry {
        // Parse activity type from string to enum
        let activityTypeEnum = WorkoutActivityType(rawValue: self.activityType) ?? .other

        return WorkoutEntry(
            id: self.id,
            userID: self.userProfile?.id.uuidString ?? "",
            activityType: activityTypeEnum,
            title: self.title,
            notes: self.notes,
            startedAt: self.startedAt,
            endedAt: self.endedAt,
            durationMinutes: self.durationMinutes,
            caloriesBurned: self.caloriesBurned,
            distanceMeters: self.distanceMeters,
            intensity: self.intensity,
            source: self.source,
            sourceID: self.sourceID,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            backendID: self.backendID,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .pending
        )
    }
}
