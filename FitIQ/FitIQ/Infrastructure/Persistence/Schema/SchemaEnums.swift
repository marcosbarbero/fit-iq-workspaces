//
//  SchemaEnums.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Shared enums used across schema versions
//

import Foundation

/// Unit system preference for displaying measurements
public enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric
    case imperial

    public var id: String { self.rawValue }
}

/// Activity level for categorizing user's daily activity
public enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case vigorous

    public var id: String { self.rawValue }
}

/// Physical attribute types that can be tracked
public enum PhysicalAttributeType: String, Codable, CaseIterable, Identifiable {
    case bodyMass
    case height
    case bodyFatPercentage
    case bmi

    public var id: String { self.rawValue }

    enum CodingKeys: String, CodingKey {
        case bodyMass = "weight"
        case height
        case bodyFatPercentage = "body_fat_percentage"
        case bmi
    }
}
