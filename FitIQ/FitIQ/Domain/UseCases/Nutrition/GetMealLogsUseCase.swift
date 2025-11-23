//
//  GetMealLogsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Use case for fetching meal logs with filtering
//

import Foundation

/// Protocol defining the contract for fetching meal logs
protocol GetMealLogsUseCase {
    /// Fetches meal logs with optional filtering
    /// - Parameters:
    ///   - status: Optional filter by processing status
    ///   - syncStatus: Optional filter by sync status
    ///   - mealType: Optional filter by meal type (enum)
    ///   - startDate: Optional start date for filtering
    ///   - endDate: Optional end date for filtering
    ///   - limit: Optional maximum number of entries to return
    ///   - useLocalOnly: If true, fetches only from local storage (offline mode)
    /// - Returns: Array of MealLog objects matching the filters
    func execute(
        status: MealLogStatus?,
        syncStatus: SyncStatus?,
        mealType: MealType?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?,
        useLocalOnly: Bool
    ) async throws -> [MealLog]
}

/// Implementation of GetMealLogsUseCase
///
/// This use case handles fetching meal logs with intelligent local/remote fallback:
/// - In offline mode or when useLocalOnly=true: fetches from SwiftData
/// - In online mode: fetches from backend API (fresher data)
/// - Automatically falls back to local if remote fails
///
/// **Architecture:**
/// - Follows Hexagonal Architecture (depends on ports, not implementations)
/// - Supports offline-first with local-remote fallback
/// - Returns domain models (MealLog) not persistence models (SDMealLog)
final class GetMealLogsUseCaseImpl: GetMealLogsUseCase {

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

    func execute(
        status: MealLogStatus? = nil,
        syncStatus: SyncStatus? = nil,
        mealType: MealType? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int? = nil,
        useLocalOnly: Bool = false
    ) async throws -> [MealLog] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetMealLogsError.userNotAuthenticated
        }

        print("GetMealLogsUseCase: Fetching meal logs for user \(userID)")
        print(
            "GetMealLogsUseCase: Filters - status: \(status?.rawValue ?? "all"), mealType: \(mealType?.rawValue ?? "all"), useLocalOnly: \(useLocalOnly)"
        )

        // If local-only mode, fetch from SwiftData
        if useLocalOnly {
            print("GetMealLogsUseCase: Using local-only mode (offline)")
            return try await fetchLocal(
                userID: userID,
                status: status,
                syncStatus: syncStatus,
                mealType: mealType,
                startDate: startDate,
                endDate: endDate,
                limit: limit
            )
        }

        // Try remote first for fresher data
        do {
            print("GetMealLogsUseCase: Attempting to fetch from backend API")
            let remoteMealLogs = try await mealLogRepository.getMealLogs(
                status: status,
                mealType: mealType?.rawValue,
                startDate: startDate,
                endDate: endDate,
                page: nil,
                limit: limit
            )
            print(
                "GetMealLogsUseCase: Successfully fetched \(remoteMealLogs.count) meal logs from backend"
            )
            return remoteMealLogs
        } catch {
            // Fallback to local if remote fails (offline mode or network error)
            print("GetMealLogsUseCase: Failed to fetch from backend: \(error.localizedDescription)")
            print("GetMealLogsUseCase: Falling back to local storage")

            return try await fetchLocal(
                userID: userID,
                status: status,
                syncStatus: syncStatus,
                mealType: mealType,
                startDate: startDate,
                endDate: endDate,
                limit: limit
            )
        }
    }

    // MARK: - Private Helpers

    private func fetchLocal(
        userID: String,
        status: MealLogStatus?,
        syncStatus: SyncStatus?,
        mealType: MealType?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [MealLog] {
        let localMealLogs = try await mealLogRepository.fetchLocal(
            forUserID: userID,
            status: status,
            syncStatus: syncStatus,
            startDate: startDate,
            endDate: endDate,
            limit: limit
        )

        print("GetMealLogsUseCase: Fetched \(localMealLogs.count) meal logs from local storage")

        // Filter by meal type if specified (local filtering)
        if let mealType = mealType {
            let filtered = localMealLogs.filter { $0.mealType == mealType }
            print(
                "GetMealLogsUseCase: Filtered to \(filtered.count) meal logs by mealType: \(mealType.rawValue)"
            )
            return filtered
        }

        return localMealLogs
    }
}

// MARK: - Errors

enum GetMealLogsError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch meal logs"
        }
    }
}
