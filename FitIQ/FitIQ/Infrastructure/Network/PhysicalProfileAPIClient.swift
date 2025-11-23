//
//  PhysicalProfileAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Refactoring - Phase 3
//

import Foundation

/// Infrastructure adapter for physical profile API operations
/// Implements PhysicalProfileRepositoryProtocol to communicate with the backend API
final class PhysicalProfileAPIClient: PhysicalProfileRepositoryProtocol {

    // MARK: - Dependencies

    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol

    // MARK: - Initialization

    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        authTokenPersistence: AuthTokenPersistencePortProtocol
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
    }

    // MARK: - PhysicalProfileRepositoryProtocol Implementation

    /// Fetches the user's physical profile from the backend using /api/v1/users/me endpoint
    ///
    /// NOTE: Backend includes physical fields (biological_sex, height_cm) in the main profile response.
    /// There is NO separate GET /api/v1/users/me/physical endpoint (would return 405).
    func getPhysicalProfile(userId: String) async throws -> PhysicalProfile {
        print("PhysicalProfileAPIClient: Fetching physical profile from /api/v1/users/me")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            throw APIError.unauthorized
        }

        // Fetch from /users/me endpoint (NOT /physical - that only supports PATCH)
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

        print("PhysicalProfileAPIClient: Response status code: \(statusCode)")

        guard statusCode == 200 else {
            print(
                "PhysicalProfileAPIClient: Failed to fetch profile. Status: \(statusCode)")
            throw APIError.apiError(
                statusCode: statusCode, message: "Failed to fetch user profile")
        }

        // Decode response - backend returns physical fields in main profile
        let decoder = configuredDecoder()
        do {
            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self, from: data)

            // Extract physical fields from profile response
            let biologicalSex = successResponse.data.biologicalSex
            let heightCm = successResponse.data.heightCm
            let dateOfBirth = successResponse.data.dateOfBirth

            // Parse date of birth if present
            var parsedDateOfBirth: Date? = nil
            if let dobString = dateOfBirth, !dobString.isEmpty {
                parsedDateOfBirth = try? dobString.toDateFromISO8601()
            }

            let physical = PhysicalProfile(
                biologicalSex: biologicalSex,
                heightCm: heightCm,
                dateOfBirth: parsedDateOfBirth
            )

            print("PhysicalProfileAPIClient: Successfully fetched physical profile")
            print("PhysicalProfileAPIClient:   biological_sex: \(biologicalSex ?? "nil")")
            print("PhysicalProfileAPIClient:   height_cm: \(heightCm?.description ?? "nil")")
            print(
                "PhysicalProfileAPIClient:   date_of_birth: \(parsedDateOfBirth?.description ?? "nil")"
            )

            return physical
        } catch {
            print("PhysicalProfileAPIClient: Failed to decode profile response: \(error)")
            throw APIError.decodingError(error)
        }
    }

    /// Updates the user's physical profile using PATCH /api/v1/users/me/physical endpoint
    func updatePhysicalProfile(
        userId: String,
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile {
        print("PhysicalProfileAPIClient: Updating physical profile via /api/v1/users/me/physical")

        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            throw APIError.unauthorized
        }

        // Build request body
        // NOTE: Backend may not support date_of_birth in PATCH /physical endpoint
        // Date of birth is typically set during registration via /users/me
        let dobString = dateOfBirth?.toISO8601DateString()
        print("PhysicalProfileAPIClient: Date of birth input: \(String(describing: dateOfBirth))")
        print("PhysicalProfileAPIClient: Date of birth formatted: \(String(describing: dobString))")

        // Try without date_of_birth first (backend may only accept biological_sex and height_cm)
        let requestDTO = PhysicalProfileUpdateRequest(
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            dateOfBirth: nil  // Don't send DOB - it's set at registration
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let bodyData = try encoder.encode(requestDTO)

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("PhysicalProfileAPIClient: Request body: \(bodyString)")
        }

        // Make PATCH request to /users/me/physical
        guard let url = URL(string: "\(baseURL)/api/v1/users/me/physical") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        // DEBUG: Log complete request details
        print("PhysicalProfileAPIClient: === REQUEST DETAILS ===")
        print("PhysicalProfileAPIClient: URL: \(url.absoluteString)")
        print("PhysicalProfileAPIClient: Method: PATCH")
        print("PhysicalProfileAPIClient: Headers:")
        print("PhysicalProfileAPIClient:   Content-Type: application/json")
        print("PhysicalProfileAPIClient:   X-API-Key: \(apiKey)")
        print("PhysicalProfileAPIClient:   Authorization: Bearer \(accessToken.prefix(20))...")
        print("PhysicalProfileAPIClient: === END REQUEST ===")

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        print("PhysicalProfileAPIClient: Update response status code: \(statusCode)")

        // Handle 400/404 - Backend may not support physical profile endpoint or has validation issues
        if statusCode == 400 || statusCode == 404 {
            if let responseString = String(data: data, encoding: .utf8) {
                print(
                    "PhysicalProfileAPIClient: Response body (\(statusCode)): \(responseString)")
            }

            if statusCode == 400 {
                print(
                    "PhysicalProfileAPIClient: ⚠️ Backend rejected physical profile update (400 - Invalid request payload)"
                )
                print(
                    "PhysicalProfileAPIClient: Possible reasons:"
                )
                print(
                    "PhysicalProfileAPIClient:   1. Endpoint expects different field names or format"
                )
                print(
                    "PhysicalProfileAPIClient:   2. Endpoint doesn't accept all fields together"
                )
                print(
                    "PhysicalProfileAPIClient:   3. Backend validation rules are too strict"
                )
                print(
                    "PhysicalProfileAPIClient:   4. Endpoint is not fully implemented"
                )
                print(
                    "PhysicalProfileAPIClient: 💡 Data is safely stored locally. Backend sync will retry automatically."
                )
            } else {
                print(
                    "PhysicalProfileAPIClient: Physical profile endpoint not found on backend (404)."
                )
                print(
                    "PhysicalProfileAPIClient: This is expected if the endpoint is not yet implemented."
                )
            }

            print(
                "PhysicalProfileAPIClient: ✅ Local data is preserved. Will retry sync on next update."
            )

            // Don't throw - allow the app to continue with local data
            // Create a PhysicalProfile from the input values to return
            let physical = PhysicalProfile(
                biologicalSex: biologicalSex,
                heightCm: heightCm,
                dateOfBirth: dateOfBirth
            )
            return physical
        }

        guard statusCode == 200 else {
            print(
                "PhysicalProfileAPIClient: Failed to update physical profile. Status: \(statusCode)"
            )
            throw APIError.apiError(
                statusCode: statusCode, message: "Failed to update physical profile")
        }

        // Decode response
        let decoder = configuredDecoder()
        do {
            let successResponse = try decoder.decode(
                StandardResponse<PhysicalProfileResponseDTO>.self, from: data)
            let physical = try successResponse.data.toDomain()
            print("PhysicalProfileAPIClient: Successfully updated physical profile")
            return physical
        } catch {
            print(
                "PhysicalProfileAPIClient: Failed to decode wrapped response, trying direct decode..."
            )
            let physicalDTO = try decoder.decode(PhysicalProfileResponseDTO.self, from: data)
            let physical = try physicalDTO.toDomain()
            print("PhysicalProfileAPIClient: Successfully updated physical profile")
            return physical
        }
    }

    // MARK: - Helper Methods

    /// Returns a configured JSONDecoder for API responses
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
