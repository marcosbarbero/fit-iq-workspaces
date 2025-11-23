//
//  ProfileViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//

import Combine
import FitIQCore
import Foundation
import HealthKit
import SwiftData

class ProfileViewModel: ObservableObject {
    private let authManager: AuthManager
    private var getLatestHealthKitMetrics: GetLatestBodyMetricsUseCase
    private let cloudDataManager: CloudDataManagerProtocol
    private let updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let updateProfileMetadataUseCase: UpdateProfileMetadataUseCase
    private let healthRepository: HealthRepositoryProtocol
    private let syncBiologicalSexFromHealthKitUseCase: SyncBiologicalSexFromHealthKitUseCase?
    private let deleteAllUserDataUseCase: DeleteAllUserDataUseCase
    private let healthKitAuthUseCase: RequestHealthKitAuthorizationUseCase?

    @Published var userName: String = "Marcos Barbero"
    @Published var profileImageUrl: String? = nil
    @Published var bodyMetrics: HealthMetricsSnapshot?
    @Published var isDeletingCloudData: Bool = false
    @Published var deletionError: Error? = nil

    // Profile editing state
    @Published var userProfile: FitIQCore.UserProfile?
    @Published var name: String = ""
    @Published var bio: String = ""
    @Published var dateOfBirth: Date = {
        let calendar = Calendar.current
        let eighteenYearsAgo = calendar.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        return eighteenYearsAgo
    }()
    @Published var preferredUnitSystem: String = "metric"
    @Published var languageCode: String = "en"

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var heightCm: String = ""
    @Published var biologicalSex: String = ""
    @Published var isEditingProfile: Bool = false
    @Published var isSavingProfile: Bool = false
    @Published var profileUpdateMessage: String?

    // Physical profile state (deprecated - now part of userProfile)
    @Published var isLoadingPhysical: Bool = false
    @Published var physicalProfileError: String?
    @Published var isReauthorizingHealthKit: Bool = false
    @Published var reauthorizationMessage: String?

    init(
        updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol,
        updateProfileMetadataUseCase: UpdateProfileMetadataUseCase,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManager,
        cloudDataManager: CloudDataManagerProtocol,
        getLatestHealthKitMetrics: GetLatestBodyMetricsUseCase,
        healthRepository: HealthRepositoryProtocol,
        syncBiologicalSexFromHealthKitUseCase: SyncBiologicalSexFromHealthKitUseCase? = nil,
        deleteAllUserDataUseCase: DeleteAllUserDataUseCase,
        healthKitAuthUseCase: RequestHealthKitAuthorizationUseCase? = nil
    ) {
        self.updateUserProfileUseCase = updateUserProfileUseCase
        self.updateProfileMetadataUseCase = updateProfileMetadataUseCase
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager
        self.cloudDataManager = cloudDataManager
        self.getLatestHealthKitMetrics = getLatestHealthKitMetrics
        self.healthRepository = healthRepository
        self.syncBiologicalSexFromHealthKitUseCase = syncBiologicalSexFromHealthKitUseCase
        self.deleteAllUserDataUseCase = deleteAllUserDataUseCase
        self.healthKitAuthUseCase = healthKitAuthUseCase
    }

    private func extractUsernameFromEmail(_ email: String) -> String {
        return email.components(separatedBy: "@").first ?? email
    }

    func logout() {
        authManager.logout()
    }

    /// Re-request HealthKit authorization (for new permissions like workout effort score)
    @MainActor
    func reauthorizeHealthKit() async {
        guard let healthKitAuthUseCase = healthKitAuthUseCase else {
            reauthorizationMessage = "HealthKit authorization not available"
            return
        }

        isReauthorizingHealthKit = true
        reauthorizationMessage = nil

        do {
            try await healthKitAuthUseCase.execute()
            reauthorizationMessage = "✅ HealthKit permissions updated! Please sync workouts again."
            print("ProfileViewModel: ✅ HealthKit re-authorization successful")
        } catch {
            reauthorizationMessage = "❌ Failed to update permissions: \(error.localizedDescription)"
            print("ProfileViewModel: ❌ HealthKit re-authorization failed: \(error)")
        }

        isReauthorizingHealthKit = false
    }

