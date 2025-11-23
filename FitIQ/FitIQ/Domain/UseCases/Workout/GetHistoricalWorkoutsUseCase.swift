//
//  GetHistoricalWorkoutsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Protocol defining the contract for fetching historical workouts
protocol GetHistoricalWorkoutsUseCase {
    /// Fetches historical workouts for the current user
    /// - Parameters:
    ///   - from: Optional start date filter
    ///   - to: Optional end date filter
    ///   - limit: Maximum number of workouts to fetch (defaults to 100)
    /// - Returns: Array of workout entries sorted by start date (most recent first)
    func execute(
        from startDate: Date?,
        to endDate: Date?,
        limit: Int
    ) async throws -> [WorkoutEntry]
}

/// Implementation of GetHistoricalWorkoutsUseCase
final class GetHistoricalWorkoutsUseCaseImpl: GetHistoricalWorkoutsUseCase {
    
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
    
    func execute(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        limit: Int = 100
    ) async throws -> [WorkoutEntry] {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetHistoricalWorkoutsError.userNotAuthenticated
        }
        
        print("GetHistoricalWorkoutsUseCase: Fetching workouts for user \(userID)")
        
        // Fetch workouts from local storage (includes all sync statuses)
        let workouts = try await workoutRepository.fetchLocal(
            forUserID: userID,
            syncStatus: nil,  // Include all sync statuses
            from: startDate,
            to: endDate,
            limit: limit
        )
        
        // Sort by start date (most recent first)
        let sortedWorkouts = workouts.sorted { $0.startedAt > $1.startedAt }
        
        print("GetHistoricalWorkoutsUseCase: Fetched \(sortedWorkouts.count) workouts")
        
        return sortedWorkouts
    }
}

// MARK: - Errors

enum GetHistoricalWorkoutsError: Error, LocalizedError {
    case userNotAuthenticated
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch workouts"
        case .fetchFailed(let message):
            return "Failed to fetch workouts: \(message)"
        }
    }
}
