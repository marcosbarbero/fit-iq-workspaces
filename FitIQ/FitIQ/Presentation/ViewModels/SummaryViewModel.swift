import Combine
// Presentation/ViewModels/SummaryViewModel.swift
import Foundation
import Observation

/// ViewModel for SummaryView, responsible for fetching and presenting activity data.
@Observable
final class SummaryViewModel {
    private let getLatestBodyMetricsUseCase: GetLatestBodyMetricsUseCase
    private let getHistoricalWeightUseCase: GetHistoricalWeightUseCase  // Use new comprehensive use case (for detail view)
    let authManager: AuthManager  // To get the current user's ID
    private let getHistoricalMoodUseCase: GetHistoricalMoodUseCase  // NEW: For mood tracking
    private let getLatestHeartRateUseCase: GetLatestHeartRateUseCase  // NEW: For fetching latest heart rate
    private let processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol  // NEW: For manual sync

    // SUMMARY-SPECIFIC: Use cases for fetching only the data needed for summary cards
    private let getLast8HoursHeartRateUseCase: GetLast8HoursHeartRateUseCase  // NEW: For heart rate hourly graph
    private let getLast8HoursStepsUseCase: GetLast8HoursStepsUseCase  // NEW: For steps hourly graph
    private let getLast5WeightsForSummaryUseCase: GetLast5WeightsForSummaryUseCase  // NEW: For weight mini-graph
    private let getLatestSleepForSummaryUseCase: GetLatestSleepForSummaryUseCase  // NEW: For sleep tracking
    private let getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase  // NEW: For daily steps total from progress API
    private let localDataChangePublisher: LocalDataChangePublisherProtocol  // NEW: For live updates

    private var cancellables = Set<AnyCancellable>()  // To hold Combine subscriptions
    private var dataChangeCancellable: AnyCancellable?  // NEW: For local data change subscription

    var latestHealthMetrics: HealthMetricsSnapshot?  // New property for body metrics
    var historicalWeightData: [Double] = []  // NEW: Property to store historical weight for the graph
    var latestMoodScore: Int?  // NEW: Latest mood score
    var latestMoodDate: Date?  // NEW: Date of latest mood entry
    var latestHeartRate: Double?  // NEW: Latest heart rate in bpm
    var latestHeartRateDate: Date?  // NEW: Date of latest heart rate entry
    var latestSleepHours: Double?  // NEW: Latest sleep duration in hours
    var latestSleepEfficiency: Int?  // NEW: Latest sleep efficiency percentage
    var latestSleepDate: Date?  // NEW: Date of latest sleep session

    // SUMMARY-SPECIFIC: Hourly data for summary cards
    var last8HoursHeartRateData: [(hour: Int, heartRate: Int)] = []  // NEW: For heart rate summary card
    var last8HoursStepsData: [(hour: Int, steps: Int)] = []  // NEW: For steps summary card

    var isLoading: Bool = false
    var isSyncing: Bool = false  // NEW: Track background sync state
    private var isSubscriptionActive: Bool = false  // Control when to respond to events

    // Individual loading states for each metric
    var isLoadingSteps: Bool = false
    var isLoadingHeartRate: Bool = false
    var isLoadingWeight: Bool = false
    var isLoadingMood: Bool = false
    var isLoadingSleep: Bool = false

    // Steps data from progress API
    var stepsCount: Int?  // Changed to optional to preserve last value when no data
    var latestStepsTimestamp: Date?  // NEW: Track when latest steps data was captured

    // NEW: Track last refresh time for debugging
    var lastRefreshTime: Date = Date()
    var refreshCount: Int = 0
    
    // Mood display text for summary card
    var moodDisplayText: String {
        guard let score = latestMoodScore else { return "Not Logged" }
        switch score {
        case 1...3: return "Poor"
        case 4...5: return "Below Average"
        case 6: return "Neutral"
        case 7...8: return "Good"
        case 9...10: return "Excellent"
        default: return "Unknown"
        }
    }

    // Mood emoji for visual feedback
    var moodEmoji: String {
        guard let score = latestMoodScore else { return "😶" }
        switch score {
        case 1...3: return "😔"
        case 4...5: return "🙁"
        case 6: return "😐"
        case 7...8: return "😊"
        case 9...10: return "🤩"
        default: return "😶"
        }
    }

