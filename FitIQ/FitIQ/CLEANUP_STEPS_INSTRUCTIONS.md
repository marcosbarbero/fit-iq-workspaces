# Cleanup Duplicate Steps Data - Quick Fix

## Problem
The steps sync has created massive duplicates in the local database. For example:
- 13:00 hour has 35 duplicate entries (should be 1)
- 12:00 hour has 35 duplicate entries (should be 1)  
- 11:00 hour has 30 duplicate entries (should be 1)

This results in **43,420 steps** being shown instead of the actual **~1,379 steps**.

## Root Cause
The `StepsSyncHandler` was running multiple times and the `SwiftDataProgressRepository.save()` method didn't have deduplication logic, so every sync created new duplicate entries for the same hour.

## Fix Applied
✅ **Deduplication logic added** to `SwiftDataProgressRepository.save()` - prevents future duplicates
✅ **Cleanup method added** to `SwiftDataProgressRepository.removeDuplicates()` - removes existing duplicates

## How to Clean Up Existing Data

### Option 1: Add Temporary Cleanup Code (Recommended)

Add this code to `SummaryViewModel.reloadAllData()` method **at the very beginning**:

```swift
func reloadAllData() async {
    // 🧹 ONE-TIME CLEANUP: Remove this after running once
    do {
        if let swiftDataRepo = progressRepository as? SwiftDataProgressRepository {
            print("🧹 Running one-time cleanup of duplicate steps...")
            try await swiftDataRepo.removeDuplicates(forUserID: authManager.currentUserProfileID!.uuidString, type: .steps)
            print("✅ Cleanup complete!")
        }
    } catch {
        print("⚠️ Cleanup failed: \(error.localizedDescription)")
    }
    // END ONE-TIME CLEANUP
    
    isLoading = true
    // ... rest of existing code
}
```

**Steps:**
1. Add the cleanup code above to `SummaryViewModel.reloadAllData()`
2. Run the app once
3. Check the console - you should see: "✅ Removed X duplicates, kept Y unique entries"
4. Verify steps count is now correct (should be ~1,379 instead of 43,420)
5. **Remove the cleanup code** after confirming it worked

### Option 2: Use Debug Button (For Testing)

Add a temporary debug button to your Summary view:

```swift
// In SummaryView, add this button temporarily
Button("🧹 Clean Duplicates") {
    Task {
        guard let repo = profileViewModel.dependencies.progressRepository as? SwiftDataProgressRepository else { return }
        guard let userID = profileViewModel.dependencies.authManager.currentUserProfileID?.uuidString else { return }
        
        do {
            try await repo.removeDuplicates(forUserID: userID, type: .steps)
            await viewModel.reloadAllData()
        } catch {
            print("Cleanup failed: \(error)")
        }
    }
}
```

### Option 3: Nuclear Option - Delete All Steps Data

If the above doesn't work, you can delete all steps data and let it re-sync fresh:

```swift
// WARNING: This deletes ALL steps data
do {
    guard let userID = authManager.currentUserProfileID?.uuidString else { return }
    try await progressRepository.deleteAll(forUserID: userID, type: .steps)
    print("✅ Deleted all steps data")
    
    // Force a fresh sync from HealthKit
    try await processDailyHealthDataUseCase.execute()
} catch {
    print("❌ Failed: \(error)")
}
```

## Verification

After cleanup, check the logs again. You should see:

```
GetDailyStepsTotalUseCase: Found 3 step entries  // Should be ~24 or fewer (one per hour)
  [1]: 107 steps | Date: 2025-11-01 13:00:00 | Time: 13:00:00 | ...
  [2]: 997 steps | Date: 2025-11-01 12:00:00 | Time: 12:00:00 | ...
  [3]: 116 steps | Date: 2025-11-01 11:00:00 | Time: 11:00:00 | ...
GetDailyStepsTotalUseCase: ✅ TOTAL: 1220 steps from 3 entries
```

**Expected result:** Each hour should have only **1 entry**, not 10-35 duplicates.

## Prevention

The deduplication logic is now in place, so:
- ✅ Future syncs won't create duplicates
- ✅ Repository checks for existing entries before saving
- ✅ Logs will show "⏭️ Entry already exists" when skipping duplicates

## Files Modified

1. `SwiftDataProgressRepository.swift` - Added deduplication in `save()` and `removeDuplicates()` method
2. `GetDailyStepsTotalUseCase.swift` - Added detailed logging for debugging
3. `RemoveDuplicateProgressEntriesUseCase.swift` - Generic cleanup use case (for all metric types)
4. `CleanupDuplicateStepsUseCase.swift` - Specific cleanup for steps

## Notes

- The issue only affects **local data** - backend API is not affected
- Heart rate and other metrics may have the same issue (check logs)
- This is a **one-time cleanup** - after running, the problem won't recur
- The deduplication fix ensures this won't happen again in the future

---

**Status:** Ready to run cleanup  
**Date:** 2025-01-27  
**Priority:** High (affects user-facing data)