# Chat Critical Issues and Fixes

**Date:** 2025-01-29  
**Priority:** 🚨 CRITICAL  
**Status:** ⚠️ Requires Immediate Attention

---

## Issues Summary

1. **AI Response Not Displayed** - WebSocket receives acknowledgment but no AI message shows
2. **Empty Messages in UI** - Messages display only timestamp, no content
3. **Message Count Falls to 0** - Chat list shows 0 messages until chat is reopened
4. **No Chat Renaming** - All chats have generic "Chat with Wellness Specialist" title
5. **Deleted Chats Reappear** - Local deletion doesn't prevent backend re-sync

---

## Issue 1: AI Response Not Displayed

### Problem

After sending a message via WebSocket:
```
📤 User sends: "What's my goal?"
✅ WebSocket acknowledges: message_received
⏳ AI typing indicator shows (3 dots)
❌ AI response never appears in UI
```

### Root Cause Analysis

From the logs:
```
📥 [ConsultationWS] Received: {"type":"message_received",...}
✅ [ConsultationWS] Server acknowledged message
```

The `message_received` type is **just an acknowledgment**, not the AI response.

The AI response should come as:
- `stream_chunk` messages with partial content
- `stream_complete` message to finalize

**The backend IS sending the AI response, but we're not receiving/processing it properly.**

### Possible Causes

1. **WebSocket Connection Drops** - Connection closes before AI response arrives
2. **Message Parsing Issue** - AI response in unexpected format
3. **Backend Not Sending** - Backend never sends stream_chunk messages
4. **WebSocket Not Listening** - receiveMessage() stops too early

### Investigation Steps

```swift
// In ConsultationWebSocketManager.swift, add detailed logging:

private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message) async {
    switch message {
    case .string(let text):
        print("📥 [ConsultationWS] RAW MESSAGE: \(text)")  // Log full message
        
        // Check if we're getting stream_chunk messages
        if text.contains("stream_chunk") {
            print("✅ [ConsultationWS] Got stream_chunk!")
        }
        
        if text.contains("stream_complete") {
            print("✅ [ConsultationWS] Got stream_complete!")
        }
        
        // Continue existing parsing...
    }
}
```

### Required Fix

**Option A: Enable Backend Streaming**

Check if backend is configured to send streaming responses:
```json
// Backend should send after message_received:
{
  "type": "stream_chunk",
  "content": "I can help you with your goal!",
  "consultation_id": "uuid",
  "timestamp": "2025-01-29T..."
}

// And finally:
{
  "type": "stream_complete",
  "consultation_id": "uuid",
  "timestamp": "2025-01-29T..."
}
```

**Option B: Poll for Response**

If backend doesn't stream, poll for new messages:
```swift
// After sending message, poll for AI response
private func pollForAIResponse() async {
    guard let consultationID = consultationID else { return }
    
    for attempt in 1...10 {  // Poll up to 10 times (30 seconds)
        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        
        // Fetch latest messages from backend
        try? await loadMessageHistory(consultationID: consultationID)
        
        // Check if we got AI response
        if messages.last?.role == .assistant {
            print("✅ Found AI response via polling")
            isAITyping = false
            break
        }
    }
    
    // Timeout
    isAITyping = false
}
```

---

## Issue 2: Empty Messages in UI

### Problem

Messages show in chat list and chat view, but with no content:
```
[Chat Bubble]
12:34 PM
[Empty space where content should be]
```

### Root Cause

Two scenarios:

**Scenario A: Messages Saved Without Content**
```swift
// Check SDChatMessage model
@Model
final class SDChatMessage {
    var content: String  // Is this empty?
}
```

**Scenario B: Fetch Query Missing Content**
```swift
// In ChatRepository.fetchMessages()
let messages = try modelContext.fetch(descriptor)

// Are we mapping content properly?
messages.map { toDomainMessage($0) }
```

### Investigation

Add logging to message persistence:
```swift
// In ChatRepository.addMessage()
func addMessage(_ message: ChatMessage, to conversationId: UUID) async throws -> ChatMessage {
    print("💾 Saving message with content length: \(message.content.count)")
    print("💾 Content preview: '\(message.content.prefix(100))'")
    
    let sdMessage = toSwiftDataMessage(message)
    print("💾 SDMessage content length: \(sdMessage.content.count)")
    
    modelContext.insert(sdMessage)
    try modelContext.save()
    
    // Verify it was saved
    let fetched = try modelContext.fetch(...)
    print("✅ Verified saved content: '\(fetched.content.prefix(100))'")
}
```

### Required Fix

**Fix A: Ensure Content is Not Empty on Save**
```swift
func addMessage(_ message: ChatMessage, to conversationId: UUID) async throws -> ChatMessage {
    guard !message.content.isEmpty else {
        throw ChatRepositoryError.invalidMessage("Message content cannot be empty")
    }
    
    // Continue with save...
}
```

