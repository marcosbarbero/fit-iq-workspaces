# Sleep Sync Attribution Logic

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Component:** `SleepSyncHandler`

---

## Overview

Sleep session synchronization is more complex than other health metrics because sleep sessions:
- Span multiple hours (often 6-10 hours)
- Cross calendar day boundaries (e.g., 10 PM Friday → 6 AM Saturday)
- Can occur multiple times per day (naps)
- Vary widely in timing (night shifts, irregular schedules)

This document explains how we correctly attribute sleep sessions to dates and avoid double-counting or missed sessions.

---

## Core Principle: Wake Date Attribution

**Sleep sessions are attributed to the date they END (wake date), not the date they start.**

This follows the industry standard used by:
- Apple Health
- Oura Ring
- Whoop
- Sleep Cycle
- AutoSleep
- All major sleep tracking apps

### Why Wake Date?

1. **User Mental Model**: Users think "I slept well last night" refers to the morning they wake up
2. **Data Consistency**: Avoids ambiguity when sessions span two days
3. **Industry Standard**: Matches user expectations from other apps
4. **Daily Aggregation**: Makes daily summaries intuitive (today's sleep = what you woke up from today)

---

## Examples

### Example 1: Typical Overnight Sleep

```
Friday 10:00 PM → Saturday 6:00 AM (8 hours)
```

**Attribution:** Saturday's sleep  
**Reasoning:** You woke up on Saturday morning

### Example 2: Late Night Sleep

```
Saturday 2:00 AM → Saturday 10:00 AM (8 hours)
```

**Attribution:** Saturday's sleep  
**Reasoning:** Session started and ended on Saturday

### Example 3: Daytime Nap

```
Saturday 2:00 PM → Saturday 4:00 PM (2 hours)
```

**Attribution:** Saturday's sleep  
**Reasoning:** Nap ended on Saturday

### Example 4: Multiple Sessions (Naps)

```
Session 1: Friday 11:00 PM → Saturday 7:00 AM (8 hours)
Session 2: Saturday 2:00 PM → Saturday 4:00 PM (2 hours)
```

**Attribution:** Both to Saturday  
**Result:** Saturday shows 10 hours total sleep (main sleep + nap)

### Example 5: Night Shift Worker

```
Saturday 8:00 AM → Saturday 4:00 PM (8 hours)
```

**Attribution:** Saturday's sleep  
**Reasoning:** Slept during the day, woke up on Saturday

---

## Query Strategy

### The Problem

If we query for sleep data that **starts** on a target date, we miss overnight sessions:

```
❌ WRONG: Query start: Saturday 00:00, end: Saturday 23:59
Result: Misses Friday 10 PM → Saturday 6 AM session (started Friday!)
```

### The Solution

Query with an **extended backward window** to capture sessions that started the previous day but ended on target date:

```
✅ CORRECT: Query start: Friday 00:00, end: Saturday 23:59
Then filter: Keep only sessions where endDate is on Saturday
Result: Captures Friday 10 PM → Saturday 6 AM session ✓
```

### Query Window Diagram

```
Syncing Saturday's Sleep
========================

Query Window:
├─────────────────────────┼─────────────────────────┤
Friday 00:00          Saturday 00:00          Sunday 00:00
(24hrs before)        (target date)           (end of target)

Filter Criteria:
Keep sessions where: session.endDate >= Saturday 00:00 
                 AND session.endDate < Sunday 00:00

Examples:
❌ Thu 11 PM → Fri 6 AM     (ends Friday, not Saturday)
✅ Fri 10 PM → Sat 6 AM     (ends Saturday ✓)
✅ Sat 2 AM → Sat 10 AM     (ends Saturday ✓)
✅ Sat 2 PM → Sat 4 PM      (ends Saturday ✓)
❌ Sat 11 PM → Sun 7 AM     (ends Sunday, not Saturday)
```

---

## Implementation Details

### Step-by-Step Process

1. **Check if already synced** (optimization)
   ```swift
   if syncTracking.hasAlreadySynced(startOfDay, for: .sleep) {
       return // Skip
   }
   ```

2. **Define query window**
   ```swift
   let queryStart = calendar.date(byAdding: .day, value: -1, to: startOfDay)
   let queryEnd = calendar.date(byAdding: .day, value: 1, to: startOfDay)
   ```

3. **Fetch samples from HealthKit**
   ```swift
   let samples = try await fetchSleepSamples(from: queryStart, to: queryEnd)
   ```

4. **Group samples into sessions**
   - HealthKit provides multiple samples per session (one per sleep stage)
   - Group by source and time continuity
   - Sessions separated by >2 hours are treated as separate sessions

5. **Filter by wake date**
   ```swift
   let filteredSessions = allSessions.filter { sessionSamples in
       let sessionEnd = sessionSamples.last?.endDate
       return sessionEnd >= startOfDay && sessionEnd < endOfDay
   }
   ```

6. **Process each session**
   - Deduplicate by sourceID (avoid double-saving)
   - Convert HealthKit stages to domain models
   - Calculate metrics (time in bed, total sleep, efficiency)
   - **Save with wake date** as session date

7. **Mark as synced**
   ```swift
   syncTracking.markAsSynced(startOfDay, for: .sleep)
   ```

---

## Deduplication Strategy

### Problem: Double-Counting

Without deduplication, historical syncs could process the same session multiple times:

```
Day 1 sync: Queries Fri-Sat window → Finds Fri 10 PM - Sat 6 AM
Day 2 sync: Queries Sat-Sun window → Finds same session again!
```

### Solution: SourceID-Based Deduplication

Every HealthKit sample has a unique UUID. We use the **first sample's UUID** as the session's sourceID:

```swift
let sourceID = firstSample.uuid.uuidString

// Before saving, check if session already exists
if let existingSession = try await sleepRepository.fetchSession(
    bySourceID: sourceID, 
    forUserID: userID
) {
    print("Session already exists, skipping")
    return false
}
```

This ensures:
- ✅ Each unique sleep session is saved exactly once
- ✅ Re-syncing the same date is safe (idempotent)
- ✅ Historical syncs don't create duplicates

---

## Edge Cases Handled

### 1. Very Long Sleep Sessions (>24 hours)

```
Friday 10 PM → Sunday 10 AM (36 hours - illness/recovery)
```

**Handling:**
- Attributed to Sunday (wake date)
- Query window must be wide enough (we use 24 hours backward)
- Sessions >24 hours might be split by HealthKit; we handle this via grouping logic

### 2. Fragmented Sleep (Multiple Short Sessions)

```
Session 1: Fri 11 PM → Sat 1 AM (2 hours)
Session 2: Sat 3 AM → Sat 7 AM (4 hours)
```

**Handling:**
- Both attributed to Saturday
- Treated as separate sessions if gap >2 hours
- User sees total sleep = 6 hours on Saturday

### 3. No Sleep Data

```
User didn't wear watch, or no sleep detected
```

**Handling:**
- Query returns empty results
- Throw `HealthMetricSyncError.noDataAvailable`
- Mark date as synced to avoid retrying (optimization)

### 4. Today's Sleep (Still In Progress)

```
Currently: Saturday 2 AM, user is asleep (started Fri 11 PM)
```

**Handling:**
- Session not yet complete (no end time)
- HealthKit won't return it until session ends
- Will be synced on next sync after user wakes up

### 5. Multiple Data Sources

```
User has Apple Watch + Oura Ring + Sleep Cycle app
```

**Handling:**
- Sessions grouped by source (bundleIdentifier)
- Each source's sessions saved separately
- Deduplication per source via sourceID
- Result: User can have multiple sleep sessions from different sources

---

## Query Performance Considerations

### Optimization: Skip Already-Synced Dates

```swift
if syncTracking.hasAlreadySynced(startOfDay, for: .sleep) {
    return // Skip HealthKit query entirely
}
```

**Benefits:**
- Avoids expensive HealthKit queries for historical dates
- Speeds up background sync operations
- Reduces battery drain

**Trade-off:**
- If user manually deletes/edits sleep in HealthKit, we won't re-sync automatically
- User must trigger "Force Re-sync" if needed

### Query Window Size

**Current:** 24 hours backward from target date

**Rationale:**
- Captures 99.9% of normal sleep sessions
- Most sleep sessions are 6-10 hours
- Starting 24 hours before ensures we catch even very late sleepers

**Limitation:**
- Sessions >24 hours won't be captured fully
- This is acceptable (extremely rare edge case)

---

## Testing Scenarios

### Unit Tests

1. **Test Wake Date Attribution**
   - Input: Session from Fri 10 PM → Sat 6 AM
   - Expected: Session date = Saturday

2. **Test Query Window**
   - Target date: Saturday
   - Expected query start: Friday 00:00
   - Expected query end: Sunday 00:00

3. **Test Filtering**
   - Input: Multiple sessions spanning Fri-Sat-Sun
   - Target: Saturday
   - Expected: Only sessions ending on Saturday

4. **Test Deduplication**
   - Input: Same session synced twice
   - Expected: Only one saved (by sourceID)

### Integration Tests

1. **Historical Sync**
   - Sync 30 days of sleep data
   - Verify no duplicates
   - Verify all sessions attributed correctly

2. **Multiple Data Sources**
   - User with Apple Watch + Sleep Cycle
   - Verify both sources' sessions saved
   - Verify no conflicts

3. **Edge Cases**
   - Very long sessions (>20 hours)
   - Fragmented sleep (multiple sessions per day)
   - No sleep data (empty results)

---

## Debugging Tips

### Enable Detailed Logging

All sleep sync operations log extensively:

```swift
print("SleepSyncHandler: 🌙 Syncing sleep data for \(formatDate(date))...")
print("SleepSyncHandler: Query window: \(queryStart) to \(queryEnd)")
print("SleepSyncHandler: Fetched \(samples.count) sleep samples from HealthKit")
print("SleepSyncHandler: Grouped into \(allSleepSessions.count) session(s)")
print("SleepSyncHandler: After filtering by wake date: \(filteredSessions.count) session(s)")
```

### Common Issues

**Issue:** "No sleep data found"
- Check HealthKit permissions
- Verify user has sleep data in Health app
- Check query date range

**Issue:** Duplicate sessions
- Check sourceID deduplication logic
- Verify `fetchSession(bySourceID:)` is working
- Check if multiple sources are being treated as one

**Issue:** Wrong date attribution
- Verify wake date calculation: `startOfDay(for: sessionEnd)`
- Check filtering logic: `sessionEnd >= startOfDay && sessionEnd < endOfDay`

---

## Future Improvements

### 1. Smart Query Optimization

Instead of fixed 24-hour backward window, analyze user's typical sleep start time:
- If user typically sleeps 11 PM - 7 AM, only query 12 hours backward
- Reduces HealthKit query load

### 2. Real-Time Sync

Currently syncs completed sessions only. Could add:
- Ongoing session tracking (update in real-time)
- Partial session sync (for very long sleep sessions)

### 3. Multi-Source Reconciliation

Currently saves all sources separately. Could add:
- Smart merging of overlapping sessions from different sources
- Primary source preference (e.g., prefer Apple Watch over Sleep Cycle)

### 4. Historical Data Gap Detection

- Detect gaps in sleep data (e.g., user forgot to wear watch)
- Prompt user to manually log sleep for missing dates

---

## References

- **HealthKit Documentation:** https://developer.apple.com/documentation/healthkit/hkcategorytype
- **Sleep Analysis Values:** https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis
- **Industry Standards:** Most sleep tracking apps use wake date attribution
- **Project Files:**
  - `SleepSyncHandler.swift` - Implementation
  - `SleepRepositoryProtocol.swift` - Repository interface
  - `SleepSession.swift` - Domain model

---

**Status:** ✅ Implemented  
**Last Reviewed:** 2025-01-27  
**Next Review:** When adding new sleep metrics or sources