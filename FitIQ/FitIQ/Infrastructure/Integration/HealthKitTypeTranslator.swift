//
//  HealthKitTypeTranslator.swift
//  FitIQ
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2 Day 6: HealthKit Migration to FitIQCore
//

import FitIQCore
import Foundation
import HealthKit

/// Comprehensive translation utilities for mapping between HealthKit types and FitIQCore types
///
/// **Purpose:**
/// This utility provides bidirectional mapping between:
/// - HKQuantityTypeIdentifier ↔ HealthDataType
/// - HKCategoryTypeIdentifier ↔ HealthDataType
/// - HKWorkoutActivityType ↔ WorkoutType
/// - HKUnit ↔ FitIQCore unit strings
///
/// **Usage:**
/// ```swift
/// // HK → FitIQCore
/// let healthDataType = HealthKitTypeTranslator.toHealthDataType(.stepCount)
///
/// // FitIQCore → HK
/// let hkIdentifier = HealthKitTypeTranslator.toHKQuantityTypeIdentifier(.stepCount)
///
/// // Unit conversion
/// let hkUnit = HealthKitTypeTranslator.toHKUnit("kg", for: .bodyMass)
/// ```
///
/// **Thread Safety:** All methods are static and thread-safe
enum HealthKitTypeTranslator {

    // MARK: - HKQuantityTypeIdentifier → HealthDataType

    /// Converts HKQuantityTypeIdentifier to FitIQCore HealthDataType
    static func toHealthDataType(_ identifier: HKQuantityTypeIdentifier) -> HealthDataType? {
        switch identifier {
        // Body Measurements
        case .bodyMass: return .bodyMass
        case .height: return .height

        // Fitness - Steps & Distance
        case .stepCount: return .stepCount
        case .distanceWalkingRunning: return .distanceWalkingRunning
        case .flightsClimbed: return .flightsClimbed

        // Fitness - Energy
        case .activeEnergyBurned: return .activeEnergyBurned
        case .basalEnergyBurned: return .basalEnergyBurned
        case .appleExerciseTime: return .exerciseTime
        case .appleStandTime: return .standTime

        // Heart & Cardiovascular
        case .heartRate: return .heartRate
        case .heartRateVariabilitySDNN: return .heartRateVariability

        // Respiratory
        case .oxygenSaturation: return .oxygenSaturation
        case .respiratoryRate: return .respiratoryRate

        default:
            print(
                "⚠️ HealthKitTypeTranslator: Unmapped HKQuantityTypeIdentifier: \(identifier.rawValue)"
            )
            return nil
        }
    }

    // MARK: - HealthDataType → HKQuantityTypeIdentifier

    /// Converts FitIQCore HealthDataType to HKQuantityTypeIdentifier
    static func toHKQuantityTypeIdentifier(_ type: HealthDataType) -> HKQuantityTypeIdentifier? {
        switch type {
        // Body Measurements
        case .bodyMass: return .bodyMass
        case .height: return .height

        // Fitness - Steps & Distance
        case .stepCount: return .stepCount
        case .distanceWalkingRunning: return .distanceWalkingRunning
        case .flightsClimbed: return .flightsClimbed

        // Fitness - Energy
        case .activeEnergyBurned: return .activeEnergyBurned
        case .basalEnergyBurned: return .basalEnergyBurned
        case .exerciseTime: return .appleExerciseTime
        case .standTime: return .appleStandTime

        // Heart & Cardiovascular
        case .heartRate: return .heartRate
        case .heartRateVariability: return .heartRateVariabilitySDNN

        // Respiratory
        case .oxygenSaturation: return .oxygenSaturation
        case .respiratoryRate: return .respiratoryRate

        // Categories (not quantity types)
        case .sleepAnalysis, .mindfulSession:
            return nil

        // Workouts (not quantity types)
        case .workout:
            return nil
        }
    }

    // MARK: - HKCategoryTypeIdentifier → HealthDataType

    /// Converts HKCategoryTypeIdentifier to FitIQCore HealthDataType
    static func toHealthDataType(_ identifier: HKCategoryTypeIdentifier) -> HealthDataType? {
        switch identifier {
        case .sleepAnalysis: return .sleepAnalysis
        case .mindfulSession: return .mindfulSession
        default:
            print(
                "⚠️ HealthKitTypeTranslator: Unmapped HKCategoryTypeIdentifier: \(identifier.rawValue)"
            )
            return nil
        }
    }

    // MARK: - HealthDataType → HKCategoryTypeIdentifier

