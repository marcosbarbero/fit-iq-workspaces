//
//  JournalRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation

/// Port for journal entry persistence operations
/// Implementation must be provided by the infrastructure layer
protocol JournalRepositoryProtocol {
    /// Create a new journal entry
    /// - Parameters:
    ///   - text: The journal entry text content
    ///   - date: The date of the journal entry
    /// - Returns: The created JournalEntry
    /// - Throws: Repository error if creation fails
    func create(text: String, date: Date) async throws -> JournalEntry

    /// Save a journal entry (create or update)
    /// - Parameter entry: The journal entry to save
    /// - Returns: The saved JournalEntry
    /// - Throws: Repository error if save fails
    func save(_ entry: JournalEntry) async throws -> JournalEntry

    /// Update an existing journal entry
    /// - Parameter entry: The journal entry to update
    /// - Returns: The updated JournalEntry
    /// - Throws: Repository error if update fails
    func update(_ entry: JournalEntry) async throws -> JournalEntry

    /// Fetch journal entries within a date range
    /// - Parameters:
    ///   - from: Start date
    ///   - to: End date
    /// - Returns: Array of JournalEntry objects within the date range
    /// - Throws: Repository error if fetch fails
    func fetch(from: Date, to: Date) async throws -> [JournalEntry]

    /// Fetch all journal entries
    /// - Returns: Array of all JournalEntry objects
    /// - Throws: Repository error if fetch fails
    func fetchAll() async throws -> [JournalEntry]

    /// Fetch a specific journal entry by ID
    /// - Parameter id: The UUID of the journal entry
    /// - Returns: The JournalEntry if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchById(_ id: UUID) async throws -> JournalEntry?

    /// Fetch journal entry for a specific date
    /// - Parameter date: The date to search for
    /// - Returns: The JournalEntry for that date if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchByDate(_ date: Date) async throws -> JournalEntry?

    /// Fetch recent journal entries
    /// - Parameter limit: Maximum number of entries to return (default: 20)
    /// - Returns: Array of recent JournalEntry objects
    /// - Throws: Repository error if fetch fails
    func fetchRecent(limit: Int) async throws -> [JournalEntry]

    /// Fetch favorite journal entries
    /// - Returns: Array of favorite JournalEntry objects
    /// - Throws: Repository error if fetch fails
    func fetchFavorites() async throws -> [JournalEntry]

    /// Fetch journal entries by tag
    /// - Parameter tag: The tag to filter by
    /// - Returns: Array of JournalEntry objects with the specified tag
    /// - Throws: Repository error if fetch fails
    func fetchByTag(_ tag: String) async throws -> [JournalEntry]

    /// Fetch journal entries by entry type
    /// - Parameter entryType: The entry type to filter by
    /// - Returns: Array of JournalEntry objects of the specified type
    /// - Throws: Repository error if fetch fails
    func fetchByEntryType(_ entryType: EntryType) async throws -> [JournalEntry]

    /// Fetch journal entries linked to a mood entry
    /// - Parameter moodId: The UUID of the mood entry
    /// - Returns: Array of JournalEntry objects linked to the mood
    /// - Throws: Repository error if fetch fails
    func fetchLinkedToMood(_ moodId: UUID) async throws -> [JournalEntry]

    /// Search journal entries by text content
    /// - Parameter searchText: The text to search for
    /// - Returns: Array of JournalEntry objects containing the search text
    /// - Throws: Repository error if search fails
    func search(_ searchText: String) async throws -> [JournalEntry]

    /// Delete a journal entry
    /// - Parameter id: The UUID of the journal entry to delete
    /// - Throws: Repository error if delete fails
    func delete(_ id: UUID) async throws

    /// Delete all journal entries for the current user
    /// - Throws: Repository error if delete fails
    func deleteAll() async throws

    /// Get total count of journal entries
    /// - Returns: The total number of journal entries
    /// - Throws: Repository error if count fails
    func count() async throws -> Int

    /// Get total word count across all journal entries
    /// - Returns: The total word count
    /// - Throws: Repository error if count fails
    func totalWordCount() async throws -> Int

    /// Get current journaling streak (consecutive days)
    /// - Returns: The number of consecutive days with entries
    /// - Throws: Repository error if fetch fails
    func currentStreak() async throws -> Int

    /// Get all unique tags used in journal entries
    /// - Returns: Array of unique tag strings
    /// - Throws: Repository error if fetch fails
    func getAllTags() async throws -> [String]

    // MARK: - Backend Sync

    /// Fetch entries that need to be synced to backend
    /// - Returns: Array of JournalEntry objects needing sync
    /// - Throws: Repository error if fetch fails
    func fetchUnsyncedEntries() async throws -> [JournalEntry]

    /// Mark an entry as synced to backend
    /// - Parameters:
    ///   - id: The UUID of the journal entry
    ///   - backendId: The backend-assigned ID
    /// - Throws: Repository error if update fails
    func markAsSynced(_ id: UUID, backendId: String) async throws
}
