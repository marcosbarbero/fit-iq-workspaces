# SwiftData Deletion Quick Reference Card

**⚠️ CRITICAL: Always break relationships before deleting entities with parent relationships**

---

## 🚨 The Golden Rule

```swift
// ❌ NEVER DO THIS - Will crash if parent has one-to-one relationships
for entity in entities {
    context.delete(entity)
}

// ✅ ALWAYS DO THIS - Break relationships FIRST
for entity in entities {
    entity.userProfile = nil  // Break relationship
}
for entity in entities {
    context.delete(entity)    // Now safe to delete
}
```

---

## 📋 Quick Checklist

Before deleting any entity:

- [ ] Does entity have a `userProfile` relationship?
- [ ] If YES → Set `entity.userProfile = nil` BEFORE deleting
- [ ] Never use `context.delete(model: Type.self)` with relationships
- [ ] Delete children before parents
- [ ] Always call `context.save()` after deletions

---

## 🔧 Safe Deletion Template

```swift
func deleteAllEntities(context: ModelContext) throws {
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
    
    // 4. Save changes
    try context.save()
}
```

---

## 🎯 FitIQ Entities - Quick Lookup

| Entity | Break Relationship? | Code |
|--------|-------------------|------|
| `SDProgressEntry` | ✅ YES | `entry.userProfile = nil` |
| `SDSleepSession` | ✅ YES | `session.userProfile = nil` |
| `SDActivitySnapshot` | ✅ YES | `snapshot.userProfile = nil` |
| `SDPhysicalAttribute` | ✅ YES | `attribute.userProfile = nil` |
| `SDDietaryAndActivityPreferences` | ✅ YES | `pref.userProfile = nil` |
| `SDSleepStage` | ❌ NO | Just delete |
| `SDOutboxEvent` | ❌ NO | Just delete |

---

## 📦 Deletion Order

```
1. SDOutboxEvent (standalone)
   ↓
2. SDSleepStage (child of SDSleepSession)
   ↓
3. SDSleepSession (break userProfile first)
   ↓
4. SDProgressEntry (break userProfile first)
   ↓
5. SDActivitySnapshot (break userProfile first)
   ↓
6. SDPhysicalAttribute (break userProfile first)
   ↓
7. SDDietaryAndActivityPreferences (break userProfile first)
   ↓
8. SDUserProfile (last - parent entity)
```

---

## ❌ Common Mistakes

### Mistake 1: Bulk Delete
```swift
// ❌ WRONG
try context.delete(model: SDProgressEntry.self)
```

### Mistake 2: Forgetting to Break Relationships
```swift
// ❌ WRONG
for entry in entries {
    context.delete(entry)  // CRASH!
}
```

### Mistake 3: Wrong Order
```swift
// ❌ WRONG - Parent before children
context.delete(userProfile)
context.delete(progressEntry)
```

---

## ✅ Correct Patterns

### Pattern 1: Delete Single Entity
```swift
let entry: SDProgressEntry = // ...
entry.userProfile = nil
context.delete(entry)
try context.save()
```

### Pattern 2: Delete Multiple Entities
```swift
let entries = try context.fetch(descriptor)
for entry in entries {
    entry.userProfile = nil
}
for entry in entries {
    context.delete(entry)
}
try context.save()
```

### Pattern 3: Delete All Data (Complete)
```swift
// 1. Standalone entities
let events = try context.fetch(FetchDescriptor<SDOutboxEvent>())
for event in events { context.delete(event) }

// 2. Deepest children
let stages = try context.fetch(FetchDescriptor<SDSleepStage>())
for stage in stages { context.delete(stage) }

// 3. Children with relationships (break first)
let sessions = try context.fetch(FetchDescriptor<SDSleepSession>())
for session in sessions { session.userProfile = nil }
for session in sessions { context.delete(session) }

let entries = try context.fetch(FetchDescriptor<SDProgressEntry>())
for entry in entries { entry.userProfile = nil }
for entry in entries { context.delete(entry) }

let snapshots = try context.fetch(FetchDescriptor<SDActivitySnapshot>())
for snapshot in snapshots { snapshot.userProfile = nil }
for snapshot in snapshots { context.delete(snapshot) }

let attributes = try context.fetch(FetchDescriptor<SDPhysicalAttribute>())
for attribute in attributes { attribute.userProfile = nil }
for attribute in attributes { context.delete(attribute) }

let prefs = try context.fetch(FetchDescriptor<SDDietaryAndActivityPreferences>())
for pref in prefs { pref.userProfile = nil }
for pref in prefs { context.delete(pref) }

// 4. Parent entity (last)
let profiles = try context.fetch(FetchDescriptor<SDUserProfile>())
for profile in profiles { context.delete(profile) }

// 5. Save all changes
try context.save()
```

---

## 🐛 Why This Is Necessary

**The Problem:**
- SwiftData expects ALL relationships to be arrays
- `SDUserProfile.dietaryAndActivityPreferences` is a single optional (one-to-one)
- When deleting a child entity, SwiftData tries to update parent's inverse relationship
- SwiftData crashes with: `Fatal error: Expected only Arrays for Relationships`

**The Solution:**
- Break relationships (`userProfile = nil`) before deletion
- SwiftData skips inverse relationship update
- No crash occurs

---

## 📚 Full Documentation

For detailed explanation, see:
- `docs/fixes/SWIFTDATA_RELATIONSHIP_DELETE_FIX_2025-01-27.md`
- `docs/guides/SWIFTDATA_DELETION_PATTERNS.md`

---

**Last Updated:** 2025-01-27  
**Status:** ✅ Active  
**Print this card and keep it handy!** 🖨️