//
//  SchemaV1.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 1)

    @Model final class SDUserProfile {
        var id: UUID = UUID()
        var name: String = ""
        var bio: String?
        var preferredUnitSystem: UnitSystem = UnitSystem.metric
        var languageCode: String?
        var dateOfBirth: Date?
        var biologicalSex: String?

        @Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
        var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?

        @Relationship(deleteRule: .cascade, inverse: \SDPhysicalAttribute.userProfile)
        var bodyMetrics: [SDPhysicalAttribute]? = []

        @Relationship(deleteRule: .cascade, inverse: \SDActivitySnapshot.userProfile)
        var activitySnapshots: [SDActivitySnapshot]? = []

        var createdAt: Date = Date()
        var updatedAt: Date?

        var hasPerformedInitialHealthKitSync: Bool = false
        var lastSuccessfulDailySyncDate: Date?

        init(
            id: UUID = UUID(),
            name: String,
            bio: String?,
            preferredUnitSystem: UnitSystem = .metric,
            languageCode: String? = nil,
            dateOfBirth: Date? = nil,
            biologicalSex: String? = nil,
            dietaryAndActivityPreferences: SDDietaryAndActivityPreferences? = nil,
            bodyMetrics: [SDPhysicalAttribute]? = [],
            activitySnapshots: [SDActivitySnapshot]? = [],
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            hasPerformedInitialHealthKitSync: Bool = false,
            lastSuccessfulDailySyncDate: Date? = nil
        ) {
            self.id = id
            self.name = name
            self.bio = bio
            self.preferredUnitSystem = preferredUnitSystem
            self.languageCode = languageCode
            self.dateOfBirth = dateOfBirth
            self.biologicalSex = biologicalSex
            self.dietaryAndActivityPreferences = dietaryAndActivityPreferences
            self.bodyMetrics = bodyMetrics
            self.activitySnapshots = activitySnapshots
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
            self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
        }
    }

    @Model final class SDDietaryAndActivityPreferences {
        var allergies: [String]?
        var dietaryRestrictions: [String]?
        var foodDislikes: [String]?
        var createdAt: Date = Date()
        var updatedAt: Date?

        @Relationship
        var userProfile: SDUserProfile?

        init(
            allergies: [String]? = nil,
            dietaryRestrictions: [String]? = nil,
            foodDislikes: [String]? = nil,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            userProfile: SDUserProfile?
        ) {
            self.allergies = allergies
            self.dietaryRestrictions = dietaryRestrictions
            self.foodDislikes = foodDislikes
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.userProfile = userProfile
        }
    }

    @Model final class SDPhysicalAttribute {
        var id: UUID = UUID()

        var value: Double?
        var type: PhysicalAttributeType = PhysicalAttributeType.bodyMass

        var createdAt: Date = Date()
        var updatedAt: Date?

        var backendID: String?
        // THIS IS THE CRITICAL LINE: backendSyncedAt is now present
        var backendSyncedAt: Date?

        @Relationship
        var userProfile: SDUserProfile?

        init(
            id: UUID = UUID(),
            value: Double?,
            type: PhysicalAttributeType,
            createdAt: Date = Date(),
            updatedAt: Date? = Date(),
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,  // Initialize backendSyncedAt
            userProfile: SDUserProfile?
        ) {
            self.id = id
            self.value = value
            self.type = type
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.backendID = backendID
            self.backendSyncedAt = backendSyncedAt  // Assign backendSyncedAt
            self.userProfile = userProfile
        }
    }

    @Model final class SDActivitySnapshot {
        var id: UUID = UUID()
        var activeMinutes: Int?
        var activityLevel: ActivityLevel = ActivityLevel.sedentary
        var caloriesBurned: Double?
        var date: Date = Date()
        var distanceKm: Double?
        var heartRateAvg: Double?
        var steps: Int?
        var workoutDurationMinutes: Double?
        var workoutSessions: Int?
        var createdAt: Date = Date()
        var updatedAt: Date?
        var backendID: String?
        var backendSyncedAt: Date?

        @Relationship
        var userProfile: SDUserProfile?

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
            updatedAt: Date? = Date(),
            backendID: String? = nil,
            backendSyncedAt: Date? = nil,
            userProfile: SDUserProfile?
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
            self.backendID = backendID
            self.backendSyncedAt = backendSyncedAt
            self.userProfile = userProfile
        }
    }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV1.SDUserProfile.self,
            SchemaV1.SDDietaryAndActivityPreferences.self,
            SchemaV1.SDPhysicalAttribute.self,
            SchemaV1.SDActivitySnapshot.self,
        ]
    }
}
