//
//  SchemaVersioning.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import Foundation
import SwiftData

/// Schema versioning for SwiftData models
/// This ensures safe migrations when models change over time
enum SchemaVersioning {

    /// Current schema version
    static let current = SchemaV7.self

    /// Version 1: Initial schema with basic mood tracking
    /// - SDOutboxEvent: For outbox pattern implementation
    /// - SDMoodEntry: Basic mood tracking
    /// - SDJournalEntry: Journal entries
    enum SchemaV1: VersionedSchema {
        static var versionIdentifier = Schema.Version(1, 0, 0)

        static var models: [any PersistentModel.Type] {
            [SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self]
        }

        @Model
        final class SDOutboxEvent {
            var id: UUID
            var createdAt: Date
            var eventType: String
            var payload: Data
            var status: String
            var retryCount: Int
            var lastAttemptAt: Date?
            var completedAt: Date?
            var errorMessage: String?

            init(
                id: UUID = UUID(),
                createdAt: Date = Date(),
                eventType: String,
                payload: Data,
                status: String = "pending",
                retryCount: Int = 0,
                lastAttemptAt: Date? = nil,
                completedAt: Date? = nil,
                errorMessage: String? = nil
            ) {
                self.id = id
                self.createdAt = createdAt
                self.eventType = eventType
                self.payload = payload
                self.status = status
                self.retryCount = retryCount
                self.lastAttemptAt = lastAttemptAt
                self.completedAt = completedAt
                self.errorMessage = errorMessage
            }
        }

        @Model
        final class SDMoodEntry {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var date: Date
            var valence: Double
            var labels: [String]
            var associations: [String]
            var notes: String?
            var source: String
            var sourceId: String?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                date: Date,
                valence: Double,
                labels: [String] = [],
                associations: [String] = [],
                notes: String? = nil,
                source: String = "manual",
                sourceId: String? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.date = date
                self.valence = max(-1.0, min(1.0, valence))
                self.labels = labels
                self.associations = associations
                self.notes = notes
                self.source = source
                self.sourceId = sourceId
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDJournalEntry {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var date: Date
            var title: String?
            var content: String
            var tags: [String]
            var entryType: String
            var isFavorite: Bool
            var linkedMoodId: UUID?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                date: Date,
                title: String? = nil,
                content: String,
                tags: [String] = [],
                entryType: String = "general",
                isFavorite: Bool = false,
                linkedMoodId: UUID? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.date = date
                self.title = title
                self.content = content
                self.tags = tags
                self.entryType = entryType
                self.isFavorite = isFavorite
                self.linkedMoodId = linkedMoodId
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }
    }

    /// Version 2: Add statistics tracking
    /// - SDStatistics: For tracking user statistics
    enum SchemaV2: VersionedSchema {
        static var versionIdentifier = Schema.Version(2, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self,
                SDStatistics.self,
            ]
        }

        @Model
        final class SDOutboxEvent {
            var id: UUID
            var createdAt: Date
            var eventType: String
            var payload: Data
            var status: String
            var retryCount: Int
            var lastAttemptAt: Date?
            var completedAt: Date?
            var errorMessage: String?

            init(
                id: UUID = UUID(),
                createdAt: Date = Date(),
                eventType: String,
                payload: Data,
                status: String = "pending",
                retryCount: Int = 0,
                lastAttemptAt: Date? = nil,
                completedAt: Date? = nil,
                errorMessage: String? = nil
            ) {
                self.id = id
                self.createdAt = createdAt
                self.eventType = eventType
                self.payload = payload
                self.status = status
                self.retryCount = retryCount
                self.lastAttemptAt = lastAttemptAt
                self.completedAt = completedAt
                self.errorMessage = errorMessage
            }
        }

