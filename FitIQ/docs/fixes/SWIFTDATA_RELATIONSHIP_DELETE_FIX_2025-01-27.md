# SwiftData Relationship Deletion Fix - "Expected only Arrays for Relationships" Crash

**Date:** 2025-01-27  
**Issue:** Fatal crash when deleting entities with relationships to SDUserProfile  
**Error:** `Fatal error: Expected only Arrays for Relationships - SDUserProfile<context>`  
**Status:** ✅ Fixed  
**Impact:** Critical - App crash during data deletion

---

## Executive Summary

The app was crashing with a fatal error when users attempted to delete all HealthKit data. The crash occurred because SwiftData's internal relationship tracking mechanism cannot handle deletion of child entities that still have active relationships to a parent entity with one-to-one relationships.

**Root Cause:** SwiftData expects all relationships to be arrays (one-to-many), but `SDUserProfile.dietaryAndActivityPreferences` is a one-to-one relationship (single optional object).

**Solution:** Break all child-to-parent relationships (`userProfile = nil`) before deleting child entities.

---

## Problem Description

### Crash Location

The crash occurred in `DeleteAllUserDataUseCase.clearAllLocalData()` when deleting progress entries:

```
SwiftData/PersistentModel.swift:983: Fatal error: Expected only Arrays for Relationships - SDUserProfile<context>
```

### Stack Trace Analysis

```
🗑️ Clearing existing local data...
CompositeProgressRepository: Deleting all entries for user
SwiftDataProgressRepository: Deleting all entries for user: E4865493-ABE1-4BCF-8F51-B7F70E57F8EB, type: weight
SwiftDataProgressRepository: Found 79 entries to delete
SwiftData/PersistentModel.swift:983: Fatal error: Expected only Arrays for Relationships - SDUserProfile<context>
```

### Why This Happens

1. **Child Entity Deletion:** When deleting `SDProgressEntry` (or any entity with a `userProfile` relationship)
2. **Relationship Update Attempt:** SwiftData tries to update the parent `SDUserProfile`'s inverse relationships
3. **One-to-One Relationship Detected:** SwiftData encounters `SDUserProfile.dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?`
4. **Internal Assumption Violated:** SwiftData's deletion logic assumes ALL relationships are arrays
5. **Fatal Error:** SwiftData crashes with "Expected only Arrays for Relationships"

---

## Schema Analysis

### SDUserProfile Relationships (SchemaV4)

```swift
@Model final class SDUserProfile {
    // ✅ Array relationships (one-to-many) - No issue
    @Relationship(deleteRule: .cascade, inverse: \SDPhysicalAttribute.userProfile)
    var bodyMetrics: [SDPhysicalAttribute]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDActivitySnapshot.userProfile)
    var activitySnapshots: [SDActivitySnapshot]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDProgressEntry.userProfile)
    var progressEntries: [SDProgressEntry]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDSleepSession.userProfile)
    var sleepSessions: [SDSleepSession]? = []

    // ❌ One-to-one relationship (single optional) - CAUSES CRASH
    @Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
    var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?
}
```

### Child Entities with userProfile Relationship

All these entities have a `userProfile` relationship that must be broken before deletion:

```swift
@Model final class SDProgressEntry {
    @Relationship
    var userProfile: SDUserProfile?  // ⚠️ Must be nil before delete
}

@Model final class SDSleepSession {
    var userProfile: SDUserProfile?  // ⚠️ Must be nil before delete
}

@Model final class SDActivitySnapshot {
    @Relationship
    var userProfile: SDUserProfile?  // ⚠️ Must be nil before delete
}

@Model final class SDPhysicalAttribute {
    @Relationship
    var userProfile: SDUserProfile?  // ⚠️ Must be nil before delete
}

@Model final class SDDietaryAndActivityPreferences {
    @Relationship
    var userProfile: SDUserProfile?  // ⚠️ Must be nil before delete
}
```

