//
//  SaveWaterProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Protocol defining the contract for saving water intake progress
protocol SaveWaterProgressUseCase {
    /// Saves water intake for a specific date locally and triggers backend sync
    /// - Parameters:
    ///   - liters: The water intake in liters to log
    ///   - date: The date for which to log water intake (defaults to current date)
    /// - Returns: The local UUID of the saved progress entry
    func execute(liters: Double, date: Date) async throws -> UUID
}

/// Implementation of SaveWaterProgressUseCase following existing patterns
final class SaveWaterProgressUseCaseImpl: SaveWaterProgressUseCase {

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

    func execute(liters: Double, date: Date = Date()) async throws -> UUID {
        // Validate input
        guard liters > 0 else {
            throw SaveWaterProgressError.invalidAmount
        }

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveWaterProgressError.userNotAuthenticated
        }

        print("SaveWaterProgressUseCase: ========================================")
        print("SaveWaterProgressUseCase: 💧 EXECUTE CALLED")
        print("SaveWaterProgressUseCase: 💧   User ID: \(userID)")
        print("SaveWaterProgressUseCase: 💧   Input liters: \(String(format: "%.3f", liters))L")
        print("SaveWaterProgressUseCase: 💧   Date: \(date)")
        print("SaveWaterProgressUseCase: ========================================")

        // Check for existing entry on the same date
        let existingEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .waterLiters,
            syncStatus: nil,
            limit: 100  // Limit to recent entries for performance
        )

        print("SaveWaterProgressUseCase: 💧 Found \(existingEntries.count) existing water entries")
        for (index, entry) in existingEntries.enumerated() {
            print("SaveWaterProgressUseCase: 💧   Entry #\(index + 1):")
            print("SaveWaterProgressUseCase: 💧     - ID: \(entry.id)")
            print(
                "SaveWaterProgressUseCase: 💧     - Quantity: \(String(format: "%.3f", entry.quantity))L"
            )
            print("SaveWaterProgressUseCase: 💧     - Date: \(entry.date)")
            print("SaveWaterProgressUseCase: 💧     - Created: \(entry.createdAt)")
            print("SaveWaterProgressUseCase: 💧     - Sync Status: \(entry.syncStatus)")
        }

        // Normalize date to start of day for comparison
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        // Look for existing entry on the same date and aggregate
        if let existingEntry = existingEntries.first(where: { entry in
            let entryDate = calendar.startOfDay(for: entry.date)
            return calendar.isDate(entryDate, inSameDayAs: targetDate)
        }) {
            print("SaveWaterProgressUseCase: ✅ EXISTING ENTRY FOUND")
            print("SaveWaterProgressUseCase: 💧   Entry ID: \(existingEntry.id)")
            print(
                "SaveWaterProgressUseCase: 💧   Current quantity: \(String(format: "%.3f", existingEntry.quantity))L"
            )

            // For water intake, we AGGREGATE (add to existing) rather than replace
            let newTotal = existingEntry.quantity + liters

            print("SaveWaterProgressUseCase: 💧   Input to add: \(String(format: "%.3f", liters))L")
            print("SaveWaterProgressUseCase: 💧   NEW TOTAL: \(String(format: "%.3f", newTotal))L")
            print(
                "SaveWaterProgressUseCase: 💧   Calculation: \(String(format: "%.3f", existingEntry.quantity)) + \(String(format: "%.3f", liters)) = \(String(format: "%.3f", newTotal))"
            )

            // Create updated entry with aggregated quantity
            let updatedEntry = ProgressEntry(
                id: existingEntry.id,  // Keep same local ID
                userID: userID,
                type: .waterLiters,
                quantity: newTotal,  // Aggregate the quantities
                date: existingEntry.date,  // CRITICAL: Keep same date to prevent duplicates
                notes: existingEntry.notes,
                createdAt: existingEntry.createdAt,
                updatedAt: Date(),
                backendID: nil,  // Clear backend ID to trigger re-sync with new total
                syncStatus: .pending  // Mark for re-sync
            )

            let localID = try await progressRepository.save(
                progressEntry: updatedEntry, forUserID: userID)

            print("SaveWaterProgressUseCase: ✅ SUCCESSFULLY UPDATED ENTRY")
            print("SaveWaterProgressUseCase: 💧   Local ID: \(localID)")
            print("SaveWaterProgressUseCase: 💧   Final total: \(String(format: "%.3f", newTotal))L")

            // Verify we didn't create a duplicate
            let verifyEntries = try await progressRepository.fetchLocal(
                forUserID: userID,
                type: .waterLiters,
                syncStatus: nil,
                limit: 100
            )
            print("SaveWaterProgressUseCase: 💧 VERIFICATION:")
            print(
                "SaveWaterProgressUseCase: 💧   Total entries after update: \(verifyEntries.count)")
            if verifyEntries.count > 1 {
                print(
                    "SaveWaterProgressUseCase: ⚠️ WARNING: Multiple entries found! Should only be 1 per day."
                )
                for (index, entry) in verifyEntries.enumerated() {
                    print(
                        "SaveWaterProgressUseCase: ⚠️   Entry #\(index + 1): \(String(format: "%.3f", entry.quantity))L at \(entry.date)"
                    )
                }
            }

            return localID
        }

        // No existing entry found, create new one
        print("SaveWaterProgressUseCase: ✅ NO EXISTING ENTRY")
        print("SaveWaterProgressUseCase: 💧   Target date: \(targetDate)")
        print(
            "SaveWaterProgressUseCase: 💧   Creating new entry with \(String(format: "%.3f", liters))L"
        )

        // Create progress entry
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .waterLiters,
            quantity: liters,
            date: date,
            notes: nil,
            createdAt: Date(),
            backendID: nil,
            syncStatus: .pending  // Mark as pending for sync
        )

        // Save locally
        let localID = try await progressRepository.save(
            progressEntry: progressEntry, forUserID: userID)

        print("SaveWaterProgressUseCase: ✅ SUCCESSFULLY CREATED NEW ENTRY")
        print("SaveWaterProgressUseCase: 💧   Local ID: \(localID)")
        print("SaveWaterProgressUseCase: 💧   Amount: \(String(format: "%.3f", liters))L")
        print("SaveWaterProgressUseCase: ========================================")

        // Repository will trigger sync event automatically
        // RemoteSyncService will pick it up and sync to backend

        return localID
    }
}

// MARK: - Errors

enum SaveWaterProgressError: Error, LocalizedError {
    case invalidAmount
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Water intake must be greater than zero"
        case .userNotAuthenticated:
            return "User must be authenticated to save water intake progress"
        }
    }
}
