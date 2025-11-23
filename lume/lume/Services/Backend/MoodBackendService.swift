//
//  MoodBackendService.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Updated: 2025-01-15 - Simplified now that domain model matches backend API
//

import Foundation

/// Backend service for mood data synchronization
/// Handles communication with mood API endpoints
protocol MoodBackendServiceProtocol {
    func createMood(_ entry: MoodEntry, accessToken: String) async throws -> String
    func updateMood(_ entry: MoodEntry, backendId: String, accessToken: String) async throws
    func deleteMood(backendId: String, accessToken: String) async throws
    func fetchAllMoods(accessToken: String) async throws -> [MoodEntry]
    func fetchAnalytics(from: Date, to: Date, includeDailyBreakdown: Bool, accessToken: String)
        async throws -> MoodAnalytics
}

final class MoodBackendService: MoodBackendServiceProtocol {

    // MARK: - Properties

    private let httpClient: HTTPClient

    // MARK: - Initialization

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    // MARK: - API Methods

    func createMood(_ entry: MoodEntry, accessToken: String) async throws -> String {
        let request = CreateMoodRequest(entry: entry)

        let response: CreateMoodResponse = try await httpClient.post(
            path: "/api/v1/wellness/mood-entries",
            body: request,
            accessToken: accessToken
        )

        print(
            "✅ [MoodBackendService] Successfully synced mood entry: \(entry.id), backend ID: \(response.data.id)"
        )
        return response.data.id
    }

    func updateMood(_ entry: MoodEntry, backendId: String, accessToken: String) async throws {
        let request = UpdateMoodRequest(entry: entry)

        let _: UpdateMoodResponse = try await httpClient.put(
            path: "/api/v1/wellness/mood-entries/\(backendId)",
            body: request,
            accessToken: accessToken
        )

        print(
            "✅ [MoodBackendService] Successfully updated mood entry: \(entry.id), backend ID: \(backendId)"
        )
    }

    func deleteMood(backendId: String, accessToken: String) async throws {
        try await httpClient.delete(
            path: "/api/v1/wellness/mood-entries/\(backendId)",
            accessToken: accessToken
        )

        print(
            "✅ [MoodBackendService] Successfully deleted mood entry with backend ID: \(backendId)")
    }

    func fetchAllMoods(accessToken: String) async throws -> [MoodEntry] {
        let response: FetchMoodsResponse = try await httpClient.get(
            path: "/api/v1/wellness/mood-entries",
            accessToken: accessToken
        )

        let entries = response.data.entries.map { dto in
            MoodEntry(
                id: UUID(uuidString: dto.id) ?? UUID(),  // Use backend ID as local ID
                userId: UUID(uuidString: dto.user_id) ?? UUID(),
                date: dto.logged_at,
                valence: dto.valence,
                labels: dto.labels,
                associations: dto.associations,
                notes: dto.notes,
                source: MoodSource(rawValue: dto.source) ?? .manual,
                sourceId: dto.id,  // Store backend ID in sourceId for sync service
                createdAt: dto.created_at,
                updatedAt: dto.updated_at
            )
        }

        print("✅ [MoodBackendService] Fetched \(entries.count) mood entries from backend")
        return entries
    }

    func fetchAnalytics(
        from: Date,
        to: Date,
        includeDailyBreakdown: Bool,
        accessToken: String
    ) async throws -> MoodAnalytics {
        // Format dates as YYYY-MM-DD
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        let fromString = formatter.string(from: from)
        let toString = formatter.string(from: to)

        // Build query parameters
        let queryParams: [String: String] = [
            "from": fromString,
            "to": toString,
            "include_daily_breakdown": includeDailyBreakdown ? "true" : "false",
        ]

        // Fetch analytics from backend
        let response: AnalyticsResponse = try await httpClient.get(
            path: "/api/v1/wellness/mood-entries/analytics",
            queryParams: queryParams,
            accessToken: accessToken
        )

        print("✅ [MoodBackendService] Fetched analytics for period \(fromString) to \(toString)")
        return response.data
    }
}

// MARK: - Request/Response Models

/// Request body for creating a mood entry
private struct CreateMoodRequest: Encodable {
    let valence: Double
    let labels: [String]
    let associations: [String]
    let notes: String?
    let logged_at: String
    let source: String

