//
//  SchemaV10.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Schema V10: Added SDWorkout for workout tracking with HealthKit integration
//

import Foundation
import SwiftData

enum SchemaV10: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 0)

    // MARK: - Reuse Models from V9 WITHOUT SDUserProfile relationships

    typealias SDOutboxEvent = SchemaV9.SDOutboxEvent

    // MARK: - Reuse Models from V9 WITH SDUserProfile relationships
    // These need to be redefined to reference SDUserProfileV10

    // MARK: - SDPhysicalAttribute (redefined for SchemaV10.SDUserProfileV10 compatibility)

    @Model final class SDPhysicalAttribute {
        var id: UUID = UUID()
        var value: Double?
        var type: PhysicalAttributeType = PhysicalAttributeType.bodyMass
        var createdAt: Date = Date()
        var updatedAt: Date? = Date()
        var backendID: String?
        var backendSyncedAt: Date?

        @Relationship
        var userProfile: SDUserProfileV10?

        init(
            id: UUID = UUID(),
            value: Double?,
            type: PhysicalAttributeType,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,
            userProfile: SDUserProfileV10?
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

    // MARK: - SDActivitySnapshot (redefined for SchemaV10.SDUserProfileV10 compatibility)

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
        var userProfile: SDUserProfileV10?

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
            userProfile: SDUserProfileV10? = nil
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

    // MARK: - SDProgressEntry (redefined for SchemaV10.SDUserProfileV10 compatibility)

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
        var userProfile: SDUserProfileV10?

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
            userProfile: SDUserProfileV10? = nil
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

    // MARK: - SDSleepSession (redefined for SchemaV10.SDUserProfileV10 compatibility)

    @Model final class SDSleepSession {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfileV10?

        var date: Date = Date()  // Wake date (for attribution and sorting)
        var startTime: Date = Date()  // Actual sleep start time
        var endTime: Date = Date()  // Actual sleep end time
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

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDSleepStage.session)
        var stages: [SDSleepStage]? = []

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfileV10? = nil,
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
            self.stages = stages ?? []
        }
    }

    // MARK: - SDSleepStage (redefined for SchemaV10 compatibility)

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

    // MARK: - SDMoodEntry (redefined for SchemaV10.SDUserProfileV10 compatibility)

    @Model final class SDMoodEntry {
        var id: UUID = UUID()
        var value: Int = 5
        var date: Date = Date()
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"

        @Relationship
        var userProfile: SDUserProfileV10?

        init(
            id: UUID = UUID(),
            value: Int,
            date: Date,
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            userProfile: SDUserProfileV10? = nil
        ) {
            self.id = id
            self.value = value
            self.date = date
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.userProfile = userProfile
        }
    }

    // MARK: - SDMeal (redefined for SchemaV10.SDUserProfileV10 compatibility)

    @Model final class SDMeal {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfileV10?

        var rawInput: String = ""
        var mealType: String = "snack"
        var status: String = "pending"
        var loggedAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDMealLogItem.mealLog)
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
            userProfile: SDUserProfileV10? = nil,
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

    // MARK: - SDMealLogItem (redefined for SchemaV10 compatibility)

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

    // MARK: - SDPhotoRecognition (redefined for SchemaV10.SDUserProfileV10 compatibility)

    @Model final class SDPhotoRecognition {
        var id: UUID = UUID()
        var status: String = "pending"
        var createdAt: Date = Date()
        var updatedAt: Date?
        var processedAt: Date?
        var errorMessage: String?
        var backendID: String?
        var syncStatus: String = "pending"
        var photoFileName: String?
        var rawResponse: String?

        @Relationship(
            deleteRule: .cascade, inverse: \SchemaV10.SDRecognizedFoodItem.photoRecognition)
        var recognizedFoods: [SDRecognizedFoodItem]? = []

        @Relationship
        var userProfile: SDUserProfileV10?

        init(
            id: UUID = UUID(),
            status: String = "pending",
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            processedAt: Date? = nil,
            errorMessage: String? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            photoFileName: String? = nil,
            rawResponse: String? = nil,
            recognizedFoods: [SDRecognizedFoodItem]? = [],
            userProfile: SDUserProfileV10? = nil
        ) {
            self.id = id
            self.status = status
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.processedAt = processedAt
            self.errorMessage = errorMessage
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.photoFileName = photoFileName
            self.rawResponse = rawResponse
            self.recognizedFoods = recognizedFoods
            self.userProfile = userProfile
        }
    }

    // MARK: - SDRecognizedFoodItem (redefined for SchemaV10 compatibility)

    @Model final class SDRecognizedFoodItem {
        var id: UUID = UUID()
        var foodName: String = ""
        var quantity: Double?
        var unit: String?
        var calories: Double = 0
        var proteinG: Double = 0
        var carbsG: Double = 0
        var fatG: Double = 0
        var fiberG: Double?
        var sugarG: Double?
        var confidence: Double?
        var orderIndex: Int = 0
        var createdAt: Date = Date()

        @Relationship
        var photoRecognition: SDPhotoRecognition?

        init(
            id: UUID = UUID(),
            foodName: String,
            quantity: Double? = nil,
            unit: String? = nil,
            calories: Double = 0,
            proteinG: Double = 0,
            carbsG: Double = 0,
            fatG: Double = 0,
            fiberG: Double? = nil,
            sugarG: Double? = nil,
            confidence: Double? = nil,
            orderIndex: Int = 0,
            createdAt: Date = Date(),
            photoRecognition: SDPhotoRecognition? = nil
        ) {
            self.id = id
            self.foodName = foodName
            self.quantity = quantity
            self.unit = unit
            self.calories = calories
            self.proteinG = proteinG
            self.carbsG = carbsG
            self.fatG = fatG
            self.fiberG = fiberG
            self.sugarG = sugarG
            self.confidence = confidence
            self.orderIndex = orderIndex
            self.createdAt = createdAt
            self.photoRecognition = photoRecognition
        }
    }

    // MARK: - NEW: SDWorkout model

    @Model final class SDWorkout {
        var id: UUID = UUID()
        var activityType: String = ""
        var title: String?
        var notes: String?
        var startedAt: Date = Date()
        var endedAt: Date?
        var durationMinutes: Int?
        var caloriesBurned: Int?
        var distanceMeters: Double?
        var intensity: Int?
        var source: String = "HealthKit"
        var sourceID: String?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var syncStatus: String = "pending"

        @Relationship
        var userProfile: SDUserProfileV10?

        init(
            id: UUID = UUID(),
            activityType: String,
            title: String? = nil,
            notes: String? = nil,
            startedAt: Date,
            endedAt: Date? = nil,
            durationMinutes: Int? = nil,
            caloriesBurned: Int? = nil,
            distanceMeters: Double? = nil,
            intensity: Int? = nil,
            source: String = "HealthKit",
            sourceID: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            userProfile: SDUserProfileV10? = nil
        ) {
            self.id = id
            self.activityType = activityType
            self.title = title
            self.notes = notes
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationMinutes = durationMinutes
            self.caloriesBurned = caloriesBurned
            self.distanceMeters = distanceMeters
            self.intensity = intensity
            self.source = source
            self.sourceID = sourceID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.userProfile = userProfile
        }
    }

    // MARK: - SDDietaryAndActivityPreferences (redefined for SchemaV10.SDUserProfileV10 compatibility)

    @Model final class SDDietaryAndActivityPreferences {
        var allergies: [String]?
        var dietaryRestrictions: [String]?
        var foodDislikes: [String]?
        var createdAt: Date = Date()
        var updatedAt: Date?

        @Relationship
        var userProfile: SDUserProfileV10?

        init(
            allergies: [String]? = nil,
            dietaryRestrictions: [String]? = nil,
            foodDislikes: [String]? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            userProfile: SDUserProfileV10? = nil
        ) {
            self.allergies = allergies
            self.dietaryRestrictions = dietaryRestrictions
            self.foodDislikes = foodDislikes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.userProfile = userProfile
        }
    }

    // MARK: - SDUserProfileV10 (updated to include workouts relationship)

    @Model final class SDUserProfileV10 {
        var id: UUID = UUID()
        var name: String = ""
        var email: String = ""
        var authToken: String?
        var refreshToken: String?
        var tokenExpiresAt: Date?
        var refreshTokenExpiresAt: Date?
        var dailyCalorieGoal: Double?
        var unitSystem: String = "metric"
        var dateOfBirth: Date?
        var biologicalSex: String?

        @Relationship(
            deleteRule: .cascade, inverse: \SchemaV10.SDDietaryAndActivityPreferences.userProfile)
        var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDPhysicalAttribute.userProfile)
        var bodyMetrics: [SDPhysicalAttribute]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDActivitySnapshot.userProfile)
        var activitySnapshots: [SDActivitySnapshot]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDSleepSession.userProfile)
        var sleepSessions: [SDSleepSession]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDMoodEntry.userProfile)
        var moodEntries: [SDMoodEntry]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDMeal.userProfile)
        var mealLogs: [SDMeal]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDPhotoRecognition.userProfile)
        var photoRecognitions: [SDPhotoRecognition]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDWorkout.userProfile)
        var workouts: [SDWorkout]? = []

        var createdAt: Date = Date()
        var updatedAt: Date?
        var hasPerformedInitialHealthKitSync: Bool = false
        var lastSuccessfulDailySyncDate: Date?

        init(
            id: UUID = UUID(),
            name: String,
            email: String,
            authToken: String? = nil,
            refreshToken: String? = nil,
            tokenExpiresAt: Date? = nil,
            refreshTokenExpiresAt: Date? = nil,
            dailyCalorieGoal: Double? = nil,
            unitSystem: String = "metric",
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
            workouts: [SDWorkout]? = [],
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            hasPerformedInitialHealthKitSync: Bool = false,
            lastSuccessfulDailySyncDate: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.authToken = authToken
            self.refreshToken = refreshToken
            self.tokenExpiresAt = tokenExpiresAt
            self.refreshTokenExpiresAt = refreshTokenExpiresAt
            self.dailyCalorieGoal = dailyCalorieGoal
            self.unitSystem = unitSystem
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
            self.workouts = workouts
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    // MARK: - Schema Models Array

    static var models: [any PersistentModel.Type] {
        [
            SDUserProfileV10.self,
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
            SDWorkout.self,  // NEW: Added workout model
        ]
    }
}
