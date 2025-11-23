# HealthKit Summary Data Sync Issues

**Date:** 2025-01-28  
**Status:** 🔴 CRITICAL - Data Discrepancy & Live Update Issues  
**Affected Components:** SummaryView, StepsSyncHandler, SummaryViewModel

---

## 🚨 Issue Summary

### Issue 1: Data Discrepancy
**Symptom:** HealthKit shows 296 steps, FitIQ shows 410 steps (114 step difference)  
**Impact:** Users see incorrect data, trust in app accuracy is compromised

### Issue 2: Hourly Updates Instead of Live Updates
**Symptom:** Data only updates approximately once per hour, not in real-time  
**Impact:** Poor user experience - users expect immediate updates when HealthKit data changes

---

## 🔍 Root Cause Analysis

### Issue 1: Data Discrepancy - Root Causes

#### 1. **Duplicate Entries from Previous Syncs**
- **Location:** `SwiftDataProgressRepository` database
- **Evidence:** Emergency cleanup removed 150MB of duplicates, reducing database to 10MB
- **Why:** Before deduplication logic was implemented, multiple syncs created duplicate entries
- **Current State:** Deduplication logic exists but doesn't clean up historical duplicates

#### 2. **Hour-Based Aggregation Timing Issues**
- **Location:** `StepsSyncHandler.syncRecentStepsData()`
- **How It Works:**
  ```swift
  // Fetches hourly aggregates from HealthKit
  let hourlySteps = try await healthRepository.fetchHourlyStatistics(
      for: .stepCount,
      unit: HKUnit.count(),
      from: fetchStartDate,
      to: endDate
  )
  ```
- **Potential Issue:** If data spans hour boundaries oddly, aggregation might double-count
- **Example:** Steps logged at 11:59 PM might appear in both 11:00 PM hour and 12:00 AM hour

#### 3. **No Aggregation or Calculation - Direct Summation**
- **Answer to Question 1:** **NO manipulation** - the code simply sums all entries:
  ```swift
  // GetDailyStepsTotalUseCase.swift
  let totalSteps = entries.reduce(0) { $0 + Int($1.quantity) }
  ```
- **This means:** If duplicates exist, they are ALL counted, causing inflated numbers

#### 4. **Deduplication Logic Limitations**
- **Location:** `SwiftDataProgressRepository.save()`
- **How It Works:**
  ```swift
  // Checks: userID + type + date + time
  let predicate = #Predicate<SDProgressEntry> { entry in
      entry.userID == userID
          && entry.type == typeRawValue
          && entry.date == targetDate
          && entry.time == targetTime
  }
  ```
- **Problem:** Only prevents NEW duplicates, doesn't clean up OLD duplicates
- **Problem:** If `time` field formatting is inconsistent, duplicates can slip through
- **Problem:** Race conditions during concurrent syncs could create duplicates

---

### Issue 2: Hourly Updates - Root Causes

#### 1. **HealthKit Observers ARE Working (But Not Immediately)**
- **Location:** `HealthKitAdapter.startObserving()` + `BackgroundSyncManager.setOnDataUpdateHandler()`
- **Flow:**
  ```
  HealthKit Data Changes
    ↓
  HKObserverQuery fires
    ↓
  onDataUpdate callback triggered
    ↓
  Added to UserDefaults pending sync queue
    ↓
  DEBOUNCED background task scheduled (with delay)
    ↓
  Background sync runs (not immediate)
    ↓
  Data saved to SwiftData
    ↓
  UI refreshes (only if isSyncing changes)
  ```

#### 2. **Debounce Delay Causes Lag**
- **Location:** `BackgroundSyncManager.setOnDataUpdateHandler()`
- **Code:**
  ```swift
  self.backgroundTaskScheduleDebounceTask = Task {
      try await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
      // ... schedule background task
  }
  ```
