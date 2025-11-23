//
//  MoodSyncService.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Infrastructure adapter for mood sync (implements MoodSyncPort)
//

import FitIQCore
import Foundation
import SwiftData

/// Service for syncing mood entries between local database and backend
/// This is an Infrastructure adapter that implements the Domain port
@MainActor
final class MoodSyncService: MoodSyncPort {

    // MARK: - Properties

    private let moodBackendService: MoodBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol

    // MARK: - Initialization

    init(
        moodBackendService: MoodBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        modelContext: ModelContext,
        outboxRepository: OutboxRepositoryProtocol
    ) {
        self.moodBackendService = moodBackendService
        self.tokenStorage = tokenStorage
        self.modelContext = modelContext
        self.outboxRepository = outboxRepository
    }

    // MARK: - MoodSyncPort Implementation

    func restoreFromBackend() async throws -> Int {
        print("🔄 [MoodSyncService] Starting restore from backend...")

        // Get access token
        guard let token = try await tokenStorage.getToken() else {
            throw MoodSyncError.notAuthenticated
        }

        // Fetch all mood entries from backend
        let backendEntries = try await moodBackendService.fetchAllMoods(
            accessToken: token.accessToken)
        print("📥 [MoodSyncService] Fetched \(backendEntries.count) entries from backend")

        // Get all existing local entries
        let localDescriptor = FetchDescriptor<SDMoodEntry>()
        let localEntries = try modelContext.fetch(localDescriptor)
        print("💾 [MoodSyncService] Found \(localEntries.count) entries in local database")

        // Create sets of existing IDs and backendIds to prevent resurrection of deleted entries
        let existingIds = Set(localEntries.map { $0.id })
        let existingBackendIds = Set(localEntries.compactMap { $0.backendId })

        // Check pending delete events to prevent restoring entries that are queued for deletion
        let pendingDeletes = try await outboxRepository.fetchPendingEvents(
            forUserID: nil,
            limit: nil
        )
        let pendingDeleteBackendIds = Set(
            pendingDeletes
                .filter { event in
                    // Check if this is a mood entry with delete operation
                    guard event.eventType == .moodEntry else { return false }
                    if case .generic(let dict) = event.metadata,
                        dict["operation"] == "delete"
                    {
                        return true
                    }
                    return false
                }
                .compactMap { event -> String? in
                    // Extract backendId from metadata
                    if case .generic(let dict) = event.metadata {
                        return dict["backendId"]
                    }
                    return nil
                }
        )
        print("🔍 [MoodSyncService] Found \(pendingDeleteBackendIds.count) pending delete events")

        // Filter out entries that already exist locally
        var restoredCount = 0
        var skippedCount = 0

        for backendEntry in backendEntries {
            // Skip if we already have this entry locally by ID
            if existingIds.contains(backendEntry.id) {
                skippedCount += 1
                print("⏭️ [MoodSyncService] Skipping entry (exists by ID): \(backendEntry.id)")
                continue
            }

            // Also check if an existing local entry already has this backendId
            // This handles cases where the same backend entry might have different local IDs
            let backendIdToCheck = backendEntry.id.uuidString
            if existingBackendIds.contains(backendIdToCheck) {
                skippedCount += 1
                print(
                    "⏭️ [MoodSyncService] Skipping entry (exists by backendId): \(backendIdToCheck)")
                continue
            }

            // Check if this entry has a pending delete event
            if pendingDeleteBackendIds.contains(backendIdToCheck) {
                skippedCount += 1
                print("⏭️ [MoodSyncService] Skipping entry (pending deletion): \(backendIdToCheck)")
                continue
            }

            // Create new local entry from backend data
            let sdEntry = SDMoodEntry(
                id: backendEntry.id,
                userId: backendEntry.userId,
                date: backendEntry.date,
                valence: backendEntry.valence,
                labels: backendEntry.labels,
                associations: backendEntry.associations,
                notes: backendEntry.notes,
                source: backendEntry.source.rawValue,
                sourceId: nil,  // Clear sourceId (it was used to transport backend ID)
                backendId: backendEntry.sourceId,  // Backend ID is in sourceId field
                createdAt: backendEntry.createdAt,
                updatedAt: backendEntry.updatedAt
            )

            modelContext.insert(sdEntry)
            restoredCount += 1
        }

        // Save all restored entries
        if restoredCount > 0 {
            try modelContext.save()
            print(
                "✅ [MoodSyncService] Restored \(restoredCount) entries, skipped \(skippedCount) duplicates"
            )
        } else {
            print("ℹ️ [MoodSyncService] No new entries to restore, skipped \(skippedCount) existing")
        }

        return restoredCount
    }

    func performFullSync() async throws -> MoodSyncResult {
        print("🔄 [MoodSyncService] Starting full sync...")

        // Step 1: Restore any missing entries from backend
        let restoredCount = try await restoreFromBackend()

        // Step 2: TODO - Push local-only entries to backend (future enhancement)
        let pushedCount = 0

        return MoodSyncResult(
            entriesRestored: restoredCount,
            entriesPushed: pushedCount
        )
    }
}

// MARK: - Errors

enum MoodSyncError: LocalizedError {
    case notAuthenticated
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Helper Models

private struct PendingDeletePayload: Decodable {
    let localId: UUID
    let backendId: String?

    enum CodingKeys: String, CodingKey {
        case localId = "local_id"
        case backendId = "backend_id"
    }
}
