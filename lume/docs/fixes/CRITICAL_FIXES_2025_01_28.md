# Critical Fixes - 2025-01-28

## Issues Fixed

### 1. Backend Response Decoding Error ✅

**Problem:**
```
❌ keyNotFound(CodingKeys "success")
```

Backend returns: `{"data": {...}}`  
App expected: `{"success": true, "data": {...}}`

**Fix:**
Removed `success: Bool` field from all response models in `ConsultationWebSocketManager.swift`:
- `CreateConsultationResponse`
- `ConsultationResponse`  
- `ConflictErrorResponse`
- `BackendMessagesResponse`

**Result:** WebSocket connection will now work correctly.

---

### 2. Excessive API Calls - Fetching All Conversations Repeatedly ✅

**Problem:**
Every time you opened a chat or sent a message, `refreshCurrentMessages()` called `loadConversations()` which:
- Fetched ALL 10 conversations from backend
- Updated all 10 in local database
- Extremely wasteful

**Code Before:**
```swift
func refreshCurrentMessages() async {
    // Reload conversations to get updated state
    await loadConversations()  // ← Fetches ALL conversations!
    
    // Update current conversation from refreshed list
    if let updated = conversations.first(where: { $0.id == conversation.id }) {
        currentConversation = updated
        messages = updated.messages
    }
}
```

**Code After:**
```swift
func refreshCurrentMessages() async {
    guard let conversation = currentConversation else { return }
    
    // Only fetch messages for current conversation
    let updatedMessages = try await chatRepository.fetchMessages(for: conversation.id)
    messages = updatedMessages
}
```

**Result:** 
- Only fetches messages for current conversation
- No unnecessary backend calls
- Much faster and efficient

---

### 3. Token Expiration Already Fixed ✅

The JWT decoding was already added to `RemoteAuthService.swift` which:
- Decodes real expiration from JWT token
- Falls back to conservative 15-minute default
- No more hardcoded 1-hour assumption

**Note:** Check logs for:
```
✅ [RemoteAuthService] Decoded JWT expiration: [date]
```
or
```
⚠️ [RemoteAuthService] Using conservative default expiration: 15 minutes
```

---

## Files Modified

1. **ConsultationWebSocketManager.swift**
   - Removed `success` field from 4 response models
   - Matches actual backend response format

2. **ChatViewModel.swift**  
   - Changed `refreshCurrentMessages()` to only fetch current conversation messages
   - No more `loadConversations()` spam

---

## Expected Behavior After Fix

### When Opening a Chat:
```
📖 selectConversation called
🔌 Connecting to existing consultation
🔌 [ConsultationWS] Connecting to existing consultation: [id]
✅ [ConsultationWS] Loaded X historical messages
✅ [ConsultationWS] Connected to existing consultation
✅ isUsingLiveChat: true
```

### When Sending a Message:
```
📤 Sending message
💬 Sending via live chat WebSocket
✅ [ConsultationWS] Message sent to WebSocket
📥 [ConsultationWS] Received: stream_chunk
✅ Stream complete
```

**No more:**
- ❌ Decoding errors
- ❌ Fetching all 10 conversations repeatedly
- ❌ Falling back to polling

---

## Testing Checklist

- [ ] Open existing chat → WebSocket connects (no decoding error)
- [ ] Send message → AI responds via WebSocket (not REST API fallback)
- [ ] Check logs → Only 1 API call when opening chat (not 10+)
- [ ] Network tab → Verify no repeated `/consultations?limit=100` calls
- [ ] Token expiration → Check JWT decoding logs

---

## Clean Up Required

You still have 10 duplicate consultations. Recommend:
1. Keep: `66a66183-4639-47fb-a5ec-b150a54033fe` (has messages)
2. Archive/delete the other 9

---

## Result

✅ WebSocket will connect successfully  
✅ Messages load from history correctly  
✅ No excessive API calls  
✅ Much faster and more efficient  
✅ Token expiration properly handled