    /// Converts FitIQCore HealthDataType to HKCategoryTypeIdentifier
    static func toHKCategoryTypeIdentifier(_ type: HealthDataType) -> HKCategoryTypeIdentifier? {
        switch type {
        case .sleepAnalysis: return .sleepAnalysis
        case .mindfulSession: return .mindfulSession
        default: return nil
        }
    }

    // MARK: - HKWorkoutActivityType → WorkoutType

    /// Converts HKWorkoutActivityType to FitIQCore WorkoutType
    static func toWorkoutType(_ activityType: HKWorkoutActivityType) -> HealthDataType.WorkoutType {
        switch activityType {
        // Cardiovascular
        case .running: return .running
        case .cycling: return .cycling
        case .walking: return .walking
        case .swimming: return .swimming
        case .rowing: return .rowing
        case .elliptical: return .elliptical
        case .stairClimbing: return .stairClimbing
        case .hiking: return .hiking
        case .wheelchairWalkPace: return .wheelchairWalkPace
        case .wheelchairRunPace: return .wheelchairRunPace

        // Strength & Training
        case .traditionalStrengthTraining: return .traditionalStrengthTraining
        case .functionalStrengthTraining: return .functionalStrengthTraining
        case .coreTraining: return .coreTraining
        case .crossTraining: return .crossTraining

        // Flexibility & Balance
        case .yoga: return .yoga
        case .pilates: return .pilates
        case .flexibility: return .flexibility
        case .barre: return .barre
        case .taiChi: return .tai_chi

        // Mind & Body
        case .mindAndBody: return .mindAndBody
        case .cooldown: return .cooldown

        // Team Sports
        case .basketball: return .basketball
        case .americanFootball: return .football
        case .soccer: return .soccer
        case .volleyball: return .volleyball
        case .baseball: return .baseball
        case .softball: return .softball
        case .hockey: return .hockey
        case .lacrosse: return .lacrosse
        case .rugby: return .rugby
        case .cricket: return .cricket
        case .handball: return .handball
        case .australianFootball: return .australianFootball

        // Racquet Sports
        case .tennis: return .tennis
        case .badminton: return .badminton
        case .racquetball: return .racquetball
        case .squash: return .squash
        case .tableTennis: return .tableTennis
        case .paddleSports: return .paddleSports

        // Combat Sports
        case .boxing: return .boxing
        case .kickboxing: return .kickboxing
        case .martialArts: return .martialArts
        case .wrestling: return .wrestling
        case .fencing: return .fencing
        case .mixedMetabolicCardioTraining: return .mixedMetabolicCardioTraining

        // Water Sports
        case .surfingSports: return .surfingSports
        case .sailing: return .sailing
        case .waterFitness: return .waterFitness
        case .waterPolo: return .waterPolo
        case .waterSports: return .waterSports

        // Winter Sports
        case .snowboarding: return .snowboarding
        case .downhillSkiing: return .skiing
        case .crossCountrySkiing: return .crossCountrySkiing
        case .snowSports: return .snowSports
        case .skatingSports: return .skating
        case .curling: return .curling

        // Outdoor Activities
        case .fishing: return .fishing
        case .hunting: return .hunting
        case .play: return .play
        case .discSports: return .discSports
        case .climbing: return .climbing
        case .equestrianSports: return .equestrianSports
        case .trackAndField: return .trackAndField

        // Dance
        case .dance: return .dance
        case .danceInspiredTraining: return .danceInspiredTraining
        case .socialDance: return .socialDance
        case .cardioDance: return .cardioDance

        // High Intensity
        case .highIntensityIntervalTraining: return .highIntensityIntervalTraining
        case .mixedCardio: return .mixedCardio
        case .jumpRope: return .jumpRope

        // Individual Sports
        case .golf: return .golf
        case .archery: return .archery
        case .bowling: return .bowling
        case .gymnastics: return .gymnastics

        // Fitness & Recreation
        case .fitnessGaming: return .fitnessGaming
        case .stairs: return .stairs
        case .stepTraining: return .stepTraining
        case .handCycling: return .handCycling

        // Other
        case .other: return .other
        case .preparationAndRecovery: return .preparationAndRecovery

        // Default (for any new HealthKit types)
        default: return .other
        }
    }

    // MARK: - WorkoutType → HKWorkoutActivityType

