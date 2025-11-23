//
//  ConsultationWebSocketManager.swift
//  lume
//
//  Created by AI Assistant on 2025-01-29.
//  Based on backend team's Consultation Live Chat Guide
//

import Foundation
import SwiftUI

/// Manages WebSocket connection for real-time consultation chat with AI
/// This is a standalone manager that follows the backend guide exactly
@MainActor
@Observable
final class ConsultationWebSocketManager {

    // MARK: - Published Properties

    nonisolated(unsafe) var isConnected = false
    var isAITyping = false
    nonisolated(unsafe) var connectionStatus: ConsultationConnectionStatus = .disconnected
    var messages: [ConsultationMessage] = []
    var error: Error?

    // MARK: - Private Properties

    nonisolated(unsafe) private var webSocketTask: URLSessionWebSocketTask?
    private var consultationID: String?
    nonisolated(unsafe) private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    private let jwtToken: String
    private let apiKey: String

    // Current AI message being streamed
    private var currentStreamingMessage = ""
    private var currentStreamingMessageID: String?

    // Streaming timeout handling
    nonisolated(unsafe) private var streamingTimeoutTask: Task<Void, Never>?
    private let streamingTimeout: TimeInterval = 30.0  // 30 seconds timeout for streaming

    // MARK: - Initialization

    init(jwtToken: String, apiKey: String) {
        self.jwtToken = jwtToken
        self.apiKey = apiKey
    }

    // MARK: - Configuration

    private var baseURL: String {
        AppConfiguration.shared.backendBaseURL.absoluteString
    }

    private var wsBaseURL: String {
        AppConfiguration.shared.webSocketURL?.absoluteString ?? "wss://fit-iq-backend.fly.dev"
    }

    deinit {
        disconnect()
    }

    // MARK: - Public Methods

    /// Create or retrieve consultation and connect
    func startConsultation(persona: String, goalID: String? = nil) async throws {
        print("🚀 [ConsultationWS] Starting consultation with persona: \(persona)")

        // Step 1: Get or create consultation
        let consultation = try await getOrCreateConsultation(persona: persona, goalID: goalID)
        self.consultationID = consultation.id

        print("✅ [ConsultationWS] Got consultation ID: \(consultation.id)")

        // Step 2: Load message history
        try await loadMessageHistory(consultationID: consultation.id)

        print("✅ [ConsultationWS] Loaded \(messages.count) historical messages")

        // Step 3: Connect to WebSocket
        await connect(consultationID: consultation.id)
    }

    /// Connect to an existing consultation without creating a new one
    func connectToExistingConsultation(consultationID: String) async throws {
        print("🔌 [ConsultationWS] Connecting to existing consultation: \(consultationID)")

        self.consultationID = consultationID

        // Step 1: Load message history
        try await loadMessageHistory(consultationID: consultationID)

        print("✅ [ConsultationWS] Loaded \(messages.count) historical messages")

        // Step 2: Connect to WebSocket
        await connect(consultationID: consultationID)

        print("✅ [ConsultationWS] Connected to existing consultation")
    }

