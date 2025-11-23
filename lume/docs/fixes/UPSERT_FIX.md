# Upsert Fix: Cross-Device Consultation Sync

**Date:** 2025-01-15  
**Issue:** Cross-device sync failing with "notFound" error  
**Status:** ✅ Fixed

---

## Problem

When syncing consultations across devices, the app would fail with:

```
✅ [ChatBackendService] Fetched conversation: 66A66183-4639-47FB-A5EC-B150A54033FE
⚠️ [FetchConversationsUseCase] Backend fetch failed, checking local: notFound
⚠️ [ChatViewModel] Consultation not found, attempting recovery...
🔧 [ChatViewModel] Attempting to delete orphaned consultation: 66A66183-4639-47FB-A5EC-B150A54033FE
```

### Scenario

1. **Device A:** User creates a consultation
2. **Device B:** User opens app, consultation syncs from backend
3. **Result:** Backend fetch succeeds, but local save fails with `notFound` error
4. **User sees:** Orphaned consultation warning, delete/retry loop

### Root Cause

The `ChatRepository.updateConversation()` method was designed for **update only**:

```swift
func updateConversation(_ conversation: ChatConversation) async throws -> ChatConversation {
    let descriptor = FetchDescriptor<SDChatConversation>(
        predicate: #Predicate { $0.id == conversation.id }
    )
    
    guard let sdConversation = try modelContext.fetch(descriptor).first else {
        throw ChatRepositoryError.notFound  // ❌ Fails here on Device B
    }
    
    updateSDConversation(sdConversation, from: conversation)
    sdConversation.updatedAt = Date()
    try modelContext.save()
    
    return try await fetchConversationById(conversation.id) ?? conversation
}
```

**Problem:** When `FetchConversationsUseCase` fetches a consultation from the backend that doesn't exist locally, it calls `updateConversation()`, which throws `notFound` because there's nothing to update.

---

## Solution

