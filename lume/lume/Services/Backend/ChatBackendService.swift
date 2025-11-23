//
//  ChatBackendService.swift
//  lume
//
//  Created by AI Assistant on 29/01/2025.
//

import Foundation

/// Backend service for AI chat with REST and WebSocket support
/// Handles communication with chat API endpoints and real-time messaging
protocol ChatBackendServiceProtocol {
    // MARK: - Conversation Operations

    /// Create a new conversation
    /// - Parameters:
    ///   - title: The conversation title
    ///   - persona: The AI persona for this conversation
    ///   - context: Optional context information
    ///   - accessToken: User's access token
    /// - Returns: The created ChatConversation
    /// - Throws: HTTPError if request fails
    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?,
        accessToken: String
    ) async throws -> ChatConversation

    /// Update a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation to update
    ///   - title: New title
    ///   - persona: New persona
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func updateConversation(
        conversationId: UUID,
        title: String?,
        persona: ChatPersona?,
        accessToken: String
    ) async throws

    /// Fetch all conversations with optional filtering
    /// - Parameters:
    ///   - status: Optional status filter (active, completed, abandoned, archived)
    ///   - persona: Optional persona filter
    ///   - limit: Number of results to return (1-100, default: 20)
    ///   - offset: Pagination offset (default: 0)
    ///   - accessToken: User's access token
    /// - Returns: Array of ChatConversation objects
    /// - Throws: HTTPError if request fails
    func fetchAllConversations(
        status: String?,
        persona: ChatPersona?,
        limit: Int,
        offset: Int,
        accessToken: String
    ) async throws -> [ChatConversation]

    /// Fetch a specific conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - accessToken: User's access token
    /// - Returns: The ChatConversation if found
    /// - Throws: HTTPError if request fails or conversation not found
    func fetchConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws -> ChatConversation

    /// Delete a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation to delete
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func deleteConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws

    /// Archive a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation to archive
    ///   - accessToken: User's access token
    /// - Throws: HTTPError if request fails
    func archiveConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws

    // MARK: - Message Operations

    /// Send a message in a conversation
    /// - Parameters:
    ///   - message: The message content
    ///   - conversationId: The ID of the conversation
    ///   - accessToken: User's access token
    /// - Returns: The created ChatMessage
    /// - Throws: HTTPError if request fails
    func sendMessage(
        message: String,
        conversationId: UUID,
        accessToken: String
    ) async throws -> ChatMessage

    /// Fetch messages for a conversation
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - limit: Maximum number of messages to fetch
    ///   - offset: Offset for pagination
    ///   - accessToken: User's access token
    /// - Returns: Array of ChatMessage objects
    /// - Throws: HTTPError if request fails
    func fetchMessages(
        conversationId: UUID,
        limit: Int,
        offset: Int,
        accessToken: String
    ) async throws -> [ChatMessage]

    // MARK: - WebSocket Operations

    /// Connect to WebSocket for real-time messaging
    /// - Parameters:
    ///   - conversationId: The ID of the conversation
    ///   - accessToken: User's access token
    /// - Throws: WebSocketError if connection fails
    func connectWebSocket(
        conversationId: UUID,
        accessToken: String
    ) async throws

    /// Disconnect from WebSocket
    func disconnectWebSocket()

    /// Send a message via WebSocket
    /// - Parameters:
    ///   - message: The message content
    ///   - conversationId: The ID of the conversation
    /// - Throws: WebSocketError if send fails
    func sendMessageViaWebSocket(
        message: String,
        conversationId: UUID
    ) async throws

    /// Set the WebSocket message handler
    /// - Parameter handler: Closure to handle incoming messages
    func setMessageHandler(_ handler: @escaping (ChatMessage) -> Void)

    /// Set the WebSocket connection status handler
    /// - Parameter handler: Closure to handle connection status changes
    func setConnectionStatusHandler(_ handler: @escaping (WebSocketConnectionStatus) -> Void)
}

/// WebSocket connection status
enum WebSocketConnectionStatus {
    case connecting
    case connected
    case disconnected
    case error(Error)
}

