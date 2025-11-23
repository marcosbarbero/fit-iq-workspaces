# 🔌 FitIQ iOS WebSocket Guide

**Backend Version:** 0.22.0  
**WebSocket URL:** `wss://fit-iq-backend.fly.dev/ws/consultation`  
**Last Updated:** 2025-01-27  
**Purpose:** Real-time AI consultation streaming for iOS

---

## 📋 Overview

This guide covers **WebSocket integration** for real-time AI consultation, including:

- ✅ WebSocket connection setup
- ✅ Real-time message streaming
- ✅ Connection management (reconnect, heartbeat)
- ✅ AI consultation flow
- ✅ Template creation during chat
- ✅ Complete Swift examples with Starscream
- ✅ Error handling and retry logic

---

## 🎯 Why WebSocket?

**REST API Limitations:**
- ❌ Polling required for new messages
- ❌ High latency
- ❌ No streaming responses
- ❌ Poor battery life

**WebSocket Benefits:**
- ✅ Real-time bidirectional communication
- ✅ Streaming AI responses (word-by-word)
- ✅ Low latency
- ✅ Efficient (single connection)
- ✅ Better UX (typing indicators, instant responses)

---

## 🚀 Setup

### Install Starscream

**Using Swift Package Manager:**

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
]
```

**Or in Xcode:**
1. File → Add Packages
2. Search: `https://github.com/daltoniam/Starscream.git`
3. Add to your target

---

## 🔐 Authentication

WebSocket requires **JWT token** and **API key** for authentication:

```
wss://fit-iq-backend.fly.dev/ws/consultation?consultation_id={id}&token={jwt}
```

**Headers:**
```
X-API-Key: YOUR_API_KEY
```

---

## 📡 WebSocket Manager

### Complete Implementation

