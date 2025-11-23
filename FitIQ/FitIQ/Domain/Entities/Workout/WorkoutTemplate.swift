//
//  WorkoutTemplate.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Represents a workout template (reusable workout plan)
/// Maps to backend API /api/v1/workout-templates
public struct WorkoutTemplate: Identifiable, Equatable, Codable {
    /// Template ID (UUID from backend or local)
    public let id: UUID

    /// Owner user ID (nil for public/system templates)
    public let userID: String?

    /// Template name
    public var name: String

    /// Optional description
    public var description: String?

    /// Template category (e.g., "strength", "cardio", "flexibility")
    public var category: String?

    /// Difficulty level
    public var difficultyLevel: DifficultyLevel?

    /// Estimated duration in minutes
    public var estimatedDurationMinutes: Int?

    /// Whether template is publicly accessible
    public let isPublic: Bool

    /// Whether template is system-managed
    public let isSystem: Bool

    /// Template publication status
    public var status: TemplateStatus

    /// Number of exercises in template
    public let exerciseCount: Int

    /// Exercises in the template
    public var exercises: [TemplateExercise]

    /// Creation timestamp
    public let createdAt: Date

    /// Last update timestamp
    public let updatedAt: Date

    /// Local-only flag for favorites (not synced to backend)
    public var isFavorite: Bool = false

    /// Local-only flag for featured (not synced to backend)
    public var isFeatured: Bool = false

    /// Backend ID (nil if not synced)
    public var backendID: String?

    /// Sync status for Outbox Pattern
    public var syncStatus: SyncStatus

    public init(
        id: UUID = UUID(),
        userID: String? = nil,
        name: String,
        description: String? = nil,
        category: String? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        estimatedDurationMinutes: Int? = nil,
        isPublic: Bool = false,
        isSystem: Bool = false,
        status: TemplateStatus = .draft,
        exerciseCount: Int = 0,
        exercises: [TemplateExercise] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        isFeatured: Bool = false,
        backendID: String? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.description = description
        self.category = category
        self.difficultyLevel = difficultyLevel
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.isPublic = isPublic
        self.isSystem = isSystem
        self.status = status
        self.exerciseCount = exerciseCount
        self.exercises = exercises
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFavorite = isFavorite
        self.isFeatured = isFeatured
        self.backendID = backendID
        self.syncStatus = syncStatus
    }
}

/// Difficulty levels for workout templates
public enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case expert
}

/// Template publication status
public enum TemplateStatus: String, Codable {
    case draft
    case published
    case archived
}

/// Represents an exercise within a workout template
public struct TemplateExercise: Identifiable, Equatable, Codable {
    /// Template exercise ID
    public let id: UUID

    /// Parent template ID
    public let templateID: UUID

    /// Global exercise ID (if using system exercise)
    public let exerciseID: UUID?

    /// User custom exercise ID (if using custom exercise)
    public let userExerciseID: UUID?

    /// Exercise name (for display)
    public let exerciseName: String

    /// Position in template (for ordering)
    public let orderIndex: Int

    /// Training technique (e.g., "standard", "superset", "drop_set")
    public let technique: String?

    /// Technique-specific parameters (JSON object)
    public let techniqueDetails: [String: String]?

    /// Number of sets
    public let sets: Int?

    /// Target reps per set
    public let reps: Int?

    /// Target weight in kg
    public let weightKg: Double?

    /// Duration for timed exercises (seconds)
    public let durationSeconds: Int?

    /// Rest period between sets (seconds)
    public let restSeconds: Int?

    /// Reps in reserve (RIR)
    public let rir: Int?

    /// Tempo notation (e.g., "3-0-1-0")
    public let tempo: String?

    /// Exercise-specific notes
    public let notes: String?

    /// Creation timestamp
    public let createdAt: Date

    /// Backend ID (nil if not synced)
    public let backendID: String?

    public init(
        id: UUID = UUID(),
        templateID: UUID,
        exerciseID: UUID? = nil,
        userExerciseID: UUID? = nil,
        exerciseName: String,
        orderIndex: Int,
        technique: String? = nil,
        techniqueDetails: [String: String]? = nil,
        sets: Int? = nil,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int? = nil,
        rir: Int? = nil,
        tempo: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        backendID: String? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.exerciseID = exerciseID
        self.userExerciseID = userExerciseID
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.technique = technique
        self.techniqueDetails = techniqueDetails
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.rir = rir
        self.tempo = tempo
        self.notes = notes
        self.createdAt = createdAt
        self.backendID = backendID
    }
}

// MARK: - Convenience Extensions

extension WorkoutTemplate {
    /// Check if template is editable by user
    var isEditable: Bool {
        // Only user-created, non-system templates are editable
        return userID != nil && !isSystem
    }

    /// Check if template is user-created
    var isUserCreated: Bool {
        return userID != nil && !isSystem
    }

    /// Get readable category name
    var categoryDisplayName: String {
        return category?.capitalized ?? "General"
    }

