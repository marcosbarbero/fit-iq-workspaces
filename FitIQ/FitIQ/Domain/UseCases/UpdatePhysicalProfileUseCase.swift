//
//  UpdatePhysicalProfileUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Updated on 27/01/2025 - Biological Sex and Height Improvements
//  Part of Profile Refactoring - Phase 4
//

import Foundation

/// Use case protocol for updating a user's physical profile
///
/// This defines the contract for updating physical attributes (height, date of birth)
/// following local-first architecture.
///
/// **IMPORTANT:** Biological sex is NEVER updated via this use case.
/// It is ONLY updated from HealthKit via SyncBiologicalSexFromHealthKitUseCase.
///
/// **Architecture:** Domain Use Case (Hexagonal Architecture)
/// - Primary port (application boundary)
/// - Saves to local storage FIRST (source of truth)
/// - Publishes event for async backend sync
/// - Logs height changes to progress endpoint for time-series tracking
///
/// **Backend Endpoints:**
/// - PATCH `/api/v1/users/me/physical` (via async sync) - Current values
/// - POST `/api/v1/progress` (type: height) - Historical tracking
///
/// **Related Models:**
/// - `PhysicalProfile` - Domain entity
/// - `UserProfileStoragePortProtocol` - Local storage port
/// - `ProfileEventPublisherProtocol` - Event publisher port
/// - `LogHeightProgressUseCase` - Height time-series tracking
///
protocol UpdatePhysicalProfileUseCase {
    /// Updates the user's physical profile (height and date of birth only)
    ///
    /// **CRITICAL:** Biological sex is NEVER updated here. It's managed by HealthKit only.
    ///
    /// All parameters are optional - only provided values will be updated.
    /// Height changes are automatically logged to the progress endpoint for time-series tracking.
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - heightCm: Optional height in centimeters
    ///   - dateOfBirth: Optional date of birth
    /// - Returns: Updated PhysicalProfile domain entity
    /// - Throws: Error if validation fails or update fails
    func execute(
        userId: String,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile
}

/// Implementation of UpdatePhysicalProfileUseCase
///
/// **Local-First Architecture:**
/// 1. Validates input data
/// 2. Detects height changes for progress logging
/// 3. Updates local storage FIRST (offline-first)
/// 4. Logs height changes to progress endpoint (time-series)
/// 5. Publishes domain event for async backend sync
/// 6. Returns updated profile immediately
///
/// The backend sync happens asynchronously via ProfileSyncService.
///
/// **Biological Sex:** Never modified here - preserved from existing profile.
/// Only HealthKit can update biological sex via SyncBiologicalSexFromHealthKitUseCase.
///
final class UpdatePhysicalProfileUseCaseImpl: UpdatePhysicalProfileUseCase {

    // MARK: - Dependencies

    private let userProfileStorage: UserProfileStoragePortProtocol
    private let eventPublisher: ProfileEventPublisherProtocol
    private let logHeightProgressUseCase: LogHeightProgressUseCase?

    // MARK: - Initialization

    init(
        userProfileStorage: UserProfileStoragePortProtocol,
        eventPublisher: ProfileEventPublisherProtocol,
        logHeightProgressUseCase: LogHeightProgressUseCase? = nil
    ) {
        self.userProfileStorage = userProfileStorage
        self.eventPublisher = eventPublisher
        self.logHeightProgressUseCase = logHeightProgressUseCase
    }

    // MARK: - Use Case Execution

