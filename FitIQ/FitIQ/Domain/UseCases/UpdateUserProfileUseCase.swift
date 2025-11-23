//
//  UpdateUserProfileUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

import FitIQCore
import Foundation

// MARK: - Use Case Protocol

/// Defines the contract for updating a user's profile
protocol UpdateUserProfileUseCaseProtocol {
    /// Updates the user's profile information
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - name: Optional name to update
    ///   - dateOfBirth: Optional date of birth to update
    ///   - gender: Optional gender to update
    ///   - height: Optional height in cm to update
    ///   - weight: Optional weight in kg to update
    ///   - activityLevel: Optional activity level to update
    /// - Returns: Updated UserProfile domain entity
    /// - Throws: Error if the operation fails
    func execute(
        userId: String,
        name: String?,
        dateOfBirth: Date?,
        gender: String?,
        height: Double?,
        weight: Double?,
        activityLevel: String?
    ) async throws -> FitIQCore.UserProfile
}

// MARK: - Use Case Implementation

/// Handles the business logic for updating a user's profile
final class UpdateUserProfileUseCase: UpdateUserProfileUseCaseProtocol {

    // MARK: - Dependencies

    private let userProfileRepository: UserProfileRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol

    // MARK: - Initialization

    init(
        userProfileRepository: UserProfileRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol
    ) {
        self.userProfileRepository = userProfileRepository
        self.userProfileStorage = userProfileStorage
    }

    // MARK: - Execute

    /// Updates the user's profile
    func execute(
        userId: String,
        name: String?,
        dateOfBirth: Date?,
        gender: String?,
        height: Double?,
        weight: Double?,
        activityLevel: String?
    ) async throws -> FitIQCore.UserProfile {
        print("UpdateUserProfileUseCase: Updating profile for user: \(userId)")

        // Validation
        if let name = name, name.isEmpty {
            throw ValidationError.emptyName
        }

        if let height = height {
            guard height >= 50 && height <= 300 else {
                throw ValidationError.invalidHeight
            }
        }

        if let weight = weight {
            guard weight >= 20 && weight <= 500 else {
                throw ValidationError.invalidWeight
            }
        }

        if let gender = gender {
            guard ["male", "female", "other"].contains(gender.lowercased()) else {
                throw ValidationError.invalidGender
            }
        }

        if let activityLevel = activityLevel {
            let validLevels = ["sedentary", "light", "moderate", "active", "very_active"]
            guard validLevels.contains(activityLevel.lowercased()) else {
                throw ValidationError.invalidActivityLevel
            }
        }

        do {
            // Update profile via repository
            let updatedProfile = try await userProfileRepository.updateProfile(
                userId: userId,
                name: name,
                dateOfBirth: dateOfBirth,
                gender: gender,
                height: height,
                weight: weight,
                activityLevel: activityLevel
            )

            // Save updated profile to local storage
            try await userProfileStorage.save(userProfile: updatedProfile)

            print("UpdateUserProfileUseCase: Successfully updated profile")
            return updatedProfile
        } catch {
            print(
                "UpdateUserProfileUseCase: Failed to update profile: \(error.localizedDescription)"
            )
            throw error
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: Error, LocalizedError {
    case emptyName
    case invalidHeight
    case invalidWeight
    case invalidGender
    case invalidActivityLevel

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name cannot be empty"
        case .invalidHeight:
            return "Height must be between 50 and 300 cm"
        case .invalidWeight:
            return "Weight must be between 20 and 500 kg"
        case .invalidGender:
            return "Gender must be male, female, or other"
        case .invalidActivityLevel:
            return "Invalid activity level selected"
        }
    }
}
