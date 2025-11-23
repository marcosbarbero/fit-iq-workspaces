//
//  SwiftDataOutboxRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 31/01/2025.
//  Updated: 2025-01-27 - Migrated to FitIQCore
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of the Outbox Pattern repository
///
/// This repository manages persistent outbox events for reliable sync to remote API.
/// Events are stored in SwiftData and survive app crashes/restarts.
final class SwiftDataOutboxRepository: OutboxRepositoryProtocol {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Event Creation

    func createEvent(
        eventType: FitIQCore.OutboxEventType,
        entityID: UUID,
        userID: String,
        isNewRecord: Bool,
        metadata: FitIQCore.OutboxMetadata?,
        priority: Int
    ) async throws -> FitIQCore.OutboxEvent {
        print(
            "OutboxRepository: 📦 Creating outbox event - Type: [\(eventType.displayName)] | EntityID: \(entityID) | UserID: \(userID) | Priority: \(priority) | IsNew: \(isNewRecord)"
        )

        // Convert metadata to JSON string
        let metadataString: String?
        if let metadata = metadata {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(metadata),
                let string = String(data: data, encoding: .utf8)
            {
                metadataString = string
            } else {
                metadataString = nil
            }
        } else {
            metadataString = nil
        }

        let sdEvent = SDOutboxEvent(
            eventType: eventType.rawValue,
            entityID: entityID,
            userID: userID,
            status: FitIQCore.OutboxEventStatus.pending.rawValue,
            metadata: metadataString,
            priority: priority,
            isNewRecord: isNewRecord
        )

        modelContext.insert(sdEvent)
        try modelContext.save()

        print(
            "OutboxRepository: ✅ Outbox event created - EventID: \(sdEvent.id) | Type: [\(eventType.displayName)] | Status: pending"
        )
        return try sdEvent.toDomain()
    }

    // MARK: - Event Retrieval

    func fetchPendingEvents(
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [FitIQCore.OutboxEvent] {
        let pendingStatus = FitIQCore.OutboxEventStatus.pending.rawValue
        let failedStatus = FitIQCore.OutboxEventStatus.failed.rawValue

        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                // Pending or failed events that can retry
                (event.status == pendingStatus
                    || (event.status == failedStatus
                        && event.attemptCount < event.maxAttempts))
            },
            sortBy: [
                SortDescriptor(\.priority, order: .reverse),  // Higher priority first
                SortDescriptor(\.createdAt),  // Older first
            ]
        )

