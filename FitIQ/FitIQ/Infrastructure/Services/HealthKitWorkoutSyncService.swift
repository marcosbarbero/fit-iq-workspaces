//
//  HealthKitWorkoutSyncService.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Service responsible for syncing workouts from HealthKit to local storage
///
/// This service fetches workout data from HealthKit and saves it to the local database
/// using the SaveWorkoutUseCase, which triggers the Outbox Pattern for backend sync.
///
/// **Architecture:**
/// - Infrastructure layer service
/// - Orchestrates workout sync from HealthKit to local DB
/// - Used by initial sync and daily sync flows
final class HealthKitWorkoutSyncService {
    
    // MARK: - Dependencies
    
    private let fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase
    private let saveWorkoutUseCase: SaveWorkoutUseCase
    
    // MARK: - Initialization
    
    init(
        fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase,
        saveWorkoutUseCase: SaveWorkoutUseCase
    ) {
        self.fetchHealthKitWorkoutsUseCase = fetchHealthKitWorkoutsUseCase
        self.saveWorkoutUseCase = saveWorkoutUseCase
    }
    
    // MARK: - Public API
    
    /// Syncs workouts from HealthKit for a specified date range
    /// - Parameters:
    ///   - startDate: The start date to fetch workouts from
    ///   - endDate: The end date to fetch workouts until
    /// - Returns: Number of workouts successfully synced
    func syncWorkouts(from startDate: Date, to endDate: Date) async throws -> Int {
        print("HealthKitWorkoutSyncService: 🏋️ Starting workout sync from \(startDate) to \(endDate)")
        
        // 1. Fetch workouts from HealthKit
        let workouts = try await fetchHealthKitWorkoutsUseCase.execute(
            from: startDate,
            to: endDate
        )
        
        guard !workouts.isEmpty else {
            print("HealthKitWorkoutSyncService: ℹ️ No workouts found in date range")
            return 0
        }
        
        print("HealthKitWorkoutSyncService: 📋 Fetched \(workouts.count) workouts from HealthKit")
        
        // 2. Save each workout (with deduplication)
        var successCount = 0
        var skippedCount = 0
        var errorCount = 0
        
        for (index, workout) in workouts.enumerated() {
            do {
                let localID = try await saveWorkoutUseCase.execute(workoutEntry: workout)
                successCount += 1
                
                // Log progress every 10 workouts or on last workout
                if (index + 1) % 10 == 0 || index == workouts.count - 1 {
                    print("HealthKitWorkoutSyncService: Progress: \(index + 1)/\(workouts.count) workouts processed")
                }
                
            } catch WorkoutRepositoryError.duplicateWorkout {
                // Duplicate workouts are expected (deduplication working)
                skippedCount += 1
            } catch {
                errorCount += 1
                print("HealthKitWorkoutSyncService: ❌ Failed to save workout: \(error.localizedDescription)")
            }
        }
        
        print("HealthKitWorkoutSyncService: ✅ Sync complete - Saved: \(successCount), Skipped (duplicates): \(skippedCount), Errors: \(errorCount)")
        
        return successCount
    }
    
    /// Syncs recent workouts (last 7 days)
    /// Convenience method for quick syncs
    func syncRecentWorkouts() async throws -> Int {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        return try await syncWorkouts(from: startDate, to: endDate)
    }
    
    /// Syncs workouts for today
    /// Used for daily sync operations
    func syncTodayWorkouts() async throws -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        return try await syncWorkouts(from: startOfDay, to: now)
    }
    
    /// Syncs workouts for yesterday
    /// Used for daily sync operations to catch any missed workouts
    func syncYesterdayWorkouts() async throws -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            return 0
        }
        
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday) ?? yesterday
        
        return try await syncWorkouts(from: startOfYesterday, to: endOfYesterday)
    }
}
