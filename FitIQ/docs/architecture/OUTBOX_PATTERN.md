# Outbox Pattern for Reliable Data Synchronization

**Version:** 1.0.0  
**Created:** 2025-01-27  
**Status:** ✅ Active Pattern  
**Architecture Layer:** Infrastructure → Backend API

---

## 🎯 Overview

The **Outbox Pattern** is a reliability pattern that ensures **outbound events requiring remote synchronization** are eventually synced to the backend API, even in the presence of:

- ❌ App crashes
- ❌ Network failures
- ❌ Backend API downtime
- ❌ User closing the app
- ❌ Device being offline

This pattern is **critical** for any outbound event that requires backend persistence (progress tracking, profile updates, user-generated content, etc.).

---

## 🏗️ Architecture

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Action                              │
│              (e.g., Log weight, Save mood)                       │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Use Case (Domain Layer)                       │
│      SaveWeightProgressUseCase / SaveMoodProgressUseCase         │
│                                                                   │
│  Creates: ProgressEntry(syncStatus: .pending)                   │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│            SwiftDataProgressRepository (Infrastructure)          │
│                                                                   │
│  1. Save ProgressEntry to SwiftData (local storage)             │
│  2. ✅ AUTOMATIC: Create SDOutboxEvent(status: .pending)         │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              OutboxProcessorService (Background)                 │
│                                                                   │
│  - Polls for pending events every 30 seconds                    │
│  - Retries failed events with exponential backoff               │
│  - Syncs to backend API                                         │
│  - Marks events as completed or failed                          │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Layer | Responsibility |
|-----------|-------|----------------|
| **ProgressEntry** | Domain | Business entity for tracking data |
| **SDOutboxEvent** | Infrastructure | Persistent event for sync queue |
| **SwiftDataProgressRepository** | Infrastructure | Saves data + creates outbox events |
| **SwiftDataOutboxRepository** | Infrastructure | Manages outbox event lifecycle |
| **OutboxProcessorService** | Infrastructure | Background sync processor |
| **ProgressAPIClient** | Infrastructure | Backend API communication |

---

## 📊 Data Flow

### Step-by-Step Example: Logging Weight

```swift
// 1. User enters weight in BodyMassEntryView
Button("Save") {
    Task { await viewModel.saveWeight() }
}

// 2. ViewModel calls use case
func saveWeight() async {
    try await saveBodyMassUseCase.execute(weightKg: 75.5, date: Date())
}

// 3. SaveBodyMassUseCase delegates to SaveWeightProgressUseCase
func execute(weightKg: Double, date: Date) async throws {
    // Save to HealthKit first
    try await healthRepository.saveQuantitySample(...)
    
    // Save to progress tracking (triggers Outbox Pattern)
    let localID = try await saveWeightProgressUseCase.execute(
        weightKg: weightKg,
        date: date
    )
}

// 4. SaveWeightProgressUseCase creates ProgressEntry
func execute(weightKg: Double, date: Date) async throws -> UUID {
    let progressEntry = ProgressEntry(
        id: UUID(),
        userID: userID,
        type: .weight,
        quantity: weightKg,
        date: date,
        syncStatus: .pending  // ✅ CRITICAL: Mark for sync
    )
    
    // Save to repository - this triggers Outbox Pattern
    return try await progressRepository.save(progressEntry, forUserID: userID)
}

// 5. SwiftDataProgressRepository saves locally AND creates outbox event
func save(progressEntry: ProgressEntry, forUserID: String) async throws -> UUID {
    // 5a. Save to SwiftData
    let sdEntry = SDProgressEntry(from: progressEntry)
    modelContext.insert(sdEntry)
    try modelContext.save()
    
    // 5b. ✅ OUTBOX PATTERN: Automatically create outbox event
    let outboxEvent = try await outboxRepository.createEvent(
        eventType: .progressCreated,
        entityID: progressEntry.id,
        userID: userID,
        isNewRecord: progressEntry.backendID == nil,
        metadata: nil,
        priority: 5
    )
    
    print("✅ Saved locally with Outbox event \(outboxEvent.id)")
    return progressEntry.id
}

// 6. OutboxProcessorService picks up pending event (background)
func processPendingEvents() async {
    let pendingEvents = try await outboxRepository.fetchPendingEvents(...)
    
    for event in pendingEvents {
        try await outboxRepository.markAsProcessing(event.id)
        
        do {
            // Sync to backend API
            try await progressAPIClient.logProgress(...)
            
            // Mark as completed
            try await outboxRepository.markAsCompleted(event.id)
            print("✅ Synced event \(event.id) to backend")
        } catch {
            // Mark as failed, will retry automatically
            try await outboxRepository.markAsFailed(event.id, error: error.localizedDescription)
            print("❌ Failed to sync event \(event.id), will retry")
        }
    }
}
```

