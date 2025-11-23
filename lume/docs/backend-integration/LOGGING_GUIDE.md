# Outbox Pattern Logging Guide

**Date:** 2025-01-15  
**Version:** 1.1.0  
**Purpose:** Understanding outbox pattern logs and troubleshooting

---

## Overview

The outbox pattern provides comprehensive logging at every stage. This guide shows you what logs to expect and what they mean.

---

## Quick Diagnostic

### Check Current Mode

When the app starts, look for:

```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Local Development
🔧 [lumeApp] Backend enabled: false
🔵 [lumeApp] Outbox processing disabled (AppMode: Local Development)
💡 [lumeApp] To enable backend sync: Set AppMode.current = .production in AppMode.swift
```

**Meaning:** App is in **local mode** - no backend sync, no outbox events

---

## Log Categories

### 🚀 App Startup Logs

**Local Mode:**
```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Local Development
🔧 [lumeApp] Backend enabled: false
🔵 [lumeApp] Outbox processing disabled (AppMode: Local Development)
💡 [lumeApp] To enable backend sync: Set AppMode.current = .production in AppMode.swift
```

**Production Mode:**
```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Production
🔧 [lumeApp] Backend enabled: true
🌐 [lumeApp] Backend URL: https://fit-iq-backend.fly.dev
✅ [lumeApp] Outbox processing started (interval: 30s)
📦 [lumeApp] Outbox will sync mood data to backend automatically
```

---

## Scenario-Based Logs

### Scenario 1: Tracking Mood (Local Mode)

**What You'll See:**
```
✅ [MoodRepository] Saved mood locally: Happy for Jan 15, 2025
🔵 [MoodRepository] Skipping outbox (AppMode: Local Development)
```

**What It Means:**
- ✅ Mood saved to local database (SwiftData)
- 🔵 No outbox event created (local mode)
- ❌ No backend sync

**Expected Behavior:**
- Data stays on device only
- Works offline perfectly
- No network calls

---

### Scenario 2: Tracking Mood (Production Mode)

**What You'll See:**
```
✅ [MoodRepository] Saved mood locally: Happy for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: 12345678-1234-1234-1234-123456789012
📦 [OutboxRepository] Event created: type='mood.created', id=87654321-4321-4321-4321-210987654321, status=pending
```

**What It Means:**
- ✅ Mood saved locally first
- 📦 Outbox event created for backend sync
- 📦 Event persisted in database (pending status)
- ⏳ Will sync within 30 seconds

**Expected Behavior:**
- Data saved locally immediately
- Background sync happens automatically
- Works offline (queues for later)

---

### Scenario 3: Outbox Processing (Production Mode, No Events)

**What You'll See:**
```
✅ [OutboxProcessor] No pending events
```

**What It Means:**
- ✅ Processor checked for work
- 📭 Nothing to sync
- ✅ All caught up

**Expected Behavior:**
- Runs every 30 seconds
- Quick no-op when nothing to do
- Minimal battery impact

---

### Scenario 4: Outbox Processing (Production Mode, Has Events)

**What You'll See:**
```
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: 12345678-1234-1234-1234-123456789012
✅ [OutboxRepository] Event completed: type='mood.created', id=87654321-4321-4321-4321-210987654321
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**What It Means:**
- 📦 Found 1 pending event
- ✅ Sent to backend successfully
- ✅ Marked as completed
- ✅ Deleted from outbox

**Expected Behavior:**
- Event synced to backend
- Removed from local outbox
- No further action needed

---

### Scenario 5: Network Failure (Production Mode)

**What You'll See:**
```
📦 [OutboxProcessor] Processing 1 pending events
⚠️ [OutboxProcessor] Event mood.created failed (retry 1/5): Network error
⚠️ [OutboxRepository] Event marked failed: type='mood.created', id=87654321-4321-4321-4321-210987654321, retryCount=1
⏳ [OutboxProcessor] Waiting 2.0s before retry...
✅ [OutboxProcessor] Processing complete: 0 succeeded, 1 failed, 1 remaining
```

**What It Means:**
- 📦 Attempted to sync
- ⚠️ Network error occurred
- ⚠️ Event marked as failed (retry count: 1)
- ⏳ Will retry with 2-second delay
- 🔄 Stays in outbox for next cycle

**Expected Behavior:**
- Automatic retry on next cycle (30s)
- Exponential backoff (2s, 4s, 8s, 16s, 32s)
- Max 5 retries before giving up

---

### Scenario 6: Token Expired (Production Mode)

**What You'll See:**
```
📦 [OutboxProcessor] Processing 1 pending events
🔄 [OutboxProcessor] Token expired or needs refresh, attempting refresh...
✅ [OutboxProcessor] Token refreshed successfully
✅ [MoodBackendService] Successfully synced mood entry: 12345678-1234-1234-1234-123456789012
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**What It Means:**
- 🔄 Token was expired or expiring soon
- ✅ Automatically refreshed token
- ✅ Continued processing with new token
- ✅ Seamless sync without user intervention

