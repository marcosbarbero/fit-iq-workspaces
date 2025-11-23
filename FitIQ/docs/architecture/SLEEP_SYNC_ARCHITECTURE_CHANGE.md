# Sleep Sync Architecture Change

**Date:** 2025-01-27  
**Type:** Architecture Improvement  
**Status:** Implemented  
**Impact:** Critical - Fixes missing sleep sessions

---

## Problem Statement

The original sleep sync implementation used a **date-based approach** that only synced data for a specific date (typically "today"). This caused two critical issues:

### Issue 1: Missing Sleep Sessions
```
Example:
- Sleep session: Oct 31, 11 PM → Nov 1, 7 AM
- User opens app on Nov 2
- Sync runs for Nov 2 → ❌ Misses the session (ended on Nov 1)
- Nov 1 was marked as "already synced" → Never checks again
```

### Issue 2: Incomplete Sleep Data
```
Example from logs:
- Session stored: Oct 30, 11:07 PM → Oct 31, 12:15 AM
- Duration: Only 68 minutes (4 samples)
- Expected: Full night (6-8 hours with 20-100+ samples)
- Cause: Date filtering cut off the session prematurely
```

### Issue 3: Sync Tracking Prevented Re-checking
```swift
// Old implementation
func syncDaily(forDate date: Date) async throws {
    if syncTracking.hasAlreadySynced(startOfDay, for: .sleep) {
        return  // ❌ Never checks again!
    }
    // ...
}
```

---

## Root Cause Analysis

### Why Date-Based Sync Fails for Sleep

1. **Sleep spans multiple calendar days**
   - Sleep session from 10 PM Friday → 6 AM Saturday
   - Should be attributed to Saturday (wake date)
   - But if sync runs on Sunday, it's already marked as "synced Saturday"

2. **Sleep is logged retroactively**
   - Apple Watch uploads sleep data after you wake up
   - Data might arrive hours after the sleep session ended
   - Date-based sync might have already run and marked date as synced

3. **Users don't open app every day**
   - If user opens app every 3 days, they miss 2 days of sleep data
   - Sync tracking prevents backfill

4. **Background sync only runs for "today"**
   ```swift
   func syncAllDailyActivityData() async {
       let today = Calendar.current.startOfDay(for: Date())  // ❌
       // Only syncs today's data
   }
   ```

---

## Solution: Recent Data Sync (Last 7 Days)

### New Approach

Instead of syncing a specific date, **query last 7 days and deduplicate**:

```swift
func syncDaily(forDate date: Date) async throws {
    // Instead of syncing only the target date, sync recent sleep data
    // Deduplication by sourceID (already implemented) prevents duplicates
    try await syncRecentSleepData()
}

private func syncRecentSleepData() async throws {
    // 1. Query last 7 days from HealthKit
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
    let samples = try await fetchSleepSamples(from: startDate, to: endDate)
    
    // 2. Group samples into sessions
    let sessions = groupSamplesIntoSessions(samples)
    
    // 3. Process each session (deduplication by sourceID)
    for session in sessions {
        try await processSleepSession(session, ...)
        // Repository checks: "if exists by sourceID, skip"
    }
}
```

### Key Changes

| Aspect | Old (Date-Based) | New (Recent Data) |
|--------|------------------|-------------------|
| **Query Window** | Only target date (24h) | Last 7 days |
| **Sync Tracking** | Marks date as synced, never re-checks | No sync tracking needed |
| **Deduplication** | By date + time | By HealthKit sourceID |
| **Missing Data** | Possible if sync runs late | Always captures recent sessions |
| **Performance** | Fast (24h query) | Slightly slower (7-day query) |
| **Reliability** | Low (misses sessions) | High (always catches up) |

---

## Benefits

### ✅ Captures All Recent Sleep Sessions
- Always queries last 7 days
- Captures sessions regardless of when they occurred
- No dependency on when user opens app

### ✅ Retroactive Data Support
- If Apple Watch uploads data late, next sync catches it
- Works with delayed HealthKit syncs

### ✅ Deduplication Already Implemented
```swift
// In processSleepSession()
if let existingSession = try await sleepRepository.fetchSession(
    bySourceID: sourceID, forUserID: userID.uuidString
) {
    print("⏭️ Already exists, skipping")
    return false
}
```

### ✅ Self-Healing
- If data was missed previously, next sync will catch it
- No manual intervention required

### ✅ Simpler Architecture
- No need for sync tracking
- No need to mark dates as "synced"
- Easier to reason about

---

## Performance Considerations

### Query Size
```
Old approach: 24 hours → ~5-20 samples
New approach: 7 days → ~35-140 samples
```

**Impact:** Minimal increase (HealthKit queries are fast)

### Deduplication
- Already implemented at repository level
- Uses sourceID (HealthKit UUID) for exact matching
- No duplicate sessions in database

### Frequency
- Daily background sync: Queries 7 days, saves only new sessions
- On-demand sync: Same behavior
- Manual re-sync: Safe to run multiple times

---

## Alternative Approaches Considered

### Option A: HealthKit Observer (Best Practice)
```swift
// Real-time sync when data arrives
let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { ... }
```

**Pros:**
- Most efficient (event-driven)
- Real-time sync
- No polling required

