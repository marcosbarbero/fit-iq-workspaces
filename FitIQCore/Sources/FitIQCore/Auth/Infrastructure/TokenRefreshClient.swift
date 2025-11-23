//
//  TokenRefreshClient.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Thread-safe client for refreshing authentication tokens
///
/// This client ensures that only one token refresh operation happens at a time,
/// preventing race conditions when multiple API calls detect expired tokens simultaneously.
///
/// **Features:**
/// - Thread-safe synchronization using NSLock
/// - Automatic deduplication of concurrent refresh requests
/// - Single in-flight refresh task shared across all callers
/// - Proper cleanup after completion or failure
///
/// **Usage:**
/// ```swift
/// let refreshClient = TokenRefreshClient(
///     baseURL: "https://api.example.com",
///     apiKey: "your-api-key",
///     networkClient: URLSessionNetworkClient()
/// )
///
/// // Multiple concurrent calls will share the same refresh operation
/// let tokens = try await refreshClient.refreshToken(refreshToken: "old-refresh-token")
/// ```
///
/// **Thread Safety:** This class is thread-safe and can be called from multiple threads.
@available(iOS 17, macOS 12, *)
public final class TokenRefreshClient {

    // MARK: - Types

    /// Response from token refresh endpoint
    public struct RefreshResponse: Codable, Sendable {
        public let accessToken: String
        public let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }

        public init(accessToken: String, refreshToken: String) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    /// Request body for token refresh
    private struct RefreshRequest: Codable {
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    /// Standard API response wrapper
    private struct StandardResponse<T: Codable>: Codable {
        let success: Bool
        let data: T?
        let error: String?
    }

    /// Error-only response (when data is null)
    private struct ErrorResponse: Codable {
        let success: Bool
        let error: String?
    }

    // MARK: - Properties

    private let baseURL: String
    private let apiKey: String
    private let networkClient: NetworkClientProtocol
    private let refreshPath: String

    // Thread synchronization
    private let refreshLock = NSLock()
    private var refreshTask: Task<RefreshResponse, Error>?

    // MARK: - Initialization

    /// Creates a new TokenRefreshClient
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the API (e.g., "https://api.example.com")
    ///   - apiKey: The API key for authentication
    ///   - networkClient: The network client to use for requests
    ///   - refreshPath: The path for token refresh endpoint (default: "/api/v1/auth/refresh")
    public init(
        baseURL: String,
        apiKey: String,
        networkClient: NetworkClientProtocol,
        refreshPath: String = "/api/v1/auth/refresh"
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.networkClient = networkClient
        self.refreshPath = refreshPath
    }

    // MARK: - Public Methods

    /// Refreshes the access token using the refresh token
    ///
    /// This method is thread-safe. If multiple callers request a refresh simultaneously,
    /// they will all wait for and share the result of a single refresh operation.
    ///
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: New access and refresh tokens
    /// - Throws: Error if refresh fails or network request fails
    public func refreshToken(refreshToken: String) async throws -> RefreshResponse {
        // Check if a refresh is already in progress
        refreshLock.lock()

        if let existingTask = refreshTask {
            // Unlock and wait for existing task
            refreshLock.unlock()
            print("TokenRefreshClient: Token refresh already in progress, waiting for result...")
            return try await existingTask.value
        }

        // Create new refresh task
        let task = Task<RefreshResponse, Error> {
            defer {
                // Clean up after completion
                refreshLock.lock()
                self.refreshTask = nil
                refreshLock.unlock()
            }

            print("TokenRefreshClient: Starting token refresh...")
            print("TokenRefreshClient: Using refresh token: \(String(refreshToken.prefix(8)))...")

            do {
                let response = try await self.performRefresh(refreshToken: refreshToken)
                print("TokenRefreshClient: ✅ Token refresh successful")
                print(
                    "TokenRefreshClient: New refresh token: \(String(response.refreshToken.prefix(8)))..."
                )
                return response
            } catch {
                print("TokenRefreshClient: ❌ Token refresh failed: \(error.localizedDescription)")
                throw error
            }
        }

        self.refreshTask = task
        refreshLock.unlock()

        return try await task.value
    }

    // MARK: - Private Methods

    /// Performs the actual token refresh HTTP request
    ///
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: New tokens from the server
    /// - Throws: Error if request fails
    private func performRefresh(refreshToken: String) async throws -> RefreshResponse {
        // Build URL
        guard let url = URL(string: baseURL + refreshPath) else {
            throw TokenRefreshError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Encode request body
        let requestBody = RefreshRequest(refreshToken: refreshToken)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        // Execute request
        let (data, response) = try await networkClient.executeRequest(request: request)
        let statusCode = response.statusCode

        // Handle response
        guard statusCode == 200 else {
            // Try to decode error message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                let errorMessage = errorResponse.error
            {
                throw TokenRefreshError.apiError(statusCode: statusCode, message: errorMessage)
            } else {
                throw TokenRefreshError.apiError(
                    statusCode: statusCode,
                    message: "Token refresh failed"
                )
            }
        }

        // Decode successful response
        let decoder = JSONDecoder()
        // Note: RefreshResponse has explicit CodingKeys, so no need for keyDecodingStrategy

        let standardResponse = try decoder.decode(
            StandardResponse<RefreshResponse>.self,
            from: data
        )

        guard let responseData = standardResponse.data else {
            throw TokenRefreshError.apiError(
                statusCode: statusCode,
                message: "Response data is missing"
            )
        }

        return responseData
    }
}

// MARK: - Errors

/// Errors that can occur during token refresh
public enum TokenRefreshError: Error, LocalizedError {
    case invalidURL
    case apiError(statusCode: Int, message: String)
    case invalidRefreshToken
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid refresh URL"
        case .apiError(let statusCode, let message):
            return "Token refresh failed (HTTP \(statusCode)): \(message)"
        case .invalidRefreshToken:
            return "Invalid or expired refresh token"
        case .networkError(let error):
            return "Network error during token refresh: \(error.localizedDescription)"
        }
    }
}

// MARK: - Testing Support

#if DEBUG
    @available(iOS 17, macOS 12, *)
    extension TokenRefreshClient {
        /// Creates a mock refresh client for testing
        ///
        /// - Parameters:
        ///   - baseURL: The base URL to use
        ///   - apiKey: The API key to use
        ///   - networkClient: A mock network client
        /// - Returns: A TokenRefreshClient configured for testing
        public static func mock(
            baseURL: String = "https://test.example.com",
            apiKey: String = "test-api-key",
            networkClient: NetworkClientProtocol
        ) -> TokenRefreshClient {
            return TokenRefreshClient(
                baseURL: baseURL,
                apiKey: apiKey,
                networkClient: networkClient
            )
        }
    }
#endif
