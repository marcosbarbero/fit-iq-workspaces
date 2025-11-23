//  SchemaV6.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Schema version 6: Adds SDMeal and SDMealLogItem for nutrition logging
//

import Foundation
import SwiftData

enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 6)

    // MARK: - Reuse V5 Models (unchanged)

    typealias SDDietaryAndActivityPreferences = SchemaV5.SDDietaryAndActivityPreferences
    typealias SDOutboxEvent = SchemaV5.SDOutboxEvent

    // MARK: - SDPhysicalAttribute (redefined to use V6 SDUserProfile relationship)

    @Model final class SDPhysicalAttribute {
        var id: UUID = UUID()

        var value: Double?
        var type: PhysicalAttributeType = PhysicalAttributeType.bodyMass

        var createdAt: Date = Date()
        var updatedAt: Date?

        var backendID: String?
        var backendSyncedAt: Date?

        @Relationship
        var userProfile: SDUserProfile?

        init(
            id: UUID = UUID(),
            value: Double?,
            type: PhysicalAttributeType,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,
            userProfile: SDUserProfile?
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

    // MARK: - SDActivitySnapshot (redefined to use V6 SDUserProfile relationship)

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
        var userProfile: SDUserProfile?

        init(
            id: UUID = UUID(),
            activeMinutes: Int? = nil,
            activityLevel: ActivityLevel,
            caloriesBurned: Double? = nil,
            date: Date,
            distanceKm: Double? = nil,
            heartRateAvg: Double? = nil,
            steps: Int? = nil,
            workoutDurationMinutes: Double? = nil,
            workoutSessions: Int? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,
            userProfile: SDUserProfile?
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

    // MARK: - SDProgressEntry (redefined to use V6 SDUserProfile relationship)

    @Model final class SDProgressEntry {
        var id: UUID = UUID()
        var userID: String = ""
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
        var userProfile: SDUserProfile?

        init(
            id: UUID = UUID(),
            userID: String,
            type: String,
            quantity: Double,
            date: Date,
            time: String? = nil,
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: String = "pending",
            userProfile: SDUserProfile? = nil
        ) {
            self.id = id
            self.userID = userID
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

    // MARK: - SDSleepStage (redefined to use V6 SDSleepSession relationship)

    /// Sleep stage model for tracking sleep quality stages
    ///
    /// Represents individual sleep stages within a sleep session:
    /// - in_bed: Time in bed (awake)
    /// - asleep: Unspecified sleep (core sleep if no detailed stages)
    /// - awake: Awake during sleep session
    /// - core: Core/light sleep (asleepCore in HealthKit)
    /// - deep: Deep sleep (asleepDeep in HealthKit)
    /// - rem: REM sleep (asleepREM in HealthKit)
    @Model final class SDSleepStage {
        /// Local UUID for the stage
        var id: UUID = UUID()

        /// Sleep stage type: "in_bed", "asleep", "awake", "core", "deep", "rem"
        /// Maps to HealthKit HKCategoryValueSleepAnalysis values
        var stage: String = ""

        /// Stage start time (RFC3339)
        var startTime: Date = Date()

        /// Stage end time (RFC3339)
        var endTime: Date = Date()

        /// Duration in minutes (calculated)
        var durationMinutes: Int = 0

        /// Parent sleep session (inverse relationship)
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

    // MARK: - SDSleepSession (redefined to use V6 SDUserProfile relationship)

    @Model final class SDSleepSession {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfile?
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
            userProfile: SDUserProfile? = nil,
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
            stages: [SDSleepStage]? = nil
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

    // MARK: - SDMoodEntry (redefined to use V6 SDUserProfile relationship)

    @Model final class SDMoodEntry {
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfile?
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
            userProfile: SDUserProfile? = nil,
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

    // MARK: - SDMeal (formerly SDMealLog)

    /// Meal log model for tracking nutrition via natural language input
    ///
    /// Stores meal logging data including raw input, parsed items, and sync status.
    /// Supports:
    /// - Natural language meal logging via /api/v1/meal-logs/natural
    /// - WebSocket real-time status updates
    /// - Backend sync via Outbox Pattern
    /// - Local-first storage with offline capability
    @Model final class SDMeal {
        /// Local UUID for the meal log
        var id: UUID = UUID()

        @Relationship
        var userProfile: SDUserProfile?

        /// Raw natural language input from the user
        var rawInput: String = ""

        /// Meal type (breakfast, lunch, dinner, snack, etc.)
        var mealType: MealType = MealType.other

        /// Processing status from backend (pending, processing, completed, failed)
        var status: MealLogStatus = MealLogStatus.pending

        /// Date/time when the meal was consumed
        var loggedAt: Date = Date()

        /// Parsed meal items (populated after processing completes)
        @Relationship(deleteRule: .cascade, inverse: \SDMealLogItem.mealLog)
        var items: [SDMealLogItem]? = []

        /// Optional notes from user
        var notes: String?

        /// When this entry was created locally
        var createdAt: Date = Date()

        /// When this entry was last updated
        var updatedAt: Date?

        /// Backend-assigned ID (populated after successful sync to /api/v1/meal-logs/natural)
        var backendID: String?

        /// Sync status for Outbox Pattern: pending, syncing, synced, failed
        var syncStatus: SyncStatus = SyncStatus.pending

        /// Optional error message if processing failed
        var errorMessage: String?

        /// Total calories for the entire meal (calculated from items or parsed)
        var totalCalories: Int?
        /// Total protein in grams for the entire meal (calculated from items or parsed)
        var totalProteinG: Double?
        /// Total carbohydrates in grams for the entire meal (calculated from items or parsed)
        var totalCarbsG: Double?
        /// Total fat in grams for the entire meal (calculated from items or parsed)
        var totalFatG: Double?
        /// Total fiber in grams for the entire meal
        var totalFiberG: Double?
        /// Total sugar in grams for the entire meal
        var totalSugarG: Double?
        /// Timestamp when backend processing of the meal log started
        var processingStartedAt: Date?
        /// Timestamp when backend processing of the meal log completed
        var processingCompletedAt: Date?

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfile? = nil,
            rawInput: String,
            mealType: MealType,
            status: MealLogStatus = .pending,
            loggedAt: Date = Date(),
            items: [SDMealLogItem]? = [],
            notes: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = nil,
            backendID: String? = nil,
            syncStatus: SyncStatus = .pending,
            errorMessage: String? = nil,
            totalCalories: Int? = nil,
            totalProteinG: Double? = nil,
            totalCarbsG: Double? = nil,
            totalFatG: Double? = nil,
            totalFiberG: Double? = nil,
            totalSugarG: Double? = nil,
            processingStartedAt: Date? = nil,
            processingCompletedAt: Date? = nil
        ) {
            self.id = id
            self.userProfile = userProfile
            self.rawInput = rawInput
            self.mealType = mealType
            self.status = status
            self.loggedAt = loggedAt
            self.items = items
            self.notes = notes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.syncStatus = syncStatus
            self.errorMessage = errorMessage
            self.totalCalories = totalCalories
            self.totalProteinG = totalProteinG
            self.totalCarbsG = totalCarbsG
            self.totalFatG = totalFatG
            self.totalFiberG = totalFiberG
            self.totalSugarG = totalSugarG
            self.processingStartedAt = processingStartedAt
            self.processingCompletedAt = processingCompletedAt
        }
    }

    // MARK: - SDMealLogItem (NEW in V6)

    /// Meal log item model for individual food items parsed from meal logs
    ///
    /// Represents a single food item extracted from the meal log's natural language input.
    /// Contains nutritional information parsed by the backend AI.
    @Model final class SDMealLogItem {
        /// Local UUID for the meal log item
        var id: UUID = UUID()

        /// Relationship to the parent meal log
        var mealLog: SDMeal?

        /// Name of the food item
        var name: String = ""

        /// Quantity/serving size (e.g., "100g", "1 cup", "2 slices")
        var quantity: String = ""

        /// Calories in kcal
        var calories: Double = 0.0

        /// Protein in grams
        var protein: Double = 0.0

        /// Carbohydrates in grams
        var carbs: Double = 0.0

        /// Fat in grams
        var fat: Double = 0.0

        /// Fiber in grams (optional)
        var fiberG: Double?
        /// Sugar in grams (optional)
        var sugarG: Double?

        /// Confidence score from AI parsing (0.0 to 1.0)
        var confidence: Double?

        /// Any notes from the parsing process for this specific item
        var parsingNotes: String?

        /// Order index for displaying items as they appeared in the original input
        var orderIndex: Int = 0

        /// When this item was created
        var createdAt: Date = Date()

        /// Backend-assigned ID (populated after successful sync)
        var backendID: String?

        init(
            id: UUID = UUID(),
            mealLog: SDMeal? = nil,
            name: String,
            quantity: String,
            calories: Double,
            protein: Double,
            carbs: Double,
            fat: Double,
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
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.fiberG = fiberG
            self.sugarG = sugarG
            self.confidence = confidence
            self.parsingNotes = parsingNotes
            self.orderIndex = orderIndex
            self.createdAt = createdAt
            self.backendID = backendID
        }
    }

    // MARK: - SDUserProfile (modified - adds mealLogs relationship)

    @Model final class SDUserProfile {
        var id: UUID = UUID()
        var name: String = ""
        var bio: String?
        var preferredUnitSystem: UnitSystem = UnitSystem.metric
        var languageCode: String?
        var dateOfBirth: Date?
        var biologicalSex: String?

        @Relationship(
            deleteRule: .cascade, inverse: \SchemaV6.SDDietaryAndActivityPreferences.userProfile)
        var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.SDPhysicalAttribute.userProfile)
        var bodyMetrics: [SDPhysicalAttribute]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.SDActivitySnapshot.userProfile)
        var activitySnapshots: [SDActivitySnapshot]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.SDSleepSession.userProfile)
        var sleepSessions: [SDSleepSession]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.SDMoodEntry.userProfile)
        var moodEntries: [SDMoodEntry]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.SDMeal.userProfile)
        var mealLogs: [SDMeal]? = []  // NEW in V6: Meal logs

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
            mealLogs: [SDMeal]? = [],  // NEW in V6: Meal logs
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
            self.mealLogs = mealLogs  // NEW in V6: Meal logs
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    // MARK: - Schema Models

    static var models: [any PersistentModel.Type] {
        [
            SchemaV6.SDUserProfile.self,
            SchemaV6.SDDietaryAndActivityPreferences.self,
            SchemaV6.SDPhysicalAttribute.self,  // Redefined in V6 for relationship compatibility
            SchemaV6.SDActivitySnapshot.self,  // Redefined in V6 for relationship compatibility
            SchemaV6.SDProgressEntry.self,  // Redefined in V6 for relationship compatibility
            SchemaV6.SDOutboxEvent.self,
            SchemaV6.SDSleepSession.self,  // Redefined in V6 for relationship compatibility
            SchemaV6.SDSleepStage.self,
            SchemaV6.SDMoodEntry.self,  // Redefined in V6 for relationship compatibility
            SchemaV6.SDMeal.self,  // Renamed from SDMealLog
            SchemaV6.SDMealLogItem.self,  // NEW in V6
        ]
    }
}
