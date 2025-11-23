//
//  ConsultationGoalSuggestionsView.swift
//  lume
//
//  Created by AI Assistant on 29/01/2025.
//

import SwiftUI

/// Bottom sheet view displaying AI-generated goal suggestions from consultation
struct ConsultationGoalSuggestionsView: View {
    @Environment(\.dismiss) private var dismiss

    let consultationId: UUID
    let persona: ChatPersona
    let suggestions: [GoalSuggestion]
    let isLoading: Bool
    let onCreateGoal: (GoalSuggestion) -> Void

    @State private var selectedSuggestion: GoalSuggestion?

    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Suggestions
                        if isLoading {
                            loadingState
                        } else if suggestions.isEmpty {
                            emptyState
                        } else {
                            suggestionsList
                        }

                        // Bottom padding
                        Color.clear.frame(height: 20)
                    }
                }
            }
            .navigationTitle("Goal Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(LumeColors.textSecondary.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#F2C9A7"),
                                Color(hex: "#D8C8EA"),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "target")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Title
            Text("Goals Based on Your Conversation")
                .font(LumeTypography.titleLarge)
                .foregroundColor(LumeColors.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text(
                "I've analyzed our discussion and created these personalized goals to help you achieve your wellness objectives."
            )
            .font(LumeTypography.body)
            .foregroundColor(LumeColors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)

            // Persona badge
            HStack(spacing: 6) {
                Image(systemName: persona.systemImage)
                    .font(.system(size: 12))

                Text("Suggested by \(persona.displayName)")
                    .font(LumeTypography.caption)
            }
            .foregroundColor(LumeColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(LumeColors.textSecondary.opacity(0.15))
            )
        }
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        VStack(spacing: 16) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                ConsultationGoalSuggestionCard(
                    suggestion: suggestion,
                    index: index + 1,
                    onTap: {
                        selectedSuggestion = suggestion
                    },
                    onCreate: {
                        onCreateGoal(suggestion)
                        dismiss()
                    }
                )
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(LumeColors.accentPrimary)

            Text("Analyzing your conversation...")
                .font(LumeTypography.titleMedium)
                .foregroundColor(LumeColors.textPrimary)

            Text("Our AI is reviewing your discussion to create personalized goal suggestions.")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(LumeColors.textSecondary.opacity(0.4))

            Text("No suggestions available")
                .font(LumeTypography.titleMedium)
                .foregroundColor(LumeColors.textPrimary)

            Text("Continue the conversation to get personalized goal suggestions.")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Consultation Goal Suggestion Card

struct ConsultationGoalSuggestionCard: View {
    let suggestion: GoalSuggestion
    let index: Int
    let onTap: () -> Void
    let onCreate: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Always visible
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
            }) {
                HStack(alignment: .top, spacing: 12) {
                    // Number badge
                    ZStack {
                        Circle()
                            .fill(difficultyColor.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Text("\(index)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(difficultyColor)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(suggestion.title)
                                .font(LumeTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(LumeColors.textPrimary)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            // Expand indicator
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(LumeColors.textSecondary)
                        }

                        // Quick info badges
                        HStack(spacing: 8) {
                            // Difficulty
                            DifficultyBadge(difficulty: suggestion.difficulty)

                            // Duration
                            if let duration = suggestion.estimatedDuration {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                    Text("\(duration) days")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(LumeColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(LumeColors.textSecondary.opacity(0.1))
                                )
                            }

                            // Type badge
                            Text(suggestion.category.displayName)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: suggestion.category.color))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: suggestion.category.color).opacity(0.1))
                                )
                        }
                    }
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(LumeColors.textSecondary)

                        Text(suggestion.description)
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)

                    // Rationale
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why this goal?")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(LumeColors.textSecondary)

                        Text(suggestion.rationale)
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)

                    // Target info
                    if let targetValue = suggestion.targetValue,
                        let targetUnit = suggestion.targetUnit
                    {
                        HStack(spacing: 8) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#F2C9A7"))

                            Text("Target: \(formatTargetValue(targetValue)) \(targetUnit)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(LumeColors.textPrimary)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Create button
                    Button(action: onCreate) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))

                            Text("Create This Goal")
                                .font(LumeTypography.body)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(LumeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#F2C9A7"),
                                    Color(hex: "#D8C8EA"),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(difficultyColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var difficultyColor: Color {
        switch suggestion.difficulty {
        case .veryEasy, .easy:
            return Color.green
        case .moderate:
            return Color.orange
        case .challenging, .veryChallenging:
            return Color.red
        }
    }

    private func formatTargetValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: DifficultyLevel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < difficulty.rawValue ? difficultyColor : Color.gray.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(difficultyColor.opacity(0.1))
        )
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .veryEasy, .easy:
            return Color.green
        case .moderate:
            return Color.orange
        case .challenging, .veryChallenging:
            return Color.red
        }
    }
}

// MARK: - Preview

#Preview {
    ConsultationGoalSuggestionsView(
        consultationId: UUID(),
        persona: .nutritionist,
        suggestions: [
            GoalSuggestion(
                id: UUID(),
                title: "Increase daily fiber intake",
                description:
                    "Based on our discussion about digestive health, aim for 30g of fiber daily through whole grains, fruits, and vegetables",
                goalType: "nutrition",
                targetValue: 30,
                targetUnit: "grams",
                rationale:
                    "Your current intake is around 15g. Doubling fiber will improve gut health and align with your wellness goals discussed in this consultation",
                estimatedDuration: 30,
                difficulty: .moderate,
                category: .physical
            ),
            GoalSuggestion(
                id: UUID(),
                title: "Meal prep 4 times per week",
                description:
                    "Prepare healthy meals in advance to support your nutrition goals and reduce reliance on processed foods",
                goalType: "nutrition",
                targetValue: 4,
                targetUnit: "days",
                rationale:
                    "We identified time constraints as a barrier. Meal prep addresses this while ensuring you have nutritious options available",
                estimatedDuration: 60,
                difficulty: .challenging,
                category: .physical
            ),
        ],
        isLoading: false,
        onCreateGoal: { suggestion in
            print("Create goal: \(suggestion.title)")
        }
    )
}