        @Model
        final class SDMoodEntry {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var date: Date
            var valence: Double
            var labels: [String]
            var associations: [String]
            var notes: String?
            var source: String
            var sourceId: String?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                date: Date,
                valence: Double,
                labels: [String] = [],
                associations: [String] = [],
                notes: String? = nil,
                source: String = "manual",
                sourceId: String? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.date = date
                self.valence = max(-1.0, min(1.0, valence))
                self.labels = labels
                self.associations = associations
                self.notes = notes
                self.source = source
                self.sourceId = sourceId
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDJournalEntry {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var date: Date
            var title: String?
            var content: String
            var tags: [String]
            var entryType: String
            var isFavorite: Bool
            var linkedMoodId: UUID?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                date: Date,
                title: String? = nil,
                content: String,
                tags: [String] = [],
                entryType: String = "general",
                isFavorite: Bool = false,
                linkedMoodId: UUID? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.date = date
                self.title = title
                self.content = content
                self.tags = tags
                self.entryType = entryType
                self.isFavorite = isFavorite
                self.linkedMoodId = linkedMoodId
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDStatistics {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var statisticsType: String
            var data: Data
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                statisticsType: String,
                data: Data,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.statisticsType = statisticsType
                self.data = data
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }
    }

    /// Version 3: Add AI features (Insights, Goals, Chat)
    /// - SDAIInsight: AI-generated insights
    /// - SDGoal: User goals with AI integration
    /// - SDChatConversation: Chat conversation metadata
    /// - SDChatMessage: Chat messages
    enum SchemaV3: VersionedSchema {
        static var versionIdentifier = Schema.Version(3, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self,
                SDStatistics.self, SDAIInsight.self, SDGoal.self,
                SDChatConversation.self, SDChatMessage.self,
            ]
        }

        @Model
        final class SDOutboxEvent {
            var id: UUID
            var createdAt: Date
            var eventType: String
            var payload: Data
            var status: String
            var retryCount: Int
            var lastAttemptAt: Date?
            var completedAt: Date?
            var errorMessage: String?

            init(
                id: UUID = UUID(),
                createdAt: Date = Date(),
                eventType: String,
                payload: Data,
                status: String = "pending",
                retryCount: Int = 0,
                lastAttemptAt: Date? = nil,
                completedAt: Date? = nil,
                errorMessage: String? = nil
            ) {
                self.id = id
                self.createdAt = createdAt
                self.eventType = eventType
                self.payload = payload
                self.status = status
                self.retryCount = retryCount
                self.lastAttemptAt = lastAttemptAt
                self.completedAt = completedAt
                self.errorMessage = errorMessage
            }
        }

