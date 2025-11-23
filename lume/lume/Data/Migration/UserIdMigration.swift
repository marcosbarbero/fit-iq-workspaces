//
//  UserIdMigration.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Foundation
import SwiftData

/// Handles migration of existing data to authenticated user's ID
/// This is needed when a user creates data before authenticating,
/// then logs in and gets a real user ID from the backend
@MainActor
final class UserIdMigration {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods

    /// Migrate all entries to the currently authenticated user's ID
    /// This should be called once after successful authentication
    /// - Parameter newUserId: The authenticated user's ID from backend
    func migrateToAuthenticatedUser(newUserId: UUID) async throws {
        print("🔄 [UserIdMigration] Starting migration to user ID: \(newUserId)")

        // Check if migration is needed
        let needsMigration = try await checkIfMigrationNeeded(newUserId: newUserId)

        guard needsMigration else {
            print(
                "✅ [UserIdMigration] No migration needed - all data already belongs to authenticated user"
            )
            return
        }

        // Migrate mood entries
        let moodCount = try await migrateMoodEntries(to: newUserId)

        // Migrate journal entries
        let journalCount = try await migrateJournalEntries(to: newUserId)

        // Save all changes
        try modelContext.save()

        print(
            "✅ [UserIdMigration] Migration complete: \(moodCount) mood entries, \(journalCount) journal entries"
        )
    }

    // MARK: - Private Methods

    /// Check if there are any entries that don't belong to the current user
    private func checkIfMigrationNeeded(newUserId: UUID) async throws -> Bool {
        // Check mood entries
        let moodDescriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.userId != newUserId
            }
        )
        let moodResults = try modelContext.fetch(moodDescriptor)

        // Check journal entries
        let journalDescriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId != newUserId
            }
        )
        let journalResults = try modelContext.fetch(journalDescriptor)

        let needsMigration = !moodResults.isEmpty || !journalResults.isEmpty

        if needsMigration {
            print(
                "⚠️ [UserIdMigration] Found \(moodResults.count) mood entries and \(journalResults.count) journal entries to migrate"
            )
        }

        return needsMigration
    }

    /// Migrate all mood entries to the new user ID
    private func migrateMoodEntries(to newUserId: UUID) async throws -> Int {
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.userId != newUserId
            }
        )

        let entries = try modelContext.fetch(descriptor)

        for entry in entries {
            print(
                "🔄 [UserIdMigration] Migrating mood entry: \(entry.id) from userId: \(entry.userId)"
            )
            entry.userId = newUserId
        }

        return entries.count
    }

    /// Migrate all journal entries to the new user ID
    private func migrateJournalEntries(to newUserId: UUID) async throws -> Int {
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId != newUserId
            }
        )

        let entries = try modelContext.fetch(descriptor)

        for entry in entries {
            print(
                "🔄 [UserIdMigration] Migrating journal entry: \(entry.id) from userId: \(entry.userId)"
            )
            entry.userId = newUserId
        }

        return entries.count
    }
}

// MARK: - Migration Errors

enum UserIdMigrationError: LocalizedError {
    case noAuthenticatedUser
    case migrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "Cannot migrate data: no authenticated user found"
        case .migrationFailed(let error):
            return "Data migration failed: \(error.localizedDescription)"
        }
    }
}
