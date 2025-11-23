//
//  HTTPClient.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//

import FitIQCore
import Foundation

/// HTTP client for backend API communication
/// Provides standardized request/response handling with error management
final class HTTPClient {

    // MARK: - Properties

    private let baseURL: URL
    private let apiKey: String
    private let networkClient: NetworkClientProtocol

    // MARK: - Initialization

    init(
        baseURL: URL = AppConfiguration.shared.backendBaseURL,
        apiKey: String = AppConfiguration.shared.apiKey,
        networkClient: NetworkClientProtocol = URLSessionNetworkClient()
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.networkClient = networkClient
    }

    // MARK: - Request Methods

    /// Perform a GET request
    func get<T: Decodable>(
        path: String,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        return try await performRequest(request)
    }

    /// Perform a GET request with query parameters
    func get<T: Decodable>(
        path: String,
        queryParams: [String: String],
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> T {
        var url = baseURL.appendingPathComponent(path)

        // Add query parameters
        if !queryParams.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = components?.url ?? url
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        return try await performRequest(request)
    }

    /// Perform a POST request
    func post<T: Encodable, R: Decodable>(
        path: String,
        body: T,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    /// Perform a POST request with no response body expected
    func post<T: Encodable>(
        path: String,
        body: T,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let _: EmptyResponse = try await performRequest(request)
    }

    /// Perform a POST request without a request body
    func post<R: Decodable>(
        path: String,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        return try await performRequest(request)
    }

    /// Perform a PUT request
    func put<T: Encodable, R: Decodable>(
        path: String,
        body: T,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    /// Perform a DELETE request
    func delete(
        path: String,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        let _: EmptyResponse = try await performRequest(request)
    }

    /// Perform a PATCH request
    func patch<T: Encodable, R: Decodable>(
        path: String,
        body: T,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = try JSONEncoder().encode(body)

        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)

        return try await performRequest(request)
    }

    // MARK: - Private Helpers

    private func addCommonHeaders(
        to request: inout URLRequest,
        additionalHeaders: [String: String],
        accessToken: String?
    ) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        // Use FitIQCore's network client
        let (data, httpResponse) = try await networkClient.executeRequest(request: request)

        // Log request and response in debug mode
        #if DEBUG
            logRequest(request, response: httpResponse, data: data)
        #endif

        // Handle successful responses
        if (200...299).contains(httpResponse.statusCode) {
            // Handle empty response for EmptyResponse type
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // Enhanced error logging for debugging
                print("❌ [HTTPClient] Decoding failed for type: \(T.self)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📋 [HTTPClient] Response JSON: \(jsonString)")
                }
                if let decodingError = error as? DecodingError {
                    print("🔍 [HTTPClient] Decoding error details: \(decodingError)")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("🔍 Missing key: \(key.stringValue) at path: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("🔍 Type mismatch for type: \(type) at path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("🔍 Value not found for type: \(type) at path: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("🔍 Data corrupted at path: \(context.codingPath)")
                    @unknown default:
                        print("🔍 Unknown decoding error")
                    }
                }
                throw HTTPError.decodingFailed(error)
            }
        }

        // Handle error responses
        throw try parseError(from: data, statusCode: httpResponse.statusCode)
    }

    private func parseError(from data: Data, statusCode: Int) throws -> HTTPError {
        // Check for 409 conflict with enhanced details FIRST (before generic backend error)
        if statusCode == 409 {
            if let conflictError = try? JSONDecoder().decode(
                ConflictErrorResponse.self, from: data),
                let details = conflictError.error.details,
                let existingId = UUID(uuidString: details.existingConsultationId)
            {
                print("✅ [HTTPClient] Parsed enhanced 409 conflict with existing ID: \(existingId)")
                return .conflictWithDetails(
                    existingId: existingId,
                    persona: details.persona,
                    status: details.status,
                    canContinue: details.canContinue
                )
            }
        }

        // Try to parse backend error response
        if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
            return HTTPError.backendError(
                code: errorResponse.error.code,
                message: errorResponse.error.message,
                statusCode: statusCode
            )
        }

        // Log raw response for server errors to help debug
        if statusCode >= 500 {
            if let responseString = String(data: data, encoding: .utf8) {
                print(
                    "❌ [HTTPClient] Server error \(statusCode) - Response body: \(responseString)")
            }
        }

        // Fallback to generic HTTP errors
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 409:
            // Fallback if enhanced details weren't parsed above
            return .conflict
        case 500...599:
            return .serverError(statusCode)
        default:
            return .unknown(statusCode)
        }
    }

    private func logRequest(_ request: URLRequest, response: HTTPURLResponse, data: Data) {
        print("=== HTTP Request ===")
        print("URL: \(request.url?.absoluteString ?? "unknown")")
        print("Method: \(request.httpMethod ?? "unknown")")
        print("Status: \(response.statusCode)")

        // Log Authorization header (first 30 chars for security)
        if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
            let preview = String(authHeader.prefix(30))
            print("Authorization: \(preview)... (\(authHeader.count) chars)")
        } else {
            print("Authorization: <none>")
        }

        if let body = request.httpBody,
            let bodyString = String(data: body, encoding: .utf8)
        {
            print("Request Body: \(bodyString)")
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("Response: \(responseString)")
        }
        print("===================")
    }
}

// MARK: - Error Types

enum HTTPError: LocalizedError {
    case invalidResponse
    case decodingFailed(Error)
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case conflictWithDetails(existingId: UUID, persona: String, status: String, canContinue: Bool)
    case serverError(Int)
    case unknown(Int)
    case backendError(code: String, message: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized"
        case .forbidden:
            return "Forbidden"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Conflict"
        case .conflictWithDetails(let existingId, _, _, _):
            return "Resource already exists with ID: \(existingId)"
        case .serverError(let code):
            return "Server error (\(code))"
        case .unknown(let code):
            return "Unknown error (\(code))"
        case .backendError(_, let message, _):
            return message
        }
    }

    var isConflict: Bool {
        switch self {
        case .conflict, .conflictWithDetails:
            return true
        default:
            return false
        }
    }

    var existingConsultationId: UUID? {
        if case .conflictWithDetails(let existingId, _, _, _) = self {
            return existingId
        }
        return nil
    }
}

// MARK: - Response Models

private struct EmptyResponse: Decodable {}

private struct BackendErrorResponse: Decodable {
    let error: BackendError

    struct BackendError: Decodable {
        let code: String
        let message: String
    }
}

private struct ConflictErrorResponse: Decodable {
    let success: Bool
    let error: ConflictError

    struct ConflictError: Decodable {
        let code: String
        let message: String
        let details: ConflictDetails?
    }

    struct ConflictDetails: Decodable {
        let existingConsultationId: String
        let persona: String
        let status: String
        let goalId: String?
        let canContinue: Bool

        enum CodingKeys: String, CodingKey {
            case existingConsultationId = "existing_consultation_id"
            case persona
            case status
            case goalId = "goal_id"
            case canContinue = "can_continue"
        }
    }
}
