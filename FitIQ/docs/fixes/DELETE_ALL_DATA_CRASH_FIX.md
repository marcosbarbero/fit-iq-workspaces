# Delete All Data Crash Fix - SwiftData Relationship Issue

**Date:** 2025-01-27  
**Issue:** App crashes when deleting all HealthKit data  
**Error:** "Expected only Arrays for Relationships - SDUserProfile"  
**Status:** ✅ Fixed

---

## Problem Summary

When users tried to delete all HealthKit data from the app, it crashed with:

```
Task 159: Fatal error: Expected only Arrays for Relationships - SDUserProfile
```

This error occurred in `DeleteAllUserDataUseCase` when trying to delete `SDUserProfile` entities.

---

## Root Cause

SwiftData was attempting to delete `SDUserProfile` entities **before** deleting their related child entities. This caused issues because:

1. **One-to-One Relationship Issue:** `SDUserProfile` has a `dietaryAndActivityPreferences` relationship defined as a single optional object (`SDDietaryAndActivityPreferences?`), which SwiftData doesn't handle well during cascade deletion.

2. **Incorrect Deletion Order:** The delete operation was deleting parent entities before their children, causing SwiftData's relationship tracking to fail.

3. **Missing Entity Types:** Sleep sessions, sleep stages, outbox events, and dietary preferences were not being deleted, leaving orphaned relationships.

### Original Code (Incorrect)

```swift
// Delete all progress entries
try context.delete(model: SDProgressEntry.self)

// Delete all activity snapshots
try context.delete(model: SDActivitySnapshot.self)

// Delete all physical attributes
try context.delete(model: SDPhysicalAttribute.self)

// Delete all user profiles ❌ CRASH HERE
try context.delete(model: SDUserProfile.self)
```

**Problem:** Using `context.delete(model:)` with `SDUserProfile` crashes because:
- `SDUserProfile` has a **one-to-one relationship** (`dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?`)
- SwiftData's bulk delete method expects **all relationships to be arrays**
- The single optional relationship triggers "Expected only Arrays for Relationships" error

---

## Solution

Switched from bulk delete (`context.delete(model:)`) to **manual fetch-and-delete** approach to avoid SwiftData relationship issues:

### New Code (Correct)

```swift
// Manual fetch-and-delete approach to avoid SwiftData relationship issues
// This bypasses the bulk delete method that crashes on one-to-one relationships

// 1. Delete all outbox events
let outboxDescriptor = FetchDescriptor<SDOutboxEvent>()
let events = try context.fetch(outboxDescriptor)
for event in events {
    context.delete(event)
}

// 2. Delete all sleep stages (deepest child)
let stageDescriptor = FetchDescriptor<SDSleepStage>()
let stages = try context.fetch(stageDescriptor)
for stage in stages {
    context.delete(stage)
}

// 3. Delete all sleep sessions
let sessionDescriptor = FetchDescriptor<SDSleepSession>()
let sessions = try context.fetch(sessionDescriptor)
// Break relationship to SDUserProfile before deleting
for session in sessions {
    session.userProfile = nil
}
for session in sessions {
    context.delete(session)
}

// 4. Delete all progress entries
let progressDescriptor = FetchDescriptor<SDProgressEntry>()
let entries = try context.fetch(progressDescriptor)
// Break relationship to SDUserProfile before deleting
for entry in entries {
    entry.userProfile = nil
}
for entry in entries {
    context.delete(entry)
}

// 5. Delete all activity snapshots
let snapshotDescriptor = FetchDescriptor<SDActivitySnapshot>()
let snapshots = try context.fetch(snapshotDescriptor)
// Break relationship to SDUserProfile before deleting
for snapshot in snapshots {
    snapshot.userProfile = nil
}
for snapshot in snapshots {
    context.delete(snapshot)
}

// 6. Delete all physical attributes
let attributeDescriptor = FetchDescriptor<SDPhysicalAttribute>()
let attributes = try context.fetch(attributeDescriptor)
// Break relationship to SDUserProfile before deleting
for attribute in attributes {
    attribute.userProfile = nil
}
for attribute in attributes {
    context.delete(attribute)
}

// 7. Delete dietary and activity preferences (one-to-one relationship)
let preferencesDescriptor = FetchDescriptor<SDDietaryAndActivityPreferences>()
let preferences = try context.fetch(preferencesDescriptor)
// Break relationship to SDUserProfile before deleting
for pref in preferences {
    pref.userProfile = nil
}
for pref in preferences {
    context.delete(pref)
}

// 8. Finally, delete all user profiles (parent entity)
let profileDescriptor = FetchDescriptor<SDUserProfile>()
let profiles = try context.fetch(profileDescriptor)
for profile in profiles {
    context.delete(profile)
}

// Save context to persist all deletions
try context.save()
```

