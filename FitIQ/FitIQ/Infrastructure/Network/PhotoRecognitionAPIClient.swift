//
//  PhotoRecognitionAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Purpose: Network client for Photo Recognition API following Hexagonal Architecture
//

import Foundation
import FitIQCore

/// Network client for photo recognition API communication
/// Implements PhotoRecognitionAPIProtocol for backend synchronization
class PhotoRecognitionAPIClient: PhotoRecognitionAPIProtocol {

    // MARK: - Properties

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

    // MARK: - PhotoRecognitionAPIProtocol Implementation

    func uploadPhoto(
        imageData: String,
        mealType: String,
        loggedAt: Date,
        notes: String?
    ) async throws -> PhotoRecognition {
        print("PhotoRecognitionAPIClient: Uploading photo for meal recognition")
        print("PhotoRecognitionAPIClient: Meal type: \(mealType)")
        print("PhotoRecognitionAPIClient: Image size: \(imageData.count) bytes (base64)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/photo"

        guard let url = URL(string: endpoint) else {
            throw PhotoRecognitionAPIError.invalidRequest
        }

        // Convert base64 string back to Data for multipart upload
        guard let imageDataDecoded = Data(base64Encoded: imageData) else {
            throw PhotoRecognitionAPIError.invalidImageFormat
        }

        print("PhotoRecognitionAPIClient: Decoded image size: \(imageDataDecoded.count) bytes")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Create multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        urlRequest.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"photo\"; filename=\"meal.jpg\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageDataDecoded)
        body.append("\r\n".data(using: .utf8)!)

        // Add meal_type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"meal_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mealType)\r\n".data(using: .utf8)!)

        // Add logged_at field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"logged_at\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(ISO8601DateFormatter().string(from: loggedAt))\r\n".data(using: .utf8)!)

        // Add notes field if present
        if let notes = notes {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"notes\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(notes)\r\n".data(using: .utf8)!)
        }

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body

        print("PhotoRecognitionAPIClient: POST \(endpoint) (multipart/form-data)")
        print("PhotoRecognitionAPIClient: Total request size: \(body.count) bytes")

        // Execute with retry logic for 401
        let wrapper: APIDataWrapper<PhotoRecognitionUploadResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        print(
            "PhotoRecognitionAPIClient: ✅ Photo uploaded successfully - Session ID: \(wrapper.data.sessionId)"
        )
        print("PhotoRecognitionAPIClient: Recognized \(wrapper.data.recognizedItems.count) items")
        print("PhotoRecognitionAPIClient: Overall confidence: \(wrapper.data.overallConfidence)%")
        print("PhotoRecognitionAPIClient: Processing time: \(wrapper.data.processingTimeMs)ms")

        return wrapper.data.toDomain(
            mealType: MealType(rawValue: mealType) ?? .snack, loggedAt: loggedAt, notes: notes)
    }