**Cons:**
- More complex implementation
- Requires background delivery setup
- Can be implemented later

**Decision:** Implement as future enhancement

### Option B: Sync Last 30 Days
**Pros:** Captures even more historical data

**Cons:** 
- Slower queries
- Unnecessary for most users
- 7 days sufficient for normal use

**Decision:** 7 days is optimal balance

### Option C: Keep Date-Based with Backfill
**Pros:** Maintains existing architecture

**Cons:**
- Adds complexity
- Doesn't solve retroactive data issue
- Still requires sync tracking

**Decision:** Rejected - architectural debt

---

## Migration Strategy

### Existing Data
- ✅ No migration needed
- ✅ Existing sleep sessions remain unchanged
- ✅ New sync will fill in any gaps

### Sync Tracking
- ⚠️ Sync tracking still exists for other metrics
- Sleep metric no longer uses it (ignored)
- Can be removed in future refactor

### Testing
1. **Verify no duplicates:**
   ```swift
   // Check database for duplicate sessions by sourceID
   let sessions = try await sleepRepository.fetchAllSessions(forUserID: userID)
   let sourceIDs = sessions.map { $0.sourceID }
   assert(sourceIDs.count == Set(sourceIDs).count, "Duplicates found!")
   ```

2. **Verify all sessions captured:**
   - Open Health app
   - Compare sleep data with FitIQ
   - Should match exactly

3. **Verify performance:**
   - Sync should complete in < 5 seconds
   - Even with 7 days of data

---

## Code Changes

### Modified Files

1. **`SleepSyncHandler.swift`**
   - Added `syncRecentSleepData()` method
   - Modified `syncDaily()` to use recent data sync
   - Deprecated old `syncDate()` method
   - Added extensive debug logging

2. **No Breaking Changes**
   - `syncDaily()` signature unchanged
   - `syncHistorical()` signature unchanged
   - Existing callers work without modification

### Debug Logging Added

```
SleepSyncHandler: 🌙 STARTING RECENT SLEEP SYNC
================================================================================
SleepSyncHandler: Query range: Last 7 days
SleepSyncHandler: Start: [date]
SleepSyncHandler: End: [date]
--------------------------------------------------------------------------------
SleepSyncHandler: ✅ HEALTHKIT SAMPLES RETRIEVED
SleepSyncHandler: Fetched X sleep samples from HealthKit
--------------------------------------------------------------------------------
  [0] ----------------------------------------------------------------
        Stage: core         | Duration: 120 min | isActualSleep: ✅
        Start: [timestamp]
        End:   [timestamp]
        Source: Apple Watch
--------------------------------------------------------------------------------
SleepSyncHandler: Total duration from all samples: 480 minutes (8.0h)
--------------------------------------------------------------------------------
SleepSyncHandler: 🔗 GROUPING SAMPLES INTO SESSIONS
SleepSyncHandler: Grouped into 2 session(s) from 35 samples
--------------------------------------------------------------------------------
SleepSyncHandler: 💾 PROCESSING & SAVING SESSIONS
✅ Session 1: SAVED
⏭️  Session 2: SKIPPED (already exists)
--------------------------------------------------------------------------------
SleepSyncHandler: ✅ Saved: 1, Skipped: 1, Total: 2
================================================================================
```

---

## Future Enhancements

### Phase 2: HealthKit Observer
- Implement `HKObserverQuery` for real-time sync
- React to new data immediately
- More efficient than polling

### Phase 3: Remove Sync Tracking for Sleep
- Clean up unused sync tracking code
- Simplify architecture further

### Phase 4: Apply to Other Metrics
- Heart rate might benefit from recent data sync
- Evaluate on case-by-case basis

---

## Testing Checklist

- [ ] Run app and trigger sleep sync
- [ ] Verify all recent sleep sessions are captured
- [ ] Check logs for proper session grouping
- [ ] Verify no duplicate sessions in database
- [ ] Test with delayed HealthKit data
- [ ] Test with multi-day gap between app opens
- [ ] Verify sync completes in < 5 seconds
- [ ] Compare with Health app data (should match)

---

## Related Documents

- **Debug Guide:** `docs/debugging/SLEEP_DISPLAY_DEBUG_GUIDE.md`
- **Sleep API Spec:** `docs/api-integration/SLEEP_API_SPEC_UPDATE.md`
- **Sleep Schema:** `Infrastructure/Persistence/Schema/SCHEMA_V4_SLEEP_TRACKING.md`

---

## Lessons Learned

1. **Date-based sync doesn't work for time-spanning events**
   - Sleep, long workouts, multi-day activities need different approach

2. **Sync tracking can create more problems than it solves**
   - "Already synced" flags prevent self-healing
   - Consider carefully before using

3. **Deduplication is key**
   - Always use stable identifiers (HealthKit sourceID)
   - Enables safe re-syncing

4. **Query recent data is simpler than date-based logic**
   - Less code, fewer edge cases
   - More reliable

5. **Event-driven > polling**
   - HKObserverQuery is the gold standard
   - Implement when time allows

---

**Status:** ✅ Implemented  
**Next Steps:** Test thoroughly and monitor production logs  
**Last Updated:** 2025-01-27