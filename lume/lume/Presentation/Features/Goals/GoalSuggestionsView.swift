//
//  GoalSuggestionsView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//

import SwiftUI

/// View showing AI-generated goal suggestions
struct GoalSuggestionsView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: GoalsViewModel

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            if viewModel.isLoadingSuggestions {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if viewModel.suggestions.isEmpty {
                emptyOrGenerateView
            } else {
                suggestionsContent
            }
        }
        .navigationTitle("AI Goal Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Text("Based on your wellness data, here are some personalized goal suggestions:")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Suggestions List
                ForEach(viewModel.suggestions) { suggestion in
                    GoalSuggestionCard(suggestion: suggestion) {
                        Task {
                            await viewModel.createGoalFromSuggestion(suggestion)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private var emptyOrGenerateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#D8C8EA"))

            VStack(spacing: 8) {
                Text("AI Goal Suggestions")
                    .font(LumeTypography.titleLarge)
                    .foregroundColor(LumeColors.textPrimary)

                Text("Get personalized goal recommendations based on your wellness data")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                Task {
                    await viewModel.generateSuggestions()
                }
            } label: {
                Text("Generate Suggestions")
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#D8C8EA"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "#D8C8EA"))

            Text("Generating personalized suggestions...")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#F0B8A4"))

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(LumeTypography.titleLarge)
                    .foregroundColor(LumeColors.textPrimary)

                Text(message)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                viewModel.clearError()
                Task {
                    await viewModel.generateSuggestions()
                }
            } label: {
                Text("Try Again")
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#D8C8EA"))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Suggestion Card

struct GoalSuggestionCard: View {
    let suggestion: GoalSuggestion
    let onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                // Icon with colored background for better visibility
                ZStack {
                    Circle()
                        .fill(Color(hex: suggestion.category.colorHex).opacity(0.25))
                        .frame(width: 44, height: 44)

                    Image(systemName: suggestion.category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(LumeColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)

                    HStack(spacing: 12) {
                        // Difficulty badge with colored background for better visibility
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(suggestion.difficulty.displayName)
                        }
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: suggestion.difficulty.colorHex).opacity(0.3))
                        .cornerRadius(6)

                        // Duration with icon
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .regular))
                            Text(suggestion.durationText)
                        }
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                    }
                }

                Spacer()
            }

            // Description
            Text(suggestion.description)
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)

            // Rationale
            Text(suggestion.rationale)
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)
                .italic()

            // Use Button
            Button(action: onUse) {
                Text("Use This Goal")
                    .font(LumeTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#F2C9A7"))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(LumeColors.surface)
        .cornerRadius(16)
        .shadow(color: LumeColors.textPrimary.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    let deps = AppDependencies.preview
    return NavigationStack {
        GoalSuggestionsView(viewModel: deps.makeGoalsViewModel())
    }
}
