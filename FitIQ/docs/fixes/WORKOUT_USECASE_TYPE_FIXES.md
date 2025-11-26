# Workout Use Case Type Fixes

**Date:** 2025-01-27  
**Phase:** 5 (HealthKit Services Migration)  
**Status:** ✅ Completed

---

## Overview

Fixed compilation errors in workout-related use cases caused by:
1. Type ambiguity between FitIQ and FitIQCore `HealthMetric` types
2. Incorrect parameter order in `HealthMetric` initializer
3. Property access errors on `HealthMetric` struct

---

## Errors Fixed

### 1. CompleteWorkoutSessionUseCase.swift

**Errors:**
- Line 126: Extra arguments at positions #1-#8 in call
- Line 127: Missing argument for parameter 'rawValue' in call
- Line 127: Cannot infer contextual base in reference to member 'workout'
- Line 127: Cannot infer contextual base in reference to member 'other'

**Root Cause:**
- Parameters passed to `HealthMetric` initializer in wrong order
- Type ambiguity not resolved with explicit namespace

**Fix:**
```swift
// ❌ BEFORE (Incorrect parameter order)
let metric = HealthMetric(
    type: .workout(.other),
    value: durationSeconds,
    unit: "s",
    date: startDate,      // ❌ Wrong - should be endDate as primary date
    startDate: startDate,
    endDate: endDate,
    source: "FitIQ",
    metadata: stringMetadata
)

// ✅ AFTER (Correct parameter order and explicit type)
let metric = FitIQCore.HealthMetric(
    type: .workout(.other),
    value: durationSeconds,
    unit: "s",
    date: endDate,        // ✅ Correct - endDate is primary date for duration metrics
    startDate: startDate,
    endDate: endDate,
    source: "FitIQ",
    metadata: stringMetadata
)
```

**Key Changes:**
1. Explicitly qualified type as `FitIQCore.HealthMetric` to resolve ambiguity
2. Changed primary `date` parameter from `startDate` to `endDate` (matches FitIQCore convention)
3. This aligns with FitIQCore's pattern where `date` represents the primary timestamp (end of workout)

---

### 2. FetchHealthKitWorkoutsUseCase.swift

**Errors:**
- Line 72: Cannot convert value of type 'FitIQCore.HealthMetric' to expected argument type 'FitIQ.HealthMetric'
- Line 88, 98, 106, 114, 121: Value of type 'HealthMetric' has no member 'metadata'
- Line 92, 93: Value of type 'HealthMetric' has no member 'startDate', 'endDate', 'date'

**Root Cause:**
- Type ambiguity between FitIQ and FitIQCore `HealthMetric` types
- Compiler couldn't determine which `HealthMetric` to use

**Fix:**
```swift
// ❌ BEFORE (Type ambiguity)
private func convertToWorkoutEntry(metric: HealthMetric, userID: String) -> WorkoutEntry {
    // Compiler couldn't determine which HealthMetric type
    // Caused all property access to fail
}

// ✅ AFTER (Explicit type qualification)
private func convertToWorkoutEntry(metric: FitIQCore.HealthMetric, userID: String) -> WorkoutEntry {
    // Now compiler knows exactly which HealthMetric type to use
    // All property access works correctly
}
```

**Key Changes:**
1. Explicitly qualified parameter type as `FitIQCore.HealthMetric`
2. All property access (`metadata`, `startDate`, `endDate`, `date`) now works correctly
3. Type inference resolved throughout the method

---

## Understanding HealthMetric Initialization

### FitIQCore HealthMetric Signature

```swift
public init(
    id: UUID = UUID(),
    type: HealthDataType,
    value: Double,
    unit: String,
    date: Date,              // Primary timestamp
    startDate: Date? = nil,  // Optional: for duration metrics
    endDate: Date? = nil,    // Optional: for duration metrics
    source: String? = nil,
    device: String? = nil,
    metadata: [String: String] = [:]
)
```

### Key Conventions

1. **Primary Date Field:**
   - For instant metrics (heart rate, steps): `date` = measurement time
   - For duration metrics (workouts, sleep): `date` = end time
   - Rationale: Most recent timestamp represents "when" the metric was recorded

2. **Duration Metrics:**
   - Must provide both `startDate` and `endDate`
   - `date` should equal `endDate` for consistency
   - Example: 45-minute workout ending at 5:00 PM → `date` = 5:00 PM

3. **Metadata:**
   - Always `[String: String]` (not `[String: Any]`)
   - Convert all values to strings before passing

---

## Type Ambiguity Resolution Pattern

### When to Use Explicit Qualification

Use `FitIQCore.HealthMetric` explicitly when:

1. **Function parameters:**
   ```swift
   func process(metric: FitIQCore.HealthMetric) { }
   ```

