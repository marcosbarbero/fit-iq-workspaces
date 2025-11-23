//
//  JournalViewModel.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Combine
import Foundation
import Network
import SwiftUI

/// Statistics for journal entries
struct JournalViewStatistics {
    let totalEntries: Int
    let totalWords: Int
    let currentStreak: Int
    let allTags: [String]
    let pendingSyncCount: Int
}

/// ViewModel for managing journal entries
/// Handles CRUD operations, search, filtering, and mood linking
@MainActor
final class JournalViewModel: ObservableObject {
    // MARK: - Dependencies

    private let journalRepository: JournalRepositoryProtocol
    private let moodRepository: MoodRepositoryProtocol

    // MARK: - State

    @Published var entries: [JournalEntry] = []
    @Published var filteredEntries: [JournalEntry] = []
    @Published var favorites: [JournalEntry] = []
    @Published var recentMoodEntry: MoodEntry?

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSyncing = false
    @Published var isOffline = false

    // Auto-refresh timer for sync status updates
    private var refreshTimer: Timer?

    // Network monitoring
    private var networkMonitor: NWPathMonitor?

    // Date Filter
    @Published var selectedDate: Date = Date() {
        didSet {
            Task {
                await loadEntries()
            }
        }
    }

    // Search & Filter
    @Published var searchQuery = "" {
        didSet {
            applyFilters()
        }
    }

    @Published var filterType: EntryType? {
        didSet {
            applyFilters()
        }
    }

    @Published var filterTag: String? {
        didSet {
            applyFilters()
        }
    }

    @Published var filterFavoritesOnly = false {
        didSet {
            applyFilters()
        }
    }

    @Published var filterLinkedToMood = false {
        didSet {
            applyFilters()
        }
    }

    // Computed properties
    var hasActiveFilters: Bool {
        filterType != nil || filterTag != nil || filterFavoritesOnly || filterLinkedToMood
    }

    var shouldPromptMoodLink: Bool {
        recentMoodEntry != nil
    }

    // Statistics
    var statistics: JournalViewStatistics {
        JournalViewStatistics(
            totalEntries: totalEntries,
            totalWords: totalWords,
            currentStreak: currentStreak,
            allTags: allTags,
            pendingSyncCount: pendingSyncCount
        )
    }

    private var totalEntries = 0
    private var totalWords = 0
    private var currentStreak = 0
    private var allTags: [String] = []
    private var pendingSyncCount = 0

    // Mood Linking
    private var linkedMoodForNewEntry: UUID?

    // MARK: - Initialization

    init(
        journalRepository: JournalRepositoryProtocol,
        moodRepository: MoodRepositoryProtocol
    ) {
        self.journalRepository = journalRepository
        self.moodRepository = moodRepository

        // Start auto-refresh timer for sync status updates
        startAutoRefresh()

        // Start network monitoring
        startNetworkMonitoring()
    }

