//
//  GetLatestProgressEntryDateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Hexagonal Architecture Compliance
//

import Foundation

/// Protocol defining the use case for retrieving the latest progress entry date for a metric type
///
/// **Hexagonal Architecture:**
/// - **Layer:** Domain (Use Case)
/// - **Purpose:** Encapsulates business logic for querying latest sync timestamps
/// - **Dependencies:** Domain ports only (ProgressRepositoryProtocol)
///
/// **Use Cases:**
/// - Determine when last sync occurred for a metric
/// - Enable smart sync optimization (avoid re-fetching existing data)
/// - Support sync status monitoring and debugging
///
/// **Example:**
/// ```swift
/// let latestDate = try await useCase.execute(
///     forUserID: userID,
///     metricType: .steps
/// )
/// ```
protocol GetLatestProgressEntryDateUseCase {
    /// Retrieves the date of the most recent progress entry for a specific metric type
    ///
    /// - Parameters:
    ///   - userID: The user's unique identifier
    ///   - metricType: The type of progress metric to query
    /// - Returns: The date of the latest entry, or nil if no entries exist
    /// - Throws: Repository errors if query fails
    func execute(forUserID userID: String, metricType: ProgressMetricType) async throws -> Date?
}

/// Default implementation of GetLatestProgressEntryDateUseCase
///
/// **Architecture:**
/// - Depends only on domain port (ProgressRepositoryProtocol)
/// - No infrastructure dependencies
/// - Pure business logic with validation
///
/// **Validation:**
/// - Ensures userID is not empty
/// - Delegates actual query to repository
final class GetLatestProgressEntryDateUseCaseImpl: GetLatestProgressEntryDateUseCase {

    // MARK: - Properties

    private let progressRepository: ProgressRepositoryProtocol

    // MARK: - Initialization

    init(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    // MARK: - GetLatestProgressEntryDateUseCase

    func execute(forUserID userID: String, metricType: ProgressMetricType) async throws -> Date? {
        // Validation
        guard !userID.isEmpty else {
            throw ValidationError.emptyUserID
        }

        // Delegate to repository
        return try await progressRepository.fetchLatestEntryDate(
            forUserID: userID,
            type: metricType
        )
    }
    
    enum ValidationError: Error, LocalizedError {
        case emptyUserID

        var errorDescription: String? {
            switch self {
            case .emptyUserID:
                return "User ID cannot be empty"
            }
        }
    }

}
