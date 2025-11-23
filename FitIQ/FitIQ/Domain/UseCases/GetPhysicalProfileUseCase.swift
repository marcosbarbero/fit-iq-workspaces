//
//  GetPhysicalProfileUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Refactoring - Phase 4
//

import Foundation

/// Use case protocol for fetching a user's physical profile
///
/// This defines the contract for retrieving physical attributes
/// (biological sex, height, date of birth) from local storage.
///
/// **Architecture:** Domain Use Case (Hexagonal Architecture)
/// - Primary port (application boundary)
/// - Depends on UserProfileStoragePortProtocol (secondary port)
///
/// **Local-First Architecture:**
/// - Reads from local storage (source of truth)
/// - Does NOT fetch from backend
/// - Backend sync happens asynchronously in background
///
/// **Related Models:**
/// - `PhysicalProfile` - Domain entity
/// - `UserProfileStoragePortProtocol` - Local storage interface
///
protocol GetPhysicalProfileUseCase {
    /// Fetches the user's physical profile from local storage
    ///
    /// - Parameter userId: The user's unique identifier
    /// - Returns: PhysicalProfile domain entity (nil if not set)
    /// - Throws: Error if fetch fails or profile not found
    func execute(userId: String) async throws -> PhysicalProfile?
}

/// Implementation of GetPhysicalProfileUseCase
///
/// **Local-First Architecture:**
/// This use case reads from local storage (SwiftData) as the single source of truth.
/// Backend sync happens asynchronously via ProfileSyncService.
///
final class GetPhysicalProfileUseCaseImpl: GetPhysicalProfileUseCase {

    // MARK: - Dependencies

    private let userProfileStorage: UserProfileStoragePortProtocol

    // MARK: - Initialization

    init(userProfileStorage: UserProfileStoragePortProtocol) {
        self.userProfileStorage = userProfileStorage
    }

    // MARK: - Use Case Execution

    func execute(userId: String) async throws -> PhysicalProfile? {
        print("GetPhysicalProfileUseCase: Executing for userId: \(userId)")

        // Validate userId
        guard !userId.isEmpty else {
            throw PhysicalProfileValidationError.emptyUserId
        }

        // Convert to UUID
        guard let userUUID = UUID(uuidString: userId) else {
            throw PhysicalProfileValidationError.invalidUserId(userId)
        }

        // Fetch from local storage (source of truth)
        do {
            let profile = try await userProfileStorage.fetch(forUserID: userUUID)

            guard let profile = profile else {
                print("GetPhysicalProfileUseCase: Profile not found for userId: \(userId)")
                throw PhysicalProfileValidationError.profileNotFound(userId)
            }

            // Return physical profile (may be nil if not set)
            let physicalProfile = profile.physical

            if physicalProfile != nil {
                print(
                    "GetPhysicalProfileUseCase: Successfully fetched physical profile from local storage"
                )
            } else {
                print("GetPhysicalProfileUseCase: Physical profile not set for user")
            }

            return physicalProfile
        } catch {
            print("GetPhysicalProfileUseCase: Failed to fetch physical profile: \(error)")
            throw error
        }
    }
}

// MARK: - Validation Errors

/// Validation errors specific to physical profile fetching
enum PhysicalProfileValidationError: Error, LocalizedError {
    case emptyUserId
    case invalidUserId(String)
    case profileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .emptyUserId:
            return "User ID cannot be empty"
        case .invalidUserId(let id):
            return "Invalid user ID format: \(id)"
        case .profileNotFound(let userId):
            return "Profile not found for user: \(userId)"
        }
    }
}
