//
//  SchemaV4.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Schema version 4: Adds SDSleepSession and SDSleepStage for sleep tracking
//

import Foundation
import SwiftData

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 4)

    // MARK: - Reuse V3 Models (unchanged)

    typealias SDDietaryAndActivityPreferences = SchemaV3.SDDietaryAndActivityPreferences
    typealias SDProgressEntry = SchemaV3.SDProgressEntry
    typealias SDOutboxEvent = SchemaV3.SDOutboxEvent
    
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

    // MARK: - SDUserProfile (modified - adds sleepSessions relationship)

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

        @Relationship(deleteRule: .cascade, inverse: \SDSleepSession.userProfile)
        var sleepSessions: [SDSleepSession]? = []

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
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    // MARK: - SDSleepSession (NEW in V4)

    /// Sleep session model for tracking sleep with detailed stage information
    ///
    /// Stores sleep sessions with start/end times, efficiency calculations,
    /// and optional stage-level tracking matching HealthKit values:
    /// (in_bed, asleep, awake, core, deep, rem)
    ///
    /// Supports:
    /// - HealthKit sync with deduplication via sourceID
    /// - Manual entry
    /// - Backend sync via Outbox Pattern to /api/v1/sleep
    /// - Sleep efficiency calculation
    @Model final class SDSleepSession {
        /// Local UUID for the sleep session
        var id: UUID = UUID()

        /// Relationship to the user profile who owns this sleep session
        var userProfile: SDUserProfile?

        /// User ID who owns this sleep session (for backward compatibility and queries)
        var userID: String = ""

        /// Date of the sleep session (derived from start_time, stored as date component only)
        var date: Date = Date()

        /// Sleep session start time (RFC3339)
        var startTime: Date = Date()

        /// Sleep session end time (RFC3339)
        var endTime: Date = Date()

        /// Total time in bed (minutes) - calculated
        var timeInBedMinutes: Int = 0

        /// Total sleep time excluding awake periods (minutes) - calculated
        var totalSleepMinutes: Int = 0

        /// Sleep efficiency percentage (sleep_time/time_in_bed * 100)
        var sleepEfficiency: Double = 0.0

        /// Data source (e.g., "healthkit", "manual")
        var source: String?

        /// External source identifier for deduplication (e.g., HealthKit UUID)
        var sourceID: String?

        /// Optional user notes
        var notes: String?

        /// When this session was created locally
        var createdAt: Date = Date()

        /// When this session was last updated locally
        var updatedAt: Date?

        /// Backend-assigned ID (populated after successful sync to /api/v1/sleep)
        var backendID: String?

        /// Sync status for Outbox Pattern: "pending", "synced", "failed"
        var syncStatus: String = "pending"

        /// Relationship to sleep stages (one-to-many)
        @Relationship(deleteRule: .cascade, inverse: \SDSleepStage.session)
        var stages: [SDSleepStage]?

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfile? = nil,
            userID: String,
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
            self.userID = userID
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

    // MARK: - SDSleepStage (NEW in V4)

    /// Individual sleep stage within a sleep session
    ///
    /// Represents a single sleep stage period with start/end times.
    /// Stage types match HealthKit HKCategoryValueSleepAnalysis:
    /// - in_bed: User is in bed but may not be asleep
    /// - asleep: Generic asleep (unspecified stage)
    /// - awake: User is awake during sleep session
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

    // MARK: - Schema Models

    static var models: [any PersistentModel.Type] {
        [
            SchemaV4.SDUserProfile.self,
            SchemaV4.SDDietaryAndActivityPreferences.self,
            SchemaV4.SDPhysicalAttribute.self,
            SchemaV4.SDActivitySnapshot.self,
            SchemaV4.SDProgressEntry.self,
            SchemaV4.SDOutboxEvent.self,
            SchemaV4.SDSleepSession.self,  // NEW in V4
            SchemaV4.SDSleepStage.self,  // NEW in V4
        ]
    }
}
