# Meal Log WebSocket Endpoint Specification

**Date:** 2025-01-27  
**Author:** iOS Team  
**Purpose:** Propose dedicated WebSocket endpoint for real-time meal log updates  
**Status:** 📋 Proposal

---

## Executive Summary

Propose a dedicated WebSocket endpoint `/ws/meal-logs` for real-time meal log processing notifications, separate from the consultation WebSocket. This simplifies iOS integration and aligns with the local-first architecture.

---

## Current State vs Proposed

### Current (v0.30.0)

**Endpoint:** `/api/v1/consultations/{id}/ws`

**Issues:**
- ❌ Requires consultation creation for meal logging
- ❌ Mixed purpose (AI chat + meal notifications)
- ❌ Complex client implementation
- ❌ Consultation lifecycle management overhead
- ❌ Not suitable for simple meal tracking

### Proposed

**Endpoint:** `/ws/meal-logs`

**Benefits:**
- ✅ Dedicated meal log notifications
- ✅ Simple authentication (JWT only)
- ✅ No consultation dependency
- ✅ Easier iOS implementation
- ✅ Scales independently
- ✅ Clear separation of concerns

---

## Proposed Endpoint Specification

### Endpoint

```
GET /ws/meal-logs
```

### Authentication

**Query Parameter:**
```
wss://fit-iq-backend.fly.dev/ws/meal-logs?token={jwt_access_token}
```

**Alternative (Header):**
```
GET /ws/meal-logs HTTP/1.1
Host: fit-iq-backend.fly.dev
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: {random_key}
Sec-WebSocket-Version: 13
Authorization: Bearer {jwt_access_token}
X-API-Key: {api_key}
```

### Connection Flow

```
1. Client: HTTP Upgrade Request (with JWT token)
   ↓
2. Server: HTTP 101 Switching Protocols
   ↓
3. Server → Client: {"type": "connected", "user_id": "uuid"}
   ↓
4. Client ← → Server: Keep-alive pings every 30s
   ↓
5. User creates meal log via POST /api/v1/meal-logs/natural
   ↓
6. Server processes meal asynchronously (AI parsing)
   ↓
7. Server → Client: {"type": "meal_log.completed", "data": {...}}
   OR
   Server → Client: {"type": "meal_log.failed", "data": {...}}
```

---

## Message Schemas

### Client → Server

#### 1. Ping (Keep-Alive)

```json
{
  "type": "ping"
}
```

### Server → Client

#### 1. Connected

```json
{
  "type": "connected",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-15T12:00:00Z"
}
```

#### 2. Pong (Keep-Alive Response)

```json
{
  "type": "pong",
  "timestamp": "2024-01-15T12:00:30Z"
}
```

#### 3. Meal Log Completed

**Full response with all meal data:**

```json
{
  "type": "meal_log.completed",
  "data": {
    "id": "7d5a3f1c-8b2e-4d3c-9f1e-2a4b5c6d7e8f",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "raw_input": "120g chicken breast, 1 cup broccoli, 1 tbsp olive oil",
    "meal_type": "lunch",
    "status": "completed",
    "logged_at": "2024-01-15T12:30:00Z",
    "items": [
      {
        "id": "item-uuid-1",
        "meal_log_id": "7d5a3f1c-8b2e-4d3c-9f1e-2a4b5c6d7e8f",
        "name": "Chicken Breast",
        "quantity": "120g",
        "unit": "grams",
        "calories": 198.0,
        "protein": 37.2,
        "carbohydrates": 0.0,
        "fat": 4.3,
        "fiber": 0.0,
        "sugar": 0.0,
        "confidence": 0.95,
        "notes": "Grilled, skinless"
      },
      {
        "id": "item-uuid-2",
        "meal_log_id": "7d5a3f1c-8b2e-4d3c-9f1e-2a4b5c6d7e8f",
        "name": "Broccoli",
        "quantity": "1 cup",
        "unit": "cup",
        "calories": 55.0,
        "protein": 3.7,
        "carbohydrates": 11.2,
        "fat": 0.6,
        "fiber": 5.1,
        "sugar": 2.2,
        "confidence": 0.92,
        "notes": "Steamed"
      },
      {
        "id": "item-uuid-3",
        "meal_log_id": "7d5a3f1c-8b2e-4d3c-9f1e-2a4b5c6d7e8f",
        "name": "Olive Oil",
        "quantity": "1 tbsp",
        "unit": "tablespoon",
        "calories": 119.0,
        "protein": 0.0,
        "carbohydrates": 0.0,
        "fat": 13.5,
        "fiber": 0.0,
        "sugar": 0.0,
        "confidence": 0.98,
        "notes": "Extra virgin"
      }
    ],
    "total_calories": 372.0,
    "total_protein": 40.9,
    "total_carbs": 11.2,
    "total_fat": 18.4,
    "total_fiber": 5.1,
    "total_sugar": 2.2,
    "processing_started_at": "2024-01-15T12:30:01Z",
    "processing_completed_at": "2024-01-15T12:30:04Z",
    "created_at": "2024-01-15T12:30:00Z",
    "updated_at": "2024-01-15T12:30:04Z"
  },
  "timestamp": "2024-01-15T12:30:04Z"
}
```

