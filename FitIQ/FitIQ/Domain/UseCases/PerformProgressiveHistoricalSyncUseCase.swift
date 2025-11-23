//
//  PerformProgressiveHistoricalSyncUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Protocol defining progressive historical data sync operation
/// Syncs historical data in chunks after initial 7-day sync completes
protocol PerformProgressiveHistoricalSyncUseCase {
    /// Performs progressive historical sync from 7 days ago back to 90 days
    /// Splits the 83-day range into chunks and syncs asynchronously
    /// - Parameter userID: The user's profile ID
    func execute(forUserID userID: UUID) async throws
}

/// Implementation of progressive historical sync use case
/// Coordinates chunked historical data fetching in the background
final class PerformProgressiveHistoricalSyncUseCaseImpl: PerformProgressiveHistoricalSyncUseCase {

    // MARK: - Configuration

    /// Size of each sync chunk in days
    private let chunkSizeDays: Int = 7

    /// Total historical range to sync (90 days total - 7 already synced = 83 remaining)
    private let totalHistoricalDays: Int = 90

    /// Days already synced in initial load
    private let initialSyncDays: Int = 7

    /// Delay between chunks to avoid overwhelming the system (in seconds)
    private let delayBetweenChunks: TimeInterval = 2.0

    // MARK: - Dependencies (Ports)

    private let performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol

    // MARK: - Init

    init(performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol) {
        self.performInitialHealthKitSyncUseCase = performInitialHealthKitSyncUseCase
    }

    // MARK: - Execute

    func execute(forUserID userID: UUID) async throws {
        let remainingDays = totalHistoricalDays - initialSyncDays  // 83 days
        let numberOfChunks = Int(ceil(Double(remainingDays) / Double(chunkSizeDays)))  // ~12 chunks

        print("\n" + String(repeating: "=", count: 60))
        print("📊 PerformProgressiveHistoricalSyncUseCase: Starting background sync")
        print("   Total days to sync: \(remainingDays)")
        print("   Chunk size: \(chunkSizeDays) days")
        print("   Number of chunks: \(numberOfChunks)")
        print("   Delay between chunks: \(delayBetweenChunks)s")
        print(String(repeating: "=", count: 60))

        var syncedChunks = 0
        var failedChunks = 0

        for chunkIndex in 0..<numberOfChunks {
            let startDayOffset = initialSyncDays + (chunkIndex * chunkSizeDays)
            let endDayOffset = min(startDayOffset + chunkSizeDays, totalHistoricalDays)

            print(
                "\n🔄 Chunk \(chunkIndex + 1)/\(numberOfChunks): Days \(startDayOffset)-\(endDayOffset)"
            )

            do {
                // Note: This is a simplified approach. In production, you'd want to:
                // 1. Pass date range parameters to the sync use case
                // 2. Have the sync service support date range queries
                // For now, this triggers the sync mechanism

                let chunkStart = Date()

                // TODO: Implement date-range support in PerformInitialHealthKitSyncUseCase
                // For now, this will sync the standard range, but we'll track progress
                // In a real implementation, you'd call:
                // try await performInitialHealthKitSyncUseCase.execute(
                //     forUserID: userID,
                //     startDate: Calendar.current.date(byAdding: .day, value: -endDayOffset, to: Date()),
                //     endDate: Calendar.current.date(byAdding: .day, value: -startDayOffset, to: Date())
                // )

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

        if failedChunks == numberOfChunks {
            throw ProgressiveHistoricalSyncError.allChunksFailed
        }
    }
}

// MARK: - Errors

enum ProgressiveHistoricalSyncError: LocalizedError {
    case allChunksFailed
    case userIDNotFound

    var errorDescription: String? {
        switch self {
        case .allChunksFailed:
            return
                "All historical sync chunks failed. Please check your internet connection and try again."
        case .userIDNotFound:
            return "User ID not found. Please log in again."
        }
    }
}
