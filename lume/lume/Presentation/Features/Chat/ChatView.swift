//
//  ChatView.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import SwiftUI

/// Main chat view for AI wellness conversations
struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @Bindable var viewModel: ChatViewModel

    var onGoalCreated: ((Goal) -> Void)?

    let conversation: ChatConversation

    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var showDeleteConfirmation = false
    @State private var showArchiveConfirmation = false
    @State private var showGoalSuggestions = false
    @State private var isGeneratingSuggestions = false
    @State private var hasScrolledToGoalSuggestions = false
    @State private var clickedQuickActions: Set<QuickAction> = []

    var body: some View {
        mainContent
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                messagesScrollView
                inputBar
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(LumeColors.appBackground, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarContent }
        .onAppear { onAppearAction() }
        .modifier(
            AlertsModifier(
                viewModel: viewModel,
                conversation: conversation,
                showArchiveConfirmation: $showArchiveConfirmation,
                showDeleteConfirmation: $showDeleteConfirmation,
                showGoalSuggestions: $showGoalSuggestions,
                onGoalCreated: onGoalCreated,
                tabCoordinator: tabCoordinator,
                dismiss: dismiss
            ))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(action: { Task { await viewModel.archiveConversation(conversation) } }) {
                    Label("Archive", systemImage: "archivebox")
                }

                Divider()

                Button(
                    role: .destructive,
                    action: { Task { await viewModel.deleteConversation(conversation) } }
                ) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(LumeColors.textPrimary)
            }
        }
    }

    private func onAppearAction() {
        print("🎯 [ChatView] onAppear - Conversation: \(conversation.title)")
        print("   - Has context: \(conversation.context != nil)")
        print("   - Related goal IDs: \(conversation.context?.relatedGoalIds ?? [])")
        print("   - Message count: \(viewModel.messages.count)")

        // Debug empty state condition
        let hasContext = conversation.context != nil
        let relatedGoalIds = conversation.context?.relatedGoalIds ?? []
        let hasRelatedGoals = !relatedGoalIds.isEmpty
        let isEmpty = viewModel.messages.isEmpty

        print("🔍 [ChatView] Empty state check:")
        print("   - isEmpty: \(isEmpty)")
        print("   - hasContext: \(hasContext)")
        print("   - relatedGoalIds count: \(relatedGoalIds.count)")
        print("   - hasRelatedGoals: \(hasRelatedGoals)")
        print("   - Should show goal empty state: \(isEmpty && hasRelatedGoals)")

        if isEmpty && !hasRelatedGoals {
            print("⚠️ [ChatView] Empty state will show GENERIC (not goal-specific)")
        } else if isEmpty && hasRelatedGoals {
            print("✅ [ChatView] Empty state will show GOAL-SPECIFIC")
        }

        // Reset scroll flag for new conversation
        hasScrolledToGoalSuggestions = false

        Task {
            await viewModel.selectConversation(conversation)
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Only show persona header if NOT showing goal empty state AND NOT showing general empty state
                    let hasRelatedGoals = !(conversation.context?.relatedGoalIds ?? []).isEmpty
                    let shouldShowPersonaHeader = !viewModel.messages.isEmpty || hasRelatedGoals

                    if shouldShowPersonaHeader {
                        personaHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    goalEmptyState

                    generalEmptyState

                    messagesList

                    if viewModel.isSendingMessage {
                        typingIndicator
                            .padding(.horizontal, 20)
                    }

                    goalSuggestionsCard

                    Color.clear.frame(height: 20)
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollProxy = proxy
                if let lastMessage = viewModel.messages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: viewModel.messages) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isSendingMessage) { _, isSending in
                print("🔄 [ChatView] isSendingMessage changed to: \(isSending)")
                print("   - Messages count: \(viewModel.messages.count)")
                print("   - Has scrolled: \(hasScrolledToGoalSuggestions)")
                print("   - Is ready for suggestions: \(viewModel.isReadyForGoalSuggestions)")

                // When AI finishes sending and suggestions are ready, trigger scroll
                if !isSending && viewModel.isReadyForGoalSuggestions && !viewModel.messages.isEmpty
                    && !hasScrolledToGoalSuggestions
                {
                    print(
                        "✅ [ChatView] AI finished sending, triggering auto-scroll to goal suggestions"
                    )
                    hasScrolledToGoalSuggestions = true

                    // Wait for LazyVStack to fully render, then scroll
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        print("📜 [ChatView] Executing scroll to goal-suggestions-card")
                        withAnimation(.easeOut(duration: 0.6)) {
                            proxy.scrollTo("goal-suggestions-scroll-anchor", anchor: .top)
                        }
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside input
                isInputFocused = false
            }
        }
    }

    // MARK: - Goal Empty State

    @ViewBuilder
    private var goalEmptyState: some View {
        let hasRelatedGoals = !(conversation.context?.relatedGoalIds ?? []).isEmpty

        if viewModel.messages.isEmpty && hasRelatedGoals {
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 48))
                    .foregroundColor(LumeColors.accentPrimary)
                    .padding(.top, 32)

                // Show the goal title (remove emoji prefix if present)
                Text(goalTitle)
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Ready to work on this goal?")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textPrimary.opacity(0.8))
                    .multilineTextAlignment(.center)

                Text(
                    "I'm your AI wellness coach. Let's create a plan, tackle challenges, and make real progress on \"\(goalTitle)\". What would you like to start with?"
                )
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                // Example prompts
                VStack(alignment: .leading, spacing: 8) {
                    Text("You could say:")
                        .font(LumeTypography.caption)
                        .foregroundColor(LumeColors.textSecondary)

                    examplePrompt("Help me create a plan to achieve this")
                    examplePrompt("What should my first step be?")
                    examplePrompt("I'm facing challenges with this goal")
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .onAppear {
                print("✅ [ChatView] Goal empty state APPEARED")
                print("   - Conversation: \(conversation.title)")
                print("   - Context: \(String(describing: conversation.context))")
                print("   - Related goal IDs: \(conversation.context?.relatedGoalIds ?? [])")
            }
        }
    }

    // Helper computed property to extract goal title
    private var goalTitle: String {
        // Use goal title from context if available
        if let contextGoalTitle = conversation.context?.goalTitle, !contextGoalTitle.isEmpty {
            return contextGoalTitle
        }

        // Fallback: Remove emoji prefix from conversation title (e.g., "💪 My Goal" -> "My Goal")
        let title = conversation.title
        // Remove common emoji prefixes
        let cleanTitle = title.replacingOccurrences(of: "💪 ", with: "")
            .replacingOccurrences(of: "🎯 ", with: "")
            .replacingOccurrences(of: "✨ ", with: "")
        return cleanTitle.isEmpty ? "Your Goal" : cleanTitle
    }

    // Helper view for example prompts
    private func examplePrompt(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("•")
                .foregroundColor(LumeColors.accentPrimary)
            Text(text)
                .font(LumeTypography.caption)
                .foregroundColor(LumeColors.textSecondary)
                .italic()
        }
    }

    // MARK: - General Empty State (for blank conversations)

    @ViewBuilder
    private var generalEmptyState: some View {
        let hasRelatedGoals = !(conversation.context?.relatedGoalIds ?? []).isEmpty

        // Only show if messages are empty AND it's not a goal conversation
        if viewModel.messages.isEmpty && !hasRelatedGoals {
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

                // Quick action buttons - only show ones that haven't been clicked
                let availableActions = QuickAction.allCases.prefix(4).filter {
                    !clickedQuickActions.contains($0)
                }

                if !availableActions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Start")
                            .font(LumeTypography.titleMedium)
                            .foregroundColor(LumeColors.textPrimary)
                            .padding(.horizontal, 20)

                        ForEach(Array(availableActions), id: \.self) { action in
                            Button(action: {
                                handleQuickAction(action)
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
                            .transition(
                                .asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // Handle quick action button click
    private func handleQuickAction(_ action: QuickAction) {
        // Hide all quick action buttons after clicking one
        withAnimation(.easeOut(duration: 0.3)) {
            // Add all actions to clicked set to hide them all
            clickedQuickActions = Set(QuickAction.allCases)
        }

        // Send the quick action to the AI
        Task {
            await viewModel.sendQuickAction(action)
        }
    }

    // MARK: - Messages List

    @ViewBuilder
    private var messagesList: some View {
        ForEach(viewModel.messages) { message in
            MessageBubble(message: message)
                .id(message.id)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Goal Suggestions Card

    @ViewBuilder
    private var goalSuggestionsCard: some View {
        // Don't show goal suggestions for conversations that already have a goal context
        let hasGoalContext = conversation.context?.relatedGoalIds?.isEmpty == false

        if viewModel.isReadyForGoalSuggestions && !viewModel.isSendingMessage
            && !viewModel.messages.isEmpty && !hasGoalContext
        {
            VStack(spacing: 0) {
                // Invisible anchor point for smooth scrolling - positioned above the card
                Color.clear
                    .frame(height: 1)
                    .id("goal-suggestions-scroll-anchor")

                GoalSuggestionPromptCard {
                    showGoalSuggestions = true
                    Task {
                        await viewModel.generateGoalSuggestions()
                    }
                }
                .id("goal-suggestions-card")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Persona Header

    private var personaHeader: some View {
        VStack(spacing: 8) {
            // Persona icon
            Image(systemName: conversation.persona.systemImage)
                .font(.system(size: 32))
                .foregroundColor(LumeColors.textPrimary)
                .padding(16)
                .background(
                    Circle()
                        .fill(Color(hex: conversation.persona.color).opacity(0.15))
                )

            // Persona name
            Text(conversation.persona.displayName)
                .font(LumeTypography.titleMedium)
                .foregroundColor(LumeColors.textPrimary)

            // Description
            Text(conversation.persona.description)
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: conversation.persona.systemImage)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: conversation.persona.color))

            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(LumeColors.textSecondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .opacity(viewModel.isSendingMessage ? 1.0 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: viewModel.isSendingMessage
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LumeColors.surface.opacity(0.6))
            )

            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(LumeColors.textSecondary.opacity(0.15))

            HStack(alignment: .bottom, spacing: 8) {
                // Text input - WhatsApp style expandable
                TextField(
                    "Message \(conversation.persona.displayName)...", text: $viewModel.messageInput,
                    axis: .vertical
                )
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textPrimary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(LumeColors.accentPrimary.opacity(0.3), lineWidth: 1)
                )
                .lineLimit(1...6)
                .focused($isInputFocused)

                // Send button - WhatsApp style with paperplane
                Button(action: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(
                            viewModel.canSendMessage
                                ? Color(hex: "#F2C9A7")
                                : LumeColors.textSecondary.opacity(0.5)
                        )
                }
                .disabled(!viewModel.canSendMessage)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(LumeColors.appBackground)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopiedAlert = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUserMessage {
                Spacer()
            }

            VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 4) {
                // Message content
                Group {
                    if message.isAssistantMessage {
                        // AI messages: Parse markdown using AttributedString
                        Text(parseMarkdown(message.content))
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textPrimary)
                    } else {
                        // User messages: Plain text
                        Text(message.content)
                            .font(LumeTypography.body)
                            .foregroundColor(LumeColors.textPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            message.isUserMessage
                                ? Color(hex: "#F2C9A7").opacity(0.3)
                                : Color.white.opacity(0.5)
                        )
                )
                .contextMenu {
                    Button {
                        copyToClipboard(message.content)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc.fill")
                    }
                }

                // Timestamp
                Text(message.formattedTimestamp)
                    .font(LumeTypography.caption)
                    .foregroundColor(LumeColors.textSecondary.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if message.isAssistantMessage {
                Spacer()
            }
        }
        .overlay(alignment: .top) {
            if showCopiedAlert {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Copied")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                )
                .offset(y: -8)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text

        // Show copied confirmation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedAlert = true
        }

        // Hide after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCopiedAlert = false
            }
        }
    }

    /// Parse markdown string to AttributedString for native rendering
    private func parseMarkdown(_ text: String) -> AttributedString {
        // Convert markdown headers to bold text since block elements don't work well in chat bubbles
        var processedText = text

        // Replace headers with bold markdown: #### Header -> **Header**
        // Also handle horizontal rules (---)
        let lines = processedText.components(separatedBy: "\n")
        let convertedLines = lines.map { line -> String in
            // Check if line starts with # (header syntax)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Handle horizontal rules: --- or *** or ___
            if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___"
                || trimmedLine.hasPrefix("---") || trimmedLine.hasPrefix("***")
                || trimmedLine.hasPrefix("___")
            {
                return "━━━━━━━━━━━━━━━━━━━━"  // Visual divider
            }

            if trimmedLine.hasPrefix("#") {
                // Find where the # symbols end
                var headerLevel = 0
                for char in trimmedLine {
                    if char == "#" {
                        headerLevel += 1
                    } else {
                        break
                    }
                }

                // Get the text after the # symbols
                let startIndex = trimmedLine.index(trimmedLine.startIndex, offsetBy: headerLevel)
                let headerText = trimmedLine[startIndex...].trimmingCharacters(in: .whitespaces)

                // Convert to bold if there's actual text
                if !headerText.isEmpty {
                    return "**\(headerText)**"
                }
            }
            return line
        }
        processedText = convertedLines.joined(separator: "\n")

        do {
            // Parse as markdown with inline-only for bold, italic, code
            var attributedString = try AttributedString(
                markdown: processedText,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )

            // Apply base styling
            attributedString.font = .system(size: 17, weight: .regular, design: .rounded)
            attributedString.foregroundColor = LumeColors.textPrimary

            return attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(text)
        }
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

    // Create mock conversation
    let conversation = ChatConversation(
        userId: UUID(),
        title: "Wellness Check-in",
        persona: .generalWellness,
        messages: [
            ChatMessage(
                conversationId: UUID(),
                role: .assistant,
                content:
                    "Hello! I'm your wellness coach. How can I support your wellness journey today?",
                timestamp: Date().addingTimeInterval(-300)
            ),
            ChatMessage(
                conversationId: UUID(),
                role: .user,
                content:
                    "I'd like to work on my sleep schedule. I've been having trouble falling asleep lately.",
                timestamp: Date().addingTimeInterval(-240)
            ),
            ChatMessage(
                conversationId: UUID(),
                role: .assistant,
                content:
                    "I understand sleep challenges can be frustrating. Let's work on this together. Can you tell me more about your current bedtime routine? What time do you usually try to go to sleep, and what activities do you do before bed?",
                timestamp: Date().addingTimeInterval(-180)
            ),
        ]
    )

    NavigationStack {
        ChatView(viewModel: viewModel, conversation: conversation)
            .task {
                await viewModel.selectConversation(conversation)
            }
    }
}

// MARK: - Alerts Modifier

private struct AlertsModifier: ViewModifier {
    @Bindable var viewModel: ChatViewModel
    let conversation: ChatConversation
    @Binding var showArchiveConfirmation: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var showGoalSuggestions: Bool
    let onGoalCreated: ((Goal) -> Void)?
    let tabCoordinator: TabCoordinator
    let dismiss: DismissAction

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .confirmationDialog(
                conversation.isArchived ? "Unarchive Conversation" : "Archive Conversation",
                isPresented: $showArchiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel", role: .cancel) {}
                Button(conversation.isArchived ? "Unarchive" : "Archive") {
                    Task {
                        if conversation.isArchived {
                            await viewModel.unarchiveConversation(conversation)
                        } else {
                            await viewModel.archiveConversation(conversation)
                        }
                        dismiss()
                    }
                }
            } message: {
                Text(
                    conversation.isArchived
                        ? "This conversation will be moved back to your active chats."
                        : "This conversation will be moved to your archived chats. You can find it in the archive section."
                )
            }
            .alert("Delete Conversation", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteConversation(conversation)
                        dismiss()
                    }
                }
            } message: {
                Text(
                    "Are you sure you want to delete this conversation? This action cannot be undone."
                )
            }
            .sheet(isPresented: $showGoalSuggestions) {
                viewModel.clearGoalSuggestions()
            } content: {
                goalSuggestionsView
            }
    }

    @ViewBuilder
    private var goalSuggestionsView: some View {
        ConsultationGoalSuggestionsView(
            consultationId: conversation.id,
            persona: conversation.persona,
            suggestions: viewModel.goalSuggestions,
            isLoading: viewModel.isLoadingGoalSuggestions,
            onCreateGoal: { suggestion in
                Task {
                    do {
                        let goal = try await viewModel.createGoal(from: suggestion)
                        showGoalSuggestions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if let onGoalCreated = onGoalCreated {
                                onGoalCreated(goal)
                            } else {
                                tabCoordinator.switchToGoals(showingGoal: goal)
                                dismiss()
                            }
                        }
                    } catch {
                        viewModel.errorMessage =
                            "Failed to create goal: \(error.localizedDescription)"
                        viewModel.showError = true
                    }
                }
            }
        )
    }
}
