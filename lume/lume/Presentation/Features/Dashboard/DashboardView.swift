//
//  DashboardView.swift
//  lume
//
//  Created by AI Assistant on 16/01/2025.
//  Enhanced dashboard combining mood and journal analytics
//

import Charts
import SwiftUI

/// Enhanced dashboard view with comprehensive wellness insights
/// Combines mood timeline, journal stats, and interactive analytics
struct DashboardView: View {

    // MARK: - Properties

    @Bindable var viewModel: DashboardViewModel
    @Bindable var insightsViewModel: AIInsightsViewModel
    var onMoodLog: (() -> Void)? = nil
    var onJournalWrite: (() -> Void)? = nil
    @State private var selectedPeriod: DashboardTimePeriod = .thirtyDays
    @State private var selectedDate: Date?
    @State private var selectedSummaryID: UUID?
    @State private var selectedInsight: AIInsight?
    @State private var showRefreshSuccess = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if let stats = viewModel.wellnessStats {
                    statisticsContent(stats)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(DashboardTimePeriod.allCases, id: \.rawValue) { period in
                            Button {
                                selectedPeriod = period
                                Task {
                                    await viewModel.changeTimeRange(period.toViewModelRange())
                                    await viewModel.refresh()
                                }
                            } label: {
                                HStack {
                                    Text(period.displayName)
                                    if selectedPeriod == period {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedPeriod.displayName)
                                .font(LumeTypography.bodySmall)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#F2C9A7"))
                        )
                    }
                }
            }
            .sheet(item: $selectedInsight) { insight in
                NavigationStack {
                    AIInsightDetailView(
                        insight: insight,
                        viewModel: insightsViewModel
                    )
                }
            }
            .task {
                // Load data if not already present in ViewModel
                if viewModel.wellnessStats == nil && !viewModel.isLoading {
                    print("📊 [Dashboard] Loading statistics")
                    await viewModel.loadStatistics()
                }

                // Load insights only if not already loaded
                if insightsViewModel.insights.isEmpty && !insightsViewModel.isLoading {
                    print("📊 [Dashboard] Loading insights")
                    await loadInsightsWithAutoGenerate()
                } else if !insightsViewModel.insights.isEmpty {
                    print(
                        "📊 [Dashboard] Using cached insights (\(insightsViewModel.insights.count) insights)"
                    )
                }
            }
            .refreshable {
                await viewModel.refresh()
                await insightsViewModel.refreshFromBackend()
            }
            .overlay(alignment: .top) {
                if showRefreshSuccess {
                    Text("✓ Insights refreshed")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#5CB85C"))
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Statistics Content

    @ViewBuilder
    private func statisticsContent(_ stats: WellnessStatistics) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // AI Insights Card
                aiInsightsSection

                // Summary Cards
                summaryCardsSection(stats)

                // Interactive Mood Timeline
                if !stats.mood.dailyBreakdown.isEmpty {
                    interactiveMoodTimeline(stats.mood)
                }

                // Top Moods
                if !stats.mood.dailyBreakdown.isEmpty {
                    topMoodsSection(stats.mood)
                }

                // Mood Distribution
                moodDistributionSection(stats.mood.moodDistribution)

                // Journal Insights
                journalInsightsSection(stats.journal)

                // Quick Actions
                quickActionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - AI Insights Section

    @ViewBuilder
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header with Unread Badge
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#D8C8EA"))

                Text("AI Insights")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                // Unread count badge
                if insightsViewModel.unreadCount > 0 {
                    Text("\(insightsViewModel.unreadCount)")
                        .font(LumeTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#F2C9A7"))
                        )
                }

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await refreshInsights()
                    }
                } label: {
                    Image(systemName: insightsViewModel.isLoading ? "hourglass" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(hex: "#F2C9A7"))
                        )
                }
                .disabled(insightsViewModel.isLoading || insightsViewModel.isGenerating)

                if !insightsViewModel.insights.isEmpty {
                    NavigationLink {
                        AIInsightsListView(viewModel: insightsViewModel)
                    } label: {
                        Text("View All")
                            .font(LumeTypography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#F2C9A7"))
                            )
                    }
                }
            }

            // Latest Insight Card or Empty State
            if insightsViewModel.isLoading || insightsViewModel.isGenerating {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "#F2C9A7"))
                    if insightsViewModel.isGenerating {
                        Text("Generating insights...")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)
                            .padding(.leading, 8)
                    }
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LumeColors.surface)
                )
            } else if let latestInsight = insightsViewModel.insights.first {
                AIInsightCard(insight: latestInsight, viewModel: insightsViewModel) {
                    selectedInsight = latestInsight
                }
            } else {
                AIInsightEmptyCard {
                    Task {
                        await generateInsights()
                    }
                }
            }
        }
    }

    // MARK: - AI Insights Actions

    /// Load insights with auto-generation if empty
    private func loadInsightsWithAutoGenerate() async {
        await insightsViewModel.loadInsights()

        // Auto-generate insights only if:
        // 1. No insights exist at all, OR
        // 2. Generation is available today (no recent daily insights)
        if insightsViewModel.insights.isEmpty && insightsViewModel.canGenerateToday {
            print("📊 [Dashboard] No insights found and generation available - auto-generating")
            await insightsViewModel.generateNewInsights(types: nil, forceRefresh: false)
        } else if !insightsViewModel.insights.isEmpty {
            print(
                "📊 [Dashboard] Found \(insightsViewModel.insights.count) existing insights - skipping auto-generation"
            )
        } else if !insightsViewModel.canGenerateToday {
            print("📊 [Dashboard] Insights already generated today - skipping auto-generation")
        }
    }

    /// Refresh insights with user feedback
    private func refreshInsights() async {
        await insightsViewModel.refreshFromBackend()

        // Show success feedback
        await MainActor.run {
            withAnimation(.spring(response: 0.3)) {
                showRefreshSuccess = true
            }

            // Hide after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.spring(response: 0.3)) {
                    showRefreshSuccess = false
                }
            }
        }
    }

    private func generateInsights() async {
        await insightsViewModel.generateNewInsights(types: nil, forceRefresh: false)
    }

    // MARK: - Summary Cards

    private func summaryCardsSection(_ stats: WellnessStatistics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Avg Mood",
                    value: viewModel.averageMoodScoreFormatted,
                    subtitle: "out of 10",
                    icon: "heart.fill",
                    color: "#F2C9A7"
                )

                StatCard(
                    title: "Current Streak",
                    value: "\(stats.mood.streakInfo.currentStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    color: "#D8C8EA"
                )

                StatCard(
                    title: "Total Entries",
                    value: "\(stats.mood.totalEntries + stats.journal.totalEntries)",
                    icon: "chart.bar.fill",
                    color: "#F5DFA8"
                )

                StatCard(
                    title: "Consistency",
                    value: viewModel.consistencyPercentageFormatted,
                    icon: "chart.line.uptrend.xyaxis",
                    color: "#B8E8D4"
                )
            }
        }
    }

    // MARK: - Interactive Mood Timeline

    private func interactiveMoodTimeline(_ mood: MoodStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mood Timeline")
                    .font(LumeTypography.titleMedium)
                    .foregroundStyle(LumeColors.textPrimary)

                Spacer()

                // Trend indicator
                HStack(spacing: 6) {
                    Image(systemName: viewModel.moodTrend.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: viewModel.moodTrend.color))
                    Text(viewModel.moodTrendMessage)
                        .font(LumeTypography.caption)
                        .foregroundStyle(LumeColors.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: viewModel.moodTrend.color).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Interactive Chart
            Chart(mood.dailyBreakdown) { summary in
                LineMark(
                    x: .value("Date", summary.date),
                    y: .value("Mood", summary.averageMood)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LumeColors.accentPrimary,
                            LumeColors.accentSecondary,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.catmullRom)

                // Entry points
                PointMark(
                    x: .value("Date", summary.date),
                    y: .value("Mood", summary.averageMood)
                )
                .foregroundStyle(moodColor(for: summary.averageMood))
                .symbolSize(selectedSummaryID == summary.id ? 200 : 100)

                // Area fill
                AreaMark(
                    x: .value("Date", summary.date),
                    y: .value("Mood", summary.averageMood)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LumeColors.accentPrimary.opacity(0.2),
                            LumeColors.accentPrimary.opacity(0.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day(), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 5, 10]) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        let location = value.location
                        if let date: Date = proxy.value(atX: location.x) {
                            if let summary = mood.dailyBreakdown.first(where: {
                                Calendar.current.isDate($0.date, inSameDayAs: date)
                            }) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedSummaryID == summary.id {
                                        selectedSummaryID = nil
                                    } else {
                                        selectedSummaryID = summary.id
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                    }
                                }
                            }
                        }
                    }
            }
            .padding(.leading, 18)
            .frame(height: 250)
            .background(
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#F5DFA8"))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white))
                            .padding(.top, 8)

                        Spacer()

                        Image(systemName: "cloud.sun.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#D8E8C8"))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white))

                        Spacer()

                        Image(systemName: "cloud.rain.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#F0B8A4"))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white))
                            .padding(.bottom, 8)
                    }
                    .frame(width: 24)
                    .padding(.leading, -8)
                    .allowsHitTesting(false)

                    Spacer()
                }
            )

            // Selected entry details
            if let selectedID = selectedSummaryID,
                let selected = mood.dailyBreakdown.first(where: { $0.id == selectedID })
            {
                entryDetailCard(selected)
            }

            if !mood.dailyBreakdown.isEmpty && selectedSummaryID == nil {
                Text("Tap any point to see details")
                    .font(LumeTypography.caption)
                    .foregroundStyle(LumeColors.textSecondary)
                    .padding(.top, 4)
            } else if selectedSummaryID != nil {
                Text("Tap again to deselect")
                    .font(LumeTypography.caption)
                    .foregroundStyle(LumeColors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(LumeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func entryDetailCard(_ summary: MoodStatistics.DailyMoodSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.date, style: .date)
                    .font(LumeTypography.body.bold())
                    .foregroundStyle(LumeColors.textPrimary)

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LumeColors.textSecondary)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Mood")
                        .font(LumeTypography.caption)
                        .foregroundStyle(LumeColors.textSecondary)
                    Text(String(format: "%.1f/10", summary.averageMood))
                        .font(LumeTypography.titleMedium)
                        .foregroundStyle(moodColor(for: summary.averageMood))
                }

                if let dominant = summary.dominantMood {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dominant Mood")
                            .font(LumeTypography.caption)
                            .foregroundStyle(LumeColors.textSecondary)
                        HStack(spacing: 4) {
                            Image(systemName: dominant.systemImage)
                                .font(.caption)
                            Text(dominant.displayName)
                                .font(LumeTypography.body)
                                .foregroundStyle(LumeColors.textPrimary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Entries")
                        .font(LumeTypography.caption)
                        .foregroundStyle(LumeColors.textSecondary)
                    Text("\(summary.entryCount)")
                        .font(LumeTypography.titleMedium)
                        .foregroundStyle(LumeColors.textPrimary)
                }
            }
        }
        .padding(12)
        .background(LumeColors.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Moods Section

    private func topMoodsSection(_ mood: MoodStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Moods")
                .font(LumeTypography.titleMedium)
                .foregroundStyle(LumeColors.textPrimary)

            let topMoods = calculateTopMoods(from: mood.dailyBreakdown)

            VStack(spacing: 12) {
                ForEach(Array(topMoods.prefix(5).enumerated()), id: \.element.label.id) {
                    index, item in
                    topMoodRow(index: index, item: item)
                }
            }
        }
        .padding(20)
        .background(LumeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mood Distribution

    private func moodDistributionSection(_ distribution: MoodStatistics.MoodDistribution)
        -> some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mood Distribution")
                .font(LumeTypography.titleMedium)
                .foregroundStyle(LumeColors.textPrimary)

            HStack(alignment: .top, spacing: 20) {
                // Pie Chart
                ZStack {
                    // Background circle
                    Circle()
                        .fill(LumeColors.appBackground)
                        .frame(width: 120, height: 120)

                    // Pie segments
                    if distribution.total > 0 {
                        PieChartView(
                            segments: [
                                PieSegment(
                                    value: Double(distribution.positive),
                                    color: Color(hex: "#A8D5A8")),
                                PieSegment(
                                    value: Double(distribution.neutral),
                                    color: Color(hex: "#D8E8C8")),
                                PieSegment(
                                    value: Double(distribution.negative),
                                    color: Color(hex: "#F0B8A4")),
                            ]
                        )
                        .frame(width: 110, height: 110)
                    } else {
                        Circle()
                            .stroke(LumeColors.textSecondary.opacity(0.2), lineWidth: 2)
                            .frame(width: 110, height: 110)
                    }
                }

                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    MoodDistributionLegendRow(
                        label: "Positive",
                        count: distribution.positive,
                        percentage: distribution.positivePercentage,
                        color: "#A8D5A8"
                    )

                    MoodDistributionLegendRow(
                        label: "Neutral",
                        count: distribution.neutral,
                        percentage: distribution.neutralPercentage,
                        color: "#D8E8C8"
                    )

                    MoodDistributionLegendRow(
                        label: "Challenging",
                        count: distribution.negative,
                        percentage: distribution.negativePercentage,
                        color: "#F0B8A4"
                    )
                }

                Spacer()
            }
            .padding(.bottom, 12)
        }
        .padding(20)
        .background(LumeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(minHeight: 200)
    }

    // MARK: - Journal Insights

    private func journalInsightsSection(_ journal: JournalStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal Insights")
                .font(LumeTypography.titleMedium)
                .foregroundStyle(LumeColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                JournalStatCell(
                    icon: "book.fill",
                    value: "\(journal.totalEntries)",
                    label: "Entries"
                )

                JournalStatCell(
                    icon: "text.word.spacing",
                    value: "\(journal.totalWords)",
                    label: "Words"
                )

                JournalStatCell(
                    icon: "chart.bar.fill",
                    value: "\(journal.averageWordsPerEntry)",
                    label: "Avg Words"
                )

                JournalStatCell(
                    icon: "star.fill",
                    value: "\(journal.favoriteCount)",
                    label: "Favorites"
                )
            }
        }
        .padding(20)
        .background(LumeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(LumeTypography.titleMedium)
                .foregroundStyle(LumeColors.textPrimary)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Log Mood",
                    icon: "heart.fill",
                    color: "#F2C9A7"
                ) {
                    onMoodLog?()
                }

                QuickActionButton(
                    title: "Write Journal",
                    icon: "book.fill",
                    color: "#D8C8EA"
                ) {
                    onJournalWrite?()
                }
            }
        }
        .padding(20)
        .background(LumeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(LumeColors.accentPrimary)

            Text("Calculating insights...")
                .font(LumeTypography.body)
                .foregroundStyle(LumeColors.textSecondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(LumeColors.textSecondary)

            Text("Unable to Load Statistics")
                .font(LumeTypography.titleMedium)
                .foregroundStyle(LumeColors.textPrimary)

            Text(message)
                .font(LumeTypography.body)
                .foregroundStyle(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Try Again") {
                Task {
                    await viewModel.refresh()
                }
            }
            .font(LumeTypography.body)
            .fontWeight(.semibold)
            .foregroundColor(LumeColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LumeColors.accentPrimary)
            .cornerRadius(16)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundStyle(LumeColors.accentPrimary)

            Text("Start Your Wellness Journey")
                .font(LumeTypography.titleLarge)
                .foregroundStyle(LumeColors.textPrimary)

            Text("Log your moods and write journal entries to see insights here")
                .font(LumeTypography.body)
                .foregroundStyle(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Get Started") {
                Task {
                    await viewModel.loadStatistics()
                }
            }
            .font(LumeTypography.body)
            .fontWeight(.semibold)
            .foregroundColor(LumeColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LumeColors.accentPrimary)
            .cornerRadius(16)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Helper Methods

    private func moodColor(for score: Double) -> Color {
        if score >= 7 {
            return Color(hex: "#F5DFA8")  // Positive
        } else if score >= 4 {
            return Color(hex: "#D8E8C8")  // Neutral
        } else {
            return Color(hex: "#F0B8A4")  // Challenging
        }
    }

    private func calculateTopMoods(from breakdown: [MoodStatistics.DailyMoodSummary]) -> [(
        label: MoodLabel, count: Int, percentage: Int
    )] {
        var labelCounts: [MoodLabel: Int] = [:]

        for summary in breakdown {
            if let mood = summary.dominantMood {
                labelCounts[mood, default: 0] += 1
            }
        }

        let total = labelCounts.values.reduce(0, +)
        guard total > 0 else { return [] }

        return labelCounts.map { label, count in
            let percentage = Int((Double(count) / Double(total)) * 100)
            return (label, count, percentage)
        }
        .sorted { $0.count > $1.count }
    }

    private func topMoodRow(index: Int, item: (label: MoodLabel, count: Int, percentage: Int))
        -> some View
    {
        HStack {
            Text("\(index + 1).")
                .font(LumeTypography.body.bold())
                .foregroundStyle(LumeColors.textSecondary)
                .frame(width: 24)

            Image(systemName: item.label.systemImage)
                .font(.body)
                .foregroundStyle(Color(hex: item.label.color))

            Text(item.label.displayName)
                .font(LumeTypography.body)
                .foregroundStyle(LumeColors.textPrimary)

            Spacer()

            Text("\(item.count)")
                .font(LumeTypography.body.bold())
                .foregroundStyle(LumeColors.textPrimary)

            Text("(\(item.percentage)%)")
                .font(LumeTypography.bodySmall)
                .foregroundStyle(LumeColors.textSecondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(LumeColors.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Types

enum DashboardTimePeriod: String, CaseIterable {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case year = "1y"

    var displayName: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .ninetyDays: return "90 Days"
        case .year: return "Year"
        }
    }

    func toViewModelRange() -> DashboardViewModel.TimeRange {
        switch self {
        case .sevenDays: return .sevenDays
        case .thirtyDays: return .thirtyDays
        case .ninetyDays: return .ninetyDays
        case .year: return .year
        }
    }
}

// MARK: - Component Views

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color(hex: color))
                .clipShape(Circle())

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LumeColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(LumeColors.textSecondary)
                    }
                }

                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(LumeColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 85, height: 85, alignment: .leading)
        .padding(10)
        .background(LumeColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MoodDistributionRow: View {
    let label: String
    let count: Int
    let percentage: Double
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(LumeTypography.body)
                    .foregroundStyle(LumeColors.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(LumeColors.textPrimary)

                Text("(\(Int(percentage))%)")
                    .font(LumeTypography.bodySmall)
                    .foregroundStyle(LumeColors.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: color).opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: color))
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct MoodDistributionLegendRow: View {
    let label: String
    let count: Int
    let percentage: Double
    let color: String

    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            Circle()
                .fill(Color(hex: color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LumeTypography.body)
                    .foregroundStyle(LumeColors.textPrimary)

                Text("\(count) entries (\(Int(percentage))%)")
                    .font(LumeTypography.caption)
                    .foregroundStyle(LumeColors.textSecondary)
            }
        }
    }
}

struct PieSegment {
    let value: Double
    let color: Color
}

struct PieChartView: View {
    let segments: [PieSegment]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    PieSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index)
                    )
                    .fill(segment.color)
                }
            }
        }
    }

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    private func startAngle(for index: Int) -> Angle {
        let values = segments.prefix(index).map { $0.value }
        let sum = values.reduce(0, +)
        return Angle(degrees: (sum / total) * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let values = segments.prefix(index + 1).map { $0.value }
        let sum = values.reduce(0, +)
        return Angle(degrees: (sum / total) * 360 - 90)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

struct JournalStatCell: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(LumeColors.accentSecondary)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(LumeColors.textPrimary)

            Text(label)
                .font(LumeTypography.caption)
                .foregroundStyle(LumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(LumeColors.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color(hex: color))

                Text(title)
                    .font(LumeTypography.body)
                    .foregroundStyle(LumeColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(LumeColors.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView(
        viewModel: DashboardViewModel(
            statisticsRepository: StatisticsRepository(
                modelContext: AppDependencies.preview.modelContext
            )
        ),
        insightsViewModel: AppDependencies.preview.makeAIInsightsViewModel()
    )
}
