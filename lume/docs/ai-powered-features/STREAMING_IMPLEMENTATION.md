# Streaming Chat Implementation Guide

## Overview

This document explains the streaming chat implementation in the Lume iOS app, which provides real-time AI responses with character-by-character streaming.

## Architecture

The streaming implementation follows Lume's Hexagonal Architecture:

```
ChatView (UI)
    ↓
ChatViewModel (Presentation)
    ↓
ChatService (Service Layer)
    ↓
ChatBackendService (Infrastructure)
    ↓
WebSocket Connection → Backend
```

## Key Components

### 1. ChatBackendService (Infrastructure)

**Location:** `lume/Services/Backend/ChatBackendService.swift`

**Responsibilities:**
- Manages WebSocket connection to backend
- Handles streaming message chunks (`stream_chunk`)
- Accumulates chunks into complete messages
- Notifies handlers when streaming is complete

**Key Features:**

```swift
// Streaming state tracking
private var currentStreamingMessage: ChatMessage?
private var currentStreamingContent: String = ""

// Message handler callback
private var messageHandler: ((ChatMessage) -> Void)?
```

**Supported WebSocket Message Types:**

| Type | Description | Handling |
|------|-------------|----------|
| `connected` | Initial connection confirmation | Logs confirmation |
| `message_received` | Server acknowledges user message | Logs acknowledgment |
| `stream_chunk` | AI response chunk (streaming) | Accumulates content |
| `stream_complete` | AI response finished | Finalizes message |
| `message` | Complete message (non-streaming) | Delivers to handler |
| `error` | Error from server | Reports to status handler |
| `pong` | Keep-alive response | Logs heartbeat |

### 2. Message Flow

#### Sending a Message

```
User types message
    ↓
ChatViewModel.sendMessage()
    ↓
ChatService.sendMessageStreaming()
    ↓
ChatBackendService.sendMessageViaWebSocket()
    ↓
WebSocket → Backend
```

#### Receiving Streaming Response

```
Backend starts AI processing
    ↓
WebSocket sends "message_received"
    ↓
Backend sends multiple "stream_chunk" messages
    ↓
ChatBackendService accumulates chunks
    ↓
messageHandler called for each chunk
    ↓
ChatViewModel updates UI in real-time
    ↓
Backend sends "stream_complete"
    ↓
Message finalized and marked as complete
```

### 3. Data Models

#### ChatMessage (Domain Entity)

```swift
struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let conversationId: UUID
    let role: MessageRole
    var content: String  // Mutable for streaming updates
    let timestamp: Date
    var metadata: MessageMetadata?  // Mutable for streaming flag
}
```

#### MessageMetadata

```swift
struct MessageMetadata: Codable, Equatable, Hashable {
    let persona: ChatPersona?
    let context: [String: String]?
    let tokens: Int?
    let processingTime: Double?
    var isStreaming: Bool  // Indicates if message is being streamed
}
```

#### WebSocketMessageWrapper (DTO)

```swift
struct WebSocketMessageWrapper: Decodable {
    let type: String
    let message: WebSocketMessageDTO?
    let consultation_id: String?
    let content: String?  // For stream_chunk messages
    let timestamp: String?
    let error: String?
}
```

## Implementation Details

### Streaming Logic in ChatBackendService

```swift
case "stream_chunk":
    if let content = wrapper.content {
        currentStreamingContent += content
        
        if currentStreamingMessage == nil {
            // Create new streaming message
            let consultationId = UUID(uuidString: wrapper.consultation_id ?? "") ?? UUID()
            currentStreamingMessage = ChatMessage(
                id: UUID(),
                conversationId: consultationId,
                role: .assistant,
                content: currentStreamingContent,
                timestamp: Date(),
                metadata: MessageMetadata(isStreaming: true)
            )
        } else {
            // Update existing streaming message
            currentStreamingMessage?.content = currentStreamingContent
        }
        
        // Notify handler with updated streaming message
        if let message = currentStreamingMessage {
            messageHandler?(message)
        }
    }

case "stream_complete":
    if var finalMessage = currentStreamingMessage {
        // Mark as not streaming
        finalMessage.metadata?.isStreaming = false
        messageHandler?(finalMessage)
    }
    
    // Reset streaming state
    currentStreamingMessage = nil
    currentStreamingContent = ""
```

### ChatViewModel Integration

The `ChatViewModel` already has WebSocket connection support via `connectWebSocket()`:

```swift
private func connectWebSocket(for conversationId: UUID) async {
    try await chatService.connectWebSocket(
        conversationId: conversationId,
        onMessage: { [weak self] message in
            Task { @MainActor in
                self?.handleIncomingMessage(message)
            }
        },
        onError: { [weak self] error in
            // Handle error and fallback to polling
        },
        onDisconnect: { [weak self] in
            // Handle disconnection
        }
    )
}
```

The `handleIncomingMessage` method processes each streaming update:

```swift
private func handleIncomingMessage(_ message: ChatMessage) {
    guard let conversation = currentConversation,
        message.conversationId == conversation.id
    else {
        return
    }
    
    if message.metadata?.isStreaming == true {
        // Update existing streaming message in UI
        if let index = messages.lastIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            // Add new streaming message
            messages.append(message)
        }
    } else {
        // Add or update completed message
        if !messages.contains(where: { $0.id == message.id }) {
            messages.append(message)
            messages.sort { $0.timestamp < $1.timestamp }
        }
    }
}
```

## UI Updates

The SwiftUI views automatically update when `messages` array changes because `ChatViewModel` uses `@Observable`:

```swift
@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    // ...
}
```

### Showing Streaming Indicator

You can detect streaming messages in your view:

```swift
ForEach(viewModel.messages) { message in
    MessageBubble(message: message)
        .overlay(
            Group {
                if message.metadata?.isStreaming == true {
                    TypingIndicator()
                }
            }
        )
}
```

## Error Handling

### Connection Errors

```swift
case "error":
    print("❌ [ChatBackendService] WebSocket error from server: \(wrapper.error ?? "unknown")")
    connectionStatusHandler?(.error(WebSocketError.messageDecodingFailed))
```

### Fallback to Polling

If WebSocket connection fails, `ChatViewModel` automatically falls back to polling:

```swift
private func startPollingFallback(for conversationId: UUID) async {
    guard !isPolling else { return }
    
    isPolling = true
    print("🔄 [ChatViewModel] Starting message polling fallback")
    
    pollingTask = Task { [weak self] in
        while !Task.isCancelled {
            await self?.pollForNewMessages(conversationId: conversationId)
            try? await Task.sleep(nanoseconds: UInt64(self?.pollingInterval ?? 3.0 * 1_000_000_000))
        }
    }
}
```

## Testing

### Unit Test Example

```swift
func testStreamingMessageAccumulation() async {
    let service = ChatBackendService()
    var receivedMessages: [ChatMessage] = []
    
    service.setMessageHandler { message in
        receivedMessages.append(message)
    }
    
    // Simulate stream chunks
    let chunk1 = """
    {"type":"stream_chunk","content":"Hello ","consultation_id":"test-id","timestamp":"2025-01-29T10:00:00Z"}
    """
    let chunk2 = """
    {"type":"stream_chunk","content":"world!","consultation_id":"test-id","timestamp":"2025-01-29T10:00:01Z"}
    """
    let complete = """
    {"type":"stream_complete","consultation_id":"test-id","timestamp":"2025-01-29T10:00:02Z"}
    """
    
    // Process chunks
    service.handleTextMessage(chunk1)
    service.handleTextMessage(chunk2)
    service.handleTextMessage(complete)
    
    // Verify
    XCTAssertEqual(receivedMessages.count, 3)  // 2 streaming updates + 1 complete
    XCTAssertEqual(receivedMessages.last?.content, "Hello world!")
    XCTAssertFalse(receivedMessages.last?.metadata?.isStreaming ?? true)
}
```

## Best Practices

### 1. Memory Management

```swift
deinit {
    pollingTask?.cancel()
    chatService.disconnectWebSocket()
}
```

Always clean up WebSocket connections and polling tasks when view models are deallocated.

### 2. Thread Safety

All UI updates must happen on the main actor:

```swift
Task { @MainActor in
    self?.handleIncomingMessage(message)
}
```

### 3. Message Deduplication

Check for existing messages before adding:

```swift
if !messages.contains(where: { $0.id == message.id }) {
    messages.append(message)
}
```

### 4. Connection Status

Track connection status for UI feedback:

```swift
@Published var connectionStatus: ConnectionStatus = .disconnected

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
}
```

## Troubleshooting

### Issue: Messages not streaming

**Check:**
1. WebSocket connection is established
2. Message handler is set before connecting
3. Backend is sending `stream_chunk` messages

**Debug:**
```swift
print("📥 [ChatBackendService] Received: \(text)")
```

### Issue: Duplicate messages

**Solution:**
Implement message deduplication:
```swift
if !messages.contains(where: { $0.id == message.id }) {
    messages.append(message)
}
```

### Issue: UI not updating

**Check:**
1. ViewModel is marked with `@Observable`
2. Properties are being mutated on `@MainActor`
3. Array mutations trigger SwiftUI updates

## Related Documentation

- [Consultation Live Chat Guide](./CONSULTATION_LIVE_CHAT_GUIDE.md) - Backend integration reference
- [WebSocket Polling Implementation](./WEBSOCKET_POLLING_IMPLEMENTATION.md) - Polling fallback details
- [AI Features Design](./AI_FEATURES_DESIGN.md) - Overall architecture

## Summary

The streaming implementation provides:

✅ Real-time AI response streaming  
✅ Character-by-character content updates  
✅ Automatic polling fallback  
✅ Proper error handling  
✅ Clean architecture separation  
✅ Thread-safe UI updates  

All changes follow Lume's architectural principles and maintain the warm, calm user experience.
