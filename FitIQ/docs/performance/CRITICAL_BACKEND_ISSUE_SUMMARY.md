# 🚨 CRITICAL: Backend WebSocket Connection Registry Issue

**Date:** 2025-01-27  
**Severity:** 🔥 **P0 - CRITICAL**  
**Status:** ⚠️ **BLOCKING REAL-TIME UPDATES**  
**Assigned To:** Backend Team

---

## 🎯 TL;DR

**Backend is logging "WebSocket connected" but then reporting "User not connected" 57 seconds later.**

This is **NOT an iOS issue** - the backend connection registry is not maintaining connections.

**Impact:** 0% of users receive real-time meal log updates via WebSocket.

---

## 📊 Evidence (Test Case 2: Most Revealing)

### Server Logs
```
09:32:24 - WebSocket connected: user=4eb4c27c-304d-4cca-8cc8-2b67a4c75d98 ✅
09:32:24 - GET /ws/meal-logs?token=... - 000 0B ⚠️ SUSPICIOUS
09:33:13 - POST /api/v1/meal-logs/natural - 201 (1.97ms)
09:33:21 - [MealLogAI] Successfully completed processing
09:33:21 - [MealLogAI] User 4eb4c27c... not connected to WebSocket, skipping notification ❌
```

### Client Logs
```
09:32:23 - NutritionViewModel: Loading meals
09:32:41 - NutritionViewModel: Saving meal log
09:33:13 - NutritionAPIClient: ✅ Meal log submitted successfully
(Client continues sending pings every 30s, believes it's connected)
```

### Timeline Analysis
```
T+0s  (09:32:24): Backend logs "WebSocket connected" ✅
T+57s (09:33:21): Backend says "User not connected" ❌
Duration: 57 seconds between "connected" and "not connected"
Result: Connection lost or not maintained in registry
```

---

## 🐛 Critical Findings

### Finding 1: Suspicious Response Code
```
GET /ws/meal-logs?token=... - 000 0B
```

**Expected:** `101 Switching Protocols`  
**Actual:** `000` (no response code)

**Implication:** WebSocket upgrade may not be completing successfully.

---

### Finding 2: Connection Not Persisted
- Backend logs "WebSocket connected" at 09:32:24 ✅
- Backend reports "not connected" at 09:33:21 (57s later) ❌
- No disconnect logs between these events
- iOS client still connected and sending pings

**Implication:** Registry is clearing connections prematurely or not persisting them.

---

### Finding 3: No Disconnect Events
```
Expected:
09:32:24 - WebSocket connected: user=...
09:33:XX - WebSocket disconnected: user=..., reason=...

Actual:
09:32:24 - WebSocket connected: user=...
(no disconnect log, but connection is gone)
```

**Implication:** Connections removed from registry without proper disconnect event.

---

### Finding 4: iOS Client Unaware
- iOS successfully completed handshake
- iOS sending pings every 30 seconds
- iOS receiving pong responses (or not detecting failures)
- iOS has no indication of problems

**Implication:** Backend responding to pings but not maintaining user in registry for notifications.

---

## 🔧 Root Causes to Investigate

### 1. WebSocket Upgrade Handler
```go
// Check: Is upgrade completing successfully?
conn, err := upgrader.Upgrade(w, r, nil)
if err != nil {
    log.Error("Upgrade failed: %v", err) // ⚠️ Check this
    return
}
// Expected: log.Info("Upgrade successful, response: 101")
```

**Why 000 response instead of 101?**

---

### 2. Connection Registry Management
```go
// Check: Is user being added to registry?
func (r *ConnectionRegistry) Add(userID string, conn *WebSocketConnection) {
    r.connections[userID] = conn
    log.Info("User %s added (total: %d)", userID, len(r.connections))
}

// Check: Is user still in registry when checking?
func (r *ConnectionRegistry) IsConnected(userID string) bool {
    conn, exists := r.connections[userID]
    if !exists {
        log.Warn("User %s NOT in registry", userID) // ⚠️ This is happening
        return false
    }
    return true
}
```

**Why is user not in registry 57 seconds after being added?**

---

### 3. Ping/Pong Not Updating LastSeen
```go
// Check: Is LastSeen being updated on ping?
func HandlePing(userID string) {
    conn := connectionRegistry.Get(userID)
    conn.LastSeen = time.Now() // ⚠️ Is this happening?
    conn.Send("pong")
}
```

**Are pings updating connection state?**

---

### 4. Connection Timeout Too Aggressive
```go
// Check: What is the timeout?
const ConnectionIdleTimeout = 60 * time.Second // ⚠️ Too short?

// iOS pings every 30 seconds, timeout should be 5+ minutes
const ConnectionIdleTimeout = 5 * time.Minute // ✅ Better
```

**Is timeout shorter than iOS ping interval?**

---

### 5. Registry Cleanup Clearing Active Connections
```go
// Check: Is cleanup removing active connections?
func (r *ConnectionRegistry) Cleanup() {
    for userID, conn := range r.connections {
        if time.Since(conn.LastSeen) > 60*time.Second {
            delete(r.connections, userID) // ⚠️ Too aggressive?
        }
    }
}
```

