//
//  DebugOutboxStatusUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import FitIQCore
import Foundation

/// Use case to debug outbox and progress entry status
///
/// This use case provides detailed diagnostic information about:
/// - Current outbox events (pending, processing, failed, completed)
/// - Progress entries in local storage
/// - Matching between outbox events and progress entries
/// - Authentication state
///
/// **When to use:**
/// - Debugging sync issues
/// - Investigating why data isn't syncing
/// - Checking for orphaned events
/// - Verifying authentication state
protocol DebugOutboxStatusUseCase {
    /// Gets comprehensive debug information about outbox and sync state
    /// - Parameter userID: User ID to check status for
    /// - Returns: Detailed debug report
    func execute(forUserID userID: String) async throws -> DebugOutboxReport
}

/// Debug report containing outbox and sync status
struct DebugOutboxReport {
    let userID: String
    let timestamp: Date

    // Authentication
    let isAuthenticated: Bool
    let currentUserProfileID: String?

    // Outbox Events
    let totalOutboxEvents: Int
    let pendingEvents: [OutboxEventSummary]
    let processingEvents: [OutboxEventSummary]
    let failedEvents: [OutboxEventSummary]
    let completedEventsCount: Int

    // Progress Entries
    let totalProgressEntries: Int
    let pendingProgressEntries: Int
    let syncedProgressEntries: Int
    let failedProgressEntries: Int

    // Orphaned Events
    let orphanedEventCount: Int
    let orphanedEvents: [OutboxEventSummary]

    // Health
    var isHealthy: Bool {
        return isAuthenticated && orphanedEventCount == 0 && failedEvents.count == 0
            && (pendingEvents.count < 20)
    }

    var issues: [String] {
        var problems: [String] = []

        if !isAuthenticated {
            problems.append("❌ User not authenticated")
        }

        if orphanedEventCount > 0 {
            problems.append("❌ \(orphanedEventCount) orphaned outbox event(s) found")
        }

        if failedEvents.count > 0 {
            problems.append("⚠️ \(failedEvents.count) failed outbox event(s)")
        }

        if pendingEvents.count > 20 {
            problems.append("⚠️ High number of pending events (\(pendingEvents.count))")
        }

        if failedProgressEntries > 0 {
            problems.append("⚠️ \(failedProgressEntries) failed progress entries")
        }

        return problems
    }

    func printReport() {
        print("\n" + String(repeating: "=", count: 80))
        print("OUTBOX DEBUG REPORT")
        print(String(repeating: "=", count: 80))
        print("Generated: \(timestamp)")
        print("User ID: \(userID)")
        print("")

        print("🔐 AUTHENTICATION")
        print("  Authenticated: \(isAuthenticated ? "✅ YES" : "❌ NO")")
        print("  Current User Profile ID: \(currentUserProfileID ?? "nil")")
        print("")

        print("📦 OUTBOX EVENTS")
        print("  Total: \(totalOutboxEvents)")
        print("  Pending: \(pendingEvents.count)")
        print("  Processing: \(processingEvents.count)")
        print("  Failed: \(failedEvents.count)")
        print("  Completed: \(completedEventsCount)")
        print("")

        if !pendingEvents.isEmpty {
            print("  📝 Pending Events:")
            for (index, event) in pendingEvents.prefix(10).enumerated() {
                print(
                    "    [\(index + 1)] \(event.eventType) | Entity: \(event.entityID) | Created: \(event.createdAt)"
                )
            }
            if pendingEvents.count > 10 {
                print("    ... and \(pendingEvents.count - 10) more")
            }
            print("")
        }

        if !failedEvents.isEmpty {
            print("  ❌ Failed Events:")
            for (index, event) in failedEvents.prefix(5).enumerated() {
                print("    [\(index + 1)] \(event.eventType) | Entity: \(event.entityID)")
                print("        Error: \(event.errorMessage ?? "Unknown")")
                print("        Attempts: \(event.attemptCount)")
            }
            if failedEvents.count > 5 {
                print("    ... and \(failedEvents.count - 5) more")
            }
            print("")
        }

        print("💾 PROGRESS ENTRIES")
        print("  Total: \(totalProgressEntries)")
        print("  Pending Sync: \(pendingProgressEntries)")
        print("  Synced: \(syncedProgressEntries)")
        print("  Failed: \(failedProgressEntries)")
        print("")

        print("🗑️ ORPHANED EVENTS")
        print("  Count: \(orphanedEventCount)")
        if orphanedEventCount > 0 {
            print("  Events referencing non-existent entities:")
            for (index, event) in orphanedEvents.prefix(10).enumerated() {
                print("    [\(index + 1)] \(event.eventType) | Entity: \(event.entityID)")
                if let error = event.errorMessage {
                    print("        Error: \(error)")
                }
            }
            if orphanedEvents.count > 10 {
                print("    ... and \(orphanedEvents.count - 10) more")
            }
        }
        print("")

        print("🏥 HEALTH STATUS")
        if isHealthy {
            print("  ✅ HEALTHY - Sync system is working correctly")
        } else {
            print("  ❌ ISSUES DETECTED:")
            for issue in issues {
                print("    \(issue)")
            }
        }

        print(String(repeating: "=", count: 80))
        print("")
    }
}

