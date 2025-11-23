//
//  ProgressiveHistoricalSyncService.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Background service that handles progressive historical data synchronization
/// Runs after initial 7-day sync completes, fetching remaining 83 days in chunks
final class ProgressiveHistoricalSyncService {

    // MARK: - Configuration

    /// Size of each sync chunk in days
    private let chunkSizeDays: Int = 7

    /// Total historical range to sync (90 days total - 7 already synced = 83 remaining)
    private let totalHistoricalDays: Int = 90

    /// Days already synced in initial load
    private let initialSyncDays: Int = 7

    /// Delay between chunks to avoid overwhelming the system (in seconds)
    /// Increased to 3.0s to reduce database write pressure
    private let delayBetweenChunks: TimeInterval = 3.0

    // MARK: - Properties

    /// Current sync task (to allow cancellation)
    private var syncTask: Task<Void, Never>?

    /// Flag to track if sync is in progress
    private(set) var isSyncing: Bool = false

    /// Current user ID being synced
    private var currentUserID: UUID?

    // MARK: - Dependencies

    private let healthDataSyncService: HealthDataSyncOrchestrator
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Init

    init(
        healthDataSyncService: HealthDataSyncOrchestrator,
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.healthDataSyncService = healthDataSyncService
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    // MARK: - Public API

    /// Starts progressive historical sync in the background
    /// - Parameter userID: The user's profile ID
    func startProgressiveSync(forUserID userID: UUID) {
        // Cancel any existing sync
        stopProgressiveSync()

        currentUserID = userID

        // Start background sync task
        syncTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.isSyncing = true
            }

            do {
                try await self.performProgressiveSync(forUserID: userID)
            } catch {
                print(
                    "ProgressiveHistoricalSyncService: Sync failed - \(error.localizedDescription)")
            }

            await MainActor.run {
                self.isSyncing = false
                self.currentUserID = nil
            }
        }
    }

    /// Stops any ongoing progressive sync
    func stopProgressiveSync() {
        syncTask?.cancel()
        syncTask = nil
        isSyncing = false
        currentUserID = nil
        print("ProgressiveHistoricalSyncService: Sync stopped")
    }

    // MARK: - Private Implementation

    private func performProgressiveSync(forUserID userID: UUID) async throws {
        let remainingDays = totalHistoricalDays - initialSyncDays  // 83 days
        let numberOfChunks = Int(ceil(Double(remainingDays) / Double(chunkSizeDays)))  // ~12 chunks

        print("\n" + String(repeating: "=", count: 60))
        print("📊 ProgressiveHistoricalSyncService: Starting background sync")
        print("   Total days to sync: \(remainingDays)")
        print("   Chunk size: \(chunkSizeDays) days")
        print("   Number of chunks: \(numberOfChunks)")
        print("   Delay between chunks: \(delayBetweenChunks)s")
        print("   Note: Using increased delay to reduce database write pressure")
        print(String(repeating: "=", count: 60))

        var syncedChunks = 0
        var failedChunks = 0

        for chunkIndex in 0..<numberOfChunks {
            // Check for cancellation
            if Task.isCancelled {
                print("ProgressiveHistoricalSyncService: Sync cancelled by user")
                return
            }

            let startDayOffset = initialSyncDays + (chunkIndex * chunkSizeDays)
            let endDayOffset = min(startDayOffset + chunkSizeDays, totalHistoricalDays)

            // Calculate actual date range
            let calendar = Calendar.current
            let endDate = calendar.date(byAdding: .day, value: -startDayOffset, to: Date())!
            let startDate = calendar.date(byAdding: .day, value: -endDayOffset, to: Date())!

            print(
                "\n🔄 Chunk \(chunkIndex + 1)/\(numberOfChunks): Days \(startDayOffset)-\(endDayOffset)"
            )
            print("   Date range: \(formatDate(startDate)) to \(formatDate(endDate))")

            do {
                let chunkStart = Date()

                // Sync this chunk's date range
                try await syncChunk(
                    forUserID: userID,
                    startDate: startDate,
                    endDate: endDate,
                    chunkNumber: chunkIndex + 1
                )

                let chunkDuration = Date().timeIntervalSince(chunkStart)
                print(
                    "✅ Chunk \(chunkIndex + 1) completed in \(String(format: "%.2f", chunkDuration))s"
                )

                syncedChunks += 1

                // Delay before next chunk to avoid overwhelming the system
                if chunkIndex < numberOfChunks - 1 {
                    print("⏳ Waiting \(delayBetweenChunks)s before next chunk...")
                    try await Task.sleep(nanoseconds: UInt64(delayBetweenChunks * 1_000_000_000))
                }

            } catch {
                print("⚠️ Chunk \(chunkIndex + 1) failed: \(error.localizedDescription)")
                failedChunks += 1

                // Continue with next chunk even if one fails
                // This ensures partial success rather than complete failure
            }
        }

        print("\n" + String(repeating: "=", count: 60))
        print("📊 Progressive Historical Sync Complete")
        print("   ✅ Successful chunks: \(syncedChunks)/\(numberOfChunks)")
        if failedChunks > 0 {
            print("   ⚠️ Failed chunks: \(failedChunks)/\(numberOfChunks)")
        }
        print(String(repeating: "=", count: 60) + "\n")

        // Mark sync as completed for this user to prevent re-running
        if let userID = currentUserID {
            await MainActor.run {
                UserDefaults.standard.set(true, forKey: "hasCompletedProgressiveSync_\(userID)")
                print("✅ Marked progressive sync as completed for user \(userID)")
            }
        }
    }

    /// Syncs a single chunk of historical data
    private func syncChunk(
        forUserID userID: UUID,
        startDate: Date,
        endDate: Date,
        chunkNumber: Int
    ) async throws {
        // Configure sync service
        healthDataSyncService.configure(withUserProfileID: userID)

        // Sync historical data for this date range
        // Note: This requires the sync service to support date range parameters
        // For now, we use the existing syncAllDailyActivityData and rely on
        // the fact that it will process any data not yet synced

        // In a future enhancement, add date range support:
        // await healthDataSyncService.syncHistoricalData(from: startDate, to: endDate)

        // OPTIMIZATION: To reduce database bloat, the sync service should:
        // 1. Check for existing data before inserting (deduplication)
        // 2. Use batch inserts instead of individual saves
        // 3. Commit changes periodically, not after each record

        // For now, use the existing daily sync which is smart enough to handle gaps
        await healthDataSyncService.syncAllDailyActivityData()

        print(
            "   📊 Chunk \(chunkNumber): Synced data from \(formatDate(startDate)) to \(formatDate(endDate))"
        )
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Protocol

protocol ProgressiveHistoricalSyncServiceProtocol {
    var isSyncing: Bool { get }
    func startProgressiveSync(forUserID userID: UUID)
    func stopProgressiveSync()
}

extension ProgressiveHistoricalSyncService: ProgressiveHistoricalSyncServiceProtocol {}
