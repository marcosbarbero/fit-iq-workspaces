//
//  HealthKitError.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Errors that can occur during HealthKit operations
///
/// This enumeration provides typed errors for all HealthKit-related operations,
/// making error handling clear and testable across both FitIQ and Lume applications.
///
/// **Usage:**
/// ```swift
/// do {
///     let metrics = try await healthService.query(type: .heartRate, ...)
/// } catch HealthKitError.notAuthorized(let type) {
///     print("Need permission for \(type)")
///     showAuthorizationRequest()
/// } catch HealthKitError.notAvailable {
///     print("HealthKit not available on this device")
///     showUnavailableMessage()
/// } catch {
///     print("Unexpected error: \(error)")
/// }
/// ```
///
/// **Architecture:** FitIQCore - Shared Domain Model
public enum HealthKitError: Error, Sendable {

    // MARK: - Authorization Errors

    /// HealthKit is not available on this device (e.g., iPad)
    case notAvailable

    /// User has not granted permission for the specified health data type
    case notAuthorized(HealthDataType)

    /// User explicitly denied permission for the specified health data type
    case denied(HealthDataType)

    /// Permission is restricted (e.g., parental controls, device management profile)
    case restricted(HealthDataType)

    /// Authorization request failed or was cancelled
    case authorizationFailed(reason: String?)

    // MARK: - Query Errors

    /// The query failed to execute
    case queryFailed(reason: String?)

    /// The specified health data type is not available on this device/OS version
    case typeNotAvailable(HealthDataType)

    /// No data found for the specified query
    case noDataAvailable

    /// Invalid date range (e.g., end date before start date)
    case invalidDateRange(start: Date, end: Date)

    /// Query options are invalid or incompatible
    case invalidQueryOptions(reason: String)

    /// Query anchor is invalid or expired
    case invalidAnchor

    /// Failed to query HealthKit characteristics (biologicalSex, dateOfBirth)
    case characteristicQueryFailed(reason: String)

    // MARK: - Write Errors

    /// Failed to save health data to HealthKit
    case saveFailed(reason: String?)

    /// The health metric data is invalid
    case invalidData(reason: String)

    /// Batch save operation failed
    case batchSaveFailed(successCount: Int, totalCount: Int, reason: String?)

    // MARK: - Delete Errors

    /// Failed to delete health data from HealthKit
    case deleteFailed(reason: String?)

    /// The specified metric was not found
    case notFound(metricID: UUID)

    // MARK: - Background Delivery Errors

    /// Failed to enable background delivery
    case backgroundDeliveryFailed(HealthDataType, reason: String?)

    /// Background delivery is not supported for this type
    case backgroundDeliveryNotSupported(HealthDataType)

    // MARK: - Observation Errors

    /// Failed to start observing health data changes
    case observationFailed(HealthDataType, reason: String?)

    /// Observer was stopped unexpectedly
    case observerStopped(HealthDataType)

    // MARK: - General Errors

    /// HealthKit store is unavailable or not initialized
    case storeUnavailable

    /// An unknown error occurred
    case unknown(Error)
}

// MARK: - LocalizedError Conformance

