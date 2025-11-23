//
//  AIInsightCard.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//  Enhanced with Phase 1 features: favorite toggle, type badge, swipe actions, metrics display
//

import SwiftUI

/// Card component displaying the latest AI insight on the dashboard
/// Shows a preview with call-to-action to view details
/// Phase 1 Features: favorite toggle, type badge, swipe actions, metrics display
struct AIInsightCard: View {
    let insight: AIInsight
    @Bindable var viewModel: AIInsightsViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Task {
                // Auto-mark as read when tapped
                if !insight.isRead {
                    await viewModel.markAsRead(id: insight.id)
                }
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with type badge and actions
                HStack(spacing: 8) {
                    // Type Badge
                    InsightTypeBadge(type: insight.insightType)

                    Spacer()

                    // Unread indicator
                    if !insight.isRead {
                        Circle()
                            .fill(Color(hex: "#F2C9A7"))
                            .frame(width: 8, height: 8)
                    }

                    // Favorite toggle
                    Button {
                        Task {
                            await viewModel.toggleFavorite(id: insight.id)
                        }
                    } label: {
                        Image(systemName: insight.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(
                                insight.isFavorite
                                    ? Color(hex: "#F5DFA8")
                                    : LumeColors.textSecondary.opacity(0.65)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Title
                Text(insight.title)
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Summary or Content Preview
                if let summary = insight.summary {
                    Text(summary)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                } else {
                    Text(insight.content)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // Metrics Row (if available)
                if let metrics = insight.metrics, metrics.hasMetrics {
                    HStack(spacing: 12) {
                        if let journalCount = metrics.journalEntriesCount, journalCount > 0 {
                            MetricChip(icon: "book.fill", value: "\(journalCount)")
                        }
                        if let moodCount = metrics.moodEntriesCount, moodCount > 0 {
                            MetricChip(
                                icon: "heart.fill",
                                value: "\(moodCount)"
                            )
                        }
                        if let goalsActive = metrics.goalsActive, goalsActive > 0 {
                            MetricChip(icon: "target", value: "\(goalsActive)")
                        }
                        if let goalsCompleted = metrics.goalsCompleted, goalsCompleted > 0 {
                            MetricChip(
                                icon: "checkmark.circle.fill",
                                value: "\(goalsCompleted)"
                            )
                        }
                    }
                    .padding(.top, 4)
                }

                // Footer
                HStack {
                    // Date
                    Text(insight.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)

                    Spacer()

                    // CTA
                    HStack(spacing: 4) {
                        Text("Read More")
                            .font(LumeTypography.bodySmall)
                            .fontWeight(.semibold)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#F2C9A7"))
                    )
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LumeColors.surface)
                    .shadow(
                        color: LumeColors.textPrimary.opacity(0.06),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
            .opacity(insight.isRead ? 0.85 : 1.0)
        }
        .buttonStyle(InsightCardButtonStyle())
    }
}

// MARK: - Insight Type Badge

struct InsightTypeBadge: View {
    let type: InsightType

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.systemImage)
                .font(.system(size: 14, weight: .semibold))

            Text(type.displayName)
                .font(LumeTypography.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(badgeTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(badgeBackgroundColor)
        )
    }

    private var badgeBackgroundColor: Color {
        switch type {
        case .daily:
            return Color(hex: "#FFF4E6")
        case .weekly, .monthly:
            return Color(hex: "#F0E6FF")
        case .milestone:
            return Color(hex: "#FFF9E6")
        }
    }

    private var badgeTextColor: Color {
        switch type {
        case .daily:
            return Color(hex: "#CC8B5C")
        case .weekly, .monthly:
            return Color(hex: "#8B5FBF")
        case .milestone:
            return Color(hex: "#CC9F3D")
        }
    }
}

// MARK: - Metric Chip

struct MetricChip: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))

            Text(value)
                .font(LumeTypography.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(LumeColors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(LumeColors.textSecondary.opacity(0.08))
        )
    }
}

// MARK: - Button Style

struct InsightCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Empty State

struct AIInsightEmptyCard: View {
    var onGenerate: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#D8C8EA").opacity(0.6))

            VStack(spacing: 8) {
                Text("Your AI Insights Await")
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)

                Text(
                    "Keep tracking your mood and journal entries. We'll generate personalized insights based on your patterns."
                )
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
            }

            if let onGenerate = onGenerate {
                Button(action: onGenerate) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Get AI Insights")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#F2C9A7"))
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LumeColors.surface)
                .shadow(
                    color: LumeColors.textPrimary.opacity(0.04),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
    }
}

// MARK: - List Version with Swipe Actions

/// Enhanced version of insight card for use in lists with swipe actions
struct AIInsightListCard: View {
    let insight: AIInsight
    @Bindable var viewModel: AIInsightsViewModel
    let onTap: () -> Void

