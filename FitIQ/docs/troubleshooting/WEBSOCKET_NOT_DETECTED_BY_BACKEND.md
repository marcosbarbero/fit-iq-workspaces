# Troubleshooting: WebSocket Not Detected by Backend

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Issue:** Backend logs "User not connected to WebSocket, skipping notification"

---

## 🚨 Symptoms

### Client Side (iOS)
- ✅ WebSocket shows as "connected" in logs
- ✅ Pings are sent successfully
- ✅ No connection errors
- ❌ No real-time updates received

### Backend Side
- ✅ Meal log processed successfully
- ✅ AI parsing completes
- ❌ Logs: "User not connected to WebSocket, skipping notification"
- ❌ WebSocket notification never sent

### User Experience
- 😐 Meal submission appears to succeed
- ⏳ Long delay (5-10s) before UI updates
- 🔄 Relies on polling fallback
- 😞 No instant feedback

---

## 🔍 Root Cause Analysis

### Timing Race Condition

```
Timeline:
┌─────────────────────────────────────────────────────────────┐
│ T+0s:    User submits meal                                  │
│ T+0.1s:  Backend receives meal via REST API                 │
│ T+0.2s:  iOS dismisses AddMealView                          │
│ T+0.3s:  NutritionViewModel initializes                     │
│ T+0.4s:  WebSocket connection starts (async)                │
│ T+1s:    WebSocket handshake completes                      │
│ T+2s:    iOS logs "WebSocket connected"                     │
│ T+26s:   Backend finishes AI processing                     │
│ T+26s:   Backend checks: "Is user connected?"               │
│ T+26s:   Backend: "No connection found"                     │
│ T+26s:   Notification skipped                               │
│ T+30s:   iOS polling kicks in                               │
│ T+30s:   UI finally updates                                 │
└─────────────────────────────────────────────────────────────┘
```

### Why This Happens

1. **WebSocket connects AFTER meal submission**
   - `NutritionViewModel.init()` starts WebSocket connection asynchronously
   - Meal submission happens before connection completes
   - Backend processes meal while connection is still establishing

2. **Backend checks connection at processing time**
   - Backend completes AI processing in ~20-30 seconds
   - Checks for WebSocket connection at that moment
   - May not detect newly established connections

3. **Connection state sync issues**
   - iOS thinks it's connected (handshake complete)
   - Backend doesn't have connection registered yet
   - State mismatch causes notification to be skipped

---

## ✅ Diagnostic Steps

### Step 1: Check iOS Logs

Look for these patterns:

```
✅ Good Pattern (Working):
NutritionViewModel: ✅ WebSocket connected and subscribed to meal log events
NutritionViewModel: 📩 Meal log completed
NutritionViewModel: ✅ Meal log completed - UI updated

❌ Bad Pattern (Not Working):
NutritionViewModel: ✅ WebSocket connected and subscribed to meal log events
NutritionViewModel: Starting polling after meal submission
NutritionViewModel: 🔄 Starting polling (interval: 5.0s)
(no meal_log.completed message received)
```

### Step 2: Check Backend Logs

Look for these patterns:

```
✅ Good Pattern (Working):
[MealLogAI] Successfully completed processing meal log
[WebSocket] Sending meal_log.completed to user 4eb4c27c-...
[WebSocket] Notification sent successfully

❌ Bad Pattern (Not Working):
[MealLogAI] Successfully completed processing meal log
User 4eb4c27c-... not connected to WebSocket, skipping notification
```

### Step 3: Check Connection State

In `NutritionViewModel`:

```swift
print("WebSocket State:")
print("  - isWebSocketConnected: \(isWebSocketConnected)")
print("  - isWebSocketConnecting: \(isWebSocketConnecting)")
print("  - service.isConnected: \(webSocketService.isConnected)")
```

Expected states:

```
✅ Healthy:
  - isWebSocketConnected: true
  - isWebSocketConnecting: false
  - service.isConnected: true

❌ Unhealthy:
  - isWebSocketConnected: false  (client thinks it's not connected)
  - isWebSocketConnecting: false
  - service.isConnected: true    (service thinks it is)
```

### Step 4: Check Network Traffic

Use Charles Proxy or Wireshark:

1. **WebSocket Handshake:**
   ```
   GET wss://fit-iq-backend.fly.dev/ws/meal-logs?token=...
   Upgrade: websocket
   Connection: Upgrade
   
   Response: 101 Switching Protocols
   ```

2. **Ping/Pong:**
   ```
   → PING
   ← PONG
   ```

3. **Notifications:**
   ```
   ← meal_log.completed (should arrive, but doesn't)
   ```

---

## 🛠️ Solutions

### Solution 1: Use Updated NutritionViewModel (Recommended)

The latest version includes connection state tracking:

```swift
// Now tracks connection state properly
var isWebSocketConnected: Bool = false
var isWebSocketConnecting: Bool = false

// Verifies connection on message receipt
private func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
    isWebSocketConnected = true  // ✅ Verified working
    // ... handle update ...
}
```

**Action:** Update to latest `NutritionViewModel.swift` (v1.1.0+)

### Solution 2: Backend Connection Registry Fix

If backend doesn't detect connection:

**Backend Team:**
1. Review WebSocket connection registration logic
2. Ensure connections are registered immediately after handshake
3. Add connection verification endpoint: `GET /ws/meal-logs/status`
4. Log connection lifecycle events

### Solution 3: Pre-Connection Check (Future Enhancement)

Ensure WebSocket is connected before submitting meals:

