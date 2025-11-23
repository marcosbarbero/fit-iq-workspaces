//
//  UserProfileRepository.swift
//  lume
//
//  Created by AI Assistant on 30/01/2025.
//

import Foundation
import SwiftData
import FitIQCore

// MARK: - Protocol Definition

protocol UserProfileRepositoryProtocol {
    /// Fetch user profile (from cache or backend)
    func fetchUserProfile(forceRefresh: Bool) async throws -> UserProfile

    /// Update user profile
    func updateUserProfile(request: UpdateUserProfileRequest) async throws -> UserProfile

    /// Update physical profile attributes
    func updatePhysicalProfile(request: UpdatePhysicalProfileRequest) async throws -> UserProfile

    /// Delete user account (GDPR)
    func deleteUserAccount() async throws

    /// Fetch dietary preferences (from cache or backend)
    func fetchPreferences(forceRefresh: Bool) async throws -> DietaryActivityPreferences?

    /// Update dietary preferences
    func updatePreferences(request: UpdatePreferencesRequest) async throws
        -> DietaryActivityPreferences

    /// Delete dietary preferences
    func deletePreferences() async throws

    /// Clear local cache (on logout)
    func clearCache() async throws
}

// MARK: - Implementation

final class UserProfileRepository: UserProfileRepositoryProtocol {
    private let modelContext: ModelContext
    private let backendService: UserProfileBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol

    init(
        modelContext: ModelContext,
        backendService: UserProfileBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.modelContext = modelContext
        self.backendService = backendService
        self.tokenStorage = tokenStorage
    }

    // MARK: - Profile Methods

    func fetchUserProfile(forceRefresh: Bool = false) async throws -> UserProfile {
        print("🔍 [UserProfileRepository] Fetching user profile (forceRefresh: \(forceRefresh))")

        // Get access token
        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Try cache first if not forcing refresh
        if !forceRefresh, let cachedProfile = try? fetchCachedProfile() {
            print("✅ [UserProfileRepository] Returning cached profile: \(cachedProfile.name)")
            return cachedProfile
        }

        // Fetch from backend
        print("🌐 [UserProfileRepository] Fetching from backend...")
        let profile = try await backendService.fetchUserProfile(accessToken: token.accessToken)

        // Save to cache
        try await saveProfileToCache(profile)

        print("✅ [UserProfileRepository] Profile fetched and cached: \(profile.name)")
        return profile
    }

    func updateUserProfile(request: UpdateUserProfileRequest) async throws -> UserProfile {
        print("📝 [UserProfileRepository] Updating user profile: \(request.name)")

        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Update on backend
        let updatedProfile = try await backendService.updateUserProfile(
            request: request,
            accessToken: token.accessToken
        )

        // Update cache
        try await saveProfileToCache(updatedProfile)

        // Update UserSession
        UserSession.shared.updateUserInfo(name: updatedProfile.name)

        print("✅ [UserProfileRepository] Profile updated and cached")
        return updatedProfile
    }

    func updatePhysicalProfile(request: UpdatePhysicalProfileRequest) async throws -> UserProfile {
        print("📝 [UserProfileRepository] Updating physical profile")

        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Update on backend
        let updatedProfile = try await backendService.updatePhysicalProfile(
            request: request,
            accessToken: token.accessToken
        )

        // Update cache
        try await saveProfileToCache(updatedProfile)

        // Update UserSession if date of birth changed
        if let dobString = request.dateOfBirth,
            let dob = ISO8601DateFormatter().date(from: dobString)
        {
            UserSession.shared.updateUserInfo(dateOfBirth: dob)
        }

        print("✅ [UserProfileRepository] Physical profile updated and cached")
        return updatedProfile
    }

    func deleteUserAccount() async throws {
        print("🗑️ [UserProfileRepository] Deleting user account (GDPR)")

        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Delete on backend
        try await backendService.deleteUserAccount(accessToken: token.accessToken)

        // Clear local cache
        try await clearCache()

        // Clear token
        try await tokenStorage.deleteToken()

        // End user session
        UserSession.shared.endSession()

        print("✅ [UserProfileRepository] User account deleted, cache cleared, session ended")
    }

    // MARK: - Preferences Methods

