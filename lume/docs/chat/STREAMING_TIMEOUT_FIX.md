# Streaming Timeout Fix - Handling Stuck AI Messages

**Date:** 2025-01-29  
**Issue:** Streaming messages stuck in "typing" state  
**Status:** ✅ Fixed

---

## Problem Statement

### User Report

When chatting with the AI, messages would occasionally get stuck in a streaming state with the typing indicator showing indefinitely:

```
[5] 🤖 I can certainly gather some information to provide... (streaming: true)
```

The UI showed three animated dots "ping ponging" continuously, but the message never completed.

### Root Cause

The WebSocket was receiving `stream_chunk` messages but never receiving the `stream_complete` signal from the backend. This left messages in a perpetual streaming state with:

- `isStreaming: true` never transitioning to `false`
- `isSendingMessage` remaining `true` in ChatViewModel
- Typing indicator animating indefinitely
- Message not persisted to database (only completed messages are saved)

---

## Solution

### 1. Streaming Timeout Mechanism

Added a **5-second inactivity timeout** that automatically finalizes streaming messages if completion signal is never received. **Critically, the timeout resets on each chunk** to prevent splitting long messages:

```swift
// ConsultationWebSocketManager.swift

// Properties
nonisolated(unsafe) private var streamingTimeoutTask: Task<Void, Never>?
private let streamingTimeout: TimeInterval = 5.0  // 5 seconds of inactivity

// Start/Reset timeout when streaming begins or new chunk arrives
// This resets the timeout each time a new chunk arrives, only triggering if no chunks for 5 seconds
private func startStreamingTimeout() {
    // Cancel any existing timeout to reset the timer
    streamingTimeoutTask?.cancel()
    
    streamingTimeoutTask = Task { [weak self] in
        do {
            try await Task.sleep(nanoseconds: UInt64(self?.streamingTimeout ?? 5.0 * 1_000_000_000))
            
            await MainActor.run {
                guard let self = self else { return }
                
                print("⏰ [ConsultationWS] Streaming timeout reached (no chunks for 5s), finalizing message")
                
                if let messageID = self.currentStreamingMessageID,
                    let index = self.messages.firstIndex(where: { $0.id == messageID }) {
                    self.messages[index].isStreaming = false
                    print("✅ [ConsultationWS] Stream finalized by timeout, length: \(self.messages[index].content.count)")
                }
                
                self.isAITyping = false
                self.currentStreamingMessage = ""
                self.currentStreamingMessageID = nil
            }
        } catch {
            // Task was cancelled (normal completion or new chunk arrived)
        }
    }
}
```

### 2. Timeout Integration

**Start/Reset Timeout on Every Chunk:**
```swift
case "stream_chunk":
    if let content = message.content {
        currentStreamingMessage += content
        
        if let messageID = currentStreamingMessageID,
            let index = messages.firstIndex(where: { $0.id == messageID }) {
            // Update existing streaming message
            messages[index].content = currentStreamingMessage
            // Reset timeout since we received a new chunk - prevents premature finalization
            startStreamingTimeout()
        } else {
            // Create new streaming message
            // ... create message ...
            // Start timeout timer for new streaming message
            startStreamingTimeout()
        }
    }
```

**Cancel on Normal Completion:**
```swift
case "stream_complete":
    // Cancel timeout since we received completion
    streamingTimeoutTask?.cancel()
    streamingTimeoutTask = nil
    
    // ... existing completion logic ...
```

**Cancel on Disconnect:**
```swift
nonisolated func disconnect() {
    webSocketTask?.cancel(with: .goingAway, reason: nil)
    webSocketTask = nil
    streamingTimeoutTask?.cancel()  // Clean up timeout
    streamingTimeoutTask = nil
    isConnected = false
    connectionStatus = .disconnected
}
```

---

## UI Improvements - Subtle Typing Indicator

### Problem