```swift
func saveMealLog(...) async {
    // Wait for connection if in progress
    if isWebSocketConnecting {
        await waitForConnection(timeout: 5.0)
    }
    
    // Only submit if connected
    guard isWebSocketConnected else {
        print("Warning: WebSocket not connected, relying on polling")
    }
    
    // Submit meal...
}
```

### Solution 4: Connection Keepalive

Ensure connection stays active:

```swift
// Already implemented in MealLogWebSocketClient
func startPingTimer() {
    pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
        self?.sendPing()
    }
}
```

**Action:** Verify ping/pong is working in logs

---

## 🧪 Testing & Verification

### Test Case 1: Immediate Submission

```swift
// Test: Submit meal immediately after view appears
@MainActor
func testImmediateSubmission() async {
    let viewModel = NutritionViewModel(...)
    
    // Submit meal right away (before WebSocket connects)
    await viewModel.saveMealLog(
        rawInput: "1 banana",
        mealType: .snack
    )
    
    // Wait for processing
    try? await Task.sleep(for: .seconds(30))
    
    // Verify: Should still get updates (via polling)
    XCTAssertFalse(viewModel.meals.isEmpty)
}
```

### Test Case 2: After Connection Established

```swift
// Test: Submit meal after WebSocket is connected
@MainActor
func testAfterConnection() async {
    let viewModel = NutritionViewModel(...)
    
    // Wait for connection
    try? await Task.sleep(for: .seconds(5))
    XCTAssertTrue(viewModel.isWebSocketConnected)
    
    // Submit meal
    await viewModel.saveMealLog(
        rawInput: "1 apple",
        mealType: .snack
    )
    
    // Should get real-time update (via WebSocket)
    try? await Task.sleep(for: .seconds(30))
    XCTAssertTrue(viewModel.isWebSocketConnected) // Still connected
}
```

### Test Case 3: Connection Recovery

```swift
// Test: Connection drops and recovers
@MainActor
func testConnectionRecovery() async {
    let viewModel = NutritionViewModel(...)
    
    // Initial connection
    try? await Task.sleep(for: .seconds(2))
    XCTAssertTrue(viewModel.isWebSocketConnected)
    
    // Simulate disconnect
    viewModel.webSocketService.disconnect()
    XCTAssertFalse(viewModel.isWebSocketConnected)
    
    // Submit meal (should use polling)
    await viewModel.saveMealLog(rawInput: "1 orange", mealType: .snack)
    
    // Reconnect
    await viewModel.reconnectWebSocket()
    XCTAssertTrue(viewModel.isWebSocketConnected)
}
```

---

## 📊 Success Metrics

### Before Fix
| Metric | Value |
|--------|-------|
| WebSocket notification delivery | 0% |
| Polling fallback success | 100% |
| Average update time | 5-10s |
| User satisfaction | 😐 Acceptable |

### After Fix
| Metric | Target |
|--------|--------|
| WebSocket notification delivery | 95%+ |
| Polling fallback success | 100% |
| Average update time | <1s (WebSocket), 5-10s (polling) |
| User satisfaction | 😄 Excellent |

---

## 🔔 Monitoring & Alerts

### Key Metrics to Track

1. **WebSocket Connection Rate**
   ```
   connections_established / connections_attempted >= 0.95
   ```

2. **Notification Delivery Rate**
   ```
   notifications_received / meals_submitted >= 0.90
   ```

3. **Polling Activation Rate**
   ```
   polling_starts / meals_submitted <= 0.10
   ```

4. **Average Update Time**
   ```
   time_to_ui_update <= 2.0 seconds
   ```

### Alert Conditions

```
⚠️  Warning: WebSocket connection rate < 90%
🚨 Critical: Notification delivery rate < 50%
⚠️  Warning: Polling activation rate > 25%
🚨 Critical: Average update time > 15 seconds
```

---

## 📞 Escalation Path

### Level 1: Check iOS Client
1. Verify `isWebSocketConnected` state
2. Check for connection errors in logs
3. Verify polling fallback is working
4. Test on different networks (WiFi, Cellular)

### Level 2: Check Backend
1. Review backend WebSocket logs
2. Verify connection registry
3. Check for server-side errors
4. Test WebSocket endpoint manually

### Level 3: Network Investigation
1. Use packet capture tools
2. Check for proxy/firewall issues
3. Verify DNS resolution
4. Test from different locations

### Level 4: Full Stack Debug
1. Add detailed logging at every layer
2. Create minimal reproduction case
3. Test with mock backend
4. Coordinate iOS + Backend debugging session

---

## 📚 Related Documentation

- **Main Fix:** `WEBSOCKET_CONNECTION_TIMING_FIX.md`
- **Integration Guide:** `MEAL_LOG_WEBSOCKET_INTEGRATION.md`
- **Polling Fallback:** `MEAL_LOG_POLLING_FALLBACK.md`
- **Quick Reference:** `MEAL_LOG_WEBSOCKET_QUICK_REFERENCE.md`

---

## 💡 Quick Fixes

### Fix 1: Force Reconnection
```swift
// In NutritionView
Button("Reconnect WebSocket") {
    Task {
        await viewModel.reconnectWebSocket()
    }
}
```

### Fix 2: Manual Refresh
```swift
// In NutritionView
Button("Refresh Data") {
    Task {
        await viewModel.loadDataForSelectedDate()
    }
}
```

### Fix 3: Enable Debug Logging
```swift
// In AppDependencies or App.swift
#if DEBUG
UserDefaults.standard.set(true, forKey: "EnableWebSocketDebugLogging")
#endif
```

---

**Status:** ✅ Issue Documented & Fixed  
**Last Updated:** 2025-01-27  
**Next Review:** After 100+ meal submissions in production