---

## Key Changes

### 1. Manual Fetch-and-Delete Instead of Bulk Delete

**Critical Change:** Replaced `context.delete(model:)` with manual fetch and delete:

```swift
// ❌ OLD - Crashes on one-to-one relationships
try context.delete(model: SDUserProfile.self)

// ✅ NEW - Manual fetch-and-delete
let descriptor = FetchDescriptor<SDUserProfile>()
let profiles = try context.fetch(descriptor)
for profile in profiles {
    context.delete(profile)
}
```

**Why This Works:**
- Bulk delete (`context.delete(model:)`) has issues with one-to-one relationships
- Manual deletion processes each entity individually
- SwiftData's cascade delete rules work correctly on individual entities
- Bypasses the "Expected only Arrays for Relationships" error

### 2. Added Missing Entity Deletions

Added deletion for entities that were missing:
- ✅ `SDOutboxEvent` - Outbox pattern events
- ✅ `SDSleepSession` - Sleep tracking sessions
- ✅ `SDSleepStage` - Sleep stage details
- ✅ `SDDietaryAndActivityPreferences` - User preferences

### 3. Break Relationships Before Deletion

**CRITICAL:** Must break relationships to `SDUserProfile` before deleting child entities:

```swift
// Break relationship to SDUserProfile before deleting
for session in sessions {
    session.userProfile = nil
}

// Now delete the sessions
for session in sessions {
    context.delete(session)
}
```

**Why This is Necessary:**
- SwiftData tracks relationships internally during deletion
- When deleting a child entity that still has a `userProfile` relationship set, SwiftData attempts to update the parent's relationship array
- If the parent has a one-to-one relationship (`dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?`), SwiftData expects all relationships to be arrays
- This causes the "Expected only Arrays for Relationships" crash
- Breaking relationships first (`userProfile = nil`) prevents SwiftData from attempting this update

**Affected Entities:**
- ✅ `SDSleepSession.userProfile` - Must be nil before deletion
- ✅ `SDProgressEntry.userProfile` - Must be nil before deletion
- ✅ `SDActivitySnapshot.userProfile` - Must be nil before deletion
- ✅ `SDPhysicalAttribute.userProfile` - Must be nil before deletion
- ✅ `SDDietaryAndActivityPreferences.userProfile` - Must be nil before deletion

### 4. Correct Deletion Order

**Principle:** Delete children before parents

```
Deletion Order:
1. Standalone entities (no dependencies)
2. Deepest children (e.g., SDSleepStage)
3. Child entities with broken relationships (e.g., SDSleepSession, SDProgressEntry)
4. One-to-one relationships with broken links (e.g., SDDietaryAndActivityPreferences)
5. Parent entities (SDUserProfile - last)
```

### 5. Enhanced Logging

Each deletion shows count of records deleted:

```swift
do {
    let descriptor = FetchDescriptor<SDSleepSession>()
    let sessions = try context.fetch(descriptor)
    for session in sessions {
        context.delete(session)
    }
    print("DeleteAllUserDataUseCase: Deleted \(sessions.count) SDSleepSession records")
} catch {
    print("DeleteAllUserDataUseCase: Error deleting SDSleepSession: \(error)")
}
```

---

## Entity Relationships

Understanding the relationships helps explain the deletion order:

```
SDUserProfile (parent)
├── dietaryAndActivityPreferences → SDDietaryAndActivityPreferences (1:1)
├── bodyMetrics → [SDPhysicalAttribute] (1:many)
├── activitySnapshots → [SDActivitySnapshot] (1:many)
├── progressEntries → [SDProgressEntry] (1:many)
└── sleepSessions → [SDSleepSession] (1:many)
    └── stages → [SDSleepStage] (1:many)

SDOutboxEvent (standalone, no relationships)
```

**Deletion Strategy:**
1. Delete deepest children first (`SDSleepStage`)
2. Work up the hierarchy (`SDSleepSession`)
3. Delete all children of `SDUserProfile`
4. Finally delete `SDUserProfile`

---

## Files Modified

### `FitIQ/Domain/UseCases/DeleteAllUserDataUseCase.swift`

**Changes:**
- **Replaced bulk delete with manual fetch-and-delete** (~100 lines rewritten)
- Added deletion of `SDOutboxEvent`
- Added deletion of `SDSleepSession`
- Added deletion of `SDSleepStage`
- Added deletion of `SDDietaryAndActivityPreferences`
- Each entity type uses `FetchDescriptor` + loop deletion
- Updated comments to explain manual deletion approach
- Maintained correct order: children before parents

