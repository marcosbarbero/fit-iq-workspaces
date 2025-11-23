# Schema V10 Migration Fix — Critical Issue Resolved

**Date:** 2025-01-28  
**Status:** ✅ FIXED  
**Impact:** High — Affects all users with existing V9 databases  
**Action Required:** Delete and reinstall app (one-time only)

---

## 🚨 Problem Summary

### The Issue
Users experienced a **fatal crash** when trying to save data after upgrading to SchemaV10:

```
Fatal error: This KeyPath does not appear to relate SDUserProfileV10 to anything - 
\SDUserProfileV9.progressEntries
```

### Root Cause
The crash occurred due to **relationship keypath ambiguity** between SchemaV9 and SchemaV10:

1. **Original Setup (WRONG):**
   - SchemaV10 **reused** `SDDietaryAndActivityPreferences` from V9 via `typealias`
   - This model had a relationship to `SDUserProfileV9`
   - When runtime tried to resolve relationships, it found conflicting keypaths:
     - V9: `\SDUserProfileV9.progressEntries`
     - V10: `\SDUserProfileV10.progressEntries`
   - SwiftData couldn't resolve which one to use → **CRASH**

2. **Migration Type (WRONG):**
   - Used **lightweight migration** from V9→V10
   - Lightweight migration doesn't properly update relationship metadata
   - Existing V9 databases retained old relationship keypaths
   - New saves attempted to use V10 relationships → **CRASH**

3. **Field Compatibility Issue (DISCOVERED):**
   - Initial V10 implementation changed `SDSleepSession` field names
   - Changed from: `date`, `startTime`, `endTime` (V9)
   - Changed to: `startDate`, `endDate` (V10 - WRONG)
   - Repository code still referenced old `date` field → **CRASH**
   - Solution: Maintained V9 field names for backward compatibility

---

## ✅ Solution

### 1. Redefined `SDDietaryAndActivityPreferences` in V10
**Changed from:**
```swift
// SchemaV10.swift (WRONG)
typealias SDDietaryAndActivityPreferences = SchemaV9.SDDietaryAndActivityPreferences
```

**Changed to:**
```swift
// SchemaV10.swift (CORRECT)
@Model final class SDDietaryAndActivityPreferences {
    var allergies: [String]?
    var dietaryRestrictions: [String]?
    var foodDislikes: [String]?
    var createdAt: Date = Date()
    var updatedAt: Date?

    @Relationship
    var userProfile: SDUserProfileV10?  // ✅ Now references V10, not V9
    
    // ... init
}
```

**Why:** Models with relationships to `SDUserProfile` **MUST** be redefined in each schema version to avoid keypath ambiguity.

### 3. Maintained Field Names for SDSleepSession
**Issue:**
```swift
// SchemaV10.swift (INITIAL - WRONG)
@Model final class SDSleepSession {
    var startDate: Date = Date()  // ❌ Changed field name
    var endDate: Date = Date()    // ❌ Changed field name
    // Repository still references .date → CRASH
}
```

**Fixed:**
```swift
// SchemaV10.swift (CORRECT)
@Model final class SDSleepSession {
    var date: Date = Date()       // ✅ Maintained from V9
    var startTime: Date = Date()  // ✅ Maintained from V9
    var endTime: Date = Date()    // ✅ Maintained from V9
    var timeInBedMinutes: Int = 0
    var totalSleepMinutes: Int = 0
    var sleepEfficiency: Double = 0.0
    // ... other fields
}
```

**Why:** Renaming fields requires updating ALL code that references them (repositories, queries, sort descriptors). For schema migrations, it's safer to maintain field names unless there's a compelling reason to change them.

### 2. Fixed Inverse Relationship Keypath
**Changed from:**
```swift
// SDUserProfileV10 (WRONG)
@Relationship(deleteRule: .cascade, inverse: \SDDietaryAndActivityPreferences.userProfile)
var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?
```

**Changed to:**
```swift
// SDUserProfileV10 (CORRECT)
@Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDDietaryAndActivityPreferences.userProfile)
var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?
```

**Why:** Fully qualified type names prevent SwiftData from finding ambiguous keypaths across schema versions.

### 3. Changed Migration from Lightweight to Custom
**Changed from:**
```swift
// PersistenceMigrationPlan.swift (WRONG)
MigrationStage.lightweight(
    fromVersion: SchemaV9.self,
    toVersion: SchemaV10.self
)
```

