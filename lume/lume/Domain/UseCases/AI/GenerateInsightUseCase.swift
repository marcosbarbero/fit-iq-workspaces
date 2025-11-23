//
//  GenerateInsightUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation
import FitIQCore

/// Protocol for generating AI insights use case
protocol GenerateInsightUseCaseProtocol {
    /// Generate AI insights based on recent user data
    /// - Parameters:
    ///   - types: Optional array of specific insight types to generate
    ///   - forceRefresh: Whether to force generation even if recent insights exist
    /// - Returns: Array of newly generated AIInsight objects
    /// - Throws: Use case error if generation fails
    func execute(types: [InsightType]?, forceRefresh: Bool) async throws -> [AIInsight]
}

/// Use case for generating AI insights
/// Coordinates between repository and AI service to create personalized insights
final class GenerateInsightUseCase: GenerateInsightUseCaseProtocol {
    private let repository: AIInsightRepositoryProtocol
    private let backendService: AIInsightBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol
    private let goalRepository: GoalRepositoryProtocol

    init(
        repository: AIInsightRepositoryProtocol,
        backendService: AIInsightBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        moodRepository: MoodRepositoryProtocol,
        journalRepository: JournalRepositoryProtocol,
        goalRepository: GoalRepositoryProtocol
    ) {
        self.repository = repository
        self.backendService = backendService
        self.tokenStorage = tokenStorage
        self.moodRepository = moodRepository
        self.journalRepository = journalRepository
        self.goalRepository = goalRepository
    }

    func execute(
        types: [InsightType]? = nil,
        forceRefresh: Bool = false
    ) async throws -> [AIInsight] {
        // Determine which insight types to generate
        let insightTypes = types ?? [.daily]  // Default to daily if not specified

        // Check if we should skip generation (recent insights exist and no force refresh)
        if !forceRefresh {
            let recentInsights = try await checkRecentInsights(for: insightTypes)
            if !recentInsights.isEmpty {
                print("✨ [GenerateInsightUseCase] Recent insights exist for requested types, skipping generation")
                print("   Found \(recentInsights.count) insight(s) from last 24 hours")
                return recentInsights
            }
        }

        // Get access token
        guard let token = try? await tokenStorage.getToken(),
            !token.accessToken.isEmpty
        else {
            throw GenerateInsightError.notAuthenticated
        }

        print("🤖 [GenerateInsightUseCase] Generating \(insightTypes.count) insight(s)")

        // Generate insights for each type
        var generatedInsights: [AIInsight] = []

        for insightType in insightTypes {
            do {
                print("   📝 Generating \(insightType.rawValue) insight...")

                // Call backend generate endpoint
                let insight = try await backendService.generateInsight(
                    insightType: insightType,
                    periodStart: nil,  // Let backend calculate period
                    periodEnd: nil,  // Let backend calculate period
                    accessToken: token.accessToken
                )

                // Save to local repository
                let savedInsight = try await repository.save(insight)
                generatedInsights.append(savedInsight)

                print("   ✅ Generated and saved \(insightType.rawValue) insight")
            } catch {
                print("   ⚠️ Failed to generate \(insightType.rawValue) insight: \(error)")
                // Continue with other types even if one fails
            }
        }

        guard !generatedInsights.isEmpty else {
            throw GenerateInsightError.noInsightsGenerated
        }

        print(
            "✅ [GenerateInsightUseCase] Successfully generated \(generatedInsights.count) insight(s)"
        )
        return generatedInsights
    }
}

// MARK: - Private Helpers

extension GenerateInsightUseCase {
    /// Check for recent insights of specific types (within last 24 hours)
    fileprivate func checkRecentInsights(for types: [InsightType]) async throws -> [AIInsight] {
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let allInsights = try await repository.fetchAll()

        print("   🔍 Checking for recent insights (last 24 hours)")
        print("   Total insights in DB: \(allInsights.count)")

        let recentInsights = allInsights.filter { insight in
            let isRecent = insight.createdAt > oneDayAgo
            let isNotArchived = !insight.isArchived
            let matchesType = types.contains(insight.insightType)

            if isRecent && isNotArchived && matchesType {
                print("   ✓ Found recent \(insight.insightType.rawValue) insight from \(insight.createdAt)")
            }

            return isRecent && isNotArchived && matchesType
        }

        print("   Found \(recentInsights.count) recent insight(s) matching requested types")
        return recentInsights
    }

    /// Check if generation is allowed (not more than once per day for daily insights)
    func canGenerateInsight(type: InsightType) async throws -> Bool {
        let insights = try await checkRecentInsights(for: [type])
        return insights.isEmpty
    }
}

// MARK: - Convenience Methods

extension GenerateInsightUseCase {
    /// Generate all default insight types
    func generateAll(forceRefresh: Bool = false) async throws -> [AIInsight] {
        try await execute(types: nil, forceRefresh: forceRefresh)
    }

    /// Generate specific type of insight
    func generate(type: InsightType, forceRefresh: Bool = false) async throws -> [AIInsight] {
        try await execute(types: [type], forceRefresh: forceRefresh)
    }

    /// Fetch mood-related insights from backend
    func generateMoodInsights(forceRefresh: Bool = false) async throws -> [AIInsight] {
        try await execute(
            types: [.daily],
            forceRefresh: forceRefresh
        )
    }

    /// Fetch goal-related insights from backend
    func generateGoalInsights(forceRefresh: Bool = false) async throws -> [AIInsight] {
        try await execute(
            types: [.milestone],
            forceRefresh: forceRefresh
        )
    }

    /// Generate weekly summary
    func generateWeeklySummary(forceRefresh: Bool = false) async throws -> [AIInsight] {
        try await execute(
            types: [.weekly],
            forceRefresh: forceRefresh
        )
    }
}

// MARK: - Errors

/// Errors specific to GenerateInsightUseCase
enum GenerateInsightError: Error, LocalizedError {
    case insufficientData
    case noInsightsGenerated
    case notAuthenticated
    case contextBuildFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .insufficientData:
            return "Not enough user data to generate insights."
        case .noInsightsGenerated:
            return "Failed to generate any insights."
        case .notAuthenticated:
            return "User is not authenticated."
        case .contextBuildFailed:
            return "Failed to build user context for AI."
        case .saveFailed:
            return "Failed to save generated insights."
        }
    }
}
