# Body Mass Current Weight Filter Bug Fix

**Date:** 2025-01-27  
**Type:** Bug Fix  
**Component:** Body Mass Tracking UI & Data Flow  
**Severity:** High (Data Integrity Issue)

---

## Problem

The Body Mass Detail View had multiple critical issues:

1. **Current Weight Changes with Filter**
   - Current weight was being calculated from `historicalData.last?.weightKg`
   - This value changed based on the selected time filter (7d, 30d, 90d, 1y, All)
   - Current weight should be a constant showing the absolute latest weight, regardless of filter

2. **Data Only Shows in "All" Filter**
   - Weight data only appeared when "All" filter was selected
   - Other filters (7d, 30d, 90d, 1y) showed empty charts
   - Historical entries displayed dates from ~5 years ago

3. **Suspicious Data Patterns**
   - Data appeared "mocked" or corrupted
   - Historical entries had very old timestamps
   - Suggests data source or integration issues

### User Impact

- Confusing UX where current weight value changes as user switches filters
- Cannot view recent weight trends (only very old data visible)
- Loss of trust in data accuracy
- Potential data source misconfiguration

---

## Root Cause Analysis

### Issue 1: Current Weight Calculation

**Location:** `BodyMassDetailView.swift` line ~46

```swift
// ❌ WRONG: Current weight from filtered data
let latestWeight = viewModel.historicalData.last?.weightKg ?? 0.0
```

**Problem:**
- `historicalData` changes based on `selectedRange` filter
- When filter is "7d", only shows last 7 days of data
- If no data exists in last 7 days, shows 0.0 or nothing
- Current weight is NOT a constant - it changes with every filter selection

### Issue 2: Data Source Investigation Required

**Symptoms:**
- Data only appears in "All" filter (looks back 5 years)
- Other filters show empty/zero
- Historical entries have very old dates

**Possible Causes:**

1. **HealthKit Data Age**
   - User may have old HealthKit data from years ago
   - No recent weight entries in HealthKit
   - `GetHistoricalWeightUseCase` prioritizes HealthKit when it has newer data

2. **Backend Data Sync Issues**
   - Backend may not have recent weight data
   - Sync between HealthKit → SwiftData → Backend may be broken
   - Rate limiting may have prevented recent syncs

3. **Date Range Query Bug**
   - Queries for recent date ranges (7d, 30d) return empty
   - Query for "All" (5 years) returns old data
   - Suggests data exists but is older than expected

4. **SwiftData Predicate Issues**
   - Previous bugs with predicates returning wrong data
   - May be filtering incorrectly by date or type
   - Could be returning steps data instead of weight

---

## Solution

### Part 1: Fix Current Weight (Implemented)

#### ViewModel Changes (`BodyMassDetailViewModel.swift`)

**Added State Property:**
```swift
var currentWeight: Double?  // Latest weight independent of filter
```

**Added Method:**
```swift
@MainActor
private func loadCurrentWeight() async {
    do {
        // Fetch all-time data to get the absolute latest weight
        let allTimeStart = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        let allTimeEntries = try await getHistoricalWeightUseCase.execute(
            startDate: allTimeStart,
            endDate: Date()
        )
        
        // Get the latest entry (sorted newest first)
        currentWeight = allTimeEntries.first?.quantity
        
        print("BodyMassDetailViewModel: Current weight (latest ever): \(currentWeight.map { String(format: "%.1f", $0) } ?? "N/A") kg")
    } catch {
        print("BodyMassDetailViewModel: Failed to load current weight: \(error.localizedDescription)")
        // Fallback to historical data if available
        currentWeight = historicalData.last?.weightKg
    }
}
```

**Integration:**
```swift
func loadHistoricalData() async {
    // ... existing code to load filtered data ...
    
    // Fetch current weight separately (not filtered by date range)
    await loadCurrentWeight()
    
    // Calculate trend if we have enough data
    calculateWeightTrend()
}
```

#### View Changes (`BodyMassDetailView.swift`)

**Before:**
```swift
// Use the latest weight from the historical data
let latestWeight = viewModel.historicalData.last?.weightKg ?? 0.0
Text(String(format: "%.1f kg", latestWeight))
    .font(.system(size: 44, weight: .bold, design: .rounded))
    .foregroundColor(.primary)
```

**After:**
```swift
// Use the current weight (independent of filter)
if let currentWeight = viewModel.currentWeight {
    Text(String(format: "%.1f kg", currentWeight))
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .foregroundColor(.primary)
} else {
    Text("-- kg")
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .foregroundColor(.secondary)
}
```

**Key Changes:**
- Current weight now comes from `viewModel.currentWeight`
- This value is fetched once with 10-year lookback
- Value does NOT change when user switches filters
- Shows placeholder "--" when no data exists

---

