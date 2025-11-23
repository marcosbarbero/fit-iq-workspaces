//
//  GoalTipsView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//

import SwiftUI

/// View displaying AI-powered tips for achieving a specific goal
struct GoalTipsView: View {
    @Environment(\.dismiss) var dismiss
    let goal: Goal
    @Bindable var viewModel: GoalsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Goal Context Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: goal.category.icon)
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: goal.category.colorHex))

                            Spacer()
                        }

                        Text(goal.title)
                            .font(LumeTypography.titleMedium)
                            .foregroundColor(LumeColors.textPrimary)

                        if !goal.description.isEmpty {
                            Text(goal.description)
                                .font(LumeTypography.bodySmall)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }
                    .padding(16)
                    .background(LumeColors.surface)
                    .cornerRadius(12)

                    // Loading State
                    if viewModel.isLoadingTips {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(LumeColors.textSecondary)

                            Text("Getting personalized tips...")
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    // Error State
                    else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "#F0B8A4"))

                            Text(errorMessage)
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textSecondary)
                                .multilineTextAlignment(.center)

                            Button {
                                Task {
                                    await viewModel.getGoalTips(for: goal)
                                }
                            } label: {
                                Text("Try Again")
                                    .font(LumeTypography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(LumeColors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LumeColors.accentPrimary)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.vertical, 20)
                    }

                    // Tips Content
                    else if !viewModel.currentGoalTips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Personalized Tips")
                                .font(LumeTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(LumeColors.textPrimary)

                            Text(
                                "Here are some AI-powered suggestions to help you achieve your goal."
                            )
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)
                        }

                        // Group tips by priority
                        let highPriorityTips = viewModel.currentGoalTips.filter {
                            $0.priority == .high
                        }
                        let mediumPriorityTips = viewModel.currentGoalTips.filter {
                            $0.priority == .medium
                        }
                        let lowPriorityTips = viewModel.currentGoalTips.filter {
                            $0.priority == .low
                        }

                        // High Priority Tips
                        if !highPriorityTips.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("High Priority")
                                        .font(LumeTypography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(LumeColors.textPrimary)
                                } icon: {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(Color(hex: "#F0B8A4"))
                                }

                                ForEach(highPriorityTips) { tip in
                                    TipCard(tip: tip)
                                }
                            }
                        }

                        // Medium Priority Tips
                        if !mediumPriorityTips.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("Recommended")
                                        .font(LumeTypography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(LumeColors.textPrimary)
                                } icon: {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundColor(LumeColors.accentPrimary)
                                }

                                ForEach(mediumPriorityTips) { tip in
                                    TipCard(tip: tip)
                                }
                            }
                        }

                        // Low Priority Tips
                        if !lowPriorityTips.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("Additional Tips")
                                        .font(LumeTypography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(LumeColors.textPrimary)
                                } icon: {
                                    Image(systemName: "lightbulb.circle.fill")
                                        .foregroundColor(LumeColors.accentSecondary)
                                }

                                ForEach(lowPriorityTips) { tip in
                                    TipCard(tip: tip)
                                }
                            }
                        }
                    }

                    // Empty State
                    else {
                        VStack(spacing: 16) {
                            Image(systemName: "lightbulb.slash")
                                .font(.system(size: 48))
                                .foregroundColor(LumeColors.textSecondary.opacity(0.5))

                            Text("No tips available yet")
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textSecondary)

                            Text("Try generating tips for this goal.")
                                .font(LumeTypography.bodySmall)
                                .foregroundColor(LumeColors.textSecondary)
                                .multilineTextAlignment(.center)

                            Button {
                                Task {
                                    await viewModel.getGoalTips(for: goal)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                    Text("Get Tips")
                                }
                                .font(LumeTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(LumeColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#D8C8EA"))
                                .cornerRadius(12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(20)
            }
            .background(LumeColors.appBackground)
            .navigationTitle("AI Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.getGoalTips(for: goal)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(LumeColors.textPrimary)
                    }
                    .disabled(viewModel.isLoadingTips)
                }
            }
        }
        .task {
            // Auto-load tips if not already loaded
            if viewModel.currentGoalTips.isEmpty && !viewModel.isLoadingTips {
                await viewModel.getGoalTips(for: goal)
            }
        }
    }
}

