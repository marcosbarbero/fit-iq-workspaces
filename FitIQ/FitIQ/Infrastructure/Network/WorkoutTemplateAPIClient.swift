//
//  WorkoutTemplateAPIClient.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Infrastructure adapter for workout template API operations
///
/// Communicates with the backend API for workout templates
///
/// **Backend Endpoints:**
/// - GET /api/v1/workout-templates/public - List public templates
/// - GET /api/v1/workout-templates - List user's templates
/// - POST /api/v1/workout-templates - Create template
/// - PUT /api/v1/workout-templates/{id} - Update template
/// - DELETE /api/v1/workout-templates/{id} - Delete template
/// - GET /api/v1/workout-templates/{id} - Get template by ID
///
/// **Architecture:**
/// - Infrastructure layer (adapter)
/// - Implements WorkoutTemplateAPIClientProtocol
final class WorkoutTemplateAPIClient: WorkoutTemplateAPIClientProtocol {

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

    // MARK: - WorkoutTemplateAPIClientProtocol Implementation

    func fetchPublicTemplates(
        category: String?,
        difficulty: DifficultyLevel?,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [WorkoutTemplate] {
        print(
            "WorkoutTemplateAPIClient: Fetching public templates - category: \(category ?? "all"), difficulty: \(difficulty?.rawValue ?? "all")"
        )

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/public") else {
            throw APIError.invalidURL
        }

        // Build query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let difficulty = difficulty {
            queryItems.append(URLQueryItem(name: "difficulty", value: difficulty.rawValue))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))

        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Execute request (no auth token needed for public endpoint)
        let (data, httpResponse) = try await networkClient.executeRequest(request: urlRequest)

        guard httpResponse.statusCode == 200 else {
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.apiError(
                    statusCode: httpResponse.statusCode, message: errorResponse.message)
            }
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let standardResponse: StandardResponse<PublicTemplatesResponse>
        do {
            standardResponse = try decoder.decode(
                StandardResponse<PublicTemplatesResponse>.self, from: data)
        } catch {
            print("WorkoutTemplateAPIClient: ❌ JSON Decoding Error:")
            print("  Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print(
                        "  Missing key: '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"
                    )
                case .typeMismatch(let type, let context):
                    print(
                        "  Type mismatch: Expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"
                    )
                    print("  Debug description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print(
                        "  Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"
                    )
                case .dataCorrupted(let context):
                    print(
                        "  Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"
                    )
                    print("  Debug description: \(context.debugDescription)")
                @unknown default:
                    print("  Unknown decoding error")
                }
            }
            throw error
        }

        let templates = standardResponse.data.toDomain()

        print("WorkoutTemplateAPIClient: ✅ Fetched \(templates.count) public templates")

        return templates
    }

    func fetchOwnedTemplates(
        category: String?,
        difficulty: DifficultyLevel?,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [WorkoutTemplate] {
        print("WorkoutTemplateAPIClient: Fetching owned templates")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates") else {
            throw APIError.invalidURL
        }

        // Build query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "source", value: "owned")
        ]

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let difficulty = difficulty {
            queryItems.append(URLQueryItem(name: "difficulty", value: difficulty.rawValue))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))

        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Execute with auth token
        let responseDTO: PaginatedWorkoutTemplatesResponse = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        let templates = responseDTO.toDomain()

        print("WorkoutTemplateAPIClient: ✅ Fetched \(templates.count) owned templates")

        return templates
    }

    func createTemplate(request: CreateWorkoutTemplateRequest) async throws -> WorkoutTemplate {
        print("WorkoutTemplateAPIClient: Creating template '\(request.name)'")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates") else {
            throw APIError.invalidURL
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = bodyData

        // Execute with auth token
        let responseDTO: WorkoutTemplateResponse = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print("WorkoutTemplateAPIClient: ✅ Created template with backend ID: \(responseDTO.id)")

        return responseDTO.toDomain()
    }

    func updateTemplate(id: UUID, request: UpdateWorkoutTemplateRequest) async throws
        -> WorkoutTemplate
    {
        print("WorkoutTemplateAPIClient: Updating template \(id)")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/\(id.uuidString)") else {
            throw APIError.invalidURL
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = bodyData

        // Execute with auth token
        let responseDTO: WorkoutTemplateResponse = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print("WorkoutTemplateAPIClient: ✅ Updated template")

        return responseDTO.toDomain()
    }

    func deleteTemplate(id: UUID) async throws {
        print("WorkoutTemplateAPIClient: Deleting template \(id)")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/\(id.uuidString)") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Get auth token
        guard let token = try? authTokenPersistence.fetchAccessToken() else {
            throw APIError.unauthorized
        }

        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, httpResponse) = try await networkClient.executeRequest(request: urlRequest)

        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw APIError.apiError(
                statusCode: httpResponse.statusCode, message: "Failed to delete template")
        }

        print("WorkoutTemplateAPIClient: ✅ Deleted template")
    }

    func fetchTemplate(id: UUID) async throws -> WorkoutTemplate {
        print("WorkoutTemplateAPIClient: Fetching template \(id)")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/\(id.uuidString)") else {
            print("WorkoutTemplateAPIClient: ❌ Invalid URL for template \(id)")
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            // Execute with auth token
            let responseDTO: WorkoutTemplateResponse = try await executeWithRetry(
                request: urlRequest,
                retryCount: 0
            )

            print(
                "WorkoutTemplateAPIClient: ✅ Fetched template '\(responseDTO.name)' with \(responseDTO.exercises?.count ?? 0) exercises"
            )

            return responseDTO.toDomain()
        } catch {
            print("WorkoutTemplateAPIClient: ❌ Error fetching template \(id): \(error)")
            print("WorkoutTemplateAPIClient: Error details: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sharing Operations

    func shareTemplate(
        id: UUID,
        userIds: [UUID],
        professionalType: ProfessionalType,
        notes: String?
    ) async throws -> ShareWorkoutTemplateResponse {
        print("WorkoutTemplateAPIClient: Sharing template \(id) with \(userIds.count) users")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/\(id.uuidString)/share")
        else {
            throw APIError.invalidURL
        }

        // Build request body
        let requestBody: [String: Any] = [
            "shared_with_user_ids": userIds.map { $0.uuidString },
            "professional_type": professionalType.rawValue,
            "notes": notes as Any,
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = bodyData

        // Execute with auth token
        let responseDTO: ShareWorkoutTemplateResponseDTO = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print("WorkoutTemplateAPIClient: ✅ Shared template with \(responseDTO.totalShared) users")

        return responseDTO.toDomain()
    }

    func revokeTemplateShare(
        templateId: UUID,
        userId: UUID
    ) async throws -> RevokeTemplateShareResponse {
        print("WorkoutTemplateAPIClient: Revoking template \(templateId) share from user \(userId)")

        guard
            let url = URL(
                string:
                    "\(baseURL)/api/v1/workout-templates/\(templateId.uuidString)/share/\(userId.uuidString)"
            )
        else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Execute with auth token
        let responseDTO: RevokeTemplateShareResponseDTO = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print("WorkoutTemplateAPIClient: ✅ Revoked template share from user")

        return responseDTO.toDomain()
    }

    func fetchSharedWithMeTemplates(
        professionalType: ProfessionalType?,
        limit: Int,
        offset: Int
    ) async throws -> ListSharedTemplatesResponse {
        print("WorkoutTemplateAPIClient: Fetching templates shared with me")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/shared-with-me") else {
            throw APIError.invalidURL
        }

        // Build query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []

        if let professionalType = professionalType {
            queryItems.append(
                URLQueryItem(name: "professional_type", value: professionalType.rawValue))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))

        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // Execute with auth token
        let responseDTO: ListSharedTemplatesResponseDTO = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print("WorkoutTemplateAPIClient: ✅ Fetched \(responseDTO.templates.count) shared templates")

        return responseDTO.toDomain()
    }

    func copyTemplate(
        id: UUID,
        newName: String?
    ) async throws -> CopyWorkoutTemplateResponse {
        print("WorkoutTemplateAPIClient: Copying template \(id)")

        guard let url = URL(string: "\(baseURL)/api/v1/workout-templates/\(id.uuidString)/copy")
        else {
            throw APIError.invalidURL
        }

        // Build request body
        var requestBody: [String: Any] = [:]
        if let newName = newName {
            requestBody["new_name"] = newName
        }

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = bodyData

        // Execute with auth token
        let responseDTO: CopyWorkoutTemplateResponseDTO = try await executeWithRetry(
            request: urlRequest,
            retryCount: 0
        )

        print(
            "WorkoutTemplateAPIClient: ✅ Copied template to new template \(responseDTO.newTemplate.id)"
        )

        return responseDTO.toDomain()
    }

    // MARK: - Private Helper Methods

    /// Executes a request with automatic token refresh on 401
    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        // Get auth token
        guard let token = try? authTokenPersistence.fetchAccessToken() else {
            print("WorkoutTemplateAPIClient: ❌ No auth token available")
            throw APIError.unauthorized
        }

        // Add auth header
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            // Execute request using networkClient
            let (data, httpResponse) = try await networkClient.executeRequest(
                request: authenticatedRequest)
            let statusCode = httpResponse.statusCode

            print("WorkoutTemplateAPIClient: Received response with status code: \(statusCode)")

            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print(
                    "WorkoutTemplateAPIClient: Response data preview: \(responseString.prefix(200))"
                )
            }

            // Handle response based on status code
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            switch statusCode {
            case 200, 201:
                // Try to decode wrapped response first, fallback to direct decode
                do {
                    let successResponse = try decoder.decode(StandardResponse<T>.self, from: data)
                    return successResponse.data
                } catch {
                    return try decoder.decode(T.self, from: data)
                }
            case 401:
                print("WorkoutTemplateAPIClient: ❌ Received 401 Unauthorized")
                throw APIError.unauthorized
            case 404:
                print("WorkoutTemplateAPIClient: ❌ Received 404 Not Found")
                throw APIError.notFound
            default:
                print("WorkoutTemplateAPIClient: ❌ Received error status code: \(statusCode)")
                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                    print("WorkoutTemplateAPIClient: Error message: \(errorResponse.message)")
                    throw APIError.apiError(statusCode: statusCode, message: errorResponse.message)
                }
                throw APIError.invalidResponse
            }
        } catch let error as NSError
            where error.code == 401 || error.localizedDescription.contains("401")
        {
            // Handle 401 - try token refresh
            print(
                "WorkoutTemplateAPIClient: 🔄 Received 401, attempting token refresh (retry \(retryCount + 1)/2)"
            )

            if retryCount >= 1 {
                print("WorkoutTemplateAPIClient: ❌ Token refresh failed after retries")
                throw APIError.unauthorized
            }

            // Attempt token refresh
            do {
                try await refreshTokenIfNeeded()

                // Retry request with new token
                return try await executeWithRetry(request: request, retryCount: retryCount + 1)
            } catch {
                print(
                    "WorkoutTemplateAPIClient: ❌ Token refresh failed: \(error.localizedDescription)"
                )
                throw APIError.unauthorized
            }
        }
    }

    /// Refreshes the auth token if needed (with synchronization)
    private func refreshTokenIfNeeded() async throws {
        // Use lock to ensure only one refresh happens at a time
        refreshLock.lock()

        if isRefreshing {
            refreshLock.unlock()
            // Wait for existing refresh to complete
            if let task = refreshTask {
                _ = try await task.value
            }
            return
        }

        isRefreshing = true
        refreshLock.unlock()

        defer {
            refreshLock.lock()
            isRefreshing = false
            refreshTask = nil
            refreshLock.unlock()
        }

        print("WorkoutTemplateAPIClient: 🔄 Refreshing auth token...")

        // Create refresh task
        let task = Task<LoginResponse, Error> {
            guard let refreshToken = try? authTokenPersistence.fetchRefreshToken() else {
                throw APIError.unauthorized
            }

            guard let url = URL(string: "\(baseURL)/api/v1/auth/refresh") else {
                throw APIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

            let (data, httpResponse) = try await networkClient.executeRequest(request: request)

            guard httpResponse.statusCode == 200 else {
                throw APIError.unauthorized
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let successResponse = try decoder.decode(
                StandardResponse<LoginResponse>.self, from: data)
            let loginData = successResponse.data

            // Update stored tokens
            try authTokenPersistence.save(
                accessToken: loginData.accessToken,
                refreshToken: loginData.refreshToken
            )

            print("WorkoutTemplateAPIClient: ✅ Token refreshed successfully")
            return loginData
        }

        refreshTask = task
        _ = try await task.value
    }
}

// MARK: - API Response DTOs for Sharing

/// DTO for share template response
private struct ShareWorkoutTemplateResponseDTO: Decodable {
    let templateId: String
    let templateName: String
    let sharedWith: [SharedWithUserInfoDTO]
    let totalShared: Int
    let professionalType: String

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case templateName = "template_name"
        case sharedWith = "shared_with"
        case totalShared = "total_shared"
        case professionalType = "professional_type"
    }

    func toDomain() -> ShareWorkoutTemplateResponse {
        return ShareWorkoutTemplateResponse(
            templateId: UUID(uuidString: templateId) ?? UUID(),
            templateName: templateName,
            sharedWith: sharedWith.map { $0.toDomain() },
            totalShared: totalShared,
            professionalType: ProfessionalType(rawValue: professionalType)
                ?? .personalTrainer
        )
    }
}

