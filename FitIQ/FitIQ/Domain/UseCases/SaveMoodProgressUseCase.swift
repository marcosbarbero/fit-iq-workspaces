//
//  SaveMoodProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import HealthKit

// MARK: - Constants

/// Constants for mood score validation and tracking
enum MoodScoreConstants {
    /// Minimum valid mood score
    static let minScore: Int = 1

    /// Maximum valid mood score
    static let maxScore: Int = 10

    /// Default mood score (neutral/middle value)
    static let defaultScore: Int = 5

    /// Maximum length for mood notes
    static let maxNotesLength: Int = 500
}

/// Protocol defining the contract for saving mood progress
protocol SaveMoodProgressUseCase {
    /// Saves mood score, emotions, and optional notes for a specific date locally and triggers backend sync
    /// - Parameters:
    ///   - score: The mood score (1-10 scale)
    ///   - emotions: Array of emotion strings from predefined list (empty array if none)
    ///   - notes: Optional notes about the mood entry
    ///   - date: The date for which to log mood (defaults to current date)
    /// - Returns: The local UUID of the saved progress entry
    func execute(score: Int, emotions: [String], notes: String?, date: Date) async throws -> UUID
}

/// Implementation of SaveMoodProgressUseCase following existing patterns
final class SaveMoodProgressUseCaseImpl: SaveMoodProgressUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(score: Int, emotions: [String] = [], notes: String? = nil, date: Date = Date())
        async throws -> UUID
    {
        // Validate mood score is within acceptable range
        guard score >= MoodScoreConstants.minScore && score <= MoodScoreConstants.maxScore else {
            throw SaveMoodProgressError.invalidScore
        }

        // Validate notes length if provided
        if let notes = notes, notes.count > MoodScoreConstants.maxNotesLength {
            throw SaveMoodProgressError.notesTooLong
        }

        // Validate emotions are from allowed set
        for emotion in emotions {
            guard MoodEmotion.allEmotions.contains(emotion.lowercased()) else {
                throw SaveMoodProgressError.invalidEmotion(emotion)
            }
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveMoodProgressError.userNotAuthenticated
        }

        print(
            "SaveMoodProgressUseCase: Saving mood score \(score) with \(emotions.count) emotions for user \(userID) on \(date)"
        )

        // Check for existing entry on the same date
        let existingEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .moodScore,
            syncStatus: nil,
            limit: 100  // Limit to recent entries for performance
        )

        // Keep actual time for display, but deduplicate by date only
        let calendar = Calendar.current

        // Look for existing entry on the same date (compare dates only, not times)
        if let existingEntry = existingEntries.first(where: { entry in
            return calendar.isDate(entry.date, inSameDayAs: date)
        }) {
            // Parse existing emotions from notes metadata (temporary until we have proper emotions field)
            let existingEmotions = parseEmotionsFromMetadata(existingEntry.notes)
            let emotionsMatch = Set(existingEmotions) == Set(emotions)

            // Check if the score, emotions, and notes are the same
            if Int(existingEntry.quantity) == score && emotionsMatch && existingEntry.notes == notes
            {
                print(
                    "SaveMoodProgressUseCase: Entry already exists for \(date) with same mood score (\(score)), emotions, and notes. Skipping duplicate. Local ID: \(existingEntry.id)"
                )
                return existingEntry.id
            } else {
                print(
                    "SaveMoodProgressUseCase: Entry exists for \(date) but with different data (existing: \(Int(existingEntry.quantity)), new: \(score)). Updating entry."
                )

                // Encode emotions in metadata (temporary until we have proper emotions field)
                let notesWithMetadata = encodeEmotionsInMetadata(emotions, notes: notes)

                // Create updated entry with new score, emotions, notes, and updated time
                let updatedEntry = ProgressEntry(
                    id: existingEntry.id,  // Keep same local ID
                    userID: userID,
                    type: .moodScore,
                    quantity: Double(score),
                    date: date,  // Use actual time from update
                    notes: notesWithMetadata,
                    createdAt: existingEntry.createdAt,
                    updatedAt: Date(),
                    backendID: existingEntry.backendID,
                    syncStatus: existingEntry.backendID != nil ? .pending : .pending  // Mark for re-sync
                )

                let localID = try await progressRepository.save(
                    progressEntry: updatedEntry, forUserID: userID)

                print(
                    "SaveMoodProgressUseCase: Successfully updated mood progress. Local ID: \(localID)"
                )

                return localID
            }
        }

        // No existing entry found, create new one
        print(
            "SaveMoodProgressUseCase: No existing entry found for \(date). Creating new entry."
        )

        // Encode emotions in metadata (temporary until we have proper emotions field)
        let notesWithMetadata = encodeEmotionsInMetadata(emotions, notes: notes)

        // Create progress entry with actual time
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .moodScore,
            quantity: Double(score),
            date: date,  // Use actual time, not start of day
            notes: notesWithMetadata,
            createdAt: Date(),
            backendID: nil,
            syncStatus: .pending  // Mark as pending for sync
        )

        // Save locally
        let localID = try await progressRepository.save(
            progressEntry: progressEntry, forUserID: userID)

        print(
            "SaveMoodProgressUseCase: Successfully saved new mood progress with local ID: \(localID)"
        )

        // Repository will trigger sync event automatically
        // RemoteSyncService will pick it up and sync to backend

        // NOTE: Mood tracking is NOT saved to HealthKit because:
        // - HKCategoryTypeIdentifier.moodChanges doesn't support custom numeric values
        // - iOS 18+ HKStateOfMind requires different data structure
        // - Mood data is tracked locally and synced to backend only

        return localID
    }

    // MARK: - Helper Methods

    /// Encodes emotions into notes metadata
    /// Format: "__EMOTIONS__:[emotion1,emotion2]__END__\nActual notes here"
    private func encodeEmotionsInMetadata(_ emotions: [String], notes: String?) -> String? {
        guard !emotions.isEmpty || notes != nil else { return nil }

        let emotionsJSON = emotions.isEmpty ? "" : emotions.joined(separator: ",")
        let emotionsMetadata = "__EMOTIONS__:[\(emotionsJSON)]__END__"

        if let notes = notes, !notes.isEmpty {
            return "\(emotionsMetadata)\n\(notes)"
        } else {
            return emotionsMetadata
        }
    }

    /// Parses emotions from notes metadata
    private func parseEmotionsFromMetadata(_ notes: String?) -> [String] {
        guard let notes = notes else { return [] }

        // Look for pattern: __EMOTIONS__:[emotion1,emotion2]__END__
        if let range = notes.range(
            of: #"__EMOTIONS__:\[(.*?)\]__END__"#, options: .regularExpression)
        {
            let metadataString = String(notes[range])
            if let contentRange = metadataString.range(
                of: #"\[(.*?)\]"#, options: .regularExpression)
            {
                let content = String(metadataString[contentRange])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

                if content.isEmpty {
                    return []
                }

                return content.split(separator: ",").map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return []
    }

}

// MARK: - HealthKit Metadata Keys Extension

extension String {
    fileprivate static let HKMetadataKeyMoodScore = "MoodScore"
    fileprivate static let HKMetadataKeyUserEnteredNotes = "UserEnteredNotes"
    fileprivate static let HKMetadataKeyUserMotivatedDelay = "HKMetadataKeyUserMotivatedDelay"
}

// MARK: - Errors

enum SaveMoodProgressError: Error, LocalizedError {
    case invalidScore
    case invalidEmotion(String)
    case notesTooLong
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidScore:
            return
                "Mood score must be between \(MoodScoreConstants.minScore) and \(MoodScoreConstants.maxScore)"
        case .invalidEmotion(let emotion):
            return "Invalid emotion: \(emotion). Must be from the predefined list."
        case .notesTooLong:
            return "Notes cannot exceed \(MoodScoreConstants.maxNotesLength) characters"
        case .userNotAuthenticated:
            return "User must be authenticated to save mood progress"
        }
    }
}
