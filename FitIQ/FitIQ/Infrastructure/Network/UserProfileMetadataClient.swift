//
//  UserProfileMetadataClient.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of API Client Refactoring - Separation of Concerns
//

import Foundation
import FitIQCore

/// Client for user profile metadata operations
///
/// Handles all operations related to user profile metadata (name, bio, preferences, etc.)
/// via the `/api/v1/users/me` endpoint.
///
/// **Responsibilities:**
/// - Create profile on backend (POST /api/v1/users/me)
/// - Fetch profile metadata (GET /api/v1/users/me)
/// - Update profile metadata (PUT /api/v1/users/me)
///
/// **Architecture:** Infrastructure Adapter (Hexagonal Architecture)
/// - Implements secondary port for profile metadata operations
/// - Adapts domain models to/from API DTOs
/// - Handles network communication and error handling
///
/// **Related Clients:**
/// - `UserAuthAPIClient` - Authentication operations (/auth/*)
/// - `PhysicalProfileAPIClient` - Physical profile operations (/api/v1/users/me/physical)
///
final class UserProfileMetadataClient {

    // MARK: - Dependencies

    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol

    // MARK: - Initialization

    init(
        networkClient: NetworkClientProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        userProfileStorage: UserProfileStoragePortProtocol
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
        self.userProfileStorage = userProfileStorage
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
    }

    // MARK: - Public Methods

    /// Creates a new user profile on the backend (PUT /api/v1/users/me)
    ///
    /// This should be called immediately after registration to create the profile.
    /// The registration endpoint only creates the auth user, not the profile.
    /// The backend auto-creates the profile on first PUT if it doesn't exist.
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - name: Full name (required)
    ///   - bio: Biography/description (optional)
    ///   - preferredUnitSystem: "metric" or "imperial" (required)
    ///   - languageCode: ISO 639-1 language code (optional)
    ///   - dateOfBirth: Date of birth (optional)
    /// - Returns: Created UserProfile
    /// - Throws: APIError if creation fails
    func createProfile(
        userId: String,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?,
        dateOfBirth: Date?
    ) async throws -> UserProfile {
        print("UserProfileMetadataClient: ===== CREATE PROFILE ON BACKEND =====")
        print("UserProfileMetadataClient: Creating profile for user \(userId)")
        print("UserProfileMetadataClient: Using PUT (backend auto-creates on first PUT)")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            print("UserProfileMetadataClient: ❌ No access token found")
            throw APIError.unauthorized
        }

        // Build request body
        var requestBody: [String: Any] = [
            "name": name,
            "preferred_unit_system": preferredUnitSystem,
        ]

        if let bio = bio, !bio.isEmpty {
            requestBody["bio"] = bio
        }

        if let languageCode = languageCode, !languageCode.isEmpty {
            requestBody["language_code"] = languageCode
        }

        if let dateOfBirth = dateOfBirth {
            // Extract calendar components from the Date in UTC timezone
            // This ensures the selected date (e.g., July 20) is sent as "1983-07-20"
            // regardless of device timezone, matching how we parse dates
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!  // UTC
            let components = calendar.dateComponents([.year, .month, .day], from: dateOfBirth)
            let dobString = String(
                format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
            requestBody["date_of_birth"] = dobString
        }

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("UserProfileMetadataClient: Request Body: \(bodyString)")
        }

        // Make PUT request to /users/me (backend auto-creates if not exists)
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        if let responseString = String(data: data, encoding: .utf8) {
            print("UserProfileMetadataClient: Response (\(statusCode)): \(responseString)")
        }

        guard statusCode == 200 else {
            print("UserProfileMetadataClient: ❌ Failed to create profile. Status: \(statusCode)")
            throw APIError.apiError(statusCode: statusCode, message: "Failed to create profile")
        }

