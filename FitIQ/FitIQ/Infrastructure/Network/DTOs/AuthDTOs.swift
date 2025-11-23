//
//  AuthDTOs.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//  Refactored to match actual backend API spec - 2025-01-27
//  Updated for Phase 2: Map to new domain models - 2025-01-27
//

import FitIQCore
import Foundation

// Import domain models for DTO mapping
// These models are defined in Domain/Entities/Profile/ and Domain/Entities/Auth/

// MARK: - User Profile DTOs (from /api/v1/users/me)

/// Maps to the actual structure returned by GET /api/v1/users/me
/// The endpoint returns user info with nested profile object
struct UserWithProfileResponseDTO: Decodable {
    let id: String  // User ID (UUID)
    let email: String
    let profile: ProfileDTO

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case profile
    }

    struct ProfileDTO: Decodable {
        let id: String  // Profile ID (UUID)
        let name: String
        let preferredUnitSystem: String
        let languageCode: String?
        let dateOfBirth: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case preferredUnitSystem = "preferred_unit_system"
            case languageCode = "language_code"
            case dateOfBirth = "date_of_birth"
        }
    }
}

/// Maps to the exact structure returned by GET/PUT /api/v1/users/me (legacy/alternative format)
/// This is the user's profile metadata (name, bio, preferences)
struct UserProfileResponseDTO: Decodable {
    let id: String  // Profile ID (UUID)
    let userId: String  // User ID (UUID)
    let name: String  // Full name
    let bio: String?  // Biography/description
    let preferredUnitSystem: String  // "metric" or "imperial"
    let languageCode: String?  // Language preference (e.g., "en", "pt")
    let dateOfBirth: String?  // Date of birth (YYYY-MM-DD format)
    let biologicalSex: String?  // Biological sex from physical profile
    let heightCm: Double?  // Height in centimeters from physical profile
    let createdAt: String  // ISO 8601 timestamp
    let updatedAt: String  // ISO 8601 timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case bio
        case preferredUnitSystem = "preferred_unit_system"
        case languageCode = "language_code"
        case dateOfBirth = "date_of_birth"
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Wrapper for the actual profile response structure from backend
/// Backend returns: {"data": {"profile": {...}}}
struct UserProfileDataWrapper: Decodable {
    let profile: UserProfileResponseDTO
}

/// Maps to PUT /api/v1/users/me request body
struct UserProfileUpdateRequest: Encodable {
    let name: String  // REQUIRED
    let preferredUnitSystem: String  // REQUIRED: "metric" or "imperial"
    let bio: String?  // OPTIONAL
    let languageCode: String?  // OPTIONAL

    enum CodingKeys: String, CodingKey {
        case name
        case preferredUnitSystem = "preferred_unit_system"
        case bio
        case languageCode = "language_code"
    }
}

// MARK: - Physical Profile DTOs (from /api/v1/users/me/physical)

/// Maps to the response from PATCH /api/v1/users/me/physical
/// This is separate from the main profile and contains physical attributes
struct PhysicalProfileResponseDTO: Decodable {
    let biologicalSex: String?  // "male", "female", "other"
    let heightCm: Double?  // Height in centimeters
    let dateOfBirth: String?  // Date of birth (YYYY-MM-DD format)

    enum CodingKeys: String, CodingKey {
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
        case dateOfBirth = "date_of_birth"
    }
}

/// Maps to PATCH /api/v1/users/me/physical request body
struct PhysicalProfileUpdateRequest: Encodable {
    let biologicalSex: String?  // OPTIONAL: "male", "female", "other"
    let heightCm: Double?  // OPTIONAL: Height in centimeters
    let dateOfBirth: String?  // OPTIONAL: Date of birth (YYYY-MM-DD)

    enum CodingKeys: String, CodingKey {
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
        case dateOfBirth = "date_of_birth"
    }

    // Custom encoding to exclude nil values from JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Only encode non-nil values
        if let biologicalSex = biologicalSex {
            try container.encode(biologicalSex, forKey: .biologicalSex)
        }
        if let heightCm = heightCm {
            try container.encode(heightCm, forKey: .heightCm)
        }
        if let dateOfBirth = dateOfBirth {
            try container.encode(dateOfBirth, forKey: .dateOfBirth)
        }
    }
}

// MARK: - Auth DTOs (Login/Register)

/// Maps to the API's successful login/register response body
struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

