# Workout Tracking Implementation Guide

**Status:** Phases 1-3 Complete (Domain, HealthKit, Persistence, DTOs) ✅  
**Remaining:** Phases 4-6 (API Client, Sync Service, ViewModel Integration)  
**Created:** 2025-01-28  
**PR:** copilot/add-workout-tracking-feature

---

## Overview

This document provides a complete guide for implementing end-to-end workout tracking from HealthKit to backend API, following the Outbox Pattern for reliable synchronization.

---

## Completed Work ✅

### Phase 1: Domain Layer

**Files Created:**
- `FitIQ/Domain/Entities/Workout/WorkoutEntry.swift` - Domain workout model
- `FitIQ/Domain/Ports/WorkoutRepositoryProtocol.swift` - Repository contract
- `FitIQ/Domain/UseCases/Workout/SaveWorkoutUseCase.swift` - Save workout with Outbox Pattern
- `FitIQ/Domain/UseCases/Workout/GetHistoricalWorkoutsUseCase.swift` - Query workouts
- `FitIQ/Domain/UseCases/Workout/FetchHealthKitWorkoutsUseCase.swift` - HealthKit integration

**Files Modified:**
- `FitIQ/Domain/Entities/Outbox/OutboxEventTypes.swift` - Added `workout` event type

**Key Features:**
- WorkoutEntry includes all fields from swagger spec (activity_type, duration, calories, distance, intensity)
- Deduplication via sourceID (HealthKit UUID)
- SyncStatus for tracking backend sync state
- Computed properties for convenience (isFromHealthKit, isInProgress, etc.)

### Phase 2: HealthKit Integration

**Files Modified:**
- `FitIQ/Domain/Ports/HealthRepositoryProtocol.swift` - Added `fetchWorkouts()` method
- `FitIQ/Infrastructure/Integration/HealthKitAdapter.swift` - Implemented workout fetching

**Key Features:**
- Fetches HKWorkout samples from HealthKit
- Extracts duration, calories, distance, activity type
- Maps HKWorkoutActivityType to backend activity_type strings
- Already included in HealthKit authorization (HKObjectType.workoutType())

### Phase 3: SwiftData Persistence

**Files Created:**
- `FitIQ/Infrastructure/Persistence/Schema/SchemaV10.swift` - New schema with SDWorkout
- `FitIQ/Infrastructure/Persistence/SwiftDataWorkoutRepository.swift` - Repository implementation

**Files Modified:**
- `FitIQ/Infrastructure/Persistence/Schema/SchemaDefinition.swift` - Set CurrentSchema = SchemaV10
- `FitIQ/Infrastructure/Persistence/Schema/PersistenceHelper.swift` - Added SDWorkout typealias & toDomain()

**Key Features:**
- SDWorkout model with all workout fields
- Automatic Outbox event creation on save
- Deduplication by sourceID (prevents duplicate HealthKit imports)
- Relationship to SDUserProfileV10 with cascade delete

### Phase 3.5: API DTOs

**Files Created:**
- `FitIQ/Infrastructure/Network/DTOs/WorkoutDTOs.swift` - Request/Response DTOs

**Key Features:**
- CreateWorkoutRequest matches swagger spec exactly
- WorkoutResponse with backend field mapping (snake_case)
- toDomain() conversion for seamless integration
- RFC3339 date formatting for API compliance

---

## Remaining Implementation

### Phase 4: API Client & Outbox Integration

**What to Create:**

1. **WorkoutAPIClient** (`FitIQ/Infrastructure/Network/WorkoutAPIClient.swift`)
   - Follow pattern from `ProgressAPIClient.swift`
   - Implement `POST /api/v1/workouts` endpoint
   - Include token refresh logic (executeWithRetry)
   - Handle 401 with automatic token refresh

2. **Update OutboxProcessorService** (`FitIQ/Infrastructure/Network/OutboxProcessorService.swift`)
   - Add case for `.workout` event type in `syncEvent()` method
   - Fetch workout from SwiftDataWorkoutRepository
   - Convert to CreateWorkoutRequest DTO
   - Call WorkoutAPIClient
   - Update local workout with backendID and syncStatus = .synced
   - Mark outbox event as completed

**Code Snippets:**

```swift
// WorkoutAPIClient.swift
protocol WorkoutAPIClientProtocol {
    func createWorkout(request: CreateWorkoutRequest) async throws -> WorkoutResponse
}

final class WorkoutAPIClient: WorkoutAPIClientProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let authManager: AuthManager
    
    func createWorkout(request: CreateWorkoutRequest) async throws -> WorkoutResponse {
        // Similar to ProgressAPIClient.logProgress()
        // POST to /api/v1/workouts
        // Return WorkoutResponse
    }
}
```