#### 4. Meal Log Failed

```json
{
  "type": "meal_log.failed",
  "data": {
    "meal_log_id": "7d5a3f1c-8b2e-4d3c-9f1e-2a4b5c6d7e8f",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "raw_input": "xyz123abc",
    "meal_type": "lunch",
    "error": "Failed to parse meal input",
    "error_code": "PARSING_FAILED",
    "details": "Could not identify any valid food items in the input. Please try again with clearer food descriptions.",
    "suggestions": [
      "Use specific food names (e.g., 'chicken breast' instead of 'meat')",
      "Include quantities (e.g., '100g', '1 cup', '2 slices')",
      "Separate items with commas"
    ]
  },
  "timestamp": "2024-01-15T12:30:04Z"
}
```

#### 5. Error

```json
{
  "type": "error",
  "error": "Authentication failed",
  "error_code": "AUTH_FAILED",
  "details": "JWT token is invalid or expired",
  "timestamp": "2024-01-15T12:00:00Z"
}
```

---

## Error Codes

| Code | Description | Action |
|------|-------------|--------|
| `AUTH_FAILED` | Invalid or expired JWT token | Refresh token and reconnect |
| `CONNECTION_LIMIT` | Too many connections from user | Close old connections first |
| `SERVER_ERROR` | Internal server error | Retry with exponential backoff |
| `PARSING_FAILED` | AI couldn't parse meal input | Show error to user with suggestions |
| `RATE_LIMIT` | Too many requests | Slow down requests |

---

## Implementation Requirements

### Backend

1. **New WebSocket Handler:** `/ws/meal-logs`
   - Independent from consultation WebSocket
   - JWT authentication via query param or header
   - User-specific connection tracking

2. **Connection Management:**
   - One connection per user (close old if new connects)
   - Automatic cleanup on disconnect
   - Keep-alive ping/pong (30s intervals)

3. **Notification Routing:**
   - When meal log processing completes → send to user's WebSocket
   - Include complete meal data (no need for client to poll)
   - Handle failed processing with error details

4. **Security:**
   - Validate JWT on connection
   - Rate limiting (max 10 connections/minute per user)
   - Auto-disconnect inactive connections (5 minutes)

### iOS

1. **WebSocket Client:**
   - Connect to `/ws/meal-logs` with JWT
   - Handle all message types
   - Automatic reconnection on disconnect
   - Keep-alive ping every 30s

2. **Message Handling:**
   - `connected` → Mark connection as active
   - `meal_log.completed` → Update local storage + refresh UI
   - `meal_log.failed` → Show error to user
   - `pong` → Reset timeout timer

3. **Integration:**
   - Connect on app launch (after login)
   - Disconnect on logout/app background
   - Update `SDMealLog` in local storage on notifications
   - Trigger UI refresh automatically

---

## Database Schema (Backend)

### active_websocket_connections

```sql
CREATE TABLE active_websocket_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    connection_id TEXT NOT NULL UNIQUE,
    connection_type TEXT NOT NULL, -- 'meal_logs' | 'consultation'
    connected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_ping_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    INDEX idx_user_connection_type (user_id, connection_type),
    INDEX idx_last_ping (last_ping_at)
);
```