// MARK: - Tip Card Component

private struct TipCard: View {
    let tip: GoalTip

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category Icon
            Image(systemName: tip.category.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(categoryColor)
                .cornerRadius(8)

            // Tip Content
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.category.displayName)
                    .font(LumeTypography.caption)
                    .foregroundColor(categoryColor)
                    .fontWeight(.semibold)

                Text(tip.tip)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(LumeColors.surface)
        .cornerRadius(12)
    }

    private var categoryColor: Color {
        switch tip.category {
        case .general:
            return LumeColors.accentPrimary
        case .nutrition:
            return Color(hex: "#F5DFA8")
        case .exercise:
            return Color(hex: "#F0B8A4")
        case .sleep:
            return LumeColors.accentSecondary
        case .mindset:
            return Color(hex: "#D8C8EA")
        case .habit:
            return Color(hex: "#D8E8C8")
        }
    }
}

// MARK: - Preview

#Preview("Goal Tips - Loading") {
    let dependencies = AppDependencies()
    let viewModel = dependencies.makeGoalsViewModel()
    viewModel.isLoadingTips = true

    let sampleGoal = Goal(
        id: UUID(),
        userId: UUID(),
        title: "Exercise 3x per week",
        description: "Build a consistent workout routine",
        createdAt: Date(),
        updatedAt: Date(),
        targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
        progress: 0.3,
        status: .active,
        category: .physical
    )

    return GoalTipsView(goal: sampleGoal, viewModel: viewModel)
}

#Preview("Goal Tips - With Tips") {
    let dependencies = AppDependencies()
    let viewModel = dependencies.makeGoalsViewModel()

    viewModel.currentGoalTips = [
        GoalTip(
            tip: "Start with just 10 minutes of exercise. Small wins build momentum!",
            category: .mindset,
            priority: .high
        ),
        GoalTip(
            tip: "Schedule your workouts in your calendar like any other important appointment.",
            category: .habit,
            priority: .high
        ),
        GoalTip(
            tip:
                "Try morning workouts - they're less likely to get skipped due to daily distractions.",
            category: .general,
            priority: .medium
        ),
        GoalTip(
            tip: "Find an accountability partner or join a fitness community for motivation.",
            category: .mindset,
            priority: .medium
        ),
        GoalTip(
            tip: "Fuel your workouts with a balanced pre-exercise snack 30-60 minutes before.",
            category: .nutrition,
            priority: .low
        ),
        GoalTip(
            tip: "Ensure you're getting 7-9 hours of sleep to support recovery and energy.",
            category: .sleep,
            priority: .low
        ),
    ]

    let sampleGoal = Goal(
        id: UUID(),
        userId: UUID(),
        title: "Exercise 3x per week",
        description: "Build a consistent workout routine",
        createdAt: Date(),
        updatedAt: Date(),
        targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
        progress: 0.3,
        status: .active,
        category: .physical
    )

    return GoalTipsView(goal: sampleGoal, viewModel: viewModel)
}

#Preview("Goal Tips - Empty") {
    let dependencies = AppDependencies()
    let viewModel = dependencies.makeGoalsViewModel()

    let sampleGoal = Goal(
        id: UUID(),
        userId: UUID(),
        title: "Exercise 3x per week",
        description: "Build a consistent workout routine",
        createdAt: Date(),
        updatedAt: Date(),
        targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
        progress: 0.3,
        status: .active,
        category: .physical
    )

    return GoalTipsView(goal: sampleGoal, viewModel: viewModel)
}
