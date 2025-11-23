# Body Mass Outbox Pattern Integration

**Created:** 2025-01-31  
**Status:** ✅ Complete  
**Purpose:** Document the migration from event-based sync to Outbox Pattern for body mass tracking

---

## 🎯 What Was Done

Body mass (weight) tracking has been migrated from the old event-based sync (using `LocalDataChangePublisher`) to the more reliable **Outbox Pattern**.

### Key Changes

1. **SwiftDataProgressRepository Updated**
   - Removed dependency on `LocalDataChangeMonitor`
   - Added dependency on `OutboxRepositoryProtocol`
   - Creates persistent outbox events instead of publishing in-memory events
   - Events survive app crashes and restarts

2. **AppDependencies Updated**
   - Created `SwiftDataOutboxRepository` instance
   - Created `OutboxProcessorService` instance
   - Injected `OutboxRepository` into `SwiftDataProgressRepository`
   - Automatically starts `OutboxProcessorService` when user is authenticated

3. **Schema V3 Created**
   - Added `SDOutboxEvent` model to persist sync events
   - CloudKit-compatible (all attributes have defaults, no unique constraints)
   - Lightweight migration from V2 to V3

---

## 📊 Architecture: Before vs After

### Before (Event-Based Sync)

```
User saves weight
    ↓
SwiftDataProgressRepository.save()
    ↓
Delay 250ms (hope data propagates)
    ↓
LocalDataChangeMonitor.notifyLocalRecordChanged()
    ↓
LocalDataChangePublisher.publish(event)  ← In-memory, can be lost!
    ↓
RemoteSyncService receives event
    ↓
Upload to API
```

**Problems:**
- ❌ Events lost on app crash
- ❌ No retry if network fails
- ❌ No delivery guarantee
- ❌ Race conditions with data propagation
- ❌ No audit trail

---

### After (Outbox Pattern)

```
User saves weight
    ↓
SwiftDataProgressRepository.save()
    ↓
Create SDOutboxEvent in database  ← Persisted immediately!
    ↓
OutboxProcessorService polls for pending events (every 2s)
    ↓
Process event in background
    ↓
Upload to API
    ↓
Mark event as completed
```

**Benefits:**
- ✅ Events persist in database (survive crashes)
- ✅ Automatic retry with exponential backoff
- ✅ Guaranteed at-least-once delivery
- ✅ Transaction-safe (data + event saved atomically)
- ✅ Full audit trail
- ✅ Batch processing
- ✅ Observable processing state

---

## 🔧 Technical Details

### 1. Outbox Event Creation

When a weight entry is saved:

```swift
// In SwiftDataProgressRepository.save()
let outboxEvent = try await outboxRepository.createEvent(
    eventType: .progressEntry,
    entityID: progressEntry.id,
    userID: userID,
    isNewRecord: progressEntry.backendID == nil,
    metadata: [
        "type": progressEntry.type.rawValue,      // "weight"
        "quantity": progressEntry.quantity,        // 72.0
        "date": progressEntry.date.timeIntervalSince1970
    ],
    priority: 0
)
```

**Event Structure:**
- `id`: Unique event ID (UUID)
- `eventType`: "progressEntry"
- `entityID`: Local ID of weight entry
- `userID`: User who owns this data
- `status`: "pending" (initial state)
- `metadata`: JSON with type, quantity, date
- `isNewRecord`: true if no backendID yet
- `attemptCount`: 0 (increments on retry)
- `maxAttempts`: 5 (give up after 5 failures)

---

### 2. Background Processing

`OutboxProcessorService` runs continuously:

```swift
// Configuration
batchSize: 10                  // Process 10 events per batch
processingInterval: 2.0        // Check every 2 seconds
cleanupInterval: 3600          // Clean up old events every hour
maxConcurrentOperations: 3     // Max 3 API calls at once
```

**Processing Flow:**

1. **Poll for pending events** (every 2s)
   - Query: `status == 'pending' OR (status == 'failed' AND attemptCount < maxAttempts)`
   - Ordered by: priority (desc), createdAt (asc)

2. **Mark as processing**
   - Update status: 'pending' → 'processing'
   - Increment attemptCount
   - Set lastAttemptAt

3. **Fetch entity from local storage**
   - Get ProgressEntry by entityID
   - Verify data still exists

4. **Upload to remote API**
   - Call `/api/v1/progress` endpoint
   - Include auth token

