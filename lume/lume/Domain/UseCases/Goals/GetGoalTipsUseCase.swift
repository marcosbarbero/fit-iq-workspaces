//
//  GetGoalTipsUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for getting AI goal tips use case
protocol GetGoalTipsUseCaseProtocol {
    /// Get AI-powered tips for achieving a specific goal
    /// - Parameter goalId: The UUID of the goal
    /// - Returns: Array of GoalTip objects
    /// - Throws: Use case error if fetching tips fails
    func execute(goalId: UUID) async throws -> [GoalTip]
}

/// Use case for getting AI tips for a goal
/// Builds context and requests tips from AI service
final class GetGoalTipsUseCase: GetGoalTipsUseCaseProtocol {
    private let goalAIService: GoalAIServiceProtocol
    private let goalRepository: GoalRepositoryProtocol
    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol

    init(
        goalAIService: GoalAIServiceProtocol,
        goalRepository: GoalRepositoryProtocol,
        moodRepository: MoodRepositoryProtocol,
        journalRepository: JournalRepositoryProtocol
    ) {
        self.goalAIService = goalAIService
        self.goalRepository = goalRepository
        self.moodRepository = moodRepository
        self.journalRepository = journalRepository
    }

    func execute(goalId: UUID) async throws -> [GoalTip] {
        // Check cache first
        if let cachedTips = try await goalRepository.getCachedTips(for: goalId) {
            print("✅ [GetGoalTipsUseCase] Using cached tips for goal \(goalId)")
            return cachedTips
        }

        print("🔄 [GetGoalTipsUseCase] No cache found, fetching from AI service")

        // Fetch the goal
        guard let goal = try await goalRepository.fetchById(goalId) else {
            throw GetGoalTipsError.goalNotFound
        }

        // Get backend ID (required for AI endpoints)
        guard let backendId = try await goalRepository.getBackendId(for: goalId) else {
            throw GetGoalTipsError.goalNotSynced
        }

        // Build user context for personalized tips
        let context = try await buildUserContext()

        // Get tips from AI service using backend ID
        let tips = try await goalAIService.getGoalTips(
            backendId: backendId,
            goalTitle: goal.title,
            goalDescription: goal.description,
            context: context
        )

        // Sort tips by priority (high to low)
        let sortedTips = tips.sorted { tip1, tip2 in
            tip1.priority.level > tip2.priority.level
        }

        // Cache the tips for future use (7 day expiration)
        do {
            try await goalRepository.cacheTips(
                for: goalId,
                backendId: backendId,
                tips: sortedTips,
                expirationDays: 7
            )
        } catch {
            // Don't fail the request if caching fails, just log it
            print("⚠️ [GetGoalTipsUseCase] Failed to cache tips: \(error)")
        }

        return sortedTips
    }
}

// MARK: - Private Helpers

extension GetGoalTipsUseCase {
    /// Build user context for personalized tips
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
}

// MARK: - Errors

/// Errors specific to GetGoalTipsUseCase
enum GetGoalTipsError: Error, LocalizedError {
    case goalNotFound
    case goalNotSynced
    case noTipsAvailable
    case contextBuildFailed

    var errorDescription: String? {
        switch self {
        case .goalNotFound:
            return "Goal not found. Please make sure the goal exists."
        case .goalNotSynced:
            return "Goal is still syncing with the server. Please try again in a moment."
        case .noTipsAvailable:
            return "No tips available for this goal at the moment."
        case .contextBuildFailed:
            return "Failed to build context for personalized tips."
        }
    }
}
