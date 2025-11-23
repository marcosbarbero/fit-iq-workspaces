//
//  StatisticsRepository.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Foundation
import SwiftData

/// Repository for calculating and fetching wellness statistics
/// Computes aggregated data from local mood and journal entries
final class StatisticsRepository: StatisticsRepositoryProtocol, UserAuthenticatedRepository {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - StatisticsRepositoryProtocol

    func fetchMoodStatistics(from startDate: Date, to endDate: Date) async throws -> MoodStatistics
    {
        print("📊 [StatisticsRepository] Fetching mood statistics from \(startDate) to \(endDate)")

        // Get current user ID
        let userId = try getCurrentUserId()

        // Fetch mood entries for date range
        let descriptor = FetchDescriptor<SDMoodEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId && entry.date >= startDate && entry.date <= endDate
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        let entries = try modelContext.fetch(descriptor)

        guard !entries.isEmpty else {
            throw StatisticsRepositoryError.noDataAvailable
        }

        print("📊 [StatisticsRepository] Found \(entries.count) mood entries")

        // Calculate statistics
        let statistics = calculateMoodStatistics(
            entries: entries, startDate: startDate, endDate: endDate)

        print("✅ [StatisticsRepository] Mood statistics calculated successfully")
        return statistics
    }

    func fetchJournalStatistics() async throws -> JournalStatistics {
        print("📊 [StatisticsRepository] Fetching journal statistics")

        // Get current user ID
        let userId = try getCurrentUserId()

        // Fetch all journal entries
        let descriptor = FetchDescriptor<SDJournalEntry>(
            predicate: #Predicate { entry in
                entry.userId == userId
            }
        )

        let entries = try modelContext.fetch(descriptor)

        guard !entries.isEmpty else {
            throw StatisticsRepositoryError.noDataAvailable
        }

        print("📊 [StatisticsRepository] Found \(entries.count) journal entries")

        // Calculate statistics
        let statistics = calculateJournalStatistics(entries: entries)

