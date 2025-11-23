//
//  SyncMoodEntriesUseCase.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Use case for syncing mood entries with backend (Domain Layer)
//

import Foundation

/// Result of mood sync operation
public struct MoodSyncResult {
    public let entriesRestored: Int
    public let entriesPushed: Int
    
    public var totalSynced: Int {
        entriesRestored + entriesPushed
    }
    
    public var description: String {
        if totalSynced == 0 {
            return "Already in sync"
        }
        var parts: [String] = []
        if entriesRestored > 0 {
            parts.append("\(entriesRestored) restored from backend")
        }
        if entriesPushed > 0 {
            parts.append("\(entriesPushed) pushed to backend")
        }
        return parts.joined(separator: ", ")
    }
    
    public init(entriesRestored: Int, entriesPushed: Int) {
        self.entriesRestored = entriesRestored
        self.entriesPushed = entriesPushed
    }
}

/// Port (protocol) for syncing mood entries - defined in Domain
protocol MoodSyncPort {
    /// Restore missing mood entries from backend
    func restoreFromBackend() async throws -> Int
    
    /// Perform full bidirectional sync
    func performFullSync() async throws -> MoodSyncResult
}

/// Use case for syncing mood entries
protocol SyncMoodEntriesUseCase {
    /// Perform full sync with backend
    func execute() async throws -> MoodSyncResult
}

/// Implementation of mood sync use case
final class SyncMoodEntriesUseCaseImpl: SyncMoodEntriesUseCase {
    
    private let syncPort: MoodSyncPort
    
    init(syncPort: MoodSyncPort) {
        self.syncPort = syncPort
    }
    
    func execute() async throws -> MoodSyncResult {
        print("🔄 [SyncMoodEntriesUseCase] Executing full sync")
        return try await syncPort.performFullSync()
    }
}