/// DTO for shared with user info
private struct SharedWithUserInfoDTO: Decodable {
    let userId: String
    let shareId: String
    let sharedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case shareId = "share_id"
        case sharedAt = "shared_at"
    }

    func toDomain() -> SharedWithUserInfo {
        let formatter = ISO8601DateFormatter()
        return SharedWithUserInfo(
            userId: UUID(uuidString: userId) ?? UUID(),
            shareId: UUID(uuidString: shareId) ?? UUID(),
            sharedAt: formatter.date(from: sharedAt) ?? Date()
        )
    }
}

/// DTO for shared template info
private struct SharedTemplateInfoDTO: Decodable {
    let templateId: String
    let name: String
    let description: String?
    let category: String?
    let difficultyLevel: String?
    let estimatedDurationMinutes: Int?
    let exerciseCount: Int
    let professionalName: String
    let professionalType: String
    let sharedAt: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case name
        case description
        case category
        case difficultyLevel = "difficulty_level"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case exerciseCount = "exercise_count"
        case professionalName = "professional_name"
        case professionalType = "professional_type"
        case sharedAt = "shared_at"
        case notes
    }

    func toDomain() -> SharedTemplateInfo {
        let formatter = ISO8601DateFormatter()
        return SharedTemplateInfo(
            templateId: UUID(uuidString: templateId) ?? UUID(),
            name: name,
            description: description,
            category: category,
            difficultyLevel: difficultyLevel.flatMap { DifficultyLevel(rawValue: $0) },
            estimatedDurationMinutes: estimatedDurationMinutes,
            exerciseCount: exerciseCount,
            professionalName: professionalName,
            professionalType: ProfessionalType(rawValue: professionalType)
                ?? .personalTrainer,
            sharedAt: formatter.date(from: sharedAt) ?? Date(),
            notes: notes
        )
    }
}

