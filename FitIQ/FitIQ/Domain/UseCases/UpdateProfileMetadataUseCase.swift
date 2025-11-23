//
//  UpdateProfileMetadataUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Edit Implementation
//

import Foundation

// MARK: - Use Case Protocol

/// Protocol for updating user profile metadata
///
/// This use case handles updating profile information (name, bio, preferences)
/// separate from physical attributes.
///
/// **Architecture:** Domain Use Case (Primary Port - Hexagonal Architecture)
///
/// **Backend Endpoint:** PUT `/api/v1/users/me`
///
/// **Related Models:**
/// - `UserProfileMetadata` - Domain entity
/// - `UserProfileStoragePortProtocol` - Local storage port
/// - `ProfileEventPublisherProtocol` - Event publisher port
///
protocol UpdateProfileMetadataUseCase {
    /// Updates the user's profile metadata
    ///
    /// All parameters except userId are optional - only provided values will be updated.
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier (required)
    ///   - name: Full name (optional)
    ///   - bio: Biography/description (optional)
    ///   - preferredUnitSystem: "metric" or "imperial" (optional)
    ///   - languageCode: ISO 639-1 language code (optional)
    /// - Returns: Updated UserProfile with new metadata
    /// - Throws: Error if validation fails or update fails
    func execute(
        userId: String,
        name: String?,
        bio: String?,
        preferredUnitSystem: String?,
        languageCode: String?
    ) async throws -> UserProfile
}

// MARK: - Use Case Implementation

/// Implementation of UpdateProfileMetadataUseCase with event publishing
///
/// This use case:
/// 1. Validates input data
/// 2. Updates local storage (offline-first)
/// 3. Publishes domain event for sync
/// 4. Returns updated profile
///
final class UpdateProfileMetadataUseCaseImpl: UpdateProfileMetadataUseCase {

    // MARK: - Dependencies

    private let userProfileStorage: UserProfileStoragePortProtocol
    private let eventPublisher: ProfileEventPublisherProtocol

    // MARK: - Initialization

    init(
        userProfileStorage: UserProfileStoragePortProtocol,
        eventPublisher: ProfileEventPublisherProtocol
    ) {
        self.userProfileStorage = userProfileStorage
        self.eventPublisher = eventPublisher
    }

    // MARK: - Use Case Execution

    func execute(
        userId: String,
        name: String?,
        bio: String?,
        preferredUnitSystem: String?,
        languageCode: String?
    ) async throws -> UserProfile {
        print("UpdateProfileMetadataUseCase: Executing for userId: \(userId)")

        // Validate user ID
        guard let userUUID = UUID(uuidString: userId) else {
            throw MetadataUpdateValidationError.invalidUserId(userId)
        }

        // Validate at least one field is provided
        guard name != nil || bio != nil || preferredUnitSystem != nil || languageCode != nil else {
            throw MetadataUpdateValidationError.noFieldsProvided
        }

        // Validate name if provided
        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty else {
                throw MetadataUpdateValidationError.emptyName
            }
            guard trimmedName.count <= 100 else {
                throw MetadataUpdateValidationError.nameTooLong
            }
        }

        // Validate bio if provided
        if let bio = bio, !bio.isEmpty {
            guard bio.count <= 500 else {
                throw MetadataUpdateValidationError.bioTooLong
            }
        }

        // Validate unit system if provided
        if let unitSystem = preferredUnitSystem {
            let validSystems = ["metric", "imperial"]
            guard validSystems.contains(unitSystem.lowercased()) else {
                throw MetadataUpdateValidationError.invalidUnitSystem(unitSystem)
            }
        }

        // Validate language code if provided
        if let languageCode = languageCode, !languageCode.isEmpty {
            guard (2...3).contains(languageCode.count) else {
                throw MetadataUpdateValidationError.invalidLanguageCode(languageCode)
            }
        }

        // Fetch current profile
        let currentProfile = try await userProfileStorage.fetch(forUserID: userUUID)

        guard let currentProfile = currentProfile else {
            throw MetadataUpdateValidationError.profileNotFound(userId)
        }

        // Create updated metadata by merging new values with existing
        let updatedMetadata = UserProfileMetadata(
            id: currentProfile.metadata.id,
            userId: currentProfile.metadata.userId,
            name: name ?? currentProfile.metadata.name,
            bio: bio ?? currentProfile.metadata.bio,
            preferredUnitSystem: preferredUnitSystem ?? currentProfile.metadata.preferredUnitSystem,
            languageCode: languageCode ?? currentProfile.metadata.languageCode,
            dateOfBirth: currentProfile.metadata.dateOfBirth,
            createdAt: currentProfile.metadata.createdAt,
            updatedAt: Date()  // Update timestamp
        )

        // Validate the updated metadata
        let validationErrors = updatedMetadata.validate()
        guard validationErrors.isEmpty else {
            throw MetadataUpdateValidationError.validationFailed(validationErrors)
        }

        // Create updated profile with new metadata
        let updatedProfile = currentProfile.updatingMetadata(updatedMetadata)

        // Save to local storage (offline-first)
        do {
            try await userProfileStorage.save(userProfile: updatedProfile)
            print("UpdateProfileMetadataUseCase: Successfully saved updated metadata locally")
        } catch {
            print("UpdateProfileMetadataUseCase: Failed to save metadata: \(error)")
            throw MetadataUpdateValidationError.saveFailed(error)
        }

        // Publish domain event for sync
        let event = ProfileEvent.metadataUpdated(
            userId: userId,
            timestamp: Date()
        )
        eventPublisher.publish(event: event)
        print("UpdateProfileMetadataUseCase: Published metadataUpdated event")

        return updatedProfile
    }
}

// MARK: - Validation Errors

/// Validation errors specific to profile metadata updates
enum MetadataUpdateValidationError: Error, LocalizedError {
    case invalidUserId(String)
    case noFieldsProvided
    case emptyName
    case nameTooLong
    case bioTooLong
    case invalidUnitSystem(String)
    case invalidLanguageCode(String)
    case profileNotFound(String)
    case validationFailed([UserProfileMetadata.ValidationError])
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUserId(let id):
            return "Invalid user ID format: \(id)"
        case .noFieldsProvided:
            return "At least one field must be provided for update"
        case .emptyName:
            return "Name cannot be empty"
        case .nameTooLong:
            return "Name is too long (maximum 100 characters)"
        case .bioTooLong:
            return "Bio is too long (maximum 500 characters)"
        case .invalidUnitSystem(let system):
            return "Invalid unit system: \(system). Must be 'metric' or 'imperial'"
        case .invalidLanguageCode(let code):
            return "Invalid language code: \(code). Must be 2-3 characters"
        case .profileNotFound(let userId):
            return "Profile not found for user: \(userId)"
        case .validationFailed(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
            return "Validation failed: \(errorMessages)"
        case .saveFailed(let error):
            return "Failed to save profile: \(error.localizedDescription)"
        }
    }
}
