//
//  ShareWorkoutTemplateUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Use case for sharing a workout template with multiple users (bulk sharing)
public protocol ShareWorkoutTemplateUseCase {
    /// Execute the use case to share a template with users
    /// - Parameters:
    ///   - templateId: Template ID to share
    ///   - userIds: List of user IDs to share with
    ///   - professionalType: Professional type for categorization
    ///   - notes: Optional notes about the share
    /// - Returns: Share response with details of all users shared with
    func execute(
        templateId: UUID,
        userIds: [UUID],
        professionalType: ProfessionalType,
        notes: String?
    ) async throws -> ShareWorkoutTemplateResponse
}

/// Implementation of ShareWorkoutTemplateUseCase
public final class ShareWorkoutTemplateUseCaseImpl: ShareWorkoutTemplateUseCase {
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
        userIds: [UUID],
        professionalType: ProfessionalType,
        notes: String? = nil
    ) async throws -> ShareWorkoutTemplateResponse {
        print(
            "ShareWorkoutTemplateUseCase: Sharing template \(templateId) with \(userIds.count) users"
        )

        // Validate
        guard !userIds.isEmpty else {
            throw ShareTemplateError.noUsersSpecified
        }

        guard authManager.isAuthenticated else {
            throw ShareTemplateError.notAuthenticated
        }

        // Verify template exists locally
        guard let template = try await repository.fetchByID(templateId) else {
            throw ShareTemplateError.templateNotFound
        }

        // Verify user owns the template
        guard let userID = authManager.currentUserProfileID?.uuidString,
            template.userID == userID
        else {
            throw ShareTemplateError.notAuthorized
        }

        // Verify template is published
        guard template.status == .published else {
            throw ShareTemplateError.templateNotPublished
        }

        // Share via API (bulk operation)
        let response = try await apiClient.shareTemplate(
            id: templateId,
            userIds: userIds,
            professionalType: professionalType,
            notes: notes
        )

        print("ShareWorkoutTemplateUseCase: ✅ Shared template with \(response.totalShared) users")

        return response
    }
}

/// Errors for sharing templates
public enum ShareTemplateError: Error, LocalizedError {
    case noUsersSpecified
    case notAuthenticated
    case templateNotFound
    case notAuthorized
    case templateNotPublished

    public var errorDescription: String? {
        switch self {
        case .noUsersSpecified:
            return "No users specified for sharing"
        case .notAuthenticated:
            return "User is not authenticated"
        case .templateNotFound:
            return "Template not found"
        case .notAuthorized:
            return "Only template owner can share"
        case .templateNotPublished:
            return "Template must be published before sharing"
        }
    }
}
