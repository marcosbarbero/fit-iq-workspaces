//
//  GoalRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation

/// Port for goal persistence operations
/// Implementation must be provided by the infrastructure layer
protocol GoalRepositoryProtocol {
    /// Create a new goal
    /// - Parameters:
    ///   - title: The goal title
    ///   - description: The goal description
    ///   - category: The goal category
    ///   - targetDate: Optional target completion date
    ///   - targetValue: Target value to achieve (must be > 0)
    ///   - targetUnit: Unit of measurement (kg, steps, minutes, servings, etc.)
    /// - Returns: The created Goal
    /// - Throws: Repository error if creation fails
    func create(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?,
        targetValue: Double,
        targetUnit: String
    ) async throws -> Goal

    /// Update an existing goal
    /// - Parameter goal: The goal to update
    /// - Returns: The updated Goal
    /// - Throws: Repository error if update fails
    func update(_ goal: Goal) async throws -> Goal

    /// Update goal progress
    /// - Parameters:
    ///   - id: The UUID of the goal
    ///   - progress: The new progress value (0.0 to 1.0)
    /// - Returns: The updated Goal
    /// - Throws: Repository error if update fails
    func updateProgress(id: UUID, progress: Double) async throws -> Goal

    /// Update goal status
    /// - Parameters:
    ///   - id: The UUID of the goal
    ///   - status: The new status
    /// - Returns: The updated Goal
    /// - Throws: Repository error if update fails
    func updateStatus(id: UUID, status: GoalStatus) async throws -> Goal

    /// Fetch all goals
    /// - Returns: Array of all Goal objects
    /// - Throws: Repository error if fetch fails
    func fetchAll() async throws -> [Goal]

    /// Fetch goals by status
    /// - Parameter status: The status to filter by
    /// - Returns: Array of Goal objects with the specified status
    /// - Throws: Repository error if fetch fails
    func fetchByStatus(_ status: GoalStatus) async throws -> [Goal]

    /// Fetch goals by category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of Goal objects with the specified category
    /// - Throws: Repository error if fetch fails
    func fetchByCategory(_ category: GoalCategory) async throws -> [Goal]

    /// Fetch active goals (status = .active)
    /// - Returns: Array of active Goal objects
    /// - Throws: Repository error if fetch fails
    func fetchActive() async throws -> [Goal]

    /// Fetch overdue goals (past target date and not complete)
    /// - Returns: Array of overdue Goal objects
    /// - Throws: Repository error if fetch fails
    func fetchOverdue() async throws -> [Goal]

    /// Fetch a specific goal by ID
    /// - Parameter id: The UUID of the goal
    /// - Returns: The Goal if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchById(_ id: UUID) async throws -> Goal?

    /// Get the backend ID for a goal
    /// - Parameter id: The local UUID of the goal
    /// - Returns: The backend-assigned ID if synced, nil otherwise
    /// - Throws: Repository error if fetch fails
    func getBackendId(for id: UUID) async throws -> String?

    /// Get cached tips for a goal
    /// - Parameter goalId: The local UUID of the goal
    /// - Returns: Cached tips if available and not expired, nil otherwise
    /// - Throws: Repository error if fetch fails
    func getCachedTips(for goalId: UUID) async throws -> [GoalTip]?

    /// Save tips to cache
    /// - Parameters:
    ///   - goalId: The local UUID of the goal
    ///   - backendId: The backend-assigned ID of the goal
    ///   - tips: Array of tips to cache
    ///   - expirationDays: Number of days until cache expires (default: 7)
    /// - Throws: Repository error if save fails
    func cacheTips(
        for goalId: UUID,
        backendId: String?,
        tips: [GoalTip],
        expirationDays: Int
    ) async throws

    /// Clear expired tip caches
    /// - Throws: Repository error if cleanup fails
    func clearExpiredTipCaches() async throws

    /// Delete a goal
    /// - Parameter id: The UUID of the goal to delete
    /// - Throws: Repository error if delete fails
    func delete(_ id: UUID) async throws

    /// Archive a goal (sets status to .archived)
    /// - Parameter id: The UUID of the goal to archive
    /// - Returns: The archived Goal
    /// - Throws: Repository error if archive fails
    func archive(_ id: UUID) async throws -> Goal

    /// Complete a goal (sets status to .completed and progress to 1.0)
    /// - Parameter id: The UUID of the goal to complete
    /// - Returns: The completed Goal
    /// - Throws: Repository error if completion fails
    func complete(_ id: UUID) async throws -> Goal

    /// Get total count of goals
    /// - Returns: The total number of goals
    /// - Throws: Repository error if count fails
    func count() async throws -> Int

    /// Get count of goals by status
    /// - Parameter status: The status to count
    /// - Returns: The number of goals with the specified status
    /// - Throws: Repository error if count fails
    func countByStatus(_ status: GoalStatus) async throws -> Int
}
