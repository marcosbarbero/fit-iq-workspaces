//
//  CompleteWorkoutSessionUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//  Migrated to FitIQCore on 2025-01-27 - Phase 5
//

import FitIQCore
import Foundation

/// Use case for completing a workout session
/// Saves the workout, writes to HealthKit, and syncs to backend
public protocol CompleteWorkoutSessionUseCase {
    /// Execute the use case to complete a workout
    /// - Parameters:
    ///   - session: The workout session to complete
    ///   - intensity: RPE intensity score (1-10)
    /// - Returns: The completed workout entry
    func execute(
        session: WorkoutSession,
        intensity: Int
    ) async throws -> WorkoutEntry
}

/// Implementation of CompleteWorkoutSessionUseCase
public final class CompleteWorkoutSessionUseCaseImpl: CompleteWorkoutSessionUseCase {
    private let saveWorkoutUseCase: SaveWorkoutUseCase
    private let healthKitService: HealthKitServiceProtocol

    init(
        saveWorkoutUseCase: SaveWorkoutUseCase,
        healthKitService: HealthKitServiceProtocol
    ) {
        self.saveWorkoutUseCase = saveWorkoutUseCase
        self.healthKitService = healthKitService
    }

    public func execute(
        session: WorkoutSession,
        intensity: Int
    ) async throws -> WorkoutEntry {
        print("CompleteWorkoutSessionUseCase: Completing workout session '\(session.name)'")

        // Validate
        guard session.isInProgress else {
            throw WorkoutSessionError.sessionAlreadyCompleted
        }

        guard intensity >= 1 && intensity <= 10 else {
            throw WorkoutSessionError.invalidIntensity
        }

        // Complete the session
        var completedSession = session
        completedSession.endedAt = Date()
        completedSession.intensity = intensity

        // Convert to WorkoutEntry
        var workoutEntry = completedSession.toWorkoutEntry()

        print("CompleteWorkoutSessionUseCase: Converting session to workout entry")

        // Save to local DB (with Outbox Pattern for backend sync)
        let savedWorkoutID = try await saveWorkoutUseCase.execute(workoutEntry: workoutEntry)

        print(
            "CompleteWorkoutSessionUseCase: ✅ Saved workout to local DB with ID: \(savedWorkoutID)")

        // Write to HealthKit
        do {
            try await writeToHealthKit(workout: completedSession)
            print("CompleteWorkoutSessionUseCase: ✅ Wrote workout to HealthKit")
        } catch {
            print("CompleteWorkoutSessionUseCase: ⚠️ Failed to write to HealthKit: \(error)")
            // Continue - local save is sufficient
        }

        print("CompleteWorkoutSessionUseCase: ✅ Completed workout session")

        return workoutEntry
    }

    // MARK: - Private Helpers

    private func writeToHealthKit(workout: WorkoutSession) async throws {
        guard let startDate = workout.startedAt as Date?,
            let endDate = workout.endedAt
        else {
            return
        }

        // Map activity type to HealthKit workout type
        let hkActivityType = workout.activityType.toHKWorkoutActivityType()

        // Calculate total energy if we have calorie data
        let totalEnergy = workout.caloriesBurned.map { Double($0) }

        // Calculate total distance if we have distance data
        let totalDistance = workout.distanceMeters

        // Prepare metadata for FitIQCore
        var metadata: [String: Any] = [
            "FitIQ Workout": workout.name,
            "Intensity": "\(workout.intensity ?? 0)",
            "workoutActivityType": String(hkActivityType),
        ]

        if let energy = totalEnergy {
            metadata["totalEnergyBurned"] = energy
        }

        if let distance = totalDistance {
            metadata["totalDistance"] = distance
        }

        // Write workout to HealthKit using FitIQCore
        let durationSeconds = endDate.timeIntervalSince(startDate)

        // Convert metadata to String-only dictionary for FitIQCore
        var stringMetadata: [String: String] = [:]
        for (key, value) in metadata {
            stringMetadata[key] = "\(value)"
        }

        let metric = FitIQCore.HealthMetric(
            type: .workout(.other),
            value: durationSeconds,
            unit: "s",
            date: endDate,
            startDate: startDate,
            endDate: endDate,
            source: "FitIQ",
            metadata: stringMetadata
        )
        try await healthKitService.save(metric: metric)
    }
}

// MARK: - WorkoutActivityType Extensions

extension WorkoutActivityType {
    /// Convert to HealthKit workout activity type
    func toHKWorkoutActivityType() -> Int {
        // Map to HKWorkoutActivityType raw values
        // This is a simplified mapping - extend as needed
        switch self {
        case .running:
            return 37  // HKWorkoutActivityType.running
        case .cycling:
            return 13  // HKWorkoutActivityType.cycling
        case .walking:
            return 52  // HKWorkoutActivityType.walking
        case .swimming:
            return 46  // HKWorkoutActivityType.swimming
        case .yoga:
            return 57  // HKWorkoutActivityType.yoga
        case .strengthTraining, .functionalStrengthTraining, .traditionalStrengthTraining:
            return 35  // HKWorkoutActivityType.traditionalStrengthTraining
        case .hiit:
            return 63  // HKWorkoutActivityType.highIntensityIntervalTraining
        case .elliptical:
            return 16  // HKWorkoutActivityType.elliptical
        case .rowing:
            return 39  // HKWorkoutActivityType.rowing
        case .stairs, .stairClimbing:
            return 42  // HKWorkoutActivityType.stairClimbing
        case .dance:
            return 15  // HKWorkoutActivityType.dance
        case .pilates:
            return 38  // HKWorkoutActivityType.pilates
        case .boxing:
            return 10  // HKWorkoutActivityType.boxing
        case .martialArts:
            return 28  // HKWorkoutActivityType.martialArts
        case .basketball:
            return 5  // HKWorkoutActivityType.basketball
        case .soccer:
            return 40  // HKWorkoutActivityType.soccer
        case .tennis:
            return 47  // HKWorkoutActivityType.tennis
        case .golf:
            return 21  // HKWorkoutActivityType.golf
        case .hiking:
            return 24  // HKWorkoutActivityType.hiking
        default:
            return 3000  // HKWorkoutActivityType.other
        }
    }
}
