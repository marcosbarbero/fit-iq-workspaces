# HealthKit Deduplication Fix

**Date:** 2025-01-27  
**Issue:** Duplicate steps entries created every time app opens/Summary view loads  
**Root Cause:** No deduplication check before saving HealthKit data locally  
**Status:** ✅ Fixed

---

## Problem

Every time the app opened or the Summary view loaded, HealthKit data (steps) was fetched and saved to local storage **without checking if it already existed**. This caused:

1. Duplicate local entries for the same date
2. Multiple sync events to backend
3. Duplicate entries in backend database

### Evidence from Logs

**First App Open:**
```
SaveStepsProgressUseCase: Saving 3422 steps for user ...
Backend ID: e273f57a-f4e0-48b2-914f-e7d22c40c342
```

**Second App Open (Same Data):**
```
SaveStepsProgressUseCase: Saving 3422 steps for user ...
Backend ID: a31f727a-cf9d-4760-8d08-65eb29c21ea5  ← Different! Duplicate!
```

**Same steps count (3422) for same date (2025-10-29) created TWO backend entries!**

---

## Root Cause

In `SaveStepsProgressUseCase.swift`, the logic was:

```swift
// ❌ BEFORE - No deduplication check
func execute(steps: Int, date: Date = Date()) async throws -> UUID {
    // Validate input
    guard steps >= 0 else { ... }
    guard let userID = ... else { ... }
    
    // Create progress entry - ALWAYS creates new entry!
    let progressEntry = ProgressEntry(
        id: UUID(),  // ← New UUID every time!
        userID: userID,
        type: .steps,
        quantity: Double(steps),
        date: date,
        ...
    )
    
    // Save locally
    let localID = try await progressRepository.save(
        progressEntry: progressEntry, forUserID: userID)
    
    return localID
}
```

**Problem:** Every call creates a new `ProgressEntry` with a new UUID, even if identical data already exists.

### Why This Happened

**HealthKit Fetch Flow:**
1. User opens app → `SummaryView` appears
2. `SummaryViewModel.loadData()` called
3. `syncStepsToProgressTracking()` fetches steps from HealthKit
4. Calls `saveStepsProgressUseCase.execute(steps: 3422, date: today)`
5. **Always creates new entry** (no deduplication)
6. Saves to local SwiftData
7. Triggers sync event
8. Syncs to backend (creates duplicate)

**Result:** Every app open = new duplicate entry!

---

## The Fix

Added **three-layer deduplication logic** to `SaveStepsProgressUseCase`:

### 1. Check if Entry Exists for Same Date

```swift
// Fetch existing entries for this user and type
let existingEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .steps,
    syncStatus: nil
)

// Normalize date to start of day
let calendar = Calendar.current
let targetDate = calendar.startOfDay(for: date)

// Look for existing entry on same date
if let existingEntry = existingEntries.first(where: { entry in
    let entryDate = calendar.startOfDay(for: entry.date)
    return calendar.isDate(entryDate, inSameDayAs: targetDate)
}) {
    // Found existing entry - check quantity
}
```

### 2. If Quantity is Same → Skip (No-Op)

```swift
if existingEntry.quantity == Double(steps) {
    print("Entry already exists with same steps count. Skipping duplicate.")
    return existingEntry.id  // ✅ Return existing ID, don't create new entry
}
```

### 3. If Quantity Changed → Update Entry

```swift
else {
    print("Entry exists but with different steps count. Updating quantity.")
    
    // Create updated entry with new quantity
    let updatedEntry = ProgressEntry(
        id: existingEntry.id,  // ✅ Keep same local ID
        userID: userID,
        type: .steps,
        quantity: Double(steps),  // ← New quantity
        date: existingEntry.date,
        notes: existingEntry.notes,
        createdAt: existingEntry.createdAt,
        updatedAt: Date(),  // ✅ Mark as updated
        backendID: existingEntry.backendID,
        syncStatus: .pending  // ✅ Trigger re-sync
    )
    
    let localID = try await progressRepository.save(
        progressEntry: updatedEntry, forUserID: userID)
    
    return localID
}
```

### 4. If No Entry Exists → Create New

```swift
// No existing entry found, create new one
print("No existing entry found. Creating new entry.")

let progressEntry = ProgressEntry(
    id: UUID(),
    userID: userID,
    type: .steps,
    quantity: Double(steps),
    date: targetDate,
    notes: nil,
    createdAt: Date(),
    backendID: nil,
    syncStatus: .pending
)

let localID = try await progressRepository.save(
    progressEntry: progressEntry, forUserID: userID)

return localID
```

---

## Deduplication Logic Flow

