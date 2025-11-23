//
//  SyncPendingMealLogsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Use case for manually syncing pending meal logs from backend
//

import Foundation

/// Protocol defining the contract for syncing pending meal logs
protocol SyncPendingMealLogsUseCase {
    /// Syncs pending meal logs by fetching their latest status from the backend
    ///
    /// This use case is called during pull-to-refresh or when the user manually
    /// requests a sync of pending meal logs. It fetches meal logs that are:
    /// - Status: `.pending` or `.processing`
    /// - Have a `backendID` (meaning they've been submitted to backend)
    ///
    /// **Flow:**
    /// 1. Find all local meal logs with status `.pending` or `.processing` and a `backendID`
    /// 2. For each meal log, fetch the latest data from the backend API
    /// 3. Update the local meal log with the backend data (status, items, nutritional info)
    /// 4. Return the count of updated meal logs
    ///
    /// **Architecture:**
    /// - Follows Hexagonal Architecture (depends on ports, not implementations)
    /// - Local-first: Updates local storage to maintain offline capability
    /// - Complements WebSocket: Handles cases where WebSocket notifications were missed
    ///
    /// - Returns: Number of meal logs that were updated
    /// - Throws: Error if sync operation fails
    func execute() async throws -> Int
}

/// Implementation of SyncPendingMealLogsUseCase
///
/// This use case handles manual synchronization of pending meal logs from the backend.
/// It's designed to work alongside WebSocket real-time updates as a fallback mechanism.
///
/// **When to Use:**
/// - Pull-to-refresh in UI
/// - App returns to foreground after being backgrounded
/// - User manually requests a sync
/// - WebSocket connection was interrupted
///
/// **What It Does:**
/// - Fetches pending/processing meal logs from local storage
/// - Only syncs meal logs that have a `backendID` (already submitted to backend)
/// - Fetches latest data from backend API for each meal log
/// - Updates local storage with backend data
/// - Handles errors gracefully (continues with other meal logs if one fails)
///
/// **What It Doesn't Do:**
/// - Doesn't submit new meal logs (use SaveMealLogUseCase for that)
/// - Doesn't sync meal logs without a `backendID` (not yet submitted)
/// - Doesn't delete meal logs
final class SyncPendingMealLogsUseCaseImpl: SyncPendingMealLogsUseCase {

    // MARK: - Dependencies

    private let mealLogRepository: MealLogRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        mealLogRepository: MealLogRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.mealLogRepository = mealLogRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute() async throws -> Int {
        print("SyncPendingMealLogsUseCase: Starting sync of pending meal logs")

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("SyncPendingMealLogsUseCase: ❌ User not authenticated")
            throw SyncPendingMealLogsError.userNotAuthenticated
        }

        // Fetch all pending/processing meal logs from local storage
        let pendingMealLogs = try await fetchPendingMealLogs(forUserID: userID)

        guard !pendingMealLogs.isEmpty else {
            print("SyncPendingMealLogsUseCase: No pending meal logs to sync")
            return 0
        }

        print("SyncPendingMealLogsUseCase: Found \(pendingMealLogs.count) pending meal log(s)")

        // Filter to only meal logs that have a backend ID (already submitted)
        let syncableMealLogs = pendingMealLogs.filter { $0.backendID != nil }

        guard !syncableMealLogs.isEmpty else {
            print("SyncPendingMealLogsUseCase: No meal logs with backend IDs to sync")
            return 0
        }

        print(
            "SyncPendingMealLogsUseCase: Syncing \(syncableMealLogs.count) meal log(s) with backend IDs"
        )

        var updatedCount = 0

        // Sync each meal log individually (continue on error)
        for mealLog in syncableMealLogs {
            do {
                try await syncSingleMealLog(mealLog, userID: userID)
                updatedCount += 1
            } catch {
                print(
                    "SyncPendingMealLogsUseCase: ⚠️ Failed to sync meal log \(mealLog.id): \(error.localizedDescription)"
                )
                // Continue with other meal logs
            }
        }

        print("SyncPendingMealLogsUseCase: ✅ Sync complete. Updated \(updatedCount) meal log(s)")
        return updatedCount
    }

    // MARK: - Private Helpers

    /// Fetches pending/processing meal logs from local storage
    private func fetchPendingMealLogs(forUserID userID: String) async throws -> [MealLog] {
        // Fetch meal logs with pending or processing status
        let pendingLogs = try await mealLogRepository.fetchLocal(
            forUserID: userID,
            status: .pending,
            syncStatus: nil,
            startDate: nil,
            endDate: nil,
            limit: nil
        )

        let processingLogs = try await mealLogRepository.fetchLocal(
            forUserID: userID,
            status: .processing,
            syncStatus: nil,
            startDate: nil,
            endDate: nil,
            limit: nil
        )

        return pendingLogs + processingLogs
    }

    /// Syncs a single meal log from the backend
    private func syncSingleMealLog(_ mealLog: MealLog, userID: String) async throws {
        guard let backendID = mealLog.backendID else {
            print(
                "SyncPendingMealLogsUseCase: ⚠️ Meal log \(mealLog.id) has no backend ID, skipping")
            return
        }

        print("SyncPendingMealLogsUseCase: Fetching meal log from backend: \(backendID)")

        // Fetch the latest data from backend
        let backendMealLog = try await mealLogRepository.getMealLogByID(backendID)

        print("SyncPendingMealLogsUseCase: Backend status: \(backendMealLog.status)")
        print("SyncPendingMealLogsUseCase: Backend items: \(backendMealLog.items.count)")

        // Only update if the status has changed (optimization)
        if backendMealLog.status != mealLog.status {
            print("SyncPendingMealLogsUseCase: Updating local meal log \(mealLog.id)")

            // Update the local meal log with backend data
            try await mealLogRepository.updateStatus(
                forLocalID: mealLog.id,
                status: backendMealLog.status,
                items: backendMealLog.items.isEmpty ? nil : backendMealLog.items,
                totalCalories: backendMealLog.totalCalories,
                totalProteinG: backendMealLog.totalProteinG,
                totalCarbsG: backendMealLog.totalCarbsG,
                totalFatG: backendMealLog.totalFatG,
                totalFiberG: backendMealLog.totalFiberG,
                totalSugarG: backendMealLog.totalSugarG,
                errorMessage: backendMealLog.errorMessage,
                forUserID: userID
            )

            // Update sync status to .synced (since we just fetched latest data)
            try await mealLogRepository.updateSyncStatus(
                forLocalID: mealLog.id,
                syncStatus: .synced,
                forUserID: userID
            )

            print("SyncPendingMealLogsUseCase: ✅ Updated meal log \(mealLog.id)")
        } else {
            print(
                "SyncPendingMealLogsUseCase: No changes for meal log \(mealLog.id), skipping update"
            )
        }
    }
}

// MARK: - Errors

enum SyncPendingMealLogsError: Error, LocalizedError {
    case userNotAuthenticated
    case noBackendID
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated. Please log in."
        case .noBackendID:
            return "Meal log has no backend ID. Cannot sync."
        case .fetchFailed(let reason):
            return "Failed to fetch meal log from backend: \(reason)"
        }
    }
}
