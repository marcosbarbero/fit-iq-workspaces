//
//  ProgressAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Biological Sex and Height Improvements
//

import Foundation
import FitIQCore

/// Infrastructure adapter for progress tracking API operations
///
/// Implements ProgressRepositoryProtocol to communicate with the backend API
/// for logging and retrieving progress metrics (height, weight, etc.)
///
/// **Backend Endpoints:**
/// - POST /api/v1/progress - Log a single metric
/// - GET /api/v1/progress - Get all progress entries with filtering and pagination
///   * Supports type filtering (e.g., ?type=weight)
///   * Supports date range filtering (e.g., ?from=2024-01-01&to=2024-01-31)
///   * Supports pagination (e.g., ?limit=20&offset=0)
///   * Note: /progress/history is DEPRECATED and removed from API
///
/// **Architecture:**
/// - Infrastructure layer (adapter)
/// - Implements ProgressRepositoryProtocol (domain port)
/// - Used by LogHeightProgressUseCase and other progress use cases
final class ProgressAPIClient: ProgressRemoteAPIProtocol {

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

    // MARK: - ProgressRemoteAPIProtocol Implementation

    func logProgress(
        type: ProgressMetricType,
        quantity: Double,
        loggedAt: Date?,
        notes: String?
    ) async throws -> ProgressEntry {
        print("ProgressAPIClient: Logging progress - type: \(type.rawValue), quantity: \(quantity)")

        // Build request body
        // Backend expects logged_at in RFC3339 format
        let loggedAtString = loggedAt?.toISO8601TimestampString()
        print("ProgressAPIClient: Logged at: \(loggedAtString ?? "nil")")

        let requestDTO = ProgressLogRequest(
            type: type.rawValue,
            quantity: quantity,
            loggedAt: loggedAtString,
            notes: notes
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let bodyData = try encoder.encode(requestDTO)

        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("ProgressAPIClient: Request body: \(bodyString)")
        }

        // Make POST request with retry logic
        guard let url = URL(string: "\(baseURL)/api/v1/progress") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = bodyData

        // Get user ID from authManager
        guard let userProfileID = authManager.currentUserProfileID else {
            print("ProgressAPIClient: ❌ No user profile ID found in authManager")
            throw APIError.invalidUserId
        }
        let userIDString = userProfileID.uuidString

        // Execute with token refresh on 401
        let responseDTO: ProgressEntryResponse = try await executeWithRetry(
            request: request, retryCount: 0)
        return try responseDTO.toDomain(userID: userIDString)
    }

    func getCurrentProgress(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry] {
        print("ProgressAPIClient: Fetching current progress (latest values)")
        return try await fetchProgress(
            type: type,
            from: from,
            to: to,
            page: page,
            limit: limit,
            isHistorical: false
        )
    }

    func getProgressHistory(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry] {
        print("ProgressAPIClient: Fetching progress history (all entries)")
        return try await fetchProgress(
            type: type,
            from: from,
            to: to,
            page: page,
            limit: limit,
            isHistorical: true
        )
    }