**Expected Behavior:**
- Automatic token refresh
- No user interruption
- Background sync continues

---

### Scenario 7: Token Refresh Failed (Production Mode)

**What You'll See:**
```
📦 [OutboxProcessor] Processing 1 pending events
🔄 [OutboxProcessor] Token expired or needs refresh, attempting refresh...
❌ [OutboxProcessor] Token refresh failed: Refresh token expired
⚠️ [OutboxProcessor] User needs to re-authenticate
```

**What It Means:**
- 🔄 Attempted to refresh token
- ❌ Refresh token also expired
- ⚠️ User needs to login again
- 📦 Events stay in outbox

**Expected Behavior:**
- Processing skipped
- Events remain pending
- User should see login screen
- After login, sync resumes automatically

---

### Scenario 8: App Foreground Transition (Production Mode)

**What You'll See:**
```
🔄 [lumeApp] App became active, triggering outbox processing
📦 [OutboxProcessor] Processing 2 pending events
✅ [MoodBackendService] Successfully synced mood entry: ...
✅ [MoodBackendService] Successfully synced mood entry: ...
✅ [OutboxProcessor] Processing complete: 2 succeeded, 0 failed, 0 remaining
```

**What It Means:**
- 🔄 App returned to foreground
- 📦 Immediate sync triggered (not waiting 30s)
- ✅ Multiple events synced
- ✅ All caught up

**Expected Behavior:**
- Immediate processing on foreground
- Syncs any events queued while backgrounded
- Fast catchup on app return

---

### Scenario 9: Deleting Mood (Production Mode)

**What You'll See:**
```
✅ [MoodRepository] Deleted mood entry locally: 12345678-1234-1234-1234-123456789012
📦 [MoodRepository] Created outbox event 'mood.deleted' for mood: 12345678-1234-1234-1234-123456789012
📦 [OutboxRepository] Event created: type='mood.deleted', id=87654321-4321-4321-4321-210987654321, status=pending
```

**Later (within 30s):**
```
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully deleted mood entry: 12345678-1234-1234-1234-123456789012
✅ [OutboxProcessor] Event mood.deleted processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**What It Means:**
- ✅ Deleted from local database
- 📦 Delete event created for backend
- ✅ Backend synced with deletion
- ✅ Consistent state everywhere

---

## Complete Log Flow Examples

### Example 1: Happy Path (Production Mode)

**User tracks mood → Backend sync succeeds**

```
[App Launch]
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Production
🔧 [lumeApp] Backend enabled: true
🌐 [lumeApp] Backend URL: https://fit-iq-backend.fly.dev
✅ [lumeApp] Outbox processing started (interval: 30s)

[User Tracks Mood]
✅ [MoodRepository] Saved mood locally: Happy for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: abc-123
📦 [OutboxRepository] Event created: type='mood.created', id=def-456, status=pending

[30 seconds later]
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxRepository] Event completed: type='mood.created', id=def-456
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

---

### Example 2: Offline Then Online (Production Mode)

**User tracks mood offline → Goes online → Auto-sync**

```
[Offline - Track Mood]
✅ [MoodRepository] Saved mood locally: Calm for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: xyz-789
📦 [OutboxRepository] Event created: type='mood.created', id=uvw-321, status=pending

[Processor Tries - Fails]
📦 [OutboxProcessor] Processing 1 pending events
⚠️ [OutboxProcessor] Event mood.created failed (retry 1/5): Network error
⚠️ [OutboxRepository] Event marked failed: type='mood.created', id=uvw-321, retryCount=1
⏳ [OutboxProcessor] Waiting 2.0s before retry...
✅ [OutboxProcessor] Processing complete: 0 succeeded, 1 failed, 1 remaining

[30s Later - Still Offline]
📦 [OutboxProcessor] Processing 1 pending events
⚠️ [OutboxProcessor] Event mood.created failed (retry 2/5): Network error
⚠️ [OutboxRepository] Event marked failed: type='mood.created', id=uvw-321, retryCount=2
⏳ [OutboxProcessor] Waiting 4.0s before retry...

[Goes Online - Next Cycle]
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: xyz-789
✅ [OutboxRepository] Event completed: type='mood.created', id=uvw-321
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

---

### Example 3: Token Refresh (Production Mode)

**Token expires → Auto-refresh → Sync continues**

```
[Processor Starts]
📦 [OutboxProcessor] Processing 1 pending events
🔄 [OutboxProcessor] Token expired or needs refresh, attempting refresh...
✅ [OutboxProcessor] Token refreshed successfully
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

---

## Log Symbols Quick Reference

