# 🧪 WebSocket Ping/Pong Testing Guide

**Purpose:** Quick guide to verify iOS ping/pong implementation works with backend  
**Date:** 2025-01-27  
**Status:** Ready for Testing

---

## 🎯 Quick Test (5 minutes)

### Prerequisites
- iOS app installed on device/simulator
- User authenticated
- Network connection available

### Steps

1. **Launch app and navigate to Nutrition tab**
   - This automatically connects WebSocket

2. **Open Xcode Console**
   - Filter logs: `MealLogWebSocketClient`

3. **Look for these logs within 30 seconds:**
   ```
   ✅ MealLogWebSocketClient: 🏓 Sending application-level ping
   ✅ MealLogWebSocketClient: ✅ Application ping sent successfully
   ✅ MealLogWebSocketClient: ✅ Pong received
   ✅ MealLogWebSocketClient: ✅ Connection is alive and healthy
   ```

4. **Wait 30 seconds, verify ping repeats**
   - Should see same logs again

5. **✅ PASS if:**
   - Pings sent every 30 seconds
   - Pongs received immediately after pings
   - No connection errors

---

## 🔍 Detailed Test (15 minutes)

### Test 1: Initial Connection & First Ping

**Expected Timeline:**
```
T+0s:  Connect to WebSocket
T+1s:  Receive "connected" message
T+1s:  Send first ping immediately
T+2s:  Receive pong
T+30s: Send second ping
T+31s: Receive pong
```

**Verify in Logs:**
```
MealLogWebSocketClient: Connecting to wss://...
MealLogWebSocketClient: ✅ Connected - User ID: <user_id>
MealLogWebSocketClient: 🏓 Sending application-level ping at <timestamp>
MealLogWebSocketClient: ✅ Application ping sent successfully
MealLogWebSocketClient: ✅ Pong received at <timestamp>
MealLogWebSocketClient:    - Backend timestamp: 2025-01-27T...
MealLogWebSocketClient: ✅ Connection is alive and healthy
```

### Test 2: Keep-Alive Over 5 Minutes

**Steps:**
1. Keep app open for 5 minutes
2. Count ping/pong cycles
3. Verify no disconnections

**Expected:**
- 10 ping/pong cycles (1 every 30s × 10 = 5 min)
- No errors
- No reconnections

**Verify:**
```bash
# Filter logs for pings
grep "Application ping sent successfully" console.log | wc -l
# Should show: 10
```

### Test 3: Long-Running Connection (15+ minutes)

**Purpose:** Verify connection doesn't timeout at 10-minute backend deadline

**Steps:**
1. Keep app open for 15 minutes
2. Verify no disconnection at 10-minute mark
3. Log a meal at 15 minutes
4. Verify real-time update still works

**Expected:**
- No disconnection
- Pings continue every 30 seconds
- Meal update received via WebSocket (not polling fallback)

### Test 4: Network Interruption

**Steps:**
1. Enable Airplane Mode
2. Wait 5 seconds
3. Disable Airplane Mode
4. Verify reconnection

**Expected Logs:**
```
# On network loss:
MealLogWebSocketClient: ⚠️ Ping failed: The network connection was lost
MealLogWebSocketClient: ❌ No internet connection

# On network restore:
MealLogWebSocketClient: Connecting to wss://...
MealLogWebSocketClient: ✅ Connected - User ID: <user_id>
MealLogWebSocketClient: 🏓 Sending application-level ping
```

### Test 5: Background/Foreground Transition

**Steps:**
1. Send app to background (Home button)
2. Wait 1 minute
3. Bring app to foreground
4. Verify reconnection

**Expected:**
- Ping timer stops in background
- Reconnects on foreground
- Pings resume immediately

---

## 📊 Success Criteria

### ✅ PASS Criteria

1. **Pings sent every 30 seconds:**
   - No missed pings
   - Consistent timing (±2 seconds)

2. **Pongs received immediately:**
   - Within 1-2 seconds of ping
   - Contains backend timestamp

