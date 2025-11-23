//
//  FetchGoalsUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for fetching goals use case
protocol FetchGoalsUseCaseProtocol {
    /// Fetch goals with optional filters
    /// - Parameters:
    ///   - status: Optional status filter
    ///   - category: Optional category filter
    /// - Returns: Array of Goal objects
    /// - Throws: Use case error if fetch fails
    func execute(
        status: GoalStatus?,
        category: GoalCategory?
    ) async throws -> [Goal]
}

/// Use case for fetching goals
/// Follows offline-first pattern, fetching from local repository
final class FetchGoalsUseCase: FetchGoalsUseCaseProtocol {
    private let goalRepository: GoalRepositoryProtocol

    init(goalRepository: GoalRepositoryProtocol) {
        self.goalRepository = goalRepository
    }

    func execute(
        status: GoalStatus? = nil,
        category: GoalCategory? = nil
    ) async throws -> [Goal] {
        // Fetch from local repository with filters
        var goals: [Goal]

        if let status = status {
            goals = try await goalRepository.fetchByStatus(status)
        } else if let category = category {
            goals = try await goalRepository.fetchByCategory(category)
        } else {
            goals = try await goalRepository.fetchAll()
        }

        // Apply additional filters if both status and category are specified
        if let status = status, let category = category {
            goals = goals.filter { $0.status == status && $0.category == category }
        }

        // Sort by created date, newest first
        goals.sort { $0.createdAt > $1.createdAt }

        return goals
    }
}

// MARK: - Convenience Methods

extension FetchGoalsUseCase {
    /// Fetch all active goals
    func fetchActive() async throws -> [Goal] {
        try await execute(status: .active, category: nil)
    }

    /// Fetch all completed goals
    func fetchCompleted() async throws -> [Goal] {
        try await execute(status: .completed, category: nil)
    }

    /// Fetch all paused goals
    func fetchPaused() async throws -> [Goal] {
        try await execute(status: .paused, category: nil)
    }

    /// Fetch all archived goals
    func fetchArchived() async throws -> [Goal] {
        try await execute(status: .archived, category: nil)
    }

    /// Fetch goals by category
    func fetchByCategory(_ category: GoalCategory) async throws -> [Goal] {
        try await execute(status: nil, category: category)
    }

    /// Fetch all goals (no filters)
    func fetchAll() async throws -> [Goal] {
        try await execute(status: nil, category: nil)
    }

    /// Fetch goals that are stalled (active with low progress)
    func fetchStalled() async throws -> [Goal] {
        let activeGoals = try await fetchActive()

        // Consider goals stalled if:
        // 1. They're active
        // 2. Progress is less than 20%
        // 3. Created more than 7 days ago
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        return activeGoals.filter { goal in
            goal.progress < 0.2 && goal.createdAt < sevenDaysAgo
        }
    }

    /// Fetch goals near completion (active with high progress)
    func fetchNearCompletion() async throws -> [Goal] {
        let activeGoals = try await fetchActive()

        // Goals near completion have 80% or more progress
        return activeGoals.filter { $0.progress >= 0.8 }
    }

    /// Fetch goals with upcoming target dates (within next 7 days)
    func fetchUpcoming() async throws -> [Goal] {
        let activeGoals = try await fetchActive()
        let now = Date()
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        return activeGoals.filter { goal in
            if let targetDate = goal.targetDate {
                return targetDate >= now && targetDate <= sevenDaysFromNow
            }
            return false
        }.sorted { goal1, goal2 in
            // Sort by target date, soonest first
            guard let date1 = goal1.targetDate, let date2 = goal2.targetDate else {
                return false
            }
            return date1 < date2
        }
    }

    /// Fetch overdue goals (past target date, still active)
    func fetchOverdue() async throws -> [Goal] {
        let activeGoals = try await fetchActive()
        let now = Date()

        return activeGoals.filter { goal in
            if let targetDate = goal.targetDate {
                return targetDate < now
            }
            return false
        }.sorted { goal1, goal2 in
            // Sort by how overdue, most overdue first
            guard let date1 = goal1.targetDate, let date2 = goal2.targetDate else {
                return false
            }
            return date1 < date2
        }
    }
}

// MARK: - Statistics

extension FetchGoalsUseCase {
    /// Get goal statistics summary
    func getStatistics() async throws -> GoalStatisticsSummary {
        let allGoals = try await fetchAll()

        let activeCount = allGoals.filter { $0.status == .active }.count
        let completedCount = allGoals.filter { $0.status == .completed }.count
        let pausedCount = allGoals.filter { $0.status == .paused }.count
        let archivedCount = allGoals.filter { $0.status == .archived }.count

        let activeGoals = allGoals.filter { $0.status == .active }
        let averageProgress =
            activeGoals.isEmpty
            ? 0.0
            : activeGoals.reduce(0.0) { $0 + $1.progress } / Double(activeGoals.count)

        let stalledGoals = try await fetchStalled()
        let nearCompletionGoals = try await fetchNearCompletion()
        let overdueGoals = try await fetchOverdue()

        return GoalStatisticsSummary(
            totalCount: allGoals.count,
            activeCount: activeCount,
            completedCount: completedCount,
            pausedCount: pausedCount,
            archivedCount: archivedCount,
            averageProgress: averageProgress,
            stalledCount: stalledGoals.count,
            nearCompletionCount: nearCompletionGoals.count,
            overdueCount: overdueGoals.count
        )
    }
}

// MARK: - Supporting Types

/// Summary statistics for goals
struct GoalStatisticsSummary {
    let totalCount: Int
    let activeCount: Int
    let completedCount: Int
    let pausedCount: Int
    let archivedCount: Int
    let averageProgress: Double
    let stalledCount: Int
    let nearCompletionCount: Int
    let overdueCount: Int

    var completionRate: Double {
        let total = activeCount + completedCount
        return total > 0 ? Double(completedCount) / Double(total) : 0.0
    }

    var description: String {
        var parts: [String] = []

        if activeCount > 0 {
            parts.append("\(activeCount) active")
        }
        if completedCount > 0 {
            parts.append("\(completedCount) completed")
        }
        if pausedCount > 0 {
            parts.append("\(pausedCount) paused")
        }

        if parts.isEmpty {
            return "No goals yet"
        }

        return parts.joined(separator: ", ")
    }
}
