//
//  SaveMealLogUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Use case for saving meal logs with Outbox Pattern for reliable sync
//

import Foundation

/// Protocol defining the contract for saving meal logs
protocol SaveMealLogUseCase {
    /// Saves a meal log locally and triggers backend sync via Outbox Pattern
    /// - Parameters:
    ///   - rawInput: The natural language meal description
    ///   - mealType: The meal type (breakfast, lunch, dinner, snack, etc.)
    ///   - loggedAt: When the meal was consumed (defaults to current date)
    ///   - notes: Optional user notes
    /// - Returns: The local UUID of the saved meal log
    func execute(
        rawInput: String,
        mealType: MealType,
        loggedAt: Date,
        notes: String?
    ) async throws -> UUID

    /// Saves a completed meal log directly (e.g., from photo recognition)
    /// - Parameters:
    ///   - mealLog: The complete MealLog entity to save
    /// - Returns: The local UUID of the saved meal log
    func executeWithCompletedMeal(mealLog: MealLog) async throws -> UUID
}

/// Implementation of SaveMealLogUseCase following Outbox Pattern
///
/// This use case handles the complete flow for meal logging:
/// 1. Validates input
/// 2. Creates local meal log entry (status: pending, syncStatus: pending)
/// 3. Saves to SwiftData (repository automatically creates Outbox event)
/// 4. OutboxProcessorService picks up the event and syncs to backend
/// 5. WebSocket notifications update the processing status
///
/// **Architecture:**
/// - Follows Hexagonal Architecture (depends on ports, not implementations)
/// - Uses Outbox Pattern for guaranteed eventual consistency
/// - Crash-resistant (survives app crashes during sync)
/// - Offline-first (works without network, syncs when available)
final class SaveMealLogUseCaseImpl: SaveMealLogUseCase {

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

    func execute(
        rawInput: String,
        mealType: MealType,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) async throws -> UUID {
        // Validate input
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SaveMealLogError.emptyInput
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveMealLogError.userNotAuthenticated
        }

        print("SaveMealLogUseCase: Saving meal log for user \(userID)")
        print("SaveMealLogUseCase: Raw input: \(rawInput)")
        print("SaveMealLogUseCase: Meal type: \(mealType.rawValue)")
        print("SaveMealLogUseCase: Logged at: \(loggedAt)")

        // Create meal log entity
        let mealLog = MealLog(
            id: UUID(),
            userID: userID,
            rawInput: rawInput,
            mealType: mealType,
            status: .pending,  // Backend will process this
            loggedAt: loggedAt,
            items: [],  // Will be populated by backend after processing
            notes: notes,
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending,  // ✅ CRITICAL: Mark for Outbox Pattern sync
            errorMessage: nil
        )

        // Save locally
        // ✅ OUTBOX PATTERN: Repository will automatically create outbox event
        let localID = try await mealLogRepository.save(
            mealLog: mealLog,
            forUserID: userID
        )

        print("SaveMealLogUseCase: Successfully saved meal log with local ID: \(localID)")
        print("SaveMealLogUseCase: Outbox event created automatically by repository")
        print("SaveMealLogUseCase: OutboxProcessorService will process event (within 0.5s)")

        // Repository automatically triggers Outbox Pattern:
        // 1. Saves meal log to SwiftData
        // 2. Creates SDOutboxEvent with type .mealLog
        // 3. OutboxProcessorService processes immediately (or within 0.5s if not triggered)
        // 4. Syncs to POST /api/v1/meal-logs/natural
        // 5. Backend returns initial response with ID
        // 6. Backend processes asynchronously with AI
        // 7. WebSocket sends status updates (processing -> completed/failed)
        // 8. WebSocket handler updates local meal log with parsed items

        return localID
    }

    /// Saves a completed meal log directly (e.g., from photo recognition)
    ///
    /// This method is used when the meal log is already fully processed
    /// (e.g., from photo recognition API) and just needs to be persisted locally.
    ///
    /// - Parameter mealLog: The complete MealLog entity to save
    /// - Returns: The local UUID of the saved meal log
    func executeWithCompletedMeal(mealLog: MealLog) async throws -> UUID {
        // Validate user ID matches authenticated user
        guard let currentUserID = authManager.currentUserProfileID?.uuidString else {
            throw SaveMealLogError.userNotAuthenticated
        }

        guard mealLog.userID == currentUserID else {
            throw SaveMealLogError.userNotAuthenticated
        }

        print("SaveMealLogUseCase: Saving completed meal log")
        print("SaveMealLogUseCase: Status: \(mealLog.status.rawValue)")
        print("SaveMealLogUseCase: Items count: \(mealLog.items.count)")
        print("SaveMealLogUseCase: Total calories: \(mealLog.totalCalories ?? 0)")

        // Save locally
        // ✅ OUTBOX PATTERN: Repository will automatically create outbox event
        let localID = try await mealLogRepository.save(
            mealLog: mealLog,
            forUserID: currentUserID
        )

        print("SaveMealLogUseCase: Successfully saved completed meal log with local ID: \(localID)")
        print("SaveMealLogUseCase: Outbox event created automatically by repository")

        return localID
    }
}

// MARK: - Errors

enum SaveMealLogError: Error, LocalizedError {
    case emptyInput
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Meal description cannot be empty"
        case .userNotAuthenticated:
            return "User must be authenticated to save meal logs"
        }
    }
}