    /// Send a message to the AI
    func sendMessage(_ content: String) async throws {
        guard let task = webSocketTask, isConnected else {
            throw ConsultationWebSocketError.notConnected
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConsultationWebSocketError.invalidMessage
        }

        print("📤 [ConsultationWS] Sending message: \(content.prefix(50))...")

        // Add user message to UI immediately
        let userMessage = ConsultationMessage(
            id: UUID().uuidString,
            role: .user,
            content: content,
            timestamp: Date(),
            isStreaming: false
        )
        messages.append(userMessage)

        // Send to backend
        let message = OutgoingConsultationMessage(
            type: "message",
            content: content
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let string = String(data: data, encoding: .utf8)!
        let wsMessage = URLSessionWebSocketTask.Message.string(string)

        try await task.send(wsMessage)

        print("✅ [ConsultationWS] Message sent to WebSocket")

        // Show AI typing indicator
        isAITyping = true
        currentStreamingMessage = ""
        currentStreamingMessageID = nil

        // Start polling as fallback (non-blocking)
        Task {
            // Wait 5 seconds for WebSocket response first
            try? await Task.sleep(nanoseconds: 5_000_000_000)

            // If still no response, start polling
            if self.isAITyping {
                print("⚠️ [ConsultationWS] No WebSocket response after 5s, starting polling")
                await self.pollForAIResponse()
            }
        }
    }

    /// Disconnect from WebSocket
    nonisolated func disconnect() {
        print("🔌 [ConsultationWS] Disconnecting WebSocket")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        streamingTimeoutTask?.cancel()
        streamingTimeoutTask = nil
        isConnected = false
        connectionStatus = .disconnected
    }

    // MARK: - Private Methods

    private func connect(consultationID: String) async {
        connectionStatus = .connecting

        // Normalize UUID to lowercase (backend requirement)
        let normalizedID = consultationID.lowercased()
        let urlString = "\(wsBaseURL)/api/v1/consultations/\(normalizedID)/ws"

        print("🔌 [ConsultationWS] Connecting to: \(urlString)")

        guard let url = URL(string: urlString) else {
            connectionStatus = .error("Invalid URL")
            print("❌ [ConsultationWS] Invalid URL: \(urlString)")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()

        self.webSocketTask = task
        self.isConnected = true
        self.connectionStatus = .connected
        self.reconnectAttempts = 0

        // Start receiving messages
        receiveMessage()

        print("✅ [ConsultationWS] WebSocket connected to consultation: \(consultationID)")
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    await self.handleIncomingMessage(message)
                    // Continue receiving
                    self.receiveMessage()

                case .failure(let error):
                    self.handleConnectionError(error)
                }
            }
        }
    }

    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            print("📥 [ConsultationWS] RAW MESSAGE: \(text)")

            // Check for specific message types for debugging
            if text.contains("stream_chunk") {
                print("✅ [ConsultationWS] Received stream_chunk!")
            }
            if text.contains("stream_complete") {
                print("✅ [ConsultationWS] Received stream_complete!")
            }
            if text.contains("\"type\":\"message\"") && !text.contains("message_received") {
                print("📨 [ConsultationWS] Received full message (non-streaming)")
            }

            // Backend may send multiple JSON objects concatenated with newlines
            // Split and process each separately
            let lines = text.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }

                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let wsMessage = try decoder.decode(
                        IncomingConsultationMessage.self, from: trimmed.data(using: .utf8)!)

                    await processMessage(wsMessage)

                } catch {
                    print("❌ [ConsultationWS] Failed to decode line: \(error)")
                    print("🔍 [ConsultationWS] Raw line: \(trimmed)")
                }
            }

        case .data(let data):
            print("⚠️ [ConsultationWS] Received binary data (unexpected): \(data)")

        @unknown default:
            print("⚠️ [ConsultationWS] Unknown message type")
        }
    }

    private func processMessage(_ message: IncomingConsultationMessage) async {
        switch message.type {
        case "connected":
            print("✅ [ConsultationWS] Connection confirmed by server")

        case "message_received":
            print("✅ [ConsultationWS] Server acknowledged message")

        case "stream_chunk":
            // Append chunk to current message
            if let content = message.content {
                currentStreamingMessage += content

                // Update or create streaming message in UI
                if let messageID = currentStreamingMessageID,
                    let index = messages.firstIndex(where: { $0.id == messageID })
                {
                    // Update existing streaming message
                    messages[index].content = currentStreamingMessage
                } else {
                    // Create new streaming message
                    let messageID = UUID().uuidString
                    currentStreamingMessageID = messageID

                    let streamingMessage = ConsultationMessage(
                        id: messageID,
                        role: .assistant,
                        content: currentStreamingMessage,
                        timestamp: Date(),
                        isStreaming: true
                    )
                    messages.append(streamingMessage)

                    // Start timeout timer for this streaming message
                    startStreamingTimeout()
                }

                print(
                    "📝 [ConsultationWS] Stream chunk received, total length: \(currentStreamingMessage.count)"
                )
            }

        case "stream_complete":
            // Cancel timeout since we received completion
            streamingTimeoutTask?.cancel()
            streamingTimeoutTask = nil

            // Finalize the streaming message
            if let messageID = currentStreamingMessageID,
                let index = messages.firstIndex(where: { $0.id == messageID })
            {
                messages[index].isStreaming = false
                print(
                    "✅ [ConsultationWS] Stream complete, final length: \(messages[index].content.count)"
                )
            }

            isAITyping = false
            currentStreamingMessage = ""
            currentStreamingMessageID = nil

        case "error":
            let errorMsg = message.error ?? "Unknown error"
            self.error = ConsultationWebSocketError.serverError(errorMsg)
            isAITyping = false
            print("❌ [ConsultationWS] Server error: \(errorMsg)")

        case "pong":
            // Response to ping (for keep-alive)
            print("🏓 [ConsultationWS] Received pong")

        default:
            print("⚠️ [ConsultationWS] Unknown message type: \(message.type)")
        }
    }

    private func handleConnectionError(_ error: Error) {
        print("❌ [ConsultationWS] Connection error: \(error.localizedDescription)")

        isConnected = false
        connectionStatus = .error(error.localizedDescription)
        self.error = error

        // Attempt reconnection with exponential backoff
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1

            let delay = UInt64(reconnectAttempts) * 1_000_000_000  // 1, 2, 3, 4, 5 seconds

            print(
                "🔄 [ConsultationWS] Attempting reconnection \(reconnectAttempts)/\(maxReconnectAttempts) in \(reconnectAttempts) seconds..."
            )

            Task {
                try? await Task.sleep(nanoseconds: delay)

                if let consultationID = self.consultationID {
                    await self.connect(consultationID: consultationID)
                }
            }
        } else {
            print("❌ [ConsultationWS] Max reconnection attempts reached")
        }
    }

    private func getOrCreateConsultation(persona: String, goalID: String?) async throws
        -> BackendConsultation
    {
        let url = URL(string: "\(baseURL)/api/v1/consultations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["persona": persona]
        if let goalID = goalID {
            body["goal_id"] = goalID
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConsultationError.invalidResponse
        }

        print("📡 [ConsultationWS] Create consultation response: \(httpResponse.statusCode)")

        // Handle 409 Conflict - consultation already exists
        if httpResponse.statusCode == 409 {
            let errorResponse = try JSONDecoder().decode(ConflictErrorResponse.self, from: data)
            print(
                "ℹ️ [ConsultationWS] Consultation exists, fetching: \(errorResponse.error.details.existingConsultationID)"
            )
            return try await fetchConsultation(
                id: errorResponse.error.details.existingConsultationID)
        }

        // Handle 429 Too Many Requests
        if httpResponse.statusCode == 429 {
            throw ConsultationError.tooManyActiveConsultations
        }

        guard httpResponse.statusCode == 201 else {
            throw ConsultationError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let createResponse = try decoder.decode(CreateConsultationResponse.self, from: data)
        return createResponse.data.consultation
    }

    private func fetchConsultation(id: String) async throws -> BackendConsultation {
        let normalizedID = id.lowercased()
        let url = URL(string: "\(baseURL)/api/v1/consultations/\(normalizedID)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ConsultationError.notFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let consultationResponse = try decoder.decode(ConsultationResponse.self, from: data)
        return consultationResponse.data
    }

    private func loadMessageHistory(consultationID: String) async throws {
        let normalizedID = consultationID.lowercased()
        let url = URL(string: "\(baseURL)/api/v1/consultations/\(normalizedID)/messages")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return  // No messages yet is okay
        }

        guard httpResponse.statusCode == 200 else {
            print("ℹ️ [ConsultationWS] No message history (status: \(httpResponse.statusCode))")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messagesResponse = try decoder.decode(BackendMessagesResponse.self, from: data)

        // Convert to ConsultationMessage format
        self.messages = messagesResponse.data.messages.map { msg in
            ConsultationMessage(
                id: msg.id,
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content,
                timestamp: msg.createdAt,
                isStreaming: false
            )
        }
    }

    /// Poll for AI response if WebSocket streaming doesn't deliver
    private func pollForAIResponse() async {
        guard let consultationID = consultationID else { return }

        print("🔄 [ConsultationWS] Starting polling for AI response...")

        // Poll up to 10 times (30 seconds total)
        for attempt in 1...10 {
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

            print("🔄 [ConsultationWS] Poll attempt \(attempt)/10")

            // Fetch latest messages from backend
            do {
                try await loadMessageHistory(consultationID: consultationID)

                // Check if we got an AI response
                if let lastMessage = messages.last, lastMessage.role == .assistant {
                    print("✅ [ConsultationWS] Found AI response via polling!")
                    isAITyping = false
                    return
                } else {
                    print(
                        "⏳ [ConsultationWS] No AI response yet, messages count: \(messages.count)")
                }
            } catch {
                print("⚠️ [ConsultationWS] Polling failed: \(error)")
            }
        }

        // Timeout after 30 seconds
        print("⏰ [ConsultationWS] Polling timeout - no AI response received")
        isAITyping = false
    }

    // MARK: - Streaming Timeout

    /// Start a timeout timer for streaming messages to handle cases where stream_complete is never received
    private func startStreamingTimeout() {
        // Cancel any existing timeout
        streamingTimeoutTask?.cancel()

        streamingTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(self?.streamingTimeout ?? 30.0 * 1_000_000_000))

                // If we reach here, timeout occurred - finalize the streaming message
                await MainActor.run {
                    guard let self = self else { return }

                    print("⏰ [ConsultationWS] Streaming timeout reached, finalizing message")

                    if let messageID = self.currentStreamingMessageID,
                        let index = self.messages.firstIndex(where: { $0.id == messageID })
                    {
                        self.messages[index].isStreaming = false
                        print(
                            "✅ [ConsultationWS] Stream finalized by timeout, length: \(self.messages[index].content.count)"
                        )
                    }

                    self.isAITyping = false
                    self.currentStreamingMessage = ""
                    self.currentStreamingMessageID = nil
                }
            } catch {
                // Task was cancelled, which is expected for normal completion
            }
        }
    }
}