extension HealthKitError: LocalizedError {
    /// User-facing error description
    public var errorDescription: String? {
        switch self {
        // Authorization Errors
        case .notAvailable:
            return "HealthKit is not available on this device."

        case .notAuthorized(let type):
            return "Permission required to access \(type.description)."

        case .denied(let type):
            return "Access to \(type.description) was denied. Please enable in Settings."

        case .restricted(let type):
            return "Access to \(type.description) is restricted by device policies."

        case .authorizationFailed(let reason):
            if let reason = reason {
                return "Authorization failed: \(reason)"
            }
            return "Failed to request HealthKit authorization."

        // Query Errors
        case .queryFailed(let reason):
            if let reason = reason {
                return "Health data query failed: \(reason)"
            }
            return "Failed to query health data."

        case .typeNotAvailable(let type):
            return "\(type.description) is not available on this device."

        case .noDataAvailable:
            return "No health data available for the specified query."

        case .invalidDateRange(let start, let end):
            return "Invalid date range: end date (\(end)) must be after start date (\(start))."

        case .invalidQueryOptions(let reason):
            return "Invalid query options: \(reason)"

        case .invalidAnchor:
            return "Query anchor is invalid or expired."

        case .characteristicQueryFailed(let reason):
            return "Failed to query HealthKit characteristic: \(reason)"

        // Write Errors
        case .saveFailed(let reason):
            if let reason = reason {
                return "Failed to save health data: \(reason)"
            }
            return "Failed to save health data to HealthKit."

        case .invalidData(let reason):
            return "Invalid health data: \(reason)"

        case .batchSaveFailed(let successCount, let totalCount, let reason):
            var message = "Batch save partially failed: \(successCount) of \(totalCount) saved."
            if let reason = reason {
                message += " Reason: \(reason)"
            }
            return message

        // Delete Errors
        case .deleteFailed(let reason):
            if let reason = reason {
                return "Failed to delete health data: \(reason)"
            }
            return "Failed to delete health data from HealthKit."

        case .notFound(let metricID):
            return "Health metric with ID \(metricID) not found."

        // Background Delivery Errors
        case .backgroundDeliveryFailed(let type, let reason):
            var message = "Failed to enable background delivery for \(type.description)."
            if let reason = reason {
                message += " Reason: \(reason)"
            }
            return message

        case .backgroundDeliveryNotSupported(let type):
            return "Background delivery is not supported for \(type.description)."

        // Observation Errors
        case .observationFailed(let type, let reason):
            var message = "Failed to observe \(type.description) changes."
            if let reason = reason {
                message += " Reason: \(reason)"
            }
            return message

        case .observerStopped(let type):
            return "\(type.description) observer stopped unexpectedly."

        // General Errors
        case .storeUnavailable:
            return "HealthKit store is unavailable."

        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    /// Localized failure reason (for detailed error messages)
    public var failureReason: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is only available on iPhone and Apple Watch."

        case .notAuthorized, .denied:
            return "The app needs permission to access health data."

        case .restricted:
            return "Health data access is restricted by parental controls or device management."

        case .typeNotAvailable:
            return "This health data type is not supported on this device or iOS version."

        case .invalidDateRange:
            return "The end date must be after the start date."

        case .invalidAnchor:
            return "The query anchor is no longer valid. Try querying all data again."

        case .characteristicQueryFailed:
            return "Unable to access HealthKit characteristic data."

        case .storeUnavailable:
            return "The HealthKit store could not be initialized."

        default:
            return nil
        }
    }

    /// Recovery suggestion for the user
    public var recoverySuggestion: String? {
        switch self {
        case .notAvailable:
            return "HealthKit features are not available on this device."

        case .notAuthorized, .denied:
            return "Go to Settings > Privacy & Security > Health to enable access."

        case .restricted:
            return "Contact your device administrator to enable health data access."

        case .authorizationFailed:
            return "Try requesting authorization again."

        case .queryFailed, .saveFailed, .deleteFailed:
            return "Try again later. If the problem persists, restart the app."

        case .typeNotAvailable:
            return "This feature requires a newer device or iOS version."

        case .noDataAvailable:
            return "No health data has been recorded yet for this type."

        case .invalidDateRange:
            return "Check the date range and try again."

        case .invalidQueryOptions:
            return "Adjust the query options and try again."

        case .invalidData:
            return "Check the health data values and try again."

        case .notFound:
            return "The health metric may have been deleted."

        case .backgroundDeliveryNotSupported:
            return "Background updates are not available for this data type."

        case .storeUnavailable:
            return "Restart the app to reinitialize HealthKit."

        default:
            return "Try again later."
        }
    }
}

// MARK: - CustomStringConvertible

extension HealthKitError: CustomStringConvertible {
    /// Human-readable description of the error
    public var description: String {
        errorDescription ?? "Unknown HealthKit error"
    }
}

// MARK: - Helpers

extension HealthKitError {
    /// Returns true if this error indicates missing authorization
    public var isAuthorizationError: Bool {
        switch self {
        case .notAuthorized, .denied, .restricted, .authorizationFailed:
            return true
        default:
            return false
        }
    }

