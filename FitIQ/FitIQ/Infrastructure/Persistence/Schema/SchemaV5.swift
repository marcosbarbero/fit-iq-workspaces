//
//  SchemaV5.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Schema version 5: Adds SDMoodEntry for HKStateOfMind mood tracking.
//

import Foundation
import SwiftData

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 5)

    // MARK: - Reuse V4 Models (unchanged)

    typealias SDDietaryAndActivityPreferences = SchemaV4.SDDietaryAndActivityPreferences
    typealias SDPhysicalAttribute = SchemaV4.SDPhysicalAttribute
    typealias SDActivitySnapshot = SchemaV4.SDActivitySnapshot
    typealias SDProgressEntry = SchemaV4.SDProgressEntry
    typealias SDOutboxEvent = SchemaV4.SDOutboxEvent
    typealias SDSleepSession = SchemaV4.SDSleepSession
    typealias SDSleepStage = SchemaV4.SDSleepStage

    // MARK: - SDUserProfile (modified - adds moodEntries relationship)

    @Model final class SDUserProfile {
        var id: UUID = UUID()
        var name: String = ""
        var bio: String?
        var preferredUnitSystem: UnitSystem = UnitSystem.metric
        var languageCode: String?
        var dateOfBirth: Date?
        var biologicalSex: String?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SDDietaryAndActivityPreferences.userProfile)
        var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SDPhysicalAttribute.userProfile)
        var bodyMetrics: [SDPhysicalAttribute]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SDActivitySnapshot.userProfile)
        var activitySnapshots: [SDActivitySnapshot]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SDSleepSession.userProfile)
        var sleepSessions: [SDSleepSession]? = []

        @Relationship(deleteRule: .cascade, inverse: \SchemaV5.SDMoodEntry.userProfile)
        var moodEntries: [SDMoodEntry]? = []  // NEW in V5: Mood entries

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
            moodEntries: [SDMoodEntry]? = [],  // NEW in V5: Mood entries
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
            self.moodEntries = moodEntries  // NEW in V5: Mood entries
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    // MARK: - SDMoodEntry (NEW in V5)

    /// Mood entry model for tracking HKStateOfMind data.
    ///
    /// Stores mood data including valence, labels, associations, and notes.
    /// Supports:
    /// - HealthKit sync (HKStateOfMind) with deduplication via sourceID
    /// - Manual entry
    /// - Backend sync via Outbox Pattern to /api/v1/mood
    @Model final class SDMoodEntry {
        /// Local UUID for the mood entry
        var id: UUID = UUID()

        /// Relationship to the user profile who owns this mood entry
        @Relationship
        var userProfile: SDUserProfile?

        /// User ID who owns this mood entry (for backward compatibility and queries)
        var userID: String = ""

        /// The continuous scale for pleasantness (-1.0 to +1.0)
        var valence: Double?

        /// Array of labels describing the mood (e.g., "happy", "stressed")
        var labels: [String] = []

        /// Array of associations related to the mood (e.g., "work", "family", "exercise")
        var associations: [String] = []

        /// Date of the mood entry
        var date: Date = Date()

        /// Optional user notes
        var notes: String?

        /// When this entry was created locally
        var createdAt: Date = Date()

        /// When this entry was last updated locally
        var updatedAt: Date?

        /// Backend-assigned ID (populated after successful sync to /api/v1/mood)
        var backendID: String?

        /// Sync status for Outbox Pattern: "pending", "synced", "failed"
        var syncStatus: String = "pending"

        /// External source identifier for deduplication (e.g., HealthKit UUID)
        var sourceID: String?

        init(
            id: UUID = UUID(),
            userProfile: SDUserProfile? = nil,
            userID: String,
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
            self.userID = userID
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

    // MARK: - Schema Models

    static var models: [any PersistentModel.Type] {
        [
            SchemaV5.SDUserProfile.self,
            SchemaV5.SDDietaryAndActivityPreferences.self,
            SchemaV5.SDPhysicalAttribute.self,
            SchemaV5.SDActivitySnapshot.self,
            SchemaV5.SDProgressEntry.self,
            SchemaV5.SDOutboxEvent.self,
            SchemaV5.SDSleepSession.self,
            SchemaV5.SDSleepStage.self,
            SchemaV5.SDMoodEntry.self,  // NEW in V5
        ]
    }
}