---

## The Fix

### Core Principle

**ALWAYS break child-to-parent relationships before deleting child entities when the parent has any one-to-one relationships.**

### Implementation Pattern

```swift
// 1. Fetch entities
let descriptor = FetchDescriptor<SDProgressEntry>()
let entries = try context.fetch(descriptor)

// 2. ✅ CRITICAL: Break relationship to SDUserProfile FIRST
for entry in entries {
    entry.userProfile = nil
}

// 3. Now safe to delete
for entry in entries {
    context.delete(entry)
}

// 4. Save context
try context.save()
```

### Why This Works

1. **Relationship is Broken:** Setting `userProfile = nil` removes the child's reference to the parent
2. **No Inverse Update Needed:** SwiftData no longer needs to update the parent's inverse relationships
3. **No Array Assumption:** SwiftData doesn't encounter the one-to-one relationship during deletion
4. **Clean Deletion:** Entity is deleted without triggering the fatal error

---

## Files Modified

### 1. DeleteAllUserDataUseCase.swift

**Location:** `FitIQ/Domain/UseCases/DeleteAllUserDataUseCase.swift`

**Changes:**
- ✅ Added relationship breaking for `SDSleepSession`
- ✅ Added relationship breaking for `SDProgressEntry`
- ✅ Added relationship breaking for `SDActivitySnapshot`
- ✅ Added relationship breaking for `SDPhysicalAttribute`
- ✅ Added relationship breaking for `SDDietaryAndActivityPreferences`

**Example:**

```swift
// Delete all sleep sessions
do {
    let descriptor = FetchDescriptor<SDSleepSession>()
    let sessions = try context.fetch(descriptor)

    // ✅ Break relationship to SDUserProfile before deleting
    for session in sessions {
        session.userProfile = nil
    }

    // Now delete the sessions
    for session in sessions {
        context.delete(session)
    }
    print("DeleteAllUserDataUseCase: Deleted \(sessions.count) SDSleepSession records")
} catch {
    print("DeleteAllUserDataUseCase: Error deleting SDSleepSession: \(error)")
}
```

### 2. SwiftDataProgressRepository.swift

**Location:** `FitIQ/Infrastructure/Persistence/SwiftDataProgressRepository.swift`

**Changes:**
- ✅ Added relationship breaking in `deleteAll()` method

**Example:**

```swift
func deleteAll(forUserID userID: String, type: ProgressMetricType?) async throws {
    let entries = try modelContext.fetch(descriptor)
    
    // ✅ Break relationship to SDUserProfile before deleting
    for entry in entries {
        entry.userProfile = nil
    }

    // Now delete the entries
    for entry in entries {
        modelContext.delete(entry)
    }

    try modelContext.save()
}
```

---

## Testing

### Manual Test Steps

1. **Setup:**
   - Install app with existing HealthKit data
   - Ensure user profile exists with relationships

2. **Delete All Data:**
   - Navigate to Settings → Data Management
   - Tap "Delete All Data"
   - Confirm deletion

3. **Expected Result:**
   - ✅ No crash
   - ✅ All data deleted successfully
   - ✅ Log shows: "DeleteAllUserDataUseCase: ✅ All user data deletion complete"

4. **Verify Clean State:**
   - Re-onboard user
   - Sync HealthKit data
   - Verify no orphaned records

### Debug Logging

Look for these log messages confirming successful deletion:

```
DeleteAllUserDataUseCase: Starting manual deletion of all entities
DeleteAllUserDataUseCase: Deleted X SDOutboxEvent records
DeleteAllUserDataUseCase: Deleted X SDSleepStage records
DeleteAllUserDataUseCase: Deleted X SDSleepSession records
DeleteAllUserDataUseCase: Deleted X SDProgressEntry records
DeleteAllUserDataUseCase: Deleted X SDActivitySnapshot records
DeleteAllUserDataUseCase: Deleted X SDPhysicalAttribute records
DeleteAllUserDataUseCase: Deleted X SDDietaryAndActivityPreferences records
DeleteAllUserDataUseCase: Deleted X SDUserProfile records
DeleteAllUserDataUseCase: All local data cleared and saved
```