**Purpose:**
- Track active WebSocket connections per user
- Allow cleanup of stale connections
- Enable targeted message routing

---

## API Flow Example

### Complete Meal Logging Flow

```
1. iOS App: User logs in
   ↓
2. iOS App: Connect WebSocket
   GET wss://fit-iq-backend.fly.dev/ws/meal-logs?token={jwt}
   ↓
3. Backend: Validate JWT, create connection
   ← {"type": "connected", "user_id": "..."}
   ↓
4. iOS App: Start ping timer (30s intervals)
   → {"type": "ping"}
   ← {"type": "pong"}
   ↓
5. iOS App: User enters "120g chicken breast"
   ↓
6. iOS App: Save to local storage (status: pending)
   POST /api/v1/meal-logs/natural
   {
     "raw_input": "120g chicken breast",
     "meal_type": "lunch",
     "logged_at": "2024-01-15T12:30:00Z"
   }
   ↓
7. Backend: Return immediately (status: processing)
   ← {
     "id": "meal-log-uuid",
     "status": "processing",
     ...
   }
   ↓
8. iOS App: Show meal in UI (status: pending)
   ↓
9. Backend: Process meal asynchronously (AI parsing)
   - Parse food items
   - Calculate nutrition
   - Update database
   ↓
10. Backend: Send WebSocket notification
    → WebSocket: {
      "type": "meal_log.completed",
      "data": {
        "id": "meal-log-uuid",
        "items": [...],
        "total_calories": 198,
        ...
      }
    }
    ↓
11. iOS App: Receive WebSocket message
    - Update local storage
    - Refresh UI
    - Show "Completed" status + nutrition data
```

---

## Performance Considerations

### Backend

1. **Scalability:**
   - Each WebSocket connection consumes minimal resources
   - Expected: ~1000 concurrent connections per server
   - Use connection pooling

2. **Message Routing:**
   - O(1) lookup: user_id → WebSocket connection
   - In-memory map for active connections
   - Redis for multi-server deployments

3. **Cleanup:**
   - Cron job every 5 minutes to close stale connections
   - Remove connections inactive > 10 minutes

### iOS

1. **Battery Efficiency:**
   - WebSocket is more efficient than polling
   - Ping every 30s (vs polling every 5s)
   - Auto-disconnect on app background (optional)

2. **Network Usage:**
   - WebSocket: ~50 bytes every 30s (ping/pong)
   - Polling: ~500 bytes every 5s
   - WebSocket = **95% less network traffic**

3. **Responsiveness:**
   - WebSocket: < 500ms notification delivery
   - Polling: 5-second average delay
   - WebSocket = **10x faster**

---

## Migration Path

### Phase 1: Backend Implementation (1-2 days)

1. Create `/ws/meal-logs` endpoint
2. Add JWT authentication
3. Implement connection tracking
4. Add notification routing from meal log processor
5. Deploy to staging

### Phase 2: iOS Integration (1 day)

1. Update `config.plist` with new endpoint
2. Test WebSocket connection
3. Verify message handling
4. Test reconnection logic

### Phase 3: Testing (1 day)

1. Unit tests for WebSocket handler
2. Integration tests for meal log flow
3. Load testing (1000 concurrent connections)
4. iOS app testing (create, complete, failed scenarios)

### Phase 4: Production Rollout (1 day)

1. Deploy to production
2. Monitor connection metrics
3. Gradual rollout (10% → 50% → 100%)
4. Rollback plan (revert to polling if issues)

**Total Estimate:** 5-7 days

---

## Monitoring & Metrics

### Backend Metrics

- `websocket.connections.active` - Current active connections
- `websocket.connections.total` - Total connections since start
- `websocket.messages.sent` - Total messages sent
- `websocket.notifications.meal_log.completed` - Meal log completions
- `websocket.notifications.meal_log.failed` - Meal log failures
- `websocket.errors.auth_failed` - Authentication failures

### iOS Metrics (Analytics)

