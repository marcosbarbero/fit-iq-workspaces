//
//  AIInsightBackendService.swift
//  lume
//
//  Created by AI Assistant on 30/01/2025.
//  Updated to match swagger-insights.yaml specification
//

import Foundation

// MARK: - Protocol Definition

protocol AIInsightBackendServiceProtocol {
    /// List insights with filtering, sorting, and pagination
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
    ///   - accessToken: User's access token
    /// - Returns: InsightsListResult with insights array and pagination info
    /// - Throws: HTTPError if request fails
    func listInsights(
        insightType: InsightType?,
        readStatus: Bool?,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        periodFrom: Date?,
        periodTo: Date?,
        limit: Int,
        offset: Int,
        sortBy: String,
        sortOrder: String,
        accessToken: String
    ) async throws -> InsightsListResult

    /// Get count of unread insights
    /// - Parameter accessToken: User's access token
    /// - Returns: Count of unread insights
    /// - Throws: HTTPError if request fails
    func countUnreadInsights(accessToken: String) async throws -> Int

    /// Mark an insight as read
    /// - Parameters:
    ///   - insightId: Insight ID (UUID)
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func markInsightAsRead(
        insightId: UUID,
        accessToken: String
    ) async throws

    /// Toggle favorite status of an insight
    /// - Parameters:
    ///   - insightId: Insight ID (UUID)
    ///   - accessToken: User's access token
    /// - Returns: New favorite status after toggle
    /// - Throws: HTTPError if request fails
    func toggleInsightFavorite(
        insightId: UUID,
        accessToken: String
    ) async throws -> Bool

    /// Archive an insight
    /// - Parameters:
    ///   - insightId: Insight ID (UUID)
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func archiveInsight(
        insightId: UUID,
        accessToken: String
    ) async throws

    /// Unarchive an insight
    /// - Parameters:
    ///   - insightId: Insight ID (UUID)
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func unarchiveInsight(
        insightId: UUID,
        accessToken: String
    ) async throws

    /// Delete an insight permanently
    /// - Parameters:
    ///   - insightId: Insight ID (UUID)
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func deleteInsight(
        insightId: UUID,
        accessToken: String
    ) async throws

    /// Generate a new wellness-specific insight
    /// Uses the `/api/v1/insights/generate/wellness` endpoint (recommended for wellness use cases)
    /// - Parameters:
    ///   - insightType: Type of insight to generate (daily, weekly, monthly, milestone, pattern)
    ///   - periodStart: Optional custom period start date (ISO 8601 with timezone). If omitted, backend calculates automatically.
    ///   - periodEnd: Optional custom period end date (ISO 8601 with timezone). If omitted, backend calculates automatically.
    ///   - accessToken: User's access token
    /// - Returns: Newly generated AIInsight with wellness-specific content
    /// - Throws: HTTPError if request fails
    func generateInsight(
        insightType: InsightType,
        periodStart: Date?,
        periodEnd: Date?,
        accessToken: String
    ) async throws -> AIInsight
}

// MARK: - Result Model

/// Result of listing insights with pagination
struct InsightsListResult {
    let insights: [AIInsight]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Service Implementation

final class AIInsightBackendService: AIInsightBackendServiceProtocol {

    // MARK: - Properties

    private let httpClient: HTTPClient

    // MARK: - Initialization

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    // MARK: - API Methods

    func listInsights(
        insightType: InsightType?,
        readStatus: Bool?,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        periodFrom: Date?,
        periodTo: Date?,
        limit: Int,
        offset: Int,
        sortBy: String,
        sortOrder: String,
        accessToken: String
    ) async throws -> InsightsListResult {
        // Build query parameters
        var queryParams: [String: String] = [
            "limit": String(limit),
            "offset": String(offset),
            "sort_by": sortBy,
            "sort_order": sortOrder,
        ]

        if let insightType = insightType {
            queryParams["insight_type"] = insightType.rawValue
        }

        if let readStatus = readStatus {
            queryParams["read_status"] = readStatus ? "true" : "false"
        }

        if favoritesOnly {
            queryParams["favorites_only"] = "true"
        }

        if let archivedStatus = archivedStatus {
            queryParams["archived_status"] = archivedStatus ? "true" : "false"
        }

        if let periodFrom = periodFrom {
            queryParams["period_from"] = ISO8601DateFormatter().string(from: periodFrom)
        }

        if let periodTo = periodTo {
            queryParams["period_to"] = ISO8601DateFormatter().string(from: periodTo)
        }

        let response: InsightsListResponse = try await httpClient.get(
            path: "/api/v1/insights",
            queryParams: queryParams,
            accessToken: accessToken
        )

        print(
            "✅ [AIInsightBackendService] Fetched \(response.data.insights.count) of \(response.data.total) insights"
        )

        return InsightsListResult(
            insights: response.data.insights.map { $0.toDomain() },
            total: response.data.total,
            limit: response.data.limit,
            offset: response.data.offset
        )
    }

