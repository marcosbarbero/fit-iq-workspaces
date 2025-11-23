# Outbox Pattern Architecture

**Date:** 2025-01-31  
**Purpose:** Reliable event-driven sync using persistent outbox  
**Status:** ✅ Recommended Architecture

---

## 🎯 Overview

The **Outbox Pattern** is a proven distributed systems pattern that ensures reliable message delivery by persisting events before attempting to process them.

### Why Outbox Pattern?

**Current Problems (Event-Based with Combine):**
- ❌ Events are transient (in-memory)
- ❌ Lost on app crash/termination
- ❌ No delivery guarantee
- ❌ Race conditions with multiple event types
- ❌ Hard to retry failed syncs
- ❌ No audit trail

**Outbox Pattern Benefits:**
- ✅ Events persist in database (survive crashes)
- ✅ Guaranteed at-least-once delivery
- ✅ Transaction-safe (data + event saved atomically)
- ✅ Automatic retry with exponential backoff
- ✅ Natural audit trail
- ✅ Offline-first with guaranteed sync
- ✅ Multiple event types handled uniformly
- ✅ No lost data, ever

---

## 🏗️ Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      User Action                             │
│                   (Log Weight, etc.)                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              SaveWeightProgressUseCase                       │
│                                                              │
│  1. Save ProgressEntry to local SwiftData                   │
│  2. Create SDOutboxEvent in SAME transaction                │
│                                                              │
│  → Both saved atomically (transaction-safe)                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  SDOutboxEvent                               │
│               (Persisted in SwiftData)                       │
│                                                              │
│  id: UUID                                                    │
│  eventType: "progressEntry"                                 │
│  entityID: <ProgressEntry.id>                               │
│  status: "pending"                                          │
│  createdAt: Date                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│            OutboxProcessorService                            │
│          (Runs in background loop)                           │
│                                                              │
│  Every 2 seconds:                                           │
│  1. Fetch pending events (batch of 10)                      │
│  2. Process each event concurrently (max 3 at once)         │
│  3. Call remote API to sync data                            │
│  4. Mark as completed or failed                             │
│  5. Retry failed events with exponential backoff            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Remote API Response                             │
│                                                              │
│  Success (200):                                             │
│    → Update local entry with backend ID                     │
│    → Mark event as "completed"                              │
│                                                              │
│  Failure (4xx/5xx):                                         │
│    → Mark event as "failed"                                 │
│    → Retry with exponential backoff: 1s, 5s, 30s, 2m, 10m  │
│    → Max 5 attempts                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Implementation Structure

### Domain Layer

**SDOutboxEvent.swift** - SwiftData @Model
- Persistent event storage
- Properties: id, eventType, entityID, userID, status, attempts, etc.
- Computed properties: canRetry, isStale, shouldProcess
- Helper methods: markAsProcessing(), markAsCompleted(), markAsFailed()

**OutboxRepositoryProtocol.swift** - Port (Interface)
- createEvent()
- fetchPendingEvents()
- fetchEvents(withStatus:)
- markAsCompleted/Failed()
- deleteCompletedEvents()
- getStatistics()

**OutboxEventType** - Enum
- progressEntry
- physicalAttribute
- activitySnapshot
- profileMetadata
- profilePhysical

**OutboxEventStatus** - Enum
- pending
- processing
- completed
- failed

### Infrastructure Layer

**SwiftDataOutboxRepository.swift** - Concrete Implementation
- Uses ModelContext for persistence
- Efficient queries with FetchDescriptor
- Transaction-safe operations

**OutboxProcessorService.swift** - Processing Engine
- Background processing loop
- Batch processing with concurrency control
- Exponential backoff retry logic
- Automatic cleanup of old events

---

## 🔄 Transaction Safety

### Critical: Atomic Operations

**Problem with Events:**
```swift
// ❌ BAD: Non-atomic (can lose event if crash between operations)
try await progressRepository.save(progressEntry)  // ✅ Saved
// ⚡️ App crashes here!
eventPublisher.publish(event)  // ❌ Never published - event lost!
```

**Solution with Outbox:**
```swift
// ✅ GOOD: Atomic transaction
modelContext.transaction {
    // 1. Insert progress entry
    modelContext.insert(progressEntry)
    
    // 2. Insert outbox event
    let outboxEvent = SDOutboxEvent(
        eventType: .progressEntry,
        entityID: progressEntry.id,
        userID: userID
    )
    modelContext.insert(outboxEvent)
    
    // Both saved in same transaction - all or nothing!
    try modelContext.save()
}
// ⚡️ Even if app crashes here, BOTH are saved
```

**Key Benefit:** Database ACID guarantees ensure data + event are saved atomically.

