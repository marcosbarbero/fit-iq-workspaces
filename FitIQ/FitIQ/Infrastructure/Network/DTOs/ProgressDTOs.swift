//
//  ProgressDTOs.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//  Part of Biological Sex and Height Improvements
//

import Foundation

// MARK: - Progress Log Request

/// Request DTO for logging a single progress metric
///
/// Maps to POST /api/v1/progress request body
///
/// **Backend Requirements:**
/// - type: Required (e.g., "height", "weight", "steps")
/// - quantity: Required (must be >= 0)
/// - logged_at: Optional (RFC3339 date-time format, defaults to now)
/// - notes: Optional (max 500 characters)
struct ProgressLogRequest: Encodable {
    let type: String
    let quantity: Double
    let loggedAt: String?  // RFC3339 format (e.g., "2024-01-15T08:00:00Z")
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case type
        case quantity
        case loggedAt = "logged_at"
        case notes
    }

    // Custom encoding to exclude nil values from JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Always encode required fields
        try container.encode(type, forKey: .type)
        try container.encode(quantity, forKey: .quantity)

        // Only encode optional fields if present
        if let loggedAt = loggedAt {
            try container.encode(loggedAt, forKey: .loggedAt)
        }
        if let notes = notes {
            try container.encode(notes, forKey: .notes)
        }
    }
}

// MARK: - Progress List Response

/// Response DTO for paginated progress entries from GET /api/v1/progress
///
/// Maps to the response body returned by GET /api/v1/progress.
/// This endpoint now supports filtering, date ranges, and pagination,
/// making it the unified endpoint for both current and historical queries.
///
/// **Backend API Contract:**
/// - entries: Array of progress entry objects matching the query
/// - total: Total number of entries that match the query filters
/// - limit: Number of results per page (default 20, max 100)
/// - offset: Pagination offset for the current page
///
/// **Migration Note:**
/// The /progress/history endpoint has been DEPRECATED and removed from the API spec.
/// All progress queries (current and historical) now use GET /api/v1/progress
/// with appropriate query parameters (type, from, to, limit, offset).
///
/// **Example Query Parameters:**
/// - Get latest weight: `?type=weight&limit=1`
/// - Get all weight history: `?type=weight&from=2024-01-01&to=2024-12-31&limit=100`
/// - Get all metrics from last 30 days: `?from=2024-11-01&to=2024-12-01&limit=100`
struct ProgressListResponse: Decodable {
    let entries: [ProgressEntryResponse]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Progress Entry Response

/// Response DTO for a single progress entry
///
/// Maps to the progress entry data returned by:
/// - POST /api/v1/progress (direct response when creating an entry)
/// - GET /api/v1/progress (as part of ProgressListResponse.entries array)
///
/// **Backend API Contract:**
/// - id: UUID string (server-assigned unique identifier)
/// - type: Metric type string (e.g., "weight", "steps", "height", "body_fat_percentage")
/// - quantity: Numeric value (must be >= 0)
/// - date: RFC3339 date-time string (e.g., "2024-01-15T08:00:00Z")
/// - notes: Optional notes string (max 500 characters)
///
/// **Supported Metric Types:**
/// Physical: weight, height, body_fat_percentage, bmi
/// Activity: steps, calories_out, distance_km, active_minutes
/// Wellness: sleep_hours, water_liters, resting_heart_rate
/// Nutrition: calories_in, protein_g, carbs_g, fat_g
struct ProgressEntryResponse: Decodable {
    let id: String
    let type: String
    let quantity: Double
    let date: String  // RFC3339 date-time format (e.g., "2024-01-15T08:00:00Z")
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case quantity
        case date
        case notes
    }
}

// MARK: - DTO to Domain Mapping

extension ProgressEntryResponse {
    /// Converts the progress entry DTO to domain model
    ///
    /// Maps backend RFC3339 date-time string to Swift Date objects and metric type string to enum.
    /// Creates a new local UUID for the entry and stores the backend ID.
    ///
    /// - Parameter userID: The current user's ID (backend doesn't return this in the response)
    /// - Returns: ProgressEntry domain model
    /// - Throws: DTOConversionError if date parsing fails or metric type is invalid
    func toDomain(userID: String) throws -> ProgressEntry {
        // Parse metric type
        guard let metricType = ProgressMetricType(rawValue: type) else {
            throw ProgressDTOConversionError.invalidMetricType(type)
        }

        // Parse date (RFC3339 format: "2024-01-15T08:00:00Z")
        guard let entryDateTime = try? date.toDateFromISO8601() else {
            throw ProgressDTOConversionError.invalidDateFormat(date)
        }

        // Extract date component (for date field)
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: entryDateTime)
        guard let entryDate = calendar.date(from: dateComponents) else {
            throw ProgressDTOConversionError.invalidDateFormat(date)
        }

        // Extract time component (for time field) - format as HH:MM:SS
        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second], from: entryDateTime)
        let timeString = String(
            format: "%02d:%02d:%02d",
            timeComponents.hour ?? 0,
            timeComponents.minute ?? 0,
            timeComponents.second ?? 0
        )

        // Use the provided user ID (backend doesn't return user_id in this endpoint)

        // Use the parsed date-time for created/updated timestamps
        let now = entryDateTime

        // Create domain model with new local UUID and store backend ID
        return ProgressEntry(
            id: UUID(),  // Generate new local UUID
            userID: userID,
            type: metricType,
            quantity: quantity,
            date: entryDate,
            time: timeString,
            notes: notes,
            createdAt: now,
            updatedAt: now,
            backendID: id,  // Store backend ID
            syncStatus: .synced  // Coming from backend, so it's already synced
        )
    }
}

// MARK: - DTO Conversion Errors

enum ProgressDTOConversionError: Error, LocalizedError {
    case invalidDateFormat(String)
    case missingRequiredField(String)
    case invalidDataType(String)
    case invalidMetricType(String)

    var errorDescription: String? {
        switch self {
        case .invalidDateFormat(let dateString):
            return "Invalid date format: \(dateString)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidDataType(let message):
            return "Invalid data type: \(message)"
        case .invalidMetricType(let typeString):
            return "Invalid metric type: \(typeString)"
        }
    }
}
