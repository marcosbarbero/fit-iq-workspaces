# Polling Fallback Mechanism

**Date:** 2025-01-27  
**Feature:** Auto-refresh polling when WebSocket unavailable  
**Purpose:** Ensure UI updates even without WebSocket connection

---

## Overview

The app now includes a **polling fallback mechanism** that automatically refreshes meal data when the WebSocket connection is unavailable. This ensures users see updated meal information even if:

- WebSocket endpoint is not available (backend < v0.31.0)
- WebSocket connection fails (network issues, server errors)
- Real-time notifications are disabled

---

## How It Works

### Flow Diagram

```
User submits meal
        ↓
Saved to local storage (status: "processing")
        ↓
UI shows meal immediately
        ↓
Outbox Pattern syncs to backend
        ↓
Backend processes meal (2-5 seconds)
        ↓
┌─────────────────────────────────────────┐
│  WebSocket Available?                    │
├─────────────────────────────────────────┤
│  YES → Receive meal_log.completed       │
│        → Stop polling                    │
│        → Update UI immediately           │
├─────────────────────────────────────────┤
│  NO  → Polling starts automatically     │
│        → Refresh every 5 seconds         │
│        → Detect updated meal data        │
│        → Update UI when data changes     │
└─────────────────────────────────────────┘
```

---

## Implementation Details

### Automatic Activation

Polling starts automatically in two scenarios:

1. **On meal submission** (if WebSocket not connected)
   ```swift
   // After saving meal
   if !isPolling && !webSocketService.isConnected {
       startPolling()
   }
   ```

2. **On WebSocket connection failure**
   ```swift
   // If WebSocket fails to connect
   catch {
       print("WebSocket failed - starting polling")
       startPolling()
   }
   ```

### Automatic Deactivation

Polling stops automatically when:

1. **WebSocket connects successfully**
   ```swift
   // In polling loop
   if webSocketService.isConnected {
       print("WebSocket connected, stopping polling")
       stopPolling()
       break
   }
   ```

2. **WebSocket receives update**
   ```swift
   // In handleMealLogCompleted()
   stopPolling()  // WebSocket working, no need to poll
   ```

3. **ViewModel is deallocated**
   ```swift
   deinit {
       pollingTask?.cancel()
   }
   ```

---

## Configuration

### Polling Interval

**Default:** 5 seconds

```swift
private let pollingInterval: TimeInterval = 5.0
```

**Rationale:**
- Backend processing typically takes 2-5 seconds
- 5-second interval balances responsiveness vs. server load
- Aggressive enough to feel "real-time"
- Conservative enough to avoid rate limiting

**Customization:**
```swift
// In NutritionViewModel init:
self.pollingInterval = 3.0  // More aggressive (3 seconds)
self.pollingInterval = 10.0 // More conservative (10 seconds)
```

---

## Performance Considerations

### Network Impact

| Scenario | Requests per Minute | Impact |
|----------|---------------------|--------|
| WebSocket working | ~2 (ping/pong) | ✅ Minimal |
| Polling (5s) | ~12 | ⚠️ Moderate |
| Polling (3s) | ~20 | ⚠️ Higher |
| Polling (10s) | ~6 | ✅ Low |

### Battery Impact

- **WebSocket**: Minimal (connection stays open, low power)
- **Polling**: Moderate (periodic HTTP requests, more power)

### Server Load

- **WebSocket**: One connection per user
- **Polling**: 12 requests/minute per user (if WebSocket unavailable)

### Optimization Strategies

1. **Prefer WebSocket**: Always try WebSocket first
2. **Stop when idle**: Cancel polling when view disappears
3. **Exponential backoff**: Could increase interval if no changes detected
4. **Smart polling**: Only poll for meals with `status: "processing"`

---

## User Experience

### With WebSocket (Best Case)

```
Submit meal → Instant local save → UI updates (0ms)
                                 ↓
Backend processes (2-5 seconds)
                                 ↓
WebSocket notification → UI updates (instant)
```

