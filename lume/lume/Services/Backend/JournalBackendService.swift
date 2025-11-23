//
//  JournalBackendService.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation

/// Backend service for journal data synchronization
/// Handles communication with journal API endpoints
protocol JournalBackendServiceProtocol {
    func createJournalEntry(_ entry: JournalEntry, accessToken: String) async throws -> String
    func updateJournalEntry(_ entry: JournalEntry, backendId: String, accessToken: String)
        async throws
    func deleteJournalEntry(backendId: String, accessToken: String) async throws
    func fetchAllJournalEntries(accessToken: String) async throws -> [JournalEntry]
    func searchJournalEntries(query: String, accessToken: String) async throws -> [JournalEntry]
}

final class JournalBackendService: JournalBackendServiceProtocol {

    // MARK: - Properties

    private let httpClient: HTTPClient

    // MARK: - Initialization

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    // MARK: - API Methods

    func createJournalEntry(_ entry: JournalEntry, accessToken: String) async throws -> String {
        let request = CreateJournalEntryRequest(entry: entry)

        let response: CreateJournalEntryResponse = try await httpClient.post(
            path: "/api/v1/journal",
            body: request,
            accessToken: accessToken
        )

        print(
            "✅ [JournalBackendService] Successfully synced journal entry: \(entry.id), backend ID: \(response.data.id)"
        )
        return response.data.id
    }

    func updateJournalEntry(_ entry: JournalEntry, backendId: String, accessToken: String)
        async throws
    {
        let request = UpdateJournalEntryRequest(entry: entry)

        let _: UpdateJournalEntryResponse = try await httpClient.put(
            path: "/api/v1/journal/\(backendId)",
            body: request,
            accessToken: accessToken
        )

        print(
            "✅ [JournalBackendService] Successfully updated journal entry: \(entry.id), backend ID: \(backendId)"
        )
    }

    func deleteJournalEntry(backendId: String, accessToken: String) async throws {
        try await httpClient.delete(
            path: "/api/v1/journal/\(backendId)",
            accessToken: accessToken
        )

        print(
            "✅ [JournalBackendService] Successfully deleted journal entry with backend ID: \(backendId)"
        )
    }

    func fetchAllJournalEntries(accessToken: String) async throws -> [JournalEntry] {
        let response: FetchJournalEntriesResponse = try await httpClient.get(
            path: "/api/v1/journal",
            accessToken: accessToken
        )

        let entries = response.data.entries.map { dto in
            JournalEntry(
                id: UUID(uuidString: dto.id) ?? UUID(),
                userId: UUID(uuidString: dto.user_id) ?? UUID(),
                date: dto.logged_at,
                title: dto.title,
                content: dto.content,
                tags: dto.tags,
                entryType: EntryType(rawValue: dto.entry_type) ?? .freeform,
                isFavorite: dto.is_favorite,
                linkedMoodId: dto.linked_mood_id != nil
                    ? UUID(uuidString: dto.linked_mood_id!) : nil,
                createdAt: dto.created_at,
                updatedAt: dto.updated_at
            )
        }

        print("✅ [JournalBackendService] Fetched \(entries.count) journal entries from backend")
        return entries
    }

    func searchJournalEntries(query: String, accessToken: String) async throws -> [JournalEntry] {
        let queryParams: [String: String] = ["q": query]

        let response: SearchJournalEntriesResponse = try await httpClient.get(
            path: "/api/v1/journal/search",
            queryParams: queryParams,
            accessToken: accessToken
        )

        let entries = response.data.results.map { dto in
            JournalEntry(
                id: UUID(uuidString: dto.id) ?? UUID(),
                userId: UUID(uuidString: dto.user_id) ?? UUID(),
                date: dto.logged_at,
                title: dto.title,
                content: dto.content,
                tags: dto.tags,
                entryType: EntryType(rawValue: dto.entry_type) ?? .freeform,
                isFavorite: dto.is_favorite,
                linkedMoodId: dto.linked_mood_id != nil
                    ? UUID(uuidString: dto.linked_mood_id!) : nil,
                createdAt: dto.created_at,
                updatedAt: dto.updated_at
            )
        }

        print(
            "✅ [JournalBackendService] Found \(entries.count) journal entries matching query: '\(query)'"
        )
        return entries
    }
}

// MARK: - Request/Response Models

