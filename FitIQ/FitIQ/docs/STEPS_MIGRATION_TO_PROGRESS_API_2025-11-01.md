# Steps Migration to /progress API
**Date:** 2025-11-01  
**Status:** ✅ Complete  
**Priority:** High - Architecture Unification

---

## 🎯 Objective

Migrate steps data from the Activity Snapshot API to the `/progress` API, unifying the architecture with how heart rate, mood, weight, and other metrics are handled.

---

## 📋 Why This Migration?

### Before: Inconsistent Architecture

**Steps (Old Way - Activity Snapshot API):**
```
HealthKit Steps
    ↓
StepsSyncHandler → SaveStepsProgressUseCase → SwiftDataProgressRepository
    ↓
SummaryViewModel → GetLatestActivitySnapshotUseCase → ActivitySnapshotRepository
    ❌ Different API for display than storage!
```

**Heart Rate (Correct Way - /progress API):**
```
HealthKit Heart Rate
    ↓
HeartRateSyncHandler → SaveHeartRateProgressUseCase → SwiftDataProgressRepository
    ↓
SummaryViewModel → GetLatestHeartRateUseCase → SwiftDataProgressRepository
    ✅ Consistent storage and retrieval!
```

### Problems with Old Approach

1. **Dual Data Sources:** Steps stored in ProgressRepository but fetched from ActivitySnapshot
2. **Inconsistent:** Different pattern from all other metrics
3. **Complex:** Activity Snapshot was a daily aggregate, while progress entries are granular (hourly)
4. **Maintenance:** Extra code to maintain for ActivitySnapshot
5. **Confusion:** New developers would be confused by the dual approach

---

## ✅ Changes Made

### 1. Created GetDailyStepsTotalUseCase

**File:** `Domain/UseCases/Summary/GetDailyStepsTotalUseCase.swift`

**Purpose:** Fetch total steps for a specific day from progress repository (matching heart rate pattern)

```swift
protocol GetDailyStepsTotalUseCase {
    func execute(forDate date: Date) async throws -> Int
}

final class GetDailyStepsTotalUseCaseImpl: GetDailyStepsTotalUseCase {
    private let progressRepository: ProgressRepositoryProtocol
    private let authManager: AuthManager
    
    func execute(forDate date: Date = Date()) async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Use optimized fetchRecent with date range (no full table scan)
        let entries = try await progressRepository.fetchRecent(
            forUserID: userID,
            type: .steps,
            startDate: startOfDay,
            endDate: endOfDay,
            limit: 100
        )
        
        // Sum all steps for the day
        return entries.reduce(0) { $0 + Int($1.quantity) }
    }
}
```

**Key Features:**
- ✅ Uses optimized `fetchRecent()` with date range (no full table scan)
- ✅ Explicit limit of 100 (more than enough for daily hourly entries)
- ✅ Sums all entries for the day (handles hourly granularity)
- ✅ Matches pattern used by heart rate

---

### 2. Updated SummaryViewModel

**File:** `Presentation/ViewModels/SummaryViewModel.swift`

**Changes:**

#### Removed Old Dependencies
```swift
// ❌ REMOVED
private let getLatestActivitySnapshotUseCase: GetLatestActivitySnapshotUseCaseProtocol
private let activitySnapshotEventPublisher: ActivitySnapshotEventPublisherProtocol
private let saveStepsProgressUseCase: SaveStepsProgressUseCase
private let healthRepository: HealthRepositoryProtocol
private let saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase
```

#### Added New Dependency
```swift
// ✅ ADDED
private let getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase
```

#### Replaced Property
```swift
// ❌ REMOVED
var latestActivitySnapshot: ActivitySnapshot?
var stepsCount: Int {
    latestActivitySnapshot?.steps ?? 0
}

// ✅ ADDED
var stepsCount: Int = 0
```

#### Replaced Fetch Method
```swift
// ❌ REMOVED
func fetchLatestActivitySnapshot() async {
    latestActivitySnapshot = try await getLatestActivitySnapshotUseCase.execute(...)
    await syncStepsToProgressTracking()  // Extra sync step!
}

// ✅ ADDED
func fetchDailyStepsTotal() async {
    stepsCount = try await getDailyStepsTotalUseCase.execute(forDate: Date())
}
```

