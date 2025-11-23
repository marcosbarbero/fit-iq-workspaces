// Domain/Ports/RemoteSyncServiceProtocol.swift
import Foundation

/// Defines the contract for a service that handles remote synchronization
/// of local health data based on triggered events.
public protocol RemoteSyncServiceProtocol {
    /// Starts the process of listening for local data change events
    /// and performing remote synchronization.
    /// - Parameter userID: The ID of the currently authenticated user.
    func startSyncing(forUserID userID: UUID)

    /// Stops the remote synchronization process.
    func stopSyncing()
}
