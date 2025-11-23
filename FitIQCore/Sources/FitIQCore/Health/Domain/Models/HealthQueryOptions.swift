//
//  HealthQueryOptions.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Configuration options for querying health data from HealthKit
///
/// This model provides fine-grained control over how health data is retrieved,
/// including sorting, limiting, aggregation, and filtering options.
///
/// **Usage:**
/// ```swift
/// // Get today's step count with hourly aggregation
/// let options = HealthQueryOptions(
///     limit: nil,
///     sortOrder: .chronological,
///     aggregation: .hourly,
///     includeSource: true
/// )
///
/// let metrics = try await healthService.query(
///     type: .stepCount,
///     from: Date().startOfDay,
///     to: Date(),
///     options: options
/// )
/// ```
///
/// **Thread Safety:** This is an immutable value type and is thread-safe.
///
/// **Architecture:** FitIQCore - Shared Domain Model
public struct HealthQueryOptions: Sendable, Hashable, Codable {

    // MARK: - Properties

    /// Maximum number of results to return (nil = unlimited)
    public let limit: Int?

    /// Sort order for results
    public let sortOrder: SortOrder

    /// Time-based aggregation method (nil = no aggregation)
    public let aggregation: AggregationMethod?

    /// Whether to include source information (app/device name)
    public let includeSource: Bool

    /// Whether to include device information
    public let includeDevice: Bool

    /// Whether to include metadata (e.g., workout type, sleep stage)
    public let includeMetadata: Bool

    /// Minimum value filter (exclude results below this threshold)
    public let minimumValue: Double?

    /// Maximum value filter (exclude results above this threshold)
    public let maximumValue: Double?

    /// Filter by specific sources (e.g., ["Apple Watch", "Lume App"])
    public let sourcesFilter: Set<String>?

    // MARK: - Initialization

    /// Creates query options with specified configuration
    ///
    /// - Parameters:
    ///   - limit: Maximum results to return (nil = unlimited)
    ///   - sortOrder: How to sort results (defaults to chronological)
    ///   - aggregation: Time-based aggregation method (defaults to none)
    ///   - includeSource: Include source app/device name (defaults to false)
    ///   - includeDevice: Include device information (defaults to false)
    ///   - includeMetadata: Include additional metadata (defaults to false)
    ///   - minimumValue: Filter out values below this (defaults to nil)
    ///   - maximumValue: Filter out values above this (defaults to nil)
    ///   - sourcesFilter: Only include specific sources (defaults to nil)
    public init(
        limit: Int? = nil,
        sortOrder: SortOrder = .chronological,
        aggregation: AggregationMethod? = nil,
        includeSource: Bool = false,
        includeDevice: Bool = false,
        includeMetadata: Bool = false,
        minimumValue: Double? = nil,
        maximumValue: Double? = nil,
        sourcesFilter: Set<String>? = nil
    ) {
        self.limit = limit
        self.sortOrder = sortOrder
        self.aggregation = aggregation
        self.includeSource = includeSource
        self.includeDevice = includeDevice
        self.includeMetadata = includeMetadata
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.sourcesFilter = sourcesFilter
    }

    // MARK: - Sort Order

    /// Sort order for query results
    public enum SortOrder: String, Sendable, Hashable, Codable, CaseIterable {
        /// Oldest to newest (ascending by date)
        case chronological

        /// Newest to oldest (descending by date)
        case reverseChronological

        /// Lowest to highest value
        case ascending

        /// Highest to lowest value
        case descending

        /// Human-readable description
        public var description: String {
            switch self {
            case .chronological:
                return "Oldest First"
            case .reverseChronological:
                return "Newest First"
            case .ascending:
                return "Lowest First"
            case .descending:
                return "Highest First"
            }
        }
    }

    // MARK: - Aggregation Method

    /// Time-based aggregation for combining multiple data points
    public enum AggregationMethod: Sendable, Hashable, Codable {
        /// Sum values within each time bucket
        case sum(TimeBucket)