- **Default:** `debounceInterval` is likely 30-60 seconds
- **Result:** Updates are delayed by debounce interval + background task execution time

#### 3. **SummaryViewModel Doesn't Listen to Local Data Changes**
- **Location:** `SummaryViewModel` + `SummaryView`
- **Current Refresh Triggers:**
  1. `.task { await viewModel.reloadAllData() }` - Only on view appear
  2. `.onChange(of: viewModel.isSyncing)` - Only when sync status changes
  3. `.refreshable { await viewModel.refreshData() }` - Manual pull-to-refresh
- **Missing:** No subscription to `LocalDataChangePublisher` or SwiftData changes

#### 4. **LocalDataChangeMonitor Exists But Isn't Used for UI Updates**
- **Location:** `LocalDataChangeMonitor` service
- **Status:** Started in `RootTabView.onAppear()` but not connected to SummaryViewModel
- **Evidence:**
  ```swift
  // RootTabView.swift
  deps.localDataChangeMonitor.startMonitoring(forUserID: userID)
  ```
- **Problem:** This monitors changes for REMOTE sync, not for UI updates

---

## 📊 Data Flow Analysis

### Current Steps Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     CURRENT FLOW                             │
└─────────────────────────────────────────────────────────────┘

1. USER WALKS (generates HealthKit data)
   ↓
2. iOS Health App records steps
   ↓
3. HKObserverQuery fires (immediate)
   ↓
4. BackgroundSyncManager.onDataUpdate() called
   ↓
5. Add to pending sync queue (UserDefaults)
   ↓
6. DEBOUNCE DELAY (30-60 seconds)
   ↓
7. Background task scheduled
   ↓
8. StepsSyncHandler.syncRecentStepsData() runs
   ↓
9. Fetch hourly statistics from HealthKit
   ↓
10. SaveStepsProgressUseCase.execute() for each hour
    ↓
11. SwiftDataProgressRepository.save()
    ↓
12. Check for duplicates (userID + type + date + time)
    ↓
13. Save to SwiftData (if not duplicate)
    ↓
14. Create Outbox event for backend sync
    ↓
15. SummaryView DOESN'T REFRESH (waiting for isSyncing change)
    ↓
16. Background sync completes
    ↓
17. isSyncing changes to false
    ↓
18. SummaryView.onChange triggers
    ↓
19. viewModel.reloadAllData() called
    ↓
20. GetDailyStepsTotalUseCase.execute()
    ↓
21. Sum ALL entries for today (including any duplicates)
    ↓
22. UI FINALLY UPDATES (30-90 seconds after user walked)
```

### Problems in Flow

- **Step 6:** Debounce delay adds 30-60 seconds
- **Step 12:** Deduplication only prevents NEW duplicates, not old ones
- **Step 15:** UI doesn't refresh when local data changes
- **Step 21:** If old duplicates exist, they inflate the count

---

## 🎯 Solutions

### Solution 1: Fix Data Discrepancy

#### A. Clean Up Existing Duplicates (IMMEDIATE - User Action Required)

**What to do:**
1. Go to Profile → App Settings → Database Management
2. Tap "Run Emergency Cleanup"
3. Wait for completion (should remove duplicates)

**Verify:**
```
Check console logs for:
"EmergencyDatabaseCleanupUseCase: Removed X duplicate progress entries"
```

#### B. Verify Deduplication Logic Works (VERIFY)

**Add logging to confirm:**

```swift
// SwiftDataProgressRepository.swift - save() method

// After deduplication check, add:
print("SwiftDataProgressRepository: 🔍 DEDUPLICATION CHECK")
print("  UserID: \(userID)")
print("  Type: \(progressEntry.type.rawValue)")
print("  Date: \(targetDate)")
print("  Time: \(targetTime)")
print("  Existing entries found: \(existingEntries.count)")
if let existing = existingEntries.first {
    print("  ✅ DUPLICATE PREVENTED - Entry already exists: \(existing.id)")
} else {
    print("  ✅ NEW ENTRY - Saving to database")
}
```

#### C. Add Time Normalization (PREVENT FUTURE ISSUES)

**Problem:** If time strings are formatted inconsistently, duplicates can slip through

**Solution:** Normalize time format in `SaveStepsProgressUseCase`:

```swift
// SaveStepsProgressUseCase.swift - execute() method

