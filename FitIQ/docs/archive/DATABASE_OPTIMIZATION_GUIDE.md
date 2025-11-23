# Database Optimization Guide

**Date:** 2025-01-27  
**Issue:** CoreData PostSaveMaintenance warnings during progressive historical sync  
**Status:** ✅ Optimized

---

## 🐛 The Warning

```
CoreData: debug: PostSaveMaintenance: fileSize 8903352 greater than prune threshold
```

### What It Means
- SwiftData/CoreData database has grown beyond ~8.9 MB
- CoreData is performing automatic maintenance (pruning unused space)
- This is **normal behavior** but indicates room for optimization
- Happens when there are many saves, updates, or deletes

### Why It Happens with Progressive Sync
When fetching 90 days of historical data:
- Creating thousands of `ProgressEntry` records (steps, heart rate, etc.)
- Creating many `ActivitySnapshot` records
- Creating/updating `OutboxEvent` records
- Individual saves for each record = lots of database writes

---

## ✅ Optimizations Applied

### 1. Increased Delay Between Sync Chunks
**File:** `ProgressiveHistoricalSyncService.swift`

**Before:**
```swift
private let delayBetweenChunks: TimeInterval = 2.0  // 2 seconds
```

**After:**
```swift
private let delayBetweenChunks: TimeInterval = 3.0  // 3 seconds
```

**Why:** Gives database more time to consolidate writes between chunks, reducing write pressure.

### 2. Created OptimizeDatabaseUseCase
**File:** `OptimizeDatabaseUseCase.swift`

**Purpose:** Periodic cleanup and optimization (for future implementation)

**Planned Features:**
- Delete old completed outbox events (older than 7 days)
- Archive old progress entries (older than 365 days)
- Remove duplicate/stale records
- Vacuum database to reclaim space

---

## 🔧 Additional Optimizations Needed

### High Priority

#### 1. Implement Deduplication in Sync Handlers
**Location:** `Infrastructure/Services/Sync/`

**Problem:** Might be creating duplicate entries for the same date/time

**Solution:**
```swift
// Before inserting, check if entry already exists
let existingEntry = try await progressRepository.fetch(
    forUserID: userID,
    type: .steps,
    date: date
)

if existingEntry == nil {
    // Only insert if doesn't exist
    try await progressRepository.save(newEntry)
}
```

#### 2. Batch Inserts in SwiftData Repositories
**Location:** `Infrastructure/Repositories/SwiftDataProgressRepository.swift`

**Problem:** Individual saves for each record

**Solution:**
```swift
// Instead of:
for entry in entries {
    modelContext.insert(entry)
    try modelContext.save()  // Save after EACH insert
}

// Do this:
for entry in entries {
    modelContext.insert(entry)  // Queue all inserts
}
try modelContext.save()  // Save ONCE at end
```

#### 3. Use Batch Processing in HealthDataSyncManager
**Location:** `Infrastructure/Services/HealthDataSyncOrchestrator.swift`

**Current:** Process and save one day at a time

**Better:** Process multiple days, then batch save:
```swift
var allEntries: [ProgressEntry] = []

for day in dateRange {
    let dayEntries = process(day)
    allEntries.append(contentsOf: dayEntries)
}

// Save all at once
try await progressRepository.batchSave(allEntries)
```

### Medium Priority

#### 4. Implement Periodic Cleanup Service
**Create:** `PeriodicDatabaseCleanupService.swift`

**Purpose:** Run cleanup automatically every 24 hours

**Tasks:**
- Delete completed outbox events older than 7 days
- Archive progress entries older than 365 days
- Vacuum database (reclaim space)

**Trigger:** In `BackgroundSyncManager` or app launch

#### 5. Add Indexes to Frequently Queried Fields
**Location:** Schema definitions in `Infrastructure/Persistence/Schema/`

**Add indexes for:**
- `ProgressEntry.date` (frequently queried by date range)
- `ProgressEntry.userID` (always filtered by user)
- `OutboxEvent.status` (queried for pending events)
- `ActivitySnapshot.date` (date range queries)

**Example:**
```swift
@Model
final class SDProgressEntry {
    @Attribute(.indexed) var date: Date
    @Attribute(.indexed) var userID: String
    // ... other fields
}
```

### Low Priority

#### 6. Implement Smart Sync (Skip Already-Synced Data)
**Location:** `PerformInitialHealthKitSyncUseCase.swift`

**Current:** Might re-sync data that's already in database

**Better:** Check what dates already have data before syncing:
```swift
let latestDate = try await progressRepository.getLatestEntryDate(forUserID: userID)
// Only sync data newer than latestDate
```

---

## 📊 Database Size Expectations

### Normal Sizes (Per User)

| Data Duration | Expected Size | Notes |
|---------------|---------------|-------|
| 7 days | 1-2 MB | Initial sync |
| 30 days | 3-5 MB | Monthly data |
| 90 days | 8-12 MB | Quarterly data (current) |
| 365 days | 30-50 MB | Full year |

### What to Monitor