        /// Average values within each time bucket
        case average(TimeBucket)

        /// Minimum value within each time bucket
        case minimum(TimeBucket)

        /// Maximum value within each time bucket
        case maximum(TimeBucket)

        /// Count data points within each time bucket
        case count(TimeBucket)

        /// Time bucket for aggregation
        public enum TimeBucket: String, Sendable, Hashable, Codable, CaseIterable {
            case hourly
            case daily
            case weekly
            case monthly

            /// Human-readable description
            public var description: String {
                switch self {
                case .hourly: return "Hourly"
                case .daily: return "Daily"
                case .weekly: return "Weekly"
                case .monthly: return "Monthly"
                }
            }

            /// Duration in seconds
            public var duration: TimeInterval {
                switch self {
                case .hourly: return 3600
                case .daily: return 86400
                case .weekly: return 604800
                case .monthly: return 2_592_000  // 30 days
                }
            }
        }

        /// The time bucket being used for aggregation
        public var timeBucket: TimeBucket {
            switch self {
            case .sum(let bucket),
                .average(let bucket),
                .minimum(let bucket),
                .maximum(let bucket),
                .count(let bucket):
                return bucket
            }
        }

        /// Human-readable description
        public var description: String {
            switch self {
            case .sum(let bucket):
                return "Sum (\(bucket.description))"
            case .average(let bucket):
                return "Average (\(bucket.description))"
            case .minimum(let bucket):
                return "Minimum (\(bucket.description))"
            case .maximum(let bucket):
                return "Maximum (\(bucket.description))"
            case .count(let bucket):
                return "Count (\(bucket.description))"
            }
        }

        // MARK: - Codable Support

        private enum CodingKeys: String, CodingKey {
            case type, bucket
        }

        private enum AggregationType: String, Codable {
            case sum, average, minimum, maximum, count
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(AggregationType.self, forKey: .type)
            let bucket = try container.decode(TimeBucket.self, forKey: .bucket)

            switch type {
            case .sum:
                self = .sum(bucket)
            case .average:
                self = .average(bucket)
            case .minimum:
                self = .minimum(bucket)
            case .maximum:
                self = .maximum(bucket)
            case .count:
                self = .count(bucket)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            let (type, bucket): (AggregationType, TimeBucket) =
                switch self {
                case .sum(let b): (.sum, b)
                case .average(let b): (.average, b)
                case .minimum(let b): (.minimum, b)
                case .maximum(let b): (.maximum, b)
                case .count(let b): (.count, b)
                }

            try container.encode(type, forKey: .type)
            try container.encode(bucket, forKey: .bucket)
        }
    }
}

// MARK: - Preset Configurations

extension HealthQueryOptions {
    /// Default query options (no aggregation, chronological, unlimited)
    public static let `default` = HealthQueryOptions()

    /// Query options for latest single value (newest, limit 1)
    public static let latest = HealthQueryOptions(
        limit: 1,
        sortOrder: .reverseChronological
    )

    /// Query options for hourly aggregated data (sum by hour)
    public static let hourly = HealthQueryOptions(
        sortOrder: .chronological,
        aggregation: .sum(.hourly)
    )

    /// Query options for daily aggregated data (sum by day)
    public static let daily = HealthQueryOptions(
        sortOrder: .chronological,
        aggregation: .sum(.daily)
    )

    /// Query options for weekly aggregated data (sum by week)
    public static let weekly = HealthQueryOptions(
        sortOrder: .chronological,
        aggregation: .sum(.weekly)
    )

    /// Query options for daily average
    public static let dailyAverage = HealthQueryOptions(
        sortOrder: .chronological,
        aggregation: .average(.daily)
    )

    /// Query options with full metadata (source, device, metadata)
    public static let detailed = HealthQueryOptions(
        includeSource: true,
        includeDevice: true,
        includeMetadata: true
    )

