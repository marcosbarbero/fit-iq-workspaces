//
//  OutboxEvent.swift
//  FitIQCore
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Domain model for Outbox Pattern events
//

import Foundation

/// Domain model for Outbox Pattern events
/// Represents a pending synchronization operation that ensures reliable data delivery
public struct OutboxEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let eventType: OutboxEventType
    public let entityID: UUID
    public let userID: String
    public var status: OutboxEventStatus
    public let createdAt: Date
    public var lastAttemptAt: Date?
    public var attemptCount: Int
    public let maxAttempts: Int
    public var errorMessage: String?
    public var completedAt: Date?
    public var metadata: OutboxMetadata?
    public let priority: Int
    public let isNewRecord: Bool

    public init(
        id: UUID = UUID(),
        eventType: OutboxEventType,
        entityID: UUID,
        userID: String,
        status: OutboxEventStatus = .pending,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        maxAttempts: Int = 5,
        errorMessage: String? = nil,
        completedAt: Date? = nil,
        metadata: OutboxMetadata? = nil,
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

/// Type-safe event types for Outbox Pattern
public enum OutboxEventType: String, Codable, CaseIterable, Sendable {
    // FitIQ events
    case progressEntry = "progressEntry"
    case physicalAttribute = "physicalAttribute"
    case activitySnapshot = "activitySnapshot"
    case profileMetadata = "profileMetadata"
    case profilePhysical = "profilePhysical"
    case sleepSession = "sleepSession"
    case mealLog = "mealLog"
    case workout = "workout"
    case workoutTemplate = "workoutTemplate"

    // Lume events
    case moodEntry = "moodEntry"
    case journalEntry = "journalEntry"
    case goal = "goal"
    case chatMessage = "chatMessage"

    public var displayName: String {
        switch self {
        case .progressEntry: return "Progress Entry"
        case .physicalAttribute: return "Physical Attribute"
        case .activitySnapshot: return "Activity Snapshot"
        case .profileMetadata: return "Profile Metadata"
        case .profilePhysical: return "Physical Profile"
        case .sleepSession: return "Sleep Session"
        case .mealLog: return "Meal Log"
        case .workout: return "Workout"
        case .workoutTemplate: return "Workout Template"
        case .moodEntry: return "Mood Entry"
        case .journalEntry: return "Journal Entry"
        case .goal: return "Goal"
        case .chatMessage: return "Chat Message"
        }
    }
}

/// Processing status for outbox events
public enum OutboxEventStatus: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    public var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .processing: return "🔄"
        case .completed: return "✅"
        case .failed: return "❌"
        }
    }
}

/// Type-safe metadata for outbox events
public enum OutboxMetadata: Codable, Sendable, Equatable {
    case progressEntry(metricType: String, value: Double, unit: String)
    case moodEntry(valence: Double, labels: [String])
    case journalEntry(wordCount: Int, linkedMoodID: UUID?)
    case sleepSession(duration: TimeInterval, quality: Double?)
    case mealLog(calories: Double, macros: [String: Double])
    case workout(type: String, duration: TimeInterval)
    case goal(title: String, category: String)
    case generic([String: String])

    enum CodingKeys: String, CodingKey {
        case type
        case metricType, value, unit
        case valence, labels
        case wordCount, linkedMoodID
        case duration, quality
        case calories, macros
        case title, category
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "progressEntry":
            let metricType = try container.decode(String.self, forKey: .metricType)
            let value = try container.decode(Double.self, forKey: .value)
            let unit = try container.decode(String.self, forKey: .unit)
            self = .progressEntry(metricType: metricType, value: value, unit: unit)

        case "moodEntry":
            let valence = try container.decode(Double.self, forKey: .valence)
            let labels = try container.decode([String].self, forKey: .labels)
            self = .moodEntry(valence: valence, labels: labels)

