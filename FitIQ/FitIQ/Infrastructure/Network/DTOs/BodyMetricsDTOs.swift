//
//  BodyMetricsDTOs.swift
//  FitIQ
//
//  Created by Marcos Barbero on 16/10/2025.
//

import Foundation

// MARK: - New DTOs for Body Metrics

/// Represents a single metric input with a type and value.
/// This replaces individual fields like weightKg, bodyFatPercentage, etc.,
/// allowing for a flexible list of metrics in a snapshot.
struct MetricInput: Codable, Hashable {
    let type: MetricType
    let value: Double
    let unit: MetricUnit
    
    enum CodingKeys: String, CodingKey {
        case type = "metric_type"
        case value = "quantity"
        case unit
    }
}

enum MetricType: String, Codable, CaseIterable {
    case bodyMass = "weight"
    case height
    case bodyFatPercentage = "body_fat_percentage"
    case bmi
}

enum MetricUnit: String, Codable, CaseIterable {
    case kg
    case cm
    case percent = "%"
}

/// Request DTO for creating a new body metric snapshot.
/// This now uses a flexible list of `MetricInput` values.
struct CreateBodyMetricRequest: Codable {
    let recordedAt: Date
    let metrics: [MetricInput]

    enum CodingKeys: String, CodingKey {
        case recordedAt = "recorded_at"
        case metrics
    }
}

/// Response DTO representing a single body measurement snapshot,
/// containing a list of recorded metrics.
struct BodyMetricResponse: Codable, Identifiable {
    let id: UUID // Updated to UUID based on API spec (format: uuid)
    let userId: UUID // Updated to UUID based on API spec (format: uuid)
    let recordedAt: Date
    let metrics: [MetricInput] // Flexible list of MetricInput, replaces individual fields

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recordedAt = "recorded_at"
        case metrics
    }
}
