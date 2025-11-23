//
//  GoalBackendService.swift
//  lume
//
//  Created by AI Assistant on 29/01/2025.
//

import Foundation

/// Backend service for goals with AI consulting support
/// Handles communication with goals API endpoints
protocol GoalBackendServiceProtocol {
    /// Create a new goal
    /// - Parameters:
    ///   - goal: The goal to create
    ///   - accessToken: User's access token
    /// - Returns: The backend ID of the created goal
    /// - Throws: HTTPError if request fails
    func createGoal(
        _ goal: Goal,
        accessToken: String
    ) async throws -> String

    /// Update an existing goal
    /// - Parameters:
    ///   - goal: The goal to update
    ///   - backendId: The backend ID of the goal
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func updateGoal(
        _ goal: Goal,
        backendId: String,
        accessToken: String
    ) async throws

    /// Delete a goal
    /// - Parameters:
    ///   - backendId: The backend ID of the goal to delete
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func deleteGoal(
        backendId: String,
        accessToken: String
    ) async throws

    /// Fetch all goals for the user
    /// - Parameter accessToken: User's access token
    /// - Returns: Array of Goal objects
    /// - Throws: HTTPError if request fails
    func fetchAllGoals(accessToken: String) async throws -> [Goal]

    /// Fetch active goals
    /// - Parameter accessToken: User's access token
    /// - Returns: Array of active Goal objects
    /// - Throws: HTTPError if request fails
    func fetchActiveGoals(accessToken: String) async throws -> [Goal]

    /// Fetch goals by category
    /// - Parameters:
    ///   - category: The goal category to filter by
    ///   - accessToken: User's access token
    /// - Returns: Array of Goal objects in the specified category
    /// - Throws: HTTPError if request fails
    func fetchGoalsByCategory(
        category: GoalCategory,
        accessToken: String
    ) async throws -> [Goal]

    /// Get AI suggestions for a goal
    /// - Parameters:
    ///   - goalId: The ID of the goal
    ///   - accessToken: User's access token
    /// - Returns: AI-generated suggestions for the goal
    /// - Throws: HTTPError if request fails
    func getAISuggestions(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalAISuggestions

    /// Get AI tips for goal achievement
    /// - Parameters:
    ///   - goalId: The ID of the goal
    ///   - accessToken: User's access token
    /// - Returns: AI-generated tips for achieving the goal
    /// - Throws: HTTPError if request fails
    func getAITips(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalAITips

    /// Get AI progress analysis for a goal
    /// - Parameters:
    ///   - goalId: The ID of the goal
    ///   - accessToken: User's access token
    /// - Returns: AI analysis of goal progress
    /// - Throws: HTTPError if request fails
    func getProgressAnalysis(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalProgressAnalysis
}

/// AI-generated suggestions for a goal
struct GoalAISuggestions: Codable, Equatable {
    let goalId: UUID
    let suggestions: [String]
    let nextSteps: [String]
    let motivationalMessage: String?
    let generatedAt: Date

    var hasSuggestions: Bool {
        !suggestions.isEmpty
    }

    var hasNextSteps: Bool {
        !nextSteps.isEmpty
    }
}

/// AI-generated tips for goal achievement
struct GoalAITips: Codable, Equatable {
    let goalId: UUID
    let tips: [GoalAITipItem]
    let category: GoalCategory
    let generatedAt: Date

    var hasTips: Bool {
        !tips.isEmpty
    }
}

/// Individual tip item for goal achievement from AI
struct GoalAITipItem: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let priority: GoalTipPriority

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        priority: GoalTipPriority = .medium
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
    }
}

/// Priority level for AI tips
enum GoalTipPriority: String, Codable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .high:
            return "High Priority"
        case .medium:
            return "Medium Priority"
        case .low:
            return "Low Priority"
        }
    }

    var systemImage: String {
        switch self {
        case .high:
            return "exclamationmark.circle.fill"
        case .medium:
            return "circle.fill"
        case .low:
            return "circle"
        }
    }
}

