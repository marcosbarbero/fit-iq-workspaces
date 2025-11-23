//
//  HealthKitTypeMapper.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation
import HealthKit

/// Maps domain health data types to HealthKit types
///
/// This mapper provides bidirectional conversion between our domain model
/// (`HealthDataType`) and Apple's HealthKit types (`HKQuantityType`,
/// `HKCategoryType`, `HKWorkoutActivityType`).
///
/// **Usage:**
/// ```swift
/// // Domain → HealthKit
/// let hkType = try HealthKitTypeMapper.toHKType(.stepCount)
/// // Returns: HKQuantityType(.stepCount)
///
/// let workoutType = try HealthKitTypeMapper.toHKWorkoutActivityType(.running)
/// // Returns: HKWorkoutActivityType.running
///
/// // Get unit for type
/// let unit = HealthKitTypeMapper.defaultUnit(for: .heartRate)
/// // Returns: HKUnit.count().unitDivided(by: .minute()) // bpm
/// ```
///
/// **Architecture:** FitIQCore - Infrastructure Layer (Hexagonal Architecture)
///
/// **Platform:** iOS, watchOS, macOS (Catalyst)
@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
public enum HealthKitTypeMapper {

    // MARK: - Domain → HealthKit Type Conversion

    /// Converts a domain HealthDataType to HealthKit's HKSampleType
    ///
    /// - Parameter type: Domain health data type
    /// - Returns: Corresponding HKSampleType (HKQuantityType, HKCategoryType, or HKWorkoutType)
    /// - Throws: `HealthKitError.typeNotAvailable` if the type is not supported
    public static func toHKType(_ type: HealthDataType) throws -> HKSampleType {
        switch type {
        case .stepCount:
            return HKQuantityType(.stepCount)
        case .heartRate:
            return HKQuantityType(.heartRate)
        case .activeEnergyBurned:
            return HKQuantityType(.activeEnergyBurned)
        case .basalEnergyBurned:
            return HKQuantityType(.basalEnergyBurned)
        case .bodyMass:
            return HKQuantityType(.bodyMass)
        case .height:
            return HKQuantityType(.height)
        case .respiratoryRate:
            return HKQuantityType(.respiratoryRate)
        case .heartRateVariability:
            return HKQuantityType(.heartRateVariabilitySDNN)
        case .distanceWalkingRunning:
            return HKQuantityType(.distanceWalkingRunning)
        case .flightsClimbed:
            return HKQuantityType(.flightsClimbed)
        case .exerciseTime:
            return HKQuantityType(.appleExerciseTime)
        case .standTime:
            return HKQuantityType(.appleStandTime)
        case .oxygenSaturation:
            return HKQuantityType(.oxygenSaturation)
        case .sleepAnalysis:
            return HKCategoryType(.sleepAnalysis)
        case .mindfulSession:
            return HKCategoryType(.mindfulSession)
        case .workout:
            return HKWorkoutType.workoutType()
        }
    }

