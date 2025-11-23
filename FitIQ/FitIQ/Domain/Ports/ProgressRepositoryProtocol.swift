//
//  ProgressRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Biological Sex and Height Improvements
//

import Foundation

// Note: ProgressMetricType is defined in Domain/Entities/Progress/ProgressMetricType.swift

/// Port (protocol) for progress tracking repository
///
/// This protocol defines the interface for progress tracking operations,
/// allowing tracking of various health and fitness metrics over time.
///
/// **Supported Metrics:**
/// - Physical: weight, height, body_fat_percentage, bmi
/// - Activity: steps, calories_out, distance_km, active_minutes
/// - Wellness: sleep_hours, water_liters, resting_heart_rate
/// - Nutrition: calories_in, protein_g, carbs_g, fat_g
///
/// **Architecture:**
/// - Domain layer (port/protocol)
/// - Implemented by infrastructure layer (ProgressAPIClient)
/// - Used by domain use cases (LogHeightProgressUseCase, etc.)
///
/// **Backend Endpoints:**
/// - POST /api/v1/progress - Log a single metric
/// - GET /api/v1/progress - Get progress entries with optional filtering and pagination
/// Protocol for local storage operations of progress entries
///
/// Handles local-first storage using SwiftData for offline capability
/// and as source of truth before backend synchronization.
protocol ProgressLocalStorageProtocol {

    /// Saves a progress entry to local storage
    ///
    /// Stores the progress entry locally for offline-first functionality.
    /// Triggers sync event for background synchronization to backend.
    ///
    /// - Parameters:
    ///   - progressEntry: The ProgressEntry to save locally
    ///   - userID: The ID of the user this entry belongs to
    /// - Returns: The local UUID of the saved entry
    /// - Throws: Error if save operation fails
    func save(progressEntry: ProgressEntry, forUserID userID: String) async throws -> UUID

    /// Fetches progress entries from local storage
    ///
    /// Retrieves locally stored progress entries with optional filtering.
    ///
    /// - Parameters:
    ///   - userID: The ID of the user
    ///   - type: Optional filter by metric type
    ///   - syncStatus: Optional filter by sync status
    /// - Parameters:
    ///   - userID: The user's ID
    ///   - type: Optional metric type filter
    ///   - syncStatus: Optional sync status filter
    ///   - limit: Optional maximum number of entries to return (nil = no limit)
    /// - Returns: Array of locally stored ProgressEntry objects
    /// - Throws: Error if fetch operation fails
    func fetchLocal(
        forUserID userID: String, type: ProgressMetricType?, syncStatus: SyncStatus?, limit: Int?
    )
        async throws -> [ProgressEntry]

    /// Fetch recent progress entries within a date range (OPTIMIZED - no full table scan)
    /// - Parameters:
    ///   - userID: The user's ID
    ///   - type: Optional metric type filter
    ///   - startDate: Start of date range (inclusive)
    ///   - endDate: End of date range (inclusive)
    ///   - limit: Maximum number of entries to return (default: 100)
    /// - Returns: Array of ProgressEntry objects within date range, sorted by date descending
    /// - Throws: Error if fetch operation fails
    func fetchRecent(
        forUserID userID: String,
        type: ProgressMetricType?,
        startDate: Date,
        endDate: Date,
        limit: Int
    ) async throws -> [ProgressEntry]

    /// Fetches the date of the most recent progress entry for a given user and metric type
    ///
    /// PERFORMANCE OPTIMIZATION: Used by HealthKit sync handlers to determine what data
    /// has already been synced, avoiding unnecessary duplicate checks.
    ///
    /// - Parameters:
    ///   - userID: The ID of the user
    ///   - type: The metric type (e.g., .steps, .resting_heart_rate)
    /// - Returns: The date of the most recent entry, or nil if no entries exist
    /// - Throws: Error if fetch operation fails
    ///
    /// **Example:**
    /// ```swift
    /// // Check latest synced steps data
    /// let latestStepsDate = try await repository.fetchLatestEntryDate(
    ///     forUserID: userID,
    ///     type: .steps
    /// )
    ///
    /// // If synced today, skip sync entirely
    /// if let latest = latestStepsDate, calendar.isDateInToday(latest) {
    ///     print("Already synced today")
    ///     return
    /// }
    /// ```
    func fetchLatestEntryDate(
        forUserID userID: String,
        type: ProgressMetricType
    ) async throws -> Date?

    /// Fetches the date of the most recent progress entry for a given user and metric type
    ///
    /// This method is optimized for HealthKit sync optimization - it queries only the latest
    /// entry date without fetching the full entry data. This allows sync handlers to determine
    /// what data is already synced and avoid re-fetching/re-saving duplicate entries.
    ///
    /// **Use Case:**
    /// - HealthKit sync handlers use this to find the latest synced data
    /// - Only fetch NEW data from HealthKit after this date
    /// - Eliminates hundreds of duplicate database queries
    ///
    /// - Parameters:
    ///   - userID: The ID of the user
    ///   - type: The metric type to check (e.g., .steps, .resting_heart_rate)
    /// - Returns: The date of the most recent entry,