- Connection success rate
- Average notification latency
- Reconnection frequency
- Battery impact (optional)

---

## Testing Checklist

### Backend

- [ ] WebSocket endpoint accepts JWT in query param
- [ ] WebSocket endpoint accepts JWT in Authorization header
- [ ] Connection tracked in database
- [ ] Duplicate connections from same user handled (close old)
- [ ] Ping/pong keep-alive works
- [ ] Meal log completion notification sent
- [ ] Meal log failure notification sent
- [ ] Stale connections cleaned up
- [ ] Rate limiting works
- [ ] Load test with 1000 concurrent connections

### iOS

- [ ] Connect to WebSocket on login
- [ ] Receive `connected` message
- [ ] Send ping every 30s
- [ ] Receive pong responses
- [ ] Receive `meal_log.completed` notification
- [ ] Update local storage on notification
- [ ] UI refreshes automatically
- [ ] Receive `meal_log.failed` notification
- [ ] Show error message to user
- [ ] Reconnect on disconnect
- [ ] Disconnect on logout
- [ ] Handle network interruptions

---

## Alternative: Enhance Consultation WebSocket

If you prefer to keep the consultation WebSocket, here's how to make it work:

### Option A: Default Consultation per User

1. Auto-create a default "meal_tracking" consultation for each user
2. iOS connects to `/api/v1/consultations/{default_id}/ws`
3. Meal log notifications come through this connection

**Pros:**
- Reuses existing infrastructure
- Supports future AI features

**Cons:**
- Still requires consultation management
- More complex client implementation

### Option B: Dedicated Endpoint (Recommended)

As specified above.

---

## Recommendation

**✅ Implement dedicated `/ws/meal-logs` endpoint**

**Rationale:**
1. **Simpler:** No consultation dependency
2. **Faster:** Quicker iOS integration
3. **Clearer:** Separation of concerns
4. **Scalable:** Independent scaling
5. **Maintainable:** Easier to debug and monitor

The consultation WebSocket can remain for AI chat features. Meal logging is a distinct use case that deserves its own endpoint.

---

## Questions for Backend Team

1. **Authentication Preference:** Query param vs Authorization header?
2. **Connection Limit:** Max connections per user? (Suggest: 1-3)
3. **Timeout:** How long before inactive connections are closed? (Suggest: 10 min)
4. **Rate Limiting:** Max connections per minute? (Suggest: 10)
5. **Multi-Server:** Using Redis for connection tracking?
6. **Monitoring:** Preferred metrics collection tool?
7. **Timeline:** When can this be implemented?

---

## Appendix: Swift Code Example

### WebSocket Connection (iOS)

```swift
class MealLogWebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let baseURL = "wss://fit-iq-backend.fly.dev"
    
    func connect(accessToken: String) async throws {
        let url = URL(string: "\(baseURL)/ws/meal-logs?token=\(accessToken)")!
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Start ping timer
        startPingTimer()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self?.handleMessage(text)
                }
                self?.receiveMessage() // Continue receiving
                
            case .failure(let error):
                print("WebSocket error: \(error)")
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        struct BaseMessage: Codable {
            let type: String
        }
        
        guard let data = text.data(using: .utf8),
              let base = try? JSONDecoder().decode(BaseMessage.self, from: data) else {
            return
        }
        
        switch base.type {
        case "connected":
            print("✅ Connected to meal log WebSocket")
        case "meal_log.completed":
            handleMealLogCompleted(data)
        case "meal_log.failed":
            handleMealLogFailed(data)
        case "pong":
            print("🏓 Pong received")
        default:
            break
        }
    }
    
    private func sendPing() {
        let message = #"{"type":"ping"}"#
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("Ping failed: \(error)")
            }
        }
    }
}
```

---

**Status:** 📋 Awaiting Backend Team Review  
**Priority:** High (Blocks meal log real-time updates)  
**Estimated Effort:** 5-7 days (Backend: 3-4 days, iOS: 1 day, Testing: 1-2 days)

---

**Next Steps:**
1. Backend team reviews specification
2. Confirm feasibility and timeline
3. Backend implements endpoint
4. iOS team integrates
5. End-to-end testing
6. Production deployment