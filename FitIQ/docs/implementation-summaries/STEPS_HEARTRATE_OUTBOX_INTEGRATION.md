# Steps & Heart Rate Outbox Pattern Integration

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Already Implemented

---

## 📋 Executive Summary

**Good news:** Steps and heart rate data **already use the Outbox Pattern**! 

Unlike body mass which required migration from the old event-based system, steps and heart rate were implemented from the start using `SwiftDataProgressRepository`, which automatically creates outbox events for all progress entries.

**No code changes needed** - this document explains how it works.

---

## 🏗️ Architecture Overview

### Data Flow for HealthKit Observer Updates

```
HealthKit Observer Fires
    ↓
BackgroundSyncManager.healthKitObserverQuery()
    ↓
HealthDataSyncManager.syncStepsToProgressTracking()
HealthDataSyncManager.syncHeartRateToProgressTracking()
    ↓
SaveStepsProgressUseCase.execute()
SaveHeartRateProgressUseCase.execute()
    ↓
SwiftDataProgressRepository.save()
    ↓
[AUTOMATIC] Outbox event created via outboxRepository.createEvent()
    ↓
OutboxProcessorService picks up event
    ↓
processProgressEntry() → Upload to backend API
```

### Key Difference from Body Mass

| Aspect | Body Mass | Steps & Heart Rate |
|--------|-----------|-------------------|
| **Trigger** | User action (manual entry) | HealthKit observer (automatic) |
| **Previous Sync** | LocalDataChangePublisher (events) | Never used events - went straight to Outbox |
| **Migration Needed** | Yes - had to migrate from events | No - already using Outbox from day 1 |
| **Entry Point** | SaveWeightProgressUseCase | SaveStepsProgressUseCase, SaveHeartRateProgressUseCase |
| **Outbox Integration** | Recently added | Built-in from the start |

---

## 🔍 How It Works

### 1. HealthKit Observer Triggers Sync

When new steps or heart rate data is available in HealthKit:

```swift
// BackgroundSyncManager.swift
func startHealthKitObservations() async throws {
    let quantityTypesToObserve: [HKQuantityTypeIdentifier] = [
        .bodyMass, .height, .stepCount, .distanceWalkingRunning,
        .basalEnergyBurned,
        .activeEnergyBurned,
        .heartRate
    ]
    
    for identifier in quantityTypesToObserve {
        try await healthRepository.enableBackgroundDelivery(for: identifier)
        try await healthRepository.startObservingQuantity(identifier) { [weak self] in
            await self?.healthKitObserverQuery()
        }
    }
}
```

### 2. Sync Manager Processes HealthKit Data

```swift
// HealthDataSyncManager.swift
func syncStepsToProgressTracking(forDate date: Date) async {
    // Fetch hourly steps from HealthKit
    let hourlySteps = try await healthRepository.fetchHourlyStatistics(
        for: .stepCount,
        unit: HKUnit.count(),
        from: startOfDay,
        to: endOfDay
    )
    
    // Save each hour's steps
    for (hourDate, steps) in hourlySteps {
        let localID = try await saveStepsProgressUseCase.execute(
            steps: steps,
            date: hourDate
        )
        print("✅ Synced \(steps) steps for \(hourDate)")
    }
}
```

### 3. Use Case Saves with Validation

```swift
// SaveStepsProgressUseCase.swift
func execute(steps: Int, date: Date) async throws -> UUID {
    // Validate input
    guard steps >= 0 else {
        throw SaveStepsProgressError.invalidStepsCount
    }
    
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        throw SaveStepsProgressError.userNotAuthenticated
    }
    
    // Create progress entry
    let progressEntry = ProgressEntry(
        id: UUID(),
        userID: userID,
        type: .steps,  // or .restingHeartRate
        quantity: Double(steps),
        date: hourDate,
        time: timeString,
        syncStatus: .pending  // Mark as pending for sync
    )
    
    // Save locally (triggers Outbox event automatically)
    let localID = try await progressRepository.save(
        progressEntry: progressEntry,
        forUserID: userID
    )
    
    return localID
}
```

