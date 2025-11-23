//
//  UserProfileMetadata.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Refactoring - Phase 1
//

import Foundation

/// Profile metadata from GET/PUT /api/v1/users/me
///
/// This contains the user's profile information (name, bio, preferences) separate from
/// physical attributes and authentication data.
///
/// **Backend Endpoint:** `/api/v1/users/me`
///
/// **Architecture:** Domain Entity (pure business logic, no external dependencies)
///
/// **Related Models:**
/// - `PhysicalProfile` - Physical attributes from `/api/v1/users/me/physical`
/// - `UserProfile` - Composition of metadata + physical
///
/// **Example:**
/// ```swift
/// let metadata = UserProfileMetadata(
///     id: UUID(),
///     userId: UUID(),
///     name: "John Doe",
///     bio: "Fitness enthusiast",
///     preferredUnitSystem: "metric",
///     languageCode: "en",
///     dateOfBirth: Date(),
///     createdAt: Date(),
///     updatedAt: Date()
/// )
/// ```
public struct UserProfileMetadata: Identifiable, Equatable {
    // MARK: - Properties

    /// Profile ID (from backend profile record)
    public let id: UUID

    /// User ID (from JWT/authentication)
    public let userId: UUID

    /// Full name (REQUIRED by backend)
    ///
    /// This is the user's display name. The backend requires this field
    /// when creating or updating a profile.
    public let name: String

    /// Biography or personal description (optional)
    ///
    /// Free-text field for users to describe themselves.
    public let bio: String?

    /// Unit system preference: "metric" or "imperial" (REQUIRED by backend)
    ///
    /// Determines how measurements are displayed throughout the app:
    /// - "metric": kg, cm, km
    /// - "imperial": lb, in, mi
    public let preferredUnitSystem: String

    /// Language preference code (optional)
    ///
    /// ISO 639-1 language code (e.g., "en", "pt", "es")
    /// Used for localization and content preferences.
    public let languageCode: String?

    /// Date of birth (optional)
    ///
    /// Note: This may also appear in PhysicalProfile. If both exist,
    /// prefer the PhysicalProfile value as it's more specific to health data.
    public let dateOfBirth: Date?

    /// Profile creation timestamp
    ///
    /// When this profile was first created in the backend.
    public let createdAt: Date

    /// Last update timestamp
    ///
    /// When this profile was last modified in the backend.
    public let updatedAt: Date

    // MARK: - Computed Properties

    /// Age calculated from date of birth
    ///
    /// Returns nil if dateOfBirth is not set or if the calculation fails.
    public var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }

    /// Whether the user prefers metric units
    public var usesMetricUnits: Bool {
        preferredUnitSystem.lowercased() == "metric"
    }

    /// Whether the user prefers imperial units
    public var usesImperialUnits: Bool {
        preferredUnitSystem.lowercased() == "imperial"
    }

    // MARK: - Initializer

    /// Creates a new UserProfileMetadata instance
    ///
    /// - Parameters:
    ///   - id: Profile ID (from backend)
    ///   - userId: User ID (from JWT/auth)
    ///   - name: Full name (required)
    ///   - bio: Biography/description (optional)
    ///   - preferredUnitSystem: "metric" or "imperial" (required)
    ///   - languageCode: ISO 639-1 language code (optional)
    ///   - dateOfBirth: Date of birth (optional)
    ///   - createdAt: Profile creation timestamp
    ///   - updatedAt: Last update timestamp
    public init(
        id: UUID,
        userId: UUID,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?,
        dateOfBirth: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.bio = bio
        self.preferredUnitSystem = preferredUnitSystem
        self.languageCode = languageCode
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Validation

extension UserProfileMetadata {
    /// Validates that the metadata meets business rules
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Name is required and cannot be empty
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.emptyName)
        }

        // Name should have reasonable length
        if name.count > 100 {
            errors.append(.nameTooLong)
        }

        // Unit system must be either "metric" or "imperial"
        let validUnitSystems = ["metric", "imperial"]
        if !validUnitSystems.contains(preferredUnitSystem.lowercased()) {
            errors.append(.invalidUnitSystem(preferredUnitSystem))
        }

        // Bio should have reasonable length if provided
        if let bio = bio, bio.count > 500 {
            errors.append(.bioTooLong)
        }

        // Language code should be 2-3 characters if provided
        if let languageCode = languageCode,
            !languageCode.isEmpty,
            !(2...3).contains(languageCode.count)
        {
            errors.append(.invalidLanguageCode(languageCode))
        }

        // Date of birth should not be in the future
        if let dateOfBirth = dateOfBirth, dateOfBirth > Date() {
            errors.append(.dateOfBirthInFuture)
        }

        return errors
    }

    /// Whether this metadata is valid
    public var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Validation Error

extension UserProfileMetadata {
    /// Validation errors for UserProfileMetadata
    public enum ValidationError: Error, LocalizedError, Equatable {
        case emptyName
        case nameTooLong
        case invalidUnitSystem(String)
        case bioTooLong
        case invalidLanguageCode(String)
        case dateOfBirthInFuture

        public var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Name is required and cannot be empty"
            case .nameTooLong:
                return "Name is too long (maximum 100 characters)"
            case .invalidUnitSystem(let system):
                return "Invalid unit system '\(system)'. Must be 'metric' or 'imperial'"
            case .bioTooLong:
                return "Bio is too long (maximum 500 characters)"
            case .invalidLanguageCode(let code):
                return "Invalid language code '\(code)'. Must be 2-3 characters"
            case .dateOfBirthInFuture:
                return "Date of birth cannot be in the future"
            }
        }
    }
}

// MARK: - Convenience Initializers

extension UserProfileMetadata {
    /// Creates a UserProfileMetadata with minimal required fields
    ///
    /// Useful for testing or when creating a new profile with defaults.
    ///
    /// - Parameters:
    ///   - id: Profile ID
    ///   - userId: User ID
    ///   - name: Full name
    ///   - preferredUnitSystem: Unit preference (defaults to "metric")
    public init(
        id: UUID,
        userId: UUID,
        name: String,
        preferredUnitSystem: String = "metric"
    ) {
        self.init(
            id: id,
            userId: userId,
            name: name,
            bio: nil,
            preferredUnitSystem: preferredUnitSystem,
            languageCode: nil,
            dateOfBirth: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