3. **No connection timeouts:**
   - Connection stable for 15+ minutes
   - No "read deadline exceeded" errors

4. **Real-time updates work:**
   - Meal logs arrive via WebSocket
   - No fallback to polling

5. **Clean reconnection:**
   - Network interruptions handled gracefully
   - No zombie connections

### ❌ FAIL Criteria

1. **No pings sent:**
   - Ping timer not starting
   - Missing ping logs

2. **Pings sent but no pongs:**
   - Backend not responding
   - Authentication issue

3. **Connection drops at 10 minutes:**
   - Backend not resetting deadline
   - Pings not reaching backend

4. **Zombie connections:**
   - Multiple connections from same user
   - Reconnect without disconnect

---

## 🐛 Debugging Tips

### View Real-Time Logs

**Xcode Console Filter:**
```
MealLogWebSocketClient
```

**Show only ping/pong:**
```
ping|pong|🏓|✅
```

### Check Backend Logs

**Ask backend team to filter:**
```
/ws/meal-logs
ping
pong
```

### Enable Verbose Logging

Add to `MealLogWebSocketClient.swift`:
```swift
// Add property
private let verboseLogging = true

// In sendPing():
if verboseLogging {
    print("DEBUG: Ping payload: \(jsonString)")
    print("DEBUG: WebSocket state: \(webSocketTask?.state.rawValue ?? -1)")
}
```

---

## 📋 Test Report Template

```markdown
## WebSocket Ping/Pong Test Report

**Date:** <date>
**Tester:** <name>
**Device:** <device model>
**iOS Version:** <version>
**App Version:** <version>

### Test 1: Initial Connection
- [ ] Connected successfully
- [ ] First ping sent immediately
- [ ] Pong received
- [ ] Backend timestamp present

### Test 2: Keep-Alive (5 minutes)
- [ ] 10 ping/pong cycles completed
- [ ] No disconnections
- [ ] Consistent 30-second interval

### Test 3: Long-Running (15 minutes)
- [ ] No timeout at 10 minutes
- [ ] Connection stable
- [ ] Real-time updates working

### Test 4: Network Interruption
- [ ] Handled gracefully
- [ ] Reconnected automatically
- [ ] Pings resumed

### Test 5: Background/Foreground
- [ ] Ping timer stopped in background
- [ ] Reconnected on foreground
- [ ] No errors

### Overall Result
- [ ] ✅ PASS - All tests passed
- [ ] ❌ FAIL - Issues found (details below)

### Issues Found
<list any issues>

### Backend Logs Verified
- [ ] Backend received pings
- [ ] Backend sent pongs
- [ ] Read deadline reset on each ping

### Notes
<additional observations>
```

---

## 🚀 Quick Verification Commands

### Count Pings in Last 5 Minutes
```bash
# In Xcode console, search:
"Application ping sent successfully"
# Count occurrences (should be ~10)
```

### Verify Pong Responses
```bash
# Search for:
"Pong received"
# Should match ping count
```

### Check for Errors
```bash
# Search for:
"Ping failed" OR "Connection lost" OR "read deadline"
# Should be 0 results
```

---

## 📞 Who to Contact

### Backend Issues
- Backend not responding to pings
- No pongs received
- Connection timeout at 10 minutes
→ **Contact:** Backend team lead

### iOS Issues
- Pings not being sent
- Ping timer not starting
- Reconnection not working
→ **Contact:** iOS team lead

### Network Issues
- Firewall blocking WebSocket
- Load balancer issues
- SSL/TLS errors
→ **Contact:** DevOps team

---

## ✅ Sign-Off

Once all tests pass:

- [ ] iOS implementation verified
- [ ] Backend integration verified
- [ ] Long-running stability verified
- [ ] Network interruption handling verified
- [ ] Ready for production deployment

**Tested By:** _______________  
**Date:** _______________  
**Approved By:** _______________  
**Date:** _______________

---

**Status:** 🧪 Ready for Testing  
**Last Updated:** 2025-01-27