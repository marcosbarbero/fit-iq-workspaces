//
//  SaveWeightProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation

/// Protocol defining the contract for saving weight progress
protocol SaveWeightProgressUseCase {
    /// Saves weight (body mass) for a specific date locally and triggers backend sync
    /// - Parameters:
    ///   - weightKg: The weight in kilograms to log
    ///   - date: The date for which to log weight (defaults to current date)
    /// - Returns: The local UUID of the saved progress entry
    func execute(weightKg: Double, date: Date) async throws -> UUID
}

/// Implementation of SaveWeightProgressUseCase following existing patterns
final class SaveWeightProgressUseCaseImpl: SaveWeightProgressUseCase {

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

    func execute(weightKg: Double, date: Date = Date()) async throws -> UUID {
        // Validate input
        guard weightKg > 0 else {
            throw SaveWeightProgressError.invalidWeight
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveWeightProgressError.userNotAuthenticated
        }

        print("SaveWeightProgressUseCase: Saving \(weightKg)kg for user \(userID) on \(date)")

        // Check for existing entry on the same date
        let existingEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .weight,
            syncStatus: nil,
            limit: 100  // Limit to recent entries for performance
        )

        // Normalize date to start of day for comparison
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        // Look for existing entry on the same date
        if let existingEntry = existingEntries.first(where: { entry in
            let entryDate = calendar.startOfDay(for: entry.date)
            return calendar.isDate(entryDate, inSameDayAs: targetDate)
        }) {
            // Check if the quantity is the same (with tolerance for floating point comparison)
            if abs(existingEntry.quantity - weightKg) < 0.01 {
                print(
                    "SaveWeightProgressUseCase: Entry already exists for \(targetDate) with same weight (\(weightKg)kg). Skipping duplicate. Local ID: \(existingEntry.id)"
                )
                return existingEntry.id
            } else {
                print(
                    "SaveWeightProgressUseCase: Entry exists for \(targetDate) but with different weight (existing: \(existingEntry.quantity)kg, new: \(weightKg)kg). Updating quantity."
                )

                // Create updated entry with new quantity
                let updatedEntry = ProgressEntry(
                    id: existingEntry.id,  // Keep same local ID
                    userID: userID,
                    type: .weight,
                    quantity: weightKg,
                    date: existingEntry.date,
                    notes: existingEntry.notes,
                    createdAt: existingEntry.createdAt,
                    updatedAt: Date(),
                    backendID: existingEntry.backendID,
                    syncStatus: existingEntry.backendID != nil ? .pending : .pending  // Mark for re-sync
                )

                let localID = try await progressRepository.save(
                    progressEntry: updatedEntry, forUserID: userID)

                print(
                    "SaveWeightProgressUseCase: Successfully updated weight progress. Local ID: \(localID)"
                )

                return localID
            }
        }

        // No existing entry found, create new one
        print(
            "SaveWeightProgressUseCase: No existing entry found for \(targetDate). Creating new entry."
        )

        // Create progress entry
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .weight,
            quantity: weightKg,
            date: targetDate,
            notes: nil,
            createdAt: Date(),
            backendID: nil,
            syncStatus: .pending  // Mark as pending for sync
        )

        // Save locally
        let localID = try await progressRepository.save(
            progressEntry: progressEntry, forUserID: userID)

        print(
            "SaveWeightProgressUseCase: Successfully saved new weight progress with local ID: \(localID)"
        )

        // Repository will trigger sync event automatically
        // RemoteSyncService will pick it up and sync to backend

        return localID
    }
}

// MARK: - Errors

enum SaveWeightProgressError: Error, LocalizedError {
    case invalidWeight
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidWeight:
            return "Weight must be greater than zero"
        case .userNotAuthenticated:
            return "User must be authenticated to save weight progress"
        }
    }
}
