//
//  SyncTrackingServiceProtocol.swift
//  FitIQ
//
//  Created by Refactoring on 27/01/2025.
//

import Foundation

/// Defines the types of health metrics that can be tracked for sync status
public enum HealthMetric: String, CaseIterable {
    case steps
    case heartRate
    case sleep
    case activeEnergy
    case exerciseMinutes
    case bodyMass

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .heartRate: return "Heart Rate"
        case .sleep: return "Sleep"
        case .activeEnergy: return "Active Energy"
        case .exerciseMinutes: return "Exercise Minutes"
        case .bodyMass: return "Body Mass"
        }
    }
}

/// Protocol for tracking which dates have been synced for each health metric.
/// This prevents redundant syncs of historical data and improves performance.
///
/// **Implementation Note:**
/// - Today's data should NEVER be marked as fully synced (data is still accumulating)
/// - Historical dates (not today) can be marked as synced to avoid re-processing
/// - Implementations should consider storage limits (e.g., keep only last 400 days)
public protocol SyncTrackingServiceProtocol {

    /// Checks if a specific date has already been synced for a given health metric.
    ///
    /// - Parameters:
    ///   - date: The date to check (will be normalized to start of day)
    ///   - metric: The health metric type
    /// - Returns: `true` if the date has been previously synced, `false` otherwise
    func hasAlreadySynced(_ date: Date, for metric: HealthMetric) -> Bool

    /// Marks a specific date as synced for a given health metric.
    ///
    /// - Parameters:
    ///   - date: The date to mark as synced (will be normalized to start of day)
    ///   - metric: The health metric type
    ///
    /// - Note: This should NOT be called for today's date, as data is still accumulating
    func markAsSynced(_ date: Date, for metric: HealthMetric)

    /// Clears all sync tracking for all metrics.
    /// Useful for force resync scenarios.
    func clearAllTracking()

    /// Clears sync tracking for a specific metric.
    ///
    /// - Parameter metric: The health metric to clear tracking for
    func clearTracking(for metric: HealthMetric)
}
