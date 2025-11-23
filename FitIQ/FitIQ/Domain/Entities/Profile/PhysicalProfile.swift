//
//  PhysicalProfile.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Refactoring - Phase 1
//

import Foundation

/// Physical profile data from PATCH /api/v1/users/me/physical
///
/// This contains the user's physical attributes (biological sex, height, date of birth)
/// separate from profile metadata and authentication data.
///
/// **Backend Endpoint:** `/api/v1/users/me/physical`
///
/// **Architecture:** Domain Entity (pure business logic, no external dependencies)
///
/// **Related Models:**
/// - `UserProfileMetadata` - Profile information from `/api/v1/users/me`
/// - `UserProfile` - Composition of metadata + physical
///
/// **Example:**
/// ```swift
/// let physical = PhysicalProfile(
///     biologicalSex: "male",
///     heightCm: 180.5,
///     dateOfBirth: Date()
/// )
/// ```
public struct PhysicalProfile: Equatable {
    // MARK: - Properties

    /// Biological sex: "male", "female", "other" (optional)
    ///
    /// Used for health calculations and HealthKit integration.
    /// Values should match HealthKit's HKBiologicalSex options.
    public let biologicalSex: String?

    /// Height in centimeters (optional)
    ///
    /// Always stored in centimeters regardless of user's preferred unit system.
    /// The presentation layer handles conversion to inches if needed.
    public let heightCm: Double?

    /// Date of birth (optional)
    ///
    /// Note: This may also appear in UserProfileMetadata. If both exist,
    /// this value should take precedence as it's specific to health data.
    /// Used for age-based health calculations.
    public let dateOfBirth: Date?

    // MARK: - Computed Properties

    /// Height in inches (calculated from heightCm)
    ///
    /// Returns nil if heightCm is not set.
    public var heightInches: Double? {
        guard let heightCm = heightCm else { return nil }
        return heightCm / 2.54
    }

    /// Height in feet and inches (calculated from heightCm)
    ///
    /// Returns a tuple of (feet, inches) or nil if heightCm is not set.
    /// Example: 180.5 cm = (5 feet, 11 inches)
    public var heightFeetAndInches: (feet: Int, inches: Double)? {
        guard let totalInches = heightInches else { return nil }
        let feet = Int(totalInches / 12)
        let inches = totalInches.truncatingRemainder(dividingBy: 12)
        return (feet, inches)
    }

    /// Age calculated from date of birth
    ///
    /// Returns nil if dateOfBirth is not set or if the calculation fails.
    public var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }

    /// Whether biological sex is set
    public var hasBiologicalSex: Bool {
        biologicalSex != nil && !(biologicalSex?.isEmpty ?? true)
    }

    /// Whether height is set
    public var hasHeight: Bool {
        heightCm != nil && (heightCm ?? 0) > 0
    }

    /// Whether date of birth is set
    public var hasDateOfBirth: Bool {
        dateOfBirth != nil
    }

    /// Whether the profile has any physical data
    public var hasAnyData: Bool {
        hasBiologicalSex || hasHeight || hasDateOfBirth
    }

    // MARK: - Initializer

    /// Creates a new PhysicalProfile instance
    ///
    /// - Parameters:
    ///   - biologicalSex: Biological sex ("male", "female", "other") - optional
    ///   - heightCm: Height in centimeters - optional
    ///   - dateOfBirth: Date of birth - optional
    public init(
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) {
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.dateOfBirth = dateOfBirth
    }
}

// MARK: - Validation

extension PhysicalProfile {
    /// Validates that the physical profile meets business rules
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Biological sex must be one of the valid values if provided
        if let biologicalSex = biologicalSex, !biologicalSex.isEmpty {
            let validSexes = ["male", "female", "other"]
            if !validSexes.contains(biologicalSex.lowercased()) {
                errors.append(.invalidBiologicalSex(biologicalSex))
            }
        }

