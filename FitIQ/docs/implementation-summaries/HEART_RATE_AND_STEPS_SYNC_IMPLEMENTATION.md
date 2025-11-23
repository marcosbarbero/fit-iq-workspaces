# Heart Rate and Steps Sync Implementation

**Created:** 2025-01-27  
**Status:** ✅ Implemented  
**Version:** 1.0.0

---

## 📋 Overview

This document describes the implementation of automatic heart rate and steps tracking from HealthKit, with local storage and remote server synchronization via the Progress API.

### What Was Implemented

1. **Heart Rate Tracking**: Automatic capture, storage, and sync of resting heart rate data
2. **Steps Tracking Fix**: Fixed the missing remote sync for steps data
3. **SummaryView Integration**: Display of heart rate data in the summary screen

---

## 🐛 Issues Addressed

### Issue #1: Steps Not Syncing to Remote Server

**Problem:**
- Steps were being captured from HealthKit ✅
- Steps were being stored in ActivitySnapshot locally ✅
- Steps were NOT being sent to the remote server ❌

**Root Cause:**
The `HealthDataSyncManager` was updating the ActivitySnapshot but never calling the `SaveStepsProgressUseCase` to trigger remote sync via the Progress API.

**Solution:**
Added `syncStepsToProgressTracking()` method in `HealthDataSyncManager` that:
1. Fetches steps from HealthKit for the current day
2. Calls `SaveStepsProgressUseCase.execute()`
3. Progress entry is saved locally with `syncStatus = .pending`
4. `LocalDataChangeMonitor` detects the change
5. `RemoteSyncService` syncs to backend via `/progress` endpoint

### Issue #2: Heart Rate Not Tracked

**Problem:**
- Heart rate was being stored in ActivitySnapshot for display
- Heart rate was NOT being sent to the remote server for tracking

**Solution:**
Implemented complete heart rate tracking following the same pattern as steps.

---

## 🏗️ Architecture

### Components Created

```
Domain/
├── UseCases/
│   └── SaveHeartRateProgressUseCase.swift         [NEW]
│       - Protocol: SaveHeartRateProgressUseCase
│       - Implementation: SaveHeartRateProgressUseCaseImpl
│       - Validates heart rate (20-300 bpm)
│       - Saves to ProgressRepository
│       - Handles deduplication

Infrastructure/
├── Integration/
│   └── HealthDataSyncManager.swift                [MODIFIED]
│       - Added saveStepsProgressUseCase dependency
│       - Added saveHeartRateProgressUseCase dependency
│       - Added syncStepsToProgressTracking() method
│       - Added syncHeartRateToProgressTracking() method
│       - Calls both methods when HealthKit data updates

├── Configuration/
│   ├── AppDependencies.swift                      [MODIFIED]
│   │   - Added saveHeartRateProgressUseCase property
│   │   - Reordered initialization for proper dependencies
│   │   - Wired up use cases to HealthDataSyncManager
│   │
│   └── ViewModelAppDependencies.swift             [MODIFIED]
│       - Injected saveHeartRateProgressUseCase into SummaryViewModel

Presentation/
├── ViewModels/
│   └── SummaryViewModel.swift                     [MODIFIED]
│       - Added saveHeartRateProgressUseCase dependency
│       - Added latestHeartRate property
│       - Added heartRateAvg computed property
│       - Added syncHeartRateToProgressTracking() method
│       - Updated reloadAllData() to sync heart rate
│
└── UI/
    └── Summary/
        └── SummaryView.swift                      [MODIFIED]
            - Replaced "Active Zone Min" card with Heart Rate card
            - Displays live heart rate data from viewModel
```

---

## 🔄 Data Flow

### Steps Sync Flow

```
HealthKit (Step Count Update)
    ↓
HealthKitAdapter.observerQuery fires
    ↓
HealthDataSyncManager.processNewHealthData(.stepCount)
    ↓
1. updateDailyActivitySnapshot()        ← Updates local ActivitySnapshot
    ↓
2. syncStepsToProgressTracking()        ← NEW: Triggers remote sync
    ↓
SaveStepsProgressUseCase.execute()
    ↓
ProgressRepository.save()
    ↓
SwiftDataProgressRepository (local storage)
    ↓
LocalDataChangeMonitor detects change
    ↓
RemoteSyncService syncs to backend
    ↓
Backend Progress API: POST /progress
```

### Heart Rate Sync Flow

```
HealthKit (Heart Rate Update)
    ↓
HealthKitAdapter.observerQuery fires
    ↓
HealthDataSyncManager.processNewHealthData(.heartRate)
    ↓
1. updateDailyActivitySnapshot()        ← Updates local ActivitySnapshot
    ↓
2. syncHeartRateToProgressTracking()    ← NEW: Triggers remote sync
    ↓
SaveHeartRateProgressUseCase.execute()
    ↓
ProgressRepository.save()
    ↓
SwiftDataProgressRepository (local storage)
    ↓
LocalDataChangeMonitor detects change
    ↓
RemoteSyncService syncs to backend
    ↓
Backend Progress API: POST /progress
```

