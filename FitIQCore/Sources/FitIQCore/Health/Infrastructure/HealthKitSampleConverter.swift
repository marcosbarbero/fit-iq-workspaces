//
//  HealthKitSampleConverter.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation
import HealthKit

/// Converts between domain HealthMetric models and HealthKit samples
///
/// This converter provides bidirectional conversion between our domain model
/// (`HealthMetric`) and Apple's HealthKit sample types (`HKQuantitySample`,
/// `HKCategorySample`, `HKWorkout`).
///
/// **Usage:**
/// ```swift
/// // Domain → HealthKit
/// let metric = HealthMetric.quantity(type: .stepCount, value: 10000, unit: "steps")
/// let sample = try HealthKitSampleConverter.toHKSample(metric)
/// // Returns: HKQuantitySample for step count
///
/// // HealthKit → Domain
/// if let hkSample = sample as? HKQuantitySample {
///     let metric = try HealthKitSampleConverter.fromHKSample(hkSample)
///     print(metric.value) // 10000
/// }
/// ```
///
/// **Architecture:** FitIQCore - Infrastructure Layer (Hexagonal Architecture)
///
/// **Platform:** iOS, watchOS, macOS (Catalyst)
@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
public enum HealthKitSampleConverter {

    // MARK: - Domain → HealthKit Conversion

    /// Converts a HealthMetric to an appropriate HKSample
    ///
    /// - Parameters:
    ///   - metric: Domain health metric
    ///   - unitSystem: User's preferred unit system (defaults to metric)
    /// - Returns: HKSample (HKQuantitySample, HKCategorySample, or HKWorkout)
    /// - Throws: `HealthKitError.invalidData` if conversion fails
    public static func toHKSample(
        _ metric: HealthMetric,
        unitSystem: HealthKitTypeMapper.UnitSystem = .metric
    ) throws -> HKSample {
        // Validate metric first
        let errors = metric.validate()
        guard errors.isEmpty else {
            throw HealthKitError.invalidData(
                reason: errors.first?.localizedDescription ?? "Invalid metric")
        }

        switch metric.type {
        case .sleepAnalysis, .mindfulSession:
            return try toCategorySample(metric)
        case .workout:
            return try toWorkout(metric, unitSystem: unitSystem)
        default:
            return try toQuantitySample(metric, unitSystem: unitSystem)
        }
    }

    /// Converts a HealthMetric to HKQuantitySample
    private static func toQuantitySample(
        _ metric: HealthMetric,
        unitSystem: HealthKitTypeMapper.UnitSystem
    ) throws -> HKQuantitySample {
        guard metric.type.isQuantityType else {
            throw HealthKitError.invalidData(reason: "\(metric.type) is not a quantity type")
        }

        // Get HealthKit type
        guard let quantityType = try? HealthKitTypeMapper.toHKType(metric.type) as? HKQuantityType
        else {
            throw HealthKitError.typeNotAvailable(metric.type)
        }

        // Get unit - use metric's unit or default
        let unit: HKUnit
        if let hkUnit = HealthKitTypeMapper.hkUnit(from: metric.unit) {
            unit = hkUnit
        } else {
            unit = HealthKitTypeMapper.defaultUnit(for: metric.type, unitSystem: unitSystem)
        }

        // Create quantity
        let quantity = HKQuantity(unit: unit, doubleValue: metric.value)

        // Create metadata
        var metadata: [String: Any] = [:]
        for (key, value) in metric.metadata {
            metadata[key] = value
        }
        if let source = metric.source {
            metadata[HKMetadataKeyExternalUUID] = metric.id.uuidString
            // Note: Can't set source name directly in metadata, that's set via HKSourceRevision
        }

        // Create sample
        let sample = HKQuantitySample(
            type: quantityType,
            quantity: quantity,
            start: metric.startDate ?? metric.date,
            end: metric.endDate ?? metric.date,
            metadata: metadata.isEmpty ? nil : metadata
        )

        return sample
    }

    /// Converts a HealthMetric to HKCategorySample
    private static func toCategorySample(_ metric: HealthMetric) throws -> HKCategorySample {
        guard metric.type.isCategoryType else {
            throw HealthKitError.invalidData(reason: "\(metric.type) is not a category type")
        }

        // Get HealthKit type
        guard let categoryType = try? HealthKitTypeMapper.toHKType(metric.type) as? HKCategoryType
        else {
            throw HealthKitError.typeNotAvailable(metric.type)
        }

        // Category value (integer)
        let categoryValue = Int(metric.value)

        // Create metadata
        var metadata: [String: Any] = [:]
        for (key, value) in metric.metadata {
            metadata[key] = value
        }
        if let source = metric.source {
            metadata[HKMetadataKeyExternalUUID] = metric.id.uuidString
        }

        // Must have start and end dates for category samples
        guard let startDate = metric.startDate, let endDate = metric.endDate else {
            throw HealthKitError.invalidData(reason: "Category samples require start and end dates")
        }

        // Create sample
        let sample = HKCategorySample(
            type: categoryType,
            value: categoryValue,
            start: startDate,
            end: endDate,
            metadata: metadata.isEmpty ? nil : metadata
        )

        return sample
    }

