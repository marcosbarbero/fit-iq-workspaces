//
//  DeleteMealLogUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Use case for deleting meal logs
//

import Foundation

/// Protocol defining the contract for deleting meal logs
protocol DeleteMealLogUseCase {
    /// Deletes a meal log by its local UUID
    /// - Parameters:
    ///   - id: The local UUID of the meal log to delete
    /// - Throws: Error if deletion fails or user is not authenticated
    func execute(id: UUID) async throws
}

/// Implementation of DeleteMealLogUseCase following Hexagonal Architecture
///
/// This use case handles the deletion of meal logs:
/// 1. Validates user authentication
/// 2. Calls repository delete (which creates outbox event if needed)
/// 3. Repository deletes from local storage immediately
/// 4. SwiftData cascade rules automatically delete related items
/// 5. Outbox Pattern syncs deletion to backend asynchronously
///
/// **Architecture:**
/// - Follows Hexagonal Architecture (depends on ports, not implementations)
/// - Uses Outbox Pattern for reliable backend sync
/// - Local-first deletion (immediate feedback)
/// - Crash-resistant (outbox event survives app crashes)
/// - Cascade deletion handles related meal log items
final class DeleteMealLogUseCaseImpl: DeleteMealLogUseCase {

    // MARK: - Dependencies

    private let mealLogRepository: MealLogRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        mealLogRepository: MealLogRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.mealLogRepository = mealLogRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(id: UUID) async throws {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw DeleteMealLogError.userNotAuthenticated
        }

        print("DeleteMealLogUseCase: Deleting meal log \(id) for user \(userID)")

        // ✅ OUTBOX PATTERN: Repository will:
        // 1. Create outbox event if meal has backendID (for backend sync)
        // 2. Delete from local storage immediately
        // 3. OutboxProcessorService will handle backend deletion asynchronously
        try await mealLogRepository.delete(id, forUserID: userID)

        print("DeleteMealLogUseCase: ✅ Meal log deleted locally")
        print("DeleteMealLogUseCase: Outbox Pattern will sync deletion to backend if needed")
    }
}

// MARK: - Errors

enum DeleteMealLogError: Error, LocalizedError {
    case userNotAuthenticated
    case mealLogNotFound

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to delete meal logs"
        case .mealLogNotFound:
            return "Meal log not found"
        }
    }
}