    init(entry: MoodEntry) {
        self.valence = entry.valence
        self.labels = entry.labels
        self.associations = entry.associations
        self.notes = entry.notes

        // Format date as RFC3339
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.logged_at = formatter.string(from: entry.date)

        self.source = entry.source.rawValue
    }
}

/// Request body for updating a mood entry
private struct UpdateMoodRequest: Encodable {
    let valence: Double
    let labels: [String]
    let associations: [String]
    let notes: String?
    let logged_at: String
    let source: String

    init(entry: MoodEntry) {
        self.valence = entry.valence
        self.labels = entry.labels
        self.associations = entry.associations
        self.notes = entry.notes

        // Format date as RFC3339
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.logged_at = formatter.string(from: entry.date)

        self.source = entry.source.rawValue
    }
}

/// Response from creating a mood entry
private struct CreateMoodResponse: Decodable {
    let data: MoodLogResponse
}

/// Response from updating a mood entry
private struct UpdateMoodResponse: Decodable {
    let data: MoodLogResponse
}

/// Response from fetching mood entries
private struct FetchMoodsResponse: Decodable {
    let data: MoodListData
}

/// List of mood entries with pagination metadata
private struct MoodListData: Decodable {
    let entries: [MoodEntryDTO]
    let total: Int
    let limit: Int
    let offset: Int
    let has_more: Bool
}

/// Individual mood log entry from backend
private struct MoodLogResponse: Decodable {
    let id: String
    let user_id: String
    let valence: Double
    let labels: [String]
    let associations: [String]
    let notes: String?
    let logged_at: Date
    let source: String
    let source_id: String?
    let is_healthkit: Bool
    let created_at: Date
    let updated_at: Date
}

/// DTO for mood entry from backend API
private struct MoodEntryDTO: Decodable {
    let id: String
    let user_id: String
    let valence: Double
    let labels: [String]
    let associations: [String]
    let notes: String?
    let logged_at: Date
    let source: String
    let source_id: String?
    let is_healthkit: Bool
    let created_at: Date
    let updated_at: Date
}

// MARK: - Mock Implementation

final class InMemoryMoodBackendService: MoodBackendServiceProtocol {

    var shouldFail = false
    var createMoodCalled = false
    var deleteMoodCalled = false

    func createMood(_ entry: MoodEntry, accessToken: String) async throws -> String {
        createMoodCalled = true

        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Return mock backend ID
        let backendId = UUID().uuidString
        print(
            "🔵 [InMemoryMoodBackendService] Simulated mood creation for: \(entry.id), backend ID: \(backendId)"
        )
        return backendId
    }

    func updateMood(_ entry: MoodEntry, backendId: String, accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        print(
            "🔵 [InMemoryMoodBackendService] Simulated mood update for: \(entry.id), backend ID: \(backendId)"
        )
    }

    func fetchAllMoods(accessToken: String) async throws -> [MoodEntry] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        print("🔵 [InMemoryMoodBackendService] Simulated fetching all moods (returning empty array)")
        return []
    }

    func deleteMood(backendId: String, accessToken: String) async throws {
        deleteMoodCalled = true

        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        print("🔵 [InMemoryMoodBackendService] Simulated mood deletion for backend ID: \(backendId)")
    }

    func fetchAnalytics(
        from: Date,
        to: Date,
        includeDailyBreakdown: Bool,
        accessToken: String
    ) async throws -> MoodAnalytics {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        // Return mock analytics with empty data
        let analytics = MoodAnalytics(
            period: AnalyticsPeriod(
                startDate: from,
                endDate: to,
                totalDays: Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
            ),
            summary: AnalyticsSummary(
                totalEntries: 0,
                averageValence: 0.0,
                daysWithEntries: 0,
                loggingConsistency: 0.0
            ),
            trends: AnalyticsTrends(
                trendDirection: .insufficientData,
                weeklyAverages: []
            ),
            topLabels: [],
            topAssociations: [],
            dailyAggregates: includeDailyBreakdown ? [] : nil
        )

        print("🔵 [InMemoryMoodBackendService] Simulated fetching analytics (returning empty data)")
        return analytics
    }
}
