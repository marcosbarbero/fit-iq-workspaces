//
//  SwiftDataWorkoutTemplateRepository.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation
import SwiftData

/// SwiftData implementation of WorkoutTemplateRepositoryProtocol
/// Replaces the UserDefaults-based implementation for proper persistence
final class SwiftDataWorkoutTemplateRepository: WorkoutTemplateRepositoryProtocol {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - WorkoutTemplateRepositoryProtocol Implementation

    func save(template: WorkoutTemplate) async throws -> WorkoutTemplate {
        print("SwiftDataWorkoutTemplateRepository: Saving template '\(template.name)'")

        // Check if template already exists (fetch SDWorkoutTemplate directly)
        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.id == template.id }
        )
        descriptor.fetchLimit = 1
        let existingSDTemplate = try modelContext.fetch(descriptor).first

        if let existing = existingSDTemplate {
            // Update existing template
            existing.name = template.name
            existing.templateDescription = template.description
            existing.category = template.category
            existing.difficultyLevel = template.difficultyLevel?.rawValue
            existing.estimatedDurationMinutes = template.estimatedDurationMinutes
            existing.status = template.status.rawValue
            existing.isFavorite = template.isFavorite
            existing.isFeatured = template.isFeatured
            existing.updatedAt = template.updatedAt
            existing.backendID = template.backendID
            existing.syncStatus = template.syncStatus.rawValue

            // Update exercises
            // Remove old exercises
            if let oldExercises = existing.exercises {
                for exercise in oldExercises {
                    modelContext.delete(exercise)
                }
            }

            // Add new exercises
            let sdExercises = template.exercises.map { exercise in
                let sdExercise = SDTemplateExercise(
                    id: exercise.id,
                    template: existing,
                    exerciseID: exercise.exerciseID?.uuidString,
                    userExerciseID: exercise.userExerciseID?.uuidString,
                    exerciseName: exercise.exerciseName,
                    orderIndex: exercise.orderIndex,
                    technique: exercise.technique,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weightKg: exercise.weightKg,
                    durationSeconds: exercise.durationSeconds,
                    restSeconds: exercise.restSeconds,
                    notes: exercise.notes,
                    createdAt: exercise.createdAt,
                    backendID: exercise.backendID
                )
                modelContext.insert(sdExercise)
                return sdExercise
            }
            existing.exercises = sdExercises

        } else {
            // Create new template
            let sdTemplate = SDWorkoutTemplate(
                id: template.id,
                userProfile: nil,  // Will be set by relationship if needed
                name: template.name,
                templateDescription: template.description,
                category: template.category,
                difficultyLevel: template.difficultyLevel?.rawValue,
                estimatedDurationMinutes: template.estimatedDurationMinutes,
                isPublic: template.isPublic,
                isSystem: template.isSystem,
                status: template.status.rawValue,
                exerciseCount: template.exerciseCount,
                timesUsed: 0,
                isFavorite: template.isFavorite,
                isFeatured: template.isFeatured,
                createdAt: template.createdAt,
                updatedAt: template.updatedAt,
                backendID: template.backendID,
                syncStatus: template.syncStatus.rawValue,
                exercises: []
            )

            modelContext.insert(sdTemplate)

            // Add exercises
            for exercise in template.exercises {
                let sdExercise = SDTemplateExercise(
                    id: exercise.id,
                    template: sdTemplate,
                    exerciseID: exercise.exerciseID?.uuidString,
                    userExerciseID: exercise.userExerciseID?.uuidString,
                    exerciseName: exercise.exerciseName,
                    orderIndex: exercise.orderIndex,
                    technique: exercise.technique,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weightKg: exercise.weightKg,
                    durationSeconds: exercise.durationSeconds,
                    restSeconds: exercise.restSeconds,
                    notes: exercise.notes,
                    createdAt: exercise.createdAt,
                    backendID: exercise.backendID
                )
                modelContext.insert(sdExercise)
            }

            // Link user profile if userID provided
            if let userID = template.userID, let userUUID = UUID(uuidString: userID) {
                let userDescriptor = FetchDescriptor<SDUserProfile>(
                    predicate: #Predicate { $0.id == userUUID }
                )
                if let userProfile = try? modelContext.fetch(userDescriptor).first {
                    sdTemplate.userProfile = userProfile
                }
            }
        }

        try modelContext.save()

        print("SwiftDataWorkoutTemplateRepository: ✅ Saved template with ID: \(template.id)")

        return template
    }

    func fetchAll(
        source: TemplateSource?,
        category: String?,
        difficulty: DifficultyLevel?
    ) async throws -> [WorkoutTemplate] {
        print(
            "SwiftDataWorkoutTemplateRepository: Fetching templates - source: \(source?.rawValue ?? "all")"
        )

        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        // Build predicate based on filters
        var predicates: [Predicate<SDWorkoutTemplate>] = []

        // Filter by source
        if let source = source {
            switch source {
            case .owned:
                predicates.append(#Predicate { $0.userProfile != nil && !$0.isSystem })
            case .system:
                predicates.append(#Predicate { $0.isSystem || $0.isPublic })
            case .shared:
                // For now, no shared templates - return empty
                return []
            }
        }

        // Filter by category (case-insensitive comparison done in memory)
        if let category = category {
            // Don't use predicate for category - will filter in memory below
        }

        // Filter by difficulty
        if let difficulty = difficulty {
            let difficultyRaw = difficulty.rawValue
            predicates.append(#Predicate { $0.difficultyLevel == difficultyRaw })
        }

        // Use single predicate or fetch all and filter in memory
        if predicates.count == 1 {
            descriptor.predicate = predicates[0]
        }
        // For multiple predicates, fetch all and filter in memory

        var sdTemplates = try modelContext.fetch(descriptor)

        // Apply additional filters in memory if needed
        // Always apply category filter in memory (can't use lowercased() in predicates)
        if let category = category {
            let categoryLower = category.lowercased()
            sdTemplates = sdTemplates.filter { template in
                guard let templateCategory = template.category else { return false }
                return templateCategory.lowercased() == categoryLower
            }
        }

        // Apply source filter in memory if multiple predicates or if category was filtered
        if predicates.count > 1 || category != nil {
            if let source = source {
                switch source {
                case .owned:
                    sdTemplates = sdTemplates.filter { $0.userProfile != nil && !$0.isSystem }
                case .system:
                    sdTemplates = sdTemplates.filter { $0.isSystem || $0.isPublic }
                case .shared:
                    sdTemplates = []
                }
            }

            // Apply difficulty filter in memory if needed
            if let difficulty = difficulty {
                let difficultyRaw = difficulty.rawValue
                sdTemplates = sdTemplates.filter { $0.difficultyLevel == difficultyRaw }
            }
        }

        let templates = sdTemplates.map { $0.toDomain() }

        print("SwiftDataWorkoutTemplateRepository: ✅ Found \(templates.count) templates")

        return templates
    }

    func fetchByID(_ id: UUID) async throws -> WorkoutTemplate? {
        print("SwiftDataWorkoutTemplateRepository: Fetching template with ID: \(id)")

        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    func update(template: WorkoutTemplate) async throws -> WorkoutTemplate {
        print("SwiftDataWorkoutTemplateRepository: Updating template '\(template.name)'")

        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.id == template.id }
        )
        descriptor.fetchLimit = 1

        guard let sdTemplate = try modelContext.fetch(descriptor).first else {
            throw WorkoutTemplateRepositoryError.notFound
        }

        // Update properties
        sdTemplate.name = template.name
        sdTemplate.templateDescription = template.description
        sdTemplate.category = template.category
        sdTemplate.difficultyLevel = template.difficultyLevel?.rawValue
        sdTemplate.estimatedDurationMinutes = template.estimatedDurationMinutes
        sdTemplate.isPublic = template.isPublic
        sdTemplate.isSystem = template.isSystem
        sdTemplate.status = template.status.rawValue
        sdTemplate.exerciseCount = template.exerciseCount

        sdTemplate.isFavorite = template.isFavorite
        sdTemplate.isFeatured = template.isFeatured
        sdTemplate.updatedAt = Date()
        sdTemplate.backendID = template.backendID
        sdTemplate.syncStatus = template.syncStatus.rawValue

        // Update exercises
        // Remove old exercises
        if let oldExercises = sdTemplate.exercises {
            for exercise in oldExercises {
                modelContext.delete(exercise)
            }
        }

        // Add new exercises
        let sdExercises = template.exercises.map { exercise in
            let sdExercise = SDTemplateExercise(
                id: exercise.id,
                template: sdTemplate,
                exerciseID: exercise.exerciseID?.uuidString,
                userExerciseID: exercise.userExerciseID?.uuidString,
                exerciseName: exercise.exerciseName,
                orderIndex: exercise.orderIndex,
                technique: exercise.technique,
                sets: exercise.sets,
                reps: exercise.reps,
                weightKg: exercise.weightKg,
                durationSeconds: exercise.durationSeconds,
                restSeconds: exercise.restSeconds,
                notes: exercise.notes,
                createdAt: exercise.createdAt,
                backendID: exercise.backendID
            )
            modelContext.insert(sdExercise)
            return sdExercise
        }
        sdTemplate.exercises = sdExercises

        try modelContext.save()

        print("SwiftDataWorkoutTemplateRepository: ✅ Updated template")

        return sdTemplate.toDomain()
    }

    func delete(id: UUID) async throws {
        print("SwiftDataWorkoutTemplateRepository: Deleting template with ID: \(id)")

        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let sdTemplate = try modelContext.fetch(descriptor).first else {
            throw WorkoutTemplateRepositoryError.notFound
        }

        modelContext.delete(sdTemplate)
        try modelContext.save()

        print("SwiftDataWorkoutTemplateRepository: ✅ Deleted template")
    }

    func toggleFavorite(id: UUID) async throws {
        print("SwiftDataWorkoutTemplateRepository: Toggling favorite for template: \(id)")

        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let sdTemplate = try modelContext.fetch(descriptor).first else {
            throw WorkoutTemplateRepositoryError.notFound
        }

        sdTemplate.isFavorite.toggle()
        try modelContext.save()

        print("SwiftDataWorkoutTemplateRepository: ✅ Toggled favorite to \(sdTemplate.isFavorite)")
    }

    func toggleFeatured(id: UUID) async throws {
        print("SwiftDataWorkoutTemplateRepository: Toggling featured for template: \(id)")

        var descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        guard let sdTemplate = try modelContext.fetch(descriptor).first else {
            throw WorkoutTemplateRepositoryError.notFound
        }

        sdTemplate.isFeatured.toggle()
        try modelContext.save()

        print("SwiftDataWorkoutTemplateRepository: ✅ Toggled featured to \(sdTemplate.isFeatured)")
    }

    func batchSave(templates: [WorkoutTemplate]) async throws {
        print("SwiftDataWorkoutTemplateRepository: Batch saving \(templates.count) templates")

        for template in templates {
            print("  - Saving '\(template.name)' with \(template.exercises.count) exercises")
            // Check if exists
            var descriptor = FetchDescriptor<SDWorkoutTemplate>(
                predicate: #Predicate { $0.id == template.id }
            )
            descriptor.fetchLimit = 1
            let existing = try modelContext.fetch(descriptor).first

            if let sdTemplate = existing {
                // Update existing
                sdTemplate.name = template.name
                sdTemplate.templateDescription = template.description
                sdTemplate.category = template.category
                sdTemplate.difficultyLevel = template.difficultyLevel?.rawValue
                sdTemplate.estimatedDurationMinutes = template.estimatedDurationMinutes
                sdTemplate.status = template.status.rawValue
                sdTemplate.updatedAt = template.updatedAt
                sdTemplate.backendID = template.backendID
                sdTemplate.syncStatus = template.syncStatus.rawValue

                // Update exercises
                if let oldExercises = sdTemplate.exercises {
                    for exercise in oldExercises {
                        modelContext.delete(exercise)
                    }
                }

                let sdExercises = template.exercises.map { exercise in
                    let sdExercise = SDTemplateExercise(
                        id: exercise.id,
                        template: sdTemplate,
                        exerciseID: exercise.exerciseID?.uuidString,
                        userExerciseID: exercise.userExerciseID?.uuidString,
                        exerciseName: exercise.exerciseName,
                        orderIndex: exercise.orderIndex,
                        technique: exercise.technique,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        weightKg: exercise.weightKg,
                        durationSeconds: exercise.durationSeconds,
                        restSeconds: exercise.restSeconds,
                        notes: exercise.notes,
                        createdAt: exercise.createdAt,
                        backendID: exercise.backendID
                    )
                    modelContext.insert(sdExercise)
                    return sdExercise
                }
                sdTemplate.exercises = sdExercises

            } else {
                // Create new
                let sdTemplate = SDWorkoutTemplate(
                    id: template.id,
                    userProfile: nil,
                    name: template.name,
                    templateDescription: template.description,
                    category: template.category,
                    difficultyLevel: template.difficultyLevel?.rawValue,
                    estimatedDurationMinutes: template.estimatedDurationMinutes,
                    isPublic: template.isPublic,
                    isSystem: template.isSystem,
                    status: template.status.rawValue,
                    exerciseCount: template.exerciseCount,
                    timesUsed: 0,
                    isFavorite: template.isFavorite,
                    isFeatured: template.isFeatured,
                    createdAt: template.createdAt,
                    updatedAt: template.updatedAt,
                    backendID: template.backendID,
                    syncStatus: template.syncStatus.rawValue,
                    exercises: []
                )

                modelContext.insert(sdTemplate)

                print("    - Creating new template with \(template.exercises.count) exercises")
                for exercise in template.exercises {
                    let sdExercise = SDTemplateExercise(
                        id: exercise.id,
                        template: sdTemplate,
                        exerciseID: exercise.exerciseID?.uuidString,
                        userExerciseID: exercise.userExerciseID?.uuidString,
                        exerciseName: exercise.exerciseName,
                        orderIndex: exercise.orderIndex,
                        technique: exercise.technique,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        weightKg: exercise.weightKg,
                        durationSeconds: exercise.durationSeconds,
                        restSeconds: exercise.restSeconds,
                        notes: exercise.notes,
                        createdAt: exercise.createdAt,
                        backendID: exercise.backendID
                    )
                    modelContext.insert(sdExercise)
                    print(
                        "      - Added exercise: \(exercise.exerciseName) (order: \(exercise.orderIndex))"
                    )
                }

                // Link user profile if userID provided
                if let userID = template.userID, let userUUID = UUID(uuidString: userID) {
                    let userDescriptor = FetchDescriptor<SDUserProfile>(
                        predicate: #Predicate { $0.id == userUUID }
                    )
                    if let userProfile = try? modelContext.fetch(userDescriptor).first {
                        sdTemplate.userProfile = userProfile
                    }
                }
            }
        }

        try modelContext.save()
        print(
            "SwiftDataWorkoutTemplateRepository: ✅ Batch save completed for \(templates.count) templates"
        )

        // Verify exercises were saved
        for template in templates {
            if let savedTemplate = try? await fetchByID(template.id) {
                print(
                    "  - Verified '\(savedTemplate.name)': \(savedTemplate.exercises.count) exercises in DB"
                )
            }
        }

        print("SwiftDataWorkoutTemplateRepository: ✅ Batch saved \(templates.count) templates")
    }

    func deleteAllSystemTemplates() async throws {
        print("SwiftDataWorkoutTemplateRepository: Deleting all system templates")

        let descriptor = FetchDescriptor<SDWorkoutTemplate>(
            predicate: #Predicate { $0.isSystem || $0.isPublic }
        )

        let systemTemplates = try modelContext.fetch(descriptor)

        for template in systemTemplates {
            modelContext.delete(template)
        }

        try modelContext.save()

        print(
            "SwiftDataWorkoutTemplateRepository: ✅ Deleted \(systemTemplates.count) system templates"
        )
    }
}

// MARK: - Domain Conversion

extension SDWorkoutTemplate {
    /// Convert SwiftData model to domain model
    func toDomain() -> WorkoutTemplate {
        let exercisesArray = self.exercises?.map { $0.toDomain() } ?? []

        print("SwiftDataWorkoutTemplateRepository.toDomain: Converting '\(self.name)'")
        print("  - SwiftData exercises count: \(self.exercises?.count ?? 0)")
        print("  - Mapped exercises count: \(exercisesArray.count)")

        return WorkoutTemplate(
            id: self.id,
            userID: self.userProfile?.id.uuidString,
            name: self.name,
            description: self.templateDescription,
            category: self.category,
            difficultyLevel: self.difficultyLevel.flatMap { DifficultyLevel(rawValue: $0) },
            estimatedDurationMinutes: self.estimatedDurationMinutes,
            isPublic: self.isPublic,
            isSystem: self.isSystem,
            status: TemplateStatus(rawValue: self.status) ?? .draft,
            exerciseCount: self.exercises?.count ?? 0,
            exercises: exercisesArray,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            isFavorite: self.isFavorite,
            isFeatured: self.isFeatured,
            backendID: self.backendID,
            syncStatus: SyncStatus(rawValue: self.syncStatus) ?? .pending
        )
    }
}

extension SDTemplateExercise {
    /// Convert SwiftData model to domain model
    func toDomain() -> TemplateExercise {
        TemplateExercise(
            id: self.id,
            templateID: self.template?.id ?? UUID(),
            exerciseID: self.exerciseID.flatMap { UUID(uuidString: $0) },
            userExerciseID: self.userExerciseID.flatMap { UUID(uuidString: $0) },
            exerciseName: self.exerciseName,
            orderIndex: self.orderIndex,
            technique: self.technique,
            techniqueDetails: nil,  // Not stored in SwiftData model
            sets: self.sets,
            reps: self.reps,
            weightKg: self.weightKg,
            durationSeconds: self.durationSeconds,
            restSeconds: self.restSeconds,
            notes: self.notes,
            createdAt: self.createdAt,
            backendID: self.backendID
        )
    }
}

// MARK: - Errors

enum WorkoutTemplateRepositoryError: Error, LocalizedError {
    case notFound
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Workout template not found"
        case .saveFailed:
            return "Failed to save workout template"
        case .deleteFailed:
            return "Failed to delete workout template"
        }
    }
}