/// AI analysis of goal progress
struct GoalProgressAnalysis: Codable, Equatable {
    let goalId: UUID
    let currentProgress: Double
    let projectedCompletion: Date?
    let analysis: String
    let recommendations: [String]
    let strengths: [String]
    let challenges: [String]
    let generatedAt: Date

    var hasRecommendations: Bool {
        !recommendations.isEmpty
    }

    var hasStrengths: Bool {
        !strengths.isEmpty
    }

    var hasChallenges: Bool {
        !challenges.isEmpty
    }

    var progressPercentage: Int {
        Int(currentProgress * 100)
    }
}

final class GoalBackendService: GoalBackendServiceProtocol {

    // MARK: - Properties

    private let httpClient: HTTPClient

    // MARK: - Initialization

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    // MARK: - Goal CRUD Operations

    func createGoal(
        _ goal: Goal,
        accessToken: String
    ) async throws -> String {
        let request = CreateGoalRequest(goal: goal)

        let response: GoalResponse = try await httpClient.post(
            path: "/api/v1/goals",
            body: request,
            accessToken: accessToken
        )

        print("✅ [GoalBackendService] Created goal: \(goal.id), backend ID: \(response.data.id)")
        return response.data.id
    }

    func updateGoal(
        _ goal: Goal,
        backendId: String,
        accessToken: String
    ) async throws {
        let request = UpdateGoalRequest(goal: goal)

        let _: GoalResponse = try await httpClient.put(
            path: "/api/v1/goals/\(backendId)",
            body: request,
            accessToken: accessToken
        )

        print("✅ [GoalBackendService] Updated goal: \(goal.id), backend ID: \(backendId)")
    }

    func deleteGoal(
        backendId: String,
        accessToken: String
    ) async throws {
        try await httpClient.delete(
            path: "/api/v1/goals/\(backendId)",
            accessToken: accessToken
        )

        print("✅ [GoalBackendService] Deleted goal with backend ID: \(backendId)")
    }

    func fetchAllGoals(accessToken: String) async throws -> [Goal] {
        let response: GoalsListResponse = try await httpClient.get(
            path: "/api/v1/goals",
            accessToken: accessToken
        )

        let goals = response.data.goals.map { $0.toDomain() }
        print("✅ [GoalBackendService] Fetched \(goals.count) goals")
        return goals
    }

    func fetchActiveGoals(accessToken: String) async throws -> [Goal] {
        let response: GoalsListResponse = try await httpClient.get(
            path: "/api/v1/goals",
            queryParams: ["status": "active"],
            accessToken: accessToken
        )

        let goals = response.data.goals.map { $0.toDomain() }
        print("✅ [GoalBackendService] Fetched \(goals.count) active goals")
        return goals
    }

    func fetchGoalsByCategory(
        category: GoalCategory,
        accessToken: String
    ) async throws -> [Goal] {
        let response: GoalsListResponse = try await httpClient.get(
            path: "/api/v1/goals",
            queryParams: ["category": category.rawValue],
            accessToken: accessToken
        )

        let goals = response.data.goals.map { $0.toDomain() }
        print("✅ [GoalBackendService] Fetched \(goals.count) \(category.rawValue) goals")
        return goals
    }

    // MARK: - AI Features

