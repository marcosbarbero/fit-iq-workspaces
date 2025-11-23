//
//  HealthAuthorizationServiceProtocol.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Interface for managing HealthKit authorization and permissions
///
/// This protocol defines operations for requesting, checking, and managing
/// HealthKit permissions. It abstracts authorization logic to provide a clean,
/// testable interface across both FitIQ and Lume applications.
///
/// **Usage:**
/// ```swift
/// // Request authorization for fitness data
/// let scope = HealthAuthorizationScope(
///     read: [.stepCount, .heartRate, .activeEnergyBurned],
///     write: [.bodyMass, .workout(.running)]
/// )
/// try await authService.requestAuthorization(scope: scope)
///
/// // Check if authorized
/// if authService.isAuthorized(for: scope) {
///     // Proceed with health data operations
/// }
///
/// // Check individual type status
/// let status = authService.authorizationStatus(for: .heartRate)
/// switch status {
/// case .authorized:
///     print("Can read heart rate")
/// case .denied:
///     print("User denied heart rate access")
/// case .notDetermined:
///     print("Need to request permission")
/// }
/// ```
///
/// **Architecture:** FitIQCore - Domain Port (Hexagonal Architecture)
///
/// **Implementation Notes:**
/// - Concrete implementations will use HealthKit's HKHealthStore
/// - Mock implementations can be used for testing
/// - Authorization is per health data type
/// - Some types require explicit user consent
///
/// **Privacy:** Always respect user privacy choices and handle denials gracefully
///
/// **Thread Safety:** All methods are async or thread-safe and can be called from any thread
public protocol HealthAuthorizationServiceProtocol: Sendable {

    // MARK: - Authorization Requests

    /// Requests authorization for specified health data types
    ///
    /// Presents the HealthKit authorization sheet to the user, requesting permission
    /// to read and/or write the specified health data types. This is an asynchronous
    /// operation that waits for the user's response.
    ///
    /// **Important Notes:**
    /// - This method should only be called when you need to use the health data
    /// - Don't request authorization preemptively or during onboarding
    /// - Request only the types you actually need
    /// - Users can grant partial permissions (some but not all types)
    /// - This method doesn't throw if user denies; check status afterward
    ///
    /// - Parameter scope: The health data types to request read/write access for
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available on device
    /// - Throws: `HealthKitError.authorizationFailed` if the authorization process fails
    ///
    /// **Example:**
    /// ```swift
    /// // Request fitness tracking permissions
    /// let scope = HealthAuthorizationScope(
    ///     read: [.stepCount, .heartRate, .activeEnergyBurned, .sleepAnalysis],
    ///     write: [.bodyMass, .workout(.running)]
    /// )
    /// try await authService.requestAuthorization(scope: scope)
    ///
    /// // Check what was actually granted
    /// if authService.isAuthorized(for: .read([.heartRate])) {
    ///     print("Heart rate access granted")
    /// }
    /// ```
    func requestAuthorization(scope: HealthAuthorizationScope) async throws

    /// Requests authorization for a single health data type
    ///
    /// Convenience method for requesting access to a single type. Equivalent to
    /// calling `requestAuthorization(scope:)` with a scope containing one type.
    ///
    /// - Parameters:
    ///   - type: The health data type to request access for
    ///   - permission: Whether to request read, write, or both permissions
    /// - Throws: `HealthKitError` if the authorization process fails
    ///
    /// **Example:**
    /// ```swift
    /// // Request read-only access to step count
    /// try await authService.requestAuthorization(
    ///     for: .stepCount,
    ///     permission: .read
    /// )
    /// ```
    func requestAuthorization(
        for type: HealthDataType,
        permission: HealthPermission
    ) async throws

    // MARK: - Authorization Status

    /// Checks the authorization status for a specific health data type
    ///
    /// Returns the current authorization status without prompting the user.
    /// This is a synchronous operation that returns immediately.
    ///
    /// **Privacy Note:** For read permissions, HealthKit may return `.notDetermined`
    /// even after authorization to protect user privacy (users can deny without
    /// apps knowing). Always handle this gracefully.
    ///
    /// - Parameter type: The health data type to check
    /// - Returns: Current authorization status
    ///
    /// **Example:**
    /// ```swift
    /// let status = authService.authorizationStatus(for: .heartRate)
    /// switch status {
    /// case .authorized:
    ///     // Can read heart rate data
    ///     loadHeartRateData()
    /// case .denied:
    ///     // User explicitly denied access
    ///     showPermissionDeniedMessage()
    /// case .notDetermined:
    ///     // Haven't asked yet, or privacy protection
    ///     showRequestPermissionButton()
    /// case .restricted:
    ///     // Restricted by parental controls or profile
    ///     showRestrictedMessage()
    /// }
    /// ```
    func authorizationStatus(for type: HealthDataType) -> HealthAuthorizationStatus

    /// Checks if the app is authorized for a specific scope
    ///
    /// Returns true only if ALL requested permissions in the scope are granted.
    /// This is useful for checking if you have all necessary permissions before
    /// starting an operation.
    ///
    /// **Note:** Due to HealthKit's privacy model, this may return false for
    /// read permissions even if the user granted access. Always attempt the
    /// operation and handle `.notAuthorized` errors gracefully.
    ///
    /// - Parameter scope: The authorization scope to check
    /// - Returns: True if all permissions in scope are granted
    ///
    /// **Example:**
    /// ```swift
    /// let workoutScope = HealthAuthorizationScope(
    ///     read: [.heartRate, .activeEnergyBurned],
    ///     write: [.workout(.running)]
    /// )
    ///
    /// if authService.isAuthorized(for: workoutScope) {
    ///     startWorkoutTracking()
    /// } else {
    ///     try await authService.requestAuthorization(scope: workoutScope)
    /// }
    /// ```
    func isAuthorized(for scope: HealthAuthorizationScope) -> Bool

