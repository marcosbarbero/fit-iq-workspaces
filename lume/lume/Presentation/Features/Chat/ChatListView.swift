//
//  ChatListView.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import SwiftUI

/// View displaying all chat conversations
struct ChatListView: View {
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @Bindable var viewModel: ChatViewModel

    @State private var showingNewChat = false
    @State private var selectedFilter = 0  // 0 = Active, 1 = Archived
    @State private var navigationPath = NavigationPath()
    @State private var conversationToNavigate: ChatConversation?
    @State private var conversationToDelete: ChatConversation?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // WhatsApp-style tabs with custom styling
            SegmentedControlStyled(selection: $selectedFilter)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.top, 8)
                .background(LumeColors.appBackground)
                .onChange(of: selectedFilter) { _, newValue in
                    viewModel.showArchivedOnly = (newValue == 1)
                }

            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()

                if viewModel.isLoading && !viewModel.hasConversations {
                    loadingView
                } else if viewModel.filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }

                // FAB for new chat - only show on Active tab and moved higher
                if viewModel.hasConversations && selectedFilter == 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                Task {
                                    await viewModel.createConversation(
                                        persona: .wellnessSpecialist, forceNew: true)

                                    // Small delay to ensure conversation is fully created
                                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

                                    if let conversation = viewModel.currentConversation {
                                        // Navigate to the conversation
                                        await MainActor.run {
                                            conversationToNavigate = conversation
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "plus.bubble.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(LumeColors.textPrimary)
                                    .padding(20)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "#F2C9A7"))
                                            .shadow(
                                                color: Color.black.opacity(0.1),
                                                radius: 8,
                                                x: 0,
                                                y: 4
                                            )
                                    )
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)  // Closer to tab bar, scrolls under
                        }
                    }
                }
            }
        }
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(LumeColors.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .refreshable {
            await viewModel.loadConversations()
        }
        .navigationDestination(item: $conversationToNavigate) { conversation in
            ChatViewWrapper(
                viewModel: viewModel,
                conversation: conversation,
                tabCoordinator: tabCoordinator,
                conversationToNavigate: $conversationToNavigate
            )
        }
        .task {
            // Load conversations on first appear or when empty
            await viewModel.loadConversations()
        }
        .onChange(of: tabCoordinator.conversationToShow) { oldValue, newValue in
            // Navigate to conversation when set from TabCoordinator (e.g., from Goals)
            if let conversation = newValue {
                conversationToNavigate = conversation
                // Clear the coordinator's property to avoid re-triggering
                tabCoordinator.conversationToShow = nil
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if let conversation = conversationToDelete {
                        await viewModel.deleteConversation(conversation)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(LumeColors.textPrimary)

            Text("Loading conversations...")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#D8C8EA").opacity(0.5))

            // Title
            Text(viewModel.showArchivedOnly ? "No Archived Chats" : "Start Your First Chat")
                .font(LumeTypography.titleLarge)
                .foregroundColor(LumeColors.textPrimary)

            // Description
            Text(
                viewModel.showArchivedOnly
                    ? "You haven't archived any conversations yet"
                    : "Chat with an AI wellness coach for personalized guidance and support"
            )
            .font(LumeTypography.body)
            .foregroundColor(LumeColors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            if !viewModel.showArchivedOnly {
                // Start Chat button
                Button(action: {
                    Task {
                        await viewModel.createConversation(
                            persona: .wellnessSpecialist, forceNew: true)

                        // Small delay to ensure conversation is fully created
                        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

                        if let conversation = viewModel.currentConversation {
                            // Navigate to the conversation
                            await MainActor.run {
                                conversationToNavigate = conversation
                            }
                        }
                    }
                }) {
                    Text("Start Chat")
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#F2C9A7"))
                        )
                }
                .padding(.top, 16)
            }

            Spacer()
        }
    }

    // MARK: - Conversations List

    private var conversationsList: some View {
        List {
            ForEach(viewModel.filteredConversations) { conversation in
                Button(action: {
                    conversationToNavigate = conversation
                }) {
                    ConversationCard(conversation: conversation)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        conversationToDelete = conversation
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        Task {
                            if conversation.isArchived {
                                await viewModel.unarchiveConversation(conversation)
                            } else {
                                await viewModel.archiveConversation(conversation)
                            }
                        }
                    } label: {
                        Label(
                            conversation.isArchived ? "Unarchive" : "Archive",
                            systemImage: conversation.isArchived
                                ? "tray.and.arrow.up" : "archivebox"
                        )
                    }
                    .tint(LumeColors.accentSecondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(LumeColors.appBackground)
        .contentMargins(.bottom, 80, for: .scrollContent)  // Add bottom padding for FAB
    }
}

// MARK: - Conversation Card

struct ConversationCard: View {
    let conversation: ChatConversation

    var body: some View {
        HStack(spacing: 12) {
            // Persona icon with better contrast - using FAB color
            Image(systemName: conversation.persona.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(LumeColors.textPrimary)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color(hex: "#F2C9A7"))
                )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title and persona
                HStack {
                    Text(conversation.title)
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(LumeColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(conversation.formattedUpdatedDate)
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)
                }

                // Last message preview
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(2)
                }

                // Message count
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 12))
                        .foregroundColor(LumeColors.textSecondary)
                    Text("\(conversation.messageCount) messages")
                        .foregroundColor(LumeColors.textSecondary)
                }
                .font(LumeTypography.caption)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(LumeColors.textSecondary.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.5))
        )
    }
}

