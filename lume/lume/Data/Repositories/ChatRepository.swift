//
//  ChatRepository.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import FitIQCore
import Foundation
import SwiftData

/// SwiftData implementation of ChatRepositoryProtocol
/// Handles local persistence of chat conversations and messages
final class ChatRepository: ChatRepositoryProtocol, UserAuthenticatedRepository {
    private let modelContext: ModelContext
    private let backendService: ChatBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let outboxRepository: OutboxRepositoryProtocol

    init(
        modelContext: ModelContext,
        backendService: ChatBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        outboxRepository: OutboxRepositoryProtocol
    ) {
        self.modelContext = modelContext
        self.backendService = backendService
        self.tokenStorage = tokenStorage
        self.outboxRepository = outboxRepository
    }

    // MARK: - Conversation Operations

    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?
    ) async throws -> ChatConversation {
        guard (try? getCurrentUserId()) != nil else {
            throw ChatRepositoryError.notAuthenticated
        }

        // Get access token
        guard let token = try? await tokenStorage.getToken() else {
            throw ChatRepositoryError.notAuthenticated
        }

        // Create consultation on backend first to get backend-assigned ID
        print("🔄 [ChatRepository] Creating consultation on backend...")

        let backendConversation: ChatConversation
        do {
            backendConversation = try await backendService.createConversation(
                title: title,
                persona: persona,
                context: context,
                accessToken: token.accessToken
            )
            print("✅ [ChatRepository] Backend returned consultation ID: \(backendConversation.id)")
            print(
                "📝 [ChatRepository] Backend returned \(backendConversation.messages.count) initial messages"
            )
        } catch let error as HTTPError where error.isConflict {
            // 409 Conflict - conversation already exists for this goal/context
            print("ℹ️ [ChatRepository] Conversation already exists (409), fetching existing one")

            if let existingId = error.existingConsultationId {
                // Backend provided the existing conversation ID
                print("✅ [ChatRepository] Backend provided existing ID: \(existingId)")

                // Try to fetch from local database first
                let descriptor = FetchDescriptor<SDChatConversation>(
                    predicate: #Predicate { $0.id == existingId }
                )

                if let localConv = try? modelContext.fetch(descriptor).first {
                    print("✅ [ChatRepository] Found existing conversation locally")

                    // Fetch messages for this conversation
                    let messagesDescriptor = FetchDescriptor<SDChatMessage>(
                        predicate: #Predicate { $0.conversationId == existingId },
                        sortBy: [SortDescriptor(\SDChatMessage.timestamp, order: .forward)]
                    )
                    let sdMessages = (try? modelContext.fetch(messagesDescriptor)) ?? []
                    let messages = sdMessages.map { toDomainMessage($0) }

                    backendConversation = toDomainConversation(localConv, messages: messages)
                } else {
                    // Fetch from backend
                    print("🔄 [ChatRepository] Fetching existing conversation from backend...")
                    backendConversation = try await backendService.fetchConversation(
                        conversationId: existingId,
                        accessToken: token.accessToken
                    )

                    // Save it locally
                    let sdConv = toSwiftDataConversation(backendConversation)
                    modelContext.insert(sdConv)
                    try modelContext.save()
                    print("✅ [ChatRepository] Saved existing conversation to local database")
                }
            } else {
                // No existing ID provided, try to find by context
                print("⚠️ [ChatRepository] No existing ID provided in 409 response")
                throw error
            }
        }

        // Merge the original context with backend response to preserve client-side data like goalTitle
        var finalConversation = backendConversation
        if let originalContext = context, let backendContext = backendConversation.context {
            // Preserve goalTitle from original context (backend doesn't store/return it)
            let mergedContext = ConversationContext(
                relatedGoalIds: backendContext.relatedGoalIds ?? originalContext.relatedGoalIds,
                relatedInsightIds: backendContext.relatedInsightIds
                    ?? originalContext.relatedInsightIds,
                moodContext: backendContext.moodContext ?? originalContext.moodContext,
                quickAction: backendContext.quickAction ?? originalContext.quickAction,
                backendGoalId: backendContext.backendGoalId ?? originalContext.backendGoalId,
                goalTitle: originalContext.goalTitle  // Always use original goalTitle
            )
            finalConversation = ChatConversation(
                id: backendConversation.id,
                userId: backendConversation.userId,
                title: backendConversation.title,
                persona: backendConversation.persona,
                messages: backendConversation.messages,
                createdAt: backendConversation.createdAt,
                updatedAt: backendConversation.updatedAt,
                isArchived: backendConversation.isArchived,
                context: mergedContext,
                hasContextForGoalSuggestions: backendConversation.hasContextForGoalSuggestions
            )
            print(
                "✅ [ChatRepository] Merged context to preserve goalTitle: '\(originalContext.goalTitle ?? "nil")'"
            )
        }

        // Save to local SwiftData with backend ID
        print("💾 [ChatRepository] Saving consultation to local database...")
        let sdConversation = toSwiftDataConversation(finalConversation)
        print("💾 [ChatRepository] SwiftData conversation created with ID: \(sdConversation.id)")
        print(
            "💾 [ChatRepository] Persona: \(sdConversation.persona), User: \(sdConversation.userId)")

        modelContext.insert(sdConversation)

        // Save initial messages from backend (e.g., AI greeting for goal context)
        if finalConversation.messages.isEmpty == false {
            print(
                "💾 [ChatRepository] Saving \(finalConversation.messages.count) initial messages..."
            )
            for message in finalConversation.messages {
                let sdMessage = toSwiftDataMessage(message)
                modelContext.insert(sdMessage)
                print(
                    "💾 [ChatRepository] Saved message: role=\(message.role.rawValue), content='\(message.content.prefix(50))...'"
                )
            }
        }

        try modelContext.save()

        print("✅ [ChatRepository] Consultation saved to local database successfully")

        // Verify it was saved by fetching it back
        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == finalConversation.id }
        )
        if let verified = try? modelContext.fetch(descriptor).first {
            print(
                "✅ [ChatRepository] Verification: Consultation found in local database with ID: \(verified.id)"
            )
        } else {
            print(
                "⚠️ [ChatRepository] WARNING: Could not verify consultation was saved to local database!"
            )
        }

        return finalConversation
    }

    func updateConversation(_ conversation: ChatConversation) async throws -> ChatConversation {
        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == conversation.id }
        )

        // Upsert: Create if not exists, update if exists
        if let sdConversation = try modelContext.fetch(descriptor).first {
            // Update existing
            print("🔄 [ChatRepository] Updating existing conversation: \(conversation.id)")
            updateSDConversation(sdConversation, from: conversation)
            // Preserve the updatedAt from the conversation (from backend)
            // Don't overwrite with Date() as this causes all conversations to show current time
            sdConversation.updatedAt = conversation.updatedAt
        } else {
            // Create new (for cross-device sync)
            print(
                "✨ [ChatRepository] Creating new conversation from backend sync: \(conversation.id)"
            )
            let sdConversation = toSwiftDataConversation(conversation)
            modelContext.insert(sdConversation)
        }

        try modelContext.save()

        return try await fetchConversationById(conversation.id) ?? conversation
    }

    func fetchAllConversations() async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            print("❌ [ChatRepository] fetchAllConversations: Not authenticated")
            throw ChatRepositoryError.notAuthenticated
        }

        print("🔍 [ChatRepository] Fetching all conversations for user: \(userId)")

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        print("🔍 [ChatRepository] Found \(results.count) conversations in local database")

        for (index, sdConv) in results.enumerated() {
            print(
                "🔍 [ChatRepository] [\(index + 1)] ID: \(sdConv.id), Persona: \(sdConv.persona), Title: \(sdConv.title)"
            )
        }

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            conversations.append(toDomainConversation(sdConversation, messages: messages))
        }

        print("✅ [ChatRepository] Returning \(conversations.count) conversations")
        return conversations
    }

    func fetchActiveConversations() async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId && !conversation.isArchived
            },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            conversations.append(toDomainConversation(sdConversation, messages: messages))
        }

        return conversations
    }

    func fetchArchivedConversations() async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId && conversation.isArchived
            },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            conversations.append(toDomainConversation(sdConversation, messages: messages))
        }

        return conversations
    }

    func fetchConversationsByPersona(_ persona: ChatPersona) async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        let personaString = persona.rawValue

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId && conversation.persona == personaString
            },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            conversations.append(toDomainConversation(sdConversation, messages: messages))
        }

        return conversations
    }

    func fetchConversationById(_ id: UUID) async throws -> ChatConversation? {
        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdConversation = try modelContext.fetch(descriptor).first else {
            return nil
        }

        let messages = try await fetchMessages(for: id)
        return toDomainConversation(sdConversation, messages: messages)
    }

    func searchConversations(query: String) async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        let lowercaseQuery = query.lowercased()

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId
                    && conversation.title.localizedStandardContains(lowercaseQuery)
            },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            conversations.append(toDomainConversation(sdConversation, messages: messages))
        }

        return conversations
    }

    func archiveConversation(_ id: UUID) async throws -> ChatConversation {
        // Update local database first
        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdConversation = try modelContext.fetch(descriptor).first else {
            throw ChatRepositoryError.notFound
        }

        sdConversation.isArchived = true
        sdConversation.updatedAt = Date()

        try modelContext.save()

        // TODO: Sync to backend when archive endpoint is available
        // The backend supports "archived" status but no dedicated archive endpoint yet
        // For now, archive is local-only
        print("⚠️ [ChatRepository] Archive is local-only, backend sync not yet implemented")

        return try await fetchConversationById(id)
            ?? ChatConversation(
                id: id,
                userId: sdConversation.userId,
                title: sdConversation.title,
                persona: ChatPersona(rawValue: sdConversation.persona) ?? .generalWellness
            )
    }

    func unarchiveConversation(_ id: UUID) async throws -> ChatConversation {
        // Update local database first
        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdConversation = try modelContext.fetch(descriptor).first else {
            throw ChatRepositoryError.notFound
        }

        sdConversation.isArchived = false
        sdConversation.updatedAt = Date()

        try modelContext.save()

        // TODO: Sync to backend when unarchive endpoint is available
        // The backend supports "archived" status but no dedicated unarchive endpoint yet
        // For now, unarchive is local-only
        print("⚠️ [ChatRepository] Unarchive is local-only, backend sync not yet implemented")

        return try await fetchConversationById(id)
            ?? ChatConversation(
                id: id,
                userId: sdConversation.userId,
                title: sdConversation.title,
                persona: ChatPersona(rawValue: sdConversation.persona) ?? .generalWellness
            )
    }

    func deleteConversation(_ id: UUID) async throws {
        print("🗑️ [ChatRepository] Deleting conversation (using Outbox): \(id)")

        // Get current user ID
        guard let userID = try? getCurrentUserId() else {
            print("⚠️ [ChatRepository] Cannot delete conversation - no authenticated user")
            throw ChatRepositoryError.notAuthenticated
        }

        // Create outbox event for backend deletion
        let metadata = OutboxMetadata.generic([
            "conversationId": id.uuidString,
            "operation": "delete",
        ])

        _ = try await outboxRepository.createEvent(
            eventType: .chatMessage,
            entityID: id,
            userID: userID.uuidString,
            isNewRecord: false,
            metadata: metadata,
            priority: 5
        )

        // Delete from local database immediately (optimistic delete)
        // First, delete all messages in the conversation
        let messageDescriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.conversationId == id }
        )
        let messages = try modelContext.fetch(messageDescriptor)
        for message in messages {
            modelContext.delete(message)
        }

        // Then delete the conversation
        let conversationDescriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdConversation = try modelContext.fetch(conversationDescriptor).first else {
            throw ChatRepositoryError.notFound
        }

        modelContext.delete(sdConversation)
        try modelContext.save()

        print("✅ [ChatRepository] Deleted locally: \(id)")
    }

    func countConversations() async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.userId == userId }
        )

        return try modelContext.fetchCount(descriptor)
    }

    func countActiveConversations() async throws -> Int {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId && !conversation.isArchived
            }
        )

        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Message Operations

    func addMessage(_ message: ChatMessage, to conversationId: UUID) async throws
        -> ChatConversation
    {
        // VALIDATE: Don't save empty messages
        guard !message.content.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("⚠️ [ChatRepository] Skipping empty message, content is blank")
            throw ChatRepositoryError.invalidMessage("Message content cannot be empty")
        }

        // VALIDATE: Don't save streaming messages (wait until complete)
        if message.metadata?.isStreaming == true {
            print("⏭️ [ChatRepository] Skipping streaming message, will persist when complete")
            // Return conversation without saving
            guard var conversation = try await fetchConversationById(conversationId) else {
                throw ChatRepositoryError.notFound
            }
            conversation.addMessage(message)
            return conversation
        }

        print("💾 [ChatRepository] Saving message with content length: \(message.content.count)")
        print("💾 [ChatRepository] Content preview: '\(message.content.prefix(100))'")

        // Verify conversation exists
        guard var conversation = try await fetchConversationById(conversationId) else {
            throw ChatRepositoryError.notFound
        }

        // Save message to SwiftData
        let sdMessage = toSwiftDataMessage(message)
        print("💾 [ChatRepository] SDMessage content length: \(sdMessage.content.count)")
        modelContext.insert(sdMessage)

        // Update conversation metadata
        let conversationDescriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        if let sdConversation = try modelContext.fetch(conversationDescriptor).first {
            sdConversation.messageCount += 1
            sdConversation.updatedAt = Date()

            // Auto-generate title from first user message if still default
            if sdConversation.title == "New Conversation" && message.role == .user {
                let words = message.content.components(separatedBy: .whitespaces).prefix(5)
                var newTitle = words.joined(separator: " ")
                if message.content.count > newTitle.count {
                    newTitle += "..."
                }
                sdConversation.title = newTitle
            }
        }

        try modelContext.save()

        // VERIFY: Fetch back to confirm content was saved
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.id == message.id }
        )
        if let verified = try? modelContext.fetch(descriptor).first {
            print("✅ [ChatRepository] Verified saved content: '\(verified.content.prefix(50))...'")
            guard !verified.content.isEmpty else {
                print("❌ [ChatRepository] ERROR: Saved message has empty content!")
                throw ChatRepositoryError.invalidMessage("Saved message is empty")
            }
        }

        // Return updated conversation with messages
        conversation.addMessage(message)
        return conversation
    }

    func fetchMessages(for conversationId: UUID) async throws -> [ChatMessage] {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\SDChatMessage.timestamp, order: .forward)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map(toDomainMessage)
    }

    func fetchRecentMessages(for conversationId: UUID, limit: Int) async throws -> [ChatMessage] {
        var descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.conversationId == conversationId },
            sortBy: [SortDescriptor(\SDChatMessage.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        return results.reversed().map(toDomainMessage)
    }

    func fetchMessageById(_ id: UUID) async throws -> ChatMessage? {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdMessage = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return toDomainMessage(sdMessage)
    }

    func deleteMessage(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.id == id }
        )

        guard let sdMessage = try modelContext.fetch(descriptor).first else {
            throw ChatRepositoryError.notFound
        }

        let conversationId = sdMessage.conversationId

        modelContext.delete(sdMessage)

        // Update conversation message count
        let conversationDescriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        if let sdConversation = try modelContext.fetch(conversationDescriptor).first {
            sdConversation.messageCount = max(0, sdConversation.messageCount - 1)
            sdConversation.updatedAt = Date()
        }

        try modelContext.save()
    }

    func clearMessages(for conversationId: UUID) async throws -> ChatConversation {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.conversationId == conversationId }
        )

        let messages = try modelContext.fetch(descriptor)

        for message in messages {
            modelContext.delete(message)
        }

        // Update conversation metadata
        let conversationDescriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        if let sdConversation = try modelContext.fetch(conversationDescriptor).first {
            sdConversation.messageCount = 0
            sdConversation.updatedAt = Date()
        }

        try modelContext.save()

        return try await fetchConversationById(conversationId)
            ?? ChatConversation(
                id: conversationId,
                userId: UUID(),
                title: "Unknown"
            )
    }

    func countMessages(for conversationId: UUID) async throws -> Int {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { $0.conversationId == conversationId }
        )

        return try modelContext.fetchCount(descriptor)
    }

    func countUserMessages(for conversationId: UUID) async throws -> Int {
        let descriptor = FetchDescriptor<SDChatMessage>(
            predicate: #Predicate { message in
                message.conversationId == conversationId && message.role == "user"
            }
        )

        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Batch Operations

    func saveMessages(_ messages: [ChatMessage], to conversationId: UUID) async throws
        -> ChatConversation
    {
        guard var conversation = try await fetchConversationById(conversationId) else {
            throw ChatRepositoryError.notFound
        }

        for message in messages {
            let sdMessage = toSwiftDataMessage(message)
            modelContext.insert(sdMessage)
            conversation.addMessage(message)
        }

        // Update conversation metadata
        let conversationDescriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        if let sdConversation = try modelContext.fetch(conversationDescriptor).first {
            sdConversation.messageCount += messages.count
            sdConversation.updatedAt = Date()
        }

        try modelContext.save()

        return conversation
    }

    func deleteConversations(_ ids: [UUID]) async throws {
        for id in ids {
            try await deleteConversation(id)
        }
    }

    // MARK: - Context Operations

    func updateConversationContext(
        _ conversationId: UUID,
        context: ConversationContext
    ) async throws -> ChatConversation {
        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        guard let sdConversation = try modelContext.fetch(descriptor).first else {
            throw ChatRepositoryError.notFound
        }

        // Encode context to data
        if let contextData = try? JSONEncoder().encode(context) {
            sdConversation.contextData = contextData
        }
        sdConversation.updatedAt = Date()

        try modelContext.save()

        return try await fetchConversationById(conversationId)
            ?? ChatConversation(
                id: conversationId,
                userId: sdConversation.userId,
                title: sdConversation.title,
                persona: ChatPersona(rawValue: sdConversation.persona) ?? .generalWellness
            )
    }

    func fetchConversationsRelatedToGoal(_ goalId: UUID) async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        _ = goalId.uuidString

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId
            },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            let conversation = toDomainConversation(sdConversation, messages: messages)

            // Check if context has this goal ID
            if let context = conversation.context,
                let relatedGoalIds = context.relatedGoalIds,
                relatedGoalIds.contains(goalId)
            {
                conversations.append(conversation)
            }
        }

        return conversations
    }

    func fetchConversationsRelatedToInsight(_ insightId: UUID) async throws -> [ChatConversation] {
        guard let userId = try? getCurrentUserId() else {
            throw ChatRepositoryError.notAuthenticated
        }

        _ = insightId.uuidString

        let descriptor = FetchDescriptor<SDChatConversation>(
            predicate: #Predicate { conversation in
                conversation.userId == userId
            },
            sortBy: [SortDescriptor(\SDChatConversation.updatedAt, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)

        var conversations: [ChatConversation] = []
        for sdConversation in results {
            let messages = try await fetchMessages(for: sdConversation.id)
            let conversation = toDomainConversation(sdConversation, messages: messages)

            // Check if context has this insight ID
            if let context = conversation.context,
                let relatedInsightIds = context.relatedInsightIds,
                relatedInsightIds.contains(insightId)
            {
                conversations.append(conversation)
            }
        }

        return conversations
    }
}

