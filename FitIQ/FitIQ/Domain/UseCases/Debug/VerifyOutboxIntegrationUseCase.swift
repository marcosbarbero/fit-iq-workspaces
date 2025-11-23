//
//  VerifyOutboxIntegrationUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import FitIQCore
import Foundation

/// Protocol for verifying Outbox Pattern integration
protocol VerifyOutboxIntegrationUseCase {
    /// Verifies that the Outbox Pattern is working correctly for progress entries
    /// - Parameters:
    ///   - metricType: The type of progress metric to verify (steps, heart rate, etc.)
    ///   - maxAge: Maximum age of events to check (in seconds, default 300 = 5 minutes)
    /// - Returns: Verification result with detailed status
    func execute(
        for metricType: ProgressMetricType?,
        maxAge: TimeInterval
    ) async throws -> OutboxVerificationResult
}

/// Implementation of VerifyOutboxIntegrationUseCase
final class VerifyOutboxIntegrationUseCaseImpl: VerifyOutboxIntegrationUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol
    private let outboxRepository: OutboxRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        progressRepository: ProgressRepositoryProtocol,
        outboxRepository: OutboxRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.outboxRepository = outboxRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(
        for metricType: ProgressMetricType? = nil,
        maxAge: TimeInterval = 300
    ) async throws -> OutboxVerificationResult {
        print(
            "VerifyOutboxIntegration: Starting verification for \(metricType?.rawValue ?? "all types")"
        )

        // Check authentication
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw OutboxVerificationError.userNotAuthenticated
        }

        // Fetch progress entries
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: metricType,
            syncStatus: nil,
            limit: 1000  // Limit to recent entries for performance
        )

        print("VerifyOutboxIntegration: Found \(allEntries.count) total entries")

        // Categorize by sync status
        let pendingEntries = allEntries.filter { $0.syncStatus == .pending }
        let syncedEntries = allEntries.filter { $0.syncStatus == .synced }
        let failedEntries = allEntries.filter { $0.syncStatus == .failed }

        print(
            "VerifyOutboxIntegration: Pending: \(pendingEntries.count), Synced: \(syncedEntries.count), Failed: \(failedEntries.count)"
        )

        // Fetch outbox events
        let allEvents = try await outboxRepository.fetchPendingEvents(
            forUserID: userID,
            limit: nil  // No limit - fetch all pending events
        )
        let progressEvents = allEvents.filter { $0.eventType == .progressEntry }

        print("VerifyOutboxIntegration: Found \(progressEvents.count) pending outbox events")

        // Check for orphaned events (events without corresponding entries)
        var orphanedEvents: [UUID] = []
        for event in progressEvents {
            let entryExists = allEntries.contains { $0.id == event.entityID }
            if !entryExists {
                orphanedEvents.append(event.id)
                print(
                    "VerifyOutboxIntegration: ⚠️ Orphaned event: \(event.id) - no matching progress entry"
                )
            }
        }

        // Check for stuck events (pending > maxAge)
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        let stuckEvents = progressEvents.filter { event in
            event.createdAt < cutoffDate && event.status == .pending
        }

        if !stuckEvents.isEmpty {
            print(
                "VerifyOutboxIntegration: ⚠️ Found \(stuckEvents.count) stuck events (older than \(Int(maxAge))s)"
            )
            for event in stuckEvents.prefix(5) {
                let age = Date().timeIntervalSince(event.createdAt)
                print(
                    "  - Event \(event.id): Age: \(Int(age))s, Attempts: \(event.attemptCount), Error: \(event.errorMessage ?? "none")"
                )
            }
        }

        // Check for missing outbox events (pending entries without events)
        var missingEvents: [UUID] = []
        for entry in pendingEntries {
            let hasEvent = progressEvents.contains { $0.entityID == entry.id }
            if !hasEvent {
                missingEvents.append(entry.id)
                print(
                    "VerifyOutboxIntegration: ⚠️ Missing outbox event for pending entry: \(entry.id)"
                )
            }
        }

        // Check for inconsistencies (synced entries should have backendID)
        var inconsistentEntries: [UUID] = []
        for entry in syncedEntries {
            if entry.backendID == nil {
                inconsistentEntries.append(entry.id)
                print("VerifyOutboxIntegration: ⚠️ Synced entry without backendID: \(entry.id)")
            }
        }

        // Calculate metrics
        let totalEntries = allEntries.count
        let syncRate = totalEntries > 0 ? Double(syncedEntries.count) / Double(totalEntries) : 0.0

        // Calculate average processing time for completed events
        let completedEvents = try await fetchCompletedEvents(forUserID: userID, limit: 100)
        let avgProcessingTime = calculateAverageProcessingTime(completedEvents)

        // Determine overall health
        let isHealthy =
            orphanedEvents.isEmpty
            && missingEvents.isEmpty
            && inconsistentEntries.isEmpty
            && stuckEvents.count < 5
            && failedEntries.count < 10

        let result = OutboxVerificationResult(
            timestamp: Date(),
            metricType: metricType,
            userID: userID,
            totalEntries: totalEntries,
            pendingEntries: pendingEntries.count,
            syncedEntries: syncedEntries.count,
            failedEntries: failedEntries.count,
            pendingEvents: progressEvents.count,
            stuckEvents: stuckEvents.count,
            orphanedEvents: orphanedEvents.count,
            missingEvents: missingEvents.count,
            inconsistentEntries: inconsistentEntries.count,
            syncRate: syncRate,
            averageProcessingTime: avgProcessingTime,
            isHealthy: isHealthy,
            issues: buildIssuesList(
                orphanedEvents: orphanedEvents,
                missingEvents: missingEvents,
                inconsistentEntries: inconsistentEntries,
                stuckEvents: stuckEvents,
                failedEntries: failedEntries
            )
        )

        print("VerifyOutboxIntegration: ✅ Verification complete - Healthy: \(isHealthy)")
        print("VerifyOutboxIntegration: Sync Rate: \(String(format: "%.1f%%", syncRate * 100))")
        if let avgTime = avgProcessingTime {
            print(
                "VerifyOutboxIntegration: Avg Processing Time: \(String(format: "%.2fs", avgTime))")
        }

        return result
    }

    // MARK: - Helper Methods

    private func fetchCompletedEvents(forUserID userID: String, limit: Int) async throws
        -> [OutboxEvent]
    {
        // Note: This assumes OutboxRepository has a method to fetch completed events
        // If not available, return empty array
        return []
    }

    private func calculateAverageProcessingTime(_ events: [OutboxEvent]) -> TimeInterval? {
        let timesWithCompletion = events.compactMap { event -> TimeInterval? in
            guard let completedAt = event.completedAt else { return nil }
            return completedAt.timeIntervalSince(event.createdAt)
        }

        guard !timesWithCompletion.isEmpty else { return nil }

        let sum = timesWithCompletion.reduce(0, +)
        return sum / Double(timesWithCompletion.count)
    }

    private func buildIssuesList(
        orphanedEvents: [UUID],
        missingEvents: [UUID],
        inconsistentEntries: [UUID],
        stuckEvents: [OutboxEvent],
        failedEntries: [ProgressEntry]
    ) -> [OutboxVerificationIssue] {
        var issues: [OutboxVerificationIssue] = []

        if !orphanedEvents.isEmpty {
            issues.append(.orphanedEvents(count: orphanedEvents.count, ids: orphanedEvents))
        }

        if !missingEvents.isEmpty {
            issues.append(.missingOutboxEvents(count: missingEvents.count, ids: missingEvents))
        }

        if !inconsistentEntries.isEmpty {
            issues.append(
                .inconsistentSyncStatus(count: inconsistentEntries.count, ids: inconsistentEntries))
        }

        if !stuckEvents.isEmpty {
            let stuckEventIDs = stuckEvents.map { $0.id }
            issues.append(.stuckEvents(count: stuckEvents.count, ids: stuckEventIDs))
        }

        if !failedEntries.isEmpty {
            let failedEntryIDs = failedEntries.map { $0.id }
            issues.append(.failedEntries(count: failedEntries.count, ids: failedEntryIDs))
        }

        return issues
    }
}

