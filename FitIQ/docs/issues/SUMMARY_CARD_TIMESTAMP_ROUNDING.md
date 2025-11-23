# Summary Card Timestamp Rounding Issue

**Date:** 2025-01-27  
**Status:** 🔴 Active Issue  
**Priority:** High (User-facing)  
**Affects:** Heart Rate and Steps summary cards

---

## 🐛 Problem Statement

The Summary View cards (Heart Rate, Steps) are showing **rounded hour timestamps** instead of **exact timestamps** when new data arrives from HealthKit.

**Example:**
- **Current Time:** 6:12 PM
- **Apple Watch syncs:** 78 BPM at 6:12 PM
- **UI Shows:** "78 BPM at 6:00" ❌
- **Expected:** "78 BPM at 6:12" ✅

**Impact:**
- Users see outdated timestamps
- Data appears stale even though it's fresh
- Confusing user experience

---

## 🔍 Root Cause Analysis

### The Data Flow

```
1. Apple Watch syncs heart rate at 6:12 PM
    ↓
2. HealthKit stores individual sample with timestamp 6:12:00
    ↓
3. HeartRateSyncHandler.syncRecentHeartRateData() executes
    ↓
4. Calls healthRepository.fetchHourlyStatistics()
    ↓
5. Returns: [6:00 PM: 78 BPM] ← ROUNDED TO HOUR
    ↓
6. Saves to Progress DB with date = 6:00 PM
    ↓
7. SummaryViewModel fetches from Progress DB
    ↓
8. UI displays: "78 BPM at 6:00" ❌
```

### Why It's Rounded

**HeartRateSyncHandler** uses `fetchHourlyStatistics()` which:
- Aggregates heart rate data into **hourly buckets**
- Returns one average per hour (e.g., average of all readings from 6:00-6:59)
- Date keys are **start of each hour** (6:00, 7:00, 8:00, etc.)
- This is by design for historical tracking and efficiency

**SaveHeartRateProgressUseCase** receives:
- `heartRate: 78`
- `date: 6:00 PM` ← Already rounded by HealthKit statistics query

**Result:**
- Progress DB stores: `(78 BPM, 6:00 PM)`
- Summary card displays: "6:00" instead of "6:12"

---

## 🎯 Design Conflict

The system has **two competing requirements:**

### 1. Historical Tracking (Current Design)
- **Goal:** Efficient storage and historical analysis
- **Method:** Hourly aggregates (one entry per hour)
- **Use Case:** Charts, trends, backend sync
- **Storage:** Progress DB with hourly granularity
- **Works Well:** ✅ Reduces data volume, easy to chart

### 2. Real-Time Display (User Expectation)
- **Goal:** Show exact timestamp of latest reading
- **Method:** Individual samples with exact timestamps
- **Use Case:** Summary card, "current" metrics
- **Storage:** Need direct HealthKit access
- **Current Issue:** ❌ Using hourly aggregates for real-time display

---

## ✅ Recommended Solution

### Option 1: Dual Data Source (Recommended)

**Concept:**
- **Historical data:** Continue using hourly aggregates from Progress DB
- **Summary card:** Fetch latest individual sample directly from HealthKit

**Implementation:**

1. **Create new use case:** `GetLatestHeartRateFromHealthKitUseCase`
   - Fetches most recent individual sample from HealthKit
   - Returns exact timestamp (e.g., 6:12:37)
   - Used ONLY for summary card display

2. **Update SummaryViewModel:**
   - Add dependency: `getLatestHeartRateFromHealthKitUseCase`
   - In `fetchLatestHeartRate()`: Call HealthKit directly
   - Store: `latestHeartRate`, `latestHeartRateDate` (exact timestamp)

3. **Keep existing sync:**
   - HeartRateSyncHandler continues using hourly aggregates
   - Progress DB continues storing hourly data
   - Historical views use Progress DB

**Benefits:**
- ✅ Real-time timestamps for summary card
- ✅ Efficient historical storage unchanged
- ✅ Clean separation of concerns
- ✅ No breaking changes to existing sync

**Tradeoffs:**
- Requires two data sources (HealthKit + Progress DB)
- Slightly more complex ViewModel logic
- Need to handle HealthKit authorization

---

### Option 2: Store Both Aggregate and Latest (Not Recommended)

