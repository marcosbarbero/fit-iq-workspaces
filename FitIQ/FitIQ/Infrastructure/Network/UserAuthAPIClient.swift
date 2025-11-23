//
//  UserAuthAPIClient.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

// Infrastructure/Network/UserAuthAPIClient.swift
import FitIQCore
import Foundation

// Renamed and isolated to focus solely on API interaction and token lifecycle.
final class UserAuthAPIClient: AuthRepositoryProtocol {
    private let authManager: AuthManager
    private let networkClient: NetworkClientProtocol = URLSessionNetworkClient()
    private let baseURL: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol  // Use the port for token persistence
    private let tokenRefreshClient: TokenRefreshClient  // FitIQCore's token refresh client

    private let apiKey: String

    init(
        authManager: AuthManager,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        tokenRefreshClient: TokenRefreshClient
    ) {
        self.authManager = authManager
        self.authTokenPersistence = authTokenPersistence
        self.tokenRefreshClient = tokenRefreshClient
        baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
        apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
    }

    // MARK: - Helper Methods

    /// Decodes user_id from JWT token payload
    private func decodeUserIdFromJWT(_ token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        let base64String = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddedLength = base64String.count + (4 - base64String.count % 4) % 4
        let paddedBase64 = base64String.padding(toLength: paddedLength, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: paddedBase64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let userId = json["user_id"] as? String
        else {
            return nil
        }

        return userId
    }

    /// Extracts email from JWT token payload
    private func extractEmailFromJWT(_ token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        let base64String = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddedLength = base64String.count + (4 - base64String.count % 4) % 4
        let paddedBase64 = base64String.padding(toLength: paddedLength, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: paddedBase64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let email = json["email"] as? String
        else {
            return nil
        }

        return email
    }

    // MARK: - AuthRepositoryProtocol Conformance

    // Implements the Core's registration logic.
    /// Registers a new user account (Implements AuthRepositoryProtocol.register)
    func register(userData: RegisterUserData) async throws -> (
        profile: UserProfile, accessToken: String, refreshToken: String
    ) {
        // NEW LOG: Before attempting to register with the external service
        print("UserAuthAPIClient: Attempting to register user with email: \(userData.email)")

        // Convert Date to "YYYY-MM-DD" string format
        // Extract calendar components from the Date in the USER'S LOCAL TIMEZONE
        // This ensures the selected date (e.g., July 20) is preserved as "1983-07-20"
        // The DatePicker provides local midnight, so we extract components in local time
        let calendar = Calendar.current  // Use user's current calendar/timezone
        let components = calendar.dateComponents([.year, .month, .day], from: userData.dateOfBirth)
        let dobString = String(
            format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)

        print("UserAuthAPIClient: Date conversion - Input: \(userData.dateOfBirth)")
        print("UserAuthAPIClient: Date conversion - Output string: \(dobString)")
        print("UserAuthAPIClient: Date conversion - Timezone: \(calendar.timeZone.identifier)")

        let requestDTO = CreateUserRequest(
            email: userData.email,
            password: userData.password,
            name: userData.name,
            dateOfBirth: dobString
        )

        do {
            // Use the centralized executor. No more boilerplate setup here.
            let registerResponse =
                try await executeAPIRequest(
                    path: "/api/v1/auth/register",
                    httpMethod: "POST",
                    body: requestDTO
                ) as RegisterResponse

            // NEW LOG: After successful registration with the external service
            print("UserAuthAPIClient: User successfully registered on remote service.")
            print(
                "UserAuthAPIClient: Backend returned user_id: \(registerResponse.userId), email: \(registerResponse.email)"
            )

            // Backend now creates profile automatically during registration
            // Use data from RegisterResponse instead of manually constructing
            guard let userId = UUID(uuidString: registerResponse.userId) else {
                print("UserAuthAPIClient: Failed to parse user_id from registration response")
                throw APIError.invalidResponse
            }

            // Parse created_at timestamp
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let createdAt = isoFormatter.date(from: registerResponse.createdAt) ?? Date()

            // Generate username from email
            let username =
                registerResponse.email.components(separatedBy: "@").first ?? registerResponse.email

            // Create metadata from registration response
            // Use user ID as profile ID to match backend architecture (user_id is primary key)
            let metadata = UserProfileMetadata(
                id: userId,  // Use user ID as profile ID (backend's primary key)
                userId: userId,
                name: registerResponse.name,
                bio: nil,
                preferredUnitSystem: "metric",
                languageCode: nil,
                dateOfBirth: userData.dateOfBirth,
                createdAt: createdAt,
                updatedAt: createdAt
            )

            // Create physical profile with date of birth from registration
            let physicalProfile = PhysicalProfile(
                biologicalSex: nil,  // Not collected during registration
                heightCm: nil,  // Not collected during registration
                dateOfBirth: userData.dateOfBirth  // Store DOB in physical profile
            )

            // Compose UserProfile
            let userProfile = UserProfile(
                metadata: metadata,
                physical: physicalProfile,  // Include physical profile with DOB
                email: registerResponse.email,
                username: username
            )

            print("UserAuthAPIClient: User profile constructed from registration response.")

            return (
                userProfile,
                registerResponse.accessToken,
                registerResponse.refreshToken
            )
        } catch {
            // NEW LOG: If registration fails with the external service
            print(
                "UserAuthAPIClient: Failed to register user with email \(userData.email). Error: \(error.localizedDescription)"
            )
            throw error  // Re-throw the error for upstream handling
        }
    }

    /// Logs in a user (Implements AuthRepositoryProtocol.login)
    func login(credentials: LoginCredentials) async throws -> (
        profile: UserProfile, accessToken: String, refreshToken: String
    ) {
        // NEW LOG: Before attempting to log in with the external service
        print("UserAuthAPIClient: Attempting to log in user with email: \(credentials.email)")

        let requestDTO = LoginRequest(
            email: credentials.email,
            password: credentials.password
        )

        do {
            // Use the centralized executor.
            let loginResponseDTO =
                try await executeAPIRequest(
                    path: "/api/v1/auth/login",
                    httpMethod: "POST",
                    body: requestDTO
                ) as LoginResponse

            // NEW LOG: After successful login with the external service
            print("UserAuthAPIClient: User successfully logged in on remote service.")

            // Decode user_id from JWT token
            guard let userId = decodeUserIdFromJWT(loginResponseDTO.accessToken) else {
                print("UserAuthAPIClient: Failed to decode user_id from JWT token")
                throw APIError.invalidResponse
            }

            print("UserAuthAPIClient: Decoded user_id: \(userId). Fetching user profile...")

            // Try to fetch user profile from backend
            let userProfile: UserProfile
            do {
                let userProfileDTO = try await fetchUserProfile(
                    userId: userId, accessToken: loginResponseDTO.accessToken)
                // Convert DTO to metadata, then compose UserProfile
                let metadata = try userProfileDTO.toDomain()
                let email = extractEmailFromJWT(loginResponseDTO.accessToken) ?? credentials.email
                let username = email.components(separatedBy: "@").first ?? email
                userProfile = UserProfile(
                    metadata: metadata,
                    physical: nil,  // Physical profile would come from separate endpoint
                    email: email,
                    username: username
                )
            } catch let caughtError {
                // Check if it's a 404 error
                if let apiError = caughtError as? APIError {
                    switch apiError {
                    case .notFound:
                        // Backend doesn't have user endpoint yet, construct minimal profile from JWT
                        print(
                            "UserAuthAPIClient: User endpoint not available (404). Constructing minimal profile from JWT..."
                        )

                        // Extract email from JWT if available
                        let email =
                            extractEmailFromJWT(loginResponseDTO.accessToken) ?? credentials.email
                        let username = email.components(separatedBy: "@").first ?? email

                        // Create minimal metadata from JWT
                        // Use user ID as profile ID to match backend architecture
                        let userUUID = UUID(uuidString: userId) ?? UUID()
                        let metadata = UserProfileMetadata(
                            id: userUUID,  // Use user ID as profile ID (backend's primary key)
                            userId: userUUID,
                            name: "",  // Will be updated when user completes profile
                            bio: nil,
                            preferredUnitSystem: "metric",
                            languageCode: nil,
                            dateOfBirth: nil,
                            createdAt: Date(),
                            updatedAt: Date()
                        )

                        // Compose UserProfile
                        userProfile = UserProfile(
                            metadata: metadata,
                            physical: nil,
                            email: email,
                            username: username
                        )
                        print("UserAuthAPIClient: Minimal profile constructed from JWT.")
                    default:
                        // Re-throw other APIError cases
                        throw caughtError
                    }
                } else {
                    // Re-throw non-APIError errors
                    throw caughtError
                }
            }

            return (
                userProfile, loginResponseDTO.accessToken, loginResponseDTO.refreshToken
            )
        } catch {
            // NEW LOG: If login fails with the external service
            print(
                "UserAuthAPIClient: Failed to log in user with email \(credentials.email). Error: \(error.localizedDescription)"
            )
            throw error  // Re-throw the error for upstream handling
        }
    }

    /// Fetches user profile from /api/v1/users/me endpoint
    /// This endpoint returns user info with nested profile containing the correct profile ID
    private func fetchUserProfile(userId: String, accessToken: String) async throws
        -> UserProfileResponseDTO
    {
        guard let url = URL(string: "\(baseURL)/api/v1/users/me") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("UserAuthAPIClient: Fetching profile from /api/v1/users/me")

        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        if let responseString = String(data: data, encoding: .utf8) {
            print("UserAuthAPIClient: /users/me Response (\(statusCode)): \(responseString)")
        }

        guard statusCode == 200 else {
            print("UserAuthAPIClient: Failed to fetch user profile. Status: \(statusCode)")
            if statusCode == 404 {
                print("UserAuthAPIClient: Profile not found (404) - user needs to create profile")
                throw APIError.notFound
            }
            throw APIError.apiError(statusCode: statusCode, message: "Failed to fetch user profile")
        }

        let decoder = configuredDecoder()

        // Decode the actual /users/me response structure
        let successResponse = try decoder.decode(
            StandardResponse<UserWithProfileResponseDTO>.self, from: data)

        let userWithProfile = successResponse.data
        print(
            "UserAuthAPIClient: Successfully decoded user \(userWithProfile.id) with profile \(userWithProfile.profile.id)"
        )

        // Convert to UserProfileResponseDTO format expected by the rest of the code
        // Use user ID as profile ID to match backend architecture (user_id is primary key)
        let profileDTO = UserProfileResponseDTO(
            id: userWithProfile.id,  // Use user ID as profile ID (backend's primary key)
            userId: userWithProfile.id,
            name: userWithProfile.profile.name,
            bio: nil,  // Not included in /users/me response
            preferredUnitSystem: userWithProfile.profile.preferredUnitSystem,
            languageCode: userWithProfile.profile.languageCode,
            dateOfBirth: userWithProfile.profile.dateOfBirth,
            biologicalSex: nil,  // Not included in /users/me response
            heightCm: nil,  // Not included in /users/me response
            createdAt: "",  // Not included in /users/me response
            updatedAt: ""  // Not included in /users/me response
        )

        return profileDTO
    }

    // MARK: - Raw API Call Functions (Your provided code)

    /// Registers a new user account (The raw network call).
    private func registerUserAPI(request: CreateUserRequest) async throws
        -> UserProfileResponseDTO
    {
        guard let url = URL(string: "\(baseURL)/api/v1/auth/register") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        // 1. Encode the request body
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        // 2. Perform the network request
        let (data, response) = try await networkClient.executeRequest(request: urlRequest)  // Changed to use networkClient.executeRequest

        // 3. Handle the response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 201:
            // Success: Decode the wrapped response (StandardResponse<UserProfileResponseDTO>)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let successResponse = try decoder.decode(
                StandardResponse<UserProfileResponseDTO>.self,
                from: data
            )
            return successResponse.data  // Return the DTO

        case 400:  // Validation failed
            let validationError = try JSONDecoder().decode(
                ValidationErrorResponse.self,
                from: data
            )
            throw APIError.apiError(validationError)

        case 409, 500:  // Conflict or Server Error
            let apiError = try JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            )
            throw APIError.apiError(apiError)

        default:
            throw APIError.apiError(
                ErrorResponse(message: "Unexpected Status Code \(statusCode)")
            )
        }
    }

    /// Logs in user and returns tokens (The raw network call).
    private func loginAPI(request: LoginRequest) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/api/v1/auth/login") else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await networkClient.executeRequest(request: urlRequest)  // Changed to use networkClient.executeRequest
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let successResponse = try decoder.decode(
                StandardResponse<LoginResponse>.self,
                from: data
            )
            return successResponse.data  // Return the DTO

        case 400:  // Validation failed
            let validationError = try JSONDecoder().decode(
                ValidationErrorResponse.self,
                from: data
            )
            throw APIError.apiError(validationError)

        case 401, 500:  // Invalid credentials or server error
            let apiError = try JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            )
            throw APIError.apiError(apiError)

        default:
            throw APIError.apiError(
                ErrorResponse(message: "Unexpected Status Code \(statusCode)")
            )
        }
    }

    /// Retrieves the current valid access token from the Keychain using the persistence port.
    private func getAccessToken() throws -> String {
        guard let token = try authTokenPersistence.fetchAccessToken(), !token.isEmpty else {  // Use the port
            throw APIError.unauthorized
        }
        return token
    }

    /// Applies ISO 8601 date decoding strategy for responses containing UserResponse
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Core Authenticated Request Wrapper (The Interceptor)

    /// The central function for all authenticated API calls. Handles token injection and automatic refresh.
    func performAuthenticatedRequest<T: Decodable>(
        url: URL,
        httpMethod: String,
        body: Encodable? = nil
    ) async throws -> T {
        // Build the initial request
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        // Use a recursive helper that can retry once
        return try await executeWithRetry(originalRequest: request, retryCount: 0)
    }

    /// Executes an authenticated request with automatic retry on 401 using FitIQCore
    private func executeWithRetry<T: Decodable>(
        originalRequest: URLRequest,
        retryCount: Int
    ) async throws -> T {
        // 1. Inject the latest Access Token
        var request = originalRequest
        do {
            let token = try getAccessToken()  // This now uses the persistence port
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            // Token is missing from Keychain
            authManager.logout()
            throw error
        }

        // 2. Get current refresh token for potential retry
        guard let currentRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
            authManager.logout()
            throw APIError.unauthorized
        }

        // 3. Execute with FitIQCore's automatic retry on 401
        do {
            let (data, httpResponse) = try await networkClient.executeRequest(request: request)
            let statusCode = httpResponse.statusCode

            switch statusCode {
            case 200...299:
                // Success: Decode the response data
                let successResponse = try configuredDecoder().decode(
                    StandardResponse<T>.self, from: data)
                return successResponse.data

            case 401:
                // Token expired, use FitIQCore's TokenRefreshClient to refresh
                print("UserAuthAPIClient: Access token expired (401). Refreshing via FitIQCore...")

                let refreshResponse = try await tokenRefreshClient.refreshToken(
                    refreshToken: currentRefreshToken
                )

                // Save new tokens
                try authTokenPersistence.save(
                    accessToken: refreshResponse.accessToken,
                    refreshToken: refreshResponse.refreshToken
                )

                print("UserAuthAPIClient: ✅ Token refresh successful. Retrying request...")

                // Retry with new token
                request.setValue(
                    "Bearer \(refreshResponse.accessToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await networkClient.executeRequest(
                    request: request)

                if retryResponse.statusCode >= 200 && retryResponse.statusCode < 300 {
                    let successResponse = try configuredDecoder().decode(
                        StandardResponse<T>.self, from: retryData)
                    return successResponse.data
                } else if retryResponse.statusCode == 401 {
                    // Still 401 after refresh, logout
                    authManager.logout()
                    throw APIError.unauthorized
                } else {
                    // Handle other error codes
                    throw APIError.apiError(
                        ErrorResponse(
                            message: "Request failed with status \(retryResponse.statusCode)"))
                }

            case 400:  // Validation failed
                let validationError = try configuredDecoder().decode(
                    ValidationErrorResponse.self, from: data)
                throw APIError.apiError(validationError)

            case 402...499:  // Client error
                let apiError = try configuredDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.apiError(apiError)

            case 500...599:  // Server error
                let apiError = try configuredDecoder().decode(ErrorResponse.self, from: data)
                throw APIError.apiError(apiError)

            default:
                throw APIError.apiError(
                    ErrorResponse(message: "Unexpected Status Code \(statusCode)"))
            }
        } catch let error as APIError {
            // Check if refresh token is invalid/revoked
            if error.localizedDescription.contains("refresh token has been revoked")
                || error.localizedDescription.contains("invalid refresh token")
                || error.localizedDescription.contains("refresh token not found")
            {
                print("UserAuthAPIClient: ⚠️ Refresh token is invalid/revoked. Logging out user.")
                authManager.logout()
            }
            throw error
        }
    }

    // MARK: - Protocol Conformance

    /// Refreshes access token using FitIQCore's TokenRefreshClient
    /// This method satisfies AuthRepositoryProtocol requirements
    func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
        print("UserAuthAPIClient: Refreshing token via FitIQCore TokenRefreshClient...")

        let refreshResponse = try await tokenRefreshClient.refreshToken(
            refreshToken: request.refreshToken
        )

        print("UserAuthAPIClient: ✅ Token refresh successful via FitIQCore.")

        // Convert FitIQCore's RefreshResponse to LoginResponse
        return LoginResponse(
            accessToken: refreshResponse.accessToken,
            refreshToken: refreshResponse.refreshToken
        )
    }

    /// Handles request setup, encoding, unauthenticated execution, and standardized error mapping.
    private func executeAPIRequest<T: Decodable, E: Encodable>(
        path: String,
        httpMethod: String,
        body: E
    ) async throws -> T {
        // 1. Build URL/Request
        guard let url = URL(string: "\(baseURL)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        // 2. Encode body
        request.httpBody = try JSONEncoder().encode(body)

        // NEW LOG: Log API request details
        print("UserAuthAPIClient: Making API request to \(path) with method \(httpMethod).")
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8)
        {
            print("UserAuthAPIClient: Request Body JSON: \(bodyString)")
        }

        // 3. Execute request using the injected client (NetworkClientProtocol implementation)
        let (data, httpResponse) = try await networkClient.executeRequest(request: request)
        let statusCode = httpResponse.statusCode

        // NEW LOG: Log API response status and data
        print("UserAuthAPIClient: Received response for \(path) with status code \(statusCode).")
        if let responseString = String(data: data, encoding: .utf8) {
            print("UserAuthAPIClient: Response Body: \(responseString)")
        }

        // 4. Standardized Response Handling
        let decoder = configuredDecoder()

        switch statusCode {
        case 200, 201:
            // Success: Try to decode the wrapped response (StandardResponse<T>)
            // If that fails, try to decode the data directly
            do {
                let successResponse = try decoder.decode(StandardResponse<T>.self, from: data)
                return successResponse.data
            } catch {
                print(
                    "UserAuthAPIClient: Failed to decode wrapped response, trying direct decode...")
                // Fallback: Try to decode directly without wrapper
                return try decoder.decode(T.self, from: data)
            }

        case 400:  // Validation failed
            let validationError = try decoder.decode(ValidationErrorResponse.self, from: data)
            print("UserAuthAPIClient: Validation Error for \(path): \(validationError.message)")
            if let details = validationError.details {
                print("UserAuthAPIClient: Validation Details: \(details)")
            }
            throw APIError.apiError(validationError)

        case 401, 409, 500...599:
            let apiError = try decoder.decode(ErrorResponse.self, from: data)
            print("UserAuthAPIClient: API Error for \(path): \(apiError.message)")  // Specific error log
            throw APIError.apiError(apiError)

        default:
            print("UserAuthAPIClient: Unexpected Status Code \(statusCode) for \(path).")  // Specific error log
            throw APIError.apiError(ErrorResponse(message: "Unexpected Status Code \(statusCode)"))
        }
    }
}
