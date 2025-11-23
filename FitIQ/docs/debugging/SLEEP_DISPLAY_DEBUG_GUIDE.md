# Sleep Display Debug Guide

**Issue:** Sleep data in SummaryView is showing 1.1h instead of the actual sleep duration from HealthKit.

**Date:** 2025-01-27  
**Status:** Debug logging added, awaiting diagnostic data

---

## Problem Description

The `FullWidthSleepStatCard` in `SummaryView.swift` is consistently displaying **1.1 hours** of sleep, which does not match the actual sleep data synced from HealthKit.

### Expected Behavior
- Sleep duration should reflect the actual total sleep time from HealthKit (e.g., 7.5h, 8h, etc.)
- Sleep efficiency should be calculated correctly
- Display should update when new sleep data is synced

### Actual Behavior
- Sleep duration is always showing **1.1h** (which equals 66 minutes)
- This suggests either:
  1. Wrong data is being stored in the database (66 minutes)
  2. Data is being calculated incorrectly during HealthKit sync
  3. Data is being transformed incorrectly during retrieval

---

## Debug Logging Added

To diagnose this issue, comprehensive debug logging has been added to the following files:

### 1. **GetLatestSleepForSummaryUseCase.swift**
Added detailed logging of:
- Raw session data (ID, date, times)
- Time in bed (minutes and hours)
- Total sleep minutes (the critical value)
- Sleep efficiency percentage
- All sleep stages with durations
- Manual recalculation of sleep minutes from stages
- Mismatch warnings if calculated value differs from stored value

**Key Log Output:**
```
GetLatestSleepForSummaryUseCase: 🔍 DEBUG - Raw session data:
  - Session ID: [UUID]
  - Session Date: [Date]
  - Start Time: [Time]
  - End Time: [Time]
  - Time in Bed: X minutes (Y hours)
  - Total Sleep: X minutes  <-- THIS IS THE CRITICAL VALUE
  - Sleep Efficiency: X%
  - Sleep Stages Count: X
    Stage 1: [stage_type] - X min (isActualSleep: true/false)
    Stage 2: [stage_type] - X min (isActualSleep: true/false)
    ...
  - Calculated Sleep Minutes (from stages): X minutes
  - ⚠️ WARNING: Mismatch between stored totalSleepMinutes (X) and calculated (Y)
```

### 2. **SummaryViewModel.swift**
Added logging to track:
- When sleep data fetch is initiated
- What values are set in the ViewModel properties
- What will be displayed in the UI (formatted value)
- Nil value detection

**Key Log Output:**
```
SummaryViewModel: 🔍 Fetching latest sleep data...
SummaryViewModel: ✅ Latest sleep SET: X.XXh (Y mins), Z% efficiency, date: [Date]
SummaryViewModel: 🎯 Will display: 'X.Xh' in UI
```

### 3. **SwiftDataSleepRepository.swift**
Added logging to inspect:
- Raw SwiftData records before conversion
- All stored fields (ID, dates, times, minutes, efficiency)
- Sleep stages stored in the database
- Confirmation of returned domain model

**Key Log Output:**
```
SwiftDataSleepRepository: 🔍 Fetching latest session for user [UUID]
SwiftDataSleepRepository: Found X session(s) in database
SwiftDataSleepRepository: 🔍 Raw SwiftData session details:
  - ID: [UUID]
  - Date: [Date]
  - Start Time: [Time]
  - End Time: [Time]
  - Time in Bed Minutes: X
  - Total Sleep Minutes: X  <-- THIS IS WHAT'S STORED
  - Sleep Efficiency: X.X
  - Source: healthkit
  - Source ID: [UUID]
  - Stages Count: X
    Stage 1: [type] - X min
    Stage 2: [type] - X min
    ...
SwiftDataSleepRepository: ✅ Returning session with ID [UUID], X mins sleep
```

---

## Diagnostic Steps

### Step 1: Run the App and Check Console Logs

1. **Build and run the app** on a device/simulator with existing sleep data
2. **Navigate to the SummaryView**
3. **Check the Xcode console** for the debug logs

### Step 2: Analyze the Log Output

Look for these key patterns:

