//
//  AuthRepositoryProtocol.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

// Domain/Ports/AuthRepositoryProtocol.swift
import FitIQCore
import Foundation

/// Port protocol for authentication repository operations
/// Following Hexagonal Architecture - Domain defines the interface, Infrastructure implements it
///
/// **Migration Note:** Now uses FitIQCore.UserProfile (Phase 2.1)
protocol AuthRepositoryProtocol {
    /// Registers a user and returns their profile and auth tokens.
    func register(userData: RegisterUserData) async throws -> (
        profile: FitIQCore.UserProfile, accessToken: String, refreshToken: String
    )

    /// Logs in a user and returns auth tokens.
    func login(credentials: LoginCredentials) async throws -> (
        profile: FitIQCore.UserProfile, accessToken: String, refreshToken: String
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
