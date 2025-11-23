//
//  OutboxEventAdapter.swift
//  lume
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Adapter to convert between SwiftData persistence models and FitIQCore domain models
//

import FitIQCore
import Foundation

/// Adapter to convert between SwiftData OutboxEvent and FitIQCore OutboxEvent
///
/// This adapter implements the Adapter Pattern to maintain clean separation between:
/// - Domain Layer (FitIQCore) - Pure business logic, no persistence dependencies
/// - Infrastructure Layer (SwiftData) - Persistence implementation
///
/// **Architecture:**
/// ```
/// Domain (FitIQCore)
/// ├── OutboxEvent (struct) - Domain model
/// └── OutboxRepositoryProtocol - Interface
///
/// Infrastructure (Lume)
/// ├── SDOutboxEvent (@Model) - SwiftData persistence
/// ├── OutboxEventAdapter - Converts between layers
/// └── SwiftDataOutboxRepository - Uses adapter
/// ```
///
/// **Usage:**
/// ```swift
/// // Domain to SwiftData
/// let domainEvent = OutboxEvent(...)
/// let sdEvent = OutboxEventAdapter.toSwiftData(domainEvent)
/// modelContext.insert(sdEvent)
///
/// // SwiftData to Domain
/// let sdEvents = try modelContext.fetch(descriptor)
/// let domainEvents = sdEvents.map { OutboxEventAdapter.toDomain($0) }
/// ```
struct OutboxEventAdapter {

    // MARK: - Domain to SwiftData

    /// Converts FitIQCore OutboxEvent (domain) to SDOutboxEvent (SwiftData persistence)
    ///
    /// - Parameter domain: Domain model from FitIQCore
    /// - Returns: SwiftData model for persistence
    static func toSwiftData(_ domain: OutboxEvent) -> SDOutboxEvent {
        // Metadata - convert enum to JSON string
        let metadataString: String? = domain.metadata.flatMap { encodeMetadata($0) }

        // Create SDOutboxEvent using initializer
        let sdEvent = SDOutboxEvent(
            id: domain.id,
            eventType: domain.eventType.rawValue,
            entityID: domain.entityID,
            userID: domain.userID,
            status: domain.status.rawValue,
            createdAt: domain.createdAt,
            lastAttemptAt: domain.lastAttemptAt,
            attemptCount: domain.attemptCount,
            maxAttempts: domain.maxAttempts,
            errorMessage: domain.errorMessage,
            completedAt: domain.completedAt,
            metadata: metadataString,
            priority: domain.priority,
            isNewRecord: domain.isNewRecord
        )

        return sdEvent
    }

    // MARK: - SwiftData to Domain

    /// Converts SDOutboxEvent (SwiftData persistence) to FitIQCore OutboxEvent (domain)
    ///
    /// - Parameter swiftData: SwiftData persistence model
    /// - Returns: Domain model from FitIQCore
    /// - Throws: If conversion fails (invalid enum values, corrupt data)
    static func toDomain(_ swiftData: SDOutboxEvent) throws -> OutboxEvent {
        // Convert event type string to enum
        guard let eventType = OutboxEventType(rawValue: swiftData.eventType) else {
            throw AdapterError.invalidEventType(swiftData.eventType)
        }

        // Convert status string to enum
        guard let status = OutboxEventStatus(rawValue: swiftData.status) else {
            throw AdapterError.invalidStatus(swiftData.status)
        }

        // Decode metadata from JSON string
        let metadata: OutboxMetadata? = try? decodeMetadata(swiftData.metadata)

        return OutboxEvent(
            id: swiftData.id,
            eventType: eventType,
            entityID: swiftData.entityID,
            userID: swiftData.userID,
            status: status,
            createdAt: swiftData.createdAt,
            lastAttemptAt: swiftData.lastAttemptAt,
            attemptCount: swiftData.attemptCount,
            maxAttempts: swiftData.maxAttempts,
            errorMessage: swiftData.errorMessage,
            completedAt: swiftData.completedAt,
            metadata: metadata,
            priority: swiftData.priority,
            isNewRecord: swiftData.isNewRecord
        )
    }

