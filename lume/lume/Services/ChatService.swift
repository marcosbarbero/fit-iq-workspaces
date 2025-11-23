//
//  ChatService.swift
//  lume
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation
import FitIQCore

/// Service implementation that wraps ChatBackendService and handles token management
/// Implements ChatServiceProtocol for domain layer while managing infrastructure concerns
final class ChatService: ChatServiceProtocol {
    private let backendService: ChatBackendServiceProtocol
    private let tokenStorage: TokenStorageProtocol

    init(
        backendService: ChatBackendServiceProtocol,
        tokenStorage: TokenStorageProtocol
    ) {
        self.backendService = backendService
        self.tokenStorage = tokenStorage
    }

    // MARK: - Conversation Operations

    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?
    ) async throws -> ChatConversation {
        let token = try await getAccessToken()
        return try await backendService.createConversation(
            title: title,
            persona: persona,
            context: context,
            accessToken: token
        )
    }

    func fetchConversations(
        status: String? = nil,
        persona: ChatPersona? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        let token = try await getAccessToken()
        return try await backendService.fetchAllConversations(
            status: status,
            persona: persona,
            limit: limit,
            offset: offset,
            accessToken: token
        )
    }

    func fetchConversation(id: UUID) async throws -> ChatConversation {
        let token = try await getAccessToken()
        return try await backendService.fetchConversation(
            conversationId: id,
            accessToken: token
        )
    }

    func deleteConversation(id: UUID) async throws {
        let token = try await getAccessToken()
        try await backendService.deleteConversation(
            conversationId: id,
            accessToken: token
        )
    }

    // MARK: - Message Operations (REST)

    func sendMessage(
        conversationId: UUID,
        content: String,
        role: MessageRole
    ) async throws -> ChatMessage {
        let token = try await getAccessToken()
        return try await backendService.sendMessage(
            message: content,
            conversationId: conversationId,
            accessToken: token
        )
    }

    func fetchMessages(for conversationId: UUID) async throws -> [ChatMessage] {
        let token = try await getAccessToken()
        return try await backendService.fetchMessages(
            conversationId: conversationId,
            limit: 100,
            offset: 0,
            accessToken: token
        )
    }

    // MARK: - WebSocket Streaming

    func connectWebSocket(
        conversationId: UUID,
        onMessage: @escaping (ChatMessage) -> Void,
        onError: @escaping (Error) -> Void,
        onDisconnect: @escaping () -> Void
    ) async throws {
        let token = try await getAccessToken()

        // Set up handlers for backend service
        backendService.setMessageHandler(onMessage)
        backendService.setConnectionStatusHandler { status in
            switch status {
            case .disconnected:
                onDisconnect()
            case .error(let error):
                onError(error)
            default:
                break
            }
        }

        try await backendService.connectWebSocket(
            conversationId: conversationId,
            accessToken: token
        )
    }

    func sendMessageStreaming(
        conversationId: UUID,
        content: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping (ChatMessage) -> Void
    ) async throws {
        // Set up message handler to capture the complete message
        backendService.setMessageHandler { message in
            onComplete(message)
        }

        // Send message via WebSocket
        try await backendService.sendMessageViaWebSocket(
            message: content,
            conversationId: conversationId
        )

        // Note: WebSocket streaming with chunks would require backend support
        // For now, we get the complete message via the message handler
    }

    func disconnectWebSocket() {
        backendService.disconnectWebSocket()
    }

    var isWebSocketConnected: Bool {
        // The backend service tracks connection internally
        // We return false as a default since the actual status is managed via callbacks
        // The UI should rely on connection status callbacks rather than polling this property
        return false
    }

    // MARK: - Connection Management

    func reconnectWebSocket(conversationId: UUID) async throws {
        let token = try await getAccessToken()
        // Disconnect and reconnect
        backendService.disconnectWebSocket()
        try await backendService.connectWebSocket(
            conversationId: conversationId,
            accessToken: token
        )
    }

    func getConnectionStatus() -> ConnectionStatus {
        // Map WebSocketConnectionStatus to ConnectionStatus
        // Since backend doesn't expose status directly, return based on connection state
        return .disconnected  // This should be tracked internally
    }

    // MARK: - Private Helpers

    private func getAccessToken() async throws -> String {
        guard let token = try await tokenStorage.getToken() else {
            throw ChatServiceError.unauthorized
        }
        return token.accessToken
    }
}