/// Summary of an outbox event for debugging
struct OutboxEventSummary {
    let id: UUID
    let eventType: String
    let entityID: UUID
    let status: String
    let createdAt: Date
    let attemptCount: Int
    let errorMessage: String?
}

/// Implementation of debug outbox status use case
final class DebugOutboxStatusUseCaseImpl: DebugOutboxStatusUseCase {

    // MARK: - Properties

    private let outboxRepository: OutboxRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        outboxRepository: OutboxRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.outboxRepository = outboxRepository
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    // MARK: - Use Case Execution

    func execute(forUserID userID: String) async throws -> DebugOutboxReport {
        print("DebugOutboxStatus: 🔍 Collecting diagnostic information for user \(userID)...")

        // 1. Check authentication
        let isAuthenticated = authManager.currentUserProfileID != nil
        let currentUserProfileID = authManager.currentUserProfileID?.uuidString

        // 2. Fetch all outbox events
        let allPendingEvents = try await outboxRepository.fetchPendingEvents(
            forUserID: userID,
            limit: nil
        )

        let allFailedEvents = try await outboxRepository.fetchEvents(
            withStatus: .failed,
            forUserID: userID,
            limit: nil
        )

        let allProcessingEvents = try await outboxRepository.fetchEvents(
            withStatus: .processing,
            forUserID: userID,
            limit: nil
        )

        let allCompletedEvents = try await outboxRepository.fetchEvents(
            withStatus: .completed,
            forUserID: userID,
            limit: 100
        )

        // 3. Fetch all progress entries
        let allProgressEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: nil,
            limit: nil
        )

        let pendingProgressEntries = allProgressEntries.filter { $0.syncStatus == .pending }.count
        let syncedProgressEntries = allProgressEntries.filter { $0.syncStatus == .synced }.count
        let failedProgressEntries = allProgressEntries.filter { $0.syncStatus == .failed }.count

        // 4. Find orphaned events
        let progressEntryIDs = Set(allProgressEntries.map { $0.id })

        let progressEvents = allPendingEvents.filter { event in
            event.eventType == .progressEntry
        }

        let orphanedEvents = progressEvents.filter { event in
            !progressEntryIDs.contains(event.entityID)
        }

        // 5. Convert to summaries
        let pendingSummaries = allPendingEvents.map { event in
            OutboxEventSummary(
                id: event.id,
                eventType: event.eventType.rawValue,
                entityID: event.entityID,
                status: event.status.rawValue,
                createdAt: event.createdAt,
                attemptCount: event.attemptCount,
                errorMessage: event.errorMessage
            )
        }

        let failedSummaries = allFailedEvents.map { event in
            OutboxEventSummary(
                id: event.id,
                eventType: event.eventType.rawValue,
                entityID: event.entityID,
                status: event.status.rawValue,
                createdAt: event.createdAt,
                attemptCount: event.attemptCount,
                errorMessage: event.errorMessage
            )
        }

        let processingSummaries = allProcessingEvents.map { event in
            OutboxEventSummary(
                id: event.id,
                eventType: event.eventType.rawValue,
                entityID: event.entityID,
                status: event.status.rawValue,
                createdAt: event.createdAt,
                attemptCount: event.attemptCount,
                errorMessage: event.errorMessage
            )
        }

        let orphanedSummaries = orphanedEvents.map { event in
            OutboxEventSummary(
                id: event.id,
                eventType: event.eventType.rawValue,
                entityID: event.entityID,
                status: event.status.rawValue,
                createdAt: event.createdAt,
                attemptCount: event.attemptCount,
                errorMessage: event.errorMessage
            )
        }

        let totalOutboxEvents =
            allPendingEvents.count + allFailedEvents.count + allProcessingEvents.count
            + allCompletedEvents.count

        return DebugOutboxReport(
            userID: userID,
            timestamp: Date(),
            isAuthenticated: isAuthenticated,
            currentUserProfileID: currentUserProfileID,
            totalOutboxEvents: totalOutboxEvents,
            pendingEvents: pendingSummaries,
            processingEvents: processingSummaries,
            failedEvents: failedSummaries,
            completedEventsCount: allCompletedEvents.count,
            totalProgressEntries: allProgressEntries.count,
            pendingProgressEntries: pendingProgressEntries,
            syncedProgressEntries: syncedProgressEntries,
            failedProgressEntries: failedProgressEntries,
            orphanedEventCount: orphanedEvents.count,
            orphanedEvents: orphanedSummaries
        )
    }
}
