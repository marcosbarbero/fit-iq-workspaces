//
//  MoodAnalytics.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Domain models for mood analytics from backend endpoint
//

import Foundation

// MARK: - Main Analytics Model

/// Complete mood analytics for a time period
/// Fetched from GET /api/v1/wellness/mood-entries/analytics
struct MoodAnalytics: Codable {
    let period: AnalyticsPeriod
    let summary: AnalyticsSummary
    let trends: AnalyticsTrends
    let topLabels: [LabelStatistic]
    let topAssociations: [AssociationStatistic]?
    let dailyAggregates: [DailyAggregate]?

    enum CodingKeys: String, CodingKey {
        case period
        case summary
        case trends
        case topLabels = "top_labels"
        case topAssociations = "top_associations"
        case dailyAggregates = "daily_aggregates"
    }
}

// MARK: - Period

/// Time period for the analytics data
struct AnalyticsPeriod: Codable {
    let startDate: Date
    let endDate: Date
    let totalDays: Int

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case totalDays = "total_days"
    }

    // Manual initializer for construction
    init(startDate: Date, endDate: Date, totalDays: Int) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalDays = totalDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let totalDays = try container.decode(Int.self, forKey: .totalDays)

        // Decode date strings in YYYY-MM-DD format
        let startDateString = try container.decode(String.self, forKey: .startDate)
        let endDateString = try container.decode(String.self, forKey: .endDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        guard let start = dateFormatter.date(from: startDateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .startDate,
                in: container,
                debugDescription:
                    "Invalid date format. Expected yyyy-MM-dd, got: \(startDateString)"
            )
        }

        guard let end = dateFormatter.date(from: endDateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .endDate,
                in: container,
                debugDescription: "Invalid date format. Expected yyyy-MM-dd, got: \(endDateString)"
            )
        }

        self.startDate = start
        self.endDate = end
        self.totalDays = totalDays
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        try container.encode(dateFormatter.string(from: startDate), forKey: .startDate)
        try container.encode(dateFormatter.string(from: endDate), forKey: .endDate)
        try container.encode(totalDays, forKey: .totalDays)
    }
}

// MARK: - Summary

/// Summary statistics for the period
struct AnalyticsSummary: Codable {
    let totalEntries: Int
    let averageValence: Double
    let daysWithEntries: Int
    let loggingConsistency: Double

    enum CodingKeys: String, CodingKey {
        case totalEntries = "total_entries"
        case averageValence = "average_valence"
        case daysWithEntries = "days_with_entries"
        case loggingConsistency = "logging_consistency"
    }

    /// Formatted consistency percentage (0-100)
    var consistencyPercentage: Int {
        Int(loggingConsistency * 100)
    }

    /// User-friendly consistency message
    var consistencyMessage: String {
        switch loggingConsistency {
        case 0.9...: return "Amazing! You're building a wonderful habit 🌟"
        case 0.7..<0.9: return "Great job staying consistent! Keep it up 💚"
        case 0.5..<0.7: return "You're doing well! A few more days each week 🌱"
        case 0.3..<0.5: return "Every entry counts. You're on your way 🌿"
        default: return "Take it one day at a time 🤍"
        }
    }

    /// Consistency level for UI color coding
    var consistencyLevel: ConsistencyLevel {
        switch loggingConsistency {
        case 0.9...: return .excellent
        case 0.7..<0.9: return .great
        case 0.5..<0.7: return .good
        case 0.3..<0.5: return .fair
        default: return .needsWork
        }
    }
}

/// Consistency level for UI presentation
enum ConsistencyLevel {
    case excellent  // 90%+
    case great  // 70-89%
    case good  // 50-69%
    case fair  // 30-49%
    case needsWork  // <30%

