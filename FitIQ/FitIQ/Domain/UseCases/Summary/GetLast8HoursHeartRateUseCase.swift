//
//  GetLast8HoursHeartRateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Fetch last 8 hours of hourly-averaged heart rate data for summary cards
//

import Foundation

// MARK: - Protocol (Port)

/// Use case for fetching the last 8 hours of hourly heart rate data for summary display
protocol GetLast8HoursHeartRateUseCase {
    /// Execute the use case to fetch last 8 hours of heart rate data
    /// - Returns: Array of tuples containing (hour, average heart rate in BPM)
    /// - Note: Returns 8 entries, one per hour, with 0 for hours with no data
    func execute() async throws -> [(hour: Int, heartRate: Int)]
}

// MARK: - Implementation

final class GetLast8HoursHeartRateUseCaseImpl: GetLast8HoursHeartRateUseCase {

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    private let numberOfHours: Int = 8

    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    func execute() async throws -> [(hour: Int, heartRate: Int)] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLast8HoursHeartRateError.userNotAuthenticated
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
            type: .restingHeartRate,
            startDate: startTime,
            endDate: now,
            limit: 500  // Enough for 8 hours of granular data
        )

        // Filter to entries with time information (from HealthKit sync)
        let entriesWithTime = recentEntries.filter { entry in
            entry.time != nil
        }

        // Group by 1-hour window offset from startTime and collect values for averaging
        var windowData: [Int: [Double]] = [:]

        for entry in entriesWithTime {
            // Calculate which 1-hour window this entry falls into (0-7)
            let components = calendar.dateComponents([.hour], from: startTime, to: entry.date)
            let hoursFromStart = components.hour ?? 0

            // Only include data within our 8-hour window
            if hoursFromStart >= 0 && hoursFromStart < 8 {
                windowData[hoursFromStart, default: []].append(entry.quantity)
            }
        }

        // Build result with averages per rolling window
        var result: [(hour: Int, heartRate: Int)] = []

        for windowIndex in 0..<self.numberOfHours {
            // Calculate the start of this 1-hour window
            guard
                let windowStart = calendar.date(byAdding: .hour, value: windowIndex, to: startTime)
            else {
                continue
            }

            // Get the clock hour for labeling (e.g., 9 for 9:XX)
            let displayHour = calendar.component(.hour, from: windowStart)

            // Calculate average heart rate for this window
            if let values = windowData[windowIndex], !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                result.append((hour: displayHour, heartRate: Int(avg)))
            } else {
                // No data for this window
                result.append((hour: displayHour, heartRate: 0))
            }
        }

        return result
    }
}

// MARK: - Errors

enum GetLast8HoursHeartRateError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        }
    }
}
