# Journal Backend Integration - Testing Checklist

**Status:** 🔄 In Progress  
**Date:** 2025-01-15  
**Phase:** Phase 4 - Backend Integration Testing

---

## Overview

This document provides a comprehensive testing checklist for the journal backend integration. Use this to verify all functionality works correctly before deploying to production.

---

## Prerequisites

### Backend Readiness
- [ ] Backend API is deployed and accessible at `https://fit-iq-backend.fly.dev`
- [ ] Journal endpoints (`/api/v1/journal/*`) are implemented
- [ ] Authentication works with valid tokens
- [ ] Test user account exists and can log in

### App Configuration
- [ ] `config.plist` has correct backend URL
- [ ] App can connect to backend (test with mood tracking first)
- [ ] Outbox processor is running (check logs for "Outbox processing started")
- [ ] Processing interval is set (10s for testing, 30-60s for production)

---

## Test Scenarios

### 1. Basic CRUD Operations

#### 1.1 Create Entry
- [ ] Open Journal tab
- [ ] Tap FAB (floating action button)
- [ ] Fill in title: "Test Entry"
- [ ] Fill in content: "This is a test entry for backend sync"
- [ ] Add tag: "test"
- [ ] Tap Save
- [ ] **Expected:** Entry appears in list
- [ ] **Expected:** Entry shows "Syncing" indicator
- [ ] **Expected:** Statistics show "1 entry pending sync"

#### 1.2 Wait for Sync
- [ ] Wait 10-15 seconds
- [ ] **Expected:** Entry changes to "Synced ✓" indicator
- [ ] **Expected:** Statistics show "0 entries pending sync"
- [ ] Check logs for: `✅ [JournalBackendService] Successfully synced journal entry`
- [ ] Check logs for: `✅ [OutboxProcessor] Stored backend ID`

#### 1.3 Edit Entry
- [ ] Tap on the synced entry
- [ ] Tap Edit button
- [ ] Change content to: "Updated content for backend sync test"
- [ ] Tap Save
- [ ] **Expected:** Entry shows "Syncing" indicator again
- [ ] Wait 10-15 seconds
- [ ] **Expected:** Entry shows "Synced ✓" indicator
- [ ] Check logs for: `✅ [JournalBackendService] Successfully updated journal entry`

#### 1.4 Delete Entry
- [ ] Swipe left on the synced entry
- [ ] Tap Delete
- [ ] Confirm deletion
- [ ] **Expected:** Entry removed from list
- [ ] Wait 10-15 seconds
- [ ] Check logs for: `✅ [JournalBackendService] Successfully deleted journal entry`
- [ ] **Note:** Deletion happens via backend ID if entry was synced

---

### 2. Multiple Entries

#### 2.1 Create Multiple Entries
- [ ] Create 5 entries rapidly (different types, tags, content)
- [ ] **Expected:** All entries show "Syncing" indicator
- [ ] **Expected:** Statistics show "5 entries pending sync"
- [ ] Wait 30 seconds (multiple processing cycles)
- [ ] **Expected:** All entries eventually show "Synced ✓"
- [ ] **Expected:** Statistics show "0 entries pending sync"

#### 2.2 Batch Editing
- [ ] Edit 3 synced entries
- [ ] **Expected:** All edited entries show "Syncing" indicator
- [ ] **Expected:** Statistics show "3 entries pending sync"
- [ ] Wait for sync
- [ ] **Expected:** All entries sync successfully

---

### 3. Offline Mode

#### 3.1 Create Entries Offline
- [ ] Enable Airplane Mode on device
- [ ] Create 2 new entries
- [ ] **Expected:** Entries save locally
- [ ] **Expected:** Entries show "Syncing" indicator
- [ ] **Expected:** Statistics show "2 entries pending sync"
- [ ] Check logs for: `⚠️ [OutboxProcessor] Processing error` (network unavailable)

#### 3.2 Go Online
- [ ] Disable Airplane Mode
- [ ] Wait for next processing cycle (10-15 seconds)
- [ ] **Expected:** Entries sync automatically
- [ ] **Expected:** "Syncing" changes to "Synced ✓"
- [ ] **Expected:** Statistics show "0 entries pending sync"

#### 3.3 Edit Entry Offline
- [ ] Enable Airplane Mode
- [ ] Edit a synced entry
- [ ] **Expected:** Changes save locally
- [ ] **Expected:** Entry shows "Syncing" indicator
- [ ] Disable Airplane Mode
- [ ] Wait for sync
- [ ] **Expected:** Update syncs to backend

---

### 4. Authentication Scenarios

#### 4.1 Token Expiration
- [ ] Let app run until token expires (check token expiry time)
- [ ] Create new entry after expiration
- [ ] **Expected:** Token refreshes automatically
- [ ] Check logs for: `🔄 [OutboxProcessor] Token expired or needs refresh, attempting refresh...`
- [ ] Check logs for: `✅ [OutboxProcessor] Token refreshed successfully`
- [ ] **Expected:** Entry syncs successfully after refresh

