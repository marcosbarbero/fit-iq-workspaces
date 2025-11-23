//
//  NutritionAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Network client for Meal Logs API following Hexagonal Architecture
//

import Foundation
import FitIQCore

/// Network client for meal logging API communication
/// Implements MealLogRemoteAPIProtocol for backend synchronization
final class NutritionAPIClient: MealLogRemoteAPIProtocol {

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

    // MARK: - MealLogRemoteAPIProtocol Implementation

    func submitMealLog(
        rawInput: String,
        mealType: String,
        loggedAt: Date,
        notes: String?
    ) async throws -> MealLog {
        print("NutritionAPIClient: Submitting meal log via natural language")
        print("NutritionAPIClient: Raw input: '\(rawInput)'")
        print("NutritionAPIClient: Meal type: \(mealType)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/natural"

        guard let url = URL(string: endpoint) else {
            throw NutritionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let requestBody: [String: Any] = [
            "raw_input": rawInput,
            "meal_type": mealType,
            "logged_at": ISO8601DateFormatter().string(from: loggedAt),
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("NutritionAPIClient: POST \(endpoint)")

        // Execute with retry logic for 401
        // The API returns wrapped response: {"data": {...}, "success": true, "error": null}
        let wrapper: APIDataWrapper<MealLogAPIResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        print("NutritionAPIClient: ✅ Meal log submitted successfully - ID: \(wrapper.data.id)")
        print("NutritionAPIClient: Status: \(wrapper.data.status)")

        return wrapper.data.toDomain()
    }

    func getMealLogs(
        status: MealLogStatus?,
        mealType: String?,
        startDate: Date?,
        endDate: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [MealLog] {
        print("NutritionAPIClient: Fetching meal logs")

        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/meal-logs")!

        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        if let mealType = mealType {
            queryItems.append(URLQueryItem(name: "meal_type", value: mealType))
        }

        if let startDate = startDate {
            queryItems.append(
                URLQueryItem(name: "from", value: ISO8601DateFormatter().string(from: startDate)))
        }

        if let endDate = endDate {
            queryItems.append(
                URLQueryItem(name: "to", value: ISO8601DateFormatter().string(from: endDate)))
        }

        if let page = page {
            queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
        }

        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents.url else {
            throw NutritionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        print("NutritionAPIClient: GET \(url)")

        let wrapper: APIDataWrapper<MealLogListAPIResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        print("NutritionAPIClient: Fetched \(wrapper.data.entries.count) meal logs")

        return wrapper.data.entries
    }

    func getMealLogByID(_ id: String) async throws -> MealLog {
        print("NutritionAPIClient: Fetching meal log by ID \(id)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/\(id)"

        guard let url = URL(string: endpoint) else {
            throw NutritionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        print("NutritionAPIClient: GET \(endpoint)")

        let wrappedResponse: APIDataWrapper<MealLogAPIResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        let response = wrappedResponse.data

        print("NutritionAPIClient: Fetched meal log \(response.id), status: \(response.status)")

        return response.toDomain()
    }

    func deleteMealLog(backendID: String) async throws {
        print("NutritionAPIClient: Deleting meal log \(backendID)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/\(backendID)"

        guard let url = URL(string: endpoint) else {
            throw NutritionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        print("NutritionAPIClient: DELETE \(endpoint)")

        // Execute with retry (handles 401 token refresh)
        try await executeDeleteWithRetry(request: urlRequest, retryCount: 0)

        print("NutritionAPIClient: ✅ Meal log deleted successfully")
    }

    // MARK: - Private Helper for DELETE (no response body)

    private func executeDeleteWithRetry(
        request: URLRequest,
        retryCount: Int
    ) async throws {
        var urlRequest = request

        // Add authorization header with current token
        if let token = try? authTokenPersistence.fetchAccessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await networkClient.executeRequest(request: urlRequest)

        // Check for 401 Unauthorized
        if response.statusCode == 401 {
            print("NutritionAPIClient: ⚠️ Received 401 Unauthorized")

            // Only retry once to avoid infinite loops
            if retryCount < 1 {
                print("NutritionAPIClient: 🔄 Attempting token refresh...")

                // Refresh the token
                try await refreshAccessToken()

                // Retry the request with new token
                print("NutritionAPIClient: 🔄 Retrying request with refreshed token...")
                return try await executeDeleteWithRetry(
                    request: request, retryCount: retryCount + 1)
            } else {
                print(
                    "NutritionAPIClient: ❌ Max retries reached, token refresh failed or unauthorized"
                )
                throw NutritionAPIError.unauthorized
            }
        }

        // Check response status codes
        if response.statusCode == 204 {
            // Success - no content
            return
        } else if response.statusCode == 404 {
            throw NutritionAPIError.notFound
        } else if response.statusCode == 403 {
            throw NutritionAPIError.forbidden
        } else if !(200...299).contains(response.statusCode) {
            throw NutritionAPIError.serverError(
                statusCode: response.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
    }

    // MARK: - Private Helpers

    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var urlRequest = request

        // Add authorization header with current token
        if let token = try? authTokenPersistence.fetchAccessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await networkClient.executeRequest(request: urlRequest)

            // Check for 401 Unauthorized
            if response.statusCode == 401 {
                print("NutritionAPIClient: ⚠️ Received 401 Unauthorized")

                // Only retry once to avoid infinite loops
                if retryCount < 1 {
                    print("NutritionAPIClient: 🔄 Attempting token refresh...")

                    // Refresh the token
                    try await refreshAccessToken()

                    // Retry the request with new token
                    print("NutritionAPIClient: 🔄 Retrying request with refreshed token...")
                    return try await executeWithRetry(request: request, retryCount: retryCount + 1)
                } else {
                    print(
                        "NutritionAPIClient: ❌ Max retries reached, token refresh failed or unauthorized"
                    )
                    throw NutritionAPIError.unauthorized
                }
            }

            // Check for other error status codes
            guard (200...299).contains(response.statusCode) else {
                throw NutritionAPIError.serverError(
                    statusCode: response.statusCode,
                    message: String(data: data, encoding: .utf8) ?? "Unknown error"
                )
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let decodedResponse = try decoder.decode(T.self, from: data)
                return decodedResponse
            } catch {
                print("NutritionAPIClient: ❌ JSON decode error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("NutritionAPIClient: Response body: \(responseString)")
                }
                throw NutritionAPIError.parsingError
            }

        } catch let error as NutritionAPIError {
            throw error
        } catch {
            print("NutritionAPIClient: ❌ Network error: \(error)")
            throw NutritionAPIError.networkError(error)
        }
    }

    private func refreshAccessToken() async throws {
        refreshLock.lock()
        defer { refreshLock.unlock() }

        // If already refreshing, wait for the existing task
        if isRefreshing, let task = refreshTask {
            _ = try await task.value
            return
        }

        // Start refresh
        isRefreshing = true

        let task = Task<LoginResponse, Error> {
            defer {
                refreshLock.lock()
                isRefreshing = false
                refreshTask = nil
                refreshLock.unlock()
            }

            guard let refreshToken = try? authTokenPersistence.fetchRefreshToken() else {
                throw NutritionAPIError.unauthorized
            }

            let endpoint = "\(baseURL)/api/v1/auth/refresh"
            guard let url = URL(string: endpoint) else {
                throw NutritionAPIError.invalidRequest
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

            let requestBody: [String: Any] = ["refresh_token": refreshToken]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await networkClient.executeRequest(request: urlRequest)

            guard (200...299).contains(response.statusCode) else {
                throw NutritionAPIError.unauthorized
            }

            let decoder = JSONDecoder()
            let loginResponse = try decoder.decode(LoginResponse.self, from: data)

            // Update tokens
            try authTokenPersistence.save(
                accessToken: loginResponse.accessToken,
                refreshToken: loginResponse.refreshToken
            )

            print("NutritionAPIClient: ✅ Token refreshed successfully")

            return loginResponse
        }

        refreshTask = task
        _ = try await task.value
    }
}

// MARK: - Response DTOs

struct MealLogAPIResponse: Codable {
    let id: String
    let userId: String
    let rawInput: String
    let mealType: String
    let status: String
    let loggedAt: String
    let items: [MealLogItemDTO]?
    let notes: String?
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let totalFiberG: Double?
    let totalSugarG: Double?
    let processingStartedAt: String?
    let processingCompletedAt: String?
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rawInput = "raw_input"
        case mealType = "meal_type"
        case status
        case loggedAt = "logged_at"
        case items
        case notes
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"
        case totalSugarG = "total_sugar_g"
        case processingStartedAt = "processing_started_at"
        case processingCompletedAt = "processing_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toDomain() -> MealLog {
        let dateFormatter = ISO8601DateFormatter()

        let mealLogStatus = MealLogStatus(rawValue: status) ?? .pending
        let domainMealType = MealType(rawValue: mealType.lowercased()) ?? .other
        let loggedAtDate = dateFormatter.date(from: loggedAt) ?? Date()
        let createdAtDate = dateFormatter.date(from: createdAt) ?? Date()
        let updatedAtDate = updatedAt != nil ? dateFormatter.date(from: updatedAt!) : nil
        let processingStartedAtDate =
            processingStartedAt != nil ? dateFormatter.date(from: processingStartedAt!) : nil
        let processingCompletedAtDate =
            processingCompletedAt != nil ? dateFormatter.date(from: processingCompletedAt!) : nil

        let domainItems = items?.map { $0.toDomain() } ?? []

        return MealLog(
            id: UUID(uuidString: id) ?? UUID(),  // Backend returns string ID
            userID: userId,
            rawInput: rawInput,
            mealType: domainMealType,
            status: mealLogStatus,
            loggedAt: loggedAtDate,
            items: domainItems,
            notes: notes,
            totalCalories: totalCalories,
            totalProteinG: totalProteinG,
            totalCarbsG: totalCarbsG,
            totalFatG: totalFatG,
            totalFiberG: totalFiberG,
            totalSugarG: totalSugarG,
            processingStartedAt: processingStartedAtDate,
            processingCompletedAt: processingCompletedAtDate,
            createdAt: createdAtDate,
            updatedAt: updatedAtDate,
            backendID: id,
            syncStatus: .synced,
            errorMessage: status == "failed" ? "Processing failed" : nil
        )
    }
}

struct MealLogItemDTO: Codable {
    let id: String
    let mealLogId: String
    let foodName: String
    let quantity: Double
    let unit: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let foodType: String?  // Food type classification: "food", "drink", "water"
    let confidenceScore: Double?
    let parsingNotes: String?
    let orderIndex: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case mealLogId = "meal_log_id"
        case foodName = "food_name"
        case quantity
        case unit
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case foodType = "food_type"
        case confidenceScore = "confidence_score"
        case parsingNotes = "parsing_notes"
        case orderIndex = "order_index"
        case createdAt = "created_at"
    }

    func toDomain() -> MealLogItem {
        let dateFormatter = ISO8601DateFormatter()
        let createdAtDate = dateFormatter.date(from: createdAt) ?? Date()

        return MealLogItem(
            id: UUID(uuidString: id) ?? UUID(),
            mealLogID: UUID(uuidString: mealLogId) ?? UUID(),
            name: foodName,
            quantity: quantity,
            unit: unit,
            calories: calories,
            protein: proteinG,
            carbs: carbsG,
            fat: fatG,
            foodType: FoodType(rawValue: foodType ?? "food") ?? .food,
            fiber: fiberG,
            sugar: sugarG,
            confidence: confidenceScore,
            parsingNotes: parsingNotes,
            orderIndex: orderIndex,
            createdAt: createdAtDate,
            backendID: id
        )
    }
}

// MARK: - API Response Wrapper

/// Wrapper for backend API responses that include a "data" field
struct APIDataWrapper<T: Codable>: Codable {
    let data: T
}

struct MealLogListAPIResponse: Codable {
    let entries: [MealLog]
    let total: Int
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case entries = "meal_logs"
        case total = "total_count"
        case limit
        case offset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode raw entries
        let rawEntries = try container.decode([MealLogAPIResponse].self, forKey: .entries)
        self.entries = rawEntries.map { $0.toDomain() }

        self.total = try container.decode(Int.self, forKey: .total)
        self.limit = try container.decode(Int.self, forKey: .limit)
        self.offset = try container.decode(Int.self, forKey: .offset)
    }
}

// MARK: - Error Types

enum NutritionAPIError: Error, LocalizedError {
    case invalidRequest
    case invalidResponse(message: String)
    case networkError(Error)
    case parsingError
    case unauthorized
    case notFound
    case forbidden
    case unexpectedResponse(statusCode: Int)
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid request parameters"
        case .invalidResponse(let message):
            return "Invalid response from server: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse server response"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .notFound:
            return "Resource not found"
        case .forbidden:
            return "Access forbidden"
        case .unexpectedResponse(let statusCode):
            return "Unexpected response from server (status code: \(statusCode))"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}
