//
//  ProfileViewModel.swift
//  lume
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import SwiftUI

/// ViewModel for user profile management
/// Handles fetching, updating profile data and dietary preferences
@MainActor
@Observable
final class ProfileViewModel {

    // MARK: - Published State

    var profile: UserProfile?
    var preferences: DietaryActivityPreferences?

    var isLoadingProfile = false
    var isLoadingPreferences = false
    var isSavingProfile = false
    var isSavingPreferences = false
    var isDeletingAccount = false

    var errorMessage: String?
    var showingError = false

    var successMessage: String?
    var showingSuccess = false

    // MARK: - Dependencies

    private let repository: UserProfileRepositoryProtocol

    // MARK: - Initialization

    init(repository: UserProfileRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Profile Methods

    /// Load user profile (with optional force refresh)
    func loadProfile(forceRefresh: Bool = false) async {
        guard !isLoadingProfile else { return }

        isLoadingProfile = true
        errorMessage = nil

        do {
            profile = try await repository.fetchUserProfile(forceRefresh: forceRefresh)
            print("✅ [ProfileViewModel] Profile loaded: \(profile?.name ?? "Unknown")")
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to load profile: \(error)")
        }

        isLoadingProfile = false
    }

    /// Update basic profile information
    func updateProfile(name: String, bio: String?, unitSystem: UnitSystem, languageCode: String)
        async
    {
        guard !isSavingProfile else { return }

        isSavingProfile = true
        errorMessage = nil

        let request = UpdateUserProfileRequest(
            name: name,
            bio: bio,
            preferredUnitSystem: unitSystem,
            languageCode: languageCode
        )

        do {
            profile = try await repository.updateUserProfile(request: request)
            successMessage = "Profile updated successfully"
            showingSuccess = true
            print("✅ [ProfileViewModel] Profile updated")
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to update profile: \(error)")
        }

        isSavingProfile = false
    }

    /// Update physical profile attributes
    func updatePhysicalProfile(
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async {
        guard !isSavingProfile else { return }

        isSavingProfile = true
        errorMessage = nil

        // Convert date to ISO8601 string if provided
        let dobString: String?
        if let dob = dateOfBirth {
            let formatter = ISO8601DateFormatter()
            dobString = formatter.string(from: dob)
        } else {
            dobString = nil
        }

        let request = UpdatePhysicalProfileRequest(
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            dateOfBirth: dobString
        )

        do {
            profile = try await repository.updatePhysicalProfile(request: request)
            successMessage = "Physical profile updated successfully"
            showingSuccess = true
            print("✅ [ProfileViewModel] Physical profile updated")
        } catch {
            errorMessage = "Failed to update physical profile: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to update physical profile: \(error)")
        }

        isSavingProfile = false
    }

    // MARK: - Preferences Methods

    /// Load dietary preferences
    func loadPreferences(forceRefresh: Bool = false) async {
        guard !isLoadingPreferences else { return }

        isLoadingPreferences = true
        errorMessage = nil

        do {
            preferences = try await repository.fetchPreferences(forceRefresh: forceRefresh)
            print("✅ [ProfileViewModel] Preferences loaded")
        } catch {
            errorMessage = "Failed to load preferences: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to load preferences: \(error)")
        }

        isLoadingPreferences = false
    }

    /// Update dietary preferences
    func updatePreferences(
        allergies: [String],
        dietaryRestrictions: [String],
        foodDislikes: [String]
    ) async {
        guard !isSavingPreferences else { return }

        isSavingPreferences = true
        errorMessage = nil

        let request = UpdatePreferencesRequest(
            allergies: allergies.isEmpty ? nil : allergies,
            dietaryRestrictions: dietaryRestrictions.isEmpty ? nil : dietaryRestrictions,
            foodDislikes: foodDislikes.isEmpty ? nil : foodDislikes
        )

        do {
            preferences = try await repository.updatePreferences(request: request)
            successMessage = "Preferences updated successfully"
            showingSuccess = true
            print("✅ [ProfileViewModel] Preferences updated")
        } catch {
            errorMessage = "Failed to update preferences: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to update preferences: \(error)")
        }

        isSavingPreferences = false
    }

    /// Delete dietary preferences
    func deletePreferences() async {
        guard !isSavingPreferences else { return }

        isSavingPreferences = true
        errorMessage = nil

        do {
            try await repository.deletePreferences()
            preferences = nil
            successMessage = "Preferences deleted successfully"
            showingSuccess = true
            print("✅ [ProfileViewModel] Preferences deleted")
        } catch {
            errorMessage = "Failed to delete preferences: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to delete preferences: \(error)")
        }

        isSavingPreferences = false
    }

    // MARK: - Account Deletion

    /// Delete user account (GDPR compliance)
    func deleteAccount() async -> Bool {
        guard !isDeletingAccount else { return false }

        isDeletingAccount = true
        errorMessage = nil

        do {
            try await repository.deleteUserAccount()
            print("✅ [ProfileViewModel] Account deleted")
            isDeletingAccount = false
            return true
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            showingError = true
            print("❌ [ProfileViewModel] Failed to delete account: \(error)")
            isDeletingAccount = false
            return false
        }
    }

    // MARK: - Helper Methods

    /// Clear error state
    func clearError() {
        errorMessage = nil
        showingError = false
    }

    /// Clear success state
    func clearSuccess() {
        successMessage = nil
        showingSuccess = false
    }

    /// Refresh all data
    func refreshAll() async {
        await loadProfile(forceRefresh: true)
        await loadPreferences(forceRefresh: true)
    }
}
