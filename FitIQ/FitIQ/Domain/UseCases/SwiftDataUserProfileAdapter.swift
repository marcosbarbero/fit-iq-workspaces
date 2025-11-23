//
//  SwiftDataUserProfileAdapter.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Updated for Phase 2.1 - Profile Unification (27/01/2025)
//  Now uses FitIQCore.UserProfile as the single source of truth
//

import FitIQCore
import Foundation
import SwiftData

/// Error types for user profile storage operations
enum UserProfileStorageError: Error, LocalizedError {
    case userProfileNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .userProfileNotFound:
            return "The user profile could not be found."
        case .saveFailed(let error):
            return "Failed to save user profile data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch user profile data: \(error.localizedDescription)"
        case .invalidData(let message):
            return "Invalid profile data: \(message)"
        }
    }
}

/// Adapter that implements UserProfileStoragePortProtocol using SwiftData
///
/// Maps between:
/// - Domain: FitIQCore.UserProfile (unified profile model)
/// - SwiftData: SDUserProfile (SchemaV10)
///
/// **Phase 2.1 Migration:**
/// - Removed old composite UserProfile (metadata + physical)
/// - Now uses FitIQCore.UserProfile directly
/// - SDUserProfile schema remains unchanged
/// - Only mapping logic updated
///
/// **Architecture:** Infrastructure Adapter (Hexagonal Architecture)
final class SwiftDataUserProfileAdapter: UserProfileStoragePortProtocol {

    // MARK: - Dependencies

    private let modelContainer: ModelContainer

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - UserProfileStoragePortProtocol Implementation

    /// Saves or updates a user profile
    ///
    /// Maps FitIQCore.UserProfile domain model to SDUserProfile SwiftData model.
    /// Uses fetch-or-create pattern to prevent duplicates.
    /// If profile exists (by userId), updates it. Otherwise creates new.
    func save(userProfile: FitIQCore.UserProfile) async throws {
        let context = ModelContext(modelContainer)

        // Use profile.id as userId (FitIQCore.UserProfile.id is the user ID)
        let userId = userProfile.id

        let predicate = #Predicate<SDUserProfile> { $0.id == userId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            if let existing = try context.fetch(descriptor).first {
                // Update existing profile
                updateSDUserProfile(existing, from: userProfile)
                print("SwiftDataAdapter: Updated existing profile for user \(userId)")
            } else {
                // Create new profile
                let newProfile = createSDUserProfile(from: userProfile)
                context.insert(newProfile)
                print("SwiftDataAdapter: Created new profile for user \(userId)")
            }

