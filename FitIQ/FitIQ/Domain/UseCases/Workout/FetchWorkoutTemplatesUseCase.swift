//
//  FetchWorkoutTemplatesUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Use case for fetching workout templates
/// Retrieves templates from local storage with filtering
public protocol FetchWorkoutTemplatesUseCase {
    /// Execute the use case
    /// - Parameters:
    ///   - source: Filter by source (owned, system, shared)
    ///   - category: Optional category filter
    ///   - difficulty: Optional difficulty filter
    /// - Returns: List of templates matching filters
    func execute(
        source: TemplateSource?,
        category: String?,
        difficulty: DifficultyLevel?
    ) async throws -> [WorkoutTemplate]
}

/// Implementation of FetchWorkoutTemplatesUseCase
public final class FetchWorkoutTemplatesUseCaseImpl: FetchWorkoutTemplatesUseCase {
    private let repository: WorkoutTemplateRepositoryProtocol
    
    public init(repository: WorkoutTemplateRepositoryProtocol) {
        self.repository = repository
    }
    
    public func execute(
        source: TemplateSource? = nil,
        category: String? = nil,
        difficulty: DifficultyLevel? = nil
    ) async throws -> [WorkoutTemplate] {
        print("FetchWorkoutTemplatesUseCase: Fetching templates - source: \(source?.rawValue ?? "all"), category: \(category ?? "all"), difficulty: \(difficulty?.rawValue ?? "all")")
        
        let templates = try await repository.fetchAll(
            source: source,
            category: category,
            difficulty: difficulty
        )
        
        print("FetchWorkoutTemplatesUseCase: ✅ Found \(templates.count) templates")
        
        // Sort templates: featured first, then favorites, then alphabetically
        let sorted = templates.sorted { t1, t2 in
            // 1. Prioritize featured templates
            if t1.isFeatured && !t2.isFeatured { return true }
            if !t1.isFeatured && t2.isFeatured { return false }
            
            // 2. If featured status is the same, prioritize favorites
            if t1.isFavorite && !t2.isFavorite { return true }
            if !t1.isFavorite && t2.isFavorite { return false }
            
            // 3. If both featured and favorite status are the same, sort by name
            return t1.name < t2.name
        }
        
        return sorted
    }
}
