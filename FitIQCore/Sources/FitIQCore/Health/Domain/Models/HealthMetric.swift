//
//  HealthMetric.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Represents a single health data measurement with value, type, and metadata
///
/// This is the core data model for all health metrics retrieved from HealthKit.
/// It provides a type-safe, platform-agnostic representation that works across
/// both FitIQ and Lume applications.
///
/// **Usage:**
/// ```swift
/// // Query heart rate data
/// let metrics = try await healthService.query(
///     type: .heartRate,
///     from: startDate,
///     to: endDate,
///     options: .default
/// )
///
/// // Access metric values
/// for metric in metrics {
///     print("\(metric.type): \(metric.value) \(metric.unit) at \(metric.date)")
/// }
/// ```
///
/// **Thread Safety:** This is an immutable value type and is thread-safe.
///
/// **Architecture:** FitIQCore - Shared Domain Model
public struct HealthMetric: Sendable, Hashable, Identifiable {

    // MARK: - Properties

    /// Unique identifier for this metric
    public let id: UUID

    /// The type of health data this metric represents
    public let type: HealthDataType

    /// The measured value (e.g., 72 for heart rate, 10000 for steps)
    public let value: Double

    /// The unit of measurement (e.g., "bpm", "steps", "kg")
    public let unit: String

    /// When this measurement was recorded
    public let date: Date

    /// Start date for duration-based metrics (e.g., workouts, sleep)
    public let startDate: Date?

    /// End date for duration-based metrics (e.g., workouts, sleep)
    public let endDate: Date?

    /// Source of the data (e.g., "Apple Watch", "iPhone", "Lume App")
    public let source: String?

    /// Device that recorded the measurement (e.g., "Apple Watch Series 8")
    public let device: String?

    /// Additional metadata (workout type, sleep stage, etc.)
    public let metadata: [String: String]

    // MARK: - Initialization

    /// Creates a new health metric
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - type: The type of health data
    ///   - value: The measured value
    ///   - unit: Unit of measurement
    ///   - date: When measurement was recorded
    ///   - startDate: Start date for duration-based metrics (optional)
    ///   - endDate: End date for duration-based metrics (optional)
    ///   - source: Data source name (optional)
    ///   - device: Recording device name (optional)
    ///   - metadata: Additional key-value metadata (optional)
    public init(
        id: UUID = UUID(),
        type: HealthDataType,
        value: Double,
        unit: String,
        date: Date,
        startDate: Date? = nil,
        endDate: Date? = nil,
        source: String? = nil,
        device: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.date = date
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
        self.device = device
        self.metadata = metadata
    }
}

// MARK: - Computed Properties

extension HealthMetric {
    /// Duration in seconds for duration-based metrics (workout, sleep)
    ///
    /// Returns nil if either startDate or endDate is missing.
    public var duration: TimeInterval? {
        guard let start = startDate, let end = endDate else { return nil }
        return end.timeIntervalSince(start)
    }

    /// Duration formatted as human-readable string (e.g., "45 min", "1h 30m")
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes) min"
        }
    }

    /// Formatted value with unit (e.g., "72 bpm", "10,000 steps")
    public var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = type.isQuantityType ? 1 : 0

        guard let formatted = formatter.string(from: NSNumber(value: value)) else {
            return "\(value) \(unit)"
        }

        return "\(formatted) \(unit)"
    }

    /// Returns true if this is a duration-based metric (has start and end dates)
    public var isDurationBased: Bool {
        startDate != nil && endDate != nil
    }

    /// Returns true if this metric was recorded today
    public var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Validation

extension HealthMetric {
    /// Validates that the metric data is consistent and reasonable
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Value validation
        if value.isNaN || value.isInfinite {
            errors.append(.invalidValue)
        }

        if value < 0 && !type.allowsNegativeValues {
            errors.append(.negativeValue)
        }

        // Date validation
        if date > Date() {
            errors.append(.futureDate)
        }

        // Duration validation
        if let start = startDate, let end = endDate {
            if end < start {
                errors.append(.endBeforeStart)
            }

            if end.timeIntervalSince(start) > 86400 * 7 {
                // More than 7 days
                errors.append(.durationTooLong)
            }
        }

        // Duration-based type validation
        if type.requiresDuration && (startDate == nil || endDate == nil) {
            errors.append(.missingDuration)
        }

