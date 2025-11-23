//
//  SchemaV2.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Schema version 2: Adds SDProgressEntry for progress tracking
//

import Foundation
import SwiftData

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 2)

    // MARK: - SDUserProfile (modified - adds progressEntries relationship)

    @Model final class SDUserProfile {
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
        var bodyMetrics: [SDPhysicalAttribute]? = []

        @Relationship(deleteRule: .cascade, inverse: \SDActivitySnapshot.userProfile)
        var activitySnapshots: [SDActivitySnapshot]? = []

        @Relationship(deleteRule: .cascade, inverse: \SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]? = []

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
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    // MARK: - SDDietaryAndActivityPreferences (unchanged from V1)

    @Model final class SDDietaryAndActivityPreferences {
        var allergies: [String]?
        var dietaryRestrictions: [String]?
        var foodDislikes: [String]?
        var createdAt: Date = Date()
        var updatedAt: Date?

        @Relationship
        var userProfile: SDUserProfile?

        init(
            allergies: [String]? = nil,
            dietaryRestrictions: [String]? = nil,
            foodDislikes: [String]? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            userProfile: SDUserProfile?
        ) {
            self.allergies = allergies
            self.dietaryRestrictions = dietaryRestrictions
            self.foodDislikes = foodDislikes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.userProfile = userProfile
        }
    }

    // MARK: - SDPhysicalAttribute (unchanged from V1)

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

    // MARK: - SDActivitySnapshot (unchanged from V1)

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

    // MARK: - SDProgressEntry (NEW in V2)

    /// Progress entry for tracking various health and fitness metrics over time
    ///
    /// Supports local-first architecture with backend synchronization.
    /// Tracks metrics like steps, weight, height, calories, etc.
    @Model final class SDProgressEntry {
        /// Local UUID for the entry (primary identifier for local storage)
        var id: UUID = UUID()

        /// User ID who owns this entry (string to match backend format)
        var userID: String = ""

        /// Metric type (raw value of ProgressMetricType enum)
        /// Examples: "steps", "weight", "height", "body_fat_percentage", etc.
        var type: String = ""

        /// The measurement value (e.g., 10000 steps, 75.5 kg, 175 cm)
        var quantity: Double = 0.0

        /// The date of the measurement
        var date: Date = Date()

        /// Optional time of the measurement (HH:MM:SS format)
        var time: String?

        /// Optional notes about the measurement (max 500 characters)
        var notes: String?

        /// When this entry was created locally
        var createdAt: Date = Date()

        /// When this entry was last updated locally
        var updatedAt: Date?

        /// Backend-assigned ID (populated after successful sync)
        var backendID: String?

        /// Sync status (raw value of SyncStatus enum)
        /// Values: "pending", "syncing", "synced", "failed"
        var syncStatus: String = "pending"

        /// Relationship to user profile (optional, for filtering/queries)
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

    // MARK: - Schema Models

    static var models: [any PersistentModel.Type] {
        [
            SchemaV2.SDUserProfile.self,
            SchemaV2.SDDietaryAndActivityPreferences.self,
            SchemaV2.SDPhysicalAttribute.self,
            SchemaV2.SDActivitySnapshot.self,
            SchemaV2.SDProgressEntry.self,
        ]
    }
}