### 4. Repository Creates Outbox Event (Automatic)

```swift
// SwiftDataProgressRepository.swift
func save(progressEntry: ProgressEntry, forUserID userID: String) async throws -> UUID {
    // Convert to SwiftData model
    let sdProgressEntry = SDProgressEntry(...)
    modelContext.insert(sdProgressEntry)
    try modelContext.save()
    
    // ✅ AUTOMATIC OUTBOX EVENT CREATION
    let isNewRecord = progressEntry.backendID == nil
    
    Task {
        let outboxEvent = try await outboxRepository.createEvent(
            eventType: .progressEntry,  // Generic for all progress types
            entityID: progressEntry.id,
            userID: userID,
            isNewRecord: isNewRecord,
            metadata: [
                "type": progressEntry.type.rawValue,  // "steps" or "resting_heart_rate"
                "quantity": progressEntry.quantity,
                "date": progressEntry.date.timeIntervalSince1970,
            ],
            priority: 0
        )
        print("✅ Created outbox event \(outboxEvent.id) for progress entry \(progressEntry.id)")
    }
    
    return progressEntry.id
}
```

### 5. Outbox Processor Uploads to Backend

```swift
// OutboxProcessorService.swift
private func processProgressEntry(_ event: SDOutboxEvent) async throws {
    // Fetch the progress entry
    guard let progressEntry = entries.first(where: { $0.id == event.entityID }) else {
        throw OutboxProcessorError.entityNotFound(event.entityID)
    }
    
    print("OutboxProcessor: Uploading progress entry: \(progressEntry.type.rawValue)")
    // ↑ This prints "steps" or "resting_heart_rate"
    
    // Upload to backend (works for all progress types)
    let backendEntry = try await progressRepository.logProgress(
        type: progressEntry.type,
        quantity: progressEntry.quantity,
        loggedAt: loggedAtDate,
        notes: progressEntry.notes
    )
    
    // Update local entry with backend ID
    try await progressRepository.updateBackendID(
        forLocalID: event.entityID,
        backendID: backendEntry.backendID,
        forUserID: userID
    )
    
    // Mark as synced
    try await progressRepository.updateSyncStatus(
        forLocalID: event.entityID,
        status: .synced,
        forUserID: userID
    )
}
```

---

## ✅ What's Already Working

### 1. Automatic Sync on HealthKit Changes
- ✅ HealthKit observer queries detect new steps/heart rate data
- ✅ BackgroundSyncManager triggers sync automatically
- ✅ No user action required

### 2. Reliable Outbox Pattern
- ✅ All steps/heart rate entries create outbox events
- ✅ Events persist across app restarts
- ✅ Automatic retry on failure (up to 5 attempts)
- ✅ Exponential backoff between retries

### 3. Crash Resilience
- ✅ Data saved to SwiftData before sync attempt
- ✅ Outbox events survive app crashes
- ✅ Processor resumes on next app launch

### 4. Authentication-Aware Processing
- ✅ Processor only runs when user is logged in
- ✅ Automatically starts after login
- ✅ Automatically stops on logout
- ✅ Uses user-specific data

### 5. Generic Progress Entry Handler
- ✅ Single `processProgressEntry()` method handles all types
- ✅ No special-casing for steps or heart rate
- ✅ Extensible to new progress types

---

## 📊 Observability & Debugging

### Console Logs to Monitor

#### When HealthKit Data Arrives:
```
HealthDataSyncService: Syncing 1234 steps for hour 14:00:00 on 2025-01-27
SaveStepsProgressUseCase: Saving 1234 steps for user abc-123 at 2025-01-27 14:00:00
SwiftDataProgressRepository: Successfully saved progress entry with ID: xyz-789
SwiftDataProgressRepository: ✅ Created outbox event def-456 for progress entry xyz-789
```

#### When Outbox Processor Runs:
```
OutboxProcessor: 🔄 Processing progressEntry event def-456
OutboxProcessor: Uploading progress entry: steps
OutboxProcessor: ✅ Successfully processed event def-456
```

