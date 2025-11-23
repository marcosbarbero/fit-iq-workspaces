//
//  AIInsightRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Port for AI insight persistence operations
/// Implementation must be provided by the infrastructure layer
protocol AIInsightRepositoryProtocol {

    // MARK: - Advanced Filtering (matches swagger spec)

    /// Fetch insights with advanced filtering, sorting, and pagination
    /// - Parameters:
    ///   - insightType: Filter by insight type
    ///   - readStatus: Filter by read status (true = read only, false = unread only, nil = all)
    ///   - favoritesOnly: Show only favorite insights
    ///   - archivedStatus: Filter by archived status (true = archived only, false = non-archived only, nil = non-archived by default)
    ///   - periodFrom: Filter insights covering periods starting from this date
    ///   - periodTo: Filter insights covering periods up to this date
    ///   - limit: Maximum number of insights to return (1-100, default 20)
    ///   - offset: Number of insights to skip for pagination (default 0)
    ///   - sortBy: Field to sort by (created_at, updated_at, period_start)
    ///   - sortOrder: Sort order (asc, desc)
    /// - Returns: InsightListResult with filtered insights and pagination info
    /// - Throws: Repository error if fetch fails
    func fetchWithFilters(
        insightType: InsightType?,
        readStatus: Bool?,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        periodFrom: Date?,
        periodTo: Date?,
        limit: Int,
        offset: Int,
        sortBy: String,
        sortOrder: String
    ) async throws -> InsightListResult

    // MARK: - Simple Fetch Methods

    /// Fetch all insights for the current user
    /// - Returns: Array of AIInsight objects
    /// - Throws: Repository error if fetch fails
    func fetchAll() async throws -> [AIInsight]

    /// Fetch insights by type
    /// - Parameter type: The type of insights to fetch
    /// - Returns: Array of AIInsight objects of the specified type
    /// - Throws: Repository error if fetch fails
    func fetchByType(_ type: InsightType) async throws -> [AIInsight]

    /// Fetch unread insights
    /// - Returns: Array of unread AIInsight objects
    /// - Throws: Repository error if fetch fails
    func fetchUnread() async throws -> [AIInsight]

    /// Fetch favorite insights
    /// - Returns: Array of favorite AIInsight objects
    /// - Throws: Repository error if fetch fails
    func fetchFavorites() async throws -> [AIInsight]

    /// Fetch archived insights
    /// - Returns: Array of archived AIInsight objects
    /// - Throws: Repository error if fetch fails
    func fetchArchived() async throws -> [AIInsight]

    /// Fetch recent insights (last N days)
    /// - Parameter days: Number of days to look back
    /// - Returns: Array of recent AIInsight objects
    /// - Throws: Repository error if fetch fails
    func fetchRecent(days: Int) async throws -> [AIInsight]

    /// Fetch a specific insight by ID
    /// - Parameter id: The UUID of the insight
    /// - Returns: The AIInsight if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchById(_ id: UUID) async throws -> AIInsight?

    /// Save a new insight
    /// - Parameter insight: The insight to save
    /// - Returns: The saved AIInsight
    /// - Throws: Repository error if save fails
    func save(_ insight: AIInsight) async throws -> AIInsight

    /// Update an existing insight
    /// - Parameter insight: The insight to update
    /// - Returns: The updated AIInsight
    /// - Throws: Repository error if update fails
    func update(_ insight: AIInsight) async throws -> AIInsight

    /// Mark an insight as read
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Repository error if update fails
    func markAsRead(id: UUID) async throws -> AIInsight

    /// Toggle favorite status of an insight
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Repository error if update fails
    func toggleFavorite(id: UUID) async throws -> AIInsight

    /// Archive an insight
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Repository error if update fails
    func archive(id: UUID) async throws -> AIInsight

    /// Unarchive an insight
    /// - Parameter id: The UUID of the insight
    /// - Returns: The updated AIInsight
    /// - Throws: Repository error if update fails
    func unarchive(id: UUID) async throws -> AIInsight

    /// Delete an insight
    /// - Parameter id: The UUID of the insight to delete
    /// - Throws: Repository error if delete fails
    func delete(_ id: UUID) async throws

    /// Get total count of insights
    /// - Returns: The total number of insights
    /// - Throws: Repository error if count fails
    func count() async throws -> Int

    /// Get count of unread insights
    /// - Returns: The number of unread insights
    /// - Throws: Repository error if count fails
    func countUnread() async throws -> Int
}

// MARK: - Result Models

/// Result of fetching insights with pagination
struct InsightListResult {
    let insights: [AIInsight]
    let total: Int
    let limit: Int
    let offset: Int
}
