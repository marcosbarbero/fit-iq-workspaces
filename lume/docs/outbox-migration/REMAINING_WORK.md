# Lume Outbox Migration - Remaining Work

**Date:** 2025-01-27  
**Status:** 🔄 In Progress - Services Need Migration  
**Priority:** 🔴 Critical - Blocking Production Deployment

---

## 📊 Current Status

### ✅ Complete (Code Migration)
- Schema migration (V6 → V7)
- Adapter pattern implementation
- Repository migrations (3 repositories)
- SwiftDataOutboxRepository (FitIQCore protocol)
- Type-safe event creation
- Comprehensive documentation

### 🚨 Blocking Issues (37 Errors)

**Files with Errors:**
1. **OutboxProcessorService.swift** - 35 errors (needs complete migration)
2. **MoodSyncService.swift** - 1 error (API update needed)
3. **SwiftDataOutboxRepository.swift** - 1 error (fixed, needs verification)

---

## 🔥 Critical: OutboxProcessorService Migration

**File:** `lume/Services/Outbox/OutboxProcessorService.swift`  
**Errors:** 35  
**Priority:** 🔴 Critical  
**Estimated Time:** 3-4 hours

### Issue Categories

#### 1. Old API Methods (8 errors)

**Problem:** Using old method names that don't exist in new protocol

| Old Method | New Method | Lines |
|------------|-----------|-------|
| `outboxRepository.pendingEvents()` | `outboxRepository.fetchPendingEvents(forUserID:limit:)` | 183, 245 |
| `outboxRepository.markCompleted(event)` | `outboxRepository.markAsCompleted(event.id)` | 201, 235 |
| `outboxRepository.markFailed(event, error)` | `outboxRepository.markAsFailed(event.id, error: String)` | 228 |

**Fix Example:**
```swift
// Before:
let events = try await outboxRepository.pendingEvents()
try await outboxRepository.markCompleted(event)

// After:
let events = try await outboxRepository.fetchPendingEvents(forUserID: nil, limit: nil)
try await outboxRepository.markAsCompleted(event.id)
```

#### 2. Missing Properties (12 errors)

**Problem:** Using old `OutboxEvent` properties that no longer exist

| Old Property | New Approach | Lines |
|--------------|-------------|-------|
| `event.payload` | Use `event.metadata` enum | 322, 328, 377, 383, 443, 459, 576, 582, 635, 641, 729, 734 |
| `event.retryCount` | Use `event.attemptCount` | 274, 275 |

**Fix Example:**
```swift
// Before:
let decoder = JSONDecoder()
let moodData = try decoder.decode(MoodPayload.self, from: event.payload)

// After:
guard case .moodEntry(let valence, let labels) = event.metadata else {
    throw ProcessorError.invalidMetadata
}
// Use valence and labels directly
```

#### 3. String Event Types (10 errors)

**Problem:** Using string literals instead of `OutboxEventType` enum

| Old (String) | New (Enum) | Lines |
|--------------|-----------|--------|
| `"mood.created"` | `.moodEntry` | 282 |
| `"mood.updated"` | `.moodEntry` (check `isNewRecord`) | 285 |
| `"mood.deleted"` | `.moodEntry` (check metadata) | 288 |
| `"journal.created"` | `.journalEntry` | 291 |
| `"journal.updated"` | `.journalEntry` | 294 |
| `"journal.deleted"` | `.journalEntry` | 297 |
| `"goal.created"` | `.goal` | 300 |
| `"goal.updated"` | `.goal` | 303 |
| `"goal.progress_updated"` | `.goal` | 306 |
| `"goal.status_updated"` | `.goal` | 309 |

**Fix Example:**
```swift
// Before:
switch event.eventType {
case "mood.created":
    await processMoodCreated(event)
case "mood.updated":
    await processMoodUpdated(event)
case "mood.deleted":
    await processMoodDeleted(event)
}

// After:
switch event.eventType {
case .moodEntry:
    if event.isNewRecord {
        await processMoodCreated(event)
    } else {
        // Check metadata for delete operation
        if case .generic(let dict) = event.metadata, dict["operation"] == "delete" {
            await processMoodDeleted(event)
        } else {
            await processMoodUpdated(event)
        }
    }
case .journalEntry:
    // Similar pattern
case .goal:
    // Similar pattern
}
```

#### 4. Generic Type Inference (4 errors)

**Problem:** JSONDecoder cannot infer type from context

