//
//  MockMoodRepository.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Mock implementation for previews and testing
//

import Foundation

/// Mock mood repository for previews and testing
final class MockMoodRepository: MoodRepositoryProtocol {
    private var entries: [MoodEntry] = []

    init() {
        // Prepopulate with sample data
        let sampleUserId = UUID()
        let calendar = Calendar.current

        entries = [
            MoodEntry(
                userId: sampleUserId,
                date: Date(),
                moodLabel: .happy,
                notes: "Had a great morning walk. The weather was perfect!"
            ),
            MoodEntry(
                userId: sampleUserId,
                date: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                moodLabel: .amazed,
                notes: "Started the day with meditation."
            ),
            MoodEntry(
                userId: sampleUserId,
                date: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                moodLabel: .content,
                notes: "Productive work day, feeling satisfied."
            ),
            MoodEntry(
                userId: sampleUserId,
                date: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                moodLabel: .stressed,
                notes: "Didn't sleep well. Taking it slow today."
            ),
            MoodEntry(
                userId: sampleUserId,
                date: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                moodLabel: .grateful,
                notes: "Feeling motivated and ready to tackle my goals!"
            ),
        ]
    }

    func save(_ entry: MoodEntry) async throws {
        entries.insert(entry, at: 0)
        print(
            "✅ [MockMoodRepository] Saved mood: valence \(entry.valence), labels: \(entry.labels.joined(separator: ", "))"
        )
    }

    func fetchRecent(days: Int) async throws -> [MoodEntry] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.date >= startDate }
            .sorted { $0.date > $1.date }
    }

    func delete(id: UUID) async throws {
        entries.removeAll { $0.id == id }
        print("✅ [MockMoodRepository] Deleted mood entry: \(id)")
    }

    func fetchById(id: UUID) async throws -> MoodEntry? {
        return entries.first { $0.id == id }
    }

    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [MoodEntry] {
        return entries.filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date > $1.date }
    }

    func fetchAnalytics(
        from: Date,
        to: Date,
        includeDailyBreakdown: Bool
    ) async throws -> MoodAnalytics {
        // Filter entries for the period
        let periodEntries = entries.filter { $0.date >= from && $0.date <= to }

        // Calculate summary stats
        let totalEntries = periodEntries.count
        let averageValence =
            totalEntries > 0
            ? periodEntries.reduce(0.0) { $0 + $1.valence } / Double(totalEntries)
            : 0.0

        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        let daysWithEntries = Set(periodEntries.map { calendar.startOfDay(for: $0.date) }).count
        let consistency = totalDays > 0 ? Double(daysWithEntries) / Double(totalDays) : 0.0

        // Calculate trend direction
        let midpoint = from.addingTimeInterval((to.timeIntervalSince(from)) / 2)
        let firstHalf = periodEntries.filter { $0.date < midpoint }
        let secondHalf = periodEntries.filter { $0.date >= midpoint }

        let firstHalfAvg =
            firstHalf.isEmpty
            ? 0.0 : firstHalf.reduce(0.0) { $0 + $1.valence } / Double(firstHalf.count)
        let secondHalfAvg =
            secondHalf.isEmpty
            ? 0.0 : secondHalf.reduce(0.0) { $0 + $1.valence } / Double(secondHalf.count)

        let trendDirection: TrendDirection
        if totalEntries < 3 {
            trendDirection = .insufficientData
        } else if secondHalfAvg > firstHalfAvg + 0.1 {
            trendDirection = .improving
        } else if secondHalfAvg < firstHalfAvg - 0.1 {
            trendDirection = .declining
        } else {
            trendDirection = .stable
        }

        // Calculate top labels
        let allLabels = periodEntries.flatMap { $0.labels }
        let labelCounts = Dictionary(grouping: allLabels, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }

        let topLabels = labelCounts.prefix(5).map { label, count in
            LabelStatistic(
                label: label,
                count: count,
                percentage: Double(count) / Double(totalEntries)
            )
        }

        // Create mock analytics
        return MoodAnalytics(
            period: AnalyticsPeriod(
                startDate: from,
                endDate: to,
                totalDays: totalDays
            ),
            summary: AnalyticsSummary(
                totalEntries: totalEntries,
                averageValence: averageValence,
                daysWithEntries: daysWithEntries,
                loggingConsistency: consistency
            ),
            trends: AnalyticsTrends(
                trendDirection: trendDirection,
                weeklyAverages: []
            ),
            topLabels: topLabels,
            topAssociations: nil,
            dailyAggregates: nil
        )
    }
}
