# Heart Rate Loading Issue

**Date:** 2025-01-27  
**Status:** 🔍 INVESTIGATING  
**Priority:** HIGH

---

## 🐛 Issue Summary

Heart rate data is not displaying in the SummaryView even after closing and reopening the app, while other metrics (steps, sleep, body mass) display correctly.

---

## ✅ Working Metrics

- **Body Mass** - ✅ Displays correctly from first load
- **Steps** - ✅ Displays after closing and reopening app
- **Sleep** - ✅ Displays after closing and reopening app
- **Mood** - Status unknown

## ❌ Broken Metrics

- **Heart Rate** - ❌ Remains empty even after relaunch

---

## 🔍 Architecture Review

### Heart Rate Data Flow

```
HealthKit (Heart Rate Samples)
    ↓
HeartRateSyncHandler.syncRecentHeartRateData()
    ↓
SaveHeartRateProgressUseCase.execute()
    ↓
ProgressRepository (type: .restingHeartRate)
    ↓
SwiftData (SDProgressEntry)
    ↓
GetLatestHeartRateUseCase.execute()
    ↓
SummaryViewModel.latestHeartRate
    ↓
SummaryView (FullWidthHeartRateStatCard)
```

### Code Verification

✅ All components use `.restingHeartRate` type consistently:
- `SaveHeartRateProgressUseCase` - line 74
- `GetLatestHeartRateUseCase` - line 50
- `GetLast8HoursHeartRateUseCase` - line 49

✅ Use cases follow hexagonal architecture
✅ Outbox Pattern implemented for sync
✅ Loading states added to ViewModel

---

## 🔍 Possible Root Causes

### 1. Heart Rate Not Being Synced from HealthKit
**Likelihood:** HIGH

**Symptoms:**
- Steps and sleep work (they have similar sync handlers)
- Heart rate handler may not be running or failing silently

**Check:**
- Review logs for `HeartRateSyncHandler` output
- Verify heart rate handler is registered in sync handlers array
- Check if HealthKit permissions include heart rate

**Verification:**
```swift
// In AppDependencies.swift
let syncHandlers: [HealthMetricSyncHandler] = [
    stepsSyncHandler,
    heartRateSyncHandler,  // ← Verify this is present
    sleepSyncHandler,
]
```

### 2. Heart Rate Query Failing in HealthKit
**Likelihood:** MEDIUM

**Symptoms:**
- Handler runs but HealthKit query returns no data
- Could be permission issue or data availability issue

**Check:**
- Verify HealthKit authorization includes `.heartRate` type
- Check if device has recent heart rate data (Apple Watch required)
- Review error logs from `healthRepository.getHourlyHeartRateAverages()`

### 3. Data Type Mismatch
**Likelihood:** LOW (verified all use `.restingHeartRate`)

**Check:**
- ~~Verify sync uses `.restingHeartRate`~~ ✅ VERIFIED
- ~~Verify fetch uses `.restingHeartRate`~~ ✅ VERIFIED

### 4. Fetch Logic Issue
**Likelihood:** LOW

**Symptoms:**
- Data is saved but not retrieved
- Could be query filter issue

**Check:**
```swift
// GetLatestHeartRateUseCase.swift line 50
let allEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .restingHeartRate,  // ✅ Correct
    syncStatus: nil,
    limit: 100
)
```

