//
//  ShouldSyncMetricUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Hexagonal Architecture Compliance
//

import Foundation

/// Protocol defining the use case for determining if a metric needs syncing
///
/// **Hexagonal Architecture:**
/// - **Layer:** Domain (Use Case)
/// - **Purpose:** Encapsulates business logic for sync decision-making
/// - **Dependencies:** Domain use case only (GetLatestProgressEntryDateUseCase)
///
/// **Business Rules:**
/// - If no local data exists, sync is needed (first sync)
/// - If latest entry is within `syncThresholdHours`, skip sync (recently synced)
/// - If latest entry is older than threshold, sync is needed (stale data)
///
/// **Use Cases:**
/// - Optimize HealthKit sync to avoid redundant queries
/// - Enable smart sync scheduling
/// - Reduce battery drain and improve performance
///
/// **Example:**
/// ```swift
/// let shouldSync = try await useCase.execute(
///     forUserID: userID,
///     metricType: .steps,
///     syncThresholdHours: 1
/// )
/// if shouldSync {
///     // Perform sync
/// }
/// ```
protocol ShouldSyncMetricUseCase {
    /// Determines if a metric needs syncing based on latest entry date
    ///
    /// - Parameters:
    ///   - userID: The user's unique identifier
    ///   - metricType: The type of progress metric to check
    ///   - syncThresholdHours: Number of hours before considering data stale (default: 1)
    /// - Returns: True if sync is needed, false if recently synced
    /// - Throws: Repository errors if query fails
    func execute(
        forUserID userID: String,
        metricType: ProgressMetricType,
        syncThresholdMinutes: Int
    ) async throws -> Bool
}

/// Default implementation of ShouldSyncMetricUseCase
///
/// **Architecture:**
/// - Depends only on domain use case (GetLatestProgressEntryDateUseCase)
/// - No infrastructure dependencies
/// - Pure business logic with validation
///
/// **Sync Logic:**
/// 1. Query latest entry date via GetLatestProgressEntryDateUseCase
/// 2. If no entry exists → sync needed (first sync)
/// 3. If entry exists → compare with threshold
/// 4. If within threshold → skip sync (recently synced)
/// 5. If beyond threshold → sync needed (stale data)
final class ShouldSyncMetricUseCaseImpl: ShouldSyncMetricUseCase {

    // MARK: - Properties

    private let getLatestEntryDateUseCase: GetLatestProgressEntryDateUseCase
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(getLatestEntryDateUseCase: GetLatestProgressEntryDateUseCase) {
        self.getLatestEntryDateUseCase = getLatestEntryDateUseCase
    }

    // MARK: - ShouldSyncMetricUseCase

    func execute(
        forUserID userID: String,
        metricType: ProgressMetricType,
        syncThresholdMinutes: Int = 1
    ) async throws -> Bool {
        // Validation
        guard !userID.isEmpty else {
            throw ShouldSyncMetricError.emptyUserID
        }

        guard syncThresholdMinutes > 0 else {
            throw ShouldSyncMetricError.invalidThreshold
        }

        // Get latest entry date
        let latestEntryDate = try await getLatestEntryDateUseCase.execute(
            forUserID: userID,
            metricType: metricType
        )

        // If no entry exists, sync is needed (first sync)
        guard let latestDate = latestEntryDate else {
            return true
        }

        // Calculate threshold date
        let thresholdDate =
            calendar.date(
                byAdding: .minute,
                value: -syncThresholdMinutes,
                to: Date()
            ) ?? Date()

        // If latest entry is older than threshold, sync is needed
        return latestDate < thresholdDate
    }
}

// MARK: - Errors

enum ShouldSyncMetricError: Error, LocalizedError {
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
