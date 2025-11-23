//
//  HealthAuthorizationScope.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Defines the scope of HealthKit authorization (read/write permissions)
///
/// This structure encapsulates which health data types an app needs to read from
/// and write to HealthKit. It provides a type-safe way to request permissions
/// and includes predefined scopes for common use cases.
///
/// **Usage:**
/// ```swift
/// // Custom scope
/// let scope = HealthAuthorizationScope(
///     read: [.stepCount, .heartRate],
///     write: [.bodyMass]
/// )
///
/// // Predefined scope
/// let fitnessScope = HealthAuthorizationScope.fitness
/// let mindfulnessScope = HealthAuthorizationScope.mindfulness
/// ```
///
/// **Architecture:** FitIQCore - Shared Domain Model
public struct HealthAuthorizationScope: Sendable, Hashable {

    // MARK: - Properties

    /// Health data types the app needs to read
    public let readTypes: Set<HealthDataType>

    /// Health data types the app needs to write
    public let writeTypes: Set<HealthDataType>

    // MARK: - Initialization

    /// Creates a new authorization scope with specified read/write types
    ///
    /// - Parameters:
    ///   - read: Set of health data types to request read permission for
    ///   - write: Set of health data types to request write permission for
    public init(read: Set<HealthDataType>, write: Set<HealthDataType>) {
        self.readTypes = read
        self.writeTypes = write
    }

    /// Creates an authorization scope with only read permissions
    ///
    /// - Parameter read: Set of health data types to request read permission for
    public init(readOnly: Set<HealthDataType>) {
        self.readTypes = readOnly
        self.writeTypes = []
    }

    /// Creates an authorization scope with only write permissions
    ///
    /// - Parameter write: Set of health data types to request write permission for
    public init(writeOnly: Set<HealthDataType>) {
        self.readTypes = []
        self.writeTypes = writeOnly
    }

    // MARK: - Computed Properties

    /// All data types included in this scope (read + write)
    public var allTypes: Set<HealthDataType> {
        readTypes.union(writeTypes)
    }

    /// Returns true if this scope requests read permission for the given type
    public func canRead(_ type: HealthDataType) -> Bool {
        readTypes.contains(type)
    }

    /// Returns true if this scope requests write permission for the given type
    public func canWrite(_ type: HealthDataType) -> Bool {
        writeTypes.contains(type)
    }

    /// Returns true if this scope has no permissions requested
    public var isEmpty: Bool {
        readTypes.isEmpty && writeTypes.isEmpty
    }
}

// MARK: - Predefined Scopes

extension HealthAuthorizationScope {

