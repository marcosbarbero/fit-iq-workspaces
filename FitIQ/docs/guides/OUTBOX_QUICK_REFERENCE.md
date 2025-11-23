# Outbox Pattern Quick Reference

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Quick lookup for Outbox Pattern implementation

---

## 🎯 What Is It?

The Outbox Pattern ensures **reliable, crash-resistant sync** of health data to the backend by persisting sync events in SwiftData before attempting upload.

**Key Benefit:** Data survives crashes, retries automatically, guarantees delivery.

---

## 📊 Metrics Using Outbox Pattern

| Metric | Event Type | Use Case | Trigger |
|--------|-----------|----------|---------|
| Body Mass | `progressEntry` | `SaveWeightProgressUseCase` | User action |
| Steps | `progressEntry` | `SaveStepsProgressUseCase` | HealthKit observer |
| Heart Rate | `progressEntry` | `SaveHeartRateProgressUseCase` | HealthKit observer |
| Height | `progressEntry` | `LogHeightProgressUseCase` | User action |
| Mood | `progressEntry` | `SaveMoodProgressUseCase` | User action |

**Status:** ✅ All metrics fully implemented

---

## 🔄 How It Works (30 Second Version)

```
1. User enters data OR HealthKit fires observer
   ↓
2. UseCase saves to SwiftData (SDProgressEntry)
   ↓
3. Repository creates Outbox Event (SDOutboxEvent)
   ↓
4. OutboxProcessorService picks up event (every 30s)
   ↓
5. Upload to backend API
   ↓
6. Mark as completed ✅
```

**If crash happens:** Event stays in database, resumes on next app launch.

---

## 📁 Key Files

### Domain Layer
- `Domain/Entities/Progress/ProgressEntry.swift` - Domain model
- `Domain/Entities/Outbox/OutboxEventTypes.swift` - Event types enum
- `Domain/UseCases/Save*ProgressUseCase.swift` - Entry points

### Infrastructure Layer
- `Infrastructure/Persistence/SwiftDataProgressRepository.swift` - **Creates outbox events here (line 63)**
- `Infrastructure/Persistence/SwiftDataOutboxRepository.swift` - Outbox event persistence
- `Infrastructure/Network/OutboxProcessorService.swift` - **Processes events here (line 240)**

### Configuration
- `Infrastructure/Configuration/AppDependencies.swift` - Dependency injection

---

## 🔍 Key Code Snippets

### Creating Outbox Event (Automatic)

```swift
// SwiftDataProgressRepository.save() - line 63
Task {
    let outboxEvent = try await outboxRepository.createEvent(
        eventType: .progressEntry,
        entityID: progressEntry.id,
        userID: userID,
        isNewRecord: progressEntry.backendID == nil,
        metadata: [
            "type": progressEntry.type.rawValue,
            "quantity": progressEntry.quantity,
            "date": progressEntry.date.timeIntervalSince1970,
        ],
        priority: 0
    )
}
```

### Processing Event

```swift
// OutboxProcessorService.processProgressEntry() - line 240
private func processProgressEntry(_ event: SDOutboxEvent) async throws {
    // 1. Fetch progress entry from local DB
    // 2. Upload to backend API
    // 3. Update local entry with backendID
    // 4. Mark event as completed
}
```

### Query Pending Events

```swift
let events = try await outboxRepository.fetchPendingEvents(forUserID: userID)
print("Pending: \(events.count)")
```

---

## 📊 Event Lifecycle

```
pending → processing → completed ✅
   ↓
  (retry on failure)
   ↓
  failed ❌ (after 5 attempts)
```

### Status Values
- `pending` - Waiting to be processed
- `processing` - Currently uploading
- `completed` - Successfully synced
- `failed` - Exceeded max retries (5)

---

## ⚙️ Configuration

### Processor Settings
```swift
processingInterval = 30 seconds  // Poll frequency
batchSize = 10                   // Events per batch
maxRetries = 5                   // Max retry attempts
```

### Retry Backoff
```
Attempt 1: 1 second
Attempt 2: 2 seconds
Attempt 3: 4 seconds
Attempt 4: 8 seconds
Attempt 5: 16 seconds
```

### Processor Lifecycle
- **Starts:** After user login
- **Stops:** On user logout
- **Runs:** Every 30 seconds while user logged in

---

## 🔍 Debugging

### Check Logs

**Event created:**
```
✅ "Created outbox event [UUID] for progress entry [UUID]"
```

**Event processing:**
```
🔄 "Processing progressEntry event [UUID]"
📤 "Uploading progress entry: steps"
✅ "Successfully processed event [UUID]"
```

**Event failed:**
```
❌ "Failed to process event [UUID]: [error]"
⚠️  "Event [UUID] attempt 3/5"
```

### Query Database

```swift
// Pending events
let pending = try await outboxRepository.fetchEvents(
    status: .pending,
    limit: 100
)

// Failed events
let failed = try await outboxRepository.fetchEvents(
    status: .failed,
    limit: 100
)

// Events for specific entry
let events = try await outboxRepository.fetchEvents(
    forEntityID: progressEntryID,
    eventType: .progressEntry
)
```

### Check Sync Status

