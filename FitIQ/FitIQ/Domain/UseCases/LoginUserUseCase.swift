//
//  LoginUserUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

import FitIQCore
import Foundation

// MARK: - Use Case Protocol (The Primary Port)

/// Defines the contract for initiating a user login.
protocol LoginUserUseCaseProtocol {
    /// Executes the login flow: verifies credentials, saves tokens, and updates application state.
    func execute(credentials: LoginCredentials) async throws -> FitIQCore.UserProfile
}

// MARK: - Use Case Implementation (The Core Orchestrator)

/// Handles the business logic for authenticating a user.
public final class AuthenticateUserUseCase: LoginUserUseCaseProtocol {

    // Dependencies (Ports and Infrastructure Hooks)
    private let authRepository: AuthRepositoryProtocol
    private let authManager: AuthManager
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let userProfileRepository: UserProfileRepositoryProtocol

    init(
        authRepository: AuthRepositoryProtocol,
        authManager: AuthManager,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        userProfileRepository: UserProfileRepositoryProtocol
    ) {
        self.authRepository = authRepository
        self.authManager = authManager
        self.authTokenPersistence = authTokenPersistence
        self.userProfileStorage = userProfileStorage
        self.userProfileRepository = userProfileRepository
    }

    /// Executes the login sequence.
    ///
    /// Flow:
    /// 1. Authenticate and save tokens
    /// 2. Fetch remote profile from /api/v1/users/me
    /// 3. Check if local profile exists
    /// 4. Compare updatedAt timestamps
    /// 5. Keep local if it's more recent, otherwise save remote
    ///
    /// **Phase 2.1 Migration:** Now uses FitIQCore.UserProfile (unified model)
    func execute(credentials: LoginCredentials) async throws -> FitIQCore.UserProfile {
        print("AuthenticateUserUseCase: ===== LOGIN FLOW START =====")

        // Step 1: Authenticate and save tokens
        let loginResult = try await authRepository.login(credentials: credentials)
        try authTokenPersistence.save(
            accessToken: loginResult.accessToken, refreshToken: loginResult.refreshToken)
        print("AuthenticateUserUseCase: ✅ Tokens saved")

        let userId = loginResult.profile.id

        // Step 2: Fetch remote profile from backend
        print("AuthenticateUserUseCase: 📡 Fetching remote profile from /api/v1/users/me...")
        let remoteProfile: FitIQCore.UserProfile?
        do {
            remoteProfile = try await userProfileRepository.getUserProfile(
                userId: userId.uuidString)

            print("AuthenticateUserUseCase: ✅ Remote profile fetched")
            print(
                "AuthenticateUserUseCase: Remote - Name: '\(remoteProfile?.name ?? "")', DOB: \(remoteProfile?.dateOfBirth?.description ?? "nil")"
            )
            print(
                "AuthenticateUserUseCase: Remote - Updated: \(remoteProfile?.updatedAt ?? Date())"
            )
        } catch {
            print(
                "AuthenticateUserUseCase: ⚠️  Remote profile fetch failed (expected for new users): \(error)"
            )
            remoteProfile = nil
        }

        // Step 3: Check if local profile exists
        print("AuthenticateUserUseCase: 💾 Checking for local profile...")
        let localProfile = try? await userProfileStorage.fetch(forUserID: userId)

        if let local = localProfile {
            print("AuthenticateUserUseCase: ✅ Local profile found")
            print(
                "AuthenticateUserUseCase: Local - Name: '\(local.name)', DOB: \(local.dateOfBirth?.description ?? "nil")"
            )
            print("AuthenticateUserUseCase: Local - Updated: \(local.updatedAt)")
        } else {
            print("AuthenticateUserUseCase: ℹ️  No local profile found")
        }

        // Step 4 & 5: Compare timestamps and decide which to keep
        let finalProfile: FitIQCore.UserProfile

        if let remote = remoteProfile, let local = localProfile {
            // Both exist - compare timestamps
            print("AuthenticateUserUseCase: 🔄 Comparing timestamps...")
            print("AuthenticateUserUseCase:   Remote updatedAt: \(remote.updatedAt)")
            print("AuthenticateUserUseCase:   Local updatedAt:  \(local.updatedAt)")

            if remote.updatedAt > local.updatedAt {
                // Remote is newer - save it, but preserve local HealthKit sync state
                print("AuthenticateUserUseCase: 🌐 Remote is newer, saving remote data")

                finalProfile = remote.updatingHealthKitSync(
                    hasPerformedInitialSync: local.hasPerformedInitialHealthKitSync,
                    lastSyncDate: local.lastSuccessfulDailySyncDate
                )

                try? await userProfileStorage.save(userProfile: finalProfile)
                print("AuthenticateUserUseCase: ✅ Saved remote profile to local storage")
            } else {
                // Local is more recent or equal - keep it
                print("AuthenticateUserUseCase: 💾 Local is more recent, keeping local data")
                finalProfile = local
            }
        } else if let remote = remoteProfile {
            // Only remote exists - save it
            print("AuthenticateUserUseCase: 🌐 Only remote exists, saving it")
            finalProfile = remote
            try? await userProfileStorage.save(userProfile: finalProfile)
            print("AuthenticateUserUseCase: ✅ Saved remote profile to local storage")
        } else if let local = localProfile {
            // Only local exists - keep it
            print("AuthenticateUserUseCase: 💾 Only local exists, keeping it")
            finalProfile = local
        } else {
            // Neither exists (rare) - use minimal from login
            print("AuthenticateUserUseCase: ⚠️  No profiles found, using minimal from login")
            finalProfile = loginResult.profile
        }

        print("AuthenticateUserUseCase: ===== FINAL PROFILE =====")
        print("AuthenticateUserUseCase: Name: '\(finalProfile.name)'")
        print(
            "AuthenticateUserUseCase: Date of Birth: \(finalProfile.dateOfBirth?.description ?? "nil")"
        )
        print("AuthenticateUserUseCase: Height: \(finalProfile.heightCm?.description ?? "nil") cm")
        print("AuthenticateUserUseCase: Biological Sex: \(finalProfile.biologicalSex ?? "nil")")
        print("AuthenticateUserUseCase: Updated: \(finalProfile.updatedAt)")
        print("AuthenticateUserUseCase: ===== LOGIN FLOW COMPLETE =====")

        // Use id (user ID) to match the ID used for profile storage
        authManager.handleSuccessfulAuth(userProfileID: finalProfile.id)
        return finalProfile
    }
}

// Define a general authentication error enum
enum AuthenticationError: Error, LocalizedError {
    case invalidUserID
    // Add other relevant authentication errors here

    var errorDescription: String? {
        switch self {
        case .invalidUserID:
            return "The user profile ID received from the server is invalid."
        }
    }
}
