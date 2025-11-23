# Body Mass Data Source Investigation Checklist

**Date:** 2025-01-27  
**Issue:** Weight data only shows in "All" filter, appears to be 5+ years old  
**Status:** 🔍 Investigation Required

---

## 🎯 Problem Summary

- **Symptom 1:** Weight data only visible when "All" (5-year) filter selected
- **Symptom 2:** Other filters (7d, 30d, 90d, 1y) show empty charts
- **Symptom 3:** Historical entries display dates from ~5 years ago
- **Symptom 4:** Data appears "mocked" or corrupted

**Current Status:** Current weight display bug fixed, but root data source issue remains

---

## 📋 Investigation Checklist

### Step 1: Check HealthKit Data (USER ACTION)

**Open Apple Health App:**

- [ ] Open Health app on iPhone
- [ ] Navigate to: Browse → Body Measurements → Weight
- [ ] Record findings:
  - Latest entry date: `_________________`
  - Number of entries in last 7 days: `_____`
  - Number of entries in last 30 days: `_____`
  - Number of entries in last 90 days: `_____`
  - Total number of entries: `_____`

**Questions to Answer:**
- [ ] Are there recent weight entries (last 7-30 days)?
- [ ] When was the last weight entry logged?
- [ ] Is there a large gap in data (e.g., no entries for years)?
- [ ] Are the old entries (5 years ago) from a previous device/app?

**Test Action:**
- [ ] Log a new weight entry in Apple Health NOW
- [ ] Note the exact weight and time
- [ ] Wait 5 seconds, then check FitIQ app
- [ ] Does new entry appear in FitIQ? YES / NO
- [ ] If yes, in which filter does it appear? `_________________`

---

### Step 2: Enable Verbose Logging (DEVELOPER ACTION)

**Run App with Xcode Console Open:**

- [ ] Connect device to Xcode
- [ ] Run app with console visible
- [ ] Navigate to Body Mass Detail View
- [ ] Watch for these log messages:

```
GetHistoricalWeightUseCase: Fetching weight for user <UUID> from <START> to <END>
GetHistoricalWeightUseCase: Found X entries from backend
GetHistoricalWeightUseCase: Found Y samples from HealthKit
GetHistoricalWeightUseCase: Backend latest: <DATE>, HealthKit latest: <DATE>
GetHistoricalWeightUseCase: Using <SOURCE> (reason)
BodyMassDetailViewModel: Loaded X weight records
```

**Record Findings for Each Filter:**

**7d Filter:**
- Start date: `_________________`
- End date: `_________________`
- Backend entries: `_____`
- HealthKit samples: `_____`
- Which source used: `_________________`

**30d Filter:**
- Start date: `_________________`
- End date: `_________________`
- Backend entries: `_____`
- HealthKit samples: `_____`
- Which source used: `_________________`

**All Filter:**
- Start date: `_________________`
- End date: `_________________`
- Backend entries: `_____`
- HealthKit samples: `_____`
- Which source used: `_________________`

---

### Step 3: Check Backend API Directly (DEVELOPER ACTION)

**Make Direct API Call:**

Use Postman, curl, or Swagger UI at https://fit-iq-backend.fly.dev/swagger/index.html

```bash
# Get recent weight history
GET /api/v1/progress/history
  ?type=weight
  &start_date=2025-01-01T00:00:00Z
  &end_date=2025-01-27T23:59:59Z

Headers:
  X-API-Key: <YOUR_API_KEY>
  Authorization: Bearer <JWT_TOKEN>
```

**Record Response:**
- [ ] Status code: `_____`
- [ ] Number of entries returned: `_____`
- [ ] Date range of entries:
  - Oldest: `_________________`
  - Newest: `_________________`
- [ ] Sample entry (first one):
  ```json
  {
    "id": "___________",
    "type": "weight",
    "quantity": _____,
    "date": "_________________"
  }
  ```

**Questions to Answer:**
- [ ] Does backend have recent data? YES / NO
- [ ] Does backend only have old data (5 years)? YES / NO
- [ ] Does backend data match HealthKit? YES / NO / UNKNOWN

