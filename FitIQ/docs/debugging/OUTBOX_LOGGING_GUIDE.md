# Outbox Pattern Logging & Debugging Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Guide for debugging Outbox Pattern with enhanced logging

---

## Overview

This guide explains how to use the enhanced logging in the Outbox Pattern to debug sync issues. The Outbox Pattern ensures reliable data synchronization to the backend API by persisting events locally before attempting remote sync.

---

## Enhanced Logging Features

### What's Been Enhanced

All Outbox Pattern components now provide detailed, structured logging:

1. **Outbox Event Creation** - Rich context when events are created
2. **Batch Processing** - Summary of event types being processed
3. **Individual Event Processing** - Detailed progress tracking per event
4. **API Client Requests** - Full endpoint, method, and payload details
5. **Response Handling** - Success/failure details with backend IDs

---

## Log Flow for Sleep Data

### Complete Flow Example

When a sleep session is synced, you'll see logs like this:

```
1. SLEEP SYNC HANDLER (Source: HealthKit)
─────────────────────────────────────────
SleepSyncHandler: 🌙 Syncing sleep data for 2025-01-26...
SleepSyncHandler: Target date (wake date): 2025-01-26 (00:00 - 23:59:59)
SleepSyncHandler: Query window: 2025-01-25 to 2025-01-27
SleepSyncHandler: This captures sessions ending on 2025-01-26
SleepSyncHandler: Fetched 8 sleep samples from HealthKit
SleepSyncHandler: Grouped into 1 session(s) from 8 samples
SleepSyncHandler: After filtering by wake date (2025-01-26): 1 session(s)
SleepSyncHandler: Processing session with 8 samples from 2025-01-25 22:00:00 to 2025-01-26 06:00:00

2. REPOSITORY SAVES LOCALLY
─────────────────────────────────────────
SwiftDataSleepRepository: Saving sleep session for user 123e4567-e89b-12d3-a456-426614174000
SwiftDataSleepRepository: Sleep session saved with ID a1b2c3d4-e5f6-7890-abcd-ef1234567890

3. OUTBOX EVENT CREATED
─────────────────────────────────────────
OutboxRepository: 📦 Creating outbox event - Type: [Sleep Session] | EntityID: a1b2c3d4-e5f6-7890-abcd-ef1234567890 | UserID: 123e4567-e89b-12d3-a456-426614174000 | Priority: 5 | IsNew: true
OutboxRepository: ✅ Outbox event created - EventID: f0e1d2c3-b4a5-9687-1234-567890abcdef | Type: [Sleep Session] | Status: pending

4. OUTBOX PROCESSOR PICKS UP EVENT
─────────────────────────────────────────
OutboxProcessor: 📦 Processing batch of 1 pending events
  - Sleep Session: 1 event(s)

5. EVENT PROCESSING BEGINS
─────────────────────────────────────────
OutboxProcessor: 🔄 Processing [Sleep Session] - EventID: f0e1d2c3-b4a5-9687-1234-567890abcdef | EntityID: a1b2c3d4-e5f6-7890-abcd-ef1234567890 | Attempt: 1/5
OutboxProcessor: 💤 Processing [Sleep Session] - EventID: f0e1d2c3-b4a5-9687-1234-567890abcdef | EntityID: a1b2c3d4-e5f6-7890-abcd-ef1234567890

6. SLEEP SESSION DETAILS
─────────────────────────────────────────
OutboxProcessor: 📤 Uploading sleep session to /api/v1/sleep
  - Session ID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
  - Date: 2025-01-26 00:00:00
  - Time: 2025-01-25 22:00:00 → 2025-01-26 06:00:00
  - Duration: 480 min in bed, 420 min sleep
  - Efficiency: 87.5%
  - Stages: 8
  - Source: healthkit

7. API CLIENT REQUEST
─────────────────────────────────────────
SleepAPIClient: 🌐 POST https://fit-iq-backend.fly.dev/api/v1/sleep
SleepAPIClient: Posting sleep session to backend
SleepAPIClient: Request details:
  - Method: POST
  - Endpoint: /api/v1/sleep
  - Date: 2025-01-26
  - Start: 2025-01-25 22:00:00
  - End: 2025-01-26 06:00:00
  - Stages: 8
SleepAPIClient: Full request payload:
{
  "date": "2025-01-26",
  "startTime": "2025-01-25T22:00:00Z",
  "endTime": "2025-01-26T06:00:00Z",
  "stages": [
    { "stage": "awake", "startTime": "2025-01-25T22:00:00Z", "endTime": "2025-01-25T22:15:00Z", "durationMinutes": 15 },
    { "stage": "light", "startTime": "2025-01-25T22:15:00Z", "endTime": "2025-01-25T23:30:00Z", "durationMinutes": 75 },
    ...
  ]
}

8. API RESPONSE
─────────────────────────────────────────
SleepAPIClient: Response status code: 201
SleepAPIClient: ✅ Request successful (HTTP 201)
SleepAPIClient: Sleep session saved successfully
  - Backend ID: backend-sleep-session-id-12345
  - Response success: true

9. LOCAL UPDATE
─────────────────────────────────────────
OutboxProcessor: ✅ Sleep session uploaded successfully
  - Backend ID: backend-sleep-session-id-12345
  - Endpoint: POST /api/v1/sleep
OutboxProcessor: ✅ Sleep session a1b2c3d4-e5f6-7890-abcd-ef1234567890 marked as synced locally

10. OUTBOX EVENT COMPLETED
─────────────────────────────────────────
OutboxProcessor: ✅ Successfully processed [Sleep Session] - EventID: f0e1d2c3-b4a5-9687-1234-567890abcdef | EntityID: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

---

## Log Markers Reference

### 📦 Outbox Repository
- **Creating event**: `📦 Creating outbox event`
- **Event created**: `✅ Outbox event created`

### 🔄 Outbox Processor
- **Batch processing**: `📦 Processing batch of X pending events`
- **Event processing**: `🔄 Processing [Event Type]`
- **Success**: `✅ Successfully processed [Event Type]`
- **Failure**: `❌ Failed to process [Event Type]`
- **Retry delay**: `⏱️ Retry delay: Xs`

### 💤 Sleep-Specific
- **Processing sleep**: `💤 Processing [Sleep Session]`
- **Uploading**: `📤 Uploading sleep session to /api/v1/sleep`

### 🌐 API Client
- **Request**: `🌐 POST https://...`
- **Success**: `✅ Request successful (HTTP 20X)`
- **Response details**: Backend ID, success status

