//
//  SaveMoodUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of HKStateOfMind Mood Tracking Integration
//

import Foundation
import HealthKit

// MARK: - Protocol

/// Use case for saving mood entries
///
/// Handles saving mood data with both 1-10 scale (backend compatibility)
/// and HKStateOfMind representation (iOS 18+ HealthKit integration).
///
/// **Responsibilities:**
/// - Validate mood input data
/// - Create MoodEntry with dual representation
/// - Save to local storage (triggers Outbox Pattern for backend sync)
/// - Optionally sync to HealthKit (iOS 18+)
protocol SaveMoodUseCase {
    /// Saves a mood entry using 1-10 score
    ///
    /// Converts the score to valence and selects appropriate labels automatically.
    ///
    /// - Parameters:
    ///   - score: Mood score (1-10)
    ///   - labels: Optional mood labels (auto-selected if nil)
    ///   - associations: Optional contextual associations (auto-inferred from notes if nil)
    ///   - notes: Optional user notes
    ///   - date: Date of the mood entry (defaults to now)
    /// - Returns: UUID of the saved mood entry
    /// - Throws: SaveMoodError if validation fails or save operation fails
    func execute(
        score: Int,
        labels: [MoodLabel]?,
        associations: [MoodAssociation]?,
        notes: String?,
        date: Date
    ) async throws -> UUID

    /// Saves a mood entry from HKStateOfMind (iOS 18+)
    ///
    /// Converts HealthKit mood data to app's domain model and saves it.
    ///
    /// - Parameter stateOfMind: HKStateOfMind from HealthKit
    /// - Returns: UUID of the saved mood entry
    /// - Throws: SaveMoodError if conversion fails or save operation fails
    @available(iOS 18.0, *)
    func execute(from stateOfMind: HKStateOfMind) async throws -> UUID
}

// MARK: - Implementation

final class SaveMoodUseCaseImpl: SaveMoodUseCase {

    // MARK: - Dependencies

