//
//  JournalMoodCoordinator.swift
//  lume
//
//  Created by Lume Team on 2025-01-15.
//

import Foundation

/// Coordinates between Journal and Mood features
/// Enables bidirectional linking and navigation
final class JournalMoodCoordinator: JournalMoodCoordinatorProtocol {

    // MARK: - Properties

    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol

    // MARK: - Initialization

    init(
        moodRepository: MoodRepositoryProtocol,
        journalRepository: JournalRepositoryProtocol
    ) {
        self.moodRepository = moodRepository
        self.journalRepository = journalRepository
    }

    // MARK: - JournalMoodCoordinatorProtocol

    func getMoodEntry(id: UUID) async -> MoodEntry? {
        do {
            return try await moodRepository.fetchById(id: id)
        } catch {
            print("❌ [JournalMoodCoordinator] Failed to fetch mood entry: \(error)")
            return nil
        }
    }

    func getRecentMoods(days: Int = 7) async -> [MoodEntry] {
        do {
            let startDate =
                Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let endDate = Date()
            return try await moodRepository.fetchByDateRange(startDate: startDate, endDate: endDate)
        } catch {
            print("❌ [JournalMoodCoordinator] Failed to fetch recent moods: \(error)")
            return []
        }
    }

    func getJournalEntries(linkedToMood moodId: UUID) async -> [JournalEntry] {
        do {
            return try await journalRepository.fetchLinkedToMood(moodId)
        } catch {
            print("❌ [JournalMoodCoordinator] Failed to fetch linked journal entries: \(error)")
            return []
        }
    }

    func getMoodForJournal(journalId: UUID) async -> MoodEntry? {
        do {
            // First get the journal entry to find its linked mood ID
            guard let entry = try await journalRepository.fetchById(journalId),
                let linkedMoodId = entry.linkedMoodId
            else {
                return nil
            }

            // Then fetch the mood entry
            return try await moodRepository.fetchById(id: linkedMoodId)
        } catch {
            print("❌ [JournalMoodCoordinator] Failed to fetch mood for journal: \(error)")
            return nil
        }
    }
}