    /// Converts FitIQCore WorkoutType to HKWorkoutActivityType
    static func toHKWorkoutActivityType(_ type: HealthDataType.WorkoutType) -> HKWorkoutActivityType
    {
        switch type {
        // Cardiovascular
        case .running: return .running
        case .cycling: return .cycling
        case .walking: return .walking
        case .swimming: return .swimming
        case .rowing: return .rowing
        case .elliptical: return .elliptical
        case .stairClimbing: return .stairClimbing
        case .hiking: return .hiking
        case .wheelchairWalkPace: return .wheelchairWalkPace
        case .wheelchairRunPace: return .wheelchairRunPace

        // Strength & Training
        case .traditionalStrengthTraining: return .traditionalStrengthTraining
        case .functionalStrengthTraining: return .functionalStrengthTraining
        case .coreTraining: return .coreTraining
        case .crossTraining: return .crossTraining

        // Flexibility & Balance
        case .yoga: return .yoga
        case .pilates: return .pilates
        case .flexibility: return .flexibility
        case .barre: return .barre
        case .tai_chi: return .taiChi
        case .stretching: return .flexibility  // HealthKit doesn't have stretching, map to flexibility

        // Mind & Body
        case .meditation: return .mindAndBody  // Map meditation to mindAndBody
        case .mindAndBody: return .mindAndBody
        case .cooldown: return .cooldown

        // Team Sports
        case .basketball: return .basketball
        case .football: return .americanFootball
        case .soccer: return .soccer
        case .volleyball: return .volleyball
        case .baseball: return .baseball
        case .softball: return .softball
        case .hockey: return .hockey
        case .lacrosse: return .lacrosse
        case .rugby: return .rugby
        case .cricket: return .cricket
        case .handball: return .handball
        case .australianFootball: return .australianFootball

        // Racquet Sports
        case .tennis: return .tennis
        case .badminton: return .badminton
        case .racquetball: return .racquetball
        case .squash: return .squash
        case .tableTennis: return .tableTennis
        case .paddleSports: return .paddleSports

        // Combat Sports
        case .boxing: return .boxing
        case .kickboxing: return .kickboxing
        case .martialArts: return .martialArts
        case .wrestling: return .wrestling
        case .fencing: return .fencing
        case .mixedMetabolicCardioTraining: return .mixedMetabolicCardioTraining

        // Water Sports
        case .surfingSports: return .surfingSports
        case .paddleboarding: return .paddleSports  // Map to paddleSports
        case .sailing: return .sailing
        case .waterFitness: return .waterFitness
        case .waterPolo: return .waterPolo
        case .waterSports: return .waterSports

        // Winter Sports
        case .snowboarding: return .snowboarding
        case .skiing: return .downhillSkiing
        case .crossCountrySkiing: return .crossCountrySkiing
        case .snowSports: return .snowSports
        case .skating: return .skatingSports
        case .curling: return .curling

        // Outdoor Activities
        case .fishing: return .fishing
        case .hunting: return .hunting
        case .play: return .play
        case .discSports: return .discSports
        case .climbing: return .climbing
        case .equestrianSports: return .equestrianSports
        case .trackAndField: return .trackAndField

        // Dance
        case .dance: return .dance
        case .danceInspiredTraining: return .danceInspiredTraining
        case .socialDance: return .socialDance
        case .cardioDance: return .cardioDance

        // High Intensity
        case .highIntensityIntervalTraining: return .highIntensityIntervalTraining
        case .mixedCardio: return .mixedCardio
        case .jumpRope: return .jumpRope

        // Individual Sports
        case .golf: return .golf
        case .archery: return .archery
        case .bowling: return .bowling
        case .gymnastics: return .gymnastics

        // Fitness & Recreation
        case .fitnessGaming: return .fitnessGaming
        case .stairs: return .stairs
        case .stepTraining: return .stepTraining
        case .handCycling: return .handCycling

        // Other
        case .other: return .other
        case .preparationAndRecovery: return .preparationAndRecovery
        }
    }

    // MARK: - HKObjectType → HealthDataType

    /// Converts generic HKObjectType to FitIQCore HealthDataType
    static func toHealthDataType(_ type: HKObjectType) -> HealthDataType? {
        if let quantityType = type as? HKQuantityType {
            let identifier = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
            return toHealthDataType(identifier)
        }

        if let categoryType = type as? HKCategoryType {
            let identifier = HKCategoryTypeIdentifier(rawValue: categoryType.identifier)
            return toHealthDataType(identifier)
        }

        if type == HKObjectType.workoutType() {
            return .workout(.other)  // Default workout type
        }

        return nil
    }

    // MARK: - Unit Conversion