**Fix B: Handle Streaming Messages Properly**
```swift
// Don't persist messages that are still streaming
guard !(message.metadata?.isStreaming ?? false) else {
    print("⏭️ Skipping streaming message, will persist when complete")
    return message
}
```

---

## Issue 3: Message Count Falls to 0

### Problem

In `ChatListView`, conversation cards show:
```
Chat with Wellness Specialist
0 messages • Just now
```

But after opening the chat or switching tabs:
```
Chat with Wellness Specialist
5 messages • 2 min ago
```

### Root Cause

The `ChatConversation.messageCount` is not being updated after sending/receiving messages.

**Where `messageCount` is Set:**

1. **On Creation** - Backend returns `message_count: 0`
2. **On Fetch** - Backend returns current `message_count`
3. **Never Updated Locally** - After sending messages, count stays stale

### Required Fix

**Fix A: Update Conversation After Sending Message**

```swift
// In ChatViewModel.sendMessage()
private func updateConversationMessageCount() async {
    guard let conversation = currentConversation else { return }
    
    // Fetch fresh conversation from backend
    if let updated = try? await chatRepository.fetchConversationById(conversation.id) {
        // Update in conversations list
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = updated
        }
        currentConversation = updated
        
        print("✅ Updated message count: \(updated.messageCount)")
    }
}
```

**Fix B: Calculate Message Count from Local Messages**

```swift
// In ChatRepository.toDomainConversation()
private func toDomainConversation(
    _ sdConversation: SDChatConversation,
    messages: [ChatMessage]
) -> ChatConversation {
    // Use actual message count instead of stored count
    let actualMessageCount = messages.count
    
    return ChatConversation(
        // ... other properties
        messageCount: actualMessageCount,  // Use real count
        messages: messages
    )
}
```

---

## Issue 4: No Chat Renaming

### Problem

All chats show:
```
Chat with Wellness Specialist
Chat with Wellness Specialist
Chat with Wellness Specialist
```

Users can't distinguish between conversations.

### Root Cause

Conversations are created with persona-based title:
```swift
let generatedTitle = "Chat with \(personaEnum.displayName)"
```

Backend doesn't store custom titles, and iOS doesn't allow renaming.

### Required Fix

**Fix A: Use First User Message as Title**

```swift
// In ConversationDTO.toDomain()
func toDomain() -> ChatConversation {
    // Generate smart title from first user message
    let smartTitle: String
    if let firstUserMessage = messages?.first(where: { $0.role == "user" }) {
        let preview = firstUserMessage.content.prefix(30)
        smartTitle = String(preview) + (firstUserMessage.content.count > 30 ? "..." : "")
    } else {
        smartTitle = "Chat with \(personaEnum.displayName)"
    }
    
    return ChatConversation(
        // ...
        title: smartTitle
    )
}
```

**Fix B: Goal-Based Chat Uses Goal Title**

```swift
// In CreateConversationUseCase.createForGoal()
func createForGoal(...) async throws -> ChatConversation {
    // Use goal title for conversation
    let title = "💪 \(goalTitle)"  // Add emoji for visual distinction
    
    return try await execute(title: title, persona: persona, context: context)
}
```

**Fix C: Add Rename Functionality**

```swift
// In ChatView, add toolbar button
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showRenameDialog = true
        } label: {
            Image(systemName: "pencil.circle")
        }
    }
}
.sheet(isPresented: $showRenameDialog) {
    RenameConversationView(
        conversation: conversation,
        onRename: { newTitle in
            await viewModel.renameConversation(conversation.id, to: newTitle)
        }
    )
}
```

---

## Issue 5: Deleted Chats Reappear

### Problem

User deletes a chat:
```
1. User taps Delete on chat
2. Chat disappears from list ✅
3. Backend sync hasn't completed yet
4. User switches tabs or refreshes
5. Chat reappears! ❌
```

### Root Cause

**Deletion Flow:**
1. Delete locally from SwiftData ✅
2. Create outbox event for backend deletion ✅
3. Outbox processes event later ⏳
4. Meanwhile, `loadConversations()` fetches from SwiftData ✅
5. But also syncs from backend ❌
6. Backend still has the conversation (not deleted yet)
7. Conversation is re-added to local SwiftData

### Solution Options

**Option A: Soft Delete with Tombstone**

```swift
@Model
final class SDChatConversation {
    var isDeleted: Bool = false
    var deletedAt: Date?
    
    // ... other properties
}

// Exclude deleted conversations from queries
let descriptor = FetchDescriptor<SDChatConversation>(
    predicate: #Predicate { 
        $0.userId == userId && !$0.isDeleted 
    }
)
```

**Option B: Deletion Tracking Table**

```swift
@Model
final class SDDeletedEntity {
    var id: UUID
    var entityType: String  // "conversation", "message", etc.
    var deletedAt: Date
    var userId: UUID
    
    init(id: UUID, entityType: String, userId: UUID) {
        self.id = id
        self.entityType = entityType
        self.deletedAt = Date()
        self.userId = userId
    }
}

// Check before syncing from backend
func shouldSync(conversationId: UUID) -> Bool {
    let descriptor = FetchDescriptor<SDDeletedEntity>(
        predicate: #Predicate {
            $0.id == conversationId && $0.entityType == "conversation"
        }
    )
    let deleted = try? modelContext.fetch(descriptor).first
    return deleted == nil
}
```