    /// Updates the backend ID for a locally stored progress entry
    ///
    /// Called after successful sync to update the local entry with server-assigned ID.
    ///
    /// - Parameters:
    ///   - localID: The local UUID of the entry
    ///   - backendID: The server-assigned ID
    ///   - userID: The ID of the user
    /// - Throws: Error if update operation fails
    func updateBackendID(forLocalID localID: UUID, backendID: String, forUserID userID: String)
        async throws

    /// Updates the sync status of a progress entry
    ///
    /// - Parameters:
    ///   - localID: The local UUID of the entry
    ///   - status: The new sync status
    ///   - userID: The ID of the user
    /// - Throws: Error if update operation fails
    func updateSyncStatus(forLocalID localID: UUID, status: SyncStatus, forUserID userID: String)
        async throws

    /// Deletes all progress entries for a user
    ///
    /// Useful for clearing corrupted data or starting fresh sync.
    ///
    /// - Parameters:
    ///   - userID: The ID of the user
    ///   - type: Optional filter by metric type (deletes all types if nil)
    /// - Throws: Error if delete operation fails
    func deleteAll(forUserID userID: String, type: ProgressMetricType?) async throws
}

/// Protocol for remote backend operations of progress entries
///
/// Handles communication with the backend API for progress tracking.
protocol ProgressRemoteAPIProtocol {

    /// Logs a single progress metric to the backend
    ///
    /// Creates a new progress entry for the specified metric type and quantity.
    /// This enables time-series tracking of health and fitness data.
    ///
    /// - Parameters:
    ///   - type: The metric type to log (e.g., .height, .weight, .steps)
    ///   - quantity: The measurement value (must be >= 0)
    ///   - loggedAt: Optional date-time for the measurement (defaults to now)
    ///   - notes: Optional notes about the measurement (max 500 characters)
    /// - Returns: The created ProgressEntry with server-assigned ID and timestamps
    /// - Throws: APIError if the request fails, ValidationError if data is invalid
    ///
    /// **Example:**
    /// ```swift
    /// let entry = try await progressRepository.logProgress(
    ///     type: .height,
    ///     quantity: 175.5,
    ///     loggedAt: Date(),
    ///     notes: "Updated in profile"
    /// )
    /// ```
    func logProgress(
        type: ProgressMetricType,
        quantity: Double,
        loggedAt: Date?,
        notes: String?
    ) async throws -> ProgressEntry

    /// Gets the current/latest progress values
    ///
    /// Retrieves the most recent entry for each metric type, or filters
    /// to a specific metric if type is provided. Now supports pagination
    /// and date filtering.
    ///
    /// - Parameters:
    ///   - type: Optional filter by specific metric type (e.g., .height)
    ///   - from: Optional start date for filtering (inclusive)
    ///   - to: Optional end date for filtering (inclusive)
    ///   - page: Optional page number for pagination (starts at 1)
    ///   - limit: Optional page size (number of entries per page)
    /// - Returns: Array of ProgressEntry objects with latest values
    /// - Throws: APIError if the request fails
    ///
    /// **Example:**
    /// ```swift
    /// // Get latest height value
    /// let latestHeight = try await progressRepository.getCurrentProgress(type: .height)
    ///
    /// // Get latest values for all metrics
    /// let allLatest = try await progressRepository.getCurrentProgress(type: nil)
    /// ```
    func getCurrentProgress(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry]

    /// Gets historical progress entries with optional filtering
    ///
    /// Retrieves ALL progress entries with support for filtering by metric type,
    /// date range, and pagination. This endpoint returns comprehensive historical data.
    ///
    /// - Parameters:
    ///   - type: Optional filter by specific metric type (e.g., .height)
    ///   - from: Optional start date for filtering (inclusive)
    ///   - to: Optional end date for filtering (inclusive)
    ///   - page: Optional page number for pagination (starts at 1)
    ///   - limit: Optional page size (number of entries per page)
    /// - Returns: Array of ProgressEntry objects matching the filters
    /// - Throws: APIError if the request fails
    ///
    /// **Example:**
    /// ```swift
    /// // Get all height entries from last 30 days
    /// let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    /// let heightHistory = try await progressRepository.getProgressHistory(
    ///     type: .height,
    ///     from: thirtyDaysAgo,
    ///     to: Date(),
    ///     page: nil,
    ///     limit: nil
    /// )
    /// ```
    func getProgressHistory(
        type: ProgressMetricType?,
        from: Date?,
        to: Date?,
        page: Int?,
        limit: Int?
    ) async throws -> [ProgressEntry]
}

/// Combined protocol for repositories that handle both local storage and remote operations
///
/// Use this protocol when you need a repository that can handle both local and remote operations,
/// such as CompositeProgressRepository which implements local-first architecture.
protocol ProgressRepositoryProtocol: ProgressLocalStorageProtocol, ProgressRemoteAPIProtocol {
    // Inherits all methods from both protocols
}

// Note: ProgressEntry is now defined in Domain/Entities/Progress/ProgressEntry.swift
// It includes both local UUID and optional backend ID for local-first architecture
