//
//  NetworkClient+AutoRetry.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Extension providing automatic retry capability with token refresh on 401 errors
///
/// This extension adds intelligent retry logic to network clients, specifically handling
/// authentication failures (HTTP 401) by automatically refreshing tokens and retrying
/// the original request.
///
/// **Features:**
/// - Automatic detection of 401 (Unauthorized) errors
/// - Token refresh using provided refresh client
/// - Single retry attempt (prevents infinite loops)
/// - Thread-safe token updates via callback
/// - Preserves original request parameters
///
/// **Usage:**
/// ```swift
/// let client = URLSessionNetworkClient()
/// let refreshClient = TokenRefreshClient(...)
///
/// var request = URLRequest(url: url)
/// request.setValue("Bearer \(oldToken)", forHTTPHeaderField: "Authorization")
///
/// let (data, response) = try await client.executeWithAutoRetry(
///     request: request,
///     refreshClient: refreshClient,
///     currentRefreshToken: "refresh-token",
///     onTokenRefreshed: { newAccessToken in
///         // Save new token to storage
///     }
/// )
/// ```
extension NetworkClientProtocol {

    /// Executes a request with automatic retry on 401 (Unauthorized) errors
    ///
    /// If the request fails with 401, this method will:
    /// 1. Use the refresh client to obtain new tokens
    /// 2. Call the onTokenRefreshed callback with new access token
    /// 3. Update the Authorization header in the request
    /// 4. Retry the request once
    ///
    /// If the retry also fails with 401, the error is thrown without further attempts.
    ///
    /// - Parameters:
    ///   - request: The original request to execute
    ///   - refreshClient: Client for refreshing tokens
    ///   - currentRefreshToken: The current refresh token to use
    ///   - onTokenRefreshed: Callback invoked with new access token after successful refresh
    /// - Returns: Response data and HTTP response
    /// - Throws: Network errors, token refresh errors, or HTTP errors
    public func executeWithAutoRetry(
        request: URLRequest,
        refreshClient: TokenRefreshClient,
        currentRefreshToken: String,
        onTokenRefreshed: @escaping (String) async throws -> Void
    ) async throws -> (Data, HTTPURLResponse) {
        // First attempt
        do {
            return try await executeRequest(request: request)
        } catch {
            // Check if this is a 401 error
            guard isUnauthorizedError(error) else {
                throw error
            }

            print("NetworkClient: Received 401, attempting token refresh...")

            // Attempt to refresh token
            let refreshResponse = try await refreshClient.refreshToken(
                refreshToken: currentRefreshToken
            )

            // Notify caller of new token (for persistence)
            try await onTokenRefreshed(refreshResponse.accessToken)

            print("NetworkClient: Token refreshed, retrying original request...")

            // Update authorization header with new token
            var retryRequest = request
            retryRequest.setValue(
                "Bearer \(refreshResponse.accessToken)",
                forHTTPHeaderField: "Authorization"
            )

            // Retry the request (only once)
            return try await executeRequest(request: retryRequest)
        }
    }

    /// Executes a request with automatic retry, returning decoded JSON
    ///
    /// This is a convenience wrapper around `executeWithAutoRetry` that automatically
    /// decodes the response data using the provided response type.
    ///
    /// - Parameters:
    ///   - request: The original request to execute
    ///   - responseType: The type to decode the response into
    ///   - refreshClient: Client for refreshing tokens
    ///   - currentRefreshToken: The current refresh token to use
    ///   - onTokenRefreshed: Callback invoked with new access token after successful refresh
    ///   - decoder: JSON decoder to use (default: JSONDecoder with snake_case conversion)
    /// - Returns: Decoded response object
    /// - Throws: Network errors, token refresh errors, decoding errors, or HTTP errors
    public func executeWithAutoRetry<T: Decodable>(
        request: URLRequest,
        responseType: T.Type,
        refreshClient: TokenRefreshClient,
        currentRefreshToken: String,
        onTokenRefreshed: @escaping (String) async throws -> Void,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }()
    ) async throws -> T {
        let (data, _) = try await executeWithAutoRetry(
            request: request,
            refreshClient: refreshClient,
            currentRefreshToken: currentRefreshToken,
            onTokenRefreshed: onTokenRefreshed
        )

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Private Helpers

    /// Checks if an error represents an unauthorized (401) HTTP response
    ///
    /// - Parameter error: The error to check
    /// - Returns: True if error represents HTTP 401, false otherwise
    private func isUnauthorizedError(_ error: Error) -> Bool {
        // Check for NetworkError.unauthorized if it exists
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return true
            default:
                return false
            }
        }

        // Check for URLError with 401 status code
        if let urlError = error as? URLError {
            // URLError doesn't directly expose status code, but we can check description
            return urlError.localizedDescription.contains("401")
        }

        // Check error description for 401
        return error.localizedDescription.contains("401")
            || error.localizedDescription.contains("Unauthorized")
    }
}

// MARK: - Standard Response Wrapper

/// Standard API response wrapper used by FitIQ backend
public struct StandardAPIResponse<T: Codable>: Codable, Sendable where T: Sendable {
    public let success: Bool
    public let data: T?
    public let error: String?

    public init(success: Bool, data: T?, error: String?) {
        self.success = success
        self.data = data
        self.error = error
    }
}

extension NetworkClientProtocol {

    /// Executes a request with auto-retry and standard response unwrapping
    ///
    /// This method combines auto-retry with automatic unwrapping of the standard
    /// FitIQ API response format: `{ "success": true, "data": {...}, "error": null }`
    ///
    /// - Parameters:
    ///   - request: The original request to execute
    ///   - dataType: The type of the data field in the response
    ///   - refreshClient: Client for refreshing tokens
    ///   - currentRefreshToken: The current refresh token to use
    ///   - onTokenRefreshed: Callback invoked with new access token after successful refresh
    ///   - decoder: JSON decoder to use (default: JSONDecoder with snake_case conversion)
    /// - Returns: Unwrapped data from the response
    /// - Throws: Network errors, token refresh errors, decoding errors, or API errors
    public func executeWithAutoRetryAndUnwrap<T: Codable & Sendable>(
        request: URLRequest,
        dataType: T.Type,
        refreshClient: TokenRefreshClient,
        currentRefreshToken: String,
        onTokenRefreshed: @escaping (String) async throws -> Void,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }()
    ) async throws -> T {
        let response: StandardAPIResponse<T> = try await executeWithAutoRetry(
            request: request,
            responseType: StandardAPIResponse<T>.self,
            refreshClient: refreshClient,
            currentRefreshToken: currentRefreshToken,
            onTokenRefreshed: onTokenRefreshed,
            decoder: decoder
        )

        // Check for API-level errors
        if !response.success {
            throw NetworkError.apiError(message: response.error ?? "Unknown API error")
        }

        // Unwrap data
        guard let data = response.data else {
            throw NetworkError.apiError(message: "Response data is missing")
        }

        return data
    }
}

// MARK: - Network Error

/// Errors that can occur during network operations
public enum NetworkError: Error, LocalizedError {
    case unauthorized
    case apiError(message: String)
    case invalidResponse
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized (401)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
