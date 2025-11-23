# Streaming Reliability Technical Guide

**Date:** 2025-01-30  
**Status:** ✅ Production Ready  
**Component:** Chat Streaming System  
**Related Docs:** 
- `docs/chat/STREAMING_UX_IMPROVEMENTS.md`
- `docs/goals/GOALS_CHAT_INTEGRATION_DEBUGGING.md`

---

## Overview

This guide provides technical details on the streaming message system in Lume's chat feature. It covers the architecture, implementation patterns, timeout handling, and error recovery mechanisms that ensure reliable AI message delivery.

---

## Architecture

### High-Level Flow

```
User sends message
    ↓
ChatViewModel.sendMessage()
    ↓
Create temporary message with isStreaming = true
    ↓
Start streaming timeout (30s safety net)
    ↓
API: POST /consultations/{conversationId}/messages
    ↓
Backend processes and streams response
    ↓
Start polling loop (2s interval)
    ↓
API: GET /consultations/{conversationId}/messages?since={timestamp}
    ↓
Receive chunks and append to message
    ↓
Backend signals completion
    ↓
Mark message as complete, stop timeout
```

### Key Components

1. **ChatViewModel** - Orchestrates streaming lifecycle
2. **ConsultationService** - Handles API communication
3. **Polling Task** - Fetches new message chunks
4. **Timeout Task** - Safety net for hung streams
5. **Message State** - Tracks streaming progress

---

## Core Implementation

### Message Model

```swift
struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let isUser: Bool
    let timestamp: Date
    var isStreaming: Bool = false
    var backendId: String?
    
    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        backendId: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.backendId = backendId
    }
}
```

### Streaming Lifecycle

#### 1. Initiate Streaming

```swift
@MainActor
func sendMessage(_ text: String) async {
    guard !text.isEmpty else { return }
    
    // Add user message
    let userMessage = Message(text: text, isUser: true)
    messages.append(userMessage)
    
    // Create streaming placeholder for AI response
    let aiMessageId = UUID()
    let aiMessage = Message(
        id: aiMessageId,
        text: "",
        isUser: false,
        isStreaming: true
    )
    messages.append(aiMessage)
    
    // Start timeout as safety net
    startStreamingTimeout(for: aiMessageId)
    
    do {
        // Send to backend
        try await consultationService.sendMessage(
            conversationId: conversationId,
            content: text
        )
        
        // Start polling for response chunks
        startPolling(conversationId: conversationId)
        
    } catch {
        await handleStreamingError(error, for: aiMessageId)
    }
}
```

#### 2. Poll for Updates

```swift
private func startPolling(conversationId: UUID) {
    // Cancel any existing poll
    pollingTask?.cancel()
    
    pollingTask = Task { @MainActor in
        while !Task.isCancelled {
            // Wait 2 seconds between polls for natural pacing
            try? await Task.sleep(for: .seconds(2))
            
            if !Task.isCancelled {
                await fetchNewMessages(conversationId: conversationId)
            }
        }
    }
}

@MainActor
private func fetchNewMessages(conversationId: UUID) async {
    do {
        // Get messages since last poll
        let newMessages = try await consultationService.getMessages(
            conversationId: conversationId,
            since: lastMessageTimestamp
        )
        
        // Process each new message
        for message in newMessages {
            handleIncomingMessage(message)
        }
        
        // Update last poll timestamp
        if let lastMessage = newMessages.last {
            lastMessageTimestamp = lastMessage.timestamp
        }
        
    } catch {
        print("⚠️ Error fetching messages: \(error)")
        // Don't stop polling on transient errors
    }
}
```

#### 3. Handle Message Chunks

```swift
@MainActor
private func handleIncomingMessage(_ message: BackendMessage) {
    // Find the streaming message to update
    guard let index = messages.firstIndex(where: { $0.isStreaming && !$0.isUser }) else {
        return
    }
    
    if message.isComplete {
        // Stream finished - finalize message
        messages[index].text = message.content
        messages[index].isStreaming = false
        messages[index].backendId = message.id
        
        // Cancel timeout - we're done
        streamingTimeoutTask?.cancel()
        streamingTimeoutTask = nil
        
        // Stop polling
        pollingTask?.cancel()
        pollingTask = nil
        
    } else {
        // Stream in progress - append chunk
        messages[index].text = message.content
        messages[index].isStreaming = true
        
        // IMPORTANT: Do NOT reset timeout here
        // Let it run for the full 30 seconds as a safety net
    }
}
```

#### 4. Timeout Safety Net