    init(
        getLatestBodyMetricsUseCase: GetLatestBodyMetricsUseCase,
        getHistoricalWeightUseCase: GetHistoricalWeightUseCase,
        authManager: AuthManager,
        getHistoricalMoodUseCase: GetHistoricalMoodUseCase,
        getLatestHeartRateUseCase: GetLatestHeartRateUseCase,
        getLast8HoursHeartRateUseCase: GetLast8HoursHeartRateUseCase,
        getLast8HoursStepsUseCase: GetLast8HoursStepsUseCase,
        getLast5WeightsForSummaryUseCase: GetLast5WeightsForSummaryUseCase,
        getLatestSleepForSummaryUseCase: GetLatestSleepForSummaryUseCase,
        getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase,  // NEW: Daily steps from progress API
        processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol,
        localDataChangePublisher: LocalDataChangePublisherProtocol  // NEW: For live updates
    ) {
        self.getLatestBodyMetricsUseCase = getLatestBodyMetricsUseCase
        self.getHistoricalWeightUseCase = getHistoricalWeightUseCase
        self.authManager = authManager
        self.processDailyHealthDataUseCase = processDailyHealthDataUseCase
        self.getHistoricalMoodUseCase = getHistoricalMoodUseCase
        self.getLatestHeartRateUseCase = getLatestHeartRateUseCase
        self.getLast8HoursHeartRateUseCase = getLast8HoursHeartRateUseCase
        self.getLast8HoursStepsUseCase = getLast8HoursStepsUseCase
        self.getLast5WeightsForSummaryUseCase = getLast5WeightsForSummaryUseCase
        self.getLatestSleepForSummaryUseCase = getLatestSleepForSummaryUseCase
        self.getDailyStepsTotalUseCase = getDailyStepsTotalUseCase
        self.localDataChangePublisher = localDataChangePublisher

        // Setup live data change subscription
        setupDataChangeSubscription()
    }

    // MARK: - Live Updates

