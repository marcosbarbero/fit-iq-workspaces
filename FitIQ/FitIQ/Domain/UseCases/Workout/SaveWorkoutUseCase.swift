//
//  SaveWorkoutUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Protocol defining the contract for saving workout entries
protocol SaveWorkoutUseCase {
    /// Saves a workout entry locally and triggers backend sync via Outbox Pattern
    /// - Parameter workoutEntry: The workout entry to save
    /// - Returns: The local UUID of the saved workout
    func execute(workoutEntry: WorkoutEntry) async throws -> UUID
}

/// Implementation of SaveWorkoutUseCase following the Outbox Pattern
final class SaveWorkoutUseCaseImpl: SaveWorkoutUseCase {

    // MARK: - Dependencies

    private let workoutRepository: WorkoutRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        workoutRepository: WorkoutRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.workoutRepository = workoutRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(workoutEntry: WorkoutEntry) async throws -> UUID {
        // Validate input - WorkoutActivityType is an enum, so it's always valid if present
        // No validation needed for activityType

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveWorkoutError.userNotAuthenticated
        }

        print(
            "SaveWorkoutUseCase: Saving workout '\(workoutEntry.activityType)' for user \(userID)")

        // Check for duplicate by sourceID (for HealthKit imports)
        if let sourceID = workoutEntry.sourceID {
            if let existingWorkout = try await workoutRepository.fetchBySourceID(
                sourceID,
                forUserID: userID
            ) {
                print(
                    "SaveWorkoutUseCase: Workout with sourceID '\(sourceID)' already exists. Local ID: \(existingWorkout.id)"
                )
                return existingWorkout.id
            }
        }

        // Create workout entry with pending sync status
        var workoutToSave = workoutEntry
        // Ensure the workout has the correct userID and pending status
        workoutToSave = WorkoutEntry(
            id: workoutEntry.id,
            userID: userID,
            activityType: workoutEntry.activityType,
            title: workoutEntry.title,
            notes: workoutEntry.notes,
            startedAt: workoutEntry.startedAt,
            endedAt: workoutEntry.endedAt,
            durationMinutes: workoutEntry.durationMinutes,
            caloriesBurned: workoutEntry.caloriesBurned,
            distanceMeters: workoutEntry.distanceMeters,
            intensity: workoutEntry.intensity,
            source: workoutEntry.source,
            sourceID: workoutEntry.sourceID,
            createdAt: workoutEntry.createdAt,
            updatedAt: Date(),
            backendID: nil,
            syncStatus: .pending  // Mark as pending for sync
        )

        // Save locally (repository will trigger Outbox Pattern)
        let localID = try await workoutRepository.save(
            workoutEntry: workoutToSave,
            forUserID: userID
        )

        print("SaveWorkoutUseCase: Successfully saved workout with local ID: \(localID)")

        // Repository automatically creates Outbox event for backend sync
        // OutboxProcessorService will pick it up and sync to backend

        return localID
    }
}

// MARK: - Errors

enum SaveWorkoutError: Error, LocalizedError {
    case invalidActivityType
    case userNotAuthenticated
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidActivityType:
            return "Activity type cannot be empty"
        case .userNotAuthenticated:
            return "User must be authenticated to save workout"
        case .saveFailed(let message):
            return "Failed to save workout: \(message)"
        }
    }
}