#### Removed Event Subscription
```swift
// ❌ REMOVED
func subscribeToActivitySnapshotEvents() {
    // 33 lines of event handling code removed
}
```

**Result:** Simpler, cleaner, more consistent code!

---

### 3. Updated ViewModelAppDependencies

**File:** `Infrastructure/Configuration/ViewModelAppDependencies.swift`

**Changes:**
```swift
// Updated SummaryViewModel initialization
let summaryViewModel = SummaryViewModel(
    // ❌ REMOVED
    // getLatestActivitySnapshotUseCase: ...
    // activitySnapshotEventPublisher: ...
    // saveStepsProgressUseCase: ...
    // healthRepository: ...
    // saveHeartRateProgressUseCase: ...
    
    // ✅ ADDED
    getDailyStepsTotalUseCase: appDependencies.getDailyStepsTotalUseCase,
    
    // ... other dependencies remain unchanged
)
```

---

### 4. Updated AppDependencies

**File:** `Infrastructure/Configuration/AppDependencies.swift`

**Added:**
1. Property declaration:
   ```swift
   let getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase
   ```

2. Initialization parameter:
   ```swift
   init(..., getDailyStepsTotalUseCase: GetDailyStepsTotalUseCase, ...)
   ```

3. Assignment in init:
   ```swift
   self.getDailyStepsTotalUseCase = getDailyStepsTotalUseCase
   ```

4. Build method:
   ```swift
   let getDailyStepsTotalUseCase = GetDailyStepsTotalUseCaseImpl(
       progressRepository: progressRepository,
       authManager: authManager
   )
   ```

5. Dependency injection:
   ```swift
   return AppDependencies(
       ...,
       getDailyStepsTotalUseCase: getDailyStepsTotalUseCase,
       ...
   )
   ```

---

## 📊 Architecture: Before vs After

### Before Migration

```
┌─────────────────────────────────────────────────────┐
│ SummaryViewModel                                     │
│                                                      │
│  Steps:     GetLatestActivitySnapshotUseCase        │
│             ↓                                        │
│             ActivitySnapshotRepository              │
│             ↓                                        │
│             SDActivitySnapshot (daily aggregate)    │
│                                                      │
│  Heart Rate: GetLatestHeartRateUseCase              │
│             ↓                                        │
│             ProgressRepository                       │
│             ↓                                        │
│             SDProgressEntry (hourly granular)        │
│                                                      │
│  ❌ INCONSISTENT ARCHITECTURE                       │
└─────────────────────────────────────────────────────┘
```

### After Migration

```
┌─────────────────────────────────────────────────────┐
│ SummaryViewModel                                     │
│                                                      │
│  Steps:     GetDailyStepsTotalUseCase               │
│             ↓                                        │
│             ProgressRepository                       │
│             ↓                                        │
│             SDProgressEntry (hourly granular)        │
│                                                      │
│  Heart Rate: GetLatestHeartRateUseCase              │
│             ↓                                        │
│             ProgressRepository                       │
│             ↓                                        │
│             SDProgressEntry (hourly granular)        │
│                                                      │
│  ✅ CONSISTENT UNIFIED ARCHITECTURE                 │
└─────────────────────────────────────────────────────┘
```

---

## 🎉 Benefits

### 1. Unified Architecture
- All metrics use the same `/progress` API
- Consistent patterns across the codebase
- Easier to understand and maintain

### 2. Simplified Code
- **Removed:** 100+ lines of ActivitySnapshot-specific code
- **Removed:** Event subscription boilerplate
- **Removed:** Extra sync step (syncStepsToProgressTracking)
- **Added:** 1 clean, simple use case

### 3. Better Performance
- Uses optimized `fetchRecent()` with date range predicates
- No full table scans
- Explicit fetch limits
- Same optimizations as heart rate queries

### 4. Easier Debugging
- Single source of truth for all metrics
- Consistent data flow for all metrics
- Less cognitive overhead

### 5. Future-Proof
- Easy to add new metrics (just follow the same pattern)
- ActivitySnapshot API can be deprecated/removed
- Cleaner architecture for new developers

---

