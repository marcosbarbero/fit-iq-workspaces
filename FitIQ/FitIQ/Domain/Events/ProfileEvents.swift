//
//  ProfileEvents.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Domain events for profile changes
/// These events are published when profile data changes, allowing other parts of the system
/// to react (e.g., sync with backend, update HealthKit, refresh UI)
public enum ProfileEvent {
    /// Profile metadata was updated (name, bio, preferences)
    case metadataUpdated(userId: String, timestamp: Date)

    /// Physical profile was updated (height, biological sex, date of birth)
    case physicalProfileUpdated(userId: String, timestamp: Date)
}

// MARK: - Equatable

extension ProfileEvent: Equatable {
    public static func == (lhs: ProfileEvent, rhs: ProfileEvent) -> Bool {
        switch (lhs, rhs) {
        case (
            .metadataUpdated(let lUserId, let lTimestamp),
            .metadataUpdated(let rUserId, let rTimestamp)
        ):
            return lUserId == rUserId && lTimestamp == rTimestamp

        case (
            .physicalProfileUpdated(let lUserId, let lTimestamp),
            .physicalProfileUpdated(let rUserId, let rTimestamp)
        ):
            return lUserId == rUserId && lTimestamp == rTimestamp

        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension ProfileEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .metadataUpdated(let userId, let timestamp):
            return "ProfileEvent.metadataUpdated(userId: \(userId), timestamp: \(timestamp))"

        case .physicalProfileUpdated(let userId, let timestamp):
            return "ProfileEvent.physicalProfileUpdated(userId: \(userId), timestamp: \(timestamp))"
        }
    }
}