// BEFORE (current):
let timeFormatter = DateFormatter()
timeFormatter.dateFormat = "HH:mm:ss"
let timeString = timeFormatter.string(from: date)

// AFTER (normalized):
let calendar = Calendar.current
let hour = calendar.component(.hour, from: date)
let timeString = String(format: "%02d:00:00", hour) // Always use top of hour
```

**Why:** This ensures consistent time strings, preventing duplicates due to formatting differences

---

### Solution 2: Enable Live Updates

#### Option A: Subscribe to LocalDataChangePublisher (RECOMMENDED)

**Location:** `SummaryViewModel`

**Add property:**
```swift
// SummaryViewModel.swift

private let localDataChangePublisher: LocalDataChangePublisherProtocol
private var dataChangeCancellable: AnyCancellable?
```

**Add to init:**
```swift
init(
    // ... existing parameters
    localDataChangePublisher: LocalDataChangePublisherProtocol
) {
    // ... existing initialization
    self.localDataChangePublisher = localDataChangePublisher
    
    // Subscribe to local data changes
    setupDataChangeSubscription()
}
```

**Add subscription method:**
```swift
private func setupDataChangeSubscription() {
    dataChangeCancellable = localDataChangePublisher.publisher
        .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
        .sink { [weak self] event in
            guard let self = self else { return }
            
            // Only refresh if it's progress entry data
            if event.modelType == .progressEntry {
                print("SummaryViewModel: 🔄 Local data changed, refreshing...")
                Task {
                    await self.refreshStepsOnly() // Efficient - only refresh steps
                }
            }
        }
}

@MainActor
private func refreshStepsOnly() async {
    // Quick refresh of just steps data
    await fetchDailyStepsTotal()
    await fetchLast8HoursSteps()
}
```

**Update AppDependencies:**
```swift
// AppDependencies.swift

lazy var summaryViewModel: SummaryViewModel = SummaryViewModel(
    // ... existing parameters
    localDataChangePublisher: localDataChangePublisher // ADD THIS
)
```

---

#### Option B: Use SwiftData @Query (ALTERNATIVE - SwiftUI Native)

**Location:** `SummaryView`

**Replace viewModel state with direct query:**
```swift
// SummaryView.swift

// ADD: Direct SwiftData query
@Query(
    filter: #Predicate<SDProgressEntry> { entry in
        entry.type == "steps" &&
        entry.date >= Calendar.current.startOfDay(for: Date())
    },
    sort: \SDProgressEntry.date
) 
private var todayStepsEntries: [SDProgressEntry]

// ADD: Computed property for total
private var todayStepsTotal: Int {
    todayStepsEntries.reduce(0) { $0 + Int($1.quantity) }
}

