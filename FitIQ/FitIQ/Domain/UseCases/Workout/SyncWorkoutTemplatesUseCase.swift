//
//  SyncWorkoutTemplatesUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Use case for syncing workout templates from backend
/// Fetches public templates from API and stores them locally
public protocol SyncWorkoutTemplatesUseCase {
    /// Execute the use case to sync templates from backend
    /// - Returns: Number of templates synced
    func execute() async throws -> Int
}

/// Implementation of SyncWorkoutTemplatesUseCase
public final class SyncWorkoutTemplatesUseCaseImpl: SyncWorkoutTemplatesUseCase {
    private let repository: WorkoutTemplateRepositoryProtocol
    private let apiClient: WorkoutTemplateAPIClientProtocol

    public init(
        repository: WorkoutTemplateRepositoryProtocol,
        apiClient: WorkoutTemplateAPIClientProtocol
    ) {
        self.repository = repository
        self.apiClient = apiClient
    }

    public func execute() async throws -> Int {
        print("SyncWorkoutTemplatesUseCase: Starting template sync from backend...")

        var allTemplates: [WorkoutTemplate] = []
        var offset = 0
        let limit = 100
        var hasMore = true

        // Fetch all templates using pagination (exercises are included in response)
        print("SyncWorkoutTemplatesUseCase: Fetching templates with exercises...")
        while hasMore {
            print(
                "SyncWorkoutTemplatesUseCase: Fetching batch - offset: \(offset), limit: \(limit)")

            let batch = try await apiClient.fetchPublicTemplates(
                category: nil,
                difficulty: nil,
                limit: limit,
                offset: offset
            )

            if batch.isEmpty {
                hasMore = false
            } else {
                allTemplates.append(contentsOf: batch)
                offset += batch.count

                // Log exercise counts for debugging
                for template in batch {
                    print("  - '\(template.name)': \(template.exercises.count) exercises")
                }

                // If we received fewer templates than the limit, we've reached the end
                if batch.count < limit {
                    hasMore = false
                }
            }

            print(
                "SyncWorkoutTemplatesUseCase: Fetched \(batch.count) templates (total so far: \(allTemplates.count))"
            )
        }

        print(
            "SyncWorkoutTemplatesUseCase: Completed fetching all \(allTemplates.count) public templates from API"
        )

        // Delete existing system templates to avoid duplicates
        try await repository.deleteAllSystemTemplates()

        // Save all templates with exercises locally
        try await repository.batchSave(templates: allTemplates)

        print(
            "SyncWorkoutTemplatesUseCase: ✅ Successfully synced \(allTemplates.count) templates"
        )

        return allTemplates.count
    }
}

/// Protocol defining workout template API operations
public protocol WorkoutTemplateAPIClientProtocol {
    /// Fetch public workout templates
    func fetchPublicTemplates(
        category: String?,
        difficulty: DifficultyLevel?,
        limit: Int,
        offset: Int
    ) async throws -> [WorkoutTemplate]

    /// Fetch user's owned templates
    func fetchOwnedTemplates(
        category: String?,
        difficulty: DifficultyLevel?,
        limit: Int,
        offset: Int
    ) async throws -> [WorkoutTemplate]

    /// Create a new workout template
    func createTemplate(request: CreateWorkoutTemplateRequest) async throws -> WorkoutTemplate

    /// Update a workout template
    func updateTemplate(id: UUID, request: UpdateWorkoutTemplateRequest) async throws
        -> WorkoutTemplate

    /// Delete a workout template
    func deleteTemplate(id: UUID) async throws

    /// Fetch a specific template by ID
    func fetchTemplate(id: UUID) async throws -> WorkoutTemplate

    // MARK: - Sharing Operations

    /// Share a template with multiple users (bulk sharing)
    /// - Parameters:
    ///   - id: Template ID
    ///   - userIds: List of user IDs to share with
    ///   - professionalType: Professional type for categorization
    ///   - notes: Optional notes about the share
    /// - Returns: Share response with details of all users shared with
    func shareTemplate(
        id: UUID,
        userIds: [UUID],
        professionalType: ProfessionalType,
        notes: String?
    ) async throws -> ShareWorkoutTemplateResponse

    /// Revoke template share from a specific user
    /// - Parameters:
    ///   - templateId: Template ID
    ///   - userId: User ID to revoke access from
    /// - Returns: Revocation response
    func revokeTemplateShare(
        templateId: UUID,
        userId: UUID
    ) async throws -> RevokeTemplateShareResponse

    /// Fetch templates shared with the authenticated user
    /// - Parameters:
    ///   - professionalType: Optional filter by professional type
    ///   - limit: Number of templates to return
    ///   - offset: Number of templates to skip
    /// - Returns: List of shared templates response
    func fetchSharedWithMeTemplates(
        professionalType: ProfessionalType?,
        limit: Int,
        offset: Int
    ) async throws -> ListSharedTemplatesResponse

    /// Copy a template to user's personal library
    /// - Parameters:
    ///   - id: Template ID to copy
    ///   - newName: Optional new name for the copy
    /// - Returns: Copy response with the new template
    func copyTemplate(
        id: UUID,
        newName: String?
    ) async throws -> CopyWorkoutTemplateResponse
}

/// Request DTO for creating workout template
public struct CreateWorkoutTemplateRequest: Codable {
    public let name: String
    public let description: String?
    public let category: String?
    public let difficultyLevel: String?
    public let estimatedDurationMinutes: Int?
    public let exercises: [TemplateExerciseRequest]?

    public init(
        name: String,
        description: String? = nil,
        category: String? = nil,
        difficultyLevel: String? = nil,
        estimatedDurationMinutes: Int? = nil,
        exercises: [TemplateExerciseRequest]? = nil
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.difficultyLevel = difficultyLevel
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.exercises = exercises
    }
}

/// Request DTO for template exercise
public struct TemplateExerciseRequest: Codable {
    public let exerciseId: String?
    public let userExerciseId: String?
    public let orderIndex: Int
    public let technique: String?
    public let techniqueDetails: [String: String]?
    public let sets: Int?
    public let reps: Int?
    public let weightKg: Double?
    public let durationSeconds: Int?
    public let restSeconds: Int?
    public let rir: Int?
    public let tempo: String?
    public let notes: String?

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case userExerciseId = "user_exercise_id"
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
    }
}

/// Request DTO for updating workout template
public struct UpdateWorkoutTemplateRequest: Codable {
    public let name: String?
    public let description: String?
    public let category: String?
    public let difficultyLevel: String?
    public let estimatedDurationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case category
        case difficultyLevel = "difficulty_level"
        case estimatedDurationMinutes = "estimated_duration_minutes"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        category: String? = nil,
        difficultyLevel: String? = nil,
        estimatedDurationMinutes: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.category = category
        self.difficultyLevel = difficultyLevel
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }
}
