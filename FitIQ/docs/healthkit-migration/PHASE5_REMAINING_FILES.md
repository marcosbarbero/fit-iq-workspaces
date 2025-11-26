# Phase 5: Remaining Files Analysis

**Status:** 📋 Analysis Complete  
**Date:** 2025-01-27

---

## Overview

This document identifies all remaining files that still reference `HealthRepositoryProtocol` and categorizes them by priority for migration or removal.

---

## File Categories

### Category A: Active Usage (Must Migrate) 🔴

These files actively use `HealthRepositoryProtocol` and need migration to FitIQCore.

#### 1. `BackgroundSyncManager.swift`
**Location:** `Domain/UseCases/BackgroundSyncManager.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Medium

**Current Usage:**
```swift
private var healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Check if actually used (might be dead code)
- If unused, remove the property entirely

---

#### 2. `CompleteWorkoutSessionUseCase.swift`
**Location:** `Domain/UseCases/Workout/CompleteWorkoutSessionUseCase.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Low

**Current Usage:**
```swift
private let healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Update to save workout data using FitIQCore
- Update AppDependencies injection

---

#### 3. `FetchHealthKitWorkoutsUseCase.swift`
**Location:** `Domain/UseCases/Workout/FetchHealthKitWorkoutsUseCase.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Medium

**Current Usage:**
```swift
private let healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Use `querySamples(dataType: .workout, ...)` from FitIQCore
- Update AppDependencies injection

---

#### 4. `HealthKitProfileSyncService.swift`
**Location:** `Infrastructure/Integration/HealthKitProfileSyncService.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Medium

**Current Usage:**
```swift
private let healthKitAdapter: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Update biological sex, date of birth queries
- Update AppDependencies injection

---

#### 5. `PerformInitialHealthKitSyncUseCase.swift`
**Location:** `Infrastructure/Integration/PerformInitialHealthKitSyncUseCase.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Medium

**Current Usage:**
```swift
private let healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Update initial sync queries to use FitIQCore
- Update AppDependencies injection

---

#### 6. `SaveBodyMassUseCase.swift`
**Location:** `Presentation/UI/Summary/SaveBodyMassUseCase.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Low

**Current Usage:**
```swift
private let healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Use `saveSample(dataType: .bodyMass, ...)` from FitIQCore
- Update AppDependencies injection

---

#### 7. `BodyMassDetailViewModel.swift`
**Location:** `Presentation/ViewModels/BodyMassDetailViewModel.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Low

**Current Usage:**
```swift
private let healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Update any direct HealthKit queries
- Update AppDependencies injection

---

#### 8. `ProfileViewModel.swift`
**Location:** `Presentation/ViewModels/ProfileViewModel.swift`  
**Status:** 🔴 Must Migrate  
**Complexity:** Low

**Current Usage:**
```swift
private let healthRepository: HealthRepositoryProtocol
```

**Migration Strategy:**
- Replace with `HealthKitServiceProtocol`
- Update any direct HealthKit queries
- Update AppDependencies injection

---

### Category B: Bridge/Adapter (Remove in Phase 6) 🟡

These are legacy adapters that will be removed entirely in Phase 6.

#### 9. `FitIQHealthKitBridge.swift`
**Location:** `Infrastructure/Integration/FitIQHealthKitBridge.swift`  
**Status:** 🟡 Remove in Phase 6  
**Action:** DO NOT MIGRATE - This is the bridge adapter we're removing

**Note:** This file implements `HealthRepositoryProtocol` as a bridge to FitIQCore. Once all other files are migrated, this entire file will be deleted.

---

#### 10. `HealthKitAdapter.swift`
**Location:** `Infrastructure/Integration/HealthKitAdapter.swift`  
**Status:** 🟡 Remove in Phase 6  
**Action:** DO NOT MIGRATE - Legacy adapter (deprecated)

**Note:** Already marked as deprecated. Will be removed in Phase 6 cleanup.

---

### Category C: Dependency Container (Update Last) 🔵

#### 11. `AppDependencies.swift`
**Location:** `Infrastructure/Configuration/AppDependencies.swift`  
**Status:** 🔵 Update Throughout  
**Action:** Update as we migrate each file

**Current State:**
- Has `healthRepository: HealthRepositoryProtocol` property
- Used for backward compatibility during migration
- Will be removed in Phase 6 after all migrations complete

**Strategy:**
- Keep for now as legacy compatibility
- Update each use case/service injection as we migrate
- Remove entirely in Phase 6

---

## Migration Priority

### P0 (Critical - Migrate First)
1. `SaveBodyMassUseCase.swift` - User-facing feature
2. `PerformInitialHealthKitSyncUseCase.swift` - Initial sync flow
3. `HealthKitProfileSyncService.swift` - Profile sync

### P1 (High - Migrate Second)
4. `FetchHealthKitWorkoutsUseCase.swift` - Workout tracking
5. `CompleteWorkoutSessionUseCase.swift` - Workout tracking
6. `BackgroundSyncManager.swift` - Background operations

### P2 (Medium - Migrate Third)
7. `BodyMassDetailViewModel.swift` - View model
8. `ProfileViewModel.swift` - View model

---

## Estimated Time

| Priority | Files | Time Est | Notes |
|----------|-------|----------|-------|
| P0 | 3 files | 30 min | User-facing & critical flows |
| P1 | 3 files | 25 min | Background & workout features |
| P2 | 2 files | 15 min | View models (simpler) |
| **Total** | **8 files** | **70 min** | Conservative estimate |

**Actual Expected:** ~45-50 minutes (based on Phase 3-4 performance)

---

## Migration Checklist

For each file:

- [ ] Identify all `HealthRepositoryProtocol` references
- [ ] Replace with `HealthKitServiceProtocol` or `HealthAuthorizationServiceProtocol`
- [ ] Update method calls to FitIQCore API
- [ ] Update error handling
- [ ] Update AppDependencies injection
- [ ] Build and verify zero errors
- [ ] Test functionality (if possible)

---

## Next Actions

1. **Start with P0 files:**
   - `SaveBodyMassUseCase.swift`
   - `PerformInitialHealthKitSyncUseCase.swift`
   - `HealthKitProfileSyncService.swift`

2. **Then P1 files:**
   - `FetchHealthKitWorkoutsUseCase.swift`
   - `CompleteWorkoutSessionUseCase.swift`
   - `BackgroundSyncManager.swift`

3. **Finally P2 files:**
   - `BodyMassDetailViewModel.swift`
   - `ProfileViewModel.swift`

4. **Phase 6:** Remove bridge adapters and legacy code

---

## Success Criteria

- [ ] All 8 active files migrated to FitIQCore
- [ ] Zero compilation errors
- [ ] Zero warnings
- [ ] AppDependencies updated for all files
- [ ] No references to `HealthRepositoryProtocol` except in bridge/adapter files (to be removed)

---

**Last Updated:** 2025-01-27  
**Status:** Ready to begin P0 migrations