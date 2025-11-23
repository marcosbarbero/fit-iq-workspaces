//
//  GoalsViewModel.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// ViewModel for Goals feature
/// Manages goals list, AI suggestions, and tips
@Observable
@MainActor
final class GoalsViewModel {

    // MARK: - Published State

    /// All goals fetched from repository
    var goals: [Goal] = []

    /// AI-generated goal suggestions
    var suggestions: [GoalSuggestion] = []

    /// Tips for a specific goal
    var currentGoalTips: [GoalTip] = []

    /// Loading states
    var isLoadingGoals = false
    var isLoadingSuggestions = false
    var isLoadingTips = false

    /// Error handling
    var errorMessage: String?

    // MARK: - Dependencies

    private let fetchGoalsUseCase: FetchGoalsUseCase
    private let createGoalUseCase: CreateGoalUseCase
    private let updateGoalUseCase: UpdateGoalUseCase
    private let generateSuggestionsUseCase: GenerateGoalSuggestionsUseCase
    private let getGoalTipsUseCase: GetGoalTipsUseCase

    // MARK: - Initialization

    init(
        fetchGoalsUseCase: FetchGoalsUseCase,
        createGoalUseCase: CreateGoalUseCase,
        updateGoalUseCase: UpdateGoalUseCase,
        generateSuggestionsUseCase: GenerateGoalSuggestionsUseCase,
        getGoalTipsUseCase: GetGoalTipsUseCase
    ) {
        self.fetchGoalsUseCase = fetchGoalsUseCase
        self.createGoalUseCase = createGoalUseCase
        self.updateGoalUseCase = updateGoalUseCase
        self.generateSuggestionsUseCase = generateSuggestionsUseCase
        self.getGoalTipsUseCase = getGoalTipsUseCase
    }

    // MARK: - Goals Management

    /// Load all goals
    func loadGoals() async {
        isLoadingGoals = true
        errorMessage = nil
        defer { isLoadingGoals = false }

        do {
            goals = try await fetchGoalsUseCase.execute()
            print("✅ [GoalsViewModel] Loaded \(goals.count) goals")
            if !goals.isEmpty {
                print("📋 [GoalsViewModel] Goals list:")
                for goal in goals {
                    print("   - \(goal.title) (status: \(goal.status), category: \(goal.category))")
                }
            } else {
                print("⚠️ [GoalsViewModel] Goals array is empty after fetch")
            }
        } catch {
            errorMessage = "Failed to load goals: \(error.localizedDescription)"
            print("❌ [GoalsViewModel] Failed to load goals: \(error)")
        }
    }

    /// Create a new goal
    func createGoal(title: String, description: String, category: GoalCategory, targetDate: Date?)
        async
    {
        errorMessage = nil

        do {
            _ = try await createGoalUseCase.execute(
                title: title,
                description: description,
                category: category,
                targetDate: targetDate
            )
            await loadGoals()  // Refresh list
            print("✅ [GoalsViewModel] Goal created: \(title)")
        } catch {
            errorMessage = "Failed to create goal: \(error.localizedDescription)"
            print("❌ [GoalsViewModel] Failed to create goal: \(error)")
        }
    }

    /// Create a goal from an AI suggestion
    func createGoalFromSuggestion(_ suggestion: GoalSuggestion) async {
        errorMessage = nil

        do {
            let createdGoal = try await createGoalUseCase.execute(
                title: suggestion.title,
                description: suggestion.description,
                category: suggestion.category,
                targetDate: suggestion.estimatedTargetDate
            )
            print("✅ [GoalsViewModel] Goal created from suggestion: \(suggestion.title)")
            print("   - ID: \(createdGoal.id)")
            print("   - Status: \(createdGoal.status)")
            print("   - Category: \(createdGoal.category)")

            print("🔄 [GoalsViewModel] Refreshing goals list...")
            await loadGoals()  // Refresh list

            print("📊 [GoalsViewModel] After refresh: \(goals.count) total goals")
            print("   - Active: \(activeGoals.count)")
            print("   - Completed: \(completedGoals.count)")
        } catch {
            errorMessage = "Failed to create goal from suggestion: \(error.localizedDescription)"
            print("❌ [GoalsViewModel] Failed to create goal from suggestion: \(error)")
        }
    }