```swift
import Foundation
import Starscream
import Combine

class ConsultationWebSocketManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var messages: [ConsultationMessage] = []
    @Published var isAITyping = false
    @Published var connectionError: String?
    
    // MARK: - Private Properties
    
    private var webSocket: WebSocket?
    private let consultationId: String
    private let apiKey: String
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var heartbeatTimer: Timer?
    
    // MARK: - Init
    
    init(consultationId: String, apiKey: String) {
        self.consultationId = consultationId
        self.apiKey = apiKey
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard let token = try? KeychainHelper.loadString(for: "fitiq_access_token") else {
            connectionError = "No authentication token"
            return
        }
        
        var urlComponents = URLComponents(string: "wss://fit-iq-backend.fly.dev/ws/consultation")!
        urlComponents.queryItems = [
            URLQueryItem(name: "consultation_id", value: consultationId),
            URLQueryItem(name: "token", value: token)
        ]
        
        guard let url = urlComponents.url else {
            connectionError = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10
        
        webSocket = WebSocket(request: request)
        webSocket?.delegate = self
        webSocket?.connect()
        
        print("🔌 Connecting to WebSocket...")
    }
    
    func disconnect() {
        stopHeartbeat()
        webSocket?.disconnect()
        webSocket = nil
        isConnected = false
        print("🔌 Disconnected from WebSocket")
    }
    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionError = "Max reconnection attempts reached"
            return
        }
        
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Exponential backoff, max 30s
        
        print("🔄 Reconnecting in \(delay) seconds... (attempt \(reconnectAttempts))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
    
    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        let ping = WebSocketMessage(
            type: "ping",
            content: nil,
            messageId: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        sendMessage(ping)
    }
    
    // MARK: - Send Messages
    
    func sendUserMessage(_ content: String) {
        let message = WebSocketMessage(
            type: "user_message",
            content: content,
            messageId: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        // Add to UI immediately
        let displayMessage = ConsultationMessage(
            id: message.messageId,
            role: "user",
            content: content,
            timestamp: Date()
        )
        messages.append(displayMessage)
        
        sendMessage(message)
    }
    
    private func sendMessage(_ message: WebSocketMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8) else {
            print("❌ Failed to encode message")
            return
        }
        
        webSocket?.write(string: string)
    }
    
    // MARK: - Handle Received Messages
    
    private func handleReceivedMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(WebSocketMessage.self, from: data) else {
            print("❌ Failed to decode message: \(text)")
            return
        }
        
        switch message.type {
        case "ai_message_start":
            // AI is starting to respond
            isAITyping = true
            
            // Create placeholder message
            let displayMessage = ConsultationMessage(
                id: message.messageId,
                role: "assistant",
                content: "",
                timestamp: Date(),
                isStreaming: true
            )
            messages.append(displayMessage)
            
        case "ai_message_chunk":
            // AI is streaming content
            guard let content = message.content,
                  let index = messages.firstIndex(where: { $0.id == message.messageId }) else {
                return
            }
            
            messages[index].content += content
            
        case "ai_message_complete":
            // AI finished responding
            isAITyping = false
            
            if let index = messages.firstIndex(where: { $0.id == message.messageId }) {
                messages[index].isStreaming = false
            }
            
        case "template_created":
            // AI created a template
            handleTemplateCreated(message)
            
        case "error":
            // Error occurred
            connectionError = message.content ?? "Unknown error"
            print("❌ Error: \(message.content ?? "unknown")")
            
        case "pong":
            // Heartbeat response
            print("💓 Heartbeat received")
            
        default:
            print("⚠️ Unknown message type: \(message.type)")
        }
    }
    
    private func handleTemplateCreated(_ message: WebSocketMessage) {
        guard let templateData = message.metadata,
              let data = try? JSONSerialization.data(withJSONObject: templateData),
              let template = try? JSONDecoder().decode(CreatedTemplate.self, from: data) else {
            print("❌ Failed to decode template")
            return
        }
        
        // Add template notification to chat
        let displayMessage = ConsultationMessage(
            id: message.messageId,
            role: "system",
            content: "Created \(template.type) template: \(template.name)",
            timestamp: Date(),
            template: template
        )
        messages.append(displayMessage)
        
        print("✅ Template created: \(template.name)")
    }
}

// MARK: - WebSocketDelegate

extension ConsultationWebSocketManager: WebSocketDelegate {
    
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("✅ WebSocket connected")
            print("Headers: \(headers)")
            isConnected = true
            connectionError = nil
            reconnectAttempts = 0
            startHeartbeat()
            
        case .disconnected(let reason, let code):
            print("❌ WebSocket disconnected: \(reason) (code: \(code))")
            isConnected = false
            stopHeartbeat()
            
            // Attempt reconnect if not intentional
            if code != CloseCode.normal.rawValue {
                reconnect()
            }
            
        case .text(let string):
            handleReceivedMessage(string)
            
        case .binary(let data):
            print("⚠️ Received binary data: \(data.count) bytes")
            
        case .ping(_):
            print("💓 Received ping")
            
        case .pong(_):
            print("💓 Received pong")
            
        case .viabilityChanged(let viable):
            print("🔄 Viability changed: \(viable)")
            
        case .reconnectSuggested(let suggested):
            if suggested {
                reconnect()
            }
            
        case .cancelled:
            print("🚫 WebSocket cancelled")
            isConnected = false
            
        case .error(let error):
            print("❌ WebSocket error: \(error?.localizedDescription ?? "unknown")")
            connectionError = error?.localizedDescription
            isConnected = false
            reconnect()
            
        case .peerClosed:
            print("🔌 Peer closed connection")
            isConnected = false
        }
    }
}

// MARK: - Models

struct WebSocketMessage: Codable {
    let type: String
    let content: String?
    let messageId: String
    let timestamp: String
    let metadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case type, content, messageId, timestamp, metadata
    }
    
    init(type: String, content: String?, messageId: String, timestamp: String, metadata: [String: Any]? = nil) {
        self.type = type
        self.content = content
        self.messageId = messageId
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        messageId = try container.decode(String.self, forKey: .messageId)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        
        if let metadataData = try? container.decodeIfPresent(Data.self, forKey: .metadata),
           let metadataDict = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
            metadata = metadataDict
        } else {
            metadata = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(timestamp, forKey: .timestamp)
        
        if let metadata = metadata,
           let data = try? JSONSerialization.data(withJSONObject: metadata) {
            try container.encode(data, forKey: .metadata)
        }
    }
}

struct ConsultationMessage: Identifiable {
    let id: String
    let role: String // "user", "assistant", "system"
    var content: String
    let timestamp: Date
    var isStreaming: Bool = false
    var template: CreatedTemplate?
}

struct CreatedTemplate: Codable {
    let id: String
    let type: String // "meal", "workout", "wellness"
    let name: String
    let description: String?
}
```