**Total perceived latency**: 0ms (local-first)  
**Final data latency**: 2-5 seconds (real-time notification)

### Without WebSocket (Fallback)

```
Submit meal → Instant local save → UI updates (0ms)
                                 ↓
Backend processes (2-5 seconds)
                                 ↓
Polling detects change → UI updates (0-5 seconds)
```

**Total perceived latency**: 0ms (local-first)  
**Final data latency**: 2-10 seconds (polling + processing)

**Note**: In worst case, user waits one polling cycle (5s) after backend completes.

---

## Monitoring & Debugging

### Log Messages

#### Polling Started
```
NutritionViewModel: 🔄 Starting polling (interval: 5.0s)
```

#### Polling Active
```
NutritionViewModel: 🔄 Polling: Refreshing meals...
NutritionViewModel: Successfully loaded 5 meals
```

#### Polling Stopped (WebSocket Connected)
```
NutritionViewModel: WebSocket connected, stopping polling
NutritionViewModel: 🛑 Stopping polling
```

#### Polling Stopped (Update Received)
```
NutritionViewModel: ✅ Meal log completed - UI updated
NutritionViewModel: 🛑 Stopping polling
```

### Debugging

**Check if polling is active:**
```swift
// In NutritionViewModel
print("Polling active: \(isPolling)")
print("WebSocket connected: \(webSocketService.isConnected)")
```

**Check polling task:**
```swift
if let task = pollingTask {
    print("Polling task exists: \(!task.isCancelled)")
} else {
    print("No polling task")
}
```

---

## Testing

### Test Scenario 1: WebSocket Available

**Setup**: Backend v0.31.0+ with `/ws/meal-logs`

**Steps**:
1. Submit meal
2. Observe WebSocket connection succeeds
3. Wait for processing (2-5s)
4. Verify `meal_log.completed` received
5. Verify UI updates immediately
6. **Verify polling does NOT start**

**Expected**:
- ✅ No polling logs
- ✅ UI updates via WebSocket only
- ✅ Minimal network traffic

### Test Scenario 2: WebSocket Unavailable

**Setup**: Backend < v0.31.0 OR `/ws/meal-logs` endpoint disabled

**Steps**:
1. Submit meal
2. Observe WebSocket connection fails
3. **Verify polling starts automatically**
4. Wait for processing (2-5s)
5. Wait for next polling cycle (0-5s)
6. Verify UI updates with completed data

**Expected**:
- ✅ Polling starts: `🔄 Starting polling (interval: 5.0s)`
- ✅ Periodic refresh logs every 5 seconds
- ✅ UI updates when data changes
- ✅ Polling continues until WebSocket connects

### Test Scenario 3: WebSocket Reconnects

**Setup**: Start without WebSocket, then enable it

**Steps**:
1. Submit meal with WebSocket unavailable
2. Verify polling starts
3. Enable WebSocket endpoint
4. Reconnect WebSocket manually
5. **Verify polling stops automatically**

**Expected**:
- ✅ Polling active initially
- ✅ WebSocket connects: `✅ Connected and subscribed`
- ✅ Polling stops: `WebSocket connected, stopping polling`
- ✅ No more polling logs

### Test Scenario 4: Multiple Meals

**Setup**: WebSocket unavailable

**Steps**:
1. Submit first meal
2. Verify polling starts
3. Submit second meal (while polling active)
4. **Verify polling does NOT restart** (already active)
5. Wait for both meals to complete
6. Verify both appear in UI

**Expected**:
- ✅ Single polling loop handles all meals
- ✅ No duplicate polling tasks
- ✅ Log: `⏭️ Polling already active`

---

## Best Practices

### ✅ Do This

1. **Let polling start automatically**
   - Don't manually start polling
   - Trust the automatic activation logic

2. **Prefer WebSocket**
   - Always try WebSocket connection first
   - Use polling only as fallback

3. **Monitor logs**
   - Check for polling activation
   - Verify polling stops when WebSocket connects

