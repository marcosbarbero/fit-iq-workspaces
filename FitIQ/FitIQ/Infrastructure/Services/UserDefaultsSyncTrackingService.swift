//
//  UserDefaultsSyncTrackingService.swift
//  FitIQ
//
//  Created by Refactoring on 27/01/2025.
//

import Foundation

/// UserDefaults-based implementation of sync tracking service.
/// Tracks which dates have been synced for each health metric to prevent redundant syncs.
///
/// **Storage Strategy:**
/// - Uses UserDefaults for simple key-value storage
/// - Stores dates as YYYY-MM-DD strings for each metric
/// - Keeps only last 400 days to prevent storage bloat
/// - Thread-safe (UserDefaults is thread-safe)
final class UserDefaultsSyncTrackingService: SyncTrackingServiceProtocol {

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let keyPrefix = "com.fitiq.historical"
    private let maxStoredDays = 400

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - SyncTrackingServiceProtocol

    func hasAlreadySynced(_ date: Date, for metric: HealthMetric) -> Bool {
        let dateString = formatDateForTracking(date)
        let key = keyForMetric(metric)
        let syncedDates = userDefaults.stringArray(forKey: key) ?? []
        return syncedDates.contains(dateString)
    }

    func markAsSynced(_ date: Date, for metric: HealthMetric) {
        let dateString = formatDateForTracking(date)
        let key = keyForMetric(metric)
        var syncedDates = userDefaults.stringArray(forKey: key) ?? []

        // Only add if not already present
        guard !syncedDates.contains(dateString) else {
            return
        }

        syncedDates.append(dateString)

        // Keep only last N days to prevent UserDefaults bloat
        if syncedDates.count > maxStoredDays {
            syncedDates = Array(syncedDates.suffix(maxStoredDays))
        }

        userDefaults.set(syncedDates, forKey: key)
        print("SyncTrackingService: 📌 Marked \(dateString) as synced for \(metric.displayName)")
    }

    func clearAllTracking() {
        for metric in HealthMetric.allCases {
            clearTracking(for: metric)
        }
        print("SyncTrackingService: 🗑️ Cleared all sync tracking for all metrics")
    }

    func clearTracking(for metric: HealthMetric) {
        let key = keyForMetric(metric)
        userDefaults.removeObject(forKey: key)
        print("SyncTrackingService: 🗑️ Cleared sync tracking for \(metric.displayName)")
    }

    // MARK: - Private Helpers

    /// Generates the UserDefaults key for a specific metric
    private func keyForMetric(_ metric: HealthMetric) -> String {
        switch metric {
        case .steps:
            return "\(keyPrefix).steps.synced"
        case .heartRate:
            return "\(keyPrefix).heartrate.synced"
        case .sleep:
            return "\(keyPrefix).sleep.synced"
        case .activeEnergy:
            return "\(keyPrefix).activeenergy.synced"
        case .exerciseMinutes:
            return "\(keyPrefix).exerciseminutes.synced"
        case .bodyMass:
            return "\(keyPrefix).bodymass.synced"
        }
    }

    /// Formats a date as YYYY-MM-DD string for consistent tracking
    private func formatDateForTracking(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Additional Utilities

extension UserDefaultsSyncTrackingService {

    /// Returns all synced dates for a specific metric (for debugging)
    func getSyncedDates(for metric: HealthMetric) -> [String] {
        let key = keyForMetric(metric)
        return userDefaults.stringArray(forKey: key) ?? []
    }

    /// Returns the count of synced dates for a specific metric (for debugging)
    func getSyncedDatesCount(for metric: HealthMetric) -> Int {
        return getSyncedDates(for: metric).count
    }

    /// Prints sync tracking status for all metrics (for debugging)
    func printSyncStatus() {
        print("\n📊 Sync Tracking Status:")
        print("─────────────────────────────────────")
        for metric in HealthMetric.allCases {
            let count = getSyncedDatesCount(for: metric)
            print("  \(metric.displayName): \(count) days synced")
        }
        print("─────────────────────────────────────\n")
    }
}
