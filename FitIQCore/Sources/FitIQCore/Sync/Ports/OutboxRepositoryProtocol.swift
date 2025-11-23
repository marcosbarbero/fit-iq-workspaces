//
//  OutboxRepositoryProtocol.swift
//  FitIQCore
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Protocol defining contract for Outbox Pattern persistence
//

import Foundation

/// Protocol defining the contract for outbox event persistence and retrieval
/// Implements the Outbox Pattern for reliable data synchronization
public protocol OutboxRepositoryProtocol: Sendable {

    // MARK: - Event Creation

    /// Creates a new outbox event for later processing
    /// - Parameters:
    ///   - eventType: Type of event to create
    ///   - entityID: ID of the entity that needs syncing
    ///   - userID: User this event belongs to
    ///   - isNewRecord: Whether this is a new record or an update
    ///   - metadata: Additional metadata for the event
    ///   - priority: Priority (higher = process first)
    /// - Returns: The created outbox event
    func createEvent(
        eventType: OutboxEventType,
        entityID: UUID,
        userID: String,
        isNewRecord: Bool,
        metadata: OutboxMetadata?,
        priority: Int
    ) async throws -> OutboxEvent

    // MARK: - Event Retrieval

    /// Fetches events that need processing (pending or eligible for retry)
    /// - Parameters:
    ///   - userID: Filter by user ID (nil for all users)
    ///   - limit: Maximum number of events to return
    /// - Returns: Array of events ready for processing, ordered by priority and creation time
    func fetchPendingEvents(
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [OutboxEvent]

    /// Fetches events by status
    /// - Parameters:
    ///   - status: Status to filter by
    ///   - userID: Filter by user ID (nil for all users)
    ///   - limit: Maximum number of events to return
    /// - Returns: Array of events with the specified status
    func fetchEvents(
        withStatus status: OutboxEventStatus,
        forUserID userID: String?,
        limit: Int?
    ) async throws -> [OutboxEvent]

    /// Fetches a specific event by ID
    /// - Parameter id: Event ID
    /// - Returns: The event if found, nil otherwise
    func fetchEvent(byID id: UUID) async throws -> OutboxEvent?

    /// Fetches events for a specific entity
    /// - Parameters:
    ///   - entityID: Entity ID to search for
    ///   - eventType: Filter by event type (nil for all types)
    /// - Returns: Array of events for the entity
    func fetchEvents(
        forEntityID entityID: UUID,
        eventType: OutboxEventType?
    ) async throws -> [OutboxEvent]

    // MARK: - Event Updates

    /// Updates an existing event
    /// - Parameter event: Event to update
    func updateEvent(_ event: OutboxEvent) async throws

    /// Marks an event as processing
    /// - Parameter eventID: ID of event to mark
    func markAsProcessing(_ eventID: UUID) async throws

    /// Marks an event as completed
    /// - Parameter eventID: ID of event to mark
    func markAsCompleted(_ eventID: UUID) async throws

    /// Marks an event as failed with error message
    /// - Parameters:
    ///   - eventID: ID of event to mark
    ///   - error: Error message
    func markAsFailed(_ eventID: UUID, error: String) async throws

    /// Resets failed events for retry
    /// - Parameter eventIDs: IDs of events to reset
    func resetForRetry(_ eventIDs: [UUID]) async throws

    // MARK: - Event Deletion

    /// Deletes completed events older than specified date
    /// - Parameter olderThan: Delete events completed before this date
    /// - Returns: Number of events deleted
    @discardableResult
    func deleteCompletedEvents(olderThan date: Date) async throws -> Int

    /// Deletes a specific event
    /// - Parameter eventID: ID of event to delete
    func deleteEvent(_ eventID: UUID) async throws

    /// Deletes outbox events for specific entity IDs
    /// - Parameter entityIDs: Array of entity IDs whose events should be deleted
    /// - Returns: Number of events deleted
    @discardableResult
    func deleteEvents(forEntityIDs entityIDs: [UUID]) async throws -> Int

    /// Deletes all outbox events for a specific user (emergency cleanup)
    /// - Parameter userID: User ID whose events should be deleted
    /// - Returns: Number of events deleted
    @discardableResult
    func deleteAllEvents(forUserID userID: String) async throws -> Int

    // MARK: - Statistics

    /// Gets statistics about outbox events
    /// - Parameter userID: Filter by user ID (nil for all users)
    /// - Returns: Summary of event counts by status
    func getStatistics(forUserID userID: String?) async throws -> OutboxStatistics

    /// Checks if there are any stale events (pending for too long)
    /// - Parameter userID: Filter by user ID (nil for all users)
    /// - Returns: Array of stale events
    func getStaleEvents(forUserID userID: String?) async throws -> [OutboxEvent]
}
