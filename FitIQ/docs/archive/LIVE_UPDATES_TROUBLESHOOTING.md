# Live Updates Troubleshooting Guide

**Date:** 2025-01-28  
**Purpose:** Debug why live updates aren't working in real-time  
**Current Issue:** Updates appear hourly instead of within seconds

---

## 🔍 Current Symptoms

- **FitIQ:** Last update 9:00 AM, 3761 steps
- **HealthKit:** Last update 9:04 AM, 3763 steps
- **Gap:** 4 minutes, 2 steps difference
- **Conclusion:** Updates are NOT happening in real-time

---

## 🧪 Debug Steps (DO THIS NOW)

### Step 1: Check If Events Are Publishing

**Search your Xcode console for these EXACT strings:**

```
SummaryViewModel: 📡 Local data change event received
```

**Results:**
- ✅ **If you SEE this log:** Events are publishing, issue is in UI refresh
- ❌ **If you DON'T see this log:** Events aren't publishing, issue is in subscription

---

### Step 2: Check If Refresh Is Being Called

**Search console for:**

```
SummaryViewModel: ⚡️ REFRESH #
```

**Results:**
- ✅ **If you SEE this log:** Refresh is being called, issue is in SwiftUI observation
- ❌ **If you DON'T see this log:** Refresh isn't being called, issue is in event handling

---

### Step 3: Check If Data Is Being Saved

**Search console for:**

```
SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor
```

**Results:**
- ✅ **If you SEE this log:** Data is being saved and notifications sent
- ❌ **If you DON'T see this log:** Data isn't being saved properly

---

### Step 4: Check Visual Debug Indicator

**Look at the TOP of SummaryView:**

You should see a yellow debug bar showing:
```
🔄 Last refresh: [TIME]  Count: [NUMBER]  Steps: [COUNT]
```

**What to check:**
1. Is the "Last refresh" time updating when you walk?
2. Is the "Count" number increasing?
3. Is the "Steps" number changing?

**Results:**
- ✅ **If ALL are updating:** SwiftUI IS detecting changes, issue is elsewhere
- ❌ **If NONE are updating:** SwiftUI is NOT detecting changes (observation issue)
- ⚠️ **If SOME are updating:** Partial observation issue

---

## 🐛 Common Issues & Solutions

### Issue 1: No Events Publishing

**Symptom:** No "Local data change event received" log

**Possible Causes:**
1. LocalDataChangePublisher not wired correctly
2. Subscription not set up in SummaryViewModel
3. LocalDataChangeMonitor not notifying

**Solution:**
Check if `setupDataChangeSubscription()` is being called in SummaryViewModel init.

**Verify:**
```swift
// SummaryViewModel.swift - in init()
setupDataChangeSubscription() // Should be here
```

---

### Issue 2: Events Publishing But No Refresh

**Symptom:** See "Local data change event received" but no "REFRESH #" log

**Possible Cause:** Switch case not matching event type

**Solution:**
Check console for the ModelType being received:
```
SummaryViewModel: 📡 Local data change event received - Type: [TYPE]
```

Should be one of: `progressEntry`, `activitySnapshot`, `physicalAttribute`

If it's something else, the switch case won't match.

---

### Issue 3: Refresh Called But UI Not Updating

**Symptom:** See "REFRESH #" logs but UI shows old data

**Possible Cause:** SwiftUI @Observable not detecting property changes

**Solution:**
This is the MOST LIKELY issue. The @Observable macro might not be tracking changes in async contexts.

**Debug Steps:**
1. Check if debug indicator at top of view updates
2. If indicator DOES update, specific cards have binding issues
3. If indicator DOESN'T update, @Observable isn't working

**Fix:** May need to use `@Published` with `ObservableObject` instead of `@Observable`

---

### Issue 4: Data Fetched But Values Same

**Symptom:** See "Fetched daily steps total: 3761 (no change)"

**Possible Cause:** Database still has old data

**Debug:**
Look for this log in GetDailyStepsTotalUseCase:
```
GetDailyStepsTotalUseCase: ✅ TOTAL: X steps from Y entries
```

**Check:**
- Are new entries being added? (Y should increase)
- Is total increasing? (X should match HealthKit)

---

## 🔧 Immediate Actions

### Action 1: Walk and Watch Console (RIGHT NOW)