        @Model
        final class SDMoodEntry {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var date: Date
            var valence: Double
            var labels: [String]
            var associations: [String]
            var notes: String?
            var source: String
            var sourceId: String?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                date: Date,
                valence: Double,
                labels: [String] = [],
                associations: [String] = [],
                notes: String? = nil,
                source: String = "manual",
                sourceId: String? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.date = date
                self.valence = max(-1.0, min(1.0, valence))
                self.labels = labels
                self.associations = associations
                self.notes = notes
                self.source = source
                self.sourceId = sourceId
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDJournalEntry {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var date: Date
            var title: String?
            var content: String
            var tags: [String]
            var entryType: String
            var isFavorite: Bool
            var linkedMoodId: UUID?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                date: Date,
                title: String? = nil,
                content: String,
                tags: [String] = [],
                entryType: String = "general",
                isFavorite: Bool = false,
                linkedMoodId: UUID? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.date = date
                self.title = title
                self.content = content
                self.tags = tags
                self.entryType = entryType
                self.isFavorite = isFavorite
                self.linkedMoodId = linkedMoodId
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDStatistics {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var statisticsType: String
            var data: Data
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                statisticsType: String,
                data: Data,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.statisticsType = statisticsType
                self.data = data
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDAIInsight {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var insightType: String
            var title: String
            var content: String
            var summary: String?
            var suggestions: [String]
            var dataContextData: Data?
            var isRead: Bool
            var isFavorite: Bool
            var isArchived: Bool
            var generatedAt: Date
            var readAt: Date?
            var archivedAt: Date?
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                insightType: String,
                title: String,
                content: String,
                summary: String? = nil,
                suggestions: [String] = [],
                dataContextData: Data? = nil,
                isRead: Bool = false,
                isFavorite: Bool = false,
                isArchived: Bool = false,
                generatedAt: Date = Date(),
                readAt: Date? = nil,
                archivedAt: Date? = nil,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.insightType = insightType
                self.title = title
                self.content = content
                self.summary = summary
                self.suggestions = suggestions
                self.dataContextData = dataContextData
                self.isRead = isRead
                self.isFavorite = isFavorite
                self.isArchived = isArchived
                self.generatedAt = generatedAt
                self.readAt = readAt
                self.archivedAt = archivedAt
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDGoal {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var title: String
            var goalDescription: String
            var category: String
            var status: String
            var progress: Double
            var targetDate: Date?
            var createdAt: Date
            var updatedAt: Date
            var backendId: String?

            init(
                id: UUID = UUID(),
                userId: UUID,
                title: String,
                goalDescription: String,
                category: String,
                status: String = "active",
                progress: Double = 0.0,
                targetDate: Date? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date(),
                backendId: String? = nil
            ) {
                self.id = id
                self.userId = userId
                self.title = title
                self.goalDescription = goalDescription
                self.category = category
                self.status = status
                self.progress = max(0.0, min(1.0, progress))
                self.targetDate = targetDate
                self.createdAt = createdAt
                self.updatedAt = updatedAt
                self.backendId = backendId
            }
        }

        @Model
        final class SDChatConversation {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var title: String
            var persona: String
            var messageCount: Int
            var isArchived: Bool
            var contextData: Data?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                title: String = "New Conversation",
                persona: String = "wellness",
                messageCount: Int = 0,
                isArchived: Bool = false,
                contextData: Data? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.title = title
                self.persona = persona
                self.messageCount = messageCount
                self.isArchived = isArchived
                self.contextData = contextData
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDChatMessage {
            @Attribute(.unique) var id: UUID
            var conversationId: UUID
            var role: String
            var content: String
            var timestamp: Date
            var metadata: Data?

            init(
                id: UUID = UUID(),
                conversationId: UUID,
                role: String,
                content: String,
                timestamp: Date = Date(),
                metadata: Data? = nil
            ) {
                self.id = id
                self.conversationId = conversationId
                self.role = role
                self.content = content
                self.timestamp = timestamp
                self.metadata = metadata
            }
        }
    }

    /// Migration plan for schema evolution
    enum MigrationPlan: SchemaMigrationPlan {
        static var schemas: [any VersionedSchema.Type] {
            [
                SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self,
                SchemaV6.self, SchemaV7.self,
            ]
        }

        static var stages: [MigrationStage] {
            [
                .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
                .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
                .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
                .lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self),
                .lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self),
                .lightweight(fromVersion: SchemaV6.self, toVersion: SchemaV7.self),
            ]
        }
    }

    /// Version 4: Added goal tips caching
    /// - SDGoalTipCache: Cache for AI-generated goal tips
    enum SchemaV4: VersionedSchema {
        static var versionIdentifier = Schema.Version(4, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self,
                SDStatistics.self, SDAIInsight.self, SDGoal.self,
                SDChatConversation.self, SDChatMessage.self, SDGoalTipCache.self,
            ]
        }

        // Inherit all models from SchemaV3
        typealias SDOutboxEvent = SchemaV3.SDOutboxEvent
        typealias SDMoodEntry = SchemaV3.SDMoodEntry
        typealias SDJournalEntry = SchemaV3.SDJournalEntry
        typealias SDStatistics = SchemaV3.SDStatistics
        typealias SDAIInsight = SchemaV3.SDAIInsight
        typealias SDGoal = SchemaV3.SDGoal
        typealias SDChatMessage = SchemaV3.SDChatMessage

        // New version of SDChatConversation with hasContextForGoalSuggestions
        @Model
        final class SDChatConversation {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var title: String
            var persona: String
            var messageCount: Int
            var isArchived: Bool
            var contextData: Data?
            var hasContextForGoalSuggestions: Bool
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                title: String = "New Conversation",
                persona: String = "wellness",
                messageCount: Int = 0,
                isArchived: Bool = false,
                contextData: Data? = nil,
                hasContextForGoalSuggestions: Bool = false,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.title = title
                self.persona = persona
                self.messageCount = messageCount
                self.isArchived = isArchived
                self.contextData = contextData
                self.hasContextForGoalSuggestions = hasContextForGoalSuggestions
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }

        @Model
        final class SDGoalTipCache {
            @Attribute(.unique) var id: UUID
            var goalId: UUID
            var backendId: String?
            var tipsData: Data
            var fetchedAt: Date
            var expiresAt: Date

            init(
                id: UUID = UUID(),
                goalId: UUID,
                backendId: String? = nil,
                tipsData: Data,
                fetchedAt: Date = Date(),
                expiresAt: Date
            ) {
                self.id = id
                self.goalId = goalId
                self.backendId = backendId
                self.tipsData = tipsData
                self.fetchedAt = fetchedAt
                self.expiresAt = expiresAt
            }

            /// Check if the cache is still valid
            var isValid: Bool {
                return Date() < expiresAt
            }

            /// Check if cache is expired
            var isExpired: Bool {
                return !isValid
            }

            /// Time remaining until expiration
            var timeUntilExpiration: TimeInterval {
                return expiresAt.timeIntervalSinceNow
            }

            // NOTE: Conversion methods removed - they should be in repository layer
            // to avoid referencing domain types from schema definitions
        }
    }

