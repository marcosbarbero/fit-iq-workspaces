//
//  WorkoutTemplateRepositoryProtocol.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-11-10.
//

import Foundation

/// Repository protocol for workout template operations (secondary port)
/// Defines contract for local storage of workout templates
public protocol WorkoutTemplateRepositoryProtocol {
    /// Save a workout template locally
    /// - Parameter template: The template to save
    /// - Returns: The saved template with local ID
    func save(template: WorkoutTemplate) async throws -> WorkoutTemplate
    
    /// Fetch all workout templates
    /// - Parameters:
    ///   - source: Filter by source (owned, system, shared)
    ///   - category: Optional category filter
    ///   - difficulty: Optional difficulty filter
    /// - Returns: List of templates matching filters
    func fetchAll(
        source: TemplateSource?,
        category: String?,
        difficulty: DifficultyLevel?
    ) async throws -> [WorkoutTemplate]
    
    /// Fetch a specific workout template by ID
    /// - Parameter id: Template ID
    /// - Returns: The template if found
    func fetchByID(_ id: UUID) async throws -> WorkoutTemplate?
    
    /// Update a workout template
    /// - Parameter template: The template to update
    /// - Returns: The updated template
    func update(template: WorkoutTemplate) async throws -> WorkoutTemplate
    
    /// Delete a workout template
    /// - Parameter id: Template ID to delete
    func delete(id: UUID) async throws
    
    /// Toggle favorite status for a template
    /// - Parameter id: Template ID
    func toggleFavorite(id: UUID) async throws
    
    /// Toggle featured status for a template
    /// - Parameter id: Template ID
    func toggleFeatured(id: UUID) async throws
    
    /// Batch save workout templates (for sync)
    /// - Parameter templates: List of templates to save
    func batchSave(templates: [WorkoutTemplate]) async throws
    
    /// Delete all system templates (for refresh)
    func deleteAllSystemTemplates() async throws
}

/// Template source types for filtering
public enum TemplateSource: String {
    case owned      // User's own templates
    case system     // Public/system templates
    case shared     // Templates shared with user
}
