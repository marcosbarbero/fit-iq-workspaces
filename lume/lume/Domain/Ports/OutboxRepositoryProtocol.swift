//
//  OutboxRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Re-export FitIQCore's OutboxRepositoryProtocol for use in Lume
//

import FitIQCore
import Foundation

// Re-export FitIQCore's OutboxRepositoryProtocol
// This allows Lume code to use the protocol without importing FitIQCore everywhere
public typealias OutboxRepositoryProtocol = FitIQCore.OutboxRepositoryProtocol

// Re-export related types from FitIQCore
public typealias OutboxEvent = FitIQCore.OutboxEvent
public typealias OutboxEventType = FitIQCore.OutboxEventType
public typealias OutboxEventStatus = FitIQCore.OutboxEventStatus
public typealias OutboxMetadata = FitIQCore.OutboxMetadata
public typealias OutboxStatistics = FitIQCore.OutboxStatistics

/// Extension to provide display names for event types
/// This is specific to Lume's UI needs
extension FitIQCore.OutboxEventType {
    /// Human-readable display name for this event type
    public var displayName: String {
        switch self {
        case .moodEntry:
            return "Mood Entry"
        case .journalEntry:
            return "Journal Entry"
        case .goal:
            return "Goal"
        case .progressEntry:
            return "Progress Entry"
        case .physicalAttribute:
            return "Physical Attribute"
        case .activitySnapshot:
            return "Activity Snapshot"
        case .sleepSession:
            return "Sleep Session"
        case .mealLog:
            return "Meal Log"
        case .workout:
            return "Workout"
        @unknown default:
            return "Unknown Event"
        }
    }
}

/// Extension to provide display names for event statuses
/// This is specific to Lume's UI needs
extension FitIQCore.OutboxEventStatus {
    /// Human-readable display name for this status
    public var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    /// Icon name for this status (SF Symbols)
    public var iconName: String {
        switch self {
        case .pending:
            return "clock"
        case .processing:
            return "arrow.clockwise"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}
