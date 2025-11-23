import FitIQCore
// Domain/Ports/UserProfileStoragePortProtocol.swift
import Foundation

/// Defines the contract for storing and retrieving a UserProfile.
/// This is a "port" that the CreateUserUseCase and PerformInitialHealthKitSyncUseCase depend on.
///
/// **Migration Note:** Now uses FitIQCore.UserProfile (Phase 2.1)
public protocol UserProfileStoragePortProtocol {
    /// Saves or updates a user profile.
    /// If a profile with the given `userProfile.id` already exists, it should be updated.
    /// Otherwise, a new profile should be created.
    func save(userProfile: FitIQCore.UserProfile) async throws

    /// Fetches a user profile for a given user ID.
    /// - Parameter userID: The ID of the user profile to fetch.
    /// - Returns: The `UserProfile` if found, or `nil` if not found.
    func fetch(forUserID userID: UUID) async throws -> FitIQCore.UserProfile?

    /// Cleans up duplicate profiles for a specific user ID.
    /// Keeps the most recently updated profile and deletes all others.
    /// - Parameter userID: The user ID to clean up duplicates for
    func cleanupDuplicateProfiles(forUserID userID: UUID) async throws

    /// Cleans up ALL duplicate profiles in the database.
    /// Groups profiles by userId and keeps only the most recent one for each user.
    func cleanupAllDuplicateProfiles() async throws
}