---

## ⚡️ Processing Flow

### Startup

```swift
// In FitIQApp.swift or AppDependencies
let outboxProcessor = OutboxProcessorService(
    outboxRepository: outboxRepository,
    progressRepository: progressRepository,
    // ... other dependencies
)

// Start processing on app launch
outboxProcessor.startProcessing(forUserID: currentUserID)
```

### Background Loop

```
OutboxProcessor starts
    ↓
Every 2 seconds:
    ↓
1. Fetch pending events (limit 10)
    ↓
2. No events? → Wait 2s, loop
   Has events? → Continue
    ↓
3. Process up to 3 events concurrently
    ↓
    For each event:
        ↓
    a. Check retry delay (exponential backoff)
    b. Mark as "processing"
    c. Fetch entity from local DB
    d. Call remote API
    e. Handle response:
       - Success → mark "completed"
       - Failure → mark "failed"
    ↓
4. Wait 2s, repeat
```

### Retry Strategy

**Exponential Backoff:**
- Attempt 1: Immediate
- Attempt 2: +1 second delay
- Attempt 3: +5 seconds delay
- Attempt 4: +30 seconds delay
- Attempt 5: +2 minutes delay
- Attempt 6: +10 minutes delay
- After 5 attempts: Give up, mark as permanently failed

**Why Exponential Backoff?**
- Avoids overwhelming API during outages
- Gives transient errors time to resolve
- Reduces battery/network usage
- Industry-standard pattern

---

## 🔧 Integration Guide

### Step 1: Update Schema

Add SDOutboxEvent to your SwiftData schema:

```swift
// In CurrentSchema.swift
enum CurrentSchema: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 1, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            SDProgressEntry.self,
            SDPhysicalAttribute.self,
            SDActivitySnapshot.self,
            SDOutboxEvent.self,  // ← ADD THIS
            // ... other models
        ]
    }
}
```

### Step 2: Update Use Cases

Modify save use cases to create outbox events:

```swift
// In SaveWeightProgressUseCase
func execute(weight: Double, date: Date) async throws -> UUID {
    let progressEntry = ProgressEntry(
        id: UUID(),
        userID: userID,
        type: .weight,
        quantity: weight,
        date: date,
        syncStatus: .pending
    )
    
    // Save entry to local DB
    let localID = try await progressRepository.save(
        progressEntry: progressEntry,
        forUserID: userID
    )
    
    // Create outbox event (transaction-safe if using same ModelContext)
    _ = try await outboxRepository.createEvent(
        eventType: .progressEntry,
        entityID: localID,
        userID: userID,
        isNewRecord: true,
        metadata: nil,
        priority: 0
    )
    
    return localID
}
```

### Step 3: Wire Up Dependencies

```swift
// In AppDependencies.swift
lazy var outboxRepository: OutboxRepositoryProtocol = SwiftDataOutboxRepository(
    modelContext: modelContext
)

lazy var outboxProcessor: OutboxProcessorService = OutboxProcessorService(
    outboxRepository: outboxRepository,
    progressRepository: progressRepository,
    localHealthDataStore: localHealthDataStore,
    activitySnapshotRepository: activitySnapshotRepository,
    remoteDataSync: remoteHealthDataSyncClient,
    authManager: authManager
)
```

### Step 4: Start Processor

```swift
// In FitIQApp.swift or after login
if let userID = authManager.currentUserProfileID {
    outboxProcessor.startProcessing(forUserID: userID)
}
```

### Step 5: Stop Processor (Optional)

```swift
// On logout or app termination
outboxProcessor.stopProcessing()
```

---

## 🎚️ Configuration

### Tunable Parameters

```swift
OutboxProcessorService(
    // Number of events to process per batch
    batchSize: 10,  // Default: 10
    
    // How often to check for new events (seconds)
    processingInterval: 2.0,  // Default: 2s
    
    // How often to clean up old events (seconds)
    cleanupInterval: 3600,  // Default: 1 hour
    
    // Max concurrent API calls
    maxConcurrentOperations: 3  // Default: 3
)
```

**Tuning Guidelines:**

**batchSize:**
- Small (5-10): Lower memory usage, more responsive
- Large (20-50): Better throughput, higher memory usage
- Recommended: 10-20 for mobile

**processingInterval:**
- Short (1-2s): Near real-time sync, higher battery usage
- Long (5-10s): Lower battery, slower sync
- Recommended: 2-5s

**maxConcurrentOperations:**
- Low (1-2): Conservative, less API load
- High (5-10): Faster processing, more aggressive
- Recommended: 3-5

---

## 📊 Monitoring & Debugging

### Statistics API

