# Live Updates: How They Actually Work

**Last Updated:** 2025-01-28  
**Status:** Implementation complete, event-driven system

---

## How Data Flows to Summary View

```
HealthKit detects new data
    ↓ (iOS controlled, 1-5 min delay)
HealthKit Observer fires in HealthKitAdapter
    ↓
BackgroundSyncManager schedules sync (1 sec debounce)
    ↓
StepsSyncHandler fetches data from HealthKit
    ↓
SaveStepsProgressUseCase saves to database
    ↓
SwiftDataProgressRepository saves entry
    ↓
LocalDataChangeMonitor notifies of change
    ↓
LocalDataChangePublisher publishes event
    ↓
SummaryViewModel receives event (2 sec debounce)
    ↓
SummaryViewModel.refreshProgressMetrics()
    ↓
GetDailyStepsTotalUseCase reads from database
    ↓
UI updates with new total
```

---

## The Summary View is Passive

**Key Point:** `SummaryView` does NOT pull data on a timer. It is purely reactive.

### What SummaryView Does:

1. **On appear:** Loads data once from database
2. **On subscription event:** Refreshes when notified of data change
3. **On pull-to-refresh:** Manually triggers HealthKit sync + reload
4. **On sync complete:** Reloads when background sync finishes

### What SummaryView Does NOT Do:

- ❌ Poll HealthKit every X seconds
- ❌ Automatically sync on a timer
- ❌ Refresh UI on a schedule

---

## Why "No Updates for 40 Minutes"?

If the Summary hasn't updated in 40 minutes, it's because **no new data was written to the database**.

### Why No New Data?

**Most Common Reasons:**

1. **App was backgrounded**
   - iOS suspends frequent HealthKit observer callbacks
   - Background sync is limited to 15-60+ minute intervals
   - Solution: Keep app in foreground

2. **User didn't walk**
   - No new steps = HealthKit has nothing to report
   - Observers only fire when HealthKit detects changes
   - Solution: Actually walk with device

3. **HealthKit hasn't synced yet**
   - Apple Watch data takes time to sync to iPhone
   - HealthKit aggregation has its own delays
   - Solution: Wait, or open Health app to force sync

4. **Observers stopped (rare)**
   - iOS can suspend observers after long periods
   - Usually fixed by bringing app to foreground
   - Solution: Kill app and relaunch

---

## How to Verify It's Working

### Test 1: Check Console During Walk

```
1. Clear Xcode console
2. Keep FitIQ in foreground
3. Walk for 2-3 minutes
4. Wait 1-5 minutes
5. Search for: "OBSERVER QUERY FIRED"
```

**If you see it:** ✅ System is working
**If you don't:** ❌ Observers not firing (see diagnosis below)

### Test 2: Pull-to-Refresh

```
1. Pull down on Summary tab
2. Console shows: "Syncing from HealthKit"
3. Numbers update
```

**If this works:** ✅ Sync mechanism works, just observers weren't firing

---

## Expected Behavior

### Foreground (App Open and Visible)

- **Frequency:** 1-5 minutes after walking
- **Reliability:** High (iOS allows frequent observer callbacks)
- **Typical lag:** 2-6 minutes from walking to UI update

### Background (App Not Visible)

- **Frequency:** 15-60+ minutes
- **Reliability:** Low (iOS restricts background activity)
- **Typical lag:** Unpredictable

### Manual Refresh

- **Frequency:** On-demand (pull-to-refresh)
- **Reliability:** 100%
- **Typical lag:** 1-2 seconds

---

## What Was Fixed

### Fix #1: Live Update Notification Chain (Previously)
- Added event publishing when data changes
- Connected SummaryViewModel to event stream
- **Result:** UI now receives notifications when database changes

### Fix #2: Current Hour Update Logic (Latest)
- Detects when entry is for current incomplete hour
- Updates existing entry quantity instead of skipping
- Creates outbox event to sync to backend
- **Result:** Same hour gets updated as steps accumulate

### What Was NOT Broken

- ✅ Event subscription (working from day 1)
- ✅ UI refresh mechanism (working)
- ✅ Database queries (working)
- ✅ HealthKit sync (working)

### What WAS The Issue

- ❌ Deduplication logic skipped updating existing entries
- ❌ Current hour quantity never changed in database
- ❌ UI refreshed but showed old data

---

## Diagnosis Steps

### If observers aren't firing:

1. **Check console for:**
   ```
   Started observing HKQuantityTypeIdentifierStepCount
   ```
   If missing → Observers never started → Kill and relaunch app

2. **Verify app is foreground:**
   - Check if FitIQ is visible on screen
   - If backgrounded → Bring to foreground, wait 5 min

3. **Check HealthKit itself:**
   - Open iOS Health app
   - Verify steps are increasing
   - If not → HealthKit hasn't synced yet → Wait or force sync

4. **Try manual sync:**
   - Pull-to-refresh in FitIQ
   - If this works → Observers issue, not sync issue

---

## Common Misconceptions

### "Live updates should be instant"
❌ False. iOS controls HealthKit observer frequency (1-5 min typical)

### "Summary should poll HealthKit every minute"
❌ Bad design. Event-driven is better (battery, performance)

### "If no updates for 40 min, system is broken"
❌ Not necessarily. Check if user walked AND app was foreground

### "Pull-to-refresh is a workaround"
✅ Correct. It's the manual fallback when automatic doesn't trigger

---

## Bottom Line

**The system works like this:**

1. HealthKit detects changes → Fires observer (iOS controlled timing)
2. Observer triggers sync → Data written to database
3. Database write fires event → SummaryViewModel receives it
4. SummaryViewModel refreshes → UI shows new data

**If step 1 doesn't happen, nothing else happens.**

**To test:** Walk, keep app foreground, wait 5 minutes, check console.

**To force:** Pull-to-refresh (always works, regardless of observers).

---

**See Also:**
- `SIMPLE_DIAGNOSIS.md` - 5-minute test to verify observers
- `CURRENT_HOUR_LIVE_UPDATE_FIX.md` - Technical details of latest fix
- `BUILD_STATUS.md` - Current implementation status