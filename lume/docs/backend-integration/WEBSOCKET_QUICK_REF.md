# WebSocket Quick Reference - Lume AI Chat

**Last Updated:** 2025-01-28  
**Status:** ✅ Production Ready

---

## Quick Facts

- **Endpoint:** `wss://fit-iq-backend.fly.dev/api/v1/consultations/{id}/ws`
- **Auth Method:** Query parameter (NOT header)
- **Auth Parameter:** `?token={jwt_access_token}`
- **Additional Header:** `X-API-Key: {api_key}`
- **Fallback:** Automatic polling every 3 seconds

---

## Correct URL Format

```
wss://{domain}/api/v1/consultations/{consultation_id}/ws?token={jwt_token}
```

### Example

```
wss://fit-iq-backend.fly.dev/api/v1/consultations/123e4567-e89b-12d3-a456-426614174000/ws?token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## iOS Implementation

### URL Construction (ChatBackendService.swift)

```swift
var wsURLComponents = URLComponents()
wsURLComponents.scheme = baseWSURL.scheme
wsURLComponents.host = baseWSURL.host
wsURLComponents.port = baseWSURL.port
wsURLComponents.path = "/api/v1/consultations/\(conversationId.uuidString)/ws"
wsURLComponents.queryItems = [
    URLQueryItem(name: "token", value: accessToken)
]

guard let wsURL = wsURLComponents.url else {
    throw WebSocketError.connectionFailed
}

var request = URLRequest(url: wsURL)
request.setValue(AppConfiguration.shared.apiKey, forHTTPHeaderField: "X-API-Key")

let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
webSocketTask = session.webSocketTask(with: request)
webSocketTask?.resume()
```

### Config (config.plist)

```xml
<key>WebSocketURL</key>
<string>wss://fit-iq-backend.fly.dev</string>
<key>BACKEND_BASE_URL</key>
<string>https://fit-iq-backend.fly.dev</string>
<key>API_KEY</key>
<string>your-api-key</string>
```

---

## Message Types

### Server → Client

| Type | Purpose | Example |
|------|---------|---------|
| `connected` | Connection established | `{"type": "connected", "consultation_id": "...", "timestamp": "..."}` |
| `message` | AI response | `{"type": "message", "message": {...}, "timestamp": "..."}` |
| `error` | Error occurred | `{"type": "error", "error": "...", "timestamp": "..."}` |
| `pong` | Keep-alive response | `{"type": "pong", "timestamp": "..."}` |

### Client → Server

| Type | Purpose | Example |
|------|---------|---------|
| `ping` | Keep-alive | `{"type": "ping"}` |

---

## Flow Diagram

```
1. User sends message (REST POST)
   POST /api/v1/consultations/{id}/messages
   
2. Backend receives and processes
   
3. AI generates response
   
4. Backend sends via WebSocket
   WS → {"type": "message", "message": {...}}
   
5. iOS app receives and displays
```

---

## Error Handling

### Common Errors

| Error | Code | Cause | Solution |
|-------|------|-------|----------|
| Bad response | -1011 | Wrong URL format | Check URL construction |
| Unauthorized | 401 | Invalid/expired token | Refresh token |
| Forbidden | 403 | Wrong consultation owner | Verify user ID |
| Not Found | 404 | Consultation doesn't exist | Check consultation ID |

### Automatic Fallback

If WebSocket fails, app automatically polls:
- Interval: 3 seconds
- Endpoint: `GET /api/v1/consultations/{id}/messages`
- User unaware of fallback

---

## Logs to Look For

### Success
```
🔌 [ChatViewModel] Connecting to WebSocket for conversation: {id}
✅ [ChatBackendService] Connected to WebSocket for conversation: {id}
✅ [ChatViewModel] WebSocket connected successfully
✅ [ChatViewModel] Received message via WebSocket: assistant
```

### Fallback
```
⚠️ [ChatViewModel] WebSocket error: {error}
🔄 [ChatViewModel] Starting message polling fallback
✅ [ChatViewModel] Polled 1 new message(s)
```

### Errors
```
❌ [ChatBackendService] WebSocket receive error: {error}
❌ [ChatViewModel] Failed to connect WebSocket: {error}
```

---

## Common Mistakes

### ❌ WRONG: Token in Authorization Header

```swift
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
```

### ✅ CORRECT: Token as Query Parameter

```swift
wsURLComponents.queryItems = [
    URLQueryItem(name: "token", value: accessToken)
]
```

### ❌ WRONG: Full Path in Config

```xml
<key>WebSocketURL</key>
<string>wss://fit-iq-backend.fly.dev/ws/meal-logs</string>
```

### ✅ CORRECT: Base URL Only

```xml
<key>WebSocketURL</key>
<string>wss://fit-iq-backend.fly.dev</string>
```

---

## Testing Checklist

- [ ] URL format is correct
- [ ] Token passed as query parameter
- [ ] API key passed in header
- [ ] Connection establishes (101 response)
- [ ] Messages received in real-time
- [ ] Fallback to polling works
- [ ] No -1011 errors in logs
- [ ] Works across app restarts
- [ ] Works after token refresh

---

## Files to Check

| File | What to Verify |
|------|----------------|
| `config.plist` | WebSocket base URL is just domain |
| `ChatBackendService.swift` | Token in query param, not header |
| `ChatViewModel.swift` | Connects on conversation select |
| `ChatService.swift` | Passes callbacks correctly |

---

## Quick Debug

### 1. Check URL Construction

```swift
print("🔍 WebSocket URL: \(wsURL.absoluteString)")
```

Expected:
```
wss://fit-iq-backend.fly.dev/api/v1/consultations/{id}/ws?token=...
```

### 2. Check Token

```swift
print("🔍 Token: \(accessToken.prefix(20))...")
```

Should be JWT format starting with `eyJ...`

### 3. Check Connection Status

```swift
print("🔍 Is connected: \(isConnected)")
```

Should be `true` after successful connection.

---

## Related Documentation

- [WEBSOCKET_FIX.md](./WEBSOCKET_FIX.md) - Detailed fix documentation
- [CHAT_FIXES_2025_01_28.md](../fixes/CHAT_FIXES_2025_01_28.md) - All chat fixes
- [swagger-consultations.yaml](../swagger-consultations.yaml) - Full API spec

---

**Need Help?**

1. Check logs for error codes
2. Verify URL format matches spec
3. Ensure token is valid (not expired)
4. Test with polling fallback
5. Review swagger spec for API changes

---

**Last Verified:** 2025-01-28  
**Backend Version:** 0.34.0  
**iOS Implementation:** Production Ready ✅