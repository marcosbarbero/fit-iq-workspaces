//
//  UserProfile.swift
//  lume
//
//  Created by AI Assistant on 30/01/2025.
//

import Foundation

// MARK: - User Profile

/// User profile entity from the domain layer
/// Maps to /api/v1/users/me endpoint
struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let name: String
    let bio: String?
    let preferredUnitSystem: UnitSystem
    let languageCode: String
    let dateOfBirth: Date?
    let createdAt: Date
    let updatedAt: Date

    /// Physical profile attributes
    var biologicalSex: String?
    var heightCm: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case bio
        case preferredUnitSystem = "preferred_unit_system"
        case languageCode = "language_code"
        case dateOfBirth = "date_of_birth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
    }
}

// MARK: - Unit System

/// Unit system preference
enum UnitSystem: String, Codable, CaseIterable {
    case metric
    case imperial

    var displayName: String {
        switch self {
        case .metric:
            return "Metric (kg, cm)"
        case .imperial:
            return "Imperial (lb, in)"
        }
    }
}

// MARK: - Dietary & Activity Preferences

/// Dietary and activity preferences
struct DietaryActivityPreferences: Identifiable, Codable, Equatable {
    let id: String
    let userProfileId: String
    var allergies: [String]
    var dietaryRestrictions: [String]
    var foodDislikes: [String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userProfileId = "user_profile_id"
        case allergies
        case dietaryRestrictions = "dietary_restrictions"
        case foodDislikes = "food_dislikes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Update Requests

/// Request to update user profile
struct UpdateUserProfileRequest: Codable {
    let name: String
    let bio: String?
    let preferredUnitSystem: UnitSystem
    let languageCode: String

    enum CodingKeys: String, CodingKey {
        case name
        case bio
        case preferredUnitSystem = "preferred_unit_system"
        case languageCode = "language_code"
    }
}

/// Request to update physical profile attributes
struct UpdatePhysicalProfileRequest: Codable {
    let biologicalSex: String?
    let heightCm: Double?
    let dateOfBirth: String?

    enum CodingKeys: String, CodingKey {
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
        case dateOfBirth = "date_of_birth"
    }
}

/// Request to update dietary and activity preferences
struct UpdatePreferencesRequest: Codable {
    let allergies: [String]?
    let dietaryRestrictions: [String]?
    let foodDislikes: [String]?

    enum CodingKeys: String, CodingKey {
        case allergies
        case dietaryRestrictions = "dietary_restrictions"
        case foodDislikes = "food_dislikes"
    }
}

// MARK: - Convenience Extensions

extension UserProfile {
    /// Get user ID as UUID
    var userIdUUID: UUID? {
        UUID(uuidString: userId)
    }

    /// Get height in feet and inches (if using imperial)
    var heightInFeetAndInches: (feet: Int, inches: Int)? {
        guard let heightCm = heightCm else { return nil }
        let totalInches = heightCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return (feet, inches)
    }

    /// Get height in meters (if using metric)
    var heightInMeters: Double? {
        guard let heightCm = heightCm else { return nil }
        return heightCm / 100.0
    }

    /// Calculate age from date of birth
    var age: Int? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year
    }
}

extension DietaryActivityPreferences {
    /// Check if user has any dietary restrictions
    var hasDietaryRestrictions: Bool {
        !allergies.isEmpty || !dietaryRestrictions.isEmpty || !foodDislikes.isEmpty
    }

    /// Get formatted summary of dietary restrictions
    var restrictionsSummary: String? {
        var items: [String] = []

        if !allergies.isEmpty {
            items.append("Allergies: \(allergies.joined(separator: ", "))")
        }
        if !dietaryRestrictions.isEmpty {
            items.append("Restrictions: \(dietaryRestrictions.joined(separator: ", "))")
        }
        if !foodDislikes.isEmpty {
            items.append("Dislikes: \(foodDislikes.joined(separator: ", "))")
        }

        return items.isEmpty ? nil : items.joined(separator: "\n")
    }
}
