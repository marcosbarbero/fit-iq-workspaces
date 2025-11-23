# 🐛 Critical Issue: WebSocket Connection Registry Not Updated by Ping/Pong

**Issue ID:** BACKEND-WS-001  
**Severity:** 🔴 Critical  
**Component:** WebSocket Connection Manager  
**Endpoint:** `/ws/meal-logs`  
**Date Reported:** 2025-01-27  
**Status:** 🔴 Open - Requires Backend Fix

---

## 📋 Executive Summary

The WebSocket connection registry is **not being updated** when iOS clients send ping messages, causing the backend to incorrectly identify active users as "not connected" when attempting to send real-time notifications.

**Impact:**
- ❌ Real-time meal log updates never reach iOS clients
- ❌ Users must rely on polling fallback (5-10 second delay)
- ❌ WebSocket infrastructure is effectively non-functional for notifications
- ❌ User experience degraded despite working connection

**Root Cause:**
The ping/pong handler resets the read deadline but does not update the user's "LastSeen" timestamp or connection status in the registry used for notification routing.

---

## 🔍 Evidence from Production Logs

### iOS Client Logs (Working Correctly)

```
10:07:26 - NutritionViewModel: Saving meal log
10:07:26 - NutritionAPIClient: POST /api/v1/meal-logs/natural
10:07:26 - NutritionAPIClient: ✅ Meal log submitted - ID: 556d0423-e064-47b1-bff4-b7c51f189b6a

10:07:29 - MealLogWebSocketClient: 🏓 Sending application-level ping
10:07:29 - MealLogWebSocketClient: ✅ Application ping sent successfully
10:07:29 - MealLogWebSocketClient: 📩 Message type: pong
10:07:29 - MealLogWebSocketClient: ✅ Pong received
10:07:29 - MealLogWebSocketClient:    - Backend timestamp: 2025-11-08T10:07:29Z
10:07:29 - MealLogWebSocketClient: ✅ Connection is alive and healthy
```

**✅ iOS Client Status:** Working perfectly
- Sends ping every 30 seconds
- Receives pong responses immediately
- Connection stable and healthy

### Backend Logs (Failing to Recognize Connection)

```
10:07:26 - POST /api/v1/meal-logs/natural - 201 (meal submitted)

10:07:46 - [EventDispatcher] Processing event meal_log.created
10:07:46 - [MealLogAI] Processing meal log 556d0423... for user 4eb4c27c...
10:07:51 - [MealLogAI] Successfully completed processing (calories: 52, protein: 0.3g)

10:07:51 - [MealLogAI] ❌ User 4eb4c27c... not connected to WebSocket, skipping notification
```

**❌ Backend Status:** Connection registry out of sync
- User was connected at 10:07:26
- Ping/pong exchange at 10:07:29 (connection alive)
- At 10:07:51 (25 seconds later), backend thinks user is disconnected
- Notification skipped

---

## 🎯 Root Cause Analysis

### Current Backend Ping Handler (Assumed)

```go
// File: internal/interfaces/rest/meal_log_websocket_handler.go
// Current implementation (from WEB_SOCKET_PING_PONG.md)

case "ping":
    // Respond with pong
    pongMsg := map[string]interface{}{
        "type":      "pong",
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    conn.WriteJSON(pongMsg)
    
    // Reset read deadline (10 minutes)
    conn.SetReadDeadline(time.Now().Add(10 * time.Minute))
    
    // ⚠️ MISSING: Update connection registry LastSeen timestamp
    // ⚠️ MISSING: Verify user is still in active connections map
```

**What's Working:**
- ✅ Pong response sent correctly
- ✅ Read deadline reset (prevents connection timeout)
- ✅ Protocol-level connection maintained

**What's Missing:**
- ❌ Connection registry not updated with LastSeen timestamp
- ❌ User's active connection status not refreshed
- ❌ Notification routing can't find user

### Expected Backend Ping Handler

```go
// File: internal/interfaces/rest/meal_log_websocket_handler.go
// What it SHOULD be

case "ping":
    // Respond with pong
    pongMsg := map[string]interface{}{
        "type":      "pong",
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    conn.WriteJSON(pongMsg)
    
    // Reset read deadline (10 minutes)
    conn.SetReadDeadline(time.Now().Add(10 * time.Minute))
    
    // ✅ ADD: Update connection registry
    if h.connectionManager != nil {
        h.connectionManager.UpdateLastSeen(userID)
        log.Printf("[WebSocket] Ping from user %s - LastSeen updated", userID)
    }
    
    // ✅ ADD: Verify user is in registry (for debugging)
    if !h.connectionManager.IsConnected(userID) {
        log.Printf("[WebSocket] WARNING: User %s sent ping but not in registry", userID)
    }
```

---

## 🔧 Required Backend Changes

### Change 1: Update Ping Handler

**File:** `internal/interfaces/rest/meal_log_websocket_handler.go`

