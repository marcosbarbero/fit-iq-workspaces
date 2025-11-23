//
//  SleepAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: API client for sleep tracking endpoints following Hexagonal Architecture
//

import Foundation

/// Protocol defining sleep API operations
protocol SleepAPIClientProtocol {
    /// Post a sleep session to the backend
    /// - Parameter request: The sleep session request with stages
    /// - Returns: The backend response with session ID and calculated metrics
    func postSleepSession(_ request: SleepSessionRequest) async throws -> SleepSessionResponse

    /// Get sleep sessions for a date range
    /// - Parameters:
    ///   - from: Start date (YYYY-MM-DD)
    ///   - to: End date (YYYY-MM-DD)
    /// - Returns: List of sleep sessions with averages
    func getSleepSessions(from: String, to: String) async throws -> SleepSessionsResponse
}

/// Implementation of sleep API client
final class SleepAPIClient: SleepAPIClientProtocol {

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
        baseURL: String,
        apiKey: String,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        authManager: AuthManager
    ) {
        self.networkClient = networkClient
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.authTokenPersistence = authTokenPersistence
        self.authManager = authManager
    }

    // MARK: - API Operations

    func postSleepSession(_ request: SleepSessionRequest) async throws -> SleepSessionResponse {
        let endpoint = "\(baseURL)/api/v1/sleep"

        print("SleepAPIClient: 🌐 POST \(endpoint)")
        print("SleepAPIClient: Posting sleep session to backend")

        guard let url = URL(string: endpoint) else {
            throw SleepAPIError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        urlRequest.httpBody = try encoder.encode(request)

        // Debug: Log request details
        print("SleepAPIClient: Request details:")
        print("  - Method: POST")
        print("  - Endpoint: /api/v1/sleep")
        print("  - Start: \(request.startTime)")
        print("  - End: \(request.endTime)")
        print("  - Stages: \(request.stages?.count ?? 0)")

        if let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8) {
            print("SleepAPIClient: Full request payload:")
            print(bodyString)
        }

        // Execute with retry logic for 401
        return try await executeWithRetry(request: urlRequest, retryCount: 0)
    }

    func getSleepSessions(from: String, to: String) async throws -> SleepSessionsResponse {
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/sleep")!

        print("SleepAPIClient: 🌐 GET \(baseURL)/api/v1/sleep?from=\(from)&to=\(to)")
        print("SleepAPIClient: Fetching sleep sessions from \(from) to \(to)")
        urlComponents.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
        ]

        guard let url = urlComponents.url else {
            throw SleepAPIError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Execute with retry logic for 401
        return try await executeWithRetry(request: urlRequest, retryCount: 0)
    }

    // MARK: - Token Refresh & Retry Logic

    /// Execute request with automatic token refresh on 401
    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var authenticatedRequest = request

        // Get and set access token
        do {
            guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
                print("SleepAPIClient: ❌ No access token found in persistence")
                authManager.logout()
                throw SleepAPIError.invalidResponse
            }

            let tokenPreview =
                accessToken.count > 20
                ? "\(accessToken.prefix(10))...\(accessToken.suffix(10))"
                : "token too short"
            print("SleepAPIClient: Using access token: \(tokenPreview)")

            authenticatedRequest.setValue(
                "Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } catch {
            print("SleepAPIClient: Access token not found or invalid. Logging out.")
            authManager.logout()
            throw error
        }

        // Execute request
        let (data, httpResponse) = try await networkClient.executeRequest(
            request: authenticatedRequest)
        let statusCode = httpResponse.statusCode

        print("SleepAPIClient: Response status code: \(statusCode)")

        // Always log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("SleepAPIClient: Response body: \(responseString)")
        }

        switch statusCode {
        case 200, 201:
            // Success - decode and return
            print("SleepAPIClient: ✅ Request successful (HTTP \(statusCode))")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let apiResponse = try decoder.decode(StandardResponse<T>.self, from: data)

            // Log success details if it's a sleep session response
            if let sleepResponse = apiResponse.data as? SleepSessionResponse {
                print("SleepAPIClient: Sleep session saved successfully")
                print("  - Backend ID: \(sleepResponse.id)")
                print("  - Response success: \(apiResponse)")
            }

            return apiResponse.data

        case 401 where retryCount == 0:
            // Token expired - attempt refresh
            print("SleepAPIClient: Access token expired. Attempting refresh...")

            guard let savedRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
                print("SleepAPIClient: No refresh token found. Logging out.")
                authManager.logout()
                throw SleepAPIError.invalidResponse
            }

            print(
                "SleepAPIClient: Current refresh token from keychain: \(savedRefreshToken.prefix(8))..."
            )

            // Refresh the token (synchronized - only one refresh at a time)
            let refreshRequest = RefreshTokenRequest(refreshToken: savedRefreshToken)
            let newTokens: LoginResponse = try await refreshAccessToken(request: refreshRequest)

            // Save new tokens
            try authTokenPersistence.save(
                accessToken: newTokens.accessToken, refreshToken: newTokens.refreshToken)

            print("SleepAPIClient: ✅ New tokens saved to keychain")
            print("SleepAPIClient: Token refreshed successfully. Retrying original request...")

            // Retry original request with new token
            return try await executeWithRetry(request: request, retryCount: 1)

        case 401 where retryCount > 0:
            // Token refresh failed or second 401
            print("SleepAPIClient: Token refresh failed or second 401. Logging out.")
            authManager.logout()
            throw SleepAPIError.invalidResponse

        case 409:
            // Duplicate session
            throw SleepAPIError.duplicateSession

        case 400:
            // Bad request - log details
            print("SleepAPIClient: ❌ 400 Bad Request")
            if let responseString = String(data: data, encoding: .utf8) {
                print("SleepAPIClient: Error details: \(responseString)")
            }
            throw SleepAPIError.networkError(
                NSError(
                    domain: "SleepAPI", code: 400,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Bad Request - Invalid data sent to server"
                    ])
            )

        default:
            // Other error
            throw SleepAPIError.networkError(
                NSError(domain: "SleepAPI", code: statusCode, userInfo: nil))
        }
    }

    /// Refresh access token with synchronization to prevent race conditions
    private func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
        // Check if a refresh is already in progress
        refreshLock.lock()
        if let existingTask = refreshTask {
            refreshLock.unlock()
            print("SleepAPIClient: Token refresh already in progress, waiting for result...")
            return try await existingTask.value
        }

        // Create new refresh task
        let task = Task<LoginResponse, Error> {
            defer {
                refreshLock.lock()
                self.refreshTask = nil
                self.isRefreshing = false
                refreshLock.unlock()
            }

            print("SleepAPIClient: Starting token refresh...")

            guard let url = URL(string: "\(baseURL)/api/v1/auth/refresh") else {
                throw SleepAPIError.invalidResponse
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            urlRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SleepAPIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                // Refresh token is revoked or expired - log out
                print("SleepAPIClient: ❌ Refresh token revoked or expired (401). Logging out.")
                await MainActor.run {
                    authManager.logout()
                }
                throw SleepAPIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print(
                    "SleepAPIClient: ❌ Token refresh failed with status \(httpResponse.statusCode)")
                throw SleepAPIError.networkError(
                    NSError(domain: "SleepAPI", code: httpResponse.statusCode, userInfo: nil))
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let apiResponse = try decoder.decode(StandardResponse<LoginResponse>.self, from: data)

            print("SleepAPIClient: ✅ Token refresh successful")
            return apiResponse.data
        }

        self.refreshTask = task
        self.isRefreshing = true
        refreshLock.unlock()

        return try await task.value
    }
}