---

### Step 4: Inspect SwiftData Local Storage (DEVELOPER ACTION)

**Add Temporary Debug Method:**

Add this to `BodyMassDetailViewModel.swift`:

```swift
@MainActor
func debugLocalStorage() async {
    guard let userID = authManager.currentUserProfileID?.uuidString else {
        print("DEBUG: No user ID")
        return
    }
    
    do {
        // Fetch ALL local weight entries
        let allEntries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: .weight,
            syncStatus: nil
        )
        
        print("DEBUG: === LOCAL STORAGE INSPECTION ===")
        print("DEBUG: Total weight entries: \(allEntries.count)")
        
        // Group by sync status
        let pending = allEntries.filter { $0.syncStatus == .pending }
        let syncing = allEntries.filter { $0.syncStatus == .syncing }
        let synced = allEntries.filter { $0.syncStatus == .synced }
        let failed = allEntries.filter { $0.syncStatus == .failed }
        
        print("DEBUG: Pending: \(pending.count), Syncing: \(syncing.count), Synced: \(synced.count), Failed: \(failed.count)")
        
        // Show date range
        if let oldest = allEntries.map({ $0.date }).min(),
           let newest = allEntries.map({ $0.date }).max() {
            print("DEBUG: Date range: \(oldest) to \(newest)")
        }
        
        // Show last 10 entries
        print("DEBUG: Last 10 entries:")
        for (index, entry) in allEntries.prefix(10).enumerated() {
            print("  \(index + 1). Date=\(entry.date), Weight=\(entry.quantity)kg, Status=\(entry.syncStatus.rawValue)")
        }
    } catch {
        print("DEBUG: Error fetching local storage: \(error)")
    }
}
```

**Call from View:**

Add button in `BodyMassDetailView`:

```swift
Button("Debug Local Storage") {
    Task {
        await viewModel.debugLocalStorage()
    }
}
```

**Record Findings:**
- [ ] Total local weight entries: `_____`
- [ ] Pending sync: `_____`
- [ ] Synced: `_____`
- [ ] Failed: `_____`
- [ ] Date range: `_________________ to _________________`

---

### Step 5: Test Date Range Calculations (DEVELOPER ACTION)

**Verify Date Math:**

Add this to `BodyMassDetailViewModel`:

```swift
@MainActor
func debugDateRanges() {
    let now = Date()
    
    for range in TimeRange.allCases {
        let start = calculateStartDate(for: range, from: now)
        print("DEBUG: Range \(range.rawValue): \(start) to \(now)")
        print("  Days difference: \(Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0)")
    }
}
```

**Call on View Appear:**

```swift
.onAppear {
    viewModel.debugDateRanges()
    Task { await viewModel.loadHistoricalData() }
}
```

**Record Output:**
- [ ] 7d range: `_________________ to _________________`
- [ ] 30d range: `_________________ to _________________`
- [ ] 90d range: `_________________ to _________________`
- [ ] 1y range: `_________________ to _________________`
- [ ] All range: `_________________ to _________________`

**Validate:**
- [ ] Are start dates in the PAST? YES / NO
- [ ] Are date ranges correct? YES / NO
- [ ] Do dates look reasonable? YES / NO

---

## 🔍 Analysis Scenarios

Based on findings, identify which scenario matches:

### Scenario A: No Recent HealthKit Data ✓

**Indicators:**
- HealthKit has only old entries (5 years)
- Backend also has only old entries
- No recent weight logs in Apple Health

**Cause:** User hasn't logged weight recently

**Solution:** 
- User needs to log new weight in Apple Health
- App will automatically detect and sync
- No code changes needed

---

### Scenario B: HealthKit Has Recent Data, Not Syncing ⚠️

**Indicators:**
- HealthKit has entries from last week
- Backend has only old entries
- Local SwiftData shows pending/failed syncs

**Cause:** Sync mechanism broken or rate-limited

**Solution:**
- Check `RemoteSyncService` logs
- Check for rate limiting errors
- Verify background sync is running
- May need to trigger manual sync
- Check network connectivity

