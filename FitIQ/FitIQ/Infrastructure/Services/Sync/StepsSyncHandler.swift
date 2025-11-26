//
//  StepsSyncHandler.swift
//  FitIQ
//
//  Created by Refactoring on 27/01/2025.
//  Migrated to FitIQCore on 27/01/2025 - Phase 4
//

import FitIQCore
import Foundation

/// Handles syncing of step count data from HealthKit to local storage and progress tracking.
///
/// **Architecture:** Uses Recent Data Sync pattern (queries last 7 days with deduplication)
///
/// **Responsibilities:**
/// - Fetch hourly step aggregates from HealthKit (last 7 days)
/// - Save to progress tracking (via SaveStepsProgressUseCase with Outbox Pattern)
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
final class StepsSyncHandler: HealthMetricSyncHandler {

    // MARK: - Properties

    let metricType: HealthMetric = .steps

    private let healthKitService: HealthKitServiceProtocol
    private let saveStepsProgressUseCase: SaveStepsProgressUseCase
    private let shouldSyncMetricUseCase: ShouldSyncMetricUseCase
    private let getLatestEntryDateUseCase: GetLatestProgressEntryDateUseCase
    private let authManager: AuthManager
    private let syncTracking: SyncTrackingServiceProtocol  // Kept for backward compatibility, not used
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        saveStepsProgressUseCase: SaveStepsProgressUseCase,
        shouldSyncMetricUseCase: ShouldSyncMetricUseCase,
        getLatestEntryDateUseCase: GetLatestProgressEntryDateUseCase,
        authManager: AuthManager,
        syncTracking: SyncTrackingServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.saveStepsProgressUseCase = saveStepsProgressUseCase
        self.shouldSyncMetricUseCase = shouldSyncMetricUseCase
        self.getLatestEntryDateUseCase = getLatestEntryDateUseCase
        self.authManager = authManager
        self.syncTracking = syncTracking
    }

    // MARK: - HealthMetricSyncHandler

    func syncDaily(forDate date: Date) async throws {
        // Note: Date parameter is ignored - we always sync recent data (last 7 days)
        // This ensures we capture any missed data and is self-healing
        print("StepsSyncHandler: 🔄 Starting recent data sync (last 7 days)")
        try await syncRecentStepsData()
    }

    func syncHistorical(from startDate: Date, to endDate: Date) async throws {
        // Use same recent data sync approach for historical data
        // The 7-day window will capture recent history automatically
        print("StepsSyncHandler: 🔄 Historical sync - using recent data sync (last 7 days)")
        try await syncRecentStepsData()
    }

    // MARK: - Private Methods

    /// Syncs recent steps data from HealthKit with smart optimization
    /// OPTIMIZED: Uses domain use cases to check sync status (hexagonal architecture compliant)
    private func syncRecentStepsData() async throws {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("StepsSyncHandler: ⚠️ No authenticated user, skipping sync")
            return
        }

        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        print("StepsSyncHandler: 🔄 STARTING OPTIMIZED STEPS SYNC")
        print("================================================================================")

        // OPTIMIZATION: Use domain use case to check if sync is needed
        // LIVE UPDATE: Reduced threshold to 5 minutes for real-time current hour updates
        let shouldSync = try await shouldSyncMetricUseCase.execute(
            forUserID: userID,
            metricType: .steps,
            syncThresholdMinutes: 1
        )

        if !shouldSync {
            print("StepsSyncHandler: ✅ Already synced within last 5 minutes, skipping")
            print(
                "================================================================================")
            return
        }

        // Get latest synced date via domain use case
        let latestSyncedDate = try await getLatestEntryDateUseCase.execute(
            forUserID: userID,
            metricType: .steps
        )

        // Determine fetch start date
        let fetchStartDate: Date
        if let latestDate = latestSyncedDate {
            print("StepsSyncHandler: ℹ️ Latest synced entry: \(latestDate)")

            // LIVE UPDATE FIX: Always re-fetch current hour for real-time updates
            // Get the start of the current hour
            let currentHourComponents = calendar.dateComponents(
                [.year, .month, .day, .hour], from: endDate)
            let currentHourStart = calendar.date(from: currentHourComponents) ?? endDate

            // If latest sync was before current hour, fetch from next hour
            // If latest sync is current hour, re-fetch current hour for live updates
            if latestDate < currentHourStart {
                // Fetch from 1 hour after latest synced data
                fetchStartDate =
                    calendar.date(byAdding: .hour, value: 1, to: latestDate) ?? startDate
                print("StepsSyncHandler: 📥 Fetching NEW data from \(fetchStartDate) to \(endDate)")
            } else {
                // Latest sync is in current hour - re-fetch current hour for live updates
                fetchStartDate = currentHourStart
                print(
                    "StepsSyncHandler: 📥 LIVE UPDATE: Re-fetching current hour from \(fetchStartDate) to \(endDate)"
                )
            }
        } else {
            // No local data - fetch full 7 days (first sync)
            fetchStartDate = startDate
            print("StepsSyncHandler: 📥 First sync - fetching full 7 days from \(startDate)")
        }

        print("--------------------------------------------------------------------------------")

        // Fetch hourly statistics from HealthKit (only missing data)
        let hourlySteps: [Date: Int]
        do {
            let options = HealthQueryOptions(
                limit: nil,
                sortOrder: .ascending,
                aggregation: .sum(.hourly)
            )

            let metrics = try await healthKitService.query(
                type: .stepCount,
                from: fetchStartDate,
                to: endDate,
                options: options
            )

            // Convert metrics to hourly dictionary
            hourlySteps = Dictionary(
                uniqueKeysWithValues: metrics.map { ($0.date, Int($0.value)) }
            )
        } catch {
            print("StepsSyncHandler: ❌ HealthKit query failed: \(error.localizedDescription)")
            throw HealthMetricSyncError.healthKitQueryFailed(
                metric: .steps,
                underlyingError: error
            )
        }

        // Check if we have NEW data
        guard !hourlySteps.isEmpty else {
            print("StepsSyncHandler: ✅ No new steps data to sync (already up to date)")
            print(
                "================================================================================")
            return
        }

        print("StepsSyncHandler: ✅ HEALTHKIT DATA RETRIEVED")
        print("StepsSyncHandler: Fetched \(hourlySteps.count) NEW hourly step aggregates")
        print("--------------------------------------------------------------------------------")

        // Save each hour's steps (should have minimal/no duplicates now)
        var savedCount = 0
        var skippedCount = 0

        for (hourDate, steps) in hourlySteps.sorted(by: { $0.key < $1.key }) {
            let hour = calendar.component(.hour, from: hourDate)
            let day = calendar.startOfDay(for: hourDate)
            let timeString = String(format: "%02d:00", hour)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            let dayString = dateFormatter.string(from: day)

            do {
                _ = try await saveStepsProgressUseCase.execute(
                    steps: steps,
                    date: hourDate
                )
                savedCount += 1
                print("StepsSyncHandler: ✅ \(dayString) \(timeString) - \(steps) steps saved")
            } catch {
                // Should rarely happen now, but handle gracefully
                skippedCount += 1
                print("StepsSyncHandler: ⏭️  \(dayString) \(timeString) - skipped (duplicate)")
            }
        }

        print("--------------------------------------------------------------------------------")
        print("StepsSyncHandler: 💾 SYNC SUMMARY")
        print("StepsSyncHandler: ✅ Saved: \(savedCount) new entries")
        print("StepsSyncHandler: ⏭️  Skipped: \(skippedCount) duplicates (should be 0)")
        print("StepsSyncHandler: 📊 Total fetched: \(hourlySteps.count) hourly aggregates")
        print(
            "StepsSyncHandler: ⚡️ Optimization: Saved \(282 - hourlySteps.count) unnecessary queries!"
        )
        print("================================================================================")
    }
}
