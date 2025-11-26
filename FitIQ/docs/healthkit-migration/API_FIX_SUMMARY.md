# FitIQCore API Method Name Fix

**Date:** 2025-01-27  
**Issue:** Incorrect method names and parameter types used during Phase 4-5 migration  
**Status:** ✅ Fixed

---

## Problem

During the migration to FitIQCore in Phases 4 and 5, incorrect method names and parameter types were used:

### Incorrect Usage
- ❌ `healthKitService.saveSample(dataType:value:date:metadata:)`
- ❌ `healthKitService.querySamples(dataType:startDate:endDate:options:)`
- ❌ `metadata: [String: Any]?` - Wrong metadata type

### Correct Usage
- ✅ `healthKitService.save(metric:)` - Takes a `HealthMetric` object
- ✅ `healthKitService.query(type:from:to:options:)` - Returns array of `HealthMetric`
- ✅ `metadata: [String: String]` - Correct metadata type (String keys and values)

---

## Root Cause

1. **Method Names:** The incorrect method names (`saveSample`, `querySamples`) were inferred based on common naming patterns but don't exist in FitIQCore's `HealthKitServiceProtocol`.

2. **Metadata Type:** The `HealthMetric` struct uses `[String: String]` for metadata, not `[String: Any]?`. This is more type-safe and aligns with HealthKit's metadata requirements.

The actual FitIQCore API uses:
- `query(type:from:to:options:)` for querying
- `save(metric:)` for saving with `HealthMetric(type:value:unit:date:source:metadata:)`

---

## Files Fixed (10 total)

### Phase 4 Files (3)
1. ✅ `Infrastructure/Services/Sync/StepsSyncHandler.swift`
2. ✅ `Infrastructure/Services/Sync/HeartRateSyncHandler.swift`
3. ✅ `Infrastructure/Services/Sync/SleepSyncHandler.swift`

### Phase 5 Files (7)
4. ✅ `Presentation/UI/Summary/SaveBodyMassUseCase.swift`
5. ✅ `Infrastructure/Integration/PerformInitialHealthKitSyncUseCase.swift`
6. ✅ `Infrastructure/Integration/HealthKitProfileSyncService.swift`
7. ✅ `Domain/UseCases/Workout/FetchHealthKitWorkoutsUseCase.swift`
8. ✅ `Domain/UseCases/Workout/CompleteWorkoutSessionUseCase.swift`
9. ✅ `Presentation/ViewModels/BodyMassDetailViewModel.swift`
10. ✅ `Presentation/ViewModels/ProfileViewModel.swift` (no API calls, just dependency injection)

---

## Correct Patterns

### Querying Data

```swift
// ✅ CORRECT
let options = HealthQueryOptions(
    aggregation: .sum(.hourly),
    sortOrder: .ascending,
    limit: nil
)

let metrics = try await healthKitService.query(
    type: .stepCount,
    from: startDate,
    to: endDate,
    options: options
)
```

### Saving Data

```swift
// ✅ CORRECT
let metric = HealthMetric(
    type: .bodyMass,
    value: weightKg,
    unit: "kg",
    date: date,
    source: "FitIQ"
    // metadata is optional with default empty dictionary
)
try await healthKitService.save(metric: metric)
```

### Saving with Extended Properties (e.g., Workouts)

```swift
// ✅ CORRECT
// Convert any metadata to String-only dictionary
var stringMetadata: [String: String] = [:]
for (key, value) in originalMetadata {
    stringMetadata[key] = "\(value)"
}

let metric = HealthMetric(
    type: .workouts,
    value: durationSeconds,
    unit: "s",
    date: startDate,
    startDate: startDate,
    endDate: endDate,
    source: "FitIQ",
    metadata: stringMetadata  // Must be [String: String]
)
try await healthKitService.save(metric: metric)
```

---

## Verification

### Build Status
- ✅ Zero compilation errors
- ✅ Zero warnings
- ✅ All files use correct API

### Testing Required
- [ ] Manual testing of all save flows (weight, height, workouts)
- [ ] Manual testing of all query flows (steps, heart rate, sleep, body mass)
- [ ] Verify data appears correctly in Apple Health app

---

## Lessons Learned

1. **Always verify API in the source protocol** - Don't assume method names based on patterns
2. **Check parameter types carefully** - `[String: String]` vs `[String: Any]?` matters
3. **Check FitIQCore documentation** - The protocol is well-documented with examples
4. **Look at existing usage** - Bridge adapter (`FitIQHealthKitBridge`) had correct usage
5. **Test incrementally** - Catch API errors early by building after each file
6. **Type safety is enforced** - Swift's type system catches these errors at compile time

---

## Related Documentation

- `FitIQCore/Sources/FitIQCore/Health/Domain/Ports/HealthKitServiceProtocol.swift` - Source protocol
- `docs/healthkit-migration/PHASE4_SERVICES_MIGRATION.md` - Phase 4 migration
- `docs/healthkit-migration/PHASE5_COMPLETION_SUMMARY.md` - Phase 5 migration

---

**Status:** ✅ All files corrected and building successfully  
**Next Step:** Proceed with Phase 6 cleanup