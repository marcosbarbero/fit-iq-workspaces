//
//  StatisticsRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Foundation

/// Protocol for statistics repository operations
/// Defines methods for fetching aggregated wellness data
protocol StatisticsRepositoryProtocol {
    /// Fetch mood statistics for a date range
    /// - Parameters:
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Aggregated mood statistics
    /// - Throws: Repository errors
    func fetchMoodStatistics(from startDate: Date, to endDate: Date) async throws -> MoodStatistics

    /// Fetch journal statistics
    /// - Returns: Aggregated journal statistics
    /// - Throws: Repository errors
    func fetchJournalStatistics() async throws -> JournalStatistics

    /// Fetch combined wellness statistics
    /// - Parameters:
    ///   - startDate: Start of the date range for mood data
    ///   - endDate: End of the date range for mood data
    /// - Returns: Combined mood and journal statistics
    /// - Throws: Repository errors
    func fetchWellnessStatistics(from startDate: Date, to endDate: Date) async throws
        -> WellnessStatistics
}

// MARK: - Repository Errors

enum StatisticsRepositoryError: LocalizedError {
    case notAuthenticated
    case noDataAvailable
    case calculationFailed(Error)
    case fetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to view statistics"
        case .noDataAvailable:
            return
                "No data available yet. Start tracking your moods and journaling to see statistics!"
        case .calculationFailed(let error):
            return "Failed to calculate statistics: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch statistics: \(error.localizedDescription)"
        }
    }
}
