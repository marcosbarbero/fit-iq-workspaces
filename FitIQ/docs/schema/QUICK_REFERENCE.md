# SwiftData Schema Migration — Quick Reference Card

**Last Updated:** 2025-01-28  
**Print this and keep it visible while coding!**

---

## 🚨 Critical Rules (NEVER BREAK THESE)

### Rule 1: Models with Relationships MUST Be Redefined

```swift
// ❌ WRONG
typealias SDProgressEntry = SchemaV9.SDProgressEntry  // Has relationship to SDUserProfileV9

// ✅ CORRECT
@Model final class SDProgressEntry {
    @Relationship
    var userProfile: SDUserProfileV10?  // References current version
}
```

### Rule 2: Always Use Fully Qualified Type Names

```swift
// ❌ WRONG
@Relationship(inverse: \SDProgressEntry.userProfile)

// ✅ CORRECT
@Relationship(inverse: \SchemaV10.SDProgressEntry.userProfile)
```

### Rule 3: Custom Migration for Relationship Changes

```swift
// ❌ WRONG
MigrationStage.lightweight(fromVersion: V9.self, toVersion: V10.self)

// ✅ CORRECT
MigrationStage.custom(
    fromVersion: V9.self,
    toVersion: V10.self,
    didMigrate: { context in try context.save() }
)
```

### Rule 4: Maintain Field Names Across Versions

```swift
// ❌ WRONG - Renaming fields breaks existing queries
@Model final class SDSleepSession {  // V10
    var startDate: Date  // Changed from 'date'
    var endDate: Date    // Changed from 'endTime'
}

// ✅ CORRECT - Keep field names consistent
@Model final class SDSleepSession {  // V10
    var date: Date       // Same as V9
    var startTime: Date  // Same as V9
    var endTime: Date    // Same as V9
}
```

---

## 📋 New Schema Version Checklist

```
[ ] 1. Create SchemaVX.swift file
[ ] 2. Set version: Schema.Version(0, X, 0)
[ ] 3. Reuse models WITHOUT relationships (typealias)
[ ] 4. Redefine models WITH relationships (full @Model)
[ ] 5. Use fully qualified names in ALL inverse keypaths
[ ] 6. Update SDUserProfileVX with new relationships
[ ] 7. Add all models to static var models array
[ ] 8. Update FitIQSchemaDefinition enum (add case vX)
[ ] 9. Update CurrentSchema typealias
[ ] 10. Add migration stage to PersistenceMigrationPlan
[ ] 11. Update PersistenceHelper typealiases
[ ] 12. Build (must be 0 errors, 0 warnings)
[ ] 13. Test fresh install on device
[ ] 14. Test migration from V(X-1) on device
[ ] 15. Test all write operations
[ ] 16. Document changes
```

---

## 🔀 When to Use Which Migration Type

| Change | Migration Type |
|--------|----------------|
| New standalone model (no relationships) | Lightweight |
| New field with default value | Lightweight |
| Adding relationship to new model | **Custom** |
| Redefining relationship models | **Custom** |
| Changing field type (data loss OK) | Lightweight |
| Changing field type (preserve data) | **Custom** |
| Removing fields | **Custom** |

---

## 🎯 Common Patterns

### Pattern 1: Reusing Standalone Models

```swift
enum SchemaV10: VersionedSchema {
    // Model has NO relationships to other models
    typealias SDOutboxEvent = SchemaV9.SDOutboxEvent  // ✅ OK
}
```

### Pattern 2: Redefining Relationship Models

```swift
enum SchemaV10: VersionedSchema {
    // Model HAS relationship to SDUserProfile
    @Model final class SDProgressEntry {  // ✅ MUST redefine
        @Relationship
        var userProfile: SDUserProfileV10?  // ✅ Current version
    }
}
```

### Pattern 3: Parent Model with Relationships

```swift
@Model final class SDUserProfileV10 {
    @Relationship(deleteRule: .cascade, inverse: \SchemaV10.SDProgressEntry.userProfile)
    //                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //                                           ✅ Fully qualified
    var progressEntries: [SDProgressEntry]?
}
```

---

## 🚨 Error Messages & Fixes

### "KeyPath does not appear to relate..."

**Cause:** Relationship model not redefined or ambiguous keypath

**Fix:**
1. Redefine model in current schema version
2. Use fully qualified type name in inverse: `\SchemaVX.Model.property`
3. Use custom migration

### "Cannot convert value of type..."

**Cause:** Model references wrong schema version

**Fix:**
1. Check all relationship properties reference current version
2. Update PersistenceHelper typealiases

### Build succeeds but crashes on save

**Cause:** Using lightweight migration when custom needed

**Fix:**
1. Change to custom migration
2. Add `didMigrate: { context in try context.save() }`

---

## 📝 Code Templates

### New Schema File Header

```swift
enum SchemaVX: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, X, 0)
    
    // MARK: - Reuse Models (no relationships)
    typealias SDOutboxEvent = SchemaV(X-1).SDOutboxEvent
    
    // MARK: - Redefine Models (with relationships)
    @Model final class SDModelName {
        @Relationship
        var userProfile: SDUserProfileVX?
    }
    
    // MARK: - User Profile
    @Model final class SDUserProfileVX {
        @Relationship(deleteRule: .cascade, inverse: \SchemaVX.SDModelName.userProfile)
        var modelNames: [SDModelName]?
    }
    
    // MARK: - Models Array
    static var models: [any PersistentModel.Type] {
        [SDUserProfileVX.self, SDModelName.self, /* ... */]
    }
}
```

### Migration Stage (Custom)

```swift
MigrationStage.custom(
    fromVersion: SchemaV(X-1).self,
    toVersion: SchemaVX.self,
    willMigrate: nil,
    didMigrate: { context in
        // Optional: Data transformation logic here
        try context.save()  // REQUIRED: Forces metadata update
    }
)
```

---

## 🧪 Testing Commands

```bash
# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild clean

# Run on device (replace with your device)
xcodebuild -scheme FitIQ -destination 'platform=iOS,name=iPhone' test
```

---

## 📞 When You're Stuck

1. Read: `docs/schema/V10_MIGRATION_FIX.md` (real-world example)
2. Review: `docs/schema/SCHEMA_MIGRATION_BEST_PRACTICES.md`
3. Ask: #ios-dev Slack channel
4. Reference: Previous schema files (V9, V8, etc.)

---

## ⚡ Most Common Mistakes

1. ❌ Forgot to redefine relationship model
2. ❌ Used bare keypath instead of fully qualified
3. ❌ Used lightweight migration for relationship changes
4. ❌ Forgot to update PersistenceHelper
5. ❌ Didn't test migration on real device

---

**Remember:** 
1. When in doubt, redefine the model and use custom migration!
2. Never rename fields unless absolutely necessary - maintain consistency!

**Version:** 1.1  
**For:** FitIQ iOS App  
**Schema Current Version:** V10