    /// Version 5: Updated AI Insights to match swagger-insights.yaml spec
    /// - SDAIInsight: Updated with periodStart, periodEnd, metricsData (removed generatedAt, readAt, archivedAt, dataContextData)
    enum SchemaV5: VersionedSchema {
        static var versionIdentifier = Schema.Version(5, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self,
                SDStatistics.self, SDAIInsight.self, SDGoal.self,
                SDChatConversation.self, SDChatMessage.self, SDGoalTipCache.self,
            ]
        }

        // Inherit all models from SchemaV4 except SDAIInsight
        typealias SDOutboxEvent = SchemaV4.SDOutboxEvent
        typealias SDMoodEntry = SchemaV4.SDMoodEntry
        typealias SDJournalEntry = SchemaV4.SDJournalEntry
        typealias SDStatistics = SchemaV4.SDStatistics
        typealias SDGoal = SchemaV4.SDGoal
        typealias SDChatConversation = SchemaV4.SDChatConversation
        typealias SDChatMessage = SchemaV4.SDChatMessage
        typealias SDGoalTipCache = SchemaV4.SDGoalTipCache

        // Updated SDAIInsight matching swagger-insights.yaml
        @Model
        final class SDAIInsight {
            @Attribute(.unique) var id: UUID
            var userId: UUID
            var insightType: String
            var title: String
            var content: String
            var summary: String?
            var periodStart: Date?
            var periodEnd: Date?
            var metricsData: Data?
            var suggestions: [String]
            var isRead: Bool
            var isFavorite: Bool
            var isArchived: Bool
            var backendId: String?
            var createdAt: Date
            var updatedAt: Date

