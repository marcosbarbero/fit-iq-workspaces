//
//  WorkoutDTOs.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

// MARK: - Workout Request DTO

/// Request DTO for creating a workout
///
/// Maps to POST /api/v1/workouts request body per swagger spec v0.17.0+
///
/// **Backend Requirements (from swagger spec):**
/// - activity_type: Required, string (1-100 chars) - Type of workout (e.g., "Running", "Strength Training")
/// - title: Optional, nullable string (max 255 chars) - Custom workout title
/// - notes: Optional, nullable string (max 2000 chars) - Workout notes
/// - started_at: Required, RFC3339 date-time - When workout started
/// - ended_at: Optional, nullable RFC3339 date-time - When workout ended
/// - duration_minutes: Optional, nullable int (>= 0) - Duration in minutes
/// - calories_burned: Optional, nullable int (>= 0) - Calories burned during workout
/// - distance_meters: Optional, nullable float (>= 0) - Distance covered in meters
/// - intensity: Optional, nullable int (1-10) - RPE intensity scale (1=rest, 4=moderate, 7=hard, 10=all out)
struct CreateWorkoutRequest: Encodable {
    let activityType: WorkoutActivityType
    let title: String?
    let notes: String?
    let startedAt: String  // RFC3339 format
    let endedAt: String?   // RFC3339 format
    let durationMinutes: Int?
    let caloriesBurned: Int?
    let distanceMeters: Double?
    let intensity: Int?
    
    enum CodingKeys: String, CodingKey {
        case activityType = "activity_type"
        case title
        case notes
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case distanceMeters = "distance_meters"
        case intensity
    }
    
    // Custom encoding to exclude nil values from JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Always encode required fields (convert enum to raw string value for backend)
        try container.encode(activityType.rawValue, forKey: .activityType)
        try container.encode(startedAt, forKey: .startedAt)
        
        // Only encode optional fields if present
        if let title = title {
            try container.encode(title, forKey: .title)
        }
        if let notes = notes {
            try container.encode(notes, forKey: .notes)
        }
        if let endedAt = endedAt {
            try container.encode(endedAt, forKey: .endedAt)
        }
        if let durationMinutes = durationMinutes {
            try container.encode(durationMinutes, forKey: .durationMinutes)
        }
        if let caloriesBurned = caloriesBurned {
            try container.encode(caloriesBurned, forKey: .caloriesBurned)
        }
        if let distanceMeters = distanceMeters {
            try container.encode(distanceMeters, forKey: .distanceMeters)
        }
        if let intensity = intensity {
            try container.encode(intensity, forKey: .intensity)
        }
    }
}

// MARK: - Workout Response DTO

/// Response DTO for a single workout from backend
///
/// Maps to the workout data returned by:
/// - POST /api/v1/workouts (workout created response)
/// - GET /api/v1/workouts (as part of paginated response)
///
/// **Backend API Contract (from swagger spec v0.17.0+):**
/// - id: UUID string (server-assigned)
/// - user_id: UUID string (user who owns the workout)
/// - activity_type: string - Type of workout
/// - title: nullable string - Custom workout title
/// - notes: nullable string - Workout notes
/// - started_at: RFC3339 date-time - When workout started
/// - ended_at: nullable RFC3339 date-time - When workout ended
/// - duration_minutes: nullable int - Duration in minutes
/// - calories_burned: nullable int - Calories burned
/// - distance_meters: nullable float - Distance covered in meters
/// - intensity: nullable int (1-10) - RPE intensity scale
/// - created_at: RFC3339 date-time - When record was created
/// - updated_at: RFC3339 date-time - When record was last updated
struct WorkoutResponse: Decodable {
    let id: String
    let userId: String
    let activityType: String
    let title: String?
    let notes: String?
    let startedAt: String  // RFC3339 format
    let endedAt: String?   // RFC3339 format
    let durationMinutes: Int?
    let caloriesBurned: Int?
    let distanceMeters: Double?
    let intensity: Int?
    let createdAt: String  // RFC3339 format
    let updatedAt: String  // RFC3339 format
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case notes
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case caloriesBurned = "calories_burned"
        case distanceMeters = "distance_meters"
        case intensity
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Convert backend response DTO to domain WorkoutEntry
    func toDomain(localID: UUID, sourceID: String?) throws -> WorkoutEntry {
        // Parse dates from RFC3339 format
        guard let startedAt = ISO8601DateFormatter().date(from: startedAt) else {
            throw WorkoutDTOError.invalidDateFormat("started_at")
        }
        
        var endedAt: Date? = nil
        if let endedAtString = self.endedAt {
            endedAt = ISO8601DateFormatter().date(from: endedAtString)
        }
        
        // Parse activity type enum from string
        let activityTypeEnum = WorkoutActivityType(rawValue: activityType) ?? .other
        
        return WorkoutEntry(
            id: localID,
            userID: userId,
            activityType: activityTypeEnum,
            title: title,
            notes: notes,
            startedAt: startedAt,
            endedAt: endedAt,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            distanceMeters: distanceMeters,
            intensity: intensity,
            source: "HealthKit",  // Assume HealthKit if synced from app
            sourceID: sourceID,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: updatedAt),
            backendID: id,
            syncStatus: .synced  // Just synced successfully
        )
    }
}

// MARK: - Workout List Response (for future pagination support)

/// Response DTO for paginated workout list from GET /api/v1/workouts
///
/// Maps to PaginatedWorkoutsResponse in swagger spec
struct WorkoutListResponse: Decodable {
    let workouts: [WorkoutResponse]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case workouts
        case total
        case limit
        case offset
        case hasMore = "has_more"
    }
}

// MARK: - Errors

enum WorkoutDTOError: Error, LocalizedError {
    case invalidDateFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidDateFormat(let field):
            return "Invalid date format for field: \(field)"
        }
    }
}