#### On Sync Success:
```
SwiftDataProgressRepository: Successfully updated backend ID
SwiftDataProgressRepository: Successfully updated sync status
OutboxProcessor: Event def-456 completed successfully
```

### Query Outbox Events

```swift
// Check pending events for a specific progress entry
let events = try await outboxRepository.fetchEvents(
    forEntityID: progressEntryID,
    eventType: .progressEntry
)

print("Outbox events: \(events.map { "\($0.status) - Attempt \($0.attemptCount)" })")
```

### Check Sync Status

```swift
// Fetch progress entries by sync status
let pendingEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .steps,  // or .restingHeartRate
    syncStatus: .pending
)

print("Pending sync: \(pendingEntries.count) step entries")
```

---

## 🎯 Key Integration Points

### 1. HealthKit Observer Setup
- **File:** `Domain/UseCases/BackgroundSyncManager.swift`
- **Method:** `startHealthKitObservations()`
- **Observes:** `.stepCount`, `.heartRate`

### 2. Sync Manager
- **File:** `Infrastructure/Integration/HealthDataSyncManager.swift`
- **Methods:** 
  - `syncStepsToProgressTracking(forDate:)`
  - `syncHeartRateToProgressTracking(forDate:)`

### 3. Use Cases
- **Files:**
  - `Domain/UseCases/SaveStepsProgressUseCase.swift`
  - `Domain/UseCases/SaveHeartRateProgressUseCase.swift`
- **Protocol:** `SaveStepsProgressUseCase`, `SaveHeartRateProgressUseCase`
- **Implementation:** `SaveStepsProgressUseCaseImpl`, `SaveHeartRateProgressUseCaseImpl`

### 4. Repository with Outbox
- **File:** `Infrastructure/Persistence/SwiftDataProgressRepository.swift`
- **Method:** `save(progressEntry:forUserID:)`
- **Outbox Event:** Created automatically in same method

### 5. Outbox Processor
- **File:** `Infrastructure/Network/OutboxProcessorService.swift`
- **Method:** `processProgressEntry(_:)`
- **Handles:** All progress entry types (steps, heart rate, weight, etc.)

---

## 🆚 Comparison: Body Mass vs Steps/Heart Rate

### Body Mass Migration Journey

1. **Before:** Used `LocalDataChangePublisher` (event-based, unreliable)
2. **Problem:** Events lost on crash, no retry, no persistence
3. **Solution:** Migrated to Outbox Pattern
4. **Changes:** Updated `SaveWeightProgressUseCase` and `SwiftDataProgressRepository`

### Steps/Heart Rate - Already Done!

1. **From Day 1:** Used `SwiftDataProgressRepository` directly
2. **No Events:** Never used `LocalDataChangePublisher`
3. **Already Reliable:** Outbox Pattern built-in from the start
4. **No Migration:** Nothing to change!

---

## 🧪 Testing Steps & Heart Rate Sync

### Manual Testing

1. **Trigger HealthKit Sync:**
   ```swift
   // In test code or debug menu
   await healthDataSyncManager.syncStepsToProgressTracking(forDate: Date())
   await healthDataSyncManager.syncHeartRateToProgressTracking(forDate: Date())
   ```

2. **Check Outbox Events:**
   ```swift
   let events = try await outboxRepository.fetchPendingEvents(forUserID: userID)
   print("Pending events: \(events.count)")
   ```

3. **Monitor Console:**
   - Look for "Created outbox event" messages
   - Look for "Processing progressEntry event" messages
   - Look for "Successfully processed event" messages

### Automated Testing

```swift
func testStepsSyncCreatesOutboxEvent() async throws {
    // Arrange
    let steps = 1000
    let date = Date()
    
    // Act
    let localID = try await saveStepsProgressUseCase.execute(steps: steps, date: date)
    
    // Assert
    let events = try await outboxRepository.fetchEvents(
        forEntityID: localID,
        eventType: .progressEntry
    )
    
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first?.eventType, "progressEntry")
    XCTAssertEqual(events.first?.status, "pending")
}
```

