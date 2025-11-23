//
//  FetchSharedWithMeTemplatesUseCase.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Use case for fetching workout templates shared with the authenticated user
public protocol FetchSharedWithMeTemplatesUseCase {
    /// Execute the use case to fetch shared templates
    /// - Parameters:
    ///   - professionalType: Optional filter by professional type
    ///   - limit: Number of templates to return
    ///   - offset: Number of templates to skip
    /// - Returns: List of shared templates response
    func execute(
        professionalType: ProfessionalType?,
        limit: Int,
        offset: Int
    ) async throws -> ListSharedTemplatesResponse
}

/// Implementation of FetchSharedWithMeTemplatesUseCase
public final class FetchSharedWithMeTemplatesUseCaseImpl: FetchSharedWithMeTemplatesUseCase {
    private let apiClient: WorkoutTemplateAPIClientProtocol
    private let authManager: AuthManager

    init(
        apiClient: WorkoutTemplateAPIClientProtocol,
        authManager: AuthManager
    ) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

    public func execute(
        professionalType: ProfessionalType? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> ListSharedTemplatesResponse {
        print("FetchSharedWithMeTemplatesUseCase: Fetching shared templates")

        // Validate authentication
        guard authManager.isAuthenticated else {
            throw FetchSharedTemplatesError.notAuthenticated
        }

        // Validate parameters
        guard limit > 0, limit <= 100 else {
            throw FetchSharedTemplatesError.invalidLimit
        }

        guard offset >= 0 else {
            throw FetchSharedTemplatesError.invalidOffset
        }

        // Fetch shared templates via API
        let response = try await apiClient.fetchSharedWithMeTemplates(
            professionalType: professionalType,
            limit: limit,
            offset: offset
        )

        print(
            "FetchSharedWithMeTemplatesUseCase: ✅ Fetched \(response.templates.count) shared templates"
        )

        return response
    }
}

/// Errors for fetching shared templates
public enum FetchSharedTemplatesError: Error, LocalizedError {
    case notAuthenticated
    case invalidLimit
    case invalidOffset

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidLimit:
            return "Limit must be between 1 and 100"
        case .invalidOffset:
            return "Offset must be non-negative"
        }
    }
}
