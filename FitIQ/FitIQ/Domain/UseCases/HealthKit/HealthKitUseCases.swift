//
//  DailyHealthKitProcessingUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 12/10/2025.
//

import Foundation
import HealthKit
import BackgroundTasks // Import BackgroundTasks for BGTaskIdentifier

protocol HealthKitUseCaseProtocol {
    associatedtype T // This is your generic type T
    func execute() async throws -> T // Made throwable to align with HealthKit errors
}

public final class ScheduleDailyEnergyProcessingUseCase: HealthKitUseCaseProtocol {
    let backgroundOperations: BackgroundOperationsProtocol
    
    init(backgroundOperations: BackgroundOperationsProtocol) {
        self.backgroundOperations = backgroundOperations
    }
    
    // This use case now schedules the NEW ConsolidatedDailyHealthKitProcessingTaskID
    public func execute() async throws -> Void {
        // Request to run daily around midnight (delay of 1 minute past midnight)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        // Set to next midnight + 1 minute
        components.day = (components.day ?? 0) + 1
        components.hour = 0
        components.minute = 1
        components.second = 0
        
        guard let startDate = calendar.date(from: components) else {
            print("Failed to calculate startDate for consolidated daily health task.")
            throw HealthKitError.backgroundDeliveryFailed("Failed to calculate schedule date for consolidated daily health task.")
        }
        
        do {
            try self.backgroundOperations.scheduleTask(
                forTaskWithIdentifier: ConsolidatedDailyHealthKitProcessingTaskID, // NEW: Use the new ID
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
    let healthRepository: HealthRepositoryProtocol
    
    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }
    
    func execute() async throws -> HealthMetricsSnapshot { // Now throwable
        let dateOfBirth = try? await healthRepository.fetchDateOfBirth()
        let biologicalSex = try? await healthRepository.fetchBiologicalSex()
        let biologicalSexString = biologicalSex?.hkSexToString()

        let latestWeight = try? await healthRepository.fetchLatestQuantitySample(for: .bodyMass, unit: .gramUnit(with: .kilo))
        let latestHeight = try? await healthRepository.fetchLatestQuantitySample(for: .height, unit: .meterUnit(with: .centi))
        let latestBMI = try? await healthRepository.fetchLatestQuantitySample(for: .bodyMassIndex, unit: .count())

        return  HealthMetricsSnapshot(
            date: Date(),
            weightKg: latestWeight?.value,
            heightCm: latestHeight?.value,
            bmi: latestBMI?.value,
            dateOfBirth: dateOfBirth,
            biologicalSex: biologicalSexString
        )
    }
}

// NEW: Use case to fetch historical body mass data
public final class GetHistoricalBodyMassUseCase {
    let healthRepository: HealthRepositoryProtocol
    
    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }
    
    func execute(limit: Int = 5) async throws -> [HealthMetricsSnapshot] {
        // This method assumes the HealthRepositoryProtocol has a method
        // to fetch multiple quantity samples.
        // E.g., func fetchQuantitySamples(for type: HKQuantityTypeIdentifier, unit: HKUnit, limit: Int, predicateProvider: ((Date, Date) -> NSPredicate)?) async throws -> [(value: Double, date: Date)]
        
        // This call will require a new method on HealthRepositoryProtocol (e.g., HealthKitAdapter)
        // We pass nil for predicateProvider to fetch the latest 'limit' samples generally.
        let samples = try await healthRepository.fetchQuantitySamples(for: .bodyMass, unit: .gramUnit(with: .kilo), predicateProvider: nil, limit: limit)
        
        return samples.map { value, date in
            // For historical context, we only need weight and date here.
            HealthMetricsSnapshot(date: date, weightKg: value, heightCm: nil, bmi: nil, dateOfBirth: nil, biologicalSex: nil)
        }
    }
}

public final class UserHasHealthKitAuthorizationUseCase: HealthKitUseCaseProtocol {
    let healthRepository: HealthRepositoryProtocol
    
    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }
    
    func execute() async throws -> Bool { // Now throwable
        return healthRepository.isHealthDataAvailable()
    }

}

