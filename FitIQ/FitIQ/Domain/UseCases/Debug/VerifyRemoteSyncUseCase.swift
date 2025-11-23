//
//  VerifyRemoteSyncUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 31/01/2025.
//

import Foundation

/// Protocol for verifying remote sync status
protocol VerifyRemoteSyncUseCase {
    /// Gets a summary of sync status for all data types
    func getSyncStatus() async throws -> SyncStatusSummary

    /// Gets detailed info about pending entries
    func getPendingEntries(limit: Int?) async throws -> [PendingSyncEntry]

    /// Manually triggers sync for pending entries (for testing)
    func triggerManualSync() async throws -> ManualSyncResult

    /// Verifies local vs remote data consistency
    func verifyConsistency(for type: ProgressMetricType, limit: Int?) async throws
        -> ConsistencyReport
}

/// Implementation for sync verification
final class VerifyRemoteSyncUseCaseImpl: VerifyRemoteSyncUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    private let localDataChangePublisher: LocalDataChangePublisherProtocol

    // MARK: - Initialization

    init(
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager,
        localDataChangePublisher: LocalDataChangePublisherProtocol
    ) {
        self.progressRepository = progressRepository
        self.authManager = authManager
        self.localDataChangePublisher = localDataChangePublisher
    }

    // MARK: - Implementation

    func getSyncStatus() async throws -> SyncStatusSummary {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SyncVerificationError.userNotAuthenticated
        }

        print("VerifyRemoteSyncUseCase: 📊 Getting sync status for user \(userID)")

        // Fetch all local entries
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: nil,
            limit: 1000  // Limit to recent entries for performance
        )

        // Group by sync status
        let pending = allEntries.filter { $0.syncStatus == .pending }
        let syncing = allEntries.filter { $0.syncStatus == .syncing }
        let synced = allEntries.filter { $0.syncStatus == .synced }
        let failed = allEntries.filter { $0.syncStatus == .failed }

        // Group by type
        let byType = Dictionary(grouping: allEntries) { $0.type }
        let typeBreakdown = byType.mapValues { entries in
            TypeSyncStatus(
                total: entries.count,
                pending: entries.filter { $0.syncStatus == .pending }.count,
                syncing: entries.filter { $0.syncStatus == .syncing }.count,
                synced: entries.filter { $0.syncStatus == .synced }.count,
                failed: entries.filter { $0.syncStatus == .failed }.count
            )
        }

        let summary = SyncStatusSummary(
            totalEntries: allEntries.count,
            pendingCount: pending.count,
            syncingCount: syncing.count,
            syncedCount: synced.count,
            failedCount: failed.count,
            byType: typeBreakdown,
            oldestPending: pending.map { $0.createdAt }.min(),
            newestPending: pending.map { $0.createdAt }.max()
        )

        print("VerifyRemoteSyncUseCase: ✅ Sync status retrieved:")
        print("  - Total: \(summary.totalEntries)")
        print("  - Pending: \(summary.pendingCount)")
        print("  - Syncing: \(summary.syncingCount)")
        print("  - Synced: \(summary.syncedCount)")
        print("  - Failed: \(summary.failedCount)")

        return summary
    }

    func getPendingEntries(limit: Int? = nil) async throws -> [PendingSyncEntry] {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SyncVerificationError.userNotAuthenticated
        }

        print(
            "VerifyRemoteSyncUseCase: 📋 Getting pending entries (limit: \(limit?.description ?? "none"))"
        )

        // Fetch pending entries
        let pendingEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: .pending,
            limit: limit ?? 1000  // Use provided limit or default to 1000
        )

        // Sort by creation date (oldest first - these need sync most urgently)
        let sorted = pendingEntries.sorted { $0.createdAt < $1.createdAt }

        // Apply limit if specified
        let limited = limit.map { Array(sorted.prefix($0)) } ?? sorted

        // Convert to detailed sync entries
        let pendingSyncEntries = limited.map { entry in
            let ageInSeconds = Date().timeIntervalSince(entry.createdAt)
            let ageDescription: String
            if ageInSeconds < 60 {
                ageDescription = "\(Int(ageInSeconds))s ago"
            } else if ageInSeconds < 3600 {
                ageDescription = "\(Int(ageInSeconds / 60))m ago"
            } else if ageInSeconds < 86400 {
                ageDescription = "\(Int(ageInSeconds / 3600))h ago"
            } else {
                ageDescription = "\(Int(ageInSeconds / 86400))d ago"
            }

            return PendingSyncEntry(
                localID: entry.id,
                type: entry.type,
                quantity: entry.quantity,
                date: entry.date,
                createdAt: entry.createdAt,
                ageDescription: ageDescription,
                hasBackendID: entry.backendID != nil
            )
        }

        print("VerifyRemoteSyncUseCase: ✅ Found \(pendingSyncEntries.count) pending entries")
        if let oldest = pendingSyncEntries.first {
            print("  - Oldest: \(oldest.type.rawValue) from \(oldest.ageDescription)")
        }

        return pendingSyncEntries
    }

    func triggerManualSync() async throws -> ManualSyncResult {
        guard let userID = authManager.currentUserProfileID else {
            throw SyncVerificationError.userNotAuthenticated
        }

        print("VerifyRemoteSyncUseCase: 🔄 Manually triggering sync for pending entries")

        // Get pending entries
        let pending = try await getPendingEntries(limit: nil)

        guard !pending.isEmpty else {
            print("VerifyRemoteSyncUseCase: ℹ️ No pending entries to sync")
            return ManualSyncResult(
                triggeredCount: 0,
                entriesByType: [:],
                timestamp: Date()
            )
        }

        print("VerifyRemoteSyncUseCase: 📤 Triggering sync for \(pending.count) entries")

        // Group by type for reporting
        let byType = Dictionary(grouping: pending) { $0.type }
        let entriesByType = byType.mapValues { $0.count }

        // Trigger sync events for each pending entry
        var triggeredCount = 0
        for entry in pending {
            let event = LocalDataNeedsSyncEvent(
                localID: entry.localID,
                userID: userID,
                modelType: .progressEntry,
                isNewRecord: entry.hasBackendID == false
            )
            localDataChangePublisher.publish(event: event)
            triggeredCount += 1

            // Small delay to avoid overwhelming the sync service
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }

        let result = ManualSyncResult(
            triggeredCount: triggeredCount,
            entriesByType: entriesByType,
            timestamp: Date()
        )

        print("VerifyRemoteSyncUseCase: ✅ Triggered sync for \(triggeredCount) entries")
        for (type, count) in entriesByType {
            print("  - \(type.rawValue): \(count)")
        }
        print(
            "VerifyRemoteSyncUseCase: ⏱️ Sync events published. RemoteSyncService will process them."
        )

        return result
    }

    func verifyConsistency(for type: ProgressMetricType, limit: Int? = 10) async throws
        -> ConsistencyReport
    {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SyncVerificationError.userNotAuthenticated
        }

        print("VerifyRemoteSyncUseCase: 🔍 Verifying consistency for \(type.rawValue)")

        // Fetch local entries
        let localEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: type,
            syncStatus: nil,
            limit: limit ?? 100  // Use provided limit or default to 100
        )

        let localSynced = localEntries.filter { $0.syncStatus == .synced && $0.backendID != nil }

        print(
            "VerifyRemoteSyncUseCase: Local: \(localEntries.count) total, \(localSynced.count) synced"
        )

        // Fetch remote entries for the last 90 days (to match our sync window)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        let remoteEntries = try await progressRepository.getProgressHistory(
            type: type,
            from: startDate,
            to: endDate,
            page: nil,
            limit: limit
        )

        print("VerifyRemoteSyncUseCase: Remote: \(remoteEntries.count) entries in last 90 days")

        // Find discrepancies
        var onlyLocal: [ProgressEntry] = []
        var onlyRemote: [ProgressEntry] = []
        var matching: [(local: ProgressEntry, remote: ProgressEntry)] = []

        // Check local entries that should be synced
        for local in localSynced {
            if let backendID = local.backendID {
                if let remote = remoteEntries.first(where: { $0.backendID == backendID }) {
                    matching.append((local: local, remote: remote))
                } else {
                    onlyLocal.append(local)
                }
            }
        }

        // Check remote entries not found locally
        for remote in remoteEntries {
            if let backendID = remote.backendID {
                if !localSynced.contains(where: { $0.backendID == backendID }) {
                    onlyRemote.append(remote)
                }
            }
        }

        let report = ConsistencyReport(
            type: type,
            localTotal: localEntries.count,
            localSynced: localSynced.count,
            remoteTotal: remoteEntries.count,
            matchingCount: matching.count,
            onlyLocalCount: onlyLocal.count,
            onlyRemoteCount: onlyRemote.count,
            consistency: calculateConsistencyPercentage(
                matching: matching.count,
                localSynced: localSynced.count,
                remote: remoteEntries.count
            )
        )

        print("VerifyRemoteSyncUseCase: ✅ Consistency report:")
        print("  - Matching: \(report.matchingCount)")
        print("  - Only local: \(report.onlyLocalCount)")
        print("  - Only remote: \(report.onlyRemoteCount)")
        print("  - Consistency: \(String(format: "%.1f", report.consistency))%")

        return report
    }

    // MARK: - Helper Methods

    private func calculateConsistencyPercentage(matching: Int, localSynced: Int, remote: Int)
        -> Double
    {
        let total = max(localSynced, remote)
        guard total > 0 else { return 100.0 }
        return (Double(matching) / Double(total)) * 100.0
    }
}

