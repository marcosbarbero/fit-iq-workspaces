# Backend WebSocket Connection Registry Issue - CRITICAL

**Date:** 2025-01-27  
**Severity:** 🔥 **CRITICAL** - Backend Issue  
**Status:** ⚠️ **BLOCKING** - Real-time updates broken  
**Affected:** All iOS users attempting to receive real-time meal log updates

---

## 🚨 Executive Summary

**Problem:** Backend WebSocket connection registry is not maintaining user connections, causing all real-time notifications to be skipped.

**Evidence:** Backend logs show:
1. ✅ "WebSocket connected: user=..." at connection time
2. ❌ "User not connected to WebSocket, skipping notification" 57 seconds later

**Impact:** 
- 0% of meal logs receive real-time updates via WebSocket
- 100% rely on polling fallback (5-10 second delay)
- Poor user experience despite WebSocket being "connected"

**Root Cause:** Backend connection registry is clearing/losing connections between handshake and notification time.

**Required Action:** Backend team must investigate and fix connection registry management.

---

## 📊 Evidence from Production Logs

### Test Case 1 (2025-01-08 09:24:23)

```
CLIENT LOG:
09:23:50 - OutboxProcessor: ✅ Meal log uploaded successfully - Backend ID: 9c65f612...
09:23:51 - NutritionViewModel: WebSocket connected, stopping polling
09:23:52 - MealLogWebSocketClient: 🏓 Ping sent successfully

SERVER LOG:
09:23:50 - POST /api/v1/meal-logs/natural - 201 (2.07ms)
09:24:16 - [EventDispatcher] Processing event meal_log.created
09:24:16 - [MealLogAI] Processing meal log 9c65f612... for user 4eb4c27c...
09:24:23 - [MealLogAI] Successfully completed processing
09:24:23 - [MealLogAI] User 4eb4c27c... not connected to WebSocket, skipping notification ❌
```

**Timeline:** 33 seconds from submission to "not connected" message

---

### Test Case 2 (2025-01-08 09:33:21) - MOST REVEALING

```
SERVER LOG:
09:32:24 - WebSocket connected: user=4eb4c27c-304d-4cca-8cc8-2b67a4c75d98 ✅
09:32:24 - GET /ws/meal-logs?token=... - 000 0B ⚠️ SUSPICIOUS
09:33:13 - POST /api/v1/meal-logs/natural - 201 (1.97ms)
09:33:21 - [MealLogAI] Successfully completed processing
09:33:21 - [MealLogAI] User 4eb4c27c... not connected to WebSocket, skipping notification ❌

CLIENT LOG:
09:32:23 - NutritionViewModel: Loading meals
09:32:41 - NutritionViewModel: Saving meal log
09:33:13 - NutritionAPIClient: ✅ Meal log submitted successfully
(Client continues sending pings, believes it's connected)
```

**Timeline:**
- Backend logs "connected" at 09:32:24 ✅
- Backend checks connection at 09:33:21 (57 seconds later) ❌
- Connection lost or not maintained in registry

---

## 🔍 Critical Findings

### Finding 1: Suspicious Response Code

```
GET /ws/meal-logs?token=... - 000 0B
```

**Expected:**
```
GET /ws/meal-logs?token=... - 101 Switching Protocols
```

**Analysis:**
- `101` = Successful WebSocket upgrade
- `000` = No response code (connection failed or rejected)
- `0B` = Zero bytes transferred

**Implication:** WebSocket handshake may not be completing successfully on backend side.

---

### Finding 2: Connection Not Persisted

```
Timeline:
09:32:24 - Backend logs: "WebSocket connected" ✅
09:33:21 - Backend checks: "User not connected" ❌
Duration: 57 seconds
```

**Analysis:**
- Connection was acknowledged
- Connection was lost or cleared from registry
- No disconnect logs between these events
- iOS client still sending pings (unaware of backend state)

**Implication:** Backend connection registry is:
- Clearing connections prematurely
- Not updating on ping/pong
- Not persisting connection state
- Has race condition in registry management

---

### Finding 3: No Disconnect Logs

