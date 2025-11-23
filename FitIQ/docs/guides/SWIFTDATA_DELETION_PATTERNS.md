# SwiftData Deletion Patterns - Quick Reference Guide

**Purpose:** Safe deletion patterns for SwiftData entities with relationships  
**Date:** 2025-01-27  
**Status:** ✅ Active

---

## 🚨 Critical Rule

**ALWAYS break child-to-parent relationships before deleting child entities when the parent has ANY one-to-one relationships.**

---

## Quick Pattern Reference

### ✅ SAFE: Delete with Relationship Breaking

```swift
// 1. Fetch entities
let descriptor = FetchDescriptor<SDProgressEntry>()
let entries = try context.fetch(descriptor)

// 2. Break relationships FIRST
for entry in entries {
    entry.userProfile = nil
}

// 3. Delete entities
for entry in entries {
    context.delete(entry)
}

// 4. Save
try context.save()
```

### ❌ UNSAFE: Direct Deletion

```swift
// ❌ Will crash if parent has one-to-one relationships
let descriptor = FetchDescriptor<SDProgressEntry>()
let entries = try context.fetch(descriptor)
for entry in entries {
    context.delete(entry)  // CRASH HERE
}
try context.save()
```

### ❌ UNSAFE: Bulk Delete

```swift
// ❌ NEVER use bulk delete with entities that have relationships
try context.delete(model: SDProgressEntry.self)  // CRASH
```

---

## FitIQ Entity Deletion Patterns

### Entities Requiring Relationship Breaking

All these entities have a `userProfile` relationship that MUST be nil before deletion:

```swift
// SDProgressEntry
for entry in entries {
    entry.userProfile = nil  // ✅ Required
}

// SDSleepSession
for session in sessions {
    session.userProfile = nil  // ✅ Required
}

// SDActivitySnapshot
for snapshot in snapshots {
    snapshot.userProfile = nil  // ✅ Required
}

// SDPhysicalAttribute
for attribute in attributes {
    attribute.userProfile = nil  // ✅ Required
}

// SDDietaryAndActivityPreferences
for pref in preferences {
    pref.userProfile = nil  // ✅ Required
}
```

### Entities Safe to Delete Directly

These entities have no relationships or only child relationships:

```swift
// SDSleepStage (child of SDSleepSession, no userProfile)
for stage in stages {
    context.delete(stage)  // ✅ Safe
}

// SDOutboxEvent (standalone, no relationships)
for event in events {
    context.delete(event)  // ✅ Safe
}
```

---

## Deletion Order

### Correct Order (Deepest to Shallowest)

```
1. Standalone entities (SDOutboxEvent)
   ↓
2. Deepest children (SDSleepStage)
   ↓
3. Child entities with BROKEN relationships
   - SDSleepSession (set userProfile = nil first)
   - SDProgressEntry (set userProfile = nil first)
   - SDActivitySnapshot (set userProfile = nil first)
   - SDPhysicalAttribute (set userProfile = nil first)
   ↓
4. One-to-one relationships with BROKEN links
   - SDDietaryAndActivityPreferences (set userProfile = nil first)
   ↓
5. Parent entity (SDUserProfile - last)
```

---

## Complete Deletion Template

```swift
func deleteAllUserData(context: ModelContext) throws {
    // 1. Standalone entities
    let outboxDescriptor = FetchDescriptor<SDOutboxEvent>()
    let events = try context.fetch(outboxDescriptor)
    for event in events {
        context.delete(event)
    }
    
    // 2. Deepest children
    let stageDescriptor = FetchDescriptor<SDSleepStage>()
    let stages = try context.fetch(stageDescriptor)
    for stage in stages {
        context.delete(stage)
    }
    
    // 3. Child entities (break relationships first)
    let sessionDescriptor = FetchDescriptor<SDSleepSession>()
    let sessions = try context.fetch(sessionDescriptor)
    for session in sessions {
        session.userProfile = nil  // ✅ Break relationship
    }
    for session in sessions {
        context.delete(session)
    }
    
    let progressDescriptor = FetchDescriptor<SDProgressEntry>()
    let entries = try context.fetch(progressDescriptor)
    for entry in entries {
        entry.userProfile = nil  // ✅ Break relationship
    }
    for entry in entries {
        context.delete(entry)
    }
    
    let snapshotDescriptor = FetchDescriptor<SDActivitySnapshot>()
    let snapshots = try context.fetch(snapshotDescriptor)
    for snapshot in snapshots {
        snapshot.userProfile = nil  // ✅ Break relationship
    }
    for snapshot in snapshots {
        context.delete(snapshot)
    }
    
    let attributeDescriptor = FetchDescriptor<SDPhysicalAttribute>()
    let attributes = try context.fetch(attributeDescriptor)
    for attribute in attributes {
        attribute.userProfile = nil  // ✅ Break relationship
    }
    for attribute in attributes {
        context.delete(attribute)
    }
    
    // 4. One-to-one relationships (break relationships first)
    let preferencesDescriptor = FetchDescriptor<SDDietaryAndActivityPreferences>()
    let preferences = try context.fetch(preferencesDescriptor)
    for pref in preferences {
        pref.userProfile = nil  // ✅ Break relationship
    }
    for pref in preferences {
        context.delete(pref)
    }
    
    // 5. Parent entity (last)
    let profileDescriptor = FetchDescriptor<SDUserProfile>()
    let profiles = try context.fetch(profileDescriptor)
    for profile in profiles {
        context.delete(profile)
    }
    
    // 6. Save all changes
    try context.save()
}
```