    /// Checks if the app has read permission for a specific type
    ///
    /// Convenience method for checking read-only access.
    ///
    /// - Parameter type: The health data type to check
    /// - Returns: True if read access is granted (or unknown due to privacy)
    ///
    /// **Example:**
    /// ```swift
    /// if authService.canRead(type: .stepCount) {
    ///     let steps = try await healthService.query(type: .stepCount, ...)
    /// }
    /// ```
    func canRead(type: HealthDataType) -> Bool

    /// Checks if the app has write permission for a specific type
    ///
    /// Convenience method for checking write-only access.
    ///
    /// - Parameter type: The health data type to check
    /// - Returns: True if write access is granted
    ///
    /// **Example:**
    /// ```swift
    /// if authService.canWrite(type: .bodyMass) {
    ///     try await healthService.save(metric: weightMetric)
    /// }
    /// ```
    func canWrite(type: HealthDataType) -> Bool

    // MARK: - Availability

    /// Checks if HealthKit is available on this device
    ///
    /// HealthKit is not available on iPad (except for apps running on Apple Silicon Macs).
    /// Always check availability before attempting to use HealthKit.
    ///
    /// - Returns: True if HealthKit is available on this device
    ///
    /// **Example:**
    /// ```swift
    /// guard authService.isHealthKitAvailable() else {
    ///     showHealthKitUnavailableMessage()
    ///     return
    /// }
    /// ```
    func isHealthKitAvailable() -> Bool

    /// Checks if a specific health data type is available for authorization
    ///
    /// Some health data types may not be available on certain devices or iOS versions.
    /// For example, wheelchair metrics are only available on Apple Watch.
    ///
    /// - Parameter type: The health data type to check
    /// - Returns: True if the type can be authorized on this device/OS version
    ///
    /// **Example:**
    /// ```swift
    /// if authService.isTypeAvailable(.heartRateVariability) {
    ///     // Can request HRV authorization
    /// } else {
    ///     // HRV not available on this device
    /// }
    /// ```
    func isTypeAvailable(_ type: HealthDataType) -> Bool

    // MARK: - Permission Summary

    /// Gets a summary of all authorization statuses
    ///
    /// Returns a dictionary mapping each requested health data type to its
    /// current authorization status. Useful for showing permission settings UI.
    ///
    /// - Parameter scope: The scope to check statuses for
    /// - Returns: Dictionary mapping types to their authorization status
    ///
    /// **Example:**
    /// ```swift
    /// let scope = HealthAuthorizationScope(
    ///     read: [.stepCount, .heartRate, .sleepAnalysis],
    ///     write: [.bodyMass]
    /// )
    /// let statuses = authService.authorizationSummary(for: scope)
    ///
    /// for (type, status) in statuses {
    ///     print("\(type.description): \(status)")
    /// }
    /// ```
    func authorizationSummary(
        for scope: HealthAuthorizationScope
    ) -> [HealthDataType: HealthAuthorizationStatus]
}

// MARK: - Supporting Types

/// Authorization status for a health data type
public enum HealthAuthorizationStatus: String, Codable, Sendable, CaseIterable {
    /// User has not been asked for permission yet
    case notDetermined

    /// User granted permission
    case authorized

    /// User explicitly denied permission
    case denied

    /// Permission is restricted (e.g., parental controls)
    case restricted

    /// Human-readable description
    public var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        }
    }

    /// Returns true if the status allows data access
    public var isAuthorized: Bool {
        self == .authorized
    }

    /// Returns true if permission should be requested
    public var shouldRequestAuthorization: Bool {
        self == .notDetermined
    }

    /// Returns true if the user explicitly denied access
    public var isDenied: Bool {
        self == .denied
    }
}

/// Permission level for health data
public enum HealthPermission: String, Codable, Sendable, CaseIterable {
    /// Read-only access
    case read

    /// Write-only access
    case write

    /// Both read and write access
    case readWrite

    /// Human-readable description
    public var description: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        case .readWrite: return "Read & Write"
        }
    }

    /// Returns true if this permission includes read access
    public var includesRead: Bool {
        self == .read || self == .readWrite
    }

    /// Returns true if this permission includes write access
    public var includesWrite: Bool {
        self == .write || self == .readWrite
    }
}

// MARK: - Default Implementations

extension HealthAuthorizationServiceProtocol {
    /// Default implementation: requests authorization for single type by creating scope
    public func requestAuthorization(
        for type: HealthDataType,
        permission: HealthPermission
    ) async throws {
        let scope: HealthAuthorizationScope

        switch permission {
        case .read:
            scope = HealthAuthorizationScope(read: [type], write: [])
        case .write:
            scope = HealthAuthorizationScope(read: [], write: [type])
        case .readWrite:
            scope = HealthAuthorizationScope(read: [type], write: [type])
        }

        try await requestAuthorization(scope: scope)
    }

    /// Default implementation: checks if status is authorized
    public func canRead(type: HealthDataType) -> Bool {
        authorizationStatus(for: type).isAuthorized
    }

    /// Default implementation: checks if status is authorized
    public func canWrite(type: HealthDataType) -> Bool {
        authorizationStatus(for: type).isAuthorized
    }

    /// Default implementation: gets status for all types in scope
    public func authorizationSummary(
        for scope: HealthAuthorizationScope
    ) -> [HealthDataType: HealthAuthorizationStatus] {
        var summary: [HealthDataType: HealthAuthorizationStatus] = [:]

        // Combine read and write types
        let allTypes = scope.readTypes.union(scope.writeTypes)

        for type in allTypes {
            summary[type] = authorizationStatus(for: type)
        }

        return summary
    }
}
