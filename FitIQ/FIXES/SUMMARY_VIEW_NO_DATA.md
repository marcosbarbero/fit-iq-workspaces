# SummaryView Shows No Data After Login

## Problem

After logging into the FitIQ app, the SummaryView displays no data for:
- Steps (shows 0)
- Heart Rate (shows "--")
- Sleep (shows "No data")
- Only Mood card might show data if manually logged

## Root Cause

The app relies on **two separate data sources** for the Summary view:

1. **ActivitySnapshot** (SwiftData) - For real-time activity data
2. **Progress Tracking** (SwiftData) - For hourly charts and historical data

Both data sources are populated by syncing from **HealthKit**, which happens via:
- `PerformInitialHealthKitSyncUseCase` (runs once after login)
- `HealthDataSyncManager` (runs daily in background)
- `BackgroundSyncManager` (observes HealthKit changes)

### Why Data Might Be Missing

1. **Initial sync hasn't completed yet**
   - The sync runs asynchronously after login
   - For 30 days of data, it takes ~10-15 seconds
   - User might navigate to Summary before sync completes

2. **HealthKit doesn't have data**
   - Physical device might not have steps/heart rate/sleep data recorded
   - User might not wear Apple Watch
   - Health app permissions might be denied for specific data types

3. **Database crash during sync** (SchemaV2 issue)
   - If the old database exists, sync might crash
   - Data is never populated
   - Requires app deletion and reinstall

4. **Progress tracking not populated**
   - `GetLast8HoursStepsUseCase` fetches from `ProgressRepository`
   - If HealthDataSyncManager hasn't synced to progress tracking yet, cards show no data
   - This is separate from `ActivitySnapshot` which might have data

## How Data Flow Works

```
HealthKit (iOS)
    ↓
PerformInitialHealthKitSyncUseCase (on login)
    ↓
HealthDataSyncManager.performInitialSync()
    ↓
├─→ ProcessDailyHealthDataUseCase (for each day)
│       ↓
│   ActivitySnapshot (SwiftData) → SummaryView.stepsCount
│
└─→ SaveStepsProgressUseCase (hourly data)
        ↓
    ProgressEntry (SwiftData) → SummaryView.last8HoursStepsData
```

**Key Insight:** The Summary view needs BOTH:
- ActivitySnapshot for total steps count
- ProgressEntry for hourly chart data

## Diagnosis Steps

### 1. Check if Initial Sync Ran

After login, check console logs for:

```
✅ PerformInitialHealthKitSyncUseCase: Initial sync completed successfully
```

If you see this, sync completed. If not, sync might have crashed or is still running.

### 2. Check What Data Was Loaded

With the new debug logging added to `SummaryViewModel.reloadAllData()`, you'll see:

```
🔄 SummaryViewModel.reloadAllData() - STARTING DATA LOAD
============================================================
📊 Activity: Steps=12543, HeartRate=72.5
⚖️  Weight: 75.5 kg, Height: 180.0 cm
📈 Weight History: 5 entries
😊 Mood: 8 (Good)
❤️  Latest HR: 75.0 bpm
📊 Hourly HR: 8 hours of data
👣 Hourly Steps: 8 hours of data
😴 Sleep: 7.5 hrs, Efficiency: 85%
============================================================
✅ SummaryViewModel.reloadAllData() - COMPLETE
```

**If all values are `nil` or `0`**, then:
- HealthKit sync hasn't populated data yet
- Or HealthKit doesn't have data to sync

### 3. Check HealthKit Permissions

In Settings → Health → Data Access & Devices → FitIQ, verify that ALL permissions are enabled:
- ✅ Steps
- ✅ Heart Rate
- ✅ Sleep Analysis
- ✅ Body Mass
- ✅ Height

### 4. Check if HealthKit Has Data

Open the Health app on your iPhone and verify that data exists:
- Activity → Steps (should show step count for today)
- Heart → Heart Rate (should show recent measurements)
- Sleep → Sleep Analysis (should show sleep sessions)

**If Health app shows no data**, then there's nothing for FitIQ to sync!

## Solutions

### Solution 1: Wait for Initial Sync to Complete (Recommended)

After logging in:
1. Stay on the Summary view for 15-30 seconds
2. Initial sync runs in background
3. Data will appear automatically when sync completes
4. Look for console log: `✅ Initial sync completed successfully`

### Solution 2: Delete and Reinstall App (If SchemaV2 Crash)

If you're experiencing the SchemaV2 migration crash:
1. **Delete the FitIQ app from your iPhone** (long-press icon → Remove App)
2. **Reinstall from Xcode**
3. Log in again
4. Wait 30 seconds for initial sync
5. Data should appear

