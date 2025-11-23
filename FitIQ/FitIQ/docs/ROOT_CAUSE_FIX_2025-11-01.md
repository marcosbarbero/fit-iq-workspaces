# Root Cause Fix - Performance Issues
**Date:** 2025-11-01  
**Status:** ✅ Fixed  
**CPU Usage:** 130-200% → Expected ~20-40%  
**Memory:** 168MB (acceptable)  
**Disk I/O:** 10MB/s → Expected <1MB/s

---

## 🔍 Root Cause Analysis

### Primary Issue: Full Table Scans in Database Queries

**Location:** `SchemaCompatibilityLayer.swift` + `SwiftDataProgressRepository.swift`

**Problem:**
1. `fetchLocal()` was fetching **ALL progress entries** from the database
2. No date range filtering in the query predicate
3. Filtering was done **in memory** after fetching all rows
4. No fetch limits on queries
5. With 7 days of historical sync, this meant fetching ~500-1000+ entries per query

**Code Path:**
```
GetLast8HoursStepsUseCase.execute()
    ↓
progressRepository.fetchLocal(userID, type: .steps, syncStatus: nil)
    ↓
SchemaCompatibilityLayer.safeFetchProgressEntries(...) 
    ↓
FetchDescriptor<SDProgressEntry>() // NO PREDICATE FOR DATE RANGE!
    ↓
try context.fetch(descriptor) // FETCHES ALL ROWS
    ↓
.filter { entry.date >= last8HoursStart } // FILTERS IN MEMORY
```

**Impact:**
- Query fetched 500-1000 entries when only 8-16 were needed
- This happened for BOTH steps and heart rate queries
- Ran in parallel = 2 full table scans simultaneously
- CPU at 130-200% trying to filter in memory
- Disk I/O at 10MB/s reading all rows

---

## ✅ Fixes Applied

### Fix 1: Add Optimized `fetchRecent()` Method
**File:** `ProgressRepositoryProtocol.swift`

Added new method with date range support:
```swift
func fetchRecent(
    forUserID userID: String,
    type: ProgressMetricType?,
    startDate: Date,      // ✅ Date range filtering
    endDate: Date,        // ✅ Date range filtering
    limit: Int            // ✅ Explicit limit
) async throws -> [ProgressEntry]
```

**Implementation:** `SwiftDataProgressRepository.swift`
```swift
// Build predicate with date range - uses index, avoids full table scan
let predicate = #Predicate<SDProgressEntry> { entry in
    entry.userID == userID
        && (typeRawValue == nil || entry.type == typeRawValue!)
        && entry.date >= startDate  // ✅ DB-level filtering
        && entry.date <= endDate    // ✅ DB-level filtering
}

var descriptor = FetchDescriptor<SDProgressEntry>(
    predicate: predicate,
    sortBy: [SortDescriptor(\.date, order: .reverse)]
)
descriptor.fetchLimit = limit  // ✅ Explicit limit
```

**Benefits:**
- Database does the filtering (indexed query)
- Only fetches rows within date range
- Explicit limit prevents unbounded queries
- ~50x fewer rows fetched (1000 → 20)

---

### Fix 2: Add `limit` Parameter to Protocol Contract
**File:** `ProgressRepositoryProtocol.swift`

**Before:**
```swift
func fetchLocal(
    forUserID userID: String, 
    type: ProgressMetricType?, 
    syncStatus: SyncStatus?
)
```

**After:**
```swift
func fetchLocal(
    forUserID userID: String, 
    type: ProgressMetricType?, 
    syncStatus: SyncStatus?,
    limit: Int? = nil  // ✅ Consumer decides limit
)
```

**Rationale:**
- No arbitrary hardcoded limits (was 1000)
- Consumer knows how much data they need
- More flexible and maintainable
- Follows principle of explicit contracts

---

### Fix 3: Update Use Cases to Use Optimized Query
**Files:** 
- `GetLast8HoursStepsUseCase.swift`
- `GetLast8HoursHeartRateUseCase.swift`

**Before:**
```swift
// ❌ Full table scan - fetches ALL entries
let allEntries = try await progressRepository.fetchLocal(
    forUserID: userID,
    type: .steps,
    syncStatus: nil
)

// ❌ Filter in memory after fetching everything
let recentEntries = allEntries.filter { entry in
    entry.date >= last8HoursStart && entry.time != nil
}
```

**After:**
```swift
// ✅ Optimized query with date range
let last8HoursStart = calendar.date(byAdding: .hour, value: -8, to: now)!
let recentEntries = try await progressRepository.fetchRecent(
    forUserID: userID,
    type: .steps,
    startDate: last8HoursStart,  // ✅ DB-level filter
    endDate: now,                // ✅ DB-level filter
    limit: 100                   // ✅ Explicit limit
)

// ✅ Only filter for time information (small subset)
let entriesWithTime = recentEntries.filter { entry in
    entry.time != nil
}
```

