//
//  JournalEntry.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import Foundation

/// Represents a journal entry for reflection and personal thoughts
struct JournalEntry: Identifiable, Codable, Equatable {
    // MARK: - Core Properties

    let id: UUID
    let userId: UUID
    let date: Date

    // MARK: - Content

    /// Optional title for the entry
    var title: String?

    /// Main content of the journal entry
    var content: String

    // MARK: - Metadata

    /// Tags for organization and search
    var tags: [String]

    /// Type of journal entry
    var entryType: EntryType

    /// Whether this entry is marked as favorite
    var isFavorite: Bool

    // MARK: - Mood Integration

    /// Optional link to a mood entry
    var linkedMoodId: UUID?

    // MARK: - Backend Sync

    /// Backend ID for synced entries
    var backendId: String?

    // MARK: - Timestamps

    let createdAt: Date
    var updatedAt: Date

    // MARK: - Constants

    /// Maximum content length (10,000 characters for deep reflection)
    static let maxContentLength = 10_000

    /// Maximum title length
    static let maxTitleLength = 100

    /// Maximum number of tags
    static let maxTags = 10

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        userId: UUID,
        date: Date = Date(),
        title: String? = nil,
        content: String = "",
        tags: [String] = [],
        entryType: EntryType = .freeform,
        isFavorite: Bool = false,
        linkedMoodId: UUID? = nil,
        backendId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.title = title
        self.content = content
        self.tags = tags
        self.entryType = entryType
        self.isFavorite = isFavorite
        self.linkedMoodId = linkedMoodId
        self.backendId = backendId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Check if the entry has content
    var hasContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if the entry has a title
    var hasTitle: Bool {
        guard let title = title else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if the entry is linked to a mood
    var isLinkedToMood: Bool {
        linkedMoodId != nil
    }

    /// Word count of the journal entry
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    /// Character count of the journal entry
    var characterCount: Int {
        content.count
    }

    /// Reading time estimate in minutes (based on 200 words per minute)
    var estimatedReadingTime: Int {
        max(1, wordCount / 200)
    }

    /// Preview of the journal text (first 150 characters)
    var preview: String {
        guard hasContent else { return "No content yet" }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 150 {
            return trimmed
        }
        return String(trimmed.prefix(150)) + "..."
    }

    /// Display title (falls back to preview if no title)
    var displayTitle: String {
        if hasTitle, let title = title {
            return title
        }
        return preview
    }

    /// Format date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Format date and time for display
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Relative date string (e.g., "Today", "Yesterday", "Jan 15")
    var relativeDateString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // Day name
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"  // Month and day
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"  // Full date
            return formatter.string(from: date)
        }
    }

    /// Check if entry was modified after creation
    var wasModified: Bool {
        updatedAt.timeIntervalSince(createdAt) > 1.0  // More than 1 second difference
    }

    /// Time since last update
    var timeSinceUpdate: String {
        let interval = Date().timeIntervalSince(updatedAt)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    // MARK: - Validation

    /// Validate the journal entry
    var isValid: Bool {
        // Must have content
        guard hasContent else { return false }

        // Content must not exceed max length
        guard content.count <= Self.maxContentLength else { return false }

        // Title must not exceed max length if present
        if let title = title, title.count > Self.maxTitleLength {
            return false
        }

        // Tags must not exceed max count
        guard tags.count <= Self.maxTags else { return false }

        return true
    }

    /// Validation errors
    var validationErrors: [String] {
        var errors: [String] = []

        if !hasContent {
            errors.append("Content is required")
        }

        if content.count > Self.maxContentLength {
            errors.append("Content exceeds \(Self.maxContentLength) characters")
        }

        if let title = title, title.count > Self.maxTitleLength {
            errors.append("Title exceeds \(Self.maxTitleLength) characters")
        }

        if tags.count > Self.maxTags {
            errors.append("Too many tags (maximum \(Self.maxTags))")
        }

        return errors
    }

    // MARK: - Helpers

    /// Add a tag to the entry
    mutating func addTag(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedTag.isEmpty else { return }
        guard !tags.contains(trimmedTag) else { return }
        guard tags.count < Self.maxTags else { return }
        tags.append(trimmedTag)
        updatedAt = Date()
    }

    /// Remove a tag from the entry
    mutating func removeTag(_ tag: String) {
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        tags.removeAll { $0 == trimmedTag }
        updatedAt = Date()
    }

    /// Toggle favorite status
    mutating func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }

    /// Link to a mood entry
    mutating func linkToMood(_ moodId: UUID) {
        linkedMoodId = moodId
        updatedAt = Date()
    }

    /// Unlink from mood entry
    mutating func unlinkFromMood() {
        linkedMoodId = nil
        updatedAt = Date()
    }

    /// Create a copy with updated timestamp
    func withUpdatedTimestamp() -> JournalEntry {
        var updated = self
        updated.updatedAt = Date()
        return updated
    }
}

// MARK: - Comparable

extension JournalEntry: Comparable {
    static func < (lhs: JournalEntry, rhs: JournalEntry) -> Bool {
        // Sort by date (most recent first)
        lhs.date > rhs.date
    }
}

// MARK: - Hashable

extension JournalEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