    // MARK: - Batch Conversions

    /// Converts array of SwiftData events to domain events
    ///
    /// - Parameter swiftDataEvents: Array of SwiftData models
    /// - Returns: Array of domain models (failures are filtered out with logging)
    static func toDomainArray(_ swiftDataEvents: [SDOutboxEvent]) -> [OutboxEvent] {
        swiftDataEvents.compactMap { sdEvent in
            do {
                return try toDomain(sdEvent)
            } catch {
                print("OutboxEventAdapter: ⚠️ Failed to convert event \(sdEvent.id): \(error)")
                return nil
            }
        }
    }

    /// Converts array of domain events to SwiftData events
    ///
    /// - Parameter domainEvents: Array of domain models
    /// - Returns: Array of SwiftData models
    static func toSwiftDataArray(_ domainEvents: [OutboxEvent]) -> [SDOutboxEvent] {
        domainEvents.map { toSwiftData($0) }
    }

    // MARK: - Update Operations

    /// Updates a SwiftData event from a domain event (for status changes, etc.)
    ///
    /// This is used when the domain logic modifies an event and we need to persist the changes.
    ///
    /// - Parameters:
    ///   - swiftData: SwiftData model to update (mutated in place)
    ///   - domain: Domain model with updated values
    static func updateSwiftData(_ swiftData: SDOutboxEvent, from domain: OutboxEvent) {
        // Only update mutable fields (not IDs or creation timestamps)
        swiftData.status = domain.status.rawValue
        swiftData.lastAttemptAt = domain.lastAttemptAt
        swiftData.attemptCount = domain.attemptCount
        swiftData.errorMessage = domain.errorMessage
        swiftData.completedAt = domain.completedAt

        // Update metadata if changed
        if let metadata = domain.metadata {
            swiftData.metadata = encodeMetadata(metadata)
        } else {
            swiftData.metadata = nil
        }
    }

    // MARK: - Metadata Serialization

    /// Encodes OutboxMetadata enum to JSON string for SwiftData storage
    ///
    /// - Parameter metadata: OutboxMetadata enum
    /// - Returns: JSON string representation
    private static func encodeMetadata(_ metadata: OutboxMetadata) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(metadata)
            return String(data: data, encoding: .utf8)
        } catch {
            print("OutboxEventAdapter: ⚠️ Failed to encode metadata: \(error)")
            return nil
        }
    }

    /// Decodes JSON string to OutboxMetadata enum
    ///
    /// - Parameter jsonString: JSON string from SwiftData
    /// - Returns: OutboxMetadata enum
    /// - Throws: DecodingError if JSON is invalid
    private static func decodeMetadata(_ jsonString: String?) throws -> OutboxMetadata? {
        guard let jsonString = jsonString,
            let data = jsonString.data(using: .utf8)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(OutboxMetadata.self, from: data)
    }
}

// MARK: - Adapter Errors

enum AdapterError: Error, LocalizedError {
    case invalidEventType(String)
    case invalidStatus(String)
    case metadataDecodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEventType(let type):
            return "Invalid event type: '\(type)' cannot be converted to OutboxEventType enum"
        case .invalidStatus(let status):
            return "Invalid status: '\(status)' cannot be converted to OutboxEventStatus enum"
        case .metadataDecodingFailed(let reason):
            return "Failed to decode metadata: \(reason)"
        }
    }
}

// MARK: - Convenience Extensions

extension SDOutboxEvent {
    /// Converts this SwiftData event to a domain event
    ///
    /// Convenience method for cleaner code:
    /// ```swift
    /// let domainEvent = try sdEvent.toDomain()
    /// ```
    func toDomain() throws -> OutboxEvent {
        try OutboxEventAdapter.toDomain(self)
    }
}

extension OutboxEvent {
    /// Converts this domain event to a SwiftData event
    ///
    /// Convenience method for cleaner code:
    /// ```swift
    /// let sdEvent = domainEvent.toSwiftData()
    /// ```
    func toSwiftData() -> SDOutboxEvent {
        OutboxEventAdapter.toSwiftData(self)
    }
}
