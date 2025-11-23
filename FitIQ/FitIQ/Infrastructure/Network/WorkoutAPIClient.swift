//
//  WorkoutAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Protocol defining workout API operations
protocol WorkoutAPIClientProtocol {
    /// Creates a workout on the backend
    /// - Parameter request: The workout data to send
    /// - Returns: The created workout response with backend ID
    func createWorkout(request: CreateWorkoutRequest) async throws -> WorkoutResponse
}

/// Infrastructure adapter for workout API operations
///
/// Communicates with the backend API for creating and managing workouts
///
/// **Backend Endpoints:**
/// - POST /api/v1/workouts - Create a new workout
///
/// **Architecture:**
/// - Infrastructure layer (adapter)
/// - Used by OutboxProcessorService for syncing workouts
final class WorkoutAPIClient: WorkoutAPIClientProtocol {

    // MARK: - Dependencies

    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let authManager: AuthManager

    // MARK: - Token Refresh Synchronization

    private var isRefreshing = false
    private var refreshTask: Task<LoginResponse, Error>?
    private let refreshLock = NSLock()

    // MARK: - Initialization

    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        authManager: AuthManager
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
        self.authManager = authManager
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
    }

    // MARK: - WorkoutAPIClientProtocol Implementation

    func createWorkout(request: CreateWorkoutRequest) async throws -> WorkoutResponse {
        print(
            "WorkoutAPIClient: Creating workout - type: \(request.activityType.rawValue), started: \(request.startedAt)"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let bodyData = try encoder.encode(request)

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("WorkoutAPIClient: Request body: \(bodyString)")
        }

        // Make POST request with retry logic
        guard let url = URL(string: "\(baseURL)/api/v1/workouts") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = bodyData

        // Execute with token refresh on 401
        let responseDTO: WorkoutResponse = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print("WorkoutAPIClient: ✅ Successfully created workout with backend ID: \(responseDTO.id)")
        return responseDTO
    }

    // MARK: - Private Helper Methods

    /// Executes a request with automatic token refresh on 401
    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        // Get auth token
        guard let token = try? authTokenPersistence.fetchAccessToken() else {
            print("WorkoutAPIClient: ❌ No auth token available")
            throw APIError.unauthorized
        }

        // Add auth header
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            // Execute request using networkClient
            let (data, httpResponse) = try await networkClient.executeRequest(
                request: authenticatedRequest)
            let statusCode = httpResponse.statusCode

            // Handle response based on status code
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            switch statusCode {
            case 200, 201:
                // Try to decode wrapped response first, fallback to direct decode
                do {
                    let successResponse = try decoder.decode(StandardResponse<T>.self, from: data)
                    return successResponse.data
                } catch {
                    return try decoder.decode(T.self, from: data)
                }
            case 401:
                throw APIError.unauthorized
            default:
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    throw APIError.apiError(statusCode: statusCode, message: errorResponse.message)
                }
                throw APIError.invalidResponse
            }

        } catch let error as NSError
            where error.code == 401 || error.localizedDescription.contains("401")
        {
            // Handle 401 - try token refresh
            print(
                "WorkoutAPIClient: 🔄 Received 401, attempting token refresh (retry \(retryCount + 1)/2)"
            )

            if retryCount >= 1 {
                print("WorkoutAPIClient: ❌ Token refresh failed after retries")
                throw APIError.unauthorized
            }

            // Attempt token refresh
            do {
                try await refreshTokenIfNeeded()

                // Retry request with new token
                return try await executeWithRetry(
                    request: request,
                    retryCount: retryCount + 1
                )
            } catch {
                print("WorkoutAPIClient: ❌ Token refresh failed: \(error.localizedDescription)")
                throw APIError.unauthorized
            }
        }
    }

    /// Refreshes the auth token if needed (with synchronization)
    private func refreshTokenIfNeeded() async throws {
        // Use lock to ensure only one refresh happens at a time
        refreshLock.lock()

        if isRefreshing {
            refreshLock.unlock()
            // Wait for existing refresh to complete
            if let task = refreshTask {
                _ = try await task.value
            }
            return
        }

        isRefreshing = true
        refreshLock.unlock()

        defer {
            refreshLock.lock()
            isRefreshing = false
            refreshTask = nil
            refreshLock.unlock()
        }

        print("WorkoutAPIClient: 🔄 Refreshing auth token...")

        // Create refresh task
        let task = Task<LoginResponse, Error> {
            guard let refreshToken = try? authTokenPersistence.fetchRefreshToken() else {
                throw APIError.unauthorized
            }

            guard let url = URL(string: "\(baseURL)/api/v1/auth/refresh") else {
                throw APIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

            let (data, httpResponse) = try await networkClient.executeRequest(request: request)

            guard httpResponse.statusCode == 200 else {
                throw APIError.unauthorized
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let successResponse = try decoder.decode(
                StandardResponse<LoginResponse>.self, from: data)
            let loginData = successResponse.data

            // Update stored tokens using the correct method
            try authTokenPersistence.save(
                accessToken: loginData.accessToken, refreshToken: loginData.refreshToken)

            print("WorkoutAPIClient: ✅ Token refreshed successfully")
            return loginData
        }

        refreshTask = task
        _ = try await task.value
    }
}