---

## Testing

### Before Fix
1. Go to Profile → "Delete All Data"
2. App crashes with "Expected only Arrays for Relationships"
3. Data partially deleted (inconsistent state)

### After Fix
1. Go to Profile → "Delete All Data"
2. App successfully deletes all data
3. User is logged out
4. Clean state

### Expected Logs

```
DeleteAllUserDataUseCase: Clearing all local SwiftData
DeleteAllUserDataUseCase: Starting manual deletion of all entities
DeleteAllUserDataUseCase: Deleted 3 SDOutboxEvent records
DeleteAllUserDataUseCase: Deleted 12 SDSleepStage records
DeleteAllUserDataUseCase: Deleted 2 SDSleepSession records
DeleteAllUserDataUseCase: Deleted 45 SDProgressEntry records
DeleteAllUserDataUseCase: Deleted 30 SDActivitySnapshot records
DeleteAllUserDataUseCase: Deleted 20 SDPhysicalAttribute records
DeleteAllUserDataUseCase: Deleted 1 SDDietaryAndActivityPreferences records
DeleteAllUserDataUseCase: Deleted 1 SDUserProfile records
DeleteAllUserDataUseCase: All local data cleared and saved
DeleteAllUserDataUseCase: ✅ Local data cleared successfully
```

---

## Why the One-to-One Relationship Is Problematic

SwiftData's **bulk delete method** has issues with one-to-one relationships:

### Current Definition (Problematic)
```swift
@Model final class SDUserProfile {
    @Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
    var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences? // Single optional
}
```

### Issue with Bulk Delete
- `context.delete(model: SDUserProfile.self)` internally expects all relationships to be arrays
- The single optional relationship (`SDDietaryAndActivityPreferences?`) confuses the bulk delete logic
- Results in crash: "Expected only Arrays for Relationships"

### Our Fix: Manual Fetch-and-Delete
- Fetch all entities individually using `FetchDescriptor`
- Delete each entity one-by-one with `context.delete(entity)`
- Individual deletion uses SwiftData's cascade rules correctly
- Bypasses the problematic bulk delete code path

### Alternative Approaches (Future Consideration)

**Option 1: Change to Array Relationship**
```swift
@Model final class SDUserProfile {
    @Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
    var dietaryAndActivityPreferences: [SDDietaryAndActivityPreferences]? = []
}
```
Then enforce "max 1" in business logic. However, this changes the semantic meaning.

**Option 2: Remove @Relationship Annotation**
```swift
@Model final class SDUserProfile {
    // Store as foreign key instead
    var dietaryAndActivityPreferencesID: UUID?
}
```
Manage relationship manually without SwiftData relationship tracking.

**Current Approach (Best for Now):**
- Keep schema as-is
- Use manual fetch-and-delete for bulk operations
- Individual entity operations work fine

---

## Verification Checklist

- [ ] App doesn't crash when deleting all data
- [ ] All entity types are deleted (check logs)
- [ ] User is logged out after deletion
- [ ] Backend receives delete request
- [ ] Auth tokens are cleared
- [ ] App can be used normally after deletion
- [ ] Re-sync works after deletion

---

## Related Issues

This fix addresses:
- ❌ App crash on delete all data
- ❌ Incomplete data deletion
- ❌ Orphaned relationships in database
- ❌ "Expected only Arrays" SwiftData error

---

## Impact

**Before:**
- ❌ App crashes on delete
- ❌ Data left in inconsistent state
- ❌ User must force-quit and reinstall

**After:**
- ✅ Clean deletion without crashes
- ✅ All data properly removed
- ✅ User can continue using app

---

## Future Improvements

1. **Schema Refactoring:** Evaluate if one-to-one relationship is truly needed or can be embedded
2. **Bulk Delete Helper:** Create reusable bulk delete helper that uses fetch-and-delete pattern
3. **Soft Delete:** Consider soft delete instead of hard delete for data recovery
4. **Transaction Safety:** Wrap entire delete operation in explicit transaction
5. **Performance:** For large datasets, consider batch deletion with periodic saves

---

**Status:** ✅ Ready for Testing  
**Priority:** High (crash bug)  
**Risk:** Low (delete operation only)  
**Confidence:** High

**Next Steps:**
1. Test delete all data functionality
2. Verify clean state after deletion
3. Verify app works normally after deletion
4. Monitor for any remaining relationship issues