    func getPhotoRecognition(id: String) async throws -> PhotoRecognition {
        print("PhotoRecognitionAPIClient: Fetching photo recognition - ID: \(id)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/photo/\(id)"

        guard let url = URL(string: endpoint) else {
            throw PhotoRecognitionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        print("PhotoRecognitionAPIClient: GET \(endpoint)")

        let wrapper: APIDataWrapper<PhotoRecognitionAPIResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        print(
            "PhotoRecognitionAPIClient: ✅ Photo recognition fetched - Status: \(wrapper.data.status)"
        )

        return wrapper.data.toDomain()
    }

    func listPhotoRecognitions(
        status: PhotoRecognitionStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?,
        offset: Int?
    ) async throws -> PhotoRecognitionListResult {
        print("PhotoRecognitionAPIClient: Listing photo recognitions")

        var components = URLComponents(string: "\(baseURL)/api/v1/meal-logs/photo")!

        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        if let startDate = startDate {
            queryItems.append(
                URLQueryItem(
                    name: "start_date", value: ISO8601DateFormatter().string(from: startDate)))
        }

        if let endDate = endDate {
            queryItems.append(
                URLQueryItem(name: "end_date", value: ISO8601DateFormatter().string(from: endDate))
            )
        }

        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw PhotoRecognitionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        print("PhotoRecognitionAPIClient: GET \(url)")

        let wrapper: APIDataWrapper<PhotoRecognitionListAPIResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        print(
            "PhotoRecognitionAPIClient: ✅ Fetched \(wrapper.data.entries.count) photo recognitions"
        )

        return PhotoRecognitionListResult(
            recognitions: wrapper.data.entries.map { $0.toDomain() },
            totalCount: wrapper.data.total,
            limit: wrapper.data.limit,
            offset: wrapper.data.offset,
            hasMore: (wrapper.data.offset + wrapper.data.entries.count) < wrapper.data.total
        )
    }

    func confirmPhotoRecognition(
        id: String,
        confirmedItems: [ConfirmedFoodItem],
        notes: String?
    ) async throws -> MealLog {
        print("PhotoRecognitionAPIClient: Confirming photo recognition - ID: \(id)")
        print("PhotoRecognitionAPIClient: Confirmed items count: \(confirmedItems.count)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/photo/\(id)/confirm"

        guard let url = URL(string: endpoint) else {
            throw PhotoRecognitionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        var requestBody: [String: Any] = [
            "confirmed_items": confirmedItems.map { item in
                [
                    "name": item.name,
                    "quantity": item.quantity,
                    "unit": item.unit,
                    "calories": item.calories,
                    "protein_g": item.proteinG,
                    "carbs_g": item.carbsG,
                    "fat_g": item.fatG,
                    "fiber_g": item.fiberG as Any,
                    "sugar_g": item.sugarG as Any,
                ]
            }
        ]

        if let notes = notes {
            requestBody["notes"] = notes
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("PhotoRecognitionAPIClient: PATCH \(endpoint)")

        // The API returns the created meal log
        let wrapper: APIDataWrapper<MealLogAPIResponse> = try await executeWithRetry(
            request: urlRequest, retryCount: 0)

        print(
            "PhotoRecognitionAPIClient: ✅ Photo recognition confirmed - Meal log ID: \(wrapper.data.id)"
        )

        return wrapper.data.toDomain()
    }

    func deletePhotoRecognition(id: String) async throws {
        print("PhotoRecognitionAPIClient: Deleting photo recognition - ID: \(id)")

        let endpoint = "\(baseURL)/api/v1/meal-logs/photo/\(id)"

        guard let url = URL(string: endpoint) else {
            throw PhotoRecognitionAPIError.invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        print("PhotoRecognitionAPIClient: DELETE \(endpoint)")

        try await executeDeleteWithRetry(request: urlRequest, retryCount: 0)

        print("PhotoRecognitionAPIClient: ✅ Photo recognition deleted")
    }

    // MARK: - Private Helper Methods

    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var urlRequest = request

        // Get current access token
        guard let accessToken = try? authTokenPersistence.fetchAccessToken() else {
            throw PhotoRecognitionAPIError.unauthorized
        }

        // Add authorization header
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            // Attempt request
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PhotoRecognitionAPIError.networkError(
                    NSError(domain: "Invalid response", code: -1))
            }

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                print("PhotoRecognitionAPIClient: ✅ Received 2xx response")

                // Log raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("PhotoRecognitionAPIClient: Raw response JSON: \(jsonString)")
                } else {
                    print(
                        "PhotoRecognitionAPIClient: ⚠️ Could not decode response data as UTF-8 string"
                    )
                }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    print("PhotoRecognitionAPIClient: ❌ Decoding error: \(error)")
                    print("PhotoRecognitionAPIClient: Expected type: \(T.self)")
                    throw PhotoRecognitionAPIError.decodingError(error)
                }

            case 401:
                // Unauthorized - refresh token and retry once
                if retryCount == 0 {
                    print("PhotoRecognitionAPIClient: 401 Unauthorized - refreshing token")
                    do {
                        try await refreshAccessToken()
                        print(
                            "PhotoRecognitionAPIClient: ✅ Token refreshed successfully, retrying request"
                        )
                        return try await executeWithRetry(
                            request: request, retryCount: retryCount + 1)
                    } catch {
                        print("PhotoRecognitionAPIClient: ❌ Token refresh failed: \(error)")
                        throw PhotoRecognitionAPIError.unauthorized
                    }
                } else {
                    print(
                        "PhotoRecognitionAPIClient: ❌ Still 401 after refresh, authentication failed"
                    )
                    throw PhotoRecognitionAPIError.unauthorized
                }

            case 403:
                throw PhotoRecognitionAPIError.forbidden

            case 404:
                throw PhotoRecognitionAPIError.notFound

            case 405:
                // Method Not Allowed - endpoint might not be implemented yet
                print("PhotoRecognitionAPIClient: ❌ 405 Method Not Allowed")
                print(
                    "PhotoRecognitionAPIClient: Endpoint: \(urlRequest.url?.absoluteString ?? "unknown")"
                )
                print("PhotoRecognitionAPIClient: Method: \(urlRequest.httpMethod ?? "unknown")")
                if let bodyString = String(data: data, encoding: .utf8) {
                    print("PhotoRecognitionAPIClient: Response: \(bodyString)")
                }
                throw PhotoRecognitionAPIError.methodNotAllowed

            case 413:
                throw PhotoRecognitionAPIError.payloadTooLarge

            case 400:
                // Log the full error response for debugging
                print("PhotoRecognitionAPIClient: ❌ 400 Bad Request")
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("PhotoRecognitionAPIClient: Response body: \(errorMessage)")

                    // Check if it's an invalid image format error
                    if errorMessage.lowercased().contains("format") {
                        throw PhotoRecognitionAPIError.invalidImageFormat
                    }
                } else {
                    print("PhotoRecognitionAPIClient: Could not decode response body")
                }

                // Log request details for debugging
                print(
                    "PhotoRecognitionAPIClient: Request URL: \(urlRequest.url?.absoluteString ?? "unknown")"
                )
                print(
                    "PhotoRecognitionAPIClient: Request method: \(urlRequest.httpMethod ?? "unknown")"
                )
                print(
                    "PhotoRecognitionAPIClient: Request headers: \(urlRequest.allHTTPHeaderFields ?? [:])"
                )
                if let bodyData = urlRequest.httpBody,
                    let bodyString = String(data: bodyData, encoding: .utf8)
                {
                    // Only log first 500 chars to avoid huge base64 dumps
                    let preview = bodyString.prefix(500)
                    print("PhotoRecognitionAPIClient: Request body preview: \(preview)...")
                }

                throw PhotoRecognitionAPIError.invalidRequest

            default:
                throw PhotoRecognitionAPIError.unknownError(statusCode: httpResponse.statusCode)
            }

        } catch let error as PhotoRecognitionAPIError {
            throw error
        } catch {
            throw PhotoRecognitionAPIError.networkError(error)
        }
    }

    private func executeDeleteWithRetry(
        request: URLRequest,
        retryCount: Int
    ) async throws {
        var urlRequest = request

        // Get current access token
        guard let accessToken = try? authTokenPersistence.fetchAccessToken() else {
            throw PhotoRecognitionAPIError.unauthorized
        }

        // Add authorization header
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            // Attempt request
            let (_, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PhotoRecognitionAPIError.networkError(
                    NSError(domain: "Invalid response", code: -1))
            }

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299, 204:
                // Success
                return

            case 401:
                // Unauthorized - refresh token and retry once
                if retryCount == 0 {
                    print("PhotoRecognitionAPIClient: 401 Unauthorized - refreshing token")
                    do {
                        try await refreshAccessToken()
                        print(
                            "PhotoRecognitionAPIClient: ✅ Token refreshed successfully, retrying request"
                        )
                        try await executeDeleteWithRetry(
                            request: request, retryCount: retryCount + 1)
                    } catch {
                        print("PhotoRecognitionAPIClient: ❌ Token refresh failed: \(error)")
                        throw PhotoRecognitionAPIError.unauthorized
                    }
                } else {
                    print(
                        "PhotoRecognitionAPIClient: ❌ Still 401 after refresh, authentication failed"
                    )
                    throw PhotoRecognitionAPIError.unauthorized
                }

            case 403:
                throw PhotoRecognitionAPIError.forbidden

            case 404:
                throw PhotoRecognitionAPIError.notFound

            default:
                throw PhotoRecognitionAPIError.unknownError(statusCode: httpResponse.statusCode)
            }

        } catch let error as PhotoRecognitionAPIError {
            throw error
        } catch {
            throw PhotoRecognitionAPIError.networkError(error)
        }
    }

    private func refreshAccessToken() async throws {
        refreshLock.lock()
        defer { refreshLock.unlock() }

        // Check if already refreshing
        if isRefreshing, let task = refreshTask {
            print("PhotoRecognitionAPIClient: Waiting for existing refresh task to complete")
            // Wait for existing refresh to complete
            _ = try await task.value
            return
        }

        // Start new refresh
        print("PhotoRecognitionAPIClient: Starting token refresh")
        isRefreshing = true
        refreshTask = Task {
            defer {
                isRefreshing = false
                refreshTask = nil
            }

            guard let refreshToken = try? authTokenPersistence.fetchRefreshToken() else {
                print("PhotoRecognitionAPIClient: ❌ No refresh token available")
                throw PhotoRecognitionAPIError.unauthorized
            }

            print("PhotoRecognitionAPIClient: Refresh token available, calling refresh endpoint")

            // Call refresh endpoint
            let endpoint = "\(baseURL)/api/v1/auth/refresh"
            guard let url = URL(string: endpoint) else {
                print("PhotoRecognitionAPIClient: ❌ Invalid refresh endpoint URL")
                throw PhotoRecognitionAPIError.invalidRequest
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

            let requestBody = ["refresh_token": refreshToken]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            print("PhotoRecognitionAPIClient: POST \(endpoint)")

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("PhotoRecognitionAPIClient: ❌ Invalid HTTP response from refresh endpoint")
                throw PhotoRecognitionAPIError.unauthorized
            }

            print(
                "PhotoRecognitionAPIClient: Refresh endpoint returned status \(httpResponse.statusCode)"
            )

            guard httpResponse.statusCode == 200 else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("PhotoRecognitionAPIClient: ❌ Refresh failed: \(errorBody)")
                }
                throw PhotoRecognitionAPIError.unauthorized
            }

            let decoder = JSONDecoder()

            // Parse the response manually since LoginResponse is Decodable only
            struct RefreshTokenResponse: Decodable {
                let data: LoginResponse
            }
            let wrapper = try decoder.decode(RefreshTokenResponse.self, from: data)

            print("PhotoRecognitionAPIClient: New tokens received, saving to keychain")

            // Save new tokens
            try authTokenPersistence.save(
                accessToken: wrapper.data.accessToken,
                refreshToken: wrapper.data.refreshToken
            )

            print("PhotoRecognitionAPIClient: ✅ Token refresh completed successfully")

            return wrapper.data
        }

        _ = try await refreshTask!.value
    }
}

