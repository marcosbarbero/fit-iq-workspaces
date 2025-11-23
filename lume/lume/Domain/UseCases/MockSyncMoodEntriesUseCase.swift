//
//  MockSyncMoodEntriesUseCase.swift
//  lume
//
//  Created by AI Assistant on 15/01/2025.
//  Mock implementation for previews and testing
//

import Foundation

/// Mock implementation of SyncMoodEntriesUseCase for previews and testing
final class MockSyncMoodEntriesUseCase: SyncMoodEntriesUseCase {

    var shouldFail = false
    var mockResult = MoodSyncResult(
        entriesRestored: 0,
        entriesPushed: 0
    )

    func execute() async throws -> MoodSyncResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        if shouldFail {
            throw MockSyncError.simulatedFailure
        }

        return mockResult
    }
}

// MARK: - Mock Error

enum MockSyncError: LocalizedError {
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated sync failure for testing"
        }
    }
}

// MARK: - Convenience Initializers

extension MockSyncMoodEntriesUseCase {
    /// Create mock that simulates successful sync with restored entries
    static func withRestoredEntries(count: Int) -> MockSyncMoodEntriesUseCase {
        let mock = MockSyncMoodEntriesUseCase()
        mock.mockResult = MoodSyncResult(
            entriesRestored: count,
            entriesPushed: 0
        )
        return mock
    }

    /// Create mock that simulates successful sync with no changes
    static func withNoChanges() -> MockSyncMoodEntriesUseCase {
        let mock = MockSyncMoodEntriesUseCase()
        mock.mockResult = MoodSyncResult(
            entriesRestored: 0,
            entriesPushed: 0
        )
        return mock
    }

    /// Create mock that simulates sync failure
    static func withFailure() -> MockSyncMoodEntriesUseCase {
        let mock = MockSyncMoodEntriesUseCase()
        mock.shouldFail = true
        return mock
    }
}
