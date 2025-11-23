# Chat Real-Time Architecture Decision

**Date:** 2025-01-28  
**Status:** Implemented  
**Decision:** Use direct real-time communication for chat instead of Outbox pattern

---

## Context

During the implementation of AI chat features for Lume, we initially considered using the Outbox pattern for all external communication, following the architectural guideline that "all external communication MUST use the Outbox pattern."

However, the Outbox pattern introduces significant delays:
- Events are processed in batches every 30+ seconds
- Messages sit in a queue before being sent
- No immediate feedback to users
- Poor conversational experience

## Decision

**Chat communication uses direct real-time delivery, not the Outbox pattern.**

### Rationale

1. **User Experience Requirements**
   - Chat is conversational and requires immediate response
   - Users expect real-time feedback (typing indicators, instant replies)
   - 30+ second delays would make the feature unusable
   - Chat needs to feel natural and responsive

2. **Technical Considerations**
   - WebSocket support for streaming responses
   - Optimistic UI updates for immediate feedback
   - Error handling with immediate retry capability
   - Message delivery status visible to user

3. **Architecture Fit**
   - Chat has different resilience requirements than goals/insights
   - Failed messages can be retried immediately by the user
   - Message history persists locally regardless of send status
   - Network failures are handled gracefully with user notification

## Implementation

### SendChatMessageUseCase

```swift
final class SendChatMessageUseCase {
    private let chatRepository: ChatRepositoryProtocol
    private let chatService: ChatServiceProtocol
    
    func execute(conversationId: UUID, content: String) async throws -> ChatMessage {
        // 1. Create and save user message locally (optimistic update)
        let userMessage = ChatMessage(...)
        _ = try await chatRepository.addMessage(userMessage, to: conversationId)
        
        // 2. Send immediately via WebSocket (streaming) or REST
        if useStreaming {
            try await sendViaWebSocket(...)
        } else {
            try await sendViaREST(...)
        }
        
        // 3. On failure, delete optimistic message and throw error
        // User can retry immediately
        
        return userMessage
    }
}
```

### Flow Diagram

```
User Input → Create Message → Save Locally (Optimistic)
                    ↓
         Send Immediately via:
         - WebSocket (streaming) OR
         - REST API (standard)
                    ↓
         ┌──────────────────┐
         │   Success        │   Failure
         ↓                  ↓
    Save Assistant     Delete Optimistic
    Response           Show Error
                       Allow Retry
```

### Error Handling

1. **Network Errors**: Immediate user notification with retry button
2. **Service Errors**: Show error message, preserve user input for retry
3. **Validation Errors**: Prevent send, show validation message
4. **Rate Limiting**: Show cooldown timer, queue message if appropriate

### Benefits

✅ **Immediate UX** - Messages send instantly  
✅ **Real-time streaming** - Assistant responses stream as they generate  
✅ **Optimistic updates** - UI updates immediately for smooth experience  
✅ **User control** - Failed messages can be retried immediately  
✅ **Natural conversation** - No artificial delays in chat flow  

### Trade-offs

⚠️ **No automatic retry** - User must manually retry failed messages  
⚠️ **Requires online** - Chat doesn't work offline (by design)  
⚠️ **Direct dependency** - Service layer tightly coupled to use case  

## When to Use Outbox Pattern

The Outbox pattern is still appropriate for:

- **Goal Sync** - Background sync of goals and progress
- **Insights** - Periodic fetch of AI insights
- **Analytics** - Usage tracking and metrics
- **Settings Sync** - User preferences and configuration
- **Batch Operations** - Any operation that can tolerate delays

## When NOT to Use Outbox Pattern

Do NOT use Outbox for:

- **Chat Messages** - Real-time conversation
- **Live Updates** - Any feature requiring immediate feedback
- **Interactive Features** - User-initiated actions expecting instant response
- **Streaming Data** - Real-time data flows

## Architectural Compliance

This decision **does not violate** Lume's architecture principles:

1. **Hexagonal Architecture** ✅
   - Domain defines ChatServiceProtocol
   - Infrastructure implements the service
   - Presentation depends only on use cases

2. **SOLID Principles** ✅
   - Single Responsibility: SendChatMessageUseCase has one job
   - Dependency Inversion: Depends on protocols, not implementations
   - Interface Segregation: Clean, focused interfaces

3. **Resilience** ✅
   - Local persistence ensures message history
   - Graceful error handling with user feedback
   - Retry capability via UI

4. **Testability** ✅
   - All dependencies are protocols
   - Easy to mock ChatService for testing
   - Clear separation of concerns

## Future Enhancements

Potential improvements to chat resilience:

1. **Offline Queue** (if needed)
   - Separate from Outbox, chat-specific queue
   - Immediate retry on reconnection
   - User-visible queue status

2. **Message Status**
   - Sending, sent, delivered, read
   - Visual indicators in UI
   - Automatic status updates

3. **Retry Logic**
   - Exponential backoff for transient errors
   - Smart retry (only for specific error types)
   - Max retry attempts with user notification

4. **WebSocket Reconnection**
   - Automatic reconnection on disconnect
   - Message buffering during reconnection
   - Seamless resume of conversation

## Conclusion

Chat requires real-time communication for good UX. The Outbox pattern is excellent for eventual consistency but inappropriate for conversational interfaces. This architectural decision maintains Lume's core principles while providing the responsive experience users expect from chat.

---

**References:**
- `SendChatMessageUseCase.swift` - Implementation
- `ChatServiceProtocol.swift` - Service interface
- `ChatRepositoryProtocol.swift` - Repository interface
- `.github/copilot-instructions.md` - Architecture guidelines