// MARK: - Models

/// Summary of sync status across all entries
struct SyncStatusSummary {
    let totalEntries: Int
    let pendingCount: Int
    let syncingCount: Int
    let syncedCount: Int
    let failedCount: Int
    let byType: [ProgressMetricType: TypeSyncStatus]
    let oldestPending: Date?
    let newestPending: Date?

    var syncPercentage: Double {
        guard totalEntries > 0 else { return 100.0 }
        return (Double(syncedCount) / Double(totalEntries)) * 100.0
    }

    var needsAttention: Bool {
        return failedCount > 0 || pendingCount > 10
    }
}

/// Sync status breakdown for a specific type
struct TypeSyncStatus {
    let total: Int
    let pending: Int
    let syncing: Int
    let synced: Int
    let failed: Int

    var syncPercentage: Double {
        guard total > 0 else { return 100.0 }
        return (Double(synced) / Double(total)) * 100.0
    }
}

/// Detailed info about a pending entry
struct PendingSyncEntry {
    let localID: UUID
    let type: ProgressMetricType
    let quantity: Double
    let date: Date
    let createdAt: Date
    let ageDescription: String
    let hasBackendID: Bool
}

/// Result of manual sync trigger
struct ManualSyncResult {
    let triggeredCount: Int
    let entriesByType: [ProgressMetricType: Int]
    let timestamp: Date
}

/// Report comparing local vs remote consistency
struct ConsistencyReport {
    let type: ProgressMetricType
    let localTotal: Int
    let localSynced: Int
    let remoteTotal: Int
    let matchingCount: Int
    let onlyLocalCount: Int
    let onlyRemoteCount: Int
    let consistency: Double  // Percentage

    var isConsistent: Bool {
        return consistency > 95.0 && onlyLocalCount == 0
    }
}

// MARK: - Errors

enum SyncVerificationError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to verify sync status"
        }
    }
}
