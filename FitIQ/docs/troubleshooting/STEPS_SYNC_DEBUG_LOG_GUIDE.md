# Steps Sync Debug Log Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Guide to understanding the enhanced logs for steps progress synchronization

---

## Overview

This guide explains the enhanced logging added to the steps progress synchronization flow. The logs help track data from HealthKit → Local Storage → Background Sync → Backend API.

---

## Issues Identified in Previous Logs

### Issue #1: LocalDataChangeMonitor Can't Find Entry
**Log:**
```
SwiftDataProgressRepository: Successfully saved progress entry with ID: B15983D5-1FC7-493F-B8BE-10430B5B2B15
LocalDataChangeMonitor: ProgressEntry with ID B15983D5-1FC7-493F-B8BE-10430B5B2B15 not found for user 774F6F3E-0237-4367-A54D-94898C0AB2E2.
```

**Root Cause:**  
`LocalDataChangeMonitor` creates a new `ModelContext` to fetch the entry, but the new context doesn't immediately see changes saved in another context until they're fully persisted.

**Solution Applied:**  
Added `Task.yield()` and a small delay (0.1s) in `SwiftDataProgressRepository.save()` to ensure the save is fully committed before notifying the monitor.

```swift
// After modelContext.save()
await Task.yield()
try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
```

### Issue #2: Unrelated Body Mass Sync Error
**Log:**
```
RemoteHealthDataSyncClient: Failed to upload body mass for user 774F6F3E-0237-4367-A54D-94898C0AB2E2 with local ID 142881E1-9F80-4431-BD4F-86D844DD4120. Error: The data couldn't be read because it isn't in the correct format.
```

**Root Cause:**  
There's a separate body mass entry that has a data format issue (likely in the DTO encoding).

**Not Related to Steps Sync:**  
This error is for a different data type (body mass, not steps progress). Steps sync uses a completely different endpoint (`/api/v1/progress` not `/api/v1/profile/metrics`).

---

## Enhanced Log Flow

With the new logging, you'll see a detailed flow like this:

### 1. Save Steps to Local Storage

```
SwiftDataProgressRepository: Saving progress entry - Type: steps, Quantity: 2241.0, User: 774F6F3E-0237-4367-A54D-94898C0AB2E2
SwiftDataProgressRepository: Successfully saved progress entry with ID: B15983D5-1FC7-493F-B8BE-10430B5B2B15
```

### 2. Notify Sync Monitor

```
LocalDataChangeMonitor: Publishing sync event for ProgressEntry (ID: B15983D5-1FC7-493F-B8BE-10430B5B2B15, new: true, status: pending)
```

### 3. RemoteSyncService Processes Event

```
RemoteSyncService: 📤 Processing progressEntry sync event for localID B15983D5-1FC7-493F-B8BE-10430B5B2B15
RemoteSyncService: Found progress entry to sync:
  - Type: steps
  - Quantity: 2241.0
  - Date: 2025-01-28 00:00:00 +0000
  - Time: nil
  - Current sync status: pending
RemoteSyncService: Updated sync status to 'syncing'
RemoteSyncService: 🌐 Calling /api/v1/progress API to upload progress entry...
```

### 4. ProgressAPIClient Makes Request

```
ProgressAPIClient: Logging progress - type: steps, quantity: 2241.0
ProgressAPIClient: Date: 2025-01-28
ProgressAPIClient: Request body: {
  "type" : "steps",
  "quantity" : 2241,
  "date" : "2025-01-28",
  "time" : null,
  "notes" : null
}
```

### 5. Backend Response

```
ProgressAPIClient: Response status code: 201
ProgressAPIClient: Response body: {
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "774F6F3E-0237-4367-A54D-94898C0AB2E2",
    "type": "steps",
    "quantity": 2241.0,
    "date": "2025-01-28",
    "created_at": "2025-01-28T10:30:00Z",
    "updated_at": "2025-01-28T10:30:00Z"
  }
}
```

### 6. Success - Update Local Entry

```
ProgressAPIClient: ✅ Successfully logged progress entry
  - Local ID: B15983D5-1FC7-493F-B8BE-10430B5B2B15
  - Backend ID: 550e8400-e29b-41d4-a716-446655440000
  - Type: steps
  - Quantity: 2241.0
  - Sync Status: synced

RemoteSyncService: ✅ /api/v1/progress API call successful!
  - Backend ID: 550e8400-e29b-41d4-a716-446655440000
  - Backend created at: 2025-01-28T10:30:00Z

RemoteSyncService: Updated local entry with backend ID
RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry B15983D5-1FC7-493F-B8BE-10430B5B2B15. Type: steps, Quantity: 2241.0, Backend ID: 550e8400-e29b-41d4-a716-446655440000
```

