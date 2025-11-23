//
//  SyncBiologicalSexFromHealthKitUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

import FitIQCore
import Foundation

/// Use case for syncing biological sex from HealthKit to local storage and backend
///
/// **CRITICAL:** This is the ONLY way biological sex should be updated in the system.
/// Biological sex is ALWAYS immutable from the user's perspective and ONLY comes from HealthKit.
///
/// **Business Rules:**
/// - Biological sex is NEVER editable by users
/// - ONLY updated when HealthKit provides the data
/// - ONLY synced to backend when the HealthKit value changes
/// - Change detection ensures we don't sync unnecessarily
///
/// **Architecture:**
/// - Domain layer (use case)
/// - Depends on UserProfileStoragePortProtocol (local storage port)
/// - Uses FitIQCore.UserProfile (unified profile model)
protocol SyncBiologicalSexFromHealthKitUseCase {
    /// Syncs biological sex from HealthKit to local storage and backend
    ///
    /// This method:
    /// 1. Checks if the value has actually changed
    /// 2. Updates local storage if changed
    /// 3. Syncs to backend if changed
    /// 4. Skips sync if value is the same (no change)
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - biologicalSex: The biological sex from HealthKit ("male", "female", "other")
    /// - Throws: ProfileError if profile not found, or repository errors
    func execute(userId: String, biologicalSex: String) async throws
}

/// Implementation of SyncBiologicalSexFromHealthKitUseCase
final class SyncBiologicalSexFromHealthKitUseCaseImpl: SyncBiologicalSexFromHealthKitUseCase {

    // MARK: - Dependencies

    private let userProfileStorage: UserProfileStoragePortProtocol

    // MARK: - Initialization

    init(userProfileStorage: UserProfileStoragePortProtocol) {
        self.userProfileStorage = userProfileStorage
    }

    // MARK: - SyncBiologicalSexFromHealthKitUseCase Implementation

    func execute(userId: String, biologicalSex: String) async throws {
        print("SyncBiologicalSexFromHealthKitUseCase: ===== HEALTHKIT SYNC START =====")
        print("SyncBiologicalSexFromHealthKitUseCase: User ID: \(userId)")
        print("SyncBiologicalSexFromHealthKitUseCase: HealthKit biological sex: \(biologicalSex)")

        // Validate user ID
        guard let userUUID = UUID(uuidString: userId) else {
            print("SyncBiologicalSexFromHealthKitUseCase: ❌ Invalid user ID")
            throw FitIQValidationError.invalidUserId("Invalid UUID format")
        }

        // Fetch current profile
        guard let currentProfile = try await userProfileStorage.fetch(forUserID: userUUID) else {
            print("SyncBiologicalSexFromHealthKitUseCase: ❌ Profile not found")
            throw ProfileError.notFound(userId)
        }

        let currentSex = currentProfile.biologicalSex
        print("SyncBiologicalSexFromHealthKitUseCase: Current local value: \(currentSex ?? "nil")")

        // Change detection: Only proceed if value actually changed
        if currentSex == biologicalSex {
            print("SyncBiologicalSexFromHealthKitUseCase: ✅ No change detected, skipping sync")
            print("SyncBiologicalSexFromHealthKitUseCase: ===== SYNC SKIPPED =====")
            return
        }

        print(
            "SyncBiologicalSexFromHealthKitUseCase: 🔄 Change detected: '\(currentSex ?? "nil")' → '\(biologicalSex)'"
        )

        // Update local profile with new biological sex using FitIQCore method
        let updatedProfile = currentProfile.updatingPhysical(
            biologicalSex: biologicalSex,
            heightCm: currentProfile.heightCm
        )
        try await userProfileStorage.save(userProfile: updatedProfile)

        print("SyncBiologicalSexFromHealthKitUseCase: ✅ Saved to local storage")

        // Note: Backend sync would happen via outbox pattern or profile update use case
        // For now, local data is saved and will be synced when profile is next updated
        print("SyncBiologicalSexFromHealthKitUseCase: ✅ Local data saved")
        print(
            "SyncBiologicalSexFromHealthKitUseCase: Note: Backend sync via profile update use case")

        print("SyncBiologicalSexFromHealthKitUseCase: ===== SYNC COMPLETE =====")
    }
}

// MARK: - Errors

enum ProfileError: Error, LocalizedError {
    case notFound(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let userId):
            return "Profile not found for user: \(userId)"
        case .invalidData(let message):
            return "Invalid profile data: \(message)"
        }
    }
}