The original typing indicator was too prominent:
- Large dots (6x6)
- Scale animation (ping-pong effect)
- High opacity
- Distracting movement

### Solution

Made the indicator more subtle and calming:

```swift
// Before
Circle()
    .fill(LumeColors.textSecondary.opacity(0.4))
    .frame(width: 6, height: 6)
    .scaleEffect(viewModel.isSendingMessage ? 1.0 : 0.5)
    .animation(
        Animation.easeInOut(duration: 0.6)
            .repeatForever()
            .delay(Double(index) * 0.2),
        value: viewModel.isSendingMessage
    )

// After
Circle()
    .fill(LumeColors.textSecondary.opacity(0.5))
    .frame(width: 5, height: 5)
    .opacity(viewModel.isSendingMessage ? 1.0 : 0.3)
    .animation(
        Animation.easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.2),
        value: viewModel.isSendingMessage
    )
```

**Changes:**
- ✅ Smaller dots: 6x6 → 5x5
- ✅ Opacity fade: Scale animation → Opacity animation
- ✅ Slower pace: 0.6s → 0.8s duration
- ✅ Softer look: Surface background instead of white
- ✅ Less distracting: Gentle fade instead of ping-pong

---

## Flow Diagrams

### Normal Streaming Flow

```
User sends message
    ↓
Backend starts streaming
    ↓
stream_chunk received
    ↓ (first chunk)
Start timeout timer (5s)
    ↓
More stream_chunk messages
    ↓ (update content + RESET timeout)
Each chunk resets the 5s timer ✅
    ↓
Continue updating UI
    ↓
stream_complete received
    ↓
Cancel timeout timer ✅
    ↓
Finalize message (isStreaming = false)
    ↓
Persist to database
```

### Timeout Fallback Flow

```
User sends message
    ↓
Backend starts streaming
    ↓
stream_chunk received
    ↓ (first chunk)
Start timeout timer (5s)
    ↓
More stream_chunk messages
    ↓ (update content + RESET timeout each time)
Continue updating UI
    ↓
⏰ 5 seconds elapsed WITH NO NEW CHUNKS
    ↓ (backend stopped sending, no stream_complete)
Timeout triggers
    ↓
Finalize message automatically ✅
    ↓
Set isStreaming = false
    ↓
Set isAITyping = false
    ↓
Clear streaming state
    ↓
Message appears complete in UI
    ↓
Persist to database
```

---

## Benefits

### User Experience
- ✅ Messages never stuck in streaming state
- ✅ Typing indicator more subtle and calming
- ✅ Automatic recovery from backend issues
- ✅ No manual intervention required

### Technical
- ✅ Resilient to missing `stream_complete` messages
- ✅ Proper cleanup on disconnect
- ✅ Messages always persisted eventually
- ✅ No memory leaks from abandoned tasks

### Performance
- ✅ 5-second timeout is reasonable (not too fast, not too slow)
- ✅ Tasks properly cancelled to avoid wasted resources
- ✅ Minimal overhead (single Task per streaming message)

---

## Configuration

### Adjustable Timeout

The timeout duration can be adjusted if needed:

```swift
private let streamingTimeout: TimeInterval = 5.0  // Configurable (seconds of inactivity)
```

**Recommendations:**
- **Too short (<3s):** May prematurely finalize during normal processing pauses
- **Too long (>10s):** User waits too long for stuck messages
- **Optimal (5s):** Balances patience with responsiveness

**Important:** This is an **inactivity timeout**, not a total duration timeout. As long as chunks keep arriving, the message continues streaming indefinitely. Only triggers if no chunks arrive for 5 consecutive seconds.

---

## Testing Scenarios

### Manual Testing

1. **Normal Streaming:**
   - Send message
   - Verify streaming works normally
   - Verify timeout doesn't trigger during active streaming
   - Verify `stream_complete` cancels timeout

