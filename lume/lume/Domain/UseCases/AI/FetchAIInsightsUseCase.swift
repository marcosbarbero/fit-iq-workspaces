//
//  FetchAIInsightsUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for fetching AI insights use case
protocol FetchAIInsightsUseCaseProtocol {
    /// Fetch insights with optional filters
    /// - Parameters:
    ///   - type: Optional type filter
    ///   - unreadOnly: Filter for unread insights only
    ///   - favoritesOnly: Filter for favorites only
    ///   - archivedStatus: Optional archived status filter
    ///   - syncFromBackend: Whether to sync from backend first
    /// - Returns: Array of AIInsight objects
    /// - Throws: Use case error if fetch fails
    func execute(
        type: InsightType?,
        unreadOnly: Bool,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        syncFromBackend: Bool
    ) async throws -> [AIInsight]
}

/// Use case for fetching AI insights
/// Coordinates between local repository and backend service
final class FetchAIInsightsUseCase: FetchAIInsightsUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol
    ) {
        self.repository = repository
    }

    func execute(
        type: InsightType? = nil,
        unreadOnly: Bool = false,
        favoritesOnly: Bool = false,
        archivedStatus: Bool? = false,
        syncFromBackend: Bool = true
    ) async throws -> [AIInsight] {
        // Note: Backend sync is handled by the repository layer
        // The syncFromBackend parameter is kept for interface compatibility
        // but actual syncing happens via the Outbox pattern

        // Fetch from local repository with filters
        var insights: [AIInsight]

        // Apply filters
        if let type = type {
            insights = try await repository.fetchByType(type)
        } else if unreadOnly {
            insights = try await repository.fetchUnread()
        } else if favoritesOnly {
            insights = try await repository.fetchFavorites()
        } else if let archived = archivedStatus {
            if archived {
                insights = try await repository.fetchArchived()
            } else {
                // Fetch all non-archived
                let all = try await repository.fetchAll()
                insights = all.filter { !$0.isArchived }
            }
        } else {
            insights = try await repository.fetchAll()
        }

        // Apply additional filters
        if unreadOnly {
            insights = insights.filter { !$0.isRead }
        }

        if favoritesOnly {
            insights = insights.filter { $0.isFavorite }
        }

        if let archived = archivedStatus {
            insights = insights.filter { $0.isArchived == archived }
        }

        // Sort by created date, newest first
        insights.sort { $0.createdAt > $1.createdAt }

        return insights
    }
}

/// Simplified fetch for common use cases
extension FetchAIInsightsUseCase {
    /// Fetch all active (non-archived) insights
    func fetchActive() async throws -> [AIInsight] {
        try await execute(
            type: nil,
            unreadOnly: false,
            favoritesOnly: false,
            archivedStatus: false,
            syncFromBackend: true
        )
    }

    /// Fetch unread insights
    func fetchUnread() async throws -> [AIInsight] {
        try await execute(
            type: nil,
            unreadOnly: true,
            favoritesOnly: false,
            archivedStatus: false,
            syncFromBackend: true
        )
    }

    /// Fetch favorite insights
    func fetchFavorites() async throws -> [AIInsight] {
        try await execute(
            type: nil,
            unreadOnly: false,
            favoritesOnly: true,
            archivedStatus: false,
            syncFromBackend: false
        )
    }

    /// Fetch insights by type
    func fetchByType(_ type: InsightType) async throws -> [AIInsight] {
        try await execute(
            type: type,
            unreadOnly: false,
            favoritesOnly: false,
            archivedStatus: false,
            syncFromBackend: true
        )
    }
}