**Changed to:**
```swift
// PersistenceMigrationPlan.swift (CORRECT)
MigrationStage.custom(
    fromVersion: SchemaV9.self,
    toVersion: SchemaV10.self,
    willMigrate: nil,
    didMigrate: { context in
        // Force schema update by saving context
        // This ensures all relationship metadata is properly updated to V10
        print("PersistenceMigrationPlan: Completed migration from V9 to V10")
        try context.save()
    }
)
```

**Why:** Custom migration forces SwiftData to properly update all relationship metadata in the database store.

**Note:** Field names in `SDSleepSession` were maintained from V9 (`date`, `startTime`, `endTime`) to ensure compatibility with existing repository code and queries.

---

## 📋 User Action Required

### ⚠️ One-Time Delete & Reinstall Required

**For users who already upgraded to V10 (with the bug):**

1. **Delete the app** from your device
2. **Reinstall the app** from TestFlight/App Store
3. **Sign in again** with your credentials
4. **HealthKit data will re-sync automatically**

### Why This Is Necessary
- Existing V9 databases have **corrupted relationship metadata** pointing to V9 types
- The only way to fix this is to start with a fresh database using V10 schema
- All your data is safely stored in the backend and will re-sync automatically
- HealthKit data will re-import from Apple Health

### ⚡ Future Updates: No More Reinstalls
- **This is the ONLY time** users need to delete/reinstall
- All future schema changes will use **automatic migrations**
- The app will seamlessly upgrade databases from V10 → V11 → V12, etc.

---

## 🔬 Technical Deep Dive

### Why Typealias Relationships Are Dangerous

When you have multiple schema versions with relationships, SwiftData's type system gets confused:

```swift
// SchemaV9
@Model final class SDDietaryAndActivityPreferences {
    @Relationship
    var userProfile: SDUserProfileV9?  // Points to V9
}

// SchemaV10 (WRONG - using typealias)
typealias SDDietaryAndActivityPreferences = SchemaV9.SDDietaryAndActivityPreferences
//                                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                         Still references SDUserProfileV9!

@Model final class SDUserProfileV10 {
    @Relationship(inverse: \SDDietaryAndActivityPreferences.userProfile)
    //                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //                     Ambiguous! Is this V9.userProfile or V10.userProfile?
    var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?
}
```

**The Problem:**
- SwiftData runtime sees BOTH `SDUserProfileV9` and `SDUserProfileV10` in memory
- When resolving `\SDDietaryAndActivityPreferences.userProfile`, it doesn't know which one to use
- Runtime metadata in the database points to V9, but current code expects V10
- **Result:** Fatal error during save operations

### Why Custom Migration Is Required

**Lightweight Migration:**
- Only updates schema structure (new tables, columns)
- Does NOT update relationship metadata
- Existing relationship keypaths remain unchanged in database store
- Works for simple changes (new fields, new standalone models)

**Custom Migration:**
- Forces full context save, updating all metadata
- Ensures relationship keypaths are resolved to new schema version
- Required when relationships change between schema versions
- Guarantees database store is fully consistent with new schema

---

## 📊 Impact Assessment

### Before Fix
- ✅ Read operations: Working
- ❌ Write operations: **CRASH**
- ❌ Progress tracking: **BROKEN**
- ❌ Sleep logging: **BROKEN**
- ❌ Mood logging: **BROKEN**
- ❌ Nutrition logging: **BROKEN**
- ❌ Sleep fetching: **CRASH** (missing `date` field)

### After Fix
- ✅ Read operations: Working
- ✅ Write operations: Working
- ✅ Progress tracking: Working
- ✅ Sleep logging: Working
- ✅ Mood logging: Working
- ✅ Nutrition logging: Working
- ✅ Sleep fetching: Working

---

## 🎓 Lessons Learned

### Rule 1: Never Reuse Models with Relationships Across Schema Versions
**WRONG:**
```swift
enum SchemaV10: VersionedSchema {
    typealias SDDietaryAndActivityPreferences = SchemaV9.SDDietaryAndActivityPreferences
    //        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //        WRONG! This model has a relationship to SDUserProfileV9
}
```

**CORRECT:**
```swift
enum SchemaV10: VersionedSchema {
    @Model final class SDDietaryAndActivityPreferences {
        @Relationship
        var userProfile: SDUserProfileV10?  // ✅ References current schema version
    }
}
```

### Rule 2: Always Use Fully Qualified Type Names for Inverse Relationships
**WRONG:**
```swift
@Relationship(inverse: \SDDietaryAndActivityPreferences.userProfile)
//                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                     Ambiguous across schema versions
```