```swift
// Pending progress entries
let pendingEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .steps,
    syncStatus: .pending
)

// Synced entries
let syncedEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .steps,
    syncStatus: .synced
)
```

---

## 🚨 Common Issues & Fixes

### Issue: Events Not Processing

**Check:**
- User logged in? (`authManager.currentUserProfileID` not nil)
- Processor running? (look for "Starting processor" log)
- Network available?

**Fix:**
```swift
// Manually trigger processor
await outboxProcessorService.processPendingEvents()
```

### Issue: Events Stuck Pending

**Check:**
- Backend API accessible?
- API authentication working?
- Event error messages?

**Fix:**
```swift
// Check error message
let events = try await outboxRepository.fetchEvents(status: .pending)
print("Error: \(events.first?.errorMessage ?? "none")")
```

### Issue: Duplicate Entries

**Check:**
- Unique constraints in SwiftData schema
- Repository deduplication logic

**Fix:**
- Review unique constraint on (userID + type + date + time)

### Issue: High Retry Rate

**Check:**
- Network stability
- Backend API health
- Error patterns in logs

**Fix:**
- Increase retry delay
- Check backend monitoring
- Add circuit breaker if needed

---

## 🧪 Testing

### Unit Test Template

```swift
func testSaveProgressCreatesOutboxEvent() async throws {
    // Arrange
    let steps = 1000
    
    // Act
    let localID = try await saveStepsProgressUseCase.execute(
        steps: steps,
        date: Date()
    )
    
    // Assert
    let events = try await outboxRepository.fetchEvents(
        forEntityID: localID
    )
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first?.eventType, "progressEntry")
}
```

### Manual Test Flow

1. Add steps in Apple Health
2. Wait for HealthKit observer (~1-5 min)
3. Check console for "Created outbox event"
4. Wait 30 seconds for processor
5. Verify "Successfully processed event"
6. Query backend API to confirm data

---

## 📈 Monitoring

### Key Metrics

```swift
// Pending count (should be low)
let pendingCount = try await outboxRepository.fetchPendingEvents(
    forUserID: userID
).count

// Failed count (should be 0)
let failedCount = try await outboxRepository.fetchEvents(
    status: .failed
).count

// Average processing time
let avgTime = calculateAverageTime(events: completedEvents)
```

### Health Check

```swift
// Alert if events stuck > 5 minutes
let stuckEvents = try await outboxRepository.fetchEvents(
    status: .pending,
    olderThan: Date().addingTimeInterval(-300)
)

if !stuckEvents.isEmpty {
    print("⚠️ \(stuckEvents.count) events stuck")
}
```

---

## 🔧 Recovery Commands

### Retry Failed Event
```swift
try await outboxRepository.resetForRetry(eventID)
```

### Delete Old Failed Events
```swift
let oldEvents = try await outboxRepository.fetchEvents(
    status: .failed,
    olderThan: Date().addingTimeInterval(-604800)  // 7 days
)

for event in oldEvents {
    try await outboxRepository.deleteEvent(event.id)
}
```

### Force Sync All Pending
```swift
await outboxProcessorService.processPendingEvents()
```

---

## 📚 Full Documentation

- **`BODY_MASS_OUTBOX_INTEGRATION.md`** - Body mass migration guide
- **`STEPS_HEARTRATE_OUTBOX_INTEGRATION.md`** - Steps/heart rate architecture
- **`STEPS_HEARTRATE_VERIFICATION_CHECKLIST.md`** - Testing checklist
- **`OUTBOX_PATTERN_COMPLETE_SUMMARY.md`** - Complete overview
- **`OUTBOX_LOGIN_INTEGRATION.md`** - Processor lifecycle
- **`CLOUDKIT_SWIFTDATA_REQUIREMENTS.md`** - Schema guidelines

---

## ✅ Quick Verification

Run this to verify everything works:

```swift
// 1. Save test entry
let localID = try await saveStepsProgressUseCase.execute(
    steps: 5000,
    date: Date()
)
print("Saved: \(localID)")

// 2. Check outbox event created
let events = try await outboxRepository.fetchEvents(
    forEntityID: localID
)
print("Events: \(events.count) - Status: \(events.first?.status ?? "none")")

// 3. Wait 35 seconds for processor
try await Task.sleep(for: .seconds(35))

// 4. Verify synced
let entry = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .steps,
    syncStatus: .synced
).first { $0.id == localID }

print("Synced: \(entry?.syncStatus == .synced ? "✅" : "❌")")
print("Backend ID: \(entry?.backendID ?? "nil")")
```

**Expected Output:**
```
Saved: [UUID]
Events: 1 - Status: pending
✅ Created outbox event [UUID]
🔄 Processing progressEntry event [UUID]
✅ Successfully processed event [UUID]
Synced: ✅
Backend ID: [backend-uuid]
```

---

## 🎯 Remember

- ✅ Outbox events are **automatic** (created in repository)
- ✅ Processor runs **only when logged in**
- ✅ Events **survive crashes** (persisted in SwiftData)
- ✅ Retries are **automatic** (up to 5 attempts)
- ✅ All progress types use **same handler** (generic)

---

**Version:** 1.0.0  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-01-27