    /// Converts a HealthMetric to HKWorkout
    private static func toWorkout(
        _ metric: HealthMetric,
        unitSystem: HealthKitTypeMapper.UnitSystem
    ) throws -> HKWorkout {
        guard case .workout(let workoutType) = metric.type else {
            throw HealthKitError.invalidData(reason: "Metric is not a workout type")
        }

        // Must have start and end dates for workouts
        guard let startDate = metric.startDate, let endDate = metric.endDate else {
            throw HealthKitError.invalidData(reason: "Workouts require start and end dates")
        }

        // Get workout activity type
        let activityType = HealthKitTypeMapper.toHKWorkoutActivityType(workoutType)

        // Duration
        let duration = endDate.timeIntervalSince(startDate)

        // Total energy (if value represents calories)
        let totalEnergy: HKQuantity?
        if metric.unit.lowercased().contains("kcal") || metric.unit.lowercased().contains("cal") {
            totalEnergy = HKQuantity(unit: .kilocalorie(), doubleValue: metric.value)
        } else {
            totalEnergy = nil
        }

        // Create metadata
        var metadata: [String: Any] = [:]
        for (key, value) in metric.metadata {
            metadata[key] = value
        }
        if let source = metric.source {
            metadata[HKMetadataKeyExternalUUID] = metric.id.uuidString
        }

        // Create workout
        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: totalEnergy,
            totalDistance: nil,  // Can be enhanced later if needed
            metadata: metadata.isEmpty ? nil : metadata
        )

