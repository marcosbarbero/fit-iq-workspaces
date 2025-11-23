# Steps & Heart Rate Outbox Verification Checklist

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Verify that steps and heart rate data are syncing correctly via Outbox Pattern

---

## ✅ Pre-Verification: Understanding the System

Before testing, confirm you understand:

- [ ] Steps and heart rate **already use** the Outbox Pattern
- [ ] They **never used** the old event-based system (LocalDataChangePublisher)
- [ ] The integration is **built-in** to SwiftDataProgressRepository
- [ ] No code changes were needed (unlike body mass migration)
- [ ] Sync is triggered by **HealthKit observers**, not user actions

---

## 🔍 Step 1: Verify Code Integration

### A. Check Use Cases Exist

- [ ] `SaveStepsProgressUseCase.swift` exists in `Domain/UseCases/`
- [ ] `SaveHeartRateProgressUseCase.swift` exists in `Domain/UseCases/`
- [ ] Both use cases accept `progressRepository: ProgressRepositoryProtocol`
- [ ] Both use cases call `progressRepository.save()` method

### B. Verify Repository Integration

- [ ] Open `SwiftDataProgressRepository.swift`
- [ ] Find the `save()` method around line 31
- [ ] Confirm it creates outbox events (lines 63-80):
  ```swift
  Task {
      let outboxEvent = try await outboxRepository.createEvent(
          eventType: .progressEntry,
          entityID: progressEntry.id,
          ...
      )
  }
  ```

### C. Check Sync Manager Calls

- [ ] Open `HealthDataSyncManager.swift`
- [ ] Verify `syncStepsToProgressTracking()` calls `saveStepsProgressUseCase.execute()`
- [ ] Verify `syncHeartRateToProgressTracking()` calls `saveHeartRateProgressUseCase.execute()`

### D. Verify Outbox Processor

- [ ] Open `OutboxProcessorService.swift`
- [ ] Find `processProgressEntry()` method around line 240
- [ ] Confirm it handles all progress types generically (no special-casing for steps/heart rate)

---

## 🧪 Step 2: Runtime Verification

### A. Enable Debug Logging

Add breakpoints or look for these log messages:

**When HealthKit data syncs:**
```
✅ "HealthDataSyncService: Syncing [N] steps for hour"
✅ "SaveStepsProgressUseCase: Saving [N] steps for user"
✅ "SwiftDataProgressRepository: Successfully saved progress entry"
✅ "SwiftDataProgressRepository: ✅ Created outbox event"
```

**When Outbox processor runs:**
```
✅ "OutboxProcessor: 🔄 Processing progressEntry event"
✅ "OutboxProcessor: Uploading progress entry: steps" (or "resting_heart_rate")
✅ "OutboxProcessor: ✅ Successfully processed event"
```

### B. Trigger Manual Sync

1. **Force HealthKit Sync:**
   - [ ] Open app with HealthKit permissions granted
   - [ ] Trigger manual sync via debug menu (if available)
   - [ ] OR: Use `ForceHealthKitResyncUseCase`

2. **Check Console Output:**
   - [ ] Look for "Saving [N] steps" messages
   - [ ] Look for "Created outbox event" messages
   - [ ] Note the outbox event ID and progress entry ID

### C. Verify Database State

**Query Progress Entries:**
```swift
let entries = try await progressRepository.fetchLocal(
    forUserID: currentUserID,
    type: .steps,
    syncStatus: .pending
)

print("Pending steps entries: \(entries.count)")
```

- [ ] Confirm pending entries exist before sync
- [ ] Verify each entry has `syncStatus = .pending`

**Query Outbox Events:**
```swift
let events = try await outboxRepository.fetchPendingEvents(forUserID: currentUserID)
let progressEvents = events.filter { $0.eventType == "progressEntry" }

print("Pending progress events: \(progressEvents.count)")
```

- [ ] Confirm outbox events exist for each progress entry
- [ ] Verify event metadata contains correct type ("steps" or "resting_heart_rate")

### D. Verify Processor Startup

- [ ] Confirm user is logged in
- [ ] Check that `OutboxProcessorService` has started
- [ ] Look for "OutboxProcessor: Starting processor" log message
- [ ] Verify processor interval is running (default: 30 seconds)

### E. Monitor Sync Completion

**Wait 30-60 seconds** (processor runs every 30 seconds):

- [ ] Look for "Processing progressEntry event" messages
- [ ] Verify "Successfully processed event" messages
- [ ] Check for "Successfully updated backend ID" messages

**Query Synced Entries:**
```swift
let syncedEntries = try await progressRepository.fetchLocal(
    forUserID: currentUserID,
    type: .steps,
    syncStatus: .synced
)

print("Synced steps entries: \(syncedEntries.count)")
```

- [ ] Confirm entries moved from `.pending` to `.synced`
- [ ] Verify `backendID` is now populated

**Query Completed Events:**
```swift
let completedEvents = try await outboxRepository.fetchEvents(
    status: .completed,
    limit: 100
)

print("Completed events: \(completedEvents.count)")
```

