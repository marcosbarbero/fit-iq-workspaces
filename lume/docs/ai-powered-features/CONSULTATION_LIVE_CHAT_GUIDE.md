# Consultation WebSocket Integration Guide for Swift 6

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Target:** iOS App (Swift 6)  
**Backend API Version:** 0.34.0

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Complete Implementation](#complete-implementation)
4. [Message Protocol](#message-protocol)
5. [Error Handling](#error-handling)
6. [Best Practices](#best-practices)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This guide shows you how to integrate the FitIQ AI Consultation WebSocket API to create a real-time chat experience with AI wellness coaches using Swift 6.

### What You'll Build

- Real-time chat with AI streaming responses
- Message history with chat bubbles
- Connection status indicators
- Automatic reconnection on failure
- Typing indicators during AI response

### Prerequisites

- Swift 6+
- iOS 15+
- JWT authentication token
- API key for FitIQ backend

---

## 🚀 Quick Start

### Step 1: Create or Get Consultation

```swift
func getOrCreateConsultation(persona: String) async throws -> Consultation {
    let url = URL(string: "\(baseURL)/api/v1/consultations")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body = ["persona": persona]
    request.httpBody = try JSONEncoder().encode(body)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw ConsultationError.invalidResponse
    }
    
    // Handle 409 Conflict - consultation already exists
    if httpResponse.statusCode == 409 {
        let errorResponse = try JSONDecoder().decode(ConflictErrorResponse.self, from: data)
        // Use existing consultation ID
        return try await fetchConsultation(id: errorResponse.error.details.existingConsultationID)
    }
    
    guard httpResponse.statusCode == 201 else {
        throw ConsultationError.httpError(httpResponse.statusCode)
    }
    
    let response = try JSONDecoder().decode(CreateConsultationResponse.self, from: data)
    return response.data.consultation
}
```

### Step 2: Connect to WebSocket

```swift
func connectToConsultation(consultationID: String) {
    let urlString = "\(wsBaseURL)/api/v1/consultations/\(consultationID.lowercased())/ws"
    guard let url = URL(string: urlString) else { return }
    
    let task = URLSession.shared.webSocketTask(with: url)
    task.resume()
    
    self.webSocketTask = task
    self.isConnected = true
    
    // Start receiving messages
    receiveMessage()
}
```

### Step 3: Send and Receive Messages

```swift
func sendMessage(_ content: String) async throws {
    guard let task = webSocketTask else {
        throw WebSocketError.notConnected
    }
    
    let message = OutgoingMessage(
        type: "message",
        content: content
    )
    
    let data = try JSONEncoder().encode(message)
    let string = String(data: data, encoding: .utf8)!
    let wsMessage = URLSessionWebSocketTask.Message.string(string)
    
    try await task.send(wsMessage)
}

func receiveMessage() {
    webSocketTask?.receive { [weak self] result in
        switch result {
        case .success(let message):
            self?.handleIncomingMessage(message)
            // Continue receiving
            self?.receiveMessage()
            
        case .failure(let error):
            self?.handleError(error)
        }
    }
}
```

---

## 💻 Complete Implementation

### ConsultationWebSocketManager.swift

```swift
import Foundation
import Combine

/// Manages WebSocket connection for AI consultation chat
@MainActor
class ConsultationWebSocketManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var isAITyping = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var consultationID: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    private let baseURL = "https://fit-iq-backend.fly.dev"
    private let wsBaseURL = "wss://fit-iq-backend.fly.dev"
    private let jwtToken: String
    private let apiKey: String
    
    // Current AI message being streamed
    private var currentStreamingMessage = ""
    
    // MARK: - Initialization
    
    init(jwtToken: String, apiKey: String) {
        self.jwtToken = jwtToken
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    /// Create or retrieve consultation and connect
    func startConsultation(persona: String, goalID: String? = nil) async throws {
        // Step 1: Get or create consultation
        let consultation = try await getOrCreateConsultation(persona: persona, goalID: goalID)
        self.consultationID = consultation.id
        
        // Step 2: Load message history
        try await loadMessageHistory(consultationID: consultation.id)
        
        // Step 3: Connect to WebSocket
        await connect(consultationID: consultation.id)
    }
    
    /// Send a message to the AI
    func sendMessage(_ content: String) async throws {
        guard let task = webSocketTask, isConnected else {
            throw WebSocketError.notConnected
        }
        
        // Add user message to UI immediately
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: content,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Send to backend
        let message = OutgoingMessage(
            type: "message",
            content: content
        )
        
        let data = try JSONEncoder().encode(message)
        let string = String(data: data, encoding: .utf8)!
        let wsMessage = URLSessionWebSocketTask.Message.string(string)
        
        try await task.send(wsMessage)
        
        // Show AI typing indicator
        isAITyping = true
        currentStreamingMessage = ""
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = .disconnected
    }
    
    // MARK: - Private Methods
    
    private func connect(consultationID: String) async {
        connectionStatus = .connecting
        
        // Normalize UUID to lowercase (backend requirement)
        let normalizedID = consultationID.lowercased()
        let urlString = "\(wsBaseURL)/api/v1/consultations/\(normalizedID)/ws"
        
        guard let url = URL(string: urlString) else {
            connectionStatus = .error("Invalid URL")
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
        
        print("✅ WebSocket connected to consultation: \(consultationID)")
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
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let wsMessage = try decoder.decode(WebSocketMessage.self, from: text.data(using: .utf8)!)
                
                await processMessage(wsMessage)
                
            } catch {
                print("❌ Failed to decode WebSocket message: \(error)")
                print("Raw message: \(text)")
            }
            
        case .data(let data):
            print("⚠️ Received binary data (unexpected): \(data)")
            
        @unknown default:
            print("⚠️ Unknown message type")
        }
    }
    
    private func processMessage(_ message: WebSocketMessage) async {
        switch message.type {
        case "connected":
            print("✅ WebSocket connection confirmed")
            
        case "message_received":
            print("✅ Message received by server")
            
        case "stream_chunk":
            // Append chunk to current message
            currentStreamingMessage += message.content ?? ""
            
            // Update or create streaming message in UI
            if let lastMessage = messages.last, lastMessage.role == .assistant, lastMessage.isStreaming {
                messages[messages.count - 1].content = currentStreamingMessage
            } else {
                let streamingMessage = ChatMessage(
                    id: UUID().uuidString,
                    role: .assistant,
                    content: currentStreamingMessage,
                    timestamp: Date(),
                    isStreaming: true
                )
                messages.append(streamingMessage)
            }
            
        case "stream_complete":
            // Finalize the streaming message
            if let lastMessageIndex = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
                messages[lastMessageIndex].isStreaming = false
            }
            
            isAITyping = false
            currentStreamingMessage = ""
            print("✅ Stream complete")
            
        case "error":
            let errorMsg = message.error ?? "Unknown error"
            self.error = WebSocketError.serverError(errorMsg)
            isAITyping = false
            print("❌ Server error: \(errorMsg)")
            
        case "pong":
            // Response to ping (for keep-alive)
            break
            
        default:
            print("⚠️ Unknown message type: \(message.type)")
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        print("❌ WebSocket error: \(error.localizedDescription)")
        
        isConnected = false
        connectionStatus = .error(error.localizedDescription)
        self.error = error
        
        // Attempt reconnection
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            
            Task {
                try? await Task.sleep(nanoseconds: UInt64(reconnectAttempts) * 1_000_000_000) // Exponential backoff
                
                if let consultationID = self.consultationID {
                    await self.connect(consultationID: consultationID)
                }
            }
        }
    }
    
    private func getOrCreateConsultation(persona: String, goalID: String?) async throws -> Consultation {
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
        
        // Handle 409 Conflict - consultation already exists
        if httpResponse.statusCode == 409 {
            let errorResponse = try JSONDecoder().decode(ConflictErrorResponse.self, from: data)
            return try await fetchConsultation(id: errorResponse.error.details.existingConsultationID)
        }
        
        // Handle 429 Too Many Requests - max consultations reached
        if httpResponse.statusCode == 429 {
            throw ConsultationError.tooManyActiveConsultations
        }
        
        guard httpResponse.statusCode == 201 else {
            throw ConsultationError.httpError(httpResponse.statusCode)
        }
        
        let createResponse = try JSONDecoder().decode(CreateConsultationResponse.self, from: data)
        return createResponse.data.consultation
    }
    
    private func fetchConsultation(id: String) async throws -> Consultation {
        let normalizedID = id.lowercased()
        let url = URL(string: "\(baseURL)/api/v1/consultations/\(normalizedID)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ConsultationError.notFound
        }
        
        let consultationResponse = try JSONDecoder().decode(ConsultationResponse.self, from: data)
        return consultationResponse.data
    }
    
    private func loadMessageHistory(consultationID: String) async throws {
        let normalizedID = consultationID.lowercased()
        let url = URL(string: "\(baseURL)/api/v1/consultations/\(normalizedID)/messages")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // No messages yet is okay
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let messagesResponse = try decoder.decode(MessagesResponse.self, from: data)
        
        // Convert to ChatMessage format
        self.messages = messagesResponse.data.messages.map { msg in
            ChatMessage(
                id: msg.id,
                role: msg.role == "user" ? .user : .assistant,
                content: msg.content,
                timestamp: msg.createdAt
            )
        }
    }
}

// MARK: - Supporting Types

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
}

enum WebSocketError: Error, LocalizedError {
    case notConnected
    case serverError(String)
    case invalidMessage
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidMessage:
            return "Invalid message format"
        }
    }
}

enum ConsultationError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case notFound
    case tooManyActiveConsultations
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .notFound:
            return "Consultation not found"
        case .tooManyActiveConsultations:
            return "Too many active consultations. Please complete some before creating new ones."
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool = false
}

enum MessageRole {
    case user
    case assistant
}

// MARK: - API Models

struct OutgoingMessage: Codable {
    let type: String
    let content: String
}

struct WebSocketMessage: Codable {
    let type: String
    let consultationID: String?
    let content: String?
    let error: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case type
        case consultationID = "consultation_id"
        case content
        case error
        case timestamp
    }
}

struct CreateConsultationResponse: Codable {
    let success: Bool
    let data: ConsultationData
    
    struct ConsultationData: Codable {
        let consultation: Consultation
    }
}

struct ConsultationResponse: Codable {
    let success: Bool
    let data: Consultation
}

struct Consultation: Codable {
    let id: String
    let userID: String
    let persona: String
    let status: String
    let startedAt: Date
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

struct ConflictErrorResponse: Codable {
    let success: Bool
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

struct MessagesResponse: Codable {
    let success: Bool
    let data: MessagesData
    
    struct MessagesData: Codable {
        let messages: [Message]
    }
    
    struct Message: Codable {
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
}
```

---

## 📱 SwiftUI View Example

### ConsultationChatView.swift

```swift
import SwiftUI

struct ConsultationChatView: View {
    @StateObject private var manager: ConsultationWebSocketManager
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    
    let persona: String
    let goalID: String?
    
    init(persona: String, goalID: String? = nil, jwtToken: String, apiKey: String) {
        self.persona = persona
        self.goalID = goalID
        _manager = StateObject(wrappedValue: ConsultationWebSocketManager(jwtToken: jwtToken, apiKey: apiKey))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(persona.capitalized)
                    .font(.headline)
                
                Spacer()
                
                ConnectionStatusView(status: manager.connectionStatus)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(manager.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        
                        if manager.isAITyping {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: manager.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(manager.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Input
            MessageInputView(
                text: $messageText,
                isEnabled: manager.isConnected && !manager.isAITyping,
                onSend: sendMessage
            )
        }
        .task {
            do {
                try await manager.startConsultation(persona: persona, goalID: goalID)
            } catch {
                print("❌ Failed to start consultation: \(error)")
            }
        }
        .onDisappear {
            manager.disconnect()
        }
        .alert("Error", isPresented: .constant(manager.error != nil)) {
            Button("OK") {
                manager.error = nil
            }
        } message: {
            if let error = manager.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        Task {
            do {
                try await manager.sendMessage(text)
                messageText = ""
            } catch {
                print("❌ Failed to send message: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .opacity(message.isStreaming ? 0.8 : 1.0)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

struct ConnectionStatusView: View {
    let status: ConnectionStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected, .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error"
        }
    }
}

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .onAppear {
            animating = true
        }
    }
}

struct MessageInputView: View {
    @Binding var text: String
    let isEnabled: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .disabled(!isEnabled)
                .onSubmit(onSend)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var canSend: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

---

## 📡 Message Protocol

### Message Types

#### From Client to Server

**1. Send Message**
```json
{
  "type": "message",
  "content": "What should I eat for breakfast?"
}
```

**2. Ping (Keep-Alive)**
```json
{
  "type": "ping"
}
```

#### From Server to Client

**1. Connected**
```json
{
  "type": "connected",
  "consultation_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-01-29T10:30:00Z"
}
```

**2. Message Received**
```json
{
  "type": "message_received",
  "consultation_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-01-29T10:30:01Z"
}
```

**3. Stream Chunk (AI Response)**
```json
{
  "type": "stream_chunk",
  "consultation_id": "550e8400-e29b-41d4-a716-446655440000",
  "content": "For breakfast, I recommend ",
  "timestamp": "2025-01-29T10:30:02Z"
}
```

**4. Stream Complete**
```json
{
  "type": "stream_complete",
  "consultation_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-01-29T10:30:05Z"
}
```

**5. Error**
```json
{
  "type": "error",
  "consultation_id": "550e8400-e29b-41d4-a716-446655440000",
  "error": "Failed to process message",
  "timestamp": "2025-01-29T10:30:02Z"
}
```

**6. Pong (Keep-Alive Response)**
```json
{
  "type": "pong",
  "timestamp": "2025-01-29T10:30:00Z"
}
```

---

## 🚨 Error Handling

### HTTP Errors

| Status Code | Meaning | Action |
|-------------|---------|--------|
| 401 | Unauthorized | Refresh JWT token |
| 404 | Consultation not found | Verify consultation ID |
| 409 | Consultation exists | Use existing consultation ID from error |
| 429 | Too many active consultations | Show alert, suggest completing old ones |
| 500 | Server error | Retry with exponential backoff |

### WebSocket Errors

```swift
private func handleConnectionError(_ error: Error) {
    let nsError = error as NSError
    
    switch nsError.code {
    case 57: // Socket is not connected
        // Attempt reconnection
        reconnect()
        
    case 60: // Operation timed out
        // Network issue - retry
        reconnect()
        
    default:
        // Show error to user
        self.error = error
    }
}
```

---

## ✅ Best Practices

### 1. UUID Normalization
Always lowercase consultation IDs before using them:
```swift
let normalizedID = consultationID.lowercased()
```

### 2. Connection Management
- Disconnect on view disappear
- Reconnect on view appear if consultation exists
- Implement exponential backoff for reconnection
- Maximum 5 reconnection attempts

### 3. Memory Management
- Use `[weak self]` in closures
- Cancel WebSocket task on deinit
- Clear message buffer on disconnect

### 4. User Experience
- Show connection status indicator
- Display typing indicator during AI response
- Auto-scroll to latest message
- Disable input while AI is responding
- Show error alerts for failures

### 5. Performance
- Lazy load message history
- Limit message cache to last 100 messages
- Use `LazyVStack` for message list
- Debounce typing events

---

## 🧪 Testing

### Unit Tests

```swift
import XCTest
@testable import YourApp

class ConsultationWebSocketManagerTests: XCTestCase {
    var manager: ConsultationWebSocketManager!
    
    override func setUp() {
        super.setUp()
        manager = ConsultationWebSocketManager(
            jwtToken: "test-token",
            apiKey: "test-api-key"
        )
    }
    
    func testMessageFormatting() {
        let message = OutgoingMessage(type: "message", content: "Hello")
        let data = try! JSONEncoder().encode(message)
        let decoded = try! JSONDecoder().decode(OutgoingMessage.self, from: data)
        
        XCTAssertEqual(decoded.type, "message")
        XCTAssertEqual(decoded.content, "Hello")
    }
    
    func testStreamingMessageAccumulation() async {
        // Test that stream chunks accumulate correctly
        let chunk1 = WebSocketMessage(
            type: "stream_chunk",
            consultationID: "test-id",
            content: "Hello ",
            error: nil,
            timestamp: Date()
        )
        
        let chunk2 = WebSocketMessage(
            type: "stream_chunk",
            consultationID: "test-id",
            content: "world",
            error: nil,
            timestamp: Date()
        )
        
        await manager.processMessage(chunk1)
        await manager.processMessage(chunk2)
        
        XCTAssertEqual(manager.messages.last?.content, "Hello world")
    }
}
```

### Integration Tests

```swift
func testFullChatFlow() async throws {
    let manager = ConsultationWebSocketManager(
        jwtToken: realJWTToken,
        apiKey: realAPIKey
    )
    
    // Start consultation
    try await manager.startConsultation(persona: "nutritionist")
    
    // Wait for connection
    try await Task.sleep(nanoseconds: 1_000_000_000)
    XCTAssertTrue(manager.isConnected)
    
    // Send message
    try await manager.sendMessage("Hello")
    
    // Wait for response
    try await Task.sleep(nanoseconds: 5_000_000_000)
    
    // Verify we got a response
    let hasAssistantMessage = manager.messages.contains { $0.role == .assistant }
    XCTAssertTrue(hasAssistantMessage)
    
    // Disconnect
    manager.disconnect()
    XCTAssertFalse(manager.isConnected)
}
```

---

## 🔍 Troubleshooting

### Issue: WebSocket not connecting

**Symptoms:** Connection status stays "connecting" forever

**Solutions:**
1. Verify JWT token is valid and not expired
2. Check API key is correct
3. Ensure consultation ID is lowercase
4. Verify network connectivity
5. Check backend logs for errors

```swift
// Debug connection
print("Connecting to: \(urlString)")
print("JWT: \(jwtToken.prefix(20))...")
print("Consultation ID: \(consultationID)")
```

### Issue: Messages not appearing

**Symptoms:** Sent messages don't show up in chat

**Solutions:**
1. Check WebSocket is connected: `manager.isConnected`
2. Verify message format is correct
3. Check for errors in console
4. Ensure `receiveMessage()` loop is running

```swift
// Debug message flow
func sendMessage(_ content: String) async throws {
    print("📤 Sending: \(content)")
    try await task.send(wsMessage)
    print("✅ Sent successfully")
}
```

### Issue: Streaming not working

**Symptoms:** AI response appears all at once instead of streaming

**Solutions:**
1. Verify `stream_chunk` messages are being received
2. Check `isStreaming` flag is set correctly
3. Ensure UI updates on main actor
4. Check message ID matching logic

```swift
// Debug streaming
case "stream_chunk":
    print("📥 Chunk: \(message.content ?? "")")
    currentStreamingMessage += message.content ?? ""
    print("💬 Accumulated: \(currentStreamingMessage)")
```

### Issue: 409 Conflict error

**Symptoms:** Cannot create new consultation

**Solution:** Handle existing consultation properly

```swift
if httpResponse.statusCode == 409 {
    let errorResponse = try JSONDecoder().decode(ConflictErrorResponse.self, from: data)
    print("ℹ️ Using existing consultation: \(errorResponse.error.details.existingConsultationID)")
    return try await fetchConsultation(id: errorResponse.error.details.existingConsultationID)
}
```

### Issue: 429 Too Many Requests

**Symptoms:** Cannot create consultation

**Solution:** User has 10+ active consultations

```swift
if httpResponse.statusCode == 429 {
    // Show alert to user
    showAlert(
        title: "Too Many Active Chats",
        message: "You have reached the maximum of 10 active consultations. Please complete some before starting new ones."
    )
}
```

---

## 📚 Additional Resources

### API Documentation
- OpenAPI Spec: `docs/swagger-consultations.yaml`
- Backend Guide: `CONSULTATION_API_IMPROVEMENTS_NEEDED.md`

### Example Apps
- Swift Chat Example: (Link to repository)
- SwiftUI Consultation Demo: (Link to repository)

### Support
- Backend API Issues: GitHub Issues
- iOS Integration Help: Slack #ios-dev
- General Questions: api@fitiq.com

---

## 🎯 Quick Reference

### Essential URLs
```swift
// Production
let baseURL = "https://fit-iq-backend.fly.dev"
let wsBaseURL = "wss://fit-iq-backend.fly.dev"

// Endpoints
POST   /api/v1/consultations              // Create consultation
GET    /api/v1/consultations/{id}         // Get consultation
GET    /api/v1/consultations/{id}/messages // Get message history
GET    /api/v1/consultations/{id}/ws      // WebSocket connection
```

### Key Concepts
- ✅ Always lowercase consultation IDs
- ✅ Handle 409 conflicts gracefully
- ✅ Max 10 active consultations per user
- ✅ WebSocket auto-reconnects on failure
- ✅ AI responses stream in real-time
- ✅ Use JWT + API Key authentication

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-29  
**Status:** Production Ready ✅
