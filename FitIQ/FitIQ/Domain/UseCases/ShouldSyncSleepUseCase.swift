//
//  ShouldSyncSleepUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Sleep Sync Optimization & Hexagonal Architecture Compliance
//

import Foundation

/// Protocol defining the use case for determining if sleep sync is needed
///
/// **Hexagonal Architecture:**
/// - **Layer:** Domain (Use Case)
/// - **Purpose:** Encapsulates business logic for sleep sync decision-making
/// - **Dependencies:** Domain use case only (GetLatestSleepSessionDateUseCase)
///
/// **Business Rules:**
/// - If no local sleep sessions exist, sync is needed (first sync)
/// - If latest session is within `syncThresholdHours`, skip sync (recently synced)
/// - If latest session is older than threshold, sync is needed (stale data)
///
/// **Sleep-Specific Considerations:**
/// - Sleep sessions span multiple hours (often overnight)
/// - Sessions are attributed to WAKE DATE (end date), not start date
/// - Query window must extend backward 24 hours to catch overnight sessions
/// - Example: Latest session ended at 6 AM today → Query from 6 AM yesterday
///
/// **Use Cases:**
/// - Optimize HealthKit sleep sync to avoid redundant queries
/// - Enable smart sync scheduling
/// - Reduce battery drain and improve performance
///
/// **Example:**
/// ```swift
/// let shouldSync = try await useCase.execute(
///     forUserID: userID,
///     syncThresholdHours: 6
/// )
/// if shouldSync {
///     // Perform sleep sync with extended backward query window
/// }
/// ```
protocol ShouldSyncSleepUseCase {
    /// Determines if sleep sync is needed based on latest session date
    ///
    /// - Parameters:
    ///   - userID: The user's unique identifier
    ///   - syncThresholdHours: Number of hours before considering data stale (default: 6)
    /// - Returns: True if sync is needed, false if recently synced
    /// - Throws: Repository errors if query fails
    func execute(
        forUserID userID: String,
        syncThresholdHours: Int
    ) async throws -> Bool
}

/// Default implementation of ShouldSyncSleepUseCase
///
/// **Architecture:**
/// - Depends only on domain use case (GetLatestSleepSessionDateUseCase)
/// - No infrastructure dependencies
/// - Pure business logic with validation
///
/// **Sync Logic:**
/// 1. Query latest session date via GetLatestSleepSessionDateUseCase
/// 2. If no session exists → sync needed (first sync)
/// 3. If session exists → compare with threshold
/// 4. If within threshold → skip sync (recently synced)
/// 5. If beyond threshold → sync needed (stale data)
///
/// **Why 6 Hour Default?**
/// - Sleep sessions typically occur once per 24 hours
/// - 6 hour threshold ensures we sync at most 2-3 times per day
/// - Balances freshness with performance
/// - User typically sleeps once at night, may nap during day
final class ShouldSyncSleepUseCaseImpl: ShouldSyncSleepUseCase {

    // MARK: - Properties

    private let getLatestSessionDateUseCase: GetLatestSleepSessionDateUseCase
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(getLatestSessionDateUseCase: GetLatestSleepSessionDateUseCase) {
        self.getLatestSessionDateUseCase = getLatestSessionDateUseCase
    }

    // MARK: - ShouldSyncSleepUseCase

    func execute(
        forUserID userID: String,
        syncThresholdHours: Int = 6
    ) async throws -> Bool {
        // Validation
        guard !userID.isEmpty else {
            throw ShouldSyncSleepError.emptyUserID
        }

        guard syncThresholdHours > 0 else {
            throw ShouldSyncSleepError.invalidThreshold
        }

        // Get latest session date (wake date)
        let latestSessionDate = try await getLatestSessionDateUseCase.execute(forUserID: userID)

        // If no session exists, sync is needed (first sync)
        guard let latestDate = latestSessionDate else {
            return true
        }

        // Calculate threshold date
        let thresholdDate =
            calendar.date(
                byAdding: .hour,
                value: -syncThresholdHours,
                to: Date()
            ) ?? Date()

        // If latest session is older than threshold, sync is needed
        return latestDate < thresholdDate
    }
}

// MARK: - Errors

enum ShouldSyncSleepError: Error, LocalizedError {
    case emptyUserID
    case invalidThreshold

    var errorDescription: String? {
        switch self {
        case .emptyUserID:
            return "User ID cannot be empty"
        case .invalidThreshold:
            return "Sync threshold must be greater than 0"
        }
    }
}
