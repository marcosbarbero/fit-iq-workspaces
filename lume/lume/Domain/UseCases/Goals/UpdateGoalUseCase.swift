//
//  UpdateGoalUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for updating an existing goal use case
protocol UpdateGoalUseCaseProtocol {
    /// Update an existing goal with validation
    /// - Parameters:
    ///   - goalId: The UUID of the goal to update
    ///   - title: Optional new title
    ///   - description: Optional new description
    ///   - category: Optional new category
    ///   - targetDate: Optional new target date
    ///   - progress: Optional new progress value
    ///   - status: Optional new status
    /// - Returns: The updated Goal
    /// - Throws: Use case error if update fails
    func execute(
        goalId: UUID,
        title: String?,
        description: String?,
        category: GoalCategory?,
        targetDate: Date?,
        progress: Double?,
        status: GoalStatus?
    ) async throws -> Goal
}

/// Use case for updating goals
/// Validates input and coordinates between repository and backend service
final class UpdateGoalUseCase: UpdateGoalUseCaseProtocol {
    private let goalRepository: GoalRepositoryProtocol
    private let outboxRepository: OutboxRepositoryProtocol

    init(
        goalRepository: GoalRepositoryProtocol,
        outboxRepository: OutboxRepositoryProtocol
    ) {
        self.goalRepository = goalRepository
        self.outboxRepository = outboxRepository
    }

    func execute(
        goalId: UUID,
        title: String? = nil,
        description: String? = nil,
        category: GoalCategory? = nil,
        targetDate: Date? = nil,
        progress: Double? = nil,
        status: GoalStatus? = nil
    ) async throws -> Goal {
        // Fetch existing goal
        guard let existingGoal = try await goalRepository.fetchById(goalId) else {
            throw UpdateGoalError.goalNotFound
        }

        // Validate updates
        try validateUpdates(
            title: title,
            description: description,
            targetDate: targetDate,
            progress: progress
        )

        // Create updated goal with new values
        let updatedGoal = Goal(
            id: existingGoal.id,
            userId: existingGoal.userId,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? existingGoal.title,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? existingGoal.description,
            createdAt: existingGoal.createdAt,
            updatedAt: Date(),
            targetDate: targetDate ?? existingGoal.targetDate,
            progress: progress ?? existingGoal.progress,
            status: status ?? existingGoal.status,
            category: category ?? existingGoal.category
        )

        // Validate progress constraints
        try validateProgressConstraints(goal: updatedGoal)

        // Update in repository (will trigger Outbox sync)
        let savedGoal = try await goalRepository.update(updatedGoal)

        print("✅ [UpdateGoalUseCase] Updated goal: \(savedGoal.id)")

        return savedGoal
    }
}

// MARK: - Validation

extension UpdateGoalUseCase {
    /// Validate update values
    fileprivate func validateUpdates(
        title: String?,
        description: String?,
        targetDate: Date?,
        progress: Double?
    ) throws {
        // Validate title if provided
        if let title = title {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedTitle.isEmpty else {
                throw UpdateGoalError.emptyTitle
            }

            guard trimmedTitle.count >= 3 else {
                throw UpdateGoalError.titleTooShort
            }

            guard trimmedTitle.count <= 100 else {
                throw UpdateGoalError.titleTooLong
            }
        }

        // Validate description if provided
        if let description = description {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedDescription.isEmpty else {
                throw UpdateGoalError.emptyDescription
            }

            guard trimmedDescription.count >= 10 else {
                throw UpdateGoalError.descriptionTooShort
            }

            guard trimmedDescription.count <= 500 else {
                throw UpdateGoalError.descriptionTooLong
            }
        }

        // Validate target date if provided
        if let targetDate = targetDate {
            let now = Date()
            guard targetDate > now else {
                throw UpdateGoalError.targetDateInPast
            }

            let fiveYearsFromNow =
                Calendar.current.date(byAdding: .year, value: 5, to: now) ?? now
            guard targetDate <= fiveYearsFromNow else {
                throw UpdateGoalError.targetDateTooFarInFuture
            }
        }

        // Validate progress if provided
        if let progress = progress {
            guard progress >= 0.0 && progress <= 1.0 else {
                throw UpdateGoalError.invalidProgress
            }
        }
    }