This creates a fresh SchemaV4 database without migration issues.

### Solution 3: Add Test Data Manually

For testing when HealthKit has no data, add test entries:

**Steps:**
1. Tap "Quick Log" button (if available)
2. Manually log steps for today
3. This creates a ProgressEntry that appears in hourly chart

**Mood:**
1. Tap Mood card → "+" button
2. Log mood for today
3. Mood card will show the entry

**Weight:**
1. Tap Body Mass card → "+" button
2. Log weight for today
3. Weight card will show the entry and mini-graph

### Solution 4: Trigger Manual Re-sync (Debug)

If data exists in HealthKit but not showing:
1. Navigate to Body Mass Detail view
2. Scroll down to "Developer Tools" section
3. Tap "Clean Up & Re-sync HealthKit Data"
4. Wait 30 seconds for re-sync to complete
5. Return to Summary view - data should appear

**Note:** This only works AFTER you've deleted the app and reinstalled (to avoid SchemaV2 crash).

## Prevention

### For Future Development

1. **Add Loading Indicator**
   - Show progress spinner during initial sync
   - Display "Syncing your health data..." message
   - Prevent user confusion

2. **Add Empty State UI**
   - Show helpful message when no data: "No steps recorded today. Start moving!"
   - Provide "Sync Now" button to trigger manual sync
   - Show onboarding if HealthKit permissions denied

3. **Add Pull-to-Refresh**
   - Allow user to manually refresh data
   - Triggers `reloadAllData()` on demand
   - Provides feedback that sync is happening

4. **Improve Sync Status**
   - Show "Last synced: 5 minutes ago" timestamp
   - Display sync status icon (syncing/synced/error)
   - Alert user if sync fails

### Example Empty State

```swift
if viewModel.stepsCount == 0 && !viewModel.isLoading {
    VStack {
        Image(systemName: "figure.walk")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
        Text("No Steps Recorded")
            .font(.headline)
        Text("Start moving to see your activity!")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        if !viewModel.hasHealthKitAccess {
            Button("Enable HealthKit") {
                // Trigger HealthKit authorization
            }
        }
    }
}
```

## Technical Details

### Use Cases Involved

1. **GetLatestActivitySnapshotUseCase**
   - Fetches today's ActivitySnapshot (total steps, avg heart rate)
   - Used for: Step count badge

2. **GetLast8HoursStepsUseCase**
   - Fetches hourly ProgressEntry records for last 8 hours
   - Used for: Hourly steps bar chart
   - **CRITICAL:** Requires `ProgressEntry` with `time` field populated

3. **GetLast8HoursHeartRateUseCase**
   - Fetches hourly ProgressEntry records for heart rate
   - Used for: Hourly heart rate chart

4. **GetLatestSleepForSummaryUseCase**
   - Fetches most recent sleep session
   - Used for: Sleep card (hours, efficiency)

5. **GetLatestHeartRateUseCase**
   - Fetches most recent heart rate entry
   - Used for: Latest heart rate display

### Data Models

**ActivitySnapshot:**
```swift
@Model
final class SDActivitySnapshot {
    var id: UUID
    var userProfile: SDUserProfile?
    var date: Date
    var steps: Int = 0
    var heartRateAvg: Double?
    // ...
}
```

**ProgressEntry:**
```swift
struct ProgressEntry {
    var id: UUID
    var userID: String
    var type: ProgressType  // .steps, .heartRate, etc.
    var quantity: Double
    var date: Date
    var time: String?  // HH:mm format for hourly grouping
    var syncStatus: SyncStatus
}
```

### Why Time Field Matters

The `GetLast8HoursStepsUseCase` filters entries where `time != nil`:

```swift
let recentEntries = allEntries.filter { entry in
    entry.date >= last8HoursStart && entry.time != nil  // ← CRITICAL
}
```

If `HealthDataSyncManager` doesn't populate the `time` field when syncing hourly data, the charts will be empty even if progress entries exist.

## Summary

**The most common reason for missing data is:**
1. ✅ **App just logged in** → Wait 30 seconds for initial sync
2. ✅ **HealthKit has no data** → Use Apple Watch or manually log data
3. ✅ **SchemaV2 database crash** → Delete app and reinstall

**Check the new debug logs** added to `SummaryViewModel.reloadAllData()` to see exactly what data is being loaded (or not loaded).

**After reinstalling the app with a fresh database, all data should appear within 30 seconds of login.**

---

**Status:** Diagnosed  
**Next Steps:** Delete app, reinstall, check debug logs  
**Date:** 2025-01-27