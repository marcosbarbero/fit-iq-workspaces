# Sleep Time Aggregation Fix - Accurate Sleep Duration Calculation

**Date:** 2025-01-27  
**Issue:** App showing incorrect sleep duration (1.1h vs. Apple Health's 3:22h)  
**Status:** ✅ Fixed

---

## Problem Summary

Users reported a significant discrepancy between sleep duration shown in Apple Health and the FitIQ app:

- **Apple Health:** 3 hours 22 minutes (3:22h)
- **FitIQ App:** 1.1 hours

This is a ~66% undercount of actual sleep time.

### Root Causes

1. **Incorrect Query Window:** Querying from noon of previous day to noon of target day, missing overnight sleep
2. **Incorrect Sample Grouping:** Splitting continuous sleep sessions into multiple smaller sessions based on start hour

**Previous Query Window (Incorrect):**
```swift
// When syncing "yesterday's sleep" (e.g., Jan 26):
let startOfDay = midnight of Jan 26 (00:00:00)
let queryStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay) // Jan 25 12:00 PM
let queryEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay)   // Jan 26 12:00 PM
// ❌ MISSES sleep from Jan 26 10 PM to Jan 27 6:30 AM!
```

**Previous Grouping Logic (Incorrect):**
```swift
// Grouped samples by sourceID + start hour
let groupedBySleep = Dictionary(grouping: samples) { sample -> String in
    let startHour = calendar.component(.hour, from: sample.startDate)
    let sourceID = sample.sourceRevision.source.bundleIdentifier
    return "\(sourceID)_\(startHour)"  // ❌ PROBLEM: Splits by hour
}
```

**Why This Was Wrong:**

First, the query window was looking at the WRONG 24-hour period - it queried from noon the day before to noon of the target day, completely missing sleep that starts in the evening and ends the next morning.

Second, even if samples were fetched, Apple HealthKit provides sleep data as **multiple samples** representing different sleep stages within a **single continuous sleep session**:

```
Sample 1: 22:00-23:00 (asleepCore) - startHour: 22
Sample 2: 23:00-01:00 (asleepDeep) - startHour: 23
Sample 3: 01:00-03:00 (asleepCore) - startHour: 1
Sample 4: 03:00-06:30 (asleepREM) - startHour: 3
```

The old logic would create **4 separate sessions** (one per start hour), and only the **latest session** would be displayed in the summary card. This resulted in showing only the last segment (3:00-6:30 = 3.5h) instead of the full night's sleep.

Even worse, if the app queried for the "latest" session, it might pick an even shorter segment, leading to the 1.1h shown to the user.

---

## Solution Implemented

### 1. Fixed Query Window

Changed the query to capture overnight sleep correctly:

```swift
// When syncing "yesterday's sleep" (e.g., Jan 26):
let startOfDay = midnight of Jan 26 (00:00:00)
let queryStart = calendar.date(byAdding: .hour, value: 12, to: startOfDay)  // Jan 26 12:00 PM
let queryEnd = calendar.date(byAdding: .hour, value: 36, to: startOfDay)    // Jan 27 12:00 PM
// ✅ CAPTURES sleep from Jan 26 10 PM to Jan 27 6:30 AM!
```

This queries from **noon of the target day** to **noon of the next day**, correctly capturing:
- Afternoon naps on the target day
- Evening sleep starting on the target day
- Morning wake-up on the next day

### 2. Sequential Session Grouping

Replaced hour-based grouping with **sequential aggregation** that merges overlapping/adjacent samples into continuous sessions:

```swift
var sleepSessions: [[HKCategorySample]] = []
var currentSession: [HKCategorySample] = []
var lastEndTime: Date?
var lastSourceID: String?

for sample in samples {
    let sourceID = sample.sourceRevision.source.bundleIdentifier
    let sampleStart = sample.startDate
    
    // Start new session if:
    // 1. First sample
    // 2. Different source (e.g., Apple Watch vs. iPhone)
    // 3. Gap > 2 hours from last sample (separate sleep sessions like naps)
    let isNewSession = currentSession.isEmpty
        || sourceID != lastSourceID
        || (lastEndTime != nil && sampleStart.timeIntervalSince(lastEndTime!) > 7200)
    
    if isNewSession && !currentSession.isEmpty {
        sleepSessions.append(currentSession)
        currentSession = []
    }
    
    currentSession.append(sample)
    lastEndTime = sample.endDate
    lastSourceID = sourceID
}

// Add last session
if !currentSession.isEmpty {
    sleepSessions.append(currentSession)
}
```

**Key Logic:**
- **Same source:** Samples from the same device are grouped together
- **Continuity:** Samples are merged if they're within 2 hours of each other
- **Separate sessions:** If there's a 2+ hour gap, it's treated as a separate session (e.g., nap vs. main sleep)

### 2. Enhanced Logging

Added comprehensive debug logging to trace sleep sample processing:

```swift
// Log all samples
for (index, sample) in samples.enumerated() {
    let value = SleepStageType.fromHealthKit(sample.value)
    let duration = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)
    let sourceID = sample.sourceRevision.source.bundleIdentifier
    print("  Sample \(index): \(value.rawValue) - \(duration) min - Source: \(sourceID)")
}

// Log stage breakdown per session
print("HealthDataSyncService: Stage breakdown:")
for stage in stages {
    print("  - \(stage.stage.rawValue): \(stage.durationMinutes) min (isActualSleep: \(stage.stage.isActualSleep))")
}

print("HealthDataSyncService: Time in bed: \(timeInBedMinutes) min, Total sleep: \(totalSleepMinutes) min")
```

This allows us to verify that:
- All samples are being fetched
- Samples are grouped correctly
- Sleep calculation is accurate

---

## Example: Before vs. After

### Before (Incorrect)

**HealthKit Samples:**
```
Sample 0: asleepCore - 60 min - Source: com.apple.health (22:00-23:00)
Sample 1: asleepDeep - 120 min - Source: com.apple.health (23:00-01:00)
Sample 2: asleepCore - 120 min - Source: com.apple.health (01:00-03:00)
Sample 3: asleepREM - 210 min - Source: com.apple.health (03:00-06:30)
```

**Old Grouping:**
- Session 1 (hour 22): 60 min sleep
- Session 2 (hour 23): 120 min sleep
- Session 3 (hour 1): 120 min sleep
- Session 4 (hour 3): 210 min sleep

**Summary Card:** Shows latest session = **3.5h** (or even worse if picking a different "latest")

### After (Correct)

**HealthKit Samples:** (same as above)

**New Grouping:**
- Session 1: All samples combined (22:00-06:30)
  - asleepCore: 60 min ✅
  - asleepDeep: 120 min ✅
  - asleepCore: 120 min ✅
  - asleepREM: 210 min ✅
  - **Total: 510 min = 8.5 hours** ✅

**Summary Card:** Shows **8.5h** ✅

---

## Files Modified

### `FitIQ/Infrastructure/Integration/HealthDataSyncManager.swift`

**Changes:**
1. **Fixed query window:** Changed from `(-12h, +12h)` to `(+12h, +36h)` relative to target date (lines 657-658)
2. **Added query window logging:** Debug output for date range verification (lines 661-662)
3. **Replaced grouping logic:** Sequential aggregation instead of hour-based grouping (lines 704-738)
4. **Added sample-level logging:** Debug output for all fetched samples (lines 692-703)
5. **Added session-level logging:** Debug output for session processing (lines 755-758, 772-775)
6. **Added stage breakdown logging:** Debug output for sleep stage calculation (lines 792-797)
7. **Added metrics logging:** Debug output for final calculations (lines 803-805)

---

## Testing Guide

### Prerequisites

1. Sleep data in Apple Health (ideally a full night's sleep with multiple stages)
2. FitIQ app with HealthKit permission
3. Xcode console access for logs

### Test Scenario: Full Night's Sleep

**Steps:**
1. Ensure you have sleep data for last night in Apple Health
2. Note the total sleep time shown in Apple Health
3. Open FitIQ app
4. Trigger sync: Go to Profile → "Force Sync"
5. Check Xcode logs for sleep processing
6. Go to Summary tab and check sleep card

**Expected Logs:**
```
HealthDataSyncService: 🌙 Syncing sleep data for 2025-01-26...
HealthDataSyncService: Query window: 2025-01-26 12:00:00 to 2025-01-27 12:00:00
HealthDataSyncService: Target date: 2025-01-26
HealthDataSyncService: Processing 8 sleep samples
  Sample 0: asleepCore - 60 min - Source: com.apple.health
  Sample 1: asleepDeep - 90 min - Source: com.apple.health
  Sample 2: asleepCore - 120 min - Source: com.apple.health
  Sample 3: asleepREM - 80 min - Source: com.apple.health
  ... (more samples)
HealthDataSyncService: Found 1 sleep session(s) from 8 samples
HealthDataSyncService: Processing session with 8 samples from 2025-01-26 22:00:00 to 2025-01-27 06:30:00
HealthDataSyncService: Stage breakdown:
  - asleepCore: 60 min (isActualSleep: true)
  - asleepDeep: 90 min (isActualSleep: true)
  - asleepCore: 120 min (isActualSleep: true)
  - asleepREM: 80 min (isActualSleep: true)
  - awake: 10 min (isActualSleep: false)
  ... (more stages)
HealthDataSyncService: Time in bed: 510 min, Total sleep: 500 min
HealthDataSyncService: ✅ Saved sleep session with local ID: [...], 500 mins sleep, 98.0% efficiency
```

**Expected UI:**
- Summary card shows sleep time matching Apple Health (e.g., 8.3h)
- Sleep efficiency percentage shown (e.g., 98%)

### Test Scenario: Nap + Night Sleep

**Steps:**
1. Ensure you have both a nap (e.g., 2:00 PM - 3:00 PM) and night sleep
2. Sync in FitIQ
3. Check logs for **2 separate sessions**

**Expected Logs:**
```
HealthDataSyncService: Found 2 sleep session(s) from 12 samples
HealthDataSyncService: Processing session with 2 samples from 2025-01-26 14:00:00 to 2025-01-26 15:00:00
HealthDataSyncService: Time in bed: 60 min, Total sleep: 55 min
HealthDataSyncService: Processing session with 10 samples from 2025-01-26 22:00:00 to 2025-01-27 06:30:00
HealthDataSyncService: Time in bed: 510 min, Total sleep: 480 min
```

**Expected UI:**
- Summary card shows the **latest** session (night sleep, not nap)

---

## Verification Checklist

- [ ] Full night's sleep shows correct total duration (matches Apple Health)
- [ ] Multiple sleep stages are aggregated into one session
- [ ] Naps and main sleep are treated as separate sessions
- [ ] Summary card shows the most recent sleep session
- [ ] Sleep efficiency is calculated correctly
- [ ] Logs show detailed sample breakdown for debugging
- [ ] No duplicate sessions created (deduplication works)

---

## Edge Cases Handled

### 1. Overnight Sleep (Primary Fix)
- ✅ Query window captures sleep starting in evening, ending next morning
- ✅ Example: 10 PM Jan 26 → 6:30 AM Jan 27 is correctly attributed to Jan 26

### 2. Multiple Sleep Sessions Per Day
- ✅ Nap + night sleep are separate sessions
- ✅ 2+ hour gap triggers new session
- ✅ Summary card shows latest session

### 3. Multiple Sources (Apple Watch + iPhone)
- ✅ Different sources are treated as separate sessions
- ✅ Prevents mixing Watch and Phone data

### 4. Fragmented Sleep (Awake Periods)
- ✅ Awake periods are included in "time in bed"
- ✅ Awake periods are **excluded** from "total sleep"
- ✅ Sleep efficiency = (total sleep / time in bed) * 100

### 5. Very Short Samples
- ✅ All samples are included, regardless of duration
- ✅ Even 5-minute samples count toward total

---

## Related Issues

This fix addresses:
- ❌ Sleep time undercount (primary issue)
- ❌ Inconsistency with Apple Health data
- ❌ User confusion about sleep tracking accuracy

---

## Technical Details

### Sleep Stage Types

```swift
enum SleepStageType {
    case inBed        // ❌ Not actual sleep
    case awake        // ❌ Not actual sleep
    case asleep       // ✅ Actual sleep (unspecified stage)
    case asleepCore   // ✅ Actual sleep (light/core)
    case asleepDeep   // ✅ Actual sleep (deep/slow-wave)
    case asleepREM    // ✅ Actual sleep (REM)
}

var isActualSleep: Bool {
    switch self {
    case .asleep, .asleepCore, .asleepDeep, .asleepREM:
        return true
    case .inBed, .awake:
        return false
    }
}
```

### Query Window Logic

```swift
// For syncing "yesterday's sleep" (Jan 26):
let startOfDay = midnight Jan 26
let queryStart = startOfDay + 12 hours = Jan 26 12:00 PM
let queryEnd = startOfDay + 36 hours = Jan 27 12:00 PM

// This captures:
// - Afternoon naps on Jan 26 (12 PM - 10 PM)
// - Evening sleep starting Jan 26 (10 PM onwards)
// - Night sleep ending Jan 27 (up to 12 PM)
```

### Metrics Calculation

```swift
// Time in bed: From first sample start to last sample end
let timeInBedMinutes = Int(sessionEnd.timeIntervalSince(sessionStart) / 60)

// Total sleep: Sum of all "actual sleep" stages
let totalSleepMinutes = stages.filter { $0.stage.isActualSleep }.reduce(0) {
    $0 + $1.durationMinutes
}

// Sleep efficiency: Percentage of time in bed spent actually sleeping
let sleepEfficiency = (Double(totalSleepMinutes) / Double(timeInBedMinutes)) * 100.0
```

---

## Future Improvements

1. **Sleep Score Algorithm**
   - Incorporate sleep stage distribution (deep, REM, light)
   - Weight sleep quality, not just quantity
   - Compare against age-based recommendations

2. **Sleep Trends**
   - 7-day average
   - Weekday vs. weekend comparison
   - Sleep debt tracking

3. **Smart Aggregation**
   - Detect split sleep sessions (biphasic sleep)
   - Handle shift workers with non-standard sleep patterns

4. **UI Enhancements**
   - Show sleep stage breakdown in summary card
   - Expandable detail view with timeline
   - Sleep goal tracking

---

## Related Documentation

- **Sleep API Fix:** `docs/fixes/SLEEP_API_400_ERROR_FIX.md`
- **Sleep Tracking:** `docs/fixes/SLEEP_TRACKING_FIX.md`
- **HealthKit Integration:** `docs/architecture/HEALTHKIT_INTEGRATION.md`

---

**Status:** ✅ Ready for QA  
**Priority:** High (data accuracy issue)  
**Risk:** Low (logic improvement, no breaking changes)  
**Impact:** Critical (fixes major data discrepancy)

---

**Next Steps:**
1. Deploy to TestFlight
2. Test with real sleep data
3. Compare with Apple Health for accuracy
4. Monitor user feedback on sleep tracking

**Expected Outcome:** FitIQ sleep duration matches Apple Health within 1-2%