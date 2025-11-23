//
//  MoodSourceType.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of HKStateOfMind Mood Tracking Integration
//

import Foundation

/// Source type for mood entries
/// Tracks where the mood data originated from to handle sync logic appropriately
enum MoodSourceType: String, Codable, Sendable {
    /// User manually entered the mood in the FitIQ app
    case userEntry

    /// Mood was synced from Apple HealthKit
    case healthKit

    /// Mood was fetched from the backend API
    case backend

    // MARK: - Computed Properties

    /// Returns the display name for the source type
    var displayName: String {
        switch self {
        case .userEntry:
            return "Manual Entry"
        case .healthKit:
            return "Apple Health"
        case .backend:
            return "Synced from Server"
        }
    }

    /// Returns an SF Symbol name for the source type
    var symbolName: String {
        switch self {
        case .userEntry:
            return "hand.tap.fill"
        case .healthKit:
            return "heart.text.square.fill"
        case .backend:
            return "cloud.fill"
        }
    }

    /// Indicates whether this source should trigger backend sync
    var shouldSyncToBackend: Bool {
        switch self {
        case .userEntry, .healthKit:
            return true  // User-generated or HealthKit data should sync to backend
        case .backend:
            return false  // Already from backend, no need to sync back
        }
    }

    /// Indicates whether this source should trigger HealthKit sync
    var shouldSyncToHealthKit: Bool {
        switch self {
        case .userEntry:
            return true  // User entries should sync to HealthKit
        case .healthKit:
            return false  // Already from HealthKit, no need to sync back
        case .backend:
            return true  // Backend data can optionally sync to HealthKit
        }
    }
}
