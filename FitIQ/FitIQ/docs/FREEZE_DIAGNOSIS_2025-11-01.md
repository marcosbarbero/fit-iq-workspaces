# App Freeze Diagnosis & Fix Plan
**Date:** 2025-11-01  
**Status:** 🔴 Critical Issue  
**Priority:** P0

---

## 🐛 Problem Summary

The FitIQ iOS app freezes when it opens, blocking the UI and preventing user interaction. This occurs during initial data load after login.

---

## 🔍 Root Cause Analysis

### Issue #1: Heavy Historical Sync on App Launch
**Location:** `PerformInitialHealthKitSyncUseCase.swift` (Line 17)

```swift
private let historicalSyncDays: Int = 90
```

**Problem:**
- Syncing **90 days** of historical data on first launch
- Even with `Task.detached`, this queries thousands of HealthKit samples
- HealthKit queries can block if SQLite database is large
- ~4,320 hourly entries for 90 days across multiple metrics (steps, heart rate, sleep)

**Impact:**
- Initial sync takes 30-90 seconds
- UI feels frozen even though sync is in background
- Poor first-time user experience

---

### Issue #2: Activity Snapshot Architecture
**Location:** `SummaryViewModel.swift` → `fetchLatestActivitySnapshot()`

**Problem:**
- Steps are using **Activity Snapshot API** instead of **/progress API**
- Activity snapshots are daily aggregates (1 per day per user)
- This is different from Heart Rate which uses hourly progress entries
- Inconsistent architecture causes confusion and maintenance issues

**Current Flow:**
```
HealthKit Steps
    ↓
StepsSyncHandler
    ↓
SaveStepsProgressUseCase (hourly entries)
    ↓
SwiftDataProgressRepository
    ↓
BUT SummaryViewModel fetches from ActivitySnapshot (daily) ❌
```

**Should Be:**
```
HealthKit Steps
    ↓
StepsSyncHandler
    ↓
SaveStepsProgressUseCase (hourly entries)
    ↓
SwiftDataProgressRepository
    ↓
SummaryViewModel fetches from ProgressRepository ✅
```

---

### Issue #3: SummaryView Data Load on Appear
**Location:** `SummaryView.swift` (Line 219-227)

```swift
.onAppear {
    guard !hasLoadedInitialData else {
        print("SummaryView: ⏭️ Skipping reload - data already loaded")
        return
    }
    
    Task {
        await viewModel.reloadAllData()
        hasLoadedInitialData = true
    }
}
```

**Problem:**
- `reloadAllData()` fetches 8 different data sources in parallel
- If background sync is still running, this compounds the load
- Uses `@MainActor` which can cause UI blocking if queries are slow

**Data Fetched:**
1. Activity Snapshot (steps)
2. Health Metrics (weight, height)
3. Last 5 weights for mini-graph
4. Latest mood entry
5. Latest heart rate
6. Last 8 hours heart rate (hourly)
7. Last 8 hours steps (hourly)
8. Latest sleep data

---

### Issue #4: SwiftData Queries May Be Slow
**Location:** Various repositories

**Problem:**
- No fetch limits on some queries
- No indexing strategy documented
- Predicates may not be optimized
- ModelContext created in each repository method (overhead)

---

## 🎯 Fix Plan

### Phase 1: Immediate Freeze Fix (30 min)
**Goal:** Stop UI freeze on app launch

#### 1.1: Reduce Historical Sync Period
```swift
// PerformInitialHealthKitSyncUseCase.swift
// Change from 90 days to 7 days for initial sync
private let historicalSyncDays: Int = 7
```

**Rationale:**
- 7 days provides enough data for immediate use
- Reduces sync time from 30-90s to 5-10s
- Can add background sync for older data later

#### 1.2: Lower Background Sync Priority
```swift
// RootTabView.swift
// Change from .userInitiated to .background
Task.detached(priority: .background) {
    print("RootTabView: Starting background HealthKit sync...")
    // ... sync code
}
```

**Rationale:**
- Prevents background sync from competing with UI updates
- Allows main thread to prioritize rendering

#### 1.3: Add Sync Completion Debouncing
```swift
// RootTabView.swift
// Add delay before reloading data after sync
try await deps.performInitialHealthKitSyncUseCase.execute(forUserID: userID)
print("RootTabView: ✅ Background HealthKit sync completed")

// Wait 500ms to let SwiftData settle
try? await Task.sleep(nanoseconds: 500_000_000)

await viewModelDeps.summaryViewModel.reloadAllData()
```

**Rationale:**
- Prevents race condition between sync completion and data fetch
- Allows SwiftData to finish writing before reading

---

### Phase 2: Migrate Steps to Progress API (2-3 hours)
**Goal:** Remove Activity Snapshot dependency for steps

#### 2.1: Create GetLast8HoursStepsUseCase (Already Exists ✅)
This already exists and queries progress entries correctly.

#### 2.2: Create GetDailyStepsTotalUseCase
**New Use Case:** `GetDailyStepsTotalUseCase.swift`

```swift
protocol GetDailyStepsTotalUseCase {
    func execute(forDate date: Date) async throws -> Int
}

final class GetDailyStepsTotalUseCaseImpl: GetDailyStepsTotalUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    func execute(forDate date: Date = Date()) async throws -> Int {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw ProgressTrackingError.userNotAuthenticated
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch all steps entries for today
        let entries = try await progressRepository.fetchProgressEntries(
            forUserID: userID,
            type: .steps,
            startDate: startOfDay,
            endDate: endOfDay
        )
        
        // Sum all steps for the day
        let totalSteps = entries.reduce(0) { $0 + Int($1.quantity) }
        
        return totalSteps
    }
}
```