```swift
// OutboxProcessorService.swift - Add to syncEvent()
case .workout:
    try await syncWorkoutEvent(event)

private func syncWorkoutEvent(_ event: SDOutboxEvent) async throws {
    // 1. Fetch workout from repository
    let workout = try await workoutRepository.fetchByID(event.entityID)
    
    // 2. Convert to CreateWorkoutRequest DTO
    let request = CreateWorkoutRequest(
        activityType: workout.activityType,  // Enum is automatically encoded to rawValue
        title: workout.title,
        notes: workout.notes,
        startedAt: workout.startedAt.toISO8601TimestampString(),
        endedAt: workout.endedAt?.toISO8601TimestampString(),
        durationMinutes: workout.durationMinutes,
        caloriesBurned: workout.caloriesBurned,
        distanceMeters: workout.distanceMeters,
        intensity: workout.intensity
    )
    
    // 3. Sync to backend
    let response = try await workoutAPIClient.createWorkout(request: request)
    
    // 4. Update local workout with backendID
    try await workoutRepository.updateSyncStatus(
        forID: event.entityID,
        syncStatus: .synced,
        backendID: response.id
    )
}
```

### Phase 5: HealthKit Sync Service

**What to Create:**

1. **HealthKitWorkoutSyncService** (`FitIQ/Infrastructure/Services/HealthKitWorkoutSyncService.swift`)
   - Fetch workouts from HealthKit for date range
   - Save to local DB via SaveWorkoutUseCase
   - Triggered during initial sync and daily sync

2. **Update PerformInitialHealthKitSyncUseCase**
   - Add workout sync to initial sync flow
   - Fetch last 30 days of workouts on first sync

3. **Update ProcessDailyHealthDataUseCase**
   - Add workout sync to daily sync flow
   - Fetch yesterday's workouts

**Code Snippets:**

```swift
// HealthKitWorkoutSyncService.swift
final class HealthKitWorkoutSyncService {
    private let fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase
    private let saveWorkoutUseCase: SaveWorkoutUseCase
    
    func syncWorkouts(from startDate: Date, to endDate: Date) async throws {
        // 1. Fetch from HealthKit
        let workouts = try await fetchHealthKitWorkoutsUseCase.execute(
            from: startDate,
            to: endDate
        )
        
        // 2. Save each workout
        for workout in workouts {
            do {
                _ = try await saveWorkoutUseCase.execute(workoutEntry: workout)
            } catch {
                print("Failed to save workout: \(error)")
            }
        }
    }
}
```

### Phase 6: ViewModel Integration

**What to Modify:**

1. **WorkoutViewModel** (`FitIQ/Presentation/ViewModels/WorkoutViewModel.swift`)
   - Add `getHistoricalWorkoutsUseCase` dependency
   - Replace mock `completedWorkouts` with real data
   - Add loading/error states
   - Subscribe to LocalDataChangeMonitor for real-time updates

**Code Snippets:**

```swift
@Observable
final class WorkoutViewModel {
    // NEW: Dependencies
    private let getHistoricalWorkoutsUseCase: GetHistoricalWorkoutsUseCase
    private let localDataChangeMonitor: LocalDataChangeMonitor
    
    // NEW: State
    var workouts: [WorkoutEntry] = []
    var isLoadingWorkouts = false
    var workoutError: String?
    
    // Keep existing mock for templates
    var workoutTemplates: [Workout] = [...]
    
    @MainActor
    func loadWorkouts() async {
        isLoadingWorkouts = true
        workoutError = nil
        
        do {
            // Fetch workouts from local DB (includes synced from HealthKit)
            let entries = try await getHistoricalWorkoutsUseCase.execute(
                from: nil,  // No date filter for now
                to: nil,
                limit: 100
            )
            workouts = entries
        } catch {
            workoutError = error.localizedDescription
        }
        
        isLoadingWorkouts = false
    }
    
    // Convert domain WorkoutEntry to UI CompletedWorkout
    var completedWorkouts: [CompletedWorkout] {
        workouts.map { workout in
            CompletedWorkout(
                date: workout.startedAt,
                name: workout.title ?? workout.activityType,
                durationMinutes: workout.durationMinutes ?? 0,
                caloriesBurned: workout.caloriesBurned ?? 0,
                source: workout.isFromHealthKit ? .healthKitImport : .appLogged,
                effortRPE: workout.intensity ?? 5,
                setsCompleted: 0,
                exercises: [:]
            )
        }
    }
}
```

---

## Testing Checklist

### Unit Tests
- [ ] SaveWorkoutUseCase - saves workout with pending status
- [ ] FetchHealthKitWorkoutsUseCase - maps HKWorkout to WorkoutEntry
- [ ] SwiftDataWorkoutRepository - saves workout and creates outbox event
- [ ] WorkoutAPIClient - creates workout via POST /api/v1/workouts

### Integration Tests
- [ ] End-to-end: HealthKit → Local DB → Backend
- [ ] Deduplication: Same HealthKit workout not saved twice
- [ ] Outbox Pattern: Failed sync retries automatically
- [ ] Offline resilience: Workouts saved locally without network

