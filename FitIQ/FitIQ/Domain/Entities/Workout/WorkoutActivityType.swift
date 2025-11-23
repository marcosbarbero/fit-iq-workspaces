//
//  WorkoutActivityType.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation
import HealthKit

/// Workout activity types supported by the app
/// Maps to HealthKit workout types and backend API activity types
public enum WorkoutActivityType: String, Codable, CaseIterable {
    // Common activities
    case running = "Running"
    case cycling = "Cycling"
    case walking = "Walking"
    case swimming = "Swimming"
    case yoga = "Yoga"
    case strengthTraining = "Strength Training"
    case functionalStrengthTraining = "Functional Strength Training"
    case traditionalStrengthTraining = "Traditional Strength Training"
    case coreTraining = "Core Training"
    case flexibility = "Flexibility"
    case hiit = "HIIT"
    case cardio = "Cardio"
    case mixedCardio = "Mixed Cardio"
    case elliptical = "Elliptical"
    case rowing = "Rowing"
    case stairClimbing = "Stair Climbing"
    case stairs = "Stairs"
    case dance = "Dance"
    case pilates = "Pilates"
    case boxing = "Boxing"
    case martialArts = "Martial Arts"

    // Sports
    case basketball = "Basketball"
    case soccer = "Soccer"
    case tennis = "Tennis"
    case golf = "Golf"
    case hiking = "Hiking"
    case baseball = "Baseball"
    case softball = "Softball"
    case volleyball = "Volleyball"
    case americanFootball = "American Football"
    case australianFootball = "Australian Football"
    case rugby = "Rugby"
    case hockey = "Hockey"

    // Additional activities
    case crossTraining = "Cross Training"
    case jumpRope = "Jump Rope"
    case kickboxing = "Kickboxing"
    case barre = "Barre"
    case mindAndBody = "Mind and Body"
    case preparationAndRecovery = "Preparation and Recovery"
    case taiChi = "Tai Chi"
    case stepTraining = "Step Training"
    case wheelchairWalkPace = "Wheelchair Walk Pace"
    case wheelchairRunPace = "Wheelchair Run Pace"
    case handCycling = "Hand Cycling"

    // Water activities
    case waterFitness = "Water Fitness"
    case waterPolo = "Water Polo"
    case waterSports = "Water Sports"
    case paddleSports = "Paddle Sports"
    case surfingSports = "Surfing Sports"
    case sailing = "Sailing"

    // Winter activities
    case snowSports = "Snow Sports"
    case crossCountrySkiing = "Cross Country Skiing"
    case downhillSkiing = "Downhill Skiing"
    case snowboarding = "Snowboarding"
    case skatingSports = "Skating Sports"

    // Other sports
    case archery = "Archery"
    case badminton = "Badminton"
    case bowling = "Bowling"
    case climbing = "Climbing"
    case curling = "Curling"
    case danceInspiredTraining = "Dance Inspired Training"
    case equestrianSports = "Equestrian Sports"
    case fencing = "Fencing"
    case fishing = "Fishing"
    case gymnastics = "Gymnastics"
    case handball = "Handball"
    case hunting = "Hunting"
    case lacrosse = "Lacrosse"
    case mixedMetabolicCardioTraining = "Mixed Metabolic Cardio Training"
    case play = "Play"
    case racquetball = "Racquetball"
    case squash = "Squash"
    case tableTennis = "Table Tennis"
    case trackAndField = "Track and Field"
    case wrestling = "Wrestling"
    case discSports = "Disc Sports"
    case fitnessGaming = "Fitness Gaming"

    // Catch-all
    case other = "Other"

    /// Initialize from HealthKit workout activity type
    public init(from hkType: HKWorkoutActivityType) {
        switch hkType {
        case .running:
            self = .running
        case .cycling:
            self = .cycling
        case .walking:
            self = .walking
        case .swimming:
            self = .swimming
        case .yoga:
            self = .yoga
        case .functionalStrengthTraining:
            self = .functionalStrengthTraining
        case .traditionalStrengthTraining:
            self = .traditionalStrengthTraining
        case .coreTraining:
            self = .coreTraining
        case .flexibility:
            self = .flexibility
        case .highIntensityIntervalTraining:
            self = .hiit
        case .mixedCardio:
            self = .mixedCardio
        case .elliptical:
            self = .elliptical
        case .rowing:
            self = .rowing
        case .stairClimbing:
            self = .stairClimbing
        case .stairs:
            self = .stairs
        case .dance, .danceInspiredTraining:
            self = .dance
        case .pilates:
            self = .pilates
        case .boxing:
            self = .boxing
        case .martialArts:
            self = .martialArts
        case .basketball:
            self = .basketball
        case .soccer:
            self = .soccer
        case .tennis:
            self = .tennis
        case .golf:
            self = .golf
        case .hiking:
            self = .hiking
        case .baseball:
            self = .baseball
        case .softball:
            self = .softball
        case .volleyball:
            self = .volleyball
        case .americanFootball:
            self = .americanFootball
        case .australianFootball:
            self = .australianFootball
        case .rugby:
            self = .rugby
        case .hockey:
            self = .hockey
        case .crossTraining:
            self = .crossTraining
        case .jumpRope:
            self = .jumpRope
        case .kickboxing:
            self = .kickboxing
        case .barre:
            self = .barre
        case .mindAndBody:
            self = .mindAndBody
        case .preparationAndRecovery:
            self = .preparationAndRecovery
        case .taiChi:
            self = .taiChi
        case .stepTraining:
            self = .stepTraining
        case .wheelchairWalkPace:
            self = .wheelchairWalkPace
        case .wheelchairRunPace:
            self = .wheelchairRunPace
        case .handCycling:
            self = .handCycling
        case .waterFitness:
            self = .waterFitness
        case .waterPolo:
            self = .waterPolo
        case .waterSports:
            self = .waterSports
        case .paddleSports:
            self = .paddleSports
        case .surfingSports:
            self = .surfingSports
        case .sailing:
            self = .sailing
        case .snowSports:
            self = .snowSports
        case .crossCountrySkiing:
            self = .crossCountrySkiing
        case .downhillSkiing:
            self = .downhillSkiing
        case .snowboarding:
            self = .snowboarding
        case .skatingSports:
            self = .skatingSports
        case .archery:
            self = .archery
        case .badminton:
            self = .badminton
        case .bowling:
            self = .bowling
        case .climbing:
            self = .climbing
        case .curling:
            self = .curling
        case .equestrianSports:
            self = .equestrianSports
        case .fencing:
            self = .fencing
        case .fishing:
            self = .fishing
        case .gymnastics:
            self = .gymnastics
        case .handball:
            self = .handball
        case .hunting:
            self = .hunting
        case .lacrosse:
            self = .lacrosse
        case .mixedMetabolicCardioTraining:
            self = .mixedMetabolicCardioTraining
        case .play:
            self = .play
        case .racquetball:
            self = .racquetball
        case .squash:
            self = .squash
        case .tableTennis:
            self = .tableTennis
        case .trackAndField:
            self = .trackAndField
        case .wrestling:
            self = .wrestling
        case .discSports:
            self = .discSports
        case .fitnessGaming:
            self = .fitnessGaming
        default:
            self = .other
        }
    }