    /// Returns true if this error is recoverable (user can retry)
    public var isRecoverable: Bool {
        switch self {
        case .notAvailable, .restricted, .typeNotAvailable, .backgroundDeliveryNotSupported:
            return false
        case .denied:
            return true  // User can enable in Settings
        default:
            return true
        }
    }

    /// Returns true if this error should trigger an authorization request
    public var shouldRequestAuthorization: Bool {
        switch self {
        case .notAuthorized, .authorizationFailed:
            return true
        default:
            return false
        }
    }

    /// Returns the affected health data type, if applicable
    public var affectedType: HealthDataType? {
        switch self {
        case .notAuthorized(let type),
            .denied(let type),
            .restricted(let type),
            .typeNotAvailable(let type),
            .backgroundDeliveryFailed(let type, _),
            .backgroundDeliveryNotSupported(let type),
            .observationFailed(let type, _),
            .observerStopped(let type):
            return type
        default:
            return nil
        }
    }
}

// MARK: - Factory Methods

extension HealthKitError {
    /// Creates an authorization error based on the current status
    public static func fromAuthorizationStatus(
        _ status: HealthAuthorizationStatus,
        type: HealthDataType
    ) -> HealthKitError? {
        switch status {
        case .notDetermined:
            return .notAuthorized(type)
        case .denied:
            return .denied(type)
        case .restricted:
            return .restricted(type)
        case .authorized:
            return nil
        }
    }
}

// MARK: - Equatable Conformance

extension HealthKitError: Equatable {
    public static func == (lhs: HealthKitError, rhs: HealthKitError) -> Bool {
        switch (lhs, rhs) {
        // Authorization Errors
        case (.notAvailable, .notAvailable):
            return true
        case (.notAuthorized(let lType), .notAuthorized(let rType)):
            return lType == rType
        case (.denied(let lType), .denied(let rType)):
            return lType == rType
        case (.restricted(let lType), .restricted(let rType)):
            return lType == rType
        case (.authorizationFailed(let lReason), .authorizationFailed(let rReason)):
            return lReason == rReason

        // Query Errors
        case (.queryFailed(let lReason), .queryFailed(let rReason)):
            return lReason == rReason
        case (.typeNotAvailable(let lType), .typeNotAvailable(let rType)):
            return lType == rType
        case (.noDataAvailable, .noDataAvailable):
            return true
        case (.invalidDateRange(let lStart, let lEnd), .invalidDateRange(let rStart, let rEnd)):
            return lStart == rStart && lEnd == rEnd
        case (.invalidQueryOptions(let lReason), .invalidQueryOptions(let rReason)):
            return lReason == rReason
        case (.invalidAnchor, .invalidAnchor):
            return true
        case (.characteristicQueryFailed(let lReason), .characteristicQueryFailed(let rReason)):
            return lReason == rReason

        // Write Errors
        case (.saveFailed(let lReason), .saveFailed(let rReason)):
            return lReason == rReason
        case (.invalidData(let lReason), .invalidData(let rReason)):
            return lReason == rReason
        case (
            .batchSaveFailed(let lSuccess, let lTotal, let lReason),
            .batchSaveFailed(let rSuccess, let rTotal, let rReason)
        ):
            return lSuccess == rSuccess && lTotal == rTotal && lReason == rReason

        // Delete Errors
        case (.deleteFailed(let lReason), .deleteFailed(let rReason)):
            return lReason == rReason
        case (.notFound(let lID), .notFound(let rID)):
            return lID == rID

        // Background Delivery Errors
        case (
            .backgroundDeliveryFailed(let lType, let lReason),
            .backgroundDeliveryFailed(let rType, let rReason)
        ):
            return lType == rType && lReason == rReason
        case (
            .backgroundDeliveryNotSupported(let lType),
            .backgroundDeliveryNotSupported(let rType)
        ):
            return lType == rType

        // Observation Errors
        case (
            .observationFailed(let lType, let lReason),
            .observationFailed(let rType, let rReason)
        ):
            return lType == rType && lReason == rReason
        case (.observerStopped(let lType), .observerStopped(let rType)):
            return lType == rType

        // General Errors
        case (.storeUnavailable, .storeUnavailable):
            return true
        case (.unknown(let lError), .unknown(let rError)):
            return lError.localizedDescription == rError.localizedDescription

        default:
            return false
        }
    }
}
