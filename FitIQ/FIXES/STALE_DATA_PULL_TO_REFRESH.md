# Pull-to-Refresh Fix for Stale Data in SummaryView

## Problem

After logging in, the SummaryView displays **stale data** from earlier in the day:
- Heart rate showing data from 4 AM when it's now 10 PM
- Steps count not updating throughout the day
- Sleep and other metrics not refreshing automatically

## Root Cause

The app syncs HealthKit data at specific times:

1. **Initial sync** - When you first log in (via `PerformInitialHealthKitSyncUseCase`)
2. **Background sync** - When the app is in the background and iOS triggers a background task
3. **HealthKit observations** - When HealthKit detects new data (but may be delayed)

**The issue:** Once the user is already in the app viewing the Summary screen, there's no automatic refresh mechanism to pull the latest data from HealthKit.

### Why Doesn't It Update Automatically?

- Background sync only runs when app is in background
- HealthKit observations can be delayed or not trigger immediately
- The SummaryView only loads data once on `.onAppear`
- No mechanism to re-sync from HealthKit while viewing the screen

## Solution: Pull-to-Refresh

We've added a **pull-to-refresh** gesture to the SummaryView that:

1. Syncs fresh data from HealthKit
2. Processes and saves it to local storage
3. Reloads the UI with the latest data

### How It Works

```
User pulls down on Summary screen
    ↓
SummaryViewModel.refreshData()
    ↓
1. ProcessDailyHealthDataUseCase.execute()
   - Fetches latest data from HealthKit
   - Updates ActivitySnapshot and ProgressEntry
    ↓
2. SummaryViewModel.reloadAllData()
   - Fetches from local storage
   - Updates UI
    ↓
Summary screen shows fresh data!
```

## Changes Made

### 1. Added `refreshData()` Method to SummaryViewModel

**File:** `FitIQ/Presentation/ViewModels/SummaryViewModel.swift`

```swift
/// Refreshes data by syncing from HealthKit first, then reloading
/// Use this for pull-to-refresh or manual refresh actions
@MainActor
func refreshData() async {
    guard !isLoading else {
        print("SummaryViewModel: ⏭️ Skipping refresh - already in progress")
        return
    }

    print("\n🔄 SummaryViewModel.refreshData() - Syncing from HealthKit...")

    // Step 1: Sync fresh data from HealthKit
    do {
        try await processDailyHealthDataUseCase.execute()
        print("✅ HealthKit sync completed successfully")
    } catch {
        print("⚠️ HealthKit sync failed: \(error.localizedDescription)")
        // Continue to reload even if sync fails - show whatever data we have
    }

    // Step 2: Reload all data from local storage
    await reloadAllData()

    print("✅ SummaryViewModel.refreshData() - Complete\n")
}
```

**Key points:**
- Prevents multiple simultaneous refreshes with `isLoading` guard
- Syncs from HealthKit first via `processDailyHealthDataUseCase`
- Then reloads all data from local storage
- Gracefully handles errors - still shows data even if sync fails

### 2. Added `processDailyHealthDataUseCase` Dependency

**File:** `FitIQ/Presentation/ViewModels/SummaryViewModel.swift`

Added new dependency to init:
```swift
private let processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol
```

This use case handles:
- Fetching latest data from HealthKit
- Processing and saving to ActivitySnapshot
- Saving to ProgressEntry for hourly charts

### 3. Updated ViewModelAppDependencies

**File:** `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`

Added the use case to SummaryViewModel initialization:
```swift
let summaryViewModel = SummaryViewModel(
    // ... existing parameters ...
    processDailyHealthDataUseCase: appDependencies.processDailyHealthDataUseCase
)
```

### 4. Added `.refreshable` Modifier to SummaryView

**File:** `FitIQ/Presentation/UI/Summary/SummaryView.swift`

Added to the ScrollView:
```swift
ScrollView {
    VStack(spacing: 20) {
        // ... all the summary cards ...
    }
    .refreshable {
        await viewModel.refreshData()
    }
}
```

**This enables:**
- Native iOS pull-to-refresh gesture
- Shows spinning indicator while syncing
- Automatically dismisses when complete

## How to Use

### For Users

1. Open the Summary screen
2. **Pull down** at the top of the screen (like refreshing email)
3. See the spinning indicator while it syncs
4. Data updates automatically when complete

**Use cases:**
- Just finished a workout → Pull to refresh to see latest steps/heart rate
- Woke up → Pull to refresh to see last night's sleep data
- Logged weight in Health app → Pull to refresh to see it in FitIQ