    func countUnreadInsights(accessToken: String) async throws -> Int {
        let response: UnreadCountResponse = try await httpClient.get(
            path: "/api/v1/insights/unread/count",
            accessToken: accessToken
        )

        print("✅ [AIInsightBackendService] Unread count: \(response.data.count)")
        return response.data.count
    }

    func markInsightAsRead(
        insightId: UUID,
        accessToken: String
    ) async throws {
        let _: SuccessResponse = try await httpClient.post(
            path: "/api/v1/insights/\(insightId.uuidString)/read",
            accessToken: accessToken
        )

        print("✅ [AIInsightBackendService] Marked insight as read: \(insightId)")
    }

    func toggleInsightFavorite(
        insightId: UUID,
        accessToken: String
    ) async throws -> Bool {
        let response: FavoriteToggleResponse = try await httpClient.post(
            path: "/api/v1/insights/\(insightId.uuidString)/favorite",
            accessToken: accessToken
        )

        print(
            "✅ [AIInsightBackendService] Toggled favorite for insight: \(insightId), new status: \(response.data.isFavorite)"
        )
        return response.data.isFavorite
    }

    func archiveInsight(
        insightId: UUID,
        accessToken: String
    ) async throws {
        let _: SuccessResponse = try await httpClient.post(
            path: "/api/v1/insights/\(insightId.uuidString)/archive",
            accessToken: accessToken
        )

        print("✅ [AIInsightBackendService] Archived insight: \(insightId)")
    }

    func unarchiveInsight(
        insightId: UUID,
        accessToken: String
    ) async throws {
        let _: SuccessResponse = try await httpClient.post(
            path: "/api/v1/insights/\(insightId.uuidString)/unarchive",
            accessToken: accessToken
        )

        print("✅ [AIInsightBackendService] Unarchived insight: \(insightId)")
    }

    func deleteInsight(
        insightId: UUID,
        accessToken: String
    ) async throws {
        try await httpClient.delete(
            path: "/api/v1/insights/\(insightId.uuidString)",
            accessToken: accessToken
        )

        print("✅ [AIInsightBackendService] Deleted insight: \(insightId)")
    }

    func generateInsight(
        insightType: InsightType,
        periodStart: Date?,
        periodEnd: Date?,
        accessToken: String
    ) async throws -> AIInsight {
        // Build request body
        let requestBody = GenerateInsightRequest(
            insightType: insightType,
            periodStart: periodStart,
            periodEnd: periodEnd
        )

        print("🤖 [AIInsightBackendService] Generating \(insightType.rawValue) wellness insight")

        let response: GenerateInsightResponse = try await httpClient.post(
            path: "/api/v1/insights/generate/wellness",
            body: requestBody,
            accessToken: accessToken
        )

        print("✅ [AIInsightBackendService] Generated wellness insight: \(response.data.id)")

        return response.data.toDomain()
    }
}

// MARK: - Response Models (DTOs)

/// Response for listing insights
private struct InsightsListResponse: Decodable {
    let data: InsightsListData
}

private struct InsightsListData: Decodable {
    let insights: [InsightDTO]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case insights, total, limit, offset
        case hasMore = "has_more"
        case totalPages = "total_pages"
    }
}

/// Response for unread count
private struct UnreadCountResponse: Decodable {
    let success: Bool
    let data: UnreadCountData
    let error: String?
}

private struct UnreadCountData: Decodable {
    let count: Int
}

/// Response for favorite toggle
private struct FavoriteToggleResponse: Decodable {
    let success: Bool
    let data: FavoriteToggleData
    let error: String?
}

private struct FavoriteToggleData: Decodable {
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case isFavorite = "is_favorite"
    }
}

/// Generic success response
private struct SuccessResponse: Decodable {
    let success: Bool
    let data: SuccessData
    let error: String?
}

private struct SuccessData: Decodable {
    let message: String
}

/// Request for generate insight
private struct GenerateInsightRequest: Codable {
    let insightType: InsightType
    let periodStart: Date?
    let periodEnd: Date?

    enum CodingKeys: String, CodingKey {
        case insightType = "insight_type"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

/// Response for generate insight
private struct GenerateInsightResponse: Decodable {
    let data: InsightDTO
}

/// Insight DTO matching swagger spec
private struct InsightDTO: Decodable {
    let id: String
    let userId: String
    let insightType: String
    let title: String
    let content: String
    let summary: String?
    let periodStart: String?
    let periodEnd: String?
    let metrics: InsightMetricsDTO?
    let suggestions: [String]?
    let isRead: Bool
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case insightType = "insight_type"
        case title
        case content
        case summary
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case metrics
        case suggestions
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toDomain() -> AIInsight {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return AIInsight(
            id: UUID(uuidString: id) ?? UUID(),
            userId: UUID(uuidString: userId) ?? UUID(),
            insightType: InsightType(rawValue: insightType) ?? .daily,
            title: title,
            content: content,
            summary: summary,
            periodStart: periodStart.flatMap { iso8601Formatter.date(from: $0) },
            periodEnd: periodEnd.flatMap { iso8601Formatter.date(from: $0) },
            metrics: metrics?.toDomain(),
            suggestions: suggestions,
            isRead: isRead,
            isFavorite: isFavorite,
            isArchived: isArchived,
            createdAt: iso8601Formatter.date(from: createdAt) ?? Date(),
            updatedAt: iso8601Formatter.date(from: updatedAt) ?? Date()
        )
    }
}

/// Metrics DTO matching swagger spec
private struct InsightMetricsDTO: Decodable {
    let moodEntriesCount: Int?
    let journalEntriesCount: Int?
    let goalsActive: Int?
    let goalsCompleted: Int?

