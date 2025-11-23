# CloudKit Compatibility Fix

**Date:** 2025-01-XX  
**Issue:** SwiftData store failing to load due to CloudKit integration requirements  
**Status:** ✅ Fixed

---

## Problem

The app was crashing on launch with the following error:

```
CoreData: error: Store failed to load.
Error Domain=NSCocoaErrorDomain Code=134060 "A Core Data error occurred."
UserInfo={NSLocalizedFailureReason=CloudKit integration requires that all relationships have an inverse, 
the following do not:
SDUserProfileV9: moodEntries
SDUserProfileV9: photoRecognitions
CloudKit integration requires that all relationships be optional, the following are not:
SDUserProfileV10: activitySnapshots
SDUserProfileV10: bodyMetrics
SDUserProfileV10: mealLogs
SDUserProfileV10: moodEntries
SDUserProfileV10: photoRecognitions
SDUserProfileV10: progressEntries
SDUserProfileV10: sleepSessions
SDUserProfileV10: workouts
CloudKit integration does not support unique constraints. The following entities are constrained:
SDUserProfileV10: id}
```

---

## Root Cause

The ModelContainer was configured with CloudKit integration enabled (`.automatic`), but the schema violated CloudKit's strict requirements:

1. **Missing Inverse Relationships** - CloudKit requires all relationships to have inverse relationships defined
2. **Non-Optional Relationships** - CloudKit requires all relationships to be optional (arrays must be `[Type]?` not `[Type]`)
3. **Unique Constraints** - CloudKit does not support `@Attribute(.unique)` on properties

---

## Fix Applied

### 1. SchemaV9 - Added Inverse Relationships

**File:** `FitIQ/Infrastructure/Persistence/Schema/SchemaV9.swift`

```swift
// BEFORE
@Model final class SDMoodEntry {
    @Relationship
    var userProfile: SDUserProfileV9?
    // ...
}

@Model final class SDUserProfileV9 {
    @Relationship(deleteRule: .cascade)
    var moodEntries: [SDMoodEntry]?
    // ...
}

// AFTER
@Model final class SDMoodEntry {
    @Relationship(inverse: \SDUserProfileV9.moodEntries)
    var userProfile: SDUserProfileV9?
    // ...
}

@Model final class SDUserProfileV9 {
    @Relationship(deleteRule: .cascade, inverse: \SDMoodEntry.userProfile)
    var moodEntries: [SDMoodEntry]?
    // ...
}
```

### 2. SchemaV10 - Made All Relationships Optional

**File:** `FitIQ/Infrastructure/Persistence/Schema/SchemaV10.swift`

```swift
// BEFORE
@Model final class SDUserProfileV10 {
    @Relationship(deleteRule: .cascade, inverse: \SDPhysicalAttribute.userProfile)
    var bodyMetrics: [SDPhysicalAttribute] = []  // ❌ Non-optional array
    
    @Relationship(deleteRule: .cascade, inverse: \SDMeal.userProfile)
    var mealLogs: [SDMeal] = []  // ❌ Non-optional array
    // ... more non-optional arrays
}

// AFTER
@Model final class SDUserProfileV10 {
    @Relationship(deleteRule: .cascade, inverse: \SDPhysicalAttribute.userProfile)
    var bodyMetrics: [SDPhysicalAttribute]? = []  // ✅ Optional array
    
    @Relationship(deleteRule: .cascade, inverse: \SDMeal.userProfile)
    var mealLogs: [SDMeal]? = []  // ✅ Optional array
    // ... all arrays now optional
}
```

### 3. SchemaV10 - Removed Unique Constraint

```swift
// BEFORE
@Model final class SDUserProfileV10 {
    @Attribute(.unique) var id: UUID = UUID()  // ❌ CloudKit doesn't support unique constraints
    // ...
}

// AFTER
@Model final class SDUserProfileV10 {
    var id: UUID = UUID()  // ✅ Removed .unique attribute
    // ...
}
```

### 4. Updated Code to Handle Optional Arrays

**File:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift`

```swift
// BEFORE
let existingHeightMetrics = sdProfile.bodyMetrics.filter { $0.type == .height }
sdProfile.bodyMetrics.append(heightMetric)

// AFTER
let existingHeightMetrics = (sdProfile.bodyMetrics ?? []).filter { $0.type == .height }
if sdProfile.bodyMetrics == nil {
    sdProfile.bodyMetrics = []
}
sdProfile.bodyMetrics?.append(heightMetric)
```

---

## Impact

### ✅ Benefits
- App no longer crashes on launch
- CloudKit sync enabled (automatic iCloud backup)
- Schema is now CloudKit-compliant
- Data is preserved during migration

### ⚠️ Considerations
- All code accessing relationship arrays must now handle optionals
- Use `sdProfile.bodyMetrics ?? []` pattern when iterating
- Check for `nil` before appending to relationship arrays

---

## Alternative: Disable CloudKit

If CloudKit integration is not needed, you can disable it in `AppDependencies.swift`:

```swift
// In buildModelContainer() method
let modelConfiguration = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .none  // ✅ Disable CloudKit
)
```

**Trade-offs:**
- ✅ Relationships can be non-optional (`[Type]` instead of `[Type]?`)
- ✅ Unique constraints are allowed
- ✅ Simpler code (no optional handling)
- ❌ No automatic iCloud sync
- ❌ No cross-device data sync

---

## Testing

1. ✅ Clean build succeeds
2. ✅ App launches without crash
3. ✅ SwiftData store loads successfully
4. ✅ No compiler errors or warnings
5. ✅ Existing data migration works

---

## Related Files Changed

1. `FitIQ/Infrastructure/Persistence/Schema/SchemaV9.swift` - Added inverse relationships
2. `FitIQ/Infrastructure/Persistence/Schema/SchemaV10.swift` - Made relationships optional, removed unique constraint
3. `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift` - Handle optional arrays

---

## Additional Notes

### Why CloudKit Has These Requirements

1. **Inverse Relationships** - CloudKit needs to maintain referential integrity across distributed databases
2. **Optional Relationships** - CloudKit's eventual consistency model requires all relationships to handle nil states during sync conflicts
3. **No Unique Constraints** - CloudKit uses its own record ID system and doesn't support custom uniqueness constraints

### Best Practices Going Forward

1. **Always add inverse relationships** when defining `@Relationship` in SwiftData models
2. **Use optional arrays** (`[Type]?`) for all relationships when CloudKit is enabled
3. **Avoid `@Attribute(.unique)`** when CloudKit integration is enabled
4. **Handle nil arrays** with nil-coalescing operator (`??`) when accessing relationships

---

## References

- Apple Developer: [Syncing a Core Data Store with CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
- SwiftData: [Model Relationships](https://developer.apple.com/documentation/swiftdata/relationships)
- CloudKit: [Design Best Practices](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitQuickStart/DesigningYourCloudKitApp/DesigningYourCloudKitApp.html)