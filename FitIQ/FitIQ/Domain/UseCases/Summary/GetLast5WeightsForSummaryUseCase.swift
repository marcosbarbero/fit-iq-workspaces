//
//  GetLast5WeightsForSummaryUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Fetch last 5 weight entries for summary card mini-graph
//

import Foundation

// MARK: - Protocol (Port)

/// Use case for fetching the last 5 weight entries for summary card display
protocol GetLast5WeightsForSummaryUseCase {
    /// Execute the use case to fetch last 5 weight entries
    /// - Returns: Array of weight values (in kg), ordered chronologically (oldest to newest)
    /// - Note: Returns empty array if no data available
    func execute() async throws -> [Double]
}

// MARK: - Implementation

final class GetLast5WeightsForSummaryUseCaseImpl: GetLast5WeightsForSummaryUseCase {

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    func execute() async throws -> [Double] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLast5WeightsForSummaryError.userNotAuthenticated
        }

        // Fetch weight entries from local storage (last 30 days to ensure we get data)
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .weight,
            syncStatus: nil,
            limit: 30  // Limit to recent entries for performance
        )

        // Filter to date range and sort by date (oldest to newest for trend visualization)
        let recentEntries =
            allEntries
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }

        // Take last 5 entries for mini-graph
        let last5Entries = Array(recentEntries.suffix(5))

        // Extract weight values
        let weights = last5Entries.map { $0.quantity }

        print(
            "GetLast5WeightsForSummaryUseCase: ✅ Found \(weights.count) weight entries for summary: \(weights.map { String(format: "%.1f", $0) }.joined(separator: ", "))"
        )

        return weights
    }
}

// MARK: - Errors

enum GetLast5WeightsForSummaryError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        }
    }
}
