//
//  SleepSyncHandler.swift
//  FitIQ
//
//  Created by Refactoring on 27/01/2025.
//  Updated by AI Assistant on 27/01/2025 - Hexagonal Architecture Compliance
//  Migrated to FitIQCore on 27/01/2025 - Phase 4
//

import FitIQCore
import Foundation
import HealthKit

/// Handles syncing of sleep data from HealthKit to local storage and progress tracking.
///
/// **Architecture:** Uses Recent Data Sync pattern with smart optimization
///
/// **Responsibilities:**
/// - Fetch sleep samples from HealthKit (optimized - only new data)
/// - Group samples into continuous sleep sessions
/// - Convert HealthKit sleep stages to domain models
/// - Calculate sleep metrics (efficiency, duration, etc.)
/// - Save to sleep repository (with Outbox Pattern)
/// - Deduplication by sourceID prevents duplicates
///
/// **Complexity:**
/// Sleep sync is more complex than other metrics because:
/// - Sleep sessions span multiple hours (often overnight, crossing calendar days)
/// - HealthKit provides multiple samples per session (one per stage)
/// - Need to group samples by source and time continuity
/// - Need to deduplicate sessions by sourceID
/// - Sleep sessions are attributed to the WAKE DATE (end date), not start date
/// - Query window must extend backward to capture sessions that started on previous day
///
/// **Sleep Attribution Logic:**
/// Sleep sessions are attributed to the date they END (wake date), following industry standard:
/// - Sleep from 10 PM Friday → 6 AM Saturday = Saturday's sleep
/// - Sleep from 2 AM → 10 AM Saturday = Saturday's sleep (late sleeper)
/// - Nap from 2 PM → 4 PM Saturday = Saturday's sleep (daytime nap)
///
/// **Optimized Query Strategy:**
/// 1. Check latest synced session date via ShouldSyncSleepUseCase
/// 2. Skip if synced within threshold (default: 6 hours)
/// 3. Query from latest session date - 24 hours (to catch overnight sessions)
/// 4. Filter sessions: only keep those that END after latest synced date
///
/// **Data Flow:**
/// 1. Check if sync needed via ShouldSyncSleepUseCase (business logic in domain)
/// 2. Skip entirely if recently synced (within 6 hours)
/// 3. Get latest session date via GetLatestSleepSessionDateUseCase
/// 4. Fetch sleep samples from HealthKit (extended 24hr backward query, only NEW data)
/// 5. Group samples into continuous sleep sessions
/// 6. Filter sessions: only process those ending after latest synced date
/// 7. For each new session:
///    - Check if already exists (deduplicate by sourceID)
///    - Convert samples to sleep stages
///    - Calculate metrics (time in bed, total sleep, efficiency)
///    - Save to repository with WAKE DATE as session date (triggers Outbox Pattern)
///
/// **Benefits:**
/// - Smart sync optimization (avoids redundant HealthKit queries)
/// - Captures all recent sessions regardless of when app was opened
/// - Safe to run multiple times (deduplication prevents duplicates)
/// - Self-healing if data was missed previously
final class SleepSyncHandler: HealthMetricSyncHandler {

    // MARK: - Properties

    let metricType: HealthMetric = .sleep

