# Body Mass Remaining Issues - 2025-01-27

**Date:** 2025-01-27  
**Status:** 🟡 IN PROGRESS  
**Priority:** 🔴 HIGH  

---

## ✅ Issue #1: FIXED - ForceHealthKitResyncUseCase Not Configured

**Problem:**
```
❌ ForceHealthKitResyncUseCase not configured in dependencies
```

**Root Cause:**
- Use case was created but never added to `AppDependencies`
- Not passed to `BodyMassDetailViewModel`

**Solution Applied:**
1. Added `forceHealthKitResyncUseCase` property to `AppDependencies`
2. Instantiated in `build()` method:
   ```swift
   let forceHealthKitResyncUseCase = ForceHealthKitResyncUseCaseImpl(
       performInitialHealthKitSyncUseCase: performInitialHealthKitSyncUseCase,
       userProfileStorage: userProfileStorageAdapter,
       progressRepository: progressRepository,
       authManager: authManager
   )
   ```
3. Passed to `BodyMassDetailViewModel` in `ViewModelAppDependencies`:
   ```swift
   let bodyMassDetailViewModel = BodyMassDetailViewModel(
       getHistoricalWeightUseCase: appDependencies.getHistoricalWeightUseCase,
       authManager: authManager,
       healthRepository: appDependencies.healthRepository,
       forceHealthKitResyncUseCase: appDependencies.forceHealthKitResyncUseCase
   )
   ```

**Status:** ✅ FIXED

**Files Modified:**
- `AppDependencies.swift`
- `ViewModelAppDependencies.swift`

**Verification:**
- [ ] Rebuild app
- [ ] Tap stethoscope icon
- [ ] Verify "Force Re-sync" buttons appear
- [ ] Test both options (Keep Existing / Clear All)

---

## 🔴 Issue #2: Charts Show Same Data Regardless of Filter

**Problem:**
All graphs look the same, no matter what time range filter is selected (7d, 30d, 90d, 1y, All).

**Observations:**
- Current weight displays correctly ✅
- Data is being loaded (64 entries confirmed)
- Filter buttons appear and can be selected
- But chart doesn't change with filter selection

**Root Cause (Suspected):**

### Hypothesis A: Data Not Being Filtered
The `GetHistoricalWeightUseCase` returns data for the selected range, but the chart might be:
1. Not receiving the filtered data
2. Ignoring the date range in the data
3. Always showing all data points

### Hypothesis B: Chart Component Issue
The chart component might be:
1. Not respecting the data bounds
2. Using a fixed x-axis range
3. Not recalculating when data changes

**Diagnostic Steps:**

1. **Check Logs When Changing Filter:**
   ```
   BodyMassDetailViewModel: Loading weight data from <START> to <END>
   BodyMassDetailViewModel: Received X entries from use case
   ```
   - Does X change with different filters?
   - Are START and END dates correct?

2. **Check Chart Data Binding:**
   - Is `historicalData` array being updated?
   - Is chart observing the correct property?
   - Is chart refreshing when data changes?

3. **Check Chart Implementation:**
   - File: `BodyMassDetailView.swift`
   - Does the chart have hard-coded date ranges?
   - Does it auto-scale x-axis?

**Potential Fixes:**

### Fix A: Verify Data Filtering Works
Add debug logging to confirm data changes:
```swift
@MainActor
func onRangeChanged(_ newRange: TimeRange) {
    print("🔍 Filter changed to: \(newRange.rawValue)")
    selectedRange = newRange
    Task {
        print("🔍 Before load: historicalData count = \(historicalData.count)")
        await loadHistoricalData()
        print("🔍 After load: historicalData count = \(historicalData.count)")
        print("🔍 Date range in data: \(historicalData.first?.date) to \(historicalData.last?.date)")
    }
}
```

### Fix B: Force Chart Refresh
If data changes but chart doesn't update, add explicit refresh:
```swift
@State private var chartID = UUID()  // Add to view

// In chart view:
Chart {
    // ... chart content
}
.id(chartID)  // Force rebuild when ID changes

// After loading data:
await loadHistoricalData()
chartID = UUID()  // Force chart rebuild
```

