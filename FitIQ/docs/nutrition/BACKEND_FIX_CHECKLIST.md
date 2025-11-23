# ✅ Backend Fix Checklist: WebSocket Connection Registry

**Issue:** Ping/pong messages don't update connection registry  
**Impact:** Real-time notifications never reach iOS clients  
**Fix Complexity:** Low (1-2 hours)  
**Risk Level:** Low (isolated change)

---

## 🎯 Quick Fix (Minimum Required)

### Step 1: Locate the Ping Handler
**File:** `internal/interfaces/rest/meal_log_websocket_handler.go`

Find this code:
```go
case "ping":
    pongMsg := map[string]interface{}{
        "type":      "pong",
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    conn.WriteJSON(pongMsg)
    conn.SetReadDeadline(time.Now().Add(10 * time.Minute))
```

- [ ] Located ping handler in codebase
- [ ] Confirmed it sends pong response
- [ ] Confirmed it resets read deadline

### Step 2: Add Registry Update
Add this line after the pong response:

```go
case "ping":
    // Respond with pong
    pongMsg := map[string]interface{}{
        "type":      "pong",
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    conn.WriteJSON(pongMsg)
    
    // Reset read deadline
    conn.SetReadDeadline(time.Now().Add(10 * time.Minute))
    
    // ✅ ADD THIS: Update connection registry
    if h.connectionManager != nil {
        h.connectionManager.UpdateLastSeen(userID)
        log.Printf("[WebSocket] User %s - connection refreshed via ping", userID)
    }
```

- [ ] Added `UpdateLastSeen(userID)` call
- [ ] Added log message for debugging
- [ ] Code compiles without errors

### Step 3: Verify ConnectionManager Has UpdateLastSeen Method

**Check if method exists:**
```go
// In connection_manager.go (or similar)
func (cm *ConnectionManager) UpdateLastSeen(userID string) error {
    // ... implementation ...
}
```

**If method doesn't exist, add it:**
```go
func (cm *ConnectionManager) UpdateLastSeen(userID string) error {
    cm.mu.Lock()
    defer cm.mu.Unlock()
    
    if conn, exists := cm.connections[userID]; exists {
        conn.LastSeen = time.Now()
        log.Printf("[ConnectionManager] Updated LastSeen for user %s", userID)
        return nil
    }
    
    log.Printf("[ConnectionManager] WARNING: User %s not found in registry", userID)
    return fmt.Errorf("user %s not in registry", userID)
}
```

- [ ] Method exists or created
- [ ] Method updates LastSeen timestamp
- [ ] Method logs success/failure
- [ ] Code compiles without errors

---

## 🔍 Verification Steps

### Step 4: Add Diagnostic Logging

**In notification sender (where "not connected" error occurs):**

```go
func (s *MealLogAI) SendNotification(userID string, notification interface{}) error {
    log.Printf("[MealLogAI] Attempting to send notification to user %s", userID)
    
    // Check if user is connected
    if !s.connectionManager.IsConnected(userID) {
        // ✅ ADD: Show LastSeen for debugging
        if lastSeen, err := s.connectionManager.GetLastSeen(userID); err == nil {
            log.Printf("[MealLogAI] User %s NOT connected (LastSeen: %v, %v ago)", 
                userID, lastSeen, time.Since(lastSeen))
        } else {
            log.Printf("[MealLogAI] User %s NOT connected (never in registry)", userID)
        }
        return fmt.Errorf("user not connected")
    }
    
    // ✅ ADD: Confirm connection found
    log.Printf("[MealLogAI] User %s IS connected - sending notification", userID)
    
    // Send notification...
}
```

- [ ] Added logging before IsConnected check
- [ ] Added logging for "not connected" case (with LastSeen)
- [ ] Added logging for "is connected" case
- [ ] Code compiles without errors

### Step 5: Review Connection Cleanup Logic

