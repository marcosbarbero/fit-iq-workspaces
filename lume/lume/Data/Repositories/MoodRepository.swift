//
//  MoodRepository.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Refactored: 2025-01-15 - Aligned with valence/labels model
//

import FitIQCore
import Foundation
import SwiftData

/// Repository implementation for mood entries
/// Translates between domain and SwiftData models
final class MoodRepository: MoodRepositoryProtocol, UserAuthenticatedRepository {
    private let modelContext: ModelContext
    private let outboxRepository: OutboxRepositoryProtocol
    private let backendService: MoodBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol

    init(
        modelContext: ModelContext,
        outboxRepository: OutboxRepositoryProtocol,
        backendService: MoodBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.modelContext = modelContext
        self.outboxRepository = outboxRepository
        self.backendService = backendService
        self.tokenStorage = tokenStorage
    }

    func save(_ entry: MoodEntry) async throws {
        // Check if entry already exists (for updates)
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { existing in
                existing.id == entry.id
            }
        )
        let existing = try modelContext.fetch(descriptor).first

        // Determine if this is an update or create BEFORE modifying anything
        let isUpdate = existing != nil
        let hasBackendId = existing?.backendId != nil

        if let existing = existing {
            // Update existing entry
            existing.valence = entry.valence
            existing.labels = entry.labels
            existing.associations = entry.associations
            existing.notes = entry.notes
            existing.date = entry.date
            existing.source = entry.source.rawValue
            existing.sourceId = entry.sourceId
            existing.updatedAt = entry.updatedAt

            print(
                "✅ [MoodRepository] Updated mood locally: valence \(entry.valence), labels: \(entry.labels.joined(separator: ", ")) for \(entry.date.formatted(date: .abbreviated, time: .omitted)), backendId: \(existing.backendId ?? "none")"
            )
        } else {
            // Insert new entry
            let sdEntry = SDMoodEntry.fromDomain(entry, backendId: nil)
            modelContext.insert(sdEntry)

            print(
                "✅ [MoodRepository] Created mood locally: valence \(entry.valence), labels: \(entry.labels.joined(separator: ", ")) for \(entry.date.formatted(date: .abbreviated, time: .omitted))"
            )
        }

        try modelContext.save()

        // Create outbox event for backend sync (only if in production mode)
        if AppMode.useBackend {
            // Create metadata from entry
            let metadata = OutboxMetadata.moodEntry(
                valence: entry.valence,
                labels: entry.labels
            )

            // Create outbox event using new FitIQCore API
            _ = try await outboxRepository.createEvent(
                eventType: .moodEntry,
                entityID: entry.id,
                userID: entry.userId.uuidString,
                isNewRecord: !isUpdate,
                metadata: metadata,
                priority: 5
            )
            print(
                "📦 [MoodRepository] Created outbox event for mood: \(entry.id) (isUpdate: \(isUpdate), hasBackendId: \(hasBackendId))"
            )
        } else {
            print("🔵 [MoodRepository] Skipping outbox (AppMode: \(AppMode.current.displayName))")
        }
    }

    func fetchRecent(days: Int) async throws -> [MoodEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw MoodRepositoryError.notAuthenticated
        }

        let startDate =
            Calendar.current.date(
                byAdding: .day,
                value: -days,
                to: Date()
            ) ?? Date()

        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.date >= startDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.id == id
            }
        )

        let results = try modelContext.fetch(descriptor)
        guard let sdEntry = results.first else {
            throw MoodRepositoryError.notFound
        }

        // Store backendId and userId before deleting (needed for backend deletion)
        let backendId = sdEntry.backendId
        let userId = sdEntry.userId

        modelContext.delete(sdEntry)
        try modelContext.save()

        print("✅ [MoodRepository] Deleted mood entry locally: \(id)")

        // Create outbox event for backend sync (only if in production mode)
        if AppMode.useBackend {
            // Create metadata with generic data for delete
            let metadata = OutboxMetadata.generic([
                "operation": "delete",
                "backendId": backendId ?? "none",
            ])

            _ = try await outboxRepository.createEvent(
                eventType: .moodEntry,
                entityID: id,
                userID: userId.uuidString,
                isNewRecord: false,
                metadata: metadata,
                priority: 10  // Higher priority for deletes
            )
            print(
                "📦 [MoodRepository] Created outbox event for mood deletion: \(id), backendId: \(backendId ?? "none")"
            )
        } else {
            print("🔵 [MoodRepository] Skipping outbox (AppMode: \(AppMode.current.displayName))")
        }
    }

    func fetchById(id: UUID) async throws -> MoodEntry? {
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.id == id
            }
        )

        let results = try modelContext.fetch(descriptor)
        return results.first?.toDomain()
    }

    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [MoodEntry] {
        guard let userId = try? getCurrentUserId() else {
            throw MoodRepositoryError.notAuthenticated
        }

        print(
            "🔍 [MoodRepository] Fetching moods from \(startDate.formatted(date: .abbreviated, time: .shortened)) to \(endDate.formatted(date: .abbreviated, time: .shortened)) for user: \(userId)"
        )

        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.date >= startDate && entry.date <= endDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        print("📊 [MoodRepository] Found \(results.count) mood entries in date range")

        let domainEntries = results.map { $0.toDomain() }
        domainEntries.forEach { entry in
            print(
                "  - Mood: \(entry.primaryMoodDisplayName) at \(entry.date.formatted(date: .abbreviated, time: .shortened)), userId: \(entry.userId)"
            )
        }

        return domainEntries
    }

    // MARK: - Private Helpers

    // getCurrentUserId() is provided by UserAuthenticatedRepository protocol

    func fetchAnalytics(
        from: Date,
        to: Date,
        includeDailyBreakdown: Bool
    ) async throws -> MoodAnalytics {
        // Get access token
        guard let token = try await tokenStorage.getToken() else {
            throw MoodRepositoryError.notAuthenticated
        }

        // Fetch analytics from backend
        do {
            let analytics = try await backendService.fetchAnalytics(
                from: from,
                to: to,
                includeDailyBreakdown: includeDailyBreakdown,
                accessToken: token.accessToken
            )

            print(
                "✅ [MoodRepository] Fetched analytics: \(analytics.summary.totalEntries) entries, \(analytics.summary.consistencyPercentage)% consistency"
            )
            return analytics
        } catch {
            print("❌ [MoodRepository] Failed to fetch analytics: \(error)")
            throw error
        }
    }
}