// MARK: - Response DTOs

/// Response from photo upload endpoint - backend returns immediate recognition results
struct PhotoRecognitionUploadResponse: Codable {
    let sessionId: String
    let recognizedItems: [RecognizedFoodItemUploadDTO]
    let totalMacros: TotalMacrosDTO
    let overallConfidence: Double
    let needsReview: Bool
    let processingTimeMs: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case recognizedItems = "recognized_items"
        case totalMacros = "total_macros"
        case overallConfidence = "overall_confidence"
        case needsReview = "needs_review"
        case processingTimeMs = "processing_time_ms"
    }

    func toDomain(mealType: MealType, loggedAt: Date, notes: String?) -> PhotoRecognition {
        // Convert items with proper order indices
        let domainItems = recognizedItems.enumerated().map { index, item in
            item.toDomain(orderIndex: index)
        }

        // Calculate total fiber and sugar from individual items (backend doesn't provide in total_macros)
        let totalFiber = recognizedItems.reduce(0.0) { sum, item in
            sum + Double(item.macronutrients.fiber ?? 0)
        }
        let totalSugar = recognizedItems.reduce(0.0) { sum, item in
            sum + Double(item.macronutrients.sugar ?? 0)
        }

        return PhotoRecognition(
            id: UUID(),  // Generate local ID
            userID: "",  // Will be set by use case
            imageURL: nil,
            mealType: mealType,
            status: .completed,  // Backend processed immediately
            confidenceScore: overallConfidence / 100.0,  // Convert percentage to 0-1
            needsReview: needsReview,
            recognizedItems: domainItems,
            totalCalories: totalMacros.totalCalories,
            totalProteinG: Double(totalMacros.totalProtein),
            totalCarbsG: Double(totalMacros.totalCarbohydrates),
            totalFatG: Double(totalMacros.totalFats),
            totalFiberG: totalFiber > 0 ? totalFiber : nil,
            totalSugarG: totalSugar > 0 ? totalSugar : nil,
            loggedAt: loggedAt,
            notes: notes,
            errorMessage: nil,
            processingStartedAt: Date(),
            processingCompletedAt: Date(),
            createdAt: Date(),
            updatedAt: nil,
            backendID: sessionId,
            syncStatus: .synced,
            mealLogID: nil
        )
    }
}