// MARK: - Domain Mapping Extensions

extension UserProfileResponseDTO {
    /// Converts the backend profile DTO to FitIQCore.UserProfile domain model
    ///
    /// This maps the profile metadata from /api/v1/users/me to the unified profile model.
    /// Physical attributes (biologicalSex, heightCm) are included if available.
    ///
    /// **Phase 2.1 Migration:** Now returns FitIQCore.UserProfile directly
    ///
    /// - Parameters:
    ///   - email: User's email (from JWT or stored locally)
    ///   - hasPerformedInitialHealthKitSync: Local HealthKit sync state
    ///   - lastSuccessfulDailySyncDate: Last HealthKit sync date
    /// - Returns: FitIQCore.UserProfile domain model
    /// - Throws: DTOConversionError if data is invalid
    func toDomain(
        email: String? = nil,
        hasPerformedInitialHealthKitSync: Bool = false,
        lastSuccessfulDailySyncDate: Date? = nil
    ) throws -> FitIQCore.UserProfile {
        // Parse user ID (use userId field from DTO)
        guard let userUUID = UUID(uuidString: userId) else {
            throw DTOConversionError.invalidUserId(userId)
        }

        // Parse date of birth if present
        var parsedDateOfBirth: Date? = nil
        if let dobString = dateOfBirth, !dobString.isEmpty {
            parsedDateOfBirth = try dobString.toDateFromISO8601()
        }

        // Parse created_at timestamp (allow empty string for responses that don't include it)
        let createdAtDate: Date
        if createdAt.isEmpty {
            createdAtDate = Date()  // Use current date as fallback
        } else {
            guard let parsed = try? createdAt.toDateFromISO8601() else {
                throw DTOConversionError.invalidDateFormat(createdAt)
            }
            createdAtDate = parsed
        }

        // Parse updated_at timestamp (allow empty string for responses that don't include it)
        let updatedAtDate: Date
        if updatedAt.isEmpty {
            updatedAtDate = Date()  // Use current date as fallback
        } else {
            guard let parsed = try? updatedAt.toDateFromISO8601() else {
                throw DTOConversionError.invalidDateFormat(updatedAt)
            }
            updatedAtDate = parsed
        }

        // Create FitIQCore.UserProfile with all available data
        return FitIQCore.UserProfile(
            id: userUUID,
            email: email ?? "",
            name: name,
            bio: bio,
            username: nil,
            languageCode: languageCode,
            dateOfBirth: parsedDateOfBirth,
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            preferredUnitSystem: preferredUnitSystem,
            hasPerformedInitialHealthKitSync: hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: lastSuccessfulDailySyncDate,
            createdAt: createdAtDate,
            updatedAt: updatedAtDate
        )
    }
}

extension PhysicalProfileResponseDTO {
    /// Converts the backend physical profile DTO to update fields for FitIQCore.UserProfile
    ///
    /// This maps the physical attributes from /api/v1/users/me/physical.
    /// Use this to update an existing profile with physical data.
    ///
    /// **Phase 2.1 Migration:** Returns tuple for updating existing profile
    ///
    /// - Returns: Tuple with physical attributes
    /// - Throws: DTOConversionError if data is invalid
    func toPhysicalAttributes() throws -> (
        biologicalSex: String?, heightCm: Double?, dateOfBirth: Date?
    ) {
        // Parse date of birth if present
        var parsedDateOfBirth: Date? = nil
        if let dobString = dateOfBirth, !dobString.isEmpty {
            parsedDateOfBirth = try dobString.toDateFromISO8601()
        }

        return (biologicalSex: biologicalSex, heightCm: heightCm, dateOfBirth: parsedDateOfBirth)
    }
}

