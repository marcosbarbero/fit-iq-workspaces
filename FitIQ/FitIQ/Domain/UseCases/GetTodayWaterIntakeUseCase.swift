//
//  GetTodayWaterIntakeUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Protocol defining the contract for fetching today's water intake
protocol GetTodayWaterIntakeUseCase {
    /// Fetches total water intake for today from local storage
    /// - Returns: Total water intake in liters for today
    func execute() async throws -> Double
}

/// Implementation of GetTodayWaterIntakeUseCase following existing patterns
final class GetTodayWaterIntakeUseCaseImpl: GetTodayWaterIntakeUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute() async throws -> Double {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetTodayWaterIntakeError.userNotAuthenticated
        }

        // Get today's date range (start and end of day)
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now

        print("GetTodayWaterIntakeUseCase: Fetching water intake for user \(userID)")
        print("  Date range: \(startOfDay) to \(endOfDay)")

        // CRITICAL: Fetch from LOCAL storage first (source of truth)
        // This follows the local-first architecture pattern
        let localEntries = try await progressRepository.fetchRecent(
            forUserID: userID,
            type: .waterLiters,
            startDate: startOfDay,
            endDate: endOfDay,
            limit: 100  // Should only be 1 entry per day due to aggregation
        )

        print(
            "GetTodayWaterIntakeUseCase: Found \(localEntries.count) local water entries for today")

        // CRITICAL FIX: Return LATEST entry only (not sum)
        // SaveWaterProgressUseCase already aggregates by updating the same entry
        // So we should only have 1 entry per day, but if there are multiple,
        // use the most recently UPDATED one (which has the aggregated total)
        let latestEntry = localEntries.sorted { entry1, entry2 in
            // Sort by updatedAt first (most recently updated), then by date
            if let updated1 = entry1.updatedAt, let updated2 = entry2.updatedAt {
                return updated1 > updated2
            }
            return entry1.date > entry2.date
        }.first
        let totalLiters = latestEntry?.quantity ?? 0.0

        print(
            "GetTodayWaterIntakeUseCase: Latest water intake today: \(String(format: "%.2f", totalLiters))L (from \(localEntries.count) entries)"
        )

        return totalLiters
    }
}

// MARK: - Errors

enum GetTodayWaterIntakeError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch water intake"
        }
    }
}