#### Pattern A: Data is Correct in Database
```
SwiftDataSleepRepository: Total Sleep Minutes: 480  <-- 8 hours stored correctly
GetLatestSleepForSummaryUseCase: Total Sleep: 480 minutes
SummaryViewModel: Latest sleep SET: 8.00h
SummaryViewModel: Will display: '8.0h' in UI
```
**If you see this:** The problem is in the UI layer (unlikely, but possible)

#### Pattern B: Data is Wrong in Database
```
SwiftDataSleepRepository: Total Sleep Minutes: 66  <-- 1.1 hours stored incorrectly
GetLatestSleepForSummaryUseCase: Total Sleep: 66 minutes
SummaryViewModel: Latest sleep SET: 1.10h
SummaryViewModel: Will display: '1.1h' in UI
```
**If you see this:** The problem is in the HealthKit sync (most likely)

#### Pattern C: Stages Don't Match Total
```
SwiftDataSleepRepository: Total Sleep Minutes: 66
GetLatestSleepForSummaryUseCase: Sleep Stages Count: 8
  Stage 1: core - 120 min (isActualSleep: true)
  Stage 2: deep - 90 min (isActualSleep: true)
  ...
GetLatestSleepForSummaryUseCase: Calculated Sleep Minutes (from stages): 480 minutes
⚠️ WARNING: Mismatch between stored totalSleepMinutes (66) and calculated (480)
```
**If you see this:** The stages are correct, but the total is wrong (database corruption or sync bug)

---

## Root Cause Analysis

### Hypothesis 1: HealthKit Sync Calculation Error
**Location:** `SleepSyncHandler.swift` (lines 380-395)

The sleep sync handler calculates total sleep minutes like this:
```swift
let totalSleepMinutes = stages.filter { $0.stage.isActualSleep }.reduce(0) {
    $0 + $1.durationMinutes
}
```

**Potential Issues:**
- HealthKit samples might not be providing correct duration data
- Stage filtering might be incorrect (`.isActualSleep` logic)
- Duration calculation might be wrong (time interval conversion)

**Check:** Look at the `SleepSyncHandler` logs during sync to see raw HealthKit data:
```
SleepSyncHandler: Fetched X sleep samples from HealthKit
  Sample 0: [stage_type] - X min - Source: [bundle_id]
  Sample 1: [stage_type] - X min - Source: [bundle_id]
  ...
SleepSyncHandler: Time in bed: X min, Total sleep: X min
```

### Hypothesis 2: Only First Sleep Stage Being Stored
**Symptom:** If you see 66 minutes (1.1h), this could be:
- Only the first sleep stage being saved
- Database not persisting all stages
- Stages relationship not being loaded correctly

**Check:** Count the stages in the logs:
- If stages count is 1 and duration is ~66 minutes → only first stage saved
- If stages count is >1 but total is still 66 → calculation error

### Hypothesis 3: Sample Data or Test Data
**Symptom:** If the data never changes (always exactly 1.1h)

**Check:** 
- Is this real HealthKit data or test data?
- When was the sleep session synced?
- Try triggering a manual sync of sleep data

---

## Next Steps Based on Findings

### If Database Has Wrong Data (66 minutes):

1. **Check HealthKit Sync Logs:**
   - Find the `SleepSyncHandler` logs when this session was synced
   - Look at the raw HealthKit samples
   - Check if all samples are being grouped correctly
   - Verify the total sleep calculation

2. **Re-sync Sleep Data:**
   - Delete the existing sleep session from the database
   - Trigger a new sync from HealthKit
   - Watch the logs to see the calculation happen in real-time

3. **Verify HealthKit Data Source:**
   - Open the Health app on the device
   - Check the actual sleep data for the date in question
   - Verify stages and duration match expectations

### If Database Has Correct Data but UI Shows Wrong:

1. **Check ViewModel Property Binding:**
   - Verify `latestSleepHours` is set correctly
   - Check if `@Observable` is working properly
   - Ensure SwiftUI is re-rendering the view

2. **Check UI Formatting:**
   - Verify `formattedSleepHours` in `FullWidthSleepStatCard`
   - Check string formatting logic