/// WebSocket error types
enum WebSocketError: LocalizedError {
    case notConnected
    case connectionFailed
    case sendFailed
    case invalidMessage
    case unauthorized
    case messageDecodingFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .connectionFailed:
            return "Failed to connect to WebSocket"
        case .sendFailed:
            return "Failed to send message via WebSocket"
        case .invalidMessage:
            return "Invalid message format"
        case .unauthorized:
            return "Unauthorized WebSocket connection"
        case .messageDecodingFailed:
            return "Failed to decode WebSocket message"
        }
    }
}

class ChatBackendService: NSObject, ChatBackendServiceProtocol {
    // MARK: - Properties

    private let httpClient: HTTPClient
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageHandler: ((ChatMessage) -> Void)?
    private var connectionStatusHandler: ((WebSocketConnectionStatus) -> Void)?
    private var isConnected = false

    // Streaming state
    private var currentStreamingMessage: ChatMessage?
    private var currentStreamingContent: String = ""

    // MARK: - Initialization

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
        super.init()
    }

    deinit {
        disconnectWebSocket()
    }

    // MARK: - Conversation Operations

    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?,
        accessToken: String
    ) async throws -> ChatConversation {
        let request = CreateConversationRequest(
            persona: persona.rawValue,
            context: context,
            initialMessage: nil
        )

        let response: CreateConversationResponse = try await httpClient.post(
            path: "/api/v1/consultations",
            body: request,
            accessToken: accessToken
        )

        print("✅ [ChatBackendService] Created conversation: \(response.data.consultation.id)")
        return response.data.consultation.toDomain()
    }

    func updateConversation(
        conversationId: UUID,
        title: String?,
        persona: ChatPersona?,
        accessToken: String
    ) async throws {
        let request = UpdateConversationRequest(
            title: title,
            persona: persona?.rawValue
        )

        let _: ConversationResponse = try await httpClient.put(
            path: "/api/v1/consultations/\(conversationId.uuidString)",
            body: request,
            accessToken: accessToken
        )

        print("✅ [ChatBackendService] Updated conversation: \(conversationId)")
    }

    func fetchAllConversations(
        status: String? = nil,
        persona: ChatPersona? = nil,
        limit: Int = 20,
        offset: Int = 0,
        accessToken: String
    ) async throws -> [ChatConversation] {
        var queryParams: [String: String] = [
            "limit": String(limit),
            "offset": String(offset),
        ]

        if let status = status {
            queryParams["status"] = status
        }

        if let persona = persona {
            queryParams["persona"] = persona.rawValue
        }

        let response: ConversationsListResponse = try await httpClient.get(
            path: "/api/v1/consultations",
            queryParams: queryParams,
            accessToken: accessToken
        )

        print(
            "✅ [ChatBackendService] Fetched \(response.data.consultations.count) conversations (total: \(response.data.total_count), limit: \(limit), offset: \(offset))"
        )
        return response.data.consultations.map { $0.toDomain() }
    }

    func fetchConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws -> ChatConversation {
        let response: ConversationResponse = try await httpClient.get(
            path: "/api/v1/consultations/\(conversationId.uuidString)",
            accessToken: accessToken
        )

        print("✅ [ChatBackendService] Fetched conversation: \(conversationId)")
        return response.data.toDomain()
    }

    func deleteConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws {
        do {
            try await httpClient.delete(
                path: "/api/v1/consultations/\(conversationId.uuidString)",
                accessToken: accessToken
            )
            print("✅ [ChatBackendService] Deleted conversation: \(conversationId)")
        } catch HTTPError.notFound {
            // 404 is acceptable for deletion - conversation already doesn't exist
            // This makes deletion idempotent
            print("✅ [ChatBackendService] Conversation already deleted (404): \(conversationId)")
        }
    }

    func archiveConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws {
        let request = UpdateConversationRequest(isArchived: true)

        let _: ConversationResponse = try await httpClient.put(
            path: "/api/v1/consultations/\(conversationId.uuidString)",
            body: request,
            accessToken: accessToken
        )

        print("✅ [ChatBackendService] Archived conversation: \(conversationId)")
    }

    // MARK: - Message Operations

    func sendMessage(
        message: String,
        conversationId: UUID,
        accessToken: String
    ) async throws -> ChatMessage {
        let request = SendMessageRequest(content: message)

        let response: MessageResponse = try await httpClient.post(
            path: "/api/v1/consultations/\(conversationId.uuidString)/messages",
            body: request,
            accessToken: accessToken
        )

        print("✅ [ChatBackendService] Sent message in conversation: \(conversationId)")
        return response.data.user_message.toDomain(conversationId: conversationId)
    }

    func fetchMessages(
        conversationId: UUID,
        limit: Int = 50,
        offset: Int = 0,
        accessToken: String
    ) async throws -> [ChatMessage] {
        let response: MessagesListResponse = try await httpClient.get(
            path: "/api/v1/consultations/\(conversationId.uuidString)/messages",
            queryParams: [
                "limit": String(limit),
                "offset": String(offset),
            ],
            accessToken: accessToken
        )

        print(
            "✅ [ChatBackendService] Fetched \(response.data.messages.count) messages for conversation: \(conversationId)"
        )
        return response.data.messages.map { $0.toDomain(conversationId: conversationId) }
    }

    // MARK: - WebSocket Operations

    func connectWebSocket(
        conversationId: UUID,
        accessToken: String
    ) async throws {
        guard !isConnected else {
            print("⚠️ [ChatBackendService] Already connected to WebSocket")
            return
        }

        connectionStatusHandler?(.connecting)

        // Construct WebSocket URL
        guard let baseWSURL = AppConfiguration.shared.webSocketURL else {
            throw WebSocketError.connectionFailed
        }

        let wsURL =
            baseWSURL
            .appendingPathComponent("/api/v1/consultations")
            .appendingPathComponent(conversationId.uuidString)
            .appendingPathComponent("ws")

        // Create WebSocket request
        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConfiguration.shared.apiKey, forHTTPHeaderField: "X-API-Key")

        // Create WebSocket task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)

        print(
            "🔌 [ChatBackendService] Initiating WebSocket connection for conversation: \(conversationId)"
        )
        print("🔍 [ChatBackendService] WebSocket URL: \(wsURL.absoluteString)")

        webSocketTask?.resume()

        // Note: isConnected will be set to true in didOpenWithProtocol delegate method
        // Don't start receiving here - it will be started in the delegate callback
    }

    func disconnectWebSocket() {
        guard isConnected else { return }

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false

        connectionStatusHandler?(.disconnected)
        print("✅ [ChatBackendService] Disconnected from WebSocket")
    }

    func sendMessageViaWebSocket(
        message: String,
        conversationId: UUID
    ) async throws {
        guard isConnected, let webSocketTask = webSocketTask else {
            throw WebSocketError.notConnected
        }

        // Create message payload
        let payload = WebSocketMessagePayload(
            type: "message",
            content: message,
            conversationId: conversationId.uuidString
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw WebSocketError.invalidMessage
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)

        try await webSocketTask.send(message)
        print("✅ [ChatBackendService] Sent message via WebSocket")
    }

    func setMessageHandler(_ handler: @escaping (ChatMessage) -> Void) {
        self.messageHandler = handler
    }

    func setConnectionStatusHandler(_ handler: @escaping (WebSocketConnectionStatus) -> Void) {
        self.connectionStatusHandler = handler
    }

    // MARK: - Private Methods

    private func receiveMessage() {
        print(
            "🔄 [ChatBackendService] Waiting to receive WebSocket message (isConnected: \(isConnected))"
        )

        webSocketTask?.receive { [weak self] result in
            guard let self = self else {
                print("⚠️ [ChatBackendService] Self is nil in receive callback")
                return
            }

            switch result {
            case .success(let message):
                print("📬 [ChatBackendService] Successfully received WebSocket message")
                self.handleWebSocketMessage(message)

                // Continue receiving
                if self.isConnected {
                    print("♻️ [ChatBackendService] Continuing to listen for next message")
                    self.receiveMessage()
                } else {
                    print(
                        "⚠️ [ChatBackendService] Not continuing receive loop - isConnected is false")
                }

            case .failure(let error):
                print(
                    "❌ [ChatBackendService] WebSocket receive error: \(error.localizedDescription)")
                self.connectionStatusHandler?(.error(error))
                self.isConnected = false
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("📝 [ChatBackendService] Received string message")
            handleTextMessage(text)
        case .data(let data):
            print("📦 [ChatBackendService] Received data message, converting to string")
            if let text = String(data: data, encoding: .utf8) {
                handleTextMessage(text)
            } else {
                print("❌ [ChatBackendService] Failed to convert data to string")
            }
        @unknown default:
            print("⚠️ [ChatBackendService] Unknown WebSocket message type")
        }
    }

    private func handleTextMessage(_ text: String) {
        print("📥 [ChatBackendService] Received WebSocket message: \(text)")

        guard let data = text.data(using: .utf8) else {
            print("❌ [ChatBackendService] Failed to convert message to data")
            return
        }

        do {
            let decoder = JSONDecoder()

            // Decode the wrapper
            let wrapper = try decoder.decode(WebSocketMessageWrapper.self, from: data)

            // Handle different message types
            switch wrapper.type {
            case "connected":
                print(
                    "✅ [ChatBackendService] WebSocket connected, consultation: \(wrapper.consultation_id ?? "unknown")"
                )

            case "message_received":
                print("✅ [ChatBackendService] Message received by server")

            case "stream_chunk":
                // Handle streaming chunk
                if let content = wrapper.content {
                    currentStreamingContent += content

                    // Create or update streaming message
                    if currentStreamingMessage == nil {
                        // Create new streaming message
                        let consultationId =
                            UUID(uuidString: wrapper.consultation_id ?? "") ?? UUID()
                        currentStreamingMessage = ChatMessage(
                            id: UUID(),
                            conversationId: consultationId,
                            role: .assistant,
                            content: currentStreamingContent,
                            timestamp: Date(),
                            metadata: MessageMetadata(
                                persona: nil,
                                context: nil,
                                tokens: nil,
                                processingTime: nil,
                                isStreaming: true
                            )
                        )
                    } else {
                        // Update existing streaming message
                        currentStreamingMessage?.content = currentStreamingContent
                    }

                    // Notify handler with updated streaming message
                    if let message = currentStreamingMessage {
                        messageHandler?(message)
                    }

                    print(
                        "📝 [ChatBackendService] Streaming chunk added, total length: \(currentStreamingContent.count)"
                    )
                }

            case "stream_complete":
                // Finalize streaming message
                if var finalMessage = currentStreamingMessage {
                    // Mark as not streaming
                    finalMessage.metadata?.isStreaming = false
                    messageHandler?(finalMessage)
                    print(
                        "✅ [ChatBackendService] Stream complete, final message length: \(finalMessage.content.count)"
                    )
                }

                // Reset streaming state
                currentStreamingMessage = nil
                currentStreamingContent = ""

            case "message":
                guard let messageDTO = wrapper.message else {
                    print("⚠️ [ChatBackendService] Received message type but no message content")
                    return
                }

                let chatMessage = messageDTO.toDomain()
                messageHandler?(chatMessage)
                print("✅ [ChatBackendService] Received message via WebSocket: \(chatMessage.id)")

            case "error":
                print(
                    "❌ [ChatBackendService] WebSocket error from server: \(wrapper.error ?? "unknown")"
                )
                connectionStatusHandler?(.error(WebSocketError.messageDecodingFailed))

            case "pong":
                print("🏓 [ChatBackendService] Received pong")

            default:
                print("⚠️ [ChatBackendService] Unknown WebSocket message type: \(wrapper.type)")
            }
        } catch {
            print(
                "❌ [ChatBackendService] Failed to decode WebSocket message: \(error.localizedDescription)"
            )
            print("🔍 [ChatBackendService] Raw message was: \(text)")
            if let decodingError = error as? DecodingError {
                print("🔍 [ChatBackendService] Decoding error details: \(decodingError)")
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension ChatBackendService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("✅ [ChatBackendService] WebSocket connection opened")
        print("🔍 [ChatBackendService] Protocol: \(`protocol` ?? "none")")

        isConnected = true
        connectionStatusHandler?(.connected)

        // Now that connection is confirmed, start receiving messages
        print("🎧 [ChatBackendService] Starting to listen for WebSocket messages")
        receiveMessage()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        print("✅ [ChatBackendService] WebSocket connection closed with code: \(closeCode.rawValue)")
        isConnected = false
        connectionStatusHandler?(.disconnected)
    }
}

// MARK: - Request/Response Models

/// Request body for creating a conversation
private struct CreateConversationRequest: Encodable {
    let persona: String
    let initialMessage: String?
    let contextType: String?
    let contextId: String?
    let quickAction: String?

    enum CodingKeys: String, CodingKey {
        case persona
        case initialMessage = "initial_message"
        case contextType = "context_type"
        case contextId = "context_id"
        case quickAction = "quick_action"
    }

    init(persona: String, context: ConversationContext?, initialMessage: String? = nil) {
        self.persona = persona
        self.initialMessage = initialMessage

        // Map context to consultations API fields
        if let context = context {
            self.quickAction = context.quickAction

            // Determine context type and set context_id
            if context.relatedGoalIds != nil {
                self.contextType = "goal"
                // CRITICAL: Use backend goal ID for context_id (lowercase to match backend format)
                // The backend needs its own goal ID to look up the goal
                self.contextId = context.backendGoalId?.lowercased()
            } else if context.relatedInsightIds != nil {
                self.contextType = "insight"
                self.contextId = context.relatedInsightIds?.first?.uuidString.lowercased()
            } else if context.moodContext != nil {
                self.contextType = "mood"
                self.contextId = nil
            } else {
                self.contextType = "general"
                self.contextId = nil
            }
        } else {
            self.contextType = nil
            self.contextId = nil
            self.quickAction = nil
        }
    }
}

/// Request body for updating a conversation
private struct UpdateConversationRequest: Encodable {
    let title: String?
    let persona: String?
    let is_archived: Bool?

    init(
        title: String? = nil,
        persona: String? = nil,
        isArchived: Bool? = nil
    ) {
        self.title = title
        self.persona = persona
        self.is_archived = isArchived
    }
}

/// Request body for sending a message
private struct SendMessageRequest: Encodable {
    let content: String
}

/// Response containing a single conversation (GET endpoint)
private struct ConversationResponse: Decodable {
    let data: ConversationDTO
}

/// Response for creating a conversation (POST endpoint)
private struct CreateConversationResponse: Decodable {
    let data: CreateConversationData
}

/// Nested data structure for create conversation response
private struct CreateConversationData: Decodable {
    let consultation: ConversationDTO
    let needs_survey: Bool?

    enum CodingKeys: String, CodingKey {
        case consultation
        case needs_survey
    }
}

/// Response containing a list of conversations
private struct ConversationsListResponse: Decodable {
    let data: ConversationsListData
}

/// List data wrapper
private struct ConversationsListData: Decodable {
    let consultations: [ConversationDTO]
    let total_count: Int
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case consultations
        case total_count
        case limit
        case offset
    }
}

/// DTO for conversation from backend

/// Context type enum for type-safe context handling
/// Maps to the backend's context_type field to indicate what kind of context a consultation has
private enum ContextType: String, Decodable {
    case goal = "goal"  // Consultation focused on a specific goal
    case mood = "mood"  // Consultation related to mood tracking
    case insight = "insight"  // Consultation about AI-generated insights
    case general = "general"  // General wellness consultation without specific context
}

private struct ConversationDTO: Decodable {
    let id: String
    let user_id: String
    let persona: String
    let status: String
    let goal_id: String?
    let context_type: ContextType?
    let context_id: String?
    let quick_action: String?
    let started_at: String?
    let completed_at: String?
    let last_message_at: String?
    let message_count: Int
    let messages: [MessageDTO]?
    let created_at: String
    let updated_at: String
    let has_context_for_goal_suggestions: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case persona
        case status
        case goal_id
        case context_type
        case context_id
        case quick_action
        case started_at
        case completed_at
        case last_message_at
        case message_count
        case messages
        case created_at
        case updated_at
        case has_context_for_goal_suggestions
    }

    func toDomain() -> ChatConversation {
        let personaEnum = ChatPersona(rawValue: persona) ?? .generalWellness

        // SMART TITLE GENERATION
        let smartTitle: String

        // Priority 1: Goal-based chats
        if context_type == .goal, let goalId = goal_id {
            smartTitle = "💪 Goal Chat"  // Placeholder, will be updated by UI layer
            print("🎯 [ConversationDTO] Goal-based chat detected, goalId: \(goalId)")
        }
        // Priority 2: Use first user message as preview
        else if let firstUserMessage = messages?.first(where: { $0.role == "user" }),
            !firstUserMessage.content.isEmpty
        {
            let preview = firstUserMessage.content.prefix(40)
            smartTitle = String(preview) + (firstUserMessage.content.count > 40 ? "..." : "")
            print("💬 [ConversationDTO] Using first message as title: '\(smartTitle)'")
        }
        // Priority 3: Default persona name
        else {
            smartTitle = "Chat with \(personaEnum.displayName)"
        }

        // Determine if archived based on status
        let isArchived = status == "archived"

        // Build context if available
        var contextObj: ConversationContext?

        // Check for context_type and context_id (new API format)
        if context_type == .goal, let contextId = context_id,
            let contextUUID = UUID(uuidString: contextId)
        {
            contextObj = ConversationContext(
                relatedGoalIds: [contextUUID],
                quickAction: quick_action,
                backendGoalId: contextId  // Store backend goal ID
            )
            print(
                "🎯 [ConversationDTO] Created context from context_type=goal, context_id: \(contextId)"
            )
        }
        // Fallback to old goal_id field for backward compatibility
        else if let goalId = goal_id, let goalUUID = UUID(uuidString: goalId) {
            contextObj = ConversationContext(
                relatedGoalIds: [goalUUID],
                quickAction: quick_action,
                backendGoalId: goalId  // Store backend goal ID
            )
            print("🎯 [ConversationDTO] Created context from legacy goal_id: \(goalId)")
        } else if let quickActionValue = quick_action {
            contextObj = ConversationContext(
                quickAction: quickActionValue
            )
        }

        // Parse dates from strings
        let formatter = ISO8601DateFormatter()
        let createdDate = formatter.date(from: created_at) ?? Date()
        let updatedDate = formatter.date(from: updated_at) ?? Date()

        return ChatConversation(
            id: UUID(uuidString: id) ?? UUID(),
            userId: UUID(uuidString: user_id) ?? UUID(),
            title: smartTitle,
            persona: personaEnum,
            messages: messages?.map { $0.toDomain(conversationId: UUID(uuidString: id) ?? UUID()) }
                ?? [],
            createdAt: createdDate,
            updatedAt: updatedDate,
            isArchived: isArchived,
            context: contextObj,
            hasContextForGoalSuggestions: has_context_for_goal_suggestions ?? false
        )
    }
}