**Check cleanup threshold:**
```go
func (cm *ConnectionManager) CleanupStaleConnections() {
    // iOS pings every 30 seconds
    // Use 5-minute threshold = 10 missed pings
    staleThreshold := time.Now().Add(-5 * time.Minute)  // ✅ Must be >= 5 minutes
    
    for userID, conn := range cm.connections {
        if conn.LastSeen.Before(staleThreshold) {
            log.Printf("[ConnectionManager] Removing stale connection: %s (LastSeen: %v)", 
                userID, conn.LastSeen)
            delete(cm.connections, userID)
        }
    }
}
```

- [ ] Cleanup threshold is at least 5 minutes
- [ ] Cleanup logs which users are removed
- [ ] Cleanup doesn't run too frequently (max every 1 minute)

---

## 🧪 Testing in Staging

### Step 6: Deploy to Staging

- [ ] Code changes committed to feature branch
- [ ] Pull request created and reviewed
- [ ] Deployed to staging environment
- [ ] Staging backend accessible to iOS team

### Step 7: Test with iOS Client

**Ask iOS team to:**
1. Connect to staging backend
2. Navigate to Nutrition tab
3. Watch logs for 60 seconds

**Expected iOS logs:**
```
MealLogWebSocketClient: 🏓 Sending application-level ping
MealLogWebSocketClient: ✅ Application ping sent successfully
MealLogWebSocketClient: ✅ Pong received
MealLogWebSocketClient:    - Backend timestamp: 2025-11-08T10:07:29Z
MealLogWebSocketClient: ✅ Connection is alive and healthy
```

**Expected Backend logs:**
```
[WebSocket] User 4eb4c27c... - connection refreshed via ping
[ConnectionManager] Updated LastSeen for user 4eb4c27c...
```

- [ ] Backend receives ping messages
- [ ] Backend sends pong responses
- [ ] Backend logs "connection refreshed" message
- [ ] ConnectionManager logs "Updated LastSeen" message
- [ ] No errors in logs

### Step 8: Test Real-Time Notification

**Ask iOS team to:**
1. Keep app open and connected
2. Log a meal (e.g., "1 small apple")
3. Wait for processing (20-30 seconds)
4. Check if notification received

**Expected iOS logs:**
```
NutritionViewModel: Meal log saved successfully
MealLogWebSocketClient: 📩 Message type: meal_log.completed  ✅ THIS IS KEY
NutritionViewModel: 📩 Meal log completed
NutritionViewModel: WebSocket connected, stopping polling  ✅ POLLING STOPS
```

**Expected Backend logs:**
```
[MealLogAI] Successfully completed processing meal log 556d0423...
[MealLogAI] Attempting to send notification to user 4eb4c27c...
[MealLogAI] User 4eb4c27c... IS connected - sending notification  ✅ THIS IS KEY
```

- [ ] Backend completes meal processing
- [ ] Backend finds user in connection registry
- [ ] Backend sends notification successfully
- [ ] iOS receives `meal_log.completed` WebSocket message
- [ ] iOS stops polling fallback automatically
- [ ] No "not connected" errors

### Step 9: Long-Running Test (15 minutes)

**Ask iOS team to:**
1. Keep app open for 15 minutes
2. Watch for ping/pong every 30 seconds
3. Submit meal at 15-minute mark
4. Verify notification still works

**Expected behavior:**
- [ ] Ping/pong exchanges every 30 seconds for 15 minutes
- [ ] Backend logs "connection refreshed" every 30 seconds
- [ ] Connection never removed from registry
- [ ] Notification works after 15 minutes
- [ ] No timeout or disconnection errors

---

## 🚀 Production Deployment

### Step 10: Prepare for Production

- [ ] All staging tests passed
- [ ] iOS team confirms real-time updates working
- [ ] No errors or warnings in staging logs
- [ ] Code review completed and approved
- [ ] Merge to main/production branch

### Step 11: Deploy to Production

- [ ] Production deployment completed
- [ ] Backend services restarted successfully
- [ ] Health checks passing
- [ ] WebSocket endpoint accessible

### Step 12: Monitor Production

**Watch logs for 1 hour after deployment:**

```bash
# Check ping activity
grep "connection refreshed" production.log | tail -n 50

# Check notification delivery
grep "IS connected - sending notification" production.log | tail -n 20

# Check for errors
grep "NOT connected" production.log | tail -n 10
```