        print("✅ [StatisticsRepository] Journal statistics calculated successfully")
        return statistics
    }

    func fetchWellnessStatistics(from startDate: Date, to endDate: Date) async throws
        -> WellnessStatistics
    {
        print("📊 [StatisticsRepository] Fetching wellness statistics")

        do {
            let moodStats = try await fetchMoodStatistics(from: startDate, to: endDate)
            let journalStats = try await fetchJournalStatistics()

            let wellness = WellnessStatistics(mood: moodStats, journal: journalStats)

            print("✅ [StatisticsRepository] Wellness statistics calculated successfully")
            return wellness
        } catch {
            print("❌ [StatisticsRepository] Failed to fetch wellness statistics: \(error)")
            throw StatisticsRepositoryError.fetchFailed(error)
        }
    }

    // MARK: - Private Calculation Methods

    private func calculateMoodStatistics(
        entries: [SDMoodEntry],
        startDate: Date,
        endDate: Date
    ) -> MoodStatistics {
        // Calculate mood distribution
        var positiveCount = 0
        var neutralCount = 0
        var negativeCount = 0

        for entry in entries {
            // Determine mood category based on valence
            let category = categorizeMood(valence: entry.valence)
            switch category {
            case .positive:
                positiveCount += 1
            case .neutral:
                neutralCount += 1
            case .negative:
                negativeCount += 1
            }
        }

        let distribution = MoodStatistics.MoodDistribution(
            positive: positiveCount,
            neutral: neutralCount,
            negative: negativeCount
        )

        // Calculate daily breakdown
        let dailyBreakdown = calculateDailyBreakdown(entries: entries)

        // Calculate streak
        let streakInfo = calculateStreak(entries: entries)

        return MoodStatistics(
            totalEntries: entries.count,
            dateRange: DateRange(startDate: startDate, endDate: endDate),
            moodDistribution: distribution,
            dailyBreakdown: dailyBreakdown,
            streakInfo: streakInfo
        )
    }

    private func calculateDailyBreakdown(entries: [SDMoodEntry]) -> [MoodStatistics
        .DailyMoodSummary]
    {
        // Group entries by date
        let calendar = Calendar.current
        var dateGroups: [Date: [SDMoodEntry]] = [:]

        for entry in entries {
            let dateOnly = calendar.startOfDay(for: entry.date)
            dateGroups[dateOnly, default: []].append(entry)
        }

        // Calculate summary for each day
        return dateGroups.map { date, dayEntries in
            // Calculate average mood value (0-10 scale)
            let moodValues = dayEntries.map { entry -> Double in
                // Convert valence (-1 to 1) to 0-10 scale
                return valenceToNumericScore(entry.valence)
            }

            let averageMood =
                moodValues.isEmpty ? 5.0 : moodValues.reduce(0, +) / Double(moodValues.count)

            // Determine dominant mood
            // Determine dominant mood from labels
            let dominantMood = findDominantMood(from: dayEntries)

            return MoodStatistics.DailyMoodSummary(
                date: date,
                averageMood: averageMood,
                entryCount: dayEntries.count,
                dominantMood: dominantMood
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func calculateStreak(entries: [SDMoodEntry]) -> MoodStatistics.StreakInfo {
        guard !entries.isEmpty else {
            return MoodStatistics.StreakInfo(
                currentStreak: 0,
                longestStreak: 0,
                lastEntryDate: nil
            )
        }

        let calendar = Calendar.current
        let sortedEntries = entries.sorted { $0.date < $1.date }

        // Get unique dates (days with entries)
        let uniqueDates = Set(sortedEntries.map { calendar.startOfDay(for: $0.date) })
            .sorted()

        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 1

        // Calculate streaks
        for i in 1..<uniqueDates.count {
            let previousDate = uniqueDates[i - 1]
            let currentDate = uniqueDates[i]

            let dayDifference =
                calendar.dateComponents([.day], from: previousDate, to: currentDate).day ?? 0

            if dayDifference == 1 {
                // Consecutive day
                tempStreak += 1
            } else {
                // Streak broken
                longestStreak = max(longestStreak, tempStreak)
                tempStreak = 1
            }
        }

        longestStreak = max(longestStreak, tempStreak)

        // Calculate current streak (from today backwards)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        if uniqueDates.contains(today) {
            // Has entry today
            currentStreak = 1
            var checkDate = yesterday

            for date in uniqueDates.reversed() where date < today {
                if date == checkDate {
                    currentStreak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                } else {
                    break
                }
            }
        } else if uniqueDates.contains(yesterday) {
            // Has entry yesterday, streak still active
            currentStreak = 1
            var checkDate = calendar.date(byAdding: .day, value: -2, to: today)!

            for date in uniqueDates.reversed() where date <= yesterday {
                if date == checkDate {
                    currentStreak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                } else {
                    break
                }
            }
        }

        return MoodStatistics.StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEntryDate: sortedEntries.last?.date
        )
    }

    private func calculateJournalStatistics(entries: [SDJournalEntry]) -> JournalStatistics {
        let calendar = Calendar.current
        let now = Date()

        // Calculate week and month counts
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now)!

        let entriesThisWeek = entries.filter { $0.createdAt >= weekAgo }.count
        let entriesThisMonth = entries.filter { $0.createdAt >= monthAgo }.count

        // Calculate word counts
        var totalWords = 0
        var longestEntry = 0

        for entry in entries {
            let wordCount = entry.content.split(separator: " ").count
            totalWords += wordCount
            longestEntry = max(longestEntry, wordCount)
        }

        let averageWords = entries.isEmpty ? 0 : totalWords / entries.count

        // Count favorites
        let favoriteCount = entries.filter { $0.isFavorite }.count

        // Count entries with mood
        let entriesWithMood = entries.filter { $0.linkedMoodId != nil }.count

        return JournalStatistics(
            totalEntries: entries.count,
            totalWords: totalWords,
            averageWordsPerEntry: averageWords,
            longestEntry: longestEntry,
            entriesThisWeek: entriesThisWeek,
            entriesThisMonth: entriesThisMonth,
            favoriteCount: favoriteCount,
            entriesWithMood: entriesWithMood
        )
    }
}

// MARK: - Private Helpers

extension StatisticsRepository {
    /// Convert valence (-1 to 1) to numeric score (0-10 scale)
    private func valenceToNumericScore(_ valence: Double) -> Double {
        // Valence -1.0 = score 0, valence 0.0 = score 5, valence 1.0 = score 10
        return (valence + 1.0) * 5.0
    }

    /// Categorize mood based on valence
    private func categorizeMood(valence: Double) -> MoodCategory {
        if valence > 0.3 {
            return .positive
        } else if valence < -0.3 {
            return .negative
        } else {
            return .neutral
        }
    }

    /// Find dominant mood label from entries
    private func findDominantMood(from entries: [SDMoodEntry]) -> MoodLabel? {
        // Count all labels across all entries
        var labelCounts: [String: Int] = [:]

        for entry in entries {
            for label in entry.labels {
                labelCounts[label, default: 0] += 1
            }
        }

        // Find most common label
        guard let dominantLabel = labelCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        // Convert to MoodLabel
        return MoodLabel(rawValue: dominantLabel)
    }

    /// Mood category for grouping
    private enum MoodCategory {
        case positive
        case neutral
        case negative
    }
}
