//
//  StartWorkoutSessionUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Use case for starting a new workout session
public protocol StartWorkoutSessionUseCase {
    /// Execute the use case to start a workout
    /// - Parameters:
    ///   - template: Optional template to base the session on
    ///   - name: Custom name (overrides template name)
    ///   - activityType: Activity type
    /// - Returns: The started workout session
    func execute(
        template: WorkoutTemplate?,
        name: String?,
        activityType: WorkoutActivityType
    ) async throws -> WorkoutSession
}

/// Implementation of StartWorkoutSessionUseCase
public final class StartWorkoutSessionUseCaseImpl: StartWorkoutSessionUseCase {
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    public func execute(
        template: WorkoutTemplate? = nil,
        name: String? = nil,
        activityType: WorkoutActivityType = .strengthTraining
    ) async throws -> WorkoutSession {
        print("StartWorkoutSessionUseCase: Starting workout session")
        
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw WorkoutSessionError.notAuthenticated
        }
        
        // Determine session name
        let sessionName = name ?? template?.name ?? "Workout"
        
        // Build exercises from template if provided
        var exercises: [SessionExercise] = []
        if let template = template {
            exercises = template.exercises.map { templateExercise in
                SessionExercise(
                    id: UUID(),
                    sessionID: UUID(), // Will be updated with actual session ID
                    name: templateExercise.exerciseName,
                    orderIndex: templateExercise.orderIndex,
                    sets: [], // Sets will be added as user progresses
                    notes: templateExercise.notes
                )
            }
        }
        
        // Create session
        let session = WorkoutSession(
            id: UUID(),
            userID: userID,
            templateID: template?.id,
            name: sessionName,
            activityType: activityType,
            startedAt: Date(),
            endedAt: nil,
            notes: nil,
            exercises: exercises,
            intensity: nil,
            caloriesBurned: nil,
            distanceMeters: nil
        )
        
        print("StartWorkoutSessionUseCase: ✅ Started session '\(sessionName)' with ID: \(session.id)")
        
        return session
    }
}

/// Errors for workout session operations
public enum WorkoutSessionError: Error, LocalizedError {
    case notAuthenticated
    case sessionNotFound
    case sessionAlreadyCompleted
    case invalidIntensity
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated to start a workout"
        case .sessionNotFound:
            return "Workout session not found"
        case .sessionAlreadyCompleted:
            return "This workout session has already been completed"
        case .invalidIntensity:
            return "Intensity must be between 1 and 10"
        }
    }
}
