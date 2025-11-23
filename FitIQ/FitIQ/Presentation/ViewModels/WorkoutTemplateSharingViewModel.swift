//
//  WorkoutTemplateSharingViewModel.swift
//  FitIQ
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import Observation

/// ViewModel for managing workout template sharing operations
/// Handles bulk sharing, revoking shares, fetching shared templates, and copying
@Observable
final class WorkoutTemplateSharingViewModel {

    // MARK: - State

    /// Loading state for share operations
    var isSharing = false

    /// Loading state for revoke operations
    var isRevoking = false

    /// Loading state for fetching shared templates
    var isLoadingSharedTemplates = false

    /// Loading state for copy operations
    var isCopying = false

    /// Error message for display
    var errorMessage: String?

    /// Success message for display
    var successMessage: String?

    /// Templates shared with the authenticated user
    var sharedWithMeTemplates: [SharedTemplateInfo] = []

    /// Pagination state for shared templates
    var hasMoreSharedTemplates = false
    var currentOffset = 0
    var pageLimit = 20

    /// Filter for professional type
    var selectedProfessionalType: ProfessionalType?

    /// Users that a template was shared with (from last share operation)
    var lastShareResponse: ShareWorkoutTemplateResponse?

    // MARK: - Dependencies

    private let shareTemplateUseCase: ShareWorkoutTemplateUseCase
    private let revokeShareUseCase: RevokeTemplateShareUseCase
    private let fetchSharedWithMeUseCase: FetchSharedWithMeTemplatesUseCase
    private let copyTemplateUseCase: CopyWorkoutTemplateUseCase

    // MARK: - Initialization

    init(
        shareTemplateUseCase: ShareWorkoutTemplateUseCase,
        revokeShareUseCase: RevokeTemplateShareUseCase,
        fetchSharedWithMeUseCase: FetchSharedWithMeTemplatesUseCase,
        copyTemplateUseCase: CopyWorkoutTemplateUseCase
    ) {
        self.shareTemplateUseCase = shareTemplateUseCase
        self.revokeShareUseCase = revokeShareUseCase
        self.fetchSharedWithMeUseCase = fetchSharedWithMeUseCase
        self.copyTemplateUseCase = copyTemplateUseCase
    }

    // MARK: - Share Template Actions

    /// Share a template with multiple users (bulk sharing)
    /// - Parameters:
    ///   - templateId: Template ID to share
    ///   - userIds: Array of user IDs to share with
    ///   - professionalType: Professional type for categorization
    ///   - notes: Optional notes about the share
    @MainActor
    func shareTemplate(
        templateId: UUID,
        userIds: [UUID],
        professionalType: ProfessionalType,
        notes: String? = nil
    ) async {
        guard !userIds.isEmpty else {
            errorMessage = "Please select at least one user to share with"
            return
        }

        isSharing = true
        errorMessage = nil
        successMessage = nil
        lastShareResponse = nil

        do {
            let response = try await shareTemplateUseCase.execute(
                templateId: templateId,
                userIds: userIds,
                professionalType: professionalType,
                notes: notes
            )

            lastShareResponse = response
            successMessage = "Template shared with \(response.totalShared) user(s) successfully"

            print(
                "WorkoutTemplateSharingViewModel: ✅ Shared template with \(response.totalShared) users"
            )
        } catch {
            errorMessage = error.localizedDescription
            print("WorkoutTemplateSharingViewModel: ❌ Failed to share template: \(error)")
        }

        isSharing = false
    }

    /// Revoke template share from a specific user
    /// - Parameters:
    ///   - templateId: Template ID
    ///   - userId: User ID to revoke access from
    @MainActor
    func revokeTemplateShare(
        templateId: UUID,
        userId: UUID
    ) async {
        isRevoking = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await revokeShareUseCase.execute(
                templateId: templateId,
                userId: userId
            )

            successMessage = "Template share revoked successfully"

            print("WorkoutTemplateSharingViewModel: ✅ Revoked template share from user \(userId)")
        } catch {
            errorMessage = error.localizedDescription
            print("WorkoutTemplateSharingViewModel: ❌ Failed to revoke share: \(error)")
        }