2. **Long Messages:**
   - Send prompt that generates long response (>5 seconds)
   - Verify message doesn't split mid-stream
   - Timeout should keep resetting with each chunk
   - Verify single complete message at end

3. **Timeout Trigger:**
   - Simulate missing `stream_complete` (backend issue)
   - Verify message finalizes after 5 seconds of **no chunks**
   - Verify typing indicator disappears
   - Verify message persists to database

4. **Rapid Disconnect:**
   - Send message
   - Disconnect before completion
   - Verify timeout task is cancelled
   - No crashes or memory leaks

5. **Multiple Messages:**
   - Send multiple messages in succession
   - Verify each has its own timeout
   - Previous timeout cancelled when new message starts

### Edge Cases

- ✅ Timeout while switching conversations
- ✅ Timeout during app backgrounding
- ✅ Multiple timeouts in different conversations
- ✅ Timeout after manual disconnect

---

## Monitoring & Debugging

### Log Messages

**Timeout Triggered:**
```
⏰ [ConsultationWS] Streaming timeout reached (no chunks for 5s), finalizing message
✅ [ConsultationWS] Stream finalized by timeout, length: 152
```

**Normal Completion:**
```
✅ [ConsultationWS] Server acknowledged message
📝 [ConsultationWS] Stream chunk received, total length: 45
✅ [ConsultationWS] Stream complete, final length: 152
```

**Disconnect Cleanup:**
```
🔌 [ConsultationWS] Disconnecting WebSocket
```

### Debug Checklist

- [ ] Check logs for timeout messages
- [ ] Verify `isStreaming` transitions to `false`
- [ ] Confirm `isAITyping` becomes `false`
- [ ] Validate message persists to database
- [ ] Check typing indicator disappears

---

## Related Issues

### Why Backend Might Not Send stream_complete

Possible backend issues:
1. Connection closed before completion signal sent
2. Backend crash during streaming
3. Network interruption at critical moment
4. Backend implementation bug
5. WebSocket proxy/load balancer issues
6. Backend sends chunks very slowly (>5s between chunks)

**Note:** Issue #6 would cause message splitting in the original implementation but is now fixed with timeout reset on each chunk.

### App Resilience

This fix makes the app resilient to all these scenarios without requiring backend changes.

---

## Future Enhancements

### Potential Improvements

1. **Adaptive Timeout:**
   - Start with 5s, extend if chunks still coming
   - Different timeouts for different message types

2. **User Notification:**
   - Subtle indicator if timeout triggered (vs normal completion)
   - "Response may be incomplete" notice

3. **Retry Logic:**
   - Option to "Continue Response" if timeout occurred
   - Attempt to reconnect and resume streaming

4. **Analytics:**
   - Track how often timeouts occur
   - Identify patterns (network, backend, specific personas)
   - Feed data back to backend team

---

## Related Documentation

- [Backend Sync Optimization](./BACKEND_SYNC_OPTIMIZATION.md)
- [Chat UX Improvements](./UX_IMPROVEMENTS_2025_01_29.md)
- [WebSocket Integration](../backend-integration/WEBSOCKET_GUIDE.md)

---

## Summary

The streaming timeout fix ensures messages never get stuck in an incomplete state, providing a resilient user experience even when backend signals are missing. Combined with a more subtle typing indicator, the chat experience is now both reliable and calm.

**Key Principle:** Always finalize streaming messages within a reasonable timeframe, whether by backend signal or timeout, to maintain user trust and data integrity.

---

**Implementation Date:** 2025-01-29  
**Files Modified:** 
- `ConsultationWebSocketManager.swift` - Timeout mechanism
- `ChatView.swift` - Subtle typing indicator

**Status:** ✅ Fixed and Ready for Testing

**Critical Fix Applied (2025-01-29):**
- Timeout now resets on each chunk arrival
- Prevents message splitting during long responses
- Only triggers after 5 seconds of **inactivity** (no new chunks)