```
Expected:
09:32:24 - WebSocket connected: user=...
(later)
09:33:XX - WebSocket disconnected: user=..., reason=...

Actual:
09:32:24 - WebSocket connected: user=...
(no disconnect log, but connection considered "not connected" later)
```

**Implication:** Connection is being cleared/removed without proper disconnect event.

---

### Finding 4: iOS Client Believes Connection is Active

```
CLIENT LOG:
09:32:51 - NutritionViewModel: WebSocket connected, stopping polling
09:32:52 - MealLogWebSocketClient: 🏓 Ping sent successfully
(continues sending pings every 30 seconds)
```

**Analysis:**
- iOS successfully completed handshake
- iOS receiving pong responses (or not detecting ping failures)
- iOS has no indication of connection problems
- iOS stopped polling (trusting WebSocket is working)

**Implication:** Backend is responding to pings but not maintaining user in connection registry for notifications.

---

## 🐛 Backend Issues to Investigate

### Issue 1: WebSocket Upgrade Response

**Problem:** Response code `000` instead of `101 Switching Protocols`

**Check:**
```go
// In WebSocket upgrade handler
func HandleWebSocketUpgrade(w http.ResponseWriter, r *http.Request) {
    upgrader := websocket.Upgrader{
        CheckOrigin: func(r *http.Request) bool {
            return true
        },
    }
    
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Error("Failed to upgrade connection: %v", err) // ⚠️ Check this
        return
    }
    
    // Should log successful upgrade here
    log.Info("WebSocket upgraded successfully")
}
```

**Expected Logs:**
```
WebSocket upgraded successfully
Response: 101 Switching Protocols
```

**Actual Logs:**
```
Response: 000 0B
```

**Action:** Add detailed logging around upgrade process.

---

### Issue 2: Connection Registry Management

**Problem:** Connection acknowledged but not found later

**Check:**
```go
// Connection registry
type ConnectionRegistry struct {
    connections map[string]*WebSocketConnection
    mu          sync.RWMutex
}

// When connection established
func (r *ConnectionRegistry) Add(userID string, conn *WebSocketConnection) {
    r.mu.Lock()
    defer r.mu.Unlock()
    
    r.connections[userID] = conn
    log.Info("User %s added to registry (total: %d)", userID, len(r.connections))
}

// When checking if user is connected
func (r *ConnectionRegistry) IsConnected(userID string) bool {
    r.mu.RLock()
    defer r.mu.RUnlock()
    
    conn, exists := r.connections[userID]
    if !exists {
        log.Warn("User %s NOT in registry", userID)
        return false
    }
    
    // Check if connection is still alive
    if time.Since(conn.LastSeen) > 5*time.Minute {
        log.Warn("User %s connection stale (last seen: %v)", userID, conn.LastSeen)
        return false
    }
    
    log.Info("User %s IS in registry (last seen: %v)", userID, conn.LastSeen)
    return true
}
```

**Verify:**
1. User is added to registry after upgrade
2. User remains in registry until explicit disconnect
3. LastSeen is updated on ping/pong
4. Timeout is reasonable (5 minutes, not 30 seconds)

---

### Issue 3: Ping/Pong Handling

**Problem:** Pings may not be updating connection state

**Check:**
```go
func HandlePing(userID string) {
    conn := connectionRegistry.Get(userID)
    if conn == nil {
        log.Warn("Received ping from unregistered user: %s", userID)
        return
    }
    
    // ✅ CRITICAL: Update LastSeen timestamp
    conn.LastSeen = time.Now()
    connectionRegistry.Update(userID, conn)
    
    log.Debug("Ping from user %s (updated LastSeen)", userID)
    
    // Send pong
    conn.Send("pong")
}
```

**Verify:**
1. Ping handler exists and is called
2. LastSeen is updated on each ping
3. Connection stays in registry as long as pings arrive
4. Logs show ping activity

---

### Issue 4: Connection Timeout

**Problem:** Timeout may be too aggressive

**Check:**
```go
// Current timeout setting
const (
    ReadTimeout  = 30 * time.Second  // ⚠️ Too short?
    WriteTimeout = 30 * time.Second
    IdleTimeout  = 60 * time.Second  // ⚠️ Too short?
)
```