/// Response containing a single message
private struct MessageResponse: Decodable {
    let data: SendMessageData
}

/// Wrapper for send message response
private struct SendMessageData: Decodable {
    let user_message: MessageDTO
    let assistant_message: MessageDTO?
}

/// Response containing a list of messages
private struct MessagesListResponse: Decodable {
    let data: MessagesListData
}

/// List data wrapper for messages
private struct MessagesListData: Decodable {
    let messages: [MessageDTO]
    let total: Int
    let has_more: Bool
}

/// DTO for message from backend
private struct MessageDTO: Decodable {
    let id: String
    let role: String
    let content: String
    let created_at: Date
    let metadata: MessageMetadataDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case created_at
        case metadata
    }

    func toDomain(conversationId: UUID) -> ChatMessage {
        ChatMessage(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: conversationId,
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            timestamp: created_at,
            metadata: metadata?.toDomain()
        )
    }
}

/// DTO for message metadata
private struct MessageMetadataDTO: Decodable {
    let persona: String?
    let context: [String: String]?
    let tokens: Int?
    let processing_time: Double?
    let is_streaming: Bool?

    func toDomain() -> MessageMetadata {
        MessageMetadata(
            persona: persona.flatMap { ChatPersona(rawValue: $0) },
            context: context,
            tokens: tokens,
            processingTime: processing_time,
            isStreaming: is_streaming ?? false
        )
    }
}