---

## 🎨 SwiftUI Chat View

### Complete Chat Interface

```swift
import SwiftUI

struct ConsultationChatView: View {
    
    @StateObject private var websocketManager: ConsultationWebSocketManager
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    
    let consultationId: String
    let userId: String
    
    init(consultationId: String, userId: String) {
        self.consultationId = consultationId
        self.userId = userId
        _websocketManager = StateObject(wrappedValue: ConsultationWebSocketManager(
            consultationId: consultationId,
            apiKey: "YOUR_API_KEY"
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Health Coach")
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(websocketManager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(websocketManager.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { websocketManager.disconnect() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(radius: 2)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(websocketManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if websocketManager.isAITyping {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: websocketManager.messages.count) { _ in
                    if let lastMessage = websocketManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input bar
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!websocketManager.isConnected)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty || !websocketManager.isConnected)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .onAppear {
            websocketManager.connect()
        }
        .onDisappear {
            websocketManager.disconnect()
        }
        .alert("Connection Error", isPresented: .constant(websocketManager.connectionError != nil)) {
            Button("Retry") {
                websocketManager.connect()
            }
            Button("Cancel", role: .cancel) {
                websocketManager.connectionError = nil
            }
        } message: {
            Text(websocketManager.connectionError ?? "")
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        websocketManager.sendUserMessage(messageText)
        messageText = ""
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConsultationMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                
                if let template = message.template {
                    TemplateCard(template: template)
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role != "user" {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case "user":
            return .blue
        case "assistant":
            return Color(.systemGray5)
        default:
            return Color(.systemGray6)
        }
    }
    
    private var textColor: Color {
        message.role == "user" ? .white : .primary
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: CreatedTemplate
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: iconName)
                        .foregroundColor(.blue)
                    
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                if let description = template.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(template.type.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Tap to view")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .sheet(isPresented: $showingDetails) {
            TemplateDetailsView(templateId: template.id, type: template.type)
        }
    }
    
    private var iconName: String {
        switch template.type {
        case "meal":
            return "fork.knife"
        case "workout":
            return "dumbbell.fill"
        case "wellness":
            return "heart.fill"
        default:
            return "doc.fill"
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(12)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            
            Spacer()
        }
        .onAppear {
            animating = true
        }
    }
}
```

---

## 🔄 Message Flow

### User Sends Message

```
Client → Server:
{
  "type": "user_message",
  "content": "I want to lose weight",
  "message_id": "msg_123",
  "timestamp": "2025-01-27T10:00:00Z"
}
```

### AI Starts Responding

```
Server → Client:
{
  "type": "ai_message_start",
  "message_id": "msg_456",
  "timestamp": "2025-01-27T10:00:01Z"
}
```

### AI Streams Content

```
Server → Client (multiple times):
{
  "type": "ai_message_chunk",
  "content": "I can help you with that! ",
  "message_id": "msg_456",
  "timestamp": "2025-01-27T10:00:01Z"
}

{
  "type": "ai_message_chunk",
  "content": "Let me create a personalized meal plan ",
  "message_id": "msg_456",
  "timestamp": "2025-01-27T10:00:02Z"
}
```

### AI Completes Message

```
Server → Client:
{
  "type": "ai_message_complete",
  "message_id": "msg_456",
  "timestamp": "2025-01-27T10:00:05Z"
}
```

### AI Creates Template

```
Server → Client:
{
  "type": "template_created",
  "message_id": "msg_789",
  "timestamp": "2025-01-27T10:00:06Z",
  "metadata": {
    "template_id": "tmpl_abc",
    "type": "meal",
    "name": "1800 Calorie Weight Loss Plan",
    "description": "Balanced meal plan for gradual weight loss"
  }
}
```

---

## 🛡️ Error Handling

### Connection Errors