    var color: String {
        switch self {
        case .excellent: return "#4CAF50"  // Green
        case .great: return "#8BC34A"  // Light green
        case .good: return "#FFC107"  // Amber
        case .fair: return "#FF9800"  // Orange
        case .needsWork: return "#9E9E9E"  // Gray
        }
    }
}

// MARK: - Trends

/// Trend analysis for the period
struct AnalyticsTrends: Codable {
    let trendDirection: TrendDirection
    let weeklyAverages: [WeeklyAverage]

    enum CodingKeys: String, CodingKey {
        case trendDirection = "trend_direction"
        case weeklyAverages = "weekly_averages"
    }
}

/// Overall trend direction
enum TrendDirection: String, Codable {
    case improving
    case stable
    case declining
    case insufficientData = "insufficient_data"

    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        case .insufficientData: return "Not enough data"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .insufficientData: return "questionmark"
        }
    }

    var color: String {
        switch self {
        case .improving: return "#4CAF50"  // Green
        case .stable: return "#2196F3"  // Blue
        case .declining: return "#FF9800"  // Orange
        case .insufficientData: return "#9E9E9E"  // Gray
        }
    }

    var description: String {
        switch self {
        case .improving: return "Your mood is trending upward"
        case .stable: return "Your mood is consistent"
        case .declining: return "Your mood needs attention"
        case .insufficientData: return "Log more moods to see trends"
        }
    }
}

/// Weekly average valence
struct WeeklyAverage: Codable, Identifiable {
    let weekStart: Date
    let averageValence: Double

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case averageValence = "average_valence"
    }

    var id: Date { weekStart }

    // Manual initializer for construction
    init(weekStart: Date, averageValence: Double) {
        self.weekStart = weekStart
        self.averageValence = averageValence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let averageValence = try container.decode(Double.self, forKey: .averageValence)

        // Decode date string in YYYY-MM-DD format
        let weekStartString = try container.decode(String.self, forKey: .weekStart)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        guard let date = dateFormatter.date(from: weekStartString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .weekStart,
                in: container,
                debugDescription:
                    "Invalid date format. Expected yyyy-MM-dd, got: \(weekStartString)"
            )
        }

        self.weekStart = date
        self.averageValence = averageValence
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        try container.encode(dateFormatter.string(from: weekStart), forKey: .weekStart)
        try container.encode(averageValence, forKey: .averageValence)
    }
}

// MARK: - Label Statistics

/// Statistics for a mood label
struct LabelStatistic: Codable, Identifiable {
    let label: String
    let count: Int
    let percentage: Double

    var id: String { label }

    /// Formatted percentage (0-100)
    var percentageFormatted: Int {
        Int(percentage * 100)
    }

    /// Get the corresponding MoodLabel if available
    var moodLabel: MoodLabel? {
        MoodLabel.allCases.first { $0.rawValue.lowercased() == label.lowercased() }
    }
}

// MARK: - Association Statistics

/// Statistics for an association/context
struct AssociationStatistic: Codable, Identifiable {
    let association: String
    let count: Int
    let percentage: Double
    let averageValence: Double

    enum CodingKeys: String, CodingKey {
        case association
        case count
        case percentage
        case averageValence = "average_valence"
    }

    var id: String { association }

    /// Formatted percentage (0-100)
    var percentageFormatted: Int {
        Int(percentage * 100)
    }

    /// Icon for common associations
    var icon: String {
        switch association.lowercased() {
        case "fitness", "exercise", "workout": return "figure.run"
        case "work", "job", "career": return "briefcase"
        case "social", "friends", "family": return "person.2"
        case "food", "meal", "eating": return "fork.knife"
        case "sleep", "rest", "relaxation": return "bed.double"
        case "hobby", "creative", "art": return "paintbrush"
        case "nature", "outdoors", "hiking": return "leaf"
        case "meditation", "mindfulness": return "brain"
        default: return "tag"
        }
    }
}

// MARK: - Daily Aggregate