        // Height must be positive and within reasonable range if provided
        if let heightCm = heightCm {
            if heightCm <= 0 {
                errors.append(.heightMustBePositive)
            } else if heightCm < 50 {
                // Minimum reasonable height: 50 cm (1.64 feet)
                errors.append(.heightTooLow(heightCm))
            } else if heightCm > 300 {
                // Maximum reasonable height: 300 cm (9.84 feet)
                errors.append(.heightTooHigh(heightCm))
            }
        }

        // Date of birth should not be in the future
        if let dateOfBirth = dateOfBirth, dateOfBirth > Date() {
            errors.append(.dateOfBirthInFuture)
        }

        // Age should be reasonable if date of birth is provided
        if let age = age {
            if age < 0 {
                errors.append(.invalidAge(age))
            } else if age > 150 {
                errors.append(.ageTooHigh(age))
            }
        }

        return errors
    }

    /// Whether this physical profile is valid
    public var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Validation Error

extension PhysicalProfile {
    /// Validation errors for PhysicalProfile
    public enum ValidationError: Error, LocalizedError, Equatable {
        case invalidBiologicalSex(String)
        case heightMustBePositive
        case heightTooLow(Double)
        case heightTooHigh(Double)
        case dateOfBirthInFuture
        case invalidAge(Int)
        case ageTooHigh(Int)

        public var errorDescription: String? {
            switch self {
            case .invalidBiologicalSex(let sex):
                return "Invalid biological sex '\(sex)'. Must be 'male', 'female', or 'other'"
            case .heightMustBePositive:
                return "Height must be a positive number"
            case .heightTooLow(let height):
                return "Height of \(height) cm is too low. Minimum is 50 cm"
            case .heightTooHigh(let height):
                return "Height of \(height) cm is too high. Maximum is 300 cm"
            case .dateOfBirthInFuture:
                return "Date of birth cannot be in the future"
            case .invalidAge(let age):
                return "Invalid age: \(age)"
            case .ageTooHigh(let age):
                return "Age of \(age) is too high. Maximum is 150"
            }
        }
    }
}

// MARK: - Convenience Initializers

extension PhysicalProfile {
    /// Creates an empty PhysicalProfile
    ///
    /// Useful for users who haven't provided any physical data yet.
    public static var empty: PhysicalProfile {
        PhysicalProfile(
            biologicalSex: nil,
            heightCm: nil,
            dateOfBirth: nil
        )
    }

    /// Creates a PhysicalProfile with height in inches
    ///
    /// Convenience initializer for imperial unit users.
    ///
    /// - Parameters:
    ///   - biologicalSex: Biological sex (optional)
    ///   - heightInches: Height in inches (will be converted to cm)
    ///   - dateOfBirth: Date of birth (optional)
    public init(
        biologicalSex: String?,
        heightInches: Double?,
        dateOfBirth: Date?
    ) {
        let heightCm = heightInches.map { $0 * 2.54 }
        self.init(
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            dateOfBirth: dateOfBirth
        )
    }
}

// MARK: - Display Formatting

extension PhysicalProfile {
    /// Formatted height string based on unit preference
    ///
    /// - Parameter useMetric: Whether to use metric units
    /// - Returns: Formatted height string or nil if height not set
    public func formattedHeight(useMetric: Bool) -> String? {
        guard let heightCm = heightCm else { return nil }

        if useMetric {
            return String(format: "%.1f cm", heightCm)
        } else {
            guard let (feet, inches) = heightFeetAndInches else { return nil }
            return String(format: "%d' %.1f\"", feet, inches)
        }
    }

    /// Formatted biological sex string
    ///
    /// Returns a capitalized, user-friendly version of biological sex.
    public var formattedBiologicalSex: String? {
        biologicalSex?.capitalized
    }

    /// Formatted age string
    ///
    /// Returns age with "years" suffix or nil if not available.
    public var formattedAge: String? {
        guard let age = age else { return nil }
        return "\(age) years"
    }
}
