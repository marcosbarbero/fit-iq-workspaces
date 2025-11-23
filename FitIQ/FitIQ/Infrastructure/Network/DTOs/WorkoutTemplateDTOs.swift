//
//  WorkoutTemplateDTOs.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

// MARK: - Response DTOs

/// Response DTO for workout template from API
public struct WorkoutTemplateResponse: Codable {
    let id: String
    let userId: String?
    let name: String
    let description: String?
    let category: String?
    let difficultyLevel: String?
    let estimatedDurationMinutes: Int?
    let isPublic: Bool
    let isSystem: Bool?
    let status: String?
    let exerciseCount: Int?
    let timesUsed: Int?
    let exercises: [TemplateExerciseResponse]?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case category
        case difficultyLevel = "difficulty_level"
        case estimatedDurationMinutes = "estimated_duration_minutes"
        case isPublic = "is_public"
        case isSystem = "is_system"
        case status
        case exerciseCount = "exercise_count"
        case timesUsed = "times_used"
        case exercises
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response DTO for template exercise from API
public struct TemplateExerciseResponse: Codable {
    let id: String
    let templateId: String
    let exerciseId: String?
    let userExerciseId: String?
    let exerciseName: String
    let orderIndex: Int
    let technique: String?
    let techniqueDetails: [String: AnyCodable]?  // Changed to handle any JSON type
    let sets: Int?
    let reps: Int?
    let weightKg: Double?
    let durationSeconds: Int?
    let restSeconds: Int?
    let rir: Int?
    let tempo: String?
    let notes: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case exerciseId = "exercise_id"
        case userExerciseId = "user_exercise_id"
        case exerciseName = "exercise_name"
        case orderIndex = "order_index"
        case technique
        case techniqueDetails = "technique_details"
        case sets
        case reps
        case weightKg = "weight_kg"
        case durationSeconds = "duration_seconds"
        case restSeconds = "rest_seconds"
        case rir
        case tempo
        case notes
        case createdAt = "created_at"
    }
}

/// Helper to decode any JSON value
public struct AnyCodable: Codable {
    let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        // Try to decode as a dictionary first
        if let dict = try? decoder.container(keyedBy: AnyCodingKey.self) {
            var result: [String: Any] = [:]
            for key in dict.allKeys {
                result[key.stringValue] = try dict.decode(AnyCodable.self, forKey: key).value
            }
            value = result
            return
        }

        // Try to decode as an array
        if var array = try? decoder.unkeyedContainer() {
            var result: [Any] = []
            while !array.isAtEnd {
                result.append(try array.decode(AnyCodable.self).value)
            }
            value = result
            return
        }

        // Fall back to single value container
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch value {
        case let dict as [String: Any]:
            var container = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, val) in dict {
                let codingKey = AnyCodingKey(stringValue: key)!
                try container.encode(AnyCodable(val), forKey: codingKey)
            }
        case let array as [Any]:
            var container = encoder.unkeyedContainer()
            for val in array {
                try container.encode(AnyCodable(val))
            }
        default:
            var container = encoder.singleValueContainer()
            switch value {
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let string as String:
                try container.encode(string)
            case let bool as Bool:
                try container.encode(bool)
            case is NSNull:
                try container.encodeNil()
            default:
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(codingPath: [], debugDescription: "Unsupported type"))
            }
        }
    }
}

/// Helper CodingKey for AnyCodable dictionary decoding
private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Paginated response for workout templates
/// Response for public templates endpoint (simplified - only templates and total)
public struct PublicTemplatesResponse: Codable {
    let templates: [WorkoutTemplateResponse]
    let total: Int
}

/// Response for authenticated templates endpoint (includes pagination metadata)
public struct PaginatedWorkoutTemplatesResponse: Codable {
    let templates: [WorkoutTemplateResponse]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case templates
        case total
        case limit
        case offset
        case hasMore = "has_more"
    }
}

// MARK: - Domain Conversion Extensions

extension WorkoutTemplateResponse {
    /// Convert API response to domain entity
    func toDomain() -> WorkoutTemplate {
        let templateUUID = UUID(uuidString: id) ?? UUID()

        let exercises: [TemplateExercise] =
            self.exercises?.compactMap { exerciseDTO -> TemplateExercise? in
                // Convert techniqueDetails from AnyCodable to String dictionary
                var techniqueDetailsConverted: [String: String]? = nil
                if let details = exerciseDTO.techniqueDetails {
                    techniqueDetailsConverted = details.mapValues { anyCodable in
                        if let intValue = anyCodable.value as? Int {
                            return String(intValue)
                        } else if let doubleValue = anyCodable.value as? Double {
                            return String(doubleValue)
                        } else if let stringValue = anyCodable.value as? String {
                            return stringValue
                        } else if let boolValue = anyCodable.value as? Bool {
                            return String(boolValue)
                        } else {
                            return ""
                        }
                    }
                }

                return TemplateExercise(
                    id: UUID(uuidString: exerciseDTO.id) ?? UUID(),
                    templateID: templateUUID,
                    exerciseID: exerciseDTO.exerciseId.flatMap { UUID(uuidString: $0) },
                    userExerciseID: exerciseDTO.userExerciseId.flatMap { UUID(uuidString: $0) },
                    exerciseName: exerciseDTO.exerciseName,
                    orderIndex: exerciseDTO.orderIndex,
                    technique: exerciseDTO.technique,
                    techniqueDetails: techniqueDetailsConverted,
                    sets: exerciseDTO.sets,
                    reps: exerciseDTO.reps,
                    weightKg: exerciseDTO.weightKg,
                    durationSeconds: exerciseDTO.durationSeconds,
                    restSeconds: exerciseDTO.restSeconds,
                    rir: exerciseDTO.rir,
                    tempo: exerciseDTO.tempo,
                    notes: exerciseDTO.notes,
                    createdAt: ISO8601DateFormatter().date(from: exerciseDTO.createdAt) ?? Date(),
                    backendID: nil
                )
            } ?? []

        return WorkoutTemplate(
            id: templateUUID,
            userID: userId,
            name: name,
            description: description,
            category: category,
            difficultyLevel: DifficultyLevel(rawValue: difficultyLevel ?? "") ?? .beginner,
            estimatedDurationMinutes: estimatedDurationMinutes,
            isPublic: isPublic,
            isSystem: isSystem ?? false,
            status: TemplateStatus(rawValue: status ?? "published") ?? .published,
            exerciseCount: exerciseCount ?? self.exercises?.count ?? 0,
            exercises: exercises,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: updatedAt) ?? Date()
        )
    }
}

extension PublicTemplatesResponse {
    /// Convert public templates response to array of domain entities
    func toDomain() -> [WorkoutTemplate] {
        return templates.map { $0.toDomain() }
    }
}

extension PaginatedWorkoutTemplatesResponse {
    /// Convert paginated response to array of domain entities
    func toDomain() -> [WorkoutTemplate] {
        return templates.map { $0.toDomain() }
    }
}
