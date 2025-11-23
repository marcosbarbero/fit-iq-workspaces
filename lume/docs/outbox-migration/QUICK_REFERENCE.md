# Lume Outbox Pattern - Quick Reference

**Date:** 2025-01-27  
**Status:** ✅ Active  
**Version:** FitIQCore 1.0.0

---

## 🚀 Quick Start

### Creating Outbox Events

```swift
// Import FitIQCore types (re-exported via Lume's OutboxRepositoryProtocol.swift)
import FitIQCore

// In your repository:
_ = try await outboxRepository.createEvent(
    eventType: .moodEntry,              // Type-safe enum
    entityID: entry.id,                 // UUID of entity
    userID: userID,                     // String (UUID.uuidString)
    isNewRecord: true,                  // true = create, false = update
    metadata: .moodEntry(               // Type-safe metadata
        valence: entry.valence,
        labels: entry.labels
    ),
    priority: 5                         // Higher = process first (0-10)
)
```

---

## 📋 Event Types

### Available Types

```swift
public enum OutboxEventType: String, Codable, Sendable {
    case moodEntry          // Mood tracking
    case journalEntry       // Journal entries
    case goal               // Goals and milestones
    case progressEntry      // Progress tracking (weight, steps, etc.)
    case physicalAttribute  // Height, weight, etc.
    case activitySnapshot   // Activity data
    case sleepSession       // Sleep tracking
    case mealLog            // Nutrition logging
    case workout            // Workout sessions
}
```

### When to Use Each Type

| Type | Use Case | Priority |
|------|----------|----------|
| `moodEntry` | Mood log created/updated/deleted | 5 (normal), 10 (delete) |
| `journalEntry` | Journal entry created/updated/deleted | 5 (normal), 10 (delete) |
| `goal` | Goal created/updated/progress/status | 5 |
| `progressEntry` | Steps, heart rate, weight, etc. | 5 |
| `sleepSession` | Sleep data sync | 5 |
| `mealLog` | Meal/food logging | 5 |
| `workout` | Workout sessions | 5 |

---

## 🏷️ Metadata Types

### Type-Safe Metadata Enum

```swift
public enum OutboxMetadata: Codable, Sendable, Equatable {
    case progressEntry(metricType: String, value: Double, unit: String)
    case moodEntry(valence: Double, labels: [String])
    case journalEntry(wordCount: Int, linkedMoodID: UUID?)
    case sleepSession(duration: TimeInterval, quality: Double?)
    case mealLog(calories: Double, macros: [String: Double])
    case workout(type: String, duration: TimeInterval)
    case goal(title: String, category: String)
    case generic([String: String])
}
```

### Metadata Examples

**Mood Entry:**
```swift
let metadata = OutboxMetadata.moodEntry(
    valence: 0.7,
    labels: ["happy", "energetic"]
)
```

**Journal Entry:**
```swift
let wordCount = entry.content.split(separator: " ").count
let metadata = OutboxMetadata.journalEntry(
    wordCount: wordCount,
    linkedMoodID: entry.linkedMoodId  // Optional
)
```

**Goal:**
```swift
let metadata = OutboxMetadata.goal(
    title: "Run 5K",
    category: "fitness"
)
```

**Generic (for custom data):**
```swift
let metadata = OutboxMetadata.generic([
    "operation": "delete",
    "backendId": backendId ?? "none",
    "reason": "user_requested"
])
```

---

## 🎯 Priority Levels

| Priority | Use Case | Processing Order |
|----------|----------|------------------|
| **10** | Delete operations | First |
| **8-9** | Critical updates | High priority |
| **5** | Normal operations | Standard |
| **1-4** | Low priority / bulk | Background |
| **0** | Lowest priority | Last |

**Example:**
```swift
// Normal create/update
priority: 5

// Delete operation (higher priority)
priority: 10
```

---

## 🔄 Event Statuses

```swift
public enum OutboxEventStatus: String, Codable, Sendable {
    case pending      // Waiting to be processed
    case processing   // Currently being synced
    case completed    // Successfully synced
    case failed       // Failed (will retry)
}
```

### Status Flow

```
pending → processing → completed
   ↓
failed → pending (retry)
```

---

## 📦 Repository Examples

### MoodRepository