---

## 🔄 Event Lifecycle

### Event States

```
┌──────────┐
│ .pending │ ← Event created, waiting to sync
└─────┬────┘
      │
      ▼
┌─────────────┐
│ .processing │ ← Currently syncing to backend
└─────┬───┬───┘
      │   │
      │   └─────────┐
      │             │
      ▼             ▼
┌───────────┐  ┌─────────┐
│ .completed│  │ .failed │ ← Will retry automatically
└───────────┘  └─────┬───┘
                     │
                     └─────► Retry with exponential backoff
                             (up to maxAttempts = 5)
```

### State Transitions

| From | To | Trigger |
|------|-----|---------|
| `.pending` | `.processing` | OutboxProcessorService picks up event |
| `.processing` | `.completed` | Successful backend sync |
| `.processing` | `.failed` | Network error / API error |
| `.failed` | `.processing` | Automatic retry (if attempts < 5) |
| `.failed` | *stays failed* | Max attempts reached (requires manual intervention) |

---

## ⚙️ Configuration

### Retry Strategy

```swift
// SDOutboxEvent.swift
final class SDOutboxEvent {
    var attemptCount: Int = 0
    var maxAttempts: Int = 5
    var retryAfter: Date?
    
    var canRetry: Bool {
        attemptCount < maxAttempts
    }
    
    // Exponential backoff calculation
    func calculateNextRetryDate() -> Date {
        let baseDelay: TimeInterval = 30  // 30 seconds
        let exponentialDelay = baseDelay * pow(2.0, Double(attemptCount))
        let maxDelay: TimeInterval = 3600  // 1 hour max
        let actualDelay = min(exponentialDelay, maxDelay)
        
        return Date().addingTimeInterval(actualDelay)
    }
}
```

### Backoff Schedule

| Attempt | Delay | Total Wait Time |
|---------|-------|-----------------|
| 1 | 30s | 30s |
| 2 | 60s | 1m 30s |
| 3 | 120s (2m) | 3m 30s |
| 4 | 240s (4m) | 7m 30s |
| 5 | 480s (8m) | 15m 30s |

After 5 attempts, the event remains in `.failed` state and requires manual intervention or app restart.

---

## 📝 Implementation Guide

### When to Use Outbox Pattern

#### ✅ ALWAYS Use For:

**Any outbound event requiring remote synchronization:**

- **Progress Tracking**: Steps, heart rate, weight, height, BMI, body fat %
- **Wellness Data**: Mood, sleep, water intake
- **Nutrition Data**: Calories, macros, meal logs
- **User-Generated Content**: Notes, custom entries
- **Profile Updates**: Physical profile changes, user preferences
- **Data Mutations**: Any local change that must be persisted to backend

#### ❌ DON'T Use For:

- **Read-Only Operations**: Fetching data from backend
- **Temporary UI State**: View state, selections, focus
- **Cached Data**: Data that can be refetched
- **Derived/Calculated Values**: Data computed from other sources

