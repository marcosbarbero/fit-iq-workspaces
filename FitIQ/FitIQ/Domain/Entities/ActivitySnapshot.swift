// Domain/Entities/ActivitySnapshot.swift
import Foundation

/// Represents a single day's activity summary in the domain.
/// This entity is independent of any specific storage mechanism (e.g., SwiftData, HealthKit, API DTOs).
public struct ActivitySnapshot: Identifiable, Equatable {
    public let id: UUID
    let activeMinutes: Int?
    let activityLevel: ActivityLevel
    let caloriesBurned: Double?
    let date: Date
    let distanceKm: Double?
    let heartRateAvg: Double?
    let steps: Int?
    let workoutDurationMinutes: Double?
    let workoutSessions: Int?
    let createdAt: Date
    let updatedAt: Date?
    public var backendID: String?

    init(
        id: UUID = UUID(),
        activeMinutes: Int? = nil,
        activityLevel: ActivityLevel,
        caloriesBurned: Double? = nil,
        date: Date,
        distanceKm: Double? = nil,
        heartRateAvg: Double? = nil,
        steps: Int? = nil,
        workoutDurationMinutes: Double? = nil,
        workoutSessions: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        backendID: String? = nil // NEW: Initialize backendID
    ) {
        self.id = id
        self.activeMinutes = activeMinutes
        self.activityLevel = activityLevel
        self.caloriesBurned = caloriesBurned
        self.date = date
        self.distanceKm = distanceKm
        self.heartRateAvg = heartRateAvg
        self.steps = steps
        self.workoutDurationMinutes = workoutDurationMinutes
        self.workoutSessions = workoutSessions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendID = backendID // Assign backendID
    }
}