// MARK: - New Chat Sheet

struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ChatViewModel
    @Binding var conversationToNavigate: ChatConversation?

    @State private var selectedQuickAction: QuickAction?

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Wellness Companion header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#D8C8EA"))
                            .padding(20)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#D8C8EA").opacity(0.15))
                            )

                        Text("Wellness Companion")
                            .font(LumeTypography.titleLarge)
                            .foregroundColor(LumeColors.textPrimary)

                        Text("Your supportive guide for mood and wellness")
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 32)

                    // Quick actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Start")
                            .font(LumeTypography.titleMedium)
                            .foregroundColor(LumeColors.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(QuickAction.allCases.prefix(4), id: \.self) { action in
                            Button(action: {
                                selectedQuickAction = action
                                startChat(with: action)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: action.systemImage)
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "#D8C8EA"))
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(action.displayName)
                                            .font(LumeTypography.body)
                                            .foregroundColor(LumeColors.textPrimary)

                                        Text(action.prompt)
                                            .font(LumeTypography.bodySmall)
                                            .foregroundColor(LumeColors.textSecondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(LumeColors.textSecondary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.5))
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Start blank conversation
                    Button(action: {
                        startBlankChat()
                    }) {
                        Text("Start Blank Conversation")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#D8C8EA").opacity(0.3))
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(LumeColors.appBackground, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(LumeColors.textPrimary)
            }
        }
    }

    private func startChat(with action: QuickAction) {
        Task {
            await viewModel.createConversation(persona: .wellnessSpecialist, forceNew: true)
            if let conversation = viewModel.currentConversation {
                await viewModel.sendQuickAction(action)

                // Wait for message to be sent and response to arrive
                // Poll isSendingMessage with timeout
                let startTime = Date()
                let timeout: TimeInterval = 5.0  // 5 second max wait

                while viewModel.isSendingMessage && Date().timeIntervalSince(startTime) < timeout {
                    try? await Task.sleep(nanoseconds: 100_000_000)  // Check every 0.1 seconds
                }

                // Additional delay to ensure messages are persisted
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

                // Refresh messages to ensure they're loaded from database
                await viewModel.refreshCurrentMessages()

                conversationToNavigate = conversation
                dismiss()
            }
        }
    }

    private func startBlankChat() {
        Task {
            await viewModel.createConversation(persona: .wellnessSpecialist, forceNew: true)
            if let conversation = viewModel.currentConversation {
                conversationToNavigate = conversation
                dismiss()
            }
        }
    }
}

// MARK: - Chat Filters Sheet

struct ChatFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ChatViewModel

    @State private var showArchived = false

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Archived filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(LumeTypography.titleMedium)
                            .foregroundColor(LumeColors.textPrimary)

                        Toggle(isOn: $showArchived) {
                            HStack(spacing: 12) {
                                Image(systemName: "archivebox")
                                    .foregroundColor(LumeColors.textPrimary)

                                Text("Show Archived Only")
                                    .font(LumeTypography.body)
                                    .foregroundColor(LumeColors.textPrimary)
                            }
                        }
                        .tint(Color(hex: "#F2C9A7"))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.5))
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Clear") {
                    showArchived = false
                }
                .foregroundColor(LumeColors.textPrimary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Apply") {
                    viewModel.applyFilters(persona: nil, showArchived: showArchived)
                    dismiss()
                }
                .foregroundColor(LumeColors.textPrimary)
            }
        }
        .onAppear {
            showArchived = viewModel.showArchivedOnly
        }
    }
}

// MARK: - Chat View Wrapper

/// Wrapper to properly handle dismiss and tab switching
struct ChatViewWrapper: View {
    let viewModel: ChatViewModel
    let conversation: ChatConversation
    let tabCoordinator: TabCoordinator
    @Binding var conversationToNavigate: ChatConversation?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ChatView(
            viewModel: viewModel,
            onGoalCreated: { goal in
                // Clear navigation to pop ChatView from the stack
                // This returns us to ChatListView which doesn't hide the tab bar
                conversationToNavigate = nil

                // Wait for the navigation pop animation to fully complete
                // This ensures we're back at ChatListView before switching tabs
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    // Switch to Goals tab and show the created goal
                    tabCoordinator.switchToGoals(showingGoal: goal)
                }
            },
            conversation: conversation
        )
        .environmentObject(tabCoordinator)
    }
}

// MARK: - Styled Segmented Control

struct SegmentedControlStyled: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 0
                }
            } label: {
                Text("Active")
                    .font(.system(size: 15, weight: selection == 0 ? .semibold : .regular))
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

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 1
                }
            } label: {
                Text("Archived")
                    .font(.system(size: 15, weight: selection == 1 ? .semibold : .regular))
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
    let deps = AppDependencies.preview
    let viewModel = ChatViewModel(
        createConversationUseCase: deps.createConversationUseCase,
        sendMessageUseCase: deps.sendChatMessageUseCase,
        fetchConversationsUseCase: deps.fetchConversationsUseCase,
        chatRepository: deps.chatRepository,
        chatService: deps.chatService,
        tokenStorage: deps.tokenStorage,
        goalAIService: deps.goalAIService,
        createGoalUseCase: deps.createGoalUseCase
    )

    NavigationStack {
        ChatListView(viewModel: viewModel)
    }
}