### Part 2: Data Source Investigation (In Progress)

#### What We Know

1. **GetHistoricalWeightUseCase Strategy:**
   ```
   - Fetches from both Backend and HealthKit
   - Compares latest timestamps
   - Uses source with most recent data
   - Syncs HealthKit → SwiftData → Backend (asynchronously)
   ```

2. **Data Flow:**
   ```
   HealthKit → GetHistoricalWeightUseCase → SwiftData (local) → Backend (async sync)
                           ↓
                   BodyMassDetailViewModel
                           ↓
                   BodyMassDetailView
   ```

3. **CompositeProgressRepository:**
   - Wraps SwiftDataProgressRepository + ProgressAPIClient
   - Local-first architecture
   - Write to SwiftData immediately
   - Sync to backend asynchronously

#### What Needs Investigation

**User Action Items:**

1. **Check HealthKit Data:**
   - Open Apple Health app on device
   - Navigate to Body Measurements → Weight
   - Verify: Are there recent weight entries?
   - Check: What's the date of the latest entry?
   - Look for: Any entries from the last 7, 30, 90 days?

2. **Check Backend Data:**
   - Need API call to `GET /api/v1/progress/history?type=weight&start_date=<recent>&end_date=<now>`
   - Verify: Does backend have recent weight data?
   - Check: What's the date of the latest backend entry?
   - Compare: HealthKit vs Backend timestamps

3. **Check SwiftData Local Storage:**
   - Add debug logging to `SwiftDataProgressRepository.fetchLocal()`
   - Query for weight entries in last 90 days
   - Check: Are entries being saved locally?
   - Verify: Are sync statuses correct (pending/syncing/synced/failed)?

4. **Enable Debug Logging:**
   - All use cases already have extensive print statements
   - Run app with Xcode console open
   - Reproduce issue (switch filters)
   - Review logs for:
     - HealthKit fetch results
     - Backend API responses
     - SwiftData query results
     - Date range calculations

**Developer Action Items:**

1. **Add Date Range Validation:**
   - Verify `calculateStartDate()` returns correct dates
   - Print actual date ranges being queried
   - Confirm dates are in the past (not future)

2. **Add Data Source Logging:**
   - Log which source "wins" (HealthKit vs Backend)
   - Print first/last entry dates from each source
   - Show count of entries per date range

3. **Test Predicates:**
   - Ensure SwiftData predicates correctly filter by:
     - User ID
     - Type (weight only, not steps)
     - Date range
   - Previous bug: predicate returned ALL types instead of filtering

4. **Check for Date Normalization Issues:**
   - Weight entries normalized to start of day
   - Verify comparison logic handles this correctly
   - Check for timezone issues (UTC vs local)

---

## Testing Scenarios

### Scenario 1: Current Weight Consistency ✅

**Given:** User has weight data across multiple time periods  
**When:** User switches between filters (7d → 30d → 90d → 1y → All)  
**Then:**
- Current weight value remains constant
- Only the chart data changes
- Trend calculation updates based on visible data range

**Status:** ✅ **FIXED** - Current weight now independent of filter

### Scenario 2: Recent Data Visibility ⚠️

**Given:** User has weight entries in last 30 days  
**When:** User selects "30d" filter  
**Then:**
- Should show all entries from last 30 days
- Chart should display recent trend
- Historical entries list should show recent dates

**Status:** ⚠️ **UNDER INVESTIGATION** - Data only shows in "All" filter

### Scenario 3: Data Source Priority ⚠️

**Given:** HealthKit has weight from 2 days ago, Backend has weight from 5 years ago  
**When:** User loads Body Mass view  
**Then:**
- Should use HealthKit data (more recent)
- Should show weight from 2 days ago
- Should trigger background sync to update backend

**Status:** ⚠️ **UNDER INVESTIGATION** - May be using old backend data

---

## Current Status

### ✅ Completed

1. **Fixed Current Weight Display**
   - Current weight no longer changes with filter
   - Fetches absolute latest weight independently
   - Shows placeholder when no data exists

2. **Maintained Trend Calculation**
   - Trend still based on filtered date range
   - Only shows when sufficient data (2+ points, 1+ day)
   - Correctly calculates change over selected period

### ⚠️ In Progress

1. **Data Source Investigation**
   - Need to verify HealthKit data age
   - Need to verify backend data age
   - Need to check local SwiftData contents
   - Need to review sync status

2. **Root Cause Identification**
   - Why does data only show in "All" filter?
   - Why are dates from 5 years ago?
   - Is HealthKit the source of old data?
   - Is backend sync working correctly?

### 🔄 Next Steps

1. **User-Driven Debugging:**
   - Check Apple Health app for recent weight entries
   - Try logging new weight in Apple Health
   - Verify new entry appears in FitIQ app