### For Developers

The refresh can be triggered programmatically:
```swift
Task {
    await summaryViewModel.refreshData()
}
```

This is useful for:
- Testing data sync
- Triggering refresh after logging data manually
- Debugging HealthKit sync issues

## What Gets Synced

When you pull to refresh, the following data is synced from HealthKit:

1. **Steps** - Last 2 days (hourly granularity for charts)
2. **Heart Rate** - Last 2 days (hourly averages)
3. **Active Energy** - Today's total
4. **Basal Energy** - Today's total
5. **Body Mass** - Latest entries
6. **Height** - Latest entries
7. **Sleep** - Last night's sleep session

## Debug Logging

When you pull to refresh, check the console for:

```
🔄 SummaryViewModel.refreshData() - Syncing from HealthKit...
ProcessDailyHealthDataUseCase: Daily health data processing complete.
✅ HealthKit sync completed successfully

🔄 SummaryViewModel.reloadAllData() - STARTING DATA LOAD
============================================================
📊 Activity: Steps=15234, HeartRate=68.5
⚖️  Weight: 75.5 kg, Height: 180.0 cm
📈 Weight History: 5 entries
😊 Mood: 8 (Good)
❤️  Latest HR: 68.0 bpm
📊 Hourly HR: 8 hours of data
👣 Hourly Steps: 8 hours of data
😴 Sleep: 7.5 hrs, Efficiency: 85%
============================================================
✅ SummaryViewModel.reloadAllData() - COMPLETE

✅ SummaryViewModel.refreshData() - Complete
```

**If sync fails:**
```
⚠️ HealthKit sync failed: [error message]
```
But data will still reload from local storage, so you see whatever was previously synced.

## Benefits

1. ✅ **User control** - Refresh anytime with simple gesture
2. ✅ **Always fresh data** - Get latest from HealthKit on demand
3. ✅ **Native UX** - Standard iOS pull-to-refresh pattern
4. ✅ **Graceful errors** - Shows data even if sync fails
5. ✅ **No infinite loops** - Properly guarded with `isLoading`

## Limitations

### What Pull-to-Refresh Does NOT Fix

1. **If HealthKit has no data** - Can't sync data that doesn't exist
2. **If HealthKit permissions denied** - Can't access denied data
3. **SchemaV2 migration crash** - Still requires app deletion/reinstall
4. **Background sync** - Still needs to be configured separately

### Known Issues

- **First refresh might be slow** - HealthKit queries can take 5-10 seconds for 2 days of data
- **Multiple pulls ignored** - Second pull while first is in progress is ignored (by design)
- **No progress indicator details** - Just shows generic spinner, not what's syncing

## Future Improvements

### 1. Add Last Synced Timestamp
```swift
var lastSyncedAt: Date?

// Show in UI
Text("Last synced: \(lastSyncedAt.formatted())")
```

### 2. Show Sync Status
```swift
enum SyncStatus {
    case idle
    case syncing
    case success
    case failed(Error)
}
```

### 3. Granular Refresh
Allow refreshing individual cards instead of all data:
```swift
func refreshSteps() async { /* ... */ }
func refreshHeartRate() async { /* ... */ }
```

### 4. Automatic Background Refresh
Use iOS 15+ background refresh API to sync every hour when app is closed.

## Testing Checklist

After implementing pull-to-refresh:

- [ ] Pull down on Summary screen shows spinner
- [ ] Console logs show HealthKit sync starting
- [ ] Data updates after sync completes
- [ ] Spinner dismisses automatically
- [ ] Multiple pulls are ignored during sync
- [ ] Works with no HealthKit data (doesn't crash)
- [ ] Works with HealthKit permissions denied
- [ ] Still shows old data if sync fails

## Related Files

- `Presentation/ViewModels/SummaryViewModel.swift` - Added `refreshData()`
- `Presentation/UI/Summary/SummaryView.swift` - Added `.refreshable`
- `Infrastructure/Configuration/ViewModelAppDependencies.swift` - Wired up dependency
- `Domain/UseCases/ProcessDailyHealthDataUseCase.swift` - Syncs from HealthKit

## Summary

**Problem:** Stale data showing from hours ago  
**Solution:** Pull-to-refresh syncs latest data from HealthKit  
**Usage:** Pull down at top of Summary screen  
**Result:** Fresh data within 5-10 seconds

---

**Status:** ✅ Implemented  
**Tested:** Pending user testing after app reinstall  
**Date:** 2025-01-27