### Fix C: Check Chart Domain/Range
Ensure chart uses data-driven ranges, not fixed ones:
```swift
Chart(historicalData) { record in
    LineMark(
        x: .value("Date", record.date),
        y: .value("Weight", record.weightKg)
    )
}
.chartXScale(domain: ...)  // Should be data-driven, not fixed
.chartYScale(domain: ...)  // Should be data-driven, not fixed
```

**Investigation Required:**
- [ ] Add debug logging to `onRangeChanged()`
- [ ] Check if `historicalData.count` changes with filter
- [ ] Check if date ranges in data match filter selection
- [ ] Review chart implementation in `BodyMassDetailView.swift`
- [ ] Check for hard-coded date ranges in chart
- [ ] Verify chart is observing `@Observable` state changes

**Files to Review:**
- `BodyMassDetailViewModel.swift` (lines 165-170 - onRangeChanged)
- `BodyMassDetailView.swift` (chart implementation)
- `GetHistoricalWeightUseCase.swift` (verify date filtering works)

---

## 🔴 Issue #3: Backend Only Has 1 Entry (Should Have 64)

**Problem:**
```bash
curl backend → {"data":[{"date":"2025-09-27T00:00:00Z","id":"...","quantity":72,"type":"weight"}]}
```
Only 1 entry on backend, but local storage has 55 entries and HealthKit has 64.

**Root Cause:**
Local entries are marked as `.pending` but `RemoteSyncService` hasn't synced them to backend.

**Why This Happens:**

### Reason 1: Events Not Published for Existing Entries
- Entries were saved before `RemoteSyncService` started listening
- No `.progressEntry` events were published for them
- RemoteSyncService only syncs when events are published

### Reason 2: RemoteSyncService Not Running
- Service might not be started
- Service might have stopped
- Event subscription might be broken

### Reason 3: Sync Failures
- Entries marked as `.failed` instead of `.pending`
- Rate limiting preventing bulk sync
- Network errors

**Diagnostic Steps:**

1. **Check RemoteSyncService Status:**
   ```
   RemoteSyncService: Starting to listen for local data sync events for user X
   ```
   - Is this log present?
   - When was it logged?

2. **Check Local Storage Sync Status:**
   Run Local Storage Diagnostic:
   ```
   Sync Status:
     Pending: X
     Syncing: Y
     Synced: Z
     Failed: W
   ```
   - How many are `.pending`?
   - How many are `.synced`?
   - How many are `.failed`?

3. **Check for Sync Events:**
   ```
   RemoteSyncService: 📤 Processing progressEntry sync event for localID X
   ```
   - Are these logs appearing?
   - How many sync attempts?

**Solutions:**

### Solution A: Manual Trigger via Force Re-sync
The Force Re-sync feature will:
1. Re-run initial HealthKit sync
2. Create new entries with fresh events
3. RemoteSyncService will pick them up
4. All 64 entries will sync to backend

**Steps:**
1. Use "Force Re-sync (Keep Existing)" button
2. Watch logs for RemoteSyncService activity
3. Check backend again with curl
4. Should see all 64 entries

### Solution B: Trigger Sync for Pending Entries
Create a "Sync Pending Entries" feature:
```swift
func syncPendingEntries() async {
    let pending = try await progressRepository.fetchLocal(
        forUserID: userID,
        type: .weight,
        syncStatus: .pending
    )
    
    print("Found \(pending.count) pending entries to sync")
    
    for entry in pending {
        // Publish sync event manually
        localDataChangePublisher.publish(
            LocalDataNeedsSyncEvent(
                modelType: .progressEntry,
                localID: entry.id,
                userID: userID,
                isNewRecord: false
            )
        )
    }
}
```

### Solution C: Batch Sync on App Start
Modify app startup to sync pending entries:
```swift
// In app startup after authentication
let pending = try await progressRepository.fetchLocal(
    forUserID: currentUserID,
    type: nil,
    syncStatus: .pending
)

if !pending.isEmpty {
    print("Found \(pending.count) pending entries on startup, triggering sync...")
    // Trigger sync for each pending entry
}
```

**Recommended Approach:**
1. **Short-term:** Use Force Re-sync feature (already implemented)
2. **Medium-term:** Add "Sync Pending Entries" diagnostic button
3. **Long-term:** Auto-sync pending entries on app startup/authentication

