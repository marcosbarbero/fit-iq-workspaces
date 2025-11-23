//
//  MoodViewModel.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Refactored: 2025-01-15 - Updated for valence/labels model
//

import Foundation

@Observable
final class MoodViewModel {
    // State
    var selectedMoodLabel: MoodLabel?
    var moodHistory: [MoodEntry] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showingMoodEntry: Bool = false
    var isSyncing: Bool = false
    var syncMessage: String?

    // Date filtering
    var selectedDate: Date = Date()

    // Dashboard data
    var dashboardStats: MoodDashboardStats?

    // Analytics data
    var analytics: MoodAnalytics?
    var isLoadingAnalytics: Bool = false
    var analyticsError: String?

    // Dependencies
    private let moodRepository: MoodRepositoryProtocol
    private let syncMoodEntriesUseCase: SyncMoodEntriesUseCase

    // Get current user ID from UserSession
    private var currentUserId: UUID {
        get throws {
            try UserSession.shared.requireUserId()
        }
    }

    init(
        moodRepository: MoodRepositoryProtocol,
        authRepository: AuthRepositoryProtocol,
        syncMoodEntriesUseCase: SyncMoodEntriesUseCase
    ) {
        self.moodRepository = moodRepository
        self.syncMoodEntriesUseCase = syncMoodEntriesUseCase
        // authRepository stored for future use when auth is implemented
    }

    /// Computed property for today's mood entry
    var todayEntry: MoodEntry? {
        let calendar = Calendar.current
        return moodHistory.first { entry in
            calendar.isDateInToday(entry.date)
        }
    }