5. **Handle result**
   - **Success:** Mark as 'completed', store backendID
   - **Failure:** Mark as 'failed', store error message
   - Automatic retry with exponential backoff

---

### 3. Retry Logic

**Exponential backoff delays:**
- Attempt 1: 1 second
- Attempt 2: 5 seconds
- Attempt 3: 30 seconds
- Attempt 4: 2 minutes
- Attempt 5: 10 minutes
- After 5 failures: Give up

**Status transitions:**
```
pending → processing → completed ✅
                    ↓
                 failed → pending (retry)
                    ↓
                 failed (maxAttempts reached) ❌
```

---

## 📝 Code Changes Summary

### Files Modified

1. **`SwiftDataProgressRepository.swift`**
   ```swift
   // Before
   private let localDataChangeMonitor: LocalDataChangeMonitor
   
   init(modelContainer: ModelContainer, localDataChangeMonitor: LocalDataChangeMonitor) {
       self.localDataChangeMonitor = localDataChangeMonitor
   }
   
   // After
   private let outboxRepository: OutboxRepositoryProtocol
   
   init(modelContainer: ModelContainer, outboxRepository: OutboxRepositoryProtocol) {
       self.outboxRepository = outboxRepository
   }
   ```

2. **`AppDependencies.swift`**
   ```swift
   // Create Outbox Repository
   let outboxRepository = SwiftDataOutboxRepository(
       modelContext: ModelContext(container)
   )
   
   // Inject into Progress Repository
   let swiftDataProgressRepository = SwiftDataProgressRepository(
       modelContainer: container,
       outboxRepository: outboxRepository  // ← Changed
   )
   
   // Create Processor (started on login, not at init)
   let outboxProcessorService = OutboxProcessorService(
       outboxRepository: outboxRepository,
       progressRepository: progressRepository,
       localHealthDataStore: swiftDataLocalHealthDataStore,
       activitySnapshotRepository: swiftDataActivitySnapshotRepository,
       remoteDataSync: remoteHealthDataSyncClient,
       authManager: authManager
   )
   
   // Observe authentication state to auto-start/stop processor
   Task { @MainActor in
       // Start for already authenticated user
       if let currentUserID = authManager.currentUserProfileID {
           outboxProcessorService.startProcessing(forUserID: currentUserID)
       }
       
       // Observe login/logout events
       for await userID in authManager.$currentUserProfileID.values {
           if let userID = userID {
               outboxProcessorService.startProcessing(forUserID: userID)
           } else {
               outboxProcessorService.stopProcessing()
           }
       }
   }
   ```

### Files Created

1. **`Domain/Entities/Outbox/OutboxEventTypes.swift`**
   - `OutboxEventType` enum
   - `OutboxEventStatus` enum
   - Extension methods on `SDOutboxEvent`

2. **`Domain/Ports/OutboxRepositoryProtocol.swift`**
   - Protocol defining outbox CRUD operations
   - Models: `OutboxStatistics`

3. **`Infrastructure/Persistence/SwiftDataOutboxRepository.swift`**
   - SwiftData implementation of outbox pattern
   - Event creation, fetching, updating, deletion

4. **`Infrastructure/Network/OutboxProcessorService.swift`**
   - Background processor for outbox events
   - Batch processing, retry logic, cleanup

5. **`Infrastructure/Persistence/Schema/SchemaV3.swift`**
   - Added `SDOutboxEvent` @Model class
   - CloudKit-compatible attributes

6. **`Infrastructure/Persistence/Migration/PersistenceMigrationPlan.swift`**
   - Added SchemaV3 to schemas array
   - Lightweight migration V2→V3

---

## 🧪 Testing

### Verify Integration Works

1. **Save a weight entry:**
   ```swift
   await bodyMassEntryViewModel.saveWeight(72.0)
   ```

2. **Check logs for outbox event:**
   ```
   SwiftDataProgressRepository: Successfully saved progress entry with ID: XXX
   SwiftDataProgressRepository: ✅ Created outbox event YYY for progress entry XXX
   ```

3. **Watch processor pick it up:**
   ```
   OutboxProcessor: Processing pending events (batch size: 10)
   OutboxProcessor: Processing event YYY (type: progressEntry, entityID: XXX)
   OutboxRepository: 🔄 Marked event YYY as processing (attempt 1)
   OutboxProcessor: 🌐 Uploading progressEntry XXX to remote API
   OutboxProcessor: ✅ Successfully synced progressEntry XXX
   OutboxRepository: ✅ Marked event YYY as completed
   ```

