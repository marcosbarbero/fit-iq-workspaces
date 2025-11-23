//
//  SendChatMessageUseCase.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//  Refactored: Real-time communication for chat (no Outbox pattern)
//

import Foundation

/// Protocol for sending chat messages use case
protocol SendChatMessageUseCaseProtocol {
    /// Send a message in a chat conversation
    /// - Parameters:
    ///   - conversationId: The UUID of the conversation
    ///   - content: The message content
    ///   - useStreaming: Whether to use WebSocket streaming
    /// - Returns: The sent ChatMessage (user message)
    /// - Throws: Use case error if sending fails
    func execute(
        conversationId: UUID,
        content: String,
        useStreaming: Bool
    ) async throws -> ChatMessage
}

/// Use case for sending chat messages
/// Uses direct real-time communication for immediate UX
final class SendChatMessageUseCase: SendChatMessageUseCaseProtocol {
    private let chatRepository: ChatRepositoryProtocol
    private let chatService: ChatServiceProtocol

    init(
        chatRepository: ChatRepositoryProtocol,
        chatService: ChatServiceProtocol
    ) {
        self.chatRepository = chatRepository
        self.chatService = chatService
    }

    func execute(
        conversationId: UUID,
        content: String,
        useStreaming: Bool = false
    ) async throws -> ChatMessage {
        // Validate input
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SendChatMessageError.emptyMessage
        }

        guard content.count <= ChatMessage.maxContentLength else {
            throw SendChatMessageError.messageTooLong
        }

        // Verify conversation exists
        guard try await chatRepository.fetchConversationById(conversationId) != nil else {
            throw SendChatMessageError.conversationNotFound
        }

        // Create user message
        let userMessage = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: content,
            timestamp: Date(),
            metadata: nil
        )

        // Save user message locally first (optimistic update)
        _ = try await chatRepository.addMessage(userMessage, to: conversationId)

        // Send to backend immediately for real-time experience
        if useStreaming && chatService.isWebSocketConnected {
            // Use WebSocket streaming for real-time response
            try await sendViaWebSocket(
                conversationId: conversationId,
                userMessage: userMessage,
                content: content
            )
        } else {
            // Use REST API with immediate response
            try await sendViaREST(
                conversationId: conversationId,
                userMessage: userMessage,
                content: content
            )
        }

        return userMessage
    }
}

// MARK: - Private Helpers

extension SendChatMessageUseCase {
    /// Send message via WebSocket streaming for real-time response
    fileprivate func sendViaWebSocket(
        conversationId: UUID,
        userMessage: ChatMessage,
        content: String
    ) async throws {
        // Send message and receive streaming response
        try await chatService.sendMessageStreaming(
            conversationId: conversationId,
            content: content,
            onChunk: { chunk in
                // Chunks are handled by the ViewModel for real-time UI updates
                // Repository doesn't need to do anything here
            },
            onComplete: { assistantMessage in
                // Save complete assistant message when streaming finishes
                Task {
                    do {
                        _ = try await self.chatRepository.addMessage(
                            assistantMessage,
                            to: conversationId
                        )
                    } catch {
                        print(
                            "⚠️ [SendChatMessageUseCase] Failed to save assistant message: \(error)"
                        )
                    }
                }
            }
        )
    }

    /// Send message via REST API with immediate response
    fileprivate func sendViaREST(
        conversationId: UUID,
        userMessage: ChatMessage,
        content: String
    ) async throws {
        do {
            // Send message and get immediate response
            let assistantMessage = try await chatService.sendMessage(
                conversationId: conversationId,
                content: content,
                role: .user
            )

            // Save assistant response locally
            _ = try await chatRepository.addMessage(
                assistantMessage,
                to: conversationId
            )

        } catch {
            // Delete the optimistically saved user message on failure
            // so the user can retry
            try? await chatRepository.deleteMessage(userMessage.id)
            throw error
        }
    }
}

// MARK: - Convenience Methods

extension SendChatMessageUseCase {
    /// Send a message using default settings (REST API)
    func send(conversationId: UUID, content: String) async throws -> ChatMessage {
        try await execute(conversationId: conversationId, content: content, useStreaming: false)
    }

    /// Send a message with streaming enabled for real-time response
    func sendStreaming(conversationId: UUID, content: String) async throws -> ChatMessage {
        try await execute(conversationId: conversationId, content: content, useStreaming: true)
    }
}

// MARK: - Errors

/// Errors specific to SendChatMessageUseCase
enum SendChatMessageError: Error, LocalizedError {
    case emptyMessage
    case conversationNotFound
    case messageTooLong
    case rateLimitExceeded
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Cannot send an empty message."
        case .conversationNotFound:
            return "Conversation not found. Please start a new conversation."
        case .messageTooLong:
            return "Message is too long. Please shorten your message."
        case .rateLimitExceeded:
            return "You're sending messages too quickly. Please wait a moment."
        case .serviceUnavailable:
            return "Chat service is temporarily unavailable. Please try again."
        }
    }
}