#### 2.3: Update SummaryViewModel
**Remove:** `fetchLatestActivitySnapshot()`  
**Add:** `fetchDailyStepsTotal()`

```swift
@MainActor
private func fetchDailyStepsTotal() async {
    do {
        let total = try await getDailyStepsTotalUseCase.execute(forDate: Date())
        stepsCount = total
        print("SummaryViewModel: ✅ Fetched daily steps total: \(total)")
    } catch {
        print("SummaryViewModel: ❌ Error fetching daily steps - \(error.localizedDescription)")
        stepsCount = 0
    }
}
```

**Update:** `reloadAllData()`
```swift
await withTaskGroup(of: Void.self) { group in
    group.addTask { await self.fetchDailyStepsTotal() }  // ✅ New
    // group.addTask { await self.fetchLatestActivitySnapshot() }  // ❌ Remove
    group.addTask { await self.fetchLatestHealthMetrics() }
    group.addTask { await self.fetchLast5WeightsForSummary() }
    group.addTask { await self.fetchLatestMoodEntry() }
    group.addTask { await self.fetchLatestHeartRate() }
    group.addTask { await self.fetchLast8HoursHeartRate() }
    group.addTask { await self.fetchLast8HoursSteps() }
    group.addTask { await self.fetchLatestSleep() }
}
```

#### 2.4: Remove Activity Snapshot Dependencies
**Files to Update:**
- `SummaryViewModel.swift` - Remove `latestActivitySnapshot` property
- `SummaryViewModel.swift` - Remove `getLatestActivitySnapshotUseCase` dependency
- `AppDependencies.swift` - Remove from SummaryViewModel initialization
- Mark `ActivitySnapshotRepository` as deprecated (keep for backward compatibility)

---

### Phase 3: Optimize Data Loading (1 hour)
**Goal:** Speed up data fetches

#### 3.1: Add Fetch Limits to Queries
```swift
// Example: GetLast8HoursStepsUseCase.swift
var descriptor = FetchDescriptor<SDProgressEntry>(
    predicate: predicate,
    sortBy: [SortDescriptor(\.date, order: .reverse)]
)
descriptor.fetchLimit = 48  // 8 hours * 6 (10-min intervals) = max possible
```

#### 3.2: Batch Small Queries
Instead of 8 separate database queries, combine related ones:
- Combine heart rate queries (latest + last 8 hours)
- Combine steps queries (total + last 8 hours)

#### 3.3: Add Loading Skeletons
Show skeleton UI immediately while data loads in background.

---

### Phase 4: Fix Proactive UI Updates (1 hour)
**Goal:** UI updates automatically when new data arrives

#### 4.1: Verify Publisher Connections
Check that `ActivitySnapshotEventPublisher` is working correctly.

#### 4.2: Add Progress Entry Publisher
Create `ProgressEntryEventPublisher` to notify when steps/heart rate data changes.

#### 4.3: Subscribe in SummaryViewModel
```swift
func subscribeToProgressEntryEvents() {
    progressEntryEventPublisher.eventPublisher
        .receive(on: DispatchQueue.main)
        .sink { [weak self] event in
            guard let self = self, self.isSubscriptionActive else { return }
            
            switch event.type {
            case .stepsUpdated:
                Task { await self.fetchDailyStepsTotal() }
            case .heartRateUpdated:
                Task { await self.fetchLatestHeartRate() }
            default:
                break
            }
        }
        .store(in: &cancellables)
}
```

---

## 📊 Expected Results

### Before Fix:
- ❌ App freezes for 30-90 seconds on launch
- ❌ Steps data inconsistent (using wrong API)
- ❌ UI doesn't update when new data arrives
- ❌ Poor user experience

### After Fix:
- ✅ App loads in < 5 seconds
- ✅ Steps use consistent /progress API (same as heart rate)
- ✅ UI updates automatically when HealthKit data changes
- ✅ Smooth, responsive user experience

---

## 🔄 Implementation Order

1. **Fix freeze (Phase 1)** - 30 min → Deploy immediately
2. **Migrate steps (Phase 2)** - 2-3 hours → Test thoroughly
3. **Optimize queries (Phase 3)** - 1 hour → Incremental improvement
4. **Fix updates (Phase 4)** - 1 hour → Polish

**Total Estimated Time:** 4.5 - 5.5 hours

---

## ⚠️ Risks & Mitigation

### Risk 1: Breaking Existing Data
**Mitigation:** Keep ActivitySnapshot code intact, just stop using it for steps

### Risk 2: Steps Data Loss During Migration
**Mitigation:** Steps are already being saved to ProgressRepository by StepsSyncHandler

### Risk 3: Performance Degradation
**Mitigation:** Test with large datasets before deploying

---

## ✅ Testing Checklist

- [ ] App launches without freeze (<5s)
- [ ] Steps display correctly on Summary view
- [ ] Steps match HealthKit data
- [ ] Hourly steps chart displays correctly
- [ ] UI updates when new steps data arrives from HealthKit
- [ ] Heart rate still works correctly (unchanged)
- [ ] Sleep data still works correctly (unchanged)
- [ ] No console errors or warnings
- [ ] Memory usage is acceptable
- [ ] Battery drain is acceptable

---

## 📝 Notes

- Activity Snapshot repository should remain for backward compatibility
- May want to add background sync for older historical data later
- Consider adding telemetry to track sync performance
- Document the new architecture in project docs

---

**Status:** Ready for Implementation  
**Next Step:** Start Phase 1 (Immediate Freeze Fix)