    func getAISuggestions(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalAISuggestions {
        let response: AISuggestionsResponse = try await httpClient.get(
            path: "/api/v1/goals/\(backendId)/suggestions",
            accessToken: accessToken
        )

        print("✅ [GoalBackendService] Fetched AI suggestions for goal backend ID: \(backendId)")
        return response.data.toDomain()
    }

    func getAITips(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalAITips {
        let response: AITipsResponse = try await httpClient.get(
            path: "/api/v1/goals/\(backendId)/tips",
            accessToken: accessToken
        )

        print("✅ [GoalBackendService] Fetched AI tips for goal backend ID: \(backendId)")
        return response.data.toDomain()
    }

    func getProgressAnalysis(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalProgressAnalysis {
        let response: ProgressAnalysisResponse = try await httpClient.get(
            path: "/api/v1/goals/\(backendId)/analysis",
            accessToken: accessToken
        )

        print("✅ [GoalBackendService] Fetched progress analysis for goal backend ID: \(backendId)")
        return response.data.toDomain()
    }
}

// MARK: - Request/Response Models

/// Request body for creating a goal
private struct CreateGoalRequest: Encodable {
    let title: String
    let description: String
    let start_date: String
    let target_date: String
    let goal_type: String
    let target_value: Double
    let target_unit: String

    init(goal: Goal) {
        self.title = goal.title
        self.description = goal.description

        // Map category to goal_type
        // Backend expects: activity, nutrition, sleep, mindfulness, custom
        switch goal.category {
        case .physical:
            self.goal_type = "activity"
        case .mental:
            self.goal_type = "mindfulness"
        case .emotional:
            self.goal_type = "mindfulness"
        case .spiritual:
            self.goal_type = "mindfulness"
        default:
            self.goal_type = "custom"
        }

        // Target tracking (required by backend)
        self.target_value = max(goal.targetValue, 0.01)  // Must be > 0
        self.target_unit = goal.targetUnit

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        // start_date is required - use goal's createdAt date
        self.start_date = formatter.string(from: goal.createdAt)

        // target_date is required by backend - default to 30 days from start if not provided
        let targetDate =
            goal.targetDate ?? Calendar.current.date(byAdding: .day, value: 30, to: goal.createdAt)
            ?? goal.createdAt
        self.target_date = formatter.string(from: targetDate)
    }
}

/// Request body for updating a goal
private struct UpdateGoalRequest: Encodable {
    let title: String
    let description: String
    let target_date: String?
    let progress: Double
    let status: String
    let goal_type: String
    let target_value: Double
    let target_unit: String
    let current_value: Double

    init(goal: Goal) {
        self.title = goal.title
        self.description = goal.description
        self.progress = goal.progress
        self.status = goal.status.rawValue

        // Map category to goal_type
        switch goal.category {
        case .physical:
            self.goal_type = "activity"
        case .mental:
            self.goal_type = "mindfulness"
        case .emotional:
            self.goal_type = "mindfulness"
        case .spiritual:
            self.goal_type = "mindfulness"
        default:
            self.goal_type = "custom"
        }

        // Target tracking (required by backend)
        self.target_value = max(goal.targetValue, 0.01)
        self.target_unit = goal.targetUnit
        self.current_value = goal.currentValue

        if let targetDate = goal.targetDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            self.target_date = formatter.string(from: targetDate)
        } else {
            self.target_date = nil
        }
    }
}

/// Response containing a single goal
private struct GoalResponse: Decodable {
    let data: GoalDTO
}

/// Response containing a list of goals
private struct GoalsListResponse: Decodable {
    let data: GoalsListData
}

/// List data wrapper
private struct GoalsListData: Decodable {
    let goals: [GoalDTO]
    let total: Int
    let has_more: Bool
}

/// DTO for goal from backend
private struct GoalDTO: Decodable {
    let id: String
    let user_id: String
    let title: String
    let description: String
    let created_at: String
    let updated_at: String
    let start_date: String?
    let target_date: String?
    let progress: Double
    let status: String
    let category: String?
    let goal_type: String?
    let target_value: Double
    let target_unit: String
    let current_value: Double

    func toDomain() -> Goal {
        // Parse dates with flexible decoder that handles nanosecond precision
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Fallback formatter without fractional seconds
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        func parseDate(_ dateString: String) -> Date {
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
            if let date = fallbackFormatter.date(from: dateString) {
                return date
            }
            // Last resort: return current date
            return Date()
        }

        let createdDate = parseDate(created_at)
        let updatedDate = parseDate(updated_at)
        let targetDateParsed = target_date.flatMap { parseDate($0) }

        return Goal(
            id: UUID(uuidString: id) ?? UUID(),
            userId: UUID(uuidString: user_id) ?? UUID(),
            title: title,
            description: description,
            createdAt: createdDate,
            updatedAt: updatedDate,
            targetDate: targetDateParsed,
            progress: progress,
            status: GoalStatus(rawValue: status) ?? .active,
            category: GoalCategory(rawValue: category ?? "general") ?? .general,
            targetValue: target_value,
            targetUnit: target_unit,
            currentValue: current_value,
            backendId: id  // Store the backend-assigned ID
        )
    }
}

/// Response for AI suggestions
private struct AISuggestionsResponse: Decodable {
    let data: AISuggestionsDTO
}

/// DTO for AI suggestions
private struct AISuggestionsDTO: Decodable {
    let goal_id: String
    let suggestions: [String]
    let next_steps: [String]
    let motivational_message: String?
    let generated_at: Date

    func toDomain() -> GoalAISuggestions {
        GoalAISuggestions(
            goalId: UUID(uuidString: goal_id) ?? UUID(),
            suggestions: suggestions,
            nextSteps: next_steps,
            motivationalMessage: motivational_message,
            generatedAt: generated_at
        )
    }
}

/// Response for AI tips
private struct AITipsResponse: Decodable {
    let data: AITipsDTO
}

/// DTO for AI tips
private struct AITipsDTO: Decodable {
    let goal_id: String
    let tips: [GoalAITipItemDTO]
    let category: String
    let generated_at: Date

    func toDomain() -> GoalAITips {
        GoalAITips(
            goalId: UUID(uuidString: goal_id) ?? UUID(),
            tips: tips.map { $0.toDomain() },
            category: GoalCategory(rawValue: category) ?? .general,
            generatedAt: generated_at
        )
    }
}

/// DTO for individual goal tip item
private struct GoalAITipItemDTO: Decodable {
    let id: String
    let title: String
    let description: String
    let priority: String

    func toDomain() -> GoalAITipItem {
        GoalAITipItem(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            description: description,
            priority: GoalTipPriority(rawValue: priority) ?? .medium
        )
    }
}

/// Response for progress analysis
private struct ProgressAnalysisResponse: Decodable {
    let data: ProgressAnalysisDTO
}

/// DTO for progress analysis
private struct ProgressAnalysisDTO: Decodable {
    let goal_id: String
    let current_progress: Double
    let projected_completion: Date?
    let analysis: String
    let recommendations: [String]
    let strengths: [String]
    let challenges: [String]
    let generated_at: Date

    func toDomain() -> GoalProgressAnalysis {
        GoalProgressAnalysis(
            goalId: UUID(uuidString: goal_id) ?? UUID(),
            currentProgress: current_progress,
            projectedCompletion: projected_completion,
            analysis: analysis,
            recommendations: recommendations,
            strengths: strengths,
            challenges: challenges,
            generatedAt: generated_at
        )
    }
}

// MARK: - Mock Implementation

final class InMemoryGoalBackendService: GoalBackendServiceProtocol {

    var shouldFail = false
    var goals: [String: Goal] = [:]

    func createGoal(
        _ goal: Goal,
        accessToken: String
    ) async throws -> String {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let backendId = UUID().uuidString
        goals[backendId] = goal

        print(
            "🔵 [InMemoryGoalBackendService] Created mock goal: \(goal.id), backend ID: \(backendId)"
        )
        return backendId
    }

    func updateGoal(
        _ goal: Goal,
        backendId: String,
        accessToken: String
    ) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        goals[backendId] = goal
        print(
            "🔵 [InMemoryGoalBackendService] Updated mock goal: \(goal.id), backend ID: \(backendId)"
        )
    }

    func deleteGoal(
        backendId: String,
        accessToken: String
    ) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        goals.removeValue(forKey: backendId)
        print("🔵 [InMemoryGoalBackendService] Deleted mock goal with backend ID: \(backendId)")
    }

