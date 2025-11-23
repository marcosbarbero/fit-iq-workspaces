//
//  GetLatestSleepSessionDateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Sleep Sync Optimization & Hexagonal Architecture Compliance
//

import Foundation

/// Protocol defining the use case for retrieving the latest sleep session date
///
/// **Hexagonal Architecture:**
/// - **Layer:** Domain (Use Case)
/// - **Purpose:** Encapsulates business logic for querying latest sleep sync timestamp
/// - **Dependencies:** Domain ports only (SleepRepositoryProtocol)
///
/// **Use Cases:**
/// - Determine when last sleep session was synced
/// - Enable smart sync optimization (avoid re-fetching existing sessions)
/// - Support sync status monitoring and debugging
///
/// **Example:**
/// ```swift
/// let latestTime = try await useCase.execute(forUserID: userID)
/// if let time = latestTime {
///     print("Last sleep session ended at: \(time)")
/// }
/// ```
protocol GetLatestSleepSessionDateUseCase {
    /// Retrieves the date when the most recent sleep session ended (wake time)
    ///
    /// Sleep sessions are attributed to their END time (wake time), not start time.
    /// This follows industry standard:
    /// - Sleep from 10 PM Friday → 6 AM Saturday = Saturday's sleep
    /// - Sleep from 2 AM → 10 AM Saturday = Saturday's sleep
    ///
    /// - Parameter userID: The user's unique identifier
    /// - Returns: The wake time of the latest session, or nil if no sessions exist
    /// - Throws: Repository errors if query fails
    func execute(forUserID userID: String) async throws -> Date?
}

/// Default implementation of GetLatestSleepSessionDateUseCase
///
/// **Architecture:**
/// - Depends only on domain port (SleepRepositoryProtocol)
/// - No infrastructure dependencies
/// - Pure business logic with validation
///
/// **Validation:**
/// - Ensures userID is not empty
/// - Delegates actual query to repository
final class GetLatestSleepSessionDateUseCaseImpl: GetLatestSleepSessionDateUseCase {

    // MARK: - Properties

    private let sleepRepository: SleepRepositoryProtocol

    // MARK: - Initialization

    init(sleepRepository: SleepRepositoryProtocol) {
        self.sleepRepository = sleepRepository
    }

    // MARK: - GetLatestSleepSessionDateUseCase

    func execute(forUserID userID: String) async throws -> Date? {
        // Validation
        guard !userID.isEmpty else {
            throw GetLatestSleepSessionDateError.emptyUserID
        }

        // Fetch latest session
        let latestSession = try await sleepRepository.fetchLatestSession(forUserID: userID)

        // Return wake time (end time) - sleep sessions are attributed to wake time
        return latestSession?.endTime
    }
}

// MARK: - Errors

enum GetLatestSleepSessionDateError: Error, LocalizedError {
    case emptyUserID

    var errorDescription: String? {
        switch self {
        case .emptyUserID:
            return "User ID cannot be empty"
        }
    }
}
