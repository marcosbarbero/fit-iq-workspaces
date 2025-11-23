//
//  EmergencyCleanupOutboxUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import FitIQCore
import Foundation

/// Emergency cleanup use case to reset outbox and force fresh sync
///
/// **WARNING:** This is a destructive operation that:
/// - Deletes ALL outbox events (pending, failed, completed)
/// - Forces a fresh sync from local data
/// - Should only be used when the outbox is corrupted or stuck
///
/// **When to use:**
/// - When there are thousands of orphaned outbox events
/// - When the outbox processor is stuck
/// - When sync has completely broken down
/// - As a last resort to recover from sync issues
///
/// **After running this:**
/// - All progress entries will be re-synced to backend
/// - You may see duplicate data on backend (backend should handle deduplication)
/// - Outbox will be rebuilt from scratch
protocol EmergencyCleanupOutboxUseCase {
    /// Performs emergency cleanup of all outbox events
    /// - Parameter userID: User ID to clean up for
    /// - Returns: Number of events deleted
    func execute(forUserID userID: String) async throws -> EmergencyCleanupResult
}

/// Result of emergency cleanup operation
struct EmergencyCleanupResult {
    let totalEventsDeleted: Int
    let pendingDeleted: Int
    let failedDeleted: Int
    let processingDeleted: Int
    let completedDeleted: Int
    let progressEntriesFound: Int
    let newEventsCreated: Int

    func printReport() {
        print("\n" + String(repeating: "=", count: 80))
        print("EMERGENCY CLEANUP REPORT")
        print(String(repeating: "=", count: 80))
        print("")

        print("🗑️ OUTBOX EVENTS DELETED")
        print("  Total: \(totalEventsDeleted)")
        print("  Pending: \(pendingDeleted)")
        print("  Failed: \(failedDeleted)")
        print("  Processing: \(processingDeleted)")
        print("  Completed: \(completedDeleted)")
        print("")

        print("💾 PROGRESS ENTRIES")
        print("  Found: \(progressEntriesFound)")
        print("  New outbox events created: \(newEventsCreated)")
        print("")

        print("✅ CLEANUP COMPLETE")
        print("  The outbox has been reset")
        print("  OutboxProcessor will now sync all pending progress entries")
        print("  Monitor logs for 'OutboxProcessor: ✅✅✅ Progress entry FULLY SYNCED'")
        print(String(repeating: "=", count: 80))
        print("")
    }
}

/// Implementation of emergency cleanup use case
final class EmergencyCleanupOutboxUseCaseImpl: EmergencyCleanupOutboxUseCase {

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

    func execute(forUserID userID: String) async throws -> EmergencyCleanupResult {
        print("EmergencyCleanup: 🚨 STARTING EMERGENCY CLEANUP FOR USER \(userID)")
        print("EmergencyCleanup: ⚠️ This will delete ALL outbox events and force fresh sync")
        print("")

        // Step 1: Count existing events by status
        print("EmergencyCleanup: 📊 Step 1: Counting existing outbox events...")

        let pendingEvents = try await outboxRepository.fetchPendingEvents(
            forUserID: userID,
            limit: nil
        )

        let failedEvents = try await outboxRepository.fetchEvents(
            withStatus: .failed,
            forUserID: userID,
            limit: nil
        )

        let processingEvents = try await outboxRepository.fetchEvents(
            withStatus: .processing,
            forUserID: userID,
            limit: nil
        )

        let completedEvents = try await outboxRepository.fetchEvents(
            withStatus: .completed,
            forUserID: userID,
            limit: nil
        )

        let totalEvents =
            pendingEvents.count + failedEvents.count + processingEvents.count
            + completedEvents.count

        print("  Pending: \(pendingEvents.count)")
        print("  Failed: \(failedEvents.count)")
        print("  Processing: \(processingEvents.count)")
        print("  Completed: \(completedEvents.count)")
        print("  Total: \(totalEvents)")
        print("")

        // Step 2: Delete ALL outbox events (BULK DELETE for speed)
        print("EmergencyCleanup: 🗑️ Step 2: Deleting ALL outbox events (bulk operation)...")

        let deletedCount = try await outboxRepository.deleteAllEvents(forUserID: userID)

        print("  ✅ Deleted all \(deletedCount) outbox events in one batch")
        print("")

        // Step 3: Fetch all progress entries that need syncing
        print("EmergencyCleanup: 📥 Step 3: Finding progress entries that need syncing...")

        let allProgressEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: nil,
            limit: nil
        )

        // Only create outbox events for entries that aren't already synced
        let entriesToSync = allProgressEntries.filter { entry in
            entry.syncStatus != .synced
        }

        print("  Total progress entries: \(allProgressEntries.count)")
        print("  Entries needing sync: \(entriesToSync.count)")
        print("")

        // Step 4: Create new outbox events for unsynced entries
        print("EmergencyCleanup: 📦 Step 4: Creating fresh outbox events...")

        var newEventsCreated = 0
        for entry in entriesToSync {
            do {
                _ = try await outboxRepository.createEvent(
                    eventType: .progressEntry,
                    entityID: entry.id,
                    userID: userID,
                    isNewRecord: entry.backendID == nil,
                    metadata: .progressEntry(
                        metricType: entry.type.rawValue,
                        value: entry.quantity,
                        unit: entry.type.unit
                    ),
                    priority: 0
                )
                newEventsCreated += 1

                if newEventsCreated % 50 == 0 {
                    print("  Created \(newEventsCreated)/\(entriesToSync.count) events...")
                }
            } catch {
                print(
                    "  ⚠️ Failed to create outbox event for entry \(entry.id): \(error.localizedDescription)"
                )
            }
        }

        print("  ✅ Created \(newEventsCreated) new outbox events")
        print("")

        // Step 5: Verify cleanup
        print("EmergencyCleanup: ✅ Step 5: Verifying cleanup...")

        let remainingPending = try await outboxRepository.fetchPendingEvents(
            forUserID: userID,
            limit: nil
        )

        print("  Remaining pending events: \(remainingPending.count)")
        print("  Expected: \(newEventsCreated)")

        if remainingPending.count == newEventsCreated {
            print("  ✅ Verification passed!")
        } else {
            print("  ⚠️ Mismatch detected, but continuing...")
        }
        print("")

        let result = EmergencyCleanupResult(
            totalEventsDeleted: deletedCount,
            pendingDeleted: pendingEvents.count,
            failedDeleted: failedEvents.count,
            processingDeleted: processingEvents.count,
            completedDeleted: completedEvents.count,
            progressEntriesFound: allProgressEntries.count,
            newEventsCreated: newEventsCreated
        )

        result.printReport()

        return result
    }
}

/// Errors that can occur during emergency cleanup
enum EmergencyCleanupError: Error, LocalizedError {
    case cleanupFailed(String)
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cleanupFailed(let message):
            return "Emergency cleanup failed: \(message)"
        case .verificationFailed(let message):
            return "Cleanup verification failed: \(message)"
        }
    }
}