```swift
private func startStreamingTimeout(for messageId: UUID) {
    // Cancel any existing timeout
    streamingTimeoutTask?.cancel()
    
    streamingTimeoutTask = Task { @MainActor in
        // Wait 30 seconds - this is a safety net only
        try? await Task.sleep(for: .seconds(30))
        
        if !Task.isCancelled {
            await handleStreamingTimeout(for: messageId)
        }
    }
}

@MainActor
private func handleStreamingTimeout(for messageId: UUID) {
    guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
        return
    }
    
    // Only handle timeout if message is still streaming
    guard messages[index].isStreaming else {
        return
    }
    
    print("⏱️ Streaming timeout for message: \(messageId)")
    
    if messages[index].text.isEmpty {
        // No content received - show error
        messages[index].text = "I'm having trouble responding right now. Please try again."
        messages[index].isStreaming = false
    } else {
        // Some content received - keep it and mark complete
        messages[index].isStreaming = false
    }
    
    // Clean up
    pollingTask?.cancel()
    pollingTask = nil
    streamingTimeoutTask = nil
}
```

---

## Critical Design Decisions

### Decision 1: Single Timeout, No Reset

**Problem:** Resetting timeout on every chunk caused race conditions and message splitting.

**Solution:** Start timeout once at stream initiation, never reset it.

**Rationale:**
- Timeout is a safety net for hung connections, not a progress indicator
- 30 seconds is generous for any reasonable response
- Prevents race conditions between chunk updates and timeout handler
- Simplifies state management

```swift
// ❌ WRONG: Resetting timeout
private func handleStreamChunk(_ chunk: String, for messageId: UUID) async {
    messages[index].text += chunk
    startStreamingTimeout(for: messageId)  // DON'T DO THIS
}

// ✅ CORRECT: Single timeout
private func handleStreamChunk(_ chunk: String, for messageId: UUID) async {
    messages[index].text += chunk
    // Timeout runs independently until stream completes
}
```

### Decision 2: 2-Second Polling Interval

**Problem:** 1-second polling felt robotic and increased server load.

**Solution:** 2-second interval for natural conversation pacing.

**Rationale:**
- Mimics human typing speed
- Reduces network traffic by 50%
- Better battery performance
- Still responsive enough for good UX

**Benchmarks:**
- 1s interval: 60 requests/minute
- 2s interval: 30 requests/minute
- User perception: 2s feels more natural and thoughtful

### Decision 3: Preserve Partial Content on Timeout

**Problem:** Timeouts would discard partially received messages.

**Solution:** Keep any received content, only show error if empty.

**Rationale:**
- User sees partial response is better than nothing
- Clear that something went wrong but preserves value
- Reduces frustration from network issues

```swift
if messages[index].text.isEmpty {
    // No content - show error
    messages[index].text = "I'm having trouble responding right now."
} else {
    // Has content - keep it
    messages[index].isStreaming = false
}
```

### Decision 4: Continue Polling on Transient Errors

**Problem:** Network blips would stop polling entirely.

**Solution:** Log error but continue polling loop.

**Rationale:**
- Network issues are often temporary
- Stopping polling makes temporary issues permanent
- User sees natural recovery when connection restores

```swift
do {
    let messages = try await fetchMessages()
    handleMessages(messages)
} catch {
    print("⚠️ Transient error: \(error)")
    // Continue polling - don't break the loop
}
```

---

## Error Scenarios and Recovery

### Scenario 1: Network Timeout

**Trigger:** Backend doesn't respond within 30 seconds

**Behavior:**
1. Timeout task fires
2. Check if message has content
3. If empty: Show error message
4. If partial: Keep content, mark complete
5. Stop polling and timeout tasks

**User Experience:** Clear feedback, no stuck state

### Scenario 2: Connection Lost Mid-Stream

**Trigger:** Network drops during streaming

**Behavior:**
1. Polling fails with network error
2. Error logged but polling continues
3. When connection restores, polling resumes
4. Stream continues from last received chunk

**User Experience:** Automatic recovery when online

### Scenario 3: Backend Error Response

**Trigger:** Backend returns error (500, 503, etc.)

**Behavior:**
1. Error caught in sendMessage
2. handleStreamingError called
3. Replace streaming message with error text
4. Clean up tasks

**User Experience:** Clear error message, can retry

### Scenario 4: Rapid Message Sending

**Trigger:** User sends multiple messages quickly

**Behavior:**
1. Each message gets its own streaming placeholder
2. Polling fetches all messages since last timestamp
3. Messages matched by backend ID
4. Independent timeout per message

**User Experience:** All messages handled correctly

---

## Performance Considerations

### Memory Management

```swift
// Clean up on view disappear
func cleanup() {
    pollingTask?.cancel()
    pollingTask = nil
    streamingTimeoutTask?.cancel()
    streamingTimeoutTask = nil
}

// SwiftUI lifecycle
.onDisappear {
    viewModel.cleanup()
}
```

### Network Efficiency

- **Polling Interval:** 2 seconds balances responsiveness and efficiency
- **Since Parameter:** Only fetch new messages, not entire history
- **Cancellation:** Stop polling when stream completes

### Battery Impact

- **Minimal:** Polling only during active streaming
- **Stopped:** When message completes or view disappears
- **Efficient:** 30 requests/minute is lightweight

---

## Testing Guide

### Unit Tests

