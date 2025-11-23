//
//  WorkoutSession.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Represents an active or completed workout session
/// Used for tracking a workout in progress
public struct WorkoutSession: Identifiable, Equatable {
    /// Session ID
    public let id: UUID
    
    /// User ID who owns this session
    public let userID: String
    
    /// Optional template this session is based on
    public let templateID: UUID?
    
    /// Workout name/title
    public var name: String
    
    /// Activity type
    public var activityType: WorkoutActivityType
    
    /// When the workout started
    public let startedAt: Date
    
    /// When the workout ended (nil if still in progress)
    public var endedAt: Date?
    
    /// Notes about the session
    public var notes: String?
    
    /// Exercises completed in this session
    public var exercises: [SessionExercise]
    
    /// Overall workout intensity (RPE 1-10)
    /// Set upon completion
    public var intensity: Int?
    
    /// Total calories burned (computed or manual)
    public var caloriesBurned: Int?
    
    /// Total distance covered in meters (for cardio)
    public var distanceMeters: Double?
    
    public init(
        id: UUID = UUID(),
        userID: String,
        templateID: UUID? = nil,
        name: String,
        activityType: WorkoutActivityType = .strengthTraining,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        notes: String? = nil,
        exercises: [SessionExercise] = [],
        intensity: Int? = nil,
        caloriesBurned: Int? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.userID = userID
        self.templateID = templateID
        self.name = name
        self.activityType = activityType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.exercises = exercises
        self.intensity = intensity
        self.caloriesBurned = caloriesBurned
        self.distanceMeters = distanceMeters
    }
}

/// Represents an exercise completed during a workout session
public struct SessionExercise: Identifiable, Equatable {
    /// Exercise ID
    public let id: UUID
    
    /// Session ID this exercise belongs to
    public let sessionID: UUID
    
    /// Exercise name
    public var name: String
    
    /// Order in the session
    public let orderIndex: Int
    
    /// Sets completed
    public var sets: [ExerciseSet]
    
    /// Notes for this exercise
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        name: String,
        orderIndex: Int,
        sets: [ExerciseSet] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.name = name
        self.orderIndex = orderIndex
        self.sets = sets
        self.notes = notes
    }
}

/// Represents a single set of an exercise
public struct ExerciseSet: Identifiable, Equatable {
    /// Set ID
    public let id: UUID
    
    /// Exercise ID this set belongs to
    public let exerciseID: UUID
    
    /// Set number (1, 2, 3, etc.)
    public let setNumber: Int
    
    /// Reps completed
    public var reps: Int?
    
    /// Weight used in kg
    public var weightKg: Double?
    
    /// Duration in seconds (for timed exercises)
    public var durationSeconds: Int?
    
    /// Distance covered in meters (for cardio)
    public var distanceMeters: Double?
    
    /// Whether set was completed
    public var isCompleted: Bool
    
    /// Notes for this set
    public var notes: String?
    
    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        isCompleted: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.isCompleted = isCompleted
        self.notes = notes
    }
}

// MARK: - Convenience Extensions

extension WorkoutSession {
    /// Check if session is still in progress
    var isInProgress: Bool {
        return endedAt == nil
    }
    
    /// Get total duration in minutes
    var durationMinutes: Int? {
        guard let endedAt = endedAt else {
            // If still in progress, calculate from start to now
            let duration = Date().timeIntervalSince(startedAt)
            return Int(duration / 60.0)
        }
        let duration = endedAt.timeIntervalSince(startedAt)
        return Int(duration / 60.0)
    }
    
    /// Get total sets completed
    var totalSetsCompleted: Int {
        return exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { $0.isCompleted }.count
        }
    }
    
    /// Get total exercises completed
    var exercisesCompleted: Int {
        return exercises.filter { !$0.sets.isEmpty }.count
    }
    
    /// Convert to WorkoutEntry for saving
    func toWorkoutEntry() -> WorkoutEntry {
        return WorkoutEntry(
            id: self.id,
            userID: self.userID,
            activityType: self.activityType,
            title: self.name,
            notes: self.notes,
            startedAt: self.startedAt,
            endedAt: self.endedAt,
            durationMinutes: self.durationMinutes,
            caloriesBurned: self.caloriesBurned,
            distanceMeters: self.distanceMeters,
            intensity: self.intensity,
            source: "Manual",
            sourceID: nil,
            createdAt: self.startedAt,
            updatedAt: self.endedAt ?? Date(),
            backendID: nil,
            syncStatus: .pending
        )
    }
}

extension SessionExercise {
    /// Get total reps completed
    var totalReps: Int {
        return sets.reduce(0) { total, set in
            total + (set.reps ?? 0)
        }
    }
    
    /// Get average weight used
    var averageWeight: Double? {
        let weights = sets.compactMap { $0.weightKg }
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }
}
