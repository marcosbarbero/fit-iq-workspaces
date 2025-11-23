# HealthKit Data Sync Entry Points

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Complete reference for all HealthKit sync triggers to help with debugging data flow issues

---

## 🎯 Overview

This document maps all entry points where HealthKit data sync is triggered in the FitIQ iOS app. Understanding these entry points is crucial for debugging sync issues, missing data, and timing problems.

---

## 📊 Sync Architecture Summary

```
HealthKit Data Sources
    ↓
HealthKitAdapter (observers & queries)
    ↓
HealthDataSyncManager (sync orchestration)
    ↓
SwiftData Local Storage (via repositories)
    ↓
UI (SummaryView, etc.)
```

**Key Component:** `HealthDataSyncManager`
- Location: `Infrastructure/Services/HealthDataSyncManager.swift`
- Role: Orchestrates all HealthKit data synchronization
- Methods:
  - `syncAllDailyActivityData()` - Syncs today's data
  - `syncHistoricalHealthData(from:to:)` - Syncs date range
  - `finalizeDailyActivityData(for:)` - Consolidates previous day
  - `configure(withUserProfileID:)` - Sets user context

---

## 🚀 Entry Point #1: Initial Sync After Login

**Trigger:** User completes login/registration and grants HealthKit permissions  
**Location:** `Presentation/UI/Shared/RootTabView.swift`

```swift
// RootTabView.swift - Line ~118
try await deps.performInitialHealthKitSyncUseCase.execute(forUserID: userID)
```

### Flow:
1. **RootTabView** detects user is authenticated
2. Calls `PerformInitialHealthKitSyncUseCase.execute(forUserID:)`
3. Use case checks if initial sync already done via `userProfile.hasPerformedInitialHealthKitSync`
4. If first time:
   - Requests HealthKit authorization
   - Syncs **90 days** of historical data (configurable in `PerformInitialHealthKitSyncUseCase`)
   - Syncs historical weight (batched to avoid rate limits)
   - Syncs today's data
   - Sets `hasPerformedInitialHealthKitSync = true`
5. If already done:
   - Skips authorization
   - Only syncs today's data (refresh)

### Files Involved:
- `Presentation/UI/Shared/RootTabView.swift` (trigger)
- `Infrastructure/Integration/PerformInitialHealthKitSyncUseCase.swift` (orchestration)
- `Infrastructure/Services/HealthDataSyncManager.swift` (execution)

### Debug Points:
- Check `hasPerformedInitialHealthKitSync` flag in user profile
- Verify 90-day historical sync completes (~30-45 seconds)
- Check for HealthKit permission errors
- Monitor console logs: "PerformInitialHealthKitSyncUseCase: Historical sync completed"

---

## 🔄 Entry Point #2: Manual Pull-to-Refresh

**Trigger:** User pulls down on SummaryView  
**Location:** `Presentation/ViewModels/SummaryViewModel.swift`

```swift
// SummaryViewModel.swift - Line ~129
func refreshData() async {
    try await processDailyHealthDataUseCase.execute()
    await reloadAllData()
}
```

### Flow:
1. User swipes down on SummaryView
2. `SummaryViewModel.refreshData()` called
3. `ProcessDailyHealthDataUseCase.execute()` triggers sync
4. Calls `HealthDataSyncManager.syncAllDailyActivityData()`
5. Syncs latest data for today:
   - Steps
   - Heart rate
   - Active energy
   - Exercise minutes
   - Sleep (if available)
6. Reloads all UI cards with fresh data

### Files Involved:
- `Presentation/Views/SummaryView.swift` (UI trigger)
- `Presentation/ViewModels/SummaryViewModel.swift` (action)
- `Domain/UseCases/ProcessDailyHealthDataUseCase.swift` (use case)
- `Infrastructure/Services/HealthDataSyncManager.swift` (sync)

### Debug Points:
- Check console: "🔄 SummaryViewModel.refreshData() - Syncing from HealthKit..."
- Verify sync completes: "✅ HealthKit sync completed successfully"
- Check if data appears in UI after refresh
- Monitor `isRefreshing` state in ViewModel

---

## 📱 Entry Point #3: Background HealthKit Observations

**Trigger:** HealthKit detects new data (automatic)  
**Location:** `Domain/UseCases/BackgroundSyncManager.swift`