    /// Converts a domain WorkoutType to HealthKit's HKWorkoutActivityType
    ///
    /// - Parameter workoutType: Domain workout type
    /// - Returns: Corresponding HKWorkoutActivityType
    public static func toHKWorkoutActivityType(_ workoutType: HealthDataType.WorkoutType)
        -> HKWorkoutActivityType
    {
        switch workoutType {
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
        case .stretching: return .flexibility  // Map to flexibility

        // Mind & Body
        case .meditation: return .mindAndBody
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
        case .mixedMetabolicCardioTraining: return .mixedCardio

        // Water Sports
        case .surfingSports: return .surfingSports
        case .paddleboarding: return .paddleSports  // Map to paddle sports
        case .sailing: return .sailing
        case .waterFitness: return .waterFitness
        case .waterPolo: return .waterPolo
        case .waterSports: return .waterSports

        // Winter Sports
        case .snowboarding: return .snowboarding
        case .skiing: return .downhillSkiing
        case .crossCountrySkiing: return .crossCountrySkiing
        case .snowSports: return .snowSports
        case .skating: return .other  // HealthKit doesn't have skating
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

    // MARK: - HealthKit → Domain Type Conversion

    /// Converts a HealthKit HKSampleType back to domain HealthDataType
    ///
    /// - Parameter hkType: HealthKit sample type
    /// - Returns: Corresponding domain health data type, or nil if not mapped
    public static func fromHKType(_ hkType: HKSampleType) -> HealthDataType? {
        if let quantityType = hkType as? HKQuantityType {
            return fromHKQuantityType(quantityType)
        } else if let categoryType = hkType as? HKCategoryType {
            return fromHKCategoryType(categoryType)
        } else if hkType is HKWorkoutType {
            // Can't determine specific workout type from HKWorkoutType alone
            // Workout type is stored in the HKWorkout sample itself
            return nil
        }
        return nil
    }

    /// Converts a HealthKit HKQuantityType back to domain HealthDataType
    private static func fromHKQuantityType(_ quantityType: HKQuantityType) -> HealthDataType? {
        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .stepCount
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return .heartRate
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .activeEnergyBurned
        case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
            return .basalEnergyBurned
        case HKQuantityTypeIdentifier.bodyMass.rawValue:
            return .bodyMass
        case HKQuantityTypeIdentifier.height.rawValue:
            return .height
        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            return .respiratoryRate
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return .heartRateVariability
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            return .distanceWalkingRunning
        case HKQuantityTypeIdentifier.flightsClimbed.rawValue:
            return .flightsClimbed
        case HKQuantityTypeIdentifier.appleExerciseTime.rawValue:
            return .exerciseTime
        case HKQuantityTypeIdentifier.appleStandTime.rawValue:
            return .standTime
        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .oxygenSaturation
        default:
            return nil
        }
    }

    /// Converts a HealthKit HKCategoryType back to domain HealthDataType
    private static func fromHKCategoryType(_ categoryType: HKCategoryType) -> HealthDataType? {
        switch categoryType.identifier {
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            return .sleepAnalysis
        case HKCategoryTypeIdentifier.mindfulSession.rawValue:
            return .mindfulSession
        default:
            return nil
        }
    }

    /// Converts a HealthKit HKWorkoutActivityType back to domain WorkoutType
    ///
    /// - Parameter hkActivityType: HealthKit workout activity type
    /// - Returns: Corresponding domain workout type
    public static func fromHKWorkoutActivityType(_ hkActivityType: HKWorkoutActivityType)
        -> HealthDataType.WorkoutType
    {
        switch hkActivityType {
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
        case .mixedCardio: return .mixedMetabolicCardioTraining

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
        case .preparationAndRecovery: return .preparationAndRecovery
        default: return .other
        }
    }

    // MARK: - Unit Conversion

    /// Unit system preference for health data display
    public enum UnitSystem: String, Codable, Sendable, CaseIterable {
        case metric
        case imperial

        /// Human-readable description
        public var description: String {
            switch self {
            case .metric: return "Metric"
            case .imperial: return "Imperial"
            }
        }
    }

    /// Returns the default HealthKit unit for a given health data type
    ///
    /// - Parameters:
    ///   - type: Domain health data type
    ///   - unitSystem: User's preferred unit system (defaults to metric)
    /// - Returns: Appropriate HKUnit for the type
    public static func defaultUnit(for type: HealthDataType, unitSystem: UnitSystem = .metric)
        -> HKUnit
    {
        switch type {
        case .stepCount:
            return .count()
        case .heartRate:
            return .count().unitDivided(by: .minute())  // bpm
        case .activeEnergyBurned, .basalEnergyBurned:
            return .kilocalorie()
        case .bodyMass:
            return unitSystem == .metric ? .gramUnit(with: .kilo) : .pound()  // kg or lbs
        case .height:
            return unitSystem == .metric ? .meter() : .foot()  // m or ft
        case .respiratoryRate:
            return .count().unitDivided(by: .minute())  // breaths/min
        case .heartRateVariability:
            return .secondUnit(with: .milli)  // ms
        case .distanceWalkingRunning:
            return unitSystem == .metric ? .meter() : .mile()  // m or mi
        case .flightsClimbed:
            return .count()
        case .exerciseTime, .standTime:
            return .minute()
        case .oxygenSaturation:
            return .percent()
        case .sleepAnalysis, .mindfulSession, .workout:
            return .minute()  // Duration-based types use minutes
        }
    }

    /// Converts a unit string to HKUnit
    ///
    /// - Parameter unitString: String representation of unit (e.g., "bpm", "steps", "kg")
    /// - Returns: Corresponding HKUnit, or nil if not recognized
    public static func hkUnit(from unitString: String) -> HKUnit? {
        switch unitString.lowercased() {
        // Count
        case "count", "steps", "flights":
            return .count()

        // Energy
        case "kcal", "kilocalories", "calories":
            return .kilocalorie()

        // Mass
        case "kg", "kilograms":
            return .gramUnit(with: .kilo)
        case "g", "grams":
            return .gram()
        case "lb", "lbs", "pounds":
            return .pound()

        // Distance
        case "m", "meters", "metres":
            return .meter()
        case "km", "kilometers", "kilometres":
            return .meterUnit(with: .kilo)
        case "mi", "miles":
            return .mile()
        case "ft", "feet":
            return .foot()

        // Time
        case "min", "minutes":
            return .minute()
        case "sec", "seconds":
            return .second()
        case "hr", "hours":
            return .hour()
        case "ms", "milliseconds":
            return .secondUnit(with: .milli)

        // Rate
        case "bpm", "beats/min":
            return .count().unitDivided(by: .minute())
        case "breaths/min":
            return .count().unitDivided(by: .minute())

        // Percentage
        case "%", "percent", "percentage":
            return .percent()

        default:
            return nil
        }
    }

    /// Returns a human-readable unit string for a health data type
    ///
    /// - Parameters:
    ///   - type: Domain health data type
    ///   - unitSystem: User's preferred unit system (defaults to metric)
    /// - Returns: Unit string (e.g., "bpm", "steps", "kg" or "lbs")
    public static func unitString(for type: HealthDataType, unitSystem: UnitSystem = .metric)
        -> String
    {
        switch type {
        case .stepCount:
            return "steps"
        case .heartRate:
            return "bpm"
        case .activeEnergyBurned, .basalEnergyBurned:
            return "kcal"
        case .bodyMass:
            return unitSystem == .metric ? "kg" : "lbs"
        case .height:
            return unitSystem == .metric ? "m" : "ft"
        case .respiratoryRate:
            return "breaths/min"
        case .heartRateVariability:
            return "ms"
        case .distanceWalkingRunning:
            return unitSystem == .metric ? "km" : "mi"
        case .flightsClimbed:
            return "flights"
        case .exerciseTime, .standTime:
            return "min"
        case .oxygenSaturation:
            return "%"
        case .sleepAnalysis, .mindfulSession, .workout:
            return "min"
        }
    }

    /// Converts a value from one unit to another within the same measurement type
    ///
    /// - Parameters:
    ///   - value: The value to convert
    ///   - from: Source unit
    ///   - to: Destination unit
    /// - Returns: Converted value
    ///
    /// **Example:**
    /// ```swift
    /// // Convert 75 kg to pounds
    /// let lbs = HealthKitTypeMapper.convert(
    ///     value: 75.0,
    ///     from: .gramUnit(with: .kilo),
    ///     to: .pound()
    /// )
    /// // Returns: 165.35
    /// ```
    public static func convert(value: Double, from: HKUnit, to: HKUnit) -> Double {
        // Use HKQuantity for proper unit conversion
        let quantity = HKQuantity(unit: from, doubleValue: value)
        return quantity.doubleValue(for: to)
    }
}

// MARK: - UnitSystem Extensions

@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
extension HealthKitTypeMapper.UnitSystem {
    /// Creates a UnitSystem from UserProfile's preferredUnitSystem string
    ///
    /// - Parameter preferredUnitSystem: String from UserProfile ("metric" or "imperial")
    /// - Returns: Corresponding UnitSystem, defaults to .metric if unrecognized
    public static func from(preferredUnitSystem: String) -> HealthKitTypeMapper.UnitSystem {
        switch preferredUnitSystem.lowercased() {
        case "imperial":
            return .imperial
        case "metric":
            return .metric
        default:
            return .metric  // Default to metric for any unrecognized value
        }
    }

    /// Converts this UnitSystem to a string compatible with UserProfile
    ///
    /// - Returns: String representation ("metric" or "imperial")
    public var toPreferredUnitSystemString: String {
        self.rawValue
    }
}