**CORRECT:**
```swift
@Relationship(inverse: \SchemaV10.SDDietaryAndActivityPreferences.userProfile)
//                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                     Fully qualified - no ambiguity
```

### Rule 3: Use Custom Migration When Redefining Relationship Models
**WRONG:**
```swift
MigrationStage.lightweight(fromVersion: SchemaV9.self, toVersion: SchemaV10.self)
//             ^^^^^^^^^^^
//             Not enough for relationship changes
```

**CORRECT:**
```swift
MigrationStage.custom(
    fromVersion: SchemaV9.self,
    toVersion: SchemaV10.self,
    didMigrate: { context in
        try context.save()  // ✅ Forces metadata update
    }
)
```

---

## 🚀 Future-Proofing

### For All Future Schema Changes (V11, V12, etc.)

When adding a new schema version, follow this checklist:

- [ ] **Redefine ALL models with relationships to `SDUserProfile`**
  - DO NOT use `typealias` for models with relationships
  - Update relationship to reference new `SDUserProfileVXX`
  
- [ ] **Maintain field names unless absolutely necessary to change**
  - Renaming fields requires updating ALL references (repositories, queries, etc.)
  - If renaming is required, update all code that references the old field name
  - Document field name changes clearly
  
- [ ] **Use fully qualified type names in all inverse relationships**
  - Format: `\SchemaVXX.ModelName.property`
  - Never use bare `\ModelName.property`
  
- [ ] **Choose correct migration type:**
  - **Lightweight:** New standalone models, new fields with defaults
  - **Custom:** Redefining relationship models, complex data transformations
  
- [ ] **Test migration thoroughly:**
  - Test upgrading from previous version
  - Test fresh installs
  - Test write operations after migration

### Pattern for New Schema Versions

```swift
// SchemaV11 Example (future)
enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 1)
    
    // ✅ CORRECT: Reuse models WITHOUT relationships
    typealias SDOutboxEvent = SchemaV10.SDOutboxEvent
    
    // ✅ CORRECT: Redefine models WITH relationships to SDUserProfile
    @Model final class SDDietaryAndActivityPreferences {
        // ... properties
        @Relationship
        var userProfile: SDUserProfileV11?  // ✅ Points to V11
    }
    
    @Model final class SDProgressEntry {
        // ... properties (maintain field names from V10)
        @Relationship
        var userProfile: SDUserProfileV11?  // ✅ Points to V11
    }
    
    @Model final class SDSleepSession {
        // ... properties (maintain field names: date, startTime, endTime)
        @Relationship
        var userProfile: SDUserProfileV11?  // ✅ Points to V11
    }
    
    @Model final class SDUserProfileV11 {
        // ✅ CORRECT: Fully qualified inverse relationships
        @Relationship(deleteRule: .cascade, inverse: \SchemaV11.SDDietaryAndActivityPreferences.userProfile)
        var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?
        
        @Relationship(deleteRule: .cascade, inverse: \SchemaV11.SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]?
    }
}

// PersistenceMigrationPlan
static var stages: [MigrationStage] {
    [
        // ... previous stages
        
        // ✅ CORRECT: Use custom migration when redefining relationships
        MigrationStage.custom(
            fromVersion: SchemaV10.self,
            toVersion: SchemaV11.self,
            didMigrate: { context in
                try context.save()
            }
        )
    ]
}
```

---

## 📞 Support

### For Users
If you encounter any issues after delete/reinstall:
1. Ensure you're signed in with the correct account
2. Wait for HealthKit sync to complete (may take 1-2 minutes)
3. Check backend sync status in Settings
4. Contact support if data doesn't appear after 5 minutes

### For Developers
If you encounter similar issues in the future:
1. Check this document for patterns
2. Review schema relationship definitions
3. Verify inverse keypaths use fully qualified names
4. Consider custom migration for relationship changes

---

## ✅ Verification Checklist

Before deploying future schema changes:

- [ ] All models with `@Relationship` to `SDUserProfile` are redefined (not aliased)
- [ ] All inverse keypaths use fully qualified type names (`\SchemaVXX.Type.property`)
- [ ] Migration type is appropriate (custom for relationship changes)
- [ ] Built successfully with zero errors/warnings
- [ ] Tested migration from previous version on real device
- [ ] Tested fresh install on real device
- [ ] Tested all write operations after migration
- [ ] Tested CloudKit sync after migration
- [ ] Documented any user-facing changes
- [ ] Updated version numbers and changelog

---

**Status:** ✅ RESOLVED  
**Version:** SchemaV10 (0.1.0)  
**Next Action:** Deploy update + communicate reinstall instructions to users