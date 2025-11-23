//
//  CleanupDuplicateStepsUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: One-time cleanup of duplicate step entries in local database
//

import Foundation

/// Quick cleanup use case to remove duplicate step entries
/// This is a temporary fix for the duplicate data issue
protocol CleanupDuplicateStepsUseCase {
    /// Removes all duplicate step entries, keeping only the first occurrence
    func execute() async throws -> CleanupResult
}

// MARK: - Implementation

final class CleanupDuplicateStepsUseCaseImpl: CleanupDuplicateStepsUseCase {

    private let progressRepository: SwiftDataProgressRepository
    private let authManager: AuthManager

    init(
        progressRepository: SwiftDataProgressRepository,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    func execute() async throws -> CleanupResult {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw CleanupError.userNotAuthenticated
        }

        print("================================================================================")
        print("CleanupDuplicateStepsUseCase: 🧹 STARTING CLEANUP")
        print("User: \(userID)")
        print("================================================================================")

        // Remove duplicates for steps
        try await progressRepository.removeDuplicates(forUserID: userID, type: .steps)

        print("CleanupDuplicateStepsUseCase: ✅ CLEANUP COMPLETE")
        print("================================================================================")

        return CleanupResult(
            metricType: .steps,
            success: true,
            message: "Successfully removed duplicate step entries"
        )
    }
}

// MARK: - Supporting Types

struct CleanupResult {
    let metricType: ProgressMetricType
    let success: Bool
    let message: String
}

enum CleanupError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to perform cleanup"
        }
    }
}