### 5. ViewModel Not Calling Fetch
**Likelihood:** LOW (code review shows it's called)

**Check:**
- Verify `fetchLatestHeartRate()` is called in `reloadAllData()`
- Verify `fetchLast8HoursHeartRate()` is called
- Check logs for "SummaryViewModel: ✅ Latest heart rate:" message

---

## 🧪 Diagnostic Steps

### Step 1: Check if Heart Rate Data Exists in Database

Add temporary debug code to `SummaryViewModel.fetchLatestHeartRate()`:

```swift
@MainActor
private func fetchLatestHeartRate() async {
    do {
        // DEBUG: Check ALL heart rate entries
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("❌ No userID")
            return
        }
        
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .restingHeartRate,
            syncStatus: nil,
            limit: 1000  // Get ALL
        )
        
        print("🔍 DEBUG: Total heart rate entries in DB: \(allEntries.count)")
        if !allEntries.isEmpty {
            print("🔍 First 5 entries:")
            for entry in allEntries.prefix(5) {
                print("  - \(Int(entry.quantity)) bpm at \(entry.date)")
            }
        }
        
        // Original fetch logic...
    }
}
```

**Expected Results:**
- If count = 0: Heart rate not being synced (Root Cause #1)
- If count > 0: Heart rate synced but fetch logic broken (Root Cause #4)

### Step 2: Check Heart Rate Sync Logs

Look for these log messages in console:

```
✅ Expected (if working):
HeartRateSyncHandler: 🔄 STARTING OPTIMIZED HEART RATE SYNC
HeartRateSyncHandler: Fetched X NEW hourly heart rate aggregates
HeartRateSyncHandler: ✅ [date] [time] - XXX bpm saved

❌ Problem indicators:
HeartRateSyncHandler: ⚠️ No authenticated user, skipping sync
HeartRateSyncHandler: ✅ Already synced within last hour, skipping
HeartRateSyncHandler: ✅ No new heart rate data to sync
HeartRateSyncHandler: ❌ HealthKit query failed: [error]
```

### Step 3: Check HealthKit Permissions

Verify heart rate is authorized:

```swift
// In RootTabView or elsewhere
let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
let status = healthStore.authorizationStatus(for: heartRateType)
print("Heart Rate Authorization: \(status)")
```

Expected: `.sharingAuthorized`

### Step 4: Check Device Has Heart Rate Data

- Verify user has Apple Watch paired
- Check Health app shows recent heart rate data
- If no heart rate data available, test with mock data

---

## 🔧 Potential Fixes

### If Heart Rate Not Being Synced (Root Cause #1)

**Fix:** Verify handler is registered and running

Check `AppDependencies.swift`:
```swift
let syncHandlers: [HealthMetricSyncHandler] = [
    stepsSyncHandler,
    heartRateSyncHandler,  // ← Add if missing
    sleepSyncHandler,
]
```

**Fix:** Force sync on app launch
```swift
// In RootTabView.task
try await deps.performInitialHealthKitSyncUseCase.execute(forUserID: userID)
```

### If HealthKit Query Failing (Root Cause #2)

**Fix:** Add better error handling
```swift
// In HeartRateSyncHandler
do {
    let heartRates = try await healthRepository.getHourlyHeartRateAverages(...)
    print("✅ Fetched \(heartRates.count) heart rate samples")
} catch {
    print("❌ Heart Rate Query Failed: \(error)")
    print("   Error details: \(error.localizedDescription)")
    throw error
}
```

### If Fetch Logic Issue (Root Cause #4)

**Fix:** Simplify fetch query
```swift
// Try fetching without date filter first
let allEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .restingHeartRate,
    syncStatus: nil,
    limit: 1  // Just get the latest
)
```

### If ViewModel Not Updating (Root Cause #5)

**Fix:** Ensure @MainActor and proper state updates
```swift
@MainActor
private func fetchLatestHeartRate() async {
    isLoadingHeartRate = true  // ← Ensure this is set
    defer { isLoadingHeartRate = false }  // ← Ensure this is reset
    
    // ... fetch logic
}
```

---

## 📋 Action Items

1. [ ] Add debug logging to `fetchLatestHeartRate()`
2. [ ] Check console logs for `HeartRateSyncHandler` messages
3. [ ] Verify heart rate handler is registered
4. [ ] Check HealthKit permissions in Settings app
5. [ ] Verify device has recent heart rate data
6. [ ] Test with mock data if device has no data
7. [ ] Compare with steps sync (which works) to find differences

---

## 📊 Comparison: Steps vs Heart Rate

| Aspect | Steps (Working ✅) | Heart Rate (Broken ❌) |
|--------|-------------------|----------------------|
| Sync Handler | `StepsSyncHandler` | `HeartRateSyncHandler` |
| Use Case | `SaveStepsProgressUseCase` | `SaveHeartRateProgressUseCase` |
| Entry Type | `.steps` | `.restingHeartRate` |
| Fetch Use Case | `GetDailyStepsTotalUseCase` | `GetLatestHeartRateUseCase` |
| HealthKit Type | `.stepCount` | `.heartRate` |
| Data Source | iPhone (built-in) | Apple Watch (required?) |

**Key Difference:** Heart rate requires Apple Watch, steps work on iPhone alone!

---

## 🎯 Most Likely Issue

**Hypothesis:** Heart rate data is not being synced from HealthKit, likely because:

1. **No Apple Watch paired** - Heart rate data is primarily from Apple Watch
2. **Handler not running** - HeartRateSyncHandler may not be in sync handlers array
3. **HealthKit permission denied** - User didn't grant heart rate permission

**Next Step:** Check console logs for `HeartRateSyncHandler` messages during app launch.

---

## 📝 Notes

- Steps and sleep work correctly, suggesting the overall architecture is sound
- Body mass works from first load, suggesting initial data fetch is working
- Heart rate is the only metric that remains broken after relaunch
- Issue persists across app relaunches, suggesting data is not in database

---

**Status:** Awaiting diagnostic results  
**Owner:** AI Assistant  
**Last Updated:** 2025-01-27