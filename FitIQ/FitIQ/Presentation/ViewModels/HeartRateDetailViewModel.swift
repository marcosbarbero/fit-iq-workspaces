//
//  HeartRateDetailViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import Observation

/// Represents a heart rate record for display in the UI
struct HeartRateRecord: Identifiable {
    let id: UUID
    let date: Date
    let heartRate: Double  // BPM (beats per minute)
    let notes: String?
    let time: String?

    /// Initialize from a ProgressEntry
    init(from progressEntry: ProgressEntry) {
        self.id = progressEntry.id
        self.date = progressEntry.date
        self.heartRate = progressEntry.quantity
        self.notes = progressEntry.notes
        self.time = progressEntry.time
    }

    /// Initialize directly (for convenience)
    init(
        id: UUID = UUID(), date: Date, heartRate: Double, notes: String? = nil, time: String? = nil
    ) {
        self.id = id
        self.date = date
        self.heartRate = heartRate
        self.notes = notes
        self.time = time
    }

    /// Formatted heart rate for display
    var formattedHeartRate: String {
        "\(Int(heartRate))"
    }
}

@Observable
final class HeartRateDetailViewModel {

    // MARK: - UI State

    enum TimeRange: String, CaseIterable, Identifiable {
        case hour = "H"
        case day = "D"
        case week = "W"
        case month = "M"
        case sixMonths = "6M"
        case year = "Y"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .hour: return "This Hour"
            case .day: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            case .sixMonths: return "Last 6 Months"
            case .year: return "Last Year"
            }
        }
    }

    var historicalData: [HeartRateRecord] = []
    var aggregatedData: [(date: Date, heartRate: Double, label: String)] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedRange: TimeRange = .day  // Default to day

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
        // Data will be loaded when the view appears via .onAppear in HeartRateDetailView
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

            // Calculate start date based on selected range
            let startDate: Date
            switch selectedRange {
            case .hour:
                // Current hour only
                startDate = calendar.date(bySetting: .minute, value: 0, of: endDate)!
            case .day:
                startDate = calendar.startOfDay(for: endDate)
            case .week:
                startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            case .month:
                startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            case .sixMonths:
                startDate = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
            case .year:
                startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
            }

            print(
                "HeartRateDetailViewModel: Fetching heart rate data from \(startDate) to \(endDate)"
            )

            // Fetch heart rate entries from progress repository
            // Use optimized fetchRecent to avoid full table scan
            let filteredEntries = try await progressRepository.fetchRecent(
                forUserID: userID,
                type: .restingHeartRate,
                startDate: startDate,
                endDate: endDate,
                limit: 1000  // Reasonable limit for detail view
            )

            historicalData =
                filteredEntries
                .sorted { $0.date > $1.date }  // Most recent first
                .map { HeartRateRecord(from: $0) }

            // Prepare aggregated data for charts
            prepareAggregatedData()

            print(
                "HeartRateDetailViewModel: Loaded \(historicalData.count) heart rate records"
            )

            isLoading = false
        } catch {
            print(
                "HeartRateDetailViewModel: Error loading heart rate data: \(error.localizedDescription)"
            )
            errorMessage = "Failed to load heart rate data: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Data Aggregation

    private func prepareAggregatedData() {
        let calendar = Calendar.current

        switch selectedRange {
        case .hour:
            // For hour view, show 15-minute intervals (4 quadrants)
            let currentHour = calendar.component(.hour, from: Date())
            let hourStart = calendar.date(bySetting: .minute, value: 0, of: Date())!

            // Group by 15-minute intervals
            var intervalData: [Date: [Double]] = [:]

            for record in historicalData {
                let minute = calendar.component(.minute, from: record.date)
                let interval = (minute / 15) * 15
                if let intervalStart = calendar.date(
                    bySettingHour: currentHour, minute: interval, second: 0, of: record.date)
                {
                    intervalData[intervalStart, default: []].append(record.heartRate)
                }
            }

            // Create 4 intervals (0, 15, 30, 45)
            var hourlyData: [(date: Date, heartRate: Double, label: String)] = []
            for interval in stride(from: 0, to: 60, by: 15) {
                if let intervalDate = calendar.date(
                    bySettingHour: currentHour, minute: interval, second: 0, of: Date())
                {
                    if let values = intervalData[intervalDate], !values.isEmpty {
                        let avg = values.reduce(0, +) / Double(values.count)
                        hourlyData.append(
                            (
                                intervalDate, avg,
                                "\(currentHour):\(String(format: "%02d", interval))"
                            ))
                    } else {
                        hourlyData.append(
                            (intervalDate, 0, "\(currentHour):\(String(format: "%02d", interval))"))
                    }
                }
            }
            aggregatedData = hourlyData

        case .day:
            // For day view, show hourly data
            let todayStart = calendar.startOfDay(for: Date())
            let todayEntries = historicalData.filter { entry in
                calendar.isDateInToday(entry.date) && entry.time != nil
            }

            var hourlyData: [Int: [Double]] = [:]
            for entry in todayEntries {
                let hour = calendar.component(.hour, from: entry.date)
                hourlyData[hour, default: []].append(entry.heartRate)
            }

            var dayData: [(date: Date, heartRate: Double, label: String)] = []
            for hour in 0..<24 {
                if let hourDate = calendar.date(byAdding: .hour, value: hour, to: todayStart) {
                    if let values = hourlyData[hour], !values.isEmpty {
                        let avg = values.reduce(0, +) / Double(values.count)
                        dayData.append((hourDate, avg, "\(hour):00"))
                    } else {
                        dayData.append((hourDate, 0, "\(hour):00"))
                    }
                }
            }
            aggregatedData = dayData

        case .week, .month:
            // For week/month, show daily data
            aggregatedData = historicalData.map {
                let formatter = DateFormatter()
                formatter.dateFormat = selectedRange == .week ? "EEE" : "d"
                return ($0.date, $0.heartRate, formatter.string(from: $0.date))
            }.reversed()

        case .sixMonths, .year:
            // For 6M/Y, show monthly averages
            var monthlyData: [Date: [Double]] = [:]
            for record in historicalData {
                let monthStart =
                    calendar.dateInterval(of: .month, for: record.date)?.start ?? record.date
                monthlyData[monthStart, default: []].append(record.heartRate)
            }

            aggregatedData = monthlyData.map {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                let avg = $0.value.reduce(0, +) / Double($0.value.count)
                return ($0.key, avg, formatter.string(from: $0.key))
            }.sorted { $0.date < $1.date }
        }
    }

    @MainActor
    func selectRange(_ range: TimeRange) {
        selectedRange = range
        Task { await loadHistoricalData() }
    }

    // MARK: - Computed Statistics

    /// Average heart rate for the selected range
    var averageHeartRate: Double? {
        guard !historicalData.isEmpty else { return nil }
        let sum = historicalData.reduce(0.0) { $0 + $1.heartRate }
        return sum / Double(historicalData.count)
    }

    /// Minimum heart rate in the selected range
    var minHeartRate: Double? {
        historicalData.map { $0.heartRate }.min()
    }

    /// Maximum heart rate in the selected range
    var maxHeartRate: Double? {
        historicalData.map { $0.heartRate }.max()
    }

    /// Formatted average heart rate for display
    var formattedAverageHeartRate: String {
        guard let avg = averageHeartRate else { return "--" }
        return "\(Int(avg))"
    }

    /// Formatted min heart rate for display
    var formattedMinHeartRate: String {
        guard let min = minHeartRate else { return "--" }
        return "\(Int(min))"
    }

    /// Formatted max heart rate for display
    var formattedMaxHeartRate: String {
        guard let max = maxHeartRate else { return "--" }
        return "\(Int(max))"
    }

    /// Heart rate trend (increasing, decreasing, or stable)
    var trend: String {
        guard historicalData.count >= 2 else { return "Insufficient data" }

        // Compare average of first half vs second half
        let midpoint = historicalData.count / 2
        let recentData = historicalData.prefix(midpoint)
        let olderData = historicalData.suffix(historicalData.count - midpoint)

        let recentAvg = recentData.reduce(0.0) { $0 + $1.heartRate } / Double(recentData.count)
        let olderAvg = olderData.reduce(0.0) { $0 + $1.heartRate } / Double(olderData.count)

        let difference = recentAvg - olderAvg

        if difference > 2.0 {
            return "Increasing"
        } else if difference < -2.0 {
            return "Decreasing"
        } else {
            return "Stable"
        }
    }

    /// Whether we have enough data to show meaningful statistics
    var hasEnoughData: Bool {
        historicalData.count >= 3
    }

    /// Empty state message
    var emptyStateMessage: String {
        "No heart rate data available for \(selectedRange.displayName.lowercased())"
    }

    /// Latest heart rate reading
    var latestHeartRate: Double? {
        historicalData.first?.heartRate
    }

    /// Formatted latest heart rate
    var formattedLatestHeartRate: String {
        guard let latest = latestHeartRate else { return "--" }
        return "\(Int(latest))"
    }

    /// Last recorded time for heart rate
    var lastRecordedTime: String {
        guard let latest = historicalData.first else { return "No data" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: latest.date)
    }

    /// Last 8 hours of heart rate data for summary card
    var last8HoursData: [(hour: Int, heartRate: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        let last8HoursStart = calendar.date(byAdding: .hour, value: -7, to: now)!
        let recentEntries = historicalData.filter { $0.date >= last8HoursStart && $0.time != nil }

        print(
            "HeartRateDetailViewModel.last8HoursData: Total historical data count: \(historicalData.count)"
        )
        print(
            "HeartRateDetailViewModel.last8HoursData: Filtered recent entries (last 8 hours with time): \(recentEntries.count)"
        )
        print("HeartRateDetailViewModel.last8HoursData: Current hour: \(currentHour)")

        var hourlyData: [Int: [Double]] = [:]
        for entry in recentEntries {
            let hour = calendar.component(.hour, from: entry.date)
            hourlyData[hour, default: []].append(entry.heartRate)
            print(
                "HeartRateDetailViewModel.last8HoursData: Entry at hour \(hour): \(entry.heartRate) bpm, time: \(entry.time ?? "nil"), date: \(entry.date)"
            )
        }

        var result: [(hour: Int, heartRate: Int)] = []
        for i in 0..<8 {
            let hour = (currentHour - 7 + i + 24) % 24
            if let values = hourlyData[hour], !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                result.append((hour: hour, heartRate: Int(avg)))
                print(
                    "HeartRateDetailViewModel.last8HoursData: Hour \(hour): \(Int(avg)) bpm (from \(values.count) values)"
                )
            } else {
                result.append((hour: hour, heartRate: 0))
                print("HeartRateDetailViewModel.last8HoursData: Hour \(hour): 0 bpm (no data)")
            }
        }
        print("HeartRateDetailViewModel.last8HoursData: Final result count: \(result.count)")
        return result
    }

    /// Chart data for display
    var chartData: [(date: Date, heartRate: Double, label: String)] {
        aggregatedData
    }
}
