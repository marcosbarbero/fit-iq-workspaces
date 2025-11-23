# Phase 2.2 Day 7 - Direct FitIQCore Migration Plan

**Date:** 2025-01-27  
**Phase:** 2.2 Day 7 - Remove Bridge, Use FitIQCore Directly  
**Estimated Time:** 2-3 hours  
**Prerequisites:** Day 6 complete and tested ✅

---

## 🎯 Goal

Remove the `FitIQHealthKitBridge` adapter and migrate FitIQ to use FitIQCore's HealthKit services directly.

**Why?**
- Simpler architecture (no adapter overhead)
- Better performance (no delegation layer)
- Cleaner code (direct type usage)
- Easier to maintain (fewer layers)

---

## 📊 Current State Analysis

### Components Using HealthRepositoryProtocol

#### Use Cases (8 files)
1. `Domain/UseCases/DiagnoseHealthKitAccessUseCase.swift`
2. `Domain/UseCases/GetHistoricalWeightUseCase.swift`
3. `Domain/UseCases/GetLatestHeartRateUseCase.swift`
4. `Domain/UseCases/HealthKit/RequestHealthKitAuthorizationUseCase.swift`
5. `Domain/UseCases/SaveMoodProgressUseCase.swift`
6. `Domain/UseCases/Summary/GetDailyStepsTotalUseCase.swift`
7. `Domain/UseCases/Workout/CompleteWorkoutSessionUseCase.swift`
8. `Domain/UseCases/Workout/FetchHealthKitWorkoutsUseCase.swift`

#### Services (3 files)
1. `Infrastructure/Services/Sync/StepsSyncHandler.swift`
2. `Infrastructure/Services/Sync/HeartRateSyncHandler.swift`
3. `Infrastructure/Services/Sync/SleepSyncHandler.swift`

#### Integration (4 files)
1. `Infrastructure/Integration/PerformInitialHealthKitSyncUseCase.swift`
2. `Infrastructure/Integration/HealthKitProfileSyncService.swift`
3. `Infrastructure/Integration/FitIQHealthKitBridge.swift` (to be removed)
4. `Infrastructure/Integration/HealthKitAdapter.swift` (legacy, to be removed)

#### Other (2 files)
1. `Domain/UseCases/BackgroundSyncManager.swift`
2. `Infrastructure/Configuration/AppDependencies.swift`

**Total:** ~17 files to update

---

## 🚀 Migration Strategy

### Phase 1: Analyze & Plan (15 min)
**Goal:** Understand current usage patterns

**Tasks:**
- [x] Identify all files using HealthRepositoryProtocol
- [ ] Document method usage patterns
- [ ] Identify breaking changes
- [ ] Plan migration order

### Phase 2: Create New Infrastructure (30 min)
**Goal:** Add FitIQCore services to AppDependencies

**Tasks:**
- [ ] Add FitIQCore services as properties
- [ ] Wire up HealthKitService
- [ ] Wire up HealthAuthorizationService
- [ ] Keep bridge temporarily for comparison

### Phase 3: Migrate Use Cases (45 min)
**Goal:** Update use cases to use FitIQCore directly

**Migration Pattern:**
```swift
// BEFORE (via HealthRepositoryProtocol)
let result = try await healthRepository.fetchLatestQuantitySample(
    for: .stepCount,
    unit: .count()
)

// AFTER (direct FitIQCore)
let metric = try await healthKitService.queryLatest(
    type: .stepCount,
    unit: .metric
)
```

**Order:**
1. Simple query use cases (3 files)
2. Authorization use case (1 file)
3. Write operation use cases (2 files)
4. Complex use cases (2 files)

### Phase 4: Migrate Services (30 min)
**Goal:** Update sync handlers

**Tasks:**
- [ ] Update StepsSyncHandler
- [ ] Update HeartRateSyncHandler
- [ ] Update SleepSyncHandler

### Phase 5: Migrate Integration Layer (15 min)
**Goal:** Update profile sync and initial sync

**Tasks:**
- [ ] Update PerformInitialHealthKitSyncUseCase
- [ ] Update HealthKitProfileSyncService
- [ ] Update BackgroundSyncManager

### Phase 6: Remove Bridge & Legacy (15 min)
**Goal:** Clean up old code

**Tasks:**
- [ ] Remove FitIQHealthKitBridge.swift
- [ ] Remove HealthKitAdapter.swift
- [ ] Remove HealthRepositoryProtocol.swift
- [ ] Remove HealthKitTypeTranslator.swift (if no longer needed)
- [ ] Update AppDependencies

### Phase 7: Test & Validate (30 min)
**Goal:** Ensure everything works

**Tasks:**
- [ ] Build succeeds
- [ ] App launches
- [ ] HealthKit authorization works
- [ ] Data fetching works
- [ ] Data writing works
- [ ] Profile sync works
- [ ] No crashes or errors

---

## 📝 Detailed Migration Guide

### Example: Simple Query Use Case

**File:** `GetLatestHeartRateUseCase.swift`

