//
//  URLSessionNetworkClient.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// A concrete implementation of NetworkClientProtocol using URLSession.
/// This is the default network client for making HTTP requests.
public final class URLSessionNetworkClient: NetworkClientProtocol {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Initialization

    /// Initializes a new URLSessionNetworkClient
    /// - Parameter session: The URLSession to use for requests. Defaults to .shared
    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - NetworkClientProtocol

    /// Executes a network request and returns the response data and HTTP response
    /// - Parameter request: The URLRequest to execute
    /// - Returns: A tuple containing the response data and HTTPURLResponse
    /// - Throws: APIError if the request fails
    public func executeRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Check for common HTTP error status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success range - return data
                return (data, httpResponse)
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            case 500...599:
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            default:
                // Try to decode error message from response
                if let errorMessage = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw APIError.apiError(
                        statusCode: httpResponse.statusCode, message: errorMessage.message)
                } else {
                    throw APIError.apiError(
                        statusCode: httpResponse.statusCode, message: "Unknown error")
                }
            }
        } catch let error as APIError {
            // Re-throw APIError as-is
            throw error
        } catch {
            // Wrap other errors as network errors
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Supporting Types

/// Basic error response structure from the backend
private struct ErrorResponse: Decodable {
    let message: String
}
