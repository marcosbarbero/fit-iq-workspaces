//
//  CompositeProgressRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Composite repository that combines local storage with remote API operations
/// Implements local-first architecture: write to local storage immediately,
/// then sync to backend asynchronously via event-driven system
final class CompositeProgressRepository: ProgressRepositoryProtocol {

    // MARK: - Properties

    private let localRepository: SwiftDataProgressRepository
    private let remoteAPIClient: ProgressAPIClient

    // MARK: - Initialization

    init(
        localRepository: SwiftDataProgressRepository,
        remoteAPIClient: ProgressAPIClient
    ) {
        self.localRepository = localRepository
        self.remoteAPIClient = remoteAPIClient
    }

    // MARK: - Local Storage Operations (Delegated to SwiftData)

    func save(progressEntry: ProgressEntry, forUserID userID: String) async throws -> UUID {
        print("CompositeProgressRepository: Saving progress entry locally")
        return try await localRepository.save(progressEntry: progressEntry, forUserID: userID)
    }

    func fetchLocal(
        forUserID userID: String,
        type: ProgressMetricType?,
        syncStatus: SyncStatus?,
        limit: Int? = nil
    ) async throws -> [ProgressEntry] {
        print("CompositeProgressRepository: Fetching local progress entries")
        return try await localRepository.fetchLocal(
            forUserID: userID,
            type: type,
            syncStatus: syncStatus,
            limit: limit
        )
    }

    func fetchRecent(
        forUserID userID: String,
        type: ProgressMetricType?,
        startDate: Date,
        endDate: Date,
        limit: Int
    ) async throws -> [ProgressEntry] {
        print("CompositeProgressRepository: Fetching recent progress entries")
        return try await localRepository.fetchRecent(
            forUserID: userID,
            type: type,
            startDate: startDate,
            endDate: endDate,
            limit: limit
        )
    }

    func updateBackendID(
        forLocalID localID: UUID,
        backendID: String,
        forUserID userID: String
    ) async throws {
        print("CompositeProgressRepository: Updating backend ID for local entry")
        try await localRepository.updateBackendID(
            forLocalID: localID,
            backendID: backendID,
            forUserID: userID
        )
    }

    func updateSyncStatus(
        forLocalID localID: UUID,
        status: SyncStatus,
        forUserID userID: String
    ) async throws {
        print("CompositeProgressRepository: Updating sync status for local entry")
        try await localRepository.updateSyncStatus(
            forLocalID: localID,
            status: status,
            forUserID: userID
        )
    }

    func deleteAll(forUserID userID: String, type: ProgressMetricType?) async throws {
        print("CompositeProgressRepository: Deleting all entries for user")
        try await localRepository.deleteAll(forUserID: userID, type: type)
    }

    func fetchLatestEntryDate(
        forUserID userID: String,
        type: ProgressMetricType
    ) async throws -> Date? {
        print("CompositeProgressRepository: Fetching latest entry date")
        return try await localRepository.fetchLatestEntryDate(forUserID: userID, type: type)
    }

    // MARK: - Remote Backend Operations (Delegated to API Client)

    func logProgress(
        type: ProgressMetricType,
        quantity: Double,
        loggedAt: Date?,
        notes: String?
    ) async throws -> ProgressEntry {
        print("CompositeProgressRepository: Logging progress to remote API")
        return try await remoteAPIClient.logProgress(
            type: type,
            quantity: quantity,
            loggedAt: loggedAt,
            notes: notes
        )
    }

    func getCurrentProgress(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry] {
        print("CompositeProgressRepository: Fetching current progress from remote API")
        return try await remoteAPIClient.getCurrentProgress(
            type: type,
            from: from,
            to: to,
            page: page,
            limit: limit
        )
    }

    func getProgressHistory(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry] {
        print("CompositeProgressRepository: Fetching progress history from remote API")
        return try await remoteAPIClient.getProgressHistory(
            type: type,
            from: from,
            to: to,
            page: page,
            limit: limit
        )
    }

    // MARK: - Sync Helper Method

    /// Syncs a local progress entry to the backend
    /// Called by RemoteSyncService or background sync manager
    func syncToBackend(localID: UUID, forUserID userID: String) async throws {
        print("CompositeProgressRepository: Syncing local entry \(localID) to backend")

        // 1. Fetch the local entry
        let localEntries = try await fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: .pending,
            limit: 100
        )

        guard let entry = localEntries.first(where: { $0.id == localID }) else {
            print("CompositeProgressRepository: Local entry not found for sync")
            throw CompositeProgressRepositoryError.entryNotFound
        }

        // 2. Check if already synced
        if entry.backendID != nil {
            print("CompositeProgressRepository: Entry already has backend ID, skipping sync")
            return
        }

        // 3. Update status to syncing
        try await updateSyncStatus(forLocalID: localID, status: .syncing, forUserID: userID)

        do {
            // 4. Send to backend
            // Combine date and time into a single timestamp
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.date)

            var loggedAtDate = entry.date
            if let time = entry.time {
                let timeComponents = time.split(separator: ":").compactMap { Int($0) }
                if timeComponents.count >= 2 {
                    var components = dateComponents
                    components.hour = timeComponents[0]
                    components.minute = timeComponents[1]
                    components.second = timeComponents.count > 2 ? timeComponents[2] : 0
                    if let combinedDate = calendar.date(from: components) {
                        loggedAtDate = combinedDate
                    }
                }
            }

            let backendEntry = try await logProgress(
                type: entry.type,
                quantity: entry.quantity,
                loggedAt: loggedAtDate,
                notes: entry.notes
            )

            // 5. Update local entry with backend ID
            try await updateBackendID(
                forLocalID: localID,
                backendID: backendEntry.id.uuidString,
                forUserID: userID
            )

            // 6. Mark as synced
            try await updateSyncStatus(forLocalID: localID, status: .synced, forUserID: userID)

            print("CompositeProgressRepository: ✅ Successfully synced entry to backend")
        } catch {
            // Mark as failed for retry
            try await updateSyncStatus(forLocalID: localID, status: .failed, forUserID: userID)
            print(
                "CompositeProgressRepository: ❌ Failed to sync entry: \(error.localizedDescription)"
            )
            throw error
        }
    }
}

// MARK: - Errors

enum CompositeProgressRepositoryError: Error, LocalizedError {
    case entryNotFound

    var errorDescription: String? {
        switch self {
        case .entryNotFound:
            return "Progress entry not found for sync"
        }
    }
}
