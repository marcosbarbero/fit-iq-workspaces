//
//  SwiftDataJournalRepository.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of JournalRepositoryProtocol
/// Handles local persistence and prepares entries for backend sync via outbox pattern
final class SwiftDataJournalRepository: JournalRepositoryProtocol, UserAuthenticatedRepository {
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol

    init(modelContext: ModelContext, outboxRepository: OutboxRepositoryProtocol) {
        self.modelContext = modelContext
        self.outboxRepository = outboxRepository
    }

    // MARK: - Create

    func create(text: String, date: Date) async throws -> JournalEntry {
        // Get current user ID from auth (simplified for now)
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let entry = JournalEntry(
            userId: userId,
            date: date,
            content: text
        )

        return try await save(entry)
    }

    func save(_ entry: JournalEntry) async throws -> JournalEntry {
        // Validate entry
        guard entry.isValid else {
            throw RepositoryError.validationFailed(entry.validationErrors.joined(separator: ", "))
        }

        // Check if entry exists
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.id == entry.id }
        )
        let existing = try modelContext.fetch(descriptor).first

        let sdEntry: SDJournalEntry
        if let existing = existing {
            // Update existing
            sdEntry = existing
            updateSDEntry(sdEntry, from: entry)
        } else {
            // Create new
            sdEntry = toSwiftData(entry)
            modelContext.insert(sdEntry)
        }

        sdEntry.updatedAt = Date()

        // Save to SwiftData
        try modelContext.save()

        // Create outbox event for backend sync
        try await createOutboxEvent(for: entry, action: existing != nil ? "update" : "create")

        return toDomain(sdEntry)
    }

    // MARK: - Read

    func fetch(from: Date, to: Date) async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.date >= from && entry.date <= to
            },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchAll() async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchById(_ id: UUID) async throws -> JournalEntry? {
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.id == id }
        )

        guard let result = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return toDomain(result)
    }

    func fetchByDate(_ date: Date) async throws -> JournalEntry? {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.date >= startOfDay && entry.date < endOfDay
            },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        guard let result = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return toDomain(result)
    }

    func fetchRecent(limit: Int = 20) async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        var descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchFavorites() async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.isFavorite
            },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchByTag(_ tag: String) async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let lowercaseTag = tag.lowercased()
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId
            },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return
            results
            .filter { $0.tags.contains(lowercaseTag) }
            .map(toDomain)
    }

    func fetchByEntryType(_ entryType: EntryType) async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.entryType == entryType.rawValue
            },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    func fetchLinkedToMood(_ moodId: UUID) async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.linkedMoodId == moodId
            },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomain)
    }

    // MARK: - Search

    func search(_ searchText: String) async throws -> [JournalEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let lowercaseSearch = searchText.lowercased()

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\SDJournalEntry.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        // Filter in memory for now (could optimize with FTS later)
        return
            results
            .filter { entry in
                (entry.title?.lowercased().contains(lowercaseSearch) ?? false)
                    || entry.content.lowercased().contains(lowercaseSearch)
                    || entry.tags.contains { $0.lowercased().contains(lowercaseSearch) }
            }
            .map(toDomain)
    }

    // MARK: - Update

    func update(_ entry: JournalEntry) async throws -> JournalEntry {
        return try await save(entry)
    }

    // MARK: - Delete

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entry = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        modelContext.delete(entry)
        try modelContext.save()

        // Create outbox event for backend deletion
        // For delete, we need to pass the backendId if available
        struct DeletePayload: Codable {
            let localId: UUID
            let backendId: String?

            enum CodingKeys: String, CodingKey {
                case localId = "local_id"
                case backendId = "backend_id"
            }
        }

        let encoder = JSONEncoder()
        let deletePayload = try encoder.encode(
            DeletePayload(
                localId: entry.id,
                backendId: entry.backendId
            )
        )

        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let metadata = OutboxMetadata.generic([
            "operation": "delete",
            "backendId": entry.backendId ?? "none",
        ])

        try await outboxRepository.createEvent(
            eventType: .journalEntry,
            entityID: id,
            userID: userId.uuidString,
            isNewRecord: false,
            metadata: metadata,
            priority: 10
        )
    }

    func deleteAll() async throws {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.userId == userId }
        )

        let results = try modelContext.fetch(descriptor)
        for entry in results {
            modelContext.delete(entry)
        }

        try modelContext.save()
    }

    // MARK: - Statistics

    func count() async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.userId == userId }
        )

        return try modelContext.fetchCount(descriptor)
    }

    func totalWordCount() async throws -> Int {
        let entries = try await fetchAll()
        return entries.reduce(0) { $0 + $1.wordCount }
    }

    func currentStreak() async throws -> Int {
        let entries = try await fetchAll()
        guard !entries.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today

        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let entryDate = calendar.startOfDay(for: entry.date)

            if calendar.isDate(entryDate, inSameDayAs: currentDate) {
                streak += 1
                currentDate =
                    calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if entryDate < currentDate {
                break
            }
        }

        return streak
    }

    func getAllTags() async throws -> [String] {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.userId == userId }
        )

        let results = try modelContext.fetch(descriptor)
        let allTags = results.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    // MARK: - Backend Sync

    func fetchUnsyncedEntries() async throws -> [JournalEntry] {
        // Note: Sync state is now managed by Outbox pattern
        // This method is deprecated but kept for interface compatibility
        // Return empty array as Outbox handles sync tracking
        return []
    }

    func markAsSynced(_ id: UUID, backendId: String) async throws {
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entry = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        // Only update backendId - sync state managed by Outbox
        entry.backendId = backendId

        try modelContext.save()
    }

    // MARK: - Private Helpers

    private func toSwiftData(_ entry: JournalEntry) -> SDJournalEntry {
        return SDJournalEntry(
            id: entry.id,
            userId: entry.userId,
            date: entry.date,
            title: entry.title,
            content: entry.content,
            tags: entry.tags,
            entryType: entry.entryType.rawValue,
            isFavorite: entry.isFavorite,
            linkedMoodId: entry.linkedMoodId,
            backendId: entry.backendId,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    private func updateSDEntry(_ sdEntry: SDJournalEntry, from entry: JournalEntry) {
        sdEntry.date = entry.date
        sdEntry.title = entry.title
        sdEntry.content = entry.content
        sdEntry.tags = entry.tags
        sdEntry.entryType = entry.entryType.rawValue
        sdEntry.isFavorite = entry.isFavorite
        sdEntry.linkedMoodId = entry.linkedMoodId
        sdEntry.updatedAt = entry.updatedAt
    }

    private func toDomain(_ sdEntry: SDJournalEntry) -> JournalEntry {
        return JournalEntry(
            id: sdEntry.id,
            userId: sdEntry.userId,
            date: sdEntry.date,
            title: sdEntry.title,
            content: sdEntry.content,
            tags: sdEntry.tags,
            entryType: EntryType(rawValue: sdEntry.entryType) ?? .freeform,
            isFavorite: sdEntry.isFavorite,
            linkedMoodId: sdEntry.linkedMoodId,
            backendId: sdEntry.backendId,
            createdAt: sdEntry.createdAt,
            updatedAt: sdEntry.updatedAt
        )
    }

    private func createOutboxEvent(for entry: JournalEntry, action: String) async throws {
        guard let userId = try? getCurrentUserId() else {
            throw RepositoryError.notAuthenticated
        }

        // Determine if this is a new record
        let isNewRecord = action == "create"

        // Calculate word count for metadata
        let wordCount = entry.content.split(separator: " ").count

        // Create metadata
        let metadata = OutboxMetadata.journalEntry(
            wordCount: wordCount,
            linkedMoodID: entry.linkedMoodId
        )

        try await outboxRepository.createEvent(
            eventType: .journalEntry,
            entityID: entry.id,
            userID: userId.uuidString,
            isNewRecord: isNewRecord,
            metadata: metadata,
            priority: 5
        )
    }

    // getCurrentUserId() is provided by UserAuthenticatedRepository protocol
}

// MARK: - Repository Error

enum RepositoryError: Error, LocalizedError {
    case notFound
    case notAuthenticated
    case validationFailed(String)
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Entry not found"
        case .notAuthenticated:
            return "User not authenticated"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        }
    }
}
