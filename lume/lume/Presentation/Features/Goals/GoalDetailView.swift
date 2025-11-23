//
//  GoalDetailView.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//

import SwiftUI

/// Detail view for a specific goal
struct GoalDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tabCoordinator: TabCoordinator
    let goal: Goal
    @Bindable var viewModel: GoalsViewModel
    let dependencies: AppDependencies
    @State private var showingTipsView = false
    @State private var showingDeleteConfirmation = false
    @State private var showingArchiveConfirmation = false
    @State private var isCreatingChat = false
    @State private var chatCreationError: String?
    @State private var showChatCreationError = false
    @State private var localProgress: Double

    init(goal: Goal, viewModel: GoalsViewModel, dependencies: AppDependencies) {
        self.goal = goal
        self.viewModel = viewModel
        self.dependencies = dependencies
        _localProgress = State(initialValue: goal.progress)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Category Icon with colored background for better visibility
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: goal.category.colorHex).opacity(0.25))
                            .frame(width: 64, height: 64)

                        Image(systemName: goal.category.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(LumeColors.textPrimary)
                    }

                    Spacer()
                }

                // Title
                Text(goal.title)
                    .font(LumeTypography.titleLarge)
                    .foregroundColor(LumeColors.textPrimary)

                // Description
                if !goal.description.isEmpty {
                    Text(goal.description)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                }

                // Progress Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Progress")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)

                        Spacer()

                        Text("\(Int(localProgress * 100))%")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                    }

                    // Progress Bar
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(LumeColors.textSecondary.opacity(0.2))
                                    .frame(height: 12)
                                    .cornerRadius(6)

                                Rectangle()
                                    .fill(Color(hex: goal.category.colorHex))
                                    .frame(width: geometry.size.width * localProgress, height: 12)
                                    .cornerRadius(6)
                            }
                        }
                        .frame(height: 12)
                    }

                    // Progress Slider (only show if goal is active)
                    if goal.status == .active {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: $localProgress, in: 0...1, step: 0.05) {
                                Text("Progress")
                            }
                            .tint(Color(hex: goal.category.colorHex))
                            .onChange(of: localProgress) { oldValue, newValue in
                                Task {
                                    await viewModel.updateProgress(
                                        goalId: goal.id, progress: newValue)
                                }
                            }

                            Text("Drag to update progress")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                        .padding(.top, 8)
                    }
                }

                // Dates
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Started")
                                .font(LumeTypography.bodySmall)
                                .foregroundColor(LumeColors.textSecondary)
                            Text(goal.createdAt, style: .date)
                                .font(LumeTypography.body)
                                .foregroundColor(LumeColors.textPrimary)
                        }

                        Spacer()

                        if let targetDate = goal.targetDate {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Target")
                                    .font(LumeTypography.bodySmall)
                                    .foregroundColor(LumeColors.textSecondary)
                                Text(targetDate, style: .date)
                                    .font(LumeTypography.body)
                                    .foregroundColor(LumeColors.textPrimary)
                            }
                        }
                    }
                    .padding(16)
                    .background(LumeColors.surface)
                    .cornerRadius(12)
                }

                // AI Tips Button
                Button {
                    showingTipsView = true
                } label: {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("Get AI Tips")
                    }
                    .font(LumeTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#D8C8EA"))
                    .cornerRadius(12)
                }

                // NOTE: "Chat About Goal" button temporarily removed (2025-01-15)
                // Reason: Gathering user feedback on "Get AI Tips" first to validate approach
                // Implementation: All chat functionality preserved in createGoalChat() and GoalChatView
                // To re-enable: See docs/design/GOAL_CHAT_FEATURE_DEFERRED.md for full details
                // Button was: HStack with bubble icon + "Chat About Goal" text, color #F2C9A7

                // Action Buttons
                VStack(spacing: 12) {
                    // Complete Button (only show if active and not already complete)
                    if goal.status == .active && goal.progress < 1.0 {
                        Button {
                            Task {
                                await viewModel.completeGoal(goal.id)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Complete")
                            }
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#B8E8D4"))
                            .cornerRadius(12)
                        }
                    }

                    // Pause/Resume Button
                    if goal.status == .active {
                        Button {
                            Task {
                                await viewModel.pauseGoal(goal.id)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "pause.circle")
                                Text("Pause Goal")
                            }
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LumeColors.surface)
                            .cornerRadius(12)
                        }
                    } else if goal.status == .paused {
                        Button {
                            Task {
                                await viewModel.resumeGoal(goal.id)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                Text("Resume Goal")
                            }
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#B8E8D4"))
                            .cornerRadius(12)
                        }
                    }

                    // Archive Button
                    Button {
                        showingArchiveConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "archivebox")
                            Text("Archive Goal")
                        }
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LumeColors.surface)
                        .cornerRadius(12)
                    }

                    // Delete Button
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Goal")
                        }
                        .font(LumeTypography.body)
                        .foregroundColor(Color(hex: "#F0B8A4"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LumeColors.surface)
                        .cornerRadius(12)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .background(LumeColors.appBackground)
        .navigationTitle("Goal Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingTipsView) {
            GoalTipsView(goal: goal, viewModel: viewModel)
        }
        .navigationTitle("Goal Details")
        .confirmationDialog(
            "Delete Goal",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteGoal(goal.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
        .confirmationDialog(
            "Archive Goal",
            isPresented: $showingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                Task {
                    await viewModel.archiveGoal(goal.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to archive this goal? You can find it in the Archived tab.")
        }
        .alert("Chat Creation Failed", isPresented: $showChatCreationError) {
            Button("OK", role: .cancel) {
                chatCreationError = nil
            }
        } message: {
            if let error = chatCreationError {
                Text(error)
            }
        }
    }

    // MARK: - Goal Chat

    /// Create a chat conversation about this goal and navigate to it
    private func createGoalChat() async {
        isCreatingChat = true
        chatCreationError = nil

        do {
            print("🎯 [GoalDetailView] Creating goal chat for: \(goal.title)")
            print("🎯 [GoalDetailView] Goal local ID: \(goal.id)")
            print("🎯 [GoalDetailView] Goal backend ID: \(goal.backendId ?? "nil")")

            // First, check if a conversation already exists for this goal
            print("🔍 [GoalDetailView] Checking for existing goal conversation...")
            do {
                let existingConversations = try await dependencies.chatRepository
                    .fetchConversationsRelatedToGoal(goal.id)

                // Find the first non-archived conversation for this goal that has proper context
                if let existingConversation = existingConversations.first(where: { conversation in
                    !conversation.isArchived
                        && conversation.context?.relatedGoalIds?.contains(goal.id) == true
                }) {
                    print(
                        "✅ [GoalDetailView] Found existing conversation with context: \(existingConversation.id)"
                    )
                    print("   - Title: \(existingConversation.title)")
                    print("   - Messages: \(existingConversation.messageCount)")
                    print("   - Has context: \(existingConversation.context != nil)")
                    print(
                        "   - Related goal IDs: \(existingConversation.context?.relatedGoalIds ?? [])"
                    )

                    // Dismiss the goal detail sheet first
                    dismiss()

                    // Wait for dismiss animation to complete, then navigate to the existing conversation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("🚀 [GoalDetailView] Navigating to existing goal chat")
                        tabCoordinator.switchToChat(showingConversation: existingConversation)
                    }

                    isCreatingChat = false
                    return
                }

                print(
                    "ℹ️ [GoalDetailView] No existing conversation with context found, creating new one"
                )
            } catch {
                print("⚠️ [GoalDetailView] Failed to check for existing conversations: \(error)")
                print("   - Continuing to create new conversation")
            }

            // Check if goal has backend ID - if not, sync it first
            var currentGoal = goal

            // Check if goal needs to be synced to backend
            let needsSync = currentGoal.backendId == nil

            if needsSync {
                print("⚠️ [GoalDetailView] Goal has no backend ID, syncing first...")
                print("   - Local ID: \(currentGoal.id)")

                // Trigger outbox processing to sync the goal
                await dependencies.outboxProcessorService.processOutbox()

                // Wait for sync to complete with exponential backoff
                // Check more frequently at first, then less frequently
                var syncSuccess = false
                let checkIntervals: [TimeInterval] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

                for (attempt, interval) in checkIntervals.enumerated() {
                    print("🔄 [GoalDetailView] Sync check \(attempt + 1)/\(checkIntervals.count)")

                    // Wait before checking
                    print("⏱️ [GoalDetailView] Waiting \(interval) seconds...")
                    try await Task.sleep(for: .seconds(interval))

                    // Fetch updated goal from repository
                    if let updatedGoal = try? await dependencies.goalRepository.fetchById(
                        currentGoal.id)
                    {
                        print("✅ [GoalDetailView] Fetched updated goal from repository")
                        print("   - Local ID: \(updatedGoal.id)")
                        print("   - Backend ID: \(updatedGoal.backendId ?? "nil")")

                        if let backendId = updatedGoal.backendId, !backendId.isEmpty {
                            currentGoal = updatedGoal
                            syncSuccess = true
                            print("✅ [GoalDetailView] Goal successfully synced with backend!")
                            print("   - Backend ID: \(backendId)")
                            break
                        } else {
                            print(
                                "⚠️ [GoalDetailView] Goal still has no backend ID after check \(attempt + 1)"
                            )
                        }
                    } else {
                        print("⚠️ [GoalDetailView] Could not fetch updated goal from repository")
                    }
                }

                // If sync failed after all attempts, show error
                if !syncSuccess || currentGoal.backendId == nil {
                    print(
                        "❌ [GoalDetailView] Failed to sync goal after \(checkIntervals.count) checks"
                    )
                    print("   - Backend ID: \(currentGoal.backendId ?? "nil")")
                    print("   - Local ID: \(currentGoal.id)")
                    print("💡 [GoalDetailView] Tip: Check network connection and backend logs")
                    throw GoalChatError.goalNotSynced
                }
            }

            print("🎯 [GoalDetailView] About to create conversation")
            print("   - Using backend ID: \(currentGoal.backendId ?? "nil")")

            // Create conversation with goal context
            let conversation = try await dependencies.createConversationUseCase
                .createForGoal(
                    goalId: currentGoal.id,
                    goalTitle: currentGoal.title,
                    backendGoalId: currentGoal.backendId,
                    persona: .generalWellness
                )

            print("✅ [GoalDetailView] Goal chat created: \(conversation.id)")

            // Dismiss the goal detail sheet first
            dismiss()

            // Wait for dismiss animation to complete, then navigate to the conversation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("🚀 [GoalDetailView] Navigating to chat tab with conversation")
                // Switch to Chat tab and show the conversation directly
                tabCoordinator.switchToChat(showingConversation: conversation)
            }
        } catch {
            // Handle error - show alert with user-friendly message
            print("❌ [GoalDetailView] Failed to create goal chat: \(error)")

            let errorMessage: String
            if let chatError = error as? GoalChatError {
                errorMessage = chatError.errorDescription ?? "Unable to create chat."
            } else if let localError = error as? LocalizedError,
                let description = localError.errorDescription
            {
                errorMessage = description
            } else {
                errorMessage = "Unable to create chat. Please try again."
            }

            chatCreationError = errorMessage
            showChatCreationError = true
        }

        isCreatingChat = false
    }
}

// MARK: - Errors

enum GoalChatError: LocalizedError {
    case goalNotSynced

    var errorDescription: String? {
        switch self {
        case .goalNotSynced:
            return
                "Unable to sync this goal with the server. Please check your internet connection and try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .goalNotSynced:
            return
                "Make sure you're connected to the internet, then try again. If the problem persists, the goal may need to be recreated."
        }
    }
}

// MARK: - Goal Chat View

struct GoalChatView: View {
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    let dependencies: AppDependencies
    @State private var chatViewModel: ChatViewModel?
    @State private var isCreatingConversation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isCreatingConversation {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color(hex: "#F2C9A7"))
                        Text("Starting conversation...")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LumeColors.appBackground)
                } else if let chatViewModel = chatViewModel {
                    if let conversation = chatViewModel.currentConversation {
                        ChatView(viewModel: chatViewModel, conversation: conversation)
                    } else {
                        Text("No conversation available")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#F0B8A4"))
                        Text("Failed to start chat")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                        Text(error)
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Try Again") {
                            Task {
                                await createConversation()
                            }
                        }
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#F2C9A7"))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LumeColors.appBackground)
                }
            }
            .navigationTitle("Chat About Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await createConversation()
        }
    }

    private func createConversation() async {
        isCreatingConversation = true
        errorMessage = nil

        do {
            let useCase = dependencies.createConversationUseCase

            // Create a goal-specific conversation
            var conversation = try await useCase.createForGoal(
                goalId: goal.id,
                goalTitle: goal.title,
                backendGoalId: goal.backendId,
                persona: ChatPersona.generalWellness
            )

            // Ensure context has the current goal title (handles existing conversations)
            if let existingContext = conversation.context {
                // If the context doesn't have goalTitle or it's different, update it
                if existingContext.goalTitle != goal.title {
                    print(
                        "🔄 [GoalChatView] Updating context with current goal title: '\(goal.title)'"
                    )
                    let updatedContext = ConversationContext(
                        relatedGoalIds: existingContext.relatedGoalIds,
                        relatedInsightIds: existingContext.relatedInsightIds,
                        moodContext: existingContext.moodContext,
                        quickAction: existingContext.quickAction,
                        backendGoalId: existingContext.backendGoalId,
                        goalTitle: goal.title
                    )

                    // Create updated conversation with new context
                    conversation = ChatConversation(
                        id: conversation.id,
                        userId: conversation.userId,
                        title: conversation.title,
                        persona: conversation.persona,
                        messages: conversation.messages,
                        createdAt: conversation.createdAt,
                        updatedAt: conversation.updatedAt,
                        isArchived: conversation.isArchived,
                        context: updatedContext,
                        hasContextForGoalSuggestions: conversation.hasContextForGoalSuggestions
                    )

                    // Save the updated context to repository
                    do {
                        _ = try await dependencies.chatRepository.updateConversation(conversation)
                        print("✅ [GoalChatView] Updated conversation context with goal title")
                    } catch {
                        print("⚠️ [GoalChatView] Failed to persist updated context: \(error)")
                        // Continue anyway - the in-memory conversation has the correct context
                    }
                }
            }

            // Create ChatViewModel with the conversation
            let newChatViewModel = dependencies.makeChatViewModel()
            newChatViewModel.currentConversation = conversation
            newChatViewModel.messages = conversation.messages

            chatViewModel = newChatViewModel
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [GoalChatView] Failed to create conversation: \(error)")
        }

        isCreatingConversation = false
    }
}