    var body: some View {
        AIInsightCard(insight: insight, viewModel: viewModel, onTap: onTap)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // Archive action
                Button {
                    Task {
                        await viewModel.archive(id: insight.id)
                    }
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(Color(hex: "#D8C8EA"))

                // Delete action
                Button(role: .destructive) {
                    Task {
                        await viewModel.delete(id: insight.id)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                // Quick mark as read/unread
                Button {
                    Task {
                        if insight.isRead {
                            // Unmark as read (re-fetch would be needed)
                            await viewModel.markAsRead(id: insight.id)
                        } else {
                            await viewModel.markAsRead(id: insight.id)
                        }
                    }
                } label: {
                    Label(
                        insight.isRead ? "Mark Unread" : "Mark Read",
                        systemImage: insight.isRead ? "envelope.badge" : "envelope.open"
                    )
                }
                .tint(Color(hex: "#F2C9A7"))
            }
    }
}

// MARK: - Compact Version for Dashboard

/// Simplified version for dashboard preview (no swipe actions)
struct AIInsightCompactCard: View {
    let insight: AIInsight
    @Bindable var viewModel: AIInsightsViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Task {
                if !insight.isRead {
                    await viewModel.markAsRead(id: insight.id)
                }
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: insight.insightType.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(typeColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(typeColor.opacity(0.15))
                    )

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(insight.title)
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if !insight.isRead {
                            Circle()
                                .fill(Color(hex: "#F2C9A7"))
                                .frame(width: 8, height: 8)
                        }
                    }

                    if let summary = insight.summary {
                        Text(summary)
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)
                            .lineLimit(2)
                    }

                    Text(insight.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                }

                // Favorite star
                Image(systemName: insight.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(
                        insight.isFavorite
                            ? Color(hex: "#F5DFA8")
                            : LumeColors.textSecondary.opacity(0.65)
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LumeColors.surface)
            )
            .opacity(insight.isRead ? 0.85 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeColor: Color {
        switch insight.insightType {
        case .daily:
            return Color(hex: "#F2C9A7")
        case .weekly, .monthly:
            return Color(hex: "#F2C9A7")
        case .milestone:
            return Color(hex: "#F5DFA8")
        }
    }
}

// MARK: - Previews

#Preview("Standard Card") {
    let insight = AIInsight(
        userId: UUID(),
        insightType: .weekly,
        title: "Your Week in Review",
        content:
            "This week showed great consistency! You logged your mood 6 out of 7 days and maintained a positive trend. Your journaling practice helped you process challenging moments effectively.",
        summary: "Great consistency this week with 6/7 mood logs and positive trends.",
        metrics: InsightMetrics(
            moodEntriesCount: 6,
            journalEntriesCount: 3,
            goalsActive: 3,
            goalsCompleted: 1
        )
    )

    let viewModel = AIInsightsViewModel.preview

    ScrollView {
        VStack(spacing: 16) {
            AIInsightCard(insight: insight, viewModel: viewModel) {
                print("Tapped insight")
            }
            .padding(.horizontal, 20)
        }
    }
    .background(LumeColors.appBackground)
}

#Preview("Favorited & Read") {
    let viewModel = AIInsightsViewModel.preview
    let insight = AIInsight(
        userId: UUID(),
        insightType: .milestone,
        title: "30-Day Streak! 🎉",
        content:
            "Congratulations! You've tracked your mood for 30 consecutive days. This consistency is building a powerful foundation for self-awareness and growth.",
        summary: "You've achieved a 30-day streak!",
        isRead: true,
        isFavorite: true
    )

    return ScrollView {
        VStack(spacing: 16) {
            AIInsightCard(insight: insight, viewModel: viewModel) {
                print("Tapped insight")
            }
            .padding(.horizontal, 20)
        }
    }
    .background(LumeColors.appBackground)
}

#Preview("With Swipe Actions") {
    let insights = [
        AIInsight(
            userId: UUID(),
            insightType: .weekly,
            title: "Your Week in Review",
            content: "Great progress this week!",
            summary: "6/7 days logged with positive trends"
        ),
        AIInsight(
            userId: UUID(),
            insightType: .weekly,
            title: "Mood Pattern Detected",
            content: "You tend to feel better in the mornings",
            summary: "Morning moods are consistently higher"
        ),
    ]

    let viewModel = AIInsightsViewModel.preview

    NavigationStack {
        List {
            ForEach(insights) { insight in
                AIInsightListCard(insight: insight, viewModel: viewModel) {
                    print("Tapped: \(insight.title)")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(LumeColors.appBackground)
        .navigationTitle("Insights")
    }
}

#Preview("Compact Cards") {
    let insights = [
        AIInsight(
            userId: UUID(),
            insightType: .weekly,
            title: "Your Week in Review",
            content: "Great progress!",
            summary: "6/7 days logged"
        ),
        AIInsight(
            userId: UUID(),
            insightType: .milestone,
            title: "7-Day Streak!",
            content: "Keep it up!",
            summary: "Consistency unlocked"
        ),
    ]

    let viewModel = AIInsightsViewModel.preview

    ScrollView {
        VStack(spacing: 12) {
            ForEach(insights) { insight in
                AIInsightCompactCard(insight: insight, viewModel: viewModel) {
                    print("Tapped: \(insight.title)")
                }
            }
        }
        .padding(20)
    }
    .background(LumeColors.appBackground)
}

#Preview("Empty State") {
    ScrollView {
        VStack(spacing: 16) {
            AIInsightEmptyCard()
                .padding(.horizontal, 20)
        }
    }
    .background(LumeColors.appBackground)
}
