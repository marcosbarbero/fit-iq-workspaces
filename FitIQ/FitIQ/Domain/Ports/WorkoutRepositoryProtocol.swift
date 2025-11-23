//
//  WorkoutRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Protocol defining workout repository operations for local storage and sync
/// Follows the Outbox Pattern for reliable backend synchronization
protocol WorkoutRepositoryProtocol {
    
    // MARK: - Local Storage Operations
    
    /// Save a workout entry locally and trigger backend sync via Outbox Pattern
    /// - Parameters:
    ///   - workoutEntry: The workout to save
    ///   - userID: The user ID who owns the workout
    /// - Returns: The local UUID of the saved workout
    /// - Throws: WorkoutRepositoryError if save fails
    func save(workoutEntry: WorkoutEntry, forUserID userID: String) async throws -> UUID
    
    /// Fetch workouts from local storage
    /// - Parameters:
    ///   - userID: The user ID to filter by
    ///   - syncStatus: Optional sync status filter (nil for all)
    ///   - from: Optional start date filter
    ///   - to: Optional end date filter
    ///   - limit: Maximum number of workouts to fetch
    /// - Returns: Array of workout entries matching the criteria
    func fetchLocal(
        forUserID userID: String,
        syncStatus: SyncStatus?,
        from startDate: Date?,
        to endDate: Date?,
        limit: Int?
    ) async throws -> [WorkoutEntry]
    
    /// Fetch a single workout by its local ID
    /// - Parameter id: The local UUID of the workout
    /// - Returns: The workout entry if found, nil otherwise
    func fetchByID(_ id: UUID) async throws -> WorkoutEntry?
    
    /// Fetch a workout by its source ID (for deduplication)
    /// - Parameters:
    ///   - sourceID: The source system identifier (e.g., HealthKit UUID)
    ///   - userID: The user ID who owns the workout
    /// - Returns: The workout entry if found, nil otherwise
    func fetchBySourceID(_ sourceID: String, forUserID userID: String) async throws -> WorkoutEntry?
    
    /// Update the sync status and backend ID for a workout
    /// - Parameters:
    ///   - id: The local UUID of the workout
    ///   - syncStatus: The new sync status
    ///   - backendID: The backend-assigned ID (optional)
    func updateSyncStatus(
        forID id: UUID,
        syncStatus: SyncStatus,
        backendID: String?
    ) async throws
    
    /// Delete a workout from local storage
    /// - Parameter id: The local UUID of the workout to delete
    func delete(id: UUID) async throws
    
    // MARK: - Query Operations
    
    /// Get total workouts count for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - from: Optional start date filter
    ///   - to: Optional end date filter
    /// - Returns: Total count of workouts
    func getTotalCount(
        forUserID userID: String,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> Int
    
    /// Get workouts grouped by activity type
    /// - Parameters:
    ///   - userID: The user ID
    ///   - from: Optional start date filter
    ///   - to: Optional end date filter
    /// - Returns: Dictionary mapping activity type to workout count
    func getWorkoutsByActivityType(
        forUserID userID: String,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> [String: Int]
}

// MARK: - Errors

enum WorkoutRepositoryError: Error, LocalizedError {
    case invalidUserID
    case workoutNotFound
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case duplicateWorkout
    
    var errorDescription: String? {
        switch self {
        case .invalidUserID:
            return "Invalid user ID provided"
        case .workoutNotFound:
            return "Workout not found"
        case .saveFailed(let message):
            return "Failed to save workout: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch workout: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete workout: \(message)"
        case .duplicateWorkout:
            return "Workout with the same source ID already exists"
        }
    }
}