        return workout
    }

    // MARK: - HealthKit → Domain Conversion

    /// Converts an HKSample to a HealthMetric
    ///
    /// - Parameters:
    ///   - sample: HealthKit sample
    ///   - unitSystem: User's preferred unit system (defaults to metric)
    /// - Returns: Domain health metric
    /// - Throws: `HealthKitError.invalidData` if conversion fails
    public static func fromHKSample(
        _ sample: HKSample,
        unitSystem: HealthKitTypeMapper.UnitSystem = .metric
    ) throws -> HealthMetric {
        if let quantitySample = sample as? HKQuantitySample {
            return try fromQuantitySample(quantitySample, unitSystem: unitSystem)
        } else if let categorySample = sample as? HKCategorySample {
            return try fromCategorySample(categorySample)
        } else if let workout = sample as? HKWorkout {
            return try fromWorkout(workout, unitSystem: unitSystem)
        } else {
            throw HealthKitError.invalidData(
                reason: "Unsupported HKSample type: \(type(of: sample))")
        }
    }

    /// Converts an HKQuantitySample to HealthMetric
    private static func fromQuantitySample(
        _ sample: HKQuantitySample,
        unitSystem: HealthKitTypeMapper.UnitSystem
    ) throws -> HealthMetric {
        // Get domain type
        guard let domainType = HealthKitTypeMapper.fromHKType(sample.quantityType) else {
            throw HealthKitError.invalidData(
                reason: "Unknown quantity type: \(sample.quantityType.identifier)")
        }

        // Get unit and value
        let unit = HealthKitTypeMapper.defaultUnit(for: domainType, unitSystem: unitSystem)
        let value = sample.quantity.doubleValue(for: unit)
        let unitString = HealthKitTypeMapper.unitString(for: domainType, unitSystem: unitSystem)

        // Extract metadata
        var metadataDict: [String: String] = [:]
        if let metadata = sample.metadata {
            for (key, value) in metadata {
                metadataDict[key] = "\(value)"
            }
        }

        // Extract source
        let source = sample.sourceRevision.source.name

        // Extract device
        let device = sample.device?.name

        // Determine if duration-based
        let isDuration = sample.startDate != sample.endDate
        let startDate = isDuration ? sample.startDate : nil
        let endDate = isDuration ? sample.endDate : nil

        // Create metric
        return HealthMetric(
            id: extractUUID(from: sample) ?? UUID(),
            type: domainType,
            value: value,
            unit: unitString,
            date: sample.endDate,
            startDate: startDate,
            endDate: endDate,
            source: source,
            device: device,
            metadata: metadataDict
        )
    }

    /// Converts an HKCategorySample to HealthMetric
    private static func fromCategorySample(_ sample: HKCategorySample) throws -> HealthMetric {
        // Get domain type
        guard let domainType = HealthKitTypeMapper.fromHKType(sample.categoryType) else {
            throw HealthKitError.invalidData(
                reason: "Unknown category type: \(sample.categoryType.identifier)")
        }

        // Category value
        let value = Double(sample.value)

        // Unit
        let unitString = HealthKitTypeMapper.unitString(for: domainType)

        // Extract metadata
        var metadataDict: [String: String] = [:]
        if let metadata = sample.metadata {
            for (key, value) in metadata {
                metadataDict[key] = "\(value)"
            }
        }

        // Extract source
        let source = sample.sourceRevision.source.name

        // Extract device
        let device = sample.device?.name

        // Create metric (category samples always have duration)
        return HealthMetric(
            id: extractUUID(from: sample) ?? UUID(),
            type: domainType,
            value: value,
            unit: unitString,
            date: sample.endDate,
            startDate: sample.startDate,
            endDate: sample.endDate,
            source: source,
            device: device,
            metadata: metadataDict
        )
    }

    /// Converts an HKWorkout to HealthMetric
    private static func fromWorkout(
        _ workout: HKWorkout,
        unitSystem: HealthKitTypeMapper.UnitSystem
    ) throws -> HealthMetric {
        // Get workout type
        let workoutType = HealthKitTypeMapper.fromHKWorkoutActivityType(workout.workoutActivityType)
        let domainType = HealthDataType.workout(workoutType)

        // Value (calories burned)
        let value: Double
        let unit: String
        if let totalEnergy = workout.totalEnergyBurned {
            value = totalEnergy.doubleValue(for: .kilocalorie())
            unit = "kcal"
        } else {
            // Use duration in minutes as fallback
            value = workout.duration / 60.0
            unit = "min"
        }

        // Extract metadata
        var metadataDict: [String: String] = [:]
        if let metadata = workout.metadata {
            for (key, value) in metadata {
                metadataDict[key] = "\(value)"
            }
        }

        // Add workout-specific metadata
        if let distance = workout.totalDistance {
            let distanceValue = distance.doubleValue(
                for: unitSystem == .metric ? .meter() : .mile())
            metadataDict["totalDistance"] = "\(distanceValue)"
            metadataDict["distanceUnit"] = unitSystem == .metric ? "m" : "mi"
        }

        // Extract source
        let source = workout.sourceRevision.source.name

        // Extract device
        let device = workout.device?.name

        // Create metric
        return HealthMetric(
            id: extractUUID(from: workout) ?? UUID(),
            type: domainType,
            value: value,
            unit: unit,
            date: workout.endDate,
            startDate: workout.startDate,
            endDate: workout.endDate,
            source: source,
            device: device,
            metadata: metadataDict
        )
    }

    // MARK: - Batch Conversion

    /// Converts multiple HealthMetrics to HKSamples
    ///
    /// - Parameters:
    ///   - metrics: Array of health metrics
    ///   - unitSystem: User's preferred unit system
    /// - Returns: Array of HKSamples
    /// - Throws: `HealthKitError.invalidData` if any conversion fails
    public static func toHKSamples(
        _ metrics: [HealthMetric],
        unitSystem: HealthKitTypeMapper.UnitSystem = .metric
    ) throws -> [HKSample] {
        try metrics.map { try toHKSample($0, unitSystem: unitSystem) }
    }

    /// Converts multiple HKSamples to HealthMetrics
    ///
    /// - Parameters:
    ///   - samples: Array of HealthKit samples
    ///   - unitSystem: User's preferred unit system
    /// - Returns: Array of health metrics
    /// - Throws: `HealthKitError.invalidData` if any conversion fails
    public static func fromHKSamples(
        _ samples: [HKSample],
        unitSystem: HealthKitTypeMapper.UnitSystem = .metric
    ) throws -> [HealthMetric] {
        try samples.map { try fromHKSample($0, unitSystem: unitSystem) }
    }

    // MARK: - Helpers

    /// Extracts UUID from sample metadata
    private static func extractUUID(from sample: HKSample) -> UUID? {
        guard let metadata = sample.metadata,
            let uuidString = metadata[HKMetadataKeyExternalUUID] as? String,
            let uuid = UUID(uuidString: uuidString)
        else {
            return nil
        }
        return uuid
    }
}

// MARK: - HealthMetric Extensions

@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
extension HealthMetric {
    /// Converts this metric to an HKSample
    ///
    /// - Parameter unitSystem: User's preferred unit system (defaults to metric)
    /// - Returns: HKSample (HKQuantitySample, HKCategorySample, or HKWorkout)
    /// - Throws: `HealthKitError.invalidData` if conversion fails
    public func toHKSample(unitSystem: HealthKitTypeMapper.UnitSystem = .metric) throws -> HKSample
    {
        try HealthKitSampleConverter.toHKSample(self, unitSystem: unitSystem)
    }
}

// MARK: - HKSample Extensions

@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
extension HKSample {
    /// Converts this HealthKit sample to a HealthMetric
    ///
    /// - Parameter unitSystem: User's preferred unit system (defaults to metric)
    /// - Returns: Domain health metric
    /// - Throws: `HealthKitError.invalidData` if conversion fails
    public func toHealthMetric(unitSystem: HealthKitTypeMapper.UnitSystem = .metric) throws
        -> HealthMetric
    {
        try HealthKitSampleConverter.fromHKSample(self, unitSystem: unitSystem)
    }
}
