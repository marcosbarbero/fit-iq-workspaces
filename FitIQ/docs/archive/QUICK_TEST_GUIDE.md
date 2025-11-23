# Quick Test Guide - Live Updates

**Date:** 2025-01-28  
**Purpose:** Quick steps to verify live updates are working

---

## 🚀 Quick Start

### 1. Clean Install
```bash
# Delete app from device/simulator
# Then build and run
```

### 2. Watch Console for These Key Logs

After walking or shaking device to simulate steps:

```
✅ GOOD SIGNS (What you want to see):

[1] HealthKitAdapter: OBSERVER QUERY FIRED for type: stepCount
[2] StepsSyncHandler: 🔄 STARTING OPTIMIZED STEPS SYNC
[3] SwiftDataProgressRepository: 🔍 DEDUPLICATION CHECK
[4] SwiftDataProgressRepository: ✅ NEW ENTRY - No duplicate found
[5] SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor
[6] SummaryViewModel: 📡 Local data change event received
[7] SummaryViewModel: ⚡️ Fast refresh of progress metrics
[8] SummaryViewModel: ✅ Progress metrics refresh complete
```

```
❌ BAD SIGNS (What you DON'T want to see):

- "DUPLICATE PREVENTED" on first sync (means duplicates exist)
- No "Local data change event received" (subscription not working)
- No "Fast refresh of progress metrics" (refresh not triggering)
- Steps count doesn't update within 10 seconds
```

---

## 🧪 Quick Tests

### Test 1: Basic Live Update (2 minutes)
1. Open app → SummaryView
2. Note current step count
3. Walk 50+ steps OR shake device
4. Wait 5 seconds
5. **PASS:** Step count updated automatically
6. **FAIL:** Step count still shows old number

### Test 2: No Duplicates (30 seconds)
1. Check current steps in FitIQ
2. Check current steps in iOS Health app
3. **PASS:** Numbers match (±2 steps)
4. **FAIL:** FitIQ shows more than Health app

### Test 3: Multiple Updates (1 minute)
1. Start at SummaryView
2. Walk 20 steps → wait 5 seconds → check (should update)
3. Walk 20 more steps → wait 5 seconds → check (should update again)
4. Walk 20 more steps → wait 5 seconds → check (should update again)
5. **PASS:** All 3 updates show
6. **FAIL:** Any update doesn't show

---

## 🔍 Console Log Filters

### Filter 1: Live Update Events
```
SummaryViewModel: 📡
SummaryViewModel: ⚡️
SummaryViewModel: ✅ Progress metrics
```

### Filter 2: Duplicate Detection
```
SwiftDataProgressRepository: 🔍 DEDUPLICATION
SwiftDataProgressRepository: ⏭️ ✅ DUPLICATE PREVENTED
SwiftDataProgressRepository: ✅ NEW ENTRY
```

### Filter 3: Sync Activity
```
StepsSyncHandler: 🔄
StepsSyncHandler: ✅ Saved:
StepsSyncHandler: ⏭️  Skipped:
```

---

## ✅ Success Checklist

- [ ] Steps update automatically within 5 seconds
- [ ] Heart rate updates automatically (if available)
- [ ] No duplicates (FitIQ matches Health app)
- [ ] Console shows "Local data change event received"
- [ ] Console shows "Fast refresh of progress metrics"
- [ ] Console shows "NEW ENTRY" (not "DUPLICATE PREVENTED" on first sync)

---

## 🐛 If Something's Wrong

### Issue: UI doesn't update
**Check console for:**
```
SummaryViewModel: 📡 Local data change event received
```
- If missing: Subscription not working
- If present: UI binding issue

### Issue: Steps don't match Health app
**Check console for:**
```
SwiftDataProgressRepository: ⏭️ ✅ DUPLICATE PREVENTED
```
- If you see this on fresh install: Something's wrong
- If you see "NEW ENTRY": Deduplication working correctly

### Issue: Updates take 30+ seconds
**Check console for:**
```
BackgroundSyncManager: Debounce finished
```
- Should happen within 1-2 seconds
- If longer: Background task delayed by iOS

---

## 📊 Expected Timeline

```
0s:   User walks
1s:   HealthKit observer fires
2s:   Background sync starts
3s:   Data saved to SwiftData
4s:   LocalDataChangeMonitor notified
5s:   SummaryViewModel refreshes
      ✅ UI UPDATES
```

**Total time: 2-5 seconds** (acceptable)

---

## 🎯 Bottom Line

**If you see these 3 things, it's working:**

1. ✅ Console: "Local data change event received"
2. ✅ Console: "Fast refresh of progress metrics"
3. ✅ UI: Steps count updates within 5 seconds

**If any are missing, something's broken.**

---

**Quick troubleshooting:**
- Clean build (Cmd+Shift+K)
- Delete app and reinstall
- Check background refresh is enabled in iOS Settings
- Check HealthKit permissions are granted