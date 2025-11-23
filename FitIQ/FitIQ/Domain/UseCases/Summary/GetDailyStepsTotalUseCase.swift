//
//  GetDailyStepsTotalUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-01.
//  Purpose: Fetch total steps for a specific day DIRECTLY from HealthKit (not Progress DB)
//
//  UPDATED: 2025-01-27 - Changed to fetch from HealthKit for real-time updates with exact timestamps
//

import FitIQCore
import Foundation
import HealthKit

// MARK: - Protocol (Port)

/// Result type containing both total steps and latest timestamp
struct DailyStepsResult {
    let totalSteps: Int
    let latestTimestamp: Date?
}

/// Use case for fetching the total steps for a specific day DIRECTLY from HealthKit
///
/// **Purpose:** Get real-time steps count and exact timestamp for summary card display
/// **Data Source:** HealthKit (not Progress DB) - ensures real-time updates
///
/// **Why HealthKit Direct:**
/// - Progress DB stores hourly aggregates (timestamps rounded to hour)
/// - HealthKit has individual samples with exact timestamps
/// - Summary card needs real-time updates, not hourly updates
///
/// **Flow:**
/// 1. Fetch sum of all steps for the day from HealthKit
/// 2. Fetch latest individual sample to get exact timestamp
/// 3. Return both for display: "1,234 steps at 6:12"
protocol GetDailyStepsTotalUseCase {
    /// Execute the use case to fetch total steps for a given date
    /// - Parameter date: The date to fetch steps for (defaults to today)
    /// - Returns: DailyStepsResult containing total steps and latest timestamp
    func execute(forDate date: Date) async throws -> DailyStepsResult
}

// MARK: - Implementation

final class GetDailyStepsTotalUseCaseImpl: GetDailyStepsTotalUseCase {

    private let healthKitService: HealthKitServiceProtocol
    private let authManager: AuthManager

    init(healthKitService: HealthKitServiceProtocol, authManager: AuthManager) {
        self.healthKitService = healthKitService
        self.authManager = authManager
    }

    func execute(forDate date: Date = Date()) async throws -> DailyStepsResult {
        // Verify user is authenticated
        guard authManager.currentUserProfileID != nil else {
            throw GetDailyStepsTotalError.userNotAuthenticated
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        print("================================================================================")
        print("GetDailyStepsTotalUseCase: 🔍 REAL-TIME - Fetching steps from HealthKit (FitIQCore)")
        print("  Start: \(startOfDay)")
        print("  End:   \(endOfDay)")
        print("--------------------------------------------------------------------------------")

        // 1. Fetch total steps for the day from HealthKit via FitIQCore
        let stats = try await healthKitService.queryStatistics(
            type: .stepCount,
            from: startOfDay,
            to: endOfDay,
            options: HealthQueryOptions(
                aggregation: .sum(.daily)
            )
        )

        let totalSteps = Int(stats.sum ?? 0)

        // 2. Fetch latest individual sample to get exact timestamp
        let latestMetric = try await healthKitService.queryLatest(type: .stepCount)

        // Ensure the latest sample is from today
        let latestTimestamp: Date?
        if let metric = latestMetric {
            if calendar.isDate(metric.date, inSameDayAs: date) {
                latestTimestamp = metric.date
            } else {
                // Latest sample is from a different day
                latestTimestamp = nil
            }
        } else {
            latestTimestamp = nil
        }

        print("--------------------------------------------------------------------------------")
        print("GetDailyStepsTotalUseCase: ✅ TOTAL: \(totalSteps) steps (FitIQCore)")
        if let latest = latestTimestamp {
            print(
                "GetDailyStepsTotalUseCase: ✅ Latest sample at: \(latest.formattedHourMinute()) (exact timestamp from HealthKit via FitIQCore)"
            )
        } else {
            print("GetDailyStepsTotalUseCase: ⚠️ No steps recorded today yet")
        }
        print("================================================================================")

        return DailyStepsResult(totalSteps: totalSteps, latestTimestamp: latestTimestamp)
    }
}

// MARK: - Errors

enum GetDailyStepsTotalError: Error, LocalizedError {
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        }
    }
}
