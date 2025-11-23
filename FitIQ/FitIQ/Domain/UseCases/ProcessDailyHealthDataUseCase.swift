//
//  ProcessDailyHealthDataUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 16/10/2025.
//

import Foundation
import HealthKit

public final class ProcessDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol {
    private let healthDataSyncService: HealthDataSyncOrchestrator
    private let workoutSyncService: HealthKitWorkoutSyncService

    init(
        healthDataSyncService: HealthDataSyncOrchestrator,
        workoutSyncService: HealthKitWorkoutSyncService
    ) {
        self.healthDataSyncService = healthDataSyncService
        self.workoutSyncService = workoutSyncService
    }

    public func execute() async throws {
        // Sync daily activity data (steps, heart rate, etc.)
        await healthDataSyncService.syncAllDailyActivityData()
        print("ProcessDailyHealthDataUseCase: Daily health data processing complete.")

        // Sync workouts from yesterday and today
        do {
            let workoutCount = try await workoutSyncService.syncYesterdayWorkouts()
            print("ProcessDailyHealthDataUseCase: Synced \(workoutCount) workouts from yesterday")
            
            let todayCount = try await workoutSyncService.syncTodayWorkouts()
            print("ProcessDailyHealthDataUseCase: Synced \(todayCount) workouts from today")
        } catch {
            print("ProcessDailyHealthDataUseCase: Failed to sync workouts: \(error.localizedDescription)")
            // Don't throw - daily activity sync succeeded, workout sync failure shouldn't fail the whole operation
        }
    }
}