### 🌙 Sleep Sync Handler
- **Syncing**: `🌙 Syncing sleep data for...`
- **Query window**: Date range and filter logic
- **Processing**: Session details and filtering

---

## Key Information in Logs

### Outbox Event Creation

```
OutboxRepository: 📦 Creating outbox event - Type: [Sleep Session] | EntityID: ... | UserID: ... | Priority: 5 | IsNew: true
```

**What to check:**
- **Type**: Which data type (Sleep Session, Progress Entry, etc.)
- **EntityID**: Local UUID of the data being synced
- **UserID**: User who owns the data
- **Priority**: Higher = processed first (1-10 scale)
- **IsNew**: `true` = new record, `false` = update

### Batch Processing

```
OutboxProcessor: 📦 Processing batch of 3 pending events
  - Sleep Session: 1 event(s)
  - Progress Entry: 2 event(s)
```

**What to check:**
- Total events in batch
- Breakdown by event type
- If specific types are missing (might not have pending events)

### Event Processing

```
OutboxProcessor: 🔄 Processing [Sleep Session] - EventID: ... | EntityID: ... | Attempt: 1/5
```

**What to check:**
- **EventID**: Outbox event UUID (for tracking)
- **EntityID**: Local data UUID
- **Attempt**: Current/Max attempts (retries after failures)