            init(
                id: UUID = UUID(),
                userId: UUID,
                insightType: String,
                title: String,
                content: String,
                summary: String? = nil,
                periodStart: Date? = nil,
                periodEnd: Date? = nil,
                metricsData: Data? = nil,
                suggestions: [String] = [],
                isRead: Bool = false,
                isFavorite: Bool = false,
                isArchived: Bool = false,
                backendId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date = Date()
            ) {
                self.id = id
                self.userId = userId
                self.insightType = insightType
                self.title = title
                self.content = content
                self.summary = summary
                self.periodStart = periodStart
                self.periodEnd = periodEnd
                self.metricsData = metricsData
                self.suggestions = suggestions
                self.isRead = isRead
                self.isFavorite = isFavorite
                self.isArchived = isArchived
                self.backendId = backendId
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }
    }

    /// Version 6: Added user profile and dietary preferences
    /// - SDUserProfile: User profile data from backend
    /// - SDDietaryPreferences: Dietary and activity preferences
    enum SchemaV6: VersionedSchema {
        static var versionIdentifier = Schema.Version(6, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self,
                SDStatistics.self, SDAIInsight.self, SDGoal.self,
                SDChatConversation.self, SDChatMessage.self, SDGoalTipCache.self,
                SDUserProfile.self, SDDietaryPreferences.self,
            ]
        }

        // Inherit all models from SchemaV5
        typealias SDOutboxEvent = SchemaV5.SDOutboxEvent
        typealias SDMoodEntry = SchemaV5.SDMoodEntry
        typealias SDJournalEntry = SchemaV5.SDJournalEntry
        typealias SDStatistics = SchemaV5.SDStatistics
        typealias SDAIInsight = SchemaV5.SDAIInsight
        typealias SDGoal = SchemaV5.SDGoal
        typealias SDChatConversation = SchemaV5.SDChatConversation
        typealias SDChatMessage = SchemaV5.SDChatMessage
        typealias SDGoalTipCache = SchemaV5.SDGoalTipCache

        // New models for user profile
        @Model
        final class SDUserProfile {
            @Attribute(.unique) var id: String
            var userId: String
            var name: String
            var bio: String?
            var preferredUnitSystem: String
            var languageCode: String
            var dateOfBirth: Date?
            var createdAt: Date
            var updatedAt: Date
            var biologicalSex: String?
            var heightCm: Double?

            init(
                id: String,
                userId: String,
                name: String,
                bio: String?,
                preferredUnitSystem: String,
                languageCode: String,
                dateOfBirth: Date?,
                createdAt: Date,
                updatedAt: Date,
                biologicalSex: String?,
                heightCm: Double?
            ) {
                self.id = id
                self.userId = userId
                self.name = name
                self.bio = bio
                self.preferredUnitSystem = preferredUnitSystem
                self.languageCode = languageCode
                self.dateOfBirth = dateOfBirth
                self.createdAt = createdAt
                self.updatedAt = updatedAt
                self.biologicalSex = biologicalSex
                self.heightCm = heightCm
            }
        }

        @Model
        final class SDDietaryPreferences {
            @Attribute(.unique) var id: String
            var userProfileId: String
            var allergies: [String]
            var dietaryRestrictions: [String]
            var foodDislikes: [String]
            var createdAt: Date
            var updatedAt: Date

            init(
                id: String,
                userProfileId: String,
                allergies: [String],
                dietaryRestrictions: [String],
                foodDislikes: [String],
                createdAt: Date,
                updatedAt: Date
            ) {
                self.id = id
                self.userProfileId = userProfileId
                self.allergies = allergies
                self.dietaryRestrictions = dietaryRestrictions
                self.foodDislikes = foodDislikes
                self.createdAt = createdAt
                self.updatedAt = updatedAt
            }
        }
    }

    /// Version 7: Updated Outbox Pattern to use FitIQCore type-safe implementation
    /// - SDOutboxEvent: Updated with entityID, userID, metadata (JSON string), priority, isNewRecord
    /// - Renamed retryCount → attemptCount
    /// - Removed payload (Data) in favor of structured metadata
    enum SchemaV7: VersionedSchema {
        static var versionIdentifier = Schema.Version(7, 0, 0)

