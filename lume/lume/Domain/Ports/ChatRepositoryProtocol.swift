//
//  ChatRepositoryProtocol.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Port for chat persistence operations
/// Implementation must be provided by the infrastructure layer
protocol ChatRepositoryProtocol {
    // MARK: - Conversation Operations

    /// Create a new conversation
    /// - Parameters:
    ///   - title: The conversation title
    ///   - persona: The AI persona for this conversation
    ///   - context: Optional context information
    /// - Returns: The created ChatConversation
    /// - Throws: Repository error if creation fails
    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?
    ) async throws -> ChatConversation

    /// Update an existing conversation
    /// - Parameter conversation: The conversation to update
    /// - Returns: The updated ChatConversation
    /// - Throws: Repository error if update fails
    func updateConversation(_ conversation: ChatConversation) async throws -> ChatConversation

    /// Fetch all conversations for the current user
    /// - Returns: Array of ChatConversation objects
    /// - Throws: Repository error if fetch fails
    func fetchAllConversations() async throws -> [ChatConversation]

    /// Fetch active (non-archived) conversations
    /// - Returns: Array of active ChatConversation objects
    /// - Throws: Repository error if fetch fails
    func fetchActiveConversations() async throws -> [ChatConversation]

    /// Fetch archived conversations
    /// - Returns: Array of archived ChatConversation objects
    /// - Throws: Repository error if fetch fails
    func fetchArchivedConversations() async throws -> [ChatConversation]

    /// Fetch conversations by persona
    /// - Parameter persona: The persona to filter by
    /// - Returns: Array of ChatConversation objects with the specified persona
    /// - Throws: Repository error if fetch fails
    func fetchConversationsByPersona(_ persona: ChatPersona) async throws -> [ChatConversation]

    /// Fetch a specific conversation by ID
    /// - Parameter id: The UUID of the conversation
    /// - Returns: The ChatConversation if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchConversationById(_ id: UUID) async throws -> ChatConversation?

    /// Search conversations by title
    /// - Parameter query: The search query
    /// - Returns: Array of matching ChatConversation objects
    /// - Throws: Repository error if search fails
    func searchConversations(query: String) async throws -> [ChatConversation]

    /// Archive a conversation
    /// - Parameter id: The UUID of the conversation to archive
    /// - Returns: The archived ChatConversation
    /// - Throws: Repository error if archive fails
    func archiveConversation(_ id: UUID) async throws -> ChatConversation

    /// Unarchive a conversation
    /// - Parameter id: The UUID of the conversation to unarchive
    /// - Returns: The unarchived ChatConversation
    /// - Throws: Repository error if unarchive fails
    func unarchiveConversation(_ id: UUID) async throws -> ChatConversation

    /// Delete a conversation and all its messages
    /// - Parameter id: The UUID of the conversation to delete
    /// - Throws: Repository error if delete fails
    func deleteConversation(_ id: UUID) async throws

    /// Get total count of conversations
    /// - Returns: The total number of conversations
    /// - Throws: Repository error if count fails
    func countConversations() async throws -> Int

    /// Get count of active conversations
    /// - Returns: The number of active conversations
    /// - Throws: Repository error if count fails
    func countActiveConversations() async throws -> Int

    // MARK: - Message Operations

    /// Add a message to a conversation
    /// - Parameters:
    ///   - message: The message to add
    ///   - conversationId: The UUID of the conversation
    /// - Returns: The updated ChatConversation
    /// - Throws: Repository error if add fails
    func addMessage(
        _ message: ChatMessage,
        to conversationId: UUID
    ) async throws -> ChatConversation

    /// Fetch all messages for a conversation
    /// - Parameter conversationId: The UUID of the conversation
    /// - Returns: Array of ChatMessage objects
    /// - Throws: Repository error if fetch fails
    func fetchMessages(for conversationId: UUID) async throws -> [ChatMessage]

    /// Fetch recent messages for a conversation
    /// - Parameters:
    ///   - conversationId: The UUID of the conversation
    ///   - limit: Maximum number of messages to fetch
    /// - Returns: Array of recent ChatMessage objects
    /// - Throws: Repository error if fetch fails
    func fetchRecentMessages(
        for conversationId: UUID,
        limit: Int
    ) async throws -> [ChatMessage]

    /// Fetch a specific message by ID
    /// - Parameter id: The UUID of the message
    /// - Returns: The ChatMessage if found, nil otherwise
    /// - Throws: Repository error if fetch fails
    func fetchMessageById(_ id: UUID) async throws -> ChatMessage?

    /// Delete a message
    /// - Parameter id: The UUID of the message to delete
    /// - Throws: Repository error if delete fails
    func deleteMessage(_ id: UUID) async throws

    /// Clear all messages from a conversation
    /// - Parameter conversationId: The UUID of the conversation
    /// - Returns: The updated ChatConversation with no messages
    /// - Throws: Repository error if clear fails
    func clearMessages(for conversationId: UUID) async throws -> ChatConversation

    /// Get total count of messages in a conversation
    /// - Parameter conversationId: The UUID of the conversation
    /// - Returns: The total number of messages
    /// - Throws: Repository error if count fails
    func countMessages(for conversationId: UUID) async throws -> Int

    /// Get count of user messages in a conversation
    /// - Parameter conversationId: The UUID of the conversation
    /// - Returns: The number of user messages
    /// - Throws: Repository error if count fails
    func countUserMessages(for conversationId: UUID) async throws -> Int

    // MARK: - Batch Operations

    /// Save multiple messages at once
    /// - Parameters:
    ///   - messages: Array of messages to save
    ///   - conversationId: The UUID of the conversation
    /// - Returns: The updated ChatConversation
    /// - Throws: Repository error if save fails
    func saveMessages(
        _ messages: [ChatMessage],
        to conversationId: UUID
    ) async throws -> ChatConversation

    /// Delete multiple conversations
    /// - Parameter ids: Array of conversation UUIDs to delete
    /// - Throws: Repository error if delete fails
    func deleteConversations(_ ids: [UUID]) async throws

    // MARK: - Context Operations

    /// Update conversation context
    /// - Parameters:
    ///   - conversationId: The UUID of the conversation
    ///   - context: The new context information
    /// - Returns: The updated ChatConversation
    /// - Throws: Repository error if update fails
    func updateConversationContext(
        _ conversationId: UUID,
        context: ConversationContext
    ) async throws -> ChatConversation

    /// Fetch conversations with related goals
    /// - Parameter goalId: The UUID of the goal
    /// - Returns: Array of conversations related to the goal
    /// - Throws: Repository error if fetch fails
    func fetchConversationsRelatedToGoal(_ goalId: UUID) async throws -> [ChatConversation]

    /// Fetch conversations with related insights
    /// - Parameter insightId: The UUID of the insight
    /// - Returns: Array of conversations related to the insight
    /// - Throws: Repository error if fetch fails
    func fetchConversationsRelatedToInsight(_ insightId: UUID) async throws -> [ChatConversation]
}