// MARK: - Domain <-> SwiftData Mapping

extension ChatRepository {
    // MARK: Conversation Mapping

    private func toSwiftDataConversation(_ conversation: ChatConversation) -> SDChatConversation {
        var contextData: Data? = nil
        if let context = conversation.context {
            contextData = try? JSONEncoder().encode(context)
        }

        return SDChatConversation(
            id: conversation.id,
            userId: conversation.userId,
            title: conversation.title,
            persona: conversation.persona.rawValue,
            messageCount: conversation.messages.count,
            isArchived: conversation.isArchived,
            contextData: contextData,
            hasContextForGoalSuggestions: conversation.hasContextForGoalSuggestions,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt
        )
    }

    private func toDomainConversation(
        _ sdConversation: SDChatConversation,
        messages: [ChatMessage]
    ) -> ChatConversation {
        var context: ConversationContext? = nil
        if let contextData = sdConversation.contextData {
            context = try? JSONDecoder().decode(ConversationContext.self, from: contextData)
        }

        // Use actual message count instead of stored count
        let actualMessageCount = messages.count

        print(
            "🔢 [ChatRepository] Message count - stored: \(sdConversation.messageCount), actual: \(actualMessageCount)"
        )

        return ChatConversation(
            id: sdConversation.id,
            userId: sdConversation.userId,
            title: sdConversation.title,
            persona: ChatPersona(rawValue: sdConversation.persona) ?? .generalWellness,
            messages: messages,
            createdAt: sdConversation.createdAt,
            updatedAt: sdConversation.updatedAt,
            isArchived: sdConversation.isArchived,
            context: context,
            hasContextForGoalSuggestions: sdConversation.hasContextForGoalSuggestions
        )
    }