### API Request Details

```
SleepAPIClient: 🌐 POST https://fit-iq-backend.fly.dev/api/v1/sleep
SleepAPIClient: Request details:
  - Method: POST
  - Endpoint: /api/v1/sleep
  - Date: 2025-01-26
  - Start: 2025-01-25 22:00:00
  - End: 2025-01-26 06:00:00
  - Stages: 8
```

**What to check:**
- **Endpoint**: Correct API path?
- **Date**: Correct date attribution?
- **Times**: Match expected sleep session?
- **Stages**: Should have sleep stage data

### API Response

```
SleepAPIClient: Response status code: 201
SleepAPIClient: ✅ Request successful (HTTP 201)
SleepAPIClient: Sleep session saved successfully
  - Backend ID: backend-sleep-session-id-12345
  - Response success: true
```

**What to check:**
- **Status code**: 201 = created, 200 = success, 401 = auth issue, 409 = duplicate, 500 = server error
- **Backend ID**: Assigned by server (confirms save)
- **Success flag**: `true` means backend accepted data

---

## Debugging Common Issues

### Issue 1: Outbox Events Not Created

**Symptoms:**
- No `📦 Creating outbox event` log after save
- Data saved locally but never synced

**Check:**
1. Repository `save()` method calls `outboxRepository.createEvent()`
2. No exceptions thrown during event creation
3. ModelContext.save() succeeds

**Example:**
```swift
// SwiftDataSleepRepository.swift
_ = try await outboxRepository.createEvent(
    eventType: .sleepSession,  // ✅ Correct type
    entityID: session.id,
    userID: userID,
    isNewRecord: session.backendID == nil,
    metadata: metadata,
    priority: 5
)
```

### Issue 2: Events Not Being Processed

**Symptoms:**
- Outbox event created but no `📦 Processing batch` log
- Events stuck in `pending` status

**Check:**
1. OutboxProcessorService is started: `startProcessing(forUserID:)`
2. User is authenticated (no events processed if no userID)
3. Check batch query: `fetchPendingEvents(forUserID:limit:)`

**Enable verbose logging:**
```swift
// Check processor status
print("OutboxProcessor: isProcessing = \(isProcessing)")
print("OutboxProcessor: processingInterval = \(processingInterval)s")
```

### Issue 3: API Request Fails

**Symptoms:**
- Event processed but `❌ Failed to process` log appears
- Status code 401, 403, 500, etc.

**Check:**
1. **401 Unauthorized**: Token refresh logic should auto-retry
2. **403 Forbidden**: API key might be invalid
3. **409 Conflict**: Duplicate (handled automatically)
4. **500 Server Error**: Backend issue, will retry automatically

**Look for:**
```
SleepAPIClient: Response status code: 401
OutboxProcessor: ❌ Failed to process [Sleep Session] - Error: ...
```

### Issue 4: Duplicate Errors (409)

**Symptoms:**
- `⚠️ Sleep session is duplicate (409 Conflict)`
- Event marked as synced anyway

**This is EXPECTED behavior:**
- Outbox Pattern guarantees "at-least-once" delivery
- Backend detects duplicates and returns 409
- We mark as synced since data already exists on backend
- No action needed - working as designed

### Issue 5: Wrong API Endpoint

**Symptoms:**
- 404 Not Found
- Wrong URL in logs

**Check:**
```
SleepAPIClient: 🌐 POST https://fit-iq-backend.fly.dev/api/v1/sleep
```

**Should be:**
- Sleep: `/api/v1/sleep`
- Progress: `/api/v1/progress`
- Profile: `/api/v1/users/profile`

**Fix in:**
- `SleepAPIClient.swift` - Check `baseURL` and endpoint construction

### Issue 6: Missing Sleep Stages

**Symptoms:**
- Stages: 0 in request details
- Backend rejects or calculates wrong metrics

