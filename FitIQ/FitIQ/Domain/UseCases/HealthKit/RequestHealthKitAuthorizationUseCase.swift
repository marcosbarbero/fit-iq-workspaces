//
//  RequestHealthKitAuthorizationUseCase.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import FitIQCore
import Foundation
import HealthKit

// Make the protocol public for broader access within the module
public protocol RequestHealthKitAuthorizationUseCase {
    func execute() async throws
}

final class HealthKitAuthorizationUseCase: RequestHealthKitAuthorizationUseCase {
    private let authService: HealthAuthorizationServiceProtocol

    init(authService: HealthAuthorizationServiceProtocol) {
        self.authService = authService
    }

    func execute() async throws {
        // Define types to write to HealthKit (only types that map to HKSampleType)
        let typesToWrite: Set<HealthDataType> = [
            .workout(.running),  // Use a default workout type for general workout permission
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .stepCount,
            .heartRate,
            .bodyMass,
            .height,
            .mindfulSession,
        ]

        // Define types to read from HealthKit
        let typesToRead: Set<HealthDataType> = [
            .workout(.running),  // Use a default workout type for general workout permission
            .activeEnergyBurned,
            .basalEnergyBurned,
            .distanceWalkingRunning,
            .stepCount,
            .heartRate,
            .bodyMass,
            .height,
            .sleepAnalysis,
            .mindfulSession,
            .exerciseTime,
            .heartRateVariability,
            .oxygenSaturation,
            .respiratoryRate,
        ]

        print(
            "HealthKitAuthorizationUseCase: 📋 Requesting authorization for \(typesToRead.count) read types (FitIQCore)"
        )

        do {
            // Create authorization scope
            let scope = HealthAuthorizationScope(
                read: typesToRead,
                write: typesToWrite
            )

            // Request authorization using FitIQCore API
            try await authService.requestAuthorization(scope: scope)
            print("✅ HealthKit Authorization successful (FitIQCore).")
        } catch {
            print("❌ HealthKit Authorization failed: \(error.localizedDescription)")
            throw error
        }
    }
}
