//
//  ChatServiceProtocol.swift
//  lume
//
//  Created by AI Assistant on 28/01/2025.
//

import Foundation

/// Port for chat backend service operations
/// Implementation must be provided by the infrastructure layer
protocol ChatServiceProtocol {
    // MARK: - Conversation Operations

    /// Create a new conversation on the backend
    /// - Parameters:
    ///   - title: The conversation title
    ///   - persona: The AI persona for this conversation
    ///   - context: Optional context information
    /// - Returns: The created ChatConversation with backend ID
    /// - Throws: Service error if creation fails
    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?
    ) async throws -> ChatConversation

    /// Fetch all conversations from backend with optional filtering
    /// - Parameters:
    ///   - status: Optional status filter (active, completed, abandoned, archived)
    ///   - persona: Optional persona filter
    ///   - limit: Number of results to return (1-100, default: 20)
    ///   - offset: Pagination offset (default: 0)
    /// - Returns: Array of ChatConversation objects
    /// - Throws: Service error if fetch fails
    func fetchConversations(
        status: String?,
        persona: ChatPersona?,
        limit: Int,
        offset: Int
    ) async throws -> [ChatConversation]

    /// Fetch a specific conversation from backend
    /// - Parameter id: The UUID of the conversation
    /// - Returns: The ChatConversation if found
    /// - Throws: Service error if fetch fails
    func fetchConversation(id: UUID) async throws -> ChatConversation

    /// Delete a conversation from backend
    /// - Parameter id: The UUID of the conversation to delete
    /// - Throws: Service error if delete fails
    func deleteConversation(id: UUID) async throws

    // MARK: - Message Operations (REST)

    /// Send a message via REST API (uses Outbox pattern)
    /// - Parameters:
    ///   - conversationId: The UUID of the conversation
    ///   - content: The message content
    ///   - role: The message role (user or assistant)
    /// - Returns: The response ChatMessage from AI
    /// - Throws: Service error if send fails
    func sendMessage(
        conversationId: UUID,
        content: String,
        role: MessageRole
    ) async throws -> ChatMessage

    /// Fetch messages for a conversation from backend
    /// - Parameter conversationId: The UUID of the conversation
    /// - Returns: Array of ChatMessage objects
    /// - Throws: Service error if fetch fails
    func fetchMessages(for conversationId: UUID) async throws -> [ChatMessage]

    // MARK: - WebSocket Streaming

    /// Connect to WebSocket stream for real-time chat
    /// - Parameters:
    ///   - conversationId: The UUID of the conversation
    ///   - onMessage: Callback for received messages
    ///   - onError: Callback for errors
    ///   - onDisconnect: Callback for disconnection
    /// - Throws: Service error if connection fails
    func connectWebSocket(
        conversationId: UUID,
        onMessage: @escaping (ChatMessage) -> Void,
        onError: @escaping (Error) -> Void,
        onDisconnect: @escaping () -> Void
    ) async throws

    /// Send a message via WebSocket for streaming response
    /// - Parameters:
    ///   - conversationId: The UUID of the conversation
    ///   - content: The message content
    ///   - onChunk: Callback for each response chunk
    ///   - onComplete: Callback when response is complete
    /// - Throws: Service error if send fails
    func sendMessageStreaming(
        conversationId: UUID,
        content: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping (ChatMessage) -> Void
    ) async throws

    /// Disconnect WebSocket connection
    func disconnectWebSocket()

    /// Check if WebSocket is currently connected
    var isWebSocketConnected: Bool { get }

    // MARK: - Connection Management

    /// Reconnect to WebSocket with exponential backoff
    /// - Parameter conversationId: The UUID of the conversation
    /// - Throws: Service error if reconnection fails
    func reconnectWebSocket(conversationId: UUID) async throws

    /// Get current connection status
    /// - Returns: Connection status string
    func getConnectionStatus() -> ConnectionStatus
}

/// WebSocket connection status
enum ConnectionStatus: String, Codable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"

    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting..."
        case .failed:
            return "Connection Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .disconnected:
            return "circle"
        case .connecting, .reconnecting:
            return "circle.dotted"
        case .connected:
            return "circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .disconnected:
            return "textSecondary"
        case .connecting, .reconnecting:
            return "moodNeutral"
        case .connected:
            return "moodPositive"
        case .failed:
            return "moodLow"
        }
    }
}

/// Chat service specific errors
enum ChatServiceError: Error, LocalizedError {
    case invalidResponse
    case connectionFailed
    case webSocketNotConnected
    case messageDecodingFailed
    case unauthorized
    case conversationNotFound
    case rateLimitExceeded
    case networkError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .connectionFailed:
            return "Failed to connect to chat service"
        case .webSocketNotConnected:
            return "WebSocket connection is not established"
        case .messageDecodingFailed:
            return "Failed to decode message"
        case .unauthorized:
            return "Unauthorized. Please log in again."
        case .conversationNotFound:
            return "Conversation not found"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later."
        case .networkError:
            return "Network error. Please check your connection."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