extension LoginResponse {
    /// Converts the login response DTO to AuthToken domain model
    ///
    /// This maps the authentication tokens from /api/v1/auth/login or /register to the domain model.
    /// Expiration time is parsed from the JWT if possible.
    ///
    /// - Returns: AuthToken domain model
    func toDomain() -> AuthToken {
        // Use the factory method that parses expiration from JWT
        return AuthToken.withParsedExpiration(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}

// MARK: - Date Formatting Helpers

extension String {
    /// Converts ISO 8601 date string to Date
    ///
    /// Supports both full timestamps and date-only formats.
    ///
    /// **CRITICAL:** For date-only strings (YYYY-MM-DD), parses in the user's local timezone
    /// to match DatePicker behavior. This ensures "1983-07-20" becomes July 20 at midnight
    /// in the user's timezone, not UTC.
    ///
    /// - Returns: Parsed Date object
    /// - Throws: DTOConversionError if parsing fails
    func toDateFromISO8601() throws -> Date {
        let isoFormatter = ISO8601DateFormatter()

        // Try full timestamp first (with time)
        if let date = isoFormatter.date(from: self) {
            return date
        }

        // Try date-only format (YYYY-MM-DD) - parse in user's local timezone
        // This matches DatePicker behavior which creates dates at midnight local time
        if let date = Date.fromISO8601DateString(self) {
            return date
        }

        throw DTOConversionError.invalidDateFormat(self)
    }
}

extension Date {
    /// Converts Date to ISO 8601 date string (YYYY-MM-DD format)
    ///
    /// Used for encoding date of birth in API requests.
    ///
    /// **CRITICAL:** Uses the user's current timezone to extract calendar components.
    /// This ensures that when a user selects "July 20, 1983" in a DatePicker,
    /// we send "1983-07-20" to the backend, not "1983-07-19" due to UTC conversion.
    ///
    /// - Returns: ISO 8601 formatted date string (YYYY-MM-DD) in user's timezone
    func toISO8601DateString() -> String {
        // Extract calendar components in the user's current timezone
        // This respects the calendar date the user selected in the DatePicker
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    /// Converts Date to ISO 8601 timestamp string
    ///
    /// Used for encoding full timestamps in API requests.
    ///
    /// - Returns: ISO 8601 formatted timestamp string
    func toISO8601TimestampString() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }

    /// Creates a Date from an ISO 8601 date string (YYYY-MM-DD) in the user's current timezone
    ///
    /// **CRITICAL:** Parses the date string as a calendar date in the user's timezone,
    /// not as a UTC timestamp. This ensures that "1983-07-20" creates a Date representing
    /// July 20, 1983 at midnight in the user's local timezone.
    ///
    /// This matches the behavior of DatePicker, which creates dates at midnight local time.
    ///
    /// - Parameter dateString: ISO 8601 date string (YYYY-MM-DD)
    /// - Returns: Date at midnight in user's timezone, or nil if parsing fails
    static func fromISO8601DateString(_ dateString: String) -> Date? {
        let components = dateString.split(separator: "-")
        guard components.count == 3,
            let year = Int(components[0]),
            let month = Int(components[1]),
            let day = Int(components[2])
        else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0

        // Create date in user's current timezone
        return Calendar.current.date(from: dateComponents)
    }
}

// MARK: - Error Types

enum DTOConversionError: Error, LocalizedError {
    case invalidProfileId(String)
    case invalidUserId(String)
    case invalidDateFormat(String)
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfileId(let id):
            return "Invalid profile ID format: \(id)"
        case .invalidUserId(let id):
            return "Invalid user ID format: \(id)"
        case .invalidDateFormat(let date):
            return "Invalid date format: \(date). Expected ISO 8601 format."
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        }
    }
}

// MARK: - Request Builders

extension UserProfileUpdateRequest {
    /// Creates a request from FitIQCore.UserProfile domain model
    ///
    /// **Phase 2.1 Migration:** Now uses FitIQCore.UserProfile
    ///
    /// - Parameter profile: The user profile to convert
    /// - Returns: UserProfileUpdateRequest for API
    static func from(_ profile: FitIQCore.UserProfile) -> UserProfileUpdateRequest {
        return UserProfileUpdateRequest(
            name: profile.name,
            preferredUnitSystem: profile.preferredUnitSystem,
            bio: profile.bio,
            languageCode: profile.languageCode
        )
    }
}

extension PhysicalProfileUpdateRequest {
    /// Creates a request from FitIQCore.UserProfile domain model
    ///
    /// **Phase 2.1 Migration:** Now uses FitIQCore.UserProfile
    ///
    /// - Parameter profile: The user profile with physical attributes
    /// - Returns: PhysicalProfileUpdateRequest for API
    static func from(_ profile: FitIQCore.UserProfile) -> PhysicalProfileUpdateRequest {
        return PhysicalProfileUpdateRequest(
            biologicalSex: profile.biologicalSex,
            heightCm: profile.heightCm,
            dateOfBirth: profile.dateOfBirth?.toISO8601DateString()
        )
    }
}
