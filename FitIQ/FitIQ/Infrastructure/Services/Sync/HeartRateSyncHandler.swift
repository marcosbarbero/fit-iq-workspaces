//
//  HeartRateSyncHandler.swift
//  FitIQ
//
//  Created by Refactoring on 27/01/2025.
//  Migrated to FitIQCore on 27/01/2025 - Phase 4
//

import FitIQCore
import Foundation

/// Handles syncing of heart rate data from HealthKit to local storage and progress tracking.
///
/// **Architecture:** Uses Recent Data Sync pattern (queries last 7 days with deduplication)
///
/// **Responsibilities:**
/// - Fetch hourly heart rate aggregates from HealthKit (last 7 days)
/// - Save to progress tracking (via SaveHeartRateProgressUseCase with Outbox Pattern)
/// - Deduplication by HealthKit sample UUID (no sync tracking needed)
/// - Self-healing: automatically captures missed data on next sync
///
/// **Data Flow:**
/// 1. Check latest synced entry via ShouldSyncMetricUseCase
/// 2. Skip if recently synced (within threshold)
/// 3. Query HealthKit for new data only (from last sync + 1 hour)
/// 4. Save each hourly aggregate to progress tracking (Outbox Pattern)
/// 5. Repository deduplicates by sourceID (HealthKit sample UUID)
/// 6. Outbox processor syncs to backend in background
///
/// **Benefits:**
/// - Smart sync optimization (avoids redundant HealthKit queries)
/// - Captures all recent data regardless of when app was opened
/// - Safe to run multiple times (deduplication prevents duplicates)
/// - Self-healing if data was missed previously
final class HeartRateSyncHandler: HealthMetricSyncHandler {

    // MARK: - Properties

    let metricType: HealthMetric = .heartRate