    /// Query options for top N results (highest values first)
    ///
    /// - Parameter count: Number of top results to return
    /// - Returns: Query options configured for top N
    public static func top(_ count: Int) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: count,
            sortOrder: .descending
        )
    }

    /// Query options for most recent N results
    ///
    /// - Parameter count: Number of recent results to return
    /// - Returns: Query options configured for recent N
    public static func recent(_ count: Int) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: count,
            sortOrder: .reverseChronological
        )
    }
}

// MARK: - Validation

extension HealthQueryOptions {
    /// Validates that the options are consistent and reasonable
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Limit validation
        if let limit = limit, limit <= 0 {
            errors.append(.invalidLimit)
        }

        // Value range validation
        if let min = minimumValue, let max = maximumValue, min > max {
            errors.append(.invalidValueRange)
        }

        // Sources filter validation
        if let sources = sourcesFilter, sources.isEmpty {
            errors.append(.emptySourcesFilter)
        }

        return errors
    }

    /// Validation errors for query options
    public enum ValidationError: Error, LocalizedError, Equatable, Sendable {
        case invalidLimit
        case invalidValueRange
        case emptySourcesFilter

        public var errorDescription: String? {
            switch self {
            case .invalidLimit:
                return "Limit must be greater than 0"
            case .invalidValueRange:
                return "Minimum value cannot be greater than maximum value"
            case .emptySourcesFilter:
                return "Sources filter cannot be empty"
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension HealthQueryOptions: CustomStringConvertible {
    /// Human-readable description of the query options
    public var description: String {
        var parts: [String] = []

        if let limit = limit {
            parts.append("limit: \(limit)")
        }

        parts.append("sort: \(sortOrder.description)")

        if let aggregation = aggregation {
            parts.append("aggregation: \(aggregation.description)")
        }

        if includeSource {
            parts.append("with source")
        }

        if includeDevice {
            parts.append("with device")
        }

        if includeMetadata {
            parts.append("with metadata")
        }

        if let min = minimumValue {
            parts.append("min: \(min)")
        }

        if let max = maximumValue {
            parts.append("max: \(max)")
        }

        if let sources = sourcesFilter {
            parts.append("sources: \(sources.joined(separator: ", "))")
        }

        return "HealthQueryOptions(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Builder Pattern

extension HealthQueryOptions {
    /// Creates a copy with modified limit
    public func withLimit(_ limit: Int?) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: includeSource,
            includeDevice: includeDevice,
            includeMetadata: includeMetadata,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            sourcesFilter: sourcesFilter
        )
    }

    /// Creates a copy with modified sort order
    public func withSortOrder(_ sortOrder: SortOrder) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: includeSource,
            includeDevice: includeDevice,
            includeMetadata: includeMetadata,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            sourcesFilter: sourcesFilter
        )
    }

    /// Creates a copy with modified aggregation
    public func withAggregation(_ aggregation: AggregationMethod?) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: includeSource,
            includeDevice: includeDevice,
            includeMetadata: includeMetadata,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            sourcesFilter: sourcesFilter
        )
    }

    /// Creates a copy with metadata flags enabled
    public func withMetadata() -> HealthQueryOptions {
        HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: true,
            includeDevice: true,
            includeMetadata: true,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            sourcesFilter: sourcesFilter
        )
    }

    /// Creates a copy with value range filter
    public func withValueRange(min: Double?, max: Double?) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: includeSource,
            includeDevice: includeDevice,
            includeMetadata: includeMetadata,
            minimumValue: min,
            maximumValue: max,
            sourcesFilter: sourcesFilter
        )
    }

    /// Creates a copy with sources filter
    public func withSourcesFilter(_ sources: Set<String>?) -> HealthQueryOptions {
        HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: includeSource,
            includeDevice: includeDevice,
            includeMetadata: includeMetadata,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            sourcesFilter: sources
        )
    }
}
