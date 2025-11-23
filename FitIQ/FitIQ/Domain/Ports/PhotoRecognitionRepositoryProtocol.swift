//
//  PhotoRecognitionRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//  Port for photo recognition data persistence
//

import Foundation

/// Repository protocol for photo recognition persistence (Hexagonal Architecture Port)
///
/// Defines the contract for storing and retrieving photo recognition data.
/// This is a secondary port - the domain defines the interface, infrastructure provides the implementation.
protocol PhotoRecognitionRepositoryProtocol {

    // MARK: - Create

    /// Save a new photo recognition entry
    /// - Parameter photoRecognition: The photo recognition to save
    /// - Returns: The saved photo recognition with assigned ID
    func save(_ photoRecognition: PhotoRecognition) async throws -> PhotoRecognition

    // MARK: - Read

    /// Fetch photo recognition by ID
    /// - Parameter id: The photo recognition ID
    /// - Returns: The photo recognition if found, nil otherwise
    func fetchByID(_ id: UUID) async throws -> PhotoRecognition?

    /// Fetch photo recognition by backend ID
    /// - Parameter backendID: The backend-assigned ID
    /// - Returns: The photo recognition if found, nil otherwise
    func fetchByBackendID(_ backendID: String) async throws -> PhotoRecognition?

    /// Fetch all photo recognitions for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - status: Optional filter by status
    ///   - startDate: Optional filter by start date
    ///   - endDate: Optional filter by end date
    ///   - limit: Maximum number of results
    ///   - offset: Number of results to skip
    /// - Returns: Array of photo recognitions
    func fetchAll(
        forUserID userID: String,
        status: PhotoRecognitionStatus?,
        startDate: Date?,
        endDate: Date?,
        limit: Int?,
        offset: Int?
    ) async throws -> [PhotoRecognition]

    /// Fetch photo recognitions that need syncing (pending or failed)
    /// - Parameter userID: The user ID
    /// - Returns: Array of photo recognitions needing sync
    func fetchPendingSync(forUserID userID: String) async throws -> [PhotoRecognition]

    /// Fetch photo recognitions awaiting user confirmation
    /// - Parameter userID: The user ID
    /// - Returns: Array of completed photo recognitions not yet confirmed
    func fetchAwaitingConfirmation(forUserID userID: String) async throws -> [PhotoRecognition]

    // MARK: - Update

    /// Update an existing photo recognition
    /// - Parameter photoRecognition: The photo recognition with updated data
    /// - Returns: The updated photo recognition
    func update(_ photoRecognition: PhotoRecognition) async throws -> PhotoRecognition

    /// Update photo recognition status
    /// - Parameters:
    ///   - id: The photo recognition ID
    ///   - status: The new status
    ///   - errorMessage: Optional error message if status is failed
    /// - Returns: The updated photo recognition
    func updateStatus(
        _ id: UUID,
        status: PhotoRecognitionStatus,
        errorMessage: String?
    ) async throws -> PhotoRecognition

    /// Update photo recognition sync status
    /// - Parameters:
    ///   - id: The photo recognition ID
    ///   - syncStatus: The new sync status
    ///   - backendID: Optional backend ID if newly synced
    /// - Returns: The updated photo recognition
    func updateSyncStatus(
        _ id: UUID,
        syncStatus: SyncStatus,
        backendID: String?
    ) async throws -> PhotoRecognition

    /// Mark photo recognition as confirmed and link to meal log
    /// - Parameters:
    ///   - id: The photo recognition ID
    ///   - mealLogID: The created meal log ID
    /// - Returns: The updated photo recognition
    func markAsConfirmed(
        _ id: UUID,
        mealLogID: UUID
    ) async throws -> PhotoRecognition

    // MARK: - Delete

    /// Delete a photo recognition entry
    /// - Parameter id: The photo recognition ID
    func delete(_ id: UUID) async throws

    /// Delete all photo recognitions for a user (for GDPR compliance)
    /// - Parameter userID: The user ID
    func deleteAll(forUserID userID: String) async throws

    // MARK: - Statistics

    /// Count total photo recognitions for a user
    /// - Parameters:
    ///   - userID: The user ID
    ///   - status: Optional filter by status
    /// - Returns: Count of photo recognitions
    func count(
        forUserID userID: String,
        status: PhotoRecognitionStatus?
    ) async throws -> Int
}