## 🔄 Data Flow Comparison

### Old Flow (Steps via ActivitySnapshot)
```
1. HealthKit Steps Data
   ↓
2. StepsSyncHandler (saves to ProgressRepository)
   ↓
3. SaveStepsProgressUseCase
   ↓
4. SwiftDataProgressRepository (stored as SDProgressEntry)
   ↓
5. SummaryViewModel calls GetLatestActivitySnapshotUseCase
   ↓
6. ActivitySnapshotRepository (fetches from different table!)
   ↓
7. Returns daily aggregate (not the same as stored data)
   ↓
8. SummaryViewModel then calls syncStepsToProgressTracking()
   ↓
9. Creates duplicate entry in ProgressRepository (again!)

❌ Complex, inefficient, dual storage
```

### New Flow (Steps via /progress API)
```
1. HealthKit Steps Data
   ↓
2. StepsSyncHandler (saves to ProgressRepository)
   ↓
3. SaveStepsProgressUseCase
   ↓
4. SwiftDataProgressRepository (stored as SDProgressEntry)
   ↓
5. SummaryViewModel calls GetDailyStepsTotalUseCase
   ↓
6. ProgressRepository (fetches from same table!)
   ↓
7. Returns sum of all hourly entries for the day

✅ Simple, direct, single source of truth
```

---

## 🧪 Testing Checklist

- [x] Steps display correctly on Summary view
- [x] Steps count matches HealthKit data
- [x] Hourly steps chart displays correctly
- [x] Steps persist across app restarts
- [x] No duplicate step entries created
- [x] No references to ActivitySnapshot for steps
- [x] All dependencies properly injected
- [x] No compilation errors
- [x] Performance is acceptable (no full table scans)

---

## 📝 Notes

### ActivitySnapshot Still Exists

The `ActivitySnapshot` repository and related code still exist in the codebase for backward compatibility. However:
- ✅ Steps no longer use it
- ✅ It can be deprecated in future
- ✅ No new code should reference it
- ✅ Consider removing in future cleanup

### Steps Sync Still Works

- ✅ `StepsSyncHandler` continues to sync from HealthKit
- ✅ Steps are saved to `ProgressRepository` (unchanged)
- ✅ Only the **retrieval** method changed (not storage)
- ✅ Outbox pattern still works for backend sync

### Data Migration

No data migration needed because:
- Steps were already being saved to `ProgressRepository`
- We're just changing where we **read** from
- Existing steps data in ProgressRepository will display correctly

---

## 🚀 Future Work

### 1. Remove ActivitySnapshot Completely
Once we verify this migration is stable:
- Remove `ActivitySnapshotRepository`
- Remove `GetLatestActivitySnapshotUseCase`
- Remove `SDActivitySnapshot` model
- Remove activity snapshot events

### 2. Apply Same Pattern to Other Metrics
If any other metrics use ActivitySnapshot:
- Migrate them to `/progress` API
- Follow this document as a template

### 3. Add More Summary Use Cases
Following the same pattern:
- `GetDailyCaloriesBurnedUseCase`
- `GetDailyDistanceUseCase`
- `GetDailyActiveMinutesUseCase`

---

## 📚 Related Documents

- `ROOT_CAUSE_FIX_2025-11-01.md` - Performance optimization
- `FREEZE_DIAGNOSIS_2025-11-01.md` - App freeze diagnosis
- `docs/architecture/UNIFIED_SYNC_ARCHITECTURE.md` - Sync architecture

---

## 🎓 Key Takeaways

1. **Consistency is King:** All metrics should use the same pattern
2. **Single Source of Truth:** Don't duplicate data across different storage mechanisms
3. **Simplify, Don't Complicate:** Fewer moving parts = easier maintenance
4. **Performance Matters:** Use optimized queries with date ranges and limits
5. **Follow Existing Patterns:** When adding new features, match what already works

---

**Status:** ✅ Complete and Tested  
**Migration Time:** ~2 hours  
**Lines of Code:** -100 (net reduction!)  
**Performance Impact:** Positive (uses optimized queries)  
**Architecture Impact:** Major improvement (unified pattern)

**Next Steps:** Monitor in production, then deprecate ActivitySnapshot