        static var models: [any PersistentModel.Type] {
            [
                SDOutboxEvent.self, SDMoodEntry.self, SDJournalEntry.self,
                SDStatistics.self, SDAIInsight.self, SDGoal.self,
                SDChatConversation.self, SDChatMessage.self, SDGoalTipCache.self,
                SDUserProfile.self, SDDietaryPreferences.self,
            ]
        }

        // Inherit unchanged models from SchemaV6
        typealias SDMoodEntry = SchemaV6.SDMoodEntry
        typealias SDJournalEntry = SchemaV6.SDJournalEntry
        typealias SDStatistics = SchemaV6.SDStatistics
        typealias SDAIInsight = SchemaV6.SDAIInsight
        typealias SDGoal = SchemaV6.SDGoal
        typealias SDChatConversation = SchemaV6.SDChatConversation
        typealias SDChatMessage = SchemaV6.SDChatMessage
        typealias SDGoalTipCache = SchemaV6.SDGoalTipCache
        typealias SDUserProfile = SchemaV6.SDUserProfile
        typealias SDDietaryPreferences = SchemaV6.SDDietaryPreferences

        // NEW: Updated SDOutboxEvent for FitIQCore compatibility
        @Model
        final class SDOutboxEvent {
            var id: UUID
            var createdAt: Date
            var eventType: String
            var entityID: UUID  // NEW: ID of the entity being synced
            var userID: String  // NEW: User who owns this event
            var status: String
            var lastAttemptAt: Date?
            var attemptCount: Int  // RENAMED: was retryCount
            var maxAttempts: Int  // NEW: Maximum retry attempts
            var errorMessage: String?
            var completedAt: Date?
            var metadata: String?  // NEW: JSON string (replaces payload)
            var priority: Int  // NEW: Processing priority
            var isNewRecord: Bool  // NEW: True if creating, false if updating

            init(
                id: UUID = UUID(),
                eventType: String,
                entityID: UUID,
                userID: String,
                status: String = "pending",
                createdAt: Date = Date(),
                lastAttemptAt: Date? = nil,
                attemptCount: Int = 0,
                maxAttempts: Int = 5,
                errorMessage: String? = nil,
                completedAt: Date? = nil,
                metadata: String? = nil,
                priority: Int = 0,
                isNewRecord: Bool = true
            ) {
                self.id = id
                self.eventType = eventType
                self.entityID = entityID
                self.userID = userID
                self.status = status
                self.createdAt = createdAt
                self.lastAttemptAt = lastAttemptAt
                self.attemptCount = attemptCount
                self.maxAttempts = maxAttempts
                self.errorMessage = errorMessage
                self.completedAt = completedAt
                self.metadata = metadata
                self.priority = priority
                self.isNewRecord = isNewRecord
            }
        }
    }
}

// MARK: - Type Aliases for Current Schema

/// Typealiases to current versioned models for convenience
/// This allows using `SDMoodEntry` instead of `SchemaVersioning.SchemaV7.SDMoodEntry`
typealias SDOutboxEvent = SchemaVersioning.SchemaV7.SDOutboxEvent
typealias SDMoodEntry = SchemaVersioning.SchemaV7.SDMoodEntry
typealias SDJournalEntry = SchemaVersioning.SchemaV7.SDJournalEntry
typealias SDStatistics = SchemaVersioning.SchemaV7.SDStatistics
typealias SDAIInsight = SchemaVersioning.SchemaV7.SDAIInsight
typealias SDGoal = SchemaVersioning.SchemaV7.SDGoal
typealias SDChatConversation = SchemaVersioning.SchemaV7.SDChatConversation
typealias SDChatMessage = SchemaVersioning.SchemaV7.SDChatMessage
typealias SDGoalTipCache = SchemaVersioning.SchemaV7.SDGoalTipCache
typealias SDUserProfile = SchemaVersioning.SchemaV7.SDUserProfile
typealias SDDietaryPreferences = SchemaVersioning.SchemaV7.SDDietaryPreferences
