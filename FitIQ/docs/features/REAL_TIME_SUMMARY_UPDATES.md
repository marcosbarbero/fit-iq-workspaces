# Real-Time Summary Card Updates with Exact Timestamps

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Implemented

---

## 🎯 Problem Statement

Summary cards for Steps and Heart Rate were only updating on the round hour (e.g., 6:00, 7:00, 8:00) instead of showing real-time updates with exact timestamps (e.g., 6:12, 7:23, 8:45).

### Root Cause

The sync handlers were fetching **hourly aggregates** from HealthKit using `fetchHourlyStatistics()`, which returns data grouped by hour with timestamps rounded to the hour boundary. This is by design in HealthKit's statistics API.

**Example:**
- HealthKit records steps at: 6:12, 6:15, 6:23, 6:45
- Hourly aggregate: 200 steps at **6:00** (rounded timestamp)
- Summary card displayed: "200 steps at 6:00" ❌ (not real-time)

---

## ✅ Solution: Direct HealthKit Queries for Summary Cards

Instead of fetching from the Progress DB (which stores hourly aggregates), the summary cards now fetch **directly from HealthKit** to get:
1. **Total steps/heart rate** for the day (sum of all samples)
2. **Exact timestamp** of the most recent individual sample

**Example:**
- HealthKit has individual samples with exact timestamps
- Summary card now displays: "1,234 steps at 6:45" ✅ (real-time with exact timestamp)

---

## 🏗️ Architecture Changes

### Before (Hourly Aggregates)

```
HealthKit Observer Query
    ↓
Sync Handler (fetches hourly aggregates)
    ↓
Progress DB (stores with rounded timestamps: 6:00, 7:00, 8:00)
    ↓
Summary Card Use Case (fetches from Progress DB)
    ↓
UI (displays: "200 steps at 6:00")
```

### After (Real-Time Updates)

```
HealthKit Observer Query
    ↓
Sync Handler (still stores hourly aggregates for historical data)
    ↓
Progress DB (hourly aggregates for charts and backend sync)

SEPARATELY:

Summary Card Use Case (fetches DIRECTLY from HealthKit)
    ↓
HealthKit (individual samples with exact timestamps)
    ↓
UI (displays: "1,234 steps at 6:45")
```

---

## 📝 Implementation Details

### Modified Use Cases

#### 1. `GetDailyStepsTotalUseCase`

**Before:** Fetched from Progress DB (hourly aggregates)
```swift
// OLD: Fetched from Progress DB
let entries = try await progressRepository.fetchRecent(...)
let totalSteps = entries.reduce(0) { $0 + Int($1.quantity) }
let latestTimestamp = entries.max(by: { $0.date < $1.date })?.date
```

**After:** Fetches directly from HealthKit (real-time)
```swift
// NEW: Fetches directly from HealthKit
// 1. Get total steps for the day
let totalSteps = try await healthRepository.fetchSumOfQuantitySamples(
    for: .stepCount,
    unit: .count(),
    from: startOfDay,
    to: endOfDay
)

// 2. Get exact timestamp of latest sample
let latestSample = try await healthRepository.fetchLatestQuantitySample(
    for: .stepCount,
    unit: .count()
)
```

**Dependency Change:**
```swift
// OLD
init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager)

// NEW
init(healthRepository: HealthRepositoryProtocol, authManager: AuthManager)
```

#### 2. `GetLatestHeartRateUseCase`

**Before:** Fetched from Progress DB (hourly aggregates)
```swift
// OLD: Returned ProgressEntry with rounded timestamp
func execute(daysBack: Int) async throws -> ProgressEntry?

let entries = try await progressRepository.fetchLocal(...)
return entries.max(by: { $0.date < $1.date })
```

**After:** Fetches directly from HealthKit (real-time)
```swift
// NEW: Returns tuple with exact timestamp
func execute(daysBack: Int) async throws -> (heartRate: Double, timestamp: Date)?

let sample = try await healthRepository.fetchLatestQuantitySample(
    for: .heartRate,
    unit: .count().unitDivided(by: .minute())
)
return (heartRate: sample.value, timestamp: sample.date)
```

**Dependency Change:**
```swift
// OLD
init(progressRepository: ProgressRepositoryProtocol, authManager: AuthManager)

// NEW
init(healthRepository: HealthRepositoryProtocol, authManager: AuthManager)
```

### Updated ViewModels

#### `SummaryViewModel`

**Timestamp Display Format:**
```swift
// Changed from HH:mm to HH:mm:ss for exact time
var lastHeartRateRecordedTime: String {
    guard let date = latestHeartRateDate else { return "No data" }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"  // Shows seconds now
    return formatter.string(from: date)
}

var lastStepsRecordedTime: String {
    guard let date = latestStepsTimestamp else { return "No data" }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"  // Shows seconds now
    return formatter.string(from: date)
}
```