2. **Developer-Driven Debugging:**
   - Enable verbose logging in GetHistoricalWeightUseCase
   - Add breakpoints in data fetch methods
   - Inspect SwiftData database contents
   - Review backend API responses

3. **Potential Fixes (Pending Investigation):**
   - May need to prioritize HealthKit differently
   - May need to fix date range calculations
   - May need to fix SwiftData predicates (again)
   - May need to trigger manual sync

---

## Related Files

### Modified

- `FitIQ/Presentation/ViewModels/BodyMassDetailViewModel.swift`
  - Added `currentWeight: Double?` property
  - Added `loadCurrentWeight()` method
  - Integrated into `loadHistoricalData()`

- `FitIQ/Presentation/UI/BodyMass/BodyMassDetailView.swift`
  - Changed current weight display to use `viewModel.currentWeight`
  - Added placeholder for missing data

### Investigation Targets

- `FitIQ/Domain/UseCases/GetHistoricalWeightUseCase.swift`
  - Data source priority logic
  - Date range filtering
  - HealthKit vs Backend comparison

- `FitIQ/Infrastructure/Persistence/SwiftDataProgressRepository.swift`
  - Local data fetch predicates
  - Date range filtering
  - Type filtering (weight vs steps)

- `FitIQ/Infrastructure/Network/ProgressAPIClient.swift`
  - Backend API calls
  - Query parameter formatting
  - Response parsing

- `FitIQ/Infrastructure/Persistence/CompositeProgressRepository.swift`
  - Local-first architecture
  - Sync coordination

### Related Documentation

- `docs/fixes/body-mass-predicate-bug-fix.md` - Previous predicate filtering bug
- `docs/fixes/body-mass-tracking-rate-limit-fix.md` - Background sync fixes
- `docs/fixes/body-mass-empty-chart-trend-fix.md` - Previous UI polish
- `docs/fixes/body-mass-tracking-phase3-implementation.md` - Overall implementation

---

## Debug Output Example

When investigating, look for logs like:

```
BodyMassDetailViewModel: Loading weight data from 2025-01-20 to 2025-01-27
GetHistoricalWeightUseCase: Fetching weight for user <UUID> from 2025-01-20 to 2025-01-27
GetHistoricalWeightUseCase: Found 0 entries from backend
GetHistoricalWeightUseCase: Found 0 samples from HealthKit
GetHistoricalWeightUseCase: No data from either source

BodyMassDetailViewModel: Loading weight data from 2020-01-27 to 2025-01-27
GetHistoricalWeightUseCase: Fetching weight for user <UUID> from 2020-01-27 to 2025-01-27
GetHistoricalWeightUseCase: Found 15 entries from backend
GetHistoricalWeightUseCase: Backend latest: 2020-02-15, HealthKit latest: none
GetHistoricalWeightUseCase: Using backend (HealthKit empty)
BodyMassDetailViewModel: Loaded 15 weight records
```

This would indicate:
- Recent queries return no data
- "All" query returns old data from 2020
- Backend has entries from 5 years ago
- HealthKit is empty

---

## Architecture Notes

### Why This Design?

**Current Weight Separation:**
- UI/UX requirement: Current weight is a "snapshot" metric
- Should not change when exploring historical trends
- Similar to bank balance: current balance vs. transaction history

**Filter Independence:**
- Filters are for exploring trends, not changing current state
- Current weight = absolute latest, regardless of when it was logged
- Trend = change over selected period

**Data Source Priority:**
- HealthKit is authoritative for Apple Health data
- Backend is for cross-platform sync and persistence
- Local SwiftData is for offline capability and performance

### Follows Project Guidelines

✅ **Hexagonal Architecture:**
- Business logic in Domain layer (ViewModel)
- Data fetching via Use Cases
- Multiple data sources coordinated via ports/adapters

✅ **No UI Layout Changes:**
- Only changed data binding
- Conditional rendering for missing data
- No styling or layout modifications

✅ **Proper Separation:**
- ViewModel calculates and holds current weight
- View displays current weight
- Use Case coordinates data sources

---

## Impact

### Fixed Issues

✅ Current weight no longer changes with filter selection  
✅ Proper placeholder for missing data  
✅ Maintains trend calculation for filtered ranges  

### Remaining Issues

⚠️ Data only visible in "All" filter  
⚠️ Historical data appears to be 5 years old  
⚠️ Need to investigate data source and sync  

### Performance

⚪ Neutral - One additional query at load time  
⚪ Query is same as "All" filter (10-year lookback)  
⚪ Cached by use case if needed  

---

**Status:** ✅ Part 1 Fixed, ⚠️ Part 2 Under Investigation  
**Version:** 1.0.0  
**Compilation:** ✅ No errors or warnings  
**Next:** User to verify HealthKit data and provide feedback