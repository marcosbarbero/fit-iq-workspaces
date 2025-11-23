# Outbox Pattern Verification Checklist

**Date:** 2025-01-15  
**Version:** 1.1.0  
**Purpose:** Step-by-step checklist to verify outbox pattern is working correctly

---

## Pre-Verification Setup

### ✅ Step 1: Files Added to Xcode

- [ ] `HTTPClient.swift` added to Xcode project
- [ ] `MoodBackendService.swift` added to Xcode project
- [ ] `OutboxProcessorService.swift` added to Xcode project
- [ ] All files have "lume" target membership checked
- [ ] Project builds successfully (⌘+B)

### ✅ Step 2: Backend Configuration

- [ ] `config.plist` exists in project
- [ ] `BACKEND_BASE_URL` configured
- [ ] `API_KEY` configured
- [ ] Backend API is accessible (test with browser/Postman)

---

## Verification Phase 1: Local Mode (Default)

### What to Test

Local mode ensures the app works without backend dependency.

### ✅ Test 1.1: App Launches Successfully

**Steps:**
1. Run app (⌘+R)
2. Open Xcode Console (⌘+⇧+C)
3. Look for startup logs

**Expected Logs:**
```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Local Development
🔧 [lumeApp] Backend enabled: false
🔵 [lumeApp] Outbox processing disabled (AppMode: Local Development)
💡 [lumeApp] To enable backend sync: Set AppMode.current = .production in AppMode.swift
```

**Checklist:**
- [ ] App launches without crash
- [ ] See "Local Development" mode log
- [ ] See "Backend enabled: false" log
- [ ] See helpful tip about enabling production mode

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 1.2: Track Mood in Local Mode

**Steps:**
1. Navigate to mood tracking screen
2. Select a mood (e.g., Happy)
3. Add optional note
4. Save mood
5. Check console logs

**Expected Logs:**
```
✅ [MoodRepository] Saved mood locally: Happy for Jan 15, 2025
🔵 [MoodRepository] Skipping outbox (AppMode: Local Development)
```

**Checklist:**
- [ ] Mood saved successfully
- [ ] See "Saved mood locally" log
- [ ] See "Skipping outbox" log
- [ ] Mood appears in mood list
- [ ] No outbox event created
- [ ] No network calls made

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 1.3: Delete Mood in Local Mode

**Steps:**
1. Find a mood entry in the list
2. Delete the mood
3. Check console logs

**Expected Logs:**
```
✅ [MoodRepository] Deleted mood entry locally: 12345678-1234-1234-1234-123456789012
🔵 [MoodRepository] Skipping outbox (AppMode: Local Development)
```

**Checklist:**
- [ ] Mood deleted successfully
- [ ] See "Deleted mood entry locally" log
- [ ] See "Skipping outbox" log
- [ ] Mood removed from list
- [ ] No outbox event created

**Result:** ✅ Pass / ❌ Fail

---

## Verification Phase 2: Production Mode (Backend Sync)

### What to Test

Production mode enables full backend synchronization.

### ⚠️ Prerequisites

Before proceeding:
- [ ] Backend API is running and accessible
- [ ] Valid authentication (login/register first)
- [ ] Access token stored in keychain

### ✅ Test 2.1: Enable Production Mode

**Steps:**
1. Stop the app
2. Open `lume/Core/Configuration/AppMode.swift`
3. Change line: `static var current: AppMode = .production`
4. Save file
5. Rebuild project (⌘+⇧+K then ⌘+B)
6. Run app (⌘+R)
7. Check console logs

**Expected Logs:**
```
🚀 [lumeApp] Starting Lume app
📱 [lumeApp] App Mode: Production
🔧 [lumeApp] Backend enabled: true
🌐 [lumeApp] Backend URL: https://fit-iq-backend.fly.dev
✅ [lumeApp] Outbox processing started (interval: 30s)
📦 [lumeApp] Outbox will sync mood data to backend automatically
```

**Checklist:**
- [ ] App launches successfully
- [ ] See "App Mode: Production" log
- [ ] See "Backend enabled: true" log
- [ ] See backend URL log
- [ ] See "Outbox processing started" log

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 2.2: Track Mood with Outbox Creation

**Steps:**
1. Navigate to mood tracking
2. Select a mood (e.g., Excited)
3. Add optional note: "Testing outbox sync"
4. Save mood
5. Check console logs

**Expected Logs:**
```
✅ [MoodRepository] Saved mood locally: Excited for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: abc-123-def-456
📦 [OutboxRepository] Event created: type='mood.created', id=xyz-789-uvw-012, status=pending
```

**Checklist:**
- [ ] Mood saved locally
- [ ] See "Saved mood locally" log
- [ ] See "Created outbox event" log
- [ ] See "Event created" log from repository
- [ ] Event status is "pending"

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 2.3: Outbox Processor Syncs Event

**Steps:**
1. After tracking mood (Test 2.2)
2. Wait 30 seconds (or bring app to foreground)
3. Watch console logs