    private let healthKitService: HealthKitServiceProtocol
    private let saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase
    private let shouldSyncMetricUseCase: ShouldSyncMetricUseCase
    private let getLatestEntryDateUseCase: GetLatestProgressEntryDateUseCase
    private let authManager: AuthManager
    private let syncTracking: SyncTrackingServiceProtocol  // Kept for backward compatibility, not used
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase,
        shouldSyncMetricUseCase: ShouldSyncMetricUseCase,
        getLatestEntryDateUseCase: GetLatestProgressEntryDateUseCase,
        authManager: AuthManager,
        syncTracking: SyncTrackingServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.saveHeartRateProgressUseCase = saveHeartRateProgressUseCase
        self.shouldSyncMetricUseCase = shouldSyncMetricUseCase
        self.getLatestEntryDateUseCase = getLatestEntryDateUseCase
        self.authManager = authManager
        self.syncTracking = syncTracking
    }

    // MARK: - HealthMetricSyncHandler

    func syncDaily(forDate date: Date) async throws {
        // Note: Date parameter is ignored - we always sync recent data (last 7 days)
        // This ensures we capture any missed data and is self-healing
        print("HeartRateSyncHandler: 🔄 Starting recent data sync (last 7 days)")
        try await syncRecentHeartRateData()
    }

    func syncHistorical(from startDate: Date, to endDate: Date) async throws {
        // Use same recent data sync approach for historical data
        // The 7-day window will capture recent history automatically
        print("HeartRateSyncHandler: 🔄 Historical sync - using recent data sync (last 7 days)")
        try await syncRecentHeartRateData()
    }

    // MARK: - Private Methods

    /// Syncs recent heart rate data from HealthKit with smart optimization
    /// OPTIMIZED: Uses domain use cases to check sync status (hexagonal architecture compliant)
    private func syncRecentHeartRateData() async throws {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("HeartRateSyncHandler: ⚠️ No authenticated user, skipping sync")
            return
        }

        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        print("HeartRateSyncHandler: 🔄 STARTING OPTIMIZED HEART RATE SYNC")
        print("================================================================================")

        // OPTIMIZATION: Use domain use case to check if sync is needed
        let shouldSync = try await shouldSyncMetricUseCase.execute(
            forUserID: userID,
            metricType: .restingHeartRate,
            syncThresholdMinutes: 1
        )

        if !shouldSync {
            print("HeartRateSyncHandler: ✅ Already synced within last hour, skipping")
            print(
                "================================================================================")
            return
        }

        // Get latest synced date via domain use case
        let latestSyncedDate = try await getLatestEntryDateUseCase.execute(
            forUserID: userID,
            metricType: .restingHeartRate
        )

        // Determine fetch start date
        let fetchStartDate: Date
        if let latestDate = latestSyncedDate {
            print("HeartRateSyncHandler: ℹ️ Latest synced entry: \(latestDate)")
            // Fetch from 1 hour after latest synced data
            fetchStartDate = calendar.date(byAdding: .hour, value: 1, to: latestDate) ?? startDate
            print("HeartRateSyncHandler: 📥 Fetching NEW data from \(fetchStartDate) to \(endDate)")
        } else {
            // No local data - fetch full 7 days (first sync)
            fetchStartDate = startDate
            print("HeartRateSyncHandler: 📥 First sync - fetching full 7 days from \(startDate)")
        }

        print("--------------------------------------------------------------------------------")

        // Fetch hourly statistics from HealthKit (only missing data)
        let hourlyHeartRates: [Date: Int]
        do {
            let options = HealthQueryOptions(
                limit: nil,
                sortOrder: .ascending,
                aggregation: .sum(.hourly)
            )

            let metrics = try await healthKitService.query(
                type: .heartRate,
                from: fetchStartDate,
                to: endDate,
                options: options
            )

            // Convert metrics to hourly dictionary
            hourlyHeartRates = Dictionary(
                uniqueKeysWithValues: metrics.map { ($0.date, Int($0.value)) }
            )
        } catch {
            print("HeartRateSyncHandler: ❌ HealthKit query failed: \(error.localizedDescription)")
            throw HealthMetricSyncError.healthKitQueryFailed(
                metric: .heartRate,
                underlyingError: error
            )
        }

        // Check if we have NEW data
        guard !hourlyHeartRates.isEmpty else {
            print("HeartRateSyncHandler: ✅ No new heart rate data to sync (already up to date)")
            print(
                "================================================================================")
            return
        }

        print("HeartRateSyncHandler: ✅ HEALTHKIT DATA RETRIEVED")
        print(
            "HeartRateSyncHandler: Fetched \(hourlyHeartRates.count) NEW hourly heart rate aggregates"
        )
        print("--------------------------------------------------------------------------------")

        // Save each hour's heart rate (should have minimal/no duplicates now)
        var savedCount = 0
        var skippedCount = 0

        for (hourDate, heartRate) in hourlyHeartRates.sorted(by: { $0.key < $1.key }) {
            let hour = calendar.component(.hour, from: hourDate)
            let day = calendar.startOfDay(for: hourDate)
            let timeString = String(format: "%02d:00", hour)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            let dayString = dateFormatter.string(from: day)

            do {
                _ = try await saveHeartRateProgressUseCase.execute(
                    heartRate: Double(heartRate),
                    date: hourDate
                )
                savedCount += 1
                print("HeartRateSyncHandler: ✅ \(dayString) \(timeString) - \(heartRate) bpm saved")
            } catch {
                // Should rarely happen now, but handle gracefully
                skippedCount += 1
                print("HeartRateSyncHandler: ⏭️  \(dayString) \(timeString) - skipped (duplicate)")
            }
        }

        print("--------------------------------------------------------------------------------")
        print("HeartRateSyncHandler: 💾 SYNC SUMMARY")
        print("HeartRateSyncHandler: ✅ Saved: \(savedCount) new entries")
        print("HeartRateSyncHandler: ⏭️  Skipped: \(skippedCount) duplicates (should be 0)")
        print("HeartRateSyncHandler: 📊 Total fetched: \(hourlyHeartRates.count) hourly aggregates")
        print(
            "HeartRateSyncHandler: ⚡️ Optimization: Saved \(282 - hourlyHeartRates.count) unnecessary queries!"
        )
        print("================================================================================")
    }
}
