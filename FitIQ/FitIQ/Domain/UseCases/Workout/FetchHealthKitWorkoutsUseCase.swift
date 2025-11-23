//
//  FetchHealthKitWorkoutsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation
import HealthKit

/// Protocol defining the contract for fetching workouts from HealthKit
protocol FetchHealthKitWorkoutsUseCase {
    /// Fetches workouts from HealthKit for a date range
    /// - Parameters:
    ///   - from: Start date for fetching workouts
    ///   - to: End date for fetching workouts
    /// - Returns: Array of workout entries from HealthKit
    func execute(from startDate: Date, to endDate: Date) async throws -> [WorkoutEntry]
}

/// Implementation of FetchHealthKitWorkoutsUseCase
final class FetchHealthKitWorkoutsUseCaseImpl: FetchHealthKitWorkoutsUseCase {

    // MARK: - Dependencies

    private let healthRepository: HealthRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        healthRepository: HealthRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.healthRepository = healthRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(from startDate: Date, to endDate: Date) async throws -> [WorkoutEntry] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw FetchHealthKitWorkoutsError.userNotAuthenticated
        }

        print(
            "FetchHealthKitWorkoutsUseCase: Fetching HealthKit workouts from \(startDate) to \(endDate)"
        )

        // Fetch workouts from HealthKit via health repository
        let hkWorkouts = try await healthRepository.fetchWorkouts(from: startDate, to: endDate)

        // Convert HKWorkout to domain WorkoutEntry (with effort scores)
        var workoutEntries: [WorkoutEntry] = []
        for hkWorkout in hkWorkouts {
            let workoutEntry = await convertToWorkoutEntry(hkWorkout: hkWorkout, userID: userID)
            workoutEntries.append(workoutEntry)
        }

        print(
            "FetchHealthKitWorkoutsUseCase: Fetched \(workoutEntries.count) workouts from HealthKit"
        )

        return workoutEntries
    }

    // MARK: - Private Helpers

    /// Convert HKWorkout to domain WorkoutEntry
    private func convertToWorkoutEntry(hkWorkout: HKWorkout, userID: String) async -> WorkoutEntry {
        // Map HealthKit activity type to domain enum
        let activityType = WorkoutActivityType(from: hkWorkout.workoutActivityType)

        // Extract duration in minutes
        let durationMinutes = Int(hkWorkout.duration / 60.0)

        // Extract calories burned (if available)
        var caloriesBurned: Int?
        if let energyBurned = hkWorkout.totalEnergyBurned {
            caloriesBurned = Int(energyBurned.doubleValue(for: .kilocalorie()))
        }

        // Extract distance (if available)
        var distanceMeters: Double?
        if let distance = hkWorkout.totalDistance {
            distanceMeters = distance.doubleValue(for: .meter())
        }

        // Extract intensity/RPE from Apple Fitness post-workout rating (iOS 18+)
        // In iOS 18+, effort score is a separate HKQuantitySample, not in workout metadata
        var intensity: Int?

        // Try to fetch effort score as separate quantity sample (iOS 18+)
        do {
            intensity = try await healthRepository.fetchWorkoutEffortScore(for: hkWorkout)
            if let score = intensity {
                print("FetchHealthKitWorkoutsUseCase: ✅ Found effort score: \(score)")
            } else {
                print("FetchHealthKitWorkoutsUseCase: ℹ️ No effort score found for this workout")
            }
        } catch {
            print(
                "FetchHealthKitWorkoutsUseCase: ⚠️ Error fetching effort score: \(error.localizedDescription)"
            )
        }

        // Create WorkoutEntry
        return WorkoutEntry(
            id: UUID(),
            userID: userID,
            activityType: activityType,
            title: nil,  // HealthKit doesn't provide workout titles
            notes: nil,
            startedAt: hkWorkout.startDate,
            endedAt: hkWorkout.endDate,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            distanceMeters: distanceMeters,
            intensity: intensity,  // RPE/effort from Apple Fitness post-workout slider (0-10 scale)
            source: "HealthKit",
            sourceID: hkWorkout.uuid.uuidString,  // Use HealthKit UUID for deduplication
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending
        )
    }

}

// MARK: - Errors

enum FetchHealthKitWorkoutsError: Error, LocalizedError {
    case userNotAuthenticated
    case healthKitNotAuthorized
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch workouts"
        case .healthKitNotAuthorized:
            return "HealthKit authorization is required to fetch workouts"
        case .fetchFailed(let message):
            return "Failed to fetch workouts from HealthKit: \(message)"
        }
    }
}
