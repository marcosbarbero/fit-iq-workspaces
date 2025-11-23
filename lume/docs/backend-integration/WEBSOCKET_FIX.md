# WebSocket Decoding Fix

**Date:** 2025-01-28  
**Status:** ✅ Fixed  
**Related Issue:** WebSocket messages not being decoded correctly

---

## Problem

The iOS app was successfully connecting to the WebSocket, but failing to decode incoming messages with the error:

```
✅ [ChatBackendService] WebSocket connection opened
❌ [ChatBackendService] Failed to decode WebSocket message: The data couldn't be read because it is missing.
```

### Root Cause

The WebSocket message decoder was expecting a flat message structure:

```swift
struct WebSocketMessageDTO: Decodable {
    let id: String
    let conversation_id: String
    let role: String
    let content: String
    let timestamp: Date
}
```

But the backend actually sends messages wrapped in an envelope with a `type` field:

```json
{
  "type": "message",
  "message": {
    "id": "...",
    "consultation_id": "...",
    "role": "assistant",
    "content": "...",
    "created_at": "2025-01-28T10:00:00Z"
  },
  "timestamp": "2025-01-28T10:00:00Z"
}
```

---

## Solution

### Updated WebSocket DTO Structure

Created a wrapper DTO to handle the envelope:

```swift
/// WebSocket message wrapper (from backend)
private struct WebSocketMessageWrapper: Decodable {
    let type: String
    let message: WebSocketMessageDTO?
    let consultation_id: String?
    let timestamp: String
    let error: String?
}

/// WebSocket message DTO (nested inside wrapper)
private struct WebSocketMessageDTO: Decodable {
    let id: String
    let consultation_id: String  // Changed from conversation_id
    let role: String
    let content: String
    let function_name: String?
    let function_args: String?
    let tokens_used: Int?
    let processing_time_ms: Int?
    let created_at: String  // Changed from timestamp: Date
    
    func toDomain() -> ChatMessage {
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
```

### Updated Decoding Logic

```swift
private func handleTextMessage(_ text: String) {
    print("📥 [ChatBackendService] Received WebSocket message: \(text)")
    
    guard let data = text.data(using: .utf8) else {
        print("❌ [ChatBackendService] Failed to convert message to data")
        return
    }
    
    do {
        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(WebSocketMessageWrapper.self, from: data)
        
        // Handle different message types
        switch wrapper.type {
        case "connected":
            print("✅ [ChatBackendService] WebSocket connected, consultation: \(wrapper.consultation_id ?? "unknown")")
            
        case "message":
            guard let messageDTO = wrapper.message else {
                print("⚠️ [ChatBackendService] Received message type but no message content")
                return
            }
            
            let chatMessage = messageDTO.toDomain()
            messageHandler?(chatMessage)
            print("✅ [ChatBackendService] Received message via WebSocket: \(chatMessage.id)")
            
        case "error":
            print("❌ [ChatBackendService] WebSocket error from server: \(wrapper.error ?? "unknown")")
            
        case "pong":
            print("🏓 [ChatBackendService] Received pong")
            
        default:
            print("⚠️ [ChatBackendService] Unknown WebSocket message type: \(wrapper.type)")
        }
    } catch {
        print("❌ [ChatBackendService] Failed to decode WebSocket message: \(error.localizedDescription)")
        print("🔍 [ChatBackendService] Raw message was: \(text)")
        if let decodingError = error as? DecodingError {
            print("🔍 [ChatBackendService] Decoding error details: \(decodingError)")
        }
    }
}
```

---

## Backend Message Types (from swagger-consultations.yaml)

### 1. Connected Message

Sent when WebSocket connection is established:

```json
{
  "type": "connected",
  "consultation_id": "uuid",
  "timestamp": "2025-01-28T10:00:00Z"
}
```

### 2. Message (AI Response)

Sent when AI generates a response:

```json
{
  "type": "message",
  "message": {
    "id": "uuid",
    "consultation_id": "uuid",
    "role": "assistant",
    "content": "AI response text",
    "tokens_used": 150,
    "processing_time_ms": 1200,
    "created_at": "2025-01-28T10:00:15Z"
  },
  "timestamp": "2025-01-28T10:00:15Z"
}
```

### 3. Error Message

Sent when an error occurs:

```json
{
  "type": "error",
  "error": "Error message",
  "code": "ERROR_CODE",
  "timestamp": "2025-01-28T10:00:20Z"
}
```

### 4. Pong Message

Response to keep-alive ping:

```json
{
  "type": "pong",
  "timestamp": "2025-01-28T10:00:25Z"
}
```

---

## Key Changes

1. **Wrapper Structure** - All WebSocket messages now decoded with type-based envelope
2. **Field Names** - Changed `conversation_id` → `consultation_id` to match backend
3. **Date Handling** - Changed from `Date` with decoder strategy to `String` with manual parsing
4. **Type Handling** - Switch statement to handle different message types
5. **Enhanced Logging** - Added raw message logging for debugging

---

## WebSocket Connection Details

### URL Format

```
wss://fit-iq-backend.fly.dev/api/v1/consultations/{id}/ws
```

### Authentication

- **Method:** Authorization header with Bearer token
- **Header:** `Authorization: Bearer {jwt_token}`
- **Additional:** `X-API-Key: {api_key}`

### Connection Flow

```
1. ChatViewModel.connectWebSocket()
2. ChatService.connectWebSocket()
3. ChatBackendService.connectWebSocket()
4. WebSocket handshake
5. Receive "connected" message
6. Ready to receive AI responses
```

---

## Testing

### Success Indicators

```
🔌 [ChatViewModel] Connecting to WebSocket for conversation: {id}
✅ [ChatBackendService] Connected to WebSocket for conversation: {id}
✅ [ChatBackendService] WebSocket connection opened
✅ [ChatBackendService] WebSocket connected, consultation: {id}
📥 [ChatBackendService] Received WebSocket message: {"type":"message",...}
✅ [ChatBackendService] Received message via WebSocket: {message_id}
✅ [ChatViewModel] Received message via WebSocket: assistant
```

### Failure Indicators (Fixed)

```
❌ [ChatBackendService] Failed to decode WebSocket message: The data couldn't be read because it is missing.
```

This error no longer appears because the DTO structure now matches the backend format.

---

## Files Modified

### Infrastructure
- ✅ `lume/Services/Backend/ChatBackendService.swift` - Fixed WebSocket message decoding

---

## Verification Checklist

- [x] WebSocketMessageWrapper struct created
- [x] WebSocketMessageDTO fields match backend (consultation_id, created_at)
- [x] Type-based message handling implemented
- [x] All message types handled (connected, message, error, pong)
- [x] Enhanced logging added for debugging
- [x] Date parsing uses ISO8601DateFormatter
- [x] No more decoding errors

---

## Impact

### Before Fix
- ❌ WebSocket connected but messages not decoded
- ❌ AI responses lost
- ❌ User sees "sending..." indefinitely
- ❌ Had to rely on polling fallback

### After Fix
- ✅ WebSocket messages decoded correctly
- ✅ Real-time AI responses work
- ✅ User sees instant replies
- ✅ WebSocket preferred over polling

---

## Key Learnings

1. **Always match backend structure exactly** - Field names and nesting matter
2. **Use wrapper/envelope pattern** - Backend uses type field for message routing
3. **Log raw messages** - Critical for debugging decoding issues
4. **Date parsing flexibility** - Manual parsing more reliable than decoder strategies
5. **Handle all message types** - Not just the happy path

---

**Status:** ✅ Production Ready  
**Priority:** Critical  
**Risk Level:** Low - WebSocket working, polling fallback available