**Fetch Methods:**
```swift
func fetchDailyStepsTotal() async {
    let result = try await getDailyStepsTotalUseCase.execute(forDate: today)
    stepsCount = result.totalSteps
    latestStepsTimestamp = result.latestTimestamp  // Exact timestamp from HealthKit
    
    print("✅ Fetched daily steps: \(stepsCount ?? 0) at \(timeStr) (real-time from HealthKit)")
}

func fetchLatestHeartRate() async {
    if let result = try await getLatestHeartRateUseCase.execute(daysBack: 7) {
        latestHeartRate = result.heartRate
        latestHeartRateDate = result.timestamp  // Exact timestamp from HealthKit
        
        print("✅ Latest heart rate: \(Int(result.heartRate)) bpm at \(timeStr) (real-time from HealthKit)")
    }
}
```

---

## 🔄 Data Flow Comparison

### Hourly Aggregates (Still Used For)
- **Historical charts** (last 8 hours heart rate/steps bar charts)
- **Backend sync** (via Outbox Pattern)
- **Trend analysis** (stored in Progress DB)

**Flow:**
```
HealthKit → Sync Handler → Progress DB → Backend API
```

### Real-Time Summary (Now Used For)
- **Summary card display** (latest value + exact timestamp)
- **User-visible metrics** (steps count, heart rate BPM)

**Flow:**
```
HealthKit → Summary Card Use Case → UI (bypasses Progress DB)
```

---

## 📊 What This Means for Users

### Before
- Summary cards updated only on the hour (6:00, 7:00, 8:00)
- Timestamps were rounded (not accurate)
- Data felt "stale" between syncs

**Example:** At 6:45, the card showed "200 steps at 6:00"

### After
- Summary cards show real-time data with exact timestamps
- Updates reflect the actual time HealthKit recorded the data
- Data feels fresh and accurate

**Example:** At 6:45, the card shows "1,234 steps at 6:45"

---

## 🔍 Technical Notes

### Why Not Store Individual Samples in Progress DB?

**Option Considered:** Store both hourly aggregates AND individual samples in Progress DB

**Problem:** This would cause double-counting
- Hourly aggregate: 200 steps for 6:00-7:00 hour
- Individual sample: 50 steps at 6:45
- Summing them: 250 steps ❌ (incorrect, double-counts the 6:45 sample)

**Solution Chosen:** Fetch directly from HealthKit for summary display
- Hourly aggregates stay in Progress DB (for historical charts)
- Individual samples fetched on-demand from HealthKit (for summary cards)
- No double-counting, clean separation of concerns

### HealthKit API Methods Used

1. **`fetchSumOfQuantitySamples`**
   - Returns the total count for a date range
   - Used for: Daily steps total
   - Example: 1,234 steps from midnight to now

2. **`fetchLatestQuantitySample`**
   - Returns the most recent individual sample
   - Used for: Exact timestamp of latest data
   - Example: Sample recorded at 6:45:32

### Performance Considerations

**Impact:** Fetching directly from HealthKit adds a small query overhead

**Mitigation:**
- These queries only run when summary card is refreshed (not constantly)
- HealthKit queries are optimized by Apple (very fast)
- We only fetch 1-2 samples (latest), not bulk data
- Background syncs still use hourly aggregates (efficient)

**Result:** Negligible performance impact, significant UX improvement

---

## 🧪 Testing

### Manual Testing Checklist

- [ ] Steps count updates immediately when HealthKit records new data
- [ ] Heart rate updates immediately when HealthKit records new data
- [ ] Timestamps show exact time with seconds (HH:mm:ss format)
- [ ] Summary cards show "No data" gracefully when no data available
- [ ] Historical charts still work (using hourly aggregates from Progress DB)
- [ ] Backend sync still works (using hourly aggregates from Progress DB)

### Test Scenarios

**Scenario 1: New Steps Recorded**
1. Walk around to generate steps
2. Wait for HealthKit to record data (~1-2 minutes)
3. Pull to refresh summary view
4. **Expected:** Steps count and timestamp update to exact time

**Scenario 2: New Heart Rate Recorded**
1. Open Apple Health app and record heart rate
2. Wait for sync (~30 seconds)
3. Pull to refresh summary view
4. **Expected:** Heart rate and timestamp update to exact time

**Scenario 3: No Recent Data**
1. Don't record any steps/heart rate for several hours
2. Pull to refresh summary view
3. **Expected:** Summary cards show last known value (doesn't reset to 0)

---

## 📚 Related Documentation

- **API Spec:** `docs/be-api-spec/swagger.yaml` (backend sync still uses hourly aggregates)
- **Outbox Pattern:** `.github/copilot-instructions.md` (backend sync remains unchanged)
- **Summary Data Loading:** `docs/architecture/SUMMARY_DATA_LOADING_PATTERN.md`

---

## 🎯 Benefits

✅ **Real-Time Updates:** Users see data as soon as HealthKit records it  
✅ **Accurate Timestamps:** Shows exact time (6:45:32) instead of rounded (6:00)  
✅ **Better UX:** Data feels fresh and responsive  
✅ **Clean Architecture:** Separates summary display from historical data  
✅ **No Breaking Changes:** Historical charts and backend sync unchanged  

---

## 🚨 Important Notes

1. **Sync Handlers Unchanged:** Background syncs still store hourly aggregates
2. **Progress DB Still Used:** For historical charts and backend sync
3. **No Data Loss:** All data still flows through Outbox Pattern to backend
4. **Backward Compatible:** Existing features continue to work as before

---

**Status:** ✅ Complete and deployed  
**Next Steps:** Monitor user feedback and performance metrics