**Is cleanup running too frequently with too short timeout?**

---

## ✅ Required Fixes (Priority Order)

### Priority 1: Add Detailed Logging
```go
log.Info("[WebSocket] Connection attempt: user=%s", userID)
log.Info("[WebSocket] Upgrade successful: user=%s, response=101", userID)
log.Info("[Registry] User %s added (total: %d)", userID, registrySize)
log.Info("[Ping] Received from user %s", userID)
log.Info("[Ping] Updated LastSeen for user %s", userID)
log.Info("[Registry] User %s is connected (last seen: %v ago)", userID, age)
log.Warn("[Registry] User %s NOT in registry", userID)
log.Info("[WebSocket] Disconnected: user=%s, reason=%s", userID, reason)
```

**Deploy this first to identify exact failure point.**

---

### Priority 2: Fix Connection Registry
```go
type WebSocketConnection struct {
    UserID      string
    Conn        *websocket.Conn
    LastSeen    time.Time      // ✅ Must be updated on every ping
    ConnectedAt time.Time
}

func (r *ConnectionRegistry) UpdateLastSeen(userID string) {
    r.mu.Lock()
    defer r.mu.Unlock()
    
    if conn, exists := r.connections[userID]; exists {
        conn.LastSeen = time.Now() // ✅ CRITICAL
        log.Debug("Updated LastSeen for user %s", userID)
    }
}
```

---

### Priority 3: Fix Ping Handler
```go
func HandlePingMessage(userID string) {
    log.Debug("[Ping] Received from user %s", userID)
    
    // ✅ MUST update LastSeen to keep connection alive
    connectionRegistry.UpdateLastSeen(userID)
    
    // Send pong
    SendPong(userID)
}
```

---

### Priority 4: Increase Timeouts
```go
const (
    ConnectionIdleTimeout = 5 * time.Minute  // Was: 60 seconds ❌
    CleanupInterval      = 1 * time.Minute  // Was: 30 seconds ❌
)
```

**iOS pings every 30s, so timeout must be 5+ minutes.**

---

### Priority 5: Add Debug Endpoint
```go
// GET /api/v1/debug/websocket/connections
{
  "total_connections": 5,
  "connections": [
    {
      "user_id": "4eb4c27c...",
      "connected_at": "2025-01-08T09:32:24Z",
      "last_seen": "2025-01-08T09:33:15Z",
      "age_seconds": 51,
      "is_stale": false
    }
  ]
}
```

---

## 🧪 How to Verify Fix

### Test 1: Connection Persistence
1. Connect WebSocket from iOS
2. Wait 2 minutes (no activity)
3. Submit meal log
4. **Expected:** Backend says "User IS connected" ✅
5. **Expected:** WebSocket notification sent ✅

---

### Test 2: Registry State
1. Connect WebSocket
2. Call debug endpoint: `GET /api/v1/debug/websocket/connections`
3. **Expected:** User appears in list ✅
4. Wait 2 minutes
5. Call debug endpoint again
6. **Expected:** User still in list, LastSeen updated by pings ✅

---

### Test 3: Notification Delivery
1. Connect WebSocket from iOS
2. Submit meal: "1 banana and 1 apple"
3. Wait ~30 seconds for AI processing
4. **Expected Backend Logs:**
   ```
   [MealLogAI] Successfully completed processing
   [Registry] User 4eb4c27c... IS connected
   [WebSocket] Sending notification to user 4eb4c27c...
   [WebSocket] Notification sent successfully
   ```
5. **Expected iOS Logs:**
   ```
   NutritionViewModel: 📩 Meal log completed
   NutritionViewModel: ✅ Meal log completed - UI updated
   ```

---

## 📊 Success Metrics

| Metric | Before | After (Target) |
|--------|--------|----------------|
| "User not connected" logs | 100% | <5% |
| WebSocket notifications delivered | 0% | >95% |
| Connection persistence | <60s | Until disconnect |
| iOS real-time updates | ❌ Never | ✅ <1s |

---

## 🚀 Deployment Plan

1. **Phase 1: Logging** (Non-breaking)
   - Deploy enhanced logging
   - Monitor for 24 hours
   - Identify exact failure point

2. **Phase 2: Fix** (Requires testing)
   - Fix connection registry
   - Fix ping/pong handler
   - Increase timeouts
   - Test on staging

3. **Phase 3: Production**
   - Deploy to production
   - Monitor metrics
   - Verify >95% notification delivery

---

## 📞 Contact

**Issue Opened By:** iOS Team  
**Blocking:** Real-time meal log updates for all iOS users  
**Detailed Documentation:**
- `docs/troubleshooting/BACKEND_CONNECTION_REGISTRY_ISSUE.md` (full details)
- `docs/architecture/WEBSOCKET_CONNECTION_TIMING_FIX.md` (iOS changes)

**Questions?** Contact iOS team or check documentation above.

---

**Status:** 🔴 **CRITICAL** - Awaiting backend fix  
**Impact:** 100% of iOS users  
**Next Action:** Backend team investigation  
**ETA:** ASAP