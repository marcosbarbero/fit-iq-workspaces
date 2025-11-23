//
//  HealthKitServiceProtocol.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Primary interface for interacting with HealthKit data
///
/// This protocol defines the core operations for reading, writing, and observing
/// health data. It abstracts HealthKit functionality to provide a clean, testable
/// interface that can be used across both FitIQ and Lume applications.
///
/// **Usage:**
/// ```swift
/// // Query step count for today
/// let metrics = try await healthService.query(
///     type: .stepCount,
///     from: Date().startOfDay,
///     to: Date(),
///     options: .hourly
/// )
///
/// // Save a new workout
/// let workout = HealthMetric.duration(
///     type: .workout(.running),
///     value: 500,
///     unit: "kcal",
///     startDate: startDate,
///     endDate: endDate
/// )
/// try await healthService.save(metric: workout)
///
/// // Observe real-time heart rate changes
/// for await metric in healthService.observeChanges(for: .heartRate) {
///     print("New heart rate: \(metric.value) bpm")
/// }
/// ```
///
/// **Architecture:** FitIQCore - Domain Port (Hexagonal Architecture)
///
/// **Implementation Notes:**
/// - Concrete implementations will use HealthKit's HKHealthStore
/// - Mock implementations can be used for testing
/// - All operations are async/await based
/// - Errors are thrown for failure cases
///
/// **Thread Safety:** All methods are async and can be called from any thread
public protocol HealthKitServiceProtocol: Sendable {

    // MARK: - Query Operations