        isRevoking = false
    }

    // MARK: - Shared With Me Actions

    /// Fetch templates shared with the authenticated user
    /// - Parameter reset: If true, resets pagination and loads from beginning
    @MainActor
    func loadSharedWithMeTemplates(reset: Bool = false) async {
        if reset {
            currentOffset = 0
            sharedWithMeTemplates = []
        }

        isLoadingSharedTemplates = true
        errorMessage = nil

        do {
            let response = try await fetchSharedWithMeUseCase.execute(
                professionalType: selectedProfessionalType,
                limit: pageLimit,
                offset: currentOffset
            )

            if reset {
                sharedWithMeTemplates = response.templates
            } else {
                sharedWithMeTemplates.append(contentsOf: response.templates)
            }

            hasMoreSharedTemplates = response.hasMore
            currentOffset += response.templates.count

            print(
                "WorkoutTemplateSharingViewModel: ✅ Loaded \(response.templates.count) shared templates"
            )
        } catch {
            errorMessage = error.localizedDescription
            print("WorkoutTemplateSharingViewModel: ❌ Failed to load shared templates: \(error)")
        }

        isLoadingSharedTemplates = false
    }

    /// Refresh shared templates (resets pagination)
    @MainActor
    func refreshSharedTemplates() async {
        await loadSharedWithMeTemplates(reset: true)
    }

    /// Load next page of shared templates
    @MainActor
    func loadMoreSharedTemplates() async {
        guard !isLoadingSharedTemplates && hasMoreSharedTemplates else { return }
        await loadSharedWithMeTemplates(reset: false)
    }

    /// Update professional type filter and reload
    @MainActor
    func updateProfessionalTypeFilter(_ type: ProfessionalType?) async {
        selectedProfessionalType = type
        await loadSharedWithMeTemplates(reset: true)
    }

    // MARK: - Copy Template Actions

    /// Copy a template to user's personal library
    /// - Parameters:
    ///   - templateId: Template ID to copy
    ///   - newName: Optional new name for the copy
    /// - Returns: The copied template
    @MainActor
    func copyTemplate(
        templateId: UUID,
        newName: String? = nil
    ) async -> WorkoutTemplate? {
        isCopying = true
        errorMessage = nil
        successMessage = nil

        do {
            let response = try await copyTemplateUseCase.execute(
                templateId: templateId,
                newName: newName
            )

            let copiedTemplate = response.newTemplate
            successMessage = "Template copied successfully: \(copiedTemplate.name)"

            print("WorkoutTemplateSharingViewModel: ✅ Copied template to \(copiedTemplate.id)")

            isCopying = false
            return copiedTemplate
        } catch {
            errorMessage = error.localizedDescription
            print("WorkoutTemplateSharingViewModel: ❌ Failed to copy template: \(error)")

            isCopying = false
            return nil
        }
    }

    // MARK: - Helper Methods

    /// Clear all messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    /// Check if any operation is in progress
    var isAnyOperationInProgress: Bool {
        return isSharing || isRevoking || isLoadingSharedTemplates || isCopying
    }

    /// Get template by ID from shared templates
    func getSharedTemplate(byId id: UUID) -> SharedTemplateInfo? {
        return sharedWithMeTemplates.first { $0.templateId == id }
    }
}

// MARK: - Factory Extension

extension WorkoutTemplateSharingViewModel {
    /// Create a ViewModel instance with dependencies from AppDependencies
    static func create(from dependencies: AppDependencies) -> WorkoutTemplateSharingViewModel {
        return WorkoutTemplateSharingViewModel(
            shareTemplateUseCase: dependencies.shareWorkoutTemplateUseCase,
            revokeShareUseCase: dependencies.revokeTemplateShareUseCase,
            fetchSharedWithMeUseCase: dependencies.fetchSharedWithMeTemplatesUseCase,
            copyTemplateUseCase: dependencies.copyWorkoutTemplateUseCase
        )
    }
}
