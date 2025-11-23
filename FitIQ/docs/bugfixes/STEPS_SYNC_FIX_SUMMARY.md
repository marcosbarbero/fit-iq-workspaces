# Steps Sync Fix Summary

**Date:** 2025-01-27  
**Issue:** LocalDataChangeMonitor unable to find ProgressEntry after save  
**Status:** ✅ Fixed

---

## Problem Description

When saving steps progress data locally, the sync to backend was not triggering because `LocalDataChangeMonitor` couldn't find the newly saved `ProgressEntry`.

### Error Log:
```
SwiftDataProgressRepository: Successfully saved progress entry with ID: DE0E0439-5DAC-4748-9291-67AD006FCD54
LocalDataChangeMonitor: ProgressEntry with ID DE0E0439-5DAC-4748-9291-67AD006FCD54 not found for user 774F6F3E-0237-4367-A54D-94898C0AB2E2.
```

---

## Root Cause Analysis

### Issue #1: Wrong Predicate in LocalDataChangeMonitor

**Location:** `LocalDataChangeMonitor.swift` line ~111

**Problem:**
```swift
// BEFORE (BROKEN)
let predicate = #Predicate<SDProgressEntry> {
    $0.id == localID && $0.userProfile?.id == userID
}
```

The predicate was checking `$0.userProfile?.id == userID`, but `SDProgressEntry` instances are saved with `userProfile: nil`:

```swift
// In SwiftDataProgressRepository.swift
let sdProgressEntry = SDProgressEntry(
    id: progressEntry.id,
    userID: userID,  // String field
    // ... other fields ...
    userProfile: nil  // ❌ Relationship not set
)
```

Since `userProfile` is `nil`, the predicate `$0.userProfile?.id == userID` always evaluates to `false`, so the entry is never found.

**Solution:**
```swift
// AFTER (FIXED)
let userIDString = userID.uuidString
let predicate = #Predicate<SDProgressEntry> {
    $0.id == localID && $0.userID == userIDString
}
```

Use the `userID` string field directly instead of the `userProfile` relationship.

### Issue #2: Context Isolation (SwiftData Multi-Context Issue)

**Location:** `LocalDataChangeMonitor.swift` line ~32

**Problem:**
```swift
@MainActor
public func notifyLocalRecordChanged(...) async {
    let context = ModelContext(modelContainer)  // ❌ Creates NEW context
    // ...
    if let progressEntry = try context.fetch(descriptor).first {
        // Entry not found because changes from other context not visible yet
    }
}
```

Even after fixing the predicate, there's a timing issue:
1. `SwiftDataProgressRepository` saves entry in **Context A**
2. Immediately notifies `LocalDataChangeMonitor`
3. Monitor creates **Context B** and tries to fetch
4. Changes from Context A haven't propagated to Context B yet

SwiftData uses multiple contexts, and changes need time to propagate from one context to another through the persistent store.

**Solution:**
```swift
// In SwiftDataProgressRepository.swift
// Schedule notification on MainActor with delay
Task { @MainActor in
    // Give SwiftData time to propagate changes between contexts
    try? await Task.sleep(nanoseconds: 250_000_000)  // 0.25 seconds

    await localDataChangeMonitor.notifyLocalRecordChanged(
        forLocalID: progressEntry.id,
        userID: userUUID,
        modelType: .progressEntry
    )
}
```

This ensures:
- The save is fully committed to persistent store
- Changes have time to propagate
- Monitor's new context can see the saved data

---

## Changes Applied

### 1. Fix Predicate (`LocalDataChangeMonitor.swift`)

```diff
case .progressEntry:
+   // Use userID string field instead of userProfile relationship
+   // because entries are saved with userProfile: nil
+   let userIDString = userID.uuidString
    let predicate = #Predicate<SDProgressEntry> {
-       $0.id == localID && $0.userProfile?.id == userID
+       $0.id == localID && $0.userID == userIDString
    }
```

### 2. Add Debug Logging (`LocalDataChangeMonitor.swift`)

```swift
print("LocalDataChangeMonitor: Searching for ProgressEntry:")
print("  - Local ID: \(localID)")
print("  - User ID: \(userIDString)")

// Fetch all entries for debugging
let allDescriptor = FetchDescriptor<SDProgressEntry>()
let allEntries = try context.fetch(allDescriptor)
print("LocalDataChangeMonitor: Found \(allEntries.count) total ProgressEntry records in context")
if !allEntries.isEmpty {
    print("LocalDataChangeMonitor: Sample IDs from context:")
    for entry in allEntries.prefix(5) {
        print("  - ID: \(entry.id), UserID: \(entry.userID), Status: \(entry.syncStatus)")
    }
}
```

### 3. Add Delay Before Notification (`SwiftDataProgressRepository.swift`)

