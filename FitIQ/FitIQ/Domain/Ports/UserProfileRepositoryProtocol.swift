//
//  UserProfileRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Port protocol for user profile repository operations
/// Following Hexagonal Architecture - Domain defines the interface, Infrastructure implements it
protocol UserProfileRepositoryProtocol {
    /// Fetches the user profile for a given user ID from the backend
    /// - Parameter userId: The user's unique identifier
    /// - Returns: UserProfile domain entity
    /// - Throws: APIError if the request fails
    func getUserProfile(userId: String) async throws -> UserProfile

    /// Updates the user's profile information (DEPRECATED - use updateProfileMetadata instead)
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - name: Optional name to update
    ///   - dateOfBirth: Optional date of birth to update
    ///   - gender: Optional gender to update
    ///   - height: Optional height in cm to update
    ///   - weight: Optional weight in kg to update
    ///   - activityLevel: Optional activity level to update
    /// - Returns: Updated UserProfile domain entity
    /// - Throws: APIError if the request fails
    func updateProfile(
        userId: String,
        name: String?,
        dateOfBirth: Date?,
        gender: String?,
        height: Double?,
        weight: Double?,
        activityLevel: String?
    ) async throws -> UserProfile

    /// Updates the user's profile metadata using the new API structure
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - name: Full name (required)
    ///   - bio: Biography/description (optional)
    ///   - preferredUnitSystem: "metric" or "imperial" (required)
    ///   - languageCode: ISO 639-1 language code (optional)
    /// - Returns: Updated UserProfile domain entity
    /// - Throws: APIError if the request fails
    func updateProfileMetadata(
        userId: String,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?
    ) async throws -> UserProfile
}