#### Before (via Protocol)
```swift
final class GetLatestHeartRateUseCase {
    private let healthRepository: HealthRepositoryProtocol
    
    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }
    
    func execute() async throws -> (value: Double, date: Date)? {
        return try await healthRepository.fetchLatestQuantitySample(
            for: .heartRate,
            unit: .count().unitDivided(by: .minute())
        )
    }
}
```

#### After (Direct FitIQCore)
```swift
import FitIQCore

final class GetLatestHeartRateUseCase {
    private let healthKitService: HealthKitServiceProtocol
    
    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }
    
    func execute() async throws -> (value: Double, date: Date)? {
        let metric = try await healthKitService.queryLatest(
            type: .heartRate,
            unit: .metric
        )
        
        return metric.map { (value: $0.value, date: $0.timestamp) }
    }
}
```

**Changes:**
1. Import FitIQCore
2. Change dependency to `HealthKitServiceProtocol`
3. Use `.heartRate` (FitIQCore type) instead of `.heartRate` (HK type)
4. Use `queryLatest` instead of `fetchLatestQuantitySample`
5. Map `HealthMetric` to tuple if needed

---

### Example: Authorization Use Case

**File:** `RequestHealthKitAuthorizationUseCase.swift`

#### Before (via Protocol)
```swift
final class RequestHealthKitAuthorizationUseCase {
    private let healthRepository: HealthRepositoryProtocol
    
    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }
    
    func execute() async throws {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRate),
            // ... more types
        ]
        
        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            // ... more types
        ]
        
        try await healthRepository.requestAuthorization(
            read: readTypes,
            share: shareTypes
        )
    }
}
```

#### After (Direct FitIQCore)
```swift
import FitIQCore

final class RequestHealthKitAuthorizationUseCase {
    private let authService: HealthAuthorizationServiceProtocol
    
    init(authService: HealthAuthorizationServiceProtocol) {
        self.authService = authService
    }
    
    func execute() async throws {
        let readTypes: Set<HealthDataType> = [
            .stepCount,
            .heartRate,
            .bodyMass,
            .height,
            // ... more types
        ]
        
        let writeTypes: Set<HealthDataType> = [
            .bodyMass,
            .height,
            // ... more types
        ]
        
        try await authService.requestAuthorization(
            toRead: readTypes,
            toWrite: writeTypes
        )
    }
}
```

**Changes:**
1. Use `HealthAuthorizationServiceProtocol` instead of `HealthRepositoryProtocol`
2. Use `HealthDataType` instead of `HKObjectType`
3. Simpler API: `toRead` and `toWrite` instead of `read` and `share`

---

### Example: Write Operation Use Case

**File:** `SaveMoodProgressUseCase.swift`

#### Before (via Protocol)
```swift
final class SaveMoodProgressUseCase {
    private let healthRepository: HealthRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    
    func execute(mood: Int, notes: String?, date: Date) async throws {
        // Save to HealthKit
        try await healthRepository.saveCategorySample(
            value: mood,
            typeIdentifier: .mindfulSession,
            date: date,
            metadata: notes.map { ["notes": $0] }
        )
        
        // Save to progress tracking
        // ...
    }
}
```

#### After (Direct FitIQCore)
```swift
import FitIQCore

final class SaveMoodProgressUseCase {
    private let healthKitService: HealthKitServiceProtocol
    private let progressRepository: ProgressRepositoryProtocol
    
    func execute(mood: Int, notes: String?, date: Date) async throws {
        // Create HealthMetric
        let metric = HealthMetric(
            type: .mindfulSession,
            value: Double(mood),
            unit: "count",
            timestamp: date,
            metadata: notes.map { ["notes": $0] } ?? [:]
        )
        
        // Save to HealthKit
        try await healthKitService.save(metric)
        
        // Save to progress tracking
        // ...
    }
}
```

**Changes:**
1. Use `HealthKitServiceProtocol` instead of `HealthRepositoryProtocol`
2. Create `HealthMetric` object
3. Use `.mindfulSession` (FitIQCore enum)
4. Use `save(metric)` instead of `saveCategorySample`

---

## 🔄 Type Mapping Reference

### HealthKit Types → FitIQCore Types

| HKQuantityTypeIdentifier | HealthDataType |
|--------------------------|----------------|
| `.stepCount` | `.stepCount` |
| `.heartRate` | `.heartRate` |
| `.bodyMass` | `.bodyMass` |
| `.height` | `.height` |
| `.activeEnergyBurned` | `.activeEnergyBurned` |
| `.basalEnergyBurned` | `.basalEnergyBurned` |
| `.distanceWalkingRunning` | `.distanceWalkingRunning` |
| `.flightsClimbed` | `.flightsClimbed` |
| `.appleExerciseTime` | `.exerciseTime` |
| `.appleStandTime` | `.standTime` |
| `.heartRateVariabilitySDNN` | `.heartRateVariability` |
| `.oxygenSaturation` | `.oxygenSaturation` |
| `.respiratoryRate` | `.respiratoryRate` |