    func fetchLatestHealthMetrics() async {
        self.bodyMetrics = try? await getLatestHealthKitMetrics.execute()
    }

    @MainActor
    func loadUserProfile() async {
        guard let userId = authManager.currentUserProfileID else {
            print("ProfileViewModel: ❌ No current user ID found")
            return
        }

        isLoading = true
        errorMessage = nil

        print("ProfileViewModel: ===== LOAD USER PROFILE START =====")
        print("ProfileViewModel: User ID: \(userId)")

        do {
            let profile = try await userProfileStorage.fetch(forUserID: userId)
            self.userProfile = profile

            print("ProfileViewModel: ===== STEP 1: LOCAL STORAGE =====")
            if let profile = profile {
                print("ProfileViewModel: ✅ Profile loaded from local storage")
                print("ProfileViewModel:   Profile ID: \(profile.id)")
                print("ProfileViewModel:   User ID: \(profile.id)")
                print("ProfileViewModel:   Name: '\(profile.name)'")
                print("ProfileViewModel:   Bio: '\(profile.bio ?? "")'")
                print("ProfileViewModel:   Updated At: \(profile.updatedAt)")
                print("ProfileViewModel: --- Physical Attributes ---")
                print(
                    "ProfileViewModel:   Date of Birth: \(profile.dateOfBirth?.description ?? "nil")"
                )
                print(
                    "ProfileViewModel:   Height: \(profile.heightCm?.description ?? "nil") cm")
                print("ProfileViewModel:   Biological Sex: \(profile.biologicalSex ?? "nil")")
            } else {
                print("ProfileViewModel: ⚠️  No profile found in local storage")
                print("ProfileViewModel: ℹ️  Profile should have been saved during registration")
                print("ProfileViewModel: ℹ️  If you see this, the wrong user ID may be in Keychain")
                print("ProfileViewModel: ℹ️  Try logging out and registering again")
            }

            print("ProfileViewModel: ===== STEP 2: POPULATE FORM FIELDS =====")
            // Populate form fields from metadata
            self.name = profile?.name ?? ""
            self.bio = profile?.bio ?? ""
            self.preferredUnitSystem = profile?.preferredUnitSystem ?? "metric"
            self.languageCode = profile?.languageCode ?? "en"
            self.userName = profile?.name ?? "User"

            // Populate physical profile fields from stored profile
            if let heightCm = profile?.heightCm {
                self.heightCm = String(format: "%.0f", heightCm)
                print("ProfileViewModel:   Set height from profile: \(heightCm) cm")
            }
            if let biologicalSex = profile?.biologicalSex {
                self.biologicalSex = biologicalSex
                print("ProfileViewModel:   Set biological sex from profile: \(biologicalSex)")
            }

            // Use UserProfile's computed property for DOB (handles physical -> metadata fallback)
            if let dob = profile?.dateOfBirth {
                self.dateOfBirth = dob
                print("ProfileViewModel:   Set DOB from profile: \(dob)")
            } else {
                print("ProfileViewModel:   No DOB available in profile")
            }

            print("ProfileViewModel: --- Form State After Local Load ---")
            print("ProfileViewModel:   Name: '\(self.name)'")
            print("ProfileViewModel:   Bio: '\(self.bio)'")
            print("ProfileViewModel:   Height: '\(self.heightCm)' cm")
            print("ProfileViewModel:   Sex: '\(self.biologicalSex)'")
            print("ProfileViewModel:   DOB: \(self.dateOfBirth)")

            // Load physical profile from backend to get any updates
            print("ProfileViewModel: ===== STEP 3: LOAD FROM BACKEND =====")
            await loadPhysicalProfile()

            // Load from HealthKit if fields are still empty
            print("ProfileViewModel: ===== STEP 4: HEALTHKIT FALLBACK =====")
            await loadFromHealthKitIfNeeded()

            // Final summary of loaded values
            print("ProfileViewModel: ===== PROFILE LOADING COMPLETE =====")
            print("ProfileViewModel: Final State:")
            print("ProfileViewModel:   Name: '\(self.name)'")
            print("ProfileViewModel:   Bio: '\(self.bio)'")
            print("ProfileViewModel:   Height: '\(self.heightCm)' cm")
            print("ProfileViewModel:   Biological Sex: '\(self.biologicalSex)'")
            print("ProfileViewModel:   DOB: \(self.dateOfBirth)")
            print("ProfileViewModel:   Unit System: '\(self.preferredUnitSystem)'")
            print("ProfileViewModel:   Language: '\(self.languageCode)'")
            print("ProfileViewModel: ==========================================")
        } catch {
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            print("ProfileViewModel: ❌ Failed to load user profile: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// DEPRECATED: This method is no longer needed with unified UserProfile
    /// Physical attributes are now loaded as part of the main user profile
    @MainActor
    func loadPhysicalProfile() async {
        print("ProfileViewModel: ⚠️  DEPRECATED: loadPhysicalProfile() is no longer needed")
        print("ProfileViewModel: Physical attributes are now part of the unified UserProfile")
        print("ProfileViewModel: Data is already loaded via loadUserProfile()")

        // Update form fields from existing userProfile
        if let profile = self.userProfile {
            if let height = profile.heightCm, height > 0 {
                self.heightCm = String(format: "%.0f", height)
            }
            if let dob = profile.dateOfBirth {
                self.dateOfBirth = dob
            }
            if let sex = profile.biologicalSex, !sex.isEmpty {
                self.biologicalSex = sex
            }
        }
    }

    /// Loads physical profile data from HealthKit if fields are empty
    ///
    /// This method is called after loading from local storage and backend.
    /// It will only fetch data from HealthKit for fields that are still empty.
    ///
    /// **Debug Notes:**
    /// - Height and biological sex come from HealthKit (if available)
    /// - Date of birth comes from registration (stored in metadata)
    /// - HealthKit requires user permissions to be granted
    /// - If data is not pre-populating, check:
    ///   1. HealthKit permissions are granted (check Settings > Health > Data Access & Devices)
    ///   2. HealthKit has data for height and biological sex
    ///   3. Backend is returning empty physical profile (check logs)
    ///   4. Local storage has no cached physical profile
    @MainActor
    private func loadFromHealthKitIfNeeded() async {
        print("ProfileViewModel: Checking if HealthKit data is needed")
        print("ProfileViewModel: Current state - Height: '\(heightCm)', Sex: '\(biologicalSex)'")

        var needsHealthKitData = false

        // Check if height is missing
        if heightCm.isEmpty {
            print("ProfileViewModel: Height is missing, will fetch from HealthKit")
            needsHealthKitData = true
        }

        // Check if biological sex is missing
        if biologicalSex.isEmpty {
            print("ProfileViewModel: Biological sex is missing, will fetch from HealthKit")
            needsHealthKitData = true
        }

        guard needsHealthKitData else {
            print("ProfileViewModel: All physical data present, skipping HealthKit fetch")
            return
        }

        // Check if HealthKit is available
        guard healthRepository.isHealthDataAvailable() else {
            print("ProfileViewModel: ⚠️ HealthKit is not available on this device")
            return
        }

        print("ProfileViewModel: Loading missing data from HealthKit")

        // Fetch height from HealthKit if missing
        if heightCm.isEmpty {
            print("ProfileViewModel: Attempting to fetch height from HealthKit...")
            do {
                let metrics = try await getLatestHealthKitMetrics.execute()
                print(
                    "ProfileViewModel: HealthKit metrics fetched - heightCm: \(metrics.heightCm ?? 0)"
                )
                if let heightSample = metrics.heightCm, heightSample > 0 {
                    self.heightCm = String(format: "%.0f", heightSample)
                    print("ProfileViewModel: ✅ Loaded height from HealthKit: \(heightSample) cm")

                    // Auto-save height to storage (like biological sex)
                    print("ProfileViewModel: Auto-saving height to storage...")
                    if let userId = authManager.currentUserProfileID {
                        do {
                            _ = try await updateUserProfileUseCase.execute(
                                userId: userId.uuidString,
                                name: nil,
                                dateOfBirth: dateOfBirth,
                                gender: nil,
                                height: heightSample,
                                weight: nil,
                                activityLevel: nil
                            )
                            print("ProfileViewModel: ✅ Height auto-saved to storage")
                        } catch {
                            print(
                                "ProfileViewModel: ⚠️ Failed to auto-save height: \(error.localizedDescription)"
                            )
                        }
                    }
                } else {
                    print("ProfileViewModel: ⚠️ No height data available in HealthKit")
                }
            } catch {
                print("ProfileViewModel: ❌ Could not load height from HealthKit: \(error)")
            }
        }

        // Fetch biological sex from HealthKit if missing
        if biologicalSex.isEmpty {
            print("ProfileViewModel: Attempting to fetch biological sex from HealthKit...")
            do {
                let hkBiologicalSex = try await healthRepository.fetchBiologicalSex()

                if let hkSex = hkBiologicalSex {
                    let sexString: String
                    switch hkSex {
                    case .female:
                        sexString = "female"
                    case .male:
                        sexString = "male"
                    case .other:
                        sexString = "other"
                    case .notSet:
                        sexString = ""
                    @unknown default:
                        sexString = ""
                    }

                    if !sexString.isEmpty {
                        self.biologicalSex = sexString
                        print(
                            "ProfileViewModel: ✅ Loaded biological sex from HealthKit: \(sexString)"
                        )
                    } else {
                        print("ProfileViewModel: ⚠️ Biological sex not set in HealthKit")
                    }
                } else {
                    print("ProfileViewModel: ⚠️ No biological sex data available in HealthKit")
                }
            } catch {
                print("ProfileViewModel: ❌ Could not load biological sex from HealthKit: \(error)")
            }
        }

        print(
            "ProfileViewModel: Final state after HealthKit - Height: '\(heightCm)', Sex: '\(biologicalSex)'"
        )
    }

    @MainActor
    func saveProfileMetadata() async {
        guard let userId = authManager.currentUserProfileID else {
            profileUpdateMessage = "No user ID found"
            print("ProfileViewModel: ❌ No user ID found for saving metadata")
            return
        }

        isSavingProfile = true
        profileUpdateMessage = nil

        print("ProfileViewModel: ===== SAVE PROFILE METADATA =====")
        print("ProfileViewModel: User ID: \(userId)")
        print("ProfileViewModel: Name: '\(name)'")
        print("ProfileViewModel: Bio: '\(bio)'")
        print("ProfileViewModel: Unit System: '\(preferredUnitSystem)'")
        print("ProfileViewModel: Language: '\(languageCode)'")

        // Validate required fields
        guard !name.isEmpty else {
            profileUpdateMessage = "Name is required"
            isSavingProfile = false
            print("ProfileViewModel: ❌ Validation failed: Name is required")
            return
        }

        do {
            let updatedProfile = try await updateProfileMetadataUseCase.execute(
                userId: userId.uuidString,
                name: name,
                bio: bio.isEmpty ? nil : bio,
                preferredUnitSystem: preferredUnitSystem,
                languageCode: languageCode.isEmpty ? nil : languageCode
            )

            self.userProfile = updatedProfile
            self.userName = updatedProfile.name
            self.profileUpdateMessage = "Profile updated successfully!"

            print("ProfileViewModel: ✅ Profile metadata saved successfully")
            print("ProfileViewModel:   Updated Name: '\(updatedProfile.name)'")
            print("ProfileViewModel:   Updated Bio: '\(updatedProfile.bio ?? "")'")
            print("ProfileViewModel:   Updated At: \(updatedProfile.updatedAt)")
        } catch {
            profileUpdateMessage = "Failed to update profile: \(error.localizedDescription)"
            print(
                "ProfileViewModel: ❌ Failed to update profile metadata: \(error.localizedDescription)"
            )
        }

        isSavingProfile = false
    }

    @MainActor
    func savePhysicalProfile() async {
        guard let userId = authManager.currentUserProfileID else {
            profileUpdateMessage = "No user ID found"
            print("ProfileViewModel: ❌ No user ID found for saving physical profile")
            return
        }

        isSavingProfile = true
        profileUpdateMessage = nil

        print("ProfileViewModel: ===== SAVE PHYSICAL PROFILE =====")
        print("ProfileViewModel: User ID: \(userId)")
        print("ProfileViewModel: Height: '\(heightCm)' cm")
        print("ProfileViewModel: DOB: \(dateOfBirth)")
        print("ProfileViewModel: Note: Biological sex is NOT updated here (HealthKit-only)")

        // Parse numeric values
        let height = Double(heightCm)

        do {
            // Note: biologicalSex is NOT passed - it's HealthKit-only
            let updatedProfile = try await updateUserProfileUseCase.execute(
                userId: userId.uuidString,
                name: nil,
                dateOfBirth: dateOfBirth,
                gender: nil,
                height: height,
                weight: nil,
                activityLevel: nil
            )

            // Update local state from unified profile
            self.userProfile = updatedProfile
            self.heightCm = String(format: "%.1f", updatedProfile.heightCm ?? 0)
            self.dateOfBirth = updatedProfile.dateOfBirth ?? self.dateOfBirth
            self.profileUpdateMessage = "Physical profile updated successfully!"

            print("ProfileViewModel: ✅ Physical profile saved successfully")
            print(
                "ProfileViewModel:   Updated Height: \(updatedProfile.heightCm?.description ?? "nil") cm"
            )
            print(
                "ProfileViewModel:   Biological Sex: \(updatedProfile.biologicalSex ?? "nil") (unchanged, HealthKit-only)"
            )
            print(
                "ProfileViewModel:   Updated DOB: \(updatedProfile.dateOfBirth?.description ?? "nil")"
            )
        } catch {
            profileUpdateMessage =
                "Failed to update physical profile: \(error.localizedDescription)"
            print(
                "ProfileViewModel: ❌ Failed to update physical profile: \(error.localizedDescription)"
            )
        }

        isSavingProfile = false
    }

    @MainActor
    func saveProfile() async {
        print("ProfileViewModel: ===== SAVE COMPLETE PROFILE =====")

        // Save both metadata and physical profile
        print("ProfileViewModel: Step 1: Saving metadata...")
        await saveProfileMetadata()

        if profileUpdateMessage?.contains("success") == true {
            print("ProfileViewModel: Step 2: Saving physical profile...")
            await savePhysicalProfile()
        } else {
            print(
                "ProfileViewModel: ⚠️  Skipping physical profile save due to metadata save failure")
        }

        if profileUpdateMessage?.contains("success") == true {
            print("ProfileViewModel: ✅ Profile save complete, exiting edit mode")
            self.isEditingProfile = false
        } else {
            print("ProfileViewModel: ⚠️  Profile save incomplete, staying in edit mode")
        }
    }

    @MainActor
    func startEditing() async {
        isEditingProfile = true

        // Reload HealthKit data if fields are empty
        // This ensures we have the latest data even if permissions were granted
        // or data was added after the profile initially loaded
        print("ProfileViewModel: Starting edit mode - checking for HealthKit data")
        await loadFromHealthKitIfNeeded()

        // Also sync biological sex from HealthKit (change detection inside use case)
        await syncBiologicalSexFromHealthKit()
    }

    /// Syncs biological sex from HealthKit to local storage and backend
    ///
    /// This is the ONLY way biological sex should be updated in the system.
    /// It's called when:
    /// - Edit profile is opened (to catch any HealthKit changes)
    /// - App launches and profile is loaded
    /// - HealthKit authorization is granted
    ///
    /// The use case includes change detection - it only syncs if the value actually changed.
    @MainActor
    func syncBiologicalSexFromHealthKit() async {
        guard let userId = authManager.currentUserProfileID else {
            print("ProfileViewModel: No user ID for biological sex sync")
            return
        }

        guard let syncUseCase = syncBiologicalSexFromHealthKitUseCase else {
            print("ProfileViewModel: SyncBiologicalSexFromHealthKitUseCase not available")
            return
        }

        print("ProfileViewModel: ===== SYNC BIOLOGICAL SEX FROM HEALTHKIT =====")

        // Fetch from HealthKit
        do {
            let hkBiologicalSex = try await healthRepository.fetchBiologicalSex()

            guard let hkSex = hkBiologicalSex else {
                print("ProfileViewModel: No biological sex in HealthKit")
                return
            }

            let sexString: String
            switch hkSex {
            case .female:
                sexString = "female"
            case .male:
                sexString = "male"
            case .other:
                sexString = "other"
            case .notSet:
                print("ProfileViewModel: Biological sex not set in HealthKit")
                return
            @unknown default:
                print("ProfileViewModel: Unknown biological sex value in HealthKit")
                return
            }

            print("ProfileViewModel: HealthKit biological sex: \(sexString)")

            // Sync to backend via dedicated use case (includes change detection)
            try await syncUseCase.execute(
                userId: userId.uuidString,
                biologicalSex: sexString
            )

            // Update local state for UI
            self.biologicalSex = sexString

            print("ProfileViewModel: ✅ Biological sex sync complete")
        } catch {
            print(
                "ProfileViewModel: ⚠️ Failed to sync biological sex: \(error.localizedDescription)")
            // Don't throw - this is a non-critical operation
        }

        print("ProfileViewModel: ===== SYNC COMPLETE =====")
    }

    func cancelEditing() {
        // Restore original values from profile metadata
        name = userProfile?.name ?? ""
        bio = userProfile?.bio ?? ""
        preferredUnitSystem = userProfile?.preferredUnitSystem ?? "metric"
        languageCode = userProfile?.languageCode ?? "en"

        if let dob = userProfile?.dateOfBirth {
            dateOfBirth = dob
        }

        // Restore from physical profile if available
        // Populate form fields from HealthKit data if available (deprecated - now uses userProfile)
        // This code is kept for backward compatibility but physical is no longer a separate entity
        if let profile = self.userProfile {
            if let height = profile.heightCm {
                heightCm = String(format: "%.0f", height)
            }
            if let sex = profile.biologicalSex {
                biologicalSex = sex
            }
            if let dob = profile.dateOfBirth {
                dateOfBirth = dob
            }
        }

        isEditingProfile = false
        profileUpdateMessage = nil
    }

    // Function to delete all user data from backend and local storage
    func deleteiCloudData() async {
        isDeletingCloudData = true
        deletionError = nil
        do {
            // Delete all data from backend via /api/v1/users/me and clear local storage
            try await deleteAllUserDataUseCase.execute()
            print("ProfileViewModel: All user data deletion successful.")

            // Logout user (this will clear auth state and navigate to login)
            await MainActor.run {
                authManager.logout()
            }
        } catch {
            print("ProfileViewModel: Failed to delete user data: \(error.localizedDescription)")
            await MainActor.run {
                deletionError = error
            }
        }
        await MainActor.run {
            isDeletingCloudData = false
        }
    }

    @MainActor
    func clearDeletionError() {
        deletionError = nil
    }
}
