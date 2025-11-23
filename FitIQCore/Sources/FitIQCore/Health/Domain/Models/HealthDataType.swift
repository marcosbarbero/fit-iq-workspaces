//
//  HealthDataType.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation

/// Represents types of health data that can be read/written via HealthKit
///
/// This enumeration provides a type-safe way to reference HealthKit data types
/// across both FitIQ and Lume apps. Each case maps to a specific HKQuantityType,
/// HKCategoryType, or HKWorkoutActivityType in HealthKit.
///
/// **Usage:**
/// ```swift
/// // Request authorization for specific types
/// let scope = HealthAuthorizationScope(
///     read: [.stepCount, .heartRate, .mindfulSession],
///     write: [.bodyMass, .workout(.meditation)]
/// )
/// ```
///
/// **Architecture:** FitIQCore - Shared Domain Model
public enum HealthDataType: Sendable, Hashable, Codable {

    // MARK: - Quantity Types

    /// Step count (steps/day)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.stepCount`
    case stepCount

    /// Heart rate (beats per minute)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.heartRate`
    case heartRate

    /// Active energy burned (kilocalories)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.activeEnergyBurned`
    case activeEnergyBurned

    /// Resting energy burned (kilocalories)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.basalEnergyBurned`
    case basalEnergyBurned

    /// Body mass/weight (kilograms)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.bodyMass`
    case bodyMass

    /// Height (meters)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.height`
    case height

    /// Respiratory rate (breaths per minute)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.respiratoryRate`
    case respiratoryRate

    /// Heart rate variability (milliseconds)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.heartRateVariabilitySDNN`
    case heartRateVariability

    /// Distance walking/running (meters)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.distanceWalkingRunning`
    case distanceWalkingRunning

    /// Flights of stairs climbed (count)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.flightsClimbed`
    case flightsClimbed

    /// Exercise time (minutes)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.appleExerciseTime`
    case exerciseTime

    /// Stand time (minutes)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.appleStandTime`
    case standTime

    /// Oxygen saturation (percentage)
    ///
    /// Maps to: `HKQuantityTypeIdentifier.oxygenSaturation`
    case oxygenSaturation

    // MARK: - Category Types

    /// Sleep analysis (in bed, asleep, awake)
    ///
    /// Maps to: `HKCategoryTypeIdentifier.sleepAnalysis`
    case sleepAnalysis

    /// Mindful session (meditation, breathing exercises)
    ///
    /// Maps to: `HKCategoryTypeIdentifier.mindfulSession`
    case mindfulSession

    // MARK: - Workout Types

    /// Workout/exercise session with specific activity type
    ///
    /// Maps to: `HKWorkoutType` with specific `HKWorkoutActivityType`
    case workout(WorkoutType)

    /// Types of workout activities supported by HealthKit (all 84 types)
    ///
    /// Maps to: `HKWorkoutActivityType` in HealthKit
    public enum WorkoutType: String, Sendable, Hashable, Codable, CaseIterable {
        // MARK: - Cardiovascular
        case running
        case cycling
        case walking
        case swimming
        case rowing
        case elliptical
        case stairClimbing
        case hiking
        case wheelchairWalkPace
        case wheelchairRunPace

        // MARK: - Strength & Training
        case traditionalStrengthTraining
        case functionalStrengthTraining
        case coreTraining
        case crossTraining

        // MARK: - Flexibility & Balance
        case yoga
        case pilates
        case flexibility
        case barre
        case tai_chi = "taiChi"
        case stretching

        // MARK: - Mind & Body
        case meditation
        case mindAndBody
        case cooldown

        // MARK: - Team Sports
        case basketball
        case football = "americanFootball"
        case soccer
        case volleyball
        case baseball
        case softball
        case hockey
        case lacrosse
        case rugby
        case cricket
        case handball
        case australianFootball

        // MARK: - Racquet Sports
        case tennis
        case badminton
        case racquetball
        case squash
        case tableTennis
        case paddleSports

