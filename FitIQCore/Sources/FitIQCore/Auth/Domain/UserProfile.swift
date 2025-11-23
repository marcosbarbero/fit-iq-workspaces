//
//  UserProfile.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// User profile information shared across FitIQ and Lume apps
///
/// This model represents the core user profile data that both applications need.
/// It is stored securely in the Keychain alongside authentication tokens.
///
/// **Usage:**
/// ```swift
/// // Create profile after successful authentication
/// let profile = UserProfile(
///     id: userId,
///     email: "user@example.com",
///     name: "John Doe",
///     dateOfBirth: birthDate
/// )
///
/// // Save via AuthManager
/// await authManager.saveUserProfile(profile)
///
/// // Retrieve current profile
/// if let profile = authManager.currentUserProfile {
///     print("Welcome, \(profile.name)")
/// }
/// ```
///
/// **Thread Safety:** This is an immutable value type and is thread-safe.
public struct UserProfile: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Unique identifier for the user
    public let id: UUID

    /// User's email address
    public let email: String

    /// User's display name
    public let name: String

    /// User's date of birth (optional)
    public let dateOfBirth: Date?

    /// When this profile was created
    public let createdAt: Date

    /// When this profile was last updated
    public let updatedAt: Date

    // MARK: - Initialization

    /// Creates a new user profile
    ///
    /// - Parameters:
    ///   - id: User's unique identifier
    ///   - email: User's email address
    ///   - name: User's display name
    ///   - dateOfBirth: User's date of birth (optional)
    ///   - createdAt: Profile creation date (defaults to now)
    ///   - updatedAt: Last update date (defaults to now)
    public init(
        id: UUID,
        email: String,
        name: String,
        dateOfBirth: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension UserProfile {

    /// User's age based on date of birth (nil if no date of birth provided)
    public var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: now)
        return ageComponents.year
    }

    /// User's initials (e.g., "JD" for "John Doe")
    public var initials: String {
        let components = name.split(separator: " ")
        let initials = components.compactMap { $0.first?.uppercased() }
        return initials.prefix(2).joined()
    }

    /// First name extracted from full name
    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Last name extracted from full name (if available)
    public var lastName: String? {
        let components = name.split(separator: " ")
        guard components.count > 1 else { return nil }
        return components.dropFirst().joined(separator: " ")
    }
}

// MARK: - Validation

extension UserProfile {

    /// Validates that the profile meets business rules
    ///
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        // Email validation
        if email.isEmpty {
            errors.append(.emptyEmail)
        } else if !isValidEmail(email) {
            errors.append(.invalidEmailFormat)
        }

        // Name validation
        if name.isEmpty {
            errors.append(.emptyName)
        } else if name.count < 2 {
            errors.append(.nameTooShort)
        }

        // Date of birth validation
        if let dob = dateOfBirth {
            let now = Date()

            // Check if date is in the future
            if dob > now {
                errors.append(.dateOfBirthInFuture)
            }

            // Check if age is reasonable (between 13 and 120 years)
            if let age = age {
                if age < 13 {
                    errors.append(.ageTooYoung)
                } else if age > 120 {
                    errors.append(.ageTooOld)
                }
            }
        }

        return errors
    }

    /// Validation errors for UserProfile
    public enum ValidationError: Error, LocalizedError, Equatable, Sendable {
        case emptyEmail
        case invalidEmailFormat
        case emptyName
        case nameTooShort
        case dateOfBirthInFuture
        case ageTooYoung
        case ageTooOld

        public var errorDescription: String? {
            switch self {
            case .emptyEmail:
                return "Email address cannot be empty"
            case .invalidEmailFormat:
                return "Email address format is invalid"
            case .emptyName:
                return "Name cannot be empty"
            case .nameTooShort:
                return "Name must be at least 2 characters"
            case .dateOfBirthInFuture:
                return "Date of birth cannot be in the future"
            case .ageTooYoung:
                return "You must be at least 13 years old"
            case .ageTooOld:
                return "Invalid date of birth"
            }
        }
    }

    // MARK: - Private Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Update Methods

extension UserProfile {

    /// Creates an updated copy of the profile with new values
    ///
    /// - Parameters:
    ///   - email: New email (optional, keeps existing if nil)
    ///   - name: New name (optional, keeps existing if nil)
    ///   - dateOfBirth: New date of birth (optional, keeps existing if nil)
    /// - Returns: New UserProfile instance with updated values
    public func updated(
        email: String? = nil,
        name: String? = nil,
        dateOfBirth: Date? = nil
    ) -> UserProfile {
        UserProfile(
            id: self.id,
            email: email ?? self.email,
            name: name ?? self.name,
            dateOfBirth: dateOfBirth ?? self.dateOfBirth,
            createdAt: self.createdAt,
            updatedAt: Date()  // Update timestamp
        )
    }
}

// MARK: - Custom String Convertible

extension UserProfile: CustomStringConvertible {

    /// Human-readable description (safe for logging - hides email)
    public var description: String {
        let emailParts = email.split(separator: "@")
        let emailDomain = emailParts.last.map(String.init) ?? ""
        let domainPreview = emailDomain.isEmpty ? "***" : String(emailDomain.prefix(3)) + "***"
        let emailPreview = String(email.prefix(3)) + "***@" + domainPreview
        let dobString = dateOfBirth.map { "dob: \(formatDate($0))" } ?? "no dob"
        return "UserProfile(id: \(id), email: \(emailPreview), name: \(name), \(dobString))"
    }

    /// Sanitized description for logging (minimal information exposure)
    public var sanitizedDescription: String {
        "UserProfile(id: \(id), name: \(name))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Codable Keys

extension UserProfile {

    /// Coding keys for JSON serialization
    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case dateOfBirth
        case createdAt
        case updatedAt
    }
}

// MARK: - Factory Methods

extension UserProfile {

    /// Creates a profile from backend API response
    ///
    /// This is a convenience method for parsing API responses that may have
    /// different date formats or nested structures.
    ///
    /// - Parameters:
    ///   - id: User ID string (will be converted to UUID)
    ///   - email: Email address
    ///   - name: Display name
    ///   - dateOfBirthString: Date of birth as ISO8601 or YYYY-MM-DD string
    /// - Returns: UserProfile if all data is valid, nil otherwise
    public static func from(
        id: String,
        email: String,
        name: String,
        dateOfBirthString: String?
    ) -> UserProfile? {
        guard let userId = UUID(uuidString: id) else {
            return nil
        }

        var dateOfBirth: Date?
        if let dobString = dateOfBirthString {
            // Try ISO8601 first
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: dobString) {
                dateOfBirth = date
            } else {
                // Try YYYY-MM-DD format
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                dateOfBirth = formatter.date(from: dobString)
            }
        }

        return UserProfile(
            id: userId,
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )
    }
}
