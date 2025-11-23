//
//  GetHistoricalWeightUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import HealthKit

/// Protocol for fetching historical weight data
protocol GetHistoricalWeightUseCase {
    /// Fetches weight entries for a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Array of progress entries sorted by date (newest first)
    func execute(startDate: Date, endDate: Date) async throws -> [ProgressEntry]
}

/// Implementation following local-first architecture
/// Local data is the source of truth - we only fetch remote/HealthKit to keep it fresh
final class GetHistoricalWeightUseCaseImpl: GetHistoricalWeightUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol
    private let healthRepository: HealthRepositoryProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase

    // MARK: - Configuration

    /// Consider local data stale if the most recent entry is older than this
    private let staleDataThreshold: TimeInterval = 3600  // 1 hour

    // MARK: - Initialization

    init(
        progressRepository: ProgressRepositoryProtocol,
        healthRepository: HealthRepositoryProtocol,
        authManager: AuthManager,
        saveWeightProgressUseCase: SaveWeightProgressUseCase
    ) {
        self.progressRepository = progressRepository
        self.healthRepository = healthRepository
        self.authManager = authManager
        self.saveWeightProgressUseCase = saveWeightProgressUseCase
    }

    // MARK: - Execute

    func execute(startDate: Date, endDate: Date) async throws -> [ProgressEntry] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetHistoricalWeightError.userNotAuthenticated
        }

        print("GetHistoricalWeightUseCase: Fetching weight for user \(userID)")
        print("  Date range: \(startDate) to \(endDate)")

        // STEP 1: CHECK LOCAL DATA FIRST (source of truth)
        let localEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .weight,
            syncStatus: nil,
            limit: 500  // Limit to 500 weight entries for performance
        )

        print("GetHistoricalWeightUseCase: Found \(localEntries.count) local entries")

        // Filter to requested date range
        let filteredEntries = localEntries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }

        print(
            "GetHistoricalWeightUseCase: \(filteredEntries.count) entries in requested date range")

        // STEP 2: DETERMINE IF WE NEED TO FETCH FRESH DATA
        let needsFreshData = shouldFetchFreshData(localEntries: localEntries)

        if needsFreshData {
            print(
                "GetHistoricalWeightUseCase: Local data is stale or empty, fetching fresh data in background"
            )

            // Fetch fresh data in background WITHOUT blocking the UI
            Task.detached { [weak self] in
                await self?.fetchFreshDataInBackground(
                    userID: userID,
                    startDate: startDate,
                    endDate: endDate,
                    existingLocalEntries: localEntries
                )
            }
        } else {
            print("GetHistoricalWeightUseCase: Local data is fresh, returning immediately")
        }

        // STEP 3: RETURN LOCAL DATA IMMEDIATELY (even if we triggered background fetch)
        let sortedEntries = filteredEntries.sorted { $0.date > $1.date }

        print("GetHistoricalWeightUseCase: Returning \(sortedEntries.count) local entries")
        if sortedEntries.count > 0 {
            print("  Latest: \(sortedEntries.first!.date) - \(sortedEntries.first!.quantity) kg")
            if sortedEntries.count > 1 {
                print("  Oldest: \(sortedEntries.last!.date) - \(sortedEntries.last!.quantity) kg")
            }
        }

        return sortedEntries
    }

    // MARK: - Helper Methods

    /// Determines if we should fetch fresh data from HealthKit/Remote
    private func shouldFetchFreshData(localEntries: [ProgressEntry]) -> Bool {
        // If no local data, we definitely need fresh data
        guard !localEntries.isEmpty else {
            print("GetHistoricalWeightUseCase: No local data - need fresh data")
            return true
        }

        // Check if most recent entry is stale
        guard let mostRecentDate = localEntries.map({ $0.date }).max() else {
            return true
        }

        let timeSinceLastEntry = Date().timeIntervalSince(mostRecentDate)
        let isStale = timeSinceLastEntry > staleDataThreshold

        if isStale {
            print(
                "GetHistoricalWeightUseCase: Most recent entry is \(Int(timeSinceLastEntry / 3600))h old - considered stale"
            )
        }

        return isStale
    }

    /// Fetches fresh data from HealthKit and syncs to local storage
    /// This runs in the background without blocking the UI
    private func fetchFreshDataInBackground(
        userID: String,
        startDate: Date,
        endDate: Date,
        existingLocalEntries: [ProgressEntry]
    ) async {
        print("GetHistoricalWeightUseCase: [Background] Fetching fresh HealthKit data...")

        // STEP 1: Fetch from HealthKit
        var healthKitSamples: [(value: Double, date: Date)] = []
        do {
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            healthKitSamples = try await healthRepository.fetchQuantitySamples(
                for: .bodyMass,
                unit: .gramUnit(with: .kilo),
                predicateProvider: { predicate },
                limit: nil
            )

            print(
                "GetHistoricalWeightUseCase: [Background] ✅ Found \(healthKitSamples.count) HealthKit samples"
            )
        } catch {
            print(
                "GetHistoricalWeightUseCase: [Background] ❌ HealthKit fetch failed: \(error.localizedDescription)"
            )
            // Try remote as fallback
            await fetchFromRemoteInBackground(
                userID: userID, startDate: startDate, endDate: endDate)
            return
        }

        // STEP 2: Save new HealthKit samples to local storage
        guard !healthKitSamples.isEmpty else {
            print("GetHistoricalWeightUseCase: [Background] No new HealthKit data to sync")
            return
        }

        var newEntriesCount = 0
        var duplicatesCount = 0
        let calendar = Calendar.current

        for sample in healthKitSamples {
            do {
                // Normalize date to start of day
                let targetDate = calendar.startOfDay(for: sample.date)

                // Check if already exists (same date + similar value)
                let alreadyExists = existingLocalEntries.contains { entry in
                    let entryDate = calendar.startOfDay(for: entry.date)
                    let sameDay = calendar.isDate(entryDate, inSameDayAs: targetDate)
                    let sameValue = abs(entry.quantity - sample.value) < 0.01
                    return sameDay && sameValue
                }

                if alreadyExists {
                    duplicatesCount += 1
                    continue
                }

                // Create and save new entry
                let progressEntry = ProgressEntry(
                    id: UUID(),
                    userID: userID,
                    type: .weight,
                    quantity: sample.value,
                    date: targetDate,
                    notes: nil,
                    createdAt: Date(),
                    backendID: nil,
                    syncStatus: .pending  // Background sync will handle upload
                )

                _ = try await progressRepository.save(
                    progressEntry: progressEntry,
                    forUserID: userID
                )

                newEntriesCount += 1

            } catch {
                print(
                    "GetHistoricalWeightUseCase: [Background] Failed to save sample: \(error.localizedDescription)"
                )
            }
        }

        print("GetHistoricalWeightUseCase: [Background] ✅ Sync complete:")
        print("  - New entries saved: \(newEntriesCount)")
        print("  - Duplicates skipped: \(duplicatesCount)")
        print("  - Background sync will upload pending entries to remote")
    }

    /// Fetches from remote API as fallback when HealthKit is unavailable
    private func fetchFromRemoteInBackground(
        userID: String,
        startDate: Date,
        endDate: Date
    ) async {
        print("GetHistoricalWeightUseCase: [Background] Trying remote API as fallback...")

        do {
            let remoteEntries = try await progressRepository.getProgressHistory(
                type: .weight,
                from: startDate,
                to: endDate,
                page: nil,
                limit: nil
            )

            print(
                "GetHistoricalWeightUseCase: [Background] ✅ Found \(remoteEntries.count) entries from remote"
            )

            // Save remote entries locally
            var savedCount = 0
            for entry in remoteEntries {
                do {
                    _ = try await progressRepository.save(
                        progressEntry: entry,
                        forUserID: userID
                    )
                    savedCount += 1
                } catch {
                    // Continue with other entries
                }
            }

            print(
                "GetHistoricalWeightUseCase: [Background] Saved \(savedCount) remote entries locally"
            )

        } catch {
            print(
                "GetHistoricalWeightUseCase: [Background] ❌ Remote fetch also failed: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Errors

enum GetHistoricalWeightError: Error, LocalizedError {
    case userNotAuthenticated
    case healthKitFetchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch weight history"
        case .healthKitFetchFailed(let error):
            return "Failed to fetch weight from HealthKit: \(error.localizedDescription)"
        }
    }
}
