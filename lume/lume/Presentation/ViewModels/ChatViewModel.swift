//
//  ChatViewModel.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import FitIQCore
import Foundation
import Observation

/// ViewModel for managing AI chat conversations
@Observable
@MainActor
final class ChatViewModel {
    // MARK: - Published State

    var conversations: [ChatConversation] = []
    var currentConversation: ChatConversation?
    var messages: [ChatMessage] = []
    var messageInput: String = ""
    var isLoading = false
    var isSendingMessage = false
    var showError = false
    var errorMessage: String?

    // Filter state
    var selectedPersona: ChatPersona?
    var showArchivedOnly = false

    // MARK: - Dependencies

    private let createConversationUseCase: CreateConversationUseCase
    private let sendMessageUseCase: SendChatMessageUseCase
    private let fetchConversationsUseCase: FetchConversationsUseCase
    private let chatRepository: ChatRepositoryProtocol
    private let chatService: ChatServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let goalAIService: GoalAIServiceProtocol
    private let createGoalUseCase: CreateGoalUseCase

    // Live streaming WebSocket manager (follows backend guide)
    nonisolated(unsafe) private var consultationManager: ConsultationWebSocketManager?
    private var isUsingLiveChat = false
    private var currentlyConnectedConversationId: UUID?

    // Polling timer for fallback
    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?
    private var isPolling = false
    private let pollingInterval: TimeInterval = 3.0  // Poll every 3 seconds
    private var isWebSocketHealthy = false  // Track WebSocket connection health

    // Track which messages have been persisted to database
    private var persistedMessageIds: Set<UUID> = []

    // Goal suggestions state
    var isLoadingGoalSuggestions = false
    var goalSuggestions: [GoalSuggestion] = []
    var goalSuggestionsError: String?

    // MARK: - Initialization

    init(
        createConversationUseCase: CreateConversationUseCase,
        sendMessageUseCase: SendChatMessageUseCase,
        fetchConversationsUseCase: FetchConversationsUseCase,
        chatRepository: ChatRepositoryProtocol,
        chatService: ChatServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        goalAIService: GoalAIServiceProtocol,
        createGoalUseCase: CreateGoalUseCase
    ) {
        self.createConversationUseCase = createConversationUseCase
        self.sendMessageUseCase = sendMessageUseCase
        self.fetchConversationsUseCase = fetchConversationsUseCase
        self.chatRepository = chatRepository
        self.chatService = chatService
        self.tokenStorage = tokenStorage
        self.goalAIService = goalAIService
        self.createGoalUseCase = createGoalUseCase
    }

    deinit {
        pollingTask?.cancel()
        Task {
            await chatService.disconnectWebSocket()
        }
        consultationManager?.disconnect()
    }

    // MARK: - Computed Properties

    var canSendMessage: Bool {
        !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSendingMessage
            && messageInput.count <= ChatMessage.maxContentLength
    }

    var hasConversations: Bool {
        !conversations.isEmpty
    }

    var filteredConversations: [ChatConversation] {
        var filtered = conversations

        // Filter by persona
        if let persona = selectedPersona {
            filtered = filtered.filter { $0.persona == persona }
        }

        // Filter by archived status
        if showArchivedOnly {
            filtered = filtered.filter { $0.isArchived }
        } else {
            filtered = filtered.filter { !$0.isArchived }
        }

        // Sort by updated date (newest first)
        filtered.sort { $0.updatedAt > $1.updatedAt }

        return filtered
    }

    var characterCount: Int {
        messageInput.count
    }

    var characterCountColor: String {
        if characterCount > ChatMessage.maxContentLength {
            return "#F0B8A4"  // Error red
        } else if characterCount > ChatMessage.maxContentLength - 500 {
            return "#F5DFA8"  // Warning yellow
        } else {
            return "#6E625A"  // Secondary text
        }
    }

    // MARK: - Public Methods

    /// Load all conversations from local storage only (no backend sync)
    /// Use this for quick refreshes when returning to the chat list
    func loadLocalConversations() async {
        guard !isLoading else { return }

        isLoading = true

        do {
            // Fetch from local storage only (syncFromBackend: false)
            conversations = try await fetchConversationsUseCase.execute(
                includeArchived: true,
                syncFromBackend: false,
                status: nil,
                persona: nil,
                limit: 100,
                offset: 0
            )
            print("✅ [ChatViewModel] Loaded \(conversations.count) local conversations")
        } catch {
            print("❌ [ChatViewModel] Failed to load local conversations: \(error)")
        }

        isLoading = false
    }

