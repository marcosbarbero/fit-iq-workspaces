//
//  HealthAuthorizationService.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation
import HealthKit

/// Concrete implementation of HealthAuthorizationServiceProtocol using HealthKit
///
/// This service manages HealthKit authorization requests and status checks.
/// It wraps Apple's HKHealthStore to provide a clean, testable interface for
/// authorization management across both FitIQ and Lume applications.
///
/// **Usage:**
/// ```swift
/// let healthStore = HKHealthStore()
/// let authService = HealthAuthorizationService(healthStore: healthStore)
///
/// // Request authorization
/// let scope = HealthAuthorizationScope(
///     read: [.stepCount, .heartRate],
///     write: [.bodyMass]
/// )
/// try await authService.requestAuthorization(scope: scope)
///
/// // Check status
/// let status = authService.authorizationStatus(for: .heartRate)
/// if status.isAuthorized {
///     // Proceed with health data operations
/// }
/// ```
///
/// **Architecture:** FitIQCore - Infrastructure Layer (Hexagonal Architecture)
///
/// **Thread Safety:** All methods are thread-safe and can be called from any thread
///
/// **Platform:** iOS, watchOS, macOS (Catalyst)
@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
public final class HealthAuthorizationService: HealthAuthorizationServiceProtocol, Sendable {

    // MARK: - Properties

    private let healthStore: HKHealthStore

    // MARK: - Initialization

    /// Creates a new HealthKit authorization service
    ///
    /// - Parameter healthStore: HKHealthStore instance (defaults to shared instance)
    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    // MARK: - Authorization Requests

    public func requestAuthorization(scope: HealthAuthorizationScope) async throws {
        // Check if HealthKit is available
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        // Convert domain types to HealthKit types
        let typesToRead = try convertToHKTypes(scope.readTypes)
        let typesToShare = try convertToHKTypes(scope.writeTypes)

        // Request authorization
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            throw HealthKitError.authorizationFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Authorization Status

    public func authorizationStatus(for type: HealthDataType) -> HealthAuthorizationStatus {
        // Check if HealthKit is available
        guard isHealthKitAvailable() else {
            return .restricted
        }

        // Get HealthKit type
        guard let hkType = try? HealthKitTypeMapper.toHKType(type) else {
            return .notDetermined
        }

        // Check authorization status
        let status = healthStore.authorizationStatus(for: hkType)

        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    public func isAuthorized(for scope: HealthAuthorizationScope) -> Bool {
        // Check all read types
        for type in scope.readTypes {
            let status = authorizationStatus(for: type)
            if !status.isAuthorized && status != .notDetermined {
                // If explicitly denied or restricted, return false
                return false
            }
        }

        // Check all write types
        for type in scope.writeTypes {
            let status = authorizationStatus(for: type)
            if !status.isAuthorized && status != .notDetermined {
                return false
            }
        }

        // Due to HealthKit's privacy model, we can't be 100% certain about read permissions
        // Return true if nothing is explicitly denied
        return true
    }

    // MARK: - Availability

    public func isHealthKitAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func isTypeAvailable(_ type: HealthDataType) -> Bool {
        // HealthKit must be available
        guard isHealthKitAvailable() else {
            return false
        }

        // Check if we can convert to HK type
        guard (try? HealthKitTypeMapper.toHKType(type)) != nil else {
            return false
        }

        // All types that can be converted are generally available
        // Some types may require specific hardware (e.g., Apple Watch)
        // but we return true if the type exists
        return true
    }

    // MARK: - Private Helpers

    /// Converts a set of domain types to HealthKit sample types
    private func convertToHKTypes(_ types: Set<HealthDataType>) throws -> Set<HKSampleType> {
        var hkTypes = Set<HKSampleType>()

        for type in types {
            do {
                let hkType = try HealthKitTypeMapper.toHKType(type)
                hkTypes.insert(hkType)
            } catch {
                // If we can't convert a type, throw error
                throw HealthKitError.typeNotAvailable(type)
            }
        }

        return hkTypes
    }
}

// MARK: - Factory

@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
extension HealthAuthorizationService {
    /// Creates a shared instance of the authorization service
    public static let shared = HealthAuthorizationService()
}
