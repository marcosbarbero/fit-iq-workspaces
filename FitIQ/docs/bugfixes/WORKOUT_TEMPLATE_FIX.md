# Workout Template Repository Fix

**Date:** 2025-01-28  
**Issue:** Compilation errors after SwiftData migration  
**Status:** ✅ Fixed

---

## Problem

After migrating from `WorkoutTemplateRepository` (UserDefaults-based) to `SwiftDataWorkoutTemplateRepository`, two compilation errors appeared in `WorkoutViewModel.swift`:

```
Cannot find 'WorkoutTemplateRepository' in scope
```

### Root Cause

The `WorkoutViewModel` was directly instantiating the old repository class:

```swift
// ❌ BEFORE: Direct instantiation of deleted class
_ = try await WorkoutTemplateRepository().update(template: updatedTemplate)
```

This violated the dependency injection pattern and broke after we deleted the old repository.

---

## Solution

### 1. Inject Repository Protocol

Added `workoutTemplateRepository` as a dependency to `WorkoutViewModel`:

**File:** `WorkoutViewModel.swift`

```swift
// Added property
private let workoutTemplateRepository: WorkoutTemplateRepositoryProtocol?

// Updated initializer
init(
    getHistoricalWorkoutsUseCase: GetHistoricalWorkoutsUseCase? = nil,
    authManager: AuthManager? = nil,
    fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase? = nil,
    saveWorkoutUseCase: SaveWorkoutUseCase? = nil,
    fetchWorkoutTemplatesUseCase: FetchWorkoutTemplatesUseCase? = nil,
    syncWorkoutTemplatesUseCase: SyncWorkoutTemplatesUseCase? = nil,
    createWorkoutTemplateUseCase: CreateWorkoutTemplateUseCase? = nil,
    startWorkoutSessionUseCase: StartWorkoutSessionUseCase? = nil,
    completeWorkoutSessionUseCase: CompleteWorkoutSessionUseCase? = nil,
    workoutTemplateRepository: WorkoutTemplateRepositoryProtocol? = nil  // NEW
) {
    // ...
    self.workoutTemplateRepository = workoutTemplateRepository
}
```

### 2. Update Method Implementations

Changed `toggleFavorite` and `toggleFeatured` methods to use injected repository:

```swift
// ✅ AFTER: Use injected repository protocol
guard let repository = self.workoutTemplateRepository else { return }
_ = try await repository.update(template: updatedTemplate)
```

### 3. Update View Initialization

Updated `WorkoutView.swift` to pass the repository when creating the ViewModel:

```swift
viewModel = WorkoutViewModel(
    getHistoricalWorkoutsUseCase: deps.getHistoricalWorkoutsUseCase,
    authManager: deps.authManager,
    fetchHealthKitWorkoutsUseCase: deps.fetchHealthKitWorkoutsUseCase,
    saveWorkoutUseCase: deps.saveWorkoutUseCase,
    fetchWorkoutTemplatesUseCase: deps.fetchWorkoutTemplatesUseCase,
    syncWorkoutTemplatesUseCase: deps.syncWorkoutTemplatesUseCase,
    createWorkoutTemplateUseCase: deps.createWorkoutTemplateUseCase,
    startWorkoutSessionUseCase: deps.startWorkoutSessionUseCase,
    completeWorkoutSessionUseCase: deps.completeWorkoutSessionUseCase,
    workoutTemplateRepository: deps.workoutTemplateRepository  // NEW
)
```

---

## Benefits

### Before (Anti-Pattern)
```
WorkoutViewModel → Direct Instantiation → WorkoutTemplateRepository (Concrete Class)
```

**Problems:**
- ❌ Tight coupling to concrete implementation
- ❌ Cannot be unit tested (no mocking)
- ❌ Violates dependency inversion principle
- ❌ Breaks when implementation changes

### After (Proper DI)
```
WorkoutViewModel → Injected Dependency → WorkoutTemplateRepositoryProtocol → SwiftDataWorkoutTemplateRepository
```

**Benefits:**
- ✅ Loose coupling via protocol
- ✅ Easily testable (mock protocol)
- ✅ Follows hexagonal architecture
- ✅ Resilient to implementation changes

---

## Files Modified

1. **`WorkoutViewModel.swift`**
   - Added `workoutTemplateRepository` property
   - Updated initializer
   - Fixed `toggleFavorite()` method
   - Fixed `toggleFeatured()` method

2. **`WorkoutView.swift`**
   - Added `workoutTemplateRepository` to ViewModel initialization

---

## Testing

### Verified
- ✅ Compilation succeeds
- ✅ No errors or warnings
- ✅ Proper dependency injection pattern

### To Test (Manual)
- [ ] Toggle favorite on a template
- [ ] Toggle featured on a template
- [ ] Verify changes persist after app restart
- [ ] Verify SwiftData storage works correctly

---

## Architecture Notes

This fix aligns the code with the project's hexagonal architecture:

```
Presentation Layer (WorkoutViewModel)
    ↓ depends on ↓
Domain Layer (WorkoutTemplateRepositoryProtocol)
    ↑ implemented by ↑
Infrastructure Layer (SwiftDataWorkoutTemplateRepository)
```

The ViewModel now properly depends on the **protocol** (port), not the concrete implementation (adapter).

---

## Related Documentation

- **Main Migration:** `WORKOUT_TEMPLATE_SWIFTDATA_MIGRATION.md`
- **Schema Changes:** `MIGRATION_SUMMARY_V11.md`
- **Architecture Guide:** `.github/copilot-instructions.md`

---

**Status:** ✅ Complete  
**Compilation:** ✅ Passes  
**Architecture:** ✅ Compliant