// MARK: - Connection Status

enum ConsultationConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)

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
        case .error(let message):
            return "Error: \(message)"
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
        case .error:
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
        case .error:
            return "moodLow"
        }
    }
}

// MARK: - Errors

enum ConsultationWebSocketError: Error, LocalizedError {
    case notConnected
    case connectionFailed
    case sendFailed
    case invalidMessage
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .connectionFailed:
            return "Failed to connect to consultation service"
        case .sendFailed:
            return "Failed to send message"
        case .invalidMessage:
            return "Invalid message content"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

enum ConsultationError: Error, LocalizedError {
    case invalidResponse
    case notFound
    case tooManyActiveConsultations
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .notFound:
            return "Consultation not found"
        case .tooManyActiveConsultations:
            return
                "Maximum active consultations reached. Please complete or archive existing consultations."
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}

// MARK: - Message Models

struct ConsultationMessage: Identifiable, Equatable {
    let id: String
    let role: ConsultationMessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

enum ConsultationMessageRole: String {
    case user = "user"
    case assistant = "assistant"

    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "AI Coach"
        }
    }
}

// MARK: - Outgoing Message DTOs

private struct OutgoingConsultationMessage: Codable {
    let type: String
    let content: String
}

// MARK: - Incoming Message DTOs

private struct IncomingConsultationMessage: Codable {
    let type: String
    let consultationID: String?
    let content: String?
    let error: String?
    let timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case type
        case consultationID = "consultation_id"
        case content
        case error
        case timestamp
    }
}