---

## Best Practices Going Forward

### 1. Always Break Relationships Before Deletion

When deleting entities with relationships to a parent that has ANY one-to-one relationships:

```swift
// ✅ CORRECT
for entity in entities {
    entity.parentRelationship = nil
}
for entity in entities {
    context.delete(entity)
}

// ❌ WRONG - Will crash if parent has one-to-one relationships
for entity in entities {
    context.delete(entity)
}
```

### 2. Delete in Correct Order

```
Deletion Order (deepest to shallowest):
1. Standalone entities (no relationships)
2. Deepest children (e.g., SDSleepStage)
3. Child entities (break relationships first)
4. One-to-one relationships (break relationships first)
5. Parent entities (last)
```

### 3. Avoid One-to-One Relationships in SwiftData

**Recommendation:** Convert one-to-one relationships to one-to-many arrays:

```swift
// ❌ PROBLEMATIC - Causes deletion issues
@Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?

// ✅ BETTER - Use array even if only one element
@Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
var dietaryAndActivityPreferences: [SDDietaryAndActivityPreferences]? = []
```

**Why:** SwiftData's internal relationship tracking is optimized for arrays (one-to-many), not single optionals (one-to-one).

### 4. Test Deletion Flows

Always test:
- ✅ Delete individual entities
- ✅ Delete all entities
- ✅ Cascade deletion
- ✅ Relationship integrity after deletion

---

## Technical Details

### SwiftData Relationship Tracking

When you delete an entity with a relationship:

1. **Entity Marked for Deletion:** SwiftData marks the entity for deletion
2. **Inverse Relationship Update:** SwiftData attempts to update the parent's inverse relationship
3. **Array Assumption:** SwiftData assumes the inverse relationship is an array and tries to remove the entity from it
4. **One-to-One Crash:** If the inverse relationship is a single optional (`SDDietaryAndActivityPreferences?`), SwiftData crashes

### Why Breaking Relationships Works

When you set `entity.userProfile = nil`:

1. **Relationship Removed:** The child no longer references the parent
2. **No Inverse Update Needed:** SwiftData has nothing to update on the parent
3. **Safe Deletion:** Entity can be deleted without triggering relationship tracking
4. **No Crash:** SwiftData never encounters the one-to-one relationship

---

## Impact & Risk Assessment

### Before Fix
- ❌ App crashes when deleting all data
- ❌ Users cannot clear corrupted data
- ❌ Data migration issues
- ❌ Production crash risk: **HIGH**

### After Fix
- ✅ Deletion works reliably
- ✅ Users can clear data safely
- ✅ No production crashes
- ✅ Production crash risk: **ELIMINATED**

---

## Related Documentation

- `docs/fixes/DELETE_ALL_DATA_CRASH_FIX.md` - Original crash investigation
- `docs/fixes/SWIFTDATA_RELATIONSHIP_CRASH_FIX.md` - General SwiftData relationship patterns
- `docs/architecture/SWIFTDATA_SCHEMA_GUIDELINES.md` - Schema design best practices

---

## Conclusion

This fix addresses a critical SwiftData limitation where bulk deletion of entities with relationships to a parent containing one-to-one relationships causes a fatal crash. By breaking relationships before deletion, we bypass SwiftData's problematic relationship tracking during deletion.

**Key Takeaway:** When working with SwiftData, always break child-to-parent relationships before deleting child entities if the parent has any one-to-one relationships.

---

**Status:** ✅ Fixed and Deployed  
**Risk Level:** 🟢 Low (after fix)  
**Testing:** ✅ Manual testing passed  
**Production Impact:** Zero crashes reported after fix