**Files to Modify:**
- `BodyMassDetailViewModel.swift` - Add syncPendingEntries() method
- `RemoteSyncService.swift` - Verify event handling
- `AppDelegate` or `FitIQApp.swift` - Add startup sync check

---

## 🎨 Issue #4: Graph Facelift Lost

**Problem:**
The graph had a nice visual design/facelift in the past, but it was lost after many changes.

**What Was Lost (Needs Investigation):**
- [ ] Custom colors/gradients
- [ ] Smooth curves/interpolation
- [ ] Grid lines styling
- [ ] Axis labels formatting
- [ ] Data point markers
- [ ] Background styling
- [ ] Chart padding/margins

**Action Required:**
1. **Check Git History:**
   ```bash
   git log --all --grep="graph\|chart\|visual" -- "**/BodyMassDetailView.swift"
   ```
   Find commit where facelift was applied

2. **Review Previous Implementation:**
   Look at older version of chart code
   Document what styling was applied

3. **Restore Visual Enhancements:**
   Apply same styling to current chart implementation

**Recommended Approach:**
- Create separate issue/task for visual improvements
- Don't mix functional fixes with visual changes
- Apply visual polish after fixing data/filtering issues

---

## 📋 Priority Order

### P0 - Critical (Fix Now)
1. ✅ **Issue #1: Configure ForceHealthKitResyncUseCase** - FIXED
2. 🔴 **Issue #2: Fix chart filtering** - IN PROGRESS
3. 🔴 **Issue #3: Sync pending entries to backend** - IN PROGRESS

### P1 - High (Fix Soon)
4. 🎨 **Issue #4: Restore chart visual facelift** - TODO

---

## 🧪 Testing Checklist

### After Fixing Issue #2 (Chart Filtering)
- [ ] Select "7d" filter → Chart shows only last 7 days
- [ ] Select "30d" filter → Chart shows only last 30 days
- [ ] Select "90d" filter → Chart shows only last 90 days
- [ ] Select "1y" filter → Chart shows only last 1 year
- [ ] Select "All" filter → Chart shows all available data
- [ ] Verify x-axis labels match filter selection
- [ ] Verify data points count changes with filter
- [ ] Current weight remains correct regardless of filter

### After Fixing Issue #3 (Backend Sync)
- [ ] Use Force Re-sync (Keep Existing)
- [ ] Wait for success message
- [ ] Run curl to check backend
- [ ] Verify backend has 64 entries (not just 1)
- [ ] Check all entries have correct dates and values
- [ ] Verify local storage shows "Synced: 64"

---

## 🔍 Debug Commands

### Check Local Storage
```swift
// In BodyMassDetailViewModel diagnostic
let allEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .weight,
    syncStatus: nil
)
print("Total: \(allEntries.count)")
print("Pending: \(allEntries.filter { $0.syncStatus == .pending }.count)")
print("Synced: \(allEntries.filter { $0.syncStatus == .synced }.count)")
print("Failed: \(allEntries.filter { $0.syncStatus == .failed }.count)")
```

### Check Backend
```bash
curl -i -X GET "https://fit-iq-backend.fly.dev/api/v1/progress?type=weight" \
  -H "X-API-Key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" | jq '.data | length'
```

### Check RemoteSyncService Logs
```
grep "RemoteSyncService" Xcode.log | tail -50
```

---

## 📝 Next Steps

1. **Investigate Chart Filtering Issue:**
   - Add debug logging to filter change
   - Verify data changes with filter
   - Check chart component implementation
   - Apply fix based on findings

2. **Test Force Re-sync:**
   - Use "Force Re-sync (Keep Existing)"
   - Monitor sync progress
   - Verify backend receives all entries

3. **Add Sync Pending Diagnostic:**
   - Create "Sync Pending Entries" button
   - Add to diagnostic menu
   - Useful for troubleshooting sync issues

4. **Restore Visual Polish:**
   - Review git history for chart styling
   - Document visual improvements
   - Apply to current implementation

---

**Last Updated:** 2025-01-27  
**Status:** Issues #2 and #3 require investigation and fixes  
**Estimated Time:** 2-4 hours for complete resolution