**Check:**
```
OutboxProcessor: 📤 Uploading sleep session to /api/v1/sleep
  - Stages: 0  ❌ Should be > 0
```

**Debug:**
1. Check HealthKit has sleep stage data (not all devices support)
2. Check `SleepSyncHandler.processSleepSession()` converts stages
3. Check `SleepSession.toAPIRequest()` includes stages

---

## Filtering Logs

### View Only Sleep Sync Logs

```bash
# Xcode console filter:
SleepSync OR SleepAPI OR Sleep Session OR 💤
```

### View Only Outbox Logs

```bash
# Xcode console filter:
Outbox OR 📦 OR Processing batch
```

### View Only API Requests

```bash
# Xcode console filter:
🌐 OR Response status code
```

### View Only Errors

```bash
# Xcode console filter:
❌ OR Failed to process OR Error:
```

---

## Success Indicators

### ✅ Complete Successful Sync

Look for this sequence:

1. ✅ Sleep session saved locally
2. ✅ Outbox event created
3. ✅ Event picked up in batch
4. ✅ Request successful (HTTP 201)
5. ✅ Backend ID received
6. ✅ Event marked as completed

### ⚠️ Handled Edge Cases

These are **normal** and handled automatically:

- `⚠️ Sleep session is duplicate (409)` - Already synced, skipping
- `⏱️ Retry delay: Xs` - Failed previously, retrying with backoff
- Token refresh (401 → refresh → retry) - Automatic auth flow

---

## Troubleshooting Workflow

### Step 1: Verify Local Save

**Look for:**
```
SwiftDataSleepRepository: Sleep session saved with ID ...
```

**If missing:**
- Check HealthKit permissions
- Check sleep data exists in Health app
- Check sync handler logs for errors

### Step 2: Verify Outbox Event Creation

**Look for:**
```
OutboxRepository: 📦 Creating outbox event - Type: [Sleep Session] ...
OutboxRepository: ✅ Outbox event created - EventID: ...
```

**If missing:**
- Check repository calls `outboxRepository.createEvent()`
- Check for exceptions during save

### Step 3: Verify Processor Picks Up Event

**Look for:**
```
OutboxProcessor: 📦 Processing batch of X pending events
  - Sleep Session: 1 event(s)
```

**If missing:**
- Check `OutboxProcessorService.startProcessing()` was called
- Check user is authenticated
- Check `processingInterval` (default 30s)

### Step 4: Verify API Request

**Look for:**
```
SleepAPIClient: 🌐 POST https://...
SleepAPIClient: Request details: ...
```

**Check:**
- Endpoint is correct
- Request payload has all required fields
- Stages count > 0 (if HealthKit supports)

### Step 5: Verify API Response

**Look for:**
```
SleepAPIClient: Response status code: 201
SleepAPIClient: ✅ Request successful (HTTP 201)
```

**If 4xx/5xx:**
- 401: Auth issue (should auto-retry after token refresh)
- 403: API key issue
- 409: Duplicate (handled, no issue)
- 500: Backend issue (will retry)

### Step 6: Verify Completion

**Look for:**
```
OutboxProcessor: ✅ Successfully processed [Sleep Session] - EventID: ... | EntityID: ...
```

**Confirms:**
- Remote sync succeeded
- Local record marked as synced
- Outbox event marked as completed

---

## Performance Monitoring

### Metrics to Track

1. **Batch Size**: How many events per batch?
   - Normal: 1-10
   - High: >20 (might indicate sync lag)

2. **Processing Time**: Time from creation to completion
   - Normal: <10 seconds
   - Slow: >60 seconds (check network)

3. **Retry Rate**: How many events fail and retry?
   - Normal: <5%
   - High: >20% (investigate backend/network issues)

4. **Event Age**: How old are pending events?
   - Normal: <5 minutes
   - Stale: >1 hour (indicates stuck events)

### Query Stale Events

