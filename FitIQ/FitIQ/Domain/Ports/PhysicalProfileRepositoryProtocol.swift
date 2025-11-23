//
//  PhysicalProfileRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Refactoring - Phase 3
//

import Foundation

/// Port (protocol) for physical profile repository operations
///
/// This defines the contract for fetching and updating a user's physical attributes
/// from the backend API endpoint `/api/v1/users/me/physical`.
///
/// **Architecture:** Domain Port (Hexagonal Architecture)
/// - Domain layer defines this interface (port)
/// - Infrastructure layer implements it (adapter)
///
/// **Backend Endpoint:** `/api/v1/users/me/physical`
/// - GET: Not available (physical data included in profile or separate fetch)
/// - PATCH: Update physical attributes
///
/// **Related Models:**
/// - `PhysicalProfile` - Domain entity
/// - `PhysicalProfileResponseDTO` - Infrastructure DTO
///
protocol PhysicalProfileRepositoryProtocol {
    /// Fetches the user's physical profile from the backend
    ///
    /// This calls the backend API to get the user's physical attributes
    /// (biological sex, height, date of birth).
    ///
    /// - Parameter userId: The user's unique identifier
    /// - Returns: PhysicalProfile domain entity
    /// - Throws: APIError if the request fails or profile not found
    func getPhysicalProfile(userId: String) async throws -> PhysicalProfile

    /// Updates the user's physical profile information
    ///
    /// This calls PATCH `/api/v1/users/me/physical` to update physical attributes.
    /// All parameters are optional - only provided values will be updated.
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - biologicalSex: Optional biological sex ("male", "female", "other")
    ///   - heightCm: Optional height in centimeters
    ///   - dateOfBirth: Optional date of birth
    /// - Returns: Updated PhysicalProfile domain entity
    /// - Throws: APIError if the request fails
    func updatePhysicalProfile(
        userId: String,
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile
}
