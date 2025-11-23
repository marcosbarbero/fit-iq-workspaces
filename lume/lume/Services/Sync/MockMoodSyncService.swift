//
//  MockMoodSyncService.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Mock sync service for previews and testing
//

import Foundation

/// Mock mood sync service for previews and testing
@MainActor
final class MockMoodSyncService: MoodSyncPort {
    
    var shouldSimulateSuccess = true
    var restoreCalled = false
    var syncCalled = false
    
    init() {
        // No-op initializer for mock
    }
    
    func restoreFromBackend() async throws -> Int {
        restoreCalled = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if shouldSimulateSuccess {
            print("✅ [MockMoodSyncService] Simulated restore (0 entries)")
            return 0
        } else {
            throw MoodSyncError.syncFailed("Simulated failure")
        }
    }
    
    func performFullSync() async throws -> MoodSyncResult {
        syncCalled = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if shouldSimulateSuccess {
            print("✅ [MockMoodSyncService] Simulated full sync")
            return MoodSyncResult(entriesRestored: 0, entriesPushed: 0)
        } else {
            throw MoodSyncError.syncFailed("Simulated failure")
        }
    }
}
