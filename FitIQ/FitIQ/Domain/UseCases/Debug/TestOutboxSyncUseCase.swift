//
//  TestOutboxSyncUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import FitIQCore
import Foundation

/// Protocol for testing Outbox Pattern sync with sample data
protocol TestOutboxSyncUseCase {
    /// Creates test progress entries and monitors their sync status
    /// - Parameters:
    ///   - metricType: The type of metric to test (.steps, .restingHeartRate, etc.)
    ///   - count: Number of test entries to create
    ///   - waitForSync: Whether to wait for sync completion
    /// - Returns: Test result with entry IDs and sync status
    func execute(
        metricType: ProgressMetricType,
        count: Int,
        waitForSync: Bool
    ) async throws -> OutboxSyncTestResult
}

/// Implementation of TestOutboxSyncUseCase
final class TestOutboxSyncUseCaseImpl: TestOutboxSyncUseCase {

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
        metricType: ProgressMetricType,
        count: Int = 5,
        waitForSync: Bool = true
    ) async throws -> OutboxSyncTestResult {
        print("TestOutboxSync: Starting test for \(metricType.rawValue) with \(count) entries")

        // Check authentication
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw TestOutboxSyncError.userNotAuthenticated
        }

        var createdEntryIDs: [UUID] = []
        var createdEventIDs: [UUID] = []

        // Create test entries
        for i in 0..<count {
            let quantity = generateTestQuantity(for: metricType, index: i)
            let date = Date().addingTimeInterval(TimeInterval(-3600 * i))  // Stagger by 1 hour

            let progressEntry = ProgressEntry(
                id: UUID(),
                userID: userID,
                type: metricType,
                quantity: quantity,
                date: date,
                time: formatTime(date),
                notes: "Test entry \(i + 1)/\(count)",
                createdAt: Date(),
                backendID: nil,
                syncStatus: .pending
            )

            // Save entry
            let localID = try await progressRepository.save(
                progressEntry: progressEntry,
                forUserID: userID
            )

            createdEntryIDs.append(localID)
            print("TestOutboxSync: Created entry \(i + 1)/\(count) - ID: \(localID)")

            // Wait a bit to allow outbox event creation
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }

        // Fetch created outbox events
        for entryID in createdEntryIDs {
            let events = try await outboxRepository.fetchEvents(
                forEntityID: entryID,
                eventType: .progressEntry
            )

            if let event = events.first {
                createdEventIDs.append(event.id)
                print("TestOutboxSync: Found outbox event \(event.id) for entry \(entryID)")
            } else {
                print("TestOutboxSync: ⚠️ No outbox event found for entry \(entryID)")
            }
        }

        print(
            "TestOutboxSync: Created \(createdEntryIDs.count) entries and \(createdEventIDs.count) events"
        )

        // Wait for sync if requested
        var syncedCount = 0
        var failedCount = 0
        var timeoutCount = 0

        if waitForSync {
            print("TestOutboxSync: Waiting for sync (max 2 minutes)...")

            let startTime = Date()
            let timeout: TimeInterval = 120  // 2 minutes

            while syncedCount < createdEntryIDs.count
                && Date().timeIntervalSince(startTime)
                    < timeout
            {
                // Check sync status of each entry
                syncedCount = 0
                failedCount = 0

                for entryID in createdEntryIDs {
                    let entries = try await progressRepository.fetchLocal(
                        forUserID: userID,
                        type: metricType,
                        syncStatus: nil,
                        limit: 100
                    )

                    if let entry = entries.first(where: { $0.id == entryID }) {
                        switch entry.syncStatus {
                        case .synced:
                            syncedCount += 1
                        case .failed:
                            failedCount += 1
                        case .pending, .syncing:
                            break
                        }
                    }
                }

                if syncedCount == createdEntryIDs.count {
                    print("TestOutboxSync: ✅ All entries synced!")
                    break
                }

                if failedCount > 0 {
                    print("TestOutboxSync: ⚠️ \(failedCount) entries failed")
                }

                // Wait before checking again
                try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            }

            if syncedCount < createdEntryIDs.count {
                timeoutCount = createdEntryIDs.count - syncedCount - failedCount
                print(
                    "TestOutboxSync: ⏱️ Timeout - \(syncedCount) synced, \(failedCount) failed, \(timeoutCount) still pending"
                )
            }
        }

        // Fetch final status
        let finalEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: metricType,
            syncStatus: nil,
            limit: 100
        )

        let testEntries = finalEntries.filter { createdEntryIDs.contains($0.id) }

        let result = OutboxSyncTestResult(
            metricType: metricType,
            totalEntries: count,
            createdEntryIDs: createdEntryIDs,
            createdEventIDs: createdEventIDs,
            syncedCount: syncedCount,
            failedCount: failedCount,
            pendingCount: count - syncedCount - failedCount,
            waitedForSync: waitForSync,
            entries: testEntries
        )

        print("TestOutboxSync: Test complete - \(result.summary)")
        return result
    }

    // MARK: - Helper Methods

    private func generateTestQuantity(for metricType: ProgressMetricType, index: Int) -> Double {
        switch metricType {
        case .steps:
            return Double(1000 + (index * 500))  // 1000, 1500, 2000, etc.
        case .restingHeartRate:
            return Double(60 + (index * 2))  // 60, 62, 64, etc.
        case .weight:
            return 70.0 + Double(index) * 0.5  // 70.0, 70.5, 71.0, etc.
        case .height:
            return 170.0 + Double(index) * 0.1  // 170.0, 170.1, 170.2, etc.
        case .caloriesOut:
            return Double(200 + (index * 50))  // 200, 250, 300, etc.
        case .distanceKm:
            return Double(1 + index) * 0.5  // 0.5, 1.0, 1.5, etc.
        case .activeMinutes:
            return Double(10 + (index * 5))  // 10, 15, 20, etc.
        case .sleepHours:
            return 7.0 + Double(index) * 0.5  // 7.0, 7.5, 8.0, etc.
        case .waterLiters:
            return 2.0 + Double(index) * 0.25  // 2.0, 2.25, 2.5, etc.
        case .moodScore:
            return Double(5 + (index % 5))  // 5, 6, 7, 8, 9, then repeat
        case .caloriesIn:
            return Double(500 + (index * 100))  // 500, 600, 700, etc.
        case .proteinG:
            return Double(20 + (index * 5))  // 20, 25, 30, etc.
        case .carbsG:
            return Double(50 + (index * 10))  // 50, 60, 70, etc.
        case .fatG:
            return Double(15 + (index * 3))  // 15, 18, 21, etc.
        case .bodyFatPercentage:
            return 20.0 + Double(index) * 0.1  // 20.0, 20.1, 20.2, etc.
        case .bmi:
            return 22.0 + Double(index) * 0.1  // 22.0, 22.1, 22.2, etc.
        }
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d:00", hour, minute)
    }
}

