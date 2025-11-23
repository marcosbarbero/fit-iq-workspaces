//
//  RevokeTemplateShareUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Use case for revoking a workout template share from a user
public protocol RevokeTemplateShareUseCase {
    /// Execute the use case to revoke template share
    /// - Parameters:
    ///   - templateId: Template ID
    ///   - userId: User ID to revoke access from
    /// - Returns: Revocation response
    func execute(
        templateId: UUID,
        userId: UUID
    ) async throws -> RevokeTemplateShareResponse
}

/// Implementation of RevokeTemplateShareUseCase
public final class RevokeTemplateShareUseCaseImpl: RevokeTemplateShareUseCase {
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
        userId: UUID
    ) async throws -> RevokeTemplateShareResponse {
        print(
            "RevokeTemplateShareUseCase: Revoking template \(templateId) share from user \(userId)")

        // Validate authentication
        guard authManager.isAuthenticated else {
            throw RevokeShareError.notAuthenticated
        }

        // Verify template exists locally
        guard let template = try await repository.fetchByID(templateId) else {
            throw RevokeShareError.templateNotFound
        }

        // Verify user owns the template
        guard let currentUserID = authManager.currentUserProfileID?.uuidString,
            template.userID == currentUserID
        else {
            throw RevokeShareError.notAuthorized
        }

        // Revoke share via API
        let response = try await apiClient.revokeTemplateShare(
            templateId: templateId,
            userId: userId
        )

        print("RevokeTemplateShareUseCase: ✅ Revoked template share from user")

        return response
    }
}

/// Errors for revoking template shares
public enum RevokeShareError: Error, LocalizedError {
    case notAuthenticated
    case templateNotFound
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .templateNotFound:
            return "Template not found"
        case .notAuthorized:
            return "Only template owner can revoke shares"
        }
    }
}
