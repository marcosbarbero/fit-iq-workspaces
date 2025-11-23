//
//  UserProfileAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Infrastructure adapter for user profile API operations
/// Implements UserProfileRepositoryProtocol to communicate with the backend API
final class UserProfileAPIClient: UserProfileRepositoryProtocol {

    // MARK: - Dependencies

    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let physicalProfileRepository: PhysicalProfileRepositoryProtocol

    // MARK: - Initialization

    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        physicalProfileRepository: PhysicalProfileRepositoryProtocol? = nil
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
        self.userProfileStorage = userProfileStorage
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""

        // If no physical profile repository provided, create default
        self.physicalProfileRepository =
            physicalProfileRepository
            ?? PhysicalProfileAPIClient(
                networkClient: networkClient,
                authTokenPersistence: authTokenPersistence
            )
    }

    // MARK: - UserProfileRepositoryProtocol Implementation

    /// Fetches the user profile from the backend using /api/v1/users/me endpoint
    func getUserProfile(userId: String) async throws -> UserProfile {
        print("UserProfileAPIClient: Fetching current user profile from /api/v1/users/me")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            throw APIError.unauthorized
        }

        // Fetch from /users/me endpoint (returns full user data)
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
            print("UserProfileAPIClient: /me Response (\(statusCode)): \(responseString)")
        }

        guard statusCode == 200 else {
            print("UserProfileAPIClient: Failed to fetch user from /me. Status: \(statusCode)")
            throw APIError.apiError(statusCode: statusCode, message: "Failed to fetch user profile")
        }

        // Decode response
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)
            metadata = try successResponse.data.toDomain()
            print("UserProfileAPIClient: Successfully fetched user profile from /me")
        } catch {
            print(
                "UserProfileAPIClient: Failed to decode wrapped response, trying direct decode...")
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileAPIClient: Successfully fetched user profile from /me")
        }

        // Try to get email from stored profile (local state)
        // We need to extract userId from metadata to fetch stored profile
        let storedProfile = try? await userProfileStorage.fetch(forUserID: metadata.userId)
        let email = storedProfile?.email
        let username = storedProfile?.username

        // Fetch physical profile from separate endpoint
        var physical: PhysicalProfile? = nil
        do {
            physical = try await physicalProfileRepository.getPhysicalProfile(userId: userId)
            print("UserProfileAPIClient: Successfully fetched physical profile")
        } catch {
            print(
                "UserProfileAPIClient: Physical profile not available: \(error.localizedDescription)"
            )
            // Physical profile is optional, continue without it
        }

        // Compose UserProfile from metadata + physical
        let profile = UserProfile(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: storedProfile?.hasPerformedInitialHealthKitSync
                ?? false,
            lastSuccessfulDailySyncDate: storedProfile?.lastSuccessfulDailySyncDate
        )

        return profile
    }

    /// Updates the user's profile information using /api/v1/users/me endpoint
    func updateProfile(
        userId: String,
        name: String?,
        dateOfBirth: Date?,
        gender: String?,
        height: Double?,
        weight: Double?,
        activityLevel: String?
    ) async throws -> UserProfile {
        print("UserProfileAPIClient: Updating user profile via /api/v1/users/me")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            throw APIError.unauthorized
        }

        // Build request
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        // Build request body with all fields
        var requestBody: [String: Any?] = [:]

        if let name = name {
            requestBody["name"] = name
        }

        // REQUIRED: preferred_unit_system is required by the API
        // Default to "metric" if not otherwise specified
        requestBody["preferred_unit_system"] = "metric"

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
        if let gender = gender {
            requestBody["gender"] = gender
        }
        if let height = height {
            requestBody["height"] = height
        }
        if let weight = weight {
            requestBody["weight"] = weight
        }
        if let activityLevel = activityLevel {
            requestBody["activity_level"] = activityLevel
        }

        let filteredBody = requestBody.compactMapValues { $0 }
        request.httpBody = try JSONSerialization.data(withJSONObject: filteredBody)

        if let bodyString = String(data: request.httpBody ?? Data(), encoding: .utf8) {
            print("UserProfileAPIClient: Update Request Body: \(bodyString)")
        }

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        if let responseString = String(data: data, encoding: .utf8) {
            print("UserProfileAPIClient: Update Response (\(statusCode)): \(responseString)")
        }

        guard statusCode == 200 else {
            print("UserProfileAPIClient: Failed to update user profile. Status: \(statusCode)")
            throw APIError.apiError(
                statusCode: statusCode, message: "Failed to update user profile")
        }

        // Decode response
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)
            metadata = try successResponse.data.toDomain()
            print("UserProfileAPIClient: Successfully updated user profile")
        } catch {
            print(
                "UserProfileAPIClient: Failed to decode wrapped response, trying direct decode...")
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileAPIClient: Successfully updated user profile")
        }

        // Try to get email from stored profile (local state)
        // We need to extract userId from metadata to fetch stored profile
        let storedProfile = try? await userProfileStorage.fetch(forUserID: metadata.userId)
        let email = storedProfile?.email
        let username = storedProfile?.username

        // Fetch physical profile from separate endpoint
        var physical: PhysicalProfile? = nil
        do {
            physical = try await physicalProfileRepository.getPhysicalProfile(userId: userId)
            print("UserProfileAPIClient: Successfully fetched physical profile after update")
        } catch {
            print(
                "UserProfileAPIClient: Physical profile not available: \(error.localizedDescription)"
            )
            // Physical profile is optional, continue without it
        }

        // Compose UserProfile from metadata + physical
        let profile = UserProfile(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: storedProfile?.hasPerformedInitialHealthKitSync
                ?? false,
            lastSuccessfulDailySyncDate: storedProfile?.lastSuccessfulDailySyncDate
        )

        return profile
    }

    // MARK: - Helper Methods

    /// Updates the user's profile metadata using PUT /api/v1/users/me endpoint
    /// This is the new method that properly aligns with the backend API
    func updateProfileMetadata(
        userId: String,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?
    ) async throws -> UserProfile {
        print("UserProfileAPIClient: Updating profile metadata via /api/v1/users/me")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
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
            print("UserProfileAPIClient: Metadata Update Request Body: \(bodyString)")
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
            print(
                "UserProfileAPIClient: Metadata Update Response (\(statusCode)): \(responseString)")
        }

        // Handle 404 - profile not created on backend yet (expected after registration)
        if statusCode == 404 {
            print(
                "UserProfileAPIClient: Profile not found on backend (404). This is expected for new users."
            )
            print(
                "UserProfileAPIClient: Profile will be created on backend on first sync or when backend implements auto-creation."
            )
            throw APIError.apiError(
                statusCode: statusCode, message: "Profile not yet created on backend")
        }

        guard statusCode == 200 else {
            print("UserProfileAPIClient: Failed to update profile metadata. Status: \(statusCode)")
            throw APIError.apiError(
                statusCode: statusCode, message: "Failed to update profile metadata")
        }

        // Decode response
        // Backend returns: {"data": {"profile": {...}}}
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileDataWrapper>.self, from: data)
            metadata = try successResponse.data.profile.toDomain()
            print("UserProfileAPIClient: Successfully decoded wrapped profile response")
        } catch {
            print(
                "UserProfileAPIClient: Failed to decode with wrapper, trying direct profile decode..."
            )
            // Fallback: try decoding profile directly (for backward compatibility)
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileAPIClient: Successfully decoded direct profile response")
        }

        // Get stored profile for email/username
        let storedProfile = try? await userProfileStorage.fetch(forUserID: metadata.userId)
        let email = storedProfile?.email
        let username = storedProfile?.username

        // Fetch physical profile from separate endpoint
        var physical: PhysicalProfile? = nil
        do {
            physical = try await physicalProfileRepository.getPhysicalProfile(userId: userId)
            print(
                "UserProfileAPIClient: Successfully fetched physical profile after metadata update")
        } catch {
            print(
                "UserProfileAPIClient: Physical profile not available: \(error.localizedDescription)"
            )
        }

        // Compose UserProfile from metadata + physical
        let profile = UserProfile(
            metadata: metadata,
            physical: physical,
            email: email,
            username: username,
            hasPerformedInitialHealthKitSync: storedProfile?.hasPerformedInitialHealthKitSync
                ?? false,
            lastSuccessfulDailySyncDate: storedProfile?.lastSuccessfulDailySyncDate
        )

        return profile
    }

    /// Creates a new user profile on the backend (POST /api/v1/users/me)
    ///
    /// This should be called immediately after registration to create the profile on the backend.
    /// The registration endpoint only creates the auth user, not the profile.
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
        print("UserProfileAPIClient: ===== CREATE PROFILE ON BACKEND =====")
        print("UserProfileAPIClient: Creating profile for user \(userId)")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            print("UserProfileAPIClient: ❌ No access token found")
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
            print("UserProfileAPIClient: Request Body: \(bodyString)")
        }

        // Make POST request to /users/me
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        if let responseString = String(data: data, encoding: .utf8) {
            print("UserProfileAPIClient: Response (\(statusCode)): \(responseString)")
        }

        // Handle different status codes
        if statusCode == 409 {
            // Profile already exists - fetch it instead
            print(
                "UserProfileAPIClient: ℹ️  Profile already exists (409), fetching existing profile")
            return try await getUserProfile(userId: userId)
        }

        guard statusCode == 200 || statusCode == 201 else {
            print("UserProfileAPIClient: ❌ Failed to create profile. Status: \(statusCode)")
            throw APIError.apiError(statusCode: statusCode, message: "Failed to create profile")
        }

        // Decode response
        let decoder = configuredDecoder()
        let metadata: UserProfileMetadata
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)
            metadata = try successResponse.data.toDomain()
            print("UserProfileAPIClient: ✅ Profile created successfully (wrapped response)")
        } catch {
            print("UserProfileAPIClient: Trying direct decode...")
            let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
            metadata = try profileDTO.toDomain()
            print("UserProfileAPIClient: ✅ Profile created successfully (direct response)")
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
            print("UserProfileAPIClient: Created physical profile with DOB: \(dateOfBirth)")
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

        print("UserProfileAPIClient: ===== PROFILE CREATION COMPLETE =====")
        return profile
    }

    /// Creates a configured JSON decoder with date handling
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