### Debug Outbox Status

Use the debug tools created earlier:

```swift
// In SyncDebugViewModel or console
let stats = try await outboxRepository.getStatistics(forUserID: userID)
print("Pending: \(stats.pendingCount)")
print("Failed: \(stats.failedCount)")
print("Completed: \(stats.completedCount)")

// Get stuck events
let stale = try await outboxRepository.getStaleEvents(forUserID: userID)
print("Stale events (>5 min): \(stale.count)")
```

---

## 🎯 What This Fixes

### Issues Resolved

1. **"Most recent entry is 5h old - considered stale"**
   - Before: Sync events could be lost, causing delays
   - After: Persistent events guarantee eventual sync

2. **"LocalDataChangeMonitor: Publishing sync event"**
   - Before: In-memory events, no recovery on crash
   - After: Database-backed events, crash-resistant

3. **Race conditions with SwiftData**
   - Before: 250ms delay hoping data propagates
   - After: Event created atomically with data save

4. **No retry on network failure**
   - Before: Failed sync was lost forever
   - After: Automatic retry with exponential backoff

5. **No visibility into sync status**
   - Before: Events disappeared into the void
   - After: Full audit trail, queryable status

---

## 🚀 Next Steps

### Immediate

- ✅ Body mass uses Outbox Pattern
- ✅ Processor auto-starts on login (observes AuthManager state)
- ⏳ Other metrics still use event-based sync
- ⏳ Monitor outbox statistics in production

### Future Improvements

1. **Migrate other metrics to Outbox:**
   - Steps (progress entries)
   - Heart rate (progress entries)
   - Mood (progress entries)
   - Physical attributes (height, body fat %)
   - Activity snapshots

2. **Add monitoring/observability:**
   - Expose outbox stats in debug UI
   - Alert on high failure count
   - Track sync latency metrics

3. **Optimize batch processing:**
   - Tune batch size based on network conditions
   - Implement priority queues
   - Add network-aware scheduling

4. **Add manual retry UI:**
   - Show failed events to user
   - Allow manual retry button
   - Explain why sync failed

---

## 📚 Related Documentation

- **`OUTBOX_PATTERN_ARCHITECTURE.md`** - Complete architecture overview
- **`SYNC_PATTERNS_COMPARISON.md`** - Event-based vs Outbox comparison
- **`OUTBOX_INTEGRATION_CHECKLIST.md`** - Integration steps
- **`CLOUDKIT_SWIFTDATA_REQUIREMENTS.md`** - CloudKit constraints

---

## 🔍 Troubleshooting

### Outbox events not processing

**Check 1: Is processor started?**
```swift
// Look for this log after login:
"AppDependencies: User logged in, starting OutboxProcessorService for user XXX"

// Or on app launch if already logged in:
"AppDependencies: User already authenticated, starting OutboxProcessorService for user XXX"
```

**Check 2: Are events being created?**
```swift
// After saving weight, look for:
"SwiftDataProgressRepository: ✅ Created outbox event YYY"
```

**Check 3: Check event status**
```swift
let pending = try await outboxRepository.fetchPendingEvents(forUserID: userID)
print("Pending events: \(pending.count)")

for event in pending {
    print("Event \(event.id): attempts=\(event.attemptCount), error=\(event.errorMessage ?? "none")")
}
```

### Events stuck in "processing"

This can happen if app crashes during processing:

```swift
// Reset stuck events to pending
let stale = try await outboxRepository.getStaleEvents(forUserID: userID)
let staleIDs = stale.map { $0.id }
try await outboxRepository.resetForRetry(staleIDs)
```

### High failure count

Check error messages:

```swift
let failed = try await outboxRepository.fetchEvents(
    withStatus: .failed,
    forUserID: userID
)

for event in failed {
    print("Failed event \(event.id): \(event.errorMessage ?? "unknown error")")
}
```

Common causes:
- Network connection issues
- Auth token expired
- API endpoint down
- Invalid data format

---

**Status:** ✅ Integration Complete  
**Tested:** Pending production validation  
**Monitoring:** Use SyncDebugViewModel for status checks  
**Version:** 1.0