```swift
extension ConsultationWebSocketManager {
    
    func handleConnectionError(_ error: Error?) {
        guard let error = error else { return }
        
        if let wsError = error as? WSError {
            switch wsError.code {
            case 401:
                connectionError = "Authentication failed. Please login again."
                // Force logout
                Task {
                    await AuthManager.shared.logout()
                }
                
            case 403:
                connectionError = "Access denied to this consultation."
                
            case 404:
                connectionError = "Consultation not found."
                
            case 500...599:
                connectionError = "Server error. Retrying..."
                reconnect()
                
            default:
                connectionError = "Connection error: \(wsError.message)"
                reconnect()
            }
        } else {
            connectionError = error.localizedDescription
            reconnect()
        }
    }
}
```

### Message Validation

```swift
extension ConsultationWebSocketManager {
    
    private func validateMessage(_ message: WebSocketMessage) -> Bool {
        // Check required fields
        guard !message.messageId.isEmpty,
              !message.timestamp.isEmpty else {
            print("❌ Invalid message: missing required fields")
            return false
        }
        
        // Check message type
        let validTypes = ["user_message", "ai_message_start", "ai_message_chunk", 
                         "ai_message_complete", "template_created", "error", "ping", "pong"]
        
        guard validTypes.contains(message.type) else {
            print("❌ Invalid message type: \(message.type)")
            return false
        }
        
        return true
    }
}
```

---

## ⚡ Performance Optimization

### Message Batching

```swift
class OptimizedWebSocketManager: ConsultationWebSocketManager {
    
    private var messageQueue: [String] = []
    private var batchTimer: Timer?
    
    override func sendUserMessage(_ content: String) {
        messageQueue.append(content)
        
        // Send after short delay to batch rapid messages
        batchTimer?.invalidate()
        batchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.flushMessageQueue()
        }
    }
    
    private func flushMessageQueue() {
        guard !messageQueue.isEmpty else { return }
        
        let combinedContent = messageQueue.joined(separator: " ")
        messageQueue.removeAll()
        
        super.sendUserMessage(combinedContent)
    }
}
```

### Memory Management

```swift
extension ConsultationWebSocketManager {
    
    func trimOldMessages(keepLast: Int = 100) {
        if messages.count > keepLast {
            let excess = messages.count - keepLast
            messages.removeFirst(excess)
        }
    }
}
```

---

## 🧪 Testing

### Mock WebSocket Manager

```swift
class MockConsultationWebSocketManager: ConsultationWebSocketManager {
    
    override func connect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isConnected = true
        }
    }
    
    override func sendUserMessage(_ content: String) {
        super.sendUserMessage(content)
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.simulateAIResponse(to: content)
        }
    }
    
    private func simulateAIResponse(to userMessage: String) {
        let messageId = UUID().uuidString
        
        // Start
        let startMessage = ConsultationMessage(
            id: messageId,
            role: "assistant",
            content: "",
            timestamp: Date(),
            isStreaming: true
        )
        messages.append(startMessage)
        isAITyping = true
        
        // Stream chunks
        let response = "Thank you for your message: '\(userMessage)'. How can I help you today?"
        let chunks = response.split(separator: " ")
        
        for (index, chunk) in chunks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                    self.messages[idx].content += String(chunk) + " "
                }
            }
        }
        
        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(chunks.count) * 0.1) {
            if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                self.messages[idx].isStreaming = false
            }
            self.isAITyping = false
        }
    }
}
```

### Preview

```swift
struct ConsultationChatView_Previews: PreviewProvider {
    static var previews: some View {
        ConsultationChatView(
            consultationId: "preview_123",
            userId: "user_preview"
        )
    }
}
```

---

## 🎯 Complete Workflow

### Start Consultation Flow

```swift
class ConsultationManager {
    
    func startNewConsultation(userId: String, type: String) async throws -> String {
        // 1. Create consultation via REST API
        let request = CreateConsultationRequest(
            userId: userId,
            consultationType: type,
            initialMessage: nil
        )
        
        let consultation: Consultation = try await FitIQAPI.shared.request(
            endpoint: "/consultations",
            method: .post,
            body: request
        )
        
        // 2. Return consultation ID for WebSocket connection
        return consultation.id
    }
    
    func showConsultationChat(consultationId: String, userId: String) -> some View {
        ConsultationChatView(
            consultationId: consultationId,
            userId: userId
        )
    }
}

// Usage
Task {
    let consultationId = try await ConsultationManager().startNewConsultation(
        userId: "user_123",
        type: "nutrition"
    )
    
    // Present chat view
    let chatView = ConsultationManager().showConsultationChat(
        consultationId: consultationId,
        userId: "user_123"
    )
}
```