```swift
// Save mood entry
func save(_ entry: MoodEntry) async throws {
    // 1. Save to SwiftData
    modelContext.insert(sdEntry)
    try modelContext.save()
    
    // 2. Create outbox event
    if AppMode.useBackend {
        let metadata = OutboxMetadata.moodEntry(
            valence: entry.valence,
            labels: entry.labels
        )
        
        _ = try await outboxRepository.createEvent(
            eventType: .moodEntry,
            entityID: entry.id,
            userID: entry.userId.uuidString,
            isNewRecord: !isUpdate,
            metadata: metadata,
            priority: 5
        )
    }
}
```

### GoalRepository

```swift
// Create goal
func create(title: String, description: String, category: GoalCategory) async throws -> Goal {
    // 1. Create goal
    let goal = Goal(...)
    
    // 2. Save to SwiftData
    modelContext.insert(toSwiftData(goal))
    try modelContext.save()
    
    // 3. Create outbox event
    guard let userID = try? await currentUserID() else {
        throw RepositoryError.notAuthenticated
    }
    
    let metadata = OutboxMetadata.goal(
        title: title,
        category: category.rawValue
    )
    
    _ = try await outboxRepository.createEvent(
        eventType: .goal,
        entityID: goal.id,
        userID: userID,
        isNewRecord: true,
        metadata: metadata,
        priority: 5
    )
    
    return goal
}
```

### JournalRepository

```swift
// Create journal entry
private func createOutboxEvent(for entry: JournalEntry, action: String) async throws {
    guard let userId = try? getCurrentUserId() else {
        throw RepositoryError.notAuthenticated
    }
    
    let isNewRecord = action == "create"
    let wordCount = entry.content.split(separator: " ").count
    
    let metadata = OutboxMetadata.journalEntry(
        wordCount: wordCount,
        linkedMoodID: entry.linkedMoodId
    )
    
    try await outboxRepository.createEvent(
        eventType: .journalEntry,
        entityID: entry.id,
        userID: userId,
        isNewRecord: isNewRecord,
        metadata: metadata,
        priority: 5
    )
}
```

---

## 🛠️ Common Patterns

### Pattern 1: Create or Update

```swift
// Determine if update or create
let isUpdate = existingEntry != nil

// Save to SwiftData
if let existing = existingEntry {
    existing.update(from: newEntry)
} else {
    modelContext.insert(newEntry)
}
try modelContext.save()

// Create outbox event
_ = try await outboxRepository.createEvent(
    eventType: .moodEntry,
    entityID: entry.id,
    userID: userID,
    isNewRecord: !isUpdate,  // Semantic flag
    metadata: metadata,
    priority: 5
)
```

### Pattern 2: Delete with Metadata

```swift
// Delete from SwiftData
modelContext.delete(entry)
try modelContext.save()

// Create deletion outbox event
let metadata = OutboxMetadata.generic([
    "operation": "delete",
    "backendId": entry.backendId ?? "none"
])

_ = try await outboxRepository.createEvent(
    eventType: .moodEntry,
    entityID: entry.id,
    userID: userID,
    isNewRecord: false,
    metadata: metadata,
    priority: 10  // Higher priority for deletes
)
```

### Pattern 3: Conditional Outbox (AppMode)

```swift
// Save to SwiftData
modelContext.insert(entry)
try modelContext.save()

// Only create outbox event if using backend
if AppMode.useBackend {
    _ = try await outboxRepository.createEvent(
        eventType: .moodEntry,
        entityID: entry.id,
        userID: userID,
        isNewRecord: true,
        metadata: metadata,
        priority: 5
    )
    print("📦 Created outbox event")
} else {
    print("🔵 Skipping outbox (AppMode: \(AppMode.current.displayName))")
}
```

---

## 🧪 Testing

### Verify Event Creation

```swift
// After creating entity, check outbox
let events = try await outboxRepository.fetchPendingEvents(
    forUserID: userID,
    limit: nil
)

XCTAssertEqual(events.count, 1)
XCTAssertEqual(events.first?.eventType, .moodEntry)
XCTAssertEqual(events.first?.entityID, moodEntry.id)
XCTAssertEqual(events.first?.isNewRecord, true)
```

### Mock Repository for Testing

