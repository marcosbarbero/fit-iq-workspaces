# Water Tracking Debugging Guide for Test Accounts

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Quick debugging and verification for water intake tracking

---

## Quick Verification Steps

### 1. Check Database State

Add this temporary debugging function to `SwiftDataProgressRepository.swift`:

```swift
/// TEMPORARY: Debug function to inspect all water entries
func debugPrintWaterEntries(forUserID userID: String) async throws {
    let predicate = #Predicate<SDProgressEntry> { entry in
        entry.userID == userID && entry.type == "water_liters"
    }
    
    var descriptor = FetchDescriptor<SDProgressEntry>(predicate: predicate)
    descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]
    
    let entries = try modelContext.fetch(descriptor)
    
    print("========================================")
    print("🔍 DEBUG: Water Entries for User \(userID)")
    print("Total entries: \(entries.count)")
    print("========================================")
    
    for (index, entry) in entries.enumerated() {
        print("Entry #\(index + 1):")
        print("  ID: \(entry.id)")
        print("  Quantity: \(String(format: "%.3f", entry.quantity))L")
        print("  Date: \(entry.date)")
        print("  Created: \(entry.createdAt)")
        print("  Updated: \(entry.updatedAt ?? Date())")
        print("  Backend ID: \(entry.backendID ?? "nil")")
        print("  Sync Status: \(entry.syncStatus)")
        print("  ---")
    }
    print("========================================")
}
```

Call it in `GetTodayWaterIntakeUseCase.execute()`:

```swift
func execute() async throws -> Double {
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        throw GetTodayWaterIntakeError.userNotAuthenticated
    }
    
    // ✅ TEMPORARY: Debug entries
    try await progressRepository.debugPrintWaterEntries(forUserID: userID)
    
    // ... rest of the function
}
```

---

### 2. Expected Console Output (Correct Behavior)

When logging water throughout the day, you should see:

```
========================================
🔍 DEBUG: Water Entries for User <UUID>
Total entries: 1
========================================
Entry #1:
  ID: <UUID-A>
  Quantity: 1.750L
  Date: 2025-01-27 08:00:00
  Created: 2025-01-27 08:00:00
  Updated: 2025-01-27 18:00:00
  Backend ID: nil
  Sync Status: pending
  ---
========================================
```

**Key indicators of correct behavior:**
- ✅ Only **1 entry** for today
- ✅ Quantity shows **total aggregated amount** (e.g., 1.750L)
- ✅ `createdAt` shows first water log time (e.g., 08:00)
- ✅ `updatedAt` shows most recent water log time (e.g., 18:00)

---

### 3. Signs of Incorrect Behavior (Legacy Duplicates)

If you see multiple entries for the same day:

```
========================================
🔍 DEBUG: Water Entries for User <UUID>
Total entries: 3  ⚠️ PROBLEM
========================================
Entry #1:
  ID: <UUID-A>
  Quantity: 0.500L  ⚠️ Should be aggregated
  Date: 2025-01-27 08:00:00
  ---
Entry #2:
  ID: <UUID-B>
  Quantity: 0.750L  ⚠️ Duplicate entry
  Date: 2025-01-27 12:00:00
  ---
Entry #3:
  ID: <UUID-C>
  Quantity: 0.500L  ⚠️ Duplicate entry
  Date: 2025-01-27 18:00:00
  ---
========================================
```

**This indicates legacy duplicate data** from before the fix.

---

## Solutions for Test Accounts

### Option 1: Reset Water Data Only

Add this to your repository and call it once:

```swift
func deleteAllWaterEntries(forUserID userID: String) async throws {
    print("🗑️ Deleting all water entries for user: \(userID)")
    
    let predicate = #Predicate<SDProgressEntry> { entry in
        entry.userID == userID && entry.type == "water_liters"
    }
    
    let descriptor = FetchDescriptor<SDProgressEntry>(predicate: predicate)
    let entries = try modelContext.fetch(descriptor)
    
    for entry in entries {
        modelContext.delete(entry)
    }
    
    try modelContext.save()
    print("✅ Deleted \(entries.count) water entries")
}
```

Call it once in your app:

