//
//  DashboardViewModel.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Foundation
import SwiftUI

/// ViewModel for the Dashboard view
/// Manages wellness statistics and data fetching
@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - Published State

    var wellnessStats: WellnessStatistics?
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedTimeRange: TimeRange = .thirtyDays

    // MARK: - Dependencies

    private let statisticsRepository: StatisticsRepositoryProtocol

    // MARK: - Initialization

    init(statisticsRepository: StatisticsRepositoryProtocol) {
        self.statisticsRepository = statisticsRepository
    }

    // MARK: - Public Methods

    /// Load statistics for the selected time range
    func loadStatistics() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let dateRange = selectedTimeRange.dateRange
            let stats = try await statisticsRepository.fetchWellnessStatistics(
                from: dateRange.start,
                to: dateRange.end
            )
            wellnessStats = stats
            print("✅ [DashboardViewModel] Statistics loaded successfully")
        } catch let error as StatisticsRepositoryError {
            // Handle no data gracefully - show empty state instead of error
            switch error {
            case .noDataAvailable, .notAuthenticated:
                wellnessStats = nil
                errorMessage = nil
                print("ℹ️ [DashboardViewModel] No data available - showing empty state")
            case .calculationFailed(let underlyingError):
                errorMessage = "Unable to calculate statistics. Please try again."
                print("❌ [DashboardViewModel] Calculation failed: \(underlyingError)")
            case .fetchFailed(let underlyingError):
                errorMessage = "Unable to load statistics. Please try again."
                print("❌ [DashboardViewModel] Failed to load statistics: \(underlyingError)")
            }
        } catch {
            errorMessage = "An unexpected error occurred."
            print("❌ [DashboardViewModel] Unexpected error: \(error)")
        }
    }

    /// Refresh statistics
    func refresh() async {
        await loadStatistics()
    }

    /// Change time range and reload
    func changeTimeRange(_ newRange: TimeRange) async {
        selectedTimeRange = newRange
        await loadStatistics()
    }

    // MARK: - Computed Properties

    /// Current mood streak status message
    var streakMessage: String {
        guard let streak = wellnessStats?.mood.streakInfo else {
            return "Start tracking to build a streak!"
        }

        if streak.currentStreak == 0 {
            return "Log a mood to start a streak!"
        } else if streak.currentStreak == 1 {
            return "Great start! Keep it going! 🔥"
        } else {
            return "\(streak.currentStreak) day streak! Keep it up! 🔥"
        }
    }

    /// Mood trend indicator (improving, stable, declining)
    var moodTrend: MoodTrend {
        guard let stats = wellnessStats,
            stats.mood.dailyBreakdown.count >= 7
        else {
            return .stable
        }

        let recentDays = Array(stats.mood.dailyBreakdown.suffix(7))
        let firstHalf = recentDays.prefix(3).map { $0.averageMood }
        let secondHalf = recentDays.suffix(4).map { $0.averageMood }

        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let difference = secondAverage - firstAverage

        if difference > 0.5 {
            return .improving
        } else if difference < -0.5 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Mood trend message
    var moodTrendMessage: String {
        switch moodTrend {
        case .improving:
            return "Your mood is improving"
        case .stable:
            return "Your mood is stable"
        case .declining:
            return "Take care of yourself"
        }
    }

    /// Average mood score (0-10)
    var averageMoodScore: Double {
        guard let stats = wellnessStats,
            !stats.mood.dailyBreakdown.isEmpty
        else {
            return 5.0
        }

        let sum = stats.mood.dailyBreakdown.map { $0.averageMood }.reduce(0, +)
        return sum / Double(stats.mood.dailyBreakdown.count)
    }

    /// Formatted average mood score
    var averageMoodScoreFormatted: String {
        String(format: "%.1f", averageMoodScore)
    }

    /// Percentage of days with entries
    var consistencyPercentage: Double {
        guard let stats = wellnessStats else { return 0 }

        let totalDays = stats.mood.dateRange.dayCount
        guard totalDays > 0 else { return 0 }

        let daysWithEntries = Set(stats.mood.dailyBreakdown.map { $0.date }).count
        return (Double(daysWithEntries) / Double(totalDays)) * 100
    }

    /// Formatted consistency percentage
    var consistencyPercentageFormatted: String {
        String(format: "%.0f%%", consistencyPercentage)
    }
}

// MARK: - Supporting Types

extension DashboardViewModel {
    enum TimeRange {
        case sevenDays
        case thirtyDays
        case ninetyDays
        case year

        var title: String {
            switch self {
            case .sevenDays: return "7 Days"
            case .thirtyDays: return "30 Days"
            case .ninetyDays: return "90 Days"
            case .year: return "Year"
            }
        }

        var dateRange: (start: Date, end: Date) {
            let end = Date()
            let calendar = Calendar.current

            let start: Date
            switch self {
            case .sevenDays:
                start = calendar.date(byAdding: .day, value: -7, to: end)!
            case .thirtyDays:
                start = calendar.date(byAdding: .day, value: -30, to: end)!
            case .ninetyDays:
                start = calendar.date(byAdding: .day, value: -90, to: end)!
            case .year:
                start = calendar.date(byAdding: .year, value: -1, to: end)!
            }

            return (start, end)
        }
    }

    enum MoodTrend {
        case improving
        case stable
        case declining

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }

        var color: String {
            switch self {
            case .improving: return "#4CAF50"  // Green - positive progress
            case .stable: return "#2196F3"  // Blue - consistent
            case .declining: return "#FF9800"  // Orange - needs attention
            }
        }
    }
}
