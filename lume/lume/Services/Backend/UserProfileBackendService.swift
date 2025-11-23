//
//  UserProfileBackendService.swift
//  lume
//
//  Created by AI Assistant on 30/01/2025.
//  Implements user profile endpoints from swagger-users.yaml
//

import Foundation

// MARK: - Protocol Definition

protocol UserProfileBackendServiceProtocol {
    /// Fetch current user's profile
    /// GET /api/v1/users/me
    func fetchUserProfile(accessToken: String) async throws -> UserProfile

    /// Update user profile
    /// PUT /api/v1/users/me
    func updateUserProfile(
        request: UpdateUserProfileRequest,
        accessToken: String
    ) async throws -> UserProfile

    /// Update physical profile attributes
    /// PATCH /api/v1/users/me/physical
    func updatePhysicalProfile(
        request: UpdatePhysicalProfileRequest,
        accessToken: String
    ) async throws -> UserProfile

    /// Delete user account (GDPR - Right to be Forgotten)
    /// DELETE /api/v1/users/me
    func deleteUserAccount(accessToken: String) async throws

    /// Get dietary and activity preferences
    /// GET /api/v1/users/me/preferences
    func fetchPreferences(accessToken: String) async throws -> DietaryActivityPreferences

    /// Update dietary and activity preferences
    /// PATCH /api/v1/users/me/preferences
    func updatePreferences(
        request: UpdatePreferencesRequest,
        accessToken: String
    ) async throws -> DietaryActivityPreferences

    /// Delete dietary and activity preferences
    /// DELETE /api/v1/users/me/preferences
    func deletePreferences(accessToken: String) async throws
}

// MARK: - Implementation

final class UserProfileBackendService: UserProfileBackendServiceProtocol {

    // MARK: - Properties

    private let httpClient: HTTPClient

    // MARK: - Initialization

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    // MARK: - Profile Methods

    func fetchUserProfile(accessToken: String) async throws -> UserProfile {
        print("🔍 [UserProfileBackendService] Fetching user profile")

        let response: UserProfileBackendResponse = try await httpClient.get(
            path: "/api/v1/users/me",
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] Profile fetched: \(response.data.profile.name)")
        return response.toDomain()
    }

    func updateUserProfile(
        request: UpdateUserProfileRequest,
        accessToken: String
    ) async throws -> UserProfile {
        print("📝 [UserProfileBackendService] Updating user profile: \(request.name)")

        let response: UserProfileBackendResponse = try await httpClient.put(
            path: "/api/v1/users/me",
            body: request,
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] Profile updated successfully")
        return response.toDomain()
    }

    func updatePhysicalProfile(
        request: UpdatePhysicalProfileRequest,
        accessToken: String
    ) async throws -> UserProfile {
        print("📝 [UserProfileBackendService] Updating physical profile")

        let response: UserProfileBackendResponse = try await httpClient.patch(
            path: "/api/v1/users/me/physical",
            body: request,
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] Physical profile updated successfully")
        return response.toDomain()
    }

    func deleteUserAccount(accessToken: String) async throws {
        print("🗑️ [UserProfileBackendService] Deleting user account (GDPR)")

        try await httpClient.delete(
            path: "/api/v1/users/me",
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] User account deleted successfully")
    }

    // MARK: - Preferences Methods

    func fetchPreferences(accessToken: String) async throws -> DietaryActivityPreferences {
        print("🔍 [UserProfileBackendService] Fetching dietary preferences")

        let response: PreferencesBackendResponse = try await httpClient.get(
            path: "/api/v1/users/me/preferences",
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] Preferences fetched")
        return response.data
    }

    func updatePreferences(
        request: UpdatePreferencesRequest,
        accessToken: String
    ) async throws -> DietaryActivityPreferences {
        print("📝 [UserProfileBackendService] Updating dietary preferences")

        let response: PreferencesBackendResponse = try await httpClient.patch(
            path: "/api/v1/users/me/preferences",
            body: request,
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] Preferences updated successfully")
        return response.data
    }

    func deletePreferences(accessToken: String) async throws {
        print("🗑️ [UserProfileBackendService] Deleting dietary preferences")

        try await httpClient.delete(
            path: "/api/v1/users/me/preferences",
            accessToken: accessToken
        )

        print("✅ [UserProfileBackendService] Preferences deleted successfully")
    }
}

// MARK: - Response Models (DTOs)

/// Response for user profile endpoints
/// Maps the actual backend structure to our domain model
private struct UserProfileBackendResponse: Decodable {
    let data: UserProfileResponseData