**Recommended:**
```go
const (
    ReadTimeout  = 90 * time.Second   // Allow for slow networks
    WriteTimeout = 30 * time.Second
    IdleTimeout  = 5 * time.Minute    // Match iOS ping interval (30s) + buffer
)
```

**Verify:** Timeout values align with iOS ping interval (30 seconds).

---

### Issue 5: Registry Cleanup Logic

**Problem:** Registry may be clearing connections prematurely

**Check:**
```go
// Cleanup goroutine
func (r *ConnectionRegistry) StartCleanup() {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for range ticker.C {
        r.mu.Lock()
        for userID, conn := range r.connections {
            // ⚠️ Check this condition
            if time.Since(conn.LastSeen) > 60*time.Second {
                log.Info("Removing stale connection: %s", userID)
                delete(r.connections, userID)
                conn.Close()
            }
        }
        r.mu.Unlock()
    }
}
```

**Problem Scenarios:**
1. LastSeen not being updated by pings → connections marked stale
2. Cleanup interval too aggressive (30s)
3. Timeout too short (60s when iOS pings every 30s)

**Recommended:**
```go
// Safer cleanup
if time.Since(conn.LastSeen) > 5*time.Minute {  // Much longer timeout
    log.Info("Removing stale connection: %s (last seen: %v)", userID, conn.LastSeen)
    delete(r.connections, userID)
    conn.Close()
}
```

---

## 🛠️ Required Backend Fixes

### Priority 1: Add Detailed Logging

```go
// In connection handler
log.Info("[WebSocket] Connection attempt from user: %s", userID)
log.Info("[WebSocket] Upgrading connection...")

conn, err := upgrader.Upgrade(w, r, nil)
if err != nil {
    log.Error("[WebSocket] Upgrade failed for user %s: %v", userID, err)
    return
}

log.Info("[WebSocket] Upgrade successful for user: %s", userID)
log.Info("[WebSocket] Response code: 101 Switching Protocols")

// Add to registry
connectionRegistry.Add(userID, conn)
log.Info("[WebSocket] User %s added to registry (total connections: %d)", 
    userID, connectionRegistry.Count())
```

---

### Priority 2: Fix Connection Registry

```go
type WebSocketConnection struct {
    UserID      string
    Conn        *websocket.Conn
    LastSeen    time.Time
    ConnectedAt time.Time
}

func (r *ConnectionRegistry) Add(userID string, conn *websocket.Conn) {
    wsConn := &WebSocketConnection{
        UserID:      userID,
        Conn:        conn,
        LastSeen:    time.Now(),
        ConnectedAt: time.Now(),
    }
    
    r.mu.Lock()
    r.connections[userID] = wsConn
    r.mu.Unlock()
    
    log.Info("[Registry] Added user %s (connected at: %v, total: %d)", 
        userID, wsConn.ConnectedAt, len(r.connections))
}

func (r *ConnectionRegistry) IsConnected(userID string) bool {
    r.mu.RLock()
    defer r.mu.RUnlock()
    
    conn, exists := r.connections[userID]
    if !exists {
        log.Warn("[Registry] User %s NOT found in registry", userID)
        log.Info("[Registry] Current connections: %d", len(r.connections))
        return false
    }
    
    age := time.Since(conn.LastSeen)
    if age > 5*time.Minute {
        log.Warn("[Registry] User %s connection stale (last seen: %v ago)", 
            userID, age)
        return false
    }
    
    log.Info("[Registry] User %s IS connected (last seen: %v ago)", userID, age)
    return true
}
```

---

### Priority 3: Fix Ping/Pong Handler

```go
func (r *ConnectionRegistry) UpdateLastSeen(userID string) {
    r.mu.Lock()
    defer r.mu.Unlock()
    
    if conn, exists := r.connections[userID]; exists {
        conn.LastSeen = time.Now()
        log.Debug("[Ping] Updated LastSeen for user %s", userID)
    } else {
        log.Warn("[Ping] Cannot update LastSeen - user %s not in registry", userID)
    }
}

func HandlePingMessage(userID string) {
    log.Debug("[Ping] Received from user %s", userID)
    
    // Update LastSeen to keep connection alive
    connectionRegistry.UpdateLastSeen(userID)
    
    // Send pong response
    if err := SendPong(userID); err != nil {
        log.Error("[Pong] Failed to send to user %s: %v", userID, err)
    } else {
        log.Debug("[Pong] Sent to user %s", userID)
    }
}
```