---

## Why This Is Necessary

### The Problem

SwiftData has an internal limitation:

1. When you delete an entity with a relationship, SwiftData tries to update the parent's inverse relationship
2. SwiftData assumes ALL relationships are arrays (`[Entity]?`)
3. If the parent has a one-to-one relationship (`Entity?`), SwiftData crashes
4. Error: `Fatal error: Expected only Arrays for Relationships - SDUserProfile`

### The Solution

Breaking relationships (`entity.userProfile = nil`) before deletion:

1. Removes the child's reference to the parent
2. Prevents SwiftData from attempting inverse relationship updates
3. Bypasses the array assumption check
4. Allows safe deletion without crashes

---

## Schema Design Recommendations

### ❌ Avoid One-to-One Relationships

```swift
// ❌ PROBLEMATIC - Causes deletion issues
@Relationship(deleteRule: .cascade, inverse: \Child.parent)
var child: Child?
```

### ✅ Use One-to-Many Arrays Instead

```swift
// ✅ RECOMMENDED - Works with SwiftData deletion
@Relationship(deleteRule: .cascade, inverse: \Child.parent)
var children: [Child]? = []

// Even if you only have one child, use an array
// Access: profile.children?.first
```

**Why:** SwiftData's relationship tracking is optimized for arrays, not single optionals.

---

## Repository Pattern

### Safe Repository Delete Method

```swift
func deleteAll(forUserID userID: String) async throws {
    let descriptor = FetchDescriptor<SDProgressEntry>(
        predicate: #Predicate { $0.userID == userID }
    )
    
    let entries = try modelContext.fetch(descriptor)
    
    // ✅ CRITICAL: Break relationships before deleting
    for entry in entries {
        entry.userProfile = nil
    }
    
    // Now safe to delete
    for entry in entries {
        modelContext.delete(entry)
    }
    
    try modelContext.save()
}
```

---

## Testing Checklist

When implementing deletion:

- [ ] Break all child-to-parent relationships before deletion
- [ ] Delete in correct order (children before parents)
- [ ] Test deletion with multiple entities
- [ ] Test deletion with no entities
- [ ] Test cascade deletion behavior
- [ ] Verify no orphaned records remain
- [ ] Check logs for successful deletion messages
- [ ] Test re-onboarding after deletion

---

## Common Mistakes

### ❌ Mistake 1: Using Bulk Delete

```swift
// ❌ WRONG - Crashes on one-to-one relationships
try context.delete(model: SDUserProfile.self)
```

**Fix:**
```swift
// ✅ CORRECT - Manual fetch-and-delete
let descriptor = FetchDescriptor<SDUserProfile>()
let profiles = try context.fetch(descriptor)
for profile in profiles {
    context.delete(profile)
}
```

### ❌ Mistake 2: Forgetting to Break Relationships

```swift
// ❌ WRONG - Crashes if parent has one-to-one relationships
let entries = try context.fetch(descriptor)
for entry in entries {
    context.delete(entry)  // CRASH
}
```

**Fix:**
```swift
// ✅ CORRECT - Break relationships first
let entries = try context.fetch(descriptor)
for entry in entries {
    entry.userProfile = nil  // Break relationship
}
for entry in entries {
    context.delete(entry)  // Safe
}
```

### ❌ Mistake 3: Wrong Deletion Order

```swift
// ❌ WRONG - Parent before children
context.delete(userProfile)  // Cascade may fail
context.delete(progressEntry)  // Already deleted by cascade?
```

**Fix:**
```swift
// ✅ CORRECT - Children before parent
for entry in entries {
    entry.userProfile = nil
    context.delete(entry)
}
context.delete(userProfile)  // Last
```

---

## Quick Diagnostic

### Is Your Deletion Safe?

Ask yourself:

1. **Does the entity have a relationship to a parent?**
   - Yes → Break relationship first
   - No → Safe to delete directly

2. **Does the parent have ANY one-to-one relationships?**
   - Yes → MUST break relationship first
   - No → Probably safe, but break relationships anyway for consistency

3. **Are you using bulk delete (`context.delete(model:)`)?**
   - Yes → Change to manual fetch-and-delete
   - No → Good

4. **Are you deleting in correct order (children before parents)?**
   - Yes → Good
   - No → Reorder deletions

---

## Related Documentation

- `docs/fixes/SWIFTDATA_RELATIONSHIP_DELETE_FIX_2025-01-27.md` - Detailed fix explanation
- `docs/fixes/DELETE_ALL_DATA_CRASH_FIX.md` - Original crash investigation
- `docs/architecture/SWIFTDATA_SCHEMA_GUIDELINES.md` - Schema design best practices

---

## Summary

### The Golden Rule

**Break relationships before deletion when the parent has one-to-one relationships.**

### The Safe Pattern

```swift
// 1. Fetch
let entities = try context.fetch(descriptor)

// 2. Break relationships
for entity in entities {
    entity.parentRelationship = nil
}

// 3. Delete
for entity in entities {
    context.delete(entity)
}

// 4. Save
try context.save()
```

### Remember

- ❌ Never use bulk delete with relationships
- ❌ Never delete entities with active parent relationships
- ✅ Always break relationships first
- ✅ Always delete children before parents
- ✅ Always test deletion flows

---

**Status:** ✅ Active  
**Last Updated:** 2025-01-27  
**Maintainer:** iOS Team