    private func updateSDConversation(
        _ sdConversation: SDChatConversation,
        from conversation: ChatConversation
    ) {
        sdConversation.title = conversation.title
        sdConversation.persona = conversation.persona.rawValue
        sdConversation.isArchived = conversation.isArchived
        sdConversation.hasContextForGoalSuggestions = conversation.hasContextForGoalSuggestions

        if let context = conversation.context {
            sdConversation.contextData = try? JSONEncoder().encode(context)
        } else {
            sdConversation.contextData = nil
        }
    }

    // MARK: Message Mapping

    private func toSwiftDataMessage(_ message: ChatMessage) -> SDChatMessage {
        var metadataData: Data? = nil
        if let metadata = message.metadata {
            metadataData = try? JSONEncoder().encode(metadata)
        }

        return SDChatMessage(
            id: message.id,
            conversationId: message.conversationId,
            role: message.role.rawValue,
            content: message.content,
            timestamp: message.timestamp,
            metadata: metadataData
        )
    }

    private func toDomainMessage(_ sdMessage: SDChatMessage) -> ChatMessage {
        var metadata: MessageMetadata? = nil
        if let metadataData = sdMessage.metadata {
            metadata = try? JSONDecoder().decode(MessageMetadata.self, from: metadataData)
        }

        return ChatMessage(
            id: sdMessage.id,
            conversationId: sdMessage.conversationId,
            role: MessageRole(rawValue: sdMessage.role) ?? .user,
            content: sdMessage.content,
            timestamp: sdMessage.timestamp,
            metadata: metadata
        )
    }

    // getCurrentUserId() is provided by UserAuthenticatedRepository protocol
}

// MARK: - Repository Errors

enum ChatRepositoryError: Error, LocalizedError {
    case notAuthenticated
    case notFound
    case invalidMessage(String)
    case validationFailed(String)
    case persistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated."
        case .notFound:
            return "Resource not found."
        case .invalidMessage(let message):
            return "Invalid message: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .persistenceFailed(let error):
            return "Persistence failed: \(error.localizedDescription)"
        }
    }
}
