//
//  SchemaV3.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-31.
//  Schema version 3: Adds SDOutboxEvent for reliable sync with Outbox Pattern
//

import Foundation
import SwiftData

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 3)

    // MARK: - Reuse V2 Models (unchanged)

    typealias SDUserProfile = SchemaV2.SDUserProfile
    typealias SDDietaryAndActivityPreferences = SchemaV2.SDDietaryAndActivityPreferences
    typealias SDPhysicalAttribute = SchemaV2.SDPhysicalAttribute
    typealias SDActivitySnapshot = SchemaV2.SDActivitySnapshot
    typealias SDProgressEntry = SchemaV2.SDProgressEntry

    // MARK: - SDOutboxEvent (NEW in V3)

    /// Outbox event for reliable sync using the Outbox Pattern
    ///
    /// Persists sync events to guarantee at-least-once delivery to remote API.
    /// Events survive app crashes/restarts and are processed by OutboxProcessorService.
    ///
    /// The Outbox Pattern ensures:
    /// - Events persist in database (survive crashes)
    /// - Transactional consistency (data + event saved atomically)
    /// - Guaranteed delivery with automatic retry
    /// - Full audit trail of all sync operations
    @Model final class SDOutboxEvent {
        /// Unique identifier for this outbox event
        /// Note: CloudKit doesn't support unique constraints, so we remove @Attribute(.unique)
        var id: UUID = UUID()

        /// Type of event (progressEntry, physicalAttribute, activitySnapshot, etc.)
        var eventType: String = ""

        /// ID of the entity that needs syncing (e.g., ProgressEntry.id, PhysicalAttribute.id)
        var entityID: UUID = UUID()

        /// User ID this event belongs to
        var userID: String = ""

        /// Current processing status: "pending", "processing", "completed", "failed"
        var status: String = "pending"

        /// Timestamp when event was created
        var createdAt: Date = Date()

        /// Timestamp when event was last attempted
        var lastAttemptAt: Date?

        /// Number of processing attempts
        var attemptCount: Int = 0

        /// Maximum number of retry attempts before giving up (default: 5)
        var maxAttempts: Int = 5

        /// Error message if sync failed
        var errorMessage: String?

        /// Timestamp when event was successfully completed
        var completedAt: Date?

        /// Additional metadata as JSON string (flexible for different event types)
        var metadata: String?

        /// Priority (higher = process first, default: 0)
        var priority: Int = 0

        /// Whether this is a new record (true) or an update (false)
        var isNewRecord: Bool = true

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

    // MARK: - Schema Models

    static var models: [any PersistentModel.Type] {
        [
            SchemaV3.SDUserProfile.self,
            SchemaV3.SDDietaryAndActivityPreferences.self,
            SchemaV3.SDPhysicalAttribute.self,
            SchemaV3.SDActivitySnapshot.self,
            SchemaV3.SDProgressEntry.self,
            SchemaV3.SDOutboxEvent.self,  // NEW in V3
        ]
    }
}