- [ ] Verify events moved to `.completed` status
- [ ] Check `completedAt` timestamp is set

---

## 🎯 Step 3: End-to-End Flow Verification

### Scenario 1: Fresh Steps Data from HealthKit

1. **Setup:**
   - [ ] Add steps in Apple Health app (or walk with device)
   - [ ] Wait for HealthKit observer to fire (can take a few minutes)

2. **Verify Flow:**
   - [ ] Check console for "HealthKit observer query fired"
   - [ ] Verify "Syncing [N] steps" message appears
   - [ ] Confirm "Created outbox event" message
   - [ ] Wait 30 seconds for processor
   - [ ] Verify "Successfully processed event" message
   - [ ] Check entry status changed to `.synced`

3. **Backend Verification:**
   - [ ] Query backend API for user's progress data
   - [ ] Confirm steps entry exists with correct timestamp
   - [ ] Verify backend ID matches local `backendID`

### Scenario 2: Fresh Heart Rate Data from HealthKit

1. **Setup:**
   - [ ] Ensure heart rate data available in Apple Health
   - [ ] Trigger HealthKit sync (automatic or manual)

2. **Verify Flow:**
   - [ ] Check console for "Syncing [N] bpm for hour"
   - [ ] Verify "Created outbox event" message
   - [ ] Wait for processor to run
   - [ ] Confirm sync completion

3. **Backend Verification:**
   - [ ] Query backend for heart rate entries
   - [ ] Verify data matches HealthKit values

### Scenario 3: App Crash During Sync

1. **Setup:**
   - [ ] Trigger steps/heart rate sync
   - [ ] Force-quit app **before** outbox processor runs
   - [ ] Verify progress entries exist in SwiftData
   - [ ] Verify outbox events exist with `.pending` status

2. **Recovery:**
   - [ ] Restart app
   - [ ] Login (processor starts automatically after login)
   - [ ] Verify processor picks up pending events
   - [ ] Confirm all pending entries get synced

3. **Validation:**
   - [ ] No data loss occurred
   - [ ] All entries eventually synced
   - [ ] Outbox events completed successfully

### Scenario 4: Network Failure During Upload

1. **Setup:**
   - [ ] Enable airplane mode
   - [ ] Trigger steps/heart rate sync
   - [ ] Verify outbox events created

2. **Monitor Retries:**
   - [ ] Wait for processor to attempt sync
   - [ ] Verify "Failed to process event" error
   - [ ] Check `attemptCount` increments
   - [ ] Confirm event stays in `.pending` status

3. **Recovery:**
   - [ ] Disable airplane mode
   - [ ] Wait for next processor cycle
   - [ ] Verify successful retry
   - [ ] Confirm sync completion

---

## 📊 Step 4: Data Integrity Checks

### A. No Duplicate Entries

```swift
// Query all steps entries for a specific hour
let entries = try await progressRepository.fetchLocal(
    forUserID: currentUserID,
    type: .steps,
    syncStatus: nil
)

// Group by date+hour
let grouped = Dictionary(grouping: entries) { entry in
    "\(entry.date)-\(entry.time ?? "")"
}

// Check for duplicates
let duplicates = grouped.filter { $0.value.count > 1 }
```

- [ ] Verify no duplicate entries for same hour
- [ ] Confirm repository unique constraints working

### B. No Orphaned Outbox Events

```swift
// Find outbox events for non-existent progress entries
let allEvents = try await outboxRepository.fetchPendingEvents(forUserID: currentUserID)

for event in allEvents where event.eventType == "progressEntry" {
    let entries = try await progressRepository.fetchLocal(
        forUserID: currentUserID,
        type: nil,
        syncStatus: nil
    )
    
    let entryExists = entries.contains { $0.id == event.entityID }
    assert(entryExists, "Orphaned outbox event: \(event.id)")
}
```

- [ ] No orphaned outbox events
- [ ] All events reference valid progress entries

### C. Sync Status Consistency

```swift
// Entries with backendID should be .synced
let entriesWithBackendID = entries.filter { $0.backendID != nil }
assert(entriesWithBackendID.allSatisfy { $0.syncStatus == .synced })

// Entries without backendID should be .pending or .failed
let entriesWithoutBackendID = entries.filter { $0.backendID == nil }
assert(entriesWithoutBackendID.allSatisfy { 
    $0.syncStatus == .pending || $0.syncStatus == .failed 
})
```

- [ ] Sync status matches backend ID presence
- [ ] No inconsistent states

---

## 🔧 Step 5: Configuration Verification

### A. AppDependencies Wiring

- [ ] `saveStepsProgressUseCase` is created in `AppDependencies.build()`
- [ ] `saveHeartRateProgressUseCase` is created in `AppDependencies.build()`
- [ ] Both use cases injected into `HealthDataSyncManager`
- [ ] `progressRepository` has `outboxRepository` dependency
- [ ] `outboxProcessorService` is created and started

### B. Outbox Processor Configuration