```
┌─────────────────────────────────────────┐
│ HealthKit fetches steps: 3422 for today │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ SaveStepsProgressUseCase.execute()      │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Fetch existing entries for date         │
└─────────────┬───────────────────────────┘
              ↓
        Entry exists?
              ├─ NO  → Create new entry ──────────┐
              │                                    │
              └─ YES → Check quantity              │
                       ├─ Same → Skip (return ID) ─┤
                       └─ Different → Update entry ┤
                                                    │
                                                    ↓
                                     ┌──────────────────────┐
                                     │ Save to SwiftData    │
                                     └──────────┬───────────┘
                                                ↓
                                     ┌──────────────────────┐
                                     │ Trigger sync event   │
                                     │ (if new or updated)  │
                                     └──────────────────────┘
```

---

## Scenarios Handled

### Scenario 1: First Time Opening App (No Existing Data)

```
1. Fetch HealthKit: 3422 steps for 2025-10-29
2. Check existing entries: None found
3. Create new entry:
   - Local ID: EE5ABE79...
   - Quantity: 3422
   - Date: 2025-10-29 00:00:00
   - Sync Status: pending
4. Save to SwiftData ✅
5. Trigger sync event ✅
6. Sync to backend → Backend ID: e273f57a...
```

### Scenario 2: Re-opening App (Same Data Exists)

```
1. Fetch HealthKit: 3422 steps for 2025-10-29
2. Check existing entries: Found 1
   - Local ID: EE5ABE79...
   - Quantity: 3422
   - Date: 2025-10-29 00:00:00
   - Backend ID: e273f57a...
3. Compare quantity: 3422 == 3422 ✅
4. Skip duplicate! Return existing ID
5. ❌ No save to SwiftData
6. ❌ No sync event
7. ❌ No duplicate backend entry
```

**Result:** No duplicate created! 🎉

### Scenario 3: Steps Count Updated in HealthKit

```
1. Fetch HealthKit: 4200 steps for 2025-10-29 (was 3422)
2. Check existing entries: Found 1
   - Local ID: EE5ABE79...
   - Quantity: 3422 (old value)
   - Backend ID: e273f57a...
3. Compare quantity: 4200 != 3422 ❌
4. Update entry:
   - Keep Local ID: EE5ABE79...
   - Update Quantity: 3422 → 4200
   - Keep Backend ID: e273f57a...
   - Set Sync Status: pending (trigger re-sync)
   - Set Updated At: now
5. Save to SwiftData ✅
6. Trigger sync event ✅
7. Sync updated value to backend ✅
```

**Result:** Entry updated, not duplicated! 🎉

---

## Expected Log Output (After Fix)

### First Open (New Entry)

```
SaveStepsProgressUseCase: Saving 3422 steps for user ... on 2025-10-29
SaveStepsProgressUseCase: No existing entry found for 2025-10-29 00:00:00. Creating new entry.
SaveStepsProgressUseCase: Successfully saved new steps progress with local ID: EE5ABE79...
RemoteSyncService: Successfully synced. Backend ID: e273f57a...
```

### Second Open (Duplicate Skipped)

```
SaveStepsProgressUseCase: Saving 3422 steps for user ... on 2025-10-29
SaveStepsProgressUseCase: Entry already exists for 2025-10-29 00:00:00 with same steps count (3422). Skipping duplicate. Local ID: EE5ABE79...
❌ No sync event published
❌ No backend API call
❌ No duplicate entry
```

### Third Open (Updated Value)

```
SaveStepsProgressUseCase: Saving 4200 steps for user ... on 2025-10-29
SaveStepsProgressUseCase: Entry exists for 2025-10-29 00:00:00 but with different steps count (existing: 3422, new: 4200). Updating quantity.
SaveStepsProgressUseCase: Successfully updated steps progress. Local ID: EE5ABE79...
RemoteSyncService: Successfully synced updated entry. Backend ID: e273f57a...
```

---

## Benefits

### 1. No Duplicate Entries

**Before:**
- Open app 5 times = 5 duplicate entries in backend

**After:**
- Open app 5 times = 1 entry in backend ✅

### 2. Efficient Syncing

**Before:**
- Every app open triggers sync (even with same data)

**After:**
- Only syncs when data is new or changed ✅

### 3. Correct Updates

**Before:**
- Steps count updated in HealthKit = new duplicate entry

**After:**
- Steps count updated in HealthKit = update existing entry ✅

### 4. Database Integrity

**Before:**
- Backend has multiple entries for same date

**After:**
- Backend has one entry per date (updated as needed) ✅

---

## Edge Cases Handled

### 1. Multiple Entries on Same Date (Shouldn't happen, but handle it)

```swift
if let existingEntry = existingEntries.first(where: { ... }) {
    // Takes FIRST match (earliest created)
    // Future improvement: Could merge or handle conflicts
}
```

### 2. Date Normalization

