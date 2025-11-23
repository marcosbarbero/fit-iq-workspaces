//
//  OptimizeDatabaseUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import FitIQCore
import Foundation
import SwiftData

/// Protocol defining database optimization operations
protocol OptimizeDatabaseUseCase {
    /// Performs database optimization (cleanup, deduplication, vacuuming)
    func execute() async throws
}

/// Implementation of database optimization use case
/// Handles periodic cleanup and optimization of SwiftData store
final class OptimizeDatabaseUseCaseImpl: OptimizeDatabaseUseCase {

    // MARK: - Configuration

    /// Keep progress entries for last N days (older entries are removed)
    private let progressRetentionDays: Int = 365

    /// Keep outbox events for last N days (older completed events are removed)
    private let outboxRetentionDays: Int = 7

    /// Keep activity snapshots for last N days
    private let activitySnapshotRetentionDays: Int = 365

    // MARK: - Dependencies (Ports)

    private let progressRepository: ProgressRepositoryProtocol
    private let outboxRepository: OutboxRepositoryProtocol
    private let activitySnapshotRepository: ActivitySnapshotRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Init

    init(
        progressRepository: ProgressRepositoryProtocol,
        outboxRepository: OutboxRepositoryProtocol,
        activitySnapshotRepository: ActivitySnapshotRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.outboxRepository = outboxRepository
        self.activitySnapshotRepository = activitySnapshotRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("🔧 OptimizeDatabaseUseCase: Starting database optimization")
        print(String(repeating: "=", count: 60))

        let startTime = Date()
        var tasksCompleted = 0
        var tasksSkipped = 0

        // Task 1: Cleanup old completed outbox events
        do {
            print("\n📦 Cleaning up old outbox events...")
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -outboxRetentionDays,
                to: Date()
            )!

            // Delete completed events older than retention period
            let deletedCount = try await outboxRepository.deleteCompletedEvents(
                olderThan: cutoffDate)
            print("✅ Outbox cleanup completed - deleted \(deletedCount) old events")
            tasksCompleted += 1
        } catch {
            print("⚠️ Outbox cleanup failed: \(error.localizedDescription)")
            tasksSkipped += 1
        }

        // Task 2: Cleanup old progress entries (keep last 365 days)
        do {
            print("\n📊 Cleaning up old progress entries...")
            guard authManager.currentUserProfileID?.uuidString != nil else {
                print("⚠️ No user ID available, skipping progress cleanup")
                tasksSkipped += 1
                throw OptimizeDatabaseError.noUserID
            }

            _ = Calendar.current.date(
                byAdding: .day,
                value: -progressRetentionDays,
                to: Date()
            )!

            // Note: This would require a new method in ProgressRepository
            // For now, we'll skip this to avoid errors
            print("⚠️ Progress cleanup not yet implemented (requires new repository method)")
            tasksSkipped += 1
        } catch {
            print("⚠️ Progress cleanup skipped: \(error.localizedDescription)")
            tasksSkipped += 1
        }

        // Task 3: Cleanup old activity snapshots (keep last 365 days)
        do {
            print("\n📸 Cleaning up old activity snapshots...")
            guard authManager.currentUserProfileID != nil else {
                print("⚠️ No user ID available, skipping activity cleanup")
                tasksSkipped += 1
                throw OptimizeDatabaseError.noUserID
            }

            _ = Calendar.current.date(
                byAdding: .day,
                value: -activitySnapshotRetentionDays,
                to: Date()
            )!

            // Note: This would require a new method in ActivitySnapshotRepository
            print("⚠️ Activity snapshot cleanup not yet implemented")
            tasksSkipped += 1
        } catch {
            print("⚠️ Activity cleanup skipped: \(error.localizedDescription)")
            tasksSkipped += 1
        }

        // Task 4: Log database statistics
        print("\n📈 Database Statistics:")
        // These would require new repository methods to get counts
        print("   Progress entries: N/A (requires new method)")
        print("   Outbox events: N/A (requires new method)")
        print("   Activity snapshots: N/A (requires new method)")

        let duration = Date().timeIntervalSince(startTime)
        print("\n" + String(repeating: "=", count: 60))
        print("✅ Database optimization completed in \(String(format: "%.2f", duration))s")
        print("   Tasks completed: \(tasksCompleted)")
        print("   Tasks skipped: \(tasksSkipped)")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Errors

enum OptimizeDatabaseError: LocalizedError {
    case noUserID
    case cleanupFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noUserID:
            return "No user ID available for database optimization"
        case .cleanupFailed(let error):
            return "Database cleanup failed: \(error.localizedDescription)"
        }
    }
}