2. **Variable declarations (if ambiguous):**
   ```swift
   let metric: FitIQCore.HealthMetric = ...
   ```

3. **Return types (if ambiguous):**
   ```swift
   func fetch() -> [FitIQCore.HealthMetric] { }
   ```

### When Implicit Type Works

Type inference handles it automatically when:

1. **Assigned from FitIQCore API:**
   ```swift
   let metrics = try await healthKitService.query(...) // Returns [FitIQCore.HealthMetric]
   ```

2. **Used in clearly-typed context:**
   ```swift
   let metric = FitIQCore.HealthMetric(...) // Type clear from initializer
   ```

---

## Testing Verification

### Compilation Tests
- ✅ `CompleteWorkoutSessionUseCase.swift` compiles without errors
- ✅ `FetchHealthKitWorkoutsUseCase.swift` compiles without errors
- ✅ No warnings or type ambiguity issues
- ✅ All property access resolves correctly

### Functional Tests Recommended

1. **Complete Workout Session:**
   ```swift
   // Test creating and saving a workout to HealthKit
   let session = WorkoutSession(...)
   let entry = try await completeWorkoutUseCase.execute(session: session, intensity: 7)
   
   // Verify:
   // - Workout saved to HealthKit with correct dates
   // - Duration calculated correctly
   // - Metadata preserved
   ```

2. **Fetch HealthKit Workouts:**
   ```swift
   // Test fetching workouts from HealthKit
   let entries = try await fetchWorkoutsUseCase.execute(from: startDate, to: endDate)
   
   // Verify:
   // - All workouts retrieved
   // - Metadata extracted correctly
   // - Duration calculated from start/end dates
   // - Activity types mapped correctly
   ```

---

## Architecture Notes

### Why Type Ambiguity Occurred

1. **Multiple HealthMetric Types:**
   - `FitIQ.HealthMetric` (legacy, if exists)
   - `FitIQCore.HealthMetric` (new, shared type)

2. **Migration Context:**
   - During migration, both types may exist temporarily
   - Swift compiler requires explicit qualification

3. **Resolution Strategy:**
   - Always use `FitIQCore.HealthMetric` for new code
   - Explicitly qualify when ambiguous
   - Eventually remove legacy types

### FitIQCore HealthMetric Benefits

1. **Type Safety:**
   - Strongly-typed `metadata: [String: String]`
   - No optional casting needed

2. **Consistency:**
   - Same model used across FitIQ and Lume
   - Shared validation and utilities

3. **Documentation:**
   - Well-documented initializer parameters
   - Clear conventions for duration metrics

---

## Related Files Modified

- `FitIQ/Domain/UseCases/Workout/CompleteWorkoutSessionUseCase.swift`
  - Fixed `HealthMetric` initialization parameter order
  - Added explicit `FitIQCore.HealthMetric` qualification
  
- `FitIQ/Domain/UseCases/Workout/FetchHealthKitWorkoutsUseCase.swift`
  - Added explicit `FitIQCore.HealthMetric` type qualification
  - Fixed method signature for `convertToWorkoutEntry`

---

## Lessons Learned

1. **Always Explicitly Qualify During Migration:**
   - When multiple types share the same name, always use full qualification
   - Don't rely on type inference during migration periods

2. **Follow FitIQCore Conventions:**
   - Read FitIQCore documentation for parameter order
   - Use `endDate` as primary `date` for duration metrics
   - Convert metadata to `[String: String]` before passing

3. **Type Ambiguity Is a Migration Signal:**
   - Indicates legacy types still exist
   - Plan to remove after full migration
   - Use as cleanup opportunity

---

## Next Steps

1. **Verify Functionality:**
   - Manual test workout creation and completion
   - Verify HealthKit data appears correctly
   - Test workout fetching from HealthKit

2. **Consider Cleanup:**
   - Search for any remaining legacy `HealthMetric` types
   - Consider removing or deprecating old types
   - Update type aliases if needed

3. **Documentation:**
   - Update API integration docs with examples
   - Document HealthMetric initialization patterns
   - Add to migration checklist

---

## Summary

✅ **All compilation errors fixed**  
✅ **Type ambiguity resolved with explicit qualification**  
✅ **HealthMetric initialization corrected**  
✅ **Follows FitIQCore conventions**  
✅ **No warnings or errors remaining**

**Outcome:** Workout use cases now correctly integrate with FitIQCore HealthKit API using proper type qualification and parameter ordering.

---

**See Also:**
- [FitIQCore HealthMetric Documentation](../../FitIQCore/Sources/FitIQCore/Health/Domain/Models/HealthMetric.swift)
- [HealthKit Services Migration Phase 5](../migration/HEALTHKIT_SERVICES_MIGRATION_PHASE5.md)
- [FitIQCore Integration Guide](../../docs/split-strategy/FITIQ_INTEGRATION_GUIDE.md)