```swift
// OutboxProcessorService.swift
private let processingInterval: TimeInterval = 30  // seconds
private let batchSize = 10
private let maxRetries = 5
```

- [ ] Processing interval appropriate for use case
- [ ] Batch size handles expected volume
- [ ] Max retries reasonable (5 is good)

### C. HealthKit Observer Configuration

```swift
// BackgroundSyncManager.swift
let quantityTypesToObserve: [HKQuantityTypeIdentifier] = [
    .stepCount,
    .heartRate,
    // ...
]
```

- [ ] `.stepCount` is in observer list
- [ ] `.heartRate` is in observer list
- [ ] Background delivery enabled

---

## 📈 Step 6: Performance Verification

### A. Memory Usage

- [ ] Profile app with Instruments
- [ ] Verify no memory leaks in outbox processing
- [ ] Check SwiftData cache size stays reasonable
- [ ] Monitor during bulk sync (e.g., 24 hours of hourly data)

### B. Processing Speed

- [ ] Time how long processor takes per event
- [ ] Should be < 1 second per event under normal conditions
- [ ] Batch of 10 events should complete in < 15 seconds

### C. Database Performance

- [ ] Query performance for fetching pending events
- [ ] Index on `syncStatus` field working
- [ ] No slow queries (> 100ms)

---

## 🎓 Step 7: Edge Cases

### A. User Logout During Sync

1. [ ] Start sync with pending events
2. [ ] Logout mid-processing
3. [ ] Verify processor stops gracefully
4. [ ] Confirm events remain pending
5. [ ] Login with same user
6. [ ] Verify sync resumes

### B. Multiple Concurrent Syncs

1. [ ] Trigger steps sync
2. [ ] Trigger heart rate sync simultaneously
3. [ ] Verify no race conditions
4. [ ] Confirm all events processed
5. [ ] Check for proper concurrency handling

### C. Large Data Volume

1. [ ] Sync full day (24 hours × 2 metrics = 48 entries)
2. [ ] Verify all entries create outbox events
3. [ ] Confirm processor handles batch efficiently
4. [ ] Check no timeouts or resource exhaustion

### D. Failed Event Cleanup

1. [ ] Create event that will fail permanently
2. [ ] Let it reach max retries (5)
3. [ ] Verify marked as `.failed`
4. [ ] Confirm doesn't block other events
5. [ ] Check manual recovery possible

---

## ✅ Final Verification

### All Systems Green

- [ ] Steps sync creates outbox events ✅
- [ ] Heart rate sync creates outbox events ✅
- [ ] Outbox processor handles both types ✅
- [ ] Retry logic works correctly ✅
- [ ] Crash recovery tested ✅
- [ ] Network failure recovery tested ✅
- [ ] No data loss observed ✅
- [ ] Performance acceptable ✅
- [ ] No memory leaks ✅
- [ ] Edge cases handled ✅

### Documentation Complete

- [ ] `STEPS_HEARTRATE_OUTBOX_INTEGRATION.md` reviewed
- [ ] Architecture diagrams understood
- [ ] Integration points documented
- [ ] Error handling documented

### Ready for Production

- [ ] All checklist items passed
- [ ] Team briefed on how it works
- [ ] Monitoring/alerting in place
- [ ] Rollback plan prepared (if schema changes needed)

---

## 🚨 Troubleshooting

### Issue: No Outbox Events Created

**Check:**
- [ ] `outboxRepository` properly injected into `SwiftDataProgressRepository`
- [ ] `save()` method completing successfully (not throwing)
- [ ] Task spawned for event creation not being cancelled

**Solution:**
- Add breakpoint in `SwiftDataProgressRepository.save()` at line 63
- Verify outbox repository is not nil
- Check for any exceptions in Task block

### Issue: Events Stay Pending Forever

**Check:**
- [ ] User is logged in (`authManager.currentUserProfileID` not nil)
- [ ] Outbox processor is running (check for startup log)
- [ ] Network connectivity working
- [ ] Backend API accessible

**Solution:**
- Manually trigger processor: `await outboxProcessorService.processPendingEvents()`
- Check for error messages in logs
- Verify backend API health

### Issue: Duplicate Entries

**Check:**
- [ ] Repository unique constraints configured
- [ ] SwiftData schema has proper indexes
- [ ] Concurrent saves handled correctly

**Solution:**
- Review unique constraint on (userID + type + date + time)
- Add database-level deduplication if needed

### Issue: High Memory Usage

**Check:**
- [ ] Batch size not too large (should be 10-20)
- [ ] SwiftData context being released properly
- [ ] No retain cycles in async tasks

**Solution:**
- Reduce batch size
- Profile with Instruments to find leaks
- Ensure proper context cleanup

---

## 📞 Support

If verification fails:

1. Review `STEPS_HEARTRATE_OUTBOX_INTEGRATION.md` for architecture details
2. Check console logs for error messages
3. Query database state directly (SwiftData)
4. Compare with body mass implementation (reference)
5. Contact team with specific error details

---

**Version:** 1.0.0  
**Status:** ✅ Verification Guide  
**Last Updated:** 2025-01-27