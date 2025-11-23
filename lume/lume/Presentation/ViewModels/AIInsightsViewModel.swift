//
//  AIInsightsViewModel.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation
import Observation

/// ViewModel for managing AI insights presentation layer
/// Coordinates between use cases and SwiftUI views
@Observable
final class AIInsightsViewModel {

    // MARK: - Published State

    /// All insights fetched from repository
    var insights: [AIInsight] = []

    /// Filtered insights based on current filter criteria
    var filteredInsights: [AIInsight] = []

    /// Count of unread insights
    var unreadCount: Int = 0

    /// Whether insights are currently being loaded
    var isLoading: Bool = false

    /// Whether new insights are being generated
    var isGenerating: Bool = false

    /// Current error message, if any
    var errorMessage: String?

    /// Whether generation is available (not done in last 24 hours)
    var canGenerateToday: Bool = true

    // MARK: - Filter State

    /// Filter by insight type
    var filterType: InsightType?

    /// Show only unread insights
    var showUnreadOnly: Bool = false

    /// Show only favorite insights
    var showFavoritesOnly: Bool = false

    /// Show archived insights
    var showArchived: Bool = false

    // MARK: - Selection State

    /// Currently selected insight for detail view
    var selectedInsight: AIInsight?

    // MARK: - Dependencies

    private let fetchInsightsUseCase: FetchAIInsightsUseCaseProtocol
    private let generateInsightUseCase: GenerateInsightUseCaseProtocol
    private let markAsReadUseCase: MarkInsightAsReadUseCaseProtocol
    private let toggleFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol
    private let archiveUseCase: ArchiveInsightUseCaseProtocol
    private let unarchiveUseCase: UnarchiveInsightUseCaseProtocol
    private let deleteUseCase: DeleteInsightUseCaseProtocol

    // MARK: - Initialization

    init(
        fetchInsightsUseCase: FetchAIInsightsUseCaseProtocol,
        generateInsightUseCase: GenerateInsightUseCaseProtocol,
        markAsReadUseCase: MarkInsightAsReadUseCaseProtocol,
        toggleFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol,
        archiveUseCase: ArchiveInsightUseCaseProtocol,
        unarchiveUseCase: UnarchiveInsightUseCaseProtocol,
        deleteUseCase: DeleteInsightUseCaseProtocol
    ) {
        self.fetchInsightsUseCase = fetchInsightsUseCase
        self.generateInsightUseCase = generateInsightUseCase
        self.markAsReadUseCase = markAsReadUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.archiveUseCase = archiveUseCase
        self.unarchiveUseCase = unarchiveUseCase
        self.deleteUseCase = deleteUseCase
    }

    // MARK: - Public Methods

    /// Load insights with current filter settings (from local cache only)
    @MainActor
    func loadInsights() async {
        isLoading = true
        errorMessage = nil

        print("📱 [AIInsightsViewModel] Loading insights from local cache")

        do {
            insights = try await fetchInsightsUseCase.execute(
                type: filterType,
                unreadOnly: showUnreadOnly,
                favoritesOnly: showFavoritesOnly,
                archivedStatus: showArchived ? true : nil,
                syncFromBackend: false  // Don't sync from backend on load
            )

            print("   ✅ Loaded \(insights.count) insight(s) from cache")

            applyFilters()
            updateUnreadCount()
            await checkGenerationAvailability()

        } catch {
            errorMessage = "Failed to load insights: \(error.localizedDescription)"
            insights = []
            filteredInsights = []
        }

        isLoading = false
    }

