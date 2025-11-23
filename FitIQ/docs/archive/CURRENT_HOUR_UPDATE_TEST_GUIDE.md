# Quick Test Guide: Current Hour Update Fix

**Purpose:** Verify that FitIQ now updates step counts in real-time for the current incomplete hour  
**Time Required:** 5-10 minutes  
**Prerequisites:** iPhone with FitIQ installed, ability to walk/move

---

## Quick Test (5 minutes)

### Setup
1. Open FitIQ app
2. Navigate to Summary tab
3. Note current step count (e.g., "4913 steps")
4. Open iOS Health app
5. Note HealthKit step count (should match or be slightly higher)

### Test Steps

**Step 1: Create baseline**
- Stand still for 30 seconds
- Note both FitIQ and HealthKit step counts
- They should match (or be within 50 steps)

**Step 2: Walk and observe**
- Walk around for 2-3 minutes (~200-300 steps)
- Return to device
- Open iOS Health app first → Note new step count (e.g., "5200 steps")
- Switch to FitIQ app
- **Wait 1-5 minutes** (HealthKit sync delay is normal)

**Step 3: Verify auto-update**
- Watch the Summary tab
- Within 1-5 minutes, the step count should UPDATE automatically
- You'll see the yellow debug bar show a new refresh count
- FitIQ should now match HealthKit (within 1-2 minutes)

### Expected Results

✅ **PASS:** FitIQ updates automatically to match HealthKit without manual refresh  
❌ **FAIL:** FitIQ stays at old count, only updates when you pull-to-refresh

---

## Detailed Test (10 minutes)

### Test 1: Multiple Updates in Same Hour

**Goal:** Verify FitIQ updates multiple times within the same hour

1. **At start of new hour (e.g., 2:00 PM):**
   - Open FitIQ, note steps for current hour
   
2. **Walk 100 steps:**
   - Walk around for 1 minute
   - Wait 2-3 minutes
   - Check FitIQ → Should show ~100 new steps
   
3. **Walk another 200 steps:**
   - Walk around for 2 minutes
   - Wait 2-3 minutes
   - Check FitIQ → Should show ~300 total new steps (not just 100)
   
4. **Walk another 150 steps:**
   - Walk around for 1.5 minutes
   - Wait 2-3 minutes
   - Check FitIQ → Should show ~450 total new steps (not 300)

**Expected:** Each time, FitIQ updates the SAME hour's total, not creates duplicates

---

## What to Check in Logs

### Open Xcode Console

**Filter for:** `SwiftDataProgressRepository`

### Success Indicators

**When sync runs, you should see:**

```
SwiftDataProgressRepository: 🔍 DEDUPLICATION CHECK
  Existing quantity: 213.0
  New quantity: 526.0
  Existing backendID: abc-123-def

SwiftDataProgressRepository: 🔄 UPDATING current hour quantity: 213.0 → 526.0
SwiftDataProgressRepository: 🔄 Marked existing entry as pending sync due to quantity update
SwiftDataProgressRepository: ✅ Created outbox event XXX for updated current hour entry
SwiftDataProgressRepository: ✅ Successfully updated current hour quantity
SwiftDataProgressRepository: 📡 Notified LocalDataChangeMonitor of UPDATED entry
```

**Then UI refresh:**

```
SummaryViewModel: 📡 Local data change event received - Type: progressEntry
SummaryViewModel: 🔄 Progress entry changed, refreshing relevant metrics...
GetDailyStepsTotalUseCase: ✅ TOTAL: 5176 steps from 7 entries
SummaryViewModel: ✅ Fetched daily steps total: 5176 (was 4863, changed by 313)
```

### Failure Indicators

**If you see this, the fix is NOT working:**

```
SwiftDataProgressRepository: ⏭️ ✅ DUPLICATE PREVENTED
# Missing: "UPDATING current hour quantity"
# Missing: "changed by XXX"
```

---

## Troubleshooting

### "FitIQ still shows old count"

**Possible causes:**

1. **HealthKit sync hasn't run yet**
   - Wait 1-5 minutes (this is normal iOS behavior)
   - HealthKit observers have built-in debounce
   
2. **App is in background**
   - Bring app to foreground
   - Background syncs are limited by iOS
   
3. **HealthKit permissions issue**
   - Go to Settings → Health → Data Access & Devices → FitIQ
   - Verify "Steps" is enabled

### "Logs don't show update message"

**Check:**

1. Are you walking during the CURRENT hour?
   - Fix only applies to incomplete current hour
   - Complete past hours won't update (correct behavior)
   
2. Did quantity actually change?
   - Need at least 1 step difference to trigger update
   
3. Is deduplication check running?
   - If you don't see "DEDUPLICATION CHECK", entry is new (not updating existing)

### "Numbers update but don't match HealthKit"

**This is normal if:**

1. **Sync delay (1-5 minutes)**
   - iOS controls HealthKit sync frequency
   - Can't make it faster than Apple allows
   
2. **Multiple sources**
   - If you have other apps writing steps
   - HealthKit aggregates all sources
   - FitIQ only syncs its own understanding

---

## Manual Verification

### Force a sync

**Pull-to-refresh:**
1. On Summary tab, pull down to refresh
2. Should immediately fetch latest data
3. FitIQ should match HealthKit within seconds

**This proves:**
- Sync mechanism works
- Data retrieval works
- Issue is auto-update timing (if discrepancy persists)

---

## Success Criteria

### ✅ Test Passes If:

1. **Auto-update works:** FitIQ updates without manual refresh
2. **Matches HealthKit:** Within 1-5 minutes, counts match
3. **Current hour updates:** Same hour gets updated quantity (not duplicate entry)
4. **Logs show updates:** Console shows "UPDATING current hour quantity"
5. **No duplicates:** Each hour has only ONE entry in database

### ❌ Test Fails If:

1. **No auto-update:** Must pull-to-refresh to see changes
2. **Stuck at old count:** FitIQ never matches HealthKit
3. **Duplicate entries:** Multiple entries for same hour
4. **No update logs:** Console missing "UPDATING" messages
5. **Crashes/errors:** App freezes or sync fails

---

## Expected Behavior Summary

### Before Fix
- HealthKit: 5176 steps
- FitIQ: 4913 steps
- Need manual refresh to update

### After Fix
- HealthKit: 5176 steps
- FitIQ: 5176 steps (within 1-5 minutes)
- Auto-updates as you walk

### Key Point
**The 1-5 minute sync delay is NORMAL and controlled by iOS.** The fix ensures that when sync DOES run, it properly updates the current hour instead of skipping it.

---

## Quick Validation Checklist

- [ ] Walked for 2-3 minutes
- [ ] HealthKit shows new step count
- [ ] Waited 1-5 minutes
- [ ] FitIQ auto-updated (no manual refresh)
- [ ] Counts match (within ~50 steps)
- [ ] Logs show "UPDATING current hour quantity"
- [ ] No crashes or errors
- [ ] Same hour entry updated (not duplicated)

**If all checked:** ✅ Fix is working!  
**If any unchecked:** See Troubleshooting section above

---

**Last Updated:** 2025-01-28  
**Related Docs:** `CURRENT_HOUR_LIVE_UPDATE_FIX.md`