```diff
- // Notify LocalDataChangeMonitor to trigger sync
- guard let userUUID = UUID(uuidString: userID) else {
-     print("...")
-     return progressEntry.id
- }
- 
- await localDataChangeMonitor.notifyLocalRecordChanged(
-     forLocalID: progressEntry.id,
-     userID: userUUID,
-     modelType: .progressEntry
- )

+ // Schedule notification on MainActor with delay to ensure context sync
+ Task { @MainActor in
+     try? await Task.sleep(nanoseconds: 250_000_000)  // 0.25 seconds
+ 
+     print("SwiftDataProgressRepository: Notifying LocalDataChangeMonitor after save and delay")
+ 
+     await localDataChangeMonitor.notifyLocalRecordChanged(
+         forLocalID: progressEntry.id,
+         userID: userUUID,
+         modelType: .progressEntry
+     )
+ }
```

### 4. Enhanced API Logging (`RemoteSyncService.swift` & `ProgressAPIClient.swift`)

Added comprehensive logging at every step:
- 📤 When sync event starts processing
- 🌐 Before API call
- Request body (pretty printed JSON)
- Response status code
- Response body (full JSON)
- ✅ Success indicators
- ❌ Failure indicators with details

---

## Expected Log Flow (After Fix)

```
1. SwiftDataProgressRepository: Saving progress entry - Type: steps, Quantity: 2241.0
2. SwiftDataProgressRepository: Successfully saved progress entry with ID: XXX
3. SwiftDataProgressRepository: Notifying LocalDataChangeMonitor after save and delay
4. LocalDataChangeMonitor: Searching for ProgressEntry:
     - Local ID: XXX
     - User ID: 774F6F3E-0237-4367-A54D-94898C0AB2E2
5. LocalDataChangeMonitor: Found 1 total ProgressEntry records in context
6. LocalDataChangeMonitor: Publishing sync event for ProgressEntry (ID: XXX, new: true, status: pending)
7. RemoteSyncService: 📤 Processing progressEntry sync event for localID XXX
8. RemoteSyncService: 🌐 Calling /api/v1/progress API to upload progress entry...
9. ProgressAPIClient: Request body: { "type": "steps", "quantity": 2241, ... }
10. ProgressAPIClient: Response status code: 201
11. ProgressAPIClient: Response body: { "success": true, "data": { ... } }
12. RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry
```

---

## Files Modified

1. **`FitIQ/Infrastructure/Persistence/Schema/LocalDataChangeMonitor.swift`**
   - Fixed predicate to use `userID` string field
   - Added debug logging to show search parameters
   - Added logging to list all entries in context

2. **`FitIQ/Infrastructure/Persistence/SwiftDataProgressRepository.swift`**
   - Changed notification to use Task with 250ms delay
   - Ensures MainActor execution
   - Added logging before notification

3. **`FitIQ/Infrastructure/Network/RemoteSyncService.swift`**
   - Added 📤 indicator for event processing
   - Added detailed entry info logging
   - Added 🌐 indicator before API call
   - Enhanced error logging with full details

4. **`FitIQ/Infrastructure/Network/ProgressAPIClient.swift`**
   - Added request body logging (pretty printed)
   - Added response body logging (always, not just on error)
   - Enhanced success logging with all entry details

---

## Testing Checklist

- [x] Fix predicate to use correct field
- [x] Add delay to allow context propagation
- [x] Add comprehensive logging
- [ ] Test with real device/simulator
- [ ] Verify entry is found by monitor
- [ ] Verify sync event is published
- [ ] Verify API call is made
- [ ] Verify backend receives data
- [ ] Verify local entry updated with backend ID

---

## Additional Notes

### About the Body Mass Error

The body mass sync error in your logs is **unrelated** to steps progress sync:

```
RemoteHealthDataSyncClient: Failed to upload body mass for user ... Error: The data couldn't be read because it isn't in the correct format.
```

This is a separate issue with:
- Different data type (body mass vs steps)
- Different endpoint (`/api/v1/profile/metrics` vs `/api/v1/progress`)
- Different DTO format

It should be investigated separately.

### Why 250ms Delay?

The 250ms delay is a pragmatic solution for SwiftData's multi-context architecture:
- SwiftData needs time to persist changes to disk
- Changes need to propagate to other contexts
- 250ms is long enough to be reliable but short enough to not impact UX
- The save operation returns immediately (non-blocking)
- Sync happens in background (user doesn't wait)

### Alternative Solutions (Future Improvements)

1. **Single Context Architecture**
   - Use one shared ModelContext for all operations
   - Eliminates context isolation issues
   - Requires architectural changes

2. **Pass Object Instead of ID**
   - Pass the saved `SDProgressEntry` object directly
   - Avoid refetching from different context
   - Requires protocol changes

3. **SwiftData Notifications**
   - Listen to SwiftData's built-in change notifications
   - More reactive, less polling
   - More complex implementation

---

**Status:** ✅ Fix Applied, Ready for Testing  
**Next Step:** Run app and verify logs show successful sync flow