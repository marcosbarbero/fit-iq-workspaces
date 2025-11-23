//
//  ProgressEntry.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Represents a progress/metric entry in the domain layer
/// This entity is storage-agnostic and represents various health/fitness metrics
/// Supports local-first architecture with backend synchronization
public struct ProgressEntry: Identifiable, Equatable {
    /// Local UUID for the entry (used for local storage)
    public let id: UUID

    /// User ID who owns this entry
    let userID: String

    /// Metric type (e.g., steps, weight, sleep_hours)
    let type: ProgressMetricType

    /// The measurement value
    let quantity: Double

    /// The date of the measurement
    let date: Date

    /// Optional time of the measurement (HH:MM:SS format)
    let time: String?

    /// Optional notes about the measurement (max 500 characters)
    let notes: String?

    /// When this entry was created locally
    let createdAt: Date

    /// When this entry was last updated locally
    let updatedAt: Date?

    /// Backend-assigned ID (populated after successful sync)
    public var backendID: String?

    /// Sync status for backend synchronization
    public var syncStatus: SyncStatus

    init(
        id: UUID = UUID(),
        userID: String,
        type: ProgressMetricType,
        quantity: Double,
        date: Date,
        time: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.userID = userID
        self.type = type
        self.quantity = quantity
        self.date = date
        self.time = time
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
    }
}
