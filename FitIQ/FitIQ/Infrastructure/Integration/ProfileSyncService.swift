//
//  ProfileSyncService.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Edit Implementation - Backend Sync
//

import Combine
import FitIQCore
import Foundation

/// Service for synchronizing profile changes with the backend API
///
/// This service implements an offline-first pattern:
/// 1. Listens to profile domain events
/// 2. Queues sync operations when offline
/// 3. Executes syncs when connection is available
/// 4. Handles sync conflicts and errors
///
/// **Architecture:** Infrastructure Service (Adapter for domain events)
///
/// **Related Components:**
/// - `ProfileEventPublisherProtocol` - Source of domain events
/// - `UserProfileRepositoryProtocol` - Backend API client

/// - `UserProfileStoragePortProtocol` - Local storage
///
protocol ProfileSyncServiceProtocol {
    /// Start listening to profile events and sync when appropriate
    func startListening()

    /// Stop listening to profile events
    func stopListening()

    /// Manually trigger sync of pending changes
    func syncPendingChanges() async throws

    /// Check if there are pending syncs
    var hasPendingSync: Bool { get }
}

/// Implementation of ProfileSyncService
final class ProfileSyncService: ProfileSyncServiceProtocol {

    // MARK: - Dependencies

    private let profileEventPublisher: ProfileEventPublisherProtocol
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private var pendingMetadataSync: Set<String> = []
    private var pendingPhysicalSync: Set<String> = []
    private var isSyncing = false
    private let syncQueue = DispatchQueue(label: "com.fitiq.profilesync", qos: .utility)

    // MARK: - Computed Properties

    var hasPendingSync: Bool {
        syncQueue.sync {
            !pendingMetadataSync.isEmpty || !pendingPhysicalSync.isEmpty
        }
    }

    // MARK: - Initialization

    init(
        profileEventPublisher: ProfileEventPublisherProtocol,
        userProfileRepository: UserProfileRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManager
    ) {
        self.profileEventPublisher = profileEventPublisher
        self.userProfileRepository = userProfileRepository
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager

        print("ProfileSyncService: Initialized")
    }

    // MARK: - Public Methods

    func startListening() {
        print("ProfileSyncService: Starting to listen for profile events")

        profileEventPublisher.publisher
            .sink { [weak self] event in
                self?.handleProfileEvent(event)
            }
            .store(in: &cancellables)
    }

    func stopListening() {
        print("ProfileSyncService: Stopping profile event listening")
        cancellables.removeAll()
    }