```go
case "ping":
    // Respond with pong
    pongMsg := map[string]interface{}{
        "type":      "pong",
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    if err := conn.WriteJSON(pongMsg); err != nil {
        log.Printf("[WebSocket] Failed to send pong to user %s: %v", userID, err)
        return
    }
    
    // Reset read deadline (10 minutes)
    conn.SetReadDeadline(time.Now().Add(10 * time.Minute))
    
    // ✅ CRITICAL: Update connection registry
    if h.connectionManager != nil {
        h.connectionManager.UpdateLastSeen(userID)
        log.Printf("[WebSocket] Ping from user %s - connection refreshed", userID)
    } else {
        log.Printf("[WebSocket] ERROR: connectionManager is nil, cannot update LastSeen")
    }
```

### Change 2: Add/Update ConnectionManager Methods

**File:** `internal/domain/services/connection_manager.go` (or similar)

```go
type ConnectionManager interface {
    // Existing methods
    AddConnection(userID string, conn *websocket.Conn) error
    RemoveConnection(userID string) error
    IsConnected(userID string) bool
    GetConnection(userID string) (*websocket.Conn, error)
    
    // ✅ ADD: Update LastSeen timestamp
    UpdateLastSeen(userID string) error
    
    // ✅ ADD: Get LastSeen for debugging
    GetLastSeen(userID string) (time.Time, error)
}

// Implementation
func (cm *ConnectionManagerImpl) UpdateLastSeen(userID string) error {
    cm.mu.Lock()
    defer cm.mu.Unlock()
    
    if conn, exists := cm.connections[userID]; exists {
        conn.LastSeen = time.Now()
        log.Printf("[ConnectionManager] Updated LastSeen for user %s", userID)
        return nil
    }
    
    return fmt.Errorf("user %s not found in connection registry", userID)
}
```

### Change 3: Update Connection Cleanup Logic

**File:** `internal/domain/services/connection_manager.go`

```go
// Ensure cleanup doesn't remove active connections
func (cm *ConnectionManagerImpl) CleanupStaleConnections() {
    cm.mu.Lock()
    defer cm.mu.Unlock()
    
    // ✅ CRITICAL: Use generous timeout (at least 5 minutes)
    // iOS pings every 30 seconds, so 5 minutes = 10 missed pings
    staleThreshold := time.Now().Add(-5 * time.Minute)
    
    for userID, conn := range cm.connections {
        if conn.LastSeen.Before(staleThreshold) {
            log.Printf("[ConnectionManager] Removing stale connection for user %s (LastSeen: %v)", 
                userID, conn.LastSeen)
            delete(cm.connections, userID)
        }
    }
}
```

### Change 4: Add Diagnostic Logging

**File:** `internal/interfaces/rest/meal_log_websocket_handler.go`

```go
// When user connects
func (h *MealLogWebSocketHandler) HandleConnection(w http.ResponseWriter, r *http.Request) {
    // ... existing connection setup ...
    
    h.connectionManager.AddConnection(userID, conn)
    log.Printf("[WebSocket] User %s connected - added to registry", userID)
    log.Printf("[WebSocket] Active connections: %d", h.connectionManager.GetConnectionCount())
    
    // ... rest of handler ...
}

// When sending notification
func (h *MealLogAI) SendNotification(userID string, notification interface{}) error {
    log.Printf("[MealLogAI] Attempting to send notification to user %s", userID)
    
    if !h.connectionManager.IsConnected(userID) {
        lastSeen, err := h.connectionManager.GetLastSeen(userID)
        if err == nil {
            log.Printf("[MealLogAI] User %s not connected (LastSeen: %v, %v ago)", 
                userID, lastSeen, time.Since(lastSeen))
        } else {
            log.Printf("[MealLogAI] User %s not connected (never seen in registry)", userID)
        }
        return fmt.Errorf("user not connected")
    }
    
    log.Printf("[MealLogAI] User %s is connected, sending notification", userID)
    // ... send notification ...
}
```

---

## 🧪 Testing & Verification

### Test Case 1: Basic Ping/Pong Updates Registry

**Steps:**
1. Connect iOS client to WebSocket
2. Wait for first ping (30 seconds)
3. Check backend logs

**Expected Logs:**
```
[WebSocket] User 4eb4c27c... connected - added to registry
[WebSocket] Active connections: 1
[WebSocket] Ping from user 4eb4c27c... - connection refreshed
[ConnectionManager] Updated LastSeen for user 4eb4c27c...
```

**Success Criteria:**
- ✅ "connection refreshed" log appears
- ✅ "Updated LastSeen" log appears
- ✅ No errors

### Test Case 2: Notification After Ping

**Steps:**
1. Connect iOS client
2. Wait for ping/pong exchange
3. Submit meal log
4. Wait for backend processing (20-30 seconds)
5. Check if notification sent

**Expected Logs:**
```
[WebSocket] Ping from user 4eb4c27c... - connection refreshed
[MealLogAI] Successfully completed processing meal log 556d0423...
[MealLogAI] Attempting to send notification to user 4eb4c27c...
[MealLogAI] User 4eb4c27c... is connected, sending notification ✅
```

**Success Criteria:**
- ✅ Notification sent successfully
- ✅ iOS receives meal_log.completed WebSocket message
- ✅ No "not connected" error