    /// Authorization scope for fitness tracking (FitIQ)
    ///
    /// **Read Permissions:**
    /// - Step count
    /// - Heart rate
    /// - Active energy burned
    /// - Basal energy burned
    /// - Body mass
    /// - Height
    /// - Distance walking/running
    /// - Flights climbed
    /// - Exercise time
    /// - Stand time
    /// - Sleep analysis
    ///
    /// **Write Permissions:**
    /// - Body mass (for manual weight logging)
    /// - Workouts (for workout tracking)
    public static var fitness: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [
                .stepCount,
                .heartRate,
                .activeEnergyBurned,
                .basalEnergyBurned,
                .bodyMass,
                .height,
                .distanceWalkingRunning,
                .flightsClimbed,
                .exerciseTime,
                .standTime,
                .sleepAnalysis,
            ],
            write: [
                .bodyMass,
                .workout(.running),
                .workout(.cycling),
                .workout(.walking),
                .workout(.traditionalStrengthTraining),
                .workout(.highIntensityIntervalTraining),
                .workout(.yoga),
            ]
        )
    }

    /// Authorization scope for mindfulness tracking (Lume)
    ///
    /// **Read Permissions:**
    /// - Mindful sessions
    /// - Heart rate
    /// - Heart rate variability
    /// - Respiratory rate
    /// - Oxygen saturation
    ///
    /// **Write Permissions:**
    /// - Mindful sessions (for meditation logging)
    /// - Meditation workouts
    /// - Yoga workouts
    public static var mindfulness: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [
                .mindfulSession,
                .heartRate,
                .heartRateVariability,
                .respiratoryRate,
                .oxygenSaturation,
            ],
            write: [
                .mindfulSession,
                .workout(.meditation),
                .workout(.yoga),
                .workout(.tai_chi),
            ]
        )
    }

    /// Authorization scope for basic health metrics (both apps)
    ///
    /// **Read Permissions:**
    /// - Heart rate
    /// - Respiratory rate
    /// - Oxygen saturation
    ///
    /// **Write Permissions:** None
    public static var basicHealth: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [
                .heartRate,
                .respiratoryRate,
                .oxygenSaturation,
            ],
            write: []
        )
    }

    /// Authorization scope for body measurements
    ///
    /// **Read Permissions:**
    /// - Body mass
    /// - Height
    ///
    /// **Write Permissions:**
    /// - Body mass (for manual weight logging)
    public static var bodyMeasurements: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [
                .bodyMass,
                .height,
            ],
            write: [
                .bodyMass
            ]
        )
    }

    /// Authorization scope for activity tracking
    ///
    /// **Read Permissions:**
    /// - Step count
    /// - Distance walking/running
    /// - Flights climbed
    /// - Exercise time
    /// - Stand time
    /// - Active energy burned
    ///
    /// **Write Permissions:** None
    public static var activity: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [
                .stepCount,
                .distanceWalkingRunning,
                .flightsClimbed,
                .exerciseTime,
                .standTime,
                .activeEnergyBurned,
            ],
            write: []
        )
    }

    /// Authorization scope for sleep tracking
    ///
    /// **Read Permissions:**
    /// - Sleep analysis
    ///
    /// **Write Permissions:** None
    public static var sleep: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [.sleepAnalysis],
            write: []
        )
    }
}

// MARK: - Combining Scopes

extension HealthAuthorizationScope {

    /// Merges this scope with another scope, combining all permissions
    ///
    /// - Parameter other: Another authorization scope to merge with
    /// - Returns: A new scope containing all permissions from both scopes
    public func merged(with other: HealthAuthorizationScope) -> HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: self.readTypes.union(other.readTypes),
            write: self.writeTypes.union(other.writeTypes)
        )
    }

    /// Creates a new scope by adding read permissions
    ///
    /// - Parameter types: Additional types to request read permission for
    /// - Returns: A new scope with added read permissions
    public func addingRead(_ types: Set<HealthDataType>) -> HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: self.readTypes.union(types),
            write: self.writeTypes
        )
    }

    /// Creates a new scope by adding write permissions
    ///
    /// - Parameter types: Additional types to request write permission for
    /// - Returns: A new scope with added write permissions
    public func addingWrite(_ types: Set<HealthDataType>) -> HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: self.readTypes,
            write: self.writeTypes.union(types)
        )
    }

    /// Creates a new scope by removing permissions for specific types
    ///
    /// - Parameter types: Types to remove from both read and write permissions
    /// - Returns: A new scope without the specified types
    public func removing(_ types: Set<HealthDataType>) -> HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: self.readTypes.subtracting(types),
            write: self.writeTypes.subtracting(types)
        )
    }
}

// MARK: - CustomStringConvertible

extension HealthAuthorizationScope: CustomStringConvertible {
    /// Human-readable description of the authorization scope
    public var description: String {
        let readCount = readTypes.count
        let writeCount = writeTypes.count
        return "HealthAuthorizationScope(read: \(readCount) types, write: \(writeCount) types)"
    }
}

// MARK: - CustomDebugStringConvertible

extension HealthAuthorizationScope: CustomDebugStringConvertible {
    /// Detailed debug description showing all requested permissions
    public var debugDescription: String {
        var lines = ["HealthAuthorizationScope:"]

        if !readTypes.isEmpty {
            lines.append("  Read (\(readTypes.count)):")
            for type in readTypes.sorted(by: { $0.description < $1.description }) {
                lines.append("    - \(type.description)")
            }
        }

        if !writeTypes.isEmpty {
            lines.append("  Write (\(writeTypes.count)):")
            for type in writeTypes.sorted(by: { $0.description < $1.description }) {
                lines.append("    - \(type.description)")
            }
        }

        if isEmpty {
            lines.append("  (empty)")
        }

        return lines.joined(separator: "\n")
    }
}
