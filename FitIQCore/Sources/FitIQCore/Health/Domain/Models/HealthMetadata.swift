//
//  HealthMetadata.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 6.5: Technical Debt Resolution
//

import Foundation

/// Standardized metadata keys for health data
///
/// Provides type-safe constants for metadata keys used across HealthKit operations.
/// Using these constants instead of string literals prevents typos and makes
/// refactoring easier.
///
/// **Usage:**
/// ```swift
/// let metadata: [String: String] = [
///     HealthMetadata.Key.source: HealthMetadata.Source.manual,
///     HealthMetadata.Key.device: "iPhone 15",
///     HealthMetadata.Key.appVersion: "1.0.0"
/// ]
///
/// // Save with metadata
/// let metric = HealthMetric(
///     type: .weight,
///     value: 70.5,
///     unit: "kg",
///     date: Date(),
///     source: HealthMetadata.Source.manual,
///     metadata: metadata
/// )
/// ```
///
/// **Architecture:** FitIQCore - Shared Domain Model
public enum HealthMetadata {

    // MARK: - Metadata Keys

    /// Standardized keys for health data metadata
    public enum Key {
        /// Data source identifier (e.g., "manual", "healthkit", "api")
        public static let source = "source"

        /// Device identifier (e.g., "iPhone 15", "Apple Watch Series 9")
        public static let device = "device"

        /// App version that created the data (e.g., "1.0.0")
        public static let appVersion = "app_version"

        /// Timestamp when data was synced to backend
        public static let syncedAt = "synced_at"

        /// Indicates if data was manually entered by user
        public static let manualEntry = "manual_entry"

        /// Indicates if data was imported from another source
        public static let imported = "imported"

        /// Import source identifier (e.g., "GoogleFit", "Strava")
        public static let importSource = "import_source"

        /// User-provided notes or comments
        public static let notes = "notes"

        /// Session identifier for grouped data (e.g., workout session)
        public static let sessionId = "session_id"

        /// Workout name (for workout-specific metadata)
        public static let workoutName = "workout_name"

        /// Workout intensity level (for workout-specific metadata)
        public static let workoutIntensity = "workout_intensity"

        /// Workout activity type (for workout-specific metadata)
        public static let workoutActivityType = "workout_activity_type"

        /// Total energy burned (for workout-specific metadata)
        public static let totalEnergyBurned = "total_energy_burned"

        /// Total distance (for workout-specific metadata)
        public static let totalDistance = "total_distance"

        /// Data confidence level (e.g., "high", "medium", "low")
        public static let confidence = "confidence"

        /// Original data format (for imported data)
        public static let originalFormat = "original_format"

        /// Timezone when data was recorded
        public static let timezone = "timezone"

        /// Location where data was recorded (if applicable)
        public static let location = "location"

        /// Weather conditions during recording (if applicable)
        public static let weather = "weather"

        /// Equipment used (for workout data)
        public static let equipment = "equipment"

        /// User mood at time of recording (for mood tracking)
        public static let mood = "mood"

        /// Energy level at time of recording
        public static let energyLevel = "energy_level"

        /// Sleep quality rating (for sleep data)
        public static let sleepQuality = "sleep_quality"

        /// Data validation status
        public static let validated = "validated"

        /// Error or warning messages
        public static let errorMessage = "error_message"

        /// Retry count for failed operations
        public static let retryCount = "retry_count"

        /// Original record ID from external system
        public static let externalId = "external_id"

        /// Data processing version
        public static let processingVersion = "processing_version"
    }

    // MARK: - Common Source Values

    /// Common values for the `source` metadata key
    public enum Source {
        /// Data manually entered by user in FitIQ app
        public static let manual = "manual"

        /// Data from FitIQ app
        public static let fitiq = "FitIQ"

        /// Data from Lume app
        public static let lume = "Lume"

        /// Data from Apple HealthKit
        public static let healthkit = "HealthKit"

        /// Data from Apple Health app
        public static let appleHealth = "Apple Health"

        /// Data from API sync
        public static let api = "API"

        /// Data imported from external source
        public static let imported = "imported"

        /// Data from automated sensor/device
        public static let device = "device"

        /// Data estimated or calculated
        public static let estimated = "estimated"

        /// Data from third-party integration
        public static let thirdParty = "third_party"
    }

    // MARK: - Common Device Values

    /// Common values for the `device` metadata key
    public enum Device {
        /// iPhone device
        public static let iphone = "iPhone"

        /// Apple Watch
        public static let appleWatch = "Apple Watch"

        /// iPad device
        public static let ipad = "iPad"

        /// Unknown or unspecified device
        public static let unknown = "Unknown"

        /// Returns device identifier with model info if available
        public static func current() -> String {
            #if os(iOS)
                return "iPhone"
            #elseif os(watchOS)
                return "Apple Watch"
            #elseif os(macOS)
                return "Mac"
            #else
                return "Unknown"
            #endif
        }
    }

    // MARK: - Common Confidence Values

    /// Common values for the `confidence` metadata key
    public enum Confidence {
        /// High confidence in data accuracy
        public static let high = "high"

        /// Medium confidence in data accuracy
        public static let medium = "medium"

        /// Low confidence in data accuracy
        public static let low = "low"

        /// Unknown confidence level
        public static let unknown = "unknown"
    }

    // MARK: - Boolean String Values

