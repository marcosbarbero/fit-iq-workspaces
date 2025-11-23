//
//  SaveStepsProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Protocol defining the contract for saving steps progress
protocol SaveStepsProgressUseCase {
    /// Saves steps count for a specific date locally and triggers backend sync
    /// - Parameters:
    ///   - steps: The number of steps to log
    ///   - date: The date for which to log steps (defaults to current date)
    /// - Returns: The local UUID of the saved progress entry
    func execute(steps: Int, date: Date) async throws -> UUID
}

/// Implementation of SaveStepsProgressUseCase following existing patterns
final class SaveStepsProgressUseCaseImpl: SaveStepsProgressUseCase {

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

    // MARK: - Execute

    func execute(steps: Int, date: Date = Date()) async throws -> UUID {
        // Validate input
        guard steps >= 0 else {
            throw SaveStepsProgressError.invalidStepsCount
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveStepsProgressError.userNotAuthenticated
        }

        // Normalize to start of hour for comparison (preserve hourly granularity)
        let calendar = Calendar.current
        let hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard let targetHour = calendar.date(from: hourComponents) else {
            throw SaveStepsProgressError.invalidDate
        }

        print("SaveStepsProgressUseCase: Saving \(steps) steps for user \(userID) at \(targetHour)")

        // Create time string in HH:MM:SS format
        let hour = calendar.component(.hour, from: targetHour)
        let timeString = String(format: "%02d:00:00", hour)

        // Create progress entry with time component for hourly tracking
        // Note: Repository handles duplicates via unique constraints at database level
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .steps,
            quantity: Double(steps),
            date: targetHour,
            time: timeString,
            notes: nil,
            createdAt: Date(),
            backendID: nil,
            syncStatus: .pending  // Mark as pending for sync
        )

        // Save locally
        let localID = try await progressRepository.save(
            progressEntry: progressEntry, forUserID: userID)

        print(
            "SaveStepsProgressUseCase: Successfully saved steps progress with local ID: \(localID)"
        )

        // Note: If duplicate exists, repository handles it (update or skip based on unique constraints)
        // Repository will trigger sync event automatically
        // RemoteSyncService will pick it up and sync to backend

        return localID
    }
}

// MARK: - Errors

enum SaveStepsProgressError: Error, LocalizedError {
    case invalidStepsCount
    case userNotAuthenticated
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .invalidStepsCount:
            return "Steps count cannot be negative"
        case .userNotAuthenticated:
            return "User must be authenticated to save steps progress"
        case .invalidDate:
            return "Invalid date provided"
        }
    }
}
