// Domain/UseCases/PerformInitialHealthKitSyncUseCase.swift
import FitIQCore
import Foundation
import HealthKit

public protocol PerformInitialHealthKitSyncUseCaseProtocol {
    func execute(forUserID userID: UUID) async throws
}

public final class PerformInitialHealthKitSyncUseCase: PerformInitialHealthKitSyncUseCaseProtocol {

    // MARK: - Configuration

    /// Number of days to sync for historical health data (steps, heart rate, activity)
    /// - 30 days: Fast sync (~10-15 sec), good for immediate AI insights
    /// - 90 days: Balanced (~30-45 sec), recommended for trend analysis
    /// - 180 days: Comprehensive (~60-90 sec), detailed historical view
    /// - 365 days: Full year (~2-3 min), may cause performance issues
    private let historicalSyncDays: Int = 7

    // MARK: - Dependencies

    private let healthDataSyncService: HealthDataSyncOrchestrator
    private let userProfileStorage: UserProfileStoragePortProtocol
    // The type for this property is the public protocol now.
    private let requestHealthKitAuthorizationUseCase: RequestHealthKitAuthorizationUseCase
    private let healthRepository: HealthRepositoryProtocol
    private let authManager: AuthManager
    private let saveWeightProgressUseCase: SaveWeightProgressUseCase
    private let workoutSyncService: HealthKitWorkoutSyncService

    // The init method MUST include userProfileStorage and requestHealthKitAuthorizationUseCase
    init(
        healthDataSyncService: HealthDataSyncOrchestrator,
        userProfileStorage: UserProfileStoragePortProtocol,
        requestHealthKitAuthorizationUseCase: RequestHealthKitAuthorizationUseCase,  // This parameter is crucial
        healthRepository: HealthRepositoryProtocol,
        authManager: AuthManager,
        saveWeightProgressUseCase: SaveWeightProgressUseCase,
        workoutSyncService: HealthKitWorkoutSyncService
    ) {
        self.healthDataSyncService = healthDataSyncService
        self.userProfileStorage = userProfileStorage
        self.requestHealthKitAuthorizationUseCase = requestHealthKitAuthorizationUseCase
        self.healthRepository = healthRepository
        self.authManager = authManager
        self.saveWeightProgressUseCase = saveWeightProgressUseCase
        self.workoutSyncService = workoutSyncService
    }

