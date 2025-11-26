//
//  HealthKitProfileSyncService.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Part of Profile Edit Implementation - HealthKit Integration
//  Migrated to FitIQCore on 2025-01-27 - Phase 5
//

import Combine
import FitIQCore
import Foundation
import HealthKit

/// Service for synchronizing physical profile changes to HealthKit
///
/// This service listens to profile events and writes relevant data to HealthKit:
/// - Height (can be written)
/// - Date of Birth (read-only in HealthKit, user must set in Health app)
/// - Biological Sex (read-only in HealthKit, user must set in Health app)
///
/// **Architecture:** Infrastructure Service (Adapter for domain events)
///
/// **Related Components:**
/// - `ProfileEventPublisherProtocol` - Source of domain events
/// - `HealthKitAdapter` - HealthKit integration
/// - `UserProfileStoragePortProtocol` - Local storage
///
protocol HealthKitProfileSyncServiceProtocol {
    /// Start listening to profile events and sync to HealthKit
    func startListening()

    /// Stop listening to profile events
    func stopListening()

    /// Manually sync current profile to HealthKit
    func syncCurrentProfile() async throws
}

/// Implementation of HealthKitProfileSyncService
final class HealthKitProfileSyncService: HealthKitProfileSyncServiceProtocol {

    // MARK: - Dependencies

