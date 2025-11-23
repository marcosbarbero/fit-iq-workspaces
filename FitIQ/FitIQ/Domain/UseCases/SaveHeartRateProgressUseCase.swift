//
//  SaveHeartRateProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Protocol defining the contract for saving heart rate progress
protocol SaveHeartRateProgressUseCase {
    /// Saves resting heart rate for a specific date locally and triggers backend sync
    /// - Parameters:
    ///   - heartRate: The resting heart rate in beats per minute (bpm)
    ///   - date: The date for which to log heart rate (defaults to current date)
    /// - Returns: The local UUID of the saved progress entry
    func execute(heartRate: Double, date: Date) async throws -> UUID
}

/// Implementation of SaveHeartRateProgressUseCase following existing patterns
final class SaveHeartRateProgressUseCaseImpl: SaveHeartRateProgressUseCase {

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

    func execute(heartRate: Double, date: Date = Date()) async throws -> UUID {
        // Validate input
        guard heartRate > 0 else {
            throw SaveHeartRateProgressError.invalidHeartRate
        }

        guard heartRate >= 20 && heartRate <= 300 else {
            throw SaveHeartRateProgressError.heartRateOutOfRange
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveHeartRateProgressError.userNotAuthenticated
        }

        // IMPORTANT: For Summary card real-time display, we use the ACTUAL timestamp
        // But for hourly aggregates and deduplication, we normalize to hour
        let calendar = Calendar.current

        // Keep the exact timestamp for display purposes
        let exactTimestamp = date

        // Also create normalized hour for grouping (used by hourly aggregates)
        let hourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard let normalizedHour = calendar.date(from: hourComponents) else {
            throw SaveHeartRateProgressError.invalidDate
        }

        print(
            "SaveHeartRateProgressUseCase: Saving heart rate \(heartRate) bpm for user \(userID) at \(exactTimestamp) (normalized: \(normalizedHour))"
        )

        // Create time string in HH:MM:SS format from EXACT timestamp (for display)
        let hour = calendar.component(.hour, from: exactTimestamp)
        let minute = calendar.component(.minute, from: exactTimestamp)
        let second = calendar.component(.second, from: exactTimestamp)
        let timeString = String(format: "%02d:%02d:%02d", hour, minute, second)

        // Create progress entry with EXACT timestamp
        // Note: Repository handles duplicates via unique constraints at database level
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .restingHeartRate,
            quantity: heartRate,
            date: exactTimestamp,  // Use EXACT timestamp for real-time display
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
            "SaveHeartRateProgressUseCase: Successfully saved heart rate progress with local ID: \(localID)"
        )

        // Note: If duplicate exists, repository handles it (update or skip based on unique constraints)
        // Repository will trigger sync event automatically
        // RemoteSyncService will pick it up and sync to backend

        return localID
    }
}

// MARK: - Errors

enum SaveHeartRateProgressError: Error, LocalizedError {
    case invalidHeartRate
    case heartRateOutOfRange
    case userNotAuthenticated
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .invalidHeartRate:
            return "Heart rate must be greater than 0"
        case .heartRateOutOfRange:
            return "Heart rate must be between 20 and 300 bpm"
        case .userNotAuthenticated:
            return "User must be authenticated to save heart rate progress"
        case .invalidDate:
            return "Invalid date provided"
        }
    }
}