### Adding a New Progress Metric

Follow this pattern for any new progress tracking feature:

#### Step 1: Create Use Case

```swift
// Domain/UseCases/SaveCustomMetricProgressUseCase.swift

protocol SaveCustomMetricProgressUseCase {
    func execute(value: Double, date: Date) async throws -> UUID
}

final class SaveCustomMetricProgressUseCaseImpl: SaveCustomMetricProgressUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager) {
        self.progressRepository = progressRepository
        self.authManager = authManager
    }
    
    func execute(value: Double, date: Date = Date()) async throws -> UUID {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw SaveCustomMetricError.userNotAuthenticated
        }
        
        // Create progress entry with .pending status
        let progressEntry = ProgressEntry(
            id: UUID(),
            userID: userID,
            type: .customMetric,  // Add to ProgressMetricType enum
            quantity: value,
            date: date,
            notes: nil,
            createdAt: Date(),
            backendID: nil,
            syncStatus: .pending  // ✅ CRITICAL: Enables Outbox Pattern
        )
        
        // Save locally - Outbox Pattern triggered automatically
        let localID = try await progressRepository.save(
            progressEntry: progressEntry,
            forUserID: userID
        )
        
        return localID
    }
}
```

#### Step 2: That's It!

The Outbox Pattern is **automatically triggered** when you call `progressRepository.save()`. You don't need to:

- ❌ Manually create outbox events
- ❌ Write custom sync logic
- ❌ Handle retries yourself
- ❌ Manage network state
- ❌ Track sync status manually

The repository and OutboxProcessorService handle everything!

---

## 🧪 Testing

### Testing Use Cases with Outbox Pattern

```swift
import XCTest
@testable import FitIQ

final class SaveWeightProgressUseCaseTests: XCTestCase {
    var sut: SaveWeightProgressUseCase!
    var mockRepository: MockProgressRepository!
    var mockAuthManager: MockAuthManager!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockProgressRepository()
        mockAuthManager = MockAuthManager()
        mockAuthManager.currentUserProfileID = UUID()
        sut = SaveWeightProgressUseCaseImpl(
            progressRepository: mockRepository,
            authManager: mockAuthManager
        )
    }
    
    func testExecute_CreatesProgressEntryWithPendingStatus() async throws {
        // Arrange
        let weightKg = 75.5
        let date = Date()
        
        // Act
        let localID = try await sut.execute(weightKg: weightKg, date: date)
        
        // Assert
        XCTAssertEqual(mockRepository.saveCallCount, 1)
        XCTAssertNotNil(localID)
        
        let savedEntry = mockRepository.savedEntries.first
        XCTAssertEqual(savedEntry?.type, .weight)
        XCTAssertEqual(savedEntry?.quantity, weightKg)
        XCTAssertEqual(savedEntry?.syncStatus, .pending)  // ✅ Critical assertion
    }
    
    func testExecute_RepositorySaveTriggersOutboxPattern() async throws {
        // The repository mock should verify that save() is called
        // In real implementation, this triggers outbox event creation
        
        let weightKg = 75.5
        _ = try await sut.execute(weightKg: weightKg, date: Date())
        
        XCTAssertTrue(mockRepository.saveCalled)
        // In integration tests, verify outbox event was created
    }
}
```

### Testing Outbox Processor