/// Request body for creating a journal entry
private struct CreateJournalEntryRequest: Encodable {
    let title: String?
    let content: String
    let content_format: String
    let entry_type: String
    let tags: [String]
    let privacy_level: String
    let linked_mood_id: String?
    let logged_at: String
    let is_favorite: Bool

    init(entry: JournalEntry) {
        self.title = entry.title
        self.content = entry.content
        self.content_format = "plain"
        self.entry_type = entry.entryType.rawValue
        self.tags = entry.tags
        self.privacy_level = "private"
        self.linked_mood_id = entry.linkedMoodId?.uuidString

        // Format date as RFC3339
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.logged_at = formatter.string(from: entry.date)

        self.is_favorite = entry.isFavorite
    }
}

/// Request body for updating a journal entry
private struct UpdateJournalEntryRequest: Encodable {
    let title: String?
    let content: String
    let content_format: String
    let entry_type: String
    let tags: [String]
    let privacy_level: String
    let linked_mood_id: String?
    let logged_at: String
    let is_favorite: Bool

    init(entry: JournalEntry) {
        self.title = entry.title
        self.content = entry.content
        self.content_format = "plain"
        self.entry_type = entry.entryType.rawValue
        self.tags = entry.tags
        self.privacy_level = "private"
        self.linked_mood_id = entry.linkedMoodId?.uuidString

        // Format date as RFC3339
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.logged_at = formatter.string(from: entry.date)

        self.is_favorite = entry.isFavorite
    }
}

/// Response from creating a journal entry
private struct CreateJournalEntryResponse: Decodable {
    let data: JournalEntryDTO
}

/// Response from updating a journal entry
private struct UpdateJournalEntryResponse: Decodable {
    let data: JournalEntryDTO
}

/// Response from fetching journal entries
private struct FetchJournalEntriesResponse: Decodable {
    let data: JournalListData
}

/// Response from searching journal entries
private struct SearchJournalEntriesResponse: Decodable {
    let data: JournalSearchData
}

/// List of journal entries with pagination metadata
private struct JournalListData: Decodable {
    let entries: [JournalEntryDTO]
    let total: Int
    let limit: Int
    let offset: Int
    let has_more: Bool
}

/// Search results with pagination metadata
private struct JournalSearchData: Decodable {
    let results: [JournalEntryDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

/// Individual journal entry from backend
private struct JournalEntryDTO: Decodable {
    let id: String
    let user_id: String
    let title: String?
    let content: String
    let content_format: String
    let entry_type: String
    let tags: [String]
    let privacy_level: String
    let prompt_id: String?
    let linked_mood_id: String?
    let linked_goal_id: String?
    let is_favorite: Bool
    let logged_at: Date
    let created_at: Date
    let updated_at: Date
}

// MARK: - Mock Implementation

final class InMemoryJournalBackendService: JournalBackendServiceProtocol {

    var shouldFail = false
    var createJournalEntryCalled = false
    var deleteJournalEntryCalled = false

    func createJournalEntry(_ entry: JournalEntry, accessToken: String) async throws -> String {
        createJournalEntryCalled = true

        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Return mock backend ID
        let backendId = UUID().uuidString
        print(
            "🔵 [InMemoryJournalBackendService] Simulated journal entry creation for: \(entry.id), backend ID: \(backendId)"
        )
        return backendId
    }

    func updateJournalEntry(_ entry: JournalEntry, backendId: String, accessToken: String)
        async throws
    {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        print(
            "🔵 [InMemoryJournalBackendService] Simulated journal entry update for: \(entry.id), backend ID: \(backendId)"
        )
    }

    func deleteJournalEntry(backendId: String, accessToken: String) async throws {
        deleteJournalEntryCalled = true

        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        print(
            "🔵 [InMemoryJournalBackendService] Simulated journal entry deletion for backend ID: \(backendId)"
        )
    }

    func fetchAllJournalEntries(accessToken: String) async throws -> [JournalEntry] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        print(
            "🔵 [InMemoryJournalBackendService] Simulated fetching all journal entries (returning empty array)"
        )
        return []
    }

    func searchJournalEntries(query: String, accessToken: String) async throws -> [JournalEntry] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)

        print(
            "🔵 [InMemoryJournalBackendService] Simulated searching journal entries with query: '\(query)' (returning empty array)"
        )
        return []
    }
}
