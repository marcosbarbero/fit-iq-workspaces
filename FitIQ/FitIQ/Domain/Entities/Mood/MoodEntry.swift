//
//  MoodEntry.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Redesigned for Backend API Alignment
//

import Foundation

/// Domain model for mood tracking
///
/// Represents a single mood entry with:
/// - mood_score: 1-10 scale (1 = very bad, 10 = excellent)
/// - emotions: Array of predefined emotion strings
/// - notes: Optional user notes (max 500 chars)
/// - logged_at: Timestamp when mood was recorded
///
/// This model aligns with the /api/v1/mood backend API contract.
struct MoodEntry: Identifiable, Equatable, Sendable {
    // MARK: - Identity & User

    /// Unique identifier for this mood entry (local UUID)
    let id: UUID

    /// User ID this mood entry belongs to
    let userID: String

    /// Date and time when the mood was recorded
    let date: Date

    // MARK: - Mood Data (Backend API Contract)

    /// Mood score on a 1-10 scale
    /// - 1-3: Very bad to below average
    /// - 4-6: Below average to neutral
    /// - 7-8: Good
    /// - 9-10: Excellent
    let score: Int

    /// List of emotions from predefined set
    /// Allowed values: happy, sad, anxious, calm, energetic, tired, stressed,
    /// relaxed, angry, content, frustrated, motivated, overwhelmed, peaceful, excited
    let emotions: [String]

    /// Optional user notes about the mood (max 500 characters)
    let notes: String?

    // MARK: - Metadata

    /// Timestamp when the entry was created locally
    let createdAt: Date

    /// Timestamp when the entry was last updated
    let updatedAt: Date?

    // MARK: - Sync Tracking

    /// Backend-assigned ID (nil if not yet synced)
    let backendID: String?

    /// Sync status for Outbox Pattern
    let syncStatus: SyncStatus

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        userID: String,
        date: Date,
        score: Int,
        emotions: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.userID = userID
        self.date = date
        self.score = score
        self.emotions = emotions
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
    }

    // MARK: - Computed Properties

    /// Returns a human-readable description of the mood score
    var moodDescription: String {
        switch score {
        case 1...2:
            return "Very Bad"
        case 3...4:
            return "Below Average"
        case 5...6:
            return "Neutral"
        case 7...8:
            return "Good"
        case 9...10:
            return "Excellent"
        default:
            return "Unknown"
        }
    }

    /// Returns an emoji representation of the mood score
    var moodEmoji: String {
        switch score {
        case 1...2:
            return "😢"
        case 3...4:
            return "🙁"
        case 5...6:
            return "😐"
        case 7...8:
            return "😊"
        case 9...10:
            return "🤩"
        default:
            return "😶"
        }
    }

    /// Returns whether this entry has been synced to the backend
    var isSynced: Bool {
        return backendID != nil && syncStatus == .synced
    }

    /// Returns whether this entry needs to be synced
    var needsSync: Bool {
        return syncStatus == .pending || syncStatus == .failed
    }

    /// Returns a formatted list of emotions for display
    var emotionsDisplay: String {
        guard !emotions.isEmpty else { return "No emotions selected" }
        return emotions.map { $0.capitalized }.joined(separator: ", ")
    }
}

// MARK: - Extensions

extension MoodEntry {
    /// Creates a copy of this MoodEntry with updated fields
    func with(
        score: Int? = nil,
        emotions: [String]? = nil,
        notes: String? = nil,
        updatedAt: Date? = Date(),
        backendID: String? = nil,
        syncStatus: SyncStatus? = nil
    ) -> MoodEntry {
        return MoodEntry(
            id: self.id,
            userID: self.userID,
            date: self.date,
            score: score ?? self.score,
            emotions: emotions ?? self.emotions,
            notes: notes ?? self.notes,
            createdAt: self.createdAt,
            updatedAt: updatedAt ?? self.updatedAt,
            backendID: backendID ?? self.backendID,
            syncStatus: syncStatus ?? self.syncStatus
        )
    }
}

// MARK: - Validation

extension MoodEntry {
    /// Validates the mood entry data
    func validate() throws {
        // Validate score range
        guard score >= 1 && score <= 10 else {
            throw MoodEntryError.invalidScore(score)
        }

        // Validate emotions are from allowed set
        for emotion in emotions {
            guard MoodEmotion.allEmotions.contains(emotion.lowercased()) else {
                throw MoodEntryError.invalidEmotion(emotion)
            }
        }

        // Validate notes length
        if let notes = notes, notes.count > 500 {
            throw MoodEntryError.notesTooLong(notes.count)
        }
    }
}

// MARK: - Errors

enum MoodEntryError: Error, LocalizedError {
    case invalidScore(Int)
    case invalidEmotion(String)
    case notesTooLong(Int)

    var errorDescription: String? {
        switch self {
        case .invalidScore(let score):
            return "Invalid mood score: \(score). Must be between 1 and 10."
        case .invalidEmotion(let emotion):
            return "Invalid emotion: \(emotion). Must be from the predefined list."
        case .notesTooLong(let length):
            return "Notes too long: \(length) characters. Maximum is 500 characters."
        }
    }
}

// MARK: - Allowed Emotions (Backend API Contract)

/// Allowed emotions for mood tracking (matches backend API)
enum MoodEmotion {
    static let allEmotions: Set<String> = [
        "happy",
        "sad",
        "anxious",
        "calm",
        "energetic",
        "tired",
        "stressed",
        "relaxed",
        "angry",
        "content",
        "frustrated",
        "motivated",
        "overwhelmed",
        "peaceful",
        "excited",
    ]

    /// Returns all emotions sorted alphabetically
    static var sortedEmotions: [String] {
        return Array(allEmotions).sorted()
    }

    /// Returns a display name for an emotion
    static func displayName(for emotion: String) -> String {
        return emotion.capitalized
    }

    /// Returns an SF Symbol for an emotion
    static func symbol(for emotion: String) -> String {
        switch emotion.lowercased() {
        case "happy": return "face.smiling.fill"
        case "sad": return "cloud.rain.fill"
        case "anxious": return "tornado"
        case "calm": return "leaf.fill"
        case "energetic": return "bolt.fill"
        case "tired": return "battery.0"
        case "stressed": return "exclamationmark.triangle.fill"
        case "relaxed": return "figure.mind.and.body"
        case "angry": return "flame.fill"
        case "content": return "checkmark.circle.fill"
        case "frustrated": return "xmark.circle.fill"
        case "motivated": return "star.fill"
        case "overwhelmed": return "square.stack.3d.up.fill"
        case "peaceful": return "moon.stars.fill"
        case "excited": return "sparkles"
        default: return "circle.fill"
        }
    }
}
