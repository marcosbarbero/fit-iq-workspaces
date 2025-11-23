//
//  LoginUserUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation

// MARK: - Use Case Protocol (The Primary Port)

/// Defines the contract for initiating a user login.
protocol LoginUserUseCaseProtocol {
    /// Executes the login flow: verifies credentials, saves tokens, and updates application state.
    func execute(credentials: LoginCredentials) async throws -> UserProfile
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
    private let getPhysicalProfileUseCase: GetPhysicalProfileUseCase

    init(
        authRepository: AuthRepositoryProtocol,
        authManager: AuthManager,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        userProfileRepository: UserProfileRepositoryProtocol,
        getPhysicalProfileUseCase: GetPhysicalProfileUseCase
    ) {
        self.authRepository = authRepository
        self.authManager = authManager
        self.authTokenPersistence = authTokenPersistence
        self.userProfileStorage = userProfileStorage
        self.userProfileRepository = userProfileRepository
        self.getPhysicalProfileUseCase = getPhysicalProfileUseCase
    }

    /// Executes the login sequence.
    ///
    /// Flow:
    /// 1. Authenticate and save tokens
    /// 2. Fetch remote profile from /api/v1/users/me and /api/v1/users/me/physical
    /// 3. Check if local profile exists
    /// 4. Compare updatedAt timestamps
    /// 5. Keep local if it's more recent, otherwise save remote
    func execute(credentials: LoginCredentials) async throws -> UserProfile {
        print("AuthenticateUserUseCase: ===== LOGIN FLOW START =====")

        // Step 1: Authenticate and save tokens
        let loginResult = try await authRepository.login(credentials: credentials)
        try authTokenPersistence.save(
            accessToken: loginResult.accessToken, refreshToken: loginResult.refreshToken)
        print("AuthenticateUserUseCase: ✅ Tokens saved")

        let userId = loginResult.profile.userId

        // Step 2: Fetch remote profile from backend
        print("AuthenticateUserUseCase: 📡 Fetching remote profile from /api/v1/users/me...")
        let remoteProfile: UserProfile?
        do {
            let remoteMetadata = try await userProfileRepository.getUserProfile(
                userId: userId.uuidString)
            let remotePhysical = try? await getPhysicalProfileUseCase.execute(
                userId: userId.uuidString)

            // Construct full remote profile
            remoteProfile = UserProfile(
                metadata: remoteMetadata.metadata,
                physical: remotePhysical,
                email: remoteMetadata.email,
                username: remoteMetadata.metadata.name,
                hasPerformedInitialHealthKitSync: false,
                lastSuccessfulDailySyncDate: nil
            )

            print("AuthenticateUserUseCase: ✅ Remote profile fetched")
            print(
                "AuthenticateUserUseCase: Remote - Name: '\(remoteProfile?.name ?? "")', DOB: \(remoteProfile?.dateOfBirth?.description ?? "nil")"
            )
            print(
                "AuthenticateUserUseCase: Remote - Updated: \(remoteProfile?.metadata.updatedAt ?? Date())"
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
            print("AuthenticateUserUseCase: Local - Updated: \(local.metadata.updatedAt)")
        } else {
            print("AuthenticateUserUseCase: ℹ️  No local profile found")
        }

        // Step 4 & 5: Compare timestamps and decide which to keep
        let finalProfile: UserProfile

        if let remote = remoteProfile, let local = localProfile {
            // Both exist - compare timestamps
            print("AuthenticateUserUseCase: 🔄 Comparing timestamps...")
            print("AuthenticateUserUseCase:   Remote updatedAt: \(remote.metadata.updatedAt)")
            print("AuthenticateUserUseCase:   Local updatedAt:  \(local.metadata.updatedAt)")

            if remote.metadata.updatedAt > local.metadata.updatedAt {
                // Remote is newer - save it, but merge DOB carefully
                print("AuthenticateUserUseCase: 🌐 Remote is newer, saving remote data")

                // Merge DOB: prefer remote physical, fallback to remote metadata, then local
                let mergedDOB =
                    remote.physical?.dateOfBirth
                    ?? remote.metadata.dateOfBirth
                    ?? local.physical?.dateOfBirth
                    ?? local.metadata.dateOfBirth

                print("AuthenticateUserUseCase:   Merged DOB: \(mergedDOB?.description ?? "nil")")
                print(
                    "AuthenticateUserUseCase:     Remote Physical DOB: \(remote.physical?.dateOfBirth?.description ?? "nil")"
                )
                print(
                    "AuthenticateUserUseCase:     Remote Metadata DOB: \(remote.metadata.dateOfBirth?.description ?? "nil")"
                )
                print(
                    "AuthenticateUserUseCase:     Local Physical DOB: \(local.physical?.dateOfBirth?.description ?? "nil")"
                )
                print(
                    "AuthenticateUserUseCase:     Local Metadata DOB: \(local.metadata.dateOfBirth?.description ?? "nil")"
                )

                // Ensure physical profile has DOB if we have it
                let mergedPhysical: PhysicalProfile?
                if let dob = mergedDOB {
                    mergedPhysical = PhysicalProfile(
                        biologicalSex: remote.physical?.biologicalSex
                            ?? local.physical?.biologicalSex,
                        heightCm: remote.physical?.heightCm ?? local.physical?.heightCm,
                        dateOfBirth: dob
                    )
                } else {
                    mergedPhysical = remote.physical
                }

                finalProfile = UserProfile(
                    metadata: remote.metadata,
                    physical: mergedPhysical,
                    email: remote.email,
                    username: remote.metadata.name,
                    hasPerformedInitialHealthKitSync: local.hasPerformedInitialHealthKitSync,
                    lastSuccessfulDailySyncDate: local.lastSuccessfulDailySyncDate
                )

                try? await userProfileStorage.save(userProfile: finalProfile)
                print("AuthenticateUserUseCase: ✅ Saved remote profile to local storage")
            } else {
                // Local is more recent or equal - keep it, but verify DOB is in physical
                print("AuthenticateUserUseCase: 💾 Local is more recent, keeping local data")

                // Ensure DOB is in physical profile if we have it
                if let dob = local.dateOfBirth {
                    if local.physical == nil || local.physical?.dateOfBirth == nil {
                        print("AuthenticateUserUseCase: 🔄 Moving DOB to physical profile")
                        let mergedPhysical = PhysicalProfile(
                            biologicalSex: local.physical?.biologicalSex,
                            heightCm: local.physical?.heightCm,
                            dateOfBirth: dob
                        )
                        finalProfile = local.updatingPhysical(mergedPhysical)
                        try? await userProfileStorage.save(userProfile: finalProfile)
                        print(
                            "AuthenticateUserUseCase: ✅ Updated local profile with DOB in physical")
                    } else {
                        finalProfile = local
                    }
                } else {
                    finalProfile = local
                }
            }
        } else if let remote = remoteProfile {
            // Only remote exists - save it, but ensure DOB is in physical
            print("AuthenticateUserUseCase: 🌐 Only remote exists, saving it")

            let dob = remote.dateOfBirth
            if let dob = dob {
                if remote.physical == nil || remote.physical?.dateOfBirth == nil {
                    print("AuthenticateUserUseCase: 🔄 Ensuring DOB is in physical profile")
                    let mergedPhysical = PhysicalProfile(
                        biologicalSex: remote.physical?.biologicalSex,
                        heightCm: remote.physical?.heightCm,
                        dateOfBirth: dob
                    )
                    finalProfile = remote.updatingPhysical(mergedPhysical)
                } else {
                    finalProfile = remote
                }
            } else {
                finalProfile = remote
            }

            try? await userProfileStorage.save(userProfile: finalProfile)
            print("AuthenticateUserUseCase: ✅ Saved remote profile to local storage")
        } else if let local = localProfile {
            // Only local exists - keep it, but ensure DOB is in physical
            print("AuthenticateUserUseCase: 💾 Only local exists, keeping it")

            let dob = local.dateOfBirth
            if let dob = dob {
                if local.physical == nil || local.physical?.dateOfBirth == nil {
                    print("AuthenticateUserUseCase: 🔄 Ensuring DOB is in physical profile")
                    let mergedPhysical = PhysicalProfile(
                        biologicalSex: local.physical?.biologicalSex,
                        heightCm: local.physical?.heightCm,
                        dateOfBirth: dob
                    )
                    finalProfile = local.updatingPhysical(mergedPhysical)
                    try? await userProfileStorage.save(userProfile: finalProfile)
                    print("AuthenticateUserUseCase: ✅ Updated local profile with DOB in physical")
                } else {
                    finalProfile = local
                }
            } else {
                finalProfile = local
            }
        } else {
            // Neither exists (rare) - use minimal from login
            print("AuthenticateUserUseCase: ⚠️  No profiles found, using minimal from login")
            finalProfile = loginResult.profile
        }

        print("AuthenticateUserUseCase: ===== FINAL PROFILE =====")
        print("AuthenticateUserUseCase: Name: '\(finalProfile.name)'")
        print(
            "AuthenticateUserUseCase: Metadata DOB: \(finalProfile.metadata.dateOfBirth?.description ?? "nil")"
        )
        print(
            "AuthenticateUserUseCase: Physical DOB: \(finalProfile.physical?.dateOfBirth?.description ?? "nil")"
        )
        print(
            "AuthenticateUserUseCase: Computed DOB: \(finalProfile.dateOfBirth?.description ?? "nil")"
        )
        print("AuthenticateUserUseCase: Height: \(finalProfile.heightCm?.description ?? "nil") cm")
        print("AuthenticateUserUseCase: Biological Sex: \(finalProfile.biologicalSex ?? "nil")")
        print("AuthenticateUserUseCase: Updated: \(finalProfile.metadata.updatedAt)")
        print("AuthenticateUserUseCase: ===== LOGIN FLOW COMPLETE =====")

        // Use userId (JWT user ID) to match the ID used for profile storage
        authManager.handleSuccessfulAuth(userProfileID: finalProfile.userId)
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
