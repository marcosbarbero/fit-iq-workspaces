//
//  GenerateGoalSuggestionsUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for generating AI goal suggestions use case
protocol GenerateGoalSuggestionsUseCaseProtocol {
    /// Generate AI-powered goal suggestions based on user context
    /// - Returns: Array of GoalSuggestion objects
    /// - Throws: Use case error if generation fails
    func execute() async throws -> [GoalSuggestion]
}

/// Use case for generating AI goal suggestions
/// Builds user context and requests suggestions from AI service
final class GenerateGoalSuggestionsUseCase: GenerateGoalSuggestionsUseCaseProtocol {
    private let goalAIService: GoalAIServiceProtocol
    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol
    private let goalRepository: GoalRepositoryProtocol

    init(
        goalAIService: GoalAIServiceProtocol,
        moodRepository: MoodRepositoryProtocol,
        journalRepository: JournalRepositoryProtocol,
        goalRepository: GoalRepositoryProtocol
    ) {
        self.goalAIService = goalAIService
        self.moodRepository = moodRepository
        self.journalRepository = journalRepository
        self.goalRepository = goalRepository
    }

    func execute() async throws -> [GoalSuggestion] {
        // Build user context for AI
        let context = try await buildUserContext()

        // Generate suggestions from AI service
        let suggestions = try await goalAIService.generateGoalSuggestions(context: context)

        // Filter out suggestions similar to existing goals
        let existingGoals = try await goalRepository.fetchActive()
        let filteredSuggestions = filterDuplicates(
            suggestions: suggestions,
            existingGoals: existingGoals
        )

        return filteredSuggestions
    }
}

// MARK: - Private Helpers

extension GenerateGoalSuggestionsUseCase {
    /// Build user context from recent data
    fileprivate func buildUserContext() async throws -> UserContextData {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let today = Date()
        let dateRange = DateRange(startDate: thirtyDaysAgo, endDate: today)

        // Fetch recent mood entries
        let moodEntries = try await moodRepository.fetchRecent(days: 30)
        let moodContext = moodEntries.map { entry in
            MoodContextEntry(
                date: entry.date,
                mood: entry.primaryLabel ?? "unknown",
                note: entry.notePreview
            )
        }

        // Fetch recent journal entries
        let journalEntries = try await journalRepository.fetchRecent(limit: 30)
        let journalContext = journalEntries.map { entry in
            let wordCount = entry.content.components(
                separatedBy: CharacterSet.whitespacesAndNewlines
            )
            .filter { !$0.isEmpty }
            .count

            return JournalContextEntry(
                date: entry.date,
                text: entry.content,
                wordCount: wordCount
            )
        }

        // Fetch active goals
        let activeGoals = try await goalRepository.fetchActive()
        let activeGoalsContext = activeGoals.map { goal in
            GoalContextEntry(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                category: goal.category.rawValue,
                progress: goal.progress,
                status: goal.status.rawValue,
                createdAt: goal.createdAt
            )
        }

        // Fetch completed goals
        let completedGoals = try await goalRepository.fetchByStatus(.completed)
        let completedGoalsContext = completedGoals.map { goal in
            GoalContextEntry(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                category: goal.category.rawValue,
                progress: goal.progress,
                status: goal.status.rawValue,
                createdAt: goal.createdAt
            )
        }

        return UserContextData(
            moodHistory: moodContext,
            journalEntries: journalContext,
            activeGoals: activeGoalsContext,
            completedGoals: completedGoalsContext,
            dateRange: dateRange
        )
    }

    /// Filter out suggestions that are too similar to existing goals
    fileprivate func filterDuplicates(
        suggestions: [GoalSuggestion],
        existingGoals: [Goal]
    ) -> [GoalSuggestion] {
        suggestions.filter { suggestion in
            !isSimilarToExistingGoal(suggestion: suggestion, existingGoals: existingGoals)
        }
    }

    /// Check if suggestion is similar to an existing goal
    fileprivate func isSimilarToExistingGoal(
        suggestion: GoalSuggestion,
        existingGoals: [Goal]
    ) -> Bool {
        let suggestionTitle = suggestion.title.lowercased()
        let suggestionCategory = suggestion.category

        for goal in existingGoals {
            let goalTitle = goal.title.lowercased()

            // Check for exact match
            if suggestionTitle == goalTitle {
                return true
            }

            // Check for very similar titles (>70% similarity)
            if calculateSimilarity(suggestionTitle, goalTitle) > 0.7 {
                return true
            }

            // Check for same category with similar keywords
            if suggestionCategory == goal.category {
                let suggestionKeywords = extractKeywords(from: suggestionTitle)
                let goalKeywords = extractKeywords(from: goalTitle)
                let commonKeywords = Set(suggestionKeywords).intersection(Set(goalKeywords))

                // If more than 50% of keywords overlap, consider it similar
                if !suggestionKeywords.isEmpty {
                    let overlapRatio =
                        Double(commonKeywords.count) / Double(suggestionKeywords.count)
                    if overlapRatio > 0.5 {
                        return true
                    }
                }
            }
        }

        return false
    }

    /// Calculate similarity between two strings (0.0 to 1.0)
    fileprivate func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let set1 = Set(str1.components(separatedBy: .whitespaces))
        let set2 = Set(str2.components(separatedBy: .whitespaces))

        let intersection = set1.intersection(set2)
        let union = set1.union(set2)

        guard !union.isEmpty else { return 0.0 }

        return Double(intersection.count) / Double(union.count)
    }

    /// Extract meaningful keywords from a string
    fileprivate func extractKeywords(from text: String) -> [String] {
        let stopWords = Set([
            "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "as", "is", "was", "are", "were", "be",
            "been", "being", "have", "has", "had", "do", "does", "did", "will",
            "would", "should", "could", "may", "might", "must", "can", "my", "your",
            "i", "me", "we", "us",
        ])

        return
            text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !stopWords.contains($0) && $0.count > 2 }
    }
}