/// DTO for list shared templates response
private struct ListSharedTemplatesResponseDTO: Decodable {
    let templates: [SharedTemplateInfoDTO]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case templates
        case total
        case limit
        case offset
        case hasMore = "has_more"
    }

    func toDomain() -> ListSharedTemplatesResponse {
        return ListSharedTemplatesResponse(
            templates: templates.map { $0.toDomain() },
            total: total,
            limit: limit,
            offset: offset,
            hasMore: hasMore
        )
    }
}

/// DTO for revoke template share response
private struct RevokeTemplateShareResponseDTO: Decodable {
    let templateId: String
    let revokedFromUserId: String
    let revokedAt: String

    enum CodingKeys: String, CodingKey {
        case templateId = "template_id"
        case revokedFromUserId = "revoked_from_user_id"
        case revokedAt = "revoked_at"
    }

    func toDomain() -> RevokeTemplateShareResponse {
        let formatter = ISO8601DateFormatter()
        return RevokeTemplateShareResponse(
            templateId: UUID(uuidString: templateId) ?? UUID(),
            revokedFromUserId: UUID(uuidString: revokedFromUserId) ?? UUID(),
            revokedAt: formatter.date(from: revokedAt) ?? Date()
        )
    }
}

/// DTO for copy template response
private struct CopyWorkoutTemplateResponseDTO: Decodable {
    let originalTemplateId: String
    let newTemplate: WorkoutTemplateResponse

    enum CodingKeys: String, CodingKey {
        case originalTemplateId = "original_template_id"
        case newTemplate = "new_template"
    }

    func toDomain() -> CopyWorkoutTemplateResponse {
        return CopyWorkoutTemplateResponse(
            originalTemplateId: UUID(uuidString: originalTemplateId) ?? UUID(),
            newTemplate: newTemplate.toDomain()
        )
    }
}
