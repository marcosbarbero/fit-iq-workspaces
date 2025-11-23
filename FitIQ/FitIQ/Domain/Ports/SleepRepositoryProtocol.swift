//
//  SleepRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Port (protocol) for sleep session repository following Hexagonal Architecture
//

import Foundation

/// Repository protocol for sleep session persistence and retrieval
/// Defines the contract for sleep data storage (port in Hexagonal Architecture)
protocol SleepRepositoryProtocol {

    // MARK: - Save Operations

    /// Save a sleep session to local storage and trigger Outbox Pattern for backend sync
    /// - Parameters:
    ///   - session: The sleep session to save
    ///   - userID: The user ID who owns this session
    /// - Returns: The local UUID of the saved session
    /// - Throws: Repository errors if save fails
    func save(session: SleepSession, forUserID userID: String) async throws -> UUID

    // MARK: - Fetch Operations

    /// Fetch all sleep sessions for a user within a date range
    /// - Parameters:
    ///   - userID: The user ID to fetch sessions for
    ///   - from: Start date (inclusive)
    ///   - to: End date (inclusive)
    ///   - syncStatus: Optional filter by sync status
    /// - Returns: Array of sleep sessions sorted by date descending
    func fetchSessions(
        forUserID userID: String,
        from: Date,
        to: Date,
        syncStatus: SyncStatus?
    ) async throws -> [SleepSession]

    /// Fetch the most recent sleep session for a user
    /// - Parameter userID: The user ID to fetch session for
    /// - Returns: The most recent sleep session, or nil if none found
    func fetchLatestSession(forUserID userID: String) async throws -> SleepSession?

    /// Fetch a specific sleep session by ID
    /// - Parameters:
    ///   - id: The local UUID of the session
    ///   - userID: The user ID (for security validation)
    /// - Returns: The sleep session, or nil if not found
    func fetchSession(byID id: UUID, forUserID userID: String) async throws -> SleepSession?

    /// Fetch a sleep session by source ID (for deduplication)
    /// - Parameters:
    ///   - sourceID: The external source identifier (e.g., HealthKit UUID)
    ///   - userID: The user ID
    /// - Returns: The sleep session with matching source ID, or nil if not found
    func fetchSession(bySourceID sourceID: String, forUserID userID: String) async throws
        -> SleepSession?

    // MARK: - Update Operations

    /// Update sync status for a sleep session (called by Outbox processor)
    /// - Parameters:
    ///   - id: The local UUID of the session
    ///   - syncStatus: The new sync status
    ///   - backendID: Optional backend ID (if sync succeeded)
    func updateSyncStatus(
        forSessionID id: UUID,
        syncStatus: SyncStatus,
        backendID: String?
    ) async throws

    // MARK: - Delete Operations

    /// Delete a sleep session
    /// - Parameters:
    ///   - id: The local UUID of the session to delete
    ///   - userID: The user ID (for security validation)
    func deleteSession(byID id: UUID, forUserID userID: String) async throws

    /// Delete all sleep sessions for a user (used in account deletion)
    /// - Parameter userID: The user ID
    func deleteAllSessions(forUserID userID: String) async throws

    // MARK: - Statistics

    /// Calculate sleep statistics for a date range
    /// - Parameters:
    ///   - userID: The user ID
    ///   - from: Start date
    ///   - to: End date
    /// - Returns: Sleep statistics (averages, totals, etc.)
    func calculateStatistics(
        forUserID userID: String,
        from: Date,
        to: Date
    ) async throws -> SleepStatistics
}

// MARK: - Supporting Types

/// Sleep statistics for a date range
struct SleepStatistics {
    let averageTimeInBedMinutes: Int
    let averageSleepMinutes: Int
    let averageEfficiency: Double
    let totalSessions: Int
    let dateRange: ClosedRange<Date>

    /// Average time in bed as hours
    var averageTimeInBedHours: Double {
        Double(averageTimeInBedMinutes) / 60.0
    }

    /// Average sleep time as hours
    var averageSleepHours: Double {
        Double(averageSleepMinutes) / 60.0
    }
}

// MARK: - Errors

enum SleepRepositoryError: Error, LocalizedError {
    case sessionNotFound
    case invalidUserID
    case userProfileNotFound
    case saveFailed(reason: String)
    case fetchFailed(reason: String)
    case updateFailed(reason: String)
    case deleteFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Sleep session not found"
        case .invalidUserID:
            return "Invalid user ID"
        case .userProfileNotFound:
            return "User profile not found"
        case .saveFailed(let reason):
            return "Failed to save sleep session: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch sleep sessions: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update sleep session: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete sleep session: \(reason)"
        }
    }
}