// MARK: - Request/Response Models

/// Request model for posting a sleep session
struct SleepSessionRequest: Codable {
    let startTime: String  // RFC3339
    let endTime: String  // RFC3339
    let source: String?
    let sourceID: String?  // For deduplication
    let stages: [SleepStageRequest]?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case source
        case sourceID = "source_id"
        case stages
        case notes
    }
}

/// Sleep stage in request
struct SleepStageRequest: Codable {
    let stage: String  // "awake", "asleep", "core", "deep", "rem", "in_bed"
    let startTime: String  // RFC3339
    let endTime: String  // RFC3339

    enum CodingKeys: String, CodingKey {
        case stage
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

/// Response model for sleep session creation
struct SleepSessionResponse: Codable {
    let id: String
    let userID: String
    let startTime: String  // RFC3339
    let endTime: String  // RFC3339
    let timeInBedMinutes: Int
    let totalSleepMinutes: Int
    let sleepEfficiencyPercentage: Double
    let awakeMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let deepMinutes: Int
    let source: String
    let sourceID: String?
    let notes: String?
    let createdAt: String  // RFC3339
    let updatedAt: String  // RFC3339

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case timeInBedMinutes = "time_in_bed_minutes"
        case totalSleepMinutes = "total_sleep_minutes"
        case sleepEfficiencyPercentage = "sleep_efficiency_percentage"
        case awakeMinutes = "awake_minutes"
        case remMinutes = "rem_minutes"
        case coreMinutes = "core_minutes"
        case deepMinutes = "deep_minutes"
        case source
        case sourceID = "source_id"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response model for fetching sleep sessions
struct SleepSessionsResponse: Codable {
    let sessions: [SleepSessionResponse]
    let averages: SleepAverages?
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case sessions
        case averages
        case total
        case limit
        case offset
        case hasMore = "has_more"
    }
}

/// Average sleep metrics
struct SleepAverages: Codable {
    let avgTimeInBedMinutes: Int
    let avgTotalSleepMinutes: Int
    let avgSleepEfficiencyPercentage: Double

    enum CodingKeys: String, CodingKey {
        case avgTimeInBedMinutes = "avg_time_in_bed_minutes"
        case avgTotalSleepMinutes = "avg_total_sleep_minutes"
        case avgSleepEfficiencyPercentage = "avg_sleep_efficiency_percentage"
    }
}

// MARK: - Errors

enum SleepAPIError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case duplicateSession

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from sleep API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .duplicateSession:
            return "Duplicate sleep session (409 Conflict)"
        }
    }
}

// MARK: - Domain Model to API Request Conversion

extension SleepSession {
    /// Convert domain model to API request
    func toAPIRequest() -> SleepSessionRequest {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]

        let stageRequests: [SleepStageRequest]? = stages?.map { stage in
            SleepStageRequest(
                stage: stage.stage.rawValue,
                startTime: iso8601Formatter.string(from: stage.startTime),
                endTime: iso8601Formatter.string(from: stage.endTime)
            )
        }

        return SleepSessionRequest(
            startTime: iso8601Formatter.string(from: startTime),
            endTime: iso8601Formatter.string(from: endTime),
            source: source,
            sourceID: sourceID,
            stages: stageRequests,
            notes: notes
        )
    }
}