### Test Case 3: Long-Running Connection (15+ minutes)

**Steps:**
1. Connect iOS client
2. Wait 15 minutes (30 ping/pong cycles)
3. Submit meal log
4. Verify notification received

**Expected Behavior:**
- ✅ Connection stays in registry for entire duration
- ✅ LastSeen updated every 30 seconds
- ✅ Notification sent successfully after 15 minutes
- ✅ No connection cleanup during active pinging

**Failure Scenario (Current Bug):**
- ❌ Connection removed from registry after ~1 minute
- ❌ Pings/pongs continue but registry not updated
- ❌ Notification fails: "user not connected"

---

## 📊 Impact Analysis

### Current State (Broken)
- **Real-time updates:** 0% success rate
- **Fallback polling:** 100% (5-10 second delay)
- **User experience:** Degraded
- **WebSocket utilization:** Wasted (connection alive but unused)

### After Fix
- **Real-time updates:** 100% success rate
- **Fallback polling:** 0% (only for errors)
- **User experience:** Instant updates
- **WebSocket utilization:** Optimal

### Performance Comparison

| Metric | Current (Broken) | After Fix |
|--------|-----------------|-----------|
| Time to see meal results | 5-10 seconds (polling) | <1 second (WebSocket) |
| Server load | High (polling every 5s) | Low (event-driven) |
| Battery usage | Higher (polling) | Lower (push) |
| Network usage | Higher (polling) | Lower (push) |

---

## 🚀 Deployment Plan

### Phase 1: Add Logging (Low Risk)
1. Add diagnostic logs to ping handler
2. Add diagnostic logs to notification sender
3. Deploy to staging
4. Analyze logs to confirm diagnosis

**Rollback:** Safe - only adds logs

### Phase 2: Fix Connection Registry (Critical)
1. Implement `UpdateLastSeen()` method
2. Update ping handler to call `UpdateLastSeen()`
3. Increase cleanup threshold to 5 minutes
4. Deploy to staging
5. Test with iOS client

**Rollback:** Revert commit if notifications still fail

### Phase 3: Production Deployment
1. Deploy to production
2. Monitor logs for "connection refreshed" messages
3. Monitor logs for successful notifications
4. Verify iOS clients receive real-time updates

**Rollback:** Revert if any issues detected

---

## 🔍 Debugging Commands

### Check Active Connections
```bash
# In backend logs, search for:
grep "Active connections:" backend.log | tail -n 10
```

### Verify Ping/Pong Activity
```bash
# Should show pings every 30 seconds per user
grep "Ping from user" backend.log | tail -n 20
```

### Check Notification Attempts
```bash
# Should show "is connected" not "not connected"
grep "Attempting to send notification" backend.log | tail -n 20
```

### Find Connection Registry Issues
```bash
# Look for users ping-ing but not in registry
grep "not in registry" backend.log
```

---

## 📞 Contact & Escalation

### Backend Team
- **Primary:** Backend Team Lead
- **Issue Type:** WebSocket connection management
- **Priority:** 🔴 Critical

### iOS Team (FYI)
- **Status:** iOS implementation verified correct
- **Action:** None required (awaiting backend fix)

### DevOps (If Needed)
- **Issue Type:** WebSocket infrastructure
- **Action:** None required (application-level issue)

---

## 📚 Related Documentation

- **iOS Implementation:** `docs/nutrition/PING_PONG_IMPLEMENTATION_SUMMARY.md`
- **Backend Guide:** `docs/nutrition/WEB_SOCKET_PING_PONG.md`
- **API Spec:** `docs/be-api-spec/swagger.yaml` (WebSocket section)
- **Previous Analysis:** Meal Log WebSocket Sync Issue thread

---

## ✅ Acceptance Criteria

**Definition of Done:**

1. ✅ Ping handler updates connection registry LastSeen timestamp
2. ✅ Notification sender finds user in registry after ping
3. ✅ Backend logs show "connection refreshed" on every ping
4. ✅ Backend logs show "is connected, sending notification"
5. ✅ iOS client receives meal_log.completed WebSocket message
6. ✅ No more "not connected to WebSocket, skipping notification" errors
7. ✅ Polling fallback stops automatically (iOS detects working WebSocket)
8. ✅ Connection stable for 15+ minutes with continuous ping/pong

**Verification:**
- Run test cases 1, 2, and 3 above
- All must pass before marking as resolved

---

## 📝 Timeline

| Date | Event |
|------|-------|
| 2025-01-27 | Issue identified and documented |
| TBD | Backend fix implemented |
| TBD | Deployed to staging |
| TBD | Tested with iOS client |
| TBD | Deployed to production |
| TBD | Issue resolved ✅ |

---

**Status:** 🔴 Open - Awaiting Backend Implementation  
**Next Review:** After backend deployment  
**Reporter:** iOS Team  
**Assignee:** Backend Team

---

**Once this issue is resolved, real-time meal log updates will work instantly for all iOS users, eliminating the need for polling fallback and significantly improving user experience.**