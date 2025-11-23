//
//  MoodStatistics.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Foundation

/// Statistics about user's mood entries
/// Domain entity representing aggregated mood data
struct MoodStatistics: Codable {
    let totalEntries: Int
    let dateRange: DateRange
    let moodDistribution: MoodDistribution
    let dailyBreakdown: [DailyMoodSummary]
    let streakInfo: StreakInfo

    struct MoodDistribution: Codable {
        let positive: Int
        let neutral: Int
        let negative: Int

        var total: Int {
            positive + neutral + negative
        }

        var positivePercentage: Double {
            guard total > 0 else { return 0 }
            return Double(positive) / Double(total) * 100
        }

        var neutralPercentage: Double {
            guard total > 0 else { return 0 }
            return Double(neutral) / Double(total) * 100
        }

        var negativePercentage: Double {
            guard total > 0 else { return 0 }
            return Double(negative) / Double(total) * 100
        }
    }

    struct DailyMoodSummary: Codable, Identifiable {
        let id: UUID
        let date: Date
        let averageMood: Double  // 0-10 scale
        let entryCount: Int
        let dominantMood: MoodLabel?

        init(
            id: UUID = UUID(), date: Date, averageMood: Double, entryCount: Int,
            dominantMood: MoodLabel?
        ) {
            self.id = id
            self.date = date
            self.averageMood = averageMood
            self.entryCount = entryCount
            self.dominantMood = dominantMood
        }

        enum CodingKeys: String, CodingKey {
            case id, date, averageMood, entryCount, dominantMood
        }
    }

    struct StreakInfo: Codable {
        let currentStreak: Int
        let longestStreak: Int
        let lastEntryDate: Date?

        var isActiveToday: Bool {
            guard let lastEntryDate = lastEntryDate else { return false }
            return Calendar.current.isDateInToday(lastEntryDate)
        }
    }
}

/// Journal statistics
struct JournalStatistics: Codable {
    let totalEntries: Int
    let totalWords: Int
    let averageWordsPerEntry: Int
    let longestEntry: Int
    let entriesThisWeek: Int
    let entriesThisMonth: Int
    let favoriteCount: Int
    let entriesWithMood: Int

    var averageEntriesPerWeek: Double {
        guard totalEntries > 0 else { return 0 }
        // Rough estimate assuming data collection started recently
        return Double(entriesThisWeek)
    }
}

/// Combined wellness statistics
struct WellnessStatistics: Codable {
    let mood: MoodStatistics
    let journal: JournalStatistics
    let generatedAt: Date

    init(mood: MoodStatistics, journal: JournalStatistics) {
        self.mood = mood
        self.journal = journal
        self.generatedAt = Date()
    }
}

// MARK: - Mock Data for Previews

extension MoodStatistics {
    static var mock: MoodStatistics {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!

        return MoodStatistics(
            totalEntries: 24,
            dateRange: DateRange(startDate: startDate, endDate: endDate),
            moodDistribution: MoodDistribution(
                positive: 15,
                neutral: 6,
                negative: 3
            ),
            dailyBreakdown: generateMockDailyBreakdown(from: startDate, to: endDate),
            streakInfo: StreakInfo(
                currentStreak: 5,
                longestStreak: 12,
                lastEntryDate: Date()
            )
        )
    }

    private static func generateMockDailyBreakdown(from startDate: Date, to endDate: Date)
        -> [DailyMoodSummary]
    {
        var summaries: [DailyMoodSummary] = []
        var currentDate = startDate

        while currentDate <= endDate {
            // Random chance of having an entry
            if Bool.random() {
                summaries.append(
                    DailyMoodSummary(
                        date: currentDate,
                        averageMood: Double.random(in: 3...9),
                        entryCount: Int.random(in: 1...3),
                        dominantMood: MoodLabel.allCases.randomElement()
                    )
                )
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return summaries
    }
}

extension JournalStatistics {
    static var mock: JournalStatistics {
        JournalStatistics(
            totalEntries: 18,
            totalWords: 3240,
            averageWordsPerEntry: 180,
            longestEntry: 540,
            entriesThisWeek: 4,
            entriesThisMonth: 15,
            favoriteCount: 5,
            entriesWithMood: 16
        )
    }
}

extension WellnessStatistics {
    static var mock: WellnessStatistics {
        WellnessStatistics(
            mood: .mock,
            journal: .mock
        )
    }
}