        // MARK: - Combat Sports
        case boxing
        case kickboxing
        case martialArts
        case wrestling
        case fencing
        case mixedMetabolicCardioTraining

        // MARK: - Water Sports
        case surfingSports
        case paddleboarding = "standUpPaddleboarding"
        case sailing
        case waterFitness
        case waterPolo
        case waterSports

        // MARK: - Winter Sports
        case snowboarding
        case skiing = "downhillSkiing"
        case crossCountrySkiing
        case snowSports
        case skating
        case curling

        // MARK: - Outdoor Activities
        case fishing
        case hunting
        case play
        case discSports
        case climbing
        case equestrianSports
        case trackAndField

        // MARK: - Dance
        case dance
        case danceInspiredTraining
        case socialDance
        case cardioDance

        // MARK: - High Intensity
        case highIntensityIntervalTraining
        case mixedCardio
        case jumpRope

        // MARK: - Individual Sports
        case golf
        case archery
        case bowling
        case gymnastics

        // MARK: - Fitness & Recreation
        case fitnessGaming
        case stairs
        case stepTraining
        case handCycling

        // MARK: - Other
        case other
        case preparationAndRecovery
    }
}

// MARK: - CustomStringConvertible

extension HealthDataType: CustomStringConvertible {
    /// Human-readable description of the health data type
    public var description: String {
        switch self {
        // Quantity Types
        case .stepCount:
            return "Step Count"
        case .heartRate:
            return "Heart Rate"
        case .activeEnergyBurned:
            return "Active Energy"
        case .basalEnergyBurned:
            return "Resting Energy"
        case .bodyMass:
            return "Body Mass"
        case .height:
            return "Height"
        case .respiratoryRate:
            return "Respiratory Rate"
        case .heartRateVariability:
            return "Heart Rate Variability"
        case .distanceWalkingRunning:
            return "Walking/Running Distance"
        case .flightsClimbed:
            return "Flights Climbed"
        case .exerciseTime:
            return "Exercise Time"
        case .standTime:
            return "Stand Time"
        case .oxygenSaturation:
            return "Oxygen Saturation"

        // Category Types
        case .sleepAnalysis:
            return "Sleep"
        case .mindfulSession:
            return "Mindful Minutes"

        // Workout Types
        case .workout(let type):
            return "Workout (\(type.displayName))"
        }
    }
}

// MARK: - Workout Type Display Names

