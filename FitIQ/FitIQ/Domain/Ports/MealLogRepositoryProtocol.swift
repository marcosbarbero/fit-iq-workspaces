//
//  MealLogRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Port (protocol) for meal log repository operations
//

import Foundation

// MARK: - Local Storage Protocol

/// Protocol for local storage operations of meal logs
///
/// Handles local-first storage using SwiftData for offline capability
/// and as source of truth before backend synchronization.
protocol MealLogLocalStorageProtocol {

    /// Saves a meal log to local storage
    ///
    /// Stores the meal log locally for offline-first functionality.
    /// Triggers sync event for background synchronization to backend.
    ///
    /// - Parameters:
    ///   - mealLog: The MealLog to save locally
    ///   - userID: The ID of the user this entry belongs to
    /// - Returns: The local UUID of the saved meal log
    /// - Throws: Error if save operation fails
    func save(mealLog: MealLog, forUserID userID: String) async throws -> UUID

    /// Fetches meal logs from local storage
    ///
    /// Retrieves locally stored meal logs with optional filtering.
    ///
    /// - Parameters:
    ///   - userID: The ID of the user
    ///   - status: Optional filter by processing status
    ///   - syncStatus: Optional filter by sync status
    ///   - startDate: Optional start date filter
    ///   - endDate: Optional end date filter
    ///   - limit: Optional maximum number of entries to return (nil = no limit)
    /// - Returns: Array of locally stored MealLog objects
    /// - Throws: Error if fetch operation fails
    func fetchLocal(
        forUserID userID: String,
        status: MealLogStatus?,
        syncStatus: SyncStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?
    ) async throws -> [MealLog]

    /// Fetches a specific meal log by ID
    ///
    /// - Parameters:
    ///   - id: The local UUID of the meal log
    ///   - userID: The ID of the user
    /// - Returns: The meal log if found, nil otherwise
    /// - Throws: Error if fetch operation fails
    func fetchByID(_ id: UUID, forUserID userID: String) async throws -> MealLog?

    /// Updates a meal log's status (after backend processing)
    ///
    /// Called when WebSocket notifications arrive with status updates.
    ///
    /// - Parameters:
    ///   - localID: The local UUID of the meal log
    ///   - status: The new processing status
    ///   - items: The parsed meal items (if processing completed)
    ///   - totalCalories: Total calories from all items
    ///   - totalProteinG: Total protein in grams
    ///   - totalCarbsG: Total carbs in grams
    ///   - totalFatG: Total fat in grams
    ///   - totalFiberG: Total fiber in grams (optional)
    ///   - totalSugarG: Total sugar in grams (optional)
    ///   - errorMessage: Optional error message (if processing failed)
    ///   - userID: The ID of the user
    /// - Throws: Error if update operation fails
    func updateStatus(
        forLocalID localID: UUID,
        status: MealLogStatus,
        items: [MealLogItem]?,
        totalCalories: Int?,
        totalProteinG: Double?,
        totalCarbsG: Double?,
        totalFatG: Double?,
        totalFiberG: Double?,
        totalSugarG: Double?,
        errorMessage: String?,
        forUserID userID: String
    ) async throws

    /// Updates the backend ID for a locally stored meal log
    ///
    /// Called after successful sync to update the local entry with server-assigned ID.
    ///
    /// - Parameters:
    ///   - localID: The local UUID of the entry
    ///   - backendID: The server-assigned ID
    ///   - userID: The ID of the user
    /// - Throws: Error if update operation fails
    func updateBackendID(
        forLocalID localID: UUID,
        backendID: String,
        forUserID userID: String
    ) async throws

    /// Updates the sync status of a meal log
    ///
    /// - Parameters:
    ///   - localID: The local UUID of the entry
    ///   - syncStatus: The new sync status
    ///   - userID: The ID of the user
    /// - Throws: Error if update operation fails
    func updateSyncStatus(
        forLocalID localID: UUID,
        syncStatus: SyncStatus,
        forUserID userID: String
    ) async throws

    /// Deletes a meal log from local storage
    ///
    /// - Parameters:
    ///   - id: The local UUID of the meal log
    ///   - userID: The ID of the user
    /// - Throws: Error if delete operation fails
    func delete(_ id: UUID, forUserID userID: String) async throws