    public func execute(forUserID userID: UUID) async throws {
        // Ensure HealthDataSyncService is configured before triggering any sync or auth
        healthDataSyncService.configure(withUserProfileID: userID)

        // Fetch the user profile to check the flag
        var userProfile = try await userProfileStorage.fetch(forUserID: userID)

        // FALLBACK: If profile not found, create a minimal one to allow sync to proceed
        if userProfile == nil {
            print(
                "PerformInitialHealthKitSyncUseCase: ⚠️ User profile not found for ID \(userID). Creating minimal profile to allow sync."
            )

            // Create a minimal profile with just the user ID
            let minimalProfile = FitIQCore.UserProfile(
                id: userID,
                email: "unknown@example.com",  // Placeholder
                name: "User",  // Placeholder name
                bio: nil,
                username: nil,
                languageCode: "en",
                dateOfBirth: nil,
                biologicalSex: nil,
                heightCm: nil,
                preferredUnitSystem: "metric",
                hasPerformedInitialHealthKitSync: false,
                lastSuccessfulDailySyncDate: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            // Save the minimal profile
            try await userProfileStorage.save(userProfile: minimalProfile)
            print("PerformInitialHealthKitSyncUseCase: ✅ Minimal profile created and saved")

            userProfile = minimalProfile
        }

        guard var profile = userProfile else {
            // This should never happen now, but keep as safety check
            throw UserProfileStorageError.userProfileNotFound
        }

        // Check if initial sync has already been performed for this user via the user profile
        if profile.hasPerformedInitialHealthKitSync {
            print(
                "PerformInitialHealthKitSyncUseCase: Initial HealthKit sync already completed for user \(userID). Skipping authorization request and historical sync, performing daily sync to ensure freshness."
            )

            await healthDataSyncService.syncAllDailyActivityData()
            print(
                "PerformInitialHealthKitSyncUseCase: Daily sync completed for existing user \(userID)."
            )
        }

        print(
            "PerformInitialHealthKitSyncUseCase: Initial HealthKit sync not yet completed for user \(userID). Starting authorization and sync process."
        )

        do {
            // STEP 1: Request HealthKit authorization
            print("PerformInitialHealthKitSyncUseCase: Requesting HealthKit authorization...")
            try await requestHealthKitAuthorizationUseCase.execute()
            print("PerformInitialHealthKitSyncUseCase: HealthKit authorization granted.")

            // STEP 2: Perform historical sync (configurable period for optimal performance and AI context)
            // Note: 90 days provides sufficient data for trend analysis and AI health insights
            // while maintaining good app performance. Full year would be ~17,520 hourly entries
            // vs ~4,320 entries for 90 days (75% reduction).
            print(
                "PerformInitialHealthKitSyncUseCase: Performing initial HealthKit historical sync (\(historicalSyncDays) days) for user \(userID)."
            )
            let calendar = Calendar.current
            let now = Date()
            let startDate =
                calendar.date(byAdding: .day, value: -historicalSyncDays, to: now)
                ?? Date.distantPast
            try await healthDataSyncService.syncHistoricalHealthData(from: startDate, to: now)
            print(
                "PerformInitialHealthKitSyncUseCase: Historical sync completed successfully (\(historicalSyncDays) days)."
            )

            // STEP 3: Sync historical weight from same period as activity data (with batching to avoid rate limiting)
            print(
                "PerformInitialHealthKitSyncUseCase: Syncing historical weight from last \(historicalSyncDays) days"
            )
            let weightEndDate = now
            let weightStartDate =
                calendar.date(byAdding: .day, value: -historicalSyncDays, to: weightEndDate)
                ?? Date.distantPast

            do {
                // Use fetchQuantitySamples with predicate for date range
                let predicate = HKQuery.predicateForSamples(
                    withStart: weightStartDate,
                    end: weightEndDate,
                    options: .strictStartDate
                )

                let weightSamples = try await healthRepository.fetchQuantitySamples(
                    for: .bodyMass,
                    unit: .gramUnit(with: .kilo),
                    predicateProvider: { predicate },
                    limit: nil
                )

                print(
                    "PerformInitialHealthKitSyncUseCase: Found \(weightSamples.count) weight samples from last \(historicalSyncDays) days to sync"
                )

                // Save locally WITHOUT immediate sync to avoid rate limiting
                print(
                    "PerformInitialHealthKitSyncUseCase: Saving weight samples locally (no immediate sync)"
                )

                for (index, sample) in weightSamples.enumerated() {
                    do {
                        // Save locally only - RemoteSyncService will batch sync later
                        _ = try await saveWeightProgressUseCase.execute(
                            weightKg: sample.value,
                            date: sample.date
                        )

                        // Add small delay every 10 samples to avoid overwhelming the system
                        if (index + 1) % 10 == 0 {
                            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                            print(
                                "PerformInitialHealthKitSyncUseCase: Saved \(index + 1)/\(weightSamples.count) samples"
                            )
                        }
                    } catch {
                        print(
                            "PerformInitialHealthKitSyncUseCase: Failed to save weight sample: \(error.localizedDescription)"
                        )
                        // Continue with other samples
                    }
                }

                print(
                    "PerformInitialHealthKitSyncUseCase: All weight samples saved locally. Background sync will process them."
                )

                print("PerformInitialHealthKitSyncUseCase: Weight sync complete")
            } catch {
                print(
                    "PerformInitialHealthKitSyncUseCase: Failed to fetch weight from HealthKit: \(error.localizedDescription)"
                )
                // Don't throw, continue with other syncs
            }

            // STEP 3.5: Sync historical workouts from HealthKit
            print(
                "PerformInitialHealthKitSyncUseCase: Syncing historical workouts from last \(historicalSyncDays) days"
            )
            do {
                let workoutCount = try await workoutSyncService.syncWorkouts(
                    from: weightStartDate,
                    to: weightEndDate
                )
                print(
                    "PerformInitialHealthKitSyncUseCase: Successfully synced \(workoutCount) workouts from HealthKit"
                )
            } catch {
                print(
                    "PerformInitialHealthKitSyncUseCase: Failed to sync workouts from HealthKit: \(error.localizedDescription)"
                )
                // Don't throw, continue with other syncs
            }

            // STEP 4: Perform an immediate daily sync to ensure today's snapshot is up-to-date
            print(
                "PerformInitialHealthKitSyncUseCase: Performing immediate daily sync for current day."
            )
            await healthDataSyncService.syncAllDailyActivityData()
            print("PerformInitialHealthKitSyncUseCase: Daily sync completed successfully.")

            // STEP 5: Update the flag on the user profile and save it AFTER all syncs are successful
            let updatedProfile = FitIQCore.UserProfile(
                id: profile.id,
                email: profile.email,
                name: profile.name,
                bio: profile.bio,
                username: profile.username,
                languageCode: profile.languageCode,
                dateOfBirth: profile.dateOfBirth,
                biologicalSex: profile.biologicalSex,
                heightCm: profile.heightCm,
                preferredUnitSystem: profile.preferredUnitSystem,
                hasPerformedInitialHealthKitSync: true,
                lastSuccessfulDailySyncDate: now,
                createdAt: profile.createdAt,
                updatedAt: Date()
            )
            try await userProfileStorage.save(userProfile: updatedProfile)

            print(
                "PerformInitialHealthKitSyncUseCase: Initial HealthKit setup (auth + historical + daily sync) completed successfully for user \(userID)."
            )
        } catch let error as HealthKitError {
            // Specifically handle authorization denied to avoid setting flag
            if case .authorizationDenied = error {
                print(
                    "PerformInitialHealthKitSyncUseCase: HealthKit authorization denied by user for ID \(userID). Initial sync process aborted."
                )
                // Do NOT set hasPerformedInitialHealthKitSync to true. User can retry later.
            } else {
                print(
                    "PerformInitialHealthKitSyncUseCase: HealthKit-related error during initial sync for user \(userID): \(error.localizedDescription)"
                )
            }
            throw error  // Re-throw HealthKit errors
        } catch {
            print(
                "PerformInitialHealthKitSyncUseCase: An unexpected error occurred during initial HealthKit sync for user \(userID): \(error.localizedDescription)"
            )
            throw error  // Re-throw other errors
        }
    }
}
