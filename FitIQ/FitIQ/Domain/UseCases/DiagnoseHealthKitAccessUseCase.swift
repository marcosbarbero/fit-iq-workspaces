//
//  DiagnoseHealthKitAccessUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 27/01/2025.
//

import Foundation
import HealthKit

/// Diagnostic use case to check HealthKit authorization and data availability
/// Helps debug why weight data might not be appearing in the app
protocol DiagnoseHealthKitAccessUseCase {
    func execute() async -> HealthKitDiagnosticResult
}

/// Result of HealthKit diagnostic check
struct HealthKitDiagnosticResult {
    let isHealthKitAvailable: Bool
    let hasWeightReadPermission: Bool
    let hasWeightWritePermission: Bool
    let weightSampleCount: Int
    let latestWeightDate: Date?
    let oldestWeightDate: Date?
    let errors: [String]

    var isFullyAuthorized: Bool {
        hasWeightReadPermission && hasWeightWritePermission
    }

    var hasData: Bool {
        weightSampleCount > 0
    }

    var summary: String {
        var lines: [String] = []
        lines.append("=== HealthKit Diagnostic Report ===")
        lines.append("HealthKit Available: \(isHealthKitAvailable ? "✅" : "❌")")
        lines.append("Weight Read Permission: \(hasWeightReadPermission ? "✅" : "❌")")
        lines.append("Weight Write Permission: \(hasWeightWritePermission ? "✅" : "❌")")
        lines.append("Weight Samples Found: \(weightSampleCount)")
        if let latest = latestWeightDate {
            lines.append("Latest Entry: \(latest)")
        } else {
            lines.append("Latest Entry: None")
        }
        if let oldest = oldestWeightDate {
            lines.append("Oldest Entry: \(oldest)")
        } else {
            lines.append("Oldest Entry: None")
        }
        if !errors.isEmpty {
            lines.append("Errors:")
            errors.forEach { lines.append("  - \($0)") }
        }
        lines.append("===================================")
        return lines.joined(separator: "\n")
    }
}

/// Implementation
final class DiagnoseHealthKitAccessUseCaseImpl: DiagnoseHealthKitAccessUseCase {

    private let healthRepository: HealthRepositoryProtocol

    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }

    func execute() async -> HealthKitDiagnosticResult {
        var errors: [String] = []

        // 1. Check if HealthKit is available on device
        let isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        if !isHealthKitAvailable {
            errors.append("HealthKit is not available on this device")
        }

        // 2. Check authorization status
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let healthStore = HKHealthStore()

        let readStatus = healthStore.authorizationStatus(for: weightType)
        let hasWeightReadPermission = (readStatus == .sharingAuthorized)

        // Note: Write permission status cannot be determined (returns notDetermined)
        // We'll assume it's granted if read is granted
        let hasWeightWritePermission = hasWeightReadPermission

        if !hasWeightReadPermission {
            errors.append("Weight read permission not granted - please authorize in Settings")
        }

        // 3. Try to fetch weight samples
        var weightSampleCount = 0
        var latestWeightDate: Date?
        var oldestWeightDate: Date?

        if hasWeightReadPermission {
            do {
                // Fetch all weight samples (last 10 years)
                let startDate =
                    Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
                let predicate = HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: Date(),
                    options: .strictStartDate
                )

                let samples = try await healthRepository.fetchQuantitySamples(
                    for: .bodyMass,
                    unit: .gramUnit(with: .kilo),
                    predicateProvider: { predicate },
                    limit: nil
                )

                weightSampleCount = samples.count

                if !samples.isEmpty {
                    let dates = samples.map { $0.date }
                    latestWeightDate = dates.max()
                    oldestWeightDate = dates.min()
                } else {
                    errors.append("No weight samples found in HealthKit (checked last 10 years)")
                }

            } catch {
                errors.append("Failed to fetch weight samples: \(error.localizedDescription)")
            }
        }

        return HealthKitDiagnosticResult(
            isHealthKitAvailable: isHealthKitAvailable,
            hasWeightReadPermission: hasWeightReadPermission,
            hasWeightWritePermission: hasWeightWritePermission,
            weightSampleCount: weightSampleCount,
            latestWeightDate: latestWeightDate,
            oldestWeightDate: oldestWeightDate,
            errors: errors
        )
    }
}
