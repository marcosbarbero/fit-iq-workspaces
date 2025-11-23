# SummaryView Real-Time Update Fix

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Issue:** Summary cards only update on round hours (7:00, 8:00, 9:00, etc.)  
**Status:** 🔴 Issue Identified - Fix Needed

---

## 🐛 Problem Statement

The SummaryView displays health metric cards (Steps, Heart Rate, Sleep, Weight) with two types of data:

1. **Latest Value** - Most recent single data point (e.g., "72 BPM at 9:37")
2. **8-Hour Mini Chart** - Hourly aggregated data for last 8 hours

**Current Issue:** Both the latest values AND the mini charts only update when the clock crosses to a new hour (e.g., 9:00 → 10:00), not in real-time as new HealthKit data arrives.

**Expected Behavior:** 
- **Latest Value** should update immediately when new HealthKit data arrives (e.g., Apple Watch syncs at 9:37)
- **8-Hour Mini Chart** should show rolling 1-hour windows that update continuously

---

## 🔍 Root Cause Analysis

### Issue 1: Mini Charts Group by Clock Hour (Not Rolling Windows)

**Location:** 
- `GetLast8HoursStepsUseCase.swift` (Lines 58-75)
- `GetLast8HoursHeartRateUseCase.swift` (Lines 58-78)

**Problem Code:**
```swift
// ❌ WRONG: Groups ALL data from hour 9 (9:00-9:59) together
let hour = calendar.component(.hour, from: entry.date)
hourlyData[hour, default: 0] += entry.quantity

// ❌ WRONG: Creates slots for clock hours 2, 3, 4, 5, 6, 7, 8, 9
for i in 0..<8 {
    let hour = (currentHour - 7 + i + 24) % 24
    // ...
}
```

**Why It Fails:**
- At **9:30 AM**, current hour is `9`
- New data from 9:30-9:35 goes into "hour 9" bucket
- But "hour 9" already has data from 9:00-9:30
- Chart shows aggregate for entire hour 9 (9:00-9:59)
- Chart only updates when clock hits 10:00 (new hour bucket)

**Example:**
```
Time: 9:37 AM
Current behavior:
  Hour 9 bucket = ALL data from 9:00-9:59 (including future data!)
  
Desired behavior:
  Window 7 = 9:00-9:59 (only data from 9:00-9:37 so far)
  Updates continuously as new data arrives at 9:38, 9:40, etc.
```

### Issue 2: Latest Values Are Actually Working (But May Need Verification)

**Location:** `SummaryViewModel.swift`

**Current Implementation:**
- `fetchLatestHeartRate()` - Fetches single most recent entry ✅
- `fetchDailyStepsTotal()` - Fetches total steps for today ✅
- `latestHeartRateDate` - Tracks timestamp of last reading ✅

**Status:** These SHOULD update in real-time via `LocalDataChangePublisher`. Need to verify why UI isn't reflecting updates.

**Possible Issue:**
- Data IS being fetched correctly
- But SwiftUI might not be re-rendering because the mini chart data hasn't changed
- Or debouncing (2 seconds) might be hiding updates

---

## 🛠️ Solution Design

### Fix 1: Rolling 1-Hour Windows for Mini Charts

**Change:** Group data by **1-hour windows from (now - 8h)**, not by clock hour.

**Implementation:**

#### GetLast8HoursStepsUseCase.swift (Line 40-78)

```swift
func execute() async throws -> [(hour: Int, steps: Int)] {
    // Get current user ID
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        throw GetLast8HoursStepsError.userNotAuthenticated
    }

    let calendar = Calendar.current
    let now = Date()
    
    // Calculate start time (8 hours ago)
    guard let startTime = calendar.date(byAdding: .hour, value: -8, to: now) else {
        return []
    }

    // Fetch entries from last 8 hours
    let recentEntries = try await progressRepository.fetchRecent(
        forUserID: userID,
        type: .steps,
        startDate: startTime,
        endDate: now,
        limit: 500  // Enough for 8 hours of granular data
    )

    // Filter to entries with time information
    let entriesWithTime = recentEntries.filter { $0.time != nil }

    // ✅ NEW: Group by 1-hour window offset from startTime
    var windowData: [Int: Double] = [:]
    
    for entry in entriesWithTime {
        // Calculate which 1-hour window this entry falls into (0-7)
        let components = calendar.dateComponents([.hour], from: startTime, to: entry.date)
        let hoursFromStart = components.hour ?? 0
        
        // Only include data within our 8-hour window
        if hoursFromStart >= 0 && hoursFromStart < 8 {
            windowData[hoursFromStart, default: 0] += entry.quantity
        }
    }

    // ✅ NEW: Build result with actual hour labels for each window
    var result: [(hour: Int, steps: Int)] = []
    
    for windowIndex in 0..<8 {
        // Calculate the start of this 1-hour window
        guard let windowStart = calendar.date(byAdding: .hour, value: windowIndex, to: startTime) else {
            continue
        }
        
        // Get the clock hour for labeling (e.g., 9 for 9:XX)
        let displayHour = calendar.component(.hour, from: windowStart)
        
        // Get steps for this window (0 if no data)
        let steps = Int(windowData[windowIndex] ?? 0)
        
        result.append((hour: displayHour, steps: steps))
    }

    return result
}
```

