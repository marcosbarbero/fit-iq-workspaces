//
//  UserProfile.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//  Refactored by AI Assistant on 27/01/2025.
//  Part of Profile Refactoring - Phase 1
//

import Foundation

/// Complete user profile combining metadata and physical attributes
///
/// This is a composition of `UserProfileMetadata` and `PhysicalProfile`, providing
/// a unified view of the user's complete profile information.
///
/// **Architecture:** Domain Entity (pure business logic, no external dependencies)
///
/// **Backend Endpoints:**
/// - Metadata: `/api/v1/users/me` (GET/PUT)
/// - Physical: `/api/v1/users/me/physical` (PATCH)
///
/// **Design Pattern:** Composition over inheritance
///
/// **Related Models:**
/// - `UserProfileMetadata` - Profile information and preferences
/// - `PhysicalProfile` - Physical attributes for health tracking
///
/// **Example:**
/// ```swift
/// let profile = UserProfile(
///     metadata: UserProfileMetadata(
///         id: UUID(),
///         userId: UUID(),
///         name: "John Doe",
///         bio: "Fitness enthusiast",
///         preferredUnitSystem: "metric",
///         languageCode: "en",
///         dateOfBirth: Date(),
///         createdAt: Date(),
///         updatedAt: Date()
///     ),
///     physical: PhysicalProfile(
///         biologicalSex: "male",
///         heightCm: 180.5,
///         dateOfBirth: Date()
///     )
/// )
/// ```
public struct UserProfile: Identifiable, Equatable {
    // MARK: - Core Components

    /// Profile metadata (from /api/v1/users/me)
    ///
    /// Contains name, bio, preferences, language code, etc.
    public let metadata: UserProfileMetadata

    /// Physical profile (from /api/v1/users/me/physical)
    ///
    /// Contains biological sex, height, date of birth.
    /// Optional because user may not have provided physical data yet.
    public let physical: PhysicalProfile?

    // MARK: - Local State (Not from Backend)

    /// Email address (from authentication, not profile endpoint)
    ///
    /// This comes from the JWT token or registration, not from the profile API.
    /// Stored here for convenience but is authentication data, not profile data.
    public let email: String?

    /// Username (from authentication, not profile endpoint)
    ///
    /// Derived from email or other auth data. Not part of backend profile.
    /// Deprecated: Use `name` from metadata instead.
    @available(*, deprecated, message: "Use metadata.name instead")
    public let username: String?

    /// Flag to track if initial HealthKit historical sync has been performed
    ///
    /// Local app state, not stored in backend profile.
    public var hasPerformedInitialHealthKitSync: Bool

    /// Track the date of the last successful daily HealthKit sync
    ///
    /// Local app state for incremental sync tracking.
    public var lastSuccessfulDailySyncDate: Date?

    // MARK: - Computed Properties (Backward Compatibility)

    /// Profile ID (from metadata)
    public var id: UUID {
        metadata.id
    }

    /// User ID (from metadata)
    public var userId: UUID {
        metadata.userId
    }

    /// Full name (from metadata)
    public var name: String {
        metadata.name
    }

    /// Biography (from metadata)
    public var bio: String? {
        metadata.bio
    }

    /// Preferred unit system (from metadata)
    public var preferredUnitSystem: String {
        metadata.preferredUnitSystem
    }

    /// Language code (from metadata)
    public var languageCode: String? {
        metadata.languageCode
    }

    /// Date of birth (prefers physical profile, falls back to metadata)
    public var dateOfBirth: Date? {
        physical?.dateOfBirth ?? metadata.dateOfBirth
    }

    /// Biological sex (from physical profile)
    ///
    /// Note: Previously called "gender" but backend uses "biological_sex"
    public var biologicalSex: String? {
        physical?.biologicalSex
    }

    /// Gender (deprecated, use biologicalSex)
    @available(*, deprecated, renamed: "biologicalSex", message: "Use biologicalSex instead")
    public var gender: String? {
        biologicalSex
    }

