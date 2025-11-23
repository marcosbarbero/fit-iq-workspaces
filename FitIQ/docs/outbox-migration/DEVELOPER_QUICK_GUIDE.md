# Outbox Pattern - Developer Quick Guide

**Last Updated:** 2025-01-27  
**Status:** ✅ Production Ready  
**Migration:** ✅ Completed

---

## Quick Start

### Using the Outbox Pattern in Your Code

#### 1. Create an Outbox Event (via Repository)

```swift
// In your use case or repository
let outboxEvent = try await outboxRepository.createEvent(
    eventType: .progressEntry,
    entityID: progressEntry.id,
    userID: userID,
    isNewRecord: true,
    metadata: .progressEntry(
        metricType: "weight_kg",
        value: 75.5,
        unit: "kg"
    ),
    priority: 0
)
```

#### 2. Convert Between Domain and Persistence

```swift
// Domain → SwiftData (for persistence)
let sdEvent = domainEvent.toSwiftData()
modelContext.insert(sdEvent)

// SwiftData → Domain (for business logic)
let domainEvent = try sdEvent.toDomain()
```

---

## Available Metadata Types

### Progress Entry
```swift
.progressEntry(
    metricType: "weight_kg",
    value: 75.5,
    unit: "kg"
)
```

### Mood Entry
```swift
.moodEntry(
    valence: 0.8,
    labels: ["happy", "energetic"]
)
```

### Journal Entry
```swift
.journalEntry(
    wordCount: 250,
    linkedMoodID: UUID()
)
```

### Sleep Session
```swift
.sleepSession(
    duration: 28800.0,  // 8 hours in seconds
    quality: 0.85
)
```

### Meal Log
```swift
.mealLog(
    calories: 500.0,
    macros: [
        "protein": 30.0,
        "carbs": 45.0,
        "fat": 15.0
    ]
)
```

### Workout
```swift
.workout(
    type: "strength_training",
    duration: 3600.0  // 1 hour in seconds
)
```

### Goal
```swift
.goal(
    title: "Lose 5kg",
    category: "weight_loss"
)
```

### Generic (Fallback)
```swift
.generic([
    "key1": "value1",
    "key2": "value2"
])
```

---

## Event Types

```swift
public enum OutboxEventType: String, Codable, Sendable {
    case progressEntry       // Health metrics (weight, steps, etc.)
    case physicalAttribute   // Body measurements
    case activitySnapshot    // Daily activity summary
    case moodEntry          // Mood tracking
    case journalEntry       // Journal/diary entries
    case sleepSession       // Sleep data
    case mealLog            // Nutrition tracking
    case workout            // Exercise sessions
    case goal               // User goals
}
```

---

## Event Statuses

```swift
public enum OutboxEventStatus: String, Codable, Sendable {
    case pending      // Waiting to be processed
    case processing   // Currently being synced
    case completed    // Successfully synced
    case failed       // Sync failed (will retry)
}
```

---

## Common Patterns

### 1. Creating Progress Entry with Outbox Event

```swift
func save(progressEntry: ProgressEntry, forUserID userID: String) async throws -> UUID {
    // 1. Save to local storage (SwiftData)
    let sdEntry = SDProgressEntry(...)
    modelContext.insert(sdEntry)
    try modelContext.save()
    
    // 2. Create outbox event (Outbox Pattern)
    let outboxEvent = try await outboxRepository.createEvent(
        eventType: .progressEntry,
        entityID: progressEntry.id,
        userID: userID,
        isNewRecord: progressEntry.backendID == nil,
        metadata: .progressEntry(
            metricType: progressEntry.type.rawValue,
            value: progressEntry.quantity,
            unit: ""
        ),
        priority: 0
    )
    
    // 3. Return local ID
    return progressEntry.id
}
```

### 2. Fetching and Converting Events

```swift
func fetchPendingEvents(forUserID userID: String) async throws -> [OutboxEvent] {
    // 1. Fetch from SwiftData
    let descriptor = FetchDescriptor<SDOutboxEvent>(
        predicate: #Predicate { $0.status == "pending" && $0.userID == userID }
    )
    let sdEvents = try modelContext.fetch(descriptor)
    
    // 2. Convert to domain models
    return try sdEvents.map { try $0.toDomain() }
}
```

