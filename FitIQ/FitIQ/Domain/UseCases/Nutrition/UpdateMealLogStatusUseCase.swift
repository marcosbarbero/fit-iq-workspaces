//
//  UpdateMealLogStatusUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Use case for updating meal log status from WebSocket notifications
//

import Foundation

/// Protocol defining the contract for updating meal log status
protocol UpdateMealLogStatusUseCase {
    /// Updates a meal log's status after backend processing completes
    /// - Parameters:
    ///   - backendID: The backend-assigned meal log ID
    ///   - status: The new processing status
    ///   - items: The parsed meal items (if processing completed)
    ///   - totalCalories: Total calories from all items
    ///   - totalProteinG: Total protein in grams
    ///   - totalCarbsG: Total carbs in grams
    ///   - totalFatG: Total fat in grams
    ///   - totalFiberG: Total fiber in grams (optional)
    ///   - totalSugarG: Total sugar in grams (optional)
    ///   - errorMessage: Optional error message (if processing failed)
    /// - Throws: Error if update fails
    func execute(
        backendID: String,
        status: MealLogStatus,
        items: [MealLogItem],
        totalCalories: Int?,
        totalProteinG: Double?,
        totalCarbsG: Double?,
        totalFatG: Double?,
        totalFiberG: Double?,
        totalSugarG: Double?,
        errorMessage: String?
    ) async throws
}

/// Implementation of UpdateMealLogStatusUseCase
///
/// This use case handles updating local meal logs when WebSocket notifications arrive
/// with completed processing results from the backend.
///
/// **Flow:**
/// 1. WebSocket receives `meal_log.completed` or `meal_log.failed` event
/// 2. ViewModel calls this use case with the payload data
/// 3. Use case finds the local meal log by backend ID
/// 4. Updates the local meal log with:
///    - New status (.completed or .failed)
///    - Parsed meal items with nutritional data
///    - Total nutritional values
///    - Error message (if failed)
/// 5. SwiftData saves the updates
/// 6. UI refreshes and shows the updated data
///
/// **Architecture:**
/// - Follows Hexagonal Architecture (depends on ports, not implementations)
/// - Updates local storage to maintain local-first architecture
/// - Ensures UI shows accurate data after backend processing
final class UpdateMealLogStatusUseCaseImpl: UpdateMealLogStatusUseCase {

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
        backendID: String,
        status: MealLogStatus,
        items: [MealLogItem],
        totalCalories: Int?,
        totalProteinG: Double?,
        totalCarbsG: Double?,
        totalFatG: Double?,
        totalFiberG: Double?,
        totalSugarG: Double?,
        errorMessage: String?
    ) async throws {
        print("UpdateMealLogStatusUseCase: Updating meal log status")
        print("UpdateMealLogStatusUseCase:    - Backend ID: \(backendID)")
        print("UpdateMealLogStatusUseCase:    - Status: \(status)")
        print("UpdateMealLogStatusUseCase:    - Items: \(items.count)")
        print("UpdateMealLogStatusUseCase:    - Total Calories: \(totalCalories ?? 0)")

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("UpdateMealLogStatusUseCase: ❌ User not authenticated")
            throw UpdateMealLogStatusError.userNotAuthenticated
        }

        // Find the local meal log by backend ID
        let mealLogs = try await mealLogRepository.fetchLocal(
            forUserID: userID,
            status: nil,
            syncStatus: nil,
            startDate: nil,
            endDate: nil,
            limit: nil
        )

        guard let localMealLog = mealLogs.first(where: { $0.backendID == backendID }) else {
            print("UpdateMealLogStatusUseCase: ❌ Meal log not found with backend ID: \(backendID)")
            throw UpdateMealLogStatusError.mealLogNotFound
        }

        let localID = localMealLog.id
        print("UpdateMealLogStatusUseCase: Found local meal log ID: \(localID)")

        // Update the meal log status and items
        try await mealLogRepository.updateStatus(
            forLocalID: localID,
            status: status,
            items: items,
            totalCalories: totalCalories,
            totalProteinG: totalProteinG,
            totalCarbsG: totalCarbsG,
            totalFatG: totalFatG,
            totalFiberG: totalFiberG,
            totalSugarG: totalSugarG,
            errorMessage: errorMessage,
            forUserID: userID
        )

        print("UpdateMealLogStatusUseCase: ✅ Meal log updated successfully")
        print("UpdateMealLogStatusUseCase:    - Local ID: \(localID)")
        print("UpdateMealLogStatusUseCase:    - Status: \(status)")
        print("UpdateMealLogStatusUseCase:    - Items count: \(items.count)")
    }
}

// MARK: - Errors

enum UpdateMealLogStatusError: Error, LocalizedError {
    case userNotAuthenticated
    case mealLogNotFound
    case invalidBackendID

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated. Please log in."
        case .mealLogNotFound:
            return "Meal log not found in local storage."
        case .invalidBackendID:
            return "Invalid backend ID provided."
        }
    }
}