    /// Deletes all meal logs for a user
    ///
    /// Useful for clearing data or starting fresh sync.
    ///
    /// - Parameter userID: The ID of the user
    /// - Throws: Error if delete operation fails
    func deleteAll(forUserID userID: String) async throws
}

// MARK: - Remote API Protocol

/// Protocol for remote backend operations of meal logs
///
/// Handles communication with the backend API for meal logging.
protocol MealLogRemoteAPIProtocol {

    /// Submits a natural language meal log to the backend
    ///
    /// Sends raw text input to the backend for AI-powered parsing.
    /// The backend will asynchronously process and return parsed items via WebSocket.
    ///
    /// - Parameters:
    ///   - rawInput: The natural language meal description
    ///   - mealType: The meal type (breakfast, lunch, dinner, snack, etc.)
    ///   - loggedAt: When the meal was consumed
    ///   - notes: Optional user notes
    /// - Returns: The created MealLog with server-assigned ID
    /// - Throws: APIError if the request fails
    ///
    /// **Example:**
    /// ```swift
    /// let mealLog = try await repository.submitMealLog(
    ///     rawInput: "2 eggs, toast with butter, coffee",
    ///     mealType: "breakfast",
    ///     loggedAt: Date(),
    ///     notes: nil
    /// )
    /// ```
    func submitMealLog(
        rawInput: String,
        mealType: String,
        loggedAt: Date,
        notes: String?
    ) async throws -> MealLog

    /// Fetches meal logs from the backend
    ///
    /// Retrieves meal logs with optional filtering and pagination.
    ///
    /// - Parameters:
    ///   - status: Optional filter by processing status
    ///   - mealType: Optional filter by meal type
    ///   - startDate: Optional start date for filtering
    ///   - endDate: Optional end date for filtering
    ///   - page: Optional page number for pagination (starts at 1)
    ///   - limit: Optional page size (number of entries per page)
    /// - Returns: Array of MealLog objects matching the filters
    /// - Throws: APIError if the request fails
    ///
    /// **Example:**
    /// ```swift
    /// // Get all meal logs from last 7 days
    /// let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    /// let mealLogs = try await repository.getMealLogs(
    ///     status: .completed,
    ///     mealType: nil,
    ///     startDate: sevenDaysAgo,
    ///     endDate: Date(),
    ///     page: nil,
    ///     limit: nil
    /// )
    /// ```
    func getMealLogs(
        status: MealLogStatus?,
        mealType: String?,
        startDate: Date?,
        endDate: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [MealLog]

    /// Fetches a specific meal log by ID from the backend
    ///
    /// - Parameter id: The backend-assigned meal log ID
    /// - Returns: The meal log if found
    /// - Throws: APIError if the request fails or meal log not found
    func getMealLogByID(_ id: String) async throws -> MealLog

    /// Deletes a meal log from the backend
    ///
    /// **⚠️ INTERNAL USE ONLY - Called by OutboxProcessorService**
    ///
    /// This method is NOT called directly by use cases. Instead, use cases should call
    /// the local `delete(_ id:, forUserID:)` method which will:
    /// 1. Delete locally immediately (good UX)
    /// 2. Create an outbox event if the meal has a backendID
    /// 3. OutboxProcessorService will call this method asynchronously
    ///
    /// Sends a DELETE request to remove the meal log and all its items from the backend.
    ///
    /// - Parameter backendID: The backend-assigned meal log ID
    /// - Throws: APIError if the request fails or meal log not found
    ///
    /// **Outbox Pattern Flow:**
    /// ```swift
    /// // Use case calls:
    /// try await repository.delete(localID, forUserID: userID)
    ///
    /// // Repository automatically creates outbox event with metadata:
    /// // { "operation": "delete", "backendID": "..." }
    ///
    /// // OutboxProcessorService processes event and calls:
    /// try await repository.deleteMealLog(backendID: "meal-log-uuid")
    /// ```
    func deleteMealLog(backendID: String) async throws
}

// MARK: - Combined Protocol

/// Combined protocol for repositories that handle both local storage and remote operations
///
/// Use this protocol when you need a repository that can handle both local and remote operations,
/// such as CompositeMealLogRepository which implements local-first architecture.
protocol MealLogRepositoryProtocol: MealLogLocalStorageProtocol, MealLogRemoteAPIProtocol {
    // Inherits all methods from both protocols
}