### 3. Updating Event Status

```swift
func markAsCompleted(_ eventID: UUID) async throws {
    // 1. Fetch event
    guard let sdEvent = try fetchSDEvent(byID: eventID) else {
        throw OutboxRepositoryError.eventNotFound(eventID)
    }
    
    // 2. Update status
    sdEvent.status = OutboxEventStatus.completed.rawValue
    sdEvent.completedAt = Date()
    
    // 3. Save
    try modelContext.save()
}
```

---

## Error Handling

### Adapter Errors

```swift
enum AdapterError: Error {
    case invalidEventType(String)
    case invalidStatus(String)
    case metadataDecodingFailed(String)
}
```

**Example:**
```swift
do {
    let domainEvent = try sdEvent.toDomain()
} catch AdapterError.invalidEventType(let type) {
    print("Unknown event type: \(type)")
} catch AdapterError.invalidStatus(let status) {
    print("Unknown status: \(status)")
} catch {
    print("Conversion failed: \(error)")
}
```

---

## Best Practices

### ✅ DO

1. **Always use type-safe metadata enums**
   ```swift
   ✅ metadata: .progressEntry(metricType: "weight_kg", value: 75.5, unit: "kg")
   ❌ metadata: ["type": "weight", "value": 75.5]
   ```

2. **Handle conversion errors explicitly**
   ```swift
   ✅ let events = try sdEvents.map { try $0.toDomain() }
   ❌ let events = sdEvents.map { $0.toDomain() }  // Won't compile
   ```

3. **Create outbox events transactionally**
   ```swift
   ✅ Save entity + Create outbox event in same transaction
   ❌ Save entity first, create outbox event later (could fail)
   ```

4. **Use convenience methods**
   ```swift
   ✅ let domainEvent = try sdEvent.toDomain()
   ✅ let sdEvent = domainEvent.toSwiftData()
   ```

### ❌ DON'T

1. **Don't create SwiftData models directly**
   ```swift
   ❌ let sdEvent = SDOutboxEvent(...)  // Hard to maintain
   ✅ let sdEvent = domainEvent.toSwiftData()  // Use adapter
   ```

2. **Don't use string literals for types/statuses**
   ```swift
   ❌ sdEvent.status = "completed"
   ✅ sdEvent.status = OutboxEventStatus.completed.rawValue
   ```

3. **Don't ignore conversion errors**
   ```swift
   ❌ try? sdEvent.toDomain()  // Swallows errors
   ✅ try sdEvent.toDomain()   // Handle properly
   ```

4. **Don't manually serialize metadata**
   ```swift
   ❌ sdEvent.metadata = "{\"type\":\"weight\"}"  // Error-prone
   ✅ Use .progressEntry() enum case  // Type-safe
   ```

---

## Testing

### Unit Test Example

```swift
class OutboxEventAdapterTests: XCTestCase {
    func testToSwiftData_ValidEvent_CreatesSDOutboxEvent() throws {
        // Given
        let domainEvent = OutboxEvent(
            id: UUID(),
            eventType: .progressEntry,
            entityID: UUID(),
            userID: "user123",
            status: .pending,
            createdAt: Date(),
            lastAttemptAt: nil,
            attemptCount: 0,
            maxAttempts: 5,
            errorMessage: nil,
            completedAt: nil,
            metadata: .progressEntry(metricType: "weight_kg", value: 75.5, unit: "kg"),
            priority: 0,
            isNewRecord: true
        )
        
        // When
        let sdEvent = OutboxEventAdapter.toSwiftData(domainEvent)
        
        // Then
        XCTAssertEqual(sdEvent.id, domainEvent.id)
        XCTAssertEqual(sdEvent.eventType, "progressEntry")
        XCTAssertEqual(sdEvent.status, "pending")
    }
    
    func testToDomain_InvalidEventType_ThrowsError() {
        // Given
        let sdEvent = SDOutboxEvent(
            id: UUID(),
            eventType: "invalid_type",
            entityID: UUID(),
            userID: "user123"
        )
        
        // When/Then
        XCTAssertThrowsError(try sdEvent.toDomain()) { error in
            XCTAssertTrue(error is AdapterError)
        }
    }
}
```

