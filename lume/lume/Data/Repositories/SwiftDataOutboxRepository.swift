//
//  SwiftDataOutboxRepository.swift
//  lume
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: SwiftData implementation of OutboxRepositoryProtocol using FitIQCore
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of OutboxRepositoryProtocol from FitIQCore
///
/// This repository implements the Outbox Pattern for reliable event sync:
/// - Events persist locally (survive crashes)
/// - Automatic retry with exponential backoff
/// - Transactional consistency (data + event saved atomically)
/// - Full audit trail of all sync operations
///
/// **Architecture:**
/// ```
/// Use Case (Domain)
///     ↓ calls
/// OutboxRepositoryProtocol (Port)
///     ↑ implemented by
/// SwiftDataOutboxRepository (Adapter)
///     ↓ uses
/// OutboxEventAdapter (Converter)
///     ↓ converts to
/// SDOutboxEvent (SwiftData @Model)
/// ```
final class SwiftDataOutboxRepository: OutboxRepositoryProtocol {
    private let modelContext: ModelContext

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
            "📦 [OutboxRepository] Creating event - Type: [\(eventType.rawValue)] | EntityID: \(entityID) | UserID: \(userID) | Priority: \(priority) | IsNew: \(isNewRecord)"
        )

        // Create domain event
        let domainEvent = FitIQCore.OutboxEvent(
            id: UUID(),
            eventType: eventType,
            entityID: entityID,
            userID: userID,
            status: .pending,
            createdAt: Date(),
            lastAttemptAt: nil,
            attemptCount: 0,
            maxAttempts: 5,
            errorMessage: nil,
            completedAt: nil,
            metadata: metadata,
            priority: priority,
            isNewRecord: isNewRecord
        )

        // Convert to SwiftData model using adapter
        let sdEvent = OutboxEventAdapter.toSwiftData(domainEvent)

        // Check for duplicate ID (prevent duplicate registration crash)
        let eventID = domainEvent.id
        let idCheckDescriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate { event in event.id == eventID }
        )
        if let existingByID = try modelContext.fetch(idCheckDescriptor).first {
            print(
                "⚠️ [OutboxRepository] Event with ID \(eventID) already exists - returning existing event"
            )
            return try existingByID.toDomain()
        }

        // Insert and save
        modelContext.insert(sdEvent)
        try modelContext.save()

        print(
            "✅ [OutboxRepository] Event created - EventID: \(sdEvent.id) | Type: [\(eventType.rawValue)] | Status: pending"
        )
        return try sdEvent.toDomain()
    }

    // MARK: - Event Retrieval

    func fetchPendingEvents(forUserID userID: String?, limit: Int?) async throws -> [FitIQCore
        .OutboxEvent]
    {
        let pendingStatus = FitIQCore.OutboxEventStatus.pending.rawValue
        let failedStatus = FitIQCore.OutboxEventStatus.failed.rawValue

        var descriptor: FetchDescriptor<SDOutboxEvent>

        if let userID = userID {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    (event.status == pendingStatus || event.status == failedStatus)
                        && event.userID == userID
                },
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.createdAt, order: .forward),
                ]
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.status == pendingStatus || event.status == failedStatus
                },
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.createdAt, order: .forward),
                ]
            )
        }

        if let limit = limit {
            descriptor.fetchLimit = limit
        }

        let sdEvents = try modelContext.fetch(descriptor)

        print(
            "📋 [OutboxRepository] Fetched \(sdEvents.count) pending events"
                + (userID.map { " for user \($0)" } ?? "")
        )

        return try sdEvents.map { try $0.toDomain() }
    }

    func fetchEvents(
        withStatus status: FitIQCore.OutboxEventStatus,
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [FitIQCore.OutboxEvent] {
        let statusString = status.rawValue

        var descriptor: FetchDescriptor<SDOutboxEvent>

        if let userID = userID {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.status == statusString && event.userID == userID
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.status == statusString
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        }

        if let limit = limit {
            descriptor.fetchLimit = limit
        }

        let sdEvents = try modelContext.fetch(descriptor)

        print(
            "📋 [OutboxRepository] Fetched \(sdEvents.count) events with status \(status.rawValue)"
        )
        return try sdEvents.map { try $0.toDomain() }
    }

    func fetchEvent(byID id: UUID) async throws -> FitIQCore.OutboxEvent? {
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate { event in event.id == id }
        )

        let sdEvents = try modelContext.fetch(descriptor)
        return try sdEvents.first?.toDomain()
    }

    func fetchEvents(forEntityID entityID: UUID, eventType: FitIQCore.OutboxEventType?)
        async
        throws -> [FitIQCore.OutboxEvent]
    {
        var descriptor: FetchDescriptor<SDOutboxEvent>

        if let eventType = eventType {
            let eventTypeString = eventType.rawValue
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.entityID == entityID && event.eventType == eventTypeString
                }
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.entityID == entityID
                }
            )
        }

        let sdEvents = try modelContext.fetch(descriptor)
        return try sdEvents.map { try $0.toDomain() }
    }

    // MARK: - Event Updates

    func markAsProcessing(_ eventID: UUID) async throws {
        guard let sdEvent = try fetchSDEvent(byID: eventID) else {
            throw OutboxError.eventNotFound
        }

        sdEvent.status = FitIQCore.OutboxEventStatus.processing.rawValue
        sdEvent.lastAttemptAt = Date()

        try modelContext.save()

        print("🔄 [OutboxRepository] Event marked as processing - EventID: \(eventID)")
    }

    func markAsCompleted(_ eventID: UUID) async throws {
        guard let sdEvent = try fetchSDEvent(byID: eventID) else {
            throw OutboxError.eventNotFound
        }

        sdEvent.status = FitIQCore.OutboxEventStatus.completed.rawValue
        sdEvent.completedAt = Date()
        sdEvent.errorMessage = nil

        try modelContext.save()

        print(
            "✅ [OutboxRepository] Event completed - EventID: \(eventID) | Type: \(sdEvent.eventType)"
        )
    }

    func markAsFailed(_ eventID: UUID, error: String) async throws {
        guard let sdEvent = try fetchSDEvent(byID: eventID) else {
            throw OutboxError.eventNotFound
        }

        sdEvent.status = FitIQCore.OutboxEventStatus.failed.rawValue
        sdEvent.lastAttemptAt = Date()
        sdEvent.attemptCount += 1
        sdEvent.errorMessage = error

        try modelContext.save()

        print(
            "⚠️ [OutboxRepository] Event failed - EventID: \(eventID) | Attempt: \(sdEvent.attemptCount)/\(sdEvent.maxAttempts) | Error: \(error)"
        )
    }

    func updateEvent(_ event: FitIQCore.OutboxEvent) async throws {
        guard let sdEvent = try fetchSDEvent(byID: event.id) else {
            throw OutboxError.eventNotFound
        }

        // Update mutable fields using adapter
        OutboxEventAdapter.updateSwiftData(sdEvent, from: event)

        try modelContext.save()

        print("🔄 [OutboxRepository] Event updated - EventID: \(event.id)")
    }

    func resetForRetry(_ eventIDs: [UUID]) async throws {
        for eventID in eventIDs {
            guard let sdEvent = try fetchSDEvent(byID: eventID) else {
                continue
            }

            sdEvent.status = FitIQCore.OutboxEventStatus.pending.rawValue
            sdEvent.lastAttemptAt = nil
            sdEvent.errorMessage = nil
        }

        try modelContext.save()

        print("🔄 [OutboxRepository] Reset \(eventIDs.count) events for retry")
    }

    // MARK: - Event Deletion</parameter>
    // MARK: - Event Deletion

    func deleteEvent(_ eventID: UUID) async throws {
        guard let sdEvent = try fetchSDEvent(byID: eventID) else {
            throw OutboxError.eventNotFound
        }

        modelContext.delete(sdEvent)
        try modelContext.save()

        print("🗑️ [OutboxRepository] Event deleted - EventID: \(eventID)")
    }

    @discardableResult
    func deleteEvents(forEntityIDs entityIDs: [UUID]) async throws -> Int {
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate { event in
                entityIDs.contains(event.entityID)
            }
        )

        let sdEvents = try modelContext.fetch(descriptor)
        let count = sdEvents.count

        for sdEvent in sdEvents {
            modelContext.delete(sdEvent)
        }

        try modelContext.save()

        print(
            "🗑️ [OutboxRepository] Deleted \(count) events for \(entityIDs.count) entities")

        return count
    }

    @discardableResult
    func deleteCompletedEvents(olderThan date: Date) async throws -> Int {
        let completedStatus = FitIQCore.OutboxEventStatus.completed.rawValue

        // Fetch all completed events and filter in memory
        // Note: Cannot use Date.distantPast in #Predicate macro
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate { event in
                event.status == completedStatus
            }
        )

        let allCompleted = try modelContext.fetch(descriptor)

        // Filter in memory for events older than date
        let sdEvents = allCompleted.filter { event in
            guard let completedAt = event.completedAt else { return false }
            return completedAt < date
        }

        let count = sdEvents.count

        for sdEvent in sdEvents {
            modelContext.delete(sdEvent)
        }

        try modelContext.save()

        print("🗑️ [OutboxRepository] Deleted \(count) completed events older than \(date)")

        return count
    }

    @discardableResult
    func deleteAllEvents(forUserID userID: String) async throws -> Int {
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate { event in
                event.userID == userID
            }
        )

        let sdEvents = try modelContext.fetch(descriptor)
        let count = sdEvents.count

        for sdEvent in sdEvents {
            modelContext.delete(sdEvent)
        }

        try modelContext.save()

        print("🗑️ [OutboxRepository] Deleted \(count) events for user \(userID)")

        return count
    }

    // MARK: - Statistics</parameter>
    // MARK: - Statistics

    func getStatistics(forUserID userID: String?) async throws -> FitIQCore.OutboxStatistics {
        let pendingStatus = FitIQCore.OutboxEventStatus.pending.rawValue
        let processingStatus = FitIQCore.OutboxEventStatus.processing.rawValue
        let failedStatus = FitIQCore.OutboxEventStatus.failed.rawValue
        let completedStatus = FitIQCore.OutboxEventStatus.completed.rawValue

        var descriptor: FetchDescriptor<SDOutboxEvent>

        if let userID = userID {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.userID == userID
                }
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>()
        }

        let allEvents = try modelContext.fetch(descriptor)

        let pending = allEvents.filter { $0.status == pendingStatus }
        let processing = allEvents.filter { $0.status == processingStatus }
        let failed = allEvents.filter { $0.status == failedStatus }
        let completed = allEvents.filter { $0.status == completedStatus }

        // Find stale events (pending for more than 1 hour)
        let staleThreshold = Date().addingTimeInterval(-3600)
        let staleCount = pending.filter { $0.createdAt < staleThreshold }.count

        // Find oldest pending and newest completed
        let oldestPending = pending.min(by: { $0.createdAt < $1.createdAt })?.createdAt
        let newestCompleted = completed.max(by: {
            $0.completedAt ?? Date.distantPast < $1.completedAt ?? Date.distantPast
        })?.completedAt

        return FitIQCore.OutboxStatistics(
            totalEvents: allEvents.count,
            pendingCount: pending.count,
            processingCount: processing.count,
            completedCount: completed.count,
            failedCount: failed.count,
            staleCount: staleCount,
            oldestPendingDate: oldestPending,
            newestCompletedDate: newestCompleted
        )
    }

    func getStaleEvents(forUserID userID: String?) async throws -> [FitIQCore.OutboxEvent] {
        let staleThreshold = Date().addingTimeInterval(-3600)  // 1 hour ago
        let pendingStatus = FitIQCore.OutboxEventStatus.pending.rawValue

        var descriptor: FetchDescriptor<SDOutboxEvent>

        if let userID = userID {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.status == pendingStatus
                        && event.createdAt < staleThreshold
                        && event.userID == userID
                }
            )
        } else {
            descriptor = FetchDescriptor<SDOutboxEvent>(
                predicate: #Predicate { event in
                    event.status == pendingStatus && event.createdAt < staleThreshold
                }
            )
        }

        let sdStaleEvents = try modelContext.fetch(descriptor)

        if !sdStaleEvents.isEmpty {
            print(
                "⚠️ [OutboxRepository] Found \(sdStaleEvents.count) stale events (pending > 1 hour)"
            )
        }

        return try sdStaleEvents.map { try $0.toDomain() }
    }

    // MARK: - Private Helpers

    private func fetchSDEvent(byID id: UUID) throws -> SDOutboxEvent? {
        let descriptor = FetchDescriptor<SDOutboxEvent>(
            predicate: #Predicate { event in event.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}

// MARK: - Errors

enum OutboxError: Error, LocalizedError {
    case eventNotFound
    case saveFailed
    case fetchFailed
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .eventNotFound:
            return "Outbox event not found"
        case .saveFailed:
            return "Failed to save outbox event"
        case .fetchFailed:
            return "Failed to fetch outbox events"
        case .invalidPayload:
            return "Invalid event payload"
        }
    }
}
