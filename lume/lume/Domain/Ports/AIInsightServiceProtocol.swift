//
//  AIInsightServiceProtocol.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Port for AI insight generation service
/// Implementation must be provided by the infrastructure layer
protocol AIInsightServiceProtocol {
    /// Generate a new AI insight based on user context
    /// - Parameters:
    ///   - type: The type of insight to generate
    ///   - context: User context including mood, journal, and goal data
    /// - Returns: The generated AIInsight
    /// - Throws: Service error if generation fails
    func generateInsight(
        type: InsightType,
        context: UserContextData
    ) async throws -> AIInsight

    /// Check if a new insight should be generated
    /// - Parameter type: The type of insight to check
    /// - Returns: True if a new insight should be generated
    /// - Throws: Service error if check fails
    func shouldGenerateInsight(type: InsightType) async throws -> Bool

    /// Fetch insights from backend API
    /// - Parameters:
    ///   - type: Optional type filter
    ///   - readStatus: Optional read status filter
    ///   - favoritesOnly: Filter for favorites only
    ///   - archivedStatus: Optional archived status filter
    ///   - page: Page number for pagination
    ///   - pageSize: Number of items per page
    /// - Returns: Array of AIInsight objects
    /// - Throws: Service error if fetch fails
    func fetchInsights(
        type: InsightType?,
        readStatus: Bool?,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        page: Int,
        pageSize: Int
    ) async throws -> [AIInsight]

    /// Fetch a specific insight from backend
    /// - Parameter id: The UUID of the insight
    /// - Returns: The AIInsight if found
    /// - Throws: Service error if fetch fails
    func fetchInsight(id: UUID) async throws -> AIInsight

    /// Update insight status on backend
    /// - Parameters:
    ///   - id: The UUID of the insight
    ///   - isRead: Optional new read status
    ///   - isFavorite: Optional new favorite status
    ///   - isArchived: Optional new archived status
    /// - Returns: The updated AIInsight
    /// - Throws: Service error if update fails
    func updateInsight(
        id: UUID,
        isRead: Bool?,
        isFavorite: Bool?,
        isArchived: Bool?
    ) async throws -> AIInsight

    /// Delete an insight from backend
    /// - Parameter id: The UUID of the insight to delete
    /// - Throws: Service error if delete fails
    func deleteInsight(id: UUID) async throws
}

/// User context data for AI insight generation
struct UserContextData: Codable, Equatable {
    let moodHistory: [MoodContextEntry]
    let journalEntries: [JournalContextEntry]
    let activeGoals: [GoalContextEntry]
    let completedGoals: [GoalContextEntry]
    let dateRange: DateRange

    init(
        moodHistory: [MoodContextEntry] = [],
        journalEntries: [JournalContextEntry] = [],
        activeGoals: [GoalContextEntry] = [],
        completedGoals: [GoalContextEntry] = [],
        dateRange: DateRange
    ) {
        self.moodHistory = moodHistory
        self.journalEntries = journalEntries
        self.activeGoals = activeGoals
        self.completedGoals = completedGoals
        self.dateRange = dateRange
    }

    /// Check if context has any data
    var hasData: Bool {
        !moodHistory.isEmpty || !journalEntries.isEmpty || !activeGoals.isEmpty
            || !completedGoals.isEmpty
    }
}

/// Mood context entry for AI processing
struct MoodContextEntry: Codable, Equatable {
    let date: Date
    let mood: String
    let note: String?

    init(date: Date, mood: String, note: String? = nil) {
        self.date = date
        self.mood = mood
        self.note = note
    }
}

/// Journal context entry for AI processing
struct JournalContextEntry: Codable, Equatable {
    let date: Date
    let text: String
    let wordCount: Int

    init(date: Date, text: String, wordCount: Int) {
        self.date = date
        self.text = text
        self.wordCount = wordCount
    }
}

/// Goal context entry for AI processing
struct GoalContextEntry: Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let category: String
    let progress: Double
    let status: String
    let createdAt: Date

    init(
        id: UUID,
        title: String,
        description: String,
        category: String,
        progress: Double,
        status: String,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.progress = progress
        self.status = status
        self.createdAt = createdAt
    }
}
