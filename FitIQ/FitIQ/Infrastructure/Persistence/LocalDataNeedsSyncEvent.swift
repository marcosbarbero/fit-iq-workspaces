// Domain/Events/LocalDataNeedsSyncEvent.swift
import Foundation

/// Represents an event indicating that a local data record needs to be synced to the backend.
public struct LocalDataNeedsSyncEvent {
    public enum ModelType: String, CaseIterable, Identifiable {
        case physicalAttribute
        case activitySnapshot
        case progressEntry

        public var id: String { self.rawValue }
    }

    public let localID: UUID
    public let userID: UUID  // The ID of the user this record belongs to
    public let modelType: ModelType
    public let isNewRecord: Bool  // True if it's a new record (no backendID yet)

    public init(localID: UUID, userID: UUID, modelType: ModelType, isNewRecord: Bool) {
        self.localID = localID
        self.userID = userID
        self.modelType = modelType
        self.isNewRecord = isNewRecord
    }
}