    /// Validate progress constraints with status
    fileprivate func validateProgressConstraints(goal: Goal) throws {
        // Completed goals must have 100% progress
        if goal.status == .completed && goal.progress < 1.0 {
            throw UpdateGoalError.completedGoalMustHaveFullProgress
        }

        // Active goals cannot have 100% progress (should be completed instead)
        if goal.status == .active && goal.progress >= 1.0 {
            throw UpdateGoalError.fullProgressShouldBeCompleted
        }
    }
}

// MARK: - Convenience Methods

extension UpdateGoalUseCase {
    /// Update only the progress of a goal
    func updateProgress(goalId: UUID, progress: Double) async throws -> Goal {
        try await execute(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: progress,
            status: nil
        )
    }

    /// Update only the status of a goal
    func updateStatus(goalId: UUID, status: GoalStatus) async throws -> Goal {
        // Fetch current goal to set appropriate progress
        guard try await goalRepository.fetchById(goalId) != nil else {
            throw UpdateGoalError.goalNotFound
        }

        // Auto-set progress when completing
        let newProgress: Double? = status == .completed ? 1.0 : nil

        return try await execute(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: newProgress,
            status: status
        )
    }

    /// Mark goal as completed
    func complete(goalId: UUID) async throws -> Goal {
        try await execute(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: 1.0,
            status: .completed
        )
    }

    /// Pause a goal
    func pause(goalId: UUID) async throws -> Goal {
        try await updateStatus(goalId: goalId, status: .paused)
    }

    /// Resume a paused goal
    func resume(goalId: UUID) async throws -> Goal {
        try await updateStatus(goalId: goalId, status: .active)
    }

    /// Update title and description
    func updateDetails(goalId: UUID, title: String, description: String) async throws -> Goal {
        try await execute(
            goalId: goalId,
            title: title,
            description: description,
            category: nil,
            targetDate: nil,
            progress: nil,
            status: nil
        )
    }
}

// MARK: - Errors

/// Errors specific to UpdateGoalUseCase
enum UpdateGoalError: Error, LocalizedError {
    case goalNotFound
    case emptyTitle
    case titleTooShort
    case titleTooLong
    case emptyDescription
    case descriptionTooShort
    case descriptionTooLong
    case targetDateInPast
    case targetDateTooFarInFuture
    case invalidProgress
    case completedGoalMustHaveFullProgress
    case fullProgressShouldBeCompleted
    case repositoryError

    var errorDescription: String? {
        switch self {
        case .goalNotFound:
            return "Goal not found. It may have been deleted."
        case .emptyTitle:
            return "Goal title cannot be empty."
        case .titleTooShort:
            return "Goal title must be at least 3 characters."
        case .titleTooLong:
            return "Goal title must be 100 characters or less."
        case .emptyDescription:
            return "Goal description cannot be empty."
        case .descriptionTooShort:
            return "Goal description must be at least 10 characters."
        case .descriptionTooLong:
            return "Goal description must be 500 characters or less."
        case .targetDateInPast:
            return "Target date must be in the future."
        case .targetDateTooFarInFuture:
            return "Target date cannot be more than 5 years in the future."
        case .invalidProgress:
            return "Progress must be between 0% and 100%."
        case .completedGoalMustHaveFullProgress:
            return "Completed goals must have 100% progress."
        case .fullProgressShouldBeCompleted:
            return "Goals at 100% progress should be marked as completed."
        case .repositoryError:
            return "Failed to update goal. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .goalNotFound:
            return "Please refresh and try again."
        case .emptyTitle, .titleTooShort:
            return "Please enter a meaningful goal title."
        case .titleTooLong:
            return "Try to make your goal title more concise."
        case .emptyDescription, .descriptionTooShort:
            return "Add more details about what you want to achieve."
        case .descriptionTooLong:
            return "Try to make your description more concise."
        case .targetDateInPast:
            return "Choose a date in the future."
        case .targetDateTooFarInFuture:
            return "Consider breaking this into smaller, nearer-term goals."
        case .invalidProgress:
            return "Enter a value between 0 and 100."
        case .completedGoalMustHaveFullProgress:
            return "Set progress to 100% when completing a goal."
        case .fullProgressShouldBeCompleted:
            return "Mark the goal as completed instead."
        case .repositoryError:
            return "Check your connection and try again."
        }
    }
}