struct RecognizedFoodItemUploadDTO: Codable {
    let id: String
    let name: String
    let quantity: Double
    let unit: String
    let confidence: Int  // Percentage (0-100)
    let needsReview: Bool
    let macronutrients: MacronutrientsDTO
    let portionHints: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unit
        case confidence
        case needsReview = "needs_review"
        case macronutrients
        case portionHints = "portion_hints"
    }

    func toDomain(orderIndex: Int) -> PhotoRecognizedFoodItem {
        let confidenceScore = Double(confidence) / 100.0  // Convert percentage to 0-1
        return PhotoRecognizedFoodItem(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            quantity: quantity,
            unit: unit,
            calories: macronutrients.calories,
            proteinG: Double(macronutrients.protein),
            carbsG: Double(macronutrients.carbohydrates),
            fatG: Double(macronutrients.fats),
            fiberG: macronutrients.fiber.map { Double($0) },
            sugarG: macronutrients.sugar.map { Double($0) },
            confidenceScore: confidenceScore,
            confidenceLevel: PhotoConfidenceLevel.fromScore(confidenceScore),
            orderIndex: orderIndex
        )
    }
}

struct MacronutrientsDTO: Codable {
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fats: Int
    let fiber: Int?
    let sugar: Int?
}

struct TotalMacrosDTO: Codable {
    let totalCalories: Int
    let totalProtein: Int
    let totalCarbohydrates: Int
    let totalFats: Int
    // Note: Backend doesn't provide total_fiber or total_sugar in total_macros
    // These are calculated from individual items in PhotoRecognitionUploadResponse.toDomain()

