// Domain/Ports/ActivitySnapshotRepositoryProtocol.swift
import Foundation
import Combine // Import Combine for the publisher

/// Defines the contract for retrieving activity snapshots from a secondary adapter.
/// This is a "secondary output port" in Hexagonal Architecture.
protocol ActivitySnapshotRepositoryProtocol {
    // NEW: Add a publisher for activity snapshot events
    var eventPublisher: ActivitySnapshotEventPublisherProtocol { get }

    /// Fetches the latest activity snapshot for a given user.
    /// - Parameter userID: The ID of the user whose activity snapshot is to be fetched.
    /// - Returns: The most recent `ActivitySnapshot` for the user, or `nil` if none exists.
    func fetchLatestActivitySnapshot(forUserID userID: String) async throws -> ActivitySnapshot?

    /// Fetches an activity snapshot for a specific date and user.
    /// - Parameters:
    ///   - userID: The ID of the user whose activity snapshot is to be fetched.
    ///   - date: The date for which to fetch the snapshot (typically `startOfDay`).
    /// - Returns: The `ActivitySnapshot` for the specified date, or `nil` if none exists.
    func fetchActivitySnapshot(forUserID userID: String, date: Date) async throws -> ActivitySnapshot?

    /// Saves or updates an activity snapshot for a user.
    /// This method will create a new snapshot if `snapshot.id` does not exist locally,
    /// or update an existing one if a snapshot with the same `id` is found.
    /// - Parameters:
    ///   - snapshot: The `ActivitySnapshot` to save or update.
    ///   - userID: The ID of the user this snapshot belongs to.
    /// - Returns: The local UUID of the saved/updated `ActivitySnapshot` entry.
    func save(snapshot: ActivitySnapshot, forUserID userID: String) async throws -> UUID
    
    /// Updates the backend ID for an existing activity snapshot.
    /// - Parameters:
    ///   - localID: The local UUID of the `ActivitySnapshot` to update.
    ///   - newBackendID: The backend ID received from the API.
    ///   - userID: The ID of the user this snapshot belongs to (for verification).
    func updateActivitySnapshotBackendID(forLocalID localID: UUID, newBackendID: String, for userID: String) async throws

    /// Fetches an activity snapshot by its local UUID.
    /// - Parameters:
    ///   - localID: The local UUID of the `ActivitySnapshot` to fetch.
    ///   - userID: The ID of the user this snapshot belongs to.
    /// - Returns: The `ActivitySnapshot` if found, otherwise `nil`.
    func fetchActivitySnapshot(forLocalID localID: UUID, for userID: String) async throws -> ActivitySnapshot?
}

