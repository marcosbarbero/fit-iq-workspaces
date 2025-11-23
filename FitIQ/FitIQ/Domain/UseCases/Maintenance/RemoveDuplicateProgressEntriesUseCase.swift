//
//  RemoveDuplicateProgressEntriesUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Remove duplicate progress entries from local storage
//

import Foundation

// MARK: - Protocol

/// Use case for removing duplicate progress entries
/// Useful for cleaning up data after sync issues or schema migrations
protocol RemoveDuplicateProgressEntriesUseCase {
    /// Removes duplicate progress entries for a specific metric type
    /// - Parameter type: The metric type to deduplicate (e.g., .steps, .heartRate)
    func execute(forType type: ProgressMetricType) async throws

    /// Removes duplicate progress entries for all metric types
    func executeForAllTypes() async throws
}

// MARK: - Implementation

final class RemoveDuplicateProgressEntriesUseCaseImpl: RemoveDuplicateProgressEntriesUseCase {

    // MARK: - Dependencies

    private let progressRepository: SwiftDataProgressRepository
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        progressRepository: SwiftDataProgressRepository,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(forType type: ProgressMetricType) async throws {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw RemoveDuplicateProgressEntriesError.userNotAuthenticated
        }

        print(
            "RemoveDuplicateProgressEntriesUseCase: 🧹 Starting duplicate removal for \(type.rawValue)"
        )

        // Remove duplicates for this type
        try await progressRepository.removeDuplicates(forUserID: userID, type: type)

        print(
            "RemoveDuplicateProgressEntriesUseCase: ✅ Completed duplicate removal for \(type.rawValue)"
        )
    }

    func executeForAllTypes() async throws {
        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw RemoveDuplicateProgressEntriesError.userNotAuthenticated
        }

        print("RemoveDuplicateProgressEntriesUseCase: 🧹 Starting duplicate removal for ALL types")

        // List of all metric types to clean
        let typesToClean: [ProgressMetricType] = [
            .steps,
            .restingHeartRate,
            .weight,
            .height,
            .bodyFatPercentage,
            .moodScore,
        ]

        for type in typesToClean {
            print("RemoveDuplicateProgressEntriesUseCase: Processing \(type.rawValue)...")

            do {
                try await progressRepository.removeDuplicates(forUserID: userID, type: type)
            } catch {
                print(
                    "RemoveDuplicateProgressEntriesUseCase: ⚠️ Failed to remove duplicates for \(type.rawValue): \(error.localizedDescription)"
                )
                // Continue with other types even if one fails
            }
        }

        print("RemoveDuplicateProgressEntriesUseCase: ✅ Completed duplicate removal for all types")
    }
}

// MARK: - Errors

enum RemoveDuplicateProgressEntriesError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to remove duplicate entries"
        }
    }
}