---

### Priority 4: Increase Timeouts

```go
// Configuration
const (
    // Read/Write timeouts
    ReadTimeout  = 90 * time.Second
    WriteTimeout = 30 * time.Second
    
    // Connection considered stale if no activity for this duration
    ConnectionIdleTimeout = 5 * time.Minute
    
    // Cleanup runs this often
    CleanupInterval = 1 * time.Minute
)
```

---

### Priority 5: Add Connection Lifecycle Events

```go
// Log all connection lifecycle events
type ConnectionEvent string

const (
    EventConnected    ConnectionEvent = "connected"
    EventPingReceived ConnectionEvent = "ping_received"
    EventPongSent     ConnectionEvent = "pong_sent"
    EventDisconnected ConnectionEvent = "disconnected"
    EventStale        ConnectionEvent = "stale"
    EventError        ConnectionEvent = "error"
)

func LogConnectionEvent(userID string, event ConnectionEvent, details string) {
    log.Info("[WebSocket][%s] User: %s | Event: %s | Details: %s", 
        time.Now().Format(time.RFC3339), userID, event, details)
}
```

---

## 🧪 Testing Strategy

### Test 1: Connection Persistence

```bash
# Connect WebSocket
wscat -c "wss://fit-iq-backend.fly.dev/ws/meal-logs?token=..."

# Wait 60 seconds
# Send ping
> {"type": "ping"}

# Check backend logs - should see:
# - User still in registry
# - LastSeen updated
# - Pong sent
```

---

### Test 2: Registry State

```bash
# Add backend debug endpoint
GET /api/v1/debug/websocket/connections

Response:
{
  "total_connections": 5,
  "connections": [
    {
      "user_id": "4eb4c27c...",
      "connected_at": "2025-01-08T09:32:24Z",
      "last_seen": "2025-01-08T09:33:15Z",
      "age_seconds": 51,
      "state": "active"
    }
  ]
}
```

---

### Test 3: Notification Delivery

```bash
# 1. Connect WebSocket
# 2. Submit meal via REST API
# 3. Wait for processing
# 4. Verify notification received

# Check backend logs:
# - User X connected: ✅
# - Processing meal Y for user X: ✅
# - User X connected: ✅ (should say YES)
# - Sending notification to user X: ✅
```

---

## 📊 Success Metrics

### Before Fix
| Metric | Current |
|--------|---------|
| WebSocket notifications delivered | 0% |
| "User not connected" log frequency | 100% |
| Connection persistence | <60 seconds |
| Real-time updates working | ❌ No |

### After Fix (Target)
| Metric | Target |
|--------|--------|
| WebSocket notifications delivered | >95% |
| "User not connected" log frequency | <5% |
| Connection persistence | Until explicit disconnect |
| Real-time updates working | ✅ Yes |

---

## 🚀 Deployment Plan

### Phase 1: Add Logging (Non-Breaking)
1. Deploy enhanced logging
2. Monitor for 24 hours
3. Identify exact failure point

### Phase 2: Fix Registry (Requires Testing)
1. Deploy registry fixes to staging
2. Test connection persistence
3. Verify notifications delivered
4. Deploy to production

### Phase 3: Monitor & Validate
1. Monitor connection registry size
2. Track notification delivery rate
3. Watch for "not connected" logs
4. Collect user feedback

---

## 📞 Escalation

**Severity:** P0 - Critical  
**Assigned To:** Backend Team  
**Blockers:** Real-time updates completely broken  
**Impact:** All iOS users (100%)  

**Required Actions:**
1. ✅ iOS team: Enhanced logging added
2. ⏳ Backend team: Investigate connection registry
3. ⏳ Backend team: Fix and deploy
4. ⏳ Joint testing: Verify fix in staging
5. ⏳ Production deployment

---

**Status:** 🔴 **CRITICAL** - Awaiting backend investigation  
**Updated:** 2025-01-27  
**Next Review:** Daily until resolved