// MARK: - Errors

enum MoodRepositoryError: LocalizedError {
    case notFound
    case notAuthenticated
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Mood entry not found"
        case .notAuthenticated:
            return "Not authenticated"
        case .saveFailed:
            return "Failed to save mood entry"
        }
    }
}

// MARK: - Outbox Payloads

private struct MoodPayload: Codable {
    let id: UUID
    let userId: UUID
    let valence: Double
    let labels: [String]
    let associations: [String]
    let notes: String?
    let date: Date
    let source: String
    let sourceId: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case valence
        case labels
        case associations
        case notes
        case date
        case source
        case sourceId = "source_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(entry: MoodEntry) {
        self.id = entry.id
        self.userId = entry.userId
        self.valence = entry.valence
        self.labels = entry.labels
        self.associations = entry.associations
        self.notes = entry.notes
        self.date = entry.date
        self.source = entry.source.rawValue
        self.sourceId = entry.sourceId
        self.createdAt = entry.createdAt
        self.updatedAt = entry.updatedAt
    }
}

private struct DeletePayload: Codable {
    let localId: UUID
    let backendId: String?

    enum CodingKeys: String, CodingKey {
        case localId = "local_id"
        case backendId = "backend_id"
    }

    init(localId: UUID, backendId: String?) {
        self.localId = localId
        self.backendId = backendId
    }
}

// MARK: - SwiftData Extensions

extension SDMoodEntry {
    /// Convert from domain model to SwiftData model
    static func fromDomain(_ entry: MoodEntry, backendId: String? = nil) -> SDMoodEntry {
        return SDMoodEntry(
            id: entry.id,
            userId: entry.userId,
            date: entry.date,
            valence: entry.valence,
            labels: entry.labels,
            associations: entry.associations,
            notes: entry.notes,
            source: entry.source.rawValue,
            sourceId: entry.sourceId,
            backendId: backendId,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    /// Convert from SwiftData model to domain model
    func toDomain() -> MoodEntry {
        return MoodEntry(
            id: self.id,
            userId: self.userId,
            date: self.date,
            valence: self.valence,
            labels: self.labels,
            associations: self.associations,
            notes: self.notes,
            source: MoodSource(rawValue: self.source) ?? .manual,
            sourceId: self.sourceId,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