**Benefits:**
- ✅ Windows roll continuously (not locked to clock hours)
- ✅ New data at 9:37 updates window 7 immediately
- ✅ Chart shows incremental progress within the hour
- ✅ No artificial boundaries at hour transitions

**Example:**
```
Time: 9:37 AM
Windows:
  [0] 1:37-2:36 (hour label: 1)  → 0 steps
  [1] 2:37-3:36 (hour label: 2)  → 0 steps
  [2] 3:37-4:36 (hour label: 3)  → 0 steps
  [3] 4:37-5:36 (hour label: 4)  → 0 steps
  [4] 5:37-6:36 (hour label: 5)  → 0 steps
  [5] 6:37-7:36 (hour label: 6)  → 1,234 steps
  [6] 7:37-8:36 (hour label: 7)  → 2,456 steps
  [7] 8:37-9:36 (hour label: 8)  → 3,789 steps ← Updates as you walk!
  
New data at 9:38 adds to window [7] immediately!
```

#### GetLast8HoursHeartRateUseCase.swift (Similar Fix)

```swift
func execute() async throws -> [(hour: Int, heartRate: Int)] {
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        throw GetLast8HoursHeartRateError.userNotAuthenticated
    }

    let calendar = Calendar.current
    let now = Date()
    
    guard let startTime = calendar.date(byAdding: .hour, value: -8, to: now) else {
        return []
    }

    let recentEntries = try await progressRepository.fetchRecent(
        forUserID: userID,
        type: .restingHeartRate,
        startDate: startTime,
        endDate: now,
        limit: 500
    )

    let entriesWithTime = recentEntries.filter { $0.time != nil }

    // ✅ NEW: Group by 1-hour window and collect values for averaging
    var windowData: [Int: [Double]] = [:]
    
    for entry in entriesWithTime {
        let components = calendar.dateComponents([.hour], from: startTime, to: entry.date)
        let hoursFromStart = components.hour ?? 0
        
        if hoursFromStart >= 0 && hoursFromStart < 8 {
            windowData[hoursFromStart, default: []].append(entry.quantity)
        }
    }

    // ✅ NEW: Build result with averages per window
    var result: [(hour: Int, heartRate: Int)] = []
    
    for windowIndex in 0..<8 {
        guard let windowStart = calendar.date(byAdding: .hour, value: windowIndex, to: startTime) else {
            continue
        }
        
        let displayHour = calendar.component(.hour, from: windowStart)
        
        if let values = windowData[windowIndex], !values.isEmpty {
            let avg = values.reduce(0, +) / Double(values.count)
            result.append((hour: displayHour, heartRate: Int(avg)))
        } else {
            result.append((hour: displayHour, heartRate: 0))
        }
    }

    return result
}
```

---

### Fix 2: Verify Latest Value Updates (Already Working?)

**Investigation Needed:**

1. **Check if data is being fetched:**
   - Enable logging in `SummaryViewModel.refreshProgressMetrics()`
   - Verify `fetchLatestHeartRate()` is called when HealthKit data changes
   - Check timestamps in logs

2. **Check if UI is updating:**
   - Add debug overlay showing `lastRefreshTime` and `refreshCount`
   - Verify `@Observable` is triggering SwiftUI updates
   - Check if `latestHeartRateDate` changes in real-time

3. **Potential Issues:**
   - Debounce interval (2 seconds) might be hiding rapid updates
   - SwiftUI might not re-render if only `last8HoursHeartRateData` changes
   - Need to verify `LocalDataChangePublisher` is firing

**Debug Code to Add:**

```swift
// Add to SummaryView.swift (in DEBUG section)
VStack(alignment: .leading) {
    Text("🔍 Latest HR: \(viewModel.formattedLatestHeartRate) BPM")
    Text("🕐 Last Updated: \(viewModel.lastHeartRateRecordedTime)")
    Text("🔄 Refresh Count: \(viewModel.refreshCount)")
    Text("⏱️ Last Refresh: \(viewModel.lastRefreshTime, formatter: timeFormatter)")
}
.font(.caption2)
.foregroundColor(.green)
```

---

## 📋 Implementation Checklist

### Phase 1: Fix Mini Charts (Critical)
- [ ] Update `GetLast8HoursStepsUseCase.swift` with rolling window logic
- [ ] Update `GetLast8HoursHeartRateUseCase.swift` with rolling window logic
- [ ] Add unit tests for window calculation edge cases
- [ ] Test at hour boundaries (9:59 → 10:00)
- [ ] Test mid-hour updates (9:37 → 9:38)
- [ ] Verify chart updates in real-time