    /// Generate new AI insights
    @MainActor
    func generateNewInsights(types: [InsightType]? = nil, forceRefresh: Bool = false) async {
        isGenerating = true
        errorMessage = nil

        do {
            let newInsights = try await generateInsightUseCase.execute(
                types: types,
                forceRefresh: forceRefresh
            )

            // Merge new insights with existing ones
            for newInsight in newInsights {
                if !insights.contains(where: { $0.id == newInsight.id }) {
                    insights.insert(newInsight, at: 0)
                }
            }

            applyFilters()
            updateUnreadCount()
            await checkGenerationAvailability()

        } catch {
            errorMessage = "Failed to generate insights: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    /// Mark an insight as read
    @MainActor
    func markAsRead(id: UUID) async {
        do {
            let updatedInsight = try await markAsReadUseCase.execute(id: id)
            updateInsight(updatedInsight)
            updateUnreadCount()
        } catch {
            errorMessage = "Failed to mark as read: \(error.localizedDescription)"
        }
    }

    /// Toggle favorite status of an insight
    @MainActor
    func toggleFavorite(id: UUID) async {
        do {
            let updatedInsight = try await toggleFavoriteUseCase.execute(id: id)
            updateInsight(updatedInsight)
        } catch {
            errorMessage = "Failed to toggle favorite: \(error.localizedDescription)"
        }
    }

    /// Archive an insight
    @MainActor
    func archive(id: UUID) async {
        do {
            let updatedInsight = try await archiveUseCase.execute(id: id)
            updateInsight(updatedInsight)

            // Remove from filtered list if not showing archived
            if !showArchived {
                filteredInsights.removeAll { $0.id == id }
            }

        } catch {
            errorMessage = "Failed to archive insight: \(error.localizedDescription)"
        }
    }

    /// Unarchive an insight
    @MainActor
    func unarchive(id: UUID) async {
        do {
            let updatedInsight = try await unarchiveUseCase.execute(id: id)
            updateInsight(updatedInsight)

            // Remove from filtered list if showing archived only
            if showArchived {
                filteredInsights.removeAll { $0.id == id }
            }

        } catch {
            errorMessage = "Failed to unarchive insight: \(error.localizedDescription)"
        }
    }

    /// Delete an insight permanently
    @MainActor
    func delete(id: UUID) async {
        do {
            try await deleteUseCase.execute(id: id)

            // Remove from all lists
            insights.removeAll { $0.id == id }
            filteredInsights.removeAll { $0.id == id }

            // Clear selection if deleted insight was selected
            if selectedInsight?.id == id {
                selectedInsight = nil
            }

            updateUnreadCount()

        } catch {
            errorMessage = "Failed to delete insight: \(error.localizedDescription)"
        }
    }

    /// Refresh insights from backend (explicitly sync)
    @MainActor
    func refreshFromBackend() async {
        isLoading = true
        errorMessage = nil

        print("🔄 [AIInsightsViewModel] Refreshing insights from backend")

        do {
            insights = try await fetchInsightsUseCase.execute(
                type: filterType,
                unreadOnly: showUnreadOnly,
                favoritesOnly: showFavoritesOnly,
                archivedStatus: showArchived ? true : nil,
                syncFromBackend: true  // Explicit backend sync
            )

            print("   ✅ Refreshed \(insights.count) insight(s) from backend")

            applyFilters()
            updateUnreadCount()
            await checkGenerationAvailability()

        } catch {
            errorMessage = "Failed to refresh insights: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Clear all filters
    func clearFilters() {
        filterType = nil
        showUnreadOnly = false
        showFavoritesOnly = false
        showArchived = false
        applyFilters()
    }

    /// Set filter type
    func setFilterType(_ type: InsightType?) {
        filterType = type
        applyFilters()
    }

    /// Toggle unread filter
    func toggleUnreadFilter() {
        showUnreadOnly.toggle()
        applyFilters()
    }

    /// Toggle favorites filter
    func toggleFavoritesFilter() {
        showFavoritesOnly.toggle()
        applyFilters()
    }

    /// Toggle archived filter
    func toggleArchivedFilter() {
        showArchived.toggle()
        applyFilters()
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Helpers

    /// Apply current filters to insights
    func applyFilters() {
        var filtered = insights

        // Filter by type
        if let type = filterType {
            filtered = filtered.filter { $0.insightType == type }
        }

        // Filter by unread status
        if showUnreadOnly {
            filtered = filtered.filter { !$0.isRead }
        }

        // Filter by favorite status
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }

        // Filter by archived status
        if showArchived {
            filtered = filtered.filter { $0.isArchived }
        } else {
            filtered = filtered.filter { !$0.isArchived }
        }

        // Sort by created date (newest first)
        filtered.sort { $0.createdAt > $1.createdAt }

        filteredInsights = filtered
    }

    /// Check if generation is available (no insights generated in last 24 hours)
    private func checkGenerationAvailability() async {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let recentInsights = insights.filter { insight in
            insight.createdAt > oneDayAgo && !insight.isArchived && insight.insightType == .daily
        }
        canGenerateToday = recentInsights.isEmpty
    }

    /// Update an insight in the collection
    private func updateInsight(_ updatedInsight: AIInsight) {
        if let index = insights.firstIndex(where: { $0.id == updatedInsight.id }) {
            insights[index] = updatedInsight
        }

        if let index = filteredInsights.firstIndex(where: { $0.id == updatedInsight.id }) {
            filteredInsights[index] = updatedInsight
        }

        if selectedInsight?.id == updatedInsight.id {
            selectedInsight = updatedInsight
        }
    }

    /// Update unread count
    private func updateUnreadCount() {
        unreadCount = insights.filter { !$0.isRead && !$0.isArchived }.count
    }

    // MARK: - Computed Properties

    /// Whether any filters are active
    var hasActiveFilters: Bool {
        filterType != nil || showUnreadOnly || showFavoritesOnly || showArchived
    }

    /// Whether the list is empty
    var isEmpty: Bool {
        filteredInsights.isEmpty
    }

    /// Whether there are any insights at all
    var hasAnyInsights: Bool {
        !insights.isEmpty
    }
}

// MARK: - Preview Support

#if DEBUG
    extension AIInsightsViewModel {
        static var preview: AIInsightsViewModel {
            AIInsightsViewModel(
                fetchInsightsUseCase: PreviewFetchAIInsightsUseCase(),
                generateInsightUseCase: PreviewGenerateInsightUseCase(),
                markAsReadUseCase: PreviewMarkInsightAsReadUseCase(),
                toggleFavoriteUseCase: PreviewToggleInsightFavoriteUseCase(),
                archiveUseCase: PreviewArchiveInsightUseCase(),
                unarchiveUseCase: PreviewUnarchiveInsightUseCase(),
                deleteUseCase: PreviewDeleteInsightUseCase()
            )
        }
    }

    // MARK: - Preview Use Cases

    private class PreviewFetchAIInsightsUseCase: FetchAIInsightsUseCaseProtocol {
        func execute(
            type: InsightType?, unreadOnly: Bool, favoritesOnly: Bool, archivedStatus: Bool?,
            syncFromBackend: Bool
        ) async throws -> [AIInsight] {
            return AIInsight.previewInsights
        }
    }

    private class PreviewGenerateInsightUseCase: GenerateInsightUseCaseProtocol {
        func execute(types: [InsightType]?, forceRefresh: Bool) async throws -> [AIInsight] {
            return [AIInsight.previewInsights[0]]
        }
    }

    private class PreviewMarkInsightAsReadUseCase: MarkInsightAsReadUseCaseProtocol {
        func execute(id: UUID) async throws -> AIInsight {
            var insight = AIInsight.previewInsights[0]
            insight.markAsRead()
            return insight
        }
    }

    private class PreviewToggleInsightFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol {
        func execute(id: UUID) async throws -> AIInsight {
            var insight = AIInsight.previewInsights[0]
            insight.toggleFavorite()
            return insight
        }
    }

    private class PreviewArchiveInsightUseCase: ArchiveInsightUseCaseProtocol {
        func execute(id: UUID) async throws -> AIInsight {
            var insight = AIInsight.previewInsights[0]
            insight.archive()
            return insight
        }
    }

    private class PreviewUnarchiveInsightUseCase: UnarchiveInsightUseCaseProtocol {
        func execute(id: UUID) async throws -> AIInsight {
            var insight = AIInsight.previewInsights[0]
            insight.unarchive()
            return insight
        }
    }

    private class PreviewDeleteInsightUseCase: DeleteInsightUseCaseProtocol {
        func execute(id: UUID) async throws {
            // No-op for preview
        }
    }

    // MARK: - Preview Data

    extension AIInsight {
        static var previewInsights: [AIInsight] {
            [
                AIInsight(
                    id: UUID(),
                    userId: UUID(),
                    insightType: .weekly,
                    title: "Your Week in Review",
                    content:
                        "This week, you've shown remarkable consistency in tracking your mood. Your average mood score was 4.2 out of 5, indicating a generally positive week. You journaled 5 times, which shows great dedication to self-reflection.",
                    summary:
                        "A positive week with consistent mood tracking and regular journaling.",
                    periodStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                    periodEnd: Date(),
                    metrics: InsightMetrics(
                        moodEntriesCount: 7,
                        journalEntriesCount: 5,
                        goalsActive: 3,
                        goalsCompleted: 2
                    ),
                    suggestions: [
                        "Continue your daily check-ins to maintain this positive momentum",
                        "Consider setting a new wellness goal to build on your progress",
                    ],
                    isRead: false,
                    isFavorite: false,
                    isArchived: false,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                AIInsight(
                    id: UUID(),
                    userId: UUID(),
                    insightType: .daily,
                    title: "Daily Check-In",
                    content:
                        "We've noticed your mood tends to be higher in the mornings. This is a great insight! Consider scheduling important tasks or challenging activities during your peak energy times.",
                    summary: "Higher mood in mornings - optimize your schedule accordingly.",
                    periodStart: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                    periodEnd: Date(),
                    metrics: InsightMetrics(
                        moodEntriesCount: 3,
                        journalEntriesCount: 1
                    ),
                    suggestions: [
                        "Schedule challenging tasks for morning hours",
                        "Protect your morning routine to maintain this pattern",
                    ],
                    isRead: true,
                    isFavorite: true,
                    isArchived: false,
                    createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())
                        ?? Date(),
                    updatedAt: Date()
                ),
                AIInsight(
                    id: UUID(),
                    userId: UUID(),
                    insightType: .milestone,
                    title: "Milestone Reached!",
                    content:
                        "Congratulations! You've completed 7 days of consistent mood tracking. This is a significant achievement and shows your commitment to emotional wellness.",
                    summary: "7-day tracking streak completed!",
                    metrics: InsightMetrics(
                        moodEntriesCount: 7
                    ),
                    suggestions: [
                        "Keep up the great work!",
                        "Consider sharing your progress with a friend",
                    ],
                    isRead: true,
                    isFavorite: false,
                    isArchived: false,
                    createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())
                        ?? Date(),
                    updatedAt: Date()
                ),
            ]
        }
    }
#endif