        case "journalEntry":
            let wordCount = try container.decode(Int.self, forKey: .wordCount)
            let linkedMoodID = try container.decodeIfPresent(UUID.self, forKey: .linkedMoodID)
            self = .journalEntry(wordCount: wordCount, linkedMoodID: linkedMoodID)

        case "sleepSession":
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            let quality = try container.decodeIfPresent(Double.self, forKey: .quality)
            self = .sleepSession(duration: duration, quality: quality)

        case "mealLog":
            let calories = try container.decode(Double.self, forKey: .calories)
            let macros = try container.decode([String: Double].self, forKey: .macros)
            self = .mealLog(calories: calories, macros: macros)

        case "workout":
            let workoutType = try container.decode(String.self, forKey: .type)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .workout(type: workoutType, duration: duration)

        case "goal":
            let title = try container.decode(String.self, forKey: .title)
            let category = try container.decode(String.self, forKey: .category)
            self = .goal(title: title, category: category)

        case "generic":
            let data = try container.decode([String: String].self, forKey: .data)
            self = .generic(data)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown metadata type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .progressEntry(let metricType, let value, let unit):
            try container.encode("progressEntry", forKey: .type)
            try container.encode(metricType, forKey: .metricType)
            try container.encode(value, forKey: .value)
            try container.encode(unit, forKey: .unit)

        case .moodEntry(let valence, let labels):
            try container.encode("moodEntry", forKey: .type)
            try container.encode(valence, forKey: .valence)
            try container.encode(labels, forKey: .labels)

        case .journalEntry(let wordCount, let linkedMoodID):
            try container.encode("journalEntry", forKey: .type)
            try container.encode(wordCount, forKey: .wordCount)
            try container.encodeIfPresent(linkedMoodID, forKey: .linkedMoodID)

        case .sleepSession(let duration, let quality):
            try container.encode("sleepSession", forKey: .type)
            try container.encode(duration, forKey: .duration)
            try container.encodeIfPresent(quality, forKey: .quality)

        case .mealLog(let calories, let macros):
            try container.encode("mealLog", forKey: .type)
            try container.encode(calories, forKey: .calories)
            try container.encode(macros, forKey: .macros)

        case .workout(let workoutType, let duration):
            try container.encode("workout", forKey: .type)
            try container.encode(workoutType, forKey: .type)
            try container.encode(duration, forKey: .duration)

        case .goal(let title, let category):
            try container.encode("goal", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(category, forKey: .category)

        case .generic(let data):
            try container.encode("generic", forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - OutboxEvent Extensions

extension OutboxEvent {
    /// Check if event is eligible for retry
    public var canRetry: Bool {
        status == .failed && attemptCount < maxAttempts
    }

    /// Check if event is stale (old pending events that might need attention)
    public var isStale: Bool {
        guard status == .pending else { return false }
        let staleThreshold: TimeInterval = 300  // 5 minutes
        return Date().timeIntervalSince(createdAt) > staleThreshold
    }

    /// Check if event should be processed
    public var shouldProcess: Bool {
        status == .pending || canRetry
    }

    /// Calculate next retry delay using exponential backoff
    public func nextRetryDelay(retryDelays: [TimeInterval] = [1, 5, 30, 120, 600]) -> TimeInterval?
    {
        guard canRetry else { return nil }
        let index = min(attemptCount, retryDelays.count - 1)
        return retryDelays[index]
    }

    /// Mark event as processing
    public mutating func markAsProcessing() {
        self.status = .processing
        self.lastAttemptAt = Date()
        self.attemptCount += 1
    }

    /// Mark event as completed
    public mutating func markAsCompleted() {
        self.status = .completed
        self.completedAt = Date()
        self.errorMessage = nil
    }

    /// Mark event as failed with error message
    public mutating func markAsFailed(error: String) {
        self.status = .failed
        self.errorMessage = error
        self.lastAttemptAt = Date()
    }

    /// Reset for retry
    public mutating func resetForRetry() {
        guard canRetry else { return }
        self.status = .pending
        self.errorMessage = nil
    }
}