**Concept:**
- Continue storing hourly aggregates
- Add separate table/field for "latest sample" with exact timestamp

**Problems:**
- Duplicate data storage
- More complex sync logic
- Unclear which source is "truth"

---

### Option 3: Change to Individual Samples (Not Recommended)

**Concept:**
- Stop using hourly aggregates
- Store every individual heart rate sample

**Problems:**
- Massive increase in data volume (hundreds of samples per day)
- Backend API would need to handle this
- Performance issues in database queries
- Breaks current architecture

---

## 📋 Implementation Plan

### Phase 1: Create HealthKit Direct Fetch Use Case ✅

**File:** `GetLatestHeartRateFromHealthKitUseCase.swift`

```swift
protocol GetLatestHeartRateFromHealthKitUseCase {
    func execute() async throws -> (heartRate: Double, timestamp: Date)?
}

final class GetLatestHeartRateFromHealthKitUseCaseImpl: GetLatestHeartRateFromHealthKitUseCase {
    private let healthRepository: HealthRepositoryProtocol
    
    func execute() async throws -> (heartRate: Double, timestamp: Date)? {
        let sample = try await healthRepository.fetchLatestQuantitySample(
            for: .heartRate,
            unit: .count().unitDivided(by: .minute())
        )
        return sample.map { (heartRate: $0.value, timestamp: $0.date) }
    }
}
```

**Status:** ✅ Created

---

### Phase 2: Register in AppDependencies

**File:** `AppDependencies.swift`

```swift
// Add property
let getLatestHeartRateFromHealthKitUseCase: GetLatestHeartRateFromHealthKitUseCase

// In init()
self.getLatestHeartRateFromHealthKitUseCase = getLatestHeartRateFromHealthKitUseCase

// In build()
let getLatestHeartRateFromHealthKitUseCase = GetLatestHeartRateFromHealthKitUseCaseImpl(
    healthRepository: healthRepository
)

// Pass to dependencies
getLatestHeartRateFromHealthKitUseCase: getLatestHeartRateFromHealthKitUseCase
```

**Status:** ⏳ TODO

---

### Phase 3: Update SummaryViewModel

**File:** `SummaryViewModel.swift`

```swift
// Add dependency
private let getLatestHeartRateFromHealthKitUseCase: GetLatestHeartRateFromHealthKitUseCase

// Update init()
init(
    // ... existing params
    getLatestHeartRateFromHealthKitUseCase: GetLatestHeartRateFromHealthKitUseCase
) {
    // ... existing assignments
    self.getLatestHeartRateFromHealthKitUseCase = getLatestHeartRateFromHealthKitUseCase
}

// Update fetchLatestHeartRate()
@MainActor
private func fetchLatestHeartRate() async {
    do {
        // Fetch latest individual sample from HealthKit (exact timestamp)
        if let result = try await getLatestHeartRateFromHealthKitUseCase.execute() {
            latestHeartRate = result.heartRate
            latestHeartRateDate = result.timestamp  // EXACT time like 6:12
            print("✅ Latest heart rate: \(Int(result.heartRate)) bpm at \(result.timestamp)")
        } else {
            latestHeartRate = nil
            latestHeartRateDate = nil
        }
    } catch {
        print("❌ Error fetching latest heart rate from HealthKit: \(error)")
        // Keep last values on error
    }
}
```

**Status:** ⏳ TODO

---

### Phase 4: Same Fix for Steps

**Files:**
- `GetLatestStepsFromHealthKitUseCase.swift` (new)
- `SummaryViewModel.swift` (update)
- `AppDependencies.swift` (register)

**Status:** ⏳ TODO

---

## 🧪 Testing

### Test Case 1: Fresh Data at Mid-Hour

**Setup:**
1. Current time: 6:12 PM
2. Last heart rate in DB: 72 BPM at 6:00 PM
3. Apple Watch records: 78 BPM at 6:12:37 PM

**Expected Result:**
- Summary card shows: "78 BPM at 6:12" ✅
- Progress DB still has: 72 BPM at 6:00 PM (until hourly sync)
- No conflicts between data sources

### Test Case 2: Hourly Sync After Individual Sample