```swift
final class OutboxProcessorServiceTests: XCTestCase {
    var sut: OutboxProcessorService!
    var mockOutboxRepository: MockOutboxRepository!
    var mockAPIClient: MockProgressAPIClient!
    
    func testProcessPendingEvents_SuccessfulSync_MarksAsCompleted() async throws {
        // Arrange
        let event = createMockOutboxEvent(status: .pending)
        mockOutboxRepository.pendingEvents = [event]
        
        // Act
        await sut.processPendingEvents()
        
        // Assert
        XCTAssertEqual(mockOutboxRepository.markAsCompletedCallCount, 1)
        XCTAssertEqual(mockAPIClient.logProgressCallCount, 1)
    }
    
    func testProcessPendingEvents_NetworkError_MarksAsFailedWithRetry() async throws {
        // Arrange
        let event = createMockOutboxEvent(status: .pending)
        mockOutboxRepository.pendingEvents = [event]
        mockAPIClient.shouldFail = true
        
        // Act
        await sut.processPendingEvents()
        
        // Assert
        XCTAssertEqual(mockOutboxRepository.markAsFailedCallCount, 1)
        XCTAssertTrue(event.canRetry)
    }
}
```

---

## 🔍 Monitoring & Debugging

### Check Outbox Status

```swift
// Get pending events count
let pendingCount = try await outboxRepository.fetchPendingEvents(
    forUserID: userID,
    limit: nil
).count

print("Pending sync events: \(pendingCount)")

// Get failed events
let failedEvents = try await outboxRepository.fetchEvents(
    withStatus: .failed,
    forUserID: userID,
    limit: nil
)

for event in failedEvents {
    print("Failed event \(event.id): \(event.lastError ?? "Unknown error")")
    print("  Attempts: \(event.attemptCount)/\(event.maxAttempts)")
    print("  Can retry: \(event.canRetry)")
}
```

### Check Progress Entry Sync Status

```swift
let entries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .weight,
    syncStatus: .pending
)

print("Unsynced weight entries: \(entries.count)")

for entry in entries {
    print("Entry \(entry.id): \(entry.quantity)kg - Status: \(entry.syncStatus)")
}
```

### Logs to Monitor

```
✅ SwiftDataProgressRepository: Saved locally with Outbox event {event-id}
🔄 OutboxProcessor: Processing event {event-id} (attempt 1/5)
✅ OutboxProcessor: Successfully synced event {event-id}
❌ OutboxProcessor: Failed to sync event {event-id} - Network error (will retry)
```

---

## ⚠️ Common Pitfalls

### 1. ❌ Bypassing the Repository

```swift
// ❌ WRONG - Directly inserting to SwiftData
let sdEntry = SDProgressEntry(...)
modelContext.insert(sdEntry)
try modelContext.save()
// This bypasses the Outbox Pattern - data won't sync!
```

```swift
// ✅ CORRECT - Use repository
let progressEntry = ProgressEntry(...)
let localID = try await progressRepository.save(progressEntry, forUserID: userID)
// This triggers Outbox Pattern automatically
```

### 2. ❌ Forgetting `.pending` Status

```swift
// ❌ WRONG - No sync status or wrong status
let progressEntry = ProgressEntry(
    id: UUID(),
    userID: userID,
    type: .weight,
    quantity: 75.5,
    date: Date(),
    syncStatus: .synced  // ❌ Wrong! Should be .pending
)
```

```swift
// ✅ CORRECT - Always .pending for new entries
let progressEntry = ProgressEntry(
    id: UUID(),
    userID: userID,
    type: .weight,
    quantity: 75.5,
    date: Date(),
    syncStatus: .pending  // ✅ Correct!
)
```

### 3. ❌ Manual Sync Logic

```swift
// ❌ WRONG - Trying to sync manually
func saveWeight() async {
    let entry = ProgressEntry(...)
    try await progressRepository.save(entry, forUserID: userID)
    
    // ❌ Don't do this - OutboxProcessorService handles it!
    try await progressAPIClient.logProgress(...)
}
```

```swift
// ✅ CORRECT - Trust the Outbox Pattern
func saveWeight() async {
    let entry = ProgressEntry(...)
    try await progressRepository.save(entry, forUserID: userID)
    // Done! Sync happens automatically in background
}
```

### 4. ❌ Not Checking Existing Entries

```swift
// ❌ WRONG - Creating duplicate entries
func execute(weightKg: Double, date: Date) async throws -> UUID {
    let entry = ProgressEntry(...)
    return try await progressRepository.save(entry, forUserID: userID)
    // This might create duplicates!
}
```

