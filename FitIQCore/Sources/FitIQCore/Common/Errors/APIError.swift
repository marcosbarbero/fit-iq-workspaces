//
//  APIError.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Errors that can occur during API operations
public enum APIError: Error, LocalizedError {
    /// The URL is invalid or malformed
    case invalidURL

    /// The response from the server is invalid
    case invalidResponse

    /// Failed to decode the response data
    case decodingError(Error)

    /// API returned an error with status code and message
    case apiError(statusCode: Int, message: String)

    /// API returned a general error
    case apiErrorGeneral(Error)

    /// User is not authorized (401)
    case unauthorized

    /// Resource not found (404)
    case notFound

    /// Invalid user ID provided
    case invalidUserId

    /// Network connectivity error
    case networkError(Error)

    /// Request timeout
    case timeout

    /// Server error (5xx)
    case serverError(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid or malformed."
        case .invalidResponse:
            return "The server response is invalid."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .apiErrorGeneral(let error):
            return "API error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .notFound:
            return "The requested resource was not found."
        case .invalidUserId:
            return "Invalid user ID provided."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "The request timed out."
        case .serverError(let statusCode):
            return "Server error (\(statusCode)). Please try again later."
        }
    }
}