```swift
// BackgroundSyncManager.swift - Line ~277
func setOnDataUpdateHandler() {
    healthRepository.onDataUpdate = { [weak self] typeIdentifier in
        // Debounced foreground sync
        await self.healthDataSyncService.syncAllDailyActivityData()
    }
}
```

### Flow:
1. HealthKit observer query fires when new data arrives
2. `HealthKitAdapter.onDataUpdate` closure triggered
3. Calls `BackgroundSyncManager.setOnDataUpdateHandler()`
4. Debounced (1 second) to avoid excessive syncs
5. If app is in **foreground**:
   - Immediate sync via `syncAllDailyActivityData()`
6. If app is in **background**:
   - Queues type for later sync
   - Schedules background task

### Files Involved:
- `Infrastructure/Repositories/HealthKitAdapter.swift` (observer)
- `Domain/UseCases/BackgroundSyncManager.swift` (handler)
- `Infrastructure/Services/HealthDataSyncManager.swift` (sync)

### Debug Points:
- Check observer setup: "HealthKitAdapter: Starting observer query for..."
- Monitor update triggers: "BackgroundSyncManager: Added [type] to pending HealthKit sync types"
- Verify debounce: Look for 1-second gaps between syncs
- Check app state: Foreground vs. background handling

---

## ⏰ Entry Point #4: Background Task Execution

**Trigger:** iOS system wakes app for background refresh  
**Location:** `Domain/UseCases/BackgroundSyncManager.swift`

```swift
// BackgroundSyncManager.swift - Line ~103
func registerHealthKitSyncTask() {
    // Task ID: "com.fitiq.healthkit.sync"
    await healthDataSyncService.syncAllDailyActivityData()
}
```

### Flow:
1. iOS schedules background task (every ~15-30 minutes)
2. `BGProcessingTask` handler executes
3. Fetches pending sync types from `UserDefaults`
4. Calls `syncAllDailyActivityData()` for comprehensive sync
5. Clears pending types after successful sync
6. Schedules next background task

### Files Involved:
- `Domain/UseCases/BackgroundSyncManager.swift` (registration & execution)
- `Infrastructure/Services/HealthDataSyncManager.swift` (sync)
- `Info.plist` (BGTaskSchedulerPermittedIdentifiers)

### Debug Points:
- Check task registration: "BackgroundSyncManager: Registering all background tasks"
- Monitor execution: "BGTask: com.fitiq.healthkit.sync received for processing"
- Verify completion: "BGTask: HealthKit sync task completed comprehensive daily sync"
- Test with: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.fitiq.healthkit.sync"]`

---

## 🌙 Entry Point #5: Daily Consolidation Task

**Trigger:** iOS system wakes app at midnight (approximately)  
**Location:** `Domain/UseCases/BackgroundSyncManager.swift`

```swift
// BackgroundSyncManager.swift - Consolidated task
func registerConsolidatedDailyHealthKitProcessingTask() {
    // Task ID: "com.fitiq.healthkit.consolidatedDaily"
    try await processConsolidatedDailyHealthDataUseCase.execute()
}
```

### Flow:
1. iOS schedules task for midnight (or shortly after)
2. `ProcessConsolidatedDailyHealthDataUseCase.execute()` runs
3. Calculates "yesterday" (previous day)
4. Calls `HealthDataSyncManager.finalizeDailyActivityData(for: yesterday)`
5. Ensures complete data for the previous day
6. Useful for daily summaries and AI insights

### Files Involved:
- `Domain/UseCases/BackgroundSyncManager.swift` (registration)
- `Domain/UseCases/ProcessConsolidatedDailyHealthDataUseCase.swift` (orchestration)
- `Infrastructure/Services/HealthDataSyncManager.swift` (finalization)

### Debug Points:
- Check registration: "BackgroundSyncManager: Registered consolidatedDailyHealthKitProcessingTask"
- Monitor execution: "ProcessConsolidatedDailyHealthDataUseCase: Executing consolidated daily health data processing"
- Verify finalization: "Consolidated daily health data finalization for [date] complete"
- Test manually by triggering background task

---

## 🔧 Entry Point #6: Manual Weight Entry

**Trigger:** User logs weight in BodyMassEntryView  
**Location:** `Presentation/UI/Summary/SaveBodyMassUseCase.swift`