4. **Trust local-first**
   - Meal shows immediately in UI
   - Polling only updates nutrition data

### ❌ Don't Do This

1. **Don't start polling manually**
   ```swift
   // ❌ Bad: Manual polling
   await viewModel.startPolling()
   
   // ✅ Good: Automatic
   // (polling starts on its own when needed)
   ```

2. **Don't poll if WebSocket works**
   - Polling should stop automatically
   - If it doesn't, investigate WebSocket connection

3. **Don't set aggressive intervals**
   ```swift
   // ❌ Bad: Too aggressive
   pollingInterval = 1.0  // Every second
   
   // ✅ Good: Balanced
   pollingInterval = 5.0  // Every 5 seconds
   ```

4. **Don't forget to stop polling**
   - Polling should stop automatically
   - If implementing custom polling, always clean up

---

## Future Improvements

### Smart Polling (Suggested)

Only poll for meals with `status: "processing"`:

```swift
// Check if any meals are processing
let hasProcessingMeals = meals.contains { $0.status == "processing" }

if !hasProcessingMeals {
    print("No processing meals, stopping polling")
    stopPolling()
}
```

### Exponential Backoff (Suggested)

Increase interval if no changes detected:

```swift
var currentInterval = pollingInterval
let maxInterval = 30.0

// If no changes detected
if !dataChanged {
    currentInterval = min(currentInterval * 1.5, maxInterval)
}
```

### Background Polling (Suggested)

Continue polling when app is backgrounded:

```swift
// Use BackgroundTask to continue polling
let taskID = await UIApplication.shared.beginBackgroundTask()
defer { UIApplication.shared.endBackgroundTask(taskID) }
```

### Adaptive Interval (Suggested)

Adjust based on backend processing time:

```swift
// If backend consistently takes 3 seconds
// Set interval to 4 seconds (3 + 1 buffer)
pollingInterval = averageProcessingTime + 1.0
```

---

## Comparison: WebSocket vs Polling

| Feature | WebSocket | Polling (Fallback) |
|---------|-----------|-------------------|
| **Latency** | Instant (<100ms) | 0-5 seconds delay |
| **Network** | Minimal (2 req/min) | Moderate (12 req/min) |
| **Battery** | Low | Moderate |
| **Server Load** | Low (1 connection) | Higher (12 req/min) |
| **Reliability** | High (if available) | High (always works) |
| **Complexity** | Higher | Lower |
| **Real-time** | ✅ Yes | ⚠️ Near real-time |
| **Fallback** | N/A | ✅ Always available |

**Verdict**: Use WebSocket when available, polling as reliable fallback.

---

## FAQ

**Q: Why not just use polling all the time?**  
A: WebSocket is more efficient (lower latency, less battery, less server load).

**Q: What if backend takes longer than 5 seconds?**  
A: Polling will catch it on the next cycle. User sees data within 5 seconds of completion.

**Q: Does polling work offline?**  
A: No. Polling requires network. But local-first means meal shows immediately. Polling only updates nutrition data.

**Q: Can I disable polling?**  
A: Not recommended. If WebSocket fails, polling is the only way to get updates.

**Q: Does polling affect app performance?**  
A: Minimal impact. Single background task, cancellable, no UI blocking.

**Q: What if I submit multiple meals?**  
A: Single polling loop handles all meals. No duplicate polling tasks.

**Q: How do I know if polling is active?**  
A: Check logs for `🔄 Starting polling` and periodic `🔄 Polling: Refreshing meals...`

---

## Related Documentation

- **WebSocket Implementation**: `WEBSOCKET_MIGRATION_SUMMARY.md`
- **Quick Reference**: `docs/MEAL_LOG_WEBSOCKET_QUICK_REFERENCE.md`
- **Architecture**: `docs/proposals/MEAL_LOG_WEBSOCKET_ENDPOINT_SPEC.md`

---

**Last Updated**: 2025-01-27  
**Status**: ✅ Implemented & Tested  
**Polling Interval**: 5 seconds (configurable)