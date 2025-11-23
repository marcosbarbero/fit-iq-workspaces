//
//  GetLatestHeartRateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//  Purpose: Fetch latest heart rate DIRECTLY from HealthKit (not Progress DB)
//
//  UPDATED: 2025-01-27 - Changed to fetch from HealthKit for real-time updates with exact timestamps
//

import FitIQCore
import Foundation
import HealthKit

/// Protocol defining the contract for fetching latest heart rate
///
/// **Purpose:** Get real-time heart rate with exact timestamp for summary card display
/// **Data Source:** HealthKit (not Progress DB) - ensures real-time updates
///
/// **Why HealthKit Direct:**
/// - Progress DB stores hourly aggregates (timestamps rounded to hour)
/// - HealthKit has individual samples with exact timestamps
/// - Summary card needs real-time updates, not hourly updates
///
/// **Flow:**
/// 1. Fetch latest individual heart rate sample from HealthKit
/// 2. Return with exact timestamp for display: "78 BPM at 6:12"
protocol GetLatestHeartRateUseCase {
    /// Fetches the most recent heart rate sample directly from HealthKit
    /// - Parameter daysBack: Number of days to look back (default: 7)
    /// - Returns: Tuple with (heart rate BPM, exact timestamp), or nil if no data
    func execute(daysBack: Int) async throws -> (heartRate: Double, timestamp: Date)?
}

/// Implementation of GetLatestHeartRateUseCase
final class GetLatestHeartRateUseCaseImpl: GetLatestHeartRateUseCase {

    // MARK: - Dependencies

    private let healthKitService: HealthKitServiceProtocol
    private let authManager: AuthManager

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        authManager: AuthManager
    ) {
        self.healthKitService = healthKitService
        self.authManager = authManager
    }

    // MARK: - Execute

    func execute(daysBack: Int = 7) async throws -> (heartRate: Double, timestamp: Date)? {
        // Verify user is authenticated
        guard authManager.currentUserProfileID != nil else {
            throw GetLatestHeartRateError.userNotAuthenticated
        }

        print(
            "GetLatestHeartRateUseCase: 🔍 REAL-TIME - Fetching latest heart rate from HealthKit (FitIQCore)"
        )

        // Fetch the single most recent heart rate sample directly from HealthKit via FitIQCore
        let metric = try await healthKitService.queryLatest(type: .heartRate)

        guard let result = metric else {
            print("GetLatestHeartRateUseCase: ⚠️ No heart rate samples found in HealthKit")
            return nil
        }

        // Check if sample is within the lookback period
        if daysBack > 0 {
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()

            if result.date < cutoffDate {
                print("GetLatestHeartRateUseCase: ⚠️ Latest sample is older than \(daysBack) days")
                return nil
            }
        }

        let timeString = result.date.formattedHourMinute()

        print(
            "GetLatestHeartRateUseCase: ✅ Latest heart rate: \(Int(result.value)) bpm at \(timeString) (exact timestamp from HealthKit via FitIQCore)"
        )

        return (heartRate: result.value, timestamp: result.date)
    }
}

// MARK: - Errors

enum GetLatestHeartRateError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to fetch heart rate data"
        }
    }
}
