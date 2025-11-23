//
//  GoalAIServiceProtocol.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Port for AI goal suggestions and tips service
/// Implementation must be provided by the infrastructure layer
protocol GoalAIServiceProtocol {
    /// Generate AI-powered goal suggestions based on user context
    /// - Parameter context: User context including activity, nutrition, and existing goals
    /// - Returns: Array of GoalSuggestion objects
    /// - Throws: Service error if generation fails
    func generateGoalSuggestions(context: UserContextData) async throws -> [GoalSuggestion]

    /// Generate AI-powered goal suggestions from consultation context
    /// - Parameters:
    ///   - consultationId: The UUID of the consultation
    ///   - maxSuggestions: Maximum number of suggestions (1-10, default 3)
    /// - Returns: Array of GoalSuggestion objects based on conversation
    /// - Throws: Service error if generation fails
    func generateConsultationGoalSuggestions(
        consultationId: UUID,
        maxSuggestions: Int
    ) async throws -> [GoalSuggestion]

    /// Get AI-powered tips for achieving a specific goal
    /// - Parameters:
    ///   - backendId: The backend-assigned ID of the goal
    ///   - goalTitle: The title of the goal
    ///   - goalDescription: The description of the goal
    ///   - context: User context for personalized tips
    /// - Returns: Array of GoalTip objects
    /// - Throws: Service error if fetching tips fails
    func getGoalTips(
        backendId: String,
        goalTitle: String,
        goalDescription: String,
        context: UserContextData
    ) async throws -> [GoalTip]

    /// Fetch goal suggestions from backend
    /// - Returns: Array of GoalSuggestion objects
    /// - Throws: Service error if fetch fails
    func fetchGoalSuggestions() async throws -> [GoalSuggestion]

    /// Fetch tips for a specific goal from backend
    /// - Parameter backendId: The backend-assigned ID of the goal
    /// - Returns: Array of GoalTip objects
    /// - Throws: Service error if fetch fails
    func fetchGoalTips(backendId: String) async throws -> [GoalTip]
}

/// Response model for goal suggestions API
struct GoalSuggestionsResponse: Codable {
    let success: Bool?
    let data: GoalSuggestionsData
}

/// Data container for goal suggestions
struct GoalSuggestionsData: Codable {
    let suggestions: [GoalSuggestionDTO]
    let count: Int
}

/// Response model for consultation-based goal suggestions API
struct ConsultationGoalSuggestionsResponse: Codable {
    let success: Bool?
    let data: ConsultationGoalSuggestionsData
}

/// Data container for consultation-based goal suggestions
struct ConsultationGoalSuggestionsData: Codable {
    let suggestions: [GoalSuggestionDTO]
    let count: Int
    let persona: String?
}

/// DTO for goal suggestion from API
struct GoalSuggestionDTO: Codable {
    let title: String
    let description: String
    let goalType: String
    let targetValue: Double?
    let targetUnit: String?
    let rationale: String
    let estimatedDuration: Int?
    let difficulty: Int

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case goalType = "goal_type"
        case targetValue = "target_value"
        case targetUnit = "target_unit"
        case rationale
        case estimatedDuration = "estimated_duration"
        case difficulty
    }

    /// Convert DTO to domain entity
    func toDomain(id: UUID = UUID()) -> GoalSuggestion {
        // Map string category from goalType
        let category = mapCategory(from: goalType)

        print("🔍 [GoalSuggestionDTO] Converting to domain:")
        print("   - Title: \(title)")
        print("   - Goal Type: \(goalType)")
        print("   - Category: \(category)")
        print("   - Difficulty: \(difficulty) -> \(DifficultyLevel(from: difficulty))")
        print("   - Duration: \(estimatedDuration ?? 0) days")

        return GoalSuggestion(
            id: id,
            title: title,
            description: description,
            goalType: goalType,
            targetValue: targetValue,
            targetUnit: targetUnit,
            rationale: rationale,
            estimatedDuration: estimatedDuration,
            difficulty: DifficultyLevel(from: difficulty),
            category: category,
            generatedAt: Date()
        )
    }

    private func mapCategory(from type: String) -> GoalCategory {
        let lowercased = type.lowercased()

        // Map backend goal_type values to app categories
        if lowercased == "activity" || lowercased.contains("physical")
            || lowercased.contains("fitness") || lowercased.contains("exercise")
        {
            return .physical
        } else if lowercased == "nutrition" || lowercased.contains("food")
            || lowercased.contains("diet") || lowercased.contains("eating")
        {
            return .physical  // Nutrition is part of physical health
        } else if lowercased.contains("mental") || lowercased.contains("mind") {
            return .mental
        } else if lowercased.contains("emotional") || lowercased.contains("mood") {
            return .emotional
        } else if lowercased.contains("social") || lowercased.contains("relationship") {
            return .social
        } else if lowercased.contains("spiritual") || lowercased.contains("meditation") {
            return .spiritual
        } else if lowercased.contains("professional") || lowercased.contains("career")
            || lowercased.contains("work")
        {
            return .professional
        }
        return .general
    }
}

/// Response model for goal tips API
struct GoalTipsResponse: Codable {
    let success: Bool?
    let data: GoalTipsData
}

/// Data wrapper for goal tips
struct GoalTipsData: Codable {
    let tips: [String]  // Backend returns array of strings, not objects
    let goalId: String
    let count: Int

    enum CodingKeys: String, CodingKey {
        case tips
        case goalId = "goal_id"
        case count
    }

    /// Convert array of tip strings to domain GoalTip objects
    func toDomain() -> [GoalTip] {
        return tips.enumerated().map { index, tipText in
            // Assign priority based on position (earlier tips are higher priority)
            let priority: TipPriority = index < 2 ? .high : index < 5 ? .medium : .low

            // Infer category from tip content
            let category = inferCategory(from: tipText)

            return GoalTip(
                id: UUID(),
                tip: tipText,
                category: category,
                priority: priority
            )
        }
    }

    private func inferCategory(from tipText: String) -> TipCategory {
        let lowercased = tipText.lowercased()

        if lowercased.contains("eat") || lowercased.contains("food") || lowercased.contains("diet")
            || lowercased.contains("nutrition") || lowercased.contains("meal")
        {
            return .nutrition
        } else if lowercased.contains("exercise") || lowercased.contains("workout")
            || lowercased.contains("walk") || lowercased.contains("run")
            || lowercased.contains("step")
        {
            return .exercise
        } else if lowercased.contains("sleep") || lowercased.contains("rest")
            || lowercased.contains("bed")
        {
            return .sleep
        } else if lowercased.contains("think") || lowercased.contains("mindset")
            || lowercased.contains("mental") || lowercased.contains("focus")
        {
            return .mindset
        } else if lowercased.contains("habit") || lowercased.contains("routine")
            || lowercased.contains("schedule") || lowercased.contains("daily")
        {
            return .habit
        }

        return .general
    }
}
