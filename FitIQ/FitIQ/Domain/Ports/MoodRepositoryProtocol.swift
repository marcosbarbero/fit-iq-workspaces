//
//  MoodRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of HKStateOfMind Mood Tracking Integration
//

import Foundation
import HealthKit

/// Port (protocol) for mood tracking repository
///
/// Defines the interface for mood data operations, following Hexagonal Architecture principles.
/// The infrastructure layer provides concrete implementations.
///
/// **Responsibilities:**
/// - Local storage operations (SwiftData)
/// - HealthKit integration (iOS 18+)
/// - Outbox Pattern integration for backend sync
protocol MoodRepositoryProtocol {

    // MARK: - Local Storage Operations

    /// Saves a mood entry to local storage
    ///
    /// Stores the mood entry locally and triggers Outbox Pattern for backend sync.
    ///
    /// - Parameters:
    ///   - moodEntry: The MoodEntry to save
    ///   - userID: The ID of the user this entry belongs to
    /// - Returns: The UUID of the saved entry
    /// - Throws: Error if save operation fails
    func save(moodEntry: MoodEntry, forUserID userID: String) async throws -> UUID

    /// Fetches mood entries from local storage
    ///
    /// Retrieves mood entries for a user within an optional date range.
    ///
    /// - Parameters:
    ///   - userID: The user ID to fetch entries for
    ///   - from: Optional start date for filtering (inclusive)
    ///   - to: Optional end date for filtering (inclusive)
    /// - Returns: Array of MoodEntry objects sorted by date (newest first)
    /// - Throws: Error if fetch operation fails
    func fetchLocal(
        forUserID userID: String,
        from: Date?,
        to: Date?
    ) async throws -> [MoodEntry]

    /// Fetches a single mood entry by ID
    ///
    /// - Parameters:
    ///   - id: The UUID of the mood entry
    ///   - userID: The user ID (for security verification)
    /// - Returns: The MoodEntry if found, nil otherwise
    /// - Throws: Error if fetch operation fails
    func fetchByID(_ id: UUID, forUserID userID: String) async throws -> MoodEntry?

    /// Deletes a mood entry from local storage
    ///
    /// - Parameters:
    ///   - id: The UUID of the mood entry to delete
    ///   - userID: The user ID (for security verification)
    /// - Throws: Error if delete operation fails or entry not found
    func delete(id: UUID, forUserID userID: String) async throws

    /// Deletes all mood entries for a user
    ///
    /// Used for account deletion or data reset.
    ///
    /// - Parameter userID: The user ID
    /// - Throws: Error if delete operation fails
    func deleteAll(forUserID userID: String) async throws

    // MARK: - HealthKit Integration (iOS 18+)

    /// Saves a mood entry to HealthKit using HKStateOfMind
    ///
    /// Converts the MoodEntry to HKStateOfMind and saves it to HealthKit.
    /// Only available on iOS 18+.
    ///
    /// - Parameter moodEntry: The mood entry to save
    /// - Throws: Error if HealthKit authorization missing or save fails
    @available(iOS 18.0, *)
    func saveToHealthKit(moodEntry: MoodEntry) async throws

    /// Fetches mood entries from HealthKit
    ///
    /// Retrieves HKStateOfMind samples from HealthKit and converts them to MoodEntry objects.
    /// Only available on iOS 18+.
    ///
    /// - Parameters:
    ///   - from: Start date for fetching (inclusive)
    ///   - to: End date for fetching (inclusive)
    /// - Returns: Array of MoodEntry objects converted from HKStateOfMind
    /// - Throws: Error if HealthKit authorization missing or fetch fails
    @available(iOS 18.0, *)
    func fetchFromHealthKit(from: Date, to: Date) async throws -> [MoodEntry]

    // MARK: - Sync Status Operations

    /// Updates the sync status of a mood entry
    ///
    /// Used by the Outbox Pattern processor to track sync state.
    ///
    /// - Parameters:
    ///   - id: The UUID of the mood entry
    ///   - syncStatus: The new sync status
    ///   - backendID: Optional backend-assigned ID (when synced)
    /// - Throws: Error if update operation fails
    func updateSyncStatus(
        id: UUID,
        syncStatus: SyncStatus,
        backendID: String?
    ) async throws

    /// Fetches mood entries by sync status
    ///
    /// Used to find entries that need syncing or have failed to sync.
    ///
    /// - Parameters:
    ///   - userID: The user ID
    ///   - syncStatus: The sync status to filter by
    /// - Returns: Array of MoodEntry objects matching the sync status
    /// - Throws: Error if fetch operation fails
    func fetchBySyncStatus(
        forUserID userID: String,
        syncStatus: SyncStatus
    ) async throws -> [MoodEntry]
}

// MARK: - Backend API Protocol

/// Protocol for mood data backend API operations
///
/// Handles communication with the backend API for mood tracking.
/// Uses the existing `/api/v1/progress` endpoint with `type: "mood_score"`.
protocol MoodRemoteAPIProtocol {

    /// Saves a mood entry to the backend
    ///
    /// - Parameters:
    ///   - score: Mood score (1-10)
    ///   - notes: Optional user notes
    ///   - loggedAt: Date when the mood was recorded
    /// - Returns: The created MoodEntry with backend-assigned ID
    /// - Throws: APIError if request fails
    func saveMood(
        score: Int,
        notes: String?,
        loggedAt: Date
    ) async throws -> MoodEntry

    /// Fetches mood history from the backend
    ///
    /// - Parameters:
    ///   - from: Optional start date for filtering
    ///   - to: Optional end date for filtering
    ///   - limit: Optional page size
    ///   - offset: Optional pagination offset
    /// - Returns: Array of MoodEntry objects
    /// - Throws: APIError if request fails
    func fetchMoodHistory(
        from: Date?,
        to: Date?,
        limit: Int?,
        offset: Int?
    ) async throws -> [MoodEntry]

    /// Deletes a mood entry from the backend
    ///
    /// - Parameter backendID: The backend-assigned ID
    /// - Throws: APIError if request fails
    func deleteMood(backendID: String) async throws
}
