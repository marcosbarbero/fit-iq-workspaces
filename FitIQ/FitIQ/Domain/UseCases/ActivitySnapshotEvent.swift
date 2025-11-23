// Domain/Events/ActivitySnapshotEvent.swift
import Foundation

// Represents an event where an ActivitySnapshot has been updated or saved.
public struct ActivitySnapshotEvent {
    public let userID: String
    public let date: Date

    public init(userID: String, date: Date) {
        self.userID = userID
        self.date = date
    }
}