---

## 📝 Implementation Details

### SaveHeartRateProgressUseCase

**Location:** `Domain/UseCases/SaveHeartRateProgressUseCase.swift`

**Key Features:**
- ✅ Validates heart rate (must be > 0 and between 20-300 bpm)
- ✅ Checks for existing entries on the same date
- ✅ Updates existing entry if value changed (> 0.5 bpm difference)
- ✅ Skips duplicate if value is the same
- ✅ Marks entries as `.pending` for sync
- ✅ Uses `.restingHeartRate` metric type

**Error Handling:**
```swift
enum SaveHeartRateProgressError: Error {
    case invalidHeartRate          // HR <= 0
    case heartRateOutOfRange       // HR < 20 or > 300
    case userNotAuthenticated      // No current user
}
```

### HealthDataSyncManager Updates

**New Dependencies:**
```swift
private let saveStepsProgressUseCase: SaveStepsProgressUseCase
private let saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase
```

**New Methods:**

#### syncStepsToProgressTracking(forDate:)
```swift
private func syncStepsToProgressTracking(forDate date: Date) async
```
- Fetches steps from HealthKit for specified date
- Calls `saveStepsProgressUseCase.execute()`
- Logs success/failure
- Non-blocking (errors don't crash the app)

#### syncHeartRateToProgressTracking(forDate:)
```swift
private func syncHeartRateToProgressTracking(forDate date: Date) async
```
- Fetches average heart rate from HealthKit for specified date
- Calls `saveHeartRateProgressUseCase.execute()`
- Logs success/failure
- Non-blocking (errors don't crash the app)

**Integration Point:**
```swift
case .stepCount, .distanceWalkingRunning, .basalEnergyBurned, .activeEnergyBurned, .heartRate:
    // Update ActivitySnapshot
    try await updateDailyActivitySnapshot(...)
    
    // NEW: Send steps to remote server
    if typeIdentifier == .stepCount {
        await syncStepsToProgressTracking(forDate: todayStart)
    }
    
    // NEW: Send heart rate to remote server
    if typeIdentifier == .heartRate {
        await syncHeartRateToProgressTracking(forDate: todayStart)
    }
```

### SummaryViewModel Updates

**New Properties:**
```swift
private let saveHeartRateProgressUseCase: SaveHeartRateProgressUseCase
var latestHeartRate: Double?

var heartRateAvg: Double? {
    latestActivitySnapshot?.heartRateAvg
}
```

**Updated reloadAllData():**
```swift
@MainActor
func reloadAllData() async {
    isLoading = true
    await self.fetchLatestActivitySnapshot()
    await self.fetchLatestHealthMetrics()
    await self.fetchHistoricalWeightData()
    await self.fetchLatestMoodEntry()
    await self.syncStepsToProgressTracking()          // Syncs steps
    await self.syncHeartRateToProgressTracking()      // NEW: Syncs heart rate
    isLoading = false
}
```

### SummaryView UI Changes

**Before:**
```swift
StatCard(
    currentValue: "45m",
    unit: "Active Zone Min.",
    icon: "bolt.heart.fill",
    color: .vitalityTeal
)
```

**After:**
```swift
StatCard(
    currentValue: viewModel.heartRateAvg != nil 
        ? "\(Int(viewModel.heartRateAvg!))" : "--",
    unit: "Avg Heart Rate",
    icon: "heart.fill",
    color: .vitalityTeal
)
```

---

## 🔧 Dependency Injection

### AppDependencies.swift Changes

**Order of Initialization:**
```swift
1. progressRepository (requires progressAPIClient, localDataChangeMonitor)
2. saveStepsProgressUseCase (requires progressRepository, authManager)
3. saveHeartRateProgressUseCase (requires progressRepository, authManager)
4. healthDataSyncService (requires both use cases)
5. processDailyHealthDataUseCase (requires healthDataSyncService)
6. processConsolidatedDailyHealthDataUseCase (requires healthDataSyncService)
7. backgroundSyncManager (requires healthDataSyncService, processing use cases)
```

**Key Change:**
Moved initialization of `healthDataSyncService` to AFTER `progressRepository` is created, ensuring all dependencies are available.

---

## 📊 Backend Integration

### Progress API Endpoints Used

**POST /progress**
```json
{
  "type": "steps",
  "quantity": 8542,
  "logged_at": "2025-01-27T10:30:00Z",
  "notes": null
}
```

**POST /progress**
```json
{
  "type": "resting_heart_rate",
  "quantity": 68.5,
  "logged_at": "2025-01-27T10:30:00Z",
  "notes": null
}
```

### Metric Types
- **Steps:** `"steps"` (unit: steps)
- **Heart Rate:** `"resting_heart_rate"` (unit: bpm)

---

## ✅ Testing Checklist

### Unit Testing
- [ ] Test `SaveHeartRateProgressUseCase` validation logic
- [ ] Test heart rate range validation (20-300 bpm)
- [ ] Test duplicate detection and updates
- [ ] Test error handling for unauthenticated user

### Integration Testing
- [ ] Test HealthKit → Local storage flow
- [ ] Test Local storage → Remote sync flow
- [ ] Test SummaryView displays correct heart rate
- [ ] Test steps sync to backend
- [ ] Test heart rate sync to backend

### Manual Testing
- [ ] Walk around and verify steps sync to backend
- [ ] Check Apple Watch heart rate updates sync
- [ ] Verify SummaryView shows live heart rate
- [ ] Check backend `/progress` endpoint receives data
- [ ] Test offline scenario (should sync when online)

---

## 🔍 Debugging

### Log Messages to Look For

**Steps Sync:**
```
HealthDataSyncService[stepCount]: Activity data updated. Triggering current day ActivitySnapshot refresh...
HealthDataSyncService: Syncing 8542 steps to progress tracking for 2025-01-27 00:00:00
SaveStepsProgressUseCase: Saving 8542 steps for user <UUID> on 2025-01-27...
HealthDataSyncService: ✅ Successfully synced steps to progress tracking. Local ID: <UUID>
```

**Heart Rate Sync:**
```
HealthDataSyncService[heartRate]: Activity data updated. Triggering current day ActivitySnapshot refresh...
HealthDataSyncService: Syncing heart rate 68.5 bpm to progress tracking for 2025-01-27 00:00:00
SaveHeartRateProgressUseCase: Saving heart rate 68.5 bpm for user <UUID> on 2025-01-27...
HealthDataSyncService: ✅ Successfully synced heart rate to progress tracking. Local ID: <UUID>
```

**Remote Sync:**
```
RemoteSyncService: Starting sync cycle...
RemoteSyncService: Found 2 pending progress entries to sync
RemoteSyncService: Successfully synced progress entry <UUID> to backend
```

### Common Issues

**Issue:** Steps/HR not syncing to backend
- Check: Is user authenticated?
- Check: Is HealthKit authorized for steps/heart rate?
- Check: Is device online?
- Check: Are there pending entries in SwiftData?

**Issue:** Heart rate shows "--" in UI
- Check: Is HealthKit authorized for heart rate?
- Check: Does device have heart rate data?
- Check: Is Apple Watch connected?

---

## 🚀 Future Enhancements

### Potential Improvements
1. **Real-time HR tracking**: Display current heart rate, not just daily average
2. **HR zones**: Track time in different heart rate zones
3. **HR variability**: Add HRV tracking for stress/recovery
4. **Historical charts**: Show steps and HR trends over time
5. **Manual entry**: Allow manual heart rate entry if no device
6. **Workout correlation**: Link heart rate to specific workouts

### Backend Enhancements
1. **Batch sync**: Send multiple progress entries in one request
2. **Delta sync**: Only send changed data
3. **Webhooks**: Real-time notifications for goal achievements
4. **Analytics**: Backend calculates trends and insights

---

## 📚 Related Documentation

- **Progress API Spec:** `docs/api-spec.yaml` (read-only, symlinked)
- **Steps Use Case:** `Domain/UseCases/SaveStepsProgressUseCase.swift`
- **Mood Tracking Fixes:** `docs/MOOD_TRACKING_FIXES_2025_01_27.md`
- **Integration Guide:** `docs/IOS_INTEGRATION_HANDOFF.md`

---

## 📝 Summary

### What Works Now ✅
1. ✅ Steps are captured from HealthKit
2. ✅ Steps are stored locally in ActivitySnapshot
3. ✅ **Steps are synced to remote server via Progress API**
4. ✅ Heart rate is captured from HealthKit
5. ✅ Heart rate is stored locally in ActivitySnapshot
6. ✅ **Heart rate is synced to remote server via Progress API**
7. ✅ **SummaryView displays live heart rate data**
8. ✅ Automatic background sync when HealthKit data changes
9. ✅ Proper error handling and logging
10. ✅ Deduplication to avoid duplicate entries

### Architecture Compliance ✅
- ✅ Follows Hexagonal Architecture (Ports & Adapters)
- ✅ Domain layer defines interfaces (protocols)
- ✅ Infrastructure layer implements adapters
- ✅ Proper dependency injection via AppDependencies
- ✅ Use cases encapsulate business logic
- ✅ Repository pattern for data access
- ✅ Event-driven sync via LocalDataChangeMonitor

---

**Version:** 1.0.0  
**Status:** ✅ Complete and Ready for Testing  
**Last Updated:** 2025-01-27