/// Daily aggregated statistics
struct DailyAggregate: Codable, Identifiable {
    let date: Date
    let entryCount: Int
    let averageValence: Double
    let minValence: Double
    let maxValence: Double
    let mostCommonLabels: [LabelCount]
    let mostCommonAssociations: [AssociationCount]?

    enum CodingKeys: String, CodingKey {
        case date
        case entryCount = "entry_count"
        case averageValence = "average_valence"
        case minValence = "min_valence"
        case maxValence = "max_valence"
        case mostCommonLabels = "most_common_labels"
        case mostCommonAssociations = "most_common_associations"
    }

    var id: Date { date }

    /// Valence range for the day
    var valenceRange: Double {
        maxValence - minValence
    }

    /// Primary mood label for the day
    var primaryLabel: String? {
        mostCommonLabels.first?.label
    }

    // Manual initializer for construction
    init(
        date: Date,
        entryCount: Int,
        averageValence: Double,
        minValence: Double,
        maxValence: Double,
        mostCommonLabels: [LabelCount],
        mostCommonAssociations: [AssociationCount]?
    ) {
        self.date = date
        self.entryCount = entryCount
        self.averageValence = averageValence
        self.minValence = minValence
        self.maxValence = maxValence
        self.mostCommonLabels = mostCommonLabels
        self.mostCommonAssociations = mostCommonAssociations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode date string in YYYY-MM-DD format
        let dateString = try container.decode(String.self, forKey: .date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        guard let decodedDate = dateFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Invalid date format. Expected yyyy-MM-dd, got: \(dateString)"
            )
        }

        self.date = decodedDate
        self.entryCount = try container.decode(Int.self, forKey: .entryCount)
        self.averageValence = try container.decode(Double.self, forKey: .averageValence)
        self.minValence = try container.decode(Double.self, forKey: .minValence)
        self.maxValence = try container.decode(Double.self, forKey: .maxValence)
        self.mostCommonLabels = try container.decode([LabelCount].self, forKey: .mostCommonLabels)
        self.mostCommonAssociations = try container.decodeIfPresent(
            [AssociationCount].self, forKey: .mostCommonAssociations)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        try container.encode(dateFormatter.string(from: date), forKey: .date)
        try container.encode(entryCount, forKey: .entryCount)
        try container.encode(averageValence, forKey: .averageValence)
        try container.encode(minValence, forKey: .minValence)
        try container.encode(maxValence, forKey: .maxValence)
        try container.encode(mostCommonLabels, forKey: .mostCommonLabels)
        try container.encodeIfPresent(mostCommonAssociations, forKey: .mostCommonAssociations)
    }
}

/// Label count for daily aggregates
struct LabelCount: Codable, Identifiable {
    let label: String
    let count: Int

    var id: String { label }
}

/// Association count for daily aggregates
struct AssociationCount: Codable, Identifiable {
    let association: String
    let count: Int

    var id: String { association }
}

// MARK: - Response Wrapper

/// Backend response wrapper for analytics
struct AnalyticsResponse: Codable {
    let data: MoodAnalytics
}

// MARK: - Helper Extensions

extension MoodAnalytics {
    /// Check if there's enough data for meaningful insights
    var hasEnoughData: Bool {
        summary.totalEntries >= 3
    }

    /// Check if daily breakdown is available
    var hasDailyBreakdown: Bool {
        dailyAggregates != nil && !(dailyAggregates?.isEmpty ?? true)
    }

    /// Check if associations are tracked
    var hasAssociations: Bool {
        topAssociations != nil && !(topAssociations?.isEmpty ?? true)
    }

    /// Get top N labels
    func topLabels(limit: Int) -> [LabelStatistic] {
        Array(topLabels.prefix(limit))
    }

    /// Get top N associations
    func topAssociations(limit: Int) -> [AssociationStatistic] {
        guard let associations = topAssociations else { return [] }
        return Array(associations.prefix(limit))
    }
}