---

## Error Scenarios

### API Call Fails (Network Error)

```
RemoteSyncService: 🌐 Calling /api/v1/progress API to upload progress entry...
ProgressAPIClient: Logging progress - type: steps, quantity: 2241.0
ProgressAPIClient: Request body: {...}
ProgressAPIClient: Response status code: 500
ProgressAPIClient: Response body: {
  "success": false,
  "error": "Internal server error"
}

RemoteSyncService: ❌ /api/v1/progress API call FAILED!
  - Error: APIError.apiError(statusCode: 500, message: "Failed to log progress")
  - Error description: Failed to log progress
RemoteSyncService: Marked ProgressEntry B15983D5-1FC7-493F-B8BE-10430B5B2B15 as 'failed' for retry
```

### Entry Not Found

```
RemoteSyncService: 📤 Processing progressEntry sync event for localID B15983D5-1FC7-493F-B8BE-10430B5B2B15
RemoteSyncService: ❌ ProgressEntry with localID B15983D5-1FC7-493F-B8BE-10430B5B2B15 not found for remote sync.
```

### Validation Error (400)

```
ProgressAPIClient: Response status code: 400
ProgressAPIClient: Response body: {
  "success": false,
  "error": {
    "message": "Validation failed",
    "fields": {
      "quantity": "must be positive"
    }
  }
}

RemoteSyncService: ❌ /api/v1/progress API call FAILED!
  - Error: APIError.apiError(statusCode: 400, message: "Failed to log progress")
RemoteSyncService: Marked ProgressEntry as 'failed' for retry
```

---

## What to Look For

### ✅ Successful Sync

1. **Save to local storage** - Entry created with UUID
2. **Monitor notification** - Entry found and sync event published
3. **Remote sync starts** - Status changed to "syncing"
4. **API request** - Body shown with proper format
5. **API response 201** - Backend returns success with ID
6. **Local update** - Backend ID stored, status changed to "synced"

### ❌ Common Issues

1. **Monitor can't find entry**
   - **Before fix:** Entry saved but monitor fetches too early
   - **After fix:** Should not happen due to Task.yield() + delay

2. **API format error**
   - Look at "Request body" - ensure proper JSON format
   - Check date format: "YYYY-MM-DD" expected
   - Check quantity: must be numeric, not string

3. **Authentication error (401)**
   - Access token expired or invalid
   - Should trigger token refresh automatically

4. **Network timeout**
   - Backend not reachable
   - Entry marked as "failed" for retry

---

## Key Log Indicators

| Log Message | Meaning |
|------------|---------|
| `📤 Processing progressEntry` | Sync event received |
| `🌐 Calling /api/v1/progress` | About to make API call |
| `✅ /api/v1/progress API call successful!` | Backend accepted data |
| `✅✅✅ Successfully synced` | Complete success (local + remote) |
| `❌ /api/v1/progress API call FAILED!` | Backend rejected data |
| `Marked ProgressEntry as 'failed'` | Will retry later |

---

## Files Modified

1. **SwiftDataProgressRepository.swift**
   - Added Task.yield() and delay after save
   - Ensures persistence before notifying monitor

2. **RemoteSyncService.swift**
   - Added 📤 indicator for event processing start
   - Shows entry details before sync
   - Shows 🌐 indicator before API call
   - Shows ✅ or ❌ for API result
   - Detailed error logging

3. **ProgressAPIClient.swift**
   - Always logs request body (pretty printed)
   - Always logs response body (success or error)
   - Shows parsed entry details after success

---

## Testing Steps

1. **Trigger steps sync** (e.g., pull to refresh in Summary view)
2. **Watch console logs** in Xcode
3. **Verify flow:**
   - ✅ Entry saved locally
   - ✅ Monitor finds entry and publishes event
   - ✅ RemoteSyncService processes event
   - ✅ API request logged with body
   - ✅ API response logged
   - ✅ Local entry updated with backend ID

4. **Check database** (optional):
   - Local entry should have `backendID` populated
   - Local entry should have `syncStatus = "synced"`

---

## Next Steps

If sync still fails after these changes:

1. **Copy the full log output** from "📤 Processing progressEntry" to "✅✅✅ Successfully synced" (or error)
2. **Check the request body** - is the JSON correct?
3. **Check the response body** - what did the backend say?
4. **Verify API endpoint** - is `/api/v1/progress` correct in backend?
5. **Check backend logs** - did it receive the request?

---

**Status:** ✅ Enhanced logging implemented  
**Last Updated:** 2025-01-27