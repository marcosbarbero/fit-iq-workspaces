//
//  SchemaV9.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Schema V9: Added SDPhotoRecognition for photo-based meal logging
//

import Foundation
import SwiftData

enum SchemaV9: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 9)

    // MARK: - Reuse Models from V8

    // MARK: - Reuse Models WITHOUT SDUserProfile relationships

    typealias SDOutboxEvent = SchemaV8.SDOutboxEvent

    // MARK: - Models WITH SDUserProfile relationships (must be redefined for V9)
    // Cannot reuse from V8 because they reference SchemaV8.SDUserProfile

    // MARK: - SDPhysicalAttribute (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDPhysicalAttribute {
        var id: UUID = UUID()
        var value: Double?
        var type: PhysicalAttributeType = PhysicalAttributeType.bodyMass
        var createdAt: Date = Date()
        var updatedAt: Date? = Date()
        var backendID: String?
        var backendSyncedAt: Date?

        @Relationship
        var userProfile: SDUserProfileV9?

        init(
            id: UUID = UUID(),
            value: Double?,
            type: PhysicalAttributeType,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,
            userProfile: SDUserProfileV9?
        ) {
            self.id = id
            self.value = value
            self.type = type
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.backendSyncedAt = backendSyncedAt
            self.userProfile = userProfile
        }
    }

    // MARK: - SDActivitySnapshot (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDActivitySnapshot {
        var id: UUID = UUID()
        var activeMinutes: Int?
        var activityLevel: ActivityLevel = ActivityLevel.sedentary
        var caloriesBurned: Double?
        var date: Date = Date()
        var distanceKm: Double?
        var heartRateAvg: Double?
        var steps: Int?
        var workoutDurationMinutes: Double?
        var workoutSessions: Int?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var backendSyncedAt: Date?

        @Relationship
        var userProfile: SDUserProfileV9?

        init(
            id: UUID = UUID(),
            activeMinutes: Int? = nil,
            activityLevel: ActivityLevel = .sedentary,
            caloriesBurned: Double? = nil,
            date: Date = Date(),
            distanceKm: Double? = nil,
            heartRateAvg: Double? = nil,
            steps: Int? = nil,
            workoutDurationMinutes: Double? = nil,
            workoutSessions: Int? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,
            userProfile: SDUserProfileV9? = nil
        ) {
            self.id = id
            self.activeMinutes = activeMinutes
            self.activityLevel = activityLevel
            self.caloriesBurned = caloriesBurned
            self.date = date
            self.distanceKm = distanceKm
            self.heartRateAvg = heartRateAvg
            self.steps = steps
            self.workoutDurationMinutes = workoutDurationMinutes
            self.workoutSessions = workoutSessions
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.backendSyncedAt = backendSyncedAt
            self.userProfile = userProfile
        }
    }

    // MARK: - SDProgressEntry (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDProgressEntry {
        var id: UUID = UUID()
        var type: String = ""
        var quantity: Double = 0.0
        var date: Date = Date()
        var time: String?
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"

        @Relationship
        var userProfile: SDUserProfileV9?

        init(
            id: UUID = UUID(),
            type: String,
            quantity: Double,
            date: Date,
            time: String? = nil,
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            userProfile: SDUserProfileV9? = nil
        ) {
            self.id = id
            self.type = type
            self.quantity = quantity
            self.date = date
            self.time = time
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.userProfile = userProfile
        }
    }

    // MARK: - SDDietaryAndActivityPreferences (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDDietaryAndActivityPreferences {
        var allergies: [String]?
        var dietaryRestrictions: [String]?
        var foodDislikes: [String]?
        var createdAt: Date = Date()
        var updatedAt: Date?

        @Relationship
        var userProfile: SDUserProfileV9?

        init(
            allergies: [String]? = nil,
            dietaryRestrictions: [String]? = nil,
            foodDislikes: [String]? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            userProfile: SDUserProfileV9? = nil
        ) {
            self.allergies = allergies
            self.dietaryRestrictions = dietaryRestrictions
            self.foodDislikes = foodDislikes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.userProfile = userProfile
        }
    }

    // MARK: - SDSleepStage (redefined for SchemaV9.SDSleepSession compatibility)

    @Model final class SDSleepStage {
        var id: UUID = UUID()
        var stage: String = ""
        var startTime: Date = Date()
        var endTime: Date = Date()
        var durationMinutes: Int = 0

        @Relationship
        var session: SDSleepSession?

        init(
            id: UUID = UUID(),
            stage: String,
            startTime: Date,
            endTime: Date,
            durationMinutes: Int,
            session: SDSleepSession? = nil
        ) {
            self.id = id
            self.stage = stage
            self.startTime = startTime
            self.endTime = endTime
            self.durationMinutes = durationMinutes
            self.session = session
        }
    }

    // MARK: - SDSleepSession (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDSleepSession {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfileV9?

        var date: Date = Date()
        var startTime: Date = Date()
        var endTime: Date = Date()
        var timeInBedMinutes: Int = 0
        var totalSleepMinutes: Int = 0
        var sleepEfficiency: Double = 0.0
        var source: String?
        var sourceID: String?
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"

        @Relationship(deleteRule: .cascade, inverse: \SDSleepStage.session)
        var stages: [SDSleepStage]? = []

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfileV9? = nil,
            date: Date,
            startTime: Date,
            endTime: Date,
            timeInBedMinutes: Int,
            totalSleepMinutes: Int,
            sleepEfficiency: Double,
            source: String? = nil,
            sourceID: String? = nil,
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            stages: [SDSleepStage]? = []
        ) {
            self.id = id
            self.userProfile = userProfile
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.timeInBedMinutes = timeInBedMinutes
            self.totalSleepMinutes = totalSleepMinutes
            self.sleepEfficiency = sleepEfficiency
            self.source = source
            self.sourceID = sourceID
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.stages = stages
        }
    }

    // MARK: - SDMoodEntry (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDMoodEntry {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfileV9?

        var valence: Double?
        var labels: [String] = []
        var associations: [String] = []
        var date: Date = Date()
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"
        var sourceID: String?

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfileV9? = nil,
            valence: Double?,
            labels: [String],
            associations: [String],
            date: Date = Date(),
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            sourceID: String? = nil
        ) {
            self.id = id
            self.userProfile = userProfile
            self.valence = valence
            self.labels = labels
            self.associations = associations
            self.date = date
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.sourceID = sourceID
        }
    }

    // MARK: - SDMealLogItem (redefined for SchemaV9 compatibility)

    @Model final class SDMealLogItem {
        var id: UUID = UUID()

        var mealLog: SDMeal?

        var name: String = ""
        var quantity: Double = 0.0
        var unit: String = ""
        var calories: Double = 0.0
        var protein: Double = 0.0
        var carbs: Double = 0.0
        var fat: Double = 0.0
        var foodType: String = "food"
        var fiberG: Double?
        var sugarG: Double?
        var confidence: Double?
        var parsingNotes: String?
        var orderIndex: Int = 0
        var createdAt: Date = Date()
        var backendID: String?

        init(
            id: UUID = UUID(),
            mealLog: SDMeal? = nil,
            name: String,
            quantity: Double,
            unit: String,
            calories: Double,
            protein: Double = 0.0,
            carbs: Double = 0.0,
            fat: Double = 0.0,
            foodType: String = "food",
            fiberG: Double? = nil,
            sugarG: Double? = nil,
            confidence: Double? = nil,
            parsingNotes: String? = nil,
            orderIndex: Int = 0,
            createdAt: Date = Date(),
            backendID: String? = nil
        ) {
            self.id = id
            self.mealLog = mealLog
            self.name = name
            self.quantity = quantity
            self.unit = unit
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.foodType = foodType
            self.fiberG = fiberG
            self.sugarG = sugarG
            self.confidence = confidence
            self.parsingNotes = parsingNotes
            self.orderIndex = orderIndex
            self.createdAt = createdAt
            self.backendID = backendID
        }
    }

    // MARK: - SDMeal (redefined for SchemaV9.SDUserProfileV9 compatibility)

    @Model final class SDMeal {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfileV9?

        var rawInput: String = ""
        var mealType: String = "snack"
        var status: String = "pending"
        var loggedAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \SDMealLogItem.mealLog)
        var items: [SDMealLogItem]? = []

        var notes: String?
        var totalCalories: Int?
        var totalProteinG: Double?
        var totalCarbsG: Double?
        var totalFatG: Double?
        var totalFiberG: Double?
        var totalSugarG: Double?
        var processingStartedAt: Date?
        var processingCompletedAt: Date?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"
        var errorMessage: String?

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfileV9? = nil,
            rawInput: String,
            mealType: String = "snack",
            status: String = "pending",
            loggedAt: Date = Date(),
            items: [SDMealLogItem]? = [],
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
            syncStatus: String = "pending",
            errorMessage: String? = nil
        ) {
            self.id = id
            self.userProfile = userProfile
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

    // MARK: - Photo Recognition Models (New in V9)

    /// SwiftData model for recognized food items from photo analysis
    @Model
    final class SDRecognizedFoodItem {
        var id: UUID = UUID()
        var name: String = ""
        var quantity: Double = 0.0
        var unit: String = ""
        var calories: Int = 0
        var proteinG: Double = 0.0
        var carbsG: Double = 0.0
        var fatG: Double = 0.0
        var fiberG: Double?
        var sugarG: Double?
        var confidenceScore: Double = 0.0
        var orderIndex: Int = 0

        // Relationship
        @Relationship(deleteRule: .nullify, inverse: \SDPhotoRecognition.recognizedItems)
        var photoRecognition: SDPhotoRecognition?

        init(
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
            orderIndex: Int,
            photoRecognition: SDPhotoRecognition? = nil
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
            self.orderIndex = orderIndex
            self.photoRecognition = photoRecognition
        }
    }

    /// SwiftData model for photo recognition entries
    @Model
    final class SDPhotoRecognition {
        var id: UUID = UUID()
        var userID: String = ""
        var imageURL: String?
        var mealType: String = "snack"
        var status: String = "pending"
        var confidenceScore: Double?
        var needsReview: Bool = true
        var totalCalories: Int?
        var totalProteinG: Double?
        var totalCarbsG: Double?
        var totalFatG: Double?
        var totalFiberG: Double?
        var totalSugarG: Double?
        var loggedAt: Date = Date()
        var notes: String?
        var errorMessage: String?
        var processingStartedAt: Date?
        var processingCompletedAt: Date?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"
        var mealLogID: UUID?

        // Relationships
        @Relationship(deleteRule: .cascade)
        var recognizedItems: [SDRecognizedFoodItem]?

        @Relationship
        var userProfile: SDUserProfileV9?

        init(
            id: UUID = UUID(),
            userID: String,
            imageURL: String? = nil,
            mealType: String,
            status: String = "pending",
            confidenceScore: Double? = nil,
            needsReview: Bool = true,
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
            syncStatus: String = "pending",
            mealLogID: UUID? = nil,
            recognizedItems: [SDRecognizedFoodItem]? = [],
            userProfile: SDUserProfileV9? = nil
        ) {
            self.id = id
            self.userID = userID
            self.imageURL = imageURL
            self.mealType = mealType
            self.status = status
            self.confidenceScore = confidenceScore
            self.needsReview = needsReview
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
            self.recognizedItems = recognizedItems
            self.userProfile = userProfile
        }
    }

    // MARK: - Updated SDUserProfile with photo recognitions

    @Model
    final class SDUserProfileV9 {
        var id: UUID = UUID()
        var name: String = ""
        var bio: String?
        var preferredUnitSystem: UnitSystem = UnitSystem.metric
        var languageCode: String?
        var dateOfBirth: Date?
        var biologicalSex: String?

        @Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
        var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?

        @Relationship(deleteRule: .cascade, inverse: \SDPhysicalAttribute.userProfile)
        var bodyMetrics: [SDPhysicalAttribute]?

        @Relationship(deleteRule: .cascade, inverse: \SDActivitySnapshot.userProfile)
        var activitySnapshots: [SDActivitySnapshot]?

        @Relationship(deleteRule: .cascade, inverse: \SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]?

        @Relationship(deleteRule: .cascade, inverse: \SDSleepSession.userProfile)
        var sleepSessions: [SDSleepSession]?

        @Relationship(deleteRule: .cascade, inverse: \SDMoodEntry.userProfile)
        var moodEntries: [SDMoodEntry]?

        @Relationship(deleteRule: .cascade, inverse: \SDMeal.userProfile)
        var mealLogs: [SDMeal]?

        @Relationship(deleteRule: .cascade, inverse: \SDPhotoRecognition.userProfile)
        var photoRecognitions: [SDPhotoRecognition]?

        var createdAt: Date = Date()
        var updatedAt: Date?

        var hasPerformedInitialHealthKitSync: Bool = false
        var lastSuccessfulDailySyncDate: Date?

        init(
            id: UUID = UUID(),
            name: String,
            bio: String?,
            preferredUnitSystem: UnitSystem = .metric,
            languageCode: String? = nil,
            dateOfBirth: Date? = nil,
            biologicalSex: String? = nil,
            dietaryAndActivityPreferences: SDDietaryAndActivityPreferences? = nil,
            bodyMetrics: [SDPhysicalAttribute]? = [],
            activitySnapshots: [SDActivitySnapshot]? = [],
            progressEntries: [SDProgressEntry]? = [],
            sleepSessions: [SDSleepSession]? = [],
            moodEntries: [SDMoodEntry]? = [],
            mealLogs: [SDMeal]? = [],
            photoRecognitions: [SDPhotoRecognition]? = [],
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            hasPerformedInitialHealthKitSync: Bool = false,
            lastSuccessfulDailySyncDate: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.bio = bio
            self.preferredUnitSystem = preferredUnitSystem
            self.languageCode = languageCode
            self.dateOfBirth = dateOfBirth
            self.biologicalSex = biologicalSex
            self.dietaryAndActivityPreferences = dietaryAndActivityPreferences
            self.bodyMetrics = bodyMetrics
            self.activitySnapshots = activitySnapshots
            self.progressEntries = progressEntries
            self.sleepSessions = sleepSessions
            self.moodEntries = moodEntries
            self.mealLogs = mealLogs
            self.photoRecognitions = photoRecognitions
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    // MARK: - Schema Models Array

    static var models: [any PersistentModel.Type] {
        [
            SDUserProfileV9.self,
            SDDietaryAndActivityPreferences.self,
            SDPhysicalAttribute.self,
            SDActivitySnapshot.self,
            SDProgressEntry.self,
            SDSleepSession.self,
            SDSleepStage.self,
            SDMoodEntry.self,
            SDMeal.self,
            SDMealLogItem.self,
            SDOutboxEvent.self,
            SDPhotoRecognition.self,
            SDRecognizedFoodItem.self,
        ]
    }
}
