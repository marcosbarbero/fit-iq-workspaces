# HealthKit Data Sync Assessment

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Active

---

## 📋 Executive Summary

The FitIQ iOS app implements a **sophisticated multi-layered HealthKit synchronization system** that combines:

1. **Real-time sync** via HealthKit observer queries (immediate when data changes)
2. **Background processing** via BGTaskScheduler (when app is not active)
3. **Daily consolidated sync** at midnight (finalize previous day's data)
4. **Debounced foreground sync** (when app is active, 1-second debounce)

---

## 🎯 Sync Frequency & Timing

### 1. Real-Time Sync (Immediate)

**Trigger:** HealthKit data changes detected by `HKObserverQuery`  
**Frequency:** Immediate (within seconds of HealthKit data change)  
**When:** Any time HealthKit data changes (e.g., Apple Watch sync, manual entry)  
**Debounce:** 1 second (prevents multiple rapid syncs)

**Observed Metrics:**
- Body Mass (weight)
- Height
- Step Count
- Distance Walking/Running
- Basal Energy Burned
- Active Energy Burned
- Heart Rate
- Sleep Analysis

**Flow:**
```
HealthKit Data Changes
    ↓
HKObserverQuery fires in HealthKitAdapter
    ↓
onDataUpdate closure called
    ↓
BackgroundSyncManager.setOnDataUpdateHandler()
    ↓
1-second debounce applied
    ↓
If app is ACTIVE → Immediate foreground sync
If app is BACKGROUND → Schedule BGTask for later
```

### 2. Background Sync (Event-Driven)

**Task ID:** `com.marcosbarbero.FitIQ.healthkitsync`  
**Trigger:** HealthKit data changes (when app is not active)  
**Timing:** As soon as iOS permits (typically within minutes to hours)  
**Requirements:** Network connectivity required, external power NOT required

**Flow:**
```
HealthKit changes detected while app is backgrounded
    ↓
Change tracked in UserDefaults (pendingHealthKitSyncTypes)
    ↓
BGTask scheduled (HealthKitSyncTaskID)
    ↓
iOS runs task when conditions are met
    ↓
BackgroundSyncManager.registerHealthKitSyncTask() executes
    ↓
HealthDataSyncOrchestrator.syncAllDailyActivityData()
    ↓
All pending metrics synced
    ↓
UserDefaults cleared
```

### 3. Daily Consolidated Sync (Scheduled)

**Task ID:** `com.marcosbarbero.FitIQ.consolidatedDailyProcessing`  
**Trigger:** Scheduled daily  
**Time:** **12:01 AM (midnight + 1 minute)** every day  
**Purpose:** Finalize and consolidate previous day's health data  
**Requirements:** Network connectivity required, external power NOT required

**Scheduled by:** `ScheduleDailyEnergyProcessingUseCase`

**Flow:**
```
Midnight + 1 minute
    ↓
BGTask fires (ConsolidatedDailyHealthKitProcessingTaskID)
    ↓
ProcessConsolidatedDailyHealthDataUseCase.execute()
    ↓
HealthDataSyncOrchestrator processes previous day's data
    ↓
ActivitySnapshot updated with finalized data
```

**Scheduling Logic:**
```swift
// Scheduled for next midnight + 1 minute
components.day = (components.day ?? 0) + 1
components.hour = 0
components.minute = 1
components.second = 0
```

---

## 🏗️ Key Classes & Responsibilities

### 1. `BackgroundSyncManager`
**Location:** `Domain/UseCases/BackgroundSyncManager.swift`

**Responsibilities:**
- Register all background tasks with BGTaskScheduler
- Set up HealthKit observer query handlers
- Manage debouncing for foreground/background syncs
- Track pending sync types in UserDefaults
- Start HealthKit observations for all metrics

**Key Methods:**
- `registerBackgroundTasks()` - Register all BGTasks at app launch
- `registerHealthKitSyncTask()` - Handle event-driven background sync
- `registerConsolidatedDailyHealthKitProcessingTask()` - Handle daily midnight sync
- `setOnDataUpdateHandler()` - Handle HealthKit change notifications
- `startHealthKitObservations()` - Start observing all HealthKit metrics

**Debounce Configuration:**
```swift
private let debounceInterval: TimeInterval = 1.0  // 1 second
```

### 2. `HealthDataSyncOrchestrator`
**Location:** `Infrastructure/Services/HealthDataSyncOrchestrator.swift`

**Responsibilities:**
- Coordinate sync across all metric handlers
- Execute daily sync for all metrics
- Execute historical sync for initial data load
- Update ActivitySnapshot after sync
- Provide clean interface for sync operations

**Key Methods:**
- `configure(withUserProfileID:)` - Set current user context
- `syncAllDailyActivityData()` - Sync today's data for all metrics
- `syncHistoricalHealthData()` - Initial historical data load

**Design Pattern:** Facade/Coordinator Pattern
- Delegates actual sync work to specialized handlers
- Runs syncs in parallel for performance
- Single responsibility: orchestrate, don't implement

### 3. `HealthKitAdapter`
**Location:** `Infrastructure/Integration/HealthKitAdapter.swift`

**Responsibilities:**
- Interface with HealthKit APIs
- Manage HKObserverQuery instances
- Enable background delivery for HealthKit types
- Trigger sync callbacks when data changes
- Fetch HealthKit data (quantity samples, category samples)

**Key Methods:**
- `startObserving(for:)` - Start HKObserverQuery for a type
- `stopObserving(for:)` - Stop observing a type
- `enableBackgroundDelivery()` - Enable HealthKit background updates

**Observer Query Implementation:**
```swift
let observerQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
    [weak self] query, completionHandler, error in
    
    // Fire onDataUpdate callback
    self?.onDataUpdate?(hkQuantityIdentifier)
    completionHandler()
}

store.execute(observerQuery)
```

**Background Delivery:**
- Frequency: `.immediate` (as soon as data changes)
- Enabled for all observed types
- Requires `UIBackgroundModes` = `["processing", "fetch", "remote-notification"]`

### 4. `BackgroundOperations`
**Location:** `Infrastructure/Background/BackgroundOperations.swift`

**Responsibilities:**
- Wrap BGTaskScheduler APIs
- Track registered task identifiers (prevent duplicate registration)
- Schedule background tasks with specific requirements
- Thread-safe task registration

**Key Methods:**
- `registerTask(forTaskWithIdentifier:handler:)` - Register BGTask handler (once per app launch)
- `scheduleTask(forTaskWithIdentifier:earliestBeginDate:requiresNetworkConnectivity:requiresExternalPower:)` - Schedule task execution

**Registered Tasks:**
```swift
public let HealthKitSyncTaskID = "com.marcosbarbero.FitIQ.healthkitsync"
public let ConsolidatedDailyHealthKitProcessingTaskID = "com.marcosbarbero.FitIQ.consolidatedDailyProcessing"
```

### 5. Metric-Specific Sync Handlers

**Examples:**
- `StepsSyncHandler` - Steps data
- `HeartRateSyncHandler` - Heart rate data
- `SleepSyncHandler` - Sleep analysis data
- `EnergySyncHandler` - Active/basal energy
- `BodyMassSyncHandler` - Weight data
- `HeightSyncHandler` - Height data

**Pattern:**
- Each handler implements `HealthMetricSyncHandler` protocol
- Handles single metric type
- Encapsulates metric-specific logic
- Called by `HealthDataSyncOrchestrator`

---

## 🔄 Sync Flow Diagrams

### Real-Time Sync (When App is Active)

```
User adds data to HealthKit (e.g., Apple Watch syncs steps)
    ↓
HKObserverQuery fires in HealthKitAdapter
    ↓
HealthKitAdapter.onDataUpdate?(.stepCount) called
    ↓
BackgroundSyncManager receives notification
    ↓
Check app state: UIApplication.shared.applicationState
    ↓
If .active:
    ↓
    Debounce 1 second (cancel previous debounce if any)
    ↓
    foregroundSyncDebounceTask executes
    ↓
    HealthDataSyncOrchestrator.syncAllDailyActivityData()
    ↓
    All handlers sync in parallel
    ↓
    ActivitySnapshot updated
    ↓
    LocalDataChangeMonitor detects changes
    ↓
    RemoteSyncService syncs to backend
```

### Background Sync (When App is Not Active)

```
User adds data to HealthKit while app is backgrounded
    ↓
HKObserverQuery fires (background delivery enabled)
    ↓
HealthKitAdapter.onDataUpdate?(.stepCount) called
    ↓
BackgroundSyncManager receives notification
    ↓
Add .stepCount to pendingHealthKitSyncTypes in UserDefaults
    ↓
Debounce 1 second
    ↓
backgroundTaskScheduleDebounceTask executes
    ↓
BackgroundOperations.scheduleTask(HealthKitSyncTaskID)
    ↓
BGTaskScheduler submits task
    ↓
iOS runs task when conditions met (network available)
    ↓
BackgroundSyncManager.registerHealthKitSyncTask() handler executes
    ↓
Read pendingHealthKitSyncTypes from UserDefaults
    ↓
HealthDataSyncOrchestrator.syncAllDailyActivityData()
    ↓
All handlers sync in parallel
    ↓
Clear pendingHealthKitSyncTypes
    ↓
ActivitySnapshot updated
    ↓
Task completes
```

### Daily Midnight Sync

```
App launch or previous daily task completes
    ↓
ScheduleDailyEnergyProcessingUseCase.execute() called
    ↓
Calculate next midnight + 1 minute
    ↓
BackgroundOperations.scheduleTask(ConsolidatedDailyHealthKitProcessingTaskID)
    ↓
earliestBeginDate = tomorrow 00:01:00
    ↓
BGTaskScheduler submits task
    ↓
... wait until midnight ...
    ↓
12:01 AM - BGTask fires
    ↓
BackgroundSyncManager.registerConsolidatedDailyHealthKitProcessingTask() executes
    ↓
ProcessConsolidatedDailyHealthDataUseCase.execute()
    ↓
HealthDataSyncOrchestrator processes previous day
    ↓
Finalize previous day's ActivitySnapshot
    ↓
Task completes
    ↓
Reschedule for next midnight
```

---

## 📊 Observed HealthKit Metrics

### Quantity Types

| Metric | HKQuantityTypeIdentifier | Update Frequency | Sync Handler |
|--------|-------------------------|------------------|--------------|
| **Weight** | `.bodyMass` | On change | `BodyMassSyncHandler` |
| **Height** | `.height` | On change | `HeightSyncHandler` |
| **Steps** | `.stepCount` | Continuous | `StepsSyncHandler` |
| **Walking Distance** | `.distanceWalkingRunning` | Continuous | Various |
| **Basal Energy** | `.basalEnergyBurned` | Continuous | `EnergySyncHandler` |
| **Active Energy** | `.activeEnergyBurned` | Continuous | `EnergySyncHandler` |
| **Heart Rate** | `.heartRate` | Continuous | `HeartRateSyncHandler` |

### Category Types

| Metric | HKCategoryTypeIdentifier | Update Frequency | Sync Handler |
|--------|-------------------------|------------------|--------------|
| **Sleep** | `.sleepAnalysis` | Daily | `SleepSyncHandler` |

**Note:** Sleep uses `.stepCount` as a proxy to trigger daily sync, which includes sleep processing.

---

## ⚙️ Configuration

### Info.plist Settings

**BGTaskScheduler Permitted Identifiers:**
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.marcosbarbero.FitIQ.healthkitsync</string>
    <string>com.marcosbarbero.FitIQ.consolidatedDailyProcessing</string>
    <string>com.marcosbarbero.FitIQ.remote.sync</string>
    <string>com.marcosbarbero.FitIQ.dailyEnergyProcessing</string>
    <string>com.marcosbarbero.FitIQ.notificationcheck</string>
</array>
```

**Background Modes:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### Task Requirements

#### HealthKitSyncTaskID
- **Network:** ✅ Required
- **External Power:** ❌ Not required
- **Earliest Begin Date:** Immediate (`Date()`)
- **Trigger:** HealthKit data changes

#### ConsolidatedDailyHealthKitProcessingTaskID
- **Network:** ✅ Required
- **External Power:** ❌ Not required
- **Earliest Begin Date:** Next midnight + 1 minute
- **Trigger:** Scheduled daily

---

## 🔍 Debugging & Monitoring

### Logging Points

**HealthKitAdapter:**
```
"HealthKitAdapter: OBSERVER QUERY FIRED for type: {type}"
"HealthKitAdapter: Called onDataUpdate for type: {type}"
"HealthKitAdapter: onDataUpdate closure is NIL" (indicates handler not set)
```

**BackgroundSyncManager:**
```
"BackgroundSyncManager: Added {type} to pending HealthKit sync types"
"BackgroundSyncManager: Debounce finished. Attempting to schedule HealthKitSyncTask"
"BackgroundSyncManager: Successfully scheduled (debounced) HealthKitSyncTask"
"BackgroundSyncManager: App is active. Scheduling debounced foreground sync"
```

**BGTask Execution:**
```
"BGTask: {taskID} received for processing"
"BGTask: HealthKit sync task starting execution"
"BGTask: {taskID} completed with success: {bool}"
"BGTask: {taskID} expiration handler called" (task took too long)
```

**HealthDataSyncOrchestrator:**
```
"HealthDataSyncOrchestrator: 🔄 Starting daily sync for all metrics..."
"HealthDataSyncOrchestrator: ✅ {metric} sync completed"
"HealthDataSyncOrchestrator: ⚠️ {metric} sync failed: {error}"
"HealthDataSyncOrchestrator: 📊 Daily sync summary: X succeeded, Y failed"
```

### UserDefaults Keys

**Pending Sync Types:**
```swift
private static let pendingHealthKitSyncTypesKey = "pendingHealthKitSyncTypes"
```

Stores array of `String` (e.g., `["HKQuantityTypeIdentifierStepCount", "HKQuantityTypeIdentifierHeartRate"]`)

### Testing Background Tasks

**Using Xcode:**
```bash
# Simulate HealthKitSyncTask
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.marcosbarbero.FitIQ.healthkitsync"]

# Simulate ConsolidatedDailyProcessingTask
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.marcosbarbero.FitIQ.consolidatedDailyProcessing"]
```

**Check Pending Tasks:**
```swift
let pendingTasks = await BGTaskScheduler.shared.pendingTaskRequests()
print("Pending tasks: \(pendingTasks.map { $0.identifier })")
```

---

## 🎯 Performance Characteristics

### Daily Sync (syncAllDailyActivityData)
- **Duration:** 1-3 seconds (today's data only)
- **Parallel Execution:** All handlers run concurrently
- **Network:** Not required for local storage, required for remote sync
- **Data Volume:** Today's data (~10-50 samples per metric)

### Historical Sync (syncHistoricalHealthData)
- **Duration:** 5-30 seconds (depending on date range)
- **Parallel Execution:** All handlers run concurrently
- **Network:** Not required for local storage, required for remote sync
- **Data Volume:** Large (30-90 days of historical data)

### Background Task Constraints
- **Max Duration:** ~30 seconds (iOS enforced)
- **Expiration Handler:** Sets task as incomplete if time runs out
- **Network Required:** Tasks won't run without network
- **Battery:** Tasks run even when not plugged in (requiresExternalPower = false)

---

## 🚨 Known Issues & Edge Cases

### 1. Observer Query Lifecycle
**Issue:** Observer queries must be recreated if app is killed  
**Mitigation:** `startHealthKitObservations()` called at app launch

### 2. Background Task Reliability
**Issue:** iOS may delay or skip background tasks  
**Mitigation:** Foreground sync when app is active + pending types tracking

### 3. Duplicate Registration
**Issue:** BGTaskScheduler crashes if handler registered multiple times  
**Mitigation:** `BackgroundOperations` tracks registered identifiers with thread-safe set

### 4. Nil onDataUpdate Closure
**Issue:** If `BackgroundSyncManager.setOnDataUpdateHandler()` not called, observer queries fire but nothing happens  
**Mitigation:** Logging to detect this scenario + registration at app launch

### 5. Sleep Analysis Category Type
**Issue:** Sleep is a category type, not a quantity type  
**Mitigation:** Use `.stepCount` as proxy to trigger daily sync (which includes sleep)

---

## 📚 Related Documentation

- **Architecture:** `.github/copilot-instructions.md` (Hexagonal Architecture)
- **API Integration:** `docs/IOS_INTEGRATION_HANDOFF.md`
- **Outbox Pattern:** `.github/copilot-instructions.md` (Progress tracking sync)
- **Summary Pattern:** `docs/architecture/SUMMARY_DATA_LOADING_PATTERN.md`

---

## 🔮 Future Improvements

### Potential Enhancements

1. **Progressive Historical Sync**
   - Sync historical data in chunks (e.g., 7 days at a time)
   - Reduce initial sync duration
   - Better user experience during onboarding

2. **Metric-Specific Sync Intervals**
   - Different debounce intervals per metric
   - E.g., weight (5 min), steps (30 sec), heart rate (1 min)

3. **Smart Sync Scheduling**
   - Skip sync if data hasn't changed significantly
   - Use HealthKit anchors for efficient incremental sync
   - Reduce battery usage

4. **Conflict Resolution**
   - Handle cases where local and HealthKit data diverge
   - Last-write-wins vs. merge strategies

5. **Sync Analytics**
   - Track sync success/failure rates
   - Monitor sync duration per metric
   - Alert on degraded sync performance

---

## ✅ Summary

The FitIQ HealthKit sync system is **robust, multi-layered, and performant**:

- ✅ **Real-time:** Observer queries detect changes immediately
- ✅ **Reliable:** Background tasks ensure sync even when app is not active
- ✅ **Daily:** Midnight task finalizes previous day's data
- ✅ **Debounced:** Prevents excessive syncs (1-second window)
- ✅ **Parallel:** All metrics sync concurrently for speed
- ✅ **Monitored:** Extensive logging for debugging
- ✅ **Resilient:** Handles app kills, network failures, task expirations

**Key Timing:**
- **Immediate:** When HealthKit data changes (if app is active)
- **Event-driven:** When HealthKit data changes (if app is backgrounded)
- **Daily:** 12:01 AM every night (consolidated processing)

**Key Classes:**
- `BackgroundSyncManager` - Coordinator
- `HealthDataSyncOrchestrator` - Sync orchestrator
- `HealthKitAdapter` - HealthKit interface
- `BackgroundOperations` - BGTaskScheduler wrapper
- Metric-specific sync handlers

---

**Version:** 1.0.0  
**Status:** ✅ Complete  
**Last Updated:** 2025-01-27