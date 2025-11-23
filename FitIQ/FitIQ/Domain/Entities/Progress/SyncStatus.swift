//
//  SyncStatus.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Progress Tracking and Backend Sync Architecture
//

import Foundation

/// Represents the synchronization status of a progress entry with the backend
///
/// This enum tracks the lifecycle of a progress entry as it moves from local storage
/// to backend synchronization, supporting the app's local-first architecture.
///
/// **Sync Flow:**
/// 1. Entry created locally → `.pending`
/// 2. Sync service picks it up → `.syncing`
/// 3. Backend confirms → `.synced`
/// 4. If sync fails → `.failed` (will retry)
///
/// **Usage:**
/// ```swift
/// let entry = ProgressEntry(
///     userID: "123",
///     type: .steps,
///     quantity: 10000,
///     date: Date(),
///     syncStatus: .pending  // Initial state
/// )
/// ```
public enum SyncStatus: String, Codable, CaseIterable {
    /// Entry created locally but not yet synced to backend
    ///
    /// This is the initial state for all new progress entries.
    /// The RemoteSyncService will detect pending entries and attempt to sync them.
    case pending = "pending"

    /// Entry is currently being synchronized to backend
    ///
    /// Set when RemoteSyncService begins uploading the entry.
    /// Prevents duplicate sync attempts while upload is in progress.
    case syncing = "syncing"

    /// Entry successfully synchronized to backend
    ///
    /// Set when backend confirms successful creation/update.
    /// Entry's `backendID` should be populated at this point.
    case synced = "synced"

    /// Sync attempt failed, will be retried
    ///
    /// Set when backend sync fails (network error, validation error, etc.).
    /// RemoteSyncService will retry failed entries on next sync cycle.
    case failed = "failed"

    // MARK: - Display Properties

    /// Human-readable display name for UI
    var displayName: String {
        switch self {
        case .pending: return "Pending Sync"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .failed: return "Sync Failed"
        }
    }

    /// SF Symbol icon name for this status
    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    /// Color indicator for this status
    var colorName: String {
        switch self {
        case .pending: return "gray"
        case .syncing: return "blue"
        case .synced: return "green"
        case .failed: return "red"
        }
    }

    // MARK: - State Checks

    /// Whether this entry needs synchronization
    var needsSync: Bool {
        return self == .pending || self == .failed
    }

    /// Whether sync is currently in progress
    var isSyncing: Bool {
        return self == .syncing
    }

    /// Whether sync completed successfully
    var isSynced: Bool {
        return self == .synced
    }

    /// Whether sync failed and needs retry
    var hasFailed: Bool {
        return self == .failed
    }
}

// MARK: - CustomStringConvertible

extension SyncStatus: CustomStringConvertible {
    public var description: String {
        return displayName
    }
}