extension HealthDataType.WorkoutType {
    /// User-facing display name for the workout type
    public var displayName: String {
        switch self {
        // MARK: - Cardiovascular
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .hiking: return "Hiking"
        case .wheelchairWalkPace: return "Wheelchair Walk"
        case .wheelchairRunPace: return "Wheelchair Run"

        // MARK: - Strength & Training
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Training"
        case .coreTraining: return "Core Training"
        case .crossTraining: return "Cross Training"

        // MARK: - Flexibility & Balance
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .flexibility: return "Flexibility"
        case .barre: return "Barre"
        case .tai_chi: return "Tai Chi"
        case .stretching: return "Stretching"

        // MARK: - Mind & Body
        case .meditation: return "Meditation"
        case .mindAndBody: return "Mind & Body"
        case .cooldown: return "Cooldown"

        // MARK: - Team Sports
        case .basketball: return "Basketball"
        case .football: return "Football"
        case .soccer: return "Soccer"
        case .volleyball: return "Volleyball"
        case .baseball: return "Baseball"
        case .softball: return "Softball"
        case .hockey: return "Hockey"
        case .lacrosse: return "Lacrosse"
        case .rugby: return "Rugby"
        case .cricket: return "Cricket"
        case .handball: return "Handball"
        case .australianFootball: return "Australian Football"

        // MARK: - Racquet Sports
        case .tennis: return "Tennis"
        case .badminton: return "Badminton"
        case .racquetball: return "Racquetball"
        case .squash: return "Squash"
        case .tableTennis: return "Table Tennis"
        case .paddleSports: return "Paddle Sports"

        // MARK: - Combat Sports
        case .boxing: return "Boxing"
        case .kickboxing: return "Kickboxing"
        case .martialArts: return "Martial Arts"
        case .wrestling: return "Wrestling"
        case .fencing: return "Fencing"
        case .mixedMetabolicCardioTraining: return "Mixed Cardio Training"

        // MARK: - Water Sports
        case .surfingSports: return "Surfing"
        case .paddleboarding: return "Stand-Up Paddleboarding"
        case .sailing: return "Sailing"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"

        // MARK: - Winter Sports
        case .snowboarding: return "Snowboarding"
        case .skiing: return "Downhill Skiing"
        case .crossCountrySkiing: return "Cross-Country Skiing"
        case .snowSports: return "Snow Sports"
        case .skating: return "Skating"
        case .curling: return "Curling"

        // MARK: - Outdoor Activities
        case .fishing: return "Fishing"
        case .hunting: return "Hunting"
        case .play: return "Play"
        case .discSports: return "Disc Sports"
        case .climbing: return "Climbing"
        case .equestrianSports: return "Equestrian Sports"
        case .trackAndField: return "Track & Field"

        // MARK: - Dance
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance Training"
        case .socialDance: return "Social Dance"
        case .cardioDance: return "Cardio Dance"

        // MARK: - High Intensity
        case .highIntensityIntervalTraining: return "HIIT"
        case .mixedCardio: return "Mixed Cardio"
        case .jumpRope: return "Jump Rope"

        // MARK: - Individual Sports
        case .golf: return "Golf"
        case .archery: return "Archery"
        case .bowling: return "Bowling"
        case .gymnastics: return "Gymnastics"

        // MARK: - Fitness & Recreation
        case .fitnessGaming: return "Fitness Gaming"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .handCycling: return "Hand Cycling"

        // MARK: - Other
        case .other: return "Other"
        case .preparationAndRecovery: return "Preparation & Recovery"
        }
    }
}

// MARK: - Categories

extension HealthDataType {
    /// Returns true if this is a quantity type (measurable value)
    public var isQuantityType: Bool {
        switch self {
        case .stepCount, .heartRate, .activeEnergyBurned, .basalEnergyBurned,
            .bodyMass, .height, .respiratoryRate, .heartRateVariability,
            .distanceWalkingRunning, .flightsClimbed, .exerciseTime,
            .standTime, .oxygenSaturation:
            return true
        case .sleepAnalysis, .mindfulSession, .workout:
            return false
        }
    }

    /// Returns true if this is a category type (discrete state)
    public var isCategoryType: Bool {
        switch self {
        case .sleepAnalysis, .mindfulSession:
            return true
        case .stepCount, .heartRate, .activeEnergyBurned, .basalEnergyBurned,
            .bodyMass, .height, .respiratoryRate, .heartRateVariability,
            .distanceWalkingRunning, .flightsClimbed, .exerciseTime,
            .standTime, .oxygenSaturation, .workout:
            return false
        }
    }

    /// Returns true if this is a workout type
    public var isWorkoutType: Bool {
        if case .workout = self {
            return true
        }
        return false
    }
}

// MARK: - Predefined Sets

extension HealthDataType {
    /// Health data types commonly used for fitness tracking (FitIQ)
    public static var fitnessTypes: Set<HealthDataType> {
        [
            .stepCount,
            .heartRate,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .bodyMass,
            .height,
            .distanceWalkingRunning,
            .flightsClimbed,
            .exerciseTime,
            .standTime,
            .sleepAnalysis,
        ]
    }

    /// Health data types commonly used for mindfulness tracking (Lume)
    public static var mindfulnessTypes: Set<HealthDataType> {
        [
            .mindfulSession,
            .heartRate,
            .heartRateVariability,
            .respiratoryRate,
            .oxygenSaturation,
            .workout(.meditation),
            .workout(.yoga),
            .workout(.tai_chi),
        ]
    }

