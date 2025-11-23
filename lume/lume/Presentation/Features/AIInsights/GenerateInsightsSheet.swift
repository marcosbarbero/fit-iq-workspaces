//
//  GenerateInsightsSheet.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import SwiftUI

/// Sheet for generating new AI insights
struct GenerateInsightsSheet: View {
    @Bindable var viewModel: AIInsightsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedTypes: Set<InsightType> = []
    @State private var forceRefresh: Bool = false
    @State private var isGenerating: Bool = false

    private var canGenerate: Bool {
        viewModel.canGenerateToday || forceRefresh
    }

    private var generateButtonText: String {
        if isGenerating {
            return "Generating..."
        } else if !viewModel.canGenerateToday && !forceRefresh {
            return "Already Generated Today"
        } else {
            return "Generate Insights"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundColor(LumeColors.accentPrimary)

                            Text("Generate Insights")
                                .font(LumeTypography.titleLarge)
                                .foregroundColor(LumeColors.textPrimary)

                            Text(
                                "AI will analyze your recent mood, journal entries, and goals to create personalized wellness insights."
                            )
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                            // Smart rate limit info
                            if !viewModel.canGenerateToday && !forceRefresh {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                        Text("Daily insights already generated today")
                                            .font(LumeTypography.bodySmall)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(Color(hex: "#7AC142"))

                                    Text(
                                        "You can still generate Weekly, Monthly, or Milestone insights below, or enable 'Force Refresh' to regenerate daily insights."
                                    )
                                    .font(LumeTypography.caption)
                                    .foregroundColor(LumeColors.textSecondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "#7AC142").opacity(0.1))
                                )
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 8)

                        Divider()
                            .background(LumeColors.textSecondary.opacity(0.2))

                        // Insight Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Insight Types")
                                .font(LumeTypography.titleMedium)
                                .foregroundColor(LumeColors.textPrimary)

                            Text("Choose specific types or leave empty for daily insights only")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)

                            VStack(spacing: 8) {
                                ForEach(InsightType.allCases, id: \.self) { type in
                                    InsightTypeSelectionRow(
                                        type: type,
                                        isSelected: selectedTypes.contains(type),
                                        onToggle: { toggleType(type) }
                                    )
                                }
                            }
                        }

                        // Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Options")
                                .font(LumeTypography.titleMedium)
                                .foregroundColor(LumeColors.textPrimary)

                            Toggle(isOn: $forceRefresh) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Force Refresh")
                                        .font(LumeTypography.body)
                                        .foregroundColor(LumeColors.textPrimary)

                                    Text(
                                        viewModel.canGenerateToday
                                            ? "Regenerate insights even if recent ones exist"
                                            : "Override daily limit to regenerate daily insights"
                                    )
                                    .font(LumeTypography.caption)
                                    .foregroundStyle(LumeColors.textSecondary)
                                }
                            }
                            .tint(LumeColors.accentPrimary)
                            .padding(12)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                        }

                        // Generate Button
                        Button(action: generateInsights) {
                            HStack(spacing: 12) {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Image(
                                    systemName: isGenerating
                                        ? "hourglass"
                                        : (canGenerate ? "sparkles" : "checkmark.circle.fill")
                                )
                                .opacity(isGenerating ? 0 : 1)

                                Text(generateButtonText)
                            }
                            .font(LumeTypography.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                (isGenerating || !canGenerate)
                                    ? LumeColors.accentPrimary.opacity(0.6)
                                    : LumeColors.accentPrimary
                            )
                            .cornerRadius(16)
                        }
                        .disabled(isGenerating || !canGenerate)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Generate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(LumeColors.textPrimary)
                    .disabled(isGenerating)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleType(_ type: InsightType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    private func generateInsights() {
        isGenerating = true

        Task {
            let types = selectedTypes.isEmpty ? nil : Array(selectedTypes)
            await viewModel.generateNewInsights(types: types, forceRefresh: forceRefresh)

            // Reload insights to refresh the list
            await viewModel.loadInsights()

            await MainActor.run {
                isGenerating = false
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

struct InsightTypeSelectionRow: View {
    let type: InsightType
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: type.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : Color(hex: type.color))
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected
                            ? Color(hex: type.color)
                            : Color(hex: type.color).opacity(0.15)
                    )
                    .cornerRadius(8)

                // Title and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)

                    Text(typeDescription(for: type))
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(
                        isSelected ? Color(hex: type.color) : LumeColors.textSecondary.opacity(0.3))
            }
            .padding(12)
            .background(LumeColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: type.color).opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func typeDescription(for type: InsightType) -> String {
        switch type {
        case .daily:
            return "Daily wellness snapshot"
        case .weekly:
            return "Summary of your past week"
        case .monthly:
            return "Monthly wellness review"
        case .milestone:
            return "Celebrate your achievements"
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        GenerateInsightsSheet(viewModel: .preview)
    }
#endif