    /// Update an existing goal
    func updateGoal(
        goalId: UUID,
        title: String?,
        description: String?,
        category: GoalCategory?,
        targetDate: Date?,
        progress: Double?,
        status: GoalStatus?
    ) async {
        errorMessage = nil

        do {
            _ = try await updateGoalUseCase.execute(
                goalId: goalId,
                title: title,
                description: description,
                category: category,
                targetDate: targetDate,
                progress: progress,
                status: status
            )
            await loadGoals()  // Refresh list
            print("✅ [GoalsViewModel] Goal updated: \(goalId)")
        } catch {
            errorMessage = "Failed to update goal: \(error.localizedDescription)"
            print("❌ [GoalsViewModel] Failed to update goal: \(error)")
        }
    }

    /// Update goal progress
    func updateProgress(goalId: UUID, progress: Double) async {
        await updateGoal(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: progress,
            status: nil
        )
    }

    /// Complete a goal
    func completeGoal(_ goalId: UUID) async {
        await updateGoal(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: 1.0,
            status: .completed
        )
    }

    /// Archive a goal
    func archiveGoal(_ goalId: UUID) async {
        await updateGoal(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: nil,
            status: .archived
        )
    }

    /// Pause a goal
    func pauseGoal(_ goalId: UUID) async {
        await updateGoal(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: nil,
            status: .paused
        )
    }

    /// Resume a goal (set back to active)
    func resumeGoal(_ goalId: UUID) async {
        await updateGoal(
            goalId: goalId,
            title: nil,
            description: nil,
            category: nil,
            targetDate: nil,
            progress: nil,
            status: .active
        )
    }

    /// Delete a goal
    func deleteGoal(_ goalId: UUID) async {
        errorMessage = nil

        // Find the goal first to check if it exists
        guard goals.contains(where: { $0.id == goalId }) else {
            print("⚠️ [GoalsViewModel] Goal not found: \(goalId)")
            return
        }

        // Note: We'll need to add a DeleteGoalUseCase for proper architecture
        // For now, we'll use archive as a soft delete
        await archiveGoal(goalId)
        print("✅ [GoalsViewModel] Goal deleted (archived): \(goalId)")
    }

    // MARK: - AI Suggestions

    /// Generate AI goal suggestions
    func generateSuggestions() async {
        isLoadingSuggestions = true
        errorMessage = nil
        defer { isLoadingSuggestions = false }

        do {
            suggestions = try await generateSuggestionsUseCase.execute()
            print("✅ [GoalsViewModel] Generated \(suggestions.count) suggestions")
        } catch {
            errorMessage = "Failed to generate suggestions: \(error.localizedDescription)"
            print("❌ [GoalsViewModel] Failed to generate suggestions: \(error)")
        }
    }

    // MARK: - Goal Tips

    /// Get AI tips for a specific goal
    func getGoalTips(for goal: Goal) async {
        isLoadingTips = true
        errorMessage = nil
        defer { isLoadingTips = false }

        do {
            currentGoalTips = try await getGoalTipsUseCase.execute(goalId: goal.id)
            print("✅ [GoalsViewModel] Got \(currentGoalTips.count) tips for goal: \(goal.title)")
        } catch {
            errorMessage = "Failed to get tips: \(error.localizedDescription)"
            print("❌ [GoalsViewModel] Failed to get tips: \(error)")
        }
    }

    // MARK: - Helpers

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Get goals by status
    func goals(withStatus status: GoalStatus) -> [Goal] {
        goals.filter { $0.status == status }
    }

    /// Get goals by category
    func goals(inCategory category: GoalCategory) -> [Goal] {
        goals.filter { $0.category == category }
    }

    // MARK: - Computed Properties

    /// Active goals
    var activeGoals: [Goal] {
        goals(withStatus: .active)
    }

    /// Completed goals
    var completedGoals: [Goal] {
        goals(withStatus: .completed)
    }

    /// Paused goals
    var pausedGoals: [Goal] {
        goals(withStatus: .paused)
    }

    /// Archived goals
    var archivedGoals: [Goal] {
        goals(withStatus: .archived)
    }

    /// At-risk goals (low progress, near deadline)
    var atRiskGoals: [Goal] {
        activeGoals.filter { goal in
            guard let targetDate = goal.targetDate else { return false }
            let daysRemaining =
                Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
            return daysRemaining <= 7 && goal.progress < 0.7
        }
    }
}