| Line | Issue |
|------|-------|
| 766 | `try decoder.decode()` missing type parameter |
| 802 | `try decoder.decode()` missing type parameter |
| 832 | `try decoder.decode()` missing type parameter |
| 841 | Using `event.payload` (doesn't exist) |

**Fix:** Use metadata enum instead of decoding payloads

#### 5. Payload Decoding (1 error)

| Line | Issue |
|------|-------|
| 794 | Using `event.payload` (doesn't exist) |

---

## 🔧 Migration Strategy for OutboxProcessorService

### Step 1: Update Event Fetching

```swift
// Current (line 183):
let events = try await outboxRepository.pendingEvents()

// Fix:
let events = try await outboxRepository.fetchPendingEvents(
    forUserID: nil,  // Process all users
    limit: 50        // Process in batches
)
```

### Step 2: Update Event Status Methods

```swift
// Current (line 201):
try await outboxRepository.markCompleted(event)

// Fix:
try await outboxRepository.markAsCompleted(event.id)

// Current (line 228):
try await outboxRepository.markFailed(event, error: error.localizedDescription)

// Fix:
try await outboxRepository.markAsFailed(event.id, error: error.localizedDescription)
```

### Step 3: Update Property Names

```swift
// Current (line 274):
if event.retryCount >= 5 {

// Fix:
if event.attemptCount >= event.maxAttempts {
```

### Step 4: Replace Event Type Strings with Enums

**Create helper method:**
```swift
private func processEvent(_ event: OutboxEvent, accessToken: String) async throws {
    switch event.eventType {
    case .moodEntry:
        try await processMoodEvent(event, accessToken: accessToken)
    case .journalEntry:
        try await processJournalEvent(event, accessToken: accessToken)
    case .goal:
        try await processGoalEvent(event, accessToken: accessToken)
    default:
        print("⚠️ [OutboxProcessor] Unknown event type: \(event.eventType)")
    }
}
```

### Step 5: Replace Payload Decoding with Metadata

**Before (mood event):**
```swift
let decoder = JSONDecoder()
decoder.dateEncodingStrategy = .iso8601
let moodData = try decoder.decode(MoodPayload.self, from: event.payload)

// Use moodData.valence, moodData.labels, etc.
```

**After:**
```swift
// Extract from metadata
guard case .moodEntry(let valence, let labels) = event.metadata else {
    throw ProcessorError.invalidMetadata
}

// Fetch full entity from local store using event.entityID
let descriptor = FetchDescriptor<SDMoodEntry>(
    predicate: #Predicate { $0.id == event.entityID }
)
guard let moodEntry = try modelContext.fetch(descriptor).first else {
    throw ProcessorError.entityNotFound
}

// Use moodEntry for API call
```

### Step 6: Handle Create/Update/Delete Based on Flags

```swift
private func processMoodEvent(_ event: OutboxEvent, accessToken: String) async throws {
    guard case .moodEntry(let valence, let labels) = event.metadata else {
        throw ProcessorError.invalidMetadata
    }
    
    // Check for delete operation
    if case .generic(let dict) = event.metadata, dict["operation"] == "delete" {
        try await deleteMoodOnBackend(entityID: event.entityID, accessToken: accessToken)
        return
    }
    
    // Fetch full entity
    let moodEntry = try await fetchMoodEntry(id: event.entityID)
    
    // Create or update based on isNewRecord
    if event.isNewRecord {
        try await createMoodOnBackend(moodEntry, accessToken: accessToken)
    } else {
        try await updateMoodOnBackend(moodEntry, accessToken: accessToken)
    }
}
```

---

## 🔄 MoodSyncService Migration

**File:** `lume/Services/Sync/MoodSyncService.swift`  
**Errors:** 1  
**Priority:** 🟡 High  
**Estimated Time:** 15 minutes

### Issue

**Line 64:**
```swift
let pendingDeletes = try await outboxRepository.pendingEvents()
```

### Fix

```swift
// Before:
let pendingDeletes = try await outboxRepository.pendingEvents()
let pendingDeleteBackendIds = Set(
    pendingDeletes
        .filter { $0.eventType == "mood.deleted" }
        .compactMap { ... }
)

// After:
let pendingDeletes = try await outboxRepository.fetchPendingEvents(
    forUserID: nil,
    limit: nil
)
let pendingDeleteBackendIds = Set(
    pendingDeletes
        .filter { 
            $0.eventType == .moodEntry && 
            (case .generic(let dict) = $0.metadata, dict["operation"] == "delete")
        }
        .compactMap { event -> String? in
            // Extract backendId from metadata or entity lookup
            if case .generic(let dict) = event.metadata {
                return dict["backendId"]
            }
            return nil
        }
)
```

---

## 📋 Implementation Checklist

### Phase 1: OutboxProcessorService Core Methods (1 hour)
- [ ] Update `processPendingEvents()` - fetch method
- [ ] Update `markCompleted()` calls to `markAsCompleted(id:)`
- [ ] Update `markFailed()` calls to `markAsFailed(id:error:)`
- [ ] Update `retryCount` to `attemptCount`

### Phase 2: Event Type Migration (1 hour)
- [ ] Replace all string event types with enum cases
- [ ] Implement `processMoodEvent()`
- [ ] Implement `processJournalEvent()`
- [ ] Implement `processGoalEvent()`
- [ ] Update event routing logic

### Phase 3: Metadata Migration (1-2 hours)
- [ ] Remove all payload decoding logic
- [ ] Replace with metadata extraction
- [ ] Add entity fetching by `entityID`
- [ ] Update all processing methods to use metadata + entity lookup

### Phase 4: MoodSyncService (15 min)
- [ ] Update `pendingEvents()` to `fetchPendingEvents()`
- [ ] Update event type filtering
- [ ] Test delete detection logic

### Phase 5: Testing (1 hour)
- [ ] Test mood create/update/delete processing
- [ ] Test journal create/update/delete processing
- [ ] Test goal create/update/progress/status processing
- [ ] Verify outbox events marked as completed
- [ ] Verify failed events retry correctly

---

## 🎯 Success Criteria

- [ ] Zero compilation errors
- [ ] Zero warnings
- [ ] All 37 errors resolved
- [ ] End-to-end sync working (create/update/delete)
- [ ] Outbox events processed correctly
- [ ] Failed events retry with exponential backoff
- [ ] No data loss during sync

---

## ⚠️ Breaking Changes

### For OutboxProcessorService

1. **Event Structure Changed**
   - No more `payload` (binary Data)
   - Now uses `metadata` (type-safe enum)
   - Must fetch full entity using `entityID`

2. **Event Type System Changed**
   - No more string matching (`"mood.created"`)
   - Now enum-based (`.moodEntry`)
   - Single event type handles create/update/delete

3. **Status Methods Changed**
   - `markCompleted(event)` → `markAsCompleted(event.id)`
   - `markFailed(event, error)` → `markAsFailed(event.id, error: String)`

4. **Property Names Changed**
   - `retryCount` → `attemptCount`
   - Added `maxAttempts` property
   - Added `isNewRecord` flag

---

## 📚 Reference Implementation

**See FitIQ's OutboxProcessorService for working example:**
- Location: `FitIQ/FitIQ/Services/OutboxProcessorService.swift`
- Status: ✅ Fully migrated to FitIQCore
- Patterns: Proven in production

**Key Patterns:**
1. Fetch entity by `entityID` from SwiftData
2. Use `metadata` for lightweight context
3. Handle create/update/delete based on `isNewRecord` + metadata
4. Process in batches (limit: 50)
5. Retry with exponential backoff

---

## 🚀 Getting Started

### Quick Start Command

```bash
# 1. Open OutboxProcessorService
open fit-iq/lume/lume/Services/Outbox/OutboxProcessorService.swift

# 2. Review FitIQ's implementation
open fit-iq/FitIQ/FitIQ/Services/OutboxProcessorService.swift

# 3. Follow migration checklist above
```

### Recommended Order

1. **Start with API method updates** (easiest, quick wins)
2. **Update event type strings** (mechanical, low risk)
3. **Migrate metadata extraction** (most complex, high value)
4. **Test thoroughly** (critical, prevents regressions)

---

## 📞 Need Help?

**Resources:**
- [MIGRATION_COMPLETE.md](./MIGRATION_COMPLETE.md) - Full migration guide
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - API examples
- FitIQ OutboxProcessorService - Working reference implementation
- FitIQCore documentation - Protocol definitions

**Questions?**
- Check existing documentation first
- Review FitIQ's implementation
- Ask team in Slack with specific error context

---

**Status:** 🔄 Ready to Begin  
**Next Action:** Start with Phase 1 (Core Methods)  
**Estimated Completion:** 4-5 hours of focused work  
**Risk Level:** Medium (proven patterns available)

---

**END OF REMAINING WORK DOCUMENT**