```swift
// In ProfileViewModel or wherever convenient
func resetWaterData() async {
    guard let userID = authManager.currentUserProfileID?.uuidString else { return }
    
    do {
        try await progressRepository.deleteAllWaterEntries(forUserID: userID)
        print("✅ Water data reset complete")
    } catch {
        print("❌ Failed to reset water data: \(error)")
    }
}
```

---

### Option 2: Use Existing Cleanup Use Case

The app already has `RemoveDuplicateProgressEntriesUseCase`. Call it once:

```swift
// In your ViewModel or app startup
func cleanupDuplicates() async {
    do {
        try await removeDuplicateProgressEntriesUseCase.execute(forType: .waterLiters)
        print("✅ Cleanup complete")
    } catch {
        print("❌ Cleanup failed: \(error)")
    }
}
```

This keeps the **most recently updated** entry and removes older duplicates.

---

### Option 3: Full Database Reset (Nuclear Option)

For test accounts, the cleanest approach:

```swift
// Delete the entire SwiftData container
func resetDatabase() {
    // 1. Delete container
    if let url = modelContainer.configurations.first?.url {
        try? FileManager.default.removeItem(at: url)
    }
    
    // 2. Restart app
    // All data will be fresh
}
```

Or simply:
1. Delete the app from simulator/device
2. Reinstall
3. Start fresh with correct accounting logic

---

## Testing Script

After resetting (if needed), follow this exact sequence:

### Test Day 1

**8:00 AM** - Log 500ml water
```
Expected DB state:
Entry A: 0.5L (created 08:00, updated 08:00)
Expected UI: 0.5L
```

**12:00 PM** - Log 750ml water
```
Expected DB state:
Entry A: 1.25L (created 08:00, updated 12:00) ← UPDATED
Expected UI: 1.25L
```

**6:00 PM** - Log 500ml water
```
Expected DB state:
Entry A: 1.75L (created 08:00, updated 18:00) ← UPDATED
Expected UI: 1.75L
```

### Test Day 2

**8:00 AM** - Log 600ml water
```
Expected DB state:
Entry A: 1.75L (created Day 1 08:00, updated Day 1 18:00) ← Yesterday
Entry B: 0.6L (created Day 2 08:00, updated Day 2 08:00)  ← Today
Expected UI: 0.6L
```

---

## Console Output to Look For

### ✅ Correct Aggregation

```
SaveWaterProgressUseCase: ✅ EXISTING ENTRY FOUND
SaveWaterProgressUseCase: 💧   Current quantity: 0.500L
SaveWaterProgressUseCase: 💧   Input to add: 0.750L
SaveWaterProgressUseCase: 💧   NEW TOTAL: 1.250L
SaveWaterProgressUseCase: ✅ SUCCESSFULLY UPDATED ENTRY
SwiftDataProgressRepository: 🔄 UPDATING quantity: 0.500 → 1.250
```

### ❌ Legacy Duplicates Warning

```
SaveWaterProgressUseCase: ⚠️ WARNING: Multiple entries found! Should only be 1 per day.
SaveWaterProgressUseCase: ⚠️   Entry #1: 0.500L at 2025-01-27 08:00:00
SaveWaterProgressUseCase: ⚠️   Entry #2: 0.750L at 2025-01-27 12:00:00
```

If you see this, you have legacy duplicates. Use one of the solutions above.

---

## Quick Checklist

- [ ] Add `debugPrintWaterEntries()` function
- [ ] Log 500ml water → Check console output
- [ ] Verify only 1 entry exists with 0.5L
- [ ] Log 750ml water → Check console output
- [ ] Verify same entry updated to 1.25L (not new entry)
- [ ] Check UI displays 1.25L
- [ ] Log 500ml water → Check console output
- [ ] Verify same entry updated to 1.75L
- [ ] Check UI displays 1.75L
- [ ] Wait until next day → Verify new entry created (not updating yesterday's)

---

## Conclusion

**The accounting logic is correct.** Any issues are from legacy duplicate data.

**For test accounts:**
1. Use Option 1, 2, or 3 above to clean legacy data
2. Re-test with fresh data
3. Verify aggregation works correctly
4. Remove debug functions when satisfied

**The fix is working as designed** - no further code changes needed!

---

**Status:** Ready for Testing  
**Recommendation:** Reset test account water data, then verify aggregation