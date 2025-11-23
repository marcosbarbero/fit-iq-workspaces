// Domain/Ports/AuthTokenPersistencePortProtocol.swift
import Foundation

/// Defines the contract for persisting, retrieving, and removing authentication tokens and user profile ID.
/// This is a "port" that the CreateUserUseCase, AuthManager, and AuthRepositoryProtocol implementations depend on.
public protocol AuthTokenPersistencePortProtocol {
    func save(accessToken: String, refreshToken: String) throws
    func fetchAccessToken() throws -> String?    // NEW: Fetch access token
    func fetchRefreshToken() throws -> String?   // NEW: Fetch refresh token
    func deleteTokens() throws
    
    func saveUserProfileID(_ userID: UUID) throws
    func fetchUserProfileID() throws -> UUID?
    func deleteUserProfileID() throws
}