// MARK: - Result Model

/// Result of outbox verification
public struct OutboxVerificationResult {
    /// Timestamp when verification was performed
    let timestamp: Date

    /// Metric type that was verified (nil = all types)
    let metricType: ProgressMetricType?

    /// User ID for which verification was performed
    let userID: String

    /// Total number of progress entries
    let totalEntries: Int

    /// Number of pending entries
    let pendingEntries: Int

    /// Number of synced entries
    let syncedEntries: Int

    /// Number of failed entries
    let failedEntries: Int

    /// Number of pending outbox events
    let pendingEvents: Int

    /// Number of stuck events (pending > maxAge)
    let stuckEvents: Int

    /// Number of orphaned events (no matching entry)
    let orphanedEvents: Int

    /// Number of pending entries without outbox events
    let missingEvents: Int

    /// Number of synced entries without backendID
    let inconsistentEntries: Int

    /// Sync success rate (0.0 to 1.0)
    let syncRate: Double

    /// Average time from event creation to completion (seconds)
    let averageProcessingTime: TimeInterval?

    /// Overall health status
    let isHealthy: Bool

    /// List of issues found
    let issues: [OutboxVerificationIssue]

    /// Human-readable summary
    var summary: String {
        var lines: [String] = []
        lines.append("=== Outbox Verification Report ===")
        lines.append("Timestamp: \(timestamp)")
        lines.append("Metric: \(metricType?.displayName ?? "All Types")")
        lines.append("User: \(userID)")
        lines.append("")
        lines.append("--- Entries ---")
        lines.append("Total: \(totalEntries)")
        lines.append("Pending: \(pendingEntries)")
        lines.append("Synced: \(syncedEntries)")
        lines.append("Failed: \(failedEntries)")
        lines.append("Sync Rate: \(String(format: "%.1f%%", syncRate * 100))")
        lines.append("")
        lines.append("--- Outbox Events ---")
        lines.append("Pending Events: \(pendingEvents)")
        lines.append("Stuck Events: \(stuckEvents)")
        lines.append("Orphaned Events: \(orphanedEvents)")
        lines.append("Missing Events: \(missingEvents)")
        lines.append("")
        lines.append("--- Health ---")
        lines.append("Status: \(isHealthy ? "✅ Healthy" : "⚠️ Issues Detected")")
        lines.append("Inconsistent Entries: \(inconsistentEntries)")
        if let avgTime = averageProcessingTime {
            lines.append("Avg Processing Time: \(String(format: "%.2fs", avgTime))")
        }

        if !issues.isEmpty {
            lines.append("")
            lines.append("--- Issues ---")
            for issue in issues {
                lines.append("• \(issue.description)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Issue Types

public enum OutboxVerificationIssue {
    case orphanedEvents(count: Int, ids: [UUID])
    case missingOutboxEvents(count: Int, ids: [UUID])
    case inconsistentSyncStatus(count: Int, ids: [UUID])
    case stuckEvents(count: Int, ids: [UUID])
    case failedEntries(count: Int, ids: [UUID])

    var description: String {
        switch self {
        case .orphanedEvents(let count, _):
            return "Orphaned Events: \(count) outbox events without matching progress entries"
        case .missingOutboxEvents(let count, _):
            return "Missing Events: \(count) pending entries without outbox events"
        case .inconsistentSyncStatus(let count, _):
            return "Inconsistent Status: \(count) synced entries missing backendID"
        case .stuckEvents(let count, _):
            return "Stuck Events: \(count) events pending for too long"
        case .failedEntries(let count, _):
            return "Failed Entries: \(count) entries marked as failed"
        }
    }
}

// MARK: - Errors

enum OutboxVerificationError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to verify outbox integration"
        }
    }
}
