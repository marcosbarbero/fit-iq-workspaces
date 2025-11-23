//
//  RegisterUserUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

// Domain/UseCases/RegisterUserUseCase.swift
import FitIQCore
import Foundation

protocol RegisterUserUseCaseProtocol {
    func execute(data: RegisterUserData) async throws -> FitIQCore.UserProfile
}

final class CreateUserUseCase: RegisterUserUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol
    private let authManager: AuthManager
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let profileMetadataClient: UserProfileMetadataClient

    init(
        authRepository: AuthRepositoryProtocol,
        authManager: AuthManager,
        userProfileStorage: UserProfileStoragePortProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        profileMetadataClient: UserProfileMetadataClient
    ) {
        self.authRepository = authRepository
        self.authManager = authManager
        self.userProfileStorage = userProfileStorage
        self.authTokenPersistence = authTokenPersistence
        self.profileMetadataClient = profileMetadataClient
    }

    func execute(data: RegisterUserData) async throws -> FitIQCore.UserProfile {
        print("RegisterUserUseCase: ===== REGISTRATION FLOW START =====")
        print("RegisterUserUseCase: Email: \(data.email)")
        print("RegisterUserUseCase: Name: \(data.name)")
        print("RegisterUserUseCase: DOB: \(data.dateOfBirth.description)")

        // Step 1: Register user (creates auth user only)
        let (userProfile, accessToken, refreshToken) = try await authRepository.register(
            userData: data)

        print("RegisterUserUseCase: ===== REGISTRATION RESPONSE =====")
        print("RegisterUserUseCase: User ID: \(userProfile.id)")
        print("RegisterUserUseCase: Name: '\(userProfile.name)'")
        print(
            "RegisterUserUseCase: DOB: \(userProfile.dateOfBirth?.description ?? "nil")"
        )

        // Step 2: Save tokens (needed for any backend API calls)
        try authTokenPersistence.save(accessToken: accessToken, refreshToken: refreshToken)
        print("RegisterUserUseCase: ✅ Tokens saved")

        // Step 3: IMMEDIATELY save profile to local storage (Local is source of truth)
        // This ensures we have the user data even if backend sync fails
        print("RegisterUserUseCase: ===== SAVING TO LOCAL STORAGE (PRIMARY) =====")
        print("RegisterUserUseCase: User ID: \(userProfile.id)")
        print("RegisterUserUseCase: Name: '\(userProfile.name)'")
        print("RegisterUserUseCase: Bio: '\(userProfile.bio ?? "")'")
        print(
            "RegisterUserUseCase: DOB: \(userProfile.dateOfBirth?.description ?? "nil")"
        )

        try await userProfileStorage.save(userProfile: userProfile)
        print(
            "RegisterUserUseCase: ✅ Profile saved to local storage with userId: \(userProfile.id)"
        )

        // Step 4: Set auth state with USER ID (from JWT)
        authManager.handleSuccessfulAuth(userProfileID: userProfile.id)
        print("RegisterUserUseCase: ✅ Auth state updated with user ID: \(userProfile.id)")

        // Step 5: Optionally fetch profile from backend to enrich local data
        // This is async and non-blocking - local data is already complete
        print("RegisterUserUseCase: ===== OPTIONAL: FETCH FROM BACKEND FOR ENRICHMENT =====")
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                let backendProfile = try await self.profileMetadataClient.getProfile(
                    userId: userProfile.id.uuidString)
                print("RegisterUserUseCase: ✅ Backend profile fetched, merging with local")

                // Merge backend data with local (prefer local for user-entered data)
                let enrichedProfile = await self.mergeProfiles(
                    local: userProfile, remote: backendProfile)
                try await self.userProfileStorage.save(userProfile: enrichedProfile)
                print("RegisterUserUseCase: ✅ Enriched profile saved to local storage")
            } catch {
                print(
                    "RegisterUserUseCase: ⚠️  Backend profile fetch failed (non-critical): \(error)")
                // Not a problem - local storage already has complete data
            }
        }

        print("RegisterUserUseCase: ===== REGISTRATION FLOW COMPLETE =====")
        print("RegisterUserUseCase: Local storage is authoritative source")

        return userProfile
    }

    // MARK: - Private Helpers

    /// Merges remote profile data with local profile
    /// Strategy: Prefer local for user-entered data, use remote for server-managed fields
    private func mergeProfiles(local: FitIQCore.UserProfile, remote: FitIQCore.UserProfile)
        -> FitIQCore.UserProfile
    {
        print("RegisterUserUseCase: Merging profiles - local is primary")

        // Prefer local name (user entered during registration)
        let name = local.name.isEmpty ? remote.name : local.name

        // Prefer local bio
        let bio = local.bio ?? remote.bio

        // Prefer local DOB (user entered during registration)
        let dateOfBirth = local.dateOfBirth ?? remote.dateOfBirth

        // Merge physical attributes - prefer local values
        let biologicalSex = local.biologicalSex ?? remote.biologicalSex
        let heightCm = local.heightCm ?? remote.heightCm

        // Create merged unified UserProfile
        let merged = FitIQCore.UserProfile(
            id: local.id,
            email: local.email,
            name: name,
            bio: bio,
            username: local.username,
            languageCode: local.languageCode ?? remote.languageCode,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            preferredUnitSystem: local.preferredUnitSystem,
            hasPerformedInitialHealthKitSync: local.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: local.lastSuccessfulDailySyncDate,
            createdAt: local.createdAt,
            updatedAt: remote.updatedAt
        )

        print("RegisterUserUseCase: Profiles merged successfully")
        return merged
    }
}