1. Keep Xcode console visible
2. Walk 20 steps
3. Wait 10 seconds
4. **COPY ALL console output** and share

**What to copy:**
```
# Copy everything from:
HealthKitAdapter: OBSERVER QUERY FIRED
# to:
SummaryViewModel: ✅ REFRESH # COMPLETE
```

This will tell us EXACTLY where the flow breaks.

---

### Action 2: Check Debug Indicator

1. Look at top of SummaryView
2. Note the values:
   - Last refresh time: _______
   - Count: _______
   - Steps: _______
3. Walk 20 steps
4. Wait 10 seconds
5. Check again:
   - Last refresh time: _______ (should change)
   - Count: _______ (should increase by 1)
   - Steps: _______ (should increase)

**If NOTHING changes:** SwiftUI observation is broken.

---

### Action 3: Force Refresh Test

**Try this:**
1. Pull down on SummaryView (pull-to-refresh)
2. Check if steps update to match HealthKit

**Results:**
- ✅ **If it DOES update:** Data is there, just not auto-refreshing
- ❌ **If it DOESN'T update:** Data sync issue (separate problem)

---

## 📊 Expected vs. Actual Timeline

### Expected (What Should Happen)
```
0s:   User walks
1s:   HealthKit observer fires
2s:   Background sync starts
3s:   Data saved to SwiftData
4s:   LocalDataChangeMonitor notified
5s:   SummaryViewModel receives event
6s:   Debounce (2 seconds)
8s:   Refresh triggered
9s:   Data fetched
10s:  UI UPDATES ✅
```

### Actual (What's Happening Now)
```
0s:   User walks
1s:   HealthKit observer fires (?)
???:  Something happens...
60min: UI updates (hourly) ❌
```

**We need to find where the flow breaks!**

---

## 🎯 Next Steps Based on Console Output

### Scenario A: No Observer Log
**Log missing:** `HealthKitAdapter: OBSERVER QUERY FIRED`
**Problem:** HealthKit observer not running
**Fix:** Check if observers are started in RootTabView

### Scenario B: Observer Fires But No Sync
**Log missing:** `StepsSyncHandler: 🔄 STARTING OPTIMIZED STEPS SYNC`
**Problem:** Background sync not triggered
**Fix:** Check BackgroundSyncManager.onDataUpdate

### Scenario C: Sync Runs But No Save
**Log missing:** `SwiftDataProgressRepository: ✅ NEW ENTRY`
**Problem:** Data not being saved
**Fix:** Check deduplication logic (might be blocking saves)

### Scenario D: Save Works But No Notification
**Log missing:** `SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor`
**Problem:** Notification not sent
**Fix:** Check localDataChangeMonitor initialization

### Scenario E: Notification Sent But Not Received
**Log missing:** `SummaryViewModel: 📡 Local data change event received`
**Problem:** Subscription not working
**Fix:** Check if subscription is set up correctly

### Scenario F: Event Received But No Refresh
**Log missing:** `SummaryViewModel: ⚡️ REFRESH #`
**Problem:** Switch case not matching
**Fix:** Check ModelType in event

### Scenario G: Refresh Called But UI Frozen
**Log present:** All logs appear
**Problem:** SwiftUI @Observable not detecting changes
**Fix:** This is the critical issue - need different observation strategy

---

## 🚨 Critical Questions to Answer

1. **Do you see ANY of the new logs we added?**
   - `SummaryViewModel: 📡 Local data change event received`
   - `SummaryViewModel: ⚡️ REFRESH #X STARTED`
   - `SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor`

2. **Does the yellow debug bar at top of SummaryView show?**
   - Yes / No

3. **When you walk, does ANYTHING in the debug bar change?**
   - Last refresh time: Yes / No
   - Count: Yes / No
   - Steps: Yes / No

4. **When you pull-to-refresh manually, do steps update?**
   - Yes (to match HealthKit) / No

---

## 📝 What to Share

**Please copy and paste:**

1. **Console logs** from walking 20 steps
2. **Debug bar values** before and after walking
3. **Pull-to-refresh result** (does it update?)
4. **Answers to the 4 critical questions above**

This will tell us EXACTLY where the issue is!

---

**Status:** 🔍 DEBUGGING IN PROGRESS  
**Next:** Run the debug steps above and share results
