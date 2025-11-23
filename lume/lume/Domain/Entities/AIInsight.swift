//
//  AIInsight.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Represents an AI-generated wellness insight
struct AIInsight: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let insightType: InsightType
    let title: String
    let content: String
    let summary: String?
    let periodStart: Date?
    let periodEnd: Date?
    let metrics: InsightMetrics?
    let suggestions: [String]?
    var isRead: Bool
    var isFavorite: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        insightType: InsightType,
        title: String,
        content: String,
        summary: String? = nil,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        metrics: InsightMetrics? = nil,
        suggestions: [String]? = nil,
        isRead: Bool = false,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.insightType = insightType
        self.title = title
        self.content = content
        self.summary = summary
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.metrics = metrics
        self.suggestions = suggestions
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Mark the insight as read
    mutating func markAsRead() {
        isRead = true
        updatedAt = Date()
    }

    /// Toggle favorite status
    mutating func toggleFavorite() {
        isFavorite.toggle()
        updatedAt = Date()
    }

    /// Archive the insight
    mutating func archive() {
        isArchived = true
        updatedAt = Date()
    }

    /// Unarchive the insight
    mutating func unarchive() {
        isArchived = false
        updatedAt = Date()
    }

    /// Check if insight has suggestions
    var hasSuggestions: Bool {
        !(suggestions?.isEmpty ?? true)
    }

    /// Check if insight has metrics
    var hasMetrics: Bool {
        metrics != nil
    }

    /// Check if insight has a time period
    var hasPeriod: Bool {
        periodStart != nil && periodEnd != nil
    }

    /// Format period for display
    var formattedPeriod: String? {
        guard let start = periodStart, let end = periodEnd else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        return "\(startStr) - \(endStr)"
    }
}

/// Type of AI insight (matches swagger spec)
enum InsightType: String, Codable, CaseIterable, Equatable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case milestone = "milestone"

    var displayName: String {
        switch self {
        case .daily:
            return "Daily Insight"
        case .weekly:
            return "Weekly Insight"
        case .monthly:
            return "Monthly Review"
        case .milestone:
            return "Milestone"
        }
    }

    var systemImage: String {
        switch self {
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.badge.clock"
        case .monthly:
            return "calendar"
        case .milestone:
            return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .daily:
            return "accentPrimary"
        case .weekly:
            return "accentPrimary"
        case .monthly:
            return "accentSecondary"
        case .milestone:
            return "moodPositive"
        }
    }
}

/// Metrics for an insight (matches swagger spec)
struct InsightMetrics: Codable, Equatable, Hashable {
    let moodEntriesCount: Int?
    let journalEntriesCount: Int?
    let goalsActive: Int?
    let goalsCompleted: Int?

    init(
        moodEntriesCount: Int? = nil,
        journalEntriesCount: Int? = nil,
        goalsActive: Int? = nil,
        goalsCompleted: Int? = nil
    ) {
        self.moodEntriesCount = moodEntriesCount
        self.journalEntriesCount = journalEntriesCount
        self.goalsActive = goalsActive
        self.goalsCompleted = goalsCompleted
    }

    /// Check if any metrics are available
    var hasMetrics: Bool {
        moodEntriesCount != nil || journalEntriesCount != nil || goalsActive != nil
            || goalsCompleted != nil
    }

    /// Total activity count
    var totalActivity: Int {
        (moodEntriesCount ?? 0) + (journalEntriesCount ?? 0)
    }
}