```swift
let staleEvents = try await outboxRepository.getStaleEvents(forUserID: userID)
print("Stale events: \(staleEvents.count)")
for event in staleEvents {
    print("  - \(event.eventType): \(event.createdAt)")
}
```

---

## Testing Outbox Pattern

### Manual Test: Force Sync

1. Trigger sleep sync (pull-to-refresh or background)
2. Watch logs for complete flow (10 steps above)
3. Verify backend has data (check Swagger UI or database)

### Manual Test: Offline Sync

1. Enable airplane mode
2. Trigger sleep sync
3. Verify local save + outbox event created
4. Disable airplane mode
5. Wait for OutboxProcessor to pick up event
6. Verify successful sync

### Manual Test: Duplicate Handling

1. Sync sleep session
2. Force re-sync same date (triggers duplicate)
3. Verify 409 Conflict handled gracefully
4. Verify event marked as completed

---

## Related Documentation

- **Outbox Pattern Overview**: `docs/architecture/OUTBOX_PATTERN.md`
- **Sleep Sync Logic**: `docs/architecture/SLEEP_SYNC_LOGIC.md`
- **API Integration**: `docs/api-integration/`
- **HealthKit Sync Entry Points**: `docs/architecture/HEALTHKIT_SYNC_ENTRY_POINTS.md`

---

## Log Examples by Scenario

### Scenario 1: First-Time Sleep Sync (Success)

```
SleepSyncHandler: 🌙 Syncing sleep data for 2025-01-26...
SwiftDataSleepRepository: Sleep session saved with ID a1b2c3d4...
OutboxRepository: 📦 Creating outbox event - Type: [Sleep Session] | IsNew: true
OutboxProcessor: 🔄 Processing [Sleep Session] - Attempt: 1/5
SleepAPIClient: 🌐 POST /api/v1/sleep
SleepAPIClient: ✅ Request successful (HTTP 201)
OutboxProcessor: ✅ Successfully processed [Sleep Session]
```

### Scenario 2: Duplicate Sleep Session (409)

```
SleepSyncHandler: 🌙 Syncing sleep data for 2025-01-26...
SwiftDataSleepRepository: Sleep session saved with ID a1b2c3d4...
OutboxRepository: 📦 Creating outbox event - Type: [Sleep Session] | IsNew: false
OutboxProcessor: 🔄 Processing [Sleep Session] - Attempt: 1/5
SleepAPIClient: 🌐 POST /api/v1/sleep
SleepAPIClient: Response status code: 409
OutboxProcessor: ⚠️ Sleep session is duplicate (409 Conflict) - marking as synced anyway
OutboxProcessor: ✅ Successfully processed [Sleep Session]
```

### Scenario 3: Network Failure with Retry

```
SleepSyncHandler: 🌙 Syncing sleep data for 2025-01-26...
OutboxProcessor: 🔄 Processing [Sleep Session] - Attempt: 1/5
SleepAPIClient: 🌐 POST /api/v1/sleep
OutboxProcessor: ❌ Failed to process [Sleep Session] - Error: Network connection lost
[30 seconds later]
OutboxProcessor: 🔄 Processing [Sleep Session] - Attempt: 2/5
OutboxProcessor: ⏱️ Retry delay: 5s for event ...
SleepAPIClient: 🌐 POST /api/v1/sleep
SleepAPIClient: ✅ Request successful (HTTP 201)
OutboxProcessor: ✅ Successfully processed [Sleep Session]
```

### Scenario 4: Token Refresh (401)

```
OutboxProcessor: 🔄 Processing [Sleep Session] - Attempt: 1/5
SleepAPIClient: 🌐 POST /api/v1/sleep
SleepAPIClient: Response status code: 401
SleepAPIClient: Access token expired. Attempting refresh...
SleepAPIClient: ✅ New tokens saved to keychain
SleepAPIClient: Token refreshed successfully. Retrying original request...
SleepAPIClient: ✅ Request successful (HTTP 201)
OutboxProcessor: ✅ Successfully processed [Sleep Session]
```

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Active