    enum CodingKeys: String, CodingKey {
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalCarbohydrates = "total_carbohydrates"
        case totalFats = "total_fats"
    }
}

/// Legacy response structure (for future endpoints that may use this)
struct PhotoRecognitionAPIResponse: Codable {
    let id: String
    let userId: String
    let imageUrl: String?
    let mealType: String
    let status: String
    let confidenceScore: Double?
    let needsReview: Bool?
    let recognizedItems: [RecognizedFoodItemDTO]?
    let totalCalories: Int?
    let totalProteinG: Double?
    let totalCarbsG: Double?
    let totalFatG: Double?
    let totalFiberG: Double?
    let totalSugarG: Double?
    let loggedAt: String?
    let notes: String?
    let errorMessage: String?
    let processingStartedAt: String?
    let processingCompletedAt: String?
    let createdAt: String?
    let updatedAt: String?
    let mealLogId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrl = "image_url"
        case mealType = "meal_type"
        case status
        case confidenceScore = "confidence_score"
        case needsReview = "needs_review"
        case recognizedItems = "recognized_items"
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"
        case totalSugarG = "total_sugar_g"
        case loggedAt = "logged_at"
        case notes
        case errorMessage = "error_message"
        case processingStartedAt = "processing_started_at"
        case processingCompletedAt = "processing_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mealLogId = "meal_log_id"
    }

    func toDomain() -> PhotoRecognition {
        let dateFormatter = ISO8601DateFormatter()

        return PhotoRecognition(
            id: UUID(),  // Generate local ID
            userID: userId,
            imageURL: imageUrl,
            mealType: MealType(rawValue: mealType) ?? .snack,
            status: PhotoRecognitionStatus(rawValue: status) ?? .pending,
            confidenceScore: confidenceScore,
            needsReview: needsReview ?? false,
            recognizedItems: recognizedItems?.map { $0.toDomain() } ?? [],
            totalCalories: totalCalories,
            totalProteinG: totalProteinG,
            totalCarbsG: totalCarbsG,
            totalFatG: totalFatG,
            totalFiberG: totalFiberG,
            totalSugarG: totalSugarG,
            loggedAt: loggedAt.flatMap { dateFormatter.date(from: $0) } ?? Date(),
            notes: notes,
            errorMessage: errorMessage,
            processingStartedAt: processingStartedAt.flatMap { dateFormatter.date(from: $0) },
            processingCompletedAt: processingCompletedAt.flatMap { dateFormatter.date(from: $0) },
            createdAt: createdAt.flatMap { dateFormatter.date(from: $0) } ?? Date(),
            updatedAt: updatedAt.flatMap { dateFormatter.date(from: $0) },
            backendID: id,
            syncStatus: .synced,
            mealLogID: mealLogId.flatMap { UUID(uuidString: $0) }
        )
    }
}

struct RecognizedFoodItemDTO: Codable {
    let id: String?
    let name: String
    let quantity: Double
    let unit: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let confidenceScore: Double
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unit
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case confidenceScore = "confidence_score"
        case orderIndex = "order_index"
    }

    func toDomain() -> PhotoRecognizedFoodItem {
        PhotoRecognizedFoodItem(
            id: id.flatMap { UUID(uuidString: $0) } ?? UUID(),
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            sugarG: sugarG,
            confidenceScore: confidenceScore,
            confidenceLevel: PhotoConfidenceLevel.fromScore(confidenceScore),
            orderIndex: orderIndex ?? 0
        )
    }
}

struct PhotoRecognitionListAPIResponse: Codable {
    let entries: [PhotoRecognitionAPIResponse]
    let total: Int
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case entries
        case total
        case limit
        case offset
    }
}

// Note: APIDataWrapper, MealLogAPIResponse, and MealLogItemDTO are already defined
// in NutritionAPIClient.swift and imported/available globally