**Option C: Immediate Backend Deletion (Recommended)**

```swift
func deleteConversation(_ conversation: ChatConversation) async {
    // 1. Delete locally
    try await chatRepository.deleteConversation(conversation.id)
    
    // 2. Delete from backend IMMEDIATELY (don't use outbox)
    if let token = try? await tokenStorage.getToken() {
        try? await chatService.deleteConversation(id: conversation.id)
    }
    
    // 3. Update UI
    conversations.removeAll { $0.id == conversation.id }
    
    print("✅ Deleted conversation immediately from local and backend")
}
```

**Option D: Faster Outbox Processing**

```swift
// After creating deletion outbox event, process immediately
try await chatRepository.deleteConversation(conversation.id)

// Process outbox NOW instead of waiting
await outboxProcessorService.processOutbox()

print("✅ Deletion outbox processed immediately")
```

---

## Recommended Fix Priority

### 🚨 Critical (Fix Today)

1. **AI Response Not Showing** - Users can't have conversations
   - Add polling mechanism as temporary fix
   - Investigate WebSocket stream_chunk handling

2. **Empty Messages** - Chat is unusable
   - Add content validation before save
   - Debug why content is empty

### 🔥 High (Fix This Week)

3. **Message Count Always 0** - Poor UX, confusing
   - Update count after sending messages
   - Fetch fresh conversation from backend

4. **Deleted Chats Reappear** - Frustrating user experience
   - Implement soft delete with tombstone
   - Process deletion outbox immediately

### 📋 Medium (Fix Next Sprint)

5. **No Chat Renaming** - Quality of life improvement
   - Use first message as title
   - Add rename dialog

---

## Testing Checklist

After fixes are implemented:

### AI Response Testing
- [ ] Send message via WebSocket
- [ ] Verify `stream_chunk` messages are received
- [ ] Verify AI response displays in UI
- [ ] Test with slow network (3G)
- [ ] Test with WebSocket disconnect/reconnect

### Empty Messages Testing
- [ ] Send message and verify content is saved
- [ ] Fetch messages and verify content is loaded
- [ ] Test with special characters (emoji, unicode)
- [ ] Test with very long messages (>1000 chars)

### Message Count Testing
- [ ] Create new conversation, verify count = 0
- [ ] Send message, verify count increments
- [ ] Receive AI response, verify count increments
- [ ] Switch tabs and return, verify count persists
- [ ] Restart app, verify count is correct

### Deletion Testing
- [ ] Delete conversation
- [ ] Verify it disappears immediately
- [ ] Switch tabs, verify it doesn't reappear
- [ ] Restart app, verify it stays deleted
- [ ] Check backend to confirm deletion

### Renaming Testing
- [ ] Create chat from goal, verify goal title is used
- [ ] Create generic chat, verify first message becomes title
- [ ] Rename chat, verify new title persists
- [ ] Sync across devices (if implemented)

---

## Implementation Notes

### Logging Best Practices

Add comprehensive logging to track issues:

```swift
// Message send/receive
print("📤 [Module] Sending: '\(content.prefix(50))'")
print("📥 [Module] Received: type=\(type), content='\(content.prefix(50))'")

// Data persistence
print("💾 [Module] Saving: id=\(id), content_length=\(content.count)")
print("✅ [Module] Saved successfully")

// Errors
print("❌ [Module] Failed: \(error.localizedDescription)")
```

### Performance Considerations

- Poll for messages sparingly (max 10 attempts, 3s intervals)
- Batch message updates to reduce SwiftData saves
- Use lazy loading for conversation lists
- Cache message counts locally

### Error Handling

```swift
// Graceful degradation
do {
    try await sendViaWebSocket()
} catch {
    print("⚠️ WebSocket failed, falling back to REST API")
    await sendViaRestAPI()
}
```

---

## Backend Coordination Required

### Questions for Backend Team

1. **Are `stream_chunk` messages being sent after `message_received`?**
   - If yes, what's the typical delay?
   - If no, how should iOS get the AI response?

2. **Is the consultation endpoint returning message content correctly?**
   - GET `/api/v1/consultations/{id}/messages`
   - Are empty messages possible?

3. **Is `message_count` updated after each message?**
   - Should iOS rely on backend count or calculate locally?

4. **Does backend support conversation title updates?**
   - PUT `/api/v1/consultations/{id}` with `title` field?

5. **How long until outbox deletions are processed?**
   - Can we have a priority queue for deletions?

---

**Status:** Documented, ready for implementation  
**Next Steps:** 
1. Investigate WebSocket streaming with backend team
2. Implement polling as temporary fix
3. Add comprehensive logging
4. Deploy and monitor production logs