**Expected Logs (Success):**
```
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: abc-123-def-456
✅ [OutboxRepository] Event completed: type='mood.created', id=xyz-789-uvw-012
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Checklist:**
- [ ] See "Processing 1 pending events" log
- [ ] See "Successfully synced" log
- [ ] See "Event completed" log
- [ ] See "Processing complete: 1 succeeded" log
- [ ] Verify data in backend (check API/database)

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 2.4: Periodic Processing (No Events)

**Steps:**
1. Wait 30 seconds after all events are synced
2. Watch console logs

**Expected Logs:**
```
✅ [OutboxProcessor] No pending events
```

**Checklist:**
- [ ] See "No pending events" log
- [ ] Log appears every ~30 seconds
- [ ] No errors
- [ ] Minimal CPU usage

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 2.5: Delete Mood with Backend Sync

**Steps:**
1. Delete a mood entry
2. Check immediate logs
3. Wait 30 seconds for sync
4. Check sync logs

**Expected Logs (Immediate):**
```
✅ [MoodRepository] Deleted mood entry locally: abc-123-def-456
📦 [MoodRepository] Created outbox event 'mood.deleted' for mood: abc-123-def-456
📦 [OutboxRepository] Event created: type='mood.deleted', id=xyz-789-uvw-012, status=pending
```

**Expected Logs (After 30s):**
```
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully deleted mood entry: abc-123-def-456
✅ [OutboxProcessor] Event mood.deleted processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Checklist:**
- [ ] Mood deleted locally
- [ ] Outbox event created
- [ ] Event synced to backend
- [ ] Backend deletion confirmed
- [ ] Event removed from outbox

**Result:** ✅ Pass / ❌ Fail

---

## Verification Phase 3: Edge Cases

### ✅ Test 3.1: Offline Mode

**Steps:**
1. Disable WiFi and cellular on device/simulator
2. Track a mood
3. Check console logs
4. Wait 30 seconds
5. Check retry logs
6. Re-enable network
7. Wait for sync

**Expected Logs (Offline):**
```
✅ [MoodRepository] Saved mood locally: Calm for Jan 15, 2025
📦 [MoodRepository] Created outbox event 'mood.created' for mood: abc-123
📦 [OutboxRepository] Event created: type='mood.created', id=xyz-789, status=pending

[30s later]
📦 [OutboxProcessor] Processing 1 pending events
⚠️ [OutboxProcessor] Event mood.created failed (retry 1/5): Network error
⚠️ [OutboxRepository] Event marked failed: type='mood.created', id=xyz-789, retryCount=1
⏳ [OutboxProcessor] Waiting 2.0s before retry...
✅ [OutboxProcessor] Processing complete: 0 succeeded, 1 failed, 1 remaining
```

**Expected Logs (Back Online):**
```
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Checklist:**
- [ ] Mood saved locally while offline
- [ ] Outbox event created
- [ ] Retry attempts logged with backoff
- [ ] Event stays in outbox
- [ ] Syncs automatically when back online
- [ ] Retry count increments properly

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 3.2: App Foreground Trigger

**Steps:**
1. Track a mood
2. Immediately background the app (Home button)
3. Wait 10 seconds
4. Bring app back to foreground
5. Check console logs

**Expected Logs:**
```
🔄 [lumeApp] App became active, triggering outbox processing
📦 [OutboxProcessor] Processing 1 pending events
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Checklist:**
- [ ] See "App became active" log
- [ ] Immediate processing triggered (not waiting 30s)
- [ ] Event synced successfully
- [ ] No delay in sync

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 3.3: Token Refresh

**Steps:**
1. Use an expired or nearly expired token (if possible)
2. Track a mood
3. Wait for processor to run
4. Watch for token refresh logs

**Expected Logs:**
```
📦 [OutboxProcessor] Processing 1 pending events
🔄 [OutboxProcessor] Token expired or needs refresh, attempting refresh...
✅ [OutboxProcessor] Token refreshed successfully
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 1 succeeded, 0 failed, 0 remaining
```

**Checklist:**
- [ ] Token expiration detected
- [ ] Automatic refresh attempted
- [ ] Refresh successful
- [ ] Processing continues with new token
- [ ] No user interruption

**Result:** ✅ Pass / ❌ Fail

**Note:** If you can't force token expiration, this test can be skipped initially and verified in production over time.

---

### ✅ Test 3.4: Multiple Events

**Steps:**
1. Quickly track 3 different moods
2. Wait for processor to run
3. Check console logs

**Expected Logs:**
```
📦 [OutboxProcessor] Processing 3 pending events
✅ [MoodBackendService] Successfully synced mood entry: abc-123
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [MoodBackendService] Successfully synced mood entry: def-456
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [MoodBackendService] Successfully synced mood entry: ghi-789
✅ [OutboxProcessor] Event mood.created processed successfully
✅ [OutboxProcessor] Processing complete: 3 succeeded, 0 failed, 0 remaining
```

**Checklist:**
- [ ] All events created successfully
- [ ] All events processed in order
- [ ] All events synced successfully
- [ ] No events left in outbox

**Result:** ✅ Pass / ❌ Fail

---

## Verification Phase 4: Backend Verification

### ✅ Test 4.1: Verify Data in Backend

