//
//  LogHeightProgressUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Biological Sex and Height Improvements
//

import Foundation

/// Use case for logging height changes to the progress tracking system
///
/// This use case handles validation and logging of height measurements to the
/// backend progress endpoint, enabling time-series tracking of height changes.
///
/// **Business Rules:**
/// - Height must be positive and within reasonable human range (0-300 cm)
/// - Each height change is logged with a timestamp
/// - Historical height data can be retrieved for growth tracking
///
/// **Architecture:**
/// - Domain layer (use case)
/// - Depends on ProgressRepositoryProtocol (port)
/// - Implemented by ProgressAPIClient (infrastructure)
protocol LogHeightProgressUseCase {
    /// Logs a height measurement to the progress tracking system
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - heightCm: The height measurement in centimeters
    ///   - loggedAt: Optional date-time for the measurement (defaults to now)
    ///   - notes: Optional notes about the measurement
    /// - Returns: The created progress entry
    /// - Throws: ValidationError if height is invalid, or repository errors
    func execute(
        userId: String,
        heightCm: Double,
        loggedAt: Date?,
        notes: String?
    ) async throws -> ProgressEntry
}

/// Implementation of LogHeightProgressUseCase
final class LogHeightProgressUseCaseImpl: LogHeightProgressUseCase {

    // MARK: - Dependencies

    private let progressRepository: ProgressRepositoryProtocol

    // MARK: - Initialization

    init(progressRepository: ProgressRepositoryProtocol) {
        self.progressRepository = progressRepository
    }

    // MARK: - LogHeightProgressUseCase Implementation

    func execute(
        userId: String,
        heightCm: Double,
        loggedAt: Date?,
        notes: String?
    ) async throws -> ProgressEntry {
        print("LogHeightProgressUseCase: Logging height progress for user \(userId)")
        print("LogHeightProgressUseCase: Height: \(heightCm) cm")
        print("LogHeightProgressUseCase: Logged at: \(loggedAt?.description ?? "now")")

        // Validation: Height must be positive
        guard heightCm > 0 else {
            print("LogHeightProgressUseCase: ❌ Invalid height: \(heightCm) (must be positive)")
            throw FitIQValidationError.invalidHeight("Height must be greater than 0")
        }

        // Validation: Height must be within reasonable human range
        guard heightCm < 300 else {
            print("LogHeightProgressUseCase: ❌ Invalid height: \(heightCm) (too tall)")
            throw FitIQValidationError.invalidHeight("Height must be less than 300 cm")
        }

        // Log to progress repository
        let progressEntry = try await progressRepository.logProgress(
            type: .height,
            quantity: heightCm,
            loggedAt: loggedAt,
            notes: notes
        )

        print("LogHeightProgressUseCase: ✅ Successfully logged height progress")
        print("LogHeightProgressUseCase: Entry ID: \(progressEntry.id)")

        return progressEntry
    }
}

// MARK: - Validation Errors

enum FitIQValidationError: Error, LocalizedError {
    case invalidHeight(String)
    case invalidUserId(String)

    var errorDescription: String? {
        switch self {
        case .invalidHeight(let message):
            return "Invalid height: \(message)"
        case .invalidUserId(let message):
            return "Invalid user ID: \(message)"
        }
    }
}