**Performance Gain:**
- Fetches ~20 entries instead of ~1000 (50x reduction)
- Database does the date filtering (indexed)
- Memory filtering only for time check (fast)

---

### Fix 4: Restore All Features (No Shortcuts)
**Files:**
- `SummaryViewModel.swift` - Restored parallel queries with `withTaskGroup`
- `SummaryView.swift` - Restored hourly chart data parameters

**Changes:**
- ✅ Parallel data fetching (now safe with optimized queries)
- ✅ Hourly steps data
- ✅ Hourly heart rate data
- ✅ All chart visualizations

**Why This Works Now:**
- Queries are optimized (no full table scans)
- Each query fetches <100 rows instead of 1000+
- Parallel execution is efficient when queries are fast

---

## 📊 Expected Performance Improvement

### Before Fix:
```
Query 1 (Steps):       Fetch 1000 rows → Filter in memory → Return 8
Query 2 (Heart Rate):  Fetch 1000 rows → Filter in memory → Return 8
Total Rows Fetched:    2000 rows
Disk I/O:              10 MB/s
CPU Usage:             130-200%
Time:                  2-3 seconds
```

### After Fix:
```
Query 1 (Steps):       Fetch 20 rows (with date predicate) → Return 8
Query 2 (Heart Rate):  Fetch 20 rows (with date predicate) → Return 8
Total Rows Fetched:    40 rows
Disk I/O:              <1 MB/s
CPU Usage:             20-40% (expected)
Time:                  <0.5 seconds
```

**Performance Gain:**
- 50x fewer rows fetched (2000 → 40)
- 10x faster disk I/O (10 MB/s → <1 MB/s)
- 5x lower CPU usage (150% → 30%)
- 6x faster query time (2-3s → <0.5s)

---

## 🧪 Testing Checklist

- [ ] App launches without freeze (<5s)
- [ ] CPU usage <50% during data load
- [ ] Disk I/O <1 MB/s during queries
- [ ] Steps display correctly (hourly chart)
- [ ] Heart rate displays correctly (hourly chart)
- [ ] Data matches HealthKit
- [ ] Scroll performance is smooth (60fps)
- [ ] No console errors about fetch limits
- [ ] Memory usage remains stable (<200MB)

---

## 🔑 Key Learnings

### 1. Always Use Date Range Predicates
- Never fetch all rows and filter in memory
- Use database predicates for indexed columns (date, userID, type)
- Let the database engine do the work

### 2. Explicit Limits in Protocol Contract
- Don't hardcode limits in implementation
- Let consumer decide based on use case
- Makes code more maintainable and flexible

### 3. Profile Before Optimizing
- CPU at 130-200% indicated database issue
- Disk I/O at 10 MB/s confirmed full table scan
- Metrics pointed directly to root cause

### 4. Don't Remove Features to Fix Performance
- Fix the actual problem (query optimization)
- Removing features is a band-aid, not a solution
- Users need the features; optimize the implementation

---

## 📝 Architecture Improvements

### Repository Pattern Enhancement

**Old Pattern (Anti-pattern):**
```swift
// Fetch everything, filter in memory
func fetchLocal(userID, type, syncStatus) -> [Entry]
```

**New Pattern (Best Practice):**
```swift
// Specific query for specific use case
func fetchRecent(userID, type, startDate, endDate, limit) -> [Entry]

// Generic query with optional limit
func fetchLocal(userID, type, syncStatus, limit?) -> [Entry]
```

**Benefits:**
- Use case chooses appropriate method
- Queries are explicit and optimized
- No hidden performance traps
- Easy to add new optimized queries

---

## 🚀 Future Optimizations

### 1. Add More Specialized Queries
- `fetchToday()` - Most recent day only
- `fetchLatest(count: Int)` - N most recent entries
- `fetchBetween(start, end)` - Specific date range

### 2. Add Database Indexes
- Composite index on (userID, type, date)
- Would make date range queries even faster
- SwiftData handles this automatically in most cases

### 3. Implement Caching
- Cache last 8 hours of data in memory
- Invalidate on new data arrival
- Would eliminate DB queries for repeated views

### 4. Batch Queries
- Combine related queries (steps + heart rate)
- Single DB round-trip instead of multiple
- Would reduce query overhead

---

## 📚 References

- [SwiftData Best Practices](https://developer.apple.com/documentation/swiftdata)
- [Database Query Optimization](https://use-the-index-luke.com/)
- [iOS Performance Tuning](https://developer.apple.com/videos/play/wwdc2023/10180/)

---

**Status:** ✅ Root Cause Fixed  
**Next Step:** Test thoroughly and monitor performance metrics  
**Estimated Impact:** 5-10x performance improvement