```swift
let stats = try await outboxRepository.getStatistics(forUserID: userID)

print("Total events: \(stats.totalEvents)")
print("Pending: \(stats.pendingCount)")
print("Completed: \(stats.completedCount)")
print("Failed: \(stats.failedCount)")
print("Success rate: \(stats.successRate)%")
```

### Health Checks

```swift
// Check for stale events (pending > 5 minutes)
let staleEvents = try await outboxRepository.getStaleEvents(forUserID: userID)

if !staleEvents.isEmpty {
    print("⚠️ \(staleEvents.count) stale events detected")
    // Consider manual intervention or alerting
}
```

### Console Logs

**Good Sync:**
```
OutboxRepository: Creating event of type progressEntry
OutboxProcessor: 📦 Processing batch of 1 events
OutboxProcessor: 🔄 Processing progressEntry event <UUID>
OutboxProcessor: Uploading progress entry: weight
OutboxProcessor: ✅ Progress entry synced, backend ID: <UUID>
OutboxProcessor: ✅ Successfully processed event <UUID>
```

**Failed Sync (with retry):**
```
OutboxProcessor: ❌ Failed to process event <UUID>: Network error
OutboxRepository: ❌ Marked event as failed (will retry)
OutboxProcessor: ⏱️ Retry delay: 1s for event <UUID>
OutboxProcessor: 🔄 Processing progressEntry event <UUID>
OutboxProcessor: ✅ Successfully processed event <UUID>
```

---

## 🧪 Testing

### Unit Tests

```swift
func testEventCreation() async throws {
    // Given
    let eventType = OutboxEventType.progressEntry
    let entityID = UUID()
    
    // When
    let event = try await outboxRepository.createEvent(
        eventType: eventType,
        entityID: entityID,
        userID: "test-user",
        isNewRecord: true,
        metadata: nil,
        priority: 0
    )
    
    // Then
    XCTAssertEqual(event.eventType, eventType.rawValue)
    XCTAssertEqual(event.entityID, entityID)
    XCTAssertEqual(event.status, OutboxEventStatus.pending.rawValue)
}

func testRetryLogic() async throws {
    // Given
    let event = try await createFailedEvent(attemptCount: 2)
    
    // When
    event.resetForRetry()
    try await outboxRepository.updateEvent(event)
    
    // Then
    XCTAssertEqual(event.status, OutboxEventStatus.pending.rawValue)
    XCTAssertTrue(event.canRetry)
}
```

### Integration Tests

```swift
func testEndToEndSync() async throws {
    // 1. Create progress entry
    let weight = 72.0
    let localID = try await saveWeightProgressUseCase.execute(
        weight: weight,
        date: Date()
    )
    
    // 2. Verify outbox event created
    let events = try await outboxRepository.fetchPendingEvents(
        forUserID: userID,
        limit: nil
    )
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].entityID, localID)
    
    // 3. Trigger processing
    await outboxProcessor.triggerProcessing(forUserID: userID)
    
    // 4. Wait for processing
    try await Task.sleep(nanoseconds: 3_000_000_000)
    
    // 5. Verify event completed
    let event = try await outboxRepository.fetchEvent(byID: events[0].id)
    XCTAssertEqual(event?.status, OutboxEventStatus.completed.rawValue)
    
    // 6. Verify data synced to remote
    let remoteEntries = try await progressRepository.getProgressHistory(
        type: .weight,
        from: Date().addingTimeInterval(-3600),
        to: Date(),
        page: nil,
        limit: 10
    )
    XCTAssertTrue(remoteEntries.contains { $0.quantity == weight })
}
```

---

## 🔍 Comparison: Outbox vs Event-Based

| Feature | Event-Based (Combine) | Outbox Pattern |
|---------|----------------------|----------------|
| **Persistence** | ❌ Transient (memory) | ✅ Persisted (DB) |
| **Crash Recovery** | ❌ Events lost | ✅ Events survive |
| **Delivery Guarantee** | ❌ At-most-once | ✅ At-least-once |
| **Transaction Safety** | ❌ Separate operations | ✅ Atomic |
| **Retry Logic** | ❌ Manual | ✅ Built-in |
| **Audit Trail** | ❌ None | ✅ Full history |
| **Offline Support** | ⚠️ Requires network | ✅ Queue & sync later |
| **Complexity** | ✅ Simple | ⚠️ Moderate |
| **Performance** | ✅ Low overhead | ⚠️ DB writes |
| **Debugging** | ❌ Hard to trace | ✅ Easy to inspect |

**Verdict:** Outbox Pattern is more robust for production systems where data reliability is critical.

---

## 🚀 Migration Path

### Phase 1: Parallel Run (Testing)