| Symbol | Meaning | Context |
|--------|---------|---------|
| 🚀 | App launch | Startup |
| 📱 | App mode | Configuration |
| 🔧 | Backend status | Configuration |
| 🌐 | Backend URL | Configuration |
| ✅ | Success | Any operation |
| 📦 | Outbox event | Event creation/processing |
| 🔵 | Local mode | Mode indicator |
| 💡 | Helpful tip | User guidance |
| ⚠️ | Warning/Retry | Non-critical issue |
| ❌ | Error | Critical failure |
| 🔄 | Refresh/Retry | Token or event retry |
| ⏳ | Waiting | Backoff delay |
| 📭 | Empty | No events |

---

## Troubleshooting by Logs

### "I don't see any outbox logs"

**Check for:**
```
🔵 [MoodRepository] Skipping outbox (AppMode: Local Development)
```

**Problem:** App is in local mode  
**Solution:** Set `AppMode.current = .production` in `AppMode.swift`

---

### "Events created but not syncing"

**Check for:**
```
⚠️ [OutboxProcessor] No valid token, skipping processing
```

**Problem:** No authentication token  
**Solution:** Login or register first

OR

```
❌ [OutboxProcessor] Token refresh failed: Refresh token expired
```

**Problem:** Token expired  
**Solution:** Re-authenticate (login again)

---

### "Events failing repeatedly"

**Check for:**
```
⚠️ [OutboxProcessor] Event mood.created failed (retry 3/5): Network error
```

**Problem:** Network connectivity issues  
**Solution:** Check internet connection

OR

```
⚠️ [OutboxProcessor] Event mood.created failed (retry 1/5): Server error (500)
```

**Problem:** Backend API issues  
**Solution:** Check backend health, wait for recovery

---

### "Processor not running"

**Check for:**
```
🔵 [lumeApp] Outbox processing disabled (AppMode: Local Development)
```

**Problem:** Local mode enabled  
**Solution:** Switch to production mode

---

## Enabling Debug Logging

All outbox logging is **always enabled** in both DEBUG and RELEASE builds.

To see logs in Xcode:
1. Run app (⌘+R)
2. Open Console (⌘+⇧+C)
3. Filter by: `[MoodRepository]`, `[OutboxProcessor]`, `[OutboxRepository]`, or `[lumeApp]`

---

## Log Retention

**In Xcode Console:**
- Logs available during development session
- Cleared on app restart
- Filter by text to find specific events

**In Production:**
- Console logs available via Xcode Console when device connected
- Consider adding analytics/crash reporting for production monitoring

---

## Expected Log Frequency

| Scenario | Frequency | Logs Per Occurrence |
|----------|-----------|---------------------|
| App launch | Once | 4-6 lines |
| Track mood (local) | Per mood | 2 lines |
| Track mood (production) | Per mood | 4 lines |
| Outbox processing (empty) | Every 30s | 1 line |
| Outbox processing (events) | Every 30s | 4-6 lines per event |
| Token refresh | As needed | 2-3 lines |
| Network failure | Per retry | 3-4 lines |
| App foreground | Per transition | 2 lines + processing |

---

## What's Normal?

### ✅ Normal Logs

**Local Mode:**
- Many `🔵 Skipping outbox` messages
- No outbox processor logs
- Only local save confirmations

**Production Mode:**
- Regular `✅ No pending events` (when caught up)
- `📦 Processing X pending events` after mood tracking
- Occasional token refresh logs
- Retry logs if network unstable

### ⚠️ Concerning Logs

**Watch For:**
- Many consecutive retry failures (>10)
- Token refresh failures (user needs to login)
- High retry counts on same event (indicates persistent issue)
- Complete silence (no logs at all - check Xcode Console filter)

---

## Quick Diagnostic Commands

### Check Current State

**Look for these logs on app launch:**
```
📱 [lumeApp] App Mode: ?
🔧 [lumeApp] Backend enabled: ?
```

**If `Local Development` / `false`:**
- ✅ Normal for development
- ❌ Not syncing to backend
- 💡 Switch to production mode to enable sync

**If `Production` / `true`:**
- ✅ Backend sync enabled
- ✅ Should see outbox processor logs
- ✅ Events will sync automatically

---

## Summary

### Key Logs to Watch

**Development (Local Mode):**
1. `🚀 Starting Lume app`
2. `📱 App Mode: Local Development`
3. `🔵 Skipping outbox` (when tracking mood)

**Production (Backend Sync):**
1. `🚀 Starting Lume app`
2. `📱 App Mode: Production`
3. `✅ Outbox processing started`
4. `📦 Created outbox event` (when tracking mood)
5. `📦 Processing X pending events` (every 30s)
6. `✅ Successfully synced` (on success)

**Troubleshooting:**
- No logs → Check Xcode Console filter
- Only local mode logs → Switch to production mode
- Retry logs → Normal if offline, concerning if persistent
- Token refresh logs → Normal, part of automatic refresh
- Token refresh failed → User needs to re-authenticate

---

**Questions?** See the full implementation guide: `OUTBOX_PATTERN_IMPLEMENTATION.md`

**Status:** Comprehensive logging enabled  
**Version:** 1.1.0  
**Last Updated:** 2025-01-15