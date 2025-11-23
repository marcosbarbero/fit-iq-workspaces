//
//  UserProfileService.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//

import Foundation

/// Protocol for user profile service operations
protocol UserProfileServiceProtocol {
    /// Fetch current user's profile from backend
    /// - Parameter accessToken: JWT access token
    /// - Returns: User profile data
    /// - Throws: Network or decoding errors
    func fetchCurrentUserProfile(accessToken: String) async throws -> UserProfileData
}

/// Service for managing user profile data from backend
final class UserProfileService: UserProfileServiceProtocol {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let baseURL: URL

    // MARK: - Initialization

    init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - API Methods

    /// Fetch current user's profile from /api/v1/users/me
    func fetchCurrentUserProfile(accessToken: String) async throws -> UserProfileData {
        let endpoint = baseURL.appendingPathComponent("/api/v1/users/me")

        print("🔍 [UserProfileService] Fetching user profile from: \(endpoint)")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if configured
        let apiKey = AppConfiguration.shared.apiKey
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UserProfileServiceError.invalidResponse
            }

            print("📊 [UserProfileService] Response status: \(httpResponse.statusCode)")

            // Debug: Log raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 [UserProfileService] Raw response: \(jsonString)")
            }

            guard httpResponse.statusCode == 200 else {
                throw UserProfileServiceError.httpError(statusCode: httpResponse.statusCode)
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let profileResponse = try decoder.decode(UserProfileResponse.self, from: data)

            print(
                "✅ [UserProfileService] Profile fetched successfully for user: \(profileResponse.data.name)"
            )

            return profileResponse.data

        } catch let error as UserProfileServiceError {
            print("❌ [UserProfileService] Error: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ [UserProfileService] Unexpected error: \(error)")
            throw UserProfileServiceError.networkError(error)
        }
    }
}

// MARK: - Errors

enum UserProfileServiceError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case networkError(Error)
    case decodingError(Error)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            switch statusCode {
            case 401:
                return "Authentication failed. Please log in again."
            case 404:
                return "User profile not found"
            case 500...599:
                return "Server error. Please try again later."
            default:
                return "HTTP error: \(statusCode)"
            }
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        }
    }
}

// MARK: - Mock Implementation for Testing

final class MockUserProfileService: UserProfileServiceProtocol {
    var shouldFail = false
    var mockProfile: UserProfileData?

    func fetchCurrentUserProfile(accessToken: String) async throws -> UserProfileData {
        if shouldFail {
            throw UserProfileServiceError.httpError(statusCode: 500)
        }

        return mockProfile
            ?? UserProfileData(
                id: UUID().uuidString,
                email: "test@lume.com",
                profile: ProfileDetails(
                    id: UUID().uuidString,
                    name: "Test User",
                    bio: "Test bio",
                    preferredUnitSystem: "metric",
                    languageCode: "en",
                    dateOfBirth: "1990-05-15"
                )
            )
    }
}