    func execute(
        userId: String,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile {
        print("UpdatePhysicalProfileUseCase: ===== EXECUTE START =====")
        print("UpdatePhysicalProfileUseCase: User ID: \(userId)")
        print("UpdatePhysicalProfileUseCase: Height: \(heightCm?.description ?? "nil") cm")
        print("UpdatePhysicalProfileUseCase: DOB: \(dateOfBirth?.description ?? "nil")")

        // Validate at least one field is provided
        guard heightCm != nil || dateOfBirth != nil else {
            throw PhysicalProfileUpdateValidationError.noFieldsProvided
        }

        // Validate height if provided
        if let height = heightCm {
            guard height > 0 else {
                throw PhysicalProfileUpdateValidationError.invalidHeight(height)
            }
            guard height >= 50 && height <= 300 else {
                throw PhysicalProfileUpdateValidationError.heightOutOfRange(height)
            }
        }

        // Validate date of birth if provided
        if let dob = dateOfBirth {
            guard dob < Date() else {
                throw PhysicalProfileUpdateValidationError.dateOfBirthInFuture
            }

            // Validate minimum age (e.g., 13 years old)
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
            if let age = ageComponents.year, age < 13 {
                throw PhysicalProfileUpdateValidationError.tooYoung(age)
            }
        }

        // Validate user ID
        guard let userUUID = UUID(uuidString: userId) else {
            throw PhysicalProfileUpdateValidationError.invalidUserId(userId)
        }

        // Fetch current profile
        let currentProfile = try await userProfileStorage.fetch(forUserID: userUUID)

        guard let currentProfile = currentProfile else {
            throw PhysicalProfileUpdateValidationError.profileNotFound(userId)
        }

        // Create updated physical profile by merging new values with existing
        // CRITICAL: Biological sex is NEVER updated here - always preserved from existing profile
        let currentPhysical = currentProfile.physical ?? PhysicalProfile.empty
        let oldHeight = currentPhysical.heightCm

        print(
            "UpdatePhysicalProfileUseCase: Current biological sex: \(currentPhysical.biologicalSex ?? "nil")"
        )
        print("UpdatePhysicalProfileUseCase: Current height: \(oldHeight?.description ?? "nil") cm")

        let updatedPhysicalProfile = PhysicalProfile(
            biologicalSex: currentPhysical.biologicalSex,  // Always preserve existing value
            heightCm: heightCm ?? currentPhysical.heightCm,
            dateOfBirth: dateOfBirth ?? currentPhysical.dateOfBirth
        )

        print(
            "UpdatePhysicalProfileUseCase: Updated biological sex: \(updatedPhysicalProfile.biologicalSex ?? "nil") (unchanged)"
        )
        print(
            "UpdatePhysicalProfileUseCase: Updated height: \(updatedPhysicalProfile.heightCm?.description ?? "nil") cm"
        )

        // Validate the updated physical profile
        let validationErrors = updatedPhysicalProfile.validate()
        guard validationErrors.isEmpty else {
            throw PhysicalProfileUpdateValidationError.validationFailed(validationErrors)
        }

        // Update the full user profile with new physical data
        let updatedProfile = currentProfile.updatingPhysical(updatedPhysicalProfile)

        // Save to local storage FIRST (offline-first, local as source of truth)
        do {
            try await userProfileStorage.save(userProfile: updatedProfile)
            print("UpdatePhysicalProfileUseCase: ✅ Saved updated physical profile locally")
        } catch {
            print("UpdatePhysicalProfileUseCase: ❌ Failed to save physical profile: \(error)")
            throw PhysicalProfileUpdateValidationError.saveFailed(error)
        }

        // Log height change to progress endpoint for time-series tracking
        if let newHeight = heightCm,
            let oldHeight = oldHeight,
            newHeight != oldHeight,
            let progressUseCase = logHeightProgressUseCase
        {
            print("UpdatePhysicalProfileUseCase: 📊 Height changed: \(oldHeight) → \(newHeight) cm")
            print(
                "UpdatePhysicalProfileUseCase: Logging to progress endpoint for time-series tracking"
            )
            do {
                let progressEntry = try await progressUseCase.execute(
                    userId: userId,
                    heightCm: newHeight,
                    loggedAt: Date(),
                    notes: "Updated in profile"
                )
                print(
                    "UpdatePhysicalProfileUseCase: ✅ Height logged to progress: \(progressEntry.id)"
                )
            } catch {
                print(
                    "UpdatePhysicalProfileUseCase: ⚠️ Failed to log height progress: \(error.localizedDescription)"
                )
                // Don't fail the whole operation if progress logging fails
            }
        } else if let newHeight = heightCm, oldHeight == nil {
            // First time setting height
            if let progressUseCase = logHeightProgressUseCase {
                print("UpdatePhysicalProfileUseCase: 📊 First height entry: \(newHeight) cm")
                print("UpdatePhysicalProfileUseCase: Logging to progress endpoint")
                do {
                    let progressEntry = try await progressUseCase.execute(
                        userId: userId,
                        heightCm: newHeight,
                        loggedAt: Date(),
                        notes: "Initial height entry"
                    )
                    print(
                        "UpdatePhysicalProfileUseCase: ✅ Initial height logged to progress: \(progressEntry.id)"
                    )
                } catch {
                    print(
                        "UpdatePhysicalProfileUseCase: ⚠️ Failed to log initial height: \(error.localizedDescription)"
                    )
                }
            }
        }

        // Publish domain event for async backend sync
        let event = ProfileEvent.physicalProfileUpdated(
            userId: userId,
            timestamp: Date()
        )
        eventPublisher.publish(event: event)
        print("UpdatePhysicalProfileUseCase: Published physicalProfileUpdated event for async sync")

        print("UpdatePhysicalProfileUseCase: ===== EXECUTE COMPLETE =====")
        return updatedPhysicalProfile
    }
}

// MARK: - Validation Errors

/// Validation errors specific to physical profile updates
enum PhysicalProfileUpdateValidationError: Error, LocalizedError {
    case invalidUserId(String)
    case noFieldsProvided
    case invalidHeight(Double)
    case heightOutOfRange(Double)
    case dateOfBirthInFuture
    case tooYoung(Int)
    case profileNotFound(String)
    case validationFailed([PhysicalProfile.ValidationError])
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUserId(let id):
            return "Invalid user ID format: \(id)"
        case .noFieldsProvided:
            return "At least one field (height or date of birth) must be provided for update"
        case .invalidHeight(let value):
            return "Invalid height: \(value). Height must be positive"
        case .heightOutOfRange(let value):
            return "Height out of range: \(value) cm. Must be between 50 and 300 cm"
        case .dateOfBirthInFuture:
            return "Date of birth cannot be in the future"
        case .tooYoung(let age):
            return "User must be at least 13 years old. Current age: \(age)"
        case .profileNotFound(let userId):
            return "Profile not found for user: \(userId)"
        case .validationFailed(let errors):
            let errorMessages = errors.map { $0.localizedDescription }.joined(separator: ", ")
            return "Validation failed: \(errorMessages)"
        case .saveFailed(let error):
            return "Failed to save physical profile: \(error.localizedDescription)"
        }
    }
}
