//
//  SaveSleepProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Save sleep data locally and trigger backend sync via Outbox Pattern
//

import Foundation

/// Protocol defining the contract for saving sleep progress
protocol SaveSleepProgressUseCase {
    /// Saves sleep duration for a specific date locally and triggers backend sync
    /// - Parameters:
    ///   - sleepHours: The total sleep duration in hours
    ///   - efficiency: Optional sleep efficiency percentage (0-100)
    ///   - date: The date for which to log sleep (defaults to current date)
    /// - Returns: The local UUID of the saved progress entry
    func execute(sleepHours: Double, efficiency: Int?, date: Date) async throws -> UUID
}

/// Implementation of SaveSleepProgressUseCase following Outbox Pattern
final class SaveSleepProgressUseCaseImpl: SaveSleepProgressUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        progressRepository: ProgressRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }

    // MARK: - Use Case Execution

    func execute(sleepHours: Double, efficiency: Int?, date: Date) async throws -> UUID {
        // 1. Validate user authentication
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveSleepProgressError.userNotAuthenticated
        }

        // 2. Validate sleep data
        guard sleepHours > 0 && sleepHours <= 24 else {
            throw SaveSleepProgressError.invalidSleepDuration
        }

        if let eff = efficiency {
            guard eff >= 0 && eff <= 100 else {
                throw SaveSleepProgressError.invalidEfficiency
            }
        }

        print("SaveSleepProgressUseCase: Saving \(sleepHours)h sleep for user \(userID)")

        // 3. Create notes with efficiency if provided
        var notes: String? = nil
        if let efficiency = efficiency {
            notes = "efficiency:\(efficiency)"
        }

        // 4. Create ProgressEntry (sleep duration in hours)
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .sleepHours,
            quantity: sleepHours,
            date: date,
            time: nil,  // Sleep is typically logged per day, not per hour
            notes: notes,
            createdAt: Date(),
            updatedAt: nil,
            backendID: nil,
            syncStatus: .pending  // ✅ CRITICAL: Mark for Outbox Pattern sync
        )

        // 5. Save to repository (automatically triggers Outbox Pattern)
        let localID = try await progressRepository.save(
            progressEntry: progressEntry,
            forUserID: userID
        )

        print(
            "SaveSleepProgressUseCase: Successfully saved sleep progress with local ID: \(localID)"
        )

        return localID
    }
}

// MARK: - Errors

enum SaveSleepProgressError: Error, LocalizedError {
    case userNotAuthenticated
    case invalidSleepDuration
    case invalidEfficiency

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to save sleep progress"
        case .invalidSleepDuration:
            return "Sleep duration must be between 0 and 24 hours"
        case .invalidEfficiency:
            return "Sleep efficiency must be between 0 and 100"
        }
    }
}