**Setup:**
1. Summary card shows: 78 BPM at 6:12 PM (from HealthKit)
2. Hourly sync runs at 6:05 PM
3. Saves aggregate: 75 BPM at 6:00 PM (average of 6:00-6:59)

**Expected Result:**
- Summary card STILL shows: 78 BPM at 6:12 PM (latest individual sample)
- Progress DB has: 75 BPM at 6:00 PM (hourly average)
- Individual sample (78) is more recent than aggregate (75)

### Test Case 3: HealthKit Authorization Denied

**Setup:**
1. User denies HealthKit access
2. Only Progress DB data available

**Expected Result:**
- Summary card falls back to Progress DB data
- Shows: "75 BPM at 6:00" (hourly aggregate)
- Graceful degradation ✅

---

## 📊 Data Architecture

### Current (Single Source)

```
HealthKit
    ↓ (hourly aggregates)
HeartRateSyncHandler
    ↓ (saves rounded timestamps)
Progress DB [6:00: 72, 7:00: 78, ...]
    ↓ (fetches)
SummaryViewModel
    ↓ (displays)
Summary Card: "78 BPM at 7:00" ❌
```

### Proposed (Dual Source)

```
HealthKit
    ↓ (hourly aggregates)          ↓ (latest individual sample)
HeartRateSyncHandler              GetLatestHeartRateFromHealthKitUseCase
    ↓                                   ↓
Progress DB                         SummaryViewModel (direct)
    ↓                                   ↓
Historical Views                    Summary Card: "78 BPM at 6:12" ✅
```

---

## 🎯 Benefits Summary

### For Users
✅ **Accurate timestamps** - See exactly when data was captured  
✅ **Real-time feel** - Data appears fresh and current  
✅ **Less confusion** - Timestamps match expectations  
✅ **Better trust** - App shows precise information

### For System
✅ **Preserves existing architecture** - Hourly aggregates unchanged  
✅ **Efficient historical storage** - No data volume increase  
✅ **Clean separation** - Real-time vs. historical data  
✅ **Fallback support** - Works without HealthKit access

---

## 🚨 Important Notes

### Don't Break Hourly Aggregates

The hourly aggregate system is working correctly for:
- Historical charts
- Backend synchronization
- Efficient storage
- Trend analysis

**DO NOT modify:**
- ❌ HeartRateSyncHandler
- ❌ SaveHeartRateProgressUseCase (hourly rounding)
- ❌ Progress DB schema
- ❌ Sync architecture

**ONLY add:**
- ✅ New use case for direct HealthKit fetch
- ✅ SummaryViewModel logic to prefer HealthKit samples
- ✅ Fallback to Progress DB if HealthKit unavailable

### HealthKit Authorization

The new use case requires HealthKit read access:
- Check authorization before querying
- Handle denial gracefully
- Fall back to Progress DB data
- Don't break if HealthKit unavailable

### Performance

Fetching latest sample from HealthKit:
- **Cost:** ~5-50ms (very fast)
- **Frequency:** Only when summary view refreshes
- **Volume:** 1 sample (not aggregates)
- **Impact:** Negligible

---

## 📚 Related Files

### Files to Create
- `Domain/UseCases/GetLatestHeartRateFromHealthKitUseCase.swift` ✅
- `Domain/UseCases/GetLatestStepsFromHealthKitUseCase.swift` ⏳

### Files to Modify
- `Infrastructure/Configuration/AppDependencies.swift`
- `Presentation/ViewModels/SummaryViewModel.swift`

### Files to NOT Touch
- `HeartRateSyncHandler.swift` (keep hourly aggregates)
- `SaveHeartRateProgressUseCase.swift` (keep as-is)
- `Progress DB schema` (no changes needed)

---

## ✅ Status

**Current State:**
- ✅ Root cause identified
- ✅ Solution designed
- ✅ Use case created (GetLatestHeartRateFromHealthKitUseCase)
- ⏳ AppDependencies registration
- ⏳ SummaryViewModel integration
- ⏳ Steps equivalent (GetLatestStepsFromHealthKitUseCase)
- ⏳ Testing

**Next Steps:**
1. Register use case in AppDependencies
2. Update SummaryViewModel to use it
3. Create GetLatestStepsFromHealthKitUseCase
4. Test with real device
5. Verify fallback behavior

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Solution:** Dual data source (HealthKit for real-time, Progress DB for historical)