// USE in UI:
FullWidthStepsStatCard(
    stepsCount: todayStepsTotal, // Use computed property
    hourlyData: viewModel.last8HoursStepsData
)
```

**Pros:**
- Automatic live updates (SwiftUI handles it)
- No need for manual refresh logic
- Reactive to database changes

**Cons:**
- Couples view to SwiftData implementation
- Less testable
- Breaks hexagonal architecture slightly

---

#### Option C: Reduce Debounce Interval (QUICK FIX)

**Location:** `BackgroundSyncManager`

**Current:**
```swift
private let debounceInterval: TimeInterval = 30.0 // or 60.0
```

**Change to:**
```swift
private let debounceInterval: TimeInterval = 5.0 // 5 seconds instead of 30-60
```

**Pros:**
- Quick fix
- Maintains existing architecture

**Cons:**
- Still not "live" (5 second delay)
- More frequent background tasks (battery impact)

---

## 🎯 Recommended Solution

### Hybrid Approach (Best of Both Worlds)

1. **Immediate:** Run emergency cleanup to remove existing duplicates
2. **Short-term:** Implement **Option A** (LocalDataChangePublisher subscription)
3. **Long-term:** Add time normalization to prevent future duplicates
4. **Optional:** Reduce debounce to 5-10 seconds for better responsiveness

### Implementation Priority

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| **P0** | Run emergency cleanup | 2 min | Fixes data discrepancy immediately |
| **P1** | Subscribe to LocalDataChangePublisher | 30 min | Enables live updates |
| **P2** | Add deduplication logging | 15 min | Helps diagnose future issues |
| **P3** | Normalize time format | 20 min | Prevents future duplicates |
| **P4** | Reduce debounce interval | 5 min | Improves responsiveness |

---

## 🧪 Testing Plan

### Test 1: Verify Duplicate Cleanup
1. Check console logs after emergency cleanup
2. Verify database size reduction
3. Compare HealthKit steps vs FitIQ steps (should match now)

### Test 2: Verify Live Updates
1. Add LocalDataChangePublisher subscription
2. Log a manual weight entry
3. Verify SummaryView refreshes within 2-3 seconds
4. Walk around with phone, check if steps update quickly

### Test 3: Verify No New Duplicates
1. Enable deduplication logging
2. Trigger multiple syncs manually
3. Check logs - should see "DUPLICATE PREVENTED" messages
4. Query database - should have no duplicates

---

## 📝 Console Logs to Monitor

### For Duplicate Detection:
```
SwiftDataProgressRepository: ⏭️ Entry already exists for steps at [date] [time] - skipping duplicate
```

### For Live Updates:
```
SummaryViewModel: 🔄 Local data changed, refreshing...
SummaryViewModel: ✅ Fetched daily steps total: [count]
```

### For Sync Activity:
```
StepsSyncHandler: 🔄 STARTING OPTIMIZED STEPS SYNC
StepsSyncHandler: ✅ Saved: X new entries
StepsSyncHandler: ⏭️  Skipped: Y duplicates (should be 0)
```

---

## ✅ Success Criteria

### Issue 1: Data Discrepancy - RESOLVED
- [ ] HealthKit steps count matches FitIQ steps count (±1 step tolerance)
- [ ] No duplicate entries in database (verify via emergency cleanup logs)
- [ ] Deduplication logs show duplicates are being prevented

### Issue 2: Live Updates - RESOLVED
- [ ] SummaryView refreshes within 5 seconds of HealthKit data change
- [ ] Manual weight entry triggers immediate refresh
- [ ] Walking activity shows step updates within 10 seconds

---

## 🔗 Related Files

### Data Sync
- `FitIQ/Infrastructure/Services/Sync/StepsSyncHandler.swift`
- `FitIQ/Domain/UseCases/SaveStepsProgressUseCase.swift`
- `FitIQ/Infrastructure/Persistence/SwiftDataProgressRepository.swift`

### UI & ViewModels
- `FitIQ/Presentation/ViewModels/SummaryViewModel.swift`
- `FitIQ/Presentation/UI/Summary/SummaryView.swift`

### Background Sync
- `FitIQ/Domain/UseCases/BackgroundSyncManager.swift`
- `FitIQ/Infrastructure/Integration/HealthKitAdapter.swift`

### Local Data Monitoring
- `FitIQ/Infrastructure/Services/LocalDataChangeMonitor.swift`
- `FitIQ/Infrastructure/Services/LocalDataChangePublisher.swift`

---

**Status:** 🟡 INVESTIGATION COMPLETE - AWAITING IMPLEMENTATION  
**Next Steps:** Implement recommended solutions in priority order