**Steps:**
1. Track a mood in the app
2. Wait for sync confirmation
3. Query backend API directly (Postman/curl)
4. Verify data exists

**API Call:**
```bash
curl -X GET "https://fit-iq-backend.fly.dev/api/v1/moods" \
  -H "X-API-Key: your-api-key" \
  -H "Authorization: Bearer your-access-token"
```

**Checklist:**
- [ ] Backend returns mood data
- [ ] Mood matches what was tracked in app
- [ ] All fields correct (date, mood, note)
- [ ] userId matches authenticated user

**Result:** ✅ Pass / ❌ Fail

---

### ✅ Test 4.2: Verify Deletion in Backend

**Steps:**
1. Delete a mood in the app
2. Wait for sync confirmation
3. Query backend API
4. Verify mood is deleted

**Checklist:**
- [ ] Mood no longer in backend response
- [ ] Deletion confirmed
- [ ] No errors in backend logs

**Result:** ✅ Pass / ❌ Fail

---

## Final Verification Summary

### Local Mode Results

- [ ] Test 1.1: App launches in local mode ✅ / ❌
- [ ] Test 1.2: Track mood locally ✅ / ❌
- [ ] Test 1.3: Delete mood locally ✅ / ❌

**Local Mode Status:** ✅ All Pass / ❌ Issues Found

---

### Production Mode Results

- [ ] Test 2.1: Enable production mode ✅ / ❌
- [ ] Test 2.2: Track mood with outbox ✅ / ❌
- [ ] Test 2.3: Outbox processor syncs ✅ / ❌
- [ ] Test 2.4: Periodic processing ✅ / ❌
- [ ] Test 2.5: Delete mood with sync ✅ / ❌

**Production Mode Status:** ✅ All Pass / ❌ Issues Found

---

### Edge Cases Results

- [ ] Test 3.1: Offline mode ✅ / ❌
- [ ] Test 3.2: Foreground trigger ✅ / ❌
- [ ] Test 3.3: Token refresh ✅ / ❌ / ⏭️ Skipped
- [ ] Test 3.4: Multiple events ✅ / ❌

**Edge Cases Status:** ✅ All Pass / ❌ Issues Found

---

### Backend Verification Results

- [ ] Test 4.1: Data in backend ✅ / ❌
- [ ] Test 4.2: Deletion in backend ✅ / ❌

**Backend Status:** ✅ All Pass / ❌ Issues Found

---

## Overall Result

**Total Tests:** 13  
**Passed:** ___  
**Failed:** ___  
**Skipped:** ___

**Overall Status:** ✅ Ready for Production / ⚠️ Issues to Resolve / ❌ Not Ready

---

## Troubleshooting Failed Tests

### Common Issues

**No logs appearing:**
- Check Xcode Console is open (⌘+⇧+C)
- Verify console filter isn't hiding logs
- Check "All Output" is selected in console

**"Cannot find type" errors:**
- Files not added to Xcode project
- Missing target membership
- See: `docs/backend-integration/ADD_OUTBOX_FILES_TO_XCODE.md`

**Events not syncing:**
- Check AppMode is set to `.production`
- Verify valid auth token exists
- Check network connectivity
- Verify backend URL in `config.plist`

**Token refresh failed:**
- Refresh token may be expired
- User needs to re-authenticate (login again)
- Check backend refresh endpoint is working

**Backend returns errors:**
- Check API key is valid
- Verify auth token is valid
- Check backend API is running
- Review backend logs for details

---

## Next Steps After Verification

### If All Tests Pass ✅

**Congratulations!** Your outbox pattern implementation is working correctly.

**Next Steps:**
1. Monitor production logs for any issues
2. Set up analytics/crash reporting (optional)
3. Document any backend-specific configuration
4. Plan for adding journal/goal events (future)

### If Some Tests Fail ⚠️

**Don't Panic!** Most issues are configuration-related.

**Next Steps:**
1. Review troubleshooting section above
2. Check logs carefully for error details
3. Verify all prerequisites are met
4. Consult `LOGGING_GUIDE.md` for log interpretation
5. Review `OUTBOX_PATTERN_IMPLEMENTATION.md` for details

### If Many Tests Fail ❌

**Let's Debug Together!**

**Next Steps:**
1. Go back to Phase 1 (Local Mode)
2. Ensure local mode works perfectly first
3. Double-check file additions to Xcode
4. Verify backend configuration
5. Check authentication is working
6. Review documentation from the beginning

---

## Documentation References

- **Full Guide:** `OUTBOX_PATTERN_IMPLEMENTATION.md`
- **Quick Summary:** `OUTBOX_IMPLEMENTATION_SUMMARY.md`
- **Logging Guide:** `LOGGING_GUIDE.md`
- **Setup Guide:** `ADD_OUTBOX_FILES_TO_XCODE.md`
- **Master Index:** `README.md`

---

**Verification Date:** _______________  
**Tested By:** _______________  
**Environment:** ☐ Simulator ☐ Device  
**iOS Version:** _______________  
**App Version:** _______________

---

**Status:** Ready for Verification  
**Version:** 1.1.0  
**Last Updated:** 2025-01-15