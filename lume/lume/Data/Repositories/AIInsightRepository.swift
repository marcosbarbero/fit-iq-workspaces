//
//  AIInsightRepository.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation
import SwiftData

/// SwiftData implementation of AIInsightRepositoryProtocol
/// Handles local persistence of AI-generated wellness insights
final class AIInsightRepository: AIInsightRepositoryProtocol, UserAuthenticatedRepository {
    private let modelContext: ModelContext
    private let backendService: AIInsightBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol

    init(
        modelContext: ModelContext,
        backendService: AIInsightBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.modelContext = modelContext
        self.backendService = backendService
        self.tokenStorage = tokenStorage
    }

    // MARK: - Advanced Filtering

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
    ) async throws -> InsightListResult {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        // Build complex predicate based on filters
        var predicates: [Predicate<SDAIInsight>] = []

        // Always filter by user ID
        predicates.append(#Predicate { $0.userId == userId })

        // Type filter
        if let type = insightType {
            let typeString = type.rawValue
            predicates.append(#Predicate { $0.insightType == typeString })
        }

        // Read status filter
        if let isRead = readStatus {
            predicates.append(#Predicate { $0.isRead == isRead })
        }

        // Favorites filter
        if favoritesOnly {
            predicates.append(#Predicate { $0.isFavorite == true })
        }

        // Archived status filter (default to non-archived if nil)
        if let isArchived = archivedStatus {
            predicates.append(#Predicate { $0.isArchived == isArchived })
        } else {
            predicates.append(#Predicate { $0.isArchived == false })
        }

        // Period filters
        if let from = periodFrom {
            predicates.append(
                #Predicate { insight in
                    insight.periodStart ?? insight.createdAt >= from
                })
        }

        if let to = periodTo {
            predicates.append(
                #Predicate { insight in
                    insight.periodEnd ?? insight.createdAt <= to
                })
        }

        // Combine all predicates
        let combinedPredicate = predicates.reduce(into: #Predicate<SDAIInsight> { _ in true }) {
            result, predicate in
            result = #Predicate { insight in
                result.evaluate(insight) && predicate.evaluate(insight)
            }
        }

        // Determine sort descriptor
        let sortDescriptor: SortDescriptor<SDAIInsight>
        switch sortBy.lowercased() {
        case "updated_at":
            sortDescriptor = SortDescriptor(
                \SDAIInsight.updatedAt, order: sortOrder == "asc" ? .forward : .reverse)
        case "period_start":
            sortDescriptor = SortDescriptor(
                \SDAIInsight.periodStart, order: sortOrder == "asc" ? .forward : .reverse)
        default:  // "created_at"
            sortDescriptor = SortDescriptor(
                \SDAIInsight.createdAt, order: sortOrder == "asc" ? .forward : .reverse)
        }

        // Fetch with pagination
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: combinedPredicate,
            sortBy: [sortDescriptor]
        )

        let allResults = try modelContext.fetch(descriptor)

        // Get total count
        let total = allResults.count

        // Apply pagination
        let startIndex = min(offset, total)
        let endIndex = min(startIndex + limit, total)
        let paginatedResults = Array(allResults[startIndex..<endIndex])

        let insights = paginatedResults.map(toDomain)

        return InsightListResult(
            insights: insights,
            total: total,
            limit: limit,
            offset: offset
        )
    }

    // MARK: - Simple Fetch Operations

    func fetchAll() async throws -> [AIInsight] {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        print("📥 [AIInsightRepository] Fetching all insights for user: \(userId)")

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\SDAIInsight.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        print("   Found \(results.count) insights in SwiftData")

        return results.map(toDomain)
    }

    func fetchByType(_ type: InsightType) async throws -> [AIInsight] {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let typeString = type.rawValue

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { insight in
                insight.userId == userId && insight.insightType == typeString
            },
            sortBy: [SortDescriptor(\SDAIInsight.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchUnread() async throws -> [AIInsight] {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { insight in
                insight.userId == userId && !insight.isRead && !insight.isArchived
            },
            sortBy: [SortDescriptor(\SDAIInsight.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchFavorites() async throws -> [AIInsight] {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { insight in
                insight.userId == userId && insight.isFavorite
            },
            sortBy: [SortDescriptor(\SDAIInsight.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchArchived() async throws -> [AIInsight] {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { insight in
                insight.userId == userId && insight.isArchived
            },
            sortBy: [SortDescriptor(\SDAIInsight.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchRecent(days: Int) async throws -> [AIInsight] {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { insight in
                insight.userId == userId
                    && insight.createdAt >= cutoffDate
                    && !insight.isArchived
            },
            sortBy: [SortDescriptor(\SDAIInsight.createdAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchById(_ id: UUID) async throws -> AIInsight? {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return toDomain(sdInsight)
    }

    // MARK: - Save & Update

    func save(_ insight: AIInsight) async throws -> AIInsight {
        print("💾 [AIInsightRepository] Saving insight: \(insight.id)")
        print("   Type: \(insight.insightType.rawValue), Title: \(insight.title)")

        // Check if insight already exists
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == insight.id }
        )
        let existing = try modelContext.fetch(descriptor).first

        let sdInsight: SDAIInsight
        if let existing = existing {
            // Update existing
            print("   ↻ Updating existing insight")
            sdInsight = existing
            updateSDInsight(sdInsight, from: insight)
        } else {
            // Create new
            print("   ✨ Creating new insight")
            sdInsight = toSwiftData(insight)
            modelContext.insert(sdInsight)
        }

        try modelContext.save()
        print("   ✅ Insight saved to SwiftData")

        return toDomain(sdInsight)
    }

    func update(_ insight: AIInsight) async throws -> AIInsight {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == insight.id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            throw AIInsightRepositoryError.notFound
        }

        updateSDInsight(sdInsight, from: insight)
        try modelContext.save()

        return toDomain(sdInsight)
    }

    // MARK: - State Updates

    func markAsRead(id: UUID) async throws -> AIInsight {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            throw AIInsightRepositoryError.notFound
        }

        sdInsight.isRead = true
        sdInsight.updatedAt = Date()

        try modelContext.save()

        return toDomain(sdInsight)
    }

    func toggleFavorite(id: UUID) async throws -> AIInsight {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            throw AIInsightRepositoryError.notFound
        }

        sdInsight.isFavorite.toggle()
        sdInsight.updatedAt = Date()

        try modelContext.save()

        return toDomain(sdInsight)
    }

    func archive(id: UUID) async throws -> AIInsight {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            throw AIInsightRepositoryError.notFound
        }

        sdInsight.isArchived = true
        sdInsight.updatedAt = Date()

        try modelContext.save()

        return toDomain(sdInsight)
    }

    func unarchive(id: UUID) async throws -> AIInsight {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            throw AIInsightRepositoryError.notFound
        }

        sdInsight.isArchived = false
        sdInsight.updatedAt = Date()

        try modelContext.save()

        return toDomain(sdInsight)
    }

    // MARK: - Delete

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdInsight = try modelContext.fetch(descriptor).first else {
            throw AIInsightRepositoryError.notFound
        }

        modelContext.delete(sdInsight)
        try modelContext.save()
    }

    // MARK: - Statistics

    func count() async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { $0.userId == userId }
        )

        return try modelContext.fetchCount(descriptor)
    }

    func countUnread() async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw AIInsightRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDAIInsight>(
            predicate: #Predicate { insight in
                insight.userId == userId && !insight.isRead && !insight.isArchived
            }
        )

        return try modelContext.fetchCount(descriptor)
    }
}

// MARK: - Domain <-> SwiftData Mapping

extension AIInsightRepository {
    /// Convert domain AIInsight to SwiftData SDAIInsight
    private func toSwiftData(_ insight: AIInsight) -> SDAIInsight {
        print("   🔄 Converting domain insight to SwiftData")
        var metricsData: Data? = nil
        if let metrics = insight.metrics {
            metricsData = try? JSONEncoder().encode(metrics)
        }

        return SDAIInsight(
            id: insight.id,
            userId: insight.userId,
            insightType: insight.insightType.rawValue,
            title: insight.title,
            content: insight.content,
            summary: insight.summary,
            periodStart: insight.periodStart,
            periodEnd: insight.periodEnd,
            metricsData: metricsData,
            suggestions: insight.suggestions ?? [],
            isRead: insight.isRead,
            isFavorite: insight.isFavorite,
            isArchived: insight.isArchived,
            createdAt: insight.createdAt,
            updatedAt: insight.updatedAt
        )
    }

    /// Convert SwiftData SDAIInsight to domain AIInsight
    private func toDomain(_ sdInsight: SDAIInsight) -> AIInsight {
        var metrics: InsightMetrics? = nil
        if let metricsData = sdInsight.metricsData {
            metrics = try? JSONDecoder().decode(InsightMetrics.self, from: metricsData)
        }

        return AIInsight(
            id: sdInsight.id,
            userId: sdInsight.userId,
            insightType: InsightType(rawValue: sdInsight.insightType) ?? .daily,
            title: sdInsight.title,
            content: sdInsight.content,
            summary: sdInsight.summary,
            periodStart: sdInsight.periodStart,
            periodEnd: sdInsight.periodEnd,
            metrics: metrics,
            suggestions: sdInsight.suggestions.isEmpty ? nil : sdInsight.suggestions,
            isRead: sdInsight.isRead,
            isFavorite: sdInsight.isFavorite,
            isArchived: sdInsight.isArchived,
            createdAt: sdInsight.createdAt,
            updatedAt: sdInsight.updatedAt
        )
    }

    /// Update SwiftData model from domain model
    private func updateSDInsight(_ sdInsight: SDAIInsight, from insight: AIInsight) {
        sdInsight.insightType = insight.insightType.rawValue
        sdInsight.title = insight.title
        sdInsight.content = insight.content
        sdInsight.summary = insight.summary
        sdInsight.periodStart = insight.periodStart
        sdInsight.periodEnd = insight.periodEnd
        sdInsight.suggestions = insight.suggestions ?? []
        sdInsight.isRead = insight.isRead
        sdInsight.isFavorite = insight.isFavorite
        sdInsight.isArchived = insight.isArchived
        sdInsight.updatedAt = insight.updatedAt

        if let metrics = insight.metrics {
            sdInsight.metricsData = try? JSONEncoder().encode(metrics)
        } else {
            sdInsight.metricsData = nil
        }
    }

    // getCurrentUserId() is provided by UserAuthenticatedRepository protocol
}

// MARK: - Repository Errors

enum AIInsightRepositoryError: Error, LocalizedError {
    case notAuthenticated
    case notFound
    case validationFailed(String)
    case persistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated."
        case .notFound:
            return "Resource not found."
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .persistenceFailed(let error):
            return "Persistence failed: \(error.localizedDescription)"
        }
    }
}