### HKCategoryTypeIdentifier → HealthDataType

| HKCategoryTypeIdentifier | HealthDataType |
|--------------------------|----------------|
| `.sleepAnalysis` | `.sleepAnalysis` |
| `.mindfulSession` | `.mindfulSession` |

### Method Mapping

| HealthRepositoryProtocol | HealthKitServiceProtocol |
|--------------------------|-------------------------|
| `fetchLatestQuantitySample(for:unit:)` | `queryLatest(type:unit:)` |
| `fetchQuantitySamples(for:unit:predicateProvider:limit:)` | `query(type:unit:options:)` |
| `fetchSumOfQuantitySamples(for:unit:from:to:)` | `queryStatistics(type:unit:from:to:statisticsOption:)` |
| `saveQuantitySample(value:unit:typeIdentifier:date:)` | `save(_ metric: HealthMetric)` |
| `requestAuthorization(read:share:)` | `requestAuthorization(toRead:toWrite:)` |

---

## ⚠️ Breaking Changes & Considerations

### 1. Return Types Changed
**Before:** Tuples `(value: Double, date: Date)`  
**After:** `HealthMetric` objects

**Solution:** Map to tuples in use cases if needed

### 2. Unit System Changed
**Before:** `HKUnit` objects  
**After:** String-based units or `.metric`/`.imperial`

**Solution:** Use FitIQCore's unit system

### 3. Predicate Handling Changed
**Before:** `NSPredicate` via closure  
**After:** `HealthQueryOptions` struct

**Solution:** Convert predicates to query options

### 4. Observer Queries
**Before:** Handled by HealthRepositoryProtocol  
**After:** Need to implement directly or use FitIQCore observer

**Solution:** Evaluate if still needed, implement if required

---

## 🧪 Testing Strategy

### Unit Tests
- [ ] Test each migrated use case independently
- [ ] Mock `HealthKitServiceProtocol` for testing
- [ ] Verify type conversions are correct
- [ ] Test error handling

### Integration Tests
- [ ] Test authorization flow
- [ ] Test data fetching
- [ ] Test data writing
- [ ] Test profile sync

### Manual Testing
- [ ] Build succeeds (0 errors, 0 warnings)
- [ ] App launches without crash
- [ ] HealthKit authorization works
- [ ] Body mass data loads
- [ ] Steps data displays
- [ ] Heart rate shows correctly
- [ ] Can save measurements
- [ ] Profile height syncs to HealthKit
- [ ] All existing features work

---

## 📊 Success Criteria

### Code Quality
- [ ] 0 compilation errors
- [ ] 0 warnings
- [ ] All use cases migrated
- [ ] Bridge removed
- [ ] Legacy adapter removed

### Functionality
- [ ] All tests pass
- [ ] Manual testing passes
- [ ] No regressions
- [ ] Performance equal or better

### Architecture
- [ ] Simpler dependency graph
- [ ] Direct FitIQCore usage
- [ ] No adapter layer
- [ ] Clean separation of concerns

---

## 🔄 Rollback Plan

If issues arise during migration:

### Quick Rollback
1. Revert commits to Day 6 state
2. Bridge adapter still exists
3. All code still works
4. Investigate issues before re-attempting

### Partial Rollback
1. Keep migrated use cases that work
2. Revert problematic ones
3. Fix issues individually
4. Re-migrate incrementally

---

## 📈 Estimated Timeline

| Phase | Task | Time | Total |
|-------|------|------|-------|
| 1 | Analyze & Plan | 15 min | 0.25h |
| 2 | New Infrastructure | 30 min | 0.5h |
| 3 | Migrate Use Cases (8) | 45 min | 0.75h |
| 4 | Migrate Services (3) | 30 min | 0.5h |
| 5 | Migrate Integration (3) | 15 min | 0.25h |
| 6 | Remove Bridge & Legacy | 15 min | 0.25h |
| 7 | Test & Validate | 30 min | 0.5h |
| **Total** | | | **3h** |

**Buffer:** +30 min for unexpected issues  
**Total with Buffer:** 3.5h

---

## 🎯 Next Actions

### Immediate (This Session)
1. Review this plan
2. Start Phase 2: Add FitIQCore services to AppDependencies
3. Begin Phase 3: Migrate first use case as proof of concept

### After Migration Complete
1. Commit changes
2. Run full test suite
3. Deploy to TestFlight (optional)
4. Move to Day 8 (cleanup & polish)

---

## 📚 Reference Documents

- **FitIQCore API:** `FitIQCore/README.md`
- **HealthKitService:** `FitIQCore/Sources/FitIQCore/Health/Infrastructure/HealthKitService.swift`
- **Day 6 Success:** `PHASE_2.2_DAY6_TESTING_PASSED.md`
- **Current Architecture:** `PHASE_2.2_INTEGRATION_COMPLETE.md`

---

**Status:** 📋 Ready to Begin  
**Confidence:** High - Clear plan, proven foundation  
**Risk:** Low - Can rollback to working Day 6 state

**Let's simplify the architecture! 🚀**