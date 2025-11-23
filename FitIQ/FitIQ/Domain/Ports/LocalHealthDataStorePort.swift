// LocalHealthDataStorePort.swift
import Foundation
import SwiftData

protocol LocalHealthDataStorePort {
    /// Saves a physical attribute, optionally with a pre-existing backend ID.
    /// - Parameters:
    ///   - value: The measurement value.
    ///   - type: The type of physical attribute (e.g., bodyMass, height).
    ///   - date: The date of the measurement.
    ///   - userProfileID: The ID of the user this attribute belongs to.
    ///   - backendID: An optional ID from the backend if this record has already been synced.
    /// - Returns: The local UUID of the saved `SDPhysicalAttribute` entry.
    func savePhysicalAttribute(value: Double, type: PhysicalAttributeType, date: Date, for userProfileID: UUID, backendID: String?) async throws -> UUID
    
    /// Updates the backend ID for an existing physical attribute.
    /// - Parameters:
    ///   - localID: The local UUID of the `SDPhysicalAttribute` to update.
    ///   - newBackendID: The backend ID received from the API.
    ///   - userProfileID: The ID of the user this attribute belongs to (for verification).
    func updatePhysicalAttributeBackendID(forLocalID localID: UUID, newBackendID: String, for userProfileID: UUID) async throws
    
    /// Fetches a physical attribute by its local UUID.
    /// - Parameters:
    ///   - localID: The local UUID of the `SDPhysicalAttribute` to fetch.
    ///   - userProfileID: The ID of the user this attribute belongs to.
    /// - Returns: The `SDPhysicalAttribute` if found, otherwise `nil`.
    func fetchPhysicalAttribute(forLocalID localID: UUID, for userProfileID: UUID) async throws -> SDPhysicalAttribute?

    /// Fetches a physical attribute by its backend ID and type.
    /// - Parameters:
    ///   - backendID: The backend ID of the `SDPhysicalAttribute` to fetch.
    ///   - type: The type of physical attribute.
    ///   - userProfileID: The ID of the user this attribute belongs to.
    /// - Returns: The `SDPhysicalAttribute` if found, otherwise `nil`.
    func fetchPhysicalAttribute(forBackendID backendID: String, of type: PhysicalAttributeType, for userProfileID: UUID) async throws -> SDPhysicalAttribute?

    /// Updates an existing SDPhysicalAttribute object directly.
    /// - Parameters:
    ///   - attribute: The `SDPhysicalAttribute` object to update.
    ///   - userProfileID: The ID of the user this attribute belongs to (for verification).
    func updatePhysicalAttribute(_ attribute: SDPhysicalAttribute, for userProfileID: UUID) async throws
}