    /// Load all conversations
    /// Note: Backend now supports GET /api/v1/consultations with filtering and pagination
    /// Syncs from backend and falls back to local data if sync fails
    func loadConversations() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        showError = false

        do {
            // Sync from backend with default parameters (all statuses, no persona filter, limit 100)
            // Will gracefully fall back to local data if sync fails
            conversations = try await fetchConversationsUseCase.execute(
                includeArchived: true,
                syncFromBackend: true,
                status: nil,
                persona: nil,
                limit: 100,
                offset: 0
            )
            print("✅ [ChatViewModel] Loaded \(conversations.count) conversations")
        } catch {
            print("❌ [ChatViewModel] Failed to load conversations: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    /// Create a new conversation
    func createConversation(
        persona: ChatPersona = .generalWellness,
        context: ConversationContext? = nil,
        forceNew: Bool = false
    ) async {
        // If not forcing new, check if we already have a local conversation with this persona
        if !forceNew {
            // First, check if we already have a local conversation with this persona
            if conversations.isEmpty {
                // Load local conversations first if not already loaded
                print("🔍 [ChatViewModel] Loading local conversations before creating new one")
                do {
                    conversations = try await fetchConversationsUseCase.execute(
                        includeArchived: true,
                        syncFromBackend: false,  // Only fetch from local storage
                        status: nil,
                        persona: nil,
                        limit: 100,
                        offset: 0
                    )
                } catch {
                    print("⚠️ [ChatViewModel] Failed to load local conversations: \(error)")
                }
            }

            // Check if we already have an active conversation with this persona locally
            if let existing = conversations.first(where: { $0.persona == persona && !$0.isArchived }
            ) {
                print(
                    "✅ [ChatViewModel] Found existing local conversation with \(persona), reusing it"
                )
                currentConversation = existing
                messages = existing.messages

                // Connect WebSocket for real-time responses (will use live chat)
                await connectWebSocket(for: existing.id)
                await refreshCurrentMessages()
                return
            }
        } else {
            print("🆕 [ChatViewModel] Force creating new conversation (forceNew=true)")
        }

        // No local conversation found or forceNew is true, create a new one
        do {
            let conversation = try await createConversationUseCase.execute(
                title: "New Conversation",
                persona: persona,
                context: context
            )

            // Add to list
            conversations.insert(conversation, at: 0)

            // Set as current
            currentConversation = conversation
            messages = conversation.messages

            // Connect WebSocket for real-time responses (will use live chat)
            await connectWebSocket(for: conversation.id)

            print("✅ [ChatViewModel] Created new conversation: \(conversation.id)")
        } catch let error as HTTPError where error.isConflict {
            // 409 Conflict - conversation with this persona already exists
            // This is normal and expected - just fetch and open the existing one silently
            print("ℹ️ [ChatViewModel] Consultation already exists, opening existing one")

            // Check if backend provided existing consultation ID
            if let existingId = error.existingConsultationId {
                print("ℹ️ [ChatViewModel] Using existing consultation ID: \(existingId)")

                // First check if we already have it locally
                if let existing = conversations.first(where: { $0.id == existingId }) {
                    print("✅ [ChatViewModel] Found existing consultation locally")
                    currentConversation = existing
                    messages = existing.messages

                    // Connect WebSocket
                    await connectWebSocket(for: existing.id)
                    await refreshCurrentMessages()
                } else {
                    // Fetch from backend using the provided ID (silent fetch)
                    print("🔄 [ChatViewModel] Fetching existing consultation from backend...")
                    do {
                        let existing = try await fetchConversationsUseCase.fetchById(existingId)
                        if let existing = existing {
                            // Add to local list
                            conversations.insert(existing, at: 0)
                            currentConversation = existing
                            messages = existing.messages

                            // Connect WebSocket
                            await connectWebSocket(for: existing.id)
                            await refreshCurrentMessages()
                            print("✅ [ChatViewModel] Opened existing consultation: \(existing.id)")
                        } else {
                            print(
                                "⚠️ [ChatViewModel] Consultation not found, attempting recovery...")
                            await recoverFromOrphanedConsultation(
                                existingId: existingId, persona: persona, context: context)
                        }
                    } catch {
                        print("⚠️ [ChatViewModel] Failed to fetch existing consultation: \(error)")
                        // Try to recover by deleting and recreating
                        await recoverFromOrphanedConsultation(
                            existingId: existingId, persona: persona, context: context)
                    }
                }
            } else {
                // Fallback: Backend didn't provide ID (old API version)
                print("ℹ️ [ChatViewModel] Searching local database for existing consultation...")

                // Search local database by persona
                if let existing = conversations.first(where: {
                    $0.persona == persona && !$0.isArchived
                }) {
                    currentConversation = existing
                    messages = existing.messages

                    // Connect WebSocket
                    await connectWebSocket(for: existing.id)
                    await refreshCurrentMessages()
                    print(
                        "✅ [ChatViewModel] Found and opened existing consultation: \(existing.id)")
                } else {
                    print("⚠️ [ChatViewModel] Could not find existing consultation locally")
                    // Don't show error - user doesn't need to know about internal conflict
                }
            }
        } catch {
            print("❌ [ChatViewModel] Failed to create conversation: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Select a conversation to view
    func selectConversation(_ conversation: ChatConversation) async {
        print("📖 [ChatViewModel] selectConversation called for: \(conversation.id)")
        print("   - Title: \(conversation.title)")
        print("   - Has context: \(conversation.context != nil)")
        print("   - Related goal IDs: \(conversation.context?.relatedGoalIds ?? [])")
        print("   - Message count: \(conversation.messages.count)")

        // Avoid duplicate selection and connection
        if currentConversation?.id == conversation.id
            && currentlyConnectedConversationId == conversation.id
        {
            print("ℹ️ [ChatViewModel] Already connected to conversation: \(conversation.id)")
            // Just refresh messages in case there are updates
            messages = conversation.messages
            return
        }

        print("✅ [ChatViewModel] Setting new current conversation: \(conversation.id)")
        print("   - Context being set: \(conversation.context != nil)")
        print("   - Related goal IDs being set: \(conversation.context?.relatedGoalIds ?? [])")

        // Clear persisted message tracking when switching conversations
        persistedMessageIds.removeAll()

        currentConversation = conversation
        messages = conversation.messages

        // Connect WebSocket for real-time AI responses (only if not already connected)
        if currentlyConnectedConversationId != conversation.id {
            print("🔌 [ChatViewModel] Connecting to WebSocket for new conversation")
            await connectWebSocket(for: conversation.id)
            currentlyConnectedConversationId = conversation.id
        }

        // Load messages from repository
        print("🔄 [ChatViewModel] Refreshing current messages from repository")
        await refreshCurrentMessages()

        print("✅ [ChatViewModel] Conversation selected, showing \(messages.count) messages")
    }

    /// Refresh messages for current conversation
    /// More efficient than reloading all conversations
    func refreshCurrentMessages() async {
        guard let conversation = currentConversation else { return }

        // Only fetch messages for current conversation, not all conversations
        do {
            let updatedMessages = try await chatRepository.fetchMessages(for: conversation.id)
            messages = updatedMessages
            print(
                "✅ [ChatViewModel] Refreshed \(updatedMessages.count) messages for current conversation"
            )
        } catch {
            print("❌ [ChatViewModel] Failed to refresh messages: \(error)")
        }
    }

    /// Send a message in the current conversation
    func sendMessage() async {
        guard canSendMessage,
            let conversation = currentConversation
        else {
            print(
                "⚠️ [ChatViewModel] Cannot send message - canSendMessage: \(canSendMessage), currentConversation: \(currentConversation != nil)"
            )
            return
        }

        let content = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        messageInput = ""  // Clear input immediately

        isSendingMessage = true

        print("📤 [ChatViewModel] Sending message: '\(content.prefix(50))...'")
        print(
            "📊 [ChatViewModel] isUsingLiveChat: \(isUsingLiveChat), consultationManager: \(consultationManager != nil)"
        )

        // Create optimistic user message to show immediately
        let optimisticMessage = ChatMessage(
            conversationId: conversation.id,
            role: .user,
            content: content
        )

        // Add to UI immediately for instant feedback
        messages.append(optimisticMessage)

        // Use live chat if available
        if isUsingLiveChat, let manager = consultationManager {
            do {
                print("💬 [ChatViewModel] Sending via live chat WebSocket")
                print("🔍 [ChatViewModel] Manager connected: \(manager.isConnected)")
                print("🔍 [ChatViewModel] Current messages in manager: \(manager.messages.count)")

                try await manager.sendMessage(content)

                print("🔄 [ChatViewModel] Message sent, syncing from consultation manager...")

                // Sync immediately to show user message and any responses
                syncConsultationMessagesToDomain()

                print(
                    "🔍 [ChatViewModel] After send, messages in manager: \(manager.messages.count)")
                print("🔍 [ChatViewModel] Messages in UI: \(messages.count)")

                print("✅ [ChatViewModel] Live chat message sent and synced")

                // Keep isSendingMessage true while waiting for AI response
                // It will be set to false by the sync task when response arrives

            } catch {
                print("❌ [ChatViewModel] Live chat failed: \(error)")
                print("❌ [ChatViewModel] Error details: \(String(describing: error))")

                // Remove optimistic message before fallback
                if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    messages.remove(at: index)
                }

                isSendingMessage = false
                // Fallback to REST API (which adds its own optimistic message)
                await sendViaRestAPI(content: content, conversation: conversation)
            }
        } else {
            print("ℹ️ [ChatViewModel] Using REST API (not live chat)")
            print("🔍 [ChatViewModel] isUsingLiveChat: \(isUsingLiveChat)")
            print("🔍 [ChatViewModel] consultationManager exists: \(consultationManager != nil)")

            // Remove the optimistic message we added at the start
            if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                messages.remove(at: index)
            }

            // Use REST API (which will add its own optimistic message)
            await sendViaRestAPI(content: content, conversation: conversation)
            isSendingMessage = false
        }
    }

    /// Send message via REST API (fallback method)
    private func sendViaRestAPI(content: String, conversation: ChatConversation) async {
        // Create optimistic user message (only if not already added)
        let userMessage = ChatMessage(
            conversationId: conversation.id,
            role: .user,
            content: content
        )

        // Add to UI immediately if not already there
        if !messages.contains(where: { $0.content == content && $0.role == .user }) {
            messages.append(userMessage)
        }

        do {
            // Send to backend (returns the user message)
            _ = try await sendMessageUseCase.execute(
                conversationId: conversation.id,
                content: content,
                useStreaming: true
            )

            // Refresh messages to get the assistant's response
            await refreshCurrentMessages()

            // Also refresh the conversation list to update message counts
            await updateCurrentConversationInList()

            print("✅ [ChatViewModel] REST API message sent and response received")
        } catch {
            print("❌ [ChatViewModel] Failed to send message: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// Update the current conversation in the conversations list after sending a message
    private func updateCurrentConversationInList() async {
        guard let current = currentConversation else { return }

        do {
            // Fetch the updated conversation from backend to get latest hasContextForGoalSuggestions
            if let updated = try await fetchConversationsUseCase.fetchById(
                current.id, syncFromBackend: true)
            {
                // Find and replace in the conversations array
                if let index = conversations.firstIndex(where: { $0.id == current.id }) {
                    conversations[index] = updated
                    currentConversation = updated
                    print(
                        "✅ [ChatViewModel] Updated conversation in list with new message count: \(updated.messageCount)"
                    )
                }
            }
        } catch {
            print("⚠️ [ChatViewModel] Failed to update conversation in list: \(error)")
        }
    }

    /// Send a quick action message
    func sendQuickAction(_ action: QuickAction) async {
        if currentConversation == nil {
            // Create new conversation for quick action
            await createConversation(persona: .generalWellness)
            guard currentConversation != nil else { return }
        }

        messageInput = action.prompt
        await sendMessage()
    }

    /// Archive a conversation
    func archiveConversation(_ conversation: ChatConversation) async {
        do {
            // Archive in repository (syncs to backend)
            let updatedConversation = try await chatRepository.archiveConversation(conversation.id)

            // Update in list
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index] = updatedConversation
            }

            // Clear current if it's the archived one
            if currentConversation?.id == conversation.id {
                currentConversation = nil
                messages = []
            }

            print("✅ [ChatViewModel] Archived conversation: \(conversation.id)")
        } catch {
            print("❌ [ChatViewModel] Failed to archive conversation: \(error)")
            errorMessage = "Failed to archive conversation"
            showError = true
        }
    }

    /// Unarchive a conversation
    func unarchiveConversation(_ conversation: ChatConversation) async {
        do {
            // Unarchive in repository (syncs to backend)
            let updatedConversation = try await chatRepository.unarchiveConversation(
                conversation.id)

            // Update in list
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index] = updatedConversation
            }

            print("✅ [ChatViewModel] Unarchived conversation: \(conversation.id)")
        } catch {
            print("❌ [ChatViewModel] Failed to unarchive conversation: \(error)")
            errorMessage = "Failed to unarchive conversation"
            showError = true
        }
    }

    /// Delete a conversation
    func deleteConversation(_ conversation: ChatConversation) async {
        print("🗑️ [ChatViewModel] Deleting conversation: \(conversation.id)")

        // 1. Remove from UI immediately for instant feedback
        conversations.removeAll { $0.id == conversation.id }

        // 2. Clear current if it's the deleted one
        if currentConversation?.id == conversation.id {
            currentConversation = nil
            messages = []
        }

        print("✅ [ChatViewModel] Conversation removed from UI")

        // 3. Delete from backend and local storage
        do {
            // Delete from repository (this creates outbox event for backend)
            try await chatRepository.deleteConversation(conversation.id)

            print("✅ [ChatViewModel] Conversation deleted from local storage")

            // 4. Try immediate backend deletion (don't wait for outbox)
            if (try? await tokenStorage.getToken()) != nil {
                print("🔄 [ChatViewModel] Attempting immediate backend deletion...")
                try? await chatService.deleteConversation(id: conversation.id)
                print("✅ [ChatViewModel] Backend deletion completed")
            }

            print("✅ [ChatViewModel] Deletion complete")
        } catch {
            print("❌ [ChatViewModel] Failed to delete from storage: \(error)")
            // Don't show error to user since it's already removed from UI
            // The outbox will retry the backend deletion
        }
    }

    /// Clear current conversation
    func clearCurrentConversation() {
        // Disconnect WebSocket and stop polling
        chatService.disconnectWebSocket()
        stopPolling()

        currentConversation = nil
        messages = []
        messageInput = ""
        persistedMessageIds.removeAll()
    }

    /// Clear error
    func clearError() {
        errorMessage = nil
        showError = false
    }

    /// Apply filters
    func applyFilters(persona: ChatPersona?, showArchived: Bool) {
        selectedPersona = persona
        showArchivedOnly = showArchived
    }

    /// Recover from orphaned consultation (exists in backend 409 but can't be fetched)
    private func recoverFromOrphanedConsultation(
        existingId: UUID, persona: ChatPersona, context: ConversationContext?
    ) async {
        print("🔧 [ChatViewModel] Attempting to delete orphaned consultation: \(existingId)")

        do {
            // Try to delete the orphaned consultation
            try await chatRepository.deleteConversation(existingId)
            print("✅ [ChatViewModel] Deleted orphaned consultation, creating new one...")

            // Now try to create a fresh consultation
            let conversation = try await createConversationUseCase.execute(
                title: "New Conversation",
                persona: persona,
                context: context
            )

            conversations.insert(conversation, at: 0)
            currentConversation = conversation
            messages = conversation.messages

            // Connect WebSocket
            await connectWebSocket(for: conversation.id)
            await refreshCurrentMessages()
            print("✅ [ChatViewModel] Created fresh consultation after recovery: \(conversation.id)")
        } catch {
            print("❌ [ChatViewModel] Recovery failed: \(error.localizedDescription)")
            // Last resort - show error to user since we can't recover
            errorMessage = "Unable to start chat. Please try again or contact support."
            showError = true
        }
    }

    // MARK: - WebSocket & Polling

    /// Start live chat with ConsultationWebSocketManager
    private func startLiveChat(conversationId: UUID, persona: ChatPersona) async {
        print(
            "🎬 [ChatViewModel] startLiveChat called for conversation: \(conversationId), persona: \(persona.rawValue)"
        )

        do {
            // Get token and API key
            print("🔑 [ChatViewModel] Getting token from storage...")
            guard let token = try await tokenStorage.getToken() else {
                print("⚠️ [ChatViewModel] No token available, falling back to polling")
                await startPollingFallback(for: conversationId)
                return
            }

            print("✅ [ChatViewModel] Token retrieved successfully")
            let apiKey = AppConfiguration.shared.apiKey
            print(
                "✅ [ChatViewModel] API key retrieved: \(String(repeating: "*", count: apiKey.count))"
            )

            print("🚀 [ChatViewModel] Starting live chat with ConsultationWebSocketManager")

            // Create consultation manager
            consultationManager = ConsultationWebSocketManager(
                jwtToken: token.accessToken,
                apiKey: apiKey
            )

            // Connect to existing consultation (don't create a new one!)
            print("🔌 [ChatViewModel] Connecting to existing consultation: \(conversationId)")
            try await consultationManager?.connectToExistingConsultation(
                consultationID: conversationId.uuidString.lowercased()
            )

            print(
                "🔍 [ChatViewModel] After connection - Manager has \(consultationManager?.messages.count ?? 0) messages"
            )
            print(
                "🔍 [ChatViewModel] Connection status: \(consultationManager?.connectionStatus ?? .disconnected)"
            )

            isUsingLiveChat = true

            // Sync messages from consultation manager to view model
            syncConsultationMessagesToDomain()

            print("🔍 [ChatViewModel] After initial sync - UI has \(messages.count) messages")

            // Start periodic sync to keep messages updated
            startConsultationMessageSync()

            // Mark WebSocket as healthy
            isWebSocketHealthy = true

            print("✅ [ChatViewModel] Live chat started successfully")

        } catch {
            print("❌ [ChatViewModel] Failed to start live chat: \(error.localizedDescription)")
            print("❌ [ChatViewModel] Error type: \(type(of: error))")
            print("❌ [ChatViewModel] Full error: \(error)")
            print("🔄 [ChatViewModel] Falling back to polling")
            isUsingLiveChat = false
            isWebSocketHealthy = false
            consultationManager = nil
            await startPollingFallback(for: conversationId)
        }
    }

    /// Sync consultation messages to domain messages for UI display
    private func syncConsultationMessagesToDomain() {
        guard let manager = consultationManager else {
            print("⚠️ [ChatViewModel] No consultation manager to sync from")
            return
        }

        print(
            "🔄 [ChatViewModel] Syncing \(manager.messages.count) messages from consultation manager"
        )

        // Convert ConsultationMessage to ChatMessage
        let newMessages = manager.messages.map { consultationMsg in
            ChatMessage(
                id: UUID(uuidString: consultationMsg.id) ?? UUID(),
                conversationId: currentConversation?.id ?? UUID(),
                role: consultationMsg.role == .user ? .user : .assistant,
                content: consultationMsg.content,
                timestamp: consultationMsg.timestamp,
                metadata: MessageMetadata(
                    persona: nil,
                    context: nil,
                    tokens: nil,
                    processingTime: nil,
                    isStreaming: consultationMsg.isStreaming
                )
            )
        }

        // Update messages array - this triggers SwiftUI updates
        // Use removeAll + append to ensure proper change detection
        messages.removeAll()
        messages.append(contentsOf: newMessages)

        print("✅ [ChatViewModel] Synced messages, now showing \(messages.count) in UI")

        // Check if AI is still typing/streaming
        let hasStreamingMessage = messages.contains { $0.metadata?.isStreaming == true }

        // Only set isSendingMessage to false if no streaming messages
        if !hasStreamingMessage && !manager.isAITyping {
            isSendingMessage = false
        }

        // Log message details for debugging
        for (index, msg) in messages.enumerated() {
            print(
                "  [\(index)] \(msg.role == .user ? "👤" : "🤖") \(msg.content.prefix(50))... (streaming: \(msg.metadata?.isStreaming ?? false))"
            )
        }

        // Persist new messages to database (only completed messages, not streaming)
        persistNewMessages()

        // Update the conversation in the list with latest message info
        Task {
            await updateCurrentConversationInList()
        }
    }

    /// Persist messages from WebSocket that haven't been saved to the database yet
    private func persistNewMessages() {
        guard let conversationId = currentConversation?.id else {
            return
        }

        // Filter messages that are:
        // 1. Not already persisted
        // 2. Not currently streaming (completed messages only)
        // 3. Not empty (NEW)
        let messagesToPersist = messages.filter { message in
            let notPersisted = !persistedMessageIds.contains(message.id)
            let notStreaming = !(message.metadata?.isStreaming ?? false)
            let notEmpty = !message.content.trimmingCharacters(in: .whitespaces).isEmpty

            return notPersisted && notStreaming && notEmpty
        }

        guard !messagesToPersist.isEmpty else {
            print("ℹ️ [ChatViewModel] No new complete messages to persist")
            return
        }

        print("💾 [ChatViewModel] Persisting \(messagesToPersist.count) new messages to database")

        // Persist messages asynchronously
        Task {
            for message in messagesToPersist {
                do {
                    print(
                        "💾 [ChatViewModel] Persisting: role=\(message.role), content='\(message.content.prefix(50))'"
                    )

                    try await chatRepository.addMessage(message, to: conversationId)

                    // Mark as persisted
                    await MainActor.run {
                        persistedMessageIds.insert(message.id)
                    }

                    print("✅ [ChatViewModel] Persisted \(message.role) message: \(message.id)")
                } catch {
                    print("❌ [ChatViewModel] Failed to persist message \(message.id): \(error)")
                }
            }

            print(
                "✅ [ChatViewModel] Finished persisting messages. Total persisted: \(persistedMessageIds.count)"
            )
        }
    }

    /// Start periodic sync of consultation messages
    private func startConsultationMessageSync() {
        print("🔄 [ChatViewModel] Starting consultation message sync task")

        // Cancel any existing sync task
        pollingTask?.cancel()

        pollingTask = Task { [weak self] in
            var syncCount = 0
            while !Task.isCancelled {
                syncCount += 1
                if syncCount % 10 == 0 {  // Log every 10 syncs (every 20 seconds)
                    print(
                        "🔄 [ChatViewModel] Sync cycle #\(syncCount) - WebSocket healthy: \(self?.isWebSocketHealthy ?? false)"
                    )
                }

                // Check if WebSocket is still healthy
                guard let self = self else { break }

                if self.isWebSocketHealthy {
                    // WebSocket is connected and healthy - just sync from consultation manager
                    self.syncConsultationMessagesToDomain()
                } else {
                    // WebSocket unhealthy - fall back to polling
                    print("⚠️ [ChatViewModel] WebSocket unhealthy, falling back to polling")
                    if let conversationId = self.currentConversation?.id {
                        await self.startPollingFallback(for: conversationId)
                    }
                    break
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2.0 seconds for more natural, human-like streaming speed
            }
        }
    }

    /// Connect to WebSocket for real-time AI responses
    private func connectWebSocket(for conversationId: UUID) async {
        print("🔌 [ChatViewModel] connectWebSocket called for: \(conversationId)")

        // First, try to use live chat with ConsultationWebSocketManager
        if let conversation = currentConversation {
            print("✅ [ChatViewModel] Current conversation found, starting live chat...")
            await startLiveChat(conversationId: conversationId, persona: conversation.persona)
            return
        }

        print("⚠️ [ChatViewModel] No current conversation, using legacy WebSocket")
        // Fallback to legacy WebSocket implementation
        await connectLegacyWebSocket(for: conversationId)
    }

    /// Connect to legacy WebSocket (fallback)
    private func connectLegacyWebSocket(for conversationId: UUID) async {
        do {
            print(
                "🔌 [ChatViewModel] Connecting to WebSocket for conversation: \(conversationId)")

            try await chatService.connectWebSocket(
                conversationId: conversationId,
                onMessage: { [weak self] message in
                    Task { @MainActor in
                        self?.handleIncomingMessage(message)
                    }
                },
                onError: { [weak self] error in
                    Task { @MainActor in
                        print(
                            "⚠️ [ChatViewModel] WebSocket error: \(error.localizedDescription)")
                        // Start polling as fallback
                        await self?.startPollingFallback(for: conversationId)
                    }
                },
                onDisconnect: { [weak self] in
                    Task { @MainActor in
                        print("⚠️ [ChatViewModel] WebSocket disconnected")
                        // Start polling as fallback
                        await self?.startPollingFallback(for: conversationId)
                    }
                }
            )

            print("✅ [ChatViewModel] WebSocket connected successfully")
        } catch {
            print(
                "❌ [ChatViewModel] Failed to connect WebSocket: \(error.localizedDescription)")
            // Start polling as fallback
            await startPollingFallback(for: conversationId)
        }
    }

    /// Handle incoming WebSocket message
    private func handleIncomingMessage(_ message: ChatMessage) {
        guard let conversation = currentConversation,
            message.conversationId == conversation.id
        else {
            return
        }

        // Add message if not already in list
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.timestamp < $1.timestamp }
            print("✅ [ChatViewModel] Received message via WebSocket: \(message.role)")
        }
    }

    /// Start polling for messages as fallback when WebSocket fails
    private func startPollingFallback(for conversationId: UUID) async {
        guard !isPolling else {
            print("ℹ️ [ChatViewModel] Already polling, skipping duplicate polling start")
            return
        }

        // Mark WebSocket as unhealthy when falling back to polling
        isWebSocketHealthy = false
        isPolling = true
        print("🔄 [ChatViewModel] Starting message polling fallback (WebSocket unavailable)")

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                // Only continue polling if WebSocket is still unhealthy
                if self.isWebSocketHealthy {
                    print("✅ [ChatViewModel] WebSocket recovered, stopping polling fallback")
                    await MainActor.run {
                        self.isPolling = false
                    }
                    break
                }

                await self.pollForNewMessages(conversationId: conversationId)
                try? await Task.sleep(
                    nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
            }
        }
    }