    /// Sets up subscription to local data changes for live UI updates
    private func setupDataChangeSubscription() {
        print("SummaryViewModel: 🔔 Setting up live data change subscription")

        dataChangeCancellable = localDataChangePublisher.publisher
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)  // Debounce to avoid excessive refreshes
            .sink { [weak self] event in
                guard let self = self else { return }

                print(
                    "SummaryViewModel: 📡 Local data change event received - Type: \(event.modelType)"
                )

                // Refresh specific data based on what changed
                Task { @MainActor in
                    switch event.modelType {
                    case .progressEntry:
                        // Progress entry changed (steps, heart rate, weight, mood, etc.)
                        print(
                            "SummaryViewModel: 🔄 Progress entry changed, refreshing relevant metrics..."
                        )
                        await self.refreshProgressMetrics()

                    case .activitySnapshot:
                        // Activity snapshot changed
                        print("SummaryViewModel: 🔄 Activity snapshot changed, refreshing...")
                        await self.fetchLatestHealthMetrics()

                    case .physicalAttribute:
                        // Physical attribute changed (weight, height, etc.)
                        print("SummaryViewModel: 🔄 Physical attribute changed, refreshing...")
                        await self.fetchLatestHealthMetrics()
                        await self.fetchLast5WeightsForSummary()
                    }
                }
            }
    }

    /// Efficiently refreshes only progress-related metrics (steps, heart rate, weight, mood)
    @MainActor
    private func refreshProgressMetrics() async {
        refreshCount += 1
        lastRefreshTime = Date()
        let timeString = lastRefreshTime.formattedHourMinute()

        print("================================================================================")
        print("SummaryViewModel: ⚡️ REFRESH #\(refreshCount) STARTED at \(timeString)")
        print("  Current steps: \(stepsCount)")
        print("  Current HR data points: \(last8HoursHeartRateData.count)")
        print("  Current steps data points: \(last8HoursStepsData.count)")
        print("--------------------------------------------------------------------------------")

        // Refresh in parallel for speed
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchDailyStepsTotal() }
            group.addTask { await self.fetchLast8HoursSteps() }
            group.addTask { await self.fetchLatestHeartRate() }
            group.addTask { await self.fetchLast8HoursHeartRate() }
            group.addTask { await self.fetchLast5WeightsForSummary() }
            group.addTask { await self.fetchLatestMoodEntry() }
        }

        print("--------------------------------------------------------------------------------")
        print("SummaryViewModel: ✅ REFRESH #\(refreshCount) COMPLETE")
        print("  NEW steps: \(stepsCount)")
        print("  NEW HR data points: \(last8HoursHeartRateData.count)")
        print("  NEW steps data points: \(last8HoursStepsData.count)")
        print("  Time: \(timeString)")
        print("================================================================================")
    }

    /// Test method to manually trigger a notification event (for debugging)
    @MainActor
    func testNotification() {
        print("🧪 TEST: Manually triggering refresh (simulating data change event)")
        Task {
            await refreshProgressMetrics()
        }
    }

    /// Refreshes data by syncing from HealthKit first, then reloading
    /// Use this for pull-to-refresh or manual refresh actions
    @MainActor
    func refreshData() async {
        guard !isLoading && !isSyncing else {
            print("SummaryViewModel: ⏭️ Skipping refresh - already in progress")
            return
        }

        print("\n🔄 SummaryViewModel.refreshData() - Syncing from HealthKit...")
        isSyncing = true

        // Step 1: Sync fresh data from HealthKit
        do {
            try await processDailyHealthDataUseCase.execute()
            print("✅ HealthKit sync completed successfully")
        } catch {
            print("⚠️ HealthKit sync failed: \(error.localizedDescription)")
            // Continue to reload even if sync fails - show whatever data we have
        }

        isSyncing = false

        // Step 2: Reload all data from local storage
        await reloadAllData()

        print("✅ SummaryViewModel.refreshData() - Complete\n")
    }

    @MainActor
    func reloadAllData() async {
        let startTime = Date()

        print("\n🔄 SummaryViewModel.reloadAllData() - STARTING DATA LOAD")
        print(String(repeating: "=", count: 60))
        print("⏰ Start Time: \(startTime)")
        print("🔄 isLoading before: \(isLoading)")
        print("🔄 isSyncing before: \(isSyncing)")

        // CRITICAL: Disable event subscription during reload to prevent loops
        isSubscriptionActive = false
        isLoading = true  // Set loading state for the whole reload operation

        // Fetch all data in parallel for better performance
        // Now optimized with proper date range queries (no full table scans)
        print("\n⏱️  Starting parallel data fetch...")
        let fetchStartTime = Date()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let taskStart = Date()
                await self.fetchDailyStepsTotal()
                print("  ⏱️  fetchDailyStepsTotal: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLatestHealthMetrics()
                print("  ⏱️  fetchLatestHealthMetrics: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLast5WeightsForSummary()
                print("  ⏱️  fetchLast5WeightsForSummary: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLatestMoodEntry()
                print("  ⏱️  fetchLatestMoodEntry: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLatestHeartRate()
                print("  ⏱️  fetchLatestHeartRate: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLast8HoursHeartRate()
                print("  ⏱️  fetchLast8HoursHeartRate: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLast8HoursSteps()
                print("  ⏱️  fetchLast8HoursSteps: \(Date().timeIntervalSince(taskStart))s")
            }
            group.addTask {
                let taskStart = Date()
                await self.fetchLatestSleep()
                print("  ⏱️  fetchLatestSleep: \(Date().timeIntervalSince(taskStart))s")
            }
        }

        let fetchDuration = Date().timeIntervalSince(fetchStartTime)
        print("⏱️  Total parallel fetch time: \(fetchDuration)s")

        print("\n📊 DATA FETCH RESULTS:")
        print("📊 Activity: Steps=\(stepsCount), HeartRate=\(heartRateAvg?.description ?? "nil")")
        print(
            "⚖️  Weight: \(latestHealthMetrics?.weightKg?.description ?? "nil") kg, Height: \(latestHealthMetrics?.heightCm?.description ?? "nil") cm"
        )
        print("📈 Weight History: \(historicalWeightData.count) entries")
        print("😊 Mood: \(latestMoodScore?.description ?? "nil") (\(moodDisplayText))")
        print("❤️  Latest HR: \(latestHeartRate?.description ?? "nil") bpm")
        print("📊 Hourly HR: \(last8HoursHeartRateData.count) hours of data")
        print("👣 Hourly Steps: \(last8HoursStepsData.count) hours of data")
        print(
            "😴 Sleep: \(latestSleepHours?.description ?? "nil") hrs, Efficiency: \(latestSleepEfficiency?.description ?? "nil")%"
        )

        let totalDuration = Date().timeIntervalSince(startTime)
        print(String(repeating: "=", count: 60))
        print("✅ SummaryViewModel.reloadAllData() - COMPLETE")
        print("⏱️  TOTAL TIME: \(totalDuration)s")
        print(String(repeating: "=", count: 60))
        print()

        // REMOVED: syncStepsToProgressTracking() and syncHeartRateToProgressTracking()
        // These were causing infinite loops because they trigger SwiftData changes
        // which refresh the view, which triggers .onAppear again.
        // Syncing is handled by HealthDataSyncManager in the background.
        isLoading = false  // Reset loading state after all fetches

        // Re-enable event subscription after initial load completes
        isSubscriptionActive = true
    }

    /// Computed property to check if we should show initial loading state
    var shouldShowInitialLoading: Bool {
        return isLoading || isSyncing
    }

    /// Fetch daily steps total from progress repository (replaces ActivitySnapshot)
    @MainActor
    func fetchDailyStepsTotal() async {
        isLoadingSteps = true
        let oldSteps = stepsCount
        do {
            let today = Date()
            let result = try await getDailyStepsTotalUseCase.execute(forDate: today)
            stepsCount = result.totalSteps
            latestStepsTimestamp = result.latestTimestamp

            if stepsCount != oldSteps {
                let timeStr =
                    latestStepsTimestamp.map {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        return formatter.string(from: $0)
                    } ?? "unknown"
                print(
                    "SummaryViewModel: ✅ Fetched daily steps total: \(stepsCount ?? 0) (was \(oldSteps ?? 0), changed by \((stepsCount ?? 0) - (oldSteps ?? 0))) at \(timeStr) (real-time from HealthKit)"
                )
            } else {
                print(
                    "SummaryViewModel: ✅ Fetched daily steps total: \(stepsCount ?? 0) (no change)")
            }
        } catch {
            print(
                "SummaryViewModel: ❌ Error fetching daily steps total: \(error.localizedDescription)"
            )
            // Keep last value instead of resetting to 0 (matches heart rate behavior)
            // stepsCount and latestStepsTimestamp remain unchanged
        }
        isLoadingSteps = false
    }

    @MainActor
    func fetchLatestHealthMetrics() async {
        isLoadingWeight = true
        do {
            // No need for userID here, as GetLatestBodyMetricsUseCase doesn't take one
            latestHealthMetrics = try await getLatestBodyMetricsUseCase.execute()
            print(
                "SummaryViewModel: Fetched latest health metrics. Weight: \(latestHealthMetrics?.weightKg.map { String(format: "%.1f kg", $0) } ?? "N/A")"
            )
        } catch {
            print(
                "SummaryViewModel: Error fetching latest health metrics: \(error.localizedDescription)"
            )
            latestHealthMetrics = nil
        }
        isLoadingWeight = false
    }

    /// Fetch last 5 weights for summary card mini-graph
    @MainActor
    private func fetchLast5WeightsForSummary() async {
        do {
            historicalWeightData = try await getLast5WeightsForSummaryUseCase.execute()
            print(
                "SummaryViewModel: ✅ Fetched \(historicalWeightData.count) weight entries for summary mini-graph"
            )
        } catch {
            print(
                "SummaryViewModel: ❌ Error fetching weight data for summary - \(error.localizedDescription)"
            )
            historicalWeightData = []
        }
    }

    @MainActor
    /// Computed property for heart rate average from activity snapshot
    var heartRateAvg: Double? {
        latestHeartRate
    }

    /// Formatted latest heart rate for summary card
    var formattedLatestHeartRate: String {
        guard let hr = latestHeartRate else { return "--" }
        return "\(Int(hr))"
    }

    /// Last recorded time for heart rate summary card
    var lastHeartRateRecordedTime: String {
        guard let date = latestHeartRateDate else { return "No data" }
        return date.formattedHourMinute()
    }

    /// Formatted steps count for summary card (matches heart rate pattern)
    var formattedStepsCount: Int {
        return stepsCount ?? 0  // Show 0 if nil, but preserve nil state internally
    }

    /// Last recorded time for steps summary card
    var lastStepsRecordedTime: String {
        guard let date = latestStepsTimestamp else { return "No data" }
        return date.formattedHourMinute()
    }

    /// Fetches the latest mood entry from the last 7 days
    @MainActor
    private func fetchLatestMoodEntry() async {
        isLoadingMood = true
        do {
            // Fetch mood entries from last 7 days to get the most recent
            let entries = try await getHistoricalMoodUseCase.execute(
                startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())
                    ?? Date(),
                endDate: Date()
            )

            // 🔍 DEBUG: Log all fetched entries
            print("🔍 SummaryViewModel.fetchLatestMoodEntry() DEBUG:")
            print("   Total entries fetched: \(entries.count)")

            if !entries.isEmpty {
                print("   All entries:")
                for (index, entry) in entries.enumerated() {
                    let score = Int(entry.quantity)
                    let dateStr = DateFormatter.localizedString(
                        from: entry.date, dateStyle: .short, timeStyle: .short)
                    print(
                        "   [\(index)] Score: \(score), Date: \(dateStr), Notes: \(entry.notes ?? "none")"
                    )
                }
            }

            // Get the most recent entry
            if let latestEntry = entries.max(by: { $0.date < $1.date }) {
                latestMoodScore = Int(latestEntry.quantity)
                latestMoodDate = latestEntry.date

                // 🔍 DEBUG: Log selected entry details
                let displayText = moodDisplayText
                let emoji = moodEmoji
                print("   ✅ Selected latest entry:")
                print("      Score: \(latestMoodScore ?? 0)")
                print(
                    "      Date: \(DateFormatter.localizedString(from: latestEntry.date, dateStyle: .short, timeStyle: .short))"
                )
                print("      Display Text: \(displayText)")
                print("      Emoji: \(emoji)")
                print("      Raw Quantity: \(latestEntry.quantity)")
            } else {
                latestMoodScore = nil
                latestMoodDate = nil
                print("   ⚠️ No mood entries found in last 7 days")
            }
        } catch {
            print(
                "SummaryViewModel: ❌ Error fetching latest mood - \(error.localizedDescription)"
            )
            latestMoodScore = nil
            latestMoodDate = nil
        }
        isLoadingMood = false
    }

    // MARK: - Summary-Specific Data Loading

    /// Fetch last 8 hours of heart rate data for summary card
    @MainActor
    private func fetchLast8HoursHeartRate() async {
        isLoadingHeartRate = true
        do {
            last8HoursHeartRateData = try await getLast8HoursHeartRateUseCase.execute()
            print(
                "SummaryViewModel: ✅ Fetched \(last8HoursHeartRateData.count) hours of heart rate data for summary"
            )
        } catch {
            print(
                "SummaryViewModel: ❌ Error fetching hourly heart rate data - \(error.localizedDescription)"
            )
            last8HoursHeartRateData = []
        }
        isLoadingHeartRate = false
    }

    /// Fetch last 8 hours of steps data for summary card
    @MainActor
    private func fetchLast8HoursSteps() async {
        do {
            last8HoursStepsData = try await getLast8HoursStepsUseCase.execute()
            print(
                "SummaryViewModel: ✅ Fetched \(last8HoursStepsData.count) hours of steps data for summary"
            )
        } catch {
            print(
                "SummaryViewModel: ❌ Error fetching hourly steps data - \(error.localizedDescription)"
            )
            last8HoursStepsData = []
        }
    }

    /// Fetches the latest heart rate from progress tracking
    @MainActor
    private func fetchLatestHeartRate() async {
        do {
            // REAL-TIME: Fetch the most recent heart rate sample from HealthKit with exact timestamp
            if let result = try await getLatestHeartRateUseCase.execute(daysBack: 7) {
                latestHeartRate = result.heartRate
                latestHeartRateDate = result.timestamp
                let timeStr = result.timestamp.formattedHourMinute()
                print(
                    "SummaryViewModel: ✅ Latest heart rate: \(Int(result.heartRate)) bpm at \(timeStr) (real-time from HealthKit)"
                )
            } else {
                // Keep last value instead of resetting to nil
                print("SummaryViewModel: ⚠️ No recent heart rate data found in HealthKit")
            }
        } catch {
            print(
                "SummaryViewModel: ❌ Error fetching latest heart rate - \(error.localizedDescription)"
            )
            // Keep last value instead of resetting to nil
        }
    }

    /// Fetches the latest sleep data for summary display
    @MainActor
    private func fetchLatestSleep() async {
        isLoadingSleep = true
        do {
            let result = try await getLatestSleepForSummaryUseCase.execute()
            latestSleepHours = result.sleepHours
            latestSleepEfficiency = result.efficiency
            latestSleepDate = result.lastSleepDate

            if let hours = result.sleepHours, let efficiency = result.efficiency,
                let date = result.lastSleepDate
            {
                print(
                    "SummaryViewModel: ✅ Latest sleep SET: \(String(format: "%.2f", hours))h (\(hours * 60) mins), \(efficiency)% efficiency, date: \(date)"
                )
                print("SummaryViewModel: 🎯 Will display: '\(String(format: "%.1f", hours))h' in UI")
            } else {
                print("SummaryViewModel: ℹ️ No sleep data available (nil values)")
                print("  - sleepHours: \(result.sleepHours?.description ?? "nil")")
                print("  - efficiency: \(result.efficiency?.description ?? "nil")")
                print("  - lastSleepDate: \(result.lastSleepDate?.description ?? "nil")")
            }
        } catch {
            print("SummaryViewModel: ❌ Error fetching latest sleep - \(error.localizedDescription)")
            latestSleepHours = nil
            latestSleepEfficiency = nil
            latestSleepDate = nil
        }
        isLoadingSleep = false
    }
}
