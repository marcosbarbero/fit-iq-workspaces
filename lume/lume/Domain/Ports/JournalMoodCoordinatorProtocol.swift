//
//  JournalMoodCoordinatorProtocol.swift
//  lume
//
//  Created by Lume Team on 2025-01-15.
//

import Foundation

/// Protocol for coordinating between Journal and Mood features
/// Enables bidirectional linking and navigation between journal entries and mood entries
protocol JournalMoodCoordinatorProtocol {
    /// Get a specific mood entry by ID
    /// - Parameters:
    ///   - id: The mood entry ID
    /// - Returns: The mood entry if found, nil otherwise
    func getMoodEntry(id: UUID) async -> MoodEntry?

    /// Get recent mood entries for linking
    /// - Parameters:
    ///   - days: Number of days to look back (default: 7)
    /// - Returns: Array of mood entries from the specified period
    func getRecentMoods(days: Int) async -> [MoodEntry]

    /// Get journal entries linked to a specific mood
    /// - Parameters:
    ///   - moodId: The mood entry ID
    /// - Returns: Array of journal entries linked to this mood
    func getJournalEntries(linkedToMood moodId: UUID) async -> [JournalEntry]

    /// Get mood entries linked to a specific journal entry
    /// - Parameters:
    ///   - journalId: The journal entry ID
    /// - Returns: The linked mood entry if exists, nil otherwise
    func getMoodForJournal(journalId: UUID) async -> MoodEntry?
}