/// DTO for conversation context
private struct ConversationContextDTO: Codable {
    let related_goal_ids: [String]?
    let related_insight_ids: [String]?
    let mood_context: MoodContextSummaryDTO?
    let quick_action: String?

    init(from context: ConversationContext) {
        self.related_goal_ids = context.relatedGoalIds?.map { $0.uuidString }
        self.related_insight_ids = context.relatedInsightIds?.map { $0.uuidString }
        self.mood_context = context.moodContext.map { MoodContextSummaryDTO(from: $0) }
        self.quick_action = context.quickAction
    }

    func toDomain() -> ConversationContext {
        ConversationContext(
            relatedGoalIds: related_goal_ids?.compactMap { UUID(uuidString: $0) },
            relatedInsightIds: related_insight_ids?.compactMap { UUID(uuidString: $0) },
            moodContext: mood_context?.toDomain(),
            quickAction: quick_action
        )
    }
}

/// DTO for mood context summary
private struct MoodContextSummaryDTO: Codable {
    let recent_mood_average: Double?
    let mood_trend: String?
    let mood_entry_count: Int?

    init(from summary: MoodContextSummary) {
        self.recent_mood_average = summary.recentMoodAverage
        self.mood_trend = summary.moodTrend
        self.mood_entry_count = summary.moodEntryCount
    }