    func fetchAllGoals(accessToken: String) async throws -> [Goal] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let allGoals = Array(goals.values)
        print("🔵 [InMemoryGoalBackendService] Fetched \(allGoals.count) mock goals")
        return allGoals
    }

    func fetchActiveGoals(accessToken: String) async throws -> [Goal] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let activeGoals = goals.values.filter { $0.status == .active }
        print("🔵 [InMemoryGoalBackendService] Fetched \(activeGoals.count) active mock goals")
        return Array(activeGoals)
    }

    func fetchGoalsByCategory(
        category: GoalCategory,
        accessToken: String
    ) async throws -> [Goal] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let filteredGoals = goals.values.filter { $0.category == category }
        print(
            "🔵 [InMemoryGoalBackendService] Fetched \(filteredGoals.count) \(category.rawValue) mock goals"
        )
        return Array(filteredGoals)
    }

    func getAISuggestions(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalAISuggestions {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Convert backend ID string to UUID for mock response
        let goalUUID = UUID(uuidString: backendId) ?? UUID()

        let suggestions = GoalAISuggestions(
            goalId: goalUUID,
            suggestions: [
                "Break down your goal into smaller, manageable steps",
                "Set specific milestones to track your progress",
                "Celebrate small wins along the way",
            ],
            nextSteps: [
                "Define your first action step",
                "Schedule time in your calendar",
                "Share your goal with a friend for accountability",
            ],
            motivationalMessage: "You've got this! Every step forward is progress.",
            generatedAt: Date()
        )

        print(
            "🔵 [InMemoryGoalBackendService] Generated mock AI suggestions for backend ID: \(backendId)"
        )
        return suggestions
    }

    func getAITips(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalAITips {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Convert backend ID string to UUID for mock response
        let goalUUID = UUID(uuidString: backendId) ?? UUID()

        let tips = GoalAITips(
            goalId: goalUUID,
            tips: [
                GoalAITipItem(
                    title: "Start Small",
                    description: "Begin with easy wins to build momentum and confidence.",
                    priority: .high
                ),
                GoalAITipItem(
                    title: "Track Progress",
                    description: "Keep a record of your achievements, no matter how small.",
                    priority: .medium
                ),
                GoalAITipItem(
                    title: "Stay Consistent",
                    description:
                        "Regular, small actions are more effective than occasional big efforts.",
                    priority: .medium
                ),
            ],
            category: .general,
            generatedAt: Date()
        )

        print("🔵 [InMemoryGoalBackendService] Generated mock AI tips for backend ID: \(backendId)")
        return tips
    }

    func getProgressAnalysis(
        for backendId: String,
        accessToken: String
    ) async throws -> GoalProgressAnalysis {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        // Convert backend ID string to UUID for mock response
        let goalUUID = UUID(uuidString: backendId) ?? UUID()

        let analysis = GoalProgressAnalysis(
            goalId: goalUUID,
            currentProgress: 0.35,
            projectedCompletion: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            analysis:
                "You're making steady progress! Based on your current pace, you're on track to achieve this goal.",
            recommendations: [
                "Maintain your current momentum",
                "Consider increasing effort slightly to finish ahead of schedule",
                "Reflect on what's working well and continue those practices",
            ],
            strengths: [
                "Consistent effort over the past week",
                "Clear understanding of the goal",
                "Good self-awareness of challenges",
            ],
            challenges: [
                "Time management during busy periods",
                "Maintaining motivation on difficult days",
            ],
            generatedAt: Date()
        )

        print(
            "🔵 [InMemoryGoalBackendService] Generated mock progress analysis for backend ID: \(backendId)"
        )
        return analysis
    }
}
