// Domain/UseCases/ProcessConsolidatedDailyHealthDataUseCase.swift
import Foundation
import HealthKit

public final class ProcessConsolidatedDailyHealthDataUseCase: ProcessConsolidatedDailyHealthDataUseCaseProtocol {
    private let healthDataSyncService: HealthDataSyncOrchestrator
    private let authManager: AuthManager

    init(healthDataSyncService: HealthDataSyncOrchestrator, authManager: AuthManager) {
        self.healthDataSyncService = healthDataSyncService
        self.authManager = authManager
    }

    public func execute() async throws {
        print("ProcessConsolidatedDailyHealthDataUseCase: Executing consolidated daily health data processing for previous day.")

        guard let currentUserID = authManager.currentUserProfileID else {
            print("ProcessConsolidatedDailyHealthDataUseCase: No user profile ID is set. Skipping consolidated daily processing.")
            throw HealthKitError.unknownError("No user profile ID for consolidated daily processing")
        }

        // Configure the HealthDataSyncManager with the current user ID
        healthDataSyncService.configure(withUserProfileID: currentUserID)

        // Calculate "yesterday's" date (start of day)
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            print("ProcessConsolidatedDailyHealthDataUseCase: Could not determine yesterday's date.")
            throw HealthKitError.unknownError("Could not determine yesterday's date for consolidated daily processing")
        }
        let yesterdayStartOfDay = calendar.startOfDay(for: yesterday)

        print("ProcessConsolidatedDailyHealthDataUseCase: Finalizing activity data for previous day: \(yesterdayStartOfDay).")

        do {
            // Call the new method to finalize the previous day's data
            try await healthDataSyncService.finalizeDailyActivityData(for: yesterdayStartOfDay)
            print("ProcessConsolidatedDailyHealthDataUseCase: Consolidated daily health data finalization for \(yesterdayStartOfDay) complete.")
        } catch {
            print("ProcessConsolidatedDailyHealthDataUseCase: Error finalizing consolidated daily health data for \(yesterdayStartOfDay): \(error.localizedDescription)")
            throw error // Re-throw for background task handler
        }
    }
}