```swift
// ✅ CORRECT - Check for existing entries first
func execute(weightKg: Double, date: Date) async throws -> UUID {
    // Check for existing entry on same date
    let existingEntries = try await progressRepository.fetchLocal(...)
    
    if let existing = existingEntries.first(where: { 
        calendar.isDate($0.date, inSameDayAs: date) 
    }) {
        // Update existing entry
        return try await updateEntry(existing, newValue: weightKg)
    }
    
    // Create new entry
    let entry = ProgressEntry(...)
    return try await progressRepository.save(entry, forUserID: userID)
}
```

---

## 🎯 Best Practices

### 1. Always Use ProgressRepositoryProtocol

```swift
// ✅ Correct dependency
private let progressRepository: ProgressRepositoryProtocol
```

### 2. Set `.pending` Status for New Entries

```swift
// ✅ Always .pending for new data
syncStatus: .pending
```

### 3. Let the System Handle Sync

```swift
// ✅ Trust the Outbox Pattern
// Don't add manual sync logic
// Don't check network status
// Don't manage retries yourself
```

### 4. Check for Duplicates

```swift
// ✅ Deduplicate by date/time
let existing = entries.first { 
    calendar.isDate($0.date, inSameDayAs: date) 
}
```

### 5. Provide User Feedback for Sync Status

```swift
// ✅ Show sync indicator in UI
if progressEntry.syncStatus == .pending {
    Image(systemName: "arrow.triangle.2.circlepath")
        .foregroundColor(.orange)
}
```

---

## 📊 Metrics Currently Using Outbox Pattern

| Metric | Use Case | Status |
|--------|----------|--------|
| **Steps** | `SaveStepsProgressUseCase` | ✅ Outbox-enabled |
| **Heart Rate** | `SaveHeartRateProgressUseCase` | ✅ Outbox-enabled |
| **Weight** | `SaveWeightProgressUseCase` | ✅ Outbox-enabled |
| **Height** | `LogHeightProgressUseCase` | ✅ Outbox-enabled |
| **Mood** | `SaveMoodProgressUseCase` | ✅ Outbox-enabled |
| **Body Fat %** | Coming soon | 🔜 Will use Outbox |
| **Sleep Hours** | Coming soon | 🔜 Will use Outbox |
| **Water Intake** | Coming soon | 🔜 Will use Outbox |

All new progress metrics should automatically use the Outbox Pattern by following the standard implementation pattern.

---

## 🔗 Related Documentation

- **Summary Data Loading Pattern**: `docs/architecture/SUMMARY_DATA_LOADING_PATTERN.md`
- **Repository Pattern**: See copilot-instructions.md section 4
- **Use Case Pattern**: See copilot-instructions.md section 6
- **Hexagonal Architecture**: See copilot-instructions.md

---

## 💡 Key Takeaways

1. **Universal Rule**: ALL outbound sync operations MUST use the Outbox Pattern
2. **Automatic**: Outbox Pattern is triggered automatically when using repository `save()` methods
3. **Reliable**: Data survives crashes, network failures, and backend downtime
4. **No Manual Work**: Don't write custom sync logic - trust the pattern
5. **Always `.pending`**: New entries requiring sync must have `syncStatus: .pending`
6. **Local-First**: Save to local storage first, sync in background
7. **Exponential Backoff**: Failed syncs retry automatically with increasing delays
8. **Eventually Consistent**: All outbound events eventually reach the backend

---

**Remember: Trust the Outbox Pattern! ANY outbound event requiring remote sync MUST use this pattern. It handles all the complexity of reliable syncing so you can focus on business logic.**

**Version:** 1.0.0  
**Status:** ✅ Active Pattern  
**Last Updated:** 2025-01-27  
**Applies To:** ALL outbound synchronization operations