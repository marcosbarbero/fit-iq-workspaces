//
//  AIInsightDetailView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//  Phase 1: Full insight detail view with all interaction features
//

import SwiftUI

/// Detailed view of a single AI insight
/// Phase 1 Features: favorite, archive, share, mark as read
struct AIInsightDetailView: View {
    let insight: AIInsight
    @Bindable var viewModel: AIInsightsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with type badge
                VStack(alignment: .leading, spacing: 12) {
                    InsightTypeBadge(type: insight.insightType)

                    Text(insight.title)
                        .font(LumeTypography.titleLarge)
                        .foregroundColor(LumeColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(insight.createdAt.formatted(date: .long, time: .omitted))
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        if !insight.isRead {
                            Circle()
                                .fill(Color(hex: "#F2C9A7"))
                                .frame(width: 6, height: 6)

                            Text("New")
                                .font(LumeTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "#F2C9A7"))
                        }
                    }
                }

                Divider()

                // Summary (if available)
                if let summary = insight.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Summary", systemImage: "text.quote")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text(summary)
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#F2C9A7").opacity(0.1))
                            )
                    }
                }

                // Main content
                VStack(alignment: .leading, spacing: 12) {
                    Label("Insights", systemImage: "sparkles")
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)

                    Text(insight.content)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)
                        .lineSpacing(6)
                }

                // Metrics (if available)
                if let metrics = insight.metrics, metrics.hasMetrics {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Your Data", systemImage: "chart.bar.fill")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        VStack(spacing: 8) {
                            if let moodCount = metrics.moodEntriesCount {
                                MetricRow(
                                    icon: "heart.fill",
                                    label: "Mood Entries",
                                    value: "\(moodCount)",
                                    color: "#F2C9A7"
                                )
                            }

                            if let journalCount = metrics.journalEntriesCount {
                                MetricRow(
                                    icon: "book.fill",
                                    label: "Journal Entries",
                                    value: "\(journalCount)",
                                    color: "#D8C8EA"
                                )
                            }

                            if let goalsActive = metrics.goalsActive {
                                MetricRow(
                                    icon: "target",
                                    label: "Active Goals",
                                    value: "\(goalsActive)",
                                    color: "#F5DFA8"
                                )
                            }

                            if let goalsCompleted = metrics.goalsCompleted {
                                MetricRow(
                                    icon: "checkmark.circle.fill",
                                    label: "Goals Completed",
                                    value: "\(goalsCompleted)",
                                    color: "#B8E8D4"
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LumeColors.surface)
                        )
                    }
                }

                // Date range (if available)
                if let periodStart = insight.periodStart, let periodEnd = insight.periodEnd {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Period", systemImage: "calendar")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Text(formatDateRange(start: periodStart, end: periodEnd))
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)

                        if let start = insight.periodStart, let end = insight.periodEnd {
                            let days =
                                Calendar.current.dateComponents([.day], from: start, to: end).day
                                ?? 0
                            Text("\(days) days")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LumeColors.surface)
                    )
                }

                // Suggestions (if available)
                if let suggestions = insight.suggestions, !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Suggestions", systemImage: "lightbulb.fill")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(suggestions.enumerated()), id: \.offset) {
                                index, suggestion in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(LumeTypography.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(Color(hex: "#F2C9A7"))
                                        )

                                    Text(suggestion)
                                        .font(LumeTypography.body)
                                        .foregroundColor(LumeColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LumeColors.surface)
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(LumeColors.appBackground)
        .navigationTitle("Insight Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.toggleFavorite(id: insight.id)
                    }
                } label: {
                    Image(systemName: insight.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(
                            insight.isFavorite
                                ? Color(hex: "#F5DFA8")
                                : LumeColors.textSecondary.opacity(0.65)
                        )
                }
            }
        }
        .onAppear {
            // Auto-mark as read when view appears
            if !insight.isRead {
                Task {
                    await viewModel.markAsRead(id: insight.id)
                }
            }
        }
    }

    // MARK: - Actions

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        return "\(startStr) - \(endStr)"
    }

    private func shareInsight() {
        let text = """
            \(insight.title)

            \(insight.content)

            Generated: \(insight.createdAt.formatted(date: .long, time: .omitted))
            """

        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootViewController = window.rootViewController
        {
            rootViewController.present(activityController, animated: true)
        }
    }
}

// MARK: - Metric Row Component

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: color))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: color).opacity(0.15))
                )

            Text(label)
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textPrimary)

            Spacer()

            Text(value)
                .font(LumeTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: color))
        }
    }
}

// MARK: - Previews

#Preview("Full Insight") {
    let insight = AIInsight(
        userId: UUID(),
        insightType: .weekly,
        title: "Your Week in Review",
        content: """
            This week showed great consistency! You logged your mood 6 out of 7 days and maintained a positive trend. Your journaling practice helped you process challenging moments effectively.

            Your average mood score was 4.2/5.0, which is above your historical average. The days you journaled correlated with improved mood scores, suggesting that reflection helps you maintain emotional balance.

            Keep up the excellent work with your daily tracking. Your consistency is building a powerful foundation for self-awareness and growth.
            """,
        summary:
            "Great consistency this week with 6/7 mood logs and positive trends. Journaling helped maintain emotional balance.",
        periodStart: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
        periodEnd: Date(),
        metrics: InsightMetrics(
            moodEntriesCount: 6,
            journalEntriesCount: 5,
            goalsActive: 3,
            goalsCompleted: 1
        ),
        suggestions: [
            "Continue your daily mood tracking to maintain momentum",
            "Try journaling in the evening to reflect on your day",
            "Set a reminder for your most productive journaling time",
        ]
    )

    let viewModel = AIInsightsViewModel.preview

    NavigationStack {
        AIInsightDetailView(insight: insight, viewModel: viewModel)
    }
}

#Preview("Achievement Insight") {
    let insight = AIInsight(
        userId: UUID(),
        insightType: .milestone,
        title: "30-Day Streak! 🎉",
        content: """
            Congratulations! You've tracked your mood for 30 consecutive days. This consistency is building a powerful foundation for self-awareness and growth.

            Reaching this milestone shows your commitment to understanding your emotional patterns. Studies show that consistent tracking leads to better emotional regulation and self-awareness.
            """,
        summary: "You've achieved a 30-day tracking streak!",
        metrics: InsightMetrics(
            moodEntriesCount: 30,
            journalEntriesCount: 30
        ),
        suggestions: [
            "Celebrate this milestone - you've earned it!",
            "Set a new goal to maintain your streak",
            "Share your achievement with supportive friends",
        ],
        isFavorite: true
    )

    let viewModel = AIInsightsViewModel.preview

    NavigationStack {
        AIInsightDetailView(insight: insight, viewModel: viewModel)
    }
}

#Preview("Mood Pattern Insight") {
    let insight = AIInsight(
        userId: UUID(),
        insightType: .weekly,
        title: "Morning Energy Pattern Detected",
        content: """
            Your data shows an interesting pattern: your mood scores are consistently 20% higher in the morning compared to evening entries.

            This pattern has been consistent over the past month, with morning moods averaging 4.8/5.0 versus evening moods at 3.9/5.0. This suggests you may be a natural morning person, or that evening stressors impact your well-being.
            """,
        summary: "Your moods are 20% higher in mornings than evenings.",
        periodStart: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
        periodEnd: Date(),
        metrics: InsightMetrics(
            moodEntriesCount: 28,
            journalEntriesCount: 28
        )
    )

    let viewModel = AIInsightsViewModel.preview

    NavigationStack {
        AIInsightDetailView(insight: insight, viewModel: viewModel)
    }
}