// MARK: - Backend DTOs

private struct BackendConsultation: Codable {
    let id: String
    let userID: String
    let persona: String
    let status: String
    let startedAt: Date?
    let messageCount: Int
    let createdAt: Date
    let updatedAt: Date
    let goalID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case persona
        case status
        case startedAt = "started_at"
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case goalID = "goal_id"
    }
}

private struct CreateConsultationResponse: Codable {
    let data: ConsultationData

    struct ConsultationData: Codable {
        let consultation: BackendConsultation
    }
}

private struct ConsultationResponse: Codable {
    let data: BackendConsultation
}

private struct ConflictErrorResponse: Codable {
    let error: ErrorDetails

    struct ErrorDetails: Codable {
        let code: String
        let message: String
        let details: ConflictDetails
    }

    struct ConflictDetails: Codable {
        let existingConsultationID: String
        let persona: String
        let status: String
        let canContinue: Bool
        let goalID: String?

        enum CodingKeys: String, CodingKey {
            case existingConsultationID = "existing_consultation_id"
            case persona
            case status
            case canContinue = "can_continue"
            case goalID = "goal_id"
        }
    }
}

private struct BackendMessagesResponse: Codable {
    let data: MessagesData

    struct MessagesData: Codable {
        let messages: [BackendMessage]
    }
}

private struct BackendMessage: Codable {
    let id: String
    let consultationID: String
    let role: String
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case consultationID = "consultation_id"
        case role
        case content
        case createdAt = "created_at"
    }
}