        // Apply user filter if specified
        if let userID = userID {
            descriptor.predicate = #Predicate<SDOutboxEvent> { event in
                event.userID == userID
                    && (event.status == pendingStatus
                        || (event.status == failedStatus
                            && event.attemptCount < event.maxAttempts))
            }
        }

        // Apply limit if specified
        if let limit = limit {
            descriptor.fetchLimit = limit
        }

        let sdEvents = try modelContext.fetch(descriptor)

        // Only log when events are found (reduce noise)
        if !sdEvents.isEmpty {
            print(
                "OutboxRepository: Fetched \(sdEvents.count) pending events"
                    + (userID.map { " for user \($0)" } ?? ""))
        }
        return try sdEvents.map { try $0.toDomain() }
    }

    func fetchEvents(
        withStatus status: FitIQCore.OutboxEventStatus,
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [FitIQCore.OutboxEvent] {
        let statusValue = status.rawValue

        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.status == statusValue
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        // Apply user filter if specified
        if let userID = userID {
            descriptor.predicate = #Predicate<SDOutboxEvent> { event in
                event.userID == userID && event.status == statusValue
            }
        }

        // Apply limit if specified
        if let limit = limit {
            descriptor.fetchLimit = limit
        }

        let sdEvents = try modelContext.fetch(descriptor)

        print("OutboxRepository: Fetched \(sdEvents.count) events with status \(status.rawValue)")
        return try sdEvents.map { try $0.toDomain() }
    }

    func fetchEvent(byID id: UUID) async throws -> FitIQCore.OutboxEvent? {
        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.id == id
            }
        )
        descriptor.fetchLimit = 1

        let sdEvents = try modelContext.fetch(descriptor)
        return try sdEvents.first?.toDomain()
    }

    func fetchEvents(
        forEntityID entityID: UUID,
        eventType: FitIQCore.OutboxEventType?
    ) async throws -> [FitIQCore.OutboxEvent] {
        var descriptor: FetchDescriptor<SDOutboxEvent>

        if let eventType = eventType {
            let eventTypeValue = eventType.rawValue
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate<SDOutboxEvent> { event in
                    event.entityID == entityID && event.eventType == eventTypeValue
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate<SDOutboxEvent> { event in
                    event.entityID == entityID
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }

        let sdEvents = try modelContext.fetch(descriptor)
        return try sdEvents.map { try $0.toDomain() }
    }

    // MARK: - Event Updates

    func updateEvent(_ event: FitIQCore.OutboxEvent) async throws {
        try modelContext.save()
        print("OutboxRepository: Updated event \(event.id)")
    }

    func markAsProcessing(_ eventID: UUID) async throws {
        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.id == eventID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdEvent = try modelContext.fetch(descriptor).first else {
            throw OutboxRepositoryError.eventNotFound(eventID)
        }

        sdEvent.markAsProcessing()
        try modelContext.save()

        print(
            "OutboxRepository: 🔄 Marked event \(eventID) as processing (attempt \(sdEvent.attemptCount))"
        )
    }

    func markAsCompleted(_ eventID: UUID) async throws {
        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.id == eventID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdEvent = try modelContext.fetch(descriptor).first else {
            throw OutboxRepositoryError.eventNotFound(eventID)
        }

        sdEvent.markAsCompleted()
        try modelContext.save()

        print("OutboxRepository: ✅ Marked event \(eventID) as completed")
    }

    func markAsFailed(_ eventID: UUID, error: String) async throws {
        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.id == eventID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdEvent = try modelContext.fetch(descriptor).first else {
            throw OutboxRepositoryError.eventNotFound(eventID)
        }

        sdEvent.markAsFailed(error: error)
        try modelContext.save()

        let canRetry = sdEvent.canRetry ? " (will retry)" : " (max attempts reached)"
        print("OutboxRepository: ❌ Marked event \(eventID) as failed\(canRetry)")
        print("  Error: \(error)")
    }

    func resetForRetry(_ eventIDs: [UUID]) async throws {
        var resetCount = 0

        for eventID in eventIDs {
            let descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate<SDOutboxEvent> { event in
                    event.id == eventID
                }
            )

            if let sdEvent = try modelContext.fetch(descriptor).first, sdEvent.canRetry {
                sdEvent.resetForRetry()
                resetCount += 1
            }
        }

        if resetCount > 0 {
            try modelContext.save()
            print("OutboxRepository: 🔄 Reset \(resetCount) events for retry")
        }
    }

    // MARK: - Event Deletion

    @discardableResult
    func deleteCompletedEvents(olderThan date: Date) async throws -> Int {
        let completedStatus = FitIQCore.OutboxEventStatus.completed.rawValue
        // Define Date.distantFuture as a local constant to avoid predicate macro issues
        let distantFutureConstant = Date.distantFuture

        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.status == completedStatus
                    && (event.completedAt ?? distantFutureConstant) < date
            }
        )

        let sdEvents = try modelContext.fetch(descriptor)
        let count = sdEvents.count

        for sdEvent in sdEvents {
            modelContext.delete(sdEvent)
        }

        if count > 0 {
            try modelContext.save()
            print("OutboxRepository: 🗑️ Deleted \(count) completed events older than \(date)")
        }

        return count
    }

    func deleteEvent(_ eventID: UUID) async throws {
        var descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.id == eventID
            }
        )
        descriptor.fetchLimit = 1

        guard let sdEvent = try modelContext.fetch(descriptor).first else {
            throw OutboxRepositoryError.eventNotFound(eventID)
        }

        modelContext.delete(sdEvent)
        try modelContext.save()

        print("OutboxRepository: 🗑️ Deleted event \(eventID)")
    }

    func deleteEvents(forEntityIDs entityIDs: [UUID]) async throws -> Int {
        guard !entityIDs.isEmpty else {
            return 0
        }

        // Fetch all events that reference any of the provided entity IDs
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                entityIDs.contains(event.entityID)
            }
        )

        let eventsToDelete = try modelContext.fetch(descriptor)
        let count = eventsToDelete.count

        for event in eventsToDelete {
            modelContext.delete(event)
        }

        if count > 0 {
            try modelContext.save()
            print(
                "OutboxRepository: 🗑️ Deleted \(count) orphaned outbox event(s) for \(entityIDs.count) entity ID(s)"
            )
        }

        return count
    }

    func deleteAllEvents(forUserID userID: String) async throws -> Int {
        // Fetch all events for this user
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate<SDOutboxEvent> { event in
                event.userID == userID
            }
        )

        let eventsToDelete = try modelContext.fetch(descriptor)
        let count = eventsToDelete.count

        // Delete all in one batch
        for event in eventsToDelete {
            modelContext.delete(event)
        }

        if count > 0 {
            try modelContext.save()
            print(
                "OutboxRepository: 🗑️ Bulk deleted ALL \(count) outbox events for user \(userID)"
            )
        }

        return count
    }

    // MARK: - Statistics

    func getStatistics(forUserID userID: String?) async throws -> FitIQCore.OutboxStatistics {
        // Fetch all events (or filtered by user)
        let allDescriptor: FetchDescriptor<SDOutboxEvent>
        if let userID = userID {
            allDescriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate<SDOutboxEvent> { event in
                    event.userID == userID
                }
            )
        } else {
            allDescriptor = FetchDescriptor<SDOutboxEvent>()
        }

        let allEvents = try modelContext.fetch(allDescriptor)

        // Count by status
        let pendingStatus = FitIQCore.OutboxEventStatus.pending.rawValue
        let processingStatus = FitIQCore.OutboxEventStatus.processing.rawValue
        let completedStatus = FitIQCore.OutboxEventStatus.completed.rawValue
        let failedStatus = FitIQCore.OutboxEventStatus.failed.rawValue

        let pendingCount = allEvents.filter { $0.status == pendingStatus }.count
        let processingCount = allEvents.filter { $0.status == processingStatus }.count
        let completedCount = allEvents.filter { $0.status == completedStatus }.count
        let failedCount = allEvents.filter { $0.status == failedStatus }.count
        let staleCount = allEvents.filter { $0.isStale }.count

        // Find oldest pending
        let pendingEvents = allEvents.filter { $0.status == pendingStatus }
        let oldestPendingDate = pendingEvents.map { $0.createdAt }.min()

        // Find newest completed
        let completedEvents = allEvents.filter { $0.status == completedStatus }
        let newestCompletedDate = completedEvents.compactMap { $0.completedAt }.max()

        let stats = FitIQCore.OutboxStatistics(
            totalEvents: allEvents.count,
            pendingCount: pendingCount,
            processingCount: processingCount,
            completedCount: completedCount,
            failedCount: failedCount,
            staleCount: staleCount,
            oldestPendingDate: oldestPendingDate,
            newestCompletedDate: newestCompletedDate
        )

        print(
            "OutboxRepository: 📊 Statistics: \(stats.totalEvents) total, \(stats.pendingCount) pending, \(stats.completedCount) completed, \(stats.failedCount) failed"
        )

        return stats
    }

    func getStaleEvents(forUserID userID: String?) async throws -> [FitIQCore.OutboxEvent] {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let pendingStatus = FitIQCore.OutboxEventStatus.pending.rawValue

        let descriptor: FetchDescriptor<SDOutboxEvent>
        if let userID = userID {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate<SDOutboxEvent> { event in
                    event.userID == userID && event.status == pendingStatus
                        && event.createdAt < fiveMinutesAgo
                }
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate<SDOutboxEvent> { event in
                    event.status == pendingStatus
                        && event.createdAt < fiveMinutesAgo
                }
            )
        }

        let sdStaleEvents = try modelContext.fetch(descriptor)

        if !sdStaleEvents.isEmpty {
            print(
                "OutboxRepository: ⚠️ Found \(sdStaleEvents.count) stale events (pending > 5 minutes)"
            )
        }

        return try sdStaleEvents.map { try $0.toDomain() }
    }
}

// MARK: - Errors

enum OutboxRepositoryError: Error, LocalizedError {
    case eventNotFound(UUID)
    case invalidEventState

    var errorDescription: String? {
        switch self {
        case .eventNotFound(let id):
            return "Outbox event not found: \(id)"
        case .invalidEventState:
            return "Invalid event state for this operation"
        }
    }
}
