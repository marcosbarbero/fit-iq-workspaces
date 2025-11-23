//
//  MoodDetailViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import Observation

/// Represents a mood record for display in the UI
struct MoodRecord: Identifiable {
    let id: UUID
    let date: Date
    let score: Int  // 1 to 10
    let notes: String?

    /// Initialize from a ProgressEntry
    init(from progressEntry: ProgressEntry) {
        self.id = progressEntry.id
        self.date = progressEntry.date
        self.score = Int(progressEntry.quantity)
        self.notes = progressEntry.notes
    }

    /// Initialize directly (for convenience)
    init(id: UUID = UUID(), date: Date, score: Int, notes: String? = nil) {
        self.id = id
        self.date = date
        self.score = score
        self.notes = notes
    }
}

@Observable
final class MoodDetailViewModel {

    // MARK: - UI State

    enum TimeRange: String, CaseIterable, Identifiable {
        case last7Days = "7D"
        case last30Days = "30D"
        case last90Days = "90D"
        case lastYear = "1Y"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .last7Days: return MoodTrackingConstants.TimeRangeDays.week
            case .last30Days: return MoodTrackingConstants.TimeRangeDays.month
            case .last90Days: return MoodTrackingConstants.TimeRangeDays.quarter
            case .lastYear: return MoodTrackingConstants.TimeRangeDays.year
            }
        }

        var displayName: String {
            switch self {
            case .last7Days: return "Last 7 Days"
            case .last30Days: return "Last 30 Days"
            case .last90Days: return "Last 90 Days"
            case .lastYear: return "Last Year"
            }
        }

        /// Convert to MoodTimeRange for use case
        var toMoodTimeRange: MoodTimeRange {
            switch self {
            case .last7Days: return .last7Days
            case .last30Days: return .last30Days
            case .last90Days: return .last90Days
            case .lastYear: return .lastYear
            }
        }
    }

    var historicalData: [MoodRecord] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedRange: TimeRange = .last30Days  // Default to 30 days

    // MARK: - Dependencies

    private let getHistoricalMoodUseCase: GetHistoricalMoodUseCase

    // MARK: - Initialization

    init(getHistoricalMoodUseCase: GetHistoricalMoodUseCase) {
        self.getHistoricalMoodUseCase = getHistoricalMoodUseCase
        Task { await loadHistoricalData() }  // Load default data on init
    }

    // MARK: - Public Methods

    @MainActor
    func loadHistoricalData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Calculate date range based on selected time range
            let endDate = Date()
            let calendar = Calendar.current
            let startDate = calendar.date(
                byAdding: .day,
                value: -selectedRange.days,
                to: endDate
            ) ?? endDate

            // Fetch mood entries from repository using date range
            let progressEntries = try await getHistoricalMoodUseCase.execute(
                startDate: startDate,
                endDate: endDate
            )

            // Convert to MoodRecord for display
            self.historicalData = progressEntries.map { MoodRecord(from: $0) }

            print(
                "MoodDetailViewModel: Loaded \(historicalData.count) mood entries for \(selectedRange.displayName)"
            )

        } catch {
            print("MoodDetailViewModel: Failed to load mood history: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            historicalData = []
        }

        isLoading = false
    }

    /// Updates the selected time range and reloads data
    @MainActor
    func updateTimeRange(_ range: TimeRange) async {
        guard selectedRange != range else { return }
        selectedRange = range
        await loadHistoricalData()
    }

    /// Refreshes the current data
    @MainActor
    func refresh() async {
        await loadHistoricalData()
    }

    /// Clears any error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Computed Properties

    /// Average mood score for the current time range
    var averageMoodScore: Double? {
        guard !historicalData.isEmpty else { return nil }
        let sum = historicalData.reduce(0) { $0 + $1.score }
        return Double(sum) / Double(historicalData.count)
    }

    /// Highest mood score in the current time range
    var highestMoodScore: Int? {
        historicalData.map { $0.score }.max()
    }

    /// Lowest mood score in the current time range
    var lowestMoodScore: Int? {
        historicalData.map { $0.score }.min()
    }

    /// Most recent mood entry
    var latestMoodEntry: MoodRecord? {
        historicalData.max { $0.date < $1.date }
    }

    /// Check if there's any data available
    var hasData: Bool {
        !historicalData.isEmpty
    }

    /// Formatted average mood score for display
    var formattedAverageMoodScore: String {
        guard let average = averageMoodScore else { return "N/A" }
        return String(format: "%.1f", average)
    }

    /// Mood trend description based on recent data
    var moodTrend: String {
        guard historicalData.count >= 2 else { return "Not enough data" }

        // Compare first half vs second half of data
        let midpoint = historicalData.count / 2
        let firstHalf = Array(historicalData.prefix(midpoint))
        let secondHalf = Array(historicalData.suffix(historicalData.count - midpoint))

        let firstAvg = Double(firstHalf.reduce(0) { $0 + $1.score }) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.reduce(0) { $0 + $1.score }) / Double(secondHalf.count)

        let difference = secondAvg - firstAvg

        if abs(difference) < 0.5 {
            return "Stable"
        } else if difference > 0 {
            return "Improving"
        } else {
            return "Declining"
        }
    }
}
