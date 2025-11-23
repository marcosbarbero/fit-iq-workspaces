//
//  MoodRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Redesigned with Lume's warm sunlight metaphor
//

import Foundation

/// Repository protocol for mood tracking operations
protocol MoodRepositoryProtocol {
    /// Save a new mood entry
    /// - Parameter entry: The mood entry to save
    /// - Throws: Repository error if save fails
    func save(_ entry: MoodEntry) async throws

    /// Fetch recent mood entries
    /// - Parameter days: Number of days to fetch (default: 30)
    /// - Returns: Array of mood entries, sorted by date descending
    /// - Throws: Repository error if fetch fails
    func fetchRecent(days: Int) async throws -> [MoodEntry]

    /// Delete a mood entry
    /// - Parameter id: The ID of the mood entry to delete
    /// - Throws: Repository error if delete fails
    func delete(id: UUID) async throws

    /// Fetch mood entry by ID
    /// - Parameter id: The ID of the mood entry
    /// - Returns: The mood entry if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchById(id: UUID) async throws -> MoodEntry?

    /// Fetch mood entries for a specific date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of mood entries within the date range
    /// - Throws: Repository error if fetch fails
    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [MoodEntry]

    /// Fetch mood analytics for a time period
    /// - Parameters:
    ///   - from: Start date of the period
    ///   - to: End date of the period
    ///   - includeDailyBreakdown: Whether to include daily aggregates (default: false)
    /// - Returns: MoodAnalytics with summary, trends, top labels, and optional daily breakdown
    /// - Throws: Repository error if fetch fails
    func fetchAnalytics(
        from: Date,
        to: Date,
        includeDailyBreakdown: Bool
    ) async throws -> MoodAnalytics
}