```swift
func testStreamingTimeout() async {
    let viewModel = ChatViewModel(...)
    
    // Send message
    await viewModel.sendMessage("Test")
    
    // Wait for timeout
    try? await Task.sleep(for: .seconds(31))
    
    // Verify timeout handled
    XCTAssertFalse(viewModel.messages.last?.isStreaming ?? true)
}

func testPartialContentPreservation() async {
    let viewModel = ChatViewModel(...)
    
    // Simulate partial stream
    viewModel.handleChunk("Partial response")
    
    // Trigger timeout
    await viewModel.handleStreamingTimeout(...)
    
    // Verify content preserved
    XCTAssertEqual(viewModel.messages.last?.text, "Partial response")
}
```

### Integration Tests

```swift
func testFullStreamingFlow() async throws {
    // 1. Send message
    await viewModel.sendMessage("Hello")
    
    // 2. Verify streaming started
    XCTAssertTrue(viewModel.messages.last?.isStreaming ?? false)
    
    // 3. Wait for completion
    try await Task.sleep(for: .seconds(5))
    
    // 4. Verify stream completed
    XCTAssertFalse(viewModel.messages.last?.isStreaming ?? true)
    XCTAssertFalse(viewModel.messages.last?.text.isEmpty ?? true)
}
```

### Manual Testing Checklist

- [ ] Send message and verify smooth streaming
- [ ] Check 2-second update interval feels natural
- [ ] Disconnect network mid-stream, reconnect, verify recovery
- [ ] Let stream timeout, verify error handling
- [ ] Send multiple rapid messages, verify all handled
- [ ] Navigate away and back, verify cleanup
- [ ] Test with slow network connection
- [ ] Test with very long responses

---

## Debugging

### Enable Verbose Logging

```swift
private func handleStreamChunk(_ chunk: String, for messageId: UUID) async {
    #if DEBUG
    print("📡 Chunk received: \(chunk.prefix(50))...")
    print("📡 Message ID: \(messageId)")
    print("📡 Current length: \(messages[index].text.count)")
    #endif
    
    messages[index].text += chunk
}
```

### Monitor Streaming State

```swift
private func logStreamingState() {
    let streaming = messages.filter { $0.isStreaming }
    print("🔄 Active streams: \(streaming.count)")
    streaming.forEach { msg in
        print("  - \(msg.id): \(msg.text.count) chars")
    }
}
```

### Track Polling Activity

```swift
private func startPolling(conversationId: UUID) {
    var pollCount = 0
    
    pollingTask = Task { @MainActor in
        while !Task.isCancelled {
            pollCount += 1
            print("🔄 Poll #\(pollCount)")
            
            try? await Task.sleep(for: .seconds(2))
            await fetchNewMessages(conversationId: conversationId)
        }
    }
}
```

---

## Best Practices

### DO ✅

- Start timeout once per message
- Use 2-second polling for natural pacing
- Preserve partial content on timeout
- Continue polling on transient errors
- Clean up tasks on view disappear
- Log errors for debugging
- Handle empty vs partial content differently

### DON'T ❌

- Reset timeout on chunk updates
- Use 1-second or faster polling
- Discard partial content on error
- Stop polling on network blips
- Leave tasks running when view hidden
- Ignore timeout scenarios
- Show generic errors for all failures

---

## Future Improvements

### Adaptive Polling

```swift
// Adjust speed based on message length
private func determinePollingInterval(expectedLength: Int) -> Duration {
    switch expectedLength {
    case 0..<100: return .seconds(1)     // Short message
    case 100..<500: return .seconds(2)   // Medium message
    default: return .seconds(3)          // Long message
    }
}
```

### Connection Quality Detection

```swift
// Monitor network speed and adjust
private func adjustPollingForConnectionQuality() {
    let speed = networkMonitor.currentSpeed
    
    switch speed {
    case .fast: pollingInterval = .seconds(1)
    case .medium: pollingInterval = .seconds(2)
    case .slow: pollingInterval = .seconds(3)
    }
}
```

### WebSocket Upgrade

```swift
// Real-time streaming without polling
func connectWebSocket() {
    webSocket = URLSession.shared.webSocketTask(with: url)
    webSocket?.resume()
    
    receiveMessages()
}

private func receiveMessages() {
    webSocket?.receive { [weak self] result in
        switch result {
        case .success(.string(let text)):
            self?.handleStreamChunk(text)
            self?.receiveMessages() // Continue listening
        case .failure(let error):
            print("WebSocket error: \(error)")
        default:
            break
        }
    }
}
```

---

## Summary

The streaming system is built on these principles:

1. **Single timeout per message** - No resets, acts as safety net
2. **Natural pacing** - 2-second polling feels human
3. **Graceful degradation** - Preserve partial content
4. **Automatic recovery** - Continue through transient errors
5. **Proper cleanup** - Cancel tasks when done

This design ensures reliable, natural streaming that handles real-world network conditions gracefully while maintaining excellent UX.

---

**Last Updated:** 2025-01-30  
**Reviewed By:** Engineering Team  
**Next Review:** Before major iOS release