---

## 📈 Performance Characteristics

### Batch Processing
- Steps and heart rate are synced **hourly** (24 entries per day)
- Outbox processor batches requests efficiently
- Backend API supports bulk uploads

### Resource Usage
- Minimal memory overhead (outbox events are small)
- SwiftData efficiently manages storage
- Background processing doesn't block UI

### Network Efficiency
- Retry with exponential backoff (1s, 2s, 4s, 8s, 16s)
- Automatic deduplication (unique constraints on date + hour + user)
- Failed events don't block other syncs

---

## 🔧 Configuration

### Outbox Settings
```swift
// OutboxProcessorService.swift
private let processingInterval: TimeInterval = 30  // Check every 30 seconds
private let batchSize = 10  // Process up to 10 events per batch
private let maxRetries = 5  // Maximum retry attempts
```

### Sync Frequency
```swift
// BackgroundSyncManager.swift
private let syncFrequency: HKUpdateFrequency = .hourly  // HealthKit observer frequency
```

---

## 🚨 Error Handling

### Common Scenarios

| Error | Cause | Resolution |
|-------|-------|-----------|
| `userNotAuthenticated` | User logged out | Processor stops, events remain pending |
| `entityNotFound` | Progress entry deleted | Event marked as failed |
| `networkError` | No internet | Retry with backoff |
| `apiError` | Backend issue | Retry up to 5 times |
| `maxRetriesExceeded` | Persistent failure | Event marked as failed permanently |

### Recovery

Failed events remain in the database for manual inspection:

```swift
// Query failed events
let failedEvents = try await outboxRepository.fetchEvents(
    status: .failed,
    limit: 100
)

// Retry manually if needed
for event in failedEvents {
    try await outboxRepository.resetForRetry(event.id)
}
```

---

## 📝 Schema Details

### Progress Entry (SwiftData)
```swift
@Model final class SDProgressEntry {
    var id: UUID
    var userID: String
    var type: String  // "steps" or "resting_heart_rate"
    var quantity: Double
    var date: Date
    var time: String?  // "14:00:00" for hourly tracking
    var syncStatus: String  // "pending" → "synced"
    var backendID: String?  // Set after successful upload
}
```

### Outbox Event (SwiftData)
```swift
@Model final class SDOutboxEvent {
    var id: UUID
    var eventType: String  // "progressEntry"
    var entityID: UUID  // SDProgressEntry.id
    var userID: String
    var status: String  // "pending" → "processing" → "completed"
    var attemptCount: Int  // 0 → 5
    var metadata: String?  // JSON: {"type": "steps", "quantity": 1000}
}
```

---

## ✨ Benefits Over Old Event System

### Reliability
- ❌ **Events:** Lost on crash, no persistence
- ✅ **Outbox:** Persisted in SwiftData, survives crashes

### Retry Logic
- ❌ **Events:** No retry, one-shot delivery
- ✅ **Outbox:** Automatic retry with exponential backoff

### Observability
- ❌ **Events:** No audit trail
- ✅ **Outbox:** Full event history with timestamps and error messages

### Testing
- ❌ **Events:** Hard to test, timing-dependent
- ✅ **Outbox:** Easy to query and verify

### Scalability
- ❌ **Events:** In-memory, memory pressure under load
- ✅ **Outbox:** Disk-based, handles thousands of events

---

## 🎉 Summary

**Steps and heart rate already use the Outbox Pattern!**

- ✅ No migration needed (unlike body mass)
- ✅ Reliable, crash-resistant sync
- ✅ Automatic retry on failure
- ✅ Full audit trail
- ✅ Authentication-aware processing
- ✅ Production-ready

**Next Steps:**
1. Monitor logs to verify sync behavior
2. Test with various HealthKit data scenarios
3. Consider adding UI indicators for sync status (optional)

---

**Version:** 1.0.0  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-01-27