    struct UserProfileResponseData: Decodable {
        let id: String
        let email: String
        let profile: ProfileData

        struct ProfileData: Decodable {
            let id: String
            let name: String
            let bio: String?
            let preferredUnitSystem: String
            let languageCode: String
            let dateOfBirth: String?
            let biologicalSex: String?
            let heightCm: Double?
            let createdAt: String?
            let updatedAt: String?

            enum CodingKeys: String, CodingKey {
                case id
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
    }

    /// Convert DTO to domain model
    func toDomain() -> UserProfile {
        let isoFormatter = ISO8601DateFormatter()

        // Parse dates
        let dateOfBirth = data.profile.dateOfBirth.flatMap { isoFormatter.date(from: $0) }
        let createdAt = data.profile.createdAt.flatMap { isoFormatter.date(from: $0) } ?? Date()
        let updatedAt = data.profile.updatedAt.flatMap { isoFormatter.date(from: $0) } ?? Date()

        // Parse unit system
        let unitSystem = UnitSystem(rawValue: data.profile.preferredUnitSystem) ?? .metric

        return UserProfile(
            id: data.profile.id,
            userId: data.id,
            name: data.profile.name,
            bio: data.profile.bio,
            preferredUnitSystem: unitSystem,
            languageCode: data.profile.languageCode,
            dateOfBirth: dateOfBirth,
            createdAt: createdAt,
            updatedAt: updatedAt,
            biologicalSex: data.profile.biologicalSex,
            heightCm: data.profile.heightCm
        )
    }
}

/// Response for preferences endpoints
private struct PreferencesBackendResponse: Decodable {
    let data: DietaryActivityPreferences
}

// MARK: - Mock Implementation

final class MockUserProfileBackendService: UserProfileBackendServiceProtocol {
    var shouldFail = false
    var mockProfile: UserProfile?
    var mockPreferences: DietaryActivityPreferences?

    func fetchUserProfile(accessToken: String) async throws -> UserProfile {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        return mockProfile
            ?? UserProfile(
                id: UUID().uuidString,
                userId: UUID().uuidString,
                name: "Test User",
                bio: "Mock bio",
                preferredUnitSystem: .metric,
                languageCode: "en",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()),
                createdAt: Date(),
                updatedAt: Date(),
                biologicalSex: "Male",
                heightCm: 175.0
            )
    }

    func updateUserProfile(
        request: UpdateUserProfileRequest,
        accessToken: String
    ) async throws -> UserProfile {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        let profile =
            mockProfile
            ?? UserProfile(
                id: UUID().uuidString,
                userId: UUID().uuidString,
                name: request.name,
                bio: request.bio,
                preferredUnitSystem: request.preferredUnitSystem,
                languageCode: request.languageCode,
                dateOfBirth: nil,
                createdAt: Date(),
                updatedAt: Date(),
                biologicalSex: nil,
                heightCm: nil
            )

        mockProfile = profile
        return profile
    }

    func updatePhysicalProfile(
        request: UpdatePhysicalProfileRequest,
        accessToken: String
    ) async throws -> UserProfile {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        let profile: UserProfile
        if let mockProfile = mockProfile {
            profile = mockProfile
        } else {
            profile = try await fetchUserProfile(accessToken: accessToken)
        }
        return profile
    }

    func deleteUserAccount(accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        mockProfile = nil
        mockPreferences = nil
    }

    func fetchPreferences(accessToken: String) async throws -> DietaryActivityPreferences {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        return mockPreferences
            ?? DietaryActivityPreferences(
                id: UUID().uuidString,
                userProfileId: UUID().uuidString,
                allergies: ["Peanuts"],
                dietaryRestrictions: ["Vegetarian"],
                foodDislikes: ["Mushrooms"],
                createdAt: Date(),
                updatedAt: Date()
            )
    }

    func updatePreferences(
        request: UpdatePreferencesRequest,
        accessToken: String
    ) async throws -> DietaryActivityPreferences {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        let preferences = DietaryActivityPreferences(
            id: UUID().uuidString,
            userProfileId: UUID().uuidString,
            allergies: request.allergies ?? [],
            dietaryRestrictions: request.dietaryRestrictions ?? [],
            foodDislikes: request.foodDislikes ?? [],
            createdAt: Date(),
            updatedAt: Date()
        )

        mockPreferences = preferences
        return preferences
    }

    func deletePreferences(accessToken: String) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        mockPreferences = nil
    }
}