### Phase 2: Verify Latest Values (Investigation)
- [ ] Add debug logging to `fetchLatestHeartRate()`
- [ ] Add debug overlay to SummaryView showing refresh timestamps
- [ ] Monitor logs when Apple Watch syncs data
- [ ] Verify `LocalDataChangePublisher` events are firing
- [ ] Check if SwiftUI is re-rendering correctly
- [ ] Measure debounce impact (2 seconds)

### Phase 3: Optimization (Optional)
- [ ] Consider reducing debounce to 1 second for faster updates
- [ ] Add loading indicators for individual metrics
- [ ] Add "Last updated X seconds ago" text
- [ ] Optimize fetchRecent queries (add indexes if needed)
- [ ] Consider caching window calculations

---

## 🧪 Testing Scenarios

### Scenario 1: Mid-Hour Data Arrival
```
1. Time: 9:37 AM
2. Current steps in window 7 (8:37-9:36): 3,000 steps
3. Walk 100 steps (Apple Watch syncs at 9:38)
4. Expected: Window 7 shows 3,100 steps immediately
5. Current: Window 7 shows 3,000 until 10:00
```

### Scenario 2: Hour Boundary Crossing
```
1. Time: 9:59 AM
2. Windows show data from 1:59-9:58
3. Clock hits 10:00
4. Expected: Windows shift to 2:00-9:59
5. Current: Works (but this is the ONLY time it updates)
```

### Scenario 3: Real-Time Heart Rate
```
1. Time: 9:40 AM
2. Current HR: 72 BPM (from 9:20)
3. Apple Watch syncs new reading: 78 BPM at 9:40
4. Expected: Card shows "78 BPM at 9:40" within 2 seconds
5. Need to verify: Is this working or stuck at 72?
```

---

## 📊 Performance Considerations

### fetchRecent Query Performance
- **Current:** Fetches last 100-500 entries
- **Concern:** Might be slow if user has thousands of entries
- **Mitigation:** Add date range to query (already done ✅)

### Window Calculation Performance
- **Cost:** O(n) where n = number of entries in 8 hours
- **Typical n:** 8-100 entries (depends on sync granularity)
- **Impact:** Negligible (<1ms)

### UI Update Frequency
- **Current:** 2-second debounce
- **Impact:** User might see slight delay
- **Recommendation:** Keep debounce to prevent excessive updates

---

## 🎯 Expected Outcomes

### After Fix 1 (Mini Charts)
- ✅ Charts update continuously as data arrives
- ✅ No artificial boundaries at clock hours
- ✅ User sees progress within the hour
- ✅ Better user experience (feels "live")

### After Fix 2 (Latest Values)
- ✅ Verify values update in real-time (or identify blocker)
- ✅ Clear visibility into update frequency
- ✅ Confidence in data freshness

---

## 🔗 Related Files

### Files to Modify
- `FitIQ/Domain/UseCases/Summary/GetLast8HoursStepsUseCase.swift`
- `FitIQ/Domain/UseCases/Summary/GetLast8HoursHeartRateUseCase.swift`

### Files to Review (No Changes)
- `FitIQ/Presentation/ViewModels/SummaryViewModel.swift` (already has refresh logic)
- `FitIQ/Presentation/UI/Summary/SummaryView.swift` (debug overlay only)

### Related Documentation
- `docs/architecture/HEALTHKIT_SYNC_ASSESSMENT.md` - Sync mechanism overview
- `docs/architecture/SUMMARY_DATA_LOADING_PATTERN.md` - Summary pattern guide
- `.github/copilot-instructions.md` - Architecture guidelines

---

## 💡 Alternative Approaches (Not Recommended)

### Alternative 1: Fetch Data More Frequently
- **Idea:** Poll HealthKit every 30 seconds
- **Problem:** Battery drain, unnecessary queries
- **Verdict:** ❌ Not recommended

### Alternative 2: Use Minute-Level Granularity
- **Idea:** Show 480 data points (8 hours × 60 minutes)
- **Problem:** Too granular for summary view, performance issues
- **Verdict:** ❌ Overkill for summary

### Alternative 3: Show "Live" Badge When Data is Fresh
- **Idea:** Add 🟢 indicator if data is <5 minutes old
- **Problem:** Doesn't fix the underlying issue
- **Verdict:** ✅ Could add as enhancement AFTER fix

---

## ✅ Success Criteria

1. **Mini Charts Update Continuously**
   - At 9:37, new steps appear in current window
   - No delay until next clock hour
   - Charts feel "live"

2. **Latest Values Are Current**
   - Heart rate shows most recent reading
   - Timestamp reflects actual sync time
   - Updates within 2-5 seconds of HealthKit sync

3. **Performance is Maintained**
   - No UI lag or jank
   - Query performance <100ms
   - Battery impact minimal

4. **User Experience is Excellent**
   - Data feels fresh and real-time
   - No confusing delays
   - Trust in app accuracy

---

**Status:** 🔴 Ready for Implementation  
**Priority:** 🔥 High (User-facing issue)  
**Estimated Effort:** 2-3 hours  
**Risk:** Low (isolated use case changes)

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-27