    /// Get readable difficulty
    var difficultyDisplayName: String {
        return difficultyLevel?.rawValue.capitalized ?? "Unknown"
    }
}

// MARK: - Sharing Models

/// Professional type for template sharing
public enum ProfessionalType: String, Codable, CaseIterable {
    case personalTrainer = "personal_trainer"
    case nutritionist = "nutritionist"
    case physicalTherapist = "physical_therapist"
    case sportsCoach = "sports_coach"

    public var displayName: String {
        switch self {
        case .personalTrainer:
            return "Personal Trainer"
        case .nutritionist:
            return "Nutritionist"
        case .physicalTherapist:
            return "Physical Therapist"
        case .sportsCoach:
            return "Sports Coach"
        }
    }
}

/// Information about a user a template was shared with
public struct SharedWithUserInfo: Identifiable, Equatable, Codable {
    /// User ID
    public let userId: UUID

    /// Share record ID
    public let shareId: UUID

    /// Share timestamp
    public let sharedAt: Date

    public var id: UUID { shareId }

    public init(userId: UUID, shareId: UUID, sharedAt: Date) {
        self.userId = userId
        self.shareId = shareId
        self.sharedAt = sharedAt
    }
}

/// Response from sharing a template
public struct ShareWorkoutTemplateResponse: Equatable, Codable {
    /// Template ID
    public let templateId: UUID

    /// Template name
    public let templateName: String

    /// Users the template was shared with
    public let sharedWith: [SharedWithUserInfo]

    /// Total number of users shared with
    public let totalShared: Int

    /// Professional type
    public let professionalType: ProfessionalType

    public init(
        templateId: UUID,
        templateName: String,
        sharedWith: [SharedWithUserInfo],
        totalShared: Int,
        professionalType: ProfessionalType
    ) {
        self.templateId = templateId
        self.templateName = templateName
        self.sharedWith = sharedWith
        self.totalShared = totalShared
        self.professionalType = professionalType
    }
}

/// Information about a template shared with the user
public struct SharedTemplateInfo: Identifiable, Equatable, Codable {
    /// Template ID
    public let templateId: UUID

    /// Template name
    public let name: String

    /// Template description
    public let description: String?

    /// Template category
    public let category: String?

    /// Difficulty level
    public let difficultyLevel: DifficultyLevel?

    /// Estimated duration
    public let estimatedDurationMinutes: Int?

    /// Number of exercises
    public let exerciseCount: Int

    /// Name of professional who shared it
    public let professionalName: String

    /// Professional type
    public let professionalType: ProfessionalType

    /// Share timestamp
    public let sharedAt: Date

    /// Share notes
    public let notes: String?

    public var id: UUID { templateId }

    public init(
        templateId: UUID,
        name: String,
        description: String?,
        category: String?,
        difficultyLevel: DifficultyLevel?,
        estimatedDurationMinutes: Int?,
        exerciseCount: Int,
        professionalName: String,
        professionalType: ProfessionalType,
        sharedAt: Date,
        notes: String?
    ) {
        self.templateId = templateId
        self.name = name
        self.description = description
        self.category = category
        self.difficultyLevel = difficultyLevel
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.exerciseCount = exerciseCount
        self.professionalName = professionalName
        self.professionalType = professionalType
        self.sharedAt = sharedAt
        self.notes = notes
    }
}

/// Response from listing shared templates
public struct ListSharedTemplatesResponse: Equatable, Codable {
    /// Shared templates
    public let templates: [SharedTemplateInfo]

    /// Total count
    public let total: Int

    /// Page size
    public let limit: Int

    /// Page offset
    public let offset: Int

    /// Whether more results exist
    public let hasMore: Bool

    public init(
        templates: [SharedTemplateInfo],
        total: Int,
        limit: Int,
        offset: Int,
        hasMore: Bool
    ) {
        self.templates = templates
        self.total = total
        self.limit = limit
        self.offset = offset
        self.hasMore = hasMore
    }
}

/// Response from revoking a template share
public struct RevokeTemplateShareResponse: Equatable, Codable {
    /// Template ID
    public let templateId: UUID

    /// User ID the share was revoked from
    public let revokedFromUserId: UUID

    /// Revocation timestamp
    public let revokedAt: Date

    public init(
        templateId: UUID,
        revokedFromUserId: UUID,
        revokedAt: Date
    ) {
        self.templateId = templateId
        self.revokedFromUserId = revokedFromUserId
        self.revokedAt = revokedAt
    }
}

/// Response from copying a template
public struct CopyWorkoutTemplateResponse: Equatable, Codable {
    /// Original template ID
    public let originalTemplateId: UUID

    /// Newly created template copy
    public let newTemplate: WorkoutTemplate

    public init(
        originalTemplateId: UUID,
        newTemplate: WorkoutTemplate
    ) {
        self.originalTemplateId = originalTemplateId
        self.newTemplate = newTemplate
    }
}
