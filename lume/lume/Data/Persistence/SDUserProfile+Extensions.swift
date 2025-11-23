//
//  SDUserProfile+Extensions.swift
//  lume
//
//  Created by AI Assistant on 30/01/2025.
//

import Foundation
import SwiftData

// MARK: - SDUserProfile Domain Conversion

extension SDUserProfile {
    /// Convert to domain entity
    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            userId: userId,
            name: name,
            bio: bio,
            preferredUnitSystem: UnitSystem(rawValue: preferredUnitSystem) ?? .metric,
            languageCode: languageCode,
            dateOfBirth: dateOfBirth,
            createdAt: createdAt,
            updatedAt: updatedAt,
            biologicalSex: biologicalSex,
            heightCm: heightCm
        )
    }

    /// Create from domain entity
    static func from(_ profile: UserProfile) -> SDUserProfile {
        SDUserProfile(
            id: profile.id,
            userId: profile.userId,
            name: profile.name,
            bio: profile.bio,
            preferredUnitSystem: profile.preferredUnitSystem.rawValue,
            languageCode: profile.languageCode,
            dateOfBirth: profile.dateOfBirth,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
            biologicalSex: profile.biologicalSex,
            heightCm: profile.heightCm
        )
    }

    /// Update from domain entity
    func update(from profile: UserProfile) {
        self.name = profile.name
        self.bio = profile.bio
        self.preferredUnitSystem = profile.preferredUnitSystem.rawValue
        self.languageCode = profile.languageCode
        self.dateOfBirth = profile.dateOfBirth
        self.updatedAt = profile.updatedAt
        self.biologicalSex = profile.biologicalSex
        self.heightCm = profile.heightCm
    }
}

// MARK: - SDDietaryPreferences Domain Conversion

extension SDDietaryPreferences {
    /// Convert to domain entity
    func toDomain() -> DietaryActivityPreferences {
        DietaryActivityPreferences(
            id: id,
            userProfileId: userProfileId,
            allergies: allergies,
            dietaryRestrictions: dietaryRestrictions,
            foodDislikes: foodDislikes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create from domain entity
    static func from(_ preferences: DietaryActivityPreferences) -> SDDietaryPreferences {
        SDDietaryPreferences(
            id: preferences.id,
            userProfileId: preferences.userProfileId,
            allergies: preferences.allergies,
            dietaryRestrictions: preferences.dietaryRestrictions,
            foodDislikes: preferences.foodDislikes,
            createdAt: preferences.createdAt,
            updatedAt: preferences.updatedAt
        )
    }

    /// Update from domain entity
    func update(from preferences: DietaryActivityPreferences) {
        self.allergies = preferences.allergies
        self.dietaryRestrictions = preferences.dietaryRestrictions
        self.foodDislikes = preferences.foodDislikes
        self.updatedAt = preferences.updatedAt
    }
}
