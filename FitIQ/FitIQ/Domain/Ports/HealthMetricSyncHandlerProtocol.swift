//
//  HealthMetricSyncHandlerProtocol.swift
//  FitIQ
//
//  Created by Refactoring on 27/01/2025.
//

import Foundation

/// Protocol defining the contract for health metric-specific sync handlers.
///
/// Each handler is responsible for syncing one type of health metric (e.g., steps, heart rate, sleep)
/// from HealthKit to local storage and progress tracking.
///
/// **Design Pattern:** Strategy Pattern
/// - Each concrete handler implements the sync logic for a specific metric
/// - Handlers are composable and can be orchestrated by a coordinator
/// - Easy to add new metrics by creating new handlers (Open/Closed Principle)
///
/// **Responsibilities:**
/// - Fetch data from HealthKit for the specific metric
/// - Transform data into domain models
/// - Save to local storage (SwiftData)
/// - Save to progress tracking (with Outbox Pattern)
/// - Handle sync tracking (mark dates as synced)
///
/// **Example Usage:**
/// ```swift
/// let handler = StepsSyncHandler(...)
/// try await handler.syncDaily(forDate: Date())
/// try await handler.syncHistorical(from: startDate, to: endDate)
/// ```
public protocol HealthMetricSyncHandler {

    /// The type of health metric this handler syncs
    var metricType: HealthMetric { get }

    /// Syncs data for a specific date (typically used for daily sync).
    ///
    /// - Parameter date: The date to sync data for (will be normalized to start of day)
    ///
    /// - Throws: If HealthKit query fails or data storage fails
    ///
    /// **Behavior:**
    /// - If `date` is today: Always syncs, even if previously synced (data still accumulating)
    /// - If `date` is historical: Checks sync tracking, skips if already synced
    /// - Fetches hourly aggregates from HealthKit
    /// - Saves to local storage and progress tracking
    /// - Marks date as synced (only if not today)
    func syncDaily(forDate date: Date) async throws

    /// Syncs historical data for a date range (used for initial sync or backfill).
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range (inclusive)
    ///   - endDate: The end of the date range (inclusive)
    ///
    /// - Throws: If HealthKit query fails or data storage fails
    ///
    /// **Behavior:**
    /// - Iterates through each day in the range
    /// - Uses sync tracking to skip already-synced dates (optimization)
    /// - Fetches hourly aggregates from HealthKit for each day
    /// - Saves to local storage and progress tracking
    /// - Marks each date as synced (except today)
    ///
    /// **Performance:**
    /// - Large date ranges (e.g., 90 days) may take 30-45 seconds
    /// - Use for initial sync or force resync scenarios
    func syncHistorical(from startDate: Date, to endDate: Date) async throws
}

// MARK: - Default Implementations

extension HealthMetricSyncHandler {

    /// Helper to check if a date is today
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Helper to get start of day for a date
    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Helper to get end of day for a date
    func endOfDay(for date: Date) -> Date {
        let startOfNextDay = Calendar.current.date(
            byAdding: .day, value: 1, to: startOfDay(for: date))!
        return startOfNextDay.addingTimeInterval(-1)  // 23:59:59
    }
}

// MARK: - Supporting Types

/// Errors that can occur during metric sync
public enum HealthMetricSyncError: Error, LocalizedError {
    case noDataAvailable(metric: HealthMetric, date: Date)
    case healthKitQueryFailed(metric: HealthMetric, underlyingError: Error)
    case storageFailed(metric: HealthMetric, underlyingError: Error)
    case noUserProfileID
    case invalidDateRange(start: Date, end: Date)

    public var errorDescription: String? {
        switch self {
        case .noDataAvailable(let metric, let date):
            return "No \(metric.displayName) data available for \(date)"
        case .healthKitQueryFailed(let metric, let error):
            return
                "Failed to query \(metric.displayName) from HealthKit: \(error.localizedDescription)"
        case .storageFailed(let metric, let error):
            return "Failed to store \(metric.displayName) data: \(error.localizedDescription)"
        case .noUserProfileID:
            return "No user profile ID configured"
        case .invalidDateRange(let start, let end):
            return "Invalid date range: start (\(start)) is after end (\(end))"
        }
    }
}
