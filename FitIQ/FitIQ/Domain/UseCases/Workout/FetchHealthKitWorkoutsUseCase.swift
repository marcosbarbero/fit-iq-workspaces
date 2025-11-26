//
//  FetchHealthKitWorkoutsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Migrated to FitIQCore on 2025-01-27 - Phase 5
//

import FitIQCore
import Foundation

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

    private let healthKitService: HealthKitServiceProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        authManager: AuthManager
    ) {
        self.healthKitService = healthKitService
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

        // Fetch workouts from HealthKit via FitIQCore
        // Note: HealthDataType.workout requires a WorkoutType parameter
        // We'll use .other as a generic type and rely on metadata for specifics
        let options = HealthQueryOptions(
            limit: nil,
            sortOrder: .chronological,
            aggregation: nil,  // Get individual workout samples
            includeMetadata: true  // Need metadata for workout details
        )

        let workoutMetrics = try await healthKitService.query(
            type: .workout(.other),  // Query all workout types
            from: startDate,
            to: endDate,
            options: options
        )

        // Convert HealthMetric to domain WorkoutEntry
        var workoutEntries: [WorkoutEntry] = []
        for metric in workoutMetrics {
            let workoutEntry = convertToWorkoutEntry(metric: metric, userID: userID)
            workoutEntries.append(workoutEntry)
        }

        print(
            "FetchHealthKitWorkoutsUseCase: Fetched \(workoutEntries.count) workouts from HealthKit"
        )

        return workoutEntries
    }

    // MARK: - Private Helpers

    /// Convert HealthMetric to domain WorkoutEntry
    private func convertToWorkoutEntry(metric: FitIQCore.HealthMetric, userID: String)
        -> WorkoutEntry
    {
        // Extract workout type from metadata or use default
        let activityTypeRaw = metric.metadata["workoutActivityType"] ?? "other"
        let activityType = WorkoutActivityType.fromString(activityTypeRaw)

        // Extract duration in minutes (from startDate to endDate)
        let start = metric.startDate ?? metric.date
        let end = metric.endDate ?? metric.date
        let durationMinutes = Int(end.timeIntervalSince(start) / 60.0)

        // Extract calories burned from metadata
        let caloriesBurned: Int? = {
            if let caloriesString = metric.metadata["totalEnergyBurned"] {
                return Int(caloriesString)
            }
            return nil
        }()

        // Extract distance from metadata
        let distanceMeters: Double? = {
            if let distanceString = metric.metadata["totalDistance"] {
                return Double(distanceString)
            }
            return nil
        }()

        // Extract intensity/effort score from metadata
        let intensity: Int? = {
            if let intensityString = metric.metadata["effortScore"] {
                return Int(intensityString)
            }
            return nil
        }()

        // Extract source ID (UUID) from metadata
        let sourceID = metric.metadata["uuid"] ?? UUID().uuidString

        // Create WorkoutEntry
        return WorkoutEntry(
            id: UUID(),
            userID: userID,
            activityType: activityType,
            title: nil,  // HealthKit doesn't provide workout titles
            notes: nil,
            startedAt: start,
            endedAt: end,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            distanceMeters: distanceMeters,
            intensity: intensity,  // RPE/effort from Apple Fitness post-workout slider (0-10 scale)
            source: "HealthKit",
            sourceID: sourceID,  // Use HealthKit UUID for deduplication
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