            try context.save()
        } catch {
            print("SwiftDataAdapter: Failed to save profile for user \(userId): \(error)")
            throw UserProfileStorageError.saveFailed(error)
        }
    }

    /// Cleans up duplicate profiles for a given user ID
    ///
    /// Keeps the most recently updated profile and deletes all others.
    /// This should be called during app initialization or after login.
    func cleanupDuplicateProfiles(forUserID userID: UUID) async throws {
        let context = ModelContext(modelContainer)

        print("SwiftDataAdapter: Cleaning up duplicate profiles for user \(userID)")

        let predicate = #Predicate<SDUserProfile> { $0.id == userID }
        let descriptor = FetchDescriptor(
            predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])

        do {
            let profiles = try context.fetch(descriptor)
            print("SwiftDataAdapter: Found \(profiles.count) profile(s) for user \(userID)")

            guard profiles.count > 1 else {
                print("SwiftDataAdapter: No duplicates found")
                return
            }

            // Keep the first one (most recently updated) and delete the rest
            let profilesToDelete = Array(profiles.dropFirst())
            print("SwiftDataAdapter: Deleting \(profilesToDelete.count) duplicate profile(s)")

            for profile in profilesToDelete {
                print("SwiftDataAdapter:   Deleting profile with name: '\(profile.name)'")
                context.delete(profile)
            }

            try context.save()
            print("SwiftDataAdapter: ✅ Duplicate cleanup complete")

        } catch {
            print("SwiftDataAdapter: ❌ Failed to cleanup duplicates: \(error)")
            throw UserProfileStorageError.saveFailed(error)
        }
    }

    /// Cleans up ALL duplicate profiles in the database
    ///
    /// Groups profiles by userId and keeps only the most recent one for each user.
    /// Should be called once during app migration or maintenance.
    func cleanupAllDuplicateProfiles() async throws {
        let context = ModelContext(modelContainer)

        print("SwiftDataAdapter: Starting cleanup of all duplicate profiles")

        let descriptor = FetchDescriptor<SDUserProfile>(sortBy: [
            SortDescriptor(\.updatedAt, order: .reverse)
        ])

        do {
            let allProfiles = try context.fetch(descriptor)
            print("SwiftDataAdapter: Found \(allProfiles.count) total profile(s)")

            // Group by userId
            var profilesByUserId: [UUID: [SDUserProfile]] = [:]
            for profile in allProfiles {
                profilesByUserId[profile.id, default: []].append(profile)
            }

            var totalDeleted = 0

            // For each userId, keep only the most recent profile
            for (userId, profiles) in profilesByUserId {
                guard profiles.count > 1 else { continue }

                print("SwiftDataAdapter: User \(userId) has \(profiles.count) profiles")

                // profiles is already sorted by updatedAt desc, so first is most recent
                let profilesToDelete = Array(profiles.dropFirst())

                for profile in profilesToDelete {
                    print("SwiftDataAdapter:   Deleting duplicate: '\(profile.name)'")
                    context.delete(profile)
                    totalDeleted += 1
                }
            }

            if totalDeleted > 0 {
                try context.save()
                print("SwiftDataAdapter: ✅ Deleted \(totalDeleted) duplicate profile(s)")
            } else {
                print("SwiftDataAdapter: ✅ No duplicates found")
            }

        } catch {
            print("SwiftDataAdapter: ❌ Failed to cleanup all duplicates: \(error)")
            throw UserProfileStorageError.saveFailed(error)
        }
    }

    /// Fetches a user profile by user ID
    ///
    /// Maps SDUserProfile SwiftData model to UserProfile domain model.
    func fetch(forUserID userID: UUID) async throws -> UserProfile? {
        let context = ModelContext(modelContainer)

        print("SwiftDataAdapter: Fetching profile for user ID: \(userID)")

        // First, let's see what profiles exist in storage
        let allDescriptor = FetchDescriptor<SDUserProfile>()
        let allProfiles = try? context.fetch(allDescriptor)
        print("SwiftDataAdapter: Found \(allProfiles?.count ?? 0) total profiles in storage")
        if let profiles = allProfiles {
            for profile in profiles {
                print(
                    "SwiftDataAdapter:   - Profile ID: \(profile.id), Name: '\(profile.name)', Email: '\(profile.email)'"
                )
            }
        }

        let predicate = #Predicate<SDUserProfile> { $0.id == userID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            guard let sdProfile = try context.fetch(descriptor).first else {
                print("SwiftDataAdapter: No profile found for user \(userID)")
                return nil
            }

            let userProfile = mapToDomain(sdProfile)
            print("SwiftDataAdapter: Fetched profile for user \(userID)")
            return userProfile

        } catch {
            print("SwiftDataAdapter: Failed to fetch profile for user \(userID): \(error)")
            throw UserProfileStorageError.fetchFailed(error)
        }
    }

    // MARK: - Mapping: Domain → SwiftData

    /// Creates a new SDUserProfile from UserProfile domain model
    private func createSDUserProfile(from userProfile: FitIQCore.UserProfile) -> SDUserProfile {
        let dateOfBirth = userProfile.dateOfBirth

        print(
            "SwiftDataAdapter: Creating SDUserProfile - DOB: \(dateOfBirth?.description ?? "nil")")
        print(
            "SwiftDataAdapter:   Source - FitIQCore.UserProfile DOB: \(dateOfBirth?.description ?? "nil")"
        )

        // Initialize bodyMetrics with height if present
        var initialBodyMetrics: [SDPhysicalAttribute] = []

        if let heightCm = userProfile.heightCm, heightCm > 0 {
            print("SwiftDataAdapter:   Initializing height in bodyMetrics: \(heightCm) cm")
            let heightMetric = SDPhysicalAttribute(
                id: UUID(),
                value: heightCm,
                type: .height,
                createdAt: Date(),
                updatedAt: Date(),
                backendID: nil,
                backendSyncedAt: nil,
                userProfile: nil  // Will be set via relationship
            )
            initialBodyMetrics.append(heightMetric)
        }

        return SDUserProfile(
            id: userProfile.id,  // FitIQCore.UserProfile.id is the user ID
            name: userProfile.name,
            email: userProfile.email,
            authToken: nil,
            refreshToken: nil,
            tokenExpiresAt: nil,
            refreshTokenExpiresAt: nil,
            dailyCalorieGoal: nil,
            unitSystem: userProfile.preferredUnitSystem,
            dateOfBirth: dateOfBirth,
            biologicalSex: userProfile.biologicalSex,
            dietaryAndActivityPreferences: nil,
            bodyMetrics: initialBodyMetrics,
            activitySnapshots: [],
            progressEntries: [],
            sleepSessions: [],
            moodEntries: [],
            mealLogs: [],
            photoRecognitions: [],
            workouts: [],
            createdAt: userProfile.createdAt,
            updatedAt: Date(),
            hasPerformedInitialHealthKitSync: userProfile.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: userProfile.lastSuccessfulDailySyncDate
        )
    }

    /// Updates an existing SDUserProfile from FitIQCore.UserProfile domain model
    private func updateSDUserProfile(
        _ sdProfile: SDUserProfile, from userProfile: FitIQCore.UserProfile
    ) {
        let dateOfBirth = userProfile.dateOfBirth

        print(
            "SwiftDataAdapter: Updating SDUserProfile - DOB: \(dateOfBirth?.description ?? "nil")")
        print("SwiftDataAdapter:   Previous DOB: \(sdProfile.dateOfBirth?.description ?? "nil")")

        // Update basic fields
        sdProfile.name = userProfile.name
        sdProfile.email = userProfile.email
        sdProfile.unitSystem = userProfile.preferredUnitSystem
        sdProfile.dateOfBirth = dateOfBirth

        // Update biological sex if present
        if let biologicalSex = userProfile.biologicalSex, !biologicalSex.isEmpty {
            if sdProfile.biologicalSex != biologicalSex {
                print("SwiftDataAdapter:   Updating biological sex: \(biologicalSex)")
                sdProfile.biologicalSex = biologicalSex
            } else {
                print("SwiftDataAdapter:   Biological sex unchanged")
            }
        }

        // Save height to bodyMetrics time-series (height changes over time)
        if let heightCm = userProfile.heightCm, heightCm > 0 {
            // Check if we need to add a new entry (value changed or first time)
            let existingHeightMetrics = (sdProfile.bodyMetrics ?? []).filter {
                $0.type == .height
            }
            let latestHeight = existingHeightMetrics.max(by: { $0.createdAt < $1.createdAt })

            if latestHeight?.value != heightCm {
                print(
                    "SwiftDataAdapter:   Height changed (\(latestHeight?.value ?? 0) → \(heightCm) cm), adding new bodyMetrics entry"
                )
                let heightMetric = SDPhysicalAttribute(
                    id: UUID(),
                    value: heightCm,
                    type: .height,
                    createdAt: Date(),
                    updatedAt: Date(),
                    backendID: nil,
                    backendSyncedAt: nil,
                    userProfile: sdProfile
                )
                if sdProfile.bodyMetrics == nil {
                    sdProfile.bodyMetrics = []
                }
                sdProfile.bodyMetrics?.append(heightMetric)
            } else {
                print(
                    "SwiftDataAdapter:   Height unchanged at \(heightCm) cm, skipping duplicate bodyMetrics entry"
                )
            }
        }

        // Update local state
        sdProfile.updatedAt = Date()
        sdProfile.hasPerformedInitialHealthKitSync = userProfile.hasPerformedInitialHealthKitSync
        sdProfile.lastSuccessfulDailySyncDate = userProfile.lastSuccessfulDailySyncDate
    }

    // MARK: - Mapping: SwiftData → Domain

    /// Maps SDUserProfile to FitIQCore.UserProfile domain model
    private func mapToDomain(_ sdProfile: SDUserProfile) -> FitIQCore.UserProfile {
        print("SwiftDataAdapter: Mapping SDUserProfile to FitIQCore.UserProfile")
        print(
            "SwiftDataAdapter:   SDUserProfile DOB: \(sdProfile.dateOfBirth?.description ?? "nil")")

        // Fetch latest height from bodyMetrics time-series
        let latestHeight: Double? = {
            guard let bodyMetrics = sdProfile.bodyMetrics, !bodyMetrics.isEmpty else {
                return nil
            }
            let heightMetrics = bodyMetrics.filter { $0.type == .height }
            return heightMetrics.max(by: { $0.createdAt < $1.createdAt })?.value
        }()

        print("SwiftDataAdapter:   Latest height: \(latestHeight?.description ?? "nil") cm")
        print("SwiftDataAdapter:   Biological sex: \(sdProfile.biologicalSex ?? "nil")")

        // Create FitIQCore.UserProfile with all available data
        return FitIQCore.UserProfile(
            id: sdProfile.id,
            email: sdProfile.email,
            name: sdProfile.name,
            bio: nil,  // SchemaV10 doesn't store bio
            username: nil,
            languageCode: nil,  // SchemaV10 doesn't store languageCode
            dateOfBirth: sdProfile.dateOfBirth,
            biologicalSex: sdProfile.biologicalSex,
            heightCm: latestHeight,
            preferredUnitSystem: sdProfile.unitSystem,
            hasPerformedInitialHealthKitSync: sdProfile.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: sdProfile.lastSuccessfulDailySyncDate,
            createdAt: sdProfile.createdAt,
            updatedAt: sdProfile.updatedAt ?? Date()
        )
    }

    // MARK: - Helper Methods

    /// Maps domain unit system string to SwiftData enum
    private func mapUnitSystem(_ unitSystem: String) -> UnitSystem {
        switch unitSystem.lowercased() {
        case "imperial":
            return .imperial
        case "metric":
            return .metric
        default:
            return .metric
        }
    }

    /// Maps SwiftData enum to domain unit system string
    private func mapUnitSystemToDomain(_ unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .imperial:
            return "imperial"
        case .metric:
            return "metric"
        }
    }
}