    private let moodRepository: MoodRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        moodRepository: MoodRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.moodRepository = moodRepository
        self.authManager = authManager
    }

    // MARK: - Execute (Score-Based)

    func execute(
        score: Int,
        labels: [MoodLabel]? = nil,
        associations: [MoodAssociation]? = nil,
        notes: String? = nil,
        date: Date = Date()
    ) async throws -> UUID {
        // 1. Validate score
        guard MoodTranslationUtility.isValidScore(score) else {
            throw SaveMoodError.invalidScore(score)
        }

        // 2. Validate notes length
        if let notes = notes, notes.count > 500 {
            throw SaveMoodError.notesTooLong(notes.count)
        }

        // 3. Get current user
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveMoodError.userNotAuthenticated
        }

        print("SaveMoodUseCase: Saving mood score \(score) for user \(userID) at \(date)")

        // 4. Convert score to valence
        let valence = MoodTranslationUtility.scoreToValence(score)

        // 5. Select labels (use provided or auto-select)
        let selectedLabels: [MoodLabel]
        if let providedLabels = labels, !providedLabels.isEmpty {
            selectedLabels = providedLabels
        } else {
            selectedLabels = MoodTranslationUtility.labelsForScore(score, notes: notes)
        }

        // 6. Select associations (use provided or auto-infer from notes)
        let selectedAssociations: [MoodAssociation]
        if let providedAssociations = associations {
            selectedAssociations = providedAssociations
        } else {
            selectedAssociations = MoodTranslationUtility.associationsFromNotes(notes)
        }

        // 7. Check for duplicate entry on the same date
        let existingEntries = try await moodRepository.fetchLocal(
            forUserID: userID,
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.date(
                byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!
        )

        // 8. Check if exact duplicate exists
        if let existingEntry = existingEntries.first(where: { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: date)
        }) {
            // Convert labels to emotions for comparison
            let emotionsFromLabels = selectedLabels.map { $0.rawValue }
            if existingEntry.score == score && existingEntry.emotions == emotionsFromLabels
                && existingEntry.notes == notes
            {
                print(
                    "SaveMoodUseCase: Duplicate entry found. Skipping save. ID: \(existingEntry.id)"
                )
                return existingEntry.id
            } else {
                print("SaveMoodUseCase: Updating existing entry for \(date)")

                // Update existing entry
                let emotionsFromLabels = selectedLabels.map { $0.rawValue }
                let updatedEntry = existingEntry.with(
                    score: score,
                    emotions: emotionsFromLabels,
                    notes: notes,
                    updatedAt: Date(),
                    syncStatus: .pending
                )

                let savedID = try await moodRepository.save(
                    moodEntry: updatedEntry,
                    forUserID: userID
                )

                print("SaveMoodUseCase: Successfully updated mood entry. ID: \(savedID)")
                return savedID
            }
        }

        // 9. Create new mood entry
        let emotionsFromLabels = selectedLabels.map { $0.rawValue }
        let moodEntry = MoodEntry(
            id: UUID(),
            userID: userID,
            date: date,
            score: score,
            emotions: emotionsFromLabels,
            notes: notes,
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending
        )

        // 10. Validate mood entry
        try moodEntry.validate()

        // 11. Save to repository (triggers Outbox Pattern automatically)
        let savedID = try await moodRepository.save(
            moodEntry: moodEntry,
            forUserID: userID
        )

        print("SaveMoodUseCase: Successfully saved mood entry. ID: \(savedID)")

        // 12. Sync to HealthKit if available (iOS 18+)
        if #available(iOS 18.0, *) {
            do {
                try await moodRepository.saveToHealthKit(moodEntry: moodEntry)
                print("SaveMoodUseCase: Successfully synced to HealthKit")
            } catch {
                // HealthKit sync failure is non-fatal
                print("SaveMoodUseCase: Failed to sync to HealthKit: \(error.localizedDescription)")
            }
        }

        return savedID
    }

    // MARK: - Execute (HKStateOfMind-Based)

    @available(iOS 18.0, *)
    func execute(from stateOfMind: HKStateOfMind) async throws -> UUID {
        // 1. Get current user
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveMoodError.userNotAuthenticated
        }

        print("SaveMoodUseCase: Saving mood from HKStateOfMind for user \(userID)")

        // 2. Convert HKStateOfMind to MoodEntry
        let moodEntry = MoodTranslationUtility.createMoodEntry(
            from: stateOfMind,
            userID: userID
        )

        // 3. Validate mood entry
        try moodEntry.validate()

        // 4. Check for duplicate
        let existingEntries = try await moodRepository.fetchLocal(
            forUserID: userID,
            from: Calendar.current.startOfDay(for: moodEntry.date),
            to: Calendar.current.date(
                byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: moodEntry.date))!
        )

        if let existingEntry = existingEntries.first(where: { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: moodEntry.date)
        }) {
            if existingEntry.score == moodEntry.score
                && existingEntry.emotions == moodEntry.emotions
            {
                print(
                    "SaveMoodUseCase: Duplicate HealthKit entry found. Skipping. ID: \(existingEntry.id)"
                )
                return existingEntry.id
            }
        }

        // 5. Save to repository (triggers Outbox Pattern automatically)
        let savedID = try await moodRepository.save(
            moodEntry: moodEntry,
            forUserID: userID
        )

        print("SaveMoodUseCase: Successfully saved mood from HealthKit. ID: \(savedID)")

        return savedID
    }
}

// MARK: - Errors

enum SaveMoodError: Error, LocalizedError {
    case invalidScore(Int)
    case notesTooLong(Int)
    case userNotAuthenticated
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidScore(let score):
            return "Invalid mood score: \(score). Must be between 1 and 10."
        case .notesTooLong(let length):
            return "Notes too long: \(length) characters. Maximum is 500 characters."
        case .userNotAuthenticated:
            return "User must be authenticated to save mood entries."
        case .saveFailed(let reason):
            return "Failed to save mood: \(reason)"
        }
    }
}
