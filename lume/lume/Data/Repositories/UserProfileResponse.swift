//
//  UserProfileResponse.swift
//  lume
//
//  Created by FitIQ Team on 2025-01-27.
//  Models for user profile API responses from backend
//

import Foundation

// MARK: - User Profile Response Models

/// User profile response from /api/v1/users/me
struct UserProfileResponse: Codable {
    let data: UserProfileData
}

/// User profile data from backend API
struct UserProfileData: Codable {
    let id: String  // User ID
    let email: String
    let profile: ProfileDetails
}

/// Detailed profile information
struct ProfileDetails: Codable {
    let id: String
    let name: String
    let bio: String?
    let preferredUnitSystem: String
    let languageCode: String
    let dateOfBirth: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bio
        case preferredUnitSystem = "preferred_unit_system"
        case languageCode = "language_code"
        case dateOfBirth = "date_of_birth"
    }

    /// Parse date of birth from string
    var dateOfBirthDate: Date? {
        guard let dateOfBirth = dateOfBirth else { return nil }

        // Try ISO8601 format first (with time)
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateOfBirth) {
            return date
        }

        // Try YYYY-MM-DD format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateOfBirth)
    }
}

// MARK: - Convenience Accessors

extension UserProfileData {
    /// Convert user id string to UUID
    var userIdUUID: UUID? {
        UUID(uuidString: id)
    }

    /// Get user's name from nested profile
    var name: String {
        profile.name
    }

    /// Get date of birth from nested profile
    var dateOfBirthDate: Date? {
        profile.dateOfBirthDate
    }
}
