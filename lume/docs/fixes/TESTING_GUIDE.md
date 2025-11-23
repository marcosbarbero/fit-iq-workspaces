# Mood Tracking Fixes - Testing Guide

**Date:** 2025-01-15  
**Version:** 1.0.0  
**Purpose:** Step-by-step testing instructions for mood tracking fixes

---

## Prerequisites

### Environment Setup
- [ ] Fresh app install (recommended) or delete existing data
- [ ] Backend configured in `config.plist`
- [ ] Device/Simulator running iOS 17.0+
- [ ] Network connectivity (for backend sync tests)

### Test Data
- [ ] At least 5 mood entries across different days
- [ ] Mix of entries with and without notes
- [ ] Various mood types (happy, sad, calm, etc.)
- [ ] Different valence levels (-1.0 to 1.0)

---

## Test Suite 1: Data Integrity

### Test 1.1: Create Mood Entry
**Objective:** Verify new entries save correctly

**Steps:**
1. Open Mood Tracking view
2. Tap the `+` FAB button
3. Select a mood (e.g., "Happy")
4. Add optional note: "Test entry"
5. Tap "Save"

**Expected Result:**
- Entry appears in history list immediately
- Time/date shows current timestamp
- Icon matches selected mood
- Bar chart reflects correct valence
- Note indicator shows if note was added

**Status:** [ ] Pass [ ] Fail

---

### Test 1.2: Edit Existing Entry (Critical Fix)
**Objective:** Verify edits update in place, no duplicates

**Steps:**
1. Tap an existing mood entry to expand
2. Tap "Edit" button (or swipe action)
3. Change mood from "Happy" to "Content"
4. Update note: "Edited test entry"
5. Tap "Save"
6. Return to history list

**Expected Result:**
- ✅ Entry is UPDATED (not duplicated)
- ✅ New mood icon and color displayed
- ✅ Updated note visible when expanded
- ✅ Same timestamp as original
- ✅ Only ONE entry for that timestamp

**Status:** [ ] Pass [ ] Fail

**Debug if Failed:**
```swift
// Check database for duplicates
print("Entry count: \(viewModel.moodHistory.count)")
// Should not increase after edit
```

---

### Test 1.3: Delete Entry
**Objective:** Verify deletion removes entry locally

**Steps:**
1. Swipe left on a mood entry
2. Tap "Delete" button
3. Confirm deletion if prompted

**Expected Result:**
- Entry immediately removed from list
- No error messages
- Other entries remain intact

**Status:** [ ] Pass [ ] Fail

---

### Test 1.4: Multiple Rapid Edits
**Objective:** Stress test update logic

**Steps:**
1. Edit the same entry 5 times in a row
2. Change mood each time
3. Alternate between adding/removing notes

**Expected Result:**
- Still only ONE entry exists
- Final state matches last save
- No performance degradation
- No crashes or hangs

**Status:** [ ] Pass [ ] Fail

---

## Test Suite 2: UI/UX Improvements

### Test 2.1: History Card Layout (New Design)
**Objective:** Verify time-first information hierarchy

**Steps:**
1. View history list with multiple entries
2. Observe card layout

**Expected Result:**
- ✅ TIME displayed first (large, bold)
- ✅ DATE displayed below time (small, gray)
- ✅ ICON shown after time (44×44px)
- ✅ BAR CHART on right side (36×24px)
- ✅ Note indicator at bottom (if note exists)

**Visual Checklist:**
```
[✓] 3:45 PM           [Icon]  [Chart]
    January 15, 2025
    📝 Tap to view note
```

**Status:** [ ] Pass [ ] Fail

---

### Test 2.2: Card Visual Weight
**Objective:** Verify reduced visual clutter

**Steps:**
1. Compare old vs new design (if possible)
2. Assess scanability

**Expected Result:**
- Easier to scan chronologically
- Icon less dominant
- Time stands out as primary anchor
- Overall calmer appearance

**Status:** [ ] Pass [ ] Fail

---

### Test 2.3: Valence Bar Chart Visibility
**Objective:** Verify improved contrast on bars

**Steps:**
1. View entries with different valence levels
2. Check bar chart readability

**Expected Result:**
- All bars have visible borders
- Filled vs unfilled bars clearly distinguished
- Colors pop without being harsh
- Readable on all backgrounds

**Status:** [ ] Pass [ ] Fail

---

### Test 2.4: FAB Overlap Fix
**Objective:** Verify last entry is accessible

**Steps:**
1. Scroll to bottom of history list
2. Observe last entry position
3. Try tapping last entry

**Expected Result:**
- ✅ Last entry fully visible
- ✅ 80pt clearance below last entry
- ✅ FAB doesn't cover any content
- ✅ Last entry is tappable/swipeable

**Status:** [ ] Pass [ ] Fail

---

## Test Suite 3: Dashboard Charts

