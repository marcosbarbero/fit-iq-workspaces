//
//  DailyHealthKitProcessingUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 12/10/2025.
//

import BackgroundTasks  // Import BackgroundTasks for BGTaskIdentifier
import FitIQCore
import Foundation
import HealthKit

protocol HealthKitUseCaseProtocol {
    associatedtype T  // This is your generic type T
    func execute() async throws -> T  // Made throwable to align with HealthKit errors
}

public final class ScheduleDailyEnergyProcessingUseCase: HealthKitUseCaseProtocol {
    let backgroundOperations: BackgroundOperationsProtocol

    init(backgroundOperations: BackgroundOperationsProtocol) {
        self.backgroundOperations = backgroundOperations
    }

    // This use case now schedules the NEW ConsolidatedDailyHealthKitProcessingTaskID
    public func execute() async throws {
        // Request to run daily around midnight (delay of 1 minute past midnight)
        let calendar = Calendar.current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: Date())
        // Set to next midnight + 1 minute
        components.day = (components.day ?? 0) + 1
        components.hour = 0
        components.minute = 1
        components.second = 0

        guard let startDate = calendar.date(from: components) else {
            print("Failed to calculate startDate for consolidated daily health task.")
            throw HealthKitError.backgroundDeliveryFailed(
                "Failed to calculate schedule date for consolidated daily health task.")
        }

        do {
            try self.backgroundOperations.scheduleTask(
                forTaskWithIdentifier: ConsolidatedDailyHealthKitProcessingTaskID,  // NEW: Use the new ID
                earliestBeginDate: startDate,
                requiresNetworkConnectivity: true,
                requiresExternalPower: false
            )
            print("Scheduled consolidated daily health task for the next midnight (\(startDate)).")
        } catch {
            print("Could not schedule consolidated daily health task: \(error)")
            throw error
        }
    }
}

public final class GetLatestBodyMetricsUseCase: HealthKitUseCaseProtocol {
    let healthKitService: HealthKitServiceProtocol

    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }

    func execute() async throws -> HealthMetricsSnapshot {  // Now throwable
        // Note: dateOfBirth and biologicalSex are characteristics, not available via HealthDataType
        // These would need to be fetched differently or stored in user profile
        let dateOfBirth: Date? = nil
        let biologicalSexString: String? = nil

        let latestWeight = try? await healthKitService.queryLatest(type: .bodyMass)
        let latestHeight = try? await healthKitService.queryLatest(type: .height)
        // Note: BMI is not in FitIQCore HealthDataType - would need to be calculated or added
        let latestBMI: FitIQCore.HealthMetric? = nil

        return HealthMetricsSnapshot(
            date: Date(),
            weightKg: latestWeight?.value,
            heightCm: latestHeight != nil ? latestHeight!.value * 100 : nil,  // Convert meters to cm
            bmi: latestBMI?.value,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSexString
        )
    }
}

// NEW: Use case to fetch historical body mass data
public final class GetHistoricalBodyMassUseCase {
    let healthKitService: HealthKitServiceProtocol

    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }

    func execute(limit: Int = 5) async throws -> [HealthMetricsSnapshot] {
        // Fetch historical body mass samples from HealthKit via FitIQCore
        let startDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()

        let metrics = try await healthKitService.query(
            type: .bodyMass,
            from: startDate,
            to: Date(),
            options: HealthQueryOptions(
                limit: limit,
                sortOrder: .reverseChronological
            )
        )

        return metrics.map { metric in
            // For historical context, we only need weight and date here.
            HealthMetricsSnapshot(
                date: metric.date, weightKg: metric.value, heightCm: nil, bmi: nil,
                dateOfBirth: nil, biologicalSex: nil)
        }
    }
}

public final class UserHasHealthKitAuthorizationUseCase: HealthKitUseCaseProtocol {
    let authService: HealthAuthorizationServiceProtocol

    init(authService: HealthAuthorizationServiceProtocol) {
        self.authService = authService
    }

    func execute() async throws -> Bool {  // Now throwable
        return authService.isHealthKitAvailable()
    }

}
