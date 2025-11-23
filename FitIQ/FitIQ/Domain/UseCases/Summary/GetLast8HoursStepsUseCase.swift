//
//  GetLast8HoursStepsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Fetch last 8 hours of hourly steps data for summary cards
//

import Foundation

// MARK: - Protocol (Port)

/// Use case for fetching the last 8 hours of hourly steps data for summary display
protocol GetLast8HoursStepsUseCase {
    /// Execute the use case to fetch last 8 hours of steps data
    /// - Returns: Array of tuples containing (hour, total steps)
    /// - Note: Returns 8 entries, one per hour, with 0 for hours with no data
    func execute() async throws -> [(hour: Int, steps: Int)]
}

// MARK: - Implementation

final class GetLast8HoursStepsUseCaseImpl: GetLast8HoursStepsUseCase {

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    func execute() async throws -> [(hour: Int, steps: Int)] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLast8HoursStepsError.userNotAuthenticated
        }

        let calendar = Calendar.current
        let now = Date()

        // Calculate start time (8 hours ago) - this creates rolling windows
        guard let startTime = calendar.date(byAdding: .hour, value: -8, to: now) else {
            return []
        }

        // OPTIMIZED: Use fetchRecent with date range to avoid full table scan
        let recentEntries = try await progressRepository.fetchRecent(
            forUserID: userID,
            type: .steps,
            startDate: startTime,
            endDate: now,
            limit: 500  // Enough for 8 hours of granular data
        )

        // Filter to entries with time information (from HealthKit sync)
        let entriesWithTime = recentEntries.filter { entry in
            entry.time != nil
        }

        // Group by 1-hour window offset from startTime (not by clock hour)
        var windowData: [Int: Double] = [:]

        for entry in entriesWithTime {
            // Calculate which 1-hour window this entry falls into (0-7)
            let components = calendar.dateComponents([.hour], from: startTime, to: entry.date)
            let hoursFromStart = components.hour ?? 0

            // Only include data within our 8-hour window
            if hoursFromStart >= 0 && hoursFromStart < 8 {
                windowData[hoursFromStart, default: 0] += entry.quantity
            }
        }

        // Build result with actual hour labels for each rolling window
        var result: [(hour: Int, steps: Int)] = []

        for windowIndex in 0..<8 {
            // Calculate the start of this 1-hour window
            guard
                let windowStart = calendar.date(byAdding: .hour, value: windowIndex, to: startTime)
            else {
                continue
            }

            // Get the clock hour for labeling (e.g., 9 for 9:XX)
            let displayHour = calendar.component(.hour, from: windowStart)

            // Get steps for this window (0 if no data)
            let steps = Int(windowData[windowIndex] ?? 0)

            result.append((hour: displayHour, steps: steps))
        }

        return result
    }
}

// MARK: - Errors

enum GetLast8HoursStepsError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        }
    }
}