    /// All basic quantity types
    public static var allQuantityTypes: Set<HealthDataType> {
        [
            .stepCount,
            .heartRate,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .bodyMass,
            .height,
            .respiratoryRate,
            .heartRateVariability,
            .distanceWalkingRunning,
            .flightsClimbed,
            .exerciseTime,
            .standTime,
            .oxygenSaturation,
        ]
    }

    /// All category types
    public static var allCategoryTypes: Set<HealthDataType> {
        [
            .sleepAnalysis,
            .mindfulSession,
        ]
    }
}

// MARK: - Codable Support

extension HealthDataType {
    private enum CodingKeys: String, CodingKey {
        case type
        case workoutType
    }

    private enum TypeIdentifier: String, Codable {
        case stepCount
        case heartRate
        case activeEnergyBurned
        case basalEnergyBurned
        case bodyMass
        case height
        case respiratoryRate
        case heartRateVariability
        case distanceWalkingRunning
        case flightsClimbed
        case exerciseTime
        case standTime
        case oxygenSaturation
        case sleepAnalysis
        case mindfulSession
        case workout
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeIdentifier.self, forKey: .type)

        switch type {
        case .stepCount:
            self = .stepCount
        case .heartRate:
            self = .heartRate
        case .activeEnergyBurned:
            self = .activeEnergyBurned
        case .basalEnergyBurned:
            self = .basalEnergyBurned
        case .bodyMass:
            self = .bodyMass
        case .height:
            self = .height
        case .respiratoryRate:
            self = .respiratoryRate
        case .heartRateVariability:
            self = .heartRateVariability
        case .distanceWalkingRunning:
            self = .distanceWalkingRunning
        case .flightsClimbed:
            self = .flightsClimbed
        case .exerciseTime:
            self = .exerciseTime
        case .standTime:
            self = .standTime
        case .oxygenSaturation:
            self = .oxygenSaturation
        case .sleepAnalysis:
            self = .sleepAnalysis
        case .mindfulSession:
            self = .mindfulSession
        case .workout:
            let workoutType = try container.decode(WorkoutType.self, forKey: .workoutType)
            self = .workout(workoutType)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .stepCount:
            try container.encode(TypeIdentifier.stepCount, forKey: .type)
        case .heartRate:
            try container.encode(TypeIdentifier.heartRate, forKey: .type)
        case .activeEnergyBurned:
            try container.encode(TypeIdentifier.activeEnergyBurned, forKey: .type)
        case .basalEnergyBurned:
            try container.encode(TypeIdentifier.basalEnergyBurned, forKey: .type)
        case .bodyMass:
            try container.encode(TypeIdentifier.bodyMass, forKey: .type)
        case .height:
            try container.encode(TypeIdentifier.height, forKey: .type)
        case .respiratoryRate:
            try container.encode(TypeIdentifier.respiratoryRate, forKey: .type)
        case .heartRateVariability:
            try container.encode(TypeIdentifier.heartRateVariability, forKey: .type)
        case .distanceWalkingRunning:
            try container.encode(TypeIdentifier.distanceWalkingRunning, forKey: .type)
        case .flightsClimbed:
            try container.encode(TypeIdentifier.flightsClimbed, forKey: .type)
        case .exerciseTime:
            try container.encode(TypeIdentifier.exerciseTime, forKey: .type)
        case .standTime:
            try container.encode(TypeIdentifier.standTime, forKey: .type)
        case .oxygenSaturation:
            try container.encode(TypeIdentifier.oxygenSaturation, forKey: .type)
        case .sleepAnalysis:
            try container.encode(TypeIdentifier.sleepAnalysis, forKey: .type)
        case .mindfulSession:
            try container.encode(TypeIdentifier.mindfulSession, forKey: .type)
        case .workout(let workoutType):
            try container.encode(TypeIdentifier.workout, forKey: .type)
            try container.encode(workoutType, forKey: .workoutType)
        }
    }
}
