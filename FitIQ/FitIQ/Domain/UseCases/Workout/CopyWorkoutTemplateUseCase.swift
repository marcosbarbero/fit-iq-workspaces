//
//  CopyWorkoutTemplateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Use case for copying a workout template to user's personal library
public protocol CopyWorkoutTemplateUseCase {
    /// Execute the use case to copy a template
    /// - Parameters:
    ///   - templateId: Template ID to copy
    ///   - newName: Optional new name for the copy
    /// - Returns: Copy response with the new template
    func execute(
        templateId: UUID,
        newName: String?
    ) async throws -> CopyWorkoutTemplateResponse
}

/// Implementation of CopyWorkoutTemplateUseCase
public final class CopyWorkoutTemplateUseCaseImpl: CopyWorkoutTemplateUseCase {
    private let apiClient: WorkoutTemplateAPIClientProtocol
    private let repository: WorkoutTemplateRepositoryProtocol
    private let authManager: AuthManager

    init(
        apiClient: WorkoutTemplateAPIClientProtocol,
        repository: WorkoutTemplateRepositoryProtocol,
        authManager: AuthManager
    ) {
        self.apiClient = apiClient
        self.repository = repository
        self.authManager = authManager
    }

    public func execute(
        templateId: UUID,
        newName: String? = nil
    ) async throws -> CopyWorkoutTemplateResponse {
        print("CopyWorkoutTemplateUseCase: Copying template \(templateId)")

        // Validate authentication
        guard authManager.isAuthenticated else {
            throw CopyTemplateError.notAuthenticated
        }

        // Validate new name if provided
        if let newName = newName {
            guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CopyTemplateError.invalidName
            }
        }

        // Copy template via API (backend handles access validation)
        let response = try await apiClient.copyTemplate(
            id: templateId,
            newName: newName
        )

        print(
            "CopyWorkoutTemplateUseCase: ✅ Copied template to new template \(response.newTemplate.id)"
        )

        // Save the copied template locally
        do {
            _ = try await repository.save(template: response.newTemplate)
            print("CopyWorkoutTemplateUseCase: ✅ Saved copied template locally")
        } catch {
            print("CopyWorkoutTemplateUseCase: ⚠️ Failed to save copied template locally: \(error)")
            // Continue - the template is created on backend, we can fetch it later
        }

        return response
    }
}

/// Errors for copying templates
public enum CopyTemplateError: Error, LocalizedError {
    case notAuthenticated
    case invalidName
    case templateNotFound
    case notAccessible

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidName:
            return "Template name cannot be empty"
        case .templateNotFound:
            return "Template not found"
        case .notAccessible:
            return "Template is not accessible (must be public, system, or shared)"
        }
    }
}