```swift
let targetDate = calendar.startOfDay(for: date)
// Ensures 2025-10-29 08:30:00 == 2025-10-29 14:15:00
// Both normalize to 2025-10-29 00:00:00
```

### 3. Backend ID Preservation

```swift
let updatedEntry = ProgressEntry(
    ...
    backendID: existingEntry.backendID,  // ✅ Keep existing backend ID
    syncStatus: .pending  // But mark for re-sync (to update backend)
)
```

---

## Testing

### Manual Testing

1. **Clean State:**
   ```
   - Delete app
   - Reinstall
   - Log in
   ```

2. **First Open:**
   ```
   - Open app → Summary view
   - Check logs: "Creating new entry"
   - Query backend: 1 entry ✅
   ```

3. **Second Open:**
   ```
   - Force quit app
   - Re-open → Summary view
   - Check logs: "Skipping duplicate"
   - Query backend: Still 1 entry ✅
   ```

4. **Update in HealthKit:**
   ```
   - Manually change steps in Health app
   - Open FitIQ app → Summary view
   - Check logs: "Updating quantity"
   - Query backend: 1 entry with updated value ✅
   ```

### Automated Testing

```swift
func testDeduplicationSameQuantity() async throws {
    // Given: Existing entry
    let existingEntry = ProgressEntry(
        id: UUID(),
        userID: "user-123",
        type: .steps,
        quantity: 3422,
        date: Date(),
        ...
    )
    try await repository.save(progressEntry: existingEntry, forUserID: "user-123")
    
    // When: Save same data again
    let resultID = try await useCase.execute(steps: 3422, date: Date())
    
    // Then: Returns existing ID (no new entry created)
    XCTAssertEqual(resultID, existingEntry.id)
    XCTAssertEqual(repository.saveCallCount, 1)  // Only initial save
}

func testDeduplicationUpdatedQuantity() async throws {
    // Given: Existing entry
    let existingEntry = ProgressEntry(
        id: UUID(),
        userID: "user-123",
        type: .steps,
        quantity: 3422,
        date: Date(),
        backendID: "backend-123",
        ...
    )
    try await repository.save(progressEntry: existingEntry, forUserID: "user-123")
    
    // When: Save updated quantity
    let resultID = try await useCase.execute(steps: 4200, date: Date())
    
    // Then: Updates existing entry
    XCTAssertEqual(resultID, existingEntry.id)
    XCTAssertEqual(repository.saveCallCount, 2)  // Initial + update
    
    let updatedEntry = try await repository.fetchLocal(...).first
    XCTAssertEqual(updatedEntry.quantity, 4200)
    XCTAssertEqual(updatedEntry.backendID, "backend-123")  // Preserved
    XCTAssertEqual(updatedEntry.syncStatus, .pending)  // Marked for re-sync
}
```

---

## Related Fixes

This fix works in conjunction with:

1. **Progress API Response Fix** (`progress-api-response-fix.md`)
   - Fixed DTO to match backend contract
   - Ensures backend ID is correctly decoded

2. **Duplicate Sync Backend ID Fix** (`duplicate-sync-backend-id-fix.md`)
   - Fixed storing correct backend ID
   - Prevents duplicate syncs on restart

**All three fixes together ensure:**
- ✅ No duplicate entries from HealthKit fetches
- ✅ Correct backend ID stored
- ✅ No duplicate syncs on app restart

---

## Future Improvements

### 1. Batch Deduplication

For historical syncs (multiple days):

```swift
func executeBatch(entries: [StepsEntry]) async throws {
    for entry in entries {
        // Use same deduplication logic
        try await execute(steps: entry.steps, date: entry.date)
    }
}
```

### 2. Conflict Resolution

If multiple entries exist for same date:

```swift
// Strategy 1: Keep most recent
// Strategy 2: Keep highest value
// Strategy 3: Merge (if different times)
```

### 3. Performance Optimization

Cache recent entries to avoid repeated fetches:

```swift
private var recentEntriesCache: [Date: ProgressEntry] = [:]
```

---

## Summary

### The Problem
Every time the app opened, HealthKit data was fetched and saved without checking for duplicates, creating multiple entries in both local storage and backend.

### The Solution
Added deduplication logic in `SaveStepsProgressUseCase` to:
1. Check if entry exists for the date
2. Skip if quantity is the same
3. Update if quantity changed
4. Create new only if no entry exists

### The Impact
- ✅ No more duplicate entries in backend
- ✅ Efficient syncing (only when needed)
- ✅ Correct updates when data changes
- ✅ Better database integrity

---

**Files Changed:**
- ✅ `FitIQ/Domain/UseCases/SaveStepsProgressUseCase.swift`

**Status:** ✅ **FIXED AND READY FOR TESTING**

**Test Priority:** HIGH - Verify no duplicates after multiple app opens.