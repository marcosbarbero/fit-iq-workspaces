//
//  AuthRepositoryProtocol.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

// Domain/Ports/AuthRepositoryProtocol.swift
import Foundation

protocol AuthRepositoryProtocol {
    /// Registers a user and returns their profile and auth tokens.
    func register(userData: RegisterUserData) async throws -> (
        profile: UserProfile, accessToken: String, refreshToken: String
    )

    /// Logs in a user and returns auth tokens.
    func login(credentials: LoginCredentials) async throws -> (
        profile: UserProfile, accessToken: String, refreshToken: String
    )

    func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse

    func performAuthenticatedRequest<T: Decodable>(url: URL, httpMethod: String, body: Encodable?)
        async throws -> T

}

// Data Transfer Objects (DTOs) for the Core (Use Case Input)
// These are clean, domain-specific structs, NOT coupled to API naming conventions.
struct RegisterUserData {
    let email: String
    let name: String
    let password: String
    let dateOfBirth: Date
}
struct LoginCredentials {
    let email: String
    let password: String
}
