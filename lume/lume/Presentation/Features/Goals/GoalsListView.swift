//
//  GoalsListView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//

import SwiftUI

/// Main goals list view showing active and completed goals
/// Includes AI suggestions button and goal creation
struct GoalsListView: View {
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @Bindable var viewModel: GoalsViewModel
    @Binding var goalToShow: Goal?
    let dependencies: AppDependencies

    @State private var showingCreateGoal = false
    @State private var showingSuggestions = false
    @State private var selectedGoal: Goal?
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Custom styled tabs
            GoalTabsStyled(selection: $selectedTab, viewModel: viewModel)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.top, 8)
                .background(LumeColors.appBackground)

            ZStack(alignment: .bottomTrailing) {
                LumeColors.appBackground
                    .ignoresSafeArea()

                // Content
                if viewModel.isLoadingGoals {
                    loadingView
                } else if viewModel.goals.isEmpty {
                    emptyStateView
                } else {
                    goalsContent
                }

                // Floating Action Button
                if !viewModel.goals.isEmpty {
                    FloatingActionButton(
                        icon: "plus",
                        action: { showingCreateGoal = true }
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)  // Closer to tab bar, scrolls under
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSuggestions = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(Color(hex: "#D8C8EA"))
                }
            }
        }
        .sheet(isPresented: $showingCreateGoal) {
            NavigationStack {
                CreateGoalView(viewModel: viewModel)
            }
            .presentationBackground(LumeColors.appBackground)
        }
        .sheet(isPresented: $showingSuggestions) {
            NavigationStack {
                GoalSuggestionsView(viewModel: viewModel)
            }
            .presentationBackground(LumeColors.appBackground)
        }
        .sheet(item: $selectedGoal) { goal in
            NavigationStack {
                GoalDetailView(goal: goal, viewModel: viewModel, dependencies: dependencies)
                    .environmentObject(tabCoordinator)
            }
            .presentationBackground(LumeColors.appBackground)
        }
        .task {
            await viewModel.loadGoals()
        }
        .refreshable {
            await viewModel.loadGoals()
        }
        .onChange(of: goalToShow) { _, newGoal in
            if let goal = newGoal {
                // Reload goals to ensure the newly created goal is in the list
                Task {
                    await viewModel.loadGoals()

                    // Then show the goal detail after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedGoal = goal
                        goalToShow = nil  // Clear it so it can be triggered again
                    }
                }
            }
        }
    }

    // MARK: - Goals Content

    @ViewBuilder
    private var goalsContent: some View {
        switch selectedTab {
        case 0:
            goalsList(goals: viewModel.activeGoals, showSwipeActions: true)
        case 1:
            goalsList(goals: viewModel.completedGoals, showSwipeActions: false)
        case 2:
            goalsList(goals: viewModel.pausedGoals, showSwipeActions: true)
        case 3:
            goalsList(goals: viewModel.archivedGoals, showSwipeActions: false)
        default:
            goalsList(goals: viewModel.activeGoals, showSwipeActions: true)
        }
    }

    @ViewBuilder
    private func goalsList(goals: [Goal], showSwipeActions: Bool) -> some View {
        if goals.isEmpty {
            emptyStateForCurrentTab
        } else {
            List {
                ForEach(goals) { goal in
                    GoalRowView(goal: goal)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .onTapGesture {
                            selectedGoal = goal
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if showSwipeActions {
                                activeGoalSwipeActions(goal: goal)
                            } else if goal.status == .completed || goal.status == .archived {
                                archiveDeleteSwipeActions(goal: goal)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if showSwipeActions && goal.status == .active {
                                completeSwipeAction(goal: goal)
                            } else if goal.status == .paused {
                                resumeSwipeAction(goal: goal)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LumeColors.appBackground)
            .contentMargins(.bottom, 80, for: .scrollContent)  // Add bottom padding for FAB
        }
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func activeGoalSwipeActions(goal: Goal) -> some View {
        Group {
            // Delete
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteGoal(goal.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            // Archive
            Button {
                Task {
                    await viewModel.archiveGoal(goal.id)
                }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(Color(hex: "#6E625A"))

            // Pause
            if goal.status == .active {
                Button {
                    Task {
                        await viewModel.pauseGoal(goal.id)
                    }
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
                .tint(Color(hex: "#D8C8EA"))
            }
        }
    }

    @ViewBuilder
    private func archiveDeleteSwipeActions(goal: Goal) -> some View {
        Button(role: .destructive) {
            Task {
                await viewModel.deleteGoal(goal.id)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func completeSwipeAction(goal: Goal) -> some View {
        Button {
            Task {
                await viewModel.completeGoal(goal.id)
            }
        } label: {
            Label("Complete", systemImage: "checkmark.circle.fill")
        }
        .tint(Color(hex: "#B8E8D4"))
    }

    @ViewBuilder
    private func resumeSwipeAction(goal: Goal) -> some View {
        Button {
            Task {
                await viewModel.resumeGoal(goal.id)
            }
        } label: {
            Label("Resume", systemImage: "play.circle")
        }
        .tint(Color(hex: "#B8E8D4"))
    }

    // MARK: - Empty States

    @ViewBuilder
    private var emptyStateForCurrentTab: some View {
        VStack(spacing: 16) {
            Image(systemName: tabIcon)
                .font(.system(size: 48))
                .foregroundColor(LumeColors.textSecondary.opacity(0.6))

            Text(tabEmptyMessage)
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)

            if selectedTab == 0 {
                Button {
                    showingCreateGoal = true
                } label: {
                    Text("Create Your First Goal")
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#F2C9A7"))
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumeColors.appBackground)
    }

    private var tabIcon: String {
        switch selectedTab {
        case 0: return "target"
        case 1: return "checkmark.circle"
        case 2: return "pause.circle"
        case 3: return "archivebox"
        default: return "target"
        }
    }

    private var tabEmptyMessage: String {
        switch selectedTab {
        case 0: return "No active goals"
        case 1: return "No completed goals yet"
        case 2: return "No paused goals"
        case 3: return "No archived goals"
        default: return "No goals"
        }
    }

    // MARK: - Empty State (All Goals)

    @ViewBuilder
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 80)

                // Icon
                ZStack {
                    Circle()
                        .fill(LumeColors.accentPrimary.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "target")
                        .font(.system(size: 50, weight: .regular))
                        .foregroundColor(Color(hex: "#F2C9A7"))
                }

                // Text Content
                VStack(spacing: 12) {
                    Text("Set Your First Goal")
                        .font(LumeTypography.titleLarge)
                        .foregroundColor(LumeColors.textPrimary)

                    Text(
                        "Track your wellness journey with goals tailored to you. Get AI-powered suggestions to help you succeed."
                    )
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }

                // Action Buttons
                VStack(spacing: 16) {
                    // Create Goal Button
                    Button {
                        showingCreateGoal = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Goal")
                        }
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#F2C9A7"))
                        .cornerRadius(12)
                    }

                    // AI Suggestions Button
                    Button {
                        showingSuggestions = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Get AI Suggestions")
                        }
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#D8C8EA"))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .background(LumeColors.appBackground)
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(LumeColors.accentPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumeColors.appBackground)
    }
}

// MARK: - Goal Row View

struct GoalRowView: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Icon with colored background
                ZStack {
                    Circle()
                        .fill(Color(hex: goal.category.colorHex).opacity(0.25))
                        .frame(width: 48, height: 48)

                    Image(systemName: goal.category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(LumeColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)

                    Text(goal.category.displayName)
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                }

                Spacer()

                // Status badge if not active
                if goal.status != .active {
                    Text(goal.status.displayName)
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.25))
                        .cornerRadius(6)
                }
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(LumeColors.textSecondary.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(Color(hex: goal.category.colorHex))
                            .frame(width: geometry.size.width * goal.progress, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(goal.progress * 100))% Complete")
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)

                    Spacer()

                    if let targetDate = goal.targetDate {
                        Text(targetDate, style: .date)
                            .font(LumeTypography.caption)
                            .foregroundColor(
                                goal.isOverdue
                                    ? Color(hex: "#F0B8A4") : LumeColors.textSecondary
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(LumeColors.surface)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch goal.status {
        case .active:
            return Color(hex: "#B8E8D4")
        case .completed:
            return Color(hex: "#B8E8D4")
        case .paused:
            return Color(hex: "#D8C8EA")
        case .archived:
            return Color(hex: "#6E625A")
        }
    }
}

// MARK: - Custom Styled Tabs

struct GoalTabsStyled: View {
    @Binding var selection: Int
    let viewModel: GoalsViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Active
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 0
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Active")
                        .font(.system(size: 14, weight: selection == 0 ? .semibold : .regular))
                    Text("\(viewModel.activeGoals.count)")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.7)
                }
                .foregroundColor(
                    selection == 0 ? LumeColors.textPrimary : LumeColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == 0
                        ? Color(hex: "#F2C9A7")
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())

            // Completed
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 1
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Done")
                        .font(.system(size: 14, weight: selection == 1 ? .semibold : .regular))
                    Text("\(viewModel.completedGoals.count)")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.7)
                }
                .foregroundColor(
                    selection == 1 ? LumeColors.textPrimary : LumeColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == 1
                        ? Color(hex: "#F2C9A7")
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())

            // Paused
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 2
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Paused")
                        .font(.system(size: 14, weight: selection == 2 ? .semibold : .regular))
                    Text("\(viewModel.pausedGoals.count)")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.7)
                }
                .foregroundColor(
                    selection == 2 ? LumeColors.textPrimary : LumeColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == 2
                        ? Color(hex: "#F2C9A7")
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())

            // Archived
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 3
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Archived")
                        .font(.system(size: 14, weight: selection == 3 ? .semibold : .regular))
                    Text("\(viewModel.archivedGoals.count)")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.7)
                }
                .foregroundColor(
                    selection == 3 ? LumeColors.textPrimary : LumeColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == 3
                        ? Color(hex: "#F2C9A7")
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var goalToShow: Goal? = nil

    NavigationStack {
        GoalsListView(
            viewModel: AppDependencies.preview.makeGoalsViewModel(),
            goalToShow: $goalToShow,
            dependencies: AppDependencies.preview
        )
    }
}