```swift
// SaveBodyMassUseCase.swift - Line ~67
func execute(weightKg: Double, date: Date) async throws {
    try await healthRepository.saveQuantitySample(...)
    healthRepository.onDataUpdate?(.bodyMass)  // Triggers observer
}
```

### Flow:
1. User enters weight in UI
2. `SaveBodyMassUseCase.execute()` saves to HealthKit
3. Manually triggers `onDataUpdate(.bodyMass)`
4. Triggers Background Observation flow (Entry Point #3)
5. Data syncs immediately to local storage
6. UI updates with new weight

### Files Involved:
- `Presentation/UI/Summary/BodyMassEntryView.swift` (UI)
- `Presentation/UI/Summary/SaveBodyMassUseCase.swift` (save)
- `Infrastructure/Repositories/HealthKitAdapter.swift` (HealthKit write)
- `Domain/UseCases/BackgroundSyncManager.swift` (observer trigger)

### Debug Points:
- Check HealthKit write: "HealthKitAdapter: Saving quantity sample..."
- Verify observer trigger: "BackgroundSyncManager: Added bodyMass to pending types"
- Confirm immediate sync in foreground
- Check UI update after save

---

## 🔄 Entry Point #7: Force Resync (Debug/Recovery)

**Trigger:** User initiates force resync from profile/settings  
**Location:** `Domain/UseCases/ForceHealthKitResyncUseCase.swift`

```swift
// ForceHealthKitResyncUseCase.swift - Line ~132
func execute(clearExisting: Bool) async throws {
    healthDataSyncManager.clearHistoricalSyncTracking()
    try await performInitialHealthKitSyncUseCase.execute(forUserID: userID)
}
```

### Flow:
1. User triggers resync (e.g., from profile screen)
2. Optionally clears existing data
3. Resets `hasPerformedInitialHealthKitSync` flag
4. Clears historical sync tracking
5. Re-runs initial sync flow (Entry Point #1)
6. Useful for recovery from sync issues

### Files Involved:
- `Domain/UseCases/ForceHealthKitResyncUseCase.swift` (orchestration)
- `Infrastructure/Integration/PerformInitialHealthKitSyncUseCase.swift` (sync)
- `Infrastructure/Services/HealthDataSyncManager.swift` (execution)

### Debug Points:
- Check flag reset: "Resetting hasPerformedInitialHealthKitSync flag"
- Monitor sync tracking clear: "Clearing historical sync tracking"
- Verify full resync: "Re-sync completed successfully!"
- Watch for errors during resync

---

## 🔍 Key Methods in HealthDataSyncManager

All entry points eventually call these core methods:

### 1. `syncAllDailyActivityData()`
- **Purpose:** Sync today's data only
- **Called by:** Manual refresh, background observers, background tasks
- **Syncs:** Steps, heart rate, active energy, exercise minutes, sleep
- **Performance:** Fast (~1-3 seconds)

### 2. `syncHistoricalHealthData(from:to:)`
- **Purpose:** Sync data for a date range
- **Called by:** Initial sync, force resync
- **Syncs:** Hourly aggregates for all metrics
- **Performance:** Depends on range (90 days = ~30-45 seconds)

### 3. `finalizeDailyActivityData(for:)`
- **Purpose:** Consolidate previous day's data
- **Called by:** Daily consolidation task
- **Syncs:** Ensures complete data for specific date
- **Performance:** Fast (~1-2 seconds)

### 4. `configure(withUserProfileID:)`
- **Purpose:** Set user context for syncs
- **Called by:** All entry points before syncing
- **Required:** Must be called before any sync operation

---

## 🐛 Debugging Checklist

When debugging sync issues, check these entry points in order:

### ✅ Initial Sync
- [ ] `hasPerformedInitialHealthKitSync` flag set correctly?
- [ ] HealthKit permissions granted?
- [ ] Historical sync completed (90 days)?
- [ ] User profile ID configured?

### ✅ Manual Refresh
- [ ] Pull-to-refresh triggering `refreshData()`?
- [ ] `processDailyHealthDataUseCase.execute()` called?
- [ ] Sync completing without errors?
- [ ] UI reloading after sync?

### ✅ Background Observations
- [ ] Observer queries set up for all types?
- [ ] `onDataUpdate` closure firing?
- [ ] Debounce working (1 second delay)?
- [ ] Foreground vs. background handling correct?

### ✅ Background Tasks
- [ ] Tasks registered in `Info.plist`?
- [ ] Background refresh enabled in settings?
- [ ] Tasks executing (check logs)?
- [ ] Pending types cleared after sync?

### ✅ Data Flow
- [ ] HealthKit → HealthDataSyncManager → Repositories → SwiftData
- [ ] No "Database busy" warnings?
- [ ] Data appearing in UI after sync?
- [ ] Correct user ID used throughout?

---

## 📝 Console Log Keywords for Debugging

Search logs for these patterns:

### Initial Sync
```
"PerformInitialHealthKitSyncUseCase: Starting authorization and sync process"
"Historical sync completed successfully (90 days)"
"Daily sync completed successfully"
```

### Manual Refresh
```
"🔄 SummaryViewModel.refreshData() - Syncing from HealthKit..."
"✅ HealthKit sync completed successfully"
"✅ SummaryViewModel.refreshData() - Complete"
```

### Background Observations
```
"HealthKitAdapter: Starting observer query for"
"BackgroundSyncManager: Added [type] to pending HealthKit sync types"
"BackgroundSyncManager: Performing comprehensive sync"
```

### Background Tasks
```
"BGTask: com.fitiq.healthkit.sync received for processing"
"BGTask: HealthKit sync task completed comprehensive daily sync"
"BackgroundSyncManager: Scheduled healthKitSyncTask for execution"
```

### Errors
```
"⚠️ HealthKit sync failed:"
"BGTask: expiration handler called"
"Database busy"
"HealthKit authorization denied"
```

---

## 🎯 Common Sync Issues & Entry Points to Check

| Issue | Entry Point to Check | What to Look For |
|-------|----------------------|------------------|
| **No data after login** | Entry Point #1 (Initial Sync) | Check if `hasPerformedInitialHealthKitSync` is set, verify 90-day sync completed |
| **Data not updating** | Entry Point #3 (Observations) | Check if observer queries are active, verify `onDataUpdate` fires |
| **Stale data** | Entry Point #2 (Manual Refresh) | Test pull-to-refresh, check if sync completes |
| **Missing yesterday's data** | Entry Point #5 (Daily Consolidation) | Check if consolidation task runs, verify finalization completes |
| **Background sync not working** | Entry Point #4 (Background Tasks) | Check task registration, verify background refresh enabled |
| **Weight not saving** | Entry Point #6 (Manual Entry) | Check HealthKit write, verify observer trigger |

---

## 🔗 Related Files

**Use Cases:**
- `Domain/UseCases/ProcessDailyHealthDataUseCase.swift`
- `Domain/UseCases/ProcessConsolidatedDailyHealthDataUseCase.swift`
- `Domain/UseCases/BackgroundSyncManager.swift`
- `Domain/UseCases/ForceHealthKitResyncUseCase.swift`
- `Infrastructure/Integration/PerformInitialHealthKitSyncUseCase.swift`

**Infrastructure:**
- `Infrastructure/Services/HealthDataSyncManager.swift` (core sync logic)
- `Infrastructure/Repositories/HealthKitAdapter.swift` (HealthKit interface)

**Presentation:**
- `Presentation/ViewModels/SummaryViewModel.swift` (manual refresh)
- `Presentation/UI/Shared/RootTabView.swift` (initial sync trigger)

**Configuration:**
- `Info.plist` (BGTaskSchedulerPermittedIdentifiers)
- `FitIQApp.swift` (background task registration)

---

**Status:** ✅ Complete  
**Maintained by:** iOS Team  
**Last Verified:** 2025-01-27

---

## Quick Reference: Entry Points Summary

1. **Initial Sync** → `RootTabView` → `PerformInitialHealthKitSyncUseCase`
2. **Manual Refresh** → `SummaryView` (pull-to-refresh) → `SummaryViewModel.refreshData()`
3. **Background Observations** → HealthKit observer → `BackgroundSyncManager.setOnDataUpdateHandler()`
4. **Background Tasks** → iOS scheduler → `BackgroundSyncManager.registerHealthKitSyncTask()`
5. **Daily Consolidation** → iOS scheduler → `ProcessConsolidatedDailyHealthDataUseCase`
6. **Manual Weight Entry** → `BodyMassEntryView` → `SaveBodyMassUseCase`
7. **Force Resync** → Profile/Settings → `ForceHealthKitResyncUseCase`

**All roads lead to:** `HealthDataSyncManager` 🎯