// MARK: - Result Model

/// Result of outbox sync test
public struct OutboxSyncTestResult {
    /// Metric type that was tested
    let metricType: ProgressMetricType

    /// Total number of entries created
    let totalEntries: Int

    /// IDs of created progress entries
    let createdEntryIDs: [UUID]

    /// IDs of created outbox events
    let createdEventIDs: [UUID]

    /// Number of entries that synced successfully
    let syncedCount: Int

    /// Number of entries that failed to sync
    let failedCount: Int

    /// Number of entries still pending
    let pendingCount: Int

    /// Whether test waited for sync completion
    let waitedForSync: Bool

    /// The actual entries (with final status)
    let entries: [ProgressEntry]

    /// Success rate (0.0 to 1.0)
    var successRate: Double {
        guard totalEntries > 0 else { return 0.0 }
        return Double(syncedCount) / Double(totalEntries)
    }

    /// Whether test was successful (all synced or not waiting)
    var isSuccessful: Bool {
        if waitedForSync {
            return syncedCount == totalEntries
        } else {
            return createdEntryIDs.count == totalEntries
                && createdEventIDs.count == totalEntries
        }
    }

    /// Human-readable summary
    var summary: String {
        if waitedForSync {
            return
                "\(syncedCount)/\(totalEntries) synced (\(String(format: "%.0f%%", successRate * 100))), \(failedCount) failed, \(pendingCount) pending"
        } else {
            return "\(totalEntries) entries created with \(createdEventIDs.count) outbox events"
        }
    }

    /// Detailed report
    var detailedReport: String {
        var lines: [String] = []
        lines.append("=== Outbox Sync Test Report ===")
        lines.append("Metric: \(metricType.displayName)")
        lines.append("Total Entries: \(totalEntries)")
        lines.append("")
        lines.append("--- Creation ---")
        lines.append("Entries Created: \(createdEntryIDs.count)")
        lines.append("Events Created: \(createdEventIDs.count)")
        lines.append("")

        if waitedForSync {
            lines.append("--- Sync Results ---")
            lines.append("Synced: \(syncedCount)")
            lines.append("Failed: \(failedCount)")
            lines.append("Pending: \(pendingCount)")
            lines.append("Success Rate: \(String(format: "%.1f%%", successRate * 100))")
            lines.append("")
            lines.append("--- Entry Details ---")
            for (index, entry) in entries.enumerated() {
                let status =
                    entry.syncStatus == .synced ? "✅" : (entry.syncStatus == .failed ? "❌" : "⏳")
                lines.append(
                    "\(index + 1). \(status) \(entry.quantity) \(metricType.unit) - \(entry.syncStatus.rawValue)"
                )
                if let backendID = entry.backendID {
                    lines.append("   Backend ID: \(backendID)")
                }
            }
        }

        lines.append("")
        lines.append("--- Status ---")
        lines.append(isSuccessful ? "✅ Test Passed" : "❌ Test Failed")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Errors

enum TestOutboxSyncError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to run outbox sync test"
        }
    }
}