Changed `updateConversation()` to be an **upsert** operation (update if exists, create if doesn't exist):

```swift
func updateConversation(_ conversation: ChatConversation) async throws -> ChatConversation {
    let descriptor = FetchDescriptor<SDChatConversation>(
        predicate: #Predicate { $0.id == conversation.id }
    )
    
    // Upsert: Create if not exists, update if exists
    if let sdConversation = try modelContext.fetch(descriptor).first {
        // Update existing conversation
        print("🔄 [ChatRepository] Updating existing conversation: \(conversation.id)")
        updateSDConversation(sdConversation, from: conversation)
        sdConversation.updatedAt = Date()
    } else {
        // Create new conversation (for cross-device sync)
        print("✨ [ChatRepository] Creating new conversation from backend sync: \(conversation.id)")
        let sdConversation = toSwiftDataConversation(conversation)
        modelContext.insert(sdConversation)
    }
    
    try modelContext.save()
    
    return try await fetchConversationById(conversation.id) ?? conversation
}
```

---

## How It Works

### Before Fix (Update Only)

```
Device A                          Backend                          Device B
--------                          -------                          --------
1. Create consultation
2. Save to local DB
3. Sync to backend      ------>  Store consultation
                                                         <------  4. Fetch from backend ✅
                                                                  5. Try to update local ❌
                                                                     (not found!)
                                                                  6. Trigger orphaned 
                                                                     consultation recovery
```

### After Fix (Upsert)

```
Device A                          Backend                          Device B
--------                          -------                          --------
1. Create consultation
2. Save to local DB
3. Sync to backend      ------>  Store consultation
                                                         <------  4. Fetch from backend ✅
                                                                  5. Check if exists locally
                                                                     (doesn't exist)
                                                                  6. Create new local record ✅
                                                                  7. Save to local DB ✅
                                                                  8. User sees consultation ✅
```

---

## Use Cases

### Use Case 1: Cross-Device Sync (New Device)

**Scenario:** User logs in on a new device

**Before Fix:**
1. App fetches consultations from backend
2. Tries to update local database (fails - nothing to update)
3. Shows "orphaned consultation" warning
4. User confused, sees error messages

**After Fix:**
1. App fetches consultations from backend
2. Creates new local records for each consultation
3. Silent, seamless sync
4. User sees all consultations immediately

---

### Use Case 2: App Reinstall

**Scenario:** User reinstalls app, logs back in

**Before Fix:**
- All backend consultations fail to sync
- Multiple "orphaned consultation" warnings
- Recovery attempts fail
- Poor user experience

**After Fix:**
- All backend consultations sync successfully
- Local database populated automatically
- No error messages
- Seamless experience

---

### Use Case 3: Existing Consultation Update

**Scenario:** Consultation is updated on backend (e.g., new message added)

**Before Fix:**
- Update works if consultation exists locally
- Fails if consultation somehow missing from local DB

**After Fix:**
- Updates existing consultation if found
- Creates new consultation if missing
- Robust, resilient sync

---

## Technical Details

### Method Name

The method is still called `updateConversation()` for backward compatibility, but it now behaves as an **upsert** operation.

### Alternative Names Considered

- `upsertConversation()` - More accurate but breaks API
- `saveConversation()` - Generic, doesn't convey update semantics
- `syncConversation()` - Implies backend sync, not local operation

**Decision:** Keep `updateConversation()` name, change behavior to upsert.

### Upsert Logic

```swift
if exists {
    update()
} else {
    create()
}
```

**Advantages:**
- No breaking API changes
- Handles both update and create scenarios
- Resilient to missing local data
- Supports cross-device sync

**Disadvantages:**
- Method name doesn't convey full behavior
- Slightly more complex logic

---

## Impact

### ✅ Fixed Issues

1. **Cross-device sync works** - Consultations sync from backend to local DB
2. **No more "notFound" errors** - Upsert handles missing local data
3. **No orphaned consultation warnings** - Silent, seamless sync
4. **App reinstall works** - All consultations restored from backend
5. **Multi-device experience** - Users can switch devices freely

### 📊 Performance

- **No performance impact** - Same number of database operations
- **Slightly slower on create path** - Negligible (milliseconds)
- **Faster overall** - Eliminates retry loops and recovery attempts

### 🎯 User Experience

**Before:**
- ⚠️ Error messages on sync
- ⚠️ Orphaned consultation warnings
- ⚠️ Manual recovery attempts
- ⚠️ Consultations missing on new devices

**After:**
- ✅ Silent, seamless sync
- ✅ No error messages
- ✅ Automatic recovery
- ✅ Consultations available everywhere

---

## Testing

### Test Case 1: New Device Sync

```swift
// Device A: Create consultation
let conversation = try await chatService.createConversation(
    title: "Test Chat",
    persona: .wellnessSpecialist,
    context: nil
)

// Device B: Fetch from backend (should create locally)
let fetched = try await chatService.fetchConversation(id: conversation.id)
let local = try await chatRepository.fetchConversationById(conversation.id)

// Expected Results:
// - fetched succeeds (no error)
// - local exists (not nil)
// - fetched.id == local.id
```

### Test Case 2: Update Existing

```swift
// Create locally first
let conversation = try await chatRepository.createConversation(
    title: "Test",
    persona: .generalWellness,
    context: nil
)

// Fetch from backend (should update existing)
var backendVersion = conversation
backendVersion.title = "Updated Title"

let updated = try await chatRepository.updateConversation(backendVersion)

// Expected Results:
// - updated succeeds
// - updated.title == "Updated Title"
// - Only one record in database (updated, not duplicated)
```

### Test Case 3: Missing Local Record

```swift
// Create consultation object without saving
let conversation = ChatConversation(
    id: UUID(),
    userId: UUID(),
    title: "Test",
    persona: .wellnessSpecialist,
    messages: [],
    createdAt: Date(),
    updatedAt: Date(),
    isArchived: false,
    context: nil
)

// Call update (should create since it doesn't exist)
let result = try await chatRepository.updateConversation(conversation)

// Expected Results:
// - result succeeds (no notFound error)
// - Local record created
// - result.id == conversation.id
```

---

## Verification

### Before Fix

```
🔄 [ChatViewModel] Fetching existing consultation from backend...
✅ [ChatBackendService] Fetched conversation: 66A66183-4639-47FB-A5EC-B150A54033FE
⚠️ [FetchConversationsUseCase] Backend fetch failed, checking local: notFound
⚠️ [ChatViewModel] Consultation not found, attempting recovery...
🔧 [ChatViewModel] Attempting to delete orphaned consultation: 66A66183-4639-47FB-A5EC-B150A54033FE
```

### After Fix

```
🔄 [ChatViewModel] Fetching existing consultation from backend...
✅ [ChatBackendService] Fetched conversation: 66A66183-4639-47FB-A5EC-B150A54033FE
✨ [ChatRepository] Creating new conversation from backend sync: 66A66183-4639-47FB-A5EC-B150A54033FE
✅ [FetchConversationsUseCase] Fetched conversation 66A66183-4639-47FB-A5EC-B150A54033FE from backend
✅ [ChatViewModel] Successfully fetched consultation from backend
```

---

## Related Fixes

This fix works in conjunction with:

1. **DTO Fix** ([CONSULTATION_DTO_FIX.md](./CONSULTATION_DTO_FIX.md))
   - Fixed decoding of backend response
   - Required for backend fetch to succeed

2. **Protocol Conformance** ([CONSULTATION_COMPLETE_FIX_SUMMARY.md](./CONSULTATION_COMPLETE_FIX_SUMMARY.md))
   - Fixed filtering and pagination
   - Required for list operations to work

**All three fixes are required** for full cross-device sync functionality.

---

## Best Practices

### When to Use Upsert

✅ **Use upsert when:**
- Syncing from external source (backend, API)
- Handling cross-device scenarios
- Data source of truth is external
- Local data might be stale or missing
- Need resilient, fault-tolerant operations

❌ **Don't use upsert when:**
- Creating user-initiated records (use explicit create)
- Update semantics are strict (must exist)
- Need to detect conflicts
- Need to validate existence before operation

### Repository Pattern

```swift
// User-initiated creation - explicit create
func createConversation(...) -> ChatConversation {
    let conversation = createNew()
    insert(conversation)
    return conversation
}

// Backend sync - upsert
func updateConversation(...) -> ChatConversation {
    if exists() {
        update()
    } else {
        create()
    }
    return conversation
}

// Explicit update - strict semantics
func updateExistingConversation(...) -> ChatConversation {
    guard exists() else { throw notFound }
    update()
    return conversation
}
```

---

## Future Considerations

### 1. Conflict Resolution

Currently last-write-wins. Consider:
- Timestamp-based conflict resolution
- Merge strategies for concurrent updates
- User-prompted conflict resolution

### 2. Separate Methods

Consider splitting into explicit methods:
```swift
protocol ChatRepositoryProtocol {
    func createConversation(...) -> ChatConversation
    func updateConversation(...) -> ChatConversation  // Strict update
    func upsertConversation(...) -> ChatConversation  // Create or update
}
```

### 3. Sync Metadata

Track sync state:
```swift
struct SyncMetadata {
    var lastSyncedAt: Date?
    var syncStatus: SyncStatus
    var conflictResolution: ConflictStrategy?
}
```

---

## Summary

The upsert fix transforms `updateConversation()` from a strict update operation to a flexible upsert operation that:

✅ **Creates** new records when syncing from backend to empty local database  
✅ **Updates** existing records when syncing changes  
✅ **Enables** seamless cross-device synchronization  
✅ **Eliminates** "orphaned consultation" errors  
✅ **Maintains** backward compatibility  

**Result:** Users can now access their consultations from any device without errors or warnings.

---

**File Modified:** `lume/Data/Repositories/ChatRepository.swift` (lines 81-103)  
**Impact:** High - Critical for cross-device sync  
**Risk:** Low - Backward compatible  
**Testing:** Verified with real backend sync scenarios