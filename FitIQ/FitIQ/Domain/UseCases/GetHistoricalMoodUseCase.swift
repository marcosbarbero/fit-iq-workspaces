//
//  GetHistoricalMoodUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

// MARK: - Constants

/// Constants for mood tracking time ranges and limits
enum MoodTrackingConstants {
    /// Maximum number of mood entries to fetch in a single query
    static let maxFetchLimit: Int = 500

    /// Default time range options (in days)
    enum TimeRangeDays {
        static let week: Int = 7
        static let month: Int = 30
        static let quarter: Int = 90
        static let year: Int = 365
    }
}

// MARK: - Protocol

/// Protocol defining the contract for fetching historical mood data
protocol GetHistoricalMoodUseCase {
    /// Fetches historical mood entries for the current user within a date range
    /// - Parameters:
    ///   - startDate: The start date for the query
    ///   - endDate: The end date for the query (defaults to current date)
    /// - Returns: Array of mood progress entries sorted by date (ascending)
    func execute(startDate: Date, endDate: Date) async throws -> [ProgressEntry]
}

// MARK: - Implementation

/// Implementation of GetHistoricalMoodUseCase following existing patterns
final class GetHistoricalMoodUseCaseImpl: GetHistoricalMoodUseCase {

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

    func execute(startDate: Date, endDate: Date = Date()) async throws -> [ProgressEntry] {
        // Validate date range
        guard startDate <= endDate else {
            throw GetHistoricalMoodError.invalidDateRange
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetHistoricalMoodError.userNotAuthenticated
        }

        print(
            "GetHistoricalMoodUseCase: Fetching mood entries for user \(userID) from \(startDate) to \(endDate)"
        )

        // Fetch all local mood entries for the user
        // Note: Currently fetchLocal doesn't support date filtering at the protocol level,
        // so we fetch all and filter in-memory. This is acceptable for reasonable data volumes.
        // For production at scale, consider adding date range parameters to the repository protocol.
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .moodScore,
            syncStatus: nil,
            limit: 365  // Limit to 1 year of mood entries for performance
        )

        // Filter by date range efficiently
        let filteredEntries = allEntries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }

        // Sort by date (ascending) for consistent display
        let sortedEntries = filteredEntries.sorted { $0.date < $1.date }

        print(
            "GetHistoricalMoodUseCase: Found \(sortedEntries.count) mood entries in date range (out of \(allEntries.count) total)"
        )

        // Warn if we're hitting potential performance issues
        if allEntries.count > MoodTrackingConstants.maxFetchLimit {
            print(
                "⚠️ GetHistoricalMoodUseCase: Large dataset detected (\(allEntries.count) entries). Consider implementing date-range filtering at repository level."
            )
        }

        return sortedEntries
    }
}

// MARK: - Convenience Methods

extension GetHistoricalMoodUseCaseImpl {
    /// Fetches mood entries for the last N days
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of mood progress entries
    func executeForLastDays(_ days: Int) async throws -> [ProgressEntry] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        return try await execute(startDate: startDate, endDate: endDate)
    }

    /// Fetches mood entries for a specific time range
    /// - Parameter timeRange: The predefined time range to fetch
    /// - Returns: Array of mood progress entries
    func execute(timeRange: MoodTimeRange) async throws -> [ProgressEntry] {
        let endDate = Date()
        let startDate = timeRange.startDate(from: endDate)
        return try await execute(startDate: startDate, endDate: endDate)
    }
}

// MARK: - Time Range Helper

/// Time range options for mood tracking queries
enum MoodTimeRange {
    case last7Days
    case last30Days
    case last90Days
    case lastYear
    case custom(days: Int)

    /// Calculate the start date for this time range
    /// - Parameter endDate: The end date (typically current date)
    /// - Returns: The calculated start date
    func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        let days: Int

        switch self {
        case .last7Days:
            days = MoodTrackingConstants.TimeRangeDays.week
        case .last30Days:
            days = MoodTrackingConstants.TimeRangeDays.month
        case .last90Days:
            days = MoodTrackingConstants.TimeRangeDays.quarter
        case .lastYear:
            days = MoodTrackingConstants.TimeRangeDays.year
        case .custom(let customDays):
            days = customDays
        }

        return calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
    }

    /// Display name for the time range
    var displayName: String {
        switch self {
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .last90Days:
            return "Last 90 Days"
        case .lastYear:
            return "Last Year"
        case .custom(let days):
            return "Last \(days) Days"
        }
    }

    /// Short label for UI display
    var shortLabel: String {
        switch self {
        case .last7Days:
            return "7D"
        case .last30Days:
            return "30D"
        case .last90Days:
            return "90D"
        case .lastYear:
            return "1Y"
        case .custom(let days):
            return "\(days)D"
        }
    }
}

// MARK: - Errors

enum GetHistoricalMoodError: Error, LocalizedError {
    case invalidDateRange
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Start date must be before or equal to end date"
        case .userNotAuthenticated:
            return "User must be authenticated to fetch mood history"
        }
    }
}