    /// Queries health data for a specific type within a date range
    ///
    /// This is the primary method for retrieving health data from HealthKit.
    /// It supports various query options including sorting, limiting, aggregation,
    /// and filtering.
    ///
    /// - Parameters:
    ///   - type: The type of health data to query
    ///   - startDate: Start of the date range (inclusive)
    ///   - endDate: End of the date range (inclusive)
    ///   - options: Query configuration (sorting, aggregation, limits, etc.)
    /// - Returns: Array of health metrics matching the query
    /// - Throws: `HealthKitError` if the query fails
    ///
    /// **Example:**
    /// ```swift
    /// // Get today's hourly step count
    /// let steps = try await service.query(
    ///     type: .stepCount,
    ///     from: Date().startOfDay,
    ///     to: Date(),
    ///     options: .hourly
    /// )
    /// ```
    func query(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> [HealthMetric]

    /// Queries the most recent metric for a specific health data type
    ///
    /// Convenience method for getting the latest single value. Equivalent to
    /// calling `query()` with `options: .latest`.
    ///
    /// - Parameter type: The type of health data to query
    /// - Returns: The most recent metric, or nil if no data exists
    /// - Throws: `HealthKitError` if the query fails
    ///
    /// **Example:**
    /// ```swift
    /// // Get current weight
    /// if let weight = try await service.queryLatest(type: .bodyMass) {
    ///     print("Current weight: \(weight.value) kg")
    /// }
    /// ```
    func queryLatest(type: HealthDataType) async throws -> HealthMetric?

    /// Queries aggregated statistics for a health data type
    ///
    /// Returns statistical information (sum, average, min, max) for the specified
    /// time period. Useful for summary views and charts.
    ///
    /// - Parameters:
    ///   - type: The type of health data to query
    ///   - startDate: Start of the date range (inclusive)
    ///   - endDate: End of the date range (inclusive)
    ///   - options: Query configuration (must include aggregation method)
    /// - Returns: Statistical summary of the health data
    /// - Throws: `HealthKitError` if the query fails or aggregation is not specified
    ///
    /// **Example:**
    /// ```swift
    /// // Get daily step statistics for last 7 days
    /// let stats = try await service.queryStatistics(
    ///     type: .stepCount,
    ///     from: Date().addingTimeInterval(-7 * 86400),
    ///     to: Date(),
    ///     options: .daily
    /// )
    /// print("Average daily steps: \(stats.average)")
    /// ```
    func queryStatistics(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> HealthStatistics

    // MARK: - Write Operations

    /// Saves a new health metric to HealthKit
    ///
    /// Writes the metric to HealthKit, creating a new sample. The metric must
    /// be valid (pass validation) and the app must have write authorization
    /// for the metric's type.
    ///
    /// - Parameter metric: The health metric to save
    /// - Throws: `HealthKitError.notAuthorized` if write permission is missing
    /// - Throws: `HealthKitError.invalidData` if the metric fails validation
    /// - Throws: `HealthKitError.saveFailed` if HealthKit rejects the save
    ///
    /// **Example:**
    /// ```swift
    /// // Log a meditation session
    /// let session = HealthMetric.duration(
    ///     type: .mindfulSession,
    ///     value: 10,
    ///     unit: "min",
    ///     startDate: startDate,
    ///     endDate: endDate,
    ///     source: "Lume"
    /// )
    /// try await service.save(metric: session)
    /// ```
    func save(metric: HealthMetric) async throws

    /// Saves multiple health metrics to HealthKit in a batch
    ///
    /// More efficient than calling `save()` multiple times. Either all metrics
    /// are saved successfully, or none are (atomic operation).
    ///
    /// - Parameter metrics: Array of health metrics to save
    /// - Throws: `HealthKitError` if any metric fails to save
    ///
    /// **Example:**
    /// ```swift
    /// // Log multiple workout heart rate samples
    /// let heartRates = [
    ///     HealthMetric(type: .heartRate, value: 120, unit: "bpm", date: date1),
    ///     HealthMetric(type: .heartRate, value: 135, unit: "bpm", date: date2),
    ///     HealthMetric(type: .heartRate, value: 128, unit: "bpm", date: date3)
    /// ]
    /// try await service.saveBatch(metrics: heartRates)
    /// ```
    func saveBatch(metrics: [HealthMetric]) async throws

    // MARK: - Delete Operations

    /// Deletes a specific health metric from HealthKit
    ///
    /// Removes the sample with the given ID from HealthKit. The app must have
    /// write authorization for the metric's type to delete it.
    ///
    /// - Parameter metricID: Unique identifier of the metric to delete
    /// - Throws: `HealthKitError.notAuthorized` if write permission is missing
    /// - Throws: `HealthKitError.notFound` if the metric doesn't exist
    ///
    /// **Example:**
    /// ```swift
    /// // Delete an incorrect weight entry
    /// try await service.delete(metricID: incorrectWeight.id)
    /// ```
    func delete(metricID: UUID) async throws

    /// Deletes all metrics of a specific type within a date range
    ///
    /// **Warning:** This is a destructive operation. Use with caution.
    ///
    /// - Parameters:
    ///   - type: The type of health data to delete
    ///   - startDate: Start of the date range (inclusive)
    ///   - endDate: End of the date range (inclusive)
    /// - Returns: Number of metrics deleted
    /// - Throws: `HealthKitError.notAuthorized` if write permission is missing
    ///
    /// **Example:**
    /// ```swift
    /// // Delete all steps for today (e.g., after calibration)
    /// let deleted = try await service.deleteAll(
    ///     type: .stepCount,
    ///     from: Date().startOfDay,
    ///     to: Date()
    /// )
    /// print("Deleted \(deleted) step samples")
    /// ```
    func deleteAll(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Int

    // MARK: - Real-Time Observation

    /// Observes real-time changes to a specific health data type
    ///
    /// Returns an async stream that emits new metrics as they are added to
    /// HealthKit. Useful for live updates in the UI (e.g., showing current
    /// heart rate during a workout).
    ///
    /// The stream will continue emitting values until it is cancelled or the
    /// service is deallocated.
    ///
    /// - Parameter type: The type of health data to observe
    /// - Returns: Async stream of new health metrics
    ///
    /// **Example:**
    /// ```swift
    /// // Show live heart rate during workout
    /// Task {
    ///     for await heartRate in service.observeChanges(for: .heartRate) {
    ///         updateUI(heartRate: heartRate.value)
    ///     }
    /// }
    /// ```
    func observeChanges(for type: HealthDataType) -> AsyncStream<HealthMetric>

    /// Observes real-time changes to multiple health data types
    ///
    /// Similar to `observeChanges(for:)` but monitors multiple types
    /// simultaneously. The stream emits metrics as they are added for any
    /// of the specified types.
    ///
    /// - Parameter types: Set of health data types to observe
    /// - Returns: Async stream of new health metrics
    ///
    /// **Example:**
    /// ```swift
    /// // Monitor both heart rate and calories during workout
    /// let types: Set<HealthDataType> = [.heartRate, .activeEnergyBurned]
    /// Task {
    ///     for await metric in service.observeChanges(for: types) {
    ///         switch metric.type {
    ///         case .heartRate:
    ///             updateHeartRateUI(metric.value)
    ///         case .activeEnergyBurned:
    ///             updateCaloriesUI(metric.value)
    ///         default:
    ///             break
    ///         }
    ///     }
    /// }
    /// ```
    func observeChanges(for types: Set<HealthDataType>) -> AsyncStream<HealthMetric>

    // MARK: - Background Delivery

    /// Enables background delivery for a specific health data type
    ///
    /// Allows the app to receive updates even when it's not running in the
    /// foreground. The system will wake the app when new data is available.
    ///
    /// - Parameters:
    ///   - type: The type of health data to observe in background
    ///   - frequency: How often to check for updates
    /// - Throws: `HealthKitError.notAuthorized` if permission is missing
    ///
    /// **Example:**
    /// ```swift
    /// // Enable background step count updates
    /// try await service.enableBackgroundDelivery(
    ///     for: .stepCount,
    ///     frequency: .hourly
    /// )
    /// ```
    func enableBackgroundDelivery(
        for type: HealthDataType,
        frequency: BackgroundDeliveryFrequency
    ) async throws

    /// Disables background delivery for a specific health data type
    ///
    /// Stops receiving background updates for the specified type.
    ///
    /// - Parameter type: The type of health data to stop observing
    /// - Throws: `HealthKitError` if the operation fails
    func disableBackgroundDelivery(for type: HealthDataType) async throws

    // MARK: - Anchored Queries (Delta Updates)

    /// Queries new data since a previous query (delta/incremental update)
    ///
    /// Uses HealthKit's anchored query system to efficiently retrieve only
    /// new or changed data since the last query. This is much more efficient
    /// than re-querying all data.
    ///
    /// - Parameters:
    ///   - type: The type of health data to query
    ///   - anchor: Anchor from previous query (nil for first query)
    ///   - limit: Maximum number of results (nil for unlimited)
    /// - Returns: Tuple of new metrics and anchor for next query
    /// - Throws: `HealthKitError` if the query fails
    ///
    /// **Example:**
    /// ```swift
    /// // First query - get all data
    /// var (metrics, anchor) = try await service.queryNew(
    ///     type: .stepCount,
    ///     since: nil
    /// )
    /// processMetrics(metrics)
    ///
    /// // Later - get only new data
    /// (metrics, anchor) = try await service.queryNew(
    ///     type: .stepCount,
    ///     since: anchor
    /// )
    /// processNewMetrics(metrics) // Only new data since last query
    /// ```
    func queryNew(
        type: HealthDataType,
        since anchor: QueryAnchor?,
        limit: Int?
    ) async throws -> (metrics: [HealthMetric], newAnchor: QueryAnchor)
}

// MARK: - Supporting Types

/// Query anchor for incremental/delta queries
///
/// Represents a point in HealthKit's data timeline. Used to track which
/// data has already been queried to enable efficient incremental updates.
public struct QueryAnchor: Codable, Sendable, Hashable {
    /// Internal anchor data (opaque)
    let data: Data

    /// Creates a new query anchor from HealthKit data
    public init(data: Data) {
        self.data = data
    }
}

/// Frequency for background data delivery
public enum BackgroundDeliveryFrequency: String, Codable, Sendable, CaseIterable {
    /// Check for updates immediately when new data is available
    case immediate

    /// Check for updates hourly
    case hourly

    /// Check for updates daily
    case daily

    /// Check for updates weekly
    case weekly

    /// Human-readable description
    public var description: String {
        switch self {
        case .immediate: return "Immediate"
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

/// Statistical summary of health data
///
/// Provides aggregated statistics for a set of health metrics over a time period.
public struct HealthStatistics: Codable, Sendable {
    /// The health data type these statistics represent
    public let type: HealthDataType

    /// Start of the time period
    public let startDate: Date

    /// End of the time period
    public let endDate: Date

    /// Total sum of all values
    public let sum: Double?

    /// Average of all values
    public let average: Double?

    /// Minimum value in the period
    public let minimum: Double?

    /// Maximum value in the period
    public let maximum: Double?

    /// Number of data points
    public let count: Int

    /// Most recent value in the period
    public let mostRecent: Double?

    /// Unit of measurement
    public let unit: String

    /// Creates new health statistics
    public init(
        type: HealthDataType,
        startDate: Date,
        endDate: Date,
        sum: Double? = nil,
        average: Double? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        count: Int,
        mostRecent: Double? = nil,
        unit: String
    ) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.sum = sum
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.count = count
        self.mostRecent = mostRecent
        self.unit = unit
    }
}

// MARK: - Default Implementations

extension HealthKitServiceProtocol {
    /// Default implementation: queries latest by calling query with `.latest` options
    public func queryLatest(type: HealthDataType) async throws -> HealthMetric? {
        let metrics = try await query(
            type: type,
            from: Date.distantPast,
            to: Date(),
            options: .latest
        )
        return metrics.first
    }

    /// Default implementation: observes single type by calling multi-type observer
    public func observeChanges(for type: HealthDataType) -> AsyncStream<HealthMetric> {
        observeChanges(for: [type])
    }
}