    /// Poll for new messages
    private func pollForNewMessages(conversationId: UUID) async {
        guard let conversation = currentConversation,
            conversation.id == conversationId
        else {
            return
        }

        do {
            let fetchedMessages = try await chatRepository.fetchMessages(for: conversationId)

            // Check for new messages
            let newMessages = fetchedMessages.filter { fetchedMsg in
                !messages.contains(where: { $0.id == fetchedMsg.id })
            }

            if !newMessages.isEmpty {
                messages.append(contentsOf: newMessages)
                messages.sort { $0.timestamp < $1.timestamp }
                print("✅ [ChatViewModel] Polled \(newMessages.count) new message(s)")
            }
        } catch {
            print("⚠️ [ChatViewModel] Polling error: \(error.localizedDescription)")
        }
    }

    /// Stop polling
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
        isUsingLiveChat = false
        isWebSocketHealthy = false
        consultationManager?.disconnect()
        consultationManager = nil
        currentlyConnectedConversationId = nil
        print("⏹️ [ChatViewModel] Stopped message polling and live chat")
    }

    /// Clear all local conversations (for debugging/recovery from sync issues)
    /// This does NOT delete consultations from the backend
    func clearAllLocalConversations() async {
        print("🗑️ [ChatViewModel] Clearing all local conversations")
        conversations.removeAll()
        currentConversation = nil
        messages.removeAll()

        // Note: This only clears the in-memory list
        // The actual database cleanup would need to be done at repository level
        print("✅ [ChatViewModel] Local conversations cleared from memory")
        print("⚠️ [ChatViewModel] Note: Backend consultations still exist and need manual cleanup")
    }

    /// Clear filters
    func clearFilters() {
        selectedPersona = nil
        showArchivedOnly = false
    }

    // MARK: - Goal Suggestions

    /// Check if conversation is ready for goal suggestions
    /// Uses backend-provided flag based on AI analysis of conversation context
    var isReadyForGoalSuggestions: Bool {
        return currentConversation?.hasContextForGoalSuggestions ?? false
    }

    /// Generate goal suggestions based on current conversation
    func generateGoalSuggestions() async {
        guard let conversation = currentConversation else {
            goalSuggestionsError = "Unable to generate suggestions for this conversation"
            return
        }

        // The conversation ID is the consultation ID
        let consultationId = conversation.id

        isLoadingGoalSuggestions = true
        goalSuggestionsError = nil

        do {
            let suggestions = try await goalAIService.generateConsultationGoalSuggestions(
                consultationId: consultationId,
                maxSuggestions: 3
            )
            goalSuggestions = suggestions
        } catch {
            goalSuggestionsError =
                "Failed to generate goal suggestions: \(error.localizedDescription)"
            print("❌ [ChatViewModel] Failed to generate goal suggestions: \(error)")
        }

        isLoadingGoalSuggestions = false
    }

    /// Create a goal from a suggestion
    func createGoal(from suggestion: GoalSuggestion) async throws -> Goal {
        return try await createGoalUseCase.createFromSuggestion(suggestion)
    }

    /// Clear goal suggestions state
    func clearGoalSuggestions() {
        goalSuggestions = []
        goalSuggestionsError = nil
        isLoadingGoalSuggestions = false
    }
}
