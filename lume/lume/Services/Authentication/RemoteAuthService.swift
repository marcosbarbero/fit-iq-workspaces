import FitIQCore
import Foundation

final class RemoteAuthService: AuthServiceProtocol {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    init(
        baseURL: URL? = nil,
        apiKey: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL ?? AppConfiguration.shared.backendBaseURL
        self.apiKey = apiKey ?? AppConfiguration.shared.apiKey
        self.session = session
    }

    func register(email: String, password: String, name: String, dateOfBirth: Date) async throws
        -> (User, AuthToken)
    {
        let endpoint = baseURL.appendingPathComponent(AppConfiguration.Endpoints.authRegister)

        let requestBody = RegisterRequest(
            email: email,
            password: password,
            name: name,
            dateOfBirth: dateOfBirth
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }

        switch httpResponse.statusCode {
        case 201:
            let apiResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
            let user = User(
                id: apiResponse.data.userId,
                email: apiResponse.data.email,
                name: apiResponse.data.name,
                dateOfBirth: dateOfBirth,
                createdAt: apiResponse.data.createdAt
            )
            // Use FitIQCore.AuthToken which automatically parses JWT
            let token = AuthToken(
                accessToken: apiResponse.data.accessToken,
                refreshToken: apiResponse.data.refreshToken
            )
            return (user, token)

        case 400:
            throw AuthenticationError.invalidEmail

        case 409:
            throw AuthenticationError.userAlreadyExists

        default:
            throw AuthenticationError.unknown
        }
    }

    func login(email: String, password: String) async throws -> AuthToken {
        let endpoint = baseURL.appendingPathComponent(AppConfiguration.Endpoints.authLogin)

        let requestBody = LoginRequest(
            email: email,
            password: password
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticationError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            let apiResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            // Use FitIQCore.AuthToken which automatically parses JWT
            let token = AuthToken(
                accessToken: apiResponse.data.accessToken,
                refreshToken: apiResponse.data.refreshToken
            )
            return token

        case 401:
            throw AuthenticationError.invalidCredentials

        default:
            throw AuthenticationError.unknown
        }
    }

    func refreshToken(_ token: String) async throws -> AuthToken {
        let endpoint = baseURL.appendingPathComponent(AppConfiguration.Endpoints.authRefresh)

        let requestBody = RefreshTokenRequest(refreshToken: token)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        print("🔄 [RemoteAuthService] Attempting token refresh")
        print("🔄 [RemoteAuthService] Endpoint: \(endpoint.absoluteString)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [RemoteAuthService] Invalid HTTP response")
            throw AuthenticationError.networkError
        }

        print("🔄 [RemoteAuthService] Token refresh response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200:
            do {
                let apiResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
                print("✅ [RemoteAuthService] Token refresh successful")
                // Use FitIQCore.AuthToken which automatically parses JWT
                return AuthToken(
                    accessToken: apiResponse.data.accessToken,
                    refreshToken: apiResponse.data.refreshToken
                )
            } catch {
                print("❌ [RemoteAuthService] Failed to decode refresh response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [RemoteAuthService] Response body: \(responseString)")
                }
                throw AuthenticationError.invalidResponse
            }

        case 401:
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [RemoteAuthService] 401 - Token expired or invalid: \(responseString)")

                // Check if the response indicates token was revoked
                if responseString.lowercased().contains("revoked") {
                    print("🚫 [RemoteAuthService] Refresh token has been revoked")
                    throw AuthenticationError.tokenRevoked
                }
            }
            throw AuthenticationError.tokenExpired

        case 400:
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [RemoteAuthService] 400 - Bad request: \(responseString)")
            }
            throw AuthenticationError.invalidResponse

        default:
            if let responseString = String(data: data, encoding: .utf8) {
                print(
                    "❌ [RemoteAuthService] Unexpected status \(httpResponse.statusCode): \(responseString)"
                )
            } else {
                print(
                    "❌ [RemoteAuthService] Unexpected status \(httpResponse.statusCode) with no response body"
                )
            }
            throw AuthenticationError.unknown
        }
    }
}

// MARK: - API Request/Response Models

private struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String
    let dateOfBirth: Date

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case name
        case dateOfBirth = "date_of_birth"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(password, forKey: .password)
        try container.encode(name, forKey: .name)

        // Format date as YYYY-MM-DD per API spec
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: dateOfBirth)
        try container.encode(dateString, forKey: .dateOfBirth)
    }
}

private struct RegisterResponse: Decodable {
    let data: RegisterResponseData

    struct RegisterResponseData: Decodable {
        let userId: UUID
        let email: String
        let name: String
        let createdAt: Date
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case email
            case name
            case createdAt = "created_at"
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct LoginResponse: Decodable {
    let data: LoginResponseData

    struct LoginResponseData: Decodable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct RefreshTokenResponse: Decodable {
    let data: RefreshTokenResponseData

    struct RefreshTokenResponseData: Decodable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }
}