    func syncPendingChanges() async throws {
        print("ProfileSyncService: ===== SYNC PENDING CHANGES START =====")

        guard !isSyncing else {
            print("ProfileSyncService: ⚠️  Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        // Get pending sync user IDs
        let metadataUserIds = syncQueue.sync { Array(pendingMetadataSync) }
        let physicalUserIds = syncQueue.sync { Array(pendingPhysicalSync) }

        print(
            "ProfileSyncService: Pending syncs - Metadata: \(metadataUserIds.count), Physical: \(physicalUserIds.count)"
        )

        // Sync metadata for all pending users
        for userId in metadataUserIds {
            print("ProfileSyncService: --- Processing metadata sync for user \(userId) ---")
            do {
                try await syncMetadata(userId: userId)
                syncQueue.sync { pendingMetadataSync.remove(userId) }
                print("ProfileSyncService: ✅ Metadata sync complete for user \(userId)")
            } catch let error as APIError {
                switch error {
                case .notFound:
                    print(
                        "ProfileSyncService: ℹ️  Profile not yet created on backend for user \(userId) (expected for new users)"
                    )
                    // Remove from queue - no point retrying until backend creates profile
                    syncQueue.sync { pendingMetadataSync.remove(userId) }
                default:
                    print(
                        "ProfileSyncService: ❌ Failed to sync metadata for user \(userId): \(error)"
                    )
                // Keep in queue for retry
                }
            } catch {
                print("ProfileSyncService: ❌ Failed to sync metadata for user \(userId): \(error)")
                // Keep in queue for retry
            }
        }

        // Sync physical profile for all pending users
        for userId in physicalUserIds {
            print("ProfileSyncService: --- Processing physical sync for user \(userId) ---")
            do {
                try await syncPhysicalProfile(userId: userId)
                syncQueue.sync { pendingPhysicalSync.remove(userId) }
                print("ProfileSyncService: ✅ Physical sync complete for user \(userId)")
            } catch let error as APIError {
                switch error {
                case .notFound:
                    print(
                        "ProfileSyncService: ℹ️  Physical profile not yet created on backend for user \(userId) (expected for new users)"
                    )
                    // Remove from queue - no point retrying until backend creates physical profile
                    syncQueue.sync { pendingPhysicalSync.remove(userId) }
                default:
                    print(
                        "ProfileSyncService: ❌ Failed to sync physical profile for user \(userId): \(error)"
                    )
                // Keep in queue for retry
                }
            } catch {
                print(
                    "ProfileSyncService: ❌ Failed to sync physical profile for user \(userId): \(error)"
                )
                // Keep in queue for retry
            }
        }

        let remainingMetadata = syncQueue.sync { pendingMetadataSync.count }
        let remainingPhysical = syncQueue.sync { pendingPhysicalSync.count }

        print("ProfileSyncService: ===== SYNC PENDING CHANGES COMPLETE =====")
        print(
            "ProfileSyncService: Remaining pending - Metadata: \(remainingMetadata), Physical: \(remainingPhysical)"
        )
    }

    // MARK: - Private Methods

    private func handleProfileEvent(_ event: ProfileEvent) {
        print("ProfileSyncService: Received event - \(event)")

        switch event {
        case .metadataUpdated(let userId, _):
            queueMetadataSync(userId: userId)
            Task {
                do {
                    try await syncMetadata(userId: userId)
                } catch let error as APIError {
                    switch error {
                    case .notFound:
                        print(
                            "ProfileSyncService: Profile not yet on backend (expected for new users)"
                        )
                        _ = syncQueue.sync { pendingMetadataSync.remove(userId) }
                    default:
                        print("ProfileSyncService: Keep in queue for retry")
                    }
                }
            }

        case .physicalProfileUpdated(let userId, _):
            queuePhysicalSync(userId: userId)
            Task {
                do {
                    try await syncPhysicalProfile(userId: userId)
                } catch let error as APIError {
                    switch error {
                    case .notFound:
                        print(
                            "ProfileSyncService: Physical profile not yet on backend (expected for new users)"
                        )
                        _ = syncQueue.sync { pendingPhysicalSync.remove(userId) }
                    default:
                        print("ProfileSyncService: Keep in queue for retry")
                    }
                }
            }
        }
    }

    private func queueMetadataSync(userId: String) {
        syncQueue.sync {
            pendingMetadataSync.insert(userId)
        }
        print("ProfileSyncService: Queued metadata sync for user \(userId)")
    }

    private func queuePhysicalSync(userId: String) {
        syncQueue.sync {
            pendingPhysicalSync.insert(userId)
        }
        print("ProfileSyncService: Queued physical sync for user \(userId)")
    }

    private func syncMetadata(userId: String) async throws {
        print("ProfileSyncService: ===== SYNC METADATA START =====")
        print("ProfileSyncService: User ID: \(userId)")

        // Validate user ID
        guard let userUUID = UUID(uuidString: userId) else {
            print("ProfileSyncService: ❌ Invalid user ID format: \(userId)")
            throw ProfileSyncError.invalidUserId(userId)
        }

        // Fetch current profile from local storage
        print("ProfileSyncService: 📂 Fetching local profile...")
        guard let profile = try await userProfileStorage.fetch(forUserID: userUUID) else {
            print("ProfileSyncService: ❌ Profile not found locally for user \(userId)")
            throw ProfileSyncError.profileNotFound(userId)
        }

        print("ProfileSyncService: ✅ Local profile fetched")
        print("ProfileSyncService:   Name: '\(profile.name)'")
        print("ProfileSyncService:   Bio: '\(profile.bio ?? "")'")
        print("ProfileSyncService:   Unit System: '\(profile.preferredUnitSystem)'")
        print("ProfileSyncService:   Language: '\(profile.languageCode ?? "")'")
        print("ProfileSyncService:   Updated At: \(profile.updatedAt)")

        // Call backend API to update profile metadata using new method
        guard let apiClient = userProfileRepository as? UserProfileAPIClient else {
            print("ProfileSyncService: ⚠️  Repository is not UserProfileAPIClient, skipping sync")
            syncQueue.sync {
                pendingMetadataSync.remove(userId)
            }
            return
        }

        print("ProfileSyncService: 🌐 Syncing to backend...")
        let updatedProfile = try await apiClient.updateProfileMetadata(
            userId: userId,
            name: profile.name,
            bio: profile.bio,
            preferredUnitSystem: profile.preferredUnitSystem,
            languageCode: profile.languageCode
        )

        print("ProfileSyncService: ✅ Backend sync successful")
        print("ProfileSyncService:   Backend Updated At: \(updatedProfile.updatedAt)")

        // Merge backend response with local state (preserve HealthKit sync flags)
        let mergedProfile = FitIQCore.UserProfile(
            id: profile.id,
            email: profile.email,
            name: updatedProfile.name,
            bio: updatedProfile.bio,
            username: profile.username,
            languageCode: updatedProfile.languageCode,
            dateOfBirth: profile.dateOfBirth,
            biologicalSex: profile.biologicalSex,
            heightCm: profile.heightCm,
            preferredUnitSystem: updatedProfile.preferredUnitSystem,
            hasPerformedInitialHealthKitSync: profile.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: profile.lastSuccessfulDailySyncDate,
            createdAt: profile.createdAt,
            updatedAt: updatedProfile.updatedAt
        )

        // Update local storage with merged profile
        try await userProfileStorage.save(userProfile: mergedProfile)
        print("ProfileSyncService: ✅ Merged profile saved to local storage")

        print("ProfileSyncService: ===== SYNC METADATA COMPLETE =====")

        // Remove from pending queue
        syncQueue.sync {
            pendingMetadataSync.remove(userId)
        }
    }

    private func syncPhysicalProfile(userId: String) async throws {
        print("ProfileSyncService: Starting physical profile sync for user \(userId)")

        // Validate user ID
        guard let userUUID = UUID(uuidString: userId) else {
            throw ProfileSyncError.invalidUserId(userId)
        }

        // Fetch current profile from local storage
        guard let profile = try await userProfileStorage.fetch(forUserID: userUUID) else {
            throw ProfileSyncError.profileNotFound(userId)
        }

        // Debug: Log what we're about to send
        print("ProfileSyncService: Syncing physical profile with:")
        print("  - biologicalSex: \(profile.biologicalSex ?? "nil")")
        print("  - heightCm: \(profile.heightCm?.description ?? "nil")")
        print("  - dateOfBirth: \(profile.dateOfBirth?.description ?? "nil")")

        // WORKAROUND: Backend /users/me/physical endpoint is for "biological sex and height" only
        // Even though the schema includes date_of_birth, the backend rejects requests with ONLY date_of_birth
        // Skip sync if we only have date_of_birth (which comes from registration and can't be changed)
        let hasBiologicalSex = profile.biologicalSex != nil && !profile.biologicalSex!.isEmpty
        let hasHeight = profile.heightCm != nil && profile.heightCm! > 0

        if !hasBiologicalSex && !hasHeight {
            print(
                "ProfileSyncService: ⚠️  Skipping physical profile sync - only date_of_birth present"
            )
            print(
                "ProfileSyncService: Backend /users/me/physical requires biological_sex or height_cm"
            )
            print(
                "ProfileSyncService: date_of_birth is set during registration and cannot be updated via this endpoint"
            )
            syncQueue.sync {
                pendingPhysicalSync.remove(userId)
            }
            return
        }

        // Call backend API to update profile with physical attributes
        // Note: Using updateProfile instead of separate physical profile endpoint
        let updatedProfile = try await userProfileRepository.updateProfile(
            userId: userId,
            name: profile.name,
            dateOfBirth: profile.dateOfBirth,
            gender: profile.biologicalSex,
            height: profile.heightCm,
            weight: nil,  // Not tracked in physical profile sync
            activityLevel: nil  // Not tracked in physical profile sync
        )

        // Save updated profile to local storage
        try await userProfileStorage.save(userProfile: updatedProfile)

        print("ProfileSyncService: Successfully synced physical profile for user \(userId)")

        // Remove from pending queue
        syncQueue.sync {
            pendingPhysicalSync.remove(userId)
        }
    }
}

// MARK: - Errors

enum ProfileSyncError: Error, LocalizedError {
    case invalidUserId(String)
    case profileNotFound(String)
    case syncInProgress
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUserId(let id):
            return "Invalid user ID format: \(id)"
        case .profileNotFound(let userId):
            return "Profile not found for user: \(userId)"
        case .syncInProgress:
            return "Sync operation already in progress"
        case .networkError(let error):
            return "Network error during sync: \(error.localizedDescription)"
        }
    }
}
