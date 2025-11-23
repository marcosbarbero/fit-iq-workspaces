//
//  CleanupOrphanedOutboxEventsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import FitIQCore
import Foundation

/// Use case to clean up orphaned outbox events
///
/// This use case finds and removes outbox events that reference
/// progress entries that no longer exist in the database.
///
/// **When to use:**
/// - After deleting progress entries
/// - When debugging sync issues
/// - During app maintenance/cleanup
///
/// **Architecture:**
/// - Domain layer use case
/// - Depends only on repository protocols
/// - No external dependencies
protocol CleanupOrphanedOutboxEventsUseCase {
    /// Cleans up orphaned outbox events for a specific user
    /// - Parameter userID: User ID to clean up events for
    /// - Returns: Number of orphaned events cleaned up
    func execute(forUserID userID: String) async throws -> Int
}

/// Implementation of cleanup orphaned outbox events use case
final class CleanupOrphanedOutboxEventsUseCaseImpl: CleanupOrphanedOutboxEventsUseCase {

    // MARK: - Properties

    private let outboxRepository: OutboxRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol

    // MARK: - Initialization

    init(
        outboxRepository: OutboxRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol
    ) {
        self.outboxRepository = outboxRepository
        self.progressRepository = progressRepository
    }

    // MARK: - Use Case Execution

    func execute(forUserID userID: String) async throws -> Int {
        print("CleanupOrphanedOutboxEvents: 🧹 Starting cleanup for user \(userID)")

        // Step 1: Fetch all pending progress entry outbox events
        let pendingEvents = try await outboxRepository.fetchPendingEvents(
            forUserID: userID,
            limit: nil  // Get all pending events
        )

        let progressEvents = pendingEvents.filter { event in
            event.eventType == .progressEntry
        }

        print(
            "CleanupOrphanedOutboxEvents: Found \(progressEvents.count) pending progress entry events"
        )

        guard !progressEvents.isEmpty else {
            print("CleanupOrphanedOutboxEvents: ✅ No progress entry events to check")
            return 0
        }

        // Step 2: Fetch all progress entries from local storage
        let allProgressEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: nil,
            limit: nil
        )

        let progressEntryIDs = Set(allProgressEntries.map { $0.id })
        print(
            "CleanupOrphanedOutboxEvents: Found \(progressEntryIDs.count) progress entries in database"
        )

        // Step 3: Find orphaned events (events referencing non-existent progress entries)
        let orphanedEventIDs = progressEvents.filter { event in
            !progressEntryIDs.contains(event.entityID)
        }.map { $0.entityID }

        print("CleanupOrphanedOutboxEvents: Found \(orphanedEventIDs.count) orphaned event(s)")

        guard !orphanedEventIDs.isEmpty else {
            print("CleanupOrphanedOutboxEvents: ✅ No orphaned events found")
            return 0
        }

        // Step 4: Delete orphaned events
        print(
            "CleanupOrphanedOutboxEvents: 🗑️ Deleting \(orphanedEventIDs.count) orphaned event(s)..."
        )
        for (index, entityID) in orphanedEventIDs.enumerated() {
            print("  [\(index + 1)/\(orphanedEventIDs.count)] Entity ID: \(entityID)")
        }

        let deletedCount = try await outboxRepository.deleteEvents(forEntityIDs: orphanedEventIDs)

        print(
            "CleanupOrphanedOutboxEvents: ✅ Successfully deleted \(deletedCount) orphaned event(s)")

        // Step 5: Verify cleanup
        let remainingEvents = try await outboxRepository.fetchPendingEvents(
            forUserID: userID,
            limit: nil
        )

        let remainingProgressEvents = remainingEvents.filter { event in
            event.eventType == .progressEntry
        }

        print(
            "CleanupOrphanedOutboxEvents: 📊 Remaining pending progress events: \(remainingProgressEvents.count)"
        )

        return deletedCount
    }
}

/// Errors that can occur during cleanup
enum CleanupOrphanedOutboxEventsError: Error, LocalizedError {
    case cleanupFailed(String)

    var errorDescription: String? {
        switch self {
        case .cleanupFailed(let message):
            return "Cleanup failed: \(message)"
        }
    }
}