    func toDomain() -> MoodContextSummary {
        MoodContextSummary(
            recentMoodAverage: recent_mood_average,
            moodTrend: mood_trend,
            moodEntryCount: mood_entry_count
        )
    }
}

/// WebSocket message payload
private struct WebSocketMessagePayload: Encodable {
    let type: String
    let content: String
    let conversationId: String
}

/// WebSocket message wrapper (from backend)
private struct WebSocketMessageWrapper: Decodable {
    let type: String
    let message: WebSocketMessageDTO?
    let consultation_id: String?
    let content: String?  // For stream_chunk messages
    let timestamp: String?
    let error: String?
}

/// WebSocket message DTO (nested inside wrapper)
private struct WebSocketMessageDTO: Decodable {
    let id: String
    let consultation_id: String
    let role: String
    let content: String
    let function_name: String?
    let function_args: String?
    let tokens_used: Int?
    let processing_time_ms: Int?
    let created_at: String

    func toDomain() -> ChatMessage {
        // Parse the ISO8601 date
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: created_at) ?? Date()

        return ChatMessage(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: UUID(uuidString: consultation_id) ?? UUID(),
            role: MessageRole(rawValue: role) ?? .assistant,
            content: content,
            timestamp: timestamp,
            metadata: nil
        )
    }
}

