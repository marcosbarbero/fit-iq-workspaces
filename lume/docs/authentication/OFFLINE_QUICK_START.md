# Offline-First Authentication - Quick Start Guide

**Purpose:** Get up and running with offline-first authentication in 5 minutes

---

## TL;DR

Lume now works offline! Users can create moods, journals, and access their data without internet. Everything syncs automatically when connectivity returns.

---

## What Changed?

### Before ❌
```swift
// App launch checked token validity (network required)
if token.isValid {
    showApp()
} else {
    showLogin() // ← User blocked if offline!
}
```

### After ✅
```swift
// App launch checks local session first
if UserSession.shared.isAuthenticated {
    showApp() // ← Works offline!
    
    // Validate token in background if online
    if networkMonitor.isConnected {
        refreshTokenIfNeeded()
    }
}
```

---

## Files to Add to Xcode

### New Files
1. **NetworkMonitor.swift**
   - Path: `lume/Core/Network/NetworkMonitor.swift`
   - Purpose: Detects internet connectivity

### Modified Files
2. **RootView.swift**
   - Path: `lume/Presentation/RootView.swift`
   - Purpose: Offline-first auth checking

3. **OutboxProcessorService.swift**
   - Path: `lume/Services/Outbox/OutboxProcessorService.swift`
   - Purpose: Skip sync when offline

4. **AppDependencies.swift**
   - Path: `lume/DI/AppDependencies.swift`
   - Purpose: Wire up NetworkMonitor

---

## How to Test

### Test 1: Offline Login Prevention
```
1. Close app
2. Turn on Airplane Mode (Settings)
3. Open app
4. ✅ Should open to main screen (not login)
```

### Test 2: Offline Data Creation
```
1. Open app (offline)
2. Create mood entry
3. Write journal entry
4. ✅ Should save locally without errors
```

### Test 3: Automatic Sync
```
1. Create data while offline
2. Turn off Airplane Mode
3. Wait 30 seconds
4. ✅ Data should sync to backend automatically
```

---

## Key Components

### NetworkMonitor
```swift
// Check connectivity anywhere in the app
if NetworkMonitor.shared.isConnected {
    // Perform online operations
} else {
    // Queue for later sync
}
```

### UserSession
```swift
// Check authentication (works offline)
if UserSession.shared.isAuthenticated {
    let userId = UserSession.shared.currentUserId
    // User is logged in
}
```

### Outbox Pattern
```swift
// All data changes go through outbox
// Automatically syncs when online
repository.save(entry) // ← Creates outbox event
```

---

## Expected Log Output

### Offline Scenario
```
📴 [RootView] Offline - allowing app usage with local session
✅ [MoodRepository] Mood entry saved locally
✅ [JournalRepository] Journal entry saved locally
📴 [OutboxProcessor] Offline - skipping sync (events queued for later)
```

### Online Scenario
```
🌐 [NetworkMonitor] Network status: connected via WiFi
🌐 [RootView] Online - validating token in background
✅ [RootView] Background token refresh successful
✅ [OutboxProcessor] Processing 3 pending events
✅ [OutboxProcessor] All events synced successfully
```

---

## Common Issues

### Issue: App still logs out when offline
**Cause:** Old RootView code still in use
**Fix:** Ensure RootView.swift is updated with new logic

### Issue: Data not syncing when back online
**Cause:** NetworkMonitor not wired up
**Fix:** Check AppDependencies.swift includes networkMonitor

### Issue: Build errors after adding files
**Cause:** Files not added to Xcode project
**Fix:** Add all new files to Xcode target

---

## Quick Checklist

Integration steps:

- [ ] Add `NetworkMonitor.swift` to Xcode project
- [ ] Update `RootView.swift` with new logic
- [ ] Update `OutboxProcessorService.swift` with network check
- [ ] Update `AppDependencies.swift` with NetworkMonitor
- [ ] Build project (resolve any errors)
- [ ] Test offline login (Airplane Mode)
- [ ] Test offline data creation
- [ ] Test automatic sync on reconnection
- [ ] Check logs for correct behavior

---

## When to Use Each Component

### Use NetworkMonitor When:
- Making optional network calls
- Showing connectivity status in UI
- Deciding whether to queue or send data

### Use UserSession When:
- Checking if user is authenticated
- Getting current user ID
- Starting/ending sessions

### Use Outbox Pattern When:
- Creating/updating data that needs backend sync
- Ensuring no data loss
- Supporting offline operations

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│         User Opens App (Offline)        │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│    RootView checks UserSession          │
│    ✅ isAuthenticated = true            │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│    NetworkMonitor.isConnected           │
│    ❌ = false (offline)                 │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│    Show Main App (Offline Mode)         │
│    - View existing data ✅              │
│    - Create new entries ✅              │
│    - Changes saved locally ✅           │
└────────────────┬────────────────────────┘
                 │
        Internet Returns
                 │
                 ▼
┌─────────────────────────────────────────┐
│    OutboxProcessor Detects Online       │
│    - Process pending events             │
│    - Sync to backend                    │
│    - Refresh token if needed            │
└─────────────────────────────────────────┘
```

---

## Code Examples

### Check Auth Status (Works Offline)
```swift
// ✅ Good - uses local session
if UserSession.shared.isAuthenticated {
    showMainApp()
}

// ❌ Bad - requires network
if token.isValid && !token.isExpired {
    showMainApp()
}
```

### Save Data (Works Offline)
```swift
// ✅ Good - uses outbox pattern
try await moodRepository.save(mood)
// Saved locally, queued for sync

// ❌ Bad - direct API call
try await moodAPI.createMood(mood)
// Fails when offline
```

### Check Connectivity
```swift
// ✅ Good - check before optional features
if NetworkMonitor.shared.isConnected {
    let aiPrompt = try await fetchAIPrompt()
} else {
    showCachedPrompt()
}

// ❌ Bad - assume online
let aiPrompt = try await fetchAIPrompt()
// Crashes when offline
```

---

## Performance Tips

1. **Battery Life**
   - NetworkMonitor has minimal impact
   - Consider increasing outbox interval if needed

2. **Data Usage**
   - Sync only when online (automatic)
   - Future: Add WiFi-only option

3. **Storage**
   - Outbox events cleaned up after sync
   - Monitor SwiftData growth

---

## Next Steps

1. **Add files to Xcode project**
2. **Test offline scenarios**
3. **Verify log output**
4. **Monitor success metrics**

---

## Full Documentation

For detailed information, see:
- `docs/authentication/OFFLINE_FIRST_AUTH.md` - Complete guide
- `docs/authentication/OFFLINE_FIRST_IMPLEMENTATION_SUMMARY.md` - Implementation details

---

**Questions?** Check the full documentation or search logs for `[NetworkMonitor]`, `[RootView]`, or `[OutboxProcessor]`.