---

## Debugging

### Check Event Status

```swift
// In Xcode debugger or logging
print("Event ID: \(sdEvent.id)")
print("Type: \(sdEvent.eventType)")
print("Status: \(sdEvent.status)")
print("Attempts: \(sdEvent.attemptCount)/\(sdEvent.maxAttempts)")
print("Error: \(sdEvent.errorMessage ?? "none")")
```

### Monitor Outbox Health

```swift
func getOutboxStats(forUserID userID: String) async throws -> OutboxStats {
    let pending = try await outboxRepository.fetchEvents(
        withStatus: .pending,
        forUserID: userID,
        limit: nil
    ).count
    
    let failed = try await outboxRepository.fetchEvents(
        withStatus: .failed,
        forUserID: userID,
        limit: nil
    ).count
    
    return OutboxStats(pending: pending, failed: failed)
}
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│           Use Case (Domain)                 │
│  • Creates domain OutboxEvent               │
└──────────────────┬──────────────────────────┘
                   │ calls
                   ↓
┌─────────────────────────────────────────────┐
│      OutboxRepositoryProtocol (Port)        │
│  • createEvent()                            │
│  • fetchPendingEvents()                     │
│  • markAsCompleted()                        │
└──────────────────┬──────────────────────────┘
                   ↑ implemented by
                   │
┌─────────────────────────────────────────────┐
│    SwiftDataOutboxRepository (Adapter)      │
│  • Uses OutboxEventAdapter                  │
│  • Converts domain ↔ persistence            │
└──────────────────┬──────────────────────────┘
                   │ uses
                   ↓
┌─────────────────────────────────────────────┐
│       OutboxEventAdapter (Converter)        │
│  • toSwiftData() - Domain → SwiftData       │
│  • toDomain() - SwiftData → Domain          │
└──────────────────┬──────────────────────────┘
                   │ converts
                   ↓
┌─────────────────────────────────────────────┐
│      SDOutboxEvent (@Model - SwiftData)     │
│  • Persisted in database                    │
│  • Used only in Infrastructure layer        │
└─────────────────────────────────────────────┘
```

---

## FAQs

### Q: When should I create an outbox event?

**A:** Whenever you need to sync data to the backend. Examples:
- Saving progress entries (weight, steps, heart rate)
- Creating mood/journal entries
- Logging meals or workouts
- Updating user profile

### Q: What if I don't have metadata?

**A:** Use `nil`:
```swift
let event = try await outboxRepository.createEvent(
    eventType: .progressEntry,
    entityID: uuid,
    userID: userID,
    isNewRecord: true,
    metadata: nil,  // ✅ OK
    priority: 0
)
```

### Q: How do I handle batch operations?

**A:** Use batch conversion methods:
```swift
// SwiftData → Domain (batch)
let domainEvents = OutboxEventAdapter.toDomainArray(sdEvents)

// Domain → SwiftData (batch)
let sdEvents = OutboxEventAdapter.toSwiftDataArray(domainEvents)
```

### Q: What happens if conversion fails?

**A:** `AdapterError` is thrown with details:
```swift
do {
    let domainEvent = try sdEvent.toDomain()
} catch AdapterError.invalidEventType(let type) {
    // Handle unknown event type
} catch AdapterError.invalidStatus(let status) {
    // Handle unknown status
}
```

### Q: Can I update an existing event?

**A:** Yes, use the adapter's update method:
```swift
// Update in-place
OutboxEventAdapter.updateSwiftData(sdEvent, from: updatedDomainEvent)
try modelContext.save()
```

---

## Additional Resources

- [Migration Completion Report](./MIGRATION_COMPLETION_REPORT.md) - Full migration details
- [FitIQCore Documentation](../../FitIQCore/README.md) - Shared library docs
- [Outbox Pattern RFC](../architecture/OUTBOX_PATTERN.md) - Design decisions
- [Hexagonal Architecture Guide](../architecture/HEXAGONAL_ARCHITECTURE.md) - Architecture overview

---

**Questions?** Contact the architecture team or create a GitHub discussion.

**Found a bug?** File an issue with the `outbox-pattern` label.

---

**END OF GUIDE**