    enum CodingKeys: String, CodingKey {
        case moodEntriesCount = "mood_entries_count"
        case journalEntriesCount = "journal_entries_count"
        case goalsActive = "goals_active"
        case goalsCompleted = "goals_completed"
    }

    func toDomain() -> InsightMetrics {
        InsightMetrics(
            moodEntriesCount: moodEntriesCount,
            journalEntriesCount: journalEntriesCount,
            goalsActive: goalsActive,
            goalsCompleted: goalsCompleted
        )
    }
}

// MARK: - In-Memory Mock Service (for testing)

final class InMemoryAIInsightBackendService: AIInsightBackendServiceProtocol {

    func generateInsight(
        insightType: InsightType,
        periodStart: Date?,
        periodEnd: Date?,
        accessToken: String
    ) async throws -> AIInsight {
        // Mock implementation - generate a sample insight
        let insight = AIInsight(
            id: UUID(),
            userId: UUID(),
            insightType: insightType,
            title: "Mock \(insightType.displayName) Insight",
            content:
                "This is a mock insight generated for testing purposes. In production, this would contain AI-generated wellness insights based on your mood, journal entries, and goals.",
            summary: "Mock insight for \(insightType.rawValue) type",
            periodStart: periodStart ?? Date(),
            periodEnd: periodEnd ?? Date(),
            metrics: nil,
            suggestions: ["Mock suggestion 1", "Mock suggestion 2"],
            isRead: false,
            isFavorite: false,
            isArchived: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        return insight
    }

    var shouldFail = false
    var mockInsights: [AIInsight] = []
    var mockUnreadCount = 0

    func listInsights(
        insightType: InsightType?,
        readStatus: Bool?,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        periodFrom: Date?,
        periodTo: Date?,
        limit: Int,
        offset: Int,
        sortBy: String,
        sortOrder: String,
        accessToken: String
    ) async throws -> InsightsListResult {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        var filtered = mockInsights

        if let insightType = insightType {
            filtered = filtered.filter { $0.insightType == insightType }
        }

        if let readStatus = readStatus {
            filtered = filtered.filter { $0.isRead == readStatus }
        }

        if favoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }

        if let archivedStatus = archivedStatus {
            filtered = filtered.filter { $0.isArchived == archivedStatus }
        } else {
            // Default: show only non-archived
            filtered = filtered.filter { !$0.isArchived }
        }

        if let periodFrom = periodFrom {
            filtered = filtered.filter { insight in
                guard let start = insight.periodStart else { return false }
                return start >= periodFrom
            }
        }

        if let periodTo = periodTo {
            filtered = filtered.filter { insight in
                guard let end = insight.periodEnd else { return false }
                return end <= periodTo
            }
        }

        // Sort
        if sortBy == "created_at" {
            filtered.sort {
                sortOrder == "asc" ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt
            }
        } else if sortBy == "updated_at" {
            filtered.sort {
                sortOrder == "asc" ? $0.updatedAt < $1.updatedAt : $0.updatedAt > $1.updatedAt
            }
        }

        let total = filtered.count
        let paginated = Array(filtered.dropFirst(offset).prefix(limit))

        return InsightsListResult(
            insights: paginated,
            total: total,
            limit: limit,
            offset: offset
        )
    }

    func countUnreadInsights(accessToken: String) async throws -> Int {
        if shouldFail {
            throw HTTPError.serverError(500)
        }
        return mockUnreadCount
    }

    func markInsightAsRead(insightId: UUID, accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        if let index = mockInsights.firstIndex(where: { $0.id == insightId }) {
            mockInsights[index].isRead = true
            if mockUnreadCount > 0 {
                mockUnreadCount -= 1
            }
        }
    }

    func toggleInsightFavorite(insightId: UUID, accessToken: String) async throws -> Bool {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        if let index = mockInsights.firstIndex(where: { $0.id == insightId }) {
            mockInsights[index].isFavorite.toggle()
            return mockInsights[index].isFavorite
        }
        return false
    }

    func archiveInsight(insightId: UUID, accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        if let index = mockInsights.firstIndex(where: { $0.id == insightId }) {
            mockInsights[index].isArchived = true
        }
    }

    func unarchiveInsight(insightId: UUID, accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        if let index = mockInsights.firstIndex(where: { $0.id == insightId }) {
            mockInsights[index].isArchived = false
        }
    }

    func deleteInsight(insightId: UUID, accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        mockInsights.removeAll { $0.id == insightId }
    }
}