---

### Scenario C: Date Range Query Bug 🐛

**Indicators:**
- HealthKit has recent data
- Recent data only shows in "All" filter
- Date math looks wrong

**Cause:** Date range calculation or query bug

**Solution:**
- Fix `calculateStartDate()` method
- Verify timezone handling (UTC vs local)
- Check predicate date comparison
- May need to normalize dates to start-of-day

---

### Scenario D: Predicate Filtering Bug (Again) 🐛

**Indicators:**
- SwiftData returns wrong type of data
- Entries include steps instead of weight
- Counts don't match expectations

**Cause:** SwiftData predicate not filtering correctly

**Solution:**
- Review `SwiftDataProgressRepository.fetchLocal()`
- Verify type filtering: `$0.type == typeRawValue`
- Check for predicate syntax errors
- Confirm `ProgressMetricType.weight` constant

---

### Scenario E: Backend Data Corruption 💥

**Indicators:**
- Backend returns old/wrong data
- API response doesn't match expected format
- Dates are obviously wrong (e.g., year 2020)

**Cause:** Backend database issue or migration problem

**Solution:**
- Contact backend team
- Check backend logs
- Verify data migration scripts
- May need to re-sync all data

---

## 📊 Decision Matrix

| Symptom | HealthKit Recent? | Backend Recent? | Local Synced? | Likely Cause |
|---------|-------------------|-----------------|---------------|--------------|
| Data in "All" only | ❌ No | ❌ No | N/A | **Scenario A** - No recent data |
| Data in "All" only | ✅ Yes | ❌ No | ❌ No | **Scenario B** - Sync broken |
| Data in "All" only | ✅ Yes | ✅ Yes | ✅ Yes | **Scenario C** - Query bug |
| Wrong data returned | ✅ Yes | ✅ Yes | ✅ Yes | **Scenario D** - Predicate bug |
| Corrupted dates | ❌ No | ⚠️ Old | ⚠️ Old | **Scenario E** - Backend issue |

---

## 🛠️ Quick Fixes to Try

### Fix 1: Force Re-sync from HealthKit

**Purpose:** Get latest HealthKit data into app

**Steps:**
1. Kill app completely
2. Open Apple Health, verify recent entries exist
3. Re-open FitIQ app
4. Navigate to Profile → Sync Health Data (if button exists)
5. Or navigate to Body Mass view (triggers auto-load)

### Fix 2: Clear Local Cache & Re-fetch

**Purpose:** Start fresh with clean slate

**Add Debug Action:**
```swift
Button("Reset Weight Data") {
    Task {
        // Clear local storage
        // Re-fetch from HealthKit
        // Re-sync to backend
    }
}
.foregroundColor(.red)
```

### Fix 3: Check HealthKit Permissions

**Purpose:** Ensure app can read weight data

**Steps:**
1. Settings → Privacy & Security → Health
2. Find FitIQ app
3. Verify "Weight" is enabled for READ
4. If not enabled, enable it
5. Re-launch app

---

## 📝 Results Template

**Investigation Date:** `_________________`  
**Investigated By:** `_________________`  
**Device:** `_________________`  
**iOS Version:** `_________________`

**Findings:**

1. HealthKit Status:
   ```
   - Latest entry: _________________
   - Entry count (7d): _____
   - Entry count (30d): _____
   ```

2. Backend Status:
   ```
   - API responds: YES / NO
   - Entry count: _____
   - Date range: _________________
   ```

3. Local Storage:
   ```
   - Total entries: _____
   - Sync status breakdown: _________________
   ```

**Conclusion:**

Matches **Scenario ___**: `_________________`

**Recommended Action:**

```
[Describe what needs to be done based on scenario]
```

**Fix Applied:**

- [ ] User action (log new weight)
- [ ] Code fix required
- [ ] Backend issue (escalated)
- [ ] No action needed (working as expected)

---

**Status:** 🔍 Investigation In Progress  
**Priority:** High  
**Assignee:** User + Developer  
**Next Review:** After completing checklist