//
//  RegisterUserUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

// Domain/UseCases/RegisterUserUseCase.swift
import Foundation

protocol RegisterUserUseCaseProtocol {
    func execute(data: RegisterUserData) async throws -> UserProfile
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

    func execute(data: RegisterUserData) async throws -> UserProfile {
        print("RegisterUserUseCase: ===== REGISTRATION FLOW START =====")
        print("RegisterUserUseCase: Email: \(data.email)")
        print("RegisterUserUseCase: Name: \(data.name)")
        print("RegisterUserUseCase: DOB: \(data.dateOfBirth.description)")

        // Step 1: Register user (creates auth user only)
        let (userProfile, accessToken, refreshToken) = try await authRepository.register(
            userData: data)

        print("RegisterUserUseCase: ===== REGISTRATION RESPONSE =====")
        print("RegisterUserUseCase: User ID: \(userProfile.userId)")
        print("RegisterUserUseCase: Name: '\(userProfile.name)'")
        print(
            "RegisterUserUseCase: Metadata DOB: \(userProfile.metadata.dateOfBirth?.description ?? "nil")"
        )
        print(
            "RegisterUserUseCase: Physical DOB: \(userProfile.physical?.dateOfBirth?.description ?? "nil")"
        )

        // Step 2: Save tokens (needed for any backend API calls)
        try authTokenPersistence.save(accessToken: accessToken, refreshToken: refreshToken)
        print("RegisterUserUseCase: ✅ Tokens saved")

        // Step 3: IMMEDIATELY save profile to local storage (Local is source of truth)
        // This ensures we have the user data even if backend sync fails
        print("RegisterUserUseCase: ===== SAVING TO LOCAL STORAGE (PRIMARY) =====")
        print("RegisterUserUseCase: Profile ID (metadata.id): \(userProfile.id)")
        print("RegisterUserUseCase: User ID (metadata.userId): \(userProfile.userId)")
        print("RegisterUserUseCase: Name: '\(userProfile.name)'")
        print("RegisterUserUseCase: Bio: '\(userProfile.bio ?? "")'")
        print(
            "RegisterUserUseCase: Metadata DOB: \(userProfile.metadata.dateOfBirth?.description ?? "nil")"
        )
        print(
            "RegisterUserUseCase: Physical DOB: \(userProfile.physical?.dateOfBirth?.description ?? "nil")"
        )

        try await userProfileStorage.save(userProfile: userProfile)
        print(
            "RegisterUserUseCase: ✅ Profile saved to local storage with userId: \(userProfile.userId)"
        )

        // Step 4: Set auth state with USER ID (from JWT), not profile ID
        // This must match the ID used to save the profile (userId)
        authManager.handleSuccessfulAuth(userProfileID: userProfile.userId)
        print("RegisterUserUseCase: ✅ Auth state updated with user ID: \(userProfile.userId)")

        // Step 5: Optionally fetch profile from backend to enrich local data
        // This is async and non-blocking - local data is already complete
        print("RegisterUserUseCase: ===== OPTIONAL: FETCH FROM BACKEND FOR ENRICHMENT =====")
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            do {
                let backendProfile = try await self.profileMetadataClient.getProfile(
                    userId: userProfile.userId.uuidString)
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
    private func mergeProfiles(local: UserProfile, remote: UserProfile) -> UserProfile {
        print("RegisterUserUseCase: Merging profiles - local is primary")

        // Prefer local name (user entered during registration)
        let name = local.name.isEmpty ? remote.name : local.name

        // Prefer local bio
        let bio = local.bio ?? remote.bio

        // Prefer local DOB (user entered during registration)
        let dateOfBirth = local.dateOfBirth ?? remote.dateOfBirth

        // Use remote profile ID (server-assigned)
        let profileId = remote.id

        // Create merged metadata
        let mergedMetadata = UserProfileMetadata(
            id: profileId,
            userId: local.userId,
            name: name,
            bio: bio,
            preferredUnitSystem: local.preferredUnitSystem,
            languageCode: local.languageCode ?? remote.languageCode,
            dateOfBirth: dateOfBirth,
            createdAt: local.metadata.createdAt,
            updatedAt: remote.metadata.updatedAt
        )

        // Merge physical profiles - prefer local DOB
        let mergedPhysical: PhysicalProfile?
        if let localPhysical = local.physical {
            mergedPhysical = PhysicalProfile(
                biologicalSex: localPhysical.biologicalSex ?? remote.physical?.biologicalSex,
                heightCm: localPhysical.heightCm ?? remote.physical?.heightCm,
                dateOfBirth: localPhysical.dateOfBirth ?? remote.physical?.dateOfBirth
            )
        } else {
            mergedPhysical = remote.physical
        }

        return UserProfile(
            metadata: mergedMetadata,
            physical: mergedPhysical,
            email: local.email,
            username: local.metadata.name
        )
    }
}
