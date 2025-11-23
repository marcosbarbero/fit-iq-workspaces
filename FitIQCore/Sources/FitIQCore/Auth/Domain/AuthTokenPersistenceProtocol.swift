//
//  AuthTokenPersistenceProtocol.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Defines the contract for persisting, retrieving, and removing authentication tokens, user profile ID, and user profile data.
/// This is a domain port that authentication components depend on.
public protocol AuthTokenPersistenceProtocol {
    /// Saves access and refresh tokens to persistent storage
    /// - Parameters:
    ///   - accessToken: The JWT access token
    ///   - refreshToken: The JWT refresh token
    /// - Throws: Error if save operation fails
    func save(accessToken: String, refreshToken: String) throws

    /// Fetches the stored access token
    /// - Returns: The access token if available, nil otherwise
    /// - Throws: Error if fetch operation fails
    func fetchAccessToken() throws -> String?

    /// Fetches the stored refresh token
    /// - Returns: The refresh token if available, nil otherwise
    /// - Throws: Error if fetch operation fails
    func fetchRefreshToken() throws -> String?

    /// Deletes both access and refresh tokens from persistent storage
    /// - Throws: Error if delete operation fails
    func deleteTokens() throws

    /// Saves the user profile ID to persistent storage
    /// - Parameter userID: The user's unique identifier
    /// - Throws: Error if save operation fails
    func saveUserProfileID(_ userID: UUID) throws

    /// Fetches the stored user profile ID
    /// - Returns: The user profile ID if available, nil otherwise
    /// - Throws: Error if fetch operation fails
    func fetchUserProfileID() throws -> UUID?

    /// Deletes the user profile ID from persistent storage
    /// - Throws: Error if delete operation fails
    func deleteUserProfileID() throws

    /// Saves the user profile to persistent storage
    /// - Parameter profile: The user profile to save
    /// - Throws: Error if save operation fails
    func saveUserProfile(_ profile: UserProfile) throws

    /// Fetches the stored user profile
    /// - Returns: The user profile if available, nil otherwise
    /// - Throws: Error if fetch operation fails
    func fetchUserProfile() throws -> UserProfile?

    /// Deletes the user profile from persistent storage
    /// - Throws: Error if delete operation fails
    func deleteUserProfile() throws
}