    /// Converts FitIQCore unit string to HKUnit
    static func toHKUnit(_ unitString: String, for type: HealthDataType) -> HKUnit {
        switch unitString {
        // Mass
        case "kg": return .gramUnit(with: .kilo)
        case "lbs", "lb": return .pound()
        case "g": return .gram()
        case "oz": return .ounce()

        // Distance
        case "m": return .meter()
        case "km": return .meterUnit(with: .kilo)
        case "mi": return .mile()
        case "ft": return .foot()
        case "in": return .inch()
        case "cm": return .meterUnit(with: .centi)
        case "yd": return .yard()

        // Energy
        case "kcal": return .kilocalorie()
        case "cal": return .smallCalorie()
        case "kJ": return .jouleUnit(with: .kilo)

        // Count
        case "steps", "count": return .count()

        // Heart Rate
        case "bpm": return .count().unitDivided(by: .minute())

        // Time
        case "min": return .minute()
        case "hr", "h": return .hour()
        case "s", "sec": return .second()
        case "ms": return .secondUnit(with: .milli)

        // Percentage
        case "%", "percent": return .percent()

        // Blood Pressure
        case "mmHg": return .millimeterOfMercury()

        // Blood Glucose
        case "mg/dL": return .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case "mmol/L":
            return .moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(
                by: .liter())

        // Temperature
        case "°C", "degC": return .degreeCelsius()
        case "°F", "degF": return .degreeFahrenheit()

        // Volume
        case "L": return .liter()
        case "mL": return .literUnit(with: .milli)
        case "fl oz": return .fluidOunceUS()
        case "cup": return .cupUS()

        // VO2 Max
        case "mL/kg/min":
            return .literUnit(with: .milli)
                .unitDivided(by: .gramUnit(with: .kilo))
                .unitDivided(by: .minute())

        default:
            print(
                "⚠️ HealthKitTypeTranslator: Unknown unit '\(unitString)' for \(type), using count")
            return .count()
        }
    }

    /// Converts HKUnit to FitIQCore unit string
    static func toUnitString(_ hkUnit: HKUnit) -> String {
        return hkUnit.unitString
    }

    // MARK: - Validation

    /// Validates that a HealthDataType can be converted to HealthKit type
    static func isSupported(_ type: HealthDataType) -> Bool {
        switch type {
        case .workout:
            return true
        case .sleepAnalysis, .mindfulSession:
            return toHKCategoryTypeIdentifier(type) != nil
        default:
            return toHKQuantityTypeIdentifier(type) != nil
        }
    }

    /// Gets all supported HKQuantityTypeIdentifiers
    static func allSupportedQuantityTypes() -> [HKQuantityTypeIdentifier] {
        return [
            // Body Measurements
            .bodyMass, .height,

            // Fitness - Steps & Distance
            .stepCount, .distanceWalkingRunning, .flightsClimbed,

            // Fitness - Energy
            .activeEnergyBurned, .basalEnergyBurned,
            .appleExerciseTime, .appleStandTime,

            // Heart & Cardiovascular
            .heartRate, .heartRateVariabilitySDNN,

            // Respiratory
            .oxygenSaturation, .respiratoryRate,
        ]
    }

    /// Gets all supported HKCategoryTypeIdentifiers
    static func allSupportedCategoryTypes() -> [HKCategoryTypeIdentifier] {
        return [
            .sleepAnalysis,
            .mindfulSession,
        ]
    }
}

// MARK: - Convenience Extensions

extension HKQuantityTypeIdentifier {
    /// Converts to FitIQCore HealthDataType
    var healthDataType: HealthDataType? {
        HealthKitTypeTranslator.toHealthDataType(self)
    }
}

extension HKCategoryTypeIdentifier {
    /// Converts to FitIQCore HealthDataType
    var healthDataType: HealthDataType? {
        HealthKitTypeTranslator.toHealthDataType(self)
    }
}

extension HKWorkoutActivityType {
    /// Converts to FitIQCore WorkoutType
    var workoutType: HealthDataType.WorkoutType {
        HealthKitTypeTranslator.toWorkoutType(self)
    }
}

extension HealthDataType {
    /// Converts to HKQuantityTypeIdentifier (if applicable)
    var hkQuantityTypeIdentifier: HKQuantityTypeIdentifier? {
        HealthKitTypeTranslator.toHKQuantityTypeIdentifier(self)
    }

    /// Converts to HKCategoryTypeIdentifier (if applicable)
    var hkCategoryTypeIdentifier: HKCategoryTypeIdentifier? {
        HealthKitTypeTranslator.toHKCategoryTypeIdentifier(self)
    }

    /// Checks if this type is supported in HealthKit bridge
    var isHealthKitSupported: Bool {
        HealthKitTypeTranslator.isSupported(self)
    }
}

extension HealthDataType.WorkoutType {
    /// Converts to HKWorkoutActivityType
    var hkWorkoutActivityType: HKWorkoutActivityType {
        HealthKitTypeTranslator.toHKWorkoutActivityType(self)
    }
}
