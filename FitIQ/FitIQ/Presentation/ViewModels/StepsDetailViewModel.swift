//
//  StepsDetailViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import Observation

/// User's daily steps goal
struct StepsGoal {
    let dailyTarget: Int

    static let `default` = StepsGoal(dailyTarget: 10000)
}

/// Represents a steps record for display in the UI
struct StepsRecord: Identifiable {
    let id: UUID
    let date: Date
    let steps: Int
    let notes: String?
    let time: String?

    /// Initialize from a ProgressEntry
    init(from progressEntry: ProgressEntry) {
        self.id = progressEntry.id
        self.date = progressEntry.date
        self.steps = Int(progressEntry.quantity)
        self.notes = progressEntry.notes
        self.time = progressEntry.time
    }

    /// Initialize directly (for convenience)
    init(id: UUID = UUID(), date: Date, steps: Int, notes: String? = nil, time: String? = nil) {
        self.id = id
        self.date = date
        self.steps = steps
        self.notes = notes
        self.time = time
    }

    /// Formatted steps for display
    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
}

@Observable
final class StepsDetailViewModel {

    // MARK: - UI State

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonths = "6M"
        case year = "Y"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .sixMonths: return 180
            case .year: return 365
            }
        }

        var displayName: String {
            switch self {
            case .day: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            case .sixMonths: return "Last 6 Months"
            case .year: return "Last Year"
            }
        }

        var periodLabel: String {
            switch self {
            case .day: return "today"
            case .week: return "per day"
            case .month: return "per day"
            case .sixMonths: return "per day"
            case .year: return "per day"
            }
        }
    }

    var historicalData: [StepsRecord] = []
    var aggregatedData: [(date: Date, steps: Int, label: String)] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedRange: TimeRange = .week  // Default to week

    // MARK: - Goal
    var stepsGoal: StepsGoal? = nil  // Will be nil until user sets a goal

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
        // NOTE: Data loading removed from init to prevent fetching all entries on app start
        // Data will be loaded when the view appears via .onAppear in StepsDetailView
    }

    // MARK: - Public Methods

    @MainActor
    func loadHistoricalData() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userID = authManager.currentUserProfileID?.uuidString else {
                errorMessage = "User not authenticated"
                isLoading = false
                return
            }

            let calendar = Calendar.current
            let endDate = Date()

            // For day view, get start of today; for others, go back N days
            let startDate: Date
            if selectedRange == .day {
                startDate = calendar.startOfDay(for: endDate)
            } else {
                startDate =
                    calendar.date(
                        byAdding: .day,
                        value: -selectedRange.days,
                        to: endDate
                    ) ?? endDate
            }

            print(
                "StepsDetailViewModel: Fetching steps data from \(startDate) to \(endDate)"
            )

            // Fetch steps entries from progress repository
            // Use optimized fetchRecent to avoid full table scan
            let filteredEntries = try await progressRepository.fetchRecent(
                forUserID: userID,
                type: .steps,
                startDate: startDate,
                endDate: endDate,
                limit: 1000  // Reasonable limit for detail view
            )

            // For day view, keep all entries (including hourly)
            // For other views, deduplicate by day
            if selectedRange == .day {
                // Keep all entries for hourly breakdown
                historicalData =
                    filteredEntries
                    .map { StepsRecord(from: $0) }
                    .sorted { $0.date > $1.date }
            } else {
                // Group by date (start of day) and keep the entry with highest steps for each day
                var entriesByDay: [Date: ProgressEntry] = [:]
                for entry in filteredEntries {
                    let dayStart = calendar.startOfDay(for: entry.date)
                    if let existing = entriesByDay[dayStart] {
                        // Keep the entry with more steps (or newer if same)
                        let entryUpdated = entry.updatedAt ?? entry.createdAt
                        let existingUpdated = existing.updatedAt ?? existing.createdAt
                        let hasMoreSteps = entry.quantity > existing.quantity
                        let sameStepsButNewer =
                            entry.quantity == existing.quantity && entryUpdated > existingUpdated

                        if hasMoreSteps || sameStepsButNewer {
                            entriesByDay[dayStart] = entry
                        }
                    } else {
                        entriesByDay[dayStart] = entry
                    }
                }

                // Convert to StepsRecord and sort
                historicalData = entriesByDay.values
                    .map { StepsRecord(from: $0) }
                    .sorted { $0.date > $1.date }  // Most recent first
            }

            // Prepare aggregated data based on time range
            prepareAggregatedData()

            print(
                "StepsDetailViewModel: Loaded \(historicalData.count) unique days of steps records"
            )

            isLoading = false
        } catch {
            print(
                "StepsDetailViewModel: Error loading steps data: \(error.localizedDescription)"
            )
            errorMessage = "Failed to load steps data: \(error.localizedDescription)"
            isLoading = false
        }
    }

    @MainActor
    func selectRange(_ range: TimeRange) {
        selectedRange = range
        Task { await loadHistoricalData() }
    }

    // MARK: - Data Aggregation

    private func prepareAggregatedData() {
        let calendar = Calendar.current

        switch selectedRange {
        case .day:
            // For day view, fetch actual hourly steps data from progress entries
            // Each bar shows steps taken DURING that specific hour (not cumulative)
            let todayStart = calendar.startOfDay(for: Date())
            let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!

            // Fetch all progress entries for today
            let todayEntries = historicalData.filter { entry in
                entry.date >= todayStart && entry.date < todayEnd
            }

            print("StepsDetailViewModel: Found \(todayEntries.count) total entries for today")

            // Filter to only hourly entries (those with time component)
            // This prevents mixing old daily totals (without time) with new hourly data (with time)
            let hourlyEntries = todayEntries.filter { entry in
                entry.time != nil
            }

            let dailyEntries = todayEntries.filter { entry in
                entry.time == nil
            }

            print("StepsDetailViewModel: \(hourlyEntries.count) hourly entries (with time)")
            print("StepsDetailViewModel: \(dailyEntries.count) daily entries (without time)")

            if !dailyEntries.isEmpty {
                let dailyTotal = dailyEntries.reduce(0) { $0 + $1.steps }
                print(
                    "StepsDetailViewModel: ⚠️ WARNING: Found old daily entries totaling \(dailyTotal) steps - these are being excluded from hourly chart"
                )
            }

            // Group entries by hour
            var hourlySteps: [Int: Int] = [:]  // hour -> steps

            for entry in hourlyEntries {
                let hour = calendar.component(.hour, from: entry.date)
                let existingSteps = hourlySteps[hour] ?? 0
                hourlySteps[hour, default: 0] += entry.steps
                print(
                    "StepsDetailViewModel: Hour \(hour): adding \(entry.steps) steps (was \(existingSteps), now \(hourlySteps[hour]!))"
                )
            }

            let totalHourlySteps = hourlySteps.values.reduce(0, +)
            print("StepsDetailViewModel: Total steps from hourly entries: \(totalHourlySteps)")

            // Create hourly breakdown for all 24 hours
            var hourlyData: [(date: Date, steps: Int, label: String)] = []

            for hour in 0..<24 {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: todayStart) {
                    let steps = hourlySteps[hour] ?? 0
                    hourlyData.append((hourDate, steps, "\(hour):00"))
                }
            }

            aggregatedData = hourlyData

        case .week:
            // Show daily data for the week (7 bars, filling missing days with 0)
            // X-axis: Day of week (Mon, Tue, Wed...), Y-axis: Steps
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate

            var dailySteps: [Date: Int] = [:]
            for record in historicalData {
                let dayStart = calendar.startOfDay(for: record.date)
                dailySteps[dayStart] = record.steps
            }

            // Create array of last 7 days
            var weekData: [(date: Date, steps: Int, label: String)] = []
            for dayOffset in 0..<7 {
                if let day = calendar.date(
                    byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: startDate))
                {
                    let steps = dailySteps[day] ?? 0
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE"
                    weekData.append((day, steps, formatter.string(from: day)))
                }
            }
            aggregatedData = weekData

        case .month:
            // Show daily data for the month (~30 bars, filling missing days with 0)
            // X-axis: Day number, Y-axis: Steps
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -29, to: endDate) ?? endDate

            var dailySteps: [Date: Int] = [:]
            for record in historicalData {
                let dayStart = calendar.startOfDay(for: record.date)
                dailySteps[dayStart] = record.steps
            }

            // Create array of last 30 days
            var monthData: [(date: Date, steps: Int, label: String)] = []
            for dayOffset in 0..<30 {
                if let day = calendar.date(
                    byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: startDate))
                {
                    let steps = dailySteps[day] ?? 0
                    let dayNumber = calendar.component(.day, from: day)
                    monthData.append((day, steps, "\(dayNumber)"))
                }
            }
            aggregatedData = monthData

        case .sixMonths:
            // Aggregate by month (6 bars, showing average steps per day for each month)
            // X-axis: Month name, Y-axis: Average steps per day
            let endDate = Date()
            let startDate = calendar.date(byAdding: .month, value: -5, to: endDate) ?? endDate

            var monthlyData: [Date: (totalSteps: Int, daysCount: Int)] = [:]
            for record in historicalData {
                let monthStart =
                    calendar.dateInterval(of: .month, for: record.date)?.start ?? record.date
                if var existing = monthlyData[monthStart] {
                    existing.totalSteps += record.steps
                    existing.daysCount += 1
                    monthlyData[monthStart] = existing
                } else {
                    monthlyData[monthStart] = (totalSteps: record.steps, daysCount: 1)
                }
            }

            // Create array of last 6 months with 0 for months with no data
            var sixMonthData: [(date: Date, steps: Int, label: String)] = []
            for monthOffset in 0..<6 {
                if let month = calendar.date(
                    byAdding: .month, value: monthOffset,
                    to: calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate)
                {
                    let avgSteps: Int
                    if let data = monthlyData[month] {
                        avgSteps = data.totalSteps / data.daysCount
                    } else {
                        avgSteps = 0
                    }
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM"
                    sixMonthData.append((month, avgSteps, formatter.string(from: month)))
                }
            }
            aggregatedData = sixMonthData

        case .year:
            // Show last 12 months (12 bars, showing average steps per day for each month)
            // X-axis: Month name, Y-axis: Average steps per day
            let endDate = Date()
            let startDate = calendar.date(byAdding: .month, value: -11, to: endDate) ?? endDate

            var monthlyData: [Date: (totalSteps: Int, daysCount: Int)] = [:]
            for record in historicalData {
                let monthStart =
                    calendar.dateInterval(of: .month, for: record.date)?.start ?? record.date
                if var existing = monthlyData[monthStart] {
                    existing.totalSteps += record.steps
                    existing.daysCount += 1
                    monthlyData[monthStart] = existing
                } else {
                    monthlyData[monthStart] = (totalSteps: record.steps, daysCount: 1)
                }
            }

            // Create array of last 12 months with 0 for months with no data
            var yearData: [(date: Date, steps: Int, label: String)] = []
            for monthOffset in 0..<12 {
                if let month = calendar.date(
                    byAdding: .month, value: monthOffset,
                    to: calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate)
                {
                    let avgSteps: Int
                    if let data = monthlyData[month] {
                        avgSteps = data.totalSteps / data.daysCount
                    } else {
                        avgSteps = 0
                    }
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM"
                    yearData.append((month, avgSteps, formatter.string(from: month)))
                }
            }
            aggregatedData = yearData
        }
    }

    // MARK: - Computed Statistics

    /// Total steps for the selected range
    var totalSteps: Int {
        historicalData.reduce(0) { $0 + $1.steps }
    }

    /// Average steps per day for the selected range (based on actual days with data)
    var averageSteps: Double? {
        guard !historicalData.isEmpty else { return nil }
        return Double(totalSteps) / Double(historicalData.count)
    }

    /// Average steps per period (day/week/month depending on aggregation)
    var averagePerPeriod: Double? {
        guard !aggregatedData.isEmpty else { return nil }
        let totalInPeriods = aggregatedData.reduce(0) { $0 + $1.steps }
        return Double(totalInPeriods) / Double(aggregatedData.count)
    }

    /// Minimum steps in a day in the selected range
    var minSteps: Int? {
        historicalData.map { $0.steps }.min()
    }

    /// Maximum steps in a day in the selected range
    var maxSteps: Int? {
        historicalData.map { $0.steps }.max()
    }

    /// Date range string for display
    var dateRangeString: String {
        guard let first = historicalData.last?.date, let last = historicalData.first?.date else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }

    /// Formatted average steps for display
    var formattedAverageSteps: String {
        guard let avg = averageSteps else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: avg)) ?? "\(Int(avg))"
    }

    /// Formatted min steps for display
    var formattedMinSteps: String {
        guard let min = minSteps else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: min)) ?? "\(min)"
    }

    /// Formatted max steps for display
    var formattedMaxSteps: String {
        guard let max = maxSteps else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: max)) ?? "\(max)"
    }

    /// Steps trend (increasing, decreasing, or stable)
    var trend: String {
        guard historicalData.count >= 2 else { return "Insufficient data" }

        // Compare average of first half vs second half
        let midpoint = historicalData.count / 2
        let recentData = historicalData.prefix(midpoint)
        let olderData = historicalData.suffix(historicalData.count - midpoint)

        let recentAvg = Double(recentData.reduce(0) { $0 + $1.steps }) / Double(recentData.count)
        let olderAvg = Double(olderData.reduce(0) { $0 + $1.steps }) / Double(olderData.count)

        let difference = recentAvg - olderAvg

        if difference > 500 {
            return "Increasing"
        } else if difference < -500 {
            return "Decreasing"
        } else {
            return "Stable"
        }
    }

    /// Days that met the steps goal (if goal is set)
    var daysMetGoal: Int {
        guard let goal = stepsGoal else { return 0 }
        return historicalData.filter { $0.steps >= goal.dailyTarget }.count
    }

    /// Percentage of days that met the goal (returns nil if no goal is set)
    var goalAchievementRate: Double? {
        guard stepsGoal != nil, !historicalData.isEmpty else { return nil }
        return Double(daysMetGoal) / Double(historicalData.count) * 100
    }

    /// Formatted goal achievement rate
    var formattedGoalRate: String {
        guard let rate = goalAchievementRate else { return "--" }
        return String(format: "%.0f%%", rate)
    }

    /// Chart data for display (uses aggregated data)
    var chartData: [(date: Date, steps: Int, label: String)] {
        aggregatedData.reversed()  // Oldest to newest for chart
    }

    /// Today's total steps count
    var todaySteps: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return historicalData.first { calendar.isDate($0.date, inSameDayAs: today) }?.steps ?? 0
    }

    /// Formatted today's steps
    var formattedTodaySteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: todaySteps)) ?? "\(todaySteps)"
    }

    /// Last 8 hours of movement data (for summary card)
    var last8HoursData: [(hour: Int, steps: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        // Calculate steps per hour based on today's total (distributed evenly as approximation)
        let todayData = historicalData.first { calendar.isDateInToday($0.date) }
        let todaySteps = todayData?.steps ?? 0

        // Approximate hourly distribution (in reality, we'd fetch this from HealthKit)
        let avgStepsPerHour = todaySteps > 0 ? todaySteps / max(currentHour, 1) : 0

        var hourlyData: [(hour: Int, steps: Int)] = []
        for i in 0..<8 {
            let hour = (currentHour - 7 + i + 24) % 24
            // Use approximation with some variation until real hourly data is available
            let steps =
                hour <= currentHour
                ? Int(Double(avgStepsPerHour) * Double.random(in: 0.7...1.3)) : 0
            hourlyData.append((hour: hour, steps: steps))
        }
        return hourlyData
    }

    /// Whether we have enough data to show meaningful statistics
    var hasEnoughData: Bool {
        historicalData.count >= 3
    }

    /// Empty state message
    var emptyStateMessage: String {
        "No steps data available for \(selectedRange.displayName.lowercased())"
    }

    /// Whether to show the goal line in the chart
    var shouldShowGoalLine: Bool {
        stepsGoal != nil
    }

    /// The goal threshold for display
    var goalThreshold: Int {
        stepsGoal?.dailyTarget ?? 10000
    }
}
