// Infrastructure/Network/RemoteHealthDataSyncClient.swift
import Foundation
import FitIQCore

/// Concrete implementation of RemoteHealthDataSyncPort that interacts with the backend REST APIs.
public final class RemoteHealthDataSyncClient: RemoteHealthDataSyncPort {

    private let networkClient: NetworkClientProtocol
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let authManager: AuthManager
    private let baseURL: String

    // MARK: - Token Refresh Synchronization

    private var isRefreshing = false
    private var refreshTask: Task<LoginResponse, Error>?
    private let refreshLock = NSLock()

    init(
        networkClient: NetworkClientProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol, authManager: AuthManager
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
        self.authManager = authManager
        // Assuming ConfigurationProperties is available to fetch base URL
        self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
    }

    // MARK: - RemoteHealthDataSyncPort Conformance

    public func uploadBodyMass(kg: Double, date: Date, for userProfileID: UUID, localID: UUID?)
        async throws -> String?
    {
        print(
            "RemoteHealthDataSyncClient: Attempting to upload body mass for user \(userProfileID) with \(kg)kg on \(date)"
        )

        let requestDTO = CreateBodyMetricRequest(
            recordedAt: date,
            metrics: [MetricInput(type: .bodyMass, value: kg, unit: .kg)]
        )

        do {
            let path = "/api/v1/profile/metrics"
            let response: BodyMetricResponse = try await performAuthenticatedRequest(
                path: path,
                httpMethod: "POST",
                body: requestDTO
            )
            print(
                "RemoteHealthDataSyncClient: Successfully uploaded body mass. Backend ID: \(response.id)"
            )
            return response.id.uuidString
        } catch {
            print(
                "RemoteHealthDataSyncClient: Failed to upload body mass for user \(userProfileID) with local ID \(localID?.uuidString ?? "N/A"). Error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func uploadHeight(cm: Double, date: Date, for userProfileID: UUID, localID: UUID?)
        async throws -> String?
    {
        print(
            "RemoteHealthDataSyncClient: Attempting to upload height for user \(userProfileID) with \(cm)cm on \(date)"
        )

        let requestDTO = CreateBodyMetricRequest(
            recordedAt: date,
            metrics: [MetricInput(type: .height, value: cm, unit: .cm)]  // Corrected: Using string literal for type
        )

        do {
            let path = "/api/v1/profile/metrics"
            let response: BodyMetricResponse = try await performAuthenticatedRequest(
                path: path,
                httpMethod: "POST",
                body: requestDTO
            )
            print(
                "RemoteHealthDataSyncClient: Successfully uploaded height. Backend ID: \(response.id)"
            )
            return response.id.uuidString
        } catch {
            print(
                "RemoteHealthDataSyncClient: Failed to upload height for user \(userProfileID) with local ID \(localID?.uuidString ?? "N/A"). Error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    // NEW: Implementation for uploadBodyFatPercentage
    public func uploadBodyFatPercentage(
        percentage: Double, date: Date, for userProfileID: UUID, localID: UUID?
    ) async throws -> String? {
        print(
            "RemoteHealthDataSyncClient: Attempting to upload body fat percentage for user \(userProfileID) with \(percentage)% on \(date)"
        )

        let requestDTO = CreateBodyMetricRequest(
            recordedAt: date,
            metrics: [MetricInput(type: .bodyFatPercentage, value: percentage, unit: .percent)]
        )

        do {
            let path = "/api/v1/profile/metrics"
            let response: BodyMetricResponse = try await performAuthenticatedRequest(
                path: path,
                httpMethod: "POST",
                body: requestDTO
            )
            print(
                "RemoteHealthDataSyncClient: Successfully uploaded body fat percentage. Backend ID: \(response.id)"
            )
            return response.id.uuidString
        } catch {
            print(
                "RemoteHealthDataSyncClient: Failed to upload body fat percentage for user \(userProfileID) with local ID \(localID?.uuidString ?? "N/A"). Error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    // NEW: Implementation for uploadBMI
    public func uploadBMI(bmi: Double, date: Date, for userProfileID: UUID, localID: UUID?)
        async throws -> String?
    {
        print(
            "RemoteHealthDataSyncClient: Attempting to upload BMI for user \(userProfileID) with \(bmi) on \(date)"
        )

        let requestDTO = CreateBodyMetricRequest(
            recordedAt: date,
            metrics: [MetricInput(type: .bmi, value: bmi, unit: .percent)]  // Corrected: Using string literal for type
        )

        do {
            let path = "/api/v1/profile/metrics"
            let response: BodyMetricResponse = try await performAuthenticatedRequest(
                path: path,
                httpMethod: "POST",
                body: requestDTO
            )
            print(
                "RemoteHealthDataSyncClient: Successfully uploaded BMI. Backend ID: \(response.id)")
            return response.id.uuidString
        } catch {
            print(
                "RemoteHealthDataSyncClient: Failed to upload BMI for user \(userProfileID) with local ID \(localID?.uuidString ?? "N/A"). Error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    public func uploadActivitySnapshot(snapshot: ActivitySnapshot, for userProfileID: UUID)
        async throws -> String?
    {
        print(
            "RemoteHealthDataSyncClient: Cannot upload activity snapshot. Backend API endpoint for activity snapshot is currently undefined."
        )
        throw APIError.apiError(
            statusCode: 501, message: "Activity snapshot upload API not defined.")
    }

    // MARK: - Helper for Authenticated Requests (Adapted from UserAuthAPIClient)

    private func getAccessToken() throws -> String {
        guard let token = try authTokenPersistence.fetchAccessToken(), !token.isEmpty else {
            throw APIError.unauthorized
        }
        return token
    }

    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func configuredEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func fetchBodyMetrics(
        forUserID userID: UUID,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [BodyMetricResponse] {
        print("RemoteHealthDataSyncClient: Attempting to fetch body metrics for user \(userID)")

        let path = "/api/v1/profile/metrics"
        var components = URLComponents(string: baseURL + path)

        var queryItems: [URLQueryItem] = []
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let startDate = startDate {
            queryItems.append(
                URLQueryItem(name: "start_date", value: dateFormatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(
                URLQueryItem(name: "end_date", value: dateFormatter.string(from: endDate)))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        do {
            let response: [BodyMetricResponse] = try await performAuthenticatedRequest(
                url: url,
                httpMethod: "GET"
            )
            print(
                "RemoteHealthDataSyncClient: Successfully fetched \(response.count) body metrics.")
            return response
        } catch {
            print(
                "RemoteHealthDataSyncClient: Failed to fetch body metrics for user \(userID). Error: \(error.localizedDescription)"
            )
            throw error
        }
    }

    private func performAuthenticatedRequest<T: Decodable, E: Encodable>(
        path: String,
        httpMethod: String,
        body: E? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        return try await performAuthenticatedRequest(url: url, httpMethod: httpMethod, body: body)
    }

    private func performAuthenticatedRequest<T: Decodable>(
        url: URL,
        httpMethod: String,
        body: Encodable? = nil
    ) async throws -> T {
        var initialRequest = URLRequest(url: url)
        initialRequest.httpMethod = httpMethod
        initialRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            let encodedData = try configuredEncoder().encode(body)
            initialRequest.httpBody = encodedData

            // 2. Convert Data to String and print to console
            if let jsonString = String(data: encodedData, encoding: .utf8) {
                print("--- Request Body JSON ---")
                print(jsonString)
                print("-------------------------")
            }
        }

        return try await executeWithRetry(originalRequest: initialRequest, retryCount: 0)
    }

    private func executeWithRetry<T: Decodable>(
        originalRequest: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var request = originalRequest
        do {
            let token = try getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            print("RemoteHealthDataSyncClient: Access token not found or invalid. Logging out.")
            authManager.logout()
            throw error
        }

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200...299:
            let successResponse = try configuredDecoder().decode(
                StandardResponse<T>.self, from: data)
            return successResponse.data

        case 401 where retryCount == 0:
            print("RemoteHealthDataSyncClient: Access token expired. Attempting refresh...")

            guard let savedRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
                print("RemoteHealthDataSyncClient: No refresh token found. Logging out.")
                authManager.logout()
                throw APIError.unauthorized
            }

            print(
                "RemoteHealthDataSyncClient: Current refresh token from keychain: \(savedRefreshToken.prefix(8))..."
            )

            // 6. RETRY ORIGINAL REQUEST (Increment retryCount) - synchronized refresh
            let refreshRequest = RefreshTokenRequest(refreshToken: savedRefreshToken)
            let newTokens = try await self.refreshAccessToken(request: refreshRequest)

            try authTokenPersistence.save(
                accessToken: newTokens.accessToken, refreshToken: newTokens.refreshToken)

            print("RemoteHealthDataSyncClient: Token refreshed, retrying original request.")
            return try await executeWithRetry(originalRequest: originalRequest, retryCount: 1)

        case 401 where retryCount > 0:
            print("RemoteHealthDataSyncClient: Token refresh failed or second 401. Logging out.")
            authManager.logout()
            throw APIError.unauthorized

        case 400:
            let validationError = try configuredDecoder().decode(
                ValidationErrorResponse.self, from: data)
            print(
                "RemoteHealthDataSyncClient: Validation Error: \(validationError.message ?? "N/A")")
            throw APIError.apiError(validationError)

        case 402...499:
            let apiError = try configuredDecoder().decode(ErrorResponse.self, from: data)
            print("RemoteHealthDataSyncClient: Client API Error: \(apiError.message)")
            throw APIError.apiError(apiError)

        case 500...599:
            let apiError = try configuredDecoder().decode(ErrorResponse.self, from: data)
            print("RemoteHealthDataSyncClient: Server API Error: \(apiError.message)")
            throw APIError.apiError(apiError)

        default:
            print("RemoteHealthDataSyncClient: Unexpected Status Code \(statusCode)")
            throw APIError.apiError(ErrorResponse(message: "Unexpected Status Code \(statusCode)"))
        }
    }

    private func executeAPIRequest<T: Decodable, E: Encodable>(
        path: String,
        httpMethod: String,
        body: E
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try configuredEncoder().encode(body)

        print(
            "RemoteHealthDataSyncClient: Making UNauthenticated API request to \(path) with method \(httpMethod)."
        )

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        print(
            "RemoteHealthDataSyncClient: Received response for \(path) with status code \(statusCode)."
        )

        let decoder = configuredDecoder()

        switch statusCode {
        case 200, 201:
            // Success: Decode the wrapped response (StandardResponse<T>)
            let successResponse = try decoder.decode(StandardResponse<T>.self, from: data)
            return successResponse.data

        case 400:  // Validation failed
            let validationError = try decoder.decode(ValidationErrorResponse.self, from: data)
            print(
                "RemoteHealthDataSyncClient: Validation Error for \(path): \(validationError.message ?? "N/A")"
            )
            throw APIError.apiError(validationError)

        case 401, 409, 500...599:
            let apiError = try decoder.decode(ErrorResponse.self, from: data)
            print("RemoteHealthDataSyncClient: API Error for \(path): \(apiError.message)")
            throw APIError.apiError(apiError)

        default:
            print("RemoteHealthDataSyncClient: Unexpected Status Code \(statusCode) for \(path).")
            throw APIError.apiError(ErrorResponse(message: "Unexpected Status Code \(statusCode)"))
        }
    }

    private func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
        // Check if a refresh is already in progress
        refreshLock.lock()
        if let existingTask = refreshTask {
            refreshLock.unlock()
            print(
                "RemoteHealthDataSyncClient: Token refresh already in progress, waiting for result..."
            )
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

            print("RemoteHealthDataSyncClient: Calling /api/v1/auth/refresh to get new tokens...")
            print(
                "RemoteHealthDataSyncClient: Refresh token being used: \(request.refreshToken.prefix(8))..."
            )

            do {
                let response: LoginResponse = try await executeAPIRequest(
                    path: "/api/v1/auth/refresh",
                    httpMethod: "POST",
                    body: request
                )

                print(
                    "RemoteHealthDataSyncClient: ✅ Token refresh successful. New tokens received.")
                print(
                    "RemoteHealthDataSyncClient: New refresh token: \(response.refreshToken.prefix(8))..."
                )

                return response
            } catch let error as APIError { // Catch the error specifically as APIError
                if case let message = error.localizedDescription { // Pattern match the .apiError case
                    // Check if refresh token is legitimately revoked (not a race condition)
                    if message.contains("refresh token has been revoked")
                        || message.contains("invalid refresh token")
                        || message.contains("refresh token not found")
                    {
                        print(
                            "RemoteHealthDataSyncClient: ⚠️ Refresh token is invalid/revoked. Logging out user."
                        )
                        await MainActor.run {
                            authManager.logout()
                        }
                    }
                    // Re-throw the original APIError that was caught
                    throw error
                } else {
                    // If it's an APIError, but not the specific .apiError(statusCode, message) case,
                    // re-throw it to be handled by an outer catch block or default error handler.
                    throw error
                }
            } catch { // Catch any other type of error
                throw error
            }
        }

        self.refreshTask = task
        self.isRefreshing = true
        refreshLock.unlock()

        return try await task.value
    }
}