    /// Height in centimeters (from physical profile)
    public var height: Double? {
        physical?.heightCm
    }

    /// Height in centimeters (alias for consistency)
    public var heightCm: Double? {
        physical?.heightCm
    }

    /// Weight in kilograms
    ///
    /// Note: Weight is NOT in the backend profile or physical endpoints.
    /// This returns nil for now. Weight should be tracked via body mass entries.
    @available(
        *, deprecated, message: "Weight is not in profile API. Use body mass tracking instead."
    )
    public var weight: Double? {
        nil  // Not in backend profile API
    }

    /// Activity level
    ///
    /// Note: Activity level is NOT in the backend profile API.
    /// This returns nil. Activity should be tracked via activity snapshots.
    @available(
        *, deprecated,
        message: "Activity level is not in profile API. Use activity snapshots instead."
    )
    public var activityLevel: String? {
        nil  // Not in backend profile API
    }

    /// Profile creation timestamp (from metadata)
    public var createdAt: Date {
        metadata.createdAt
    }

    /// Last update timestamp (from metadata)
    public var updatedAt: Date {
        metadata.updatedAt
    }

    /// Age calculated from date of birth
    public var age: Int? {
        physical?.age ?? metadata.age
    }

    /// Whether the user uses metric units
    public var usesMetricUnits: Bool {
        metadata.usesMetricUnits
    }

    /// Whether the user uses imperial units
    public var usesImperialUnits: Bool {
        metadata.usesImperialUnits
    }

    // MARK: - Initializers

    /// Creates a UserProfile from metadata and physical components
    ///
    /// This is the preferred initializer for the new architecture.
    ///
    /// - Parameters:
    ///   - metadata: Profile metadata (required)
    ///   - physical: Physical profile (optional)
    ///   - email: Email address from auth (optional)
    ///   - username: Username from auth (optional, deprecated)
    ///   - hasPerformedInitialHealthKitSync: HealthKit sync flag (defaults to false)
    ///   - lastSuccessfulDailySyncDate: Last sync date (optional)
    public init(
        metadata: UserProfileMetadata,
        physical: PhysicalProfile? = nil,
        email: String? = nil,
        username: String? = nil,
        hasPerformedInitialHealthKitSync: Bool = false,
        lastSuccessfulDailySyncDate: Date? = nil
    ) {
        self.metadata = metadata
        self.physical = physical
        self.email = email
        self.username = username
        self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
        self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
    }

    /// Legacy initializer for backward compatibility
    ///
    /// This initializer is deprecated and should not be used for new code.
    /// It exists only to maintain compatibility during the migration period.
    ///
    /// - Note: This creates the new structure from old parameters.
    ///         Some fields (weight, activityLevel) are ignored as they don't exist in backend.
    @available(*, deprecated, message: "Use init(metadata:physical:) instead")
    public init(
        id: UUID,
        username: String,
        email: String,
        name: String,
        dateOfBirth: Date?,
        gender: String?,
        height: Double?,
        weight: Double?,  // Ignored - not in backend
        activityLevel: String?,  // Ignored - not in backend
        preferredUnitSystem: String = "metric",
        createdAt: Date,
        hasPerformedInitialHealthKitSync: Bool = false,
        lastSuccessfulDailySyncDate: Date? = nil
    ) {
        // Create metadata from old parameters
        let metadata = UserProfileMetadata(
            id: id,
            userId: id,  // Use same ID for now (will be corrected when fetched from backend)
            name: name,
            bio: nil,  // Not available in old structure
            preferredUnitSystem: preferredUnitSystem,
            languageCode: nil,  // Not available in old structure
            dateOfBirth: dateOfBirth,
            createdAt: createdAt,
            updatedAt: createdAt  // Assume same as created for now
        )

        // Create physical from old parameters if any physical data exists
        let physical: PhysicalProfile?
        if gender != nil || height != nil || dateOfBirth != nil {
            physical = PhysicalProfile(
                biologicalSex: gender,
                heightCm: height,
                dateOfBirth: dateOfBirth
            )
        } else {
            physical = nil
        }

        // Note: weight and activityLevel are ignored as they don't exist in backend

        self.init(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: lastSuccessfulDailySyncDate
        )
    }
}