        // Decode response
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)
            metadata = try successResponse.data.toDomain()
            print("UserProfileMetadataClient: ✅ Profile created successfully (wrapped response)")
        } catch {
            print("UserProfileMetadataClient: Trying direct decode...")
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileMetadataClient: ✅ Profile created successfully (direct response)")
        }

        // Get stored profile for email/username
        guard let userUUID = UUID(uuidString: userId) else {
            throw APIError.invalidUserId
        }
        let storedProfile = try? await userProfileStorage.fetch(forUserID: userUUID)
        let email = storedProfile?.email
        let username = storedProfile?.username

        // Create physical profile with DOB if provided
        var physical: PhysicalProfile? = nil
        if let dateOfBirth = dateOfBirth {
            physical = PhysicalProfile(
                biologicalSex: nil,
                heightCm: nil,
                dateOfBirth: dateOfBirth
            )
            print("UserProfileMetadataClient: Created physical profile with DOB: \(dateOfBirth)")
        }

        // Compose UserProfile
        let profile = UserProfile(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: false,
            lastSuccessfulDailySyncDate: nil
        )

        print("UserProfileMetadataClient: ===== PROFILE CREATION COMPLETE =====")
        return profile
    }

    /// Fetches the user profile from the backend (GET /api/v1/users/me)
    ///
    /// - Parameter userId: The user's unique identifier
    /// - Returns: Complete UserProfile with metadata and physical data
    /// - Throws: APIError if fetch fails
    func getProfile(userId: String) async throws -> UserProfile {
        print("UserProfileMetadataClient: ===== FETCH PROFILE FROM BACKEND =====")
        print("UserProfileMetadataClient: Fetching profile from /api/v1/users/me")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            throw APIError.unauthorized
        }

        // Fetch from /users/me endpoint
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        if let responseString = String(data: data, encoding: .utf8) {
            print("UserProfileMetadataClient: /me Response (\(statusCode)): \(responseString)")
        }

        guard statusCode == 200 else {
            print("UserProfileMetadataClient: ❌ Failed to fetch profile. Status: \(statusCode)")
            throw APIError.apiError(statusCode: statusCode, message: "Failed to fetch user profile")
        }

        // Decode response
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)
            metadata = try successResponse.data.toDomain()
            print("UserProfileMetadataClient: ✅ Successfully fetched profile metadata")
        } catch {
            print("UserProfileMetadataClient: Trying direct decode...")
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileMetadataClient: ✅ Successfully fetched profile metadata")
        }

        // Get stored profile for email/username/physical data
        let storedProfile = try? await userProfileStorage.fetch(forUserID: metadata.userId)
        let email = storedProfile?.email
        let username = storedProfile?.username
        let physical = storedProfile?.physical

        // Compose UserProfile from metadata + stored physical
        let profile = UserProfile(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: storedProfile?.hasPerformedInitialHealthKitSync
                ?? false,
            lastSuccessfulDailySyncDate: storedProfile?.lastSuccessfulDailySyncDate
        )

        print("UserProfileMetadataClient: ===== FETCH COMPLETE =====")
        return profile
    }

    /// Updates the user's profile metadata (PUT /api/v1/users/me)
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - name: Full name (required)
    ///   - bio: Biography/description (optional)
    ///   - preferredUnitSystem: "metric" or "imperial" (required)
    ///   - languageCode: ISO 639-1 language code (optional)
    /// - Returns: Updated UserProfile
    /// - Throws: APIError if update fails
    func updateMetadata(
        userId: String,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?
    ) async throws -> UserProfile {
        print("UserProfileMetadataClient: ===== UPDATE PROFILE METADATA =====")
        print("UserProfileMetadataClient: Updating profile via PUT /api/v1/users/me")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            print("UserProfileMetadataClient: ❌ No access token found")
            throw APIError.unauthorized
        }

        // Build request body using proper DTO
        let requestDTO = UserProfileUpdateRequest(
            name: name,
            preferredUnitSystem: preferredUnitSystem,
            bio: bio,
            languageCode: languageCode
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(requestDTO)

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("UserProfileMetadataClient: Request Body: \(bodyString)")
        }

        // Make PUT request to /users/me
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        if let responseString = String(data: data, encoding: .utf8) {
            print("UserProfileMetadataClient: Response (\(statusCode)): \(responseString)")
        }

        // Handle 404 - profile not created on backend yet
        if statusCode == 404 {
            print("UserProfileMetadataClient: ⚠️  Profile not found (404)")
            print("UserProfileMetadataClient: This shouldn't happen after registration fix")
            throw APIError.apiError(
                statusCode: statusCode, message: "Profile not yet created on backend")
        }

        guard statusCode == 200 else {
            print("UserProfileMetadataClient: ❌ Failed to update profile. Status: \(statusCode)")
            throw APIError.apiError(
                statusCode: statusCode, message: "Failed to update profile metadata")
        }

        // Decode response
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)
            metadata = try successResponse.data.toDomain()
            print("UserProfileMetadataClient: ✅ Successfully updated profile metadata")
        } catch {
            print("UserProfileMetadataClient: Trying direct decode...")
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileMetadataClient: ✅ Successfully updated profile metadata")
        }

        // Get stored profile for email/username/physical
        let storedProfile = try? await userProfileStorage.fetch(forUserID: metadata.userId)
        let email = storedProfile?.email
        let username = storedProfile?.username
        let physical = storedProfile?.physical

        // Compose UserProfile from updated metadata + stored physical
        let profile = UserProfile(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: storedProfile?.hasPerformedInitialHealthKitSync
                ?? false,
            lastSuccessfulDailySyncDate: storedProfile?.lastSuccessfulDailySyncDate
        )

        print("UserProfileMetadataClient: ===== UPDATE COMPLETE =====")
        return profile
    }

    // MARK: - Private Helpers

    /// Creates a configured JSON decoder with date handling
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