    func fetchPreferences(forceRefresh: Bool = false) async throws -> DietaryActivityPreferences? {
        print(
            "🔍 [UserProfileRepository] Fetching dietary preferences (forceRefresh: \(forceRefresh))"
        )

        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Try cache first if not forcing refresh
        if !forceRefresh, let cachedPreferences = try? fetchCachedPreferences() {
            print("✅ [UserProfileRepository] Returning cached preferences")
            return cachedPreferences
        }

        // Fetch from backend
        do {
            print("🌐 [UserProfileRepository] Fetching preferences from backend...")
            let preferences = try await backendService.fetchPreferences(
                accessToken: token.accessToken)

            // Save to cache
            try await savePreferencesToCache(preferences)

            print("✅ [UserProfileRepository] Preferences fetched and cached")
            return preferences
        } catch {
            // If 404, preferences don't exist yet - return nil
            if let httpError = error as? HTTPError, case .notFound = httpError {
                print("ℹ️ [UserProfileRepository] No preferences found (404)")
                return nil
            }
            throw error
        }
    }

    func updatePreferences(request: UpdatePreferencesRequest) async throws
        -> DietaryActivityPreferences
    {
        print("📝 [UserProfileRepository] Updating dietary preferences")

        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Update on backend
        let updatedPreferences = try await backendService.updatePreferences(
            request: request,
            accessToken: token.accessToken
        )

        // Update cache
        try await savePreferencesToCache(updatedPreferences)

        print("✅ [UserProfileRepository] Preferences updated and cached")
        return updatedPreferences
    }

    func deletePreferences() async throws {
        print("🗑️ [UserProfileRepository] Deleting dietary preferences")

        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw UserProfileRepositoryError.notAuthenticated
        }

        // Delete on backend
        try await backendService.deletePreferences(accessToken: token.accessToken)

        // Clear from cache
        try await clearPreferencesCache()

        print("✅ [UserProfileRepository] Preferences deleted and cache cleared")
    }

    func clearCache() async throws {
        print("🧹 [UserProfileRepository] Clearing all local cache")

        // Clear profile
        let profileDescriptor = FetchDescriptor<SDUserProfile>()
        let profiles = try modelContext.fetch(profileDescriptor)
        for profile in profiles {
            modelContext.delete(profile)
        }

        // Clear preferences
        let preferencesDescriptor = FetchDescriptor<SDDietaryPreferences>()
        let preferences = try modelContext.fetch(preferencesDescriptor)
        for preference in preferences {
            modelContext.delete(preference)
        }

        try modelContext.save()
        print("✅ [UserProfileRepository] Cache cleared")
    }

    // MARK: - Private Helpers

    private func fetchCachedProfile() throws -> UserProfile? {
        let descriptor = FetchDescriptor<SDUserProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let sdProfile = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdProfile.toDomain()
    }

    private func saveProfileToCache(_ profile: UserProfile) async throws {
        // Check if profile exists
        let descriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate { $0.id == profile.id }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            // Update existing
            existing.update(from: profile)
        } else {
            // Insert new
            let sdProfile = SDUserProfile.from(profile)
            modelContext.insert(sdProfile)
        }

        try modelContext.save()
    }

    private func fetchCachedPreferences() throws -> DietaryActivityPreferences? {
        let descriptor = FetchDescriptor<SDDietaryPreferences>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        guard let sdPreferences = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return sdPreferences.toDomain()
    }

    private func savePreferencesToCache(_ preferences: DietaryActivityPreferences) async throws {
        // Check if preferences exist
        let descriptor = FetchDescriptor<SDDietaryPreferences>(
            predicate: #Predicate { $0.id == preferences.id }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            // Update existing
            existing.update(from: preferences)
        } else {
            // Insert new
            let sdPreferences = SDDietaryPreferences.from(preferences)
            modelContext.insert(sdPreferences)
        }

        try modelContext.save()
    }

    private func clearPreferencesCache() async throws {
        let descriptor = FetchDescriptor<SDDietaryPreferences>()
        let preferences = try modelContext.fetch(descriptor)

        for preference in preferences {
            modelContext.delete(preference)
        }

        try modelContext.save()
    }
}

// MARK: - Errors

enum UserProfileRepositoryError: Error, LocalizedError {
    case notAuthenticated
    case profileNotFound
    case saveFailed
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to access profile data"
        case .profileNotFound:
            return "Profile not found"
        case .saveFailed:
            return "Failed to save profile data"
        case .invalidData:
            return "Invalid profile data"
        }
    }
}