### Test 3.1: Chart Background Contrast
**Objective:** Verify white panel improves visibility

**Steps:**
1. Open Dashboard (chart icon in toolbar)
2. View mood timeline chart

**Expected Result:**
- Chart on white (#FFFFFF) background panel
- Subtle shadow around panel
- Clear separation from page background
- All elements easily readable

**Status:** [ ] Pass [ ] Fail

---

### Test 3.2: Chart Element Visibility
**Objective:** Verify all chart components are clear

**Steps:**
1. View chart with multiple data points
2. Check each element

**Expected Result:**
- Line: Thick (2.5pt), 80% opacity
- Area: Visible gradient (30% → 8%)
- Points: Large (250px), white borders
- Grid lines: Visible at 30% opacity
- Axis labels: Dark, readable text

**Status:** [ ] Pass [ ] Fail

---

### Test 3.3: Chart Interaction
**Objective:** Verify chart tap/selection works

**Steps:**
1. Tap on data points in chart
2. Tap on entry rows below chart

**Expected Result:**
- Tapping point shows entry details
- Tapping row shows entry details
- Selection highlights correctly
- Sheet dismisses properly

**Status:** [ ] Pass [ ] Fail

---

## Test Suite 4: Backend Sync

### Test 4.1: Create Entry Sync
**Objective:** Verify new entries sync to backend

**Steps:**
1. Enable backend mode in config
2. Create new mood entry
3. Wait for sync or trigger manually
4. Check outbox events

**Expected Result:**
- Outbox event created: "mood.created"
- Event payload contains correct data
- Backend receives entry (check logs/API)
- No errors in console

**Status:** [ ] Pass [ ] Fail [ ] N/A (Backend not available)

---

### Test 4.2: Edit Entry Sync (Critical Fix)
**Objective:** Verify edits sync as updates, not creates

**Steps:**
1. Edit an existing entry
2. Wait for sync or trigger manually
3. Check outbox events

**Expected Result:**
- ✅ Outbox event created: "mood.updated" (NOT "mood.created")
- ✅ Event includes entry ID
- ✅ Backend updates existing entry
- ✅ No duplicate entries on backend

**Status:** [ ] Pass [ ] Fail [ ] N/A (Backend not available)

**Debug Commands:**
```swift
// Check outbox events
let events = try await outboxRepository.fetchPending()
print("Event types: \(events.map { $0.eventType })")
// Should see "mood.updated" after edit
```

---

### Test 4.3: Delete Entry Sync
**Objective:** Verify deletes sync to backend

**Steps:**
1. Delete a mood entry
2. Trigger backend sync
3. Pull to refresh
4. Verify entry doesn't reappear

**Expected Result:**
- Outbox event created: "mood.deleted"
- Backend deletes entry (if backendId exists)
- Sync doesn't resurrect deleted entry
- Entry stays deleted locally

**Status:** [ ] Pass [ ] Fail [ ] N/A (Backend not available)

**Known Issue:** This may need backend verification if entries reappear.

---

### Test 4.4: Full Sync Cycle
**Objective:** Verify complete sync flow

**Steps:**
1. Create 3 entries locally
2. Edit 1 entry
3. Delete 1 entry
4. Trigger sync
5. Wait for outbox processing
6. Pull to refresh

**Expected Result:**
- 2 entries remain (1 deleted)
- Edited entry shows updates
- All changes reflected in backend
- No sync errors or conflicts

**Status:** [ ] Pass [ ] Fail [ ] N/A (Backend not available)

---

## Test Suite 5: Edge Cases

### Test 5.1: Offline Behavior
**Objective:** Verify app works without network

**Steps:**
1. Enable Airplane Mode
2. Create, edit, delete entries
3. Re-enable network
4. Trigger sync

**Expected Result:**
- All operations work offline
- Outbox queues events
- Sync processes queue when online
- No data loss

**Status:** [ ] Pass [ ] Fail

---

### Test 5.2: Rapid Operations
**Objective:** Stress test UI responsiveness

**Steps:**
1. Quickly create 10 entries
2. Edit 5 entries rapidly
3. Delete 3 entries
4. Navigate between views

**Expected Result:**
- No UI freezing
- No crashes
- All operations complete
- Data integrity maintained

**Status:** [ ] Pass [ ] Fail

---

### Test 5.3: Date Boundaries
**Objective:** Test entries across days/months

**Steps:**
1. Create entry at 11:59 PM
2. Wait until 12:01 AM
3. Create another entry
4. View both days

**Expected Result:**
- Entries appear on correct dates
- Date filtering works properly
- No timezone issues

**Status:** [ ] Pass [ ] Fail

---

### Test 5.4: Empty States
**Objective:** Verify empty state handling

**Steps:**
1. Fresh install (no data)
2. View history list
3. View dashboard

**Expected Result:**
- History: Shows empty state message
- Dashboard: Shows "No data yet" message
- Both states are friendly and helpful
- No crashes or errors

**Status:** [ ] Pass [ ] Fail

---

## Test Suite 6: Accessibility

### Test 6.1: VoiceOver Navigation
**Objective:** Verify screen reader support

**Steps:**
1. Enable VoiceOver (Settings > Accessibility)
2. Navigate mood history
3. Try editing/deleting entries

**Expected Result:**
- All elements have labels
- Logical navigation order
- Actions are announced
- Gestures work correctly

**Status:** [ ] Pass [ ] Fail

---

### Test 6.2: Dynamic Type
**Objective:** Verify text scaling

**Steps:**
1. Settings > Display > Text Size
2. Increase to maximum
3. View mood tracking screens

**Expected Result:**
- All text scales appropriately
- Layout doesn't break
- Still readable and usable
- No text truncation

**Status:** [ ] Pass [ ] Fail

---

### Test 6.3: Color Contrast
**Objective:** Verify WCAG compliance

**Steps:**
1. Use contrast checker tool
2. Test all text/background combinations

**Expected Result:**
- Primary text: AAA (≥7:1)
- Secondary text: AA (≥4.5:1)
- Charts: AA minimum
- Colors distinguishable

**Status:** [ ] Pass [ ] Fail

---

## Regression Tests

### Test R.1: Existing Features Unaffected
**Objective:** Verify no breaks in other features

**Steps:**
1. Navigate to Journal tab
2. Navigate to Goals tab
3. Navigate to Profile tab
4. Return to Mood tab

**Expected Result:**
- All tabs load correctly
- Navigation works smoothly
- No unexpected crashes
- Data persists across tabs

**Status:** [ ] Pass [ ] Fail

---

### Test R.2: Authentication Flow
**Objective:** Verify auth still works

**Steps:**
1. Log out (if applicable)
2. Log back in
3. View mood data

**Expected Result:**
- Login succeeds
- Mood data loads for user
- No permission errors

**Status:** [ ] Pass [ ] Fail [ ] N/A

---

## Performance Tests

### Test P.1: Large Dataset
**Objective:** Verify performance with many entries

**Steps:**
1. Create 100+ mood entries
2. Scroll through history
3. Open dashboard
4. Edit/delete entries

**Expected Result:**
- Smooth scrolling (60 FPS)
- Dashboard loads quickly (<2s)
- No lag or stuttering
- Memory usage acceptable

**Status:** [ ] Pass [ ] Fail

---

### Test P.2: Memory Leaks
**Objective:** Check for memory issues

**Steps:**
1. Open mood tracking
2. Create/edit/delete 50 entries
3. Navigate away and back 10 times
4. Check Instruments/Xcode memory graph

**Expected Result:**
- No memory leaks detected
- Memory usage stable
- Objects deallocate properly

**Status:** [ ] Pass [ ] Fail

---

## Test Results Summary

### Critical Tests
- [ ] 1.2: Edit updates in place ⭐ **CRITICAL**
- [ ] 4.2: Edit syncs as "mood.updated" ⭐ **CRITICAL**
- [ ] 2.1: New card layout visible ⭐ **IMPORTANT**
- [ ] 2.4: FAB doesn't overlap ⭐ **IMPORTANT**
- [ ] 3.1: Chart contrast improved ⭐ **IMPORTANT**

### Pass Rate
- **Data Integrity:** ____ / 4 tests passed
- **UI/UX:** ____ / 4 tests passed
- **Dashboard:** ____ / 3 tests passed
- **Backend Sync:** ____ / 4 tests passed
- **Edge Cases:** ____ / 4 tests passed
- **Accessibility:** ____ / 3 tests passed
- **Regression:** ____ / 2 tests passed
- **Performance:** ____ / 2 tests passed

**Total:** ____ / 26 tests passed (____%)

---

## Issue Reporting Template

If a test fails, use this template:

```markdown
### Issue: [Brief description]

**Test:** [Test ID and name]
**Severity:** Critical / High / Medium / Low
**Steps to Reproduce:**
1. 
2. 
3. 

**Expected:**
[What should happen]

**Actual:**
[What actually happened]

**Screenshots/Logs:**
[Attach if available]

**Environment:**
- Device: [iPhone model / Simulator]
- iOS Version: [e.g., 17.2]
- App Version: [e.g., 1.0.0]

**Additional Notes:**
[Any other relevant information]
```

---

## Sign-Off

### Tester Information
- **Name:** ______________________
- **Date:** ______________________
- **Build:** ______________________

### Approval
- [ ] All critical tests passed
- [ ] No blocking issues found
- [ ] Ready for production deployment

**Signature:** ______________________

---

**Note:** For backend sync tests (Suite 4), coordinate with backend team to verify API endpoints are functioning correctly.