    deinit {
        // Clean up network monitor
        networkMonitor?.cancel()

        // Clean up refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Auto-Refresh

    private func startAutoRefresh() {
        // Refresh every 2 seconds while there are pending syncs
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.pendingSyncCount > 0 {
                    await self.refreshEntriesQuietly()
                }
            }
        }
    }

    private func refreshEntriesQuietly() async {
        // Refresh without showing loading indicator
        do {
            let allEntries = try await journalRepository.fetchAll()

            // Update entries while preserving scroll position
            self.entries = allEntries

            // Note: Sync state is now managed by Outbox pattern
            // pendingSyncCount tracking removed

            applyFilters()
        } catch {
            // Silent failure - don't interrupt user
        }
    }

    // MARK: - Data Loading

    func loadEntries() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch entries for the selected date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

            entries = try await journalRepository.fetch(from: startOfDay, to: endOfDay)
            filteredEntries = entries
            applyFilters()
            await loadStatistics()
            await checkForRecentMood()
        } catch {
            errorMessage = "Failed to load journal entries: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadRecent(limit: Int = 20) async {
        isLoading = true
        errorMessage = nil

        do {
            entries = try await journalRepository.fetchRecent(limit: limit)
            filteredEntries = entries
            applyFilters()
        } catch {
            errorMessage = "Failed to load recent entries: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadFavorites() async {
        do {
            favorites = try await journalRepository.fetchFavorites()
        } catch {
            errorMessage = "Failed to load favorites: \(error.localizedDescription)"
        }
    }

    func loadStatistics() async {
        do {
            totalEntries = try await journalRepository.count()

            // Note: Sync state is now managed by Outbox pattern
            // pendingSyncCount tracking removed
            pendingSyncCount = 0
            isSyncing = false

            totalWords = try await journalRepository.totalWordCount()
            currentStreak = try await journalRepository.currentStreak()
            allTags = try await journalRepository.getAllTags()
        } catch {
            // Statistics are non-critical, just log
            print("Failed to load statistics: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD Operations

    func createEntry(
        title: String?,
        content: String,
        tags: [String] = [],
        entryType: EntryType = .freeform,
        isFavorite: Bool = false,
        date: Date = Date()
    ) async throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JournalError.emptyContent
        }

        guard content.count <= JournalEntry.maxContentLength else {
            throw JournalError.contentTooLong
        }

        isLoading = true
        defer { isLoading = false }

        // Get current user ID from UserSession
        guard let userId = try? UserSession.shared.requireUserId() else {
            errorMessage = "Not authenticated. Please log in."
            return
        }

        let entry = JournalEntry(
            userId: userId,
            date: date,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.map { $0.lowercased() },
            entryType: entryType,
            isFavorite: isFavorite,
            linkedMoodId: linkedMoodForNewEntry
        )

        _ = try await journalRepository.save(entry)

        // Reload data
        await loadEntries()

        successMessage = "Entry saved successfully"
        linkedMoodForNewEntry = nil
    }

    func updateEntry(
        _ entry: JournalEntry,
        title: String?,
        content: String,
        tags: [String],
        entryType: EntryType,
        isFavorite: Bool
    ) async throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JournalError.emptyContent
        }

        guard content.count <= JournalEntry.maxContentLength else {
            throw JournalError.contentTooLong
        }

        isLoading = true
        defer { isLoading = false }

        var updated = entry
        updated.title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = tags.map { $0.lowercased() }
        updated.entryType = entryType
        updated.isFavorite = isFavorite

        _ = try await journalRepository.update(updated.withUpdatedTimestamp())

        await loadEntries()

        successMessage = "Entry updated successfully"
    }

    func deleteEntry(_ entry: JournalEntry) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await journalRepository.delete(entry.id)
            await loadEntries()
            successMessage = "Entry deleted"
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
        }
    }

    // MARK: - Search & Filter

    func applyFilters() {
        var filtered = entries

        // Note: Date filtering is now done at database level in loadEntries()
        // This only applies search and other filters on already date-filtered entries

        // Apply search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter { entry in
                entry.content.lowercased().contains(query)
                    || (entry.title?.lowercased().contains(query) ?? false)
                    || entry.tags.contains { $0.lowercased().contains(query) }
            }
        }

        // Apply entry type filter
        if let type = filterType {
            filtered = filtered.filter { $0.entryType == type }
        }

        // Apply tag filter
        if let tag = filterTag {
            filtered = filtered.filter { $0.tags.contains(tag.lowercased()) }
        }

        // Apply favorites filter
        if filterFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }

        // Apply mood link filter
        if filterLinkedToMood {
            filtered = filtered.filter { $0.isLinkedToMood }
        }

        filteredEntries = filtered
    }

    func clearFilters() {
        searchQuery = ""
        filterType = nil
        filterTag = nil
        filterFavoritesOnly = false
        filterLinkedToMood = false
        selectedDate = Date()  // Reset to today
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }
    func updateEntry(_ entry: JournalEntry) async -> Bool {
        guard entry.isValid else {
            errorMessage = entry.validationErrors.joined(separator: ", ")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            var updated = entry
            updated = updated.withUpdatedTimestamp()
            _ = try await journalRepository.update(updated)

            // Reload data
            await loadEntries()

            successMessage = "Entry updated successfully"
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to update entry: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func deleteEntry(_ id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await journalRepository.delete(id)

            // Remove from local state
            entries.removeAll { $0.id == id }
            applyFilters()
            await loadStatistics()

            successMessage = "Entry deleted successfully"
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Entry Actions

    func toggleFavorite(_ entry: JournalEntry) async {
        var updated = entry
        updated.toggleFavorite()
        _ = await updateEntry(updated)
        await loadFavorites()
    }

    func addTag(_ tag: String, to entry: JournalEntry) async {
        var updated = entry
        updated.addTag(tag)
        _ = await updateEntry(updated)
    }

    func removeTag(_ tag: String, from entry: JournalEntry) async {
        var updated = entry
        updated.removeTag(tag)
        _ = await updateEntry(updated)
    }

    func linkToMood(_ moodId: UUID, entry: JournalEntry) async {
        var updated = entry
        updated.linkToMood(moodId)
        _ = await updateEntry(updated)
    }

    func unlinkFromMood(_ entry: JournalEntry) async {
        var updated = entry
        updated.unlinkFromMood()
        _ = await updateEntry(updated)
    }

    // MARK: - Search & Filter

    func search(_ text: String) async {
        guard !text.isEmpty else {
            filteredEntries = entries
            return
        }

        do {
            filteredEntries = try await journalRepository.search(text)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    func filterByTag(_ tag: String) async {
        do {
            filteredEntries = try await journalRepository.fetchByTag(tag)
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
        }
    }

    func filterByEntryType(_ type: EntryType) async {
        do {
            filteredEntries = try await journalRepository.fetchByEntryType(type)
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Mood Integration

    func checkForRecentMood() async {
        do {
            // Check if user logged mood in the last hour
            let oneHourAgo = Date().addingTimeInterval(-3600)
            let today = Calendar.current.startOfDay(for: Date())

            let recentMoods = try await moodRepository.fetchByDateRange(
                startDate: oneHourAgo, endDate: Date())

            if let latestMood = recentMoods.first {
                recentMoodEntry = latestMood

                // Check if user has already journaled today
                let todayEntries = entries.filter { entry in
                    Calendar.current.isDate(entry.date, inSameDayAs: today)
                }

                // Show prompt if mood logged but no journal yet, or journal not linked
                _ = todayEntries.contains { $0.linkedMoodId == nil }
            } else {
                recentMoodEntry = nil
            }
        } catch {
            print("Failed to check for recent mood: \(error.localizedDescription)")
        }
    }

    func dismissMoodLinkPrompt() {
        // Mood link prompt dismissed
    }

    func acceptMoodLink() {
        if let moodId = recentMoodEntry?.id {
            linkedMoodForNewEntry = moodId
        }
    }

    func getMoodForEntry(_ entry: JournalEntry) async -> MoodEntry? {
        guard let moodId = entry.linkedMoodId else { return nil }

        do {
            return try await moodRepository.fetchById(id: moodId)
        } catch {
            print("Failed to fetch linked mood: \(error.localizedDescription)")
            return nil
        }
    }

    func getJournalEntriesForMood(_ moodId: UUID) async -> [JournalEntry] {
        do {
            return try await journalRepository.fetchLinkedToMood(moodId)
        } catch {
            print("Failed to fetch journal entries for mood: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Mood Linking

    /// Link journal entry to a mood
    func linkToMood(_ moodId: UUID, for entry: JournalEntry) async {
        var updatedEntry = entry
        updatedEntry.linkToMood(moodId)

        let success = await updateEntry(updatedEntry)
        if success {
            successMessage = "Entry linked to mood"

            // Clear message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.successMessage = nil
            }
        }
    }

    /// Unlink journal entry from mood
    func unlinkFromMood(for entry: JournalEntry) async {
        var updatedEntry = entry
        updatedEntry.unlinkFromMood()

        let success = await updateEntry(updatedEntry)
        if success {
            successMessage = "Entry unlinked from mood"

            // Clear message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.successMessage = nil
            }
        }
    }

    /// Get recent moods for linking (within last 7 days)
    func getRecentMoodsForLinking(days: Int = 7) async -> [MoodEntry] {
        do {
            let startDate =
                Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let endDate = Date()
            print(
                "🔗 [JournalViewModel] Fetching moods for linking from \(startDate.formatted(date: .abbreviated, time: .shortened)) to \(endDate.formatted(date: .abbreviated, time: .shortened))"
            )
            let moods = try await moodRepository.fetchByDateRange(
                startDate: startDate, endDate: endDate)
            print("🔗 [JournalViewModel] Found \(moods.count) moods available for linking")
            return moods
        } catch {
            print("❌ [JournalViewModel] Failed to fetch recent moods: \(error)")
            return []
        }
    }

    /// Get mood entry by ID
    func getMoodEntry(id: UUID) async -> MoodEntry? {
        do {
            return try await moodRepository.fetchById(id: id)
        } catch {
            print("❌ [JournalViewModel] Failed to fetch mood entry: \(error)")
            return nil
        }
    }

    // MARK: - Network Monitoring

    /// Start monitoring network connectivity
    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOffline = (path.status != .satisfied)
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global(qos: .background))
    }

    /// Get user-friendly sync status message
    var syncStatusMessage: String {
        if isOffline {
            let count = statistics.pendingSyncCount
            return count > 0
                ? "📡 Offline - \(count) \(count == 1 ? "entry" : "entries") waiting to sync"
                : "📡 Offline"
        } else if statistics.pendingSyncCount > 0 {
            return
                "⟳ Syncing \(statistics.pendingSyncCount) \(statistics.pendingSyncCount == 1 ? "entry" : "entries")..."
        } else {
            return ""
        }
    }

    // MARK: - Helpers

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func getEntry(by id: UUID) -> JournalEntry? {
        return entries.first { $0.id == id }
    }

    func refresh() async {
        await loadEntries()
    }

    // MARK: - Sync Management

    /// Manually trigger sync for all pending entries
    func retrySyncAll() async {
        isSyncing = true
        defer { isSyncing = false }

        // Force refresh to pick up any pending entries
        await loadEntries()
        await loadStatistics()

        successMessage = "Sync retry triggered"

        // Clear message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }

    /// Check if there are any failed sync attempts
    func hasFailedSyncs() async -> Bool {
        // This would need outbox repository access to check for failed events
        // For now, return true if there are pending syncs
        return pendingSyncCount > 0
    }
}

// MARK: - Preview Helper

extension JournalViewModel {
    static var preview: JournalViewModel {
        JournalViewModel(
            journalRepository: MockJournalRepository(),
            moodRepository: MockMoodRepository()
        )
    }
}

// MARK: - Errors

enum JournalError: LocalizedError {
    case emptyContent
    case contentTooLong

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Content cannot be empty"
        case .contentTooLong:
            return "Content exceeds maximum length"
        }
    }
}

// MARK: - Mock Repository

final class MockJournalRepository: JournalRepositoryProtocol {
    private var entries: [JournalEntry] = []

    func create(text: String, date: Date) async throws -> JournalEntry {
        let entry = JournalEntry(
            userId: UUID(),
            date: date,
            content: text
        )
        entries.append(entry)
        return entry
    }

    func save(_ entry: JournalEntry) async throws -> JournalEntry {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        return entry
    }

    func update(_ entry: JournalEntry) async throws -> JournalEntry {
        return try await save(entry)
    }

    func fetch(from: Date, to: Date) async throws -> [JournalEntry] {
        return entries.filter { $0.date >= from && $0.date <= to }
    }

    func fetchAll() async throws -> [JournalEntry] {
        return entries
    }

    func fetchById(_ id: UUID) async throws -> JournalEntry? {
        return entries.first { $0.id == id }
    }

    func fetchByDate(_ date: Date) async throws -> JournalEntry? {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchRecent(limit: Int) async throws -> [JournalEntry] {
        return Array(entries.sorted(by: { $0.date > $1.date }).prefix(limit))
    }

    func fetchFavorites() async throws -> [JournalEntry] {
        return entries.filter { $0.isFavorite }
    }

    func fetchByTag(_ tag: String) async throws -> [JournalEntry] {
        return entries.filter { $0.tags.contains(tag.lowercased()) }
    }

    func fetchByEntryType(_ entryType: EntryType) async throws -> [JournalEntry] {
        return entries.filter { $0.entryType == entryType }
    }

    func fetchLinkedToMood(_ moodId: UUID) async throws -> [JournalEntry] {
        return entries.filter { $0.linkedMoodId == moodId }
    }

    func search(_ searchText: String) async throws -> [JournalEntry] {
        let lowercaseSearch = searchText.lowercased()
        return entries.filter {
            ($0.title?.lowercased().contains(lowercaseSearch) ?? false)
                || $0.content.lowercased().contains(lowercaseSearch)
                || $0.tags.contains { $0.lowercased().contains(lowercaseSearch) }
        }
    }

    func delete(_ id: UUID) async throws {
        entries.removeAll { $0.id == id }
    }

    func deleteAll() async throws {
        entries.removeAll()
    }

    func count() async throws -> Int {
        return entries.count
    }

    func totalWordCount() async throws -> Int {
        return entries.reduce(0) { $0 + $1.wordCount }
    }

    func currentStreak() async throws -> Int {
        return 3  // Mock streak
    }

    func getAllTags() async throws -> [String] {
        let allTags = entries.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    func fetchUnsyncedEntries() async throws -> [JournalEntry] {
        return entries
    }

    func markAsSynced(_ id: UUID, backendId: String) async throws {
        // Mock implementation
    }
}