    private let profileEventPublisher: ProfileEventPublisherProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let authService: HealthAuthorizationServiceProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        profileEventPublisher: ProfileEventPublisherProtocol,
        healthKitService: HealthKitServiceProtocol,
        authService: HealthAuthorizationServiceProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManager
    ) {
        self.profileEventPublisher = profileEventPublisher
        self.healthKitService = healthKitService
        self.authService = authService
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager

        print("HealthKitProfileSyncService: Initialized")
    }

    // MARK: - Public Methods

    func startListening() {
        print("HealthKitProfileSyncService: Starting to listen for profile events")

        profileEventPublisher.publisher
            .sink { [weak self] event in
                self?.handleProfileEvent(event)
            }
            .store(in: &cancellables)
    }

    func stopListening() {
        print("HealthKitProfileSyncService: Stopping profile event listening")
        cancellables.removeAll()
    }

    func syncCurrentProfile() async throws {
        print("HealthKitProfileSyncService: Manually syncing current profile to HealthKit")

        guard let userId = authManager.currentUserProfileID else {
            print("HealthKitProfileSyncService: No current user ID, skipping sync")
            return
        }

        guard let profile = try await userProfileStorage.fetch(forUserID: userId) else {
            print("HealthKitProfileSyncService: No profile found for user \(userId)")
            return
        }

        try await syncPhysicalProfileToHealthKit(profile: profile)
    }

    // MARK: - Private Methods

    private func handleProfileEvent(_ event: ProfileEvent) {
        print("HealthKitProfileSyncService: Received event - \(event)")

        switch event {
        case .physicalProfileUpdated(let userId, _):
            // Only sync physical profile changes (metadata doesn't go to HealthKit)
            Task {
                do {
                    guard let userUUID = UUID(uuidString: userId) else {
                        print("HealthKitProfileSyncService: Invalid user ID format: \(userId)")
                        return
                    }

                    guard let profile = try await userProfileStorage.fetch(forUserID: userUUID)
                    else {
                        print("HealthKitProfileSyncService: Profile not found for user \(userId)")
                        return
                    }

                    try await syncPhysicalProfileToHealthKit(profile: profile)
                } catch {
                    print("HealthKitProfileSyncService: Failed to sync to HealthKit: \(error)")
                }
            }

        case .metadataUpdated:
            // Metadata doesn't sync to HealthKit
            break
        }
    }

    private func syncPhysicalProfileToHealthKit(profile: FitIQCore.UserProfile) async throws {
        // Check if HealthKit is available
        guard authService.isHealthKitAvailable() else {
            print("HealthKitProfileSyncService: HealthKit not available on this device")
            return
        }

        // Sync height (can be written to HealthKit)
        if let heightCm = profile.heightCm, heightCm > 0 {
            do {
                // Convert height to meters and save using FitIQCore
                let heightInMeters = heightCm / 100.0
                let metric = FitIQCore.HealthMetric(
                    type: .height,
                    value: heightInMeters,
                    unit: "m",
                    date: Date(),
                    source: "FitIQ",
                    metadata: [:]
                )
                try await healthKitService.save(metric: metric)
                print("HealthKitProfileSyncService: Successfully synced height to HealthKit")
            } catch {
                print("HealthKitProfileSyncService: Failed to save height to HealthKit: \(error)")
                // Don't throw - continue with other fields
            }
        }

        // Date of birth and biological sex are READ-ONLY in HealthKit
        // Log informational messages about these fields
        if let dob = profile.dateOfBirth {
            print(
                "HealthKitProfileSyncService: Date of birth (\(dob)) cannot be written to HealthKit (user must set in Health app)"
            )
        }

        if let sex = profile.biologicalSex {
            print(
                "HealthKitProfileSyncService: Biological sex (\(sex)) cannot be written to HealthKit (user must set in Health app)"
            )
        }

        // Verify HealthKit data matches (for date of birth and biological sex)
        await verifyHealthKitAlignment(profile: profile)
    }

    private func verifyHealthKitAlignment(profile: FitIQCore.UserProfile) async {
        // Check if date of birth matches
        if let profileDob = profile.dateOfBirth {
            do {
                // Fetch date of birth using FitIQCore HealthKitService
                if let healthKitDob = try await healthKitService.getDateOfBirth() {
                    let calendar = Calendar.current
                    let isSameDay = calendar.isDate(profileDob, inSameDayAs: healthKitDob)

                    if isSameDay {
                        print("HealthKitProfileSyncService: ✅ Date of birth matches HealthKit")
                    } else {
                        print(
                            "HealthKitProfileSyncService: ⚠️ Date of birth mismatch - Profile: \(profileDob), HealthKit: \(healthKitDob)"
                        )
                    }
                } else {
                    print(
                        "HealthKitProfileSyncService: ⚠️ Could not fetch date of birth from HealthKit"
                    )
                }
            } catch {
                print(
                    "HealthKitProfileSyncService: Could not fetch HealthKit date of birth: \(error)"
                )
            }
        }

        // Check if biological sex matches
        if let profileSex = profile.biologicalSex {
            do {
                // Fetch biological sex using FitIQCore HealthKitService
                if let healthKitSexString = try await healthKitService.getBiologicalSex() {
                    if profileSex.lowercased() == healthKitSexString.lowercased() {
                        print("HealthKitProfileSyncService: ✅ Biological sex matches HealthKit")
                    } else {
                        print(
                            "HealthKitProfileSyncService: ⚠️ Biological sex mismatch - Profile: \(profileSex), HealthKit: \(healthKitSexString)"
                        )
                    }
                } else {
                    print(
                        "HealthKitProfileSyncService: ⚠️ Biological sex not set in HealthKit"
                    )
                }
            } catch {
                print(
                    "HealthKitProfileSyncService: Could not fetch HealthKit biological sex: \(error)"
                )
            }
        }
    }

    private func hkBiologicalSexToString(_ sex: HKBiologicalSex) -> String {
        switch sex {
        case .female:
            return "female"
        case .male:
            return "male"
        case .other:
            return "other"
        case .notSet:
            return ""
        @unknown default:
            return ""
        }
    }
}

// MARK: - Errors

enum HealthKitProfileSyncError: Error, LocalizedError {
    case healthKitNotAvailable
    case profileNotFound(String)
    case syncFailed(Error)

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .profileNotFound(let userId):
            return "Profile not found for user: \(userId)"
        case .syncFailed(let error):
            return "Failed to sync to HealthKit: \(error.localizedDescription)"
        }
    }
}