- [ ] Pings being received and processed
- [ ] Connection registry being updated
- [ ] Notifications being sent successfully
- [ ] No "not connected" errors for active users

---

## 📊 Success Criteria

### ✅ Fix is Successful If:

1. **Ping/Pong Updates Registry:**
   - [ ] Backend logs "connection refreshed" on every ping
   - [ ] ConnectionManager logs "Updated LastSeen"
   - [ ] No registry-related errors

2. **Notifications Delivered:**
   - [ ] Backend logs "IS connected - sending notification"
   - [ ] iOS receives WebSocket messages instantly
   - [ ] No "not connected" errors for active users

3. **Polling Stops:**
   - [ ] iOS logs "WebSocket connected, stopping polling"
   - [ ] iOS uses WebSocket exclusively
   - [ ] No polling fallback when WebSocket working

4. **Long-Running Stability:**
   - [ ] Connections stable for 15+ minutes
   - [ ] Ping/pong continues every 30 seconds
   - [ ] Notifications work after extended uptime

---

## 🐛 Troubleshooting

### Issue: "connectionManager is nil"

**Problem:** Connection manager not injected into handler

**Fix:**
```go
func NewMealLogWebSocketHandler(connManager *ConnectionManager) *Handler {
    return &Handler{
        connectionManager: connManager,  // ✅ Ensure this is set
    }
}
```

### Issue: "User not in registry" on Ping

**Problem:** User connection not added when WebSocket connects

**Fix:**
```go
func (h *Handler) HandleConnection(w http.ResponseWriter, r *http.Request) {
    // ... parse userID from token ...
    
    // ✅ Add to registry immediately after connection
    h.connectionManager.AddConnection(userID, conn)
    log.Printf("[WebSocket] User %s connected and added to registry", userID)
}
```

### Issue: Still Getting "Not Connected" After Fix

**Problem:** Connection cleanup too aggressive

**Fix:**
```go
// Increase threshold from 1 minute to 5 minutes
staleThreshold := time.Now().Add(-5 * time.Minute)  // Not -1 * time.Minute
```

### Issue: Ping Received But LastSeen Not Updated

**Problem:** UpdateLastSeen method not working

**Debug:**
```go
func (cm *ConnectionManager) UpdateLastSeen(userID string) error {
    cm.mu.Lock()
    defer cm.mu.Unlock()
    
    log.Printf("[DEBUG] Attempting to update LastSeen for user %s", userID)
    log.Printf("[DEBUG] Registry has %d connections", len(cm.connections))
    
    if conn, exists := cm.connections[userID]; exists {
        oldLastSeen := conn.LastSeen
        conn.LastSeen = time.Now()
        log.Printf("[DEBUG] Updated LastSeen from %v to %v", oldLastSeen, conn.LastSeen)
        return nil
    }
    
    log.Printf("[DEBUG] User %s not found in registry!", userID)
    return fmt.Errorf("user not in registry")
}
```

---

## 📞 Need Help?

### Contact iOS Team
- **For:** Testing assistance, log analysis
- **When:** After staging deployment

### Contact DevOps
- **For:** Deployment issues, infrastructure
- **When:** If deployment fails

### Escalate If:
- [ ] Tests fail in staging
- [ ] Can't locate ping handler in code
- [ ] Connection manager architecture unclear
- [ ] Production deployment issues

---

## 📝 Completion Report

Once all steps completed, fill out:

**Date Fixed:** _______________  
**Developer:** _______________  
**Commit SHA:** _______________  
**Staging Test Results:** ✅ Pass / ❌ Fail  
**Production Deployment:** ✅ Complete / ❌ Pending  
**iOS Team Verified:** ✅ Yes / ❌ No  

**Notes:**
_________________________________
_________________________________
_________________________________

---

## 🎉 Expected Outcome

After completing this checklist:
- ✅ Real-time notifications delivered instantly (<1 second)
- ✅ No more "not connected" errors for active users
- ✅ iOS clients stop using polling fallback
- ✅ Server load reduced (no more polling every 5 seconds)
- ✅ Better user experience (instant feedback)

**The fix is simple. The impact is huge. Let's ship it! 🚀**