        return errors
    }

    /// Validation errors for health metrics
    public enum ValidationError: Error, LocalizedError, Equatable, Sendable {
        case invalidValue
        case negativeValue
        case futureDate
        case endBeforeStart
        case durationTooLong
        case missingDuration

        public var errorDescription: String? {
            switch self {
            case .invalidValue:
                return "Metric value is invalid (NaN or infinite)"
            case .negativeValue:
                return "Metric value cannot be negative"
            case .futureDate:
                return "Metric date cannot be in the future"
            case .endBeforeStart:
                return "End date must be after start date"
            case .durationTooLong:
                return "Duration exceeds maximum allowed (7 days)"
            case .missingDuration:
                return "This metric type requires start and end dates"
            }
        }
    }
}

// MARK: - HealthDataType Extensions

extension HealthDataType {
    /// Returns true if this type allows negative values
    fileprivate var allowsNegativeValues: Bool {
        // Most health metrics don't allow negative values
        // This could be expanded if needed for specific types
        false
    }

    /// Returns true if this type requires duration (start/end dates)
    fileprivate var requiresDuration: Bool {
        switch self {
        case .workout, .sleepAnalysis, .mindfulSession:
            return true
        default:
            return false
        }
    }
}

// MARK: - Codable

extension HealthMetric: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case unit
        case date
        case startDate
        case endDate
        case source
        case device
        case metadata
    }
}

// MARK: - CustomStringConvertible

extension HealthMetric: CustomStringConvertible {
    /// Human-readable description of the metric
    public var description: String {
        var parts: [String] = [
            "\(type.description):",
            formattedValue,
        ]

        if let duration = formattedDuration {
            parts.append("(\(duration))")
        }

        if let source = source {
            parts.append("from \(source)")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Comparable

extension HealthMetric: Comparable {
    /// Metrics are ordered by date (most recent first)
    public static func < (lhs: HealthMetric, rhs: HealthMetric) -> Bool {
        lhs.date < rhs.date
    }
}

// MARK: - Factory Methods

extension HealthMetric {
    /// Creates a simple quantity metric (no duration)
    ///
    /// - Parameters:
    ///   - type: Health data type
    ///   - value: Measured value
    ///   - unit: Unit of measurement
    ///   - date: Recording date (defaults to now)
    ///   - source: Data source (optional)
    /// - Returns: New HealthMetric instance
    public static func quantity(
        type: HealthDataType,
        value: Double,
        unit: String,
        date: Date = Date(),
        source: String? = nil
    ) -> HealthMetric {
        HealthMetric(
            type: type,
            value: value,
            unit: unit,
            date: date,
            source: source
        )
    }

    /// Creates a duration-based metric (workout, sleep, mindfulness)
    ///
    /// - Parameters:
    ///   - type: Health data type
    ///   - value: Measured value (e.g., total calories)
    ///   - unit: Unit of measurement
    ///   - startDate: When activity started
    ///   - endDate: When activity ended
    ///   - source: Data source (optional)
    ///   - metadata: Additional metadata (optional)
    /// - Returns: New HealthMetric instance
    public static func duration(
        type: HealthDataType,
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date,
        source: String? = nil,
        metadata: [String: String] = [:]
    ) -> HealthMetric {
        HealthMetric(
            type: type,
            value: value,
            unit: unit,
            date: endDate,  // Use end date as primary date
            startDate: startDate,
            endDate: endDate,
            source: source,
            metadata: metadata
        )
    }
}

// MARK: - Collection Extensions

extension Collection where Element == HealthMetric {
    /// Returns metrics filtered by date range
    ///
    /// - Parameters:
    ///   - start: Start date (inclusive)
    ///   - end: End date (inclusive)
    /// - Returns: Filtered metrics
    public func inDateRange(from start: Date, to end: Date) -> [HealthMetric] {
        filter { metric in
            metric.date >= start && metric.date <= end
        }
    }

    /// Returns metrics of a specific type
    ///
    /// - Parameter type: Health data type to filter by
    /// - Returns: Filtered metrics
    public func ofType(_ type: HealthDataType) -> [HealthMetric] {
        filter { $0.type == type }
    }

    /// Returns metrics sorted by date (newest first)
    public var sortedByDateDescending: [HealthMetric] {
        sorted { $0.date > $1.date }
    }

    /// Returns metrics sorted by date (oldest first)
    public var sortedByDateAscending: [HealthMetric] {
        sorted { $0.date < $1.date }
    }

    /// Calculates total/sum of metric values
    public var total: Double {
        reduce(0) { $0 + $1.value }
    }

    /// Calculates average of metric values
    public var average: Double? {
        guard !isEmpty else { return nil }
        return total / Double(count)
    }

    /// Returns the minimum metric value
    public var minimum: Double? {
        map(\.value).min()
    }

    /// Returns the maximum metric value
    public var maximum: Double? {
        map(\.value).max()
    }
}
