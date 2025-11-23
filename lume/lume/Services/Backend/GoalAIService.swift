//
//  GoalAIService.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation
import FitIQCore

/// Real implementation of GoalAIServiceProtocol
/// Communicates with backend AI service for goal suggestions and tips
final class GoalAIService: GoalAIServiceProtocol {
    private let httpClient: HTTPClient
    private let tokenStorage: TokenStorageProtocol

    init(httpClient: HTTPClient, tokenStorage: TokenStorageProtocol) {
        self.httpClient = httpClient
        self.tokenStorage = tokenStorage
    }

    // MARK: - Generate Goal Suggestions

    func generateGoalSuggestions(context: UserContextData) async throws -> [GoalSuggestion] {
        let path = "/api/v1/goals/suggestions"

        // Get access token
        guard let token = try? await getAccessToken() else {
            throw GoalAIServiceError.authenticationRequired
        }

        do {
            // Backend generates suggestions based on user's existing data
            // No request body needed - it uses authenticated user's mood, journal, and goal history
            let response: GoalSuggestionsResponse = try await httpClient.post(
                path: path,
                accessToken: token
            )

            print(
                "✅ [GoalAIService] Received response with \(response.data.suggestions.count) suggestions"
            )
            if let success = response.success {
                print("📦 [GoalAIService] Success: \(success)")
            }

            let domainSuggestions = response.data.suggestions.map { $0.toDomain() }
            print("🎯 [GoalAIService] Converted to \(domainSuggestions.count) domain suggestions")

            return domainSuggestions
        } catch {
            print("❌ [GoalAIService] Failed to generate suggestions: \(error)")
            if let decodingError = error as? DecodingError {
                print("❌ [GoalAIService] Decoding error details: \(decodingError)")
            }
            throw GoalAIServiceError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Generate Consultation Goal Suggestions

    func generateConsultationGoalSuggestions(
        consultationId: UUID,
        maxSuggestions: Int = 3
    ) async throws -> [GoalSuggestion] {
        let path = "/api/v1/consultations/\(consultationId.uuidString.lowercased())/suggest-goals"

        // Get access token
        guard let token = try? await getAccessToken() else {
            throw GoalAIServiceError.authenticationRequired
        }

        // Request body with max suggestions
        struct RequestBody: Codable {
            let max_suggestions: Int
        }

        let requestBody = RequestBody(max_suggestions: maxSuggestions)

        do {
            print("🎯 [GoalAIService] Requesting consultation goal suggestions...")
            print("   Consultation ID: \(consultationId)")
            print("   Max suggestions: \(maxSuggestions)")

            let response: ConsultationGoalSuggestionsResponse = try await httpClient.post(
                path: path,
                body: requestBody,
                accessToken: token
            )

            print(
                "✅ [GoalAIService] Received \(response.data.suggestions.count) consultation-based suggestions"
            )
            print("   Persona: \(response.data.persona ?? "unknown")")

            let domainSuggestions = response.data.suggestions.map { $0.toDomain() }
            print("🎯 [GoalAIService] Converted to \(domainSuggestions.count) domain suggestions")

            return domainSuggestions
        } catch {
            print("❌ [GoalAIService] Failed to generate consultation suggestions: \(error)")
            if let decodingError = error as? DecodingError {
                print("❌ [GoalAIService] Decoding error details: \(decodingError)")
            }
            throw GoalAIServiceError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Get Goal Tips

    func getGoalTips(
        backendId: String,
        goalTitle: String,
        goalDescription: String,
        context: UserContextData
    ) async throws -> [GoalTip] {
        let path = "/api/v1/goals/\(backendId)/tips"

        // Get access token
        guard let token = try? await getAccessToken() else {
            throw GoalAIServiceError.authenticationRequired
        }

        do {
            // Backend generates tips based on goal and user's existing data
            // Uses GET method as per Swagger spec
            let response: GoalTipsResponse = try await httpClient.get(
                path: path,
                accessToken: token
            )

            return response.data.toDomain()
        } catch {
            print("❌ [GoalAIService] Failed to get tips: \(error)")
            throw GoalAIServiceError.tipsFetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Cached Suggestions

    func fetchGoalSuggestions() async throws -> [GoalSuggestion] {
        let path = "/api/v1/goals/suggestions"

        // Get access token
        guard let token = try? await getAccessToken() else {
            throw GoalAIServiceError.authenticationRequired
        }

        do {
            let response: GoalSuggestionsResponse = try await httpClient.get(
                path: path,
                accessToken: token
            )
            return response.data.suggestions.map { $0.toDomain() }
        } catch {
            print("❌ [GoalAIService] Failed to fetch suggestions: \(error)")
            throw GoalAIServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Cached Tips

    func fetchGoalTips(backendId: String) async throws -> [GoalTip] {
        let path = "/api/v1/goals/\(backendId)/tips"

        // Get access token
        guard let token = try? await getAccessToken() else {
            throw GoalAIServiceError.authenticationRequired
        }

        do {
            let response: GoalTipsResponse = try await httpClient.get(
                path: path,
                accessToken: token
            )
            return response.data.toDomain()
        } catch {
            print("❌ [GoalAIService] Failed to fetch tips: \(error)")
            throw GoalAIServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func getAccessToken() async throws -> String {
        guard let token = try await tokenStorage.getToken() else {
            throw GoalAIServiceError.authenticationRequired
        }
        return token.accessToken
    }
}

// MARK: - Note
// Request bodies removed - backend generates suggestions and tips based on
// authenticated user's existing data (mood, journal, goals) without client input

// MARK: - Mock Implementation

/// Mock implementation of GoalAIServiceProtocol for testing and previews
final class InMemoryGoalAIService: GoalAIServiceProtocol {
    func generateGoalSuggestions(context: UserContextData) async throws -> [GoalSuggestion] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Return mock suggestions
        return [
            GoalSuggestion(
                id: UUID(),
                title: "Morning Meditation Practice",
                description:
                    "Start each day with 10 minutes of mindfulness meditation to improve focus and reduce stress.",
                goalType: "meditation",
                targetValue: 10,
                targetUnit: "minutes",
                rationale:
                    "Based on your recent mood patterns, meditation could help improve emotional balance.",
                estimatedDuration: 30,
                difficulty: .easy,
                category: .mental,
                generatedAt: Date()
            ),
            GoalSuggestion(
                id: UUID(),
                title: "Daily Gratitude Journal",
                description:
                    "Write down three things you're grateful for each day to cultivate a positive mindset.",
                goalType: "journaling",
                targetValue: 3,
                targetUnit: "items",
                rationale:
                    "Your journal entries show thoughtfulness. A gratitude practice could enhance this.",
                estimatedDuration: 21,
                difficulty: .easy,
                category: .emotional,
                generatedAt: Date()
            ),
            GoalSuggestion(
                id: UUID(),
                title: "Evening Walk Routine",
                description:
                    "Take a 20-minute walk each evening to improve physical health and clear your mind.",
                goalType: "exercise",
                targetValue: 20,
                targetUnit: "minutes",
                rationale: "Regular physical activity can boost mood and energy levels.",
                estimatedDuration: 30,
                difficulty: .easy,
                category: .physical,
                generatedAt: Date()
            ),
        ]
    }

    func generateConsultationGoalSuggestions(
        consultationId: UUID,
        maxSuggestions: Int = 3
    ) async throws -> [GoalSuggestion] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Return mock consultation-based suggestions
        return [
            GoalSuggestion(
                id: UUID(),
                title: "Improve Sleep Quality",
                description:
                    "Establish a consistent sleep routine with a wind-down period before bed to improve sleep quality and duration.",
                goalType: "wellness",
                targetValue: 8,
                targetUnit: "hours",
                rationale:
                    "Based on your discussion about sleep challenges, creating a consistent routine will help regulate your circadian rhythm.",
                estimatedDuration: 30,
                difficulty: .moderate,
                category: .physical,
                generatedAt: Date()
            ),
            GoalSuggestion(
                id: UUID(),
                title: "Increase Daily Water Intake",
                description:
                    "Drink at least 8 glasses of water throughout the day to stay hydrated and support overall health.",
                goalType: "nutrition",
                targetValue: 8,
                targetUnit: "glasses",
                rationale:
                    "From our conversation about energy levels, proper hydration can significantly improve focus and reduce fatigue.",
                estimatedDuration: 21,
                difficulty: .easy,
                category: .physical,
                generatedAt: Date()
            ),
            GoalSuggestion(
                id: UUID(),
                title: "Weekly Meal Prep Sessions",
                description:
                    "Dedicate 2 hours each weekend to prepare healthy meals for the upcoming week.",
                goalType: "nutrition",
                targetValue: 2,
                targetUnit: "hours",
                rationale:
                    "Based on your interest in better nutrition, meal prep will help you maintain healthy eating habits consistently.",
                estimatedDuration: 60,
                difficulty: .moderate,
                category: .physical,
                generatedAt: Date()
            ),
        ].prefix(maxSuggestions).map { $0 }
    }

    func getGoalTips(
        backendId: String,
        goalTitle: String,
        goalDescription: String,
        context: UserContextData
    ) async throws -> [GoalTip] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Return mock tips based on goal
        return [
            GoalTip(
                id: UUID(),
                tip: "Start small - begin with just 5 minutes and gradually increase duration.",
                category: .habit,
                priority: .high
            ),
            GoalTip(
                id: UUID(),
                tip: "Set a consistent time each day to build a strong routine.",
                category: .habit,
                priority: .high
            ),
            GoalTip(
                id: UUID(),
                tip: "Track your progress daily to stay motivated and accountable.",
                category: .mindset,
                priority: .medium
            ),
            GoalTip(
                id: UUID(),
                tip:
                    "Don't be too hard on yourself if you miss a day - consistency matters more than perfection.",
                category: .mindset,
                priority: .medium
            ),
            GoalTip(
                id: UUID(),
                tip: "Consider pairing this goal with an existing habit for better adherence.",
                category: .habit,
                priority: .low
            ),
        ]
    }

    func fetchGoalSuggestions() async throws -> [GoalSuggestion] {
        // Return empty for mock - suggestions are generated on demand
        return []
    }

    func fetchGoalTips(backendId: String) async throws -> [GoalTip] {
        // Return empty for mock - tips are generated on demand
        return []
    }
}

// MARK: - Service Errors

/// Errors specific to GoalAIService
enum GoalAIServiceError: Error, LocalizedError {
    case generationFailed(String)
    case tipsFetchFailed(String)
    case fetchFailed(String)
    case invalidResponse
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return "Failed to generate goal suggestions: \(message)"
        case .tipsFetchFailed(let message):
            return "Failed to fetch goal tips: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch data: \(message)"
        case .invalidResponse:
            return "Received invalid response from server"
        case .authenticationRequired:
            return "Authentication required to access AI features"
        }
    }
}