#### 4.2 Invalid Token
- [ ] (Advanced) Manually invalidate token in Keychain
- [ ] Create new entry
- [ ] **Expected:** App detects invalid token
- [ ] Check logs for: `🔐 [OutboxProcessor] 401 Unauthorized - token invalid or expired`
- [ ] **Expected:** User is logged out and shown login screen
- [ ] Log back in
- [ ] **Expected:** Pending entries sync after re-authentication

---

### 5. Error Handling

#### 5.1 Backend Unavailable
- [ ] (Advanced) Temporarily stop backend server or block network to specific URL
- [ ] Create entry
- [ ] **Expected:** Entry remains in "Syncing" state
- [ ] Check logs for retry attempts with exponential backoff
- [ ] Restore backend connectivity
- [ ] **Expected:** Entry syncs on next successful attempt

#### 5.2 Network Timeout
- [ ] (Advanced) Simulate slow network
- [ ] Create entry
- [ ] **Expected:** Request times out
- [ ] **Expected:** Retry occurs with backoff
- [ ] **Expected:** Eventually succeeds or reaches max retries

#### 5.3 Max Retries Exceeded
- [ ] (Advanced) Keep backend unavailable for extended period
- [ ] Create entry
- [ ] Wait through 5 retry attempts (will take several minutes due to exponential backoff)
- [ ] Check logs for: `❌ [OutboxProcessor] Event journal.created failed permanently after 5 retries`
- [ ] **Expected:** Entry marked as completed (stops retrying)
- [ ] **Note:** This prevents infinite retry loops

---

### 6. Edge Cases

#### 6.1 Empty Content
- [ ] Try to create entry with empty content
- [ ] **Expected:** Validation fails before save
- [ ] **Expected:** Error message shown to user

#### 6.2 Very Long Content
- [ ] Create entry with 10,000 characters (max limit)
- [ ] **Expected:** Saves successfully
- [ ] **Expected:** Syncs without truncation
- [ ] Try to enter 10,001 characters
- [ ] **Expected:** Character counter shows limit reached

#### 6.3 Special Characters
- [ ] Create entry with emojis: "🎉 Test Entry 🚀"
- [ ] Create entry with special chars: `Test & "quotes" <tags>`
- [ ] **Expected:** All characters save and sync correctly
- [ ] **Expected:** No encoding issues

#### 6.4 Many Tags
- [ ] Create entry with 10 tags (max limit)
- [ ] **Expected:** All tags save and sync
- [ ] Try to add 11th tag
- [ ] **Expected:** Tag limit enforced

---

### 7. UI/UX Verification

#### 7.1 Sync Indicators
- [ ] **"Syncing" badge:**
  - Shows orange clockwise arrow icon
  - Appears immediately after save/edit
  - Text says "Syncing"
  
- [ ] **"Synced" badge:**
  - Shows green checkmark icon
  - Appears after successful sync
  - Text says "Synced"
  
- [ ] **No indicator:**
  - For entries that are synced and don't need attention

#### 7.2 Statistics Card
- [ ] Check "Your Journal" card at top of list
- [ ] Verify "Entries" count is accurate
- [ ] Verify "Day Streak" calculation
- [ ] Verify "Words" count is accurate
- [ ] When entries pending sync:
  - Shows orange sync icon
  - Shows count: "X entries pending sync"
- [ ] When all synced:
  - Pending sync message disappears

#### 7.3 Performance
- [ ] Create 50 entries (stress test)
- [ ] **Expected:** UI remains responsive
- [ ] **Expected:** Scroll is smooth
- [ ] **Expected:** All entries eventually sync
- [ ] Check pending count calculation performance

---

### 8. App Lifecycle

#### 8.1 Background/Foreground
- [ ] Create entry
- [ ] Put app in background (home button)
- [ ] Wait 10 seconds
- [ ] Return to foreground
- [ ] **Expected:** Outbox processes on foreground
- [ ] **Expected:** Entry syncs shortly after returning

#### 8.2 App Restart
- [ ] Create entry and immediately close app (before sync)
- [ ] Reopen app
- [ ] **Expected:** Entry still shows "Syncing"
- [ ] **Expected:** Syncs on next processing cycle
- [ ] **Expected:** No data loss

#### 8.3 Crash Recovery
- [ ] (Advanced) Force crash app during sync
- [ ] Reopen app
- [ ] **Expected:** Outbox events intact
- [ ] **Expected:** Retry occurs automatically
- [ ] **Expected:** No duplicate entries created

---

### 9. Backend Verification