// MARK: - Mock Implementation

/// Mock chat service for development and testing
final class MockChatService: ChatServiceProtocol {

    private var conversations: [ChatConversation] = []
    private var messagesByConversation: [UUID: [ChatMessage]] = [:]
    private var isConnected = false
    private var connectionStatus: ConnectionStatus = .disconnected

    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?
    ) async throws -> ChatConversation {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        let conversation = ChatConversation(
            id: UUID(),
            userId: UUID(),
            title: title,
            persona: persona,
            messages: [],
            createdAt: Date(),
            updatedAt: Date(),
            isArchived: false,
            context: context
        )

        conversations.append(conversation)
        messagesByConversation[conversation.id] = []

        return conversation
    }

    func fetchConversations(
        status: String? = nil,
        persona: ChatPersona? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatConversation] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds

        var filtered = conversations

        // Filter by status
        if let status = status {
            filtered = filtered.filter { conversation in
                if status == "archived" {
                    return conversation.isArchived
                } else if status == "active" {
                    return !conversation.isArchived
                }
                return true
            }
        }

        // Filter by persona
        if let persona = persona {
            filtered = filtered.filter { $0.persona == persona }
        }

        // Sort and paginate
        let sorted = filtered.sorted { $0.updatedAt > $1.updatedAt }
        let startIndex = min(offset, sorted.count)
        let endIndex = min(startIndex + limit, sorted.count)

        return Array(sorted[startIndex..<endIndex])
    }

    func fetchConversation(id: UUID) async throws -> ChatConversation {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

        guard let conversation = conversations.first(where: { $0.id == id }) else {
            throw ChatServiceError.conversationNotFound
        }

        return conversation
    }

    func deleteConversation(id: UUID) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

        conversations.removeAll { $0.id == id }
        messagesByConversation.removeValue(forKey: id)
    }

    func sendMessage(
        conversationId: UUID,
        content: String,
        role: MessageRole
    ) async throws -> ChatMessage {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Create user message
        let userMessage = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: role,
            content: content,
            timestamp: Date(),
            metadata: nil
        )

        // Add to message history
        if messagesByConversation[conversationId] == nil {
            messagesByConversation[conversationId] = []
        }
        messagesByConversation[conversationId]?.append(userMessage)

        // Simulate AI response
        try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds

        let aiResponse = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .assistant,
            content: "This is a mock response to: \(content)",
            timestamp: Date(),
            metadata: nil
        )

        messagesByConversation[conversationId]?.append(aiResponse)

        // Update conversation
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            var updated = conversations[index]
            updated.updatedAt = Date()
            // Add messages to conversation
            if let messages = messagesByConversation[conversationId] {
                updated.messages = messages
            }
            conversations[index] = updated
        }

        return aiResponse
    }

    func fetchMessages(for conversationId: UUID) async throws -> [ChatMessage] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
        return messagesByConversation[conversationId] ?? []
    }

    func connectWebSocket(
        conversationId: UUID,
        onMessage: @escaping (ChatMessage) -> Void,
        onError: @escaping (Error) -> Void,
        onDisconnect: @escaping () -> Void
    ) async throws {
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        isConnected = true
        connectionStatus = .connected
        print("📱 [MockChatService] WebSocket connected for conversation: \(conversationId)")
    }

    func sendMessageStreaming(
        conversationId: UUID,
        content: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping (ChatMessage) -> Void
    ) async throws {
        guard isConnected else {
            throw ChatServiceError.webSocketNotConnected
        }

        // Simulate streaming response
        let response = "This is a mock streaming response to: \(content)"
        let words = response.split(separator: " ")

        for word in words {
            onChunk(String(word) + " ")
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds per word
        }

        // Create final message
        let message = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .assistant,
            content: response,
            timestamp: Date(),
            metadata: nil
        )

        onComplete(message)
    }

    func disconnectWebSocket() {
        isConnected = false
        connectionStatus = .disconnected
        print("📱 [MockChatService] WebSocket disconnected")
    }

    var isWebSocketConnected: Bool {
        isConnected
    }

    func reconnectWebSocket(conversationId: UUID) async throws {
        connectionStatus = .reconnecting
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
        isConnected = true
        connectionStatus = .connected
        print("📱 [MockChatService] WebSocket reconnected for conversation: \(conversationId)")
    }

    func getConnectionStatus() -> ConnectionStatus {
        connectionStatus
    }
}