### If Stages Exist but Total is Wrong:

1. **Check Stage Persistence:**
   - Verify all stages are being saved to SwiftData
   - Check the relationship between `SDSleepSession` and `SDSleepStage`
   - Ensure stages are being loaded with the session

2. **Re-calculate Total:**
   - Add logic to recalculate total from stages on load
   - Update the stored value if mismatch detected

---

## Commands to Trigger Manual Sync

If you need to force a re-sync of sleep data:

```swift
// In Xcode console or through a debug button:
await healthDataSyncOrchestrator.syncSleepData(
    forDate: Date(), 
    skipIfAlreadySynced: false
)
```

Or use the "Sync All Data" button in the app (if available).

---

## Expected Log Flow (Normal Operation)

```
1. User opens SummaryView
   └─> SummaryViewModel: 🔍 Fetching latest sleep data...

2. ViewModel calls Use Case
   └─> GetLatestSleepForSummaryUseCase: Fetching latest sleep session

3. Use Case calls Repository
   └─> SwiftDataSleepRepository: 🔍 Fetching latest session for user [UUID]
   └─> SwiftDataSleepRepository: Found 1 session(s) in database
   └─> SwiftDataSleepRepository: 🔍 Raw SwiftData session details:
       - Total Sleep Minutes: 480  <-- Should be > 66
   └─> SwiftDataSleepRepository: ✅ Returning session with ID [UUID], 480 mins sleep

4. Use Case processes data
   └─> GetLatestSleepForSummaryUseCase: 🔍 DEBUG - Raw session data:
       - Total Sleep: 480 minutes
       - Sleep Efficiency: 95%
       - Sleep Stages Count: 8
   └─> GetLatestSleepForSummaryUseCase: ✅ Returning sleep data - 8.00h (480 mins), 95% efficiency

5. ViewModel updates properties
   └─> SummaryViewModel: ✅ Latest sleep SET: 8.00h (480.0 mins), 95% efficiency, date: [Date]
   └─> SummaryViewModel: 🎯 Will display: '8.0h' in UI

6. SwiftUI renders card
   └─> FullWidthSleepStatCard displays: "8.0 hours"
```

---

## Files Modified

1. **FitIQ/FitIQ/Domain/UseCases/Summary/GetLatestSleepForSummaryUseCase.swift**
   - Added comprehensive debug logging for session data and stages
   - Added manual recalculation of sleep minutes from stages
   - Added mismatch warning detection

2. **FitIQ/FitIQ/Presentation/ViewModels/SummaryViewModel.swift**
   - Added debug logging for fetch initiation
   - Added detailed logging of set values
   - Added nil value detection and logging

3. **FitIQ/FitIQ/Infrastructure/Repositories/SwiftDataSleepRepository.swift**
   - Added debug logging for raw SwiftData records
   - Added stage breakdown logging
   - Added session count verification

---

## Additional Resources

- **Sleep Sync Documentation:** `docs/api-integration/SLEEP_API_SPEC_UPDATE.md`
- **Sleep Schema:** `Infrastructure/Persistence/Schema/SCHEMA_V4_SLEEP_TRACKING.md`
- **Sleep Sync Handler:** `Infrastructure/Services/Sync/SleepSyncHandler.swift`
- **Sleep Repository:** `Infrastructure/Repositories/SwiftDataSleepRepository.swift`

---

## Quick Reference: Sleep Calculation Logic

```
Total Sleep Minutes = Sum of all stages where isActualSleep == true

isActualSleep stages:
✅ asleep (generic)
✅ asleepCore (light sleep)
✅ asleepDeep (deep sleep)
✅ asleepREM (REM sleep)

NOT isActualSleep:
❌ inBed (in bed but not asleep)
❌ awake (awake during sleep session)

Formula:
totalSleepHours = totalSleepMinutes / 60.0
sleepEfficiency = (totalSleepMinutes / timeInBedMinutes) * 100
```

---

## Contact

If you find the root cause, please update this document with:
- The actual cause of the issue
- The fix that was applied
- Any lessons learned
- Updated diagnostic steps if needed

---

**Last Updated:** 2025-01-27  
**Status:** Awaiting diagnostic data from app run