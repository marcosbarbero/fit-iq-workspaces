//
//  RequestHealthKitAuthorizationUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import HealthKit

// Make the protocol public for broader access within the module
public protocol RequestHealthKitAuthorizationUseCase {
    func execute() async throws
}

final class HealthKitAuthorizationUseCase: RequestHealthKitAuthorizationUseCase {
    private let healthRepository: HealthRepositoryProtocol

    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }

    func execute() async throws {
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(
                forIdentifier: .distanceWalkingRunning
            )!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .height)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKCategoryType.categoryType(forIdentifier: .moodChanges)!,
        ]

        var typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(
                forIdentifier: .distanceWalkingRunning
            )!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .height)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKCategoryType.categoryType(forIdentifier: .mindfulSession)!,
            HKCategoryType.categoryType(forIdentifier: .moodChanges)!,
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
        ]

        // Add workout effort score for iOS 18+
        if #available(iOS 18.0, *) {
            print(
                "HealthKitAuthorizationUseCase: ✅ iOS 18+ detected - adding workout effort score authorization"
            )
            if let effortScoreType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore)
            {
                typesToRead.insert(effortScoreType)
                print(
                    "HealthKitAuthorizationUseCase: ✅ Workout effort score type added to authorization request"
                )
            } else {
                print(
                    "HealthKitAuthorizationUseCase: ⚠️ Workout effort score type not available (API issue)"
                )
            }
        } else {
            print("HealthKitAuthorizationUseCase: ℹ️ iOS < 18 - workout effort score not available")
        }

        print(
            "HealthKitAuthorizationUseCase: 📋 Requesting authorization for \(typesToRead.count) read types"
        )

        do {
            try await healthRepository.requestAuthorization(
                read: typesToRead,
                share: typesToShare
            )
            print("✅ HealthKit Authorization successful.")

            // Verify effort score authorization status (iOS 18+)
            if #available(iOS 18.0, *) {
                if let effortScoreType = HKQuantityType.quantityType(
                    forIdentifier: .workoutEffortScore)
                {
                    let status = healthRepository.authorizationStatus(for: effortScoreType)
                    print(
                        "HealthKitAuthorizationUseCase: 🔍 Workout effort score authorization status: \(status)"
                    )
                }
            }
        } catch {
            print("❌ HealthKit Authorization failed: \(error.localizedDescription)")
            throw error
        }
    }
}