```swift
final class MockOutboxRepository: OutboxRepositoryProtocol {
    var createdEvents: [OutboxEvent] = []
    
    func createEvent(
        eventType: OutboxEventType,
        entityID: UUID,
        userID: String,
        isNewRecord: Bool,
        metadata: OutboxMetadata?,
        priority: Int
    ) async throws -> OutboxEvent {
        let event = OutboxEvent(
            id: UUID(),
            eventType: eventType,
            entityID: entityID,
            userID: userID,
            // ... other fields
        )
        createdEvents.append(event)
        return event
    }
    
    // ... implement other protocol methods
}
```

---

## 🚨 Common Mistakes

### ❌ Don't: Use string literals

```swift
// ❌ WRONG
try await outboxRepository.createEvent(
    type: "mood.created",  // String literal
    payload: Data(...)     // Binary blob
)
```

### ✅ Do: Use type-safe enums

```swift
// ✅ CORRECT
try await outboxRepository.createEvent(
    eventType: .moodEntry,       // Enum
    entityID: entry.id,
    userID: userID,
    isNewRecord: true,
    metadata: .moodEntry(...),   // Type-safe metadata
    priority: 5
)
```

### ❌ Don't: Forget user ID

```swift
// ❌ WRONG - Missing user ID
_ = try await outboxRepository.createEvent(
    eventType: .moodEntry,
    entityID: entry.id,
    userID: "",  // Empty!
    isNewRecord: true,
    metadata: metadata,
    priority: 5
)
```

### ✅ Do: Always provide user ID

```swift
// ✅ CORRECT
guard let userID = try? await currentUserID() else {
    throw RepositoryError.notAuthenticated
}

_ = try await outboxRepository.createEvent(
    eventType: .moodEntry,
    entityID: entry.id,
    userID: userID,  // Valid user ID
    isNewRecord: true,
    metadata: metadata,
    priority: 5
)
```

### ❌ Don't: Ignore errors

```swift
// ❌ WRONG - Swallowing errors
try? await outboxRepository.createEvent(...)
```

### ✅ Do: Handle errors properly

```swift
// ✅ CORRECT
do {
    _ = try await outboxRepository.createEvent(...)
    print("✅ Created outbox event")
} catch {
    print("⚠️ Failed to create outbox event: \(error)")
    // Don't fail the entire operation - outbox will retry
}
```

---

## 📊 Monitoring & Debugging

### Console Logs

Look for these log patterns:

```
📦 [OutboxRepository] Creating event - Type: [Mood Entry] | EntityID: ... | UserID: ...
✅ [OutboxRepository] Event created - EventID: ... | Type: [Mood Entry] | Status: pending
```

### Get Statistics

```swift
let stats = try await outboxRepository.getStatistics(forUserID: userID)

print("Total events: \(stats.totalEvents)")
print("Pending: \(stats.pendingCount)")
print("Failed: \(stats.failedCount)")
print("Stale: \(stats.staleCount)")
```

### Check Stale Events

```swift
let staleEvents = try await outboxRepository.getStaleEvents(forUserID: userID)

if !staleEvents.isEmpty {
    print("⚠️ Found \(staleEvents.count) stale events (pending > 1 hour)")
}
```

---

## 🔗 Related Documentation

- **Full Migration Report:** [MIGRATION_COMPLETE.md](./MIGRATION_COMPLETE.md)
- **Setup Instructions:** [SETUP_INSTRUCTIONS.md](./SETUP_INSTRUCTIONS.md)
- **FitIQCore Documentation:** [../../FitIQCore/README.md](../../FitIQCore/README.md)
- **FitIQ Outbox Docs:** [../../FitIQ/docs/outbox-migration/](../../FitIQ/docs/outbox-migration/)

---

## 💡 Pro Tips

1. **Use Higher Priority for Deletes** - Ensures deletions sync before creates/updates
2. **Keep Metadata Lightweight** - Don't store large payloads (use entity ID to fetch)
3. **Test AppMode Branches** - Verify both backend and local-only modes
4. **Monitor Stale Events** - Set up alerts if stale count exceeds threshold
5. **Use Generic Metadata Sparingly** - Prefer typed cases for better safety

---

**Last Updated:** 2025-01-27  
**Status:** ✅ Current  
**Questions?** Check [MIGRATION_COMPLETE.md](./MIGRATION_COMPLETE.md) or ask the team.

---

**END OF QUICK REFERENCE**