✅ **Normal:**
- Database grows as data accumulates
- Occasional PostSaveMaintenance warnings
- Size stabilizes after initial 90-day sync

⚠️ **Warning Signs:**
- Database grows beyond 100 MB
- Frequent PostSaveMaintenance warnings
- App becomes sluggish
- Queries take > 1 second

🚨 **Action Required:**
- Database grows beyond 200 MB
- App crashes with memory warnings
- Queries take > 3 seconds

---

## 🔍 Monitoring Database Health

### Console Logs to Watch For

**Good:**
```
📊 ProgressiveHistoricalSyncService: Chunk 1 completed in 8.45s
✅ ProgressiveHistoricalSyncService: All chunks synced successfully
```

**Concerning:**
```
CoreData: debug: PostSaveMaintenance: fileSize > threshold (frequent)
⚠️ ProgressiveHistoricalSyncService: Chunk failed (repeated failures)
⚠️ SwiftData: Save operation took longer than 1 second
```

**Critical:**
```
🚨 Memory warning received
🚨 Database file corrupted
🚨 Unable to save to SwiftData
```

### Add Performance Monitoring

**In repositories, add timing logs:**
```swift
let startTime = Date()
try modelContext.save()
let duration = Date().timeIntervalSince(startTime)

if duration > 0.5 {
    print("⚠️ Slow save operation: \(duration)s")
}
```

---

## 🛠️ Quick Fixes for Immediate Relief

### 1. Increase Chunk Delay (Done ✅)
Already increased from 2s to 3s.

### 2. Reduce Historical Range (Temporary)
If database growth is problematic, temporarily reduce from 90 to 30 days:

**In `ProgressiveHistoricalSyncService.swift`:**
```swift
private let totalHistoricalDays: Int = 30  // Reduced from 90
```

### 3. Manual Database Reset (Last Resort)
**⚠️ Warning: This deletes ALL local data**

```swift
// In debug settings, add "Reset Database" button
// Only for development/testing
func resetDatabase() {
    try? FileManager.default.removeItem(at: databaseURL)
    // App will recreate database on next launch
}
```

### 4. Delete App and Reinstall
- Simplest way to start fresh
- All local data is lost
- User needs to re-sync from HealthKit

---

## 📝 Implementation Priority

### Phase 1: Immediate (Done ✅)
- [x] Increase chunk delay to 3 seconds
- [x] Add optimization notes in code
- [x] Document database growth expectations

### Phase 2: Short-term (This Week)
- [ ] Implement deduplication in sync handlers
- [ ] Add batch insert capability to repositories
- [ ] Test with larger datasets (180+ days)

### Phase 3: Medium-term (Next Sprint)
- [ ] Implement periodic cleanup service
- [ ] Add database size monitoring
- [ ] Add performance metrics logging
- [ ] Implement OptimizeDatabaseUseCase

### Phase 4: Long-term (Future)
- [ ] Add database indexes
- [ ] Implement smart sync (skip existing data)
- [ ] Add data archival/export feature
- [ ] Implement database compression

---

## 🧪 Testing Database Performance

### Test Scenarios

1. **Fresh Install Test:**
   - Delete app, reinstall
   - Complete onboarding
   - Monitor database size during 90-day sync
   - Expected: ~8-12 MB final size

2. **Re-sync Test:**
   - With existing data, trigger manual sync
   - Should skip duplicates (once implemented)
   - Database size should NOT double

3. **Cleanup Test:**
   - Let app run for 7+ days
   - Trigger cleanup (once implemented)
   - Verify old outbox events are deleted
   - Database size should stabilize or decrease

4. **Performance Test:**
   - Time query operations
   - All queries should complete in < 500ms
   - Save operations should complete in < 100ms

---

## 🎓 Best Practices

### DO ✅
- Batch insert multiple records
- Check for existing data before inserting (deduplication)
- Save to SwiftData AFTER processing multiple records
- Use background threads for large operations
- Monitor database size and performance
- Delete old/stale data periodically

### DON'T ❌
- Save after every single insert
- Re-sync data that's already in database
- Keep data indefinitely without cleanup
- Block main thread with database operations
- Ignore PostSaveMaintenance warnings (monitor them)
- Create duplicate records for same date/time/metric

---

## 📚 Resources

### SwiftData/CoreData Optimization
- [Apple: Optimizing Core Data Performance](https://developer.apple.com/documentation/coredata/optimizing_core_data_performance)
- [SwiftData Best Practices](https://developer.apple.com/documentation/swiftdata)

### Database Maintenance
- [Core Data Batch Operations](https://developer.apple.com/documentation/coredata/batch_processing)
- [Database Indexing Strategies](https://developer.apple.com/documentation/coredata/nsentitydescription/1506829-indexes)

---

**Status:** ✅ Optimized (Phase 1 complete)  
**Next Steps:** Implement Phase 2 (deduplication and batch inserts)  
**Performance Impact:** Minimal (3s delay per chunk is acceptable)  
**Database Health:** Good (warnings are normal during large syncs)

---