1. Keep existing RemoteSyncService
2. Add OutboxProcessorService alongside
3. Create outbox events but don't rely on them
4. Monitor and compare results
5. Verify no data loss

### Phase 2: Gradual Migration

1. Migrate one event type at a time (start with progressEntry)
2. Monitor for issues
3. Once stable, migrate next type
4. Keep RemoteSyncService as fallback

### Phase 3: Full Cutover

1. Remove RemoteSyncService
2. Remove LocalDataChangePublisher (if only used for sync)
3. Full reliance on Outbox Pattern
4. Monitor metrics closely

---

## 📈 Performance Considerations

### Database Impact

**Writes:**
- 2x writes per data change (data + outbox event)
- SwiftData is optimized for this
- Batch operations minimize overhead

**Reads:**
- Periodic polling (every 2s)
- Efficient indexes on status and createdAt
- FetchDescriptor with limits keeps memory low

**Storage:**
- Events auto-deleted after 7 days
- Completed events are small (few KB each)
- Typical overhead: <1MB per 1000 events

### Memory Impact

- Batch processing limits memory usage
- Max concurrent operations controls peak usage
- Typical: <10MB additional memory

### Network Impact

- No change vs event-based approach
- Same number of API calls
- Retry logic may increase calls if failures occur

---

## 🛡️ Production Checklist

Before deploying to production:

- [ ] SDOutboxEvent added to schema
- [ ] All save use cases create outbox events
- [ ] OutboxProcessor wired up in AppDependencies
- [ ] Processor started on app launch/login
- [ ] Processor stopped on logout (optional)
- [ ] Unit tests for outbox repository
- [ ] Integration tests for end-to-end sync
- [ ] Monitoring/alerting for stale events
- [ ] Cleanup job configured (old events)
- [ ] Retry limits configured appropriately
- [ ] Console logs verified in staging
- [ ] Performance tested with large batches
- [ ] Crash recovery tested (kill app mid-sync)
- [ ] Offline mode tested (airplane mode)
- [ ] Network error handling tested

---

## 🎓 Best Practices

### 1. Transaction Safety
Always create outbox event in same transaction as data:
```swift
modelContext.transaction {
    modelContext.insert(dataEntity)
    modelContext.insert(outboxEvent)
    try modelContext.save()
}
```

### 2. Idempotency
Ensure remote API handles duplicate requests:
- Use entity IDs for deduplication
- Backend should check if entry already exists
- 409 Conflict is OK (not a failure)

### 3. Priority
Use priority for urgent events:
```swift
// High priority (user-initiated)
createEvent(..., priority: 10)

// Normal priority (background sync)
createEvent(..., priority: 0)
```

### 4. Metadata
Store extra context for debugging:
```swift
createEvent(
    ...,
    metadata: [
        "source": "manual_entry",
        "app_version": "1.0.0",
        "device": "iPhone 14"
    ]
)
```

### 5. Monitoring
Set up alerts for:
- Stale events (pending > 5 minutes)
- High failure rate (>10%)
- Large pending queue (>50 events)

---

## 📚 Related Patterns

### Saga Pattern
For multi-step distributed transactions, consider Saga Pattern on top of Outbox.

### Change Data Capture (CDC)
For systems with high write volume, CDC can complement Outbox Pattern.

### Event Sourcing
If you need full event history, Event Sourcing builds on Outbox concepts.

---

## 🔗 References

- **Outbox Pattern:** https://microservices.io/patterns/data/transactional-outbox.html
- **SwiftData:** https://developer.apple.com/documentation/swiftdata
- **ACID Transactions:** https://en.wikipedia.org/wiki/ACID

---

## 📝 Summary

**Key Takeaways:**

1. ✅ **Outbox Pattern = Reliability** - No data loss, even on crashes
2. ✅ **Transaction Safety** - Data + event saved atomically
3. ✅ **Automatic Retry** - Exponential backoff handles transient failures
4. ✅ **Audit Trail** - Full history of sync operations
5. ✅ **Production-Ready** - Battle-tested pattern from distributed systems

**When to Use:**
- ✅ Data reliability is critical
- ✅ Network is unreliable
- ✅ Need audit trail
- ✅ Multiple event types to sync
- ✅ Production app with real users

**When NOT to Use:**
- ❌ Prototype/demo (event-based is simpler)
- ❌ Perfect network (no failures)
- ❌ Single event type (event-based OK)
- ❌ No data criticality (transient OK)

**Recommendation for FitIQ:**
✅ **Use Outbox Pattern** - Health data is critical, network is unreliable, multiple event types, production app.

---

**Status:** ✅ Ready for implementation  
**Last Updated:** 2025-01-31  
**Author:** AI Assistant