    /// Sync mood entries with backend
    @MainActor
    func syncWithBackend() async {
        isSyncing = true
        syncMessage = nil
        defer { isSyncing = false }

        do {
            let result = try await syncMoodEntriesUseCase.execute()

            if result.totalSynced > 0 {
                syncMessage = "✅ \(result.description)"
                // Reload current view after sync
                await loadMoodsForSelectedDate()
            } else {
                syncMessage = "✅ Already in sync"
            }

            // Clear message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    syncMessage = nil
                }
            }
        } catch {
            syncMessage = "⚠️ Sync failed: \(error.localizedDescription)"
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func saveMood(moodLabel: MoodLabel, notes: String?, date: Date = Date()) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Get current user ID
            guard let userId = try? UserSession.shared.requireUserId() else {
                errorMessage = "Not authenticated. Please log in."
                return
            }

            let entry = MoodEntry(
                userId: userId,
                date: date,
                moodLabel: moodLabel,
                notes: notes
            )

            try await moodRepository.save(entry)

            // Reload to reflect new entry
            await loadMoodsForSelectedDate()

            // Clear selection
            selectedMoodLabel = nil
            showingMoodEntry = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateMood(_ entry: MoodEntry, moodLabel: MoodLabel, notes: String?, date: Date? = nil)
        async
    {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let updatedEntry = MoodEntry(
                id: entry.id,
                userId: entry.userId,
                date: date ?? entry.date,
                moodLabel: moodLabel,
                notes: notes,
                createdAt: entry.createdAt,
                updatedAt: Date()
            )

            try await moodRepository.save(updatedEntry)

            // Reload to reflect updated entry
            await loadMoodsForSelectedDate()

            // Clear selection
            selectedMoodLabel = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadRecentMoods(days: Int = 30) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            moodHistory = try await moodRepository.fetchRecent(days: days)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadMoodsForSelectedDate() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

            moodHistory = try await moodRepository.fetchByDateRange(
                startDate: startOfDay,
                endDate: endOfDay
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadMoodsForDateRange(startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            moodHistory = try await moodRepository.fetchByDateRange(
                startDate: startDate,
                endDate: endDate
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteMood(_ id: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await moodRepository.delete(id: id)

            // Remove from local state
            moodHistory.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadDashboardStats() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let calendar = Calendar.current

            // Today's entries
            let todayStart = calendar.startOfDay(for: Date())
            let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            let todayEntries = try await moodRepository.fetchByDateRange(
                startDate: todayStart,
                endDate: todayEnd
            )

            // Last 7 days
            let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            let weekEntries = try await moodRepository.fetchByDateRange(
                startDate: weekStart,
                endDate: todayEnd
            )

            // Last 30 days
            let monthStart = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
            let monthEntries = try await moodRepository.fetchByDateRange(
                startDate: monthStart,
                endDate: todayEnd
            )

            dashboardStats = MoodDashboardStats(
                todayEntries: todayEntries,
                weekEntries: weekEntries,
                monthEntries: monthEntries
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load analytics for a specific time period
    @MainActor
    func loadAnalytics(for period: MoodTimePeriod) async {
        isLoadingAnalytics = true
        analyticsError = nil
        defer { isLoadingAnalytics = false }

        let endDate = Date()
        guard
            let startDate = Calendar.current.date(
                byAdding: .day,
                value: -period.days,
                to: endDate
            )
        else {
            analyticsError = "Failed to calculate date range"
            return
        }

        do {
            analytics = try await moodRepository.fetchAnalytics(
                from: startDate,
                to: endDate,
                includeDailyBreakdown: period == .today
            )

            print(
                "✅ [MoodViewModel] Loaded analytics: \(analytics?.summary.totalEntries ?? 0) entries, \(analytics?.summary.consistencyPercentage ?? 0)% consistency"
            )

            // Also load dashboard stats for the chart
            await loadDashboardStats()
        } catch {
            analyticsError = error.localizedDescription
            print("❌ [MoodViewModel] Failed to load analytics: \(error)")

            // Fallback to local computation
            await loadDashboardStats()
        }
    }
}

// MARK: - Dashboard Stats Model

/// Dashboard statistics for mood tracking insights
/// Legacy model - being replaced by MoodAnalytics from backend
struct MoodDashboardStats {
    let todayEntries: [MoodEntry]
    let weekEntries: [MoodEntry]
    let monthEntries: [MoodEntry]

    var averageTodayValence: Double {
        guard !todayEntries.isEmpty else { return 0 }
        let total = todayEntries.reduce(0.0) { $0 + $1.valence }
        return total / Double(todayEntries.count)
    }

    var averageWeekValence: Double {
        guard !weekEntries.isEmpty else { return 0 }
        let total = weekEntries.reduce(0.0) { $0 + $1.valence }
        return total / Double(weekEntries.count)
    }

    var averageMonthValence: Double {
        guard !monthEntries.isEmpty else { return 0 }
        let total = monthEntries.reduce(0.0) { $0 + $1.valence }
        return total / Double(monthEntries.count)
    }

    var todayLabelDistribution: [String: Int] {
        let allLabels = todayEntries.flatMap { $0.labels }
        return Dictionary(grouping: allLabels, by: { $0 })
            .mapValues { $0.count }
    }

    var weekLabelDistribution: [String: Int] {
        let allLabels = weekEntries.flatMap { $0.labels }
        return Dictionary(grouping: allLabels, by: { $0 })
            .mapValues { $0.count }
    }

    var monthLabelDistribution: [String: Int] {
        let allLabels = monthEntries.flatMap { $0.labels }
        return Dictionary(grouping: allLabels, by: { $0 })
            .mapValues { $0.count }
    }

    /// Daily averages for the week (for line chart)
    /// Calculation: Groups all mood entries by day, then calculates the average valence for each day
    /// - Returns: Array of tuples (Date, Average Valence) sorted chronologically
    /// - Note: If multiple entries exist on the same day, they are averaged together
    var weekDailyAverages: [(Date, Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: weekEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped.map { date, entries in
            let average =
                entries.isEmpty
                ? 0 : entries.reduce(0.0) { $0 + $1.valence } / Double(entries.count)
            return (date, average)
        }.sorted { $0.0 < $1.0 }
    }

    // Hourly distribution for today
    var todayHourlyEntries: [(Int, [MoodEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: todayEntries) { entry in
            calendar.component(.hour, from: entry.date)
        }

        return grouped.map { hour, entries in
            (hour, entries)
        }.sorted { $0.0 < $1.0 }
    }

    /// Daily averages for the month (for line chart)
    /// Calculation: Groups all mood entries by day, then calculates the average valence for each day
    /// - Returns: Array of tuples (Date, Average Valence) sorted chronologically
    /// - Note: If multiple entries exist on the same day, they are averaged together
    var monthDailyAverages: [(Date, Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: monthEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped.map { date, entries in
            let average =
                entries.isEmpty
                ? 0 : entries.reduce(0.0) { $0 + $1.valence } / Double(entries.count)
            return (date, average)
        }.sorted { $0.0 < $1.0 }
    }
}
