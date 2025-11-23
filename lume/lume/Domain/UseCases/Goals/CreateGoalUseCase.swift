//
//  CreateGoalUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Protocol for creating a new goal use case
protocol CreateGoalUseCaseProtocol {
    /// Create a new goal with validation
    /// - Parameters:
    ///   - title: The goal title
    ///   - description: The goal description
    ///   - category: The goal category
    ///   - targetDate: Optional target completion date
    ///   - targetValue: Target value to achieve (default: 1.0)
    ///   - targetUnit: Unit of measurement (default: "completion")
    /// - Returns: The created Goal
    /// - Throws: Use case error if creation fails
    func execute(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?,
        targetValue: Double,
        targetUnit: String
    ) async throws -> Goal
}

/// Use case for creating goals
/// Validates input and coordinates between repository and backend service
final class CreateGoalUseCase: CreateGoalUseCaseProtocol {
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
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date? = nil,
        targetValue: Double = 1.0,
        targetUnit: String = "completion"
    ) async throws -> Goal {
        // Validate input
        try validateInput(title: title, description: description, targetDate: targetDate)

        // Check for duplicate goals
        try await checkForDuplicates(title: title)

        // Create goal in repository (offline-first with Outbox pattern)
        let goal = try await goalRepository.create(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            targetDate: targetDate,
            targetValue: max(targetValue, 0.01),  // Ensure > 0 for backend
            targetUnit: targetUnit
        )

        print("✅ [CreateGoalUseCase] Created goal: \(goal.id)")

        // Backend sync happens via Outbox pattern in repository
        return goal
    }
}

// MARK: - Validation

extension CreateGoalUseCase {
    /// Validate goal input
    fileprivate func validateInput(
        title: String,
        description: String,
        targetDate: Date?
    ) throws {
        // Validate title
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw CreateGoalError.emptyTitle
        }

        guard trimmedTitle.count >= 3 else {
            throw CreateGoalError.titleTooShort
        }

        guard trimmedTitle.count <= 100 else {
            throw CreateGoalError.titleTooLong
        }

        // Validate description
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            throw CreateGoalError.emptyDescription
        }

        guard trimmedDescription.count >= 10 else {
            throw CreateGoalError.descriptionTooShort
        }

        guard trimmedDescription.count <= 500 else {
            throw CreateGoalError.descriptionTooLong
        }

        // Validate target date (if provided)
        if let targetDate = targetDate {
            let now = Date()
            guard targetDate > now else {
                throw CreateGoalError.targetDateInPast
            }

            // Check if target date is too far in the future (more than 5 years)
            let fiveYearsFromNow =
                Calendar.current.date(
                    byAdding: .year,
                    value: 5,
                    to: now
                ) ?? now

            guard targetDate <= fiveYearsFromNow else {
                throw CreateGoalError.targetDateTooFarInFuture
            }
        }
    }

    /// Check for duplicate goals with similar titles
    fileprivate func checkForDuplicates(title: String) async throws {
        let existingGoals = try await goalRepository.fetchActive()
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for goal in existingGoals {
            let existingTitle = goal.title.lowercased().trimmingCharacters(
                in: .whitespacesAndNewlines)

            // Check for exact match
            if normalizedTitle == existingTitle {
                throw CreateGoalError.duplicateGoal
            }

            // Check for very similar titles (>85% similarity)
            if calculateSimilarity(normalizedTitle, existingTitle) > 0.85 {
                throw CreateGoalError.similarGoalExists(existingTitle: goal.title)
            }
        }
    }

    /// Calculate similarity between two strings (0.0 to 1.0)
    fileprivate func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let set1 = Set(str1.components(separatedBy: .whitespaces))
        let set2 = Set(str2.components(separatedBy: .whitespaces))

        let intersection = set1.intersection(set2)
        let union = set1.union(set2)

        guard !union.isEmpty else { return 0.0 }

        return Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Convenience Methods

extension CreateGoalUseCase {
    /// Create goal from suggestion
    func createFromSuggestion(_ suggestion: GoalSuggestion) async throws -> Goal {
        try await execute(
            title: suggestion.title,
            description: suggestion.description,
            category: suggestion.category,
            targetDate: suggestion.estimatedTargetDate,
            targetValue: suggestion.targetValue ?? 1.0,
            targetUnit: suggestion.targetUnit ?? "completion"
        )
    }

    /// Create simple goal with minimal input
    func createSimple(title: String, category: GoalCategory) async throws -> Goal {
        try await execute(
            title: title,
            description: "Working towards: \(title)",
            category: category,
            targetDate: nil,
            targetValue: 1.0,
            targetUnit: "completion"
        )
    }
}

// MARK: - Errors

/// Errors specific to CreateGoalUseCase
enum CreateGoalError: Error, LocalizedError {
    case emptyTitle
    case titleTooShort
    case titleTooLong
    case emptyDescription
    case descriptionTooShort
    case descriptionTooLong
    case targetDateInPast
    case targetDateTooFarInFuture
    case duplicateGoal
    case similarGoalExists(existingTitle: String)
    case repositoryError

    var errorDescription: String? {
        switch self {
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
        case .duplicateGoal:
            return "A goal with this title already exists."
        case .similarGoalExists(let existingTitle):
            return "A similar goal already exists: \"\(existingTitle)\""
        case .repositoryError:
            return "Failed to save goal. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
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
        case .duplicateGoal, .similarGoalExists:
            return "Try updating your existing goal or choose a different title."
        case .repositoryError:
            return "Check your connection and try again."
        }
    }
}
