//
//  GetLatestSleepForSummaryUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Fetch last night's sleep data for summary card display
//

import Foundation

// MARK: - Protocol (Port)

/// Use case for fetching the latest sleep data for summary display
protocol GetLatestSleepForSummaryUseCase {
    /// Execute the use case to fetch last night's sleep data
    /// - Returns: Tuple containing total sleep duration (hours), sleep efficiency (%), and last sleep date
    /// - Note: Returns nil values if no sleep data is available
    func execute() async throws -> (sleepHours: Double?, efficiency: Int?, lastSleepDate: Date?)
}

// MARK: - Implementation

final class GetLatestSleepForSummaryUseCaseImpl: GetLatestSleepForSummaryUseCase {

    // MARK: - Dependencies

    private let sleepRepository: SleepRepositoryProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(sleepRepository: SleepRepositoryProtocol, authManager: AuthManager) {
        self.sleepRepository = sleepRepository
        self.authManager = authManager
    }

    // MARK: - Use Case Execution

    func execute() async throws -> (sleepHours: Double?, efficiency: Int?, lastSleepDate: Date?) {
        print("GetLatestSleepForSummaryUseCase: Fetching latest sleep session")

        // Get current user ID
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw GetLatestSleepForSummaryError.userNotAuthenticated
        }

        // Fetch the most recent sleep session from repository
        guard let latestSession = try await sleepRepository.fetchLatestSession(forUserID: userID)
        else {
            print("GetLatestSleepForSummaryUseCase: No sleep data available")
            return (sleepHours: nil, efficiency: nil, lastSleepDate: nil)
        }

        // Debug: Log raw session data
        print("GetLatestSleepForSummaryUseCase: 🔍 DEBUG - Raw session data:")
        print("  - Session ID: \(latestSession.id)")
        print("  - Session Date: \(latestSession.date)")
        print("  - Start Time: \(latestSession.startTime)")
        print("  - End Time: \(latestSession.endTime)")
        print("  - Time in Bed: \(latestSession.timeInBedMinutes) minutes (\(latestSession.timeInBedHours) hours)")
        print("  - Total Sleep: \(latestSession.totalSleepMinutes) minutes")
        print("  - Sleep Efficiency: \(latestSession.sleepEfficiency)%")

        if let stages = latestSession.stages {
            print("  - Sleep Stages Count: \(stages.count)")
            for (index, stage) in stages.enumerated() {
                print("    Stage \(index + 1): \(stage.stage.rawValue) - \(stage.durationMinutes) min (isActualSleep: \(stage.stage.isActualSleep))")
            }

            // Manually calculate total sleep minutes to verify
            let calculatedSleepMinutes = stages.filter { $0.stage.isActualSleep }.reduce(0) { $0 + $1.durationMinutes }
            print("  - Calculated Sleep Minutes (from stages): \(calculatedSleepMinutes) minutes")

            if calculatedSleepMinutes != latestSession.totalSleepMinutes {
                print("  - ⚠️ WARNING: Mismatch between stored totalSleepMinutes (\(latestSession.totalSleepMinutes)) and calculated (\(calculatedSleepMinutes))")
            }
        } else {
            print("  - Sleep Stages: None (no stage data available)")
        }

        // Convert sleep minutes to hours
        let sleepHours = Double(latestSession.totalSleepMinutes) / 60.0

        // Sleep efficiency is already calculated and stored
        let efficiency = Int(latestSession.sleepEfficiency.rounded())

        print(
            "GetLatestSleepForSummaryUseCase: ✅ Returning sleep data - \(String(format: "%.2f", sleepHours))h (\(latestSession.totalSleepMinutes) mins), \(efficiency)% efficiency"
        )

        return (
            sleepHours: sleepHours,
            efficiency: efficiency,
            lastSleepDate: latestSession.date
        )
    }
}

// MARK: - Errors

enum GetLatestSleepForSummaryError: Error, LocalizedError {
    case userNotAuthenticated
    case noSleepDataAvailable

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .noSleepDataAvailable:
            return "No sleep data available"
        }
    }
}