// MARK: - Convenience Methods

extension UserProfile {
    /// Updates the profile metadata with new values
    ///
    /// Returns a new UserProfile with updated metadata, preserving physical data.
    ///
    /// - Parameter metadata: New metadata
    /// - Returns: Updated UserProfile
    public func updatingMetadata(_ metadata: UserProfileMetadata) -> UserProfile {
        return UserProfile(
            metadata: metadata,
            physical: self.physical,
            email: self.email,
            username: self.metadata.name,
            hasPerformedInitialHealthKitSync: self.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: self.lastSuccessfulDailySyncDate
        )
    }

    /// Updates the physical profile with new values
    ///
    /// Returns a new UserProfile with updated physical data, preserving metadata.
    ///
    /// - Parameter physical: New physical profile
    /// - Returns: Updated UserProfile
    public func updatingPhysical(_ physical: PhysicalProfile?) -> UserProfile {
        return UserProfile(
            metadata: self.metadata,
            physical: physical,
            email: self.email,
            username: self.metadata.name,
            hasPerformedInitialHealthKitSync: self.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: self.lastSuccessfulDailySyncDate
        )
    }

    /// Updates both metadata and physical profile
    ///
    /// Returns a new UserProfile with both components updated.
    ///
    /// - Parameters:
    ///   - metadata: New metadata
    ///   - physical: New physical profile
    /// - Returns: Updated UserProfile
    public func updating(
        metadata: UserProfileMetadata,
        physical: PhysicalProfile?
    ) -> UserProfile {
        return UserProfile(
            metadata: metadata,
            physical: physical,
            email: self.email,
            username: metadata.name,
            hasPerformedInitialHealthKitSync: self.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: self.lastSuccessfulDailySyncDate
        )
    }

    /// Updates HealthKit sync state
    ///
    /// Returns a new UserProfile with updated sync flags.
    ///
    /// - Parameters:
    ///   - hasPerformedInitialSync: Whether initial sync is complete
    ///   - lastSyncDate: Date of last successful sync
    /// - Returns: Updated UserProfile
    public func updatingHealthKitSync(
        hasPerformedInitialSync: Bool,
        lastSyncDate: Date?
    ) -> UserProfile {
        return UserProfile(
            metadata: self.metadata,
            physical: self.physical,
            email: self.email,
            username: self.metadata.name,
            hasPerformedInitialHealthKitSync: hasPerformedInitialSync,
            lastSuccessfulDailySyncDate: lastSyncDate
        )
    }
}

// MARK: - Validation

extension UserProfile {
    /// Validates the complete profile
    ///
    /// Checks both metadata and physical profile for validity.
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Validate metadata
        let metadataErrors = metadata.validate()
        errors.append(contentsOf: metadataErrors.map { .metadataError($0) })

        // Validate physical if present
        if let physical = physical {
            let physicalErrors = physical.validate()
            errors.append(contentsOf: physicalErrors.map { .physicalError($0) })
        }

        return errors
    }

    /// Whether the profile is valid
    public var isValid: Bool {
        validate().isEmpty
    }

    /// Validation errors for UserProfile
    public enum ValidationError: Error, LocalizedError, Equatable {
        case metadataError(UserProfileMetadata.ValidationError)
        case physicalError(PhysicalProfile.ValidationError)

        public var errorDescription: String? {
            switch self {
            case .metadataError(let error):
                return "Profile metadata error: \(error.localizedDescription)"
            case .physicalError(let error):
                return "Physical profile error: \(error.localizedDescription)"
            }
        }
    }
}
