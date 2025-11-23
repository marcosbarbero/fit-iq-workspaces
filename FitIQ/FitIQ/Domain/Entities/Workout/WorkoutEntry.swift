//
//  WorkoutEntry.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Represents a workout/exercise session in the domain layer
/// This entity is storage-agnostic and represents workout sessions from HealthKit or manual entry
/// Supports local-first architecture with backend synchronization via Outbox Pattern
public struct WorkoutEntry: Identifiable, Equatable {
    /// Local UUID for the entry (used for local storage)
    public let id: UUID
    
    /// User ID who owns this workout
    let userID: String
    
    /// Activity type - strongly typed enum that maps to HealthKit workout types
    let activityType: WorkoutActivityType
    
    /// Optional title for the workout session
    let title: String?
    
    /// Optional notes about the workout
    let notes: String?
    
    /// When the workout started
    let startedAt: Date
    
    /// When the workout ended (optional if still in progress)
    let endedAt: Date?
    
    /// Duration in minutes
    let durationMinutes: Int?
    
    /// Calories burned during the workout
    let caloriesBurned: Int?
    
    /// Distance covered in meters (for cardio activities)
    let distanceMeters: Double?
    
    /// Workout intensity on 1-10 RPE scale (Rate of Perceived Exertion)
    /// 1=rest, 4=moderate, 7=hard, 10=all out
    let intensity: Int?
    
    /// Source of the workout data (e.g., "HealthKit", "Manual")
    let source: String
    
    /// Unique identifier from the source system (e.g., HealthKit UUID)
    /// Used for deduplication when importing from external sources
    let sourceID: String?
    
    /// When this entry was created locally
    let createdAt: Date
    
    /// When this entry was last updated locally
    let updatedAt: Date?
    
    /// Backend-assigned ID (populated after successful sync)
    public var backendID: String?
    
    /// Sync status for backend synchronization
    public var syncStatus: SyncStatus
    
    init(
        id: UUID = UUID(),
        userID: String,
        activityType: WorkoutActivityType,
        title: String? = nil,
        notes: String? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        durationMinutes: Int? = nil,
        caloriesBurned: Int? = nil,
        distanceMeters: Double? = nil,
        intensity: Int? = nil,
        source: String = "HealthKit",
        sourceID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.userID = userID
        self.activityType = activityType
        self.title = title
        self.notes = notes
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.distanceMeters = distanceMeters
        self.intensity = intensity
        self.source = source
        self.sourceID = sourceID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID
        self.syncStatus = syncStatus
    }
}

// MARK: - Convenience Extensions

extension WorkoutEntry {
    /// Check if workout is from HealthKit
    var isFromHealthKit: Bool {
        source.lowercased() == "healthkit"
    }
    
    /// Check if workout is manually logged
    var isManual: Bool {
        source.lowercased() == "manual"
    }
    
    /// Check if workout is currently in progress
    var isInProgress: Bool {
        endedAt == nil
    }
    
    /// Get computed duration if not explicitly set
    var computedDurationMinutes: Int? {
        if let durationMinutes = durationMinutes {
            return durationMinutes
        }
        
        guard let endedAt = endedAt else {
            return nil
        }
        
        let duration = endedAt.timeIntervalSince(startedAt)
        return Int(duration / 60.0)
    }
}