    /// Display name for UI
    public var displayName: String {
        rawValue
    }

    /// Common name (e.g., "HIIT" instead of "High Intensity Interval Training")
    public var commonName: String {
        switch self {
        case .hiit:
            return "HIIT"
        default:
            return rawValue
        }
    }

    /// SF Symbol icon name for UI display
    public var systemIconName: String {
        switch self {
        // Running & Walking
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .hiking:
            return "figure.hiking"

        // Cycling
        case .cycling:
            return "figure.outdoor.cycle"
        case .handCycling:
            return "figure.hand.cycling"

        // Swimming & Water
        case .swimming:
            return "figure.pool.swim"
        case .waterFitness, .waterPolo, .waterSports, .paddleSports, .surfingSports, .sailing:
            return "figure.water.fitness"

        // Strength Training
        case .strengthTraining, .functionalStrengthTraining, .traditionalStrengthTraining:
            return "figure.strengthtraining.traditional"
        case .coreTraining:
            return "figure.core.training"
        case .crossTraining:
            return "figure.cross.training"

        // Cardio
        case .cardio, .mixedCardio:
            return "figure.mixed.cardio"
        case .hiit:
            return "figure.highintensity.intervaltraining"
        case .elliptical:
            return "figure.elliptical"
        case .rowing:
            return "figure.rower"
        case .stairClimbing, .stairs:
            return "figure.stairs"
        case .stepTraining:
            return "figure.step.training"

        // Mind & Body
        case .yoga:
            return "figure.yoga"
        case .pilates:
            return "figure.pilates"
        case .flexibility:
            return "figure.flexibility"
        case .mindAndBody:
            return "figure.mind.and.body"
        case .taiChi:
            return "figure.tai.chi"
        case .preparationAndRecovery:
            return "figure.cooldown"

        // Dance
        case .dance, .danceInspiredTraining:
            return "figure.dance"
        case .barre:
            return "figure.barre"

        // Combat Sports
        case .boxing:
            return "figure.boxing"
        case .kickboxing:
            return "figure.kickboxing"
        case .martialArts:
            return "figure.martial.arts"
        case .wrestling:
            return "figure.wrestling"
        case .fencing:
            return "figure.fencing"

        // Ball Sports
        case .basketball:
            return "basketball.fill"
        case .soccer:
            return "soccerball"
        case .tennis, .tableTennis:
            return "tennis.racket"
        case .golf:
            return "figure.golf"
        case .baseball:
            return "baseball.fill"
        case .softball:
            return "softball"
        case .volleyball:
            return "volleyball.fill"
        case .americanFootball, .australianFootball, .rugby:
            return "football.fill"
        case .hockey:
            return "hockey.puck.fill"
        case .handball:
            return "figure.handball"
        case .badminton:
            return "figure.badminton"
        case .racquetball, .squash:
            return "figure.racquetball"
        case .bowling:
            return "figure.bowling"
        case .discSports:
            return "figure.disc.sports"

        // Winter Sports
        case .snowSports, .snowboarding:
            return "snowflake"
        case .crossCountrySkiing:
            return "figure.skiing.crosscountry"
        case .downhillSkiing:
            return "figure.skiing.downhill"
        case .skatingSports:
            return "figure.skating"
        case .curling:
            return "figure.curling"

        // Other Activities
        case .jumpRope:
            return "figure.jumprope"
        case .climbing:
            return "figure.climbing"
        case .archery:
            return "figure.archery"
        case .equestrianSports:
            return "figure.equestrian.sports"
        case .fishing:
            return "figure.fishing"
        case .hunting:
            return "figure.hunting"
        case .gymnastics:
            return "figure.gymnastics"
        case .lacrosse:
            return "sportscourt.fill"
        case .trackAndField:
            return "figure.track.and.field"
        case .fitnessGaming, .play:
            return "gamecontroller.fill"
        case .mixedMetabolicCardioTraining:
            return "figure.mixed.cardio"

        // Wheelchair
        case .wheelchairWalkPace, .wheelchairRunPace:
            return "figure.roll"

        // Default
        case .other:
            return "figure.walk"
        }
    }
}