    /// Internal method to fetch progress entries from the unified /progress endpoint
    ///
    /// The backend /progress endpoint now handles both current and historical queries
    /// through filtering and pagination parameters.
    ///
    /// - Parameters:
    ///   - type: Optional metric type filter
    ///   - from: Optional start date
    ///   - to: Optional end date
    ///   - page: Optional page number (not used, kept for compatibility)
    ///   - limit: Optional page size
    ///   - isHistorical: If true, fetch more results; if false, use smaller default limit
    /// - Returns: Array of progress entries
    private func fetchProgress(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?,
        isHistorical: Bool
    ) async throws -> [ProgressEntry] {
        print("ProgressAPIClient: Type: \(type?.rawValue ?? "all")")
        print(
            "ProgressAPIClient: Date range: \(from?.description ?? "nil") to \(to?.description ?? "nil")"
        )
        print(
            "ProgressAPIClient: Pagination: limit=\(limit?.description ?? "nil"), offset=\(page != nil ? String((page! - 1) * (limit ?? 20)) : "nil")"
        )

        // Build URL with query parameters
        // The /progress endpoint uses offset-based pagination (not page numbers)
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/progress")!
        var queryItems: [URLQueryItem] = []

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        if let from = from {
            queryItems.append(
                URLQueryItem(name: "from", value: from.toISO8601DateString()))
        }
        if let to = to {
            queryItems.append(URLQueryItem(name: "to", value: to.toISO8601DateString()))
        }

        // Convert page to offset if provided, otherwise use 0
        let offset = page != nil ? (page! - 1) * (limit ?? 20) : 0
        queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))

        // Use provided limit, or default based on query type
        let effectiveLimit = limit ?? (isHistorical ? 100 : 20)
        queryItems.append(URLQueryItem(name: "limit", value: "\(effectiveLimit)"))

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Get user ID from authManager
        guard let userProfileID = await authManager.currentUserProfileID else {
            print("ProgressAPIClient: ❌ No user profile ID found in authManager")
            throw APIError.invalidUserId
        }
        let userIDString = userProfileID.uuidString

        // Execute with token refresh on 401 - now returns ProgressListResponse
        let listResponse: ProgressListResponse = try await executeWithRetry(
            request: request, retryCount: 0)

        // Convert DTOs to domain models
        let entries = try listResponse.entries.map { try $0.toDomain(userID: userIDString) }
        print(
            "ProgressAPIClient: ✅ Fetched \(entries.count) of \(listResponse.total) progress entries"
        )
        return entries
    }

    // MARK: - Helper Methods

    /// Returns a configured JSONDecoder for API responses
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Returns a configured JSONEncoder for API requests
    private func configuredEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Executes request with automatic token refresh on 401
    /// This method handles both single object responses and paginated list responses
    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var authenticatedRequest = request

        // Get and set access token
        do {
            guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
                print("ProgressAPIClient: ❌ No access token found in persistence")
                authManager.logout()
                throw APIError.unauthorized
            }

            let tokenPreview =
                accessToken.count > 20
                ? "\(accessToken.prefix(10))...\(accessToken.suffix(10))"
                : "token too short"
            print("ProgressAPIClient: Using access token: \(tokenPreview)")

            authenticatedRequest.setValue(
                "Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } catch {
            print("ProgressAPIClient: Access token not found or invalid. Logging out.")
            authManager.logout()
            throw error
        }

        // Execute request
        let (data, httpResponse) = try await networkClient.executeRequest(
            request: authenticatedRequest)
        let statusCode = httpResponse.statusCode

        print("ProgressAPIClient: Response status code: \(statusCode)")

        // Always log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("ProgressAPIClient: Response body: \(responseString)")
        }

        switch statusCode {
        case 200, 201:
            // Success - decode and return DTO (generic type T)
            let decoder = configuredDecoder()

            // Try to decode as wrapped StandardResponse first, then fallback to direct decode
            do {
                let successResponse = try decoder.decode(
                    StandardResponse<T>.self,
                    from: data
                )
                return successResponse.data
            } catch {
                print(
                    "ProgressAPIClient: Failed to decode wrapped response, trying direct decode...")
                return try decoder.decode(T.self, from: data)
            }

        case 401 where retryCount == 0:
            // Token expired - attempt refresh
            print("ProgressAPIClient: Access token expired. Attempting refresh...")

            guard let savedRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
                print("ProgressAPIClient: No refresh token found. Logging out.")
                authManager.logout()
                throw APIError.unauthorized
            }

            print(
                "ProgressAPIClient: Current refresh token from keychain: \(savedRefreshToken.prefix(8))..."
            )

            // Refresh the token (synchronized - only one refresh at a time)
            let refreshRequest = RefreshTokenRequest(refreshToken: savedRefreshToken)
            let newTokens: LoginResponse = try await refreshAccessToken(request: refreshRequest)

            // Save new tokens
            try authTokenPersistence.save(
                accessToken: newTokens.accessToken, refreshToken: newTokens.refreshToken)

            print("ProgressAPIClient: ✅ New tokens saved to keychain")
            print("ProgressAPIClient: Token refreshed successfully. Retrying original request...")

            // Retry original request with new token
            return try await executeWithRetry(request: request, retryCount: 1)

        case 401 where retryCount > 0:
            // Token refresh failed or second 401
            print("ProgressAPIClient: Token refresh failed or second 401. Logging out.")
            authManager.logout()
            throw APIError.unauthorized

        default:
            // Other error
            throw APIError.apiError(
                statusCode: statusCode,
                message: "Request failed"
            )
        }
    }

    /// Executes request with automatic token refresh on 401 - for array responses
    /// Note: This is kept for backwards compatibility but the new /progress endpoint
    /// returns ProgressListResponse (not arrays) so this method is rarely used now.
    private func executeWithRetryArray<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> [T] {
        var authenticatedRequest = request

        // Get and set access token
        do {
            guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
                print("ProgressAPIClient: ❌ No access token found in persistence")
                authManager.logout()
                throw APIError.unauthorized
            }

            let tokenPreview =
                accessToken.count > 20
                ? "\(accessToken.prefix(10))...\(accessToken.suffix(10))"
                : "token too short"
            print("ProgressAPIClient: Using access token: \(tokenPreview)")

            authenticatedRequest.setValue(
                "Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } catch {
            print("ProgressAPIClient: Access token not found or invalid. Logging out.")
            authManager.logout()
            throw error
        }

        // Execute request
        let (data, httpResponse) = try await networkClient.executeRequest(
            request: authenticatedRequest)
        let statusCode = httpResponse.statusCode

        print("ProgressAPIClient: Response status code: \(statusCode)")

        // Always log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("ProgressAPIClient: Response body: \(responseString)")
        }

        switch statusCode {
        case 200:
            // Success - decode and return array of DTOs
            let decoder = configuredDecoder()
            let responseDTOs: [T]
            do {
                let successResponse = try decoder.decode(
                    StandardResponse<[T]>.self,
                    from: data
                )
                responseDTOs = successResponse.data
            } catch {
                print(
                    "ProgressAPIClient: Failed to decode wrapped response, trying direct decode...")
                responseDTOs = try decoder.decode([T].self, from: data)
            }

            return responseDTOs

        case 401 where retryCount == 0:
            // Token expired - attempt refresh
            print("ProgressAPIClient: Access token expired. Attempting refresh...")

            guard let savedRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
                print("ProgressAPIClient: No refresh token found. Logging out.")
                authManager.logout()
                throw APIError.unauthorized
            }

            print(
                "ProgressAPIClient: Current refresh token from keychain: \(savedRefreshToken.prefix(8))..."
            )

            // Refresh the token (synchronized - only one refresh at a time)
            let refreshRequest = RefreshTokenRequest(refreshToken: savedRefreshToken)
            let newTokens: LoginResponse = try await refreshAccessToken(request: refreshRequest)

            // Save new tokens
            try authTokenPersistence.save(
                accessToken: newTokens.accessToken, refreshToken: newTokens.refreshToken)

            print("ProgressAPIClient: ✅ New tokens saved to keychain")
            print("ProgressAPIClient: Token refreshed successfully. Retrying original request...")

            // Retry original request with new token
            return try await executeWithRetryArray(request: request, retryCount: 1)

        case 401 where retryCount > 0:
            // Token refresh failed or second 401
            print("ProgressAPIClient: Token refresh failed or second 401. Logging out.")
            authManager.logout()
            throw APIError.unauthorized

        default:
            // Other error
            throw APIError.apiError(
                statusCode: statusCode,
                message: "Request failed"
            )
        }
    }

    /// Refreshes the access token using the refresh token with synchronization
    /// Ensures only one refresh happens at a time across all concurrent requests
    private func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
        // Check if a refresh is already in progress
        refreshLock.lock()
        if let existingTask = refreshTask {
            refreshLock.unlock()
            print("ProgressAPIClient: Token refresh already in progress, waiting for result...")
            return try await existingTask.value
        }

        // Mark that we're starting a refresh
        let task = Task<LoginResponse, Error> {
            defer {
                refreshLock.lock()
                self.refreshTask = nil
                self.isRefreshing = false
                refreshLock.unlock()
            }

            guard let url = URL(string: "\(baseURL)/api/v1/auth/refresh") else {
                throw APIError.invalidURL
            }

            var refreshRequest = URLRequest(url: url)
            refreshRequest.httpMethod = "POST"
            refreshRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            refreshRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            refreshRequest.httpBody = try configuredEncoder().encode(request)

            print("ProgressAPIClient: Calling /api/v1/auth/refresh to get new tokens...")
            print(
                "ProgressAPIClient: Refresh token being used: \(request.refreshToken.prefix(8))...")

            let (data, httpResponse) = try await networkClient.executeRequest(
                request: refreshRequest)
            let statusCode = httpResponse.statusCode

            guard statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("ProgressAPIClient: Token refresh failed. Response: \(responseString)")

                    // Check if refresh token is legitimately revoked (not a race condition)
                    if responseString.contains("refresh token has been revoked")
                        || responseString.contains("invalid refresh token")
                        || responseString.contains("refresh token not found")
                    {
                        print(
                            "ProgressAPIClient: ⚠️ Refresh token is invalid/revoked. Logging out user."
                        )
                        await MainActor.run {
                            authManager.logout()
                        }
                    }
                }
                throw APIError.apiError(statusCode: statusCode, message: "Token refresh failed")
            }

            let decoder = configuredDecoder()
            let successResponse = try decoder.decode(
                StandardResponse<LoginResponse>.self, from: data)
            print("ProgressAPIClient: ✅ Token refresh successful. New tokens received.")
            print(
                "ProgressAPIClient: New refresh token: \(successResponse.data.refreshToken.prefix(8))..."
            )
            return successResponse.data
        }

        self.refreshTask = task
        self.isRefreshing = true
        refreshLock.unlock()

        return try await task.value
    }
}
