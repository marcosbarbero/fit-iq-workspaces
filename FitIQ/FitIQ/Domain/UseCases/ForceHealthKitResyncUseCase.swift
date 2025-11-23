//
//  ForceHealthKitResyncUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

import FitIQCore
import Foundation

/// Protocol for forcing a manual re-sync from HealthKit
protocol ForceHealthKitResyncUseCase {
    /// Forces a re-sync of HealthKit data
    /// - Parameter clearExisting: If true, clears existing local data before syncing
    func execute(clearExisting: Bool) async throws
}

/// Implementation of force re-sync use case
final class ForceHealthKitResyncUseCaseImpl: ForceHealthKitResyncUseCase {

    // MARK: - Dependencies

    private let performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    private let healthDataSyncManager: HealthDataSyncOrchestrator

    // MARK: - Initialization

    init(
        performInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager,
        healthDataSyncManager: HealthDataSyncOrchestrator
    ) {
        self.performInitialHealthKitSyncUseCase = performInitialHealthKitSyncUseCase
        self.userProfileStorage = userProfileStorage
        self.progressRepository = progressRepository
        self.authManager = authManager
        self.healthDataSyncManager = healthDataSyncManager
    }

    // MARK: - Execute

    func execute(clearExisting: Bool) async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("FORCE HEALTHKIT RE-SYNC - START")
        print(String(repeating: "=", count: 60))

        // Get current user
        guard let userID = authManager.currentUserProfileID else {
            print("❌ No authenticated user")
            throw ForceResyncError.userNotAuthenticated
        }

        print("User ID: \(userID)")
        print("Clear existing data: \(clearExisting)")

        // Fetch user profile
        guard var userProfile = try await userProfileStorage.fetch(forUserID: userID) else {
            print("❌ User profile not found for ID: \(userID)")
            print("\n" + String(repeating: "!", count: 60))
            print("UUID MISMATCH DETECTED!")
            print(String(repeating: "!", count: 60))
            print("\nThe user ID in keychain doesn't match any profile in the database.")
            print("\nPossible causes:")
            print("  1. User logged in with different account")
            print("  2. Database was cleared but keychain wasn't")
            print("  3. Profile was deleted but session remained active")
            print("\n🔧 SOLUTION:")
            print("  1. Log out from the app")
            print("  2. Log back in")
            print("  3. This will reset the user ID in keychain")
            print("\nIf issue persists:")
            print("  - Delete and reinstall the app")
            print("  - This will clear all local data and keychain")
            print(String(repeating: "!", count: 60) + "\n")
            throw ForceResyncError.userProfileNotFound
        }

        // Check current sync status
        let hadPerformedSync = userProfile.hasPerformedInitialHealthKitSync
        print("Previous sync status: \(hadPerformedSync ? "✅ Completed" : "⚠️ Never completed")")

        // Optionally clear existing local data
        if clearExisting {
            print("\n🗑️ Clearing existing local data...")
            do {
                // Clear weight data
                try await progressRepository.deleteAll(
                    forUserID: userID.uuidString,
                    type: .weight
                )
                print("✅ Successfully cleared all weight entries")

                // Clear steps data
                try await progressRepository.deleteAll(
                    forUserID: userID.uuidString,
                    type: .steps
                )
                print("✅ Successfully cleared all steps entries")

                // Clear heart rate data
                try await progressRepository.deleteAll(
                    forUserID: userID.uuidString,
                    type: .restingHeartRate
                )
                print("✅ Successfully cleared all heart rate entries")

                // Clear historical sync tracking to allow re-processing
                healthDataSyncManager.clearHistoricalSyncTracking()

            } catch {
                print("⚠️ Warning: Failed to clear existing data: \(error.localizedDescription)")
                print("Continuing with re-sync anyway...")
            }
        } else {
            print("\n📌 Keeping existing local data (will skip duplicates)")
        }

        // Reset the sync flag to allow initial sync to run again
        print("\n🔄 Resetting initial sync flag...")
        userProfile = userProfile.updatingHealthKitSync(
            hasPerformedInitialSync: false,
            lastSyncDate: nil
        )
        try await userProfileStorage.save(userProfile: userProfile)
        print("✅ Flag reset successfully")

        // Trigger initial sync
        print("\n🚀 Triggering HealthKit initial sync...")
        print("This will fetch up to 1 year of weight data from HealthKit")

        do {
            try await performInitialHealthKitSyncUseCase.execute(forUserID: userID)
            print("\n✅ Re-sync completed successfully!")
            print("Data should now be visible in the app")
        } catch {
            print("\n❌ Re-sync failed: \(error.localizedDescription)")

            // Restore the original sync flag if re-sync failed
            if hadPerformedSync {
                print("⚠️ Restoring original sync flag...")
                userProfile = userProfile.updatingHealthKitSync(
                    hasPerformedInitialSync: true,
                    lastSyncDate: userProfile.lastSuccessfulDailySyncDate
                )
                try? await userProfileStorage.save(userProfile: userProfile)
            }

            throw ForceResyncError.resyncFailed(error)
        }

        print(String(repeating: "=", count: 60))
        print("FORCE HEALTHKIT RE-SYNC - END")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Errors

enum ForceResyncError: Error, LocalizedError {
    case userNotAuthenticated
    case userProfileNotFound
    case resyncFailed(Error)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to force re-sync"
        case .userProfileNotFound:
            return "User profile not found"
        case .resyncFailed(let error):
            return "Re-sync failed: \(error.localizedDescription)"
        }
    }
}