#### 9.1 Data Integrity
- [ ] Create entry with specific content
- [ ] Wait for sync
- [ ] Check backend database/API to verify:
  - Entry exists with correct content
  - Title matches
  - Tags are correct
  - Entry type is correct
  - Timestamps are accurate
  - User ID is correct

#### 9.2 Update Verification
- [ ] Edit entry
- [ ] Wait for sync
- [ ] Check backend to verify:
  - Content updated correctly
  - Updated timestamp changed
  - No duplicate entries created

#### 9.3 Deletion Verification
- [ ] Delete synced entry
- [ ] Wait for sync
- [ ] Check backend to verify:
  - Entry is deleted
  - No orphaned data remains

---

### 10. Integration with Other Features

#### 10.1 Mood Linking (UI Only)
- [ ] Create mood entry
- [ ] Create journal entry
- [ ] **Expected:** Prompt to link to recent mood (UI only)
- [ ] **Note:** Actual linking not yet implemented
- [ ] Verify `linked_mood_id` field in payload (should be null)

#### 10.2 Search
- [ ] Create several entries with unique keywords
- [ ] Wait for sync
- [ ] Use search to find entries
- [ ] **Expected:** Search works on local data regardless of sync status

#### 10.3 Filters
- [ ] Create entries of different types
- [ ] Wait for sync
- [ ] Apply filters (by type, tags, favorites)
- [ ] **Expected:** Filters work correctly
- [ ] **Expected:** Sync status visible on filtered entries

---

## Performance Benchmarks

### Expected Sync Times
- [ ] Single entry: < 2 seconds after processing cycle
- [ ] 5 entries: < 10 seconds total
- [ ] 10 entries: < 20 seconds total
- [ ] **Note:** Times include processing interval wait (10s)

### Resource Usage
- [ ] Battery drain during sync: Minimal (< 1% per hour)
- [ ] Memory usage: Stable (no leaks)
- [ ] Network data: ~1-5 KB per entry

---

## Logs to Monitor

### Success Indicators
```
✅ [JournalBackendService] Successfully synced journal entry: <id>, backend ID: <backend_id>
✅ [OutboxProcessor] Stored backend ID: <backend_id> for journal entry: <local_id>
✅ [OutboxProcessor] Event journal.created processed successfully
```

### Warning Indicators
```
⚠️ [OutboxProcessor] Token expired or needs refresh, attempting refresh...
⚠️ [OutboxProcessor] No backend ID for journal deletion, entry was never synced
⚠️ [OutboxProcessor] Event journal.created failed (retry X/5)
```

### Error Indicators
```
❌ [OutboxProcessor] Processing error: <error>
❌ [JournalBackendService] Sync failed: <error>
🔐 [OutboxProcessor] 401 Unauthorized - token invalid or expired
```

---

## Known Issues & Workarounds

### Issue 1: Sync Stuck on "Syncing"
**Symptoms:** Entry shows "Syncing" indefinitely  
**Check:** Outbox processing logs for errors  
**Workaround:** Check backend connectivity, check authentication token  

### Issue 2: Duplicate Entries on Backend
**Symptoms:** Same entry synced multiple times  
**Check:** Backend ID assignment in logs  
**Workaround:** Ensure backend ID is stored correctly after creation  

### Issue 3: Pending Count Incorrect
**Symptoms:** Statistics show wrong pending count  
**Check:** Filter logic in `loadStatistics()`  
**Workaround:** Pull to refresh to recalculate  

---

## Sign-Off

### Test Environments
- [ ] **Development:** Local testing with mock backend
- [ ] **Staging:** Testing with staging backend
- [ ] **Production:** Final verification with production backend

### Test Coverage
- [ ] **Basic CRUD:** All operations tested ✓
- [ ] **Offline Mode:** Tested and verified ✓
- [ ] **Authentication:** Token scenarios tested ✓
- [ ] **Error Handling:** Major error cases covered ✓
- [ ] **Edge Cases:** Limits and special cases tested ✓
- [ ] **UI/UX:** Visual indicators verified ✓
- [ ] **Performance:** Benchmarks within acceptable range ✓

### Sign-Off
- [ ] **Developer:** Tested by _______________ on ___/___/___
- [ ] **QA:** Verified by _______________ on ___/___/___
- [ ] **Product:** Approved by _______________ on ___/___/___

---

## Next Steps After Testing

### If All Tests Pass ✅
1. Update documentation with any findings
2. Create release notes for backend integration
3. Deploy to TestFlight for user testing
4. Monitor production logs for issues
5. Plan Phase 3 enhancements (optional)

### If Issues Found ❌
1. Document all failing tests
2. Prioritize issues (critical, high, medium, low)
3. Create GitHub issues for tracking
4. Fix critical issues before proceeding
5. Re-test after fixes

---

**Testing Status:** 🔄 In Progress  
**Last Updated:** 2025-01-15  
**Tester:** _______________  
**Next Review:** ___/___/___