// MARK: - Mock Implementation

final class InMemoryChatBackendService: ChatBackendServiceProtocol {

    var shouldFail = false
    var conversations: [UUID: ChatConversation] = [:]
    var messageHandler: ((ChatMessage) -> Void)?
    var connectionStatusHandler: ((WebSocketConnectionStatus) -> Void)?

    func createConversation(
        title: String,
        persona: ChatPersona,
        context: ConversationContext?,
        accessToken: String
    ) async throws -> ChatConversation {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let conversation = ChatConversation(
            id: UUID(),
            userId: UUID(),
            title: title,
            persona: persona,
            messages: [],
            context: context
        )

        conversations[conversation.id] = conversation
        print("🔵 [InMemoryChatBackendService] Created mock conversation: \(conversation.id)")
        return conversation
    }

    func updateConversation(
        conversationId: UUID,
        title: String?,
        persona: ChatPersona?,
        accessToken: String
    ) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        if var conversation = conversations[conversationId] {
            if let title = title {
                conversation.title = title
            }
            if let persona = persona {
                conversation.persona = persona
            }
            conversation.updatedAt = Date()
            conversations[conversationId] = conversation
        }

        print("🔵 [InMemoryChatBackendService] Updated mock conversation: \(conversationId)")
    }

    func fetchAllConversations(
        status: String? = nil,
        persona: ChatPersona? = nil,
        limit: Int = 20,
        offset: Int = 0,
        accessToken: String
    ) async throws -> [ChatConversation] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        var filtered = Array(conversations.values)

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

        let paginated = Array(sorted[startIndex..<endIndex])
        print(
            "🔵 [InMemoryChatBackendService] Fetched \(paginated.count) mock conversations (total: \(sorted.count), limit: \(limit), offset: \(offset))"
        )
        return paginated
    }

    func fetchConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws -> ChatConversation {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        guard let conversation = conversations[conversationId] else {
            throw HTTPError.notFound
        }

        print("🔵 [InMemoryChatBackendService] Fetched mock conversation: \(conversationId)")
        return conversation
    }

    func deleteConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        conversations.removeValue(forKey: conversationId)
        print("🔵 [InMemoryChatBackendService] Deleted mock conversation: \(conversationId)")
    }

    func archiveConversation(
        conversationId: UUID,
        accessToken: String
    ) async throws {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        if var conversation = conversations[conversationId] {
            conversation.archive()
            conversations[conversationId] = conversation
        }

        print("🔵 [InMemoryChatBackendService] Archived mock conversation: \(conversationId)")
    }

    func sendMessage(
        message: String,
        conversationId: UUID,
        accessToken: String
    ) async throws -> ChatMessage {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let chatMessage = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: message,
            timestamp: Date()
        )

        if var conversation = conversations[conversationId] {
            conversation.addMessage(chatMessage)
            conversations[conversationId] = conversation

            // Simulate AI response
            try await Task.sleep(nanoseconds: 500_000_000)
            let aiResponse = ChatMessage(
                id: UUID(),
                conversationId: conversationId,
                role: .assistant,
                content: "This is a mock AI response to: \(message)",
                timestamp: Date()
            )
            conversation.addMessage(aiResponse)
            conversations[conversationId] = conversation

            messageHandler?(aiResponse)
        }

        print("🔵 [InMemoryChatBackendService] Sent mock message in conversation: \(conversationId)")
        return chatMessage
    }

    func fetchMessages(
        conversationId: UUID,
        limit: Int,
        offset: Int,
        accessToken: String
    ) async throws -> [ChatMessage] {
        if shouldFail {
            throw HTTPError.serverError(500)
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        guard let conversation = conversations[conversationId] else {
            return []
        }

        let messages = Array(conversation.messages.dropFirst(offset).prefix(limit))
        print(
            "🔵 [InMemoryChatBackendService] Fetched \(messages.count) mock messages for conversation: \(conversationId)"
        )
        return messages
    }

    func connectWebSocket(
        conversationId: UUID,
        accessToken: String
    ) async throws {
        if shouldFail {
            throw WebSocketError.connectionFailed
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        connectionStatusHandler?(.connected)
        print(
            "🔵 [InMemoryChatBackendService] Mock WebSocket connected for conversation: \(conversationId)"
        )
    }

    func disconnectWebSocket() {
        connectionStatusHandler?(.disconnected)
        print("🔵 [InMemoryChatBackendService] Mock WebSocket disconnected")
    }

    func sendMessageViaWebSocket(
        message: String,
        conversationId: UUID
    ) async throws {
        if shouldFail {
            throw WebSocketError.sendFailed
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let chatMessage = ChatMessage(
            id: UUID(),
            conversationId: conversationId,
            role: .assistant,
            content: "Mock WebSocket response to: \(message)",
            timestamp: Date()
        )

        messageHandler?(chatMessage)
        print("🔵 [InMemoryChatBackendService] Sent mock message via WebSocket")
    }

    func setMessageHandler(_ handler: @escaping (ChatMessage) -> Void) {
        self.messageHandler = handler
    }

    func setConnectionStatusHandler(_ handler: @escaping (WebSocketConnectionStatus) -> Void) {
        self.connectionStatusHandler = handler
    }
}