### Manual Testing
1. Grant HealthKit authorization
2. Log a workout in Apple Health app
3. Trigger sync in FitIQ app
4. Verify workout appears in WorkoutView
5. Check backend API for synced workout
6. Verify sourceID prevents duplicates

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  - WorkoutView (SwiftUI)                                    │
│  - WorkoutViewModel (@Observable)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │ depends on
┌─────────────────────▼───────────────────────────────────────┐
│                       Domain Layer                           │
│  - WorkoutEntry (entity)                                    │
│  - WorkoutRepositoryProtocol (port)                         │
│  - SaveWorkoutUseCase                                       │
│  - GetHistoricalWorkoutsUseCase                             │
│  - FetchHealthKitWorkoutsUseCase                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ implemented by
┌─────────────────────▼───────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  - HealthKitAdapter (HealthKit → Domain)                    │
│  - SwiftDataWorkoutRepository (Persistence + Outbox)        │
│  - WorkoutAPIClient (Backend API)                           │
│  - OutboxProcessorService (Sync coordinator)                │
│  - HealthKitWorkoutSyncService (Sync orchestrator)          │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Patterns Used

### 1. Hexagonal Architecture (Ports & Adapters)
- **Domain:** Pure business logic, no external dependencies
- **Ports:** Interfaces defined by domain (WorkoutRepositoryProtocol)
- **Adapters:** Infrastructure implements ports (SwiftDataWorkoutRepository, HealthKitAdapter)

### 2. Outbox Pattern
- **Problem:** Ensure workouts sync to backend even if app crashes
- **Solution:** Save workout locally + create outbox event atomically
- **Result:** OutboxProcessorService polls for pending events and syncs asynchronously

### 3. Deduplication via sourceID
- **Problem:** Same HealthKit workout imported multiple times
- **Solution:** Use HKWorkout.uuid as sourceID, check before saving
- **Result:** No duplicates even with repeated syncs

### 4. Local-First Architecture
- **Save to SwiftData first** (fast, always works)
- **Sync to backend asynchronously** (via Outbox Pattern)
- **UI shows local data immediately** (no loading spinners)
- **Backend sync happens in background** (user doesn't wait)

---

## Configuration

### HealthKit Permissions
Already configured in `RequestHealthKitAuthorizationUseCase.swift`:
- Read: `HKObjectType.workoutType()`
- Share: `HKObjectType.workoutType()`

### Info.plist
Ensure these keys are set:
- `NSHealthShareUsageDescription` - "FitIQ needs access to your workout data to track your fitness progress."
- `NSHealthUpdateUsageDescription` - "FitIQ needs to write workout data to HealthKit."

### Backend API
- Endpoint: `POST /api/v1/workouts`
- Authentication: JWT Bearer token + X-API-Key header
- Spec version: v0.17.0+ (includes intensity field)

---

## Migration Path

### Database Migration (SchemaV9 → SchemaV10)
- **Type:** Lightweight migration (new entity, no data loss)
- **Action:** Automatic on app launch
- **Rollback:** Not needed (additive change)

### Data Migration (Optional)
If you want to import existing HealthKit workouts:
```swift
// Run once on app launch after migration
let syncService = HealthKitWorkoutSyncService(...)
await syncService.syncWorkouts(
    from: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
    to: Date()
)
```

---

## Common Issues & Solutions

### Issue: Workouts not syncing from HealthKit
- **Check:** HealthKit authorization granted?
- **Check:** Workout authorization included in `typesToRead` set?
- **Fix:** Call `RequestHealthKitAuthorizationUseCase.execute()` again

### Issue: Duplicate workouts in database
- **Check:** Is sourceID set correctly (HKWorkout.uuid.uuidString)?
- **Check:** Deduplication logic in SwiftDataWorkoutRepository?
- **Fix:** Ensure `fetchBySourceID()` is called before saving

### Issue: Workouts not appearing in backend
- **Check:** Outbox events created (check SDOutboxEvent table)?
- **Check:** OutboxProcessorService running?
- **Check:** Backend API credentials valid?
- **Fix:** Check OutboxProcessorService logs for sync errors

---

## Next Steps

1. **Create WorkoutAPIClient** following ProgressAPIClient pattern
2. **Update OutboxProcessorService** to handle workout events
3. **Create HealthKitWorkoutSyncService** for sync orchestration
4. **Update ViewModels** to use real data
5. **Test end-to-end flow** from HealthKit to backend
6. **Document API integration** in `docs/api-integration/features/`

---

## References

- **Swagger Spec:** `docs/be-api-spec/swagger.yaml` (lines 1300-1456)
- **Existing Patterns:** 
  - Progress tracking: `SaveWeightProgressUseCase.swift`
  - Sleep tracking: `SleepRepositoryProtocol.swift`
  - Meal logging: `MealLogRepositoryProtocol.swift`
- **Architecture Docs:** `docs/architecture/SUMMARY_DATA_LOADING_PATTERN.md`
- **Outbox Pattern:** `docs/OUTBOX_PATTERN_ARCHITECTURE.md`

---

**Status:** Ready for Phase 4 implementation  
**Estimated Effort:** ~3-4 hours for remaining phases  
**Risk Level:** Low (follows established patterns)