    /// Common boolean string representations
    public enum BoolString {
        public static let `true` = "true"
        public static let `false` = "false"
    }

    // MARK: - Helper Methods

    /// Creates basic metadata dictionary with common fields
    ///
    /// - Parameters:
    ///   - source: Data source identifier
    ///   - device: Device identifier (defaults to current device)
    ///   - manualEntry: Whether data was manually entered
    ///   - notes: Optional user notes
    /// - Returns: Metadata dictionary ready to use
    ///
    /// **Example:**
    /// ```swift
    /// let metadata = HealthMetadata.create(
    ///     source: HealthMetadata.Source.manual,
    ///     manualEntry: true,
    ///     notes: "Morning weigh-in"
    /// )
    /// ```
    public static func create(
        source: String,
        device: String? = nil,
        manualEntry: Bool = false,
        notes: String? = nil
    ) -> [String: String] {
        var metadata: [String: String] = [
            Key.source: source,
            Key.device: device ?? Device.current(),
            Key.manualEntry: manualEntry ? BoolString.true : BoolString.false,
        ]

        if let notes = notes, !notes.isEmpty {
            metadata[Key.notes] = notes
        }

        return metadata
    }

    /// Creates metadata for manual user entry
    ///
    /// Convenience method for the common case of manually entered data.
    ///
    /// - Parameters:
    ///   - notes: Optional user notes
    ///   - device: Device identifier (defaults to current device)
    /// - Returns: Metadata dictionary for manual entry
    ///
    /// **Example:**
    /// ```swift
    /// let metadata = HealthMetadata.manualEntry(notes: "Before breakfast")
    /// ```
    public static func manualEntry(
        notes: String? = nil,
        device: String? = nil
    ) -> [String: String] {
        create(
            source: Source.manual,
            device: device,
            manualEntry: true,
            notes: notes
        )
    }

    /// Creates metadata for HealthKit-sourced data
    ///
    /// Convenience method for data imported from HealthKit.
    ///
    /// - Parameter device: Device identifier (defaults to current device)
    /// - Returns: Metadata dictionary for HealthKit data
    ///
    /// **Example:**
    /// ```swift
    /// let metadata = HealthMetadata.fromHealthKit()
    /// ```
    public static func fromHealthKit(device: String? = nil) -> [String: String] {
        create(
            source: Source.healthkit,
            device: device,
            manualEntry: false
        )
    }

    /// Creates metadata for API-synced data
    ///
    /// Convenience method for data synced from backend API.
    ///
    /// - Parameter syncedAt: Timestamp when data was synced
    /// - Returns: Metadata dictionary for API data
    ///
    /// **Example:**
    /// ```swift
    /// let metadata = HealthMetadata.fromAPI(syncedAt: Date())
    /// ```
    public static func fromAPI(syncedAt: Date? = nil) -> [String: String] {
        var metadata = create(
            source: Source.api,
            manualEntry: false
        )

        if let syncedAt = syncedAt {
            let formatter = ISO8601DateFormatter()
            metadata[Key.syncedAt] = formatter.string(from: syncedAt)
        }

        return metadata
    }

    /// Creates metadata for imported data
    ///
    /// Convenience method for data imported from external sources.
    ///
    /// - Parameters:
    ///   - importSource: Source of the import (e.g., "GoogleFit", "Strava")
    ///   - externalId: Original record ID from external system
    /// - Returns: Metadata dictionary for imported data
    ///
    /// **Example:**
    /// ```swift
    /// let metadata = HealthMetadata.imported(
    ///     from: "GoogleFit",
    ///     externalId: "abc123"
    /// )
    /// ```
    public static func imported(
        from importSource: String,
        externalId: String? = nil
    ) -> [String: String] {
        var metadata = create(
            source: Source.imported,
            manualEntry: false
        )

        metadata[Key.importSource] = importSource
        metadata[Key.imported] = BoolString.true

        if let externalId = externalId {
            metadata[Key.externalId] = externalId
        }

        return metadata
    }

    /// Merges multiple metadata dictionaries, with later ones taking precedence
    ///
    /// - Parameter metadataArray: Array of metadata dictionaries to merge
    /// - Returns: Merged metadata dictionary
    ///
    /// **Example:**
    /// ```swift
    /// let base = HealthMetadata.manualEntry()
    /// let extra = [HealthMetadata.Key.notes: "Extra info"]
    /// let merged = HealthMetadata.merge(base, extra)
    /// ```
    public static func merge(_ metadataArray: [String: String]...) -> [String: String] {
        var result: [String: String] = [:]
        for metadata in metadataArray {
            result.merge(metadata) { _, new in new }
        }
        return result
    }
}

// MARK: - Convenience Extensions

extension Dictionary where Key == String, Value == String {
    /// Returns the source value from metadata
    public var healthSource: String? {
        self[HealthMetadata.Key.source]
    }

    /// Returns whether data was manually entered
    public var isManualEntry: Bool {
        self[HealthMetadata.Key.manualEntry] == HealthMetadata.BoolString.true
    }

    /// Returns whether data was imported
    public var isImported: Bool {
        self[HealthMetadata.Key.imported] == HealthMetadata.BoolString.true
    }

    /// Returns user notes from metadata
    public var healthNotes: String? {
        self[HealthMetadata.Key.notes]
    }

    /// Returns device identifier from metadata
    public var healthDevice: String? {
        self[HealthMetadata.Key.device]
    }
}
