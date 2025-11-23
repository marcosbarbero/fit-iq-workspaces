//
//  CreateWorkoutTemplateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import FitIQCore
import Foundation

/// Use case for creating a custom workout template
public protocol CreateWorkoutTemplateUseCase {
    /// Execute the use case to create a template
    /// - Parameters:
    ///   - name: Template name
    ///   - description: Optional description
    ///   - category: Category (e.g., "strength", "cardio")
    ///   - difficultyLevel: Difficulty level
    ///   - estimatedDurationMinutes: Estimated duration
    ///   - exercises: List of exercises in the template
    /// - Returns: The created template
    func execute(
        name: String,
        description: String?,
        category: String?,
        difficultyLevel: DifficultyLevel?,
        estimatedDurationMinutes: Int?,
        exercises: [TemplateExercise]
    ) async throws -> WorkoutTemplate
}

/// Implementation of CreateWorkoutTemplateUseCase
public final class CreateWorkoutTemplateUseCaseImpl: CreateWorkoutTemplateUseCase {
    private let repository: WorkoutTemplateRepositoryProtocol
    private let outboxRepository: OutboxRepositoryProtocol
    private let authManager: AuthManager

    init(
        repository: WorkoutTemplateRepositoryProtocol,
        outboxRepository: OutboxRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.repository = repository
        self.outboxRepository = outboxRepository
        self.authManager = authManager
    }

    public func execute(
        name: String,
        description: String? = nil,
        category: String? = nil,
        difficultyLevel: DifficultyLevel? = nil,
        estimatedDurationMinutes: Int? = nil,
        exercises: [TemplateExercise] = []
    ) async throws -> WorkoutTemplate {
        print("CreateWorkoutTemplateUseCase: Creating template '\(name)'")

        // Validate
        guard !name.isEmpty else {
            throw WorkoutTemplateError.invalidName
        }

        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw WorkoutTemplateError.notAuthenticated
        }

        // Create template entity with pending sync status
        let template = WorkoutTemplate(
            id: UUID(),
            userID: userID,
            name: name,
            description: description,
            category: category,
            difficultyLevel: difficultyLevel,
            estimatedDurationMinutes: estimatedDurationMinutes,
            isPublic: false,
            isSystem: false,
            status: .draft,
            exerciseCount: exercises.count,
            exercises: exercises,
            createdAt: Date(),
            updatedAt: Date(),
            isFavorite: false,
            isFeatured: false,
            backendID: nil,
            syncStatus: .pending
        )

        // Save locally first
        let savedTemplate = try await repository.save(template: template)

        print("CreateWorkoutTemplateUseCase: ✅ Saved template locally with ID: \(savedTemplate.id)")

        // ✅ OUTBOX PATTERN: Create outbox event for reliable background sync
        do {
            let _ = try await outboxRepository.createEvent(
                eventType: .workoutTemplate,
                entityID: savedTemplate.id,
                userID: userID,
                isNewRecord: true,
                metadata: .generic([
                    "name": name,
                    "category": category ?? "",
                    "exerciseCount": String(exercises.count),
                ]),
                priority: 5
            )
            print("CreateWorkoutTemplateUseCase: ✅ Created outbox event for template sync")
        } catch {
            print("CreateWorkoutTemplateUseCase: ⚠️ Failed to create outbox event: \(error)")
            // Continue - the template is saved locally, outbox processor will handle orphaned records
        }

        return savedTemplate
    }
}

/// Errors for workout template operations
public enum WorkoutTemplateError: Error, LocalizedError {
    case invalidName
    case notAuthenticated
    case templateNotFound
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Template name cannot be empty"
        case .notAuthenticated:
            return "User must be authenticated to create templates"
        case .templateNotFound:
            return "Template not found"
        case .notAuthorized:
            return "You do not have permission to modify this template"
        }
    }
}