    private let healthKitService: HealthKitServiceProtocol
    private let sleepRepository: SleepRepositoryProtocol
    private let shouldSyncSleepUseCase: ShouldSyncSleepUseCase
    private let getLatestSessionDateUseCase: GetLatestSleepSessionDateUseCase
    private let syncTracking: SyncTrackingServiceProtocol  // Kept for backward compatibility
    private var currentUserProfileID: UUID?

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        sleepRepository: SleepRepositoryProtocol,
        shouldSyncSleepUseCase: ShouldSyncSleepUseCase,
        getLatestSessionDateUseCase: GetLatestSleepSessionDateUseCase,
        syncTracking: SyncTrackingServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.sleepRepository = sleepRepository
        self.shouldSyncSleepUseCase = shouldSyncSleepUseCase
        self.getLatestSessionDateUseCase = getLatestSessionDateUseCase
        self.syncTracking = syncTracking
    }

    // MARK: - Configuration

    /// Configures the handler with the current user profile ID
    func configure(withUserProfileID userProfileID: UUID) {
        self.currentUserProfileID = userProfileID
    }

    // MARK: - HealthMetricSyncHandler

    func syncDaily(forDate date: Date) async throws {
        // Note: Date parameter is ignored - we always sync recent data with smart optimization
        // This ensures we capture all sleep sessions regardless of when they occurred
        // Deduplication by sourceID prevents duplicates
        print("SleepSyncHandler: 🌙 Starting optimized sleep sync...")
        try await syncRecentSleepData()
    }

    func syncHistorical(from startDate: Date, to endDate: Date) async throws {
        // Use same optimized recent data sync approach for historical data
        // The smart optimization will capture recent history automatically
        print("SleepSyncHandler: 🔄 Historical sync - using optimized recent data sync")
        try await syncRecentSleepData()
    }

    // MARK: - Private Methods

    /// Syncs recent sleep data with smart optimization
    /// OPTIMIZED: Uses domain use cases to check sync status (hexagonal architecture compliant)
    private func syncRecentSleepData() async throws {
        guard let userID = currentUserProfileID else {
            throw HealthMetricSyncError.noUserProfileID
        }

        let calendar = Calendar.current
        let endDate = Date()

        print("\n" + String(repeating: "=", count: 80))
        print("SleepSyncHandler: 🌙 STARTING OPTIMIZED SLEEP SYNC")
        print(String(repeating: "=", count: 80))

        // OPTIMIZATION: Use domain use case to check if sync is needed
        let shouldSync = try await shouldSyncSleepUseCase.execute(
            forUserID: userID.uuidString,
            syncThresholdHours: 6  // Skip if synced within last 6 hours
        )

        if !shouldSync {
            print("SleepSyncHandler: ✅ Already synced within last 6 hours, skipping")
            print(String(repeating: "=", count: 80) + "\n")
            return
        }

        // Get latest synced session date via domain use case
        let latestSessionDate = try await getLatestSessionDateUseCase.execute(
            forUserID: userID.uuidString
        )

        // Determine fetch start date
        let fetchStartDate: Date
        if let latestDate = latestSessionDate {
            // Fetch from 24 hours BEFORE latest session (to catch overnight sessions)
            fetchStartDate =
                calendar.date(byAdding: .hour, value: -24, to: latestDate) ?? calendar.date(
                    byAdding: .day, value: -7, to: endDate)!
            print("SleepSyncHandler: ℹ️ Latest synced session ended at: \(formatDate(latestDate))")
            print(
                "SleepSyncHandler: 📥 Fetching NEW data from \(formatDate(fetchStartDate)) to \(formatDate(endDate))"
            )
        } else {
            // No local data - fetch full 7 days (first sync)
            fetchStartDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
            print(
                "SleepSyncHandler: 📥 First sync - fetching full 7 days from \(formatDate(fetchStartDate))"
            )
        }

        print(String(repeating: "-", count: 80))

        // Fetch sleep samples from HealthKit (only missing data)
        let samples: [FitIQCore.HealthMetric]
        do {
            samples = try await fetchSleepSamples(from: fetchStartDate, to: endDate)
        } catch {
            throw HealthMetricSyncError.healthKitQueryFailed(
                metric: .sleep,
                underlyingError: error
            )
        }

        guard !samples.isEmpty else {
            print("SleepSyncHandler: ✅ No new sleep data to sync (already up to date)")
            print(String(repeating: "=", count: 80) + "\n")
            return
        }

        print("SleepSyncHandler: ✅ HEALTHKIT DATA RETRIEVED")
        print("SleepSyncHandler: Fetched \(samples.count) NEW sleep samples")
        print(String(repeating: "-", count: 80))
        print(String(repeating: "-", count: 80) + "\n")

        // Group samples into continuous sleep sessions
        print("SleepSyncHandler: 🔗 GROUPING SAMPLES INTO SESSIONS")
        print(String(repeating: "-", count: 80))
        let allSleepSessions = groupSamplesIntoSessions(samples)
        print(
            "SleepSyncHandler: Grouped into \(allSleepSessions.count) session(s) from \(samples.count) samples"
        )

        // Filter sessions: only process those ending AFTER latest synced date
        let sessionsToProcess: [[FitIQCore.HealthMetric]]
        if let latestDate = latestSessionDate {
            sessionsToProcess = allSleepSessions.filter { sessionSamples in
                guard let lastSample = sessionSamples.last else { return false }
                let lastEnd = lastSample.endDate ?? lastSample.date
                return lastEnd > latestDate
            }
            let skippedSessionsCount = allSleepSessions.count - sessionsToProcess.count
            print(
                "SleepSyncHandler: Filtered to \(sessionsToProcess.count) NEW session(s) (skipped \(skippedSessionsCount) already synced)"
            )
        } else {
            // First sync - process all sessions
            sessionsToProcess = allSleepSessions
            print(
                "SleepSyncHandler: First sync - processing all \(sessionsToProcess.count) session(s)"
            )
        }

        guard !sessionsToProcess.isEmpty else {
            print("SleepSyncHandler: ✅ No new sessions to sync (already up to date)")
            print(String(repeating: "=", count: 80) + "\n")
            return
        }

        print(String(repeating: "-", count: 80))

        // Process each NEW sleep session (deduplication by sourceID happens here)
        print("SleepSyncHandler: 💾 PROCESSING & SAVING NEW SESSIONS")
        print(String(repeating: "-", count: 80))
        var savedCount = 0
        var skippedCount = 0

        for (index, sessionSamples) in sessionsToProcess.enumerated() {
            guard let first = sessionSamples.first, let last = sessionSamples.last else {
                continue
            }
            let sessionEnd = last.endDate ?? last.date
            let sessionDate = startOfDay(for: sessionEnd)

            print("Processing session \(index + 1) of \(sessionsToProcess.count)...")
            do {
                let saved = try await processSleepSession(
                    sessionSamples,
                    forDate: sessionDate,
                    userID: userID
                )
                if saved {
                    savedCount += 1
                    print("✅ Session \(index + 1): SAVED")
                } else {
                    skippedCount += 1
                    print("⏭️  Session \(index + 1): SKIPPED (already exists)")
                }
            } catch {
                print("❌ Session \(index + 1): FAILED - \(error.localizedDescription)")
            }
        }

        print(String(repeating: "-", count: 80))
        print("SleepSyncHandler: 💾 SYNC SUMMARY")
        print("SleepSyncHandler: ✅ Saved: \(savedCount) new session(s)")
        print("SleepSyncHandler: ⏭️  Skipped: \(skippedCount) duplicate(s) (should be 0)")
        print("SleepSyncHandler: 📊 Total processed: \(sessionsToProcess.count) session(s)")
        if let latestDate = latestSessionDate {
            print(
                "SleepSyncHandler: ⚡️ Optimization: Skipped \(allSleepSessions.count - sessionsToProcess.count) already-synced sessions!"
            )
        }
        print(String(repeating: "=", count: 80))
    }

    /// Syncs sleep data for a specific date (DEPRECATED - use syncRecentSleepData instead)
    @available(
        *, deprecated, message: "Use syncRecentSleepData() instead for better sleep session capture"
    )
    private func syncDate(_ date: Date, markAsSynced: Bool) async throws {
        guard let userID = currentUserProfileID else {
            throw HealthMetricSyncError.noUserProfileID
        }

        let calendar = Calendar.current
        let startOfDay = startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        print("\n" + String(repeating: "=", count: 80))
        print("SleepSyncHandler: 🌙 STARTING SLEEP SYNC")
        print(String(repeating: "=", count: 80))
        print("SleepSyncHandler: Target date (wake date): \(formatDate(date)) (00:00 - 23:59:59)")
        print("SleepSyncHandler: startOfDay: \(startOfDay)")
        print("SleepSyncHandler: endOfDay: \(endOfDay)")

        // Query Strategy: Capture all sessions that END on target date
        // Sleep sessions are attributed to their WAKE DATE (end date)
        //
        // Examples:
        // - If syncing Saturday, we want sessions ending between Sat 00:00 - Sat 23:59:59
        // - This includes: Fri 10 PM → Sat 6 AM (started yesterday, ended today)
        // - This includes: Sat 2 AM → Sat 10 AM (started and ended today)
        // - This includes: Sat 2 PM → Sat 4 PM (daytime nap)
        //
        // Query Window:
        // - Start: 24 hours BEFORE target date start (to catch overnight sessions from previous day)
        // - End: End of target date (midnight next day)
        let queryStart = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        let queryEnd = endOfDay

        print("\n" + String(repeating: "-", count: 80))
        print("SleepSyncHandler: 🔍 HEALTHKIT QUERY SETUP")
        print(String(repeating: "-", count: 80))
        print("SleepSyncHandler: Query Start: \(queryStart) (\(formatDate(queryStart)))")
        print("SleepSyncHandler: Query End:   \(queryEnd) (\(formatDate(queryEnd)))")
        print(
            "SleepSyncHandler: Query Window: \(queryEnd.timeIntervalSince(queryStart) / 3600) hours"
        )
        print("SleepSyncHandler: This captures sessions ending on \(formatDate(date))")
        print(String(repeating: "-", count: 80) + "\n")

        // Fetch sleep samples from HealthKit
        let samples: [FitIQCore.HealthMetric]
        do {
            samples = try await fetchSleepSamples(from: queryStart, to: queryEnd)
        } catch {
            throw HealthMetricSyncError.healthKitQueryFailed(
                metric: .sleep,
                underlyingError: error
            )
        }

        guard !samples.isEmpty else {
            print("\n❌ SleepSyncHandler: No sleep data found for \(formatDate(date))")
            throw HealthMetricSyncError.noDataAvailable(metric: .sleep, date: startOfDay)
        }

        print("\n" + String(repeating: "-", count: 80))
        print("SleepSyncHandler: ✅ HEALTHKIT SAMPLES RETRIEVED")
        print(String(repeating: "-", count: 80))
        print("SleepSyncHandler: Fetched \(samples.count) sleep samples from HealthKit")
        print(String(repeating: "-", count: 80))

        // Log each sample with detailed information
        var totalSampleMinutes = 0
        for (index, sample) in samples.enumerated() {
            let value = SleepStageType.fromHealthKit(Int(sample.value))
            let sampleStart = sample.startDate ?? sample.date
            let sampleEnd = sample.endDate ?? sample.date
            let duration = Int(sampleEnd.timeIntervalSince(sampleStart) / 60)
            let sourceID = sample.metadata["sourceID"] ?? sample.source ?? "Unknown"
            let sourceName = sample.metadata["sourceName"] ?? sample.source ?? "Unknown"
            totalSampleMinutes += duration

            print(String(format: "  [%3lld] %@", index, String(repeating: "-", count: 60)))
            print(
                String(
                    format: "        Stage: %-12@ | Duration: %3lld min | isActualSleep: %@",
                    value.rawValue, duration, value.isActualSleep ? "✅" : "❌"))
            print(String(format: "        Start: %@", sampleStart.description))
            print(String(format: "        End:   %@", sampleEnd.description))
            print(String(format: "        Source: %@ (%@)", sourceName, sourceID))
            let uuid = sample.metadata["uuid"] ?? sample.id.uuidString
            print(String(format: "        UUID: %@", uuid))
        }

        print(String(repeating: "-", count: 80))
        print(
            "SleepSyncHandler: Total duration from all samples: \(totalSampleMinutes) minutes (\(String(format: "%.1f", Double(totalSampleMinutes) / 60.0))h)"
        )
        print(String(repeating: "-", count: 80) + "\n")

        // Group samples into continuous sleep sessions
        print("\n" + String(repeating: "-", count: 80))
        print("SleepSyncHandler: 🔗 GROUPING SAMPLES INTO SESSIONS")
        print(String(repeating: "-", count: 80))
        let allSleepSessions = groupSamplesIntoSessions(samples)
        print(
            "SleepSyncHandler: Grouped into \(allSleepSessions.count) session(s) from \(samples.count) samples"
        )

        // Log each session
        for (sessionIndex, sessionSamples) in allSleepSessions.enumerated() {
            guard let first = sessionSamples.first, let last = sessionSamples.last else { continue }
            let firstStart = first.startDate ?? first.date
            let lastEnd = last.endDate ?? last.date
            let sessionDuration = Int(lastEnd.timeIntervalSince(firstStart) / 60)
            print("\n  Session \(sessionIndex + 1):")
            print("    Sample count: \(sessionSamples.count)")
            print("    Start: \(firstStart)")
            print("    End: \(lastEnd)")
            print(
                "    Duration: \(sessionDuration) minutes (\(String(format: "%.1f", Double(sessionDuration) / 60.0))h)"
            )
            let firstSourceName = first.metadata["sourceName"] ?? first.source ?? "Unknown"
            print("    Source: \(firstSourceName)")
        }
        print(String(repeating: "-", count: 80) + "\n")

        // Filter: Only keep sessions that END on target date (wake date attribution)
        print("\n" + String(repeating: "-", count: 80))
        print("SleepSyncHandler: 🎯 FILTERING BY WAKE DATE")
        print(String(repeating: "-", count: 80))
        print("SleepSyncHandler: Looking for sessions that END between:")
        print("  startOfDay: \(startOfDay)")
        print("  endOfDay:   \(endOfDay)")

        let filteredSessions = allSleepSessions.filter { sessionSamples in
            guard let lastSample = sessionSamples.last else { return false }
            let sessionEnd = lastSample.endDate ?? lastSample.date
            let matches = sessionEnd >= startOfDay && sessionEnd < endOfDay

            print("\n  Checking session ending at: \(sessionEnd)")
            print("    >= startOfDay (\(startOfDay)): \(sessionEnd >= startOfDay ? "✅" : "❌")")
            print("    < endOfDay (\(endOfDay)): \(sessionEnd < endOfDay ? "✅" : "❌")")
            print("    Result: \(matches ? "✅ KEEP" : "❌ SKIP")")

            return matches
        }

        print("\n" + String(repeating: "-", count: 80))
        print(
            "SleepSyncHandler: After filtering by wake date (\(formatDate(date))): \(filteredSessions.count) session(s)"
        )
        print(String(repeating: "-", count: 80) + "\n")

        guard !filteredSessions.isEmpty else {
            print("\n❌ SleepSyncHandler: No sleep sessions ended on \(formatDate(date))")
            print("   This means either:")
            print("   1. No sleep data exists for this date in HealthKit")
            print("   2. Sleep sessions for this date ended outside the target window")
            print("   3. All sessions were filtered out by the grouping/filtering logic")
            print(String(repeating: "=", count: 80) + "\n")
            throw HealthMetricSyncError.noDataAvailable(metric: .sleep, date: startOfDay)
        }

        // Process each sleep session that ended on target date
        print("\n" + String(repeating: "-", count: 80))
        print("SleepSyncHandler: 💾 PROCESSING & SAVING SESSIONS")
        print(String(repeating: "-", count: 80))
        var savedCount = 0
        for (index, sessionSamples) in filteredSessions.enumerated() {
            print("\nProcessing session \(index + 1) of \(filteredSessions.count)...")
            do {
                let saved = try await processSleepSession(
                    sessionSamples,
                    forDate: startOfDay,
                    userID: userID
                )
                if saved {
                    savedCount += 1
                    print("✅ Session \(index + 1): SAVED")
                } else {
                    print("⏭️  Session \(index + 1): SKIPPED (already exists)")
                }
            } catch {
                print("❌ Session \(index + 1): FAILED - \(error.localizedDescription)")
                // Continue with other sessions even if one fails
            }
        }

        print("\n" + String(repeating: "-", count: 80))
        print(
            "SleepSyncHandler: ✅ Saved \(savedCount) of \(filteredSessions.count) sleep session(s)")

        // Mark date as synced
        if markAsSynced {
            syncTracking.markAsSynced(startOfDay, for: .sleep)
            print("SleepSyncHandler: ✅ Date marked as synced: \(formatDate(date))")
        }

        print(String(repeating: "=", count: 80))
        print("SleepSyncHandler: ✅ SLEEP SYNC COMPLETE (DEPRECATED)")
        print(String(repeating: "=", count: 80) + "\n")
    }

    /// Fetches sleep samples from HealthKit for the given time range
    private func fetchSleepSamples(from startDate: Date, to endDate: Date) async throws
        -> [FitIQCore.HealthMetric]
    {
        let options = HealthQueryOptions(
            limit: nil,
            sortOrder: .ascending,
            aggregation: .none  // Get individual samples
        )

        return try await healthKitService.query(
            type: .sleepAnalysis,
            from: startDate,
            to: endDate,
            options: options
        )
    }

    /// Groups sleep samples into continuous sleep sessions
    /// Apple HealthKit provides multiple samples for a single sleep session (one per stage)
    /// We need to merge overlapping/adjacent samples from the same source into sessions
    private func groupSamplesIntoSessions(_ samples: [FitIQCore.HealthMetric]) -> [[FitIQCore
        .HealthMetric]]
    {
        print("  🔗 Starting session grouping algorithm...")
        print("  Rule 1: New session if different source")
        print("  Rule 2: New session if gap > 2 hours")
        print("  Rule 3: New session if first sample")

        var sleepSessions: [[FitIQCore.HealthMetric]] = []
        var currentSession: [FitIQCore.HealthMetric] = []
        var lastEndTime: Date?
        var lastSourceID: String?

        for (index, sample) in samples.enumerated() {
            let sourceID = sample.metadata["sourceID"] ?? ""
            let sampleStart = sample.startDate ?? sample.date
            let sampleEnd = sample.endDate ?? sample.date

            let gapFromLast = lastEndTime != nil ? sampleStart.timeIntervalSince(lastEndTime!) : 0
            let gapHours = gapFromLast / 3600.0

            // Start new session if:
            // 1. First sample
            // 2. Different source
            // 3. Gap > 2 hours from last sample (new sleep session)
            let isNewSession =
                currentSession.isEmpty
                || sourceID != lastSourceID
                || (lastEndTime != nil && sampleStart.timeIntervalSince(lastEndTime!) > 7200)  // 2 hours

            if index % 10 == 0 || isNewSession {
                print(
                    String(
                        format: "    Sample %3lld: gap=%.2fh | source=%@ | newSession=%@",
                        index, gapHours,
                        sourceID == lastSourceID ? "same" : "DIFFERENT",
                        isNewSession ? "YES" : "no"))
            }

            if isNewSession && !currentSession.isEmpty {
                print("    → Closing session with \(currentSession.count) samples")
                sleepSessions.append(currentSession)
                currentSession = []
            }

            currentSession.append(sample)
            lastEndTime = sampleEnd
            lastSourceID = sourceID
        }

        // Add last session
        if !currentSession.isEmpty {
            print("    → Closing final session with \(currentSession.count) samples")
            sleepSessions.append(currentSession)
        }

        print("  ✅ Grouping complete: \(sleepSessions.count) session(s) created")

        return sleepSessions
    }

    /// Processes a single sleep session: converts samples, calculates metrics, and saves
    private func processSleepSession(
        _ sessionSamples: [FitIQCore.HealthMetric],
        forDate date: Date,
        userID: UUID
    ) async throws -> Bool {
        guard let firstSample = sessionSamples.first,
            let lastSample = sessionSamples.last
        else {
            return false
        }

        let sessionStart = firstSample.startDate ?? firstSample.date
        let sessionEnd = lastSample.endDate ?? lastSample.date
        let sourceID = firstSample.metadata["uuid"] ?? UUID().uuidString

        print("\n" + String(repeating: "·", count: 80))
        print("  Processing session:")
        print("    Samples: \(sessionSamples.count)")
        print("    Start: \(sessionStart)")
        print("    End: \(sessionEnd)")
        print("    Duration: \(Int((sessionEnd.timeIntervalSince(sessionStart)) / 60)) minutes")
        print(String(repeating: "·", count: 80))

        // Check if this session already exists (deduplication by sourceID)
        if let existingSession = try await sleepRepository.fetchSession(
            bySourceID: sourceID, forUserID: userID.uuidString)
        {
            print(
                "SleepSyncHandler: ⏭️ Sleep session with sourceID \(sourceID) already exists (ID: \(existingSession.id)), skipping"
            )
            return false
        }

        // Convert HealthKit samples to sleep stages
        var stages: [SleepStage] = []
        print("  Converting \(sessionSamples.count) samples to sleep stages...")
        for sample in sessionSamples {
            let stageValue = Int(sample.value)
            let stageType = SleepStageType.fromHealthKit(stageValue)
            let sampleStart = sample.startDate ?? sample.date
            let sampleEnd = sample.endDate ?? sample.date
            let duration = Int(sampleEnd.timeIntervalSince(sampleStart) / 60)  // minutes

            let stage = SleepStage(
                stage: stageType,
                startTime: sampleStart,
                endTime: sampleEnd,
                durationMinutes: duration
            )
            stages.append(stage)
        }

        // Calculate metrics
        let timeInBedMinutes = Int(sessionEnd.timeIntervalSince(sessionStart) / 60)
        print("  Time in bed: \(timeInBedMinutes) minutes")

        // Debug: Log stage breakdown
        print("  Stage breakdown:")
        var actualSleepMinutes = 0
        for stage in stages {
            let marker = stage.stage.isActualSleep ? "✅" : "❌"
            print(
                String(
                    format: "    %@ %-12@ %3lld min", marker, stage.stage.rawValue,
                    stage.durationMinutes))
            if stage.stage.isActualSleep {
                actualSleepMinutes += stage.durationMinutes
            }
        }

        let totalSleepMinutes = stages.filter { $0.stage.isActualSleep }.reduce(0) {
            $0 + $1.durationMinutes
        }

        print("  Calculated sleep:")
        print(
            "    Time in bed: \(timeInBedMinutes) min (\(String(format: "%.1f", Double(timeInBedMinutes) / 60.0))h)"
        )
        print(
            "    Total sleep: \(totalSleepMinutes) min (\(String(format: "%.1f", Double(totalSleepMinutes) / 60.0))h)"
        )
        print("    Manual calc: \(actualSleepMinutes) min (should match total sleep)")

        let sleepEfficiency =
            timeInBedMinutes > 0
            ? (Double(totalSleepMinutes) / Double(timeInBedMinutes)) * 100.0 : 0.0

        // Create sleep session
        // Use wake date (session end date) as the session date
        // This follows industry standard: sleep is attributed to the day you wake up
        let wakeDate = startOfDay(for: sessionEnd)

        print("  Attributing session to wake date: \(formatDate(wakeDate))")
        print("  Sleep efficiency: \(String(format: "%.1f", sleepEfficiency))%")

        let sleepSession = SleepSession(
            userID: userID.uuidString,
            date: wakeDate,  // Use wake date, not query date
            startTime: sessionStart,
            endTime: sessionEnd,
            timeInBedMinutes: timeInBedMinutes,
            totalSleepMinutes: totalSleepMinutes,
            sleepEfficiency: sleepEfficiency,
            source: "healthkit",
            sourceID: sourceID,
            notes: nil,
            syncStatus: .pending,
            stages: stages
        )

        // Save to repository (triggers Outbox Pattern)
        let localID = try await sleepRepository.save(
            session: sleepSession, forUserID: userID.uuidString)
        print("  ✅ Saved to database:")
        print("    Local ID: \(localID)")
        print(
            "    Sleep: \(totalSleepMinutes) min (\(String(format: "%.1f", Double(totalSleepMinutes) / 60.0))h)"
        )
        print("    Efficiency: \(String(format: "%.1f", sleepEfficiency))%")
        print(String(repeating: "·", count: 80))

        return true
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
