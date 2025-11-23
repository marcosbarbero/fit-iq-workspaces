//
//  AIInsightsListView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//  Phase 1: Complete insights management with filtering, favorites, archive, and interactions
//

import SwiftUI

/// Full list view of AI insights with filtering and management features
/// Phase 1 Features: mark as read, favorite, archive, delete, filters, swipe actions
struct AIInsightsListView: View {
    @Bindable var viewModel: AIInsightsViewModel
    @State private var showingFilters = false
    @State private var showingGenerate = false
    @State private var showingDeleteConfirmation = false
    @State private var insightToDelete: AIInsight?
    @State private var selectedInsightForDetail: AIInsight?

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredInsights.isEmpty {
                emptyStateView
            } else {
                insightsList
            }
        }
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingGenerate = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Generate")
                            .font(LumeTypography.bodySmall)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(LumeColors.accentPrimary)
                }
                .disabled(viewModel.isGenerating)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFilters = true
                } label: {
                    HStack(spacing: 4) {
                        Image(
                            systemName: viewModel.hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                        .font(.system(size: 18))

                        if viewModel.hasActiveFilters {
                            Circle()
                                .fill(Color(hex: "#F2C9A7"))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundColor(LumeColors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            InsightFiltersSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingGenerate) {
            GenerateInsightsSheet(viewModel: viewModel)
        }
        .alert(
            "Delete Insight", isPresented: $showingDeleteConfirmation, presenting: insightToDelete
        ) { insight in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.delete(id: insight.id)
                }
            }
        } message: { insight in
            Text(
                "Are you sure you want to permanently delete \"\(insight.title)\"? This action cannot be undone."
            )
        }
        .refreshable {
            await viewModel.refreshFromBackend()
        }
        .onAppear {
            // Ensure we have the latest insights when view appears
            if viewModel.insights.isEmpty {
                Task {
                    await viewModel.loadInsights()
                }
            }
        }
        .sheet(item: $selectedInsightForDetail) { insight in
            NavigationStack {
                AIInsightDetailView(
                    insight: insight,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - Insights List

    private var insightsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Quick filter pills
                quickFilterPills

                // Insights list
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredInsights) { insight in
                        AIInsightListCard(
                            insight: insight,
                            viewModel: viewModel
                        ) {
                            // Mark as read and show detail when tapped
                            Task {
                                if !insight.isRead {
                                    await viewModel.markAsRead(id: insight.id)
                                }
                            }
                            selectedInsightForDetail = insight
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.top, 12)
        }
        .task {
            // Ensure filters are applied when view appears
            viewModel.applyFilters()
        }
    }

    // MARK: - Quick Filter Pills

    private var quickFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: !viewModel.hasActiveFilters
                ) {
                    viewModel.clearFilters()
                }

                FilterPill(
                    title: "Unread",
                    icon: "envelope.badge",
                    isSelected: viewModel.showUnreadOnly,
                    badge: viewModel.showUnreadOnly ? nil : viewModel.unreadCount
                ) {
                    viewModel.toggleUnreadFilter()
                }

                FilterPill(
                    title: "Favorites",
                    icon: "star.fill",
                    isSelected: viewModel.showFavoritesOnly
                ) {
                    viewModel.toggleFavoritesFilter()
                }

                Divider()
                    .frame(height: 24)

                ForEach(InsightType.allCases, id: \.rawValue) { type in
                    FilterPill(
                        title: type.displayName,
                        icon: type.systemImage,
                        isSelected: viewModel.filterType == type
                    ) {
                        if viewModel.filterType == type {
                            viewModel.setFilterType(nil)
                        } else {
                            viewModel.setFilterType(type)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "#F2C9A7"))

            Text("Loading your insights...")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#D8C8EA").opacity(0.6))

            VStack(spacing: 12) {
                Text(emptyStateTitle)
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                Text(emptyStateMessage)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if viewModel.hasActiveFilters {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("Clear Filters")
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#F2C9A7"))
                        )
                }
            } else if !viewModel.hasAnyInsights {
                Button {
                    showingGenerate = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Generate Insights")
                    }
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#F2C9A7"))
                    )
                }
            }
        }
        .padding()
    }

    private var emptyStateIcon: String {
        if viewModel.hasActiveFilters {
            return "magnifyingglass"
        } else if !viewModel.hasAnyInsights {
            return "sparkles"
        } else {
            return "checkmark.circle"
        }
    }

    private var emptyStateTitle: String {
        if viewModel.hasActiveFilters {
            return "No Matching Insights"
        } else if !viewModel.hasAnyInsights {
            return "No Insights Yet"
        } else {
            return "All Caught Up!"
        }
    }

    private var emptyStateMessage: String {
        if viewModel.hasActiveFilters {
            return "Try adjusting your filters to see more insights."
        } else if !viewModel.hasAnyInsights {
            return
                "Keep tracking your mood and journal entries. AI will generate personalized insights based on your patterns."
        } else {
            return "You've read all your insights. Check back later for new ones!"
        }
    }
}

// MARK: - Filter Pill Component

struct FilterPill: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(LumeTypography.caption)
                    .fontWeight(.semibold)

                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.3) : Color(hex: "#F2C9A7"))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : LumeColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#F2C9A7") : LumeColors.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : LumeColors.textSecondary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#Preview("With Insights") {
    let viewModel = AIInsightsViewModel.preview

    NavigationStack {
        AIInsightsListView(viewModel: viewModel)
    }
}

#Preview("Empty State") {
    let viewModel = AIInsightsViewModel.preview

    NavigationStack {
        AIInsightsListView(viewModel: viewModel)
    }
}

#Preview("Loading") {
    let viewModel = AIInsightsViewModel.preview

    return NavigationStack {
        AIInsightsListView(viewModel: viewModel)
            .onAppear {
                viewModel.isLoading = true
            }
    }
}

#Preview("Filter Pills") {
    ScrollView(.horizontal) {
        HStack(spacing: 8) {
            FilterPill(title: "All", icon: "square.grid.2x2", isSelected: true) {}
            FilterPill(title: "Unread", icon: "envelope.badge", isSelected: false, badge: 3) {}
            FilterPill(title: "Favorites", icon: "star.fill", isSelected: false) {}
            FilterPill(title: "Weekly", icon: "calendar.badge.clock", isSelected: false) {}
            FilterPill(title: "Achievement", icon: "star.fill", isSelected: true) {}
        }
        .padding()
    }
    .background(LumeColors.appBackground)
}
