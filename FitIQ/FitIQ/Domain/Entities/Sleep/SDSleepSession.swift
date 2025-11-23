//
//  SleepSession.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Purpose: Domain models for sleep tracking (storage-agnostic)
//

import Foundation

// MARK: - Domain Models (for business logic layer)

/// Domain model for sleep session (storage-agnostic)
/// Used in business logic, converted to/from SwiftData models at repository boundary
struct SleepSession: Identifiable, Equatable {
    let id: UUID
    let userID: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let timeInBedMinutes: Int
    let totalSleepMinutes: Int
    let sleepEfficiency: Double
    let source: String?
    let sourceID: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date?
    var backendID: String?
    var syncStatus: SyncStatus
    let stages: [SleepStage]?

    /// Create new sleep session
    init(
        id: UUID = UUID(),
        userID: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        timeInBedMinutes: Int,
        totalSleepMinutes: Int,
        sleepEfficiency: Double,
        source: String? = nil,
        sourceID: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending,
        stages: [SleepStage]? = nil
    ) {
        self.id = id
        self.userID = userID
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.timeInBedMinutes = timeInBedMinutes
        self.totalSleepMinutes = totalSleepMinutes
        self.sleepEfficiency = sleepEfficiency
        self.source = source
        self.sourceID = sourceID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
        self.stages = stages
    }

    /// Convenience property: total time in bed as hours
    var timeInBedHours: Double {
        Double(timeInBedMinutes) / 60.0
    }

    /// Convenience property: total sleep time as hours
    var totalSleepHours: Double {
        Double(totalSleepMinutes) / 60.0
    }
}

/// Domain model for sleep stage
struct SleepStage: Identifiable, Equatable {
    let id: UUID
    let stage: SleepStageType
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int

    /// Create new sleep stage
    init(
        id: UUID = UUID(),
        stage: SleepStageType,
        startTime: Date,
        endTime: Date,
        durationMinutes: Int
    ) {
        self.id = id
        self.stage = stage
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
    }

    /// Convenience property: duration as hours
    var durationHours: Double {
        Double(durationMinutes) / 60.0
    }
}

/// Enum for sleep stage types (strictly matches HealthKit HKCategoryValueSleepAnalysis)
/// HealthKit values: inBed(0), asleep(1), awake(2), asleepCore(3), asleepDeep(4), asleepREM(5)
enum SleepStageType: String, CaseIterable, Codable {
    case inBed = "in_bed"
    case asleep = "asleep"  // Generic asleep (unspecified stage)
    case awake = "awake"
    case asleepCore = "core"  // Core/light sleep
    case asleepDeep = "deep"  // Deep sleep
    case asleepREM = "rem"  // REM sleep

    var displayName: String {
        switch self {
        case .inBed: return "In Bed"
        case .asleep: return "Asleep"
        case .awake: return "Awake"
        case .asleepCore: return "Core"
        case .asleepDeep: return "Deep"
        case .asleepREM: return "REM"
        }
    }

    var iconName: String {
        switch self {
        case .inBed: return "bed.double.fill"
        case .asleep: return "moon.stars.fill"
        case .awake: return "eye.fill"
        case .asleepCore: return "moon.fill"
        case .asleepDeep: return "moon.zzz.fill"
        case .asleepREM: return "brain.head.profile"
        }
    }

    /// Convert HealthKit HKCategoryValueSleepAnalysis to SleepStageType
    static func fromHealthKit(_ value: Int) -> SleepStageType {
        // HKCategoryValueSleepAnalysis raw values:
        // 0 = inBed, 1 = asleep (unspecified), 2 = awake
        // 3 = asleepCore, 4 = asleepDeep, 5 = asleepREM
        switch value {
        case 0: return .inBed
        case 1: return .asleep
        case 2: return .awake
        case 3: return .asleepCore
        case 4: return .asleepDeep
        case 5: return .asleepREM
        default: return .asleep
        }
    }

    /// Check if this stage counts as actual sleep (excludes awake and in_bed)
    var isActualSleep: Bool {
        switch self {
        case .asleep, .asleepCore, .asleepDeep, .asleepREM:
            return true
        case .inBed, .awake:
            return false
        }
    }
}