---

## 🔍 Debugging

### Enable Logging

```swift
extension ConsultationWebSocketManager {
    
    func enableDebugLogging() {
        webSocket?.onText = { text in
            print("📥 Received: \(text)")
        }
        
        webSocket?.onData = { data in
            print("📥 Received data: \(data.count) bytes")
        }
    }
}
```

### Connection Diagnostics

```swift
struct ConnectionDiagnostics {
    let isConnected: Bool
    let reconnectAttempts: Int
    let lastError: String?
    let messageCount: Int
    let uptime: TimeInterval
    
    static func from(_ manager: ConsultationWebSocketManager) -> ConnectionDiagnostics {
        // Implement diagnostics collection
        ConnectionDiagnostics(
            isConnected: manager.isConnected,
            reconnectAttempts: 0, // Access private property via reflection or make public
            lastError: manager.connectionError,
            messageCount: manager.messages.count,
            uptime: 0
        )
    }
}
```

---

## 📊 Best Practices

### ✅ DO

1. **Always handle reconnection** - Network drops happen
2. **Implement heartbeat** - Keep connection alive
3. **Validate messages** - Check types and required fields
4. **Show connection status** - Users need feedback
5. **Trim old messages** - Prevent memory bloat
6. **Use exponential backoff** - For reconnection attempts
7. **Handle token expiry** - Refresh and reconnect
8. **Show typing indicators** - Better UX
9. **Stream responses** - Don't wait for complete message
10. **Clean up on dismiss** - Disconnect WebSocket

### ❌ DON'T

1. **Don't ignore connection errors** - Handle gracefully
2. **Don't reconnect infinitely** - Set max attempts
3. **Don't block UI thread** - Use async operations
4. **Don't store sensitive data** - In messages
5. **Don't send messages when disconnected** - Check status
6. **Don't forget to disconnect** - On view dismiss
7. **Don't hardcode URLs** - Use configuration
8. **Don't ignore timeouts** - Set reasonable limits
9. **Don't spam messages** - Implement rate limiting
10. **Don't skip error messages** - Show to user

---

## 🚀 Advanced Features

### Voice Input Integration

```swift
import Speech

extension ConsultationChatView {
    
    func startVoiceInput() {
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechAudioBufferRecognitionRequest()
        
        recognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                self.messageText = result.bestTranscription.formattedString
            }
        }
    }
}
```

### Message Persistence

```swift
class ConsultationStorage {
    
    func saveMessages(_ messages: [ConsultationMessage], consultationId: String) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(messages) {
            UserDefaults.standard.set(data, forKey: "consultation_\(consultationId)")
        }
    }
    
    func loadMessages(consultationId: String) -> [ConsultationMessage] {
        guard let data = UserDefaults.standard.data(forKey: "consultation_\(consultationId)"),
              let messages = try? JSONDecoder().decode([ConsultationMessage].self, from: data) else {
            return []
        }
        return messages
    }
}
```

---

## 📞 Support

**WebSocket Endpoint:**
- URL: `wss://fit-iq-backend.fly.dev/ws/consultation`
- Protocol: WebSocket (RFC 6455)
- Authentication: JWT token + API key

**Documentation:**
- [Integration Roadmap](INTEGRATION_ROADMAP.md)
- [Authentication Guide](AUTHENTICATION.md)
- [API Reference](API_REFERENCE.md)

**Health Check:**
- REST: `https://fit-iq-backend.fly.dev/health`
- Swagger: `https://fit-iq-backend.fly.dev/swagger/index.html`

---

## 🎓 Summary

**WebSocket provides:**
- ✅ Real-time bidirectional communication
- ✅ Streaming AI responses
- ✅ Template creation during chat
- ✅ Low latency
- ✅ Better user experience

**Key Components:**
1. **ConsultationWebSocketManager** - Connection and message handling
2. **ConsultationChatView** - SwiftUI chat interface
3. **Message models** - Typed message structures
4. **Error handling** - Reconnection and validation
5. **Performance optimization** - Batching and memory management

**Ready to integrate AI chat into your iOS app! 🤖**