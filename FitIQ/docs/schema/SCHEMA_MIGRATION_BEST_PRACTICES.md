# SwiftData Schema Migration Best Practices

**Last Updated:** 2025-01-28  
**For:** iOS SwiftData + CloudKit Projects  
**Experience Level:** Intermediate to Advanced

---

## 🎯 Core Principles

### 1. **Models with Relationships MUST Be Redefined**

**❌ WRONG:**
```swift
enum SchemaV2: VersionedSchema {
    // This model has a relationship to SDUserProfile
    typealias SDProgressEntry = SchemaV1.SDProgressEntry
    //        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    //        WRONG! This references SchemaV1.SDUserProfile
}
```

**✅ CORRECT:**
```swift
enum SchemaV2: VersionedSchema {
    @Model final class SDProgressEntry {
        // ... properties
        @Relationship
        var userProfile: SDUserProfileV2?  // ✅ References current version
    }
}
```

**Rule:** If a model has a `@Relationship` to another model that changes between versions, **you MUST redefine it**.

---

### 2. **Always Use Fully Qualified Type Names in Inverse Relationships**

**❌ WRONG:**
```swift
@Relationship(inverse: \SDProgressEntry.userProfile)
//                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                     Ambiguous across schema versions
```

**✅ CORRECT:**
```swift
@Relationship(inverse: \SchemaV10.SDProgressEntry.userProfile)
//                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                     Fully qualified - no ambiguity
```

**Rule:** Always prefix with `SchemaVX.` to avoid keypath resolution errors.

---

### 3. **Choose the Right Migration Type**

| Scenario | Migration Type | Reason |
|----------|----------------|--------|
| Adding new standalone model | **Lightweight** | No relationships to existing models |
| Adding new field with default value | **Lightweight** | Simple schema change |
| Adding new relationship array | **Lightweight** | If target model unchanged |
| Redefining relationship models | **Custom** | Forces metadata update |
| Complex data transformation | **Custom** | Needs migration logic |
| Removing fields | **Custom** | May need data cleanup |

---

## 📋 Step-by-Step Migration Checklist

### Phase 1: Planning

- [ ] Identify what's changing (new models, new fields, relationship changes)
- [ ] Determine if any existing models need to be redefined
- [ ] Choose migration type (lightweight vs. custom)
- [ ] Plan data transformation if needed
- [ ] Document expected behavior

### Phase 2: Implementation

- [ ] Create new `SchemaVX.swift` file
- [ ] Increment version identifier: `Schema.Version(0, X, 0)`
- [ ] Reuse unchanged models via `typealias` (if no relationships)
- [ ] Redefine models with relationships to changed models
- [ ] Update parent model (e.g., `SDUserProfileVX`)
- [ ] Use fully qualified type names in all inverse relationships
- [ ] Update `models` array with all model types
- [ ] Add schema version to `FitIQSchemaDefinition` enum
- [ ] Update `CurrentSchema` typealias
- [ ] Add migration stage to `PersistenceMigrationPlan`
- [ ] Update `PersistenceHelper` typealiases

### Phase 3: Testing

- [ ] Build project (zero errors/warnings)
- [ ] Test fresh install on simulator
- [ ] Test fresh install on real device
- [ ] Test migration from previous version on simulator
- [ ] Test migration from previous version on real device
- [ ] Test all write operations after migration
- [ ] Test all read operations after migration
- [ ] Test CloudKit sync after migration
- [ ] Test background sync after migration
- [ ] Verify data integrity after migration

### Phase 4: Documentation

- [ ] Document schema changes in code comments
- [ ] Update migration plan comments
- [ ] Add entry to changelog
- [ ] Document any breaking changes
- [ ] Create user-facing documentation if needed

---

## 🔧 Common Scenarios

### Scenario 1: Adding a New Standalone Model

**Example:** Adding `SDNotification` model (no relationships)

```swift
enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 1)
    
    // Reuse all existing models
    typealias SDUserProfileV10 = SchemaV10.SDUserProfileV10
    typealias SDProgressEntry = SchemaV10.SDProgressEntry
    // ... all other models
    
    // Add new standalone model
    @Model final class SDNotification {
        var id: UUID = UUID()
        var title: String = ""
        var message: String = ""
        var createdAt: Date = Date()
        // No relationships to other models
    }
    
    static var models: [any PersistentModel.Type] {
        [
            SDUserProfileV10.self,
            SDProgressEntry.self,
            // ... all other models
            SDNotification.self,  // NEW
        ]
    }
}

// Migration Plan
MigrationStage.lightweight(
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self
)
```

**Migration Type:** Lightweight ✅  
**Why:** No relationships, no data transformation needed

---

### Scenario 2: Adding a Field with Default Value

**Example:** Adding `timezone` field to `SDUserProfile`

```swift
enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 1)
    
    // Reuse models without relationships
    typealias SDOutboxEvent = SchemaV10.SDOutboxEvent
    
    // Redefine models with relationships to SDUserProfile
    @Model final class SDProgressEntry {
        // ... existing properties
        @Relationship
        var userProfile: SDUserProfileV11?  // Updated to V11
    }
    
    @Model final class SDUserProfileV11 {
        // ... existing properties
        var timezone: String = "UTC"  // NEW with default value
        
        @Relationship(deleteRule: .cascade, inverse: \SchemaV11.SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]?
    }
}

// Migration Plan
MigrationStage.lightweight(
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self
)
```

**Migration Type:** Lightweight ✅  
**Why:** Default value provided, relationship models redefined

---

### Scenario 3: Adding a New Relationship

**Example:** Adding `workouts` relationship to `SDUserProfile`

```swift
enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 1)
    
    // New model with relationship
    @Model final class SDWorkout {
        var id: UUID = UUID()
        var name: String = ""
        var durationMinutes: Int = 0
        
        @Relationship
        var userProfile: SDUserProfileV11?  // Relationship to user
    }
    
    // All models with relationships to SDUserProfile must be redefined
    @Model final class SDProgressEntry {
        // ... properties
        @Relationship
        var userProfile: SDUserProfileV11?  // Updated to V11
    }
    
    @Model final class SDUserProfileV11 {
        // ... existing properties and relationships
        
        @Relationship(deleteRule: .cascade, inverse: \SchemaV11.SDWorkout.userProfile)
        var workouts: [SDWorkout]?  // NEW relationship
    }
}

// Migration Plan
MigrationStage.custom(
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self,
    didMigrate: { context in
        // Force metadata update
        try context.save()
    }
)
```

**Migration Type:** Custom ⚠️  
**Why:** Redefining relationship models requires metadata update

---

### Scenario 4: Changing Field Type

**Example:** Changing `quantity` from `String` to `Double`

```swift
enum SchemaV11: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 1, 1)
    
    @Model final class SDMealLogItem {
        var id: UUID = UUID()
        var quantity: Double = 0.0  // Changed from String to Double
        var unit: String = ""       // NEW field
        
        @Relationship
        var meal: SDMeal?
    }
    
    @Model final class SDMeal {
        // ... properties
        @Relationship(deleteRule: .cascade, inverse: \SchemaV11.SDMealLogItem.meal)
        var items: [SDMealLogItem]?
    }
}

// Migration Plan
MigrationStage.lightweight(
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self
)
```

**Migration Type:** Lightweight ✅  
**Why:** Default value provided, old data acceptable with defaults

**⚠️ Note:** Existing string values will be lost and replaced with default `0.0`. Only use lightweight if data loss is acceptable (e.g., read-only data that will be replaced by backend).

**Alternative:** Use custom migration to preserve/transform data:

```swift
MigrationStage.custom(
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self,
    didMigrate: { context in
        // Migrate existing data
        let oldItems = try context.fetch(FetchDescriptor<SchemaV10.SDMealLogItem>())
        for oldItem in oldItems {
            if let newItem = try? context.fetch(
                FetchDescriptor<SchemaV11.SDMealLogItem>(
                    predicate: #Predicate { $0.id == oldItem.id }
                )
            ).first {
                // Parse old string quantity to double
                if let quantity = Double(oldItem.quantity) {
                    newItem.quantity = quantity
                }
            }
        }
        try context.save()
    }
)
```

---

## 🚨 Common Pitfalls

### Pitfall 1: Forgetting to Redefine Relationship Models

**Problem:**
```swift
enum SchemaV11: VersionedSchema {
    typealias SDProgressEntry = SchemaV10.SDProgressEntry  // ❌ Still references V10 user profile
    
    @Model final class SDUserProfileV11 {
        @Relationship(inverse: \SDProgressEntry.userProfile)  // ❌ Ambiguous!
        var progressEntries: [SDProgressEntry]?
    }
}
```

**Error:** `Fatal error: This KeyPath does not appear to relate SDUserProfileV11 to anything`

**Solution:** Redefine ALL models with relationships to changed models.

---

### Pitfall 2: Using Bare Type Names in Inverse Relationships

**Problem:**
```swift
@Relationship(inverse: \SDProgressEntry.userProfile)  // ❌ Ambiguous
//                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

**Error:** Runtime crashes with keypath resolution errors

**Solution:** Always use fully qualified type names:
```swift
@Relationship(inverse: \SchemaV11.SDProgressEntry.userProfile)  // ✅ Clear
```

---

### Pitfall 3: Using Lightweight Migration When Custom Is Needed

**Problem:**
```swift
// Redefined relationship models but using lightweight migration
MigrationStage.lightweight(  // ❌ Won't update metadata properly
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self
)
```

**Symptom:** Runtime crashes on save operations after migration

**Solution:** Use custom migration when redefining relationship models:
```swift
MigrationStage.custom(  // ✅ Forces metadata update
    fromVersion: SchemaV10.self,
    toVersion: SchemaV11.self,
    didMigrate: { context in
        try context.save()
    }
)
```

---

### Pitfall 4: Forgetting to Update PersistenceHelper

**Problem:**
```swift
// PersistenceHelper.swift still references old version
typealias SDProgressEntry = SchemaV10.SDProgressEntry  // ❌ Should be V11
```

**Symptom:** Code compiles but references wrong schema version at runtime

**Solution:** Update ALL typealiases in PersistenceHelper:
```swift
typealias SDProgressEntry = SchemaV11.SDProgressEntry  // ✅ Current version
```

---

## 📊 Migration Decision Tree

```
Is this a new schema version?
│
├─ YES → Continue
│
└─ NO → Update existing schema (if not yet deployed)

Are you adding a new model?
│
├─ YES
│   │
│   └─ Does it have relationships to existing models?
│       │
│       ├─ YES → Redefine related models + Use CUSTOM migration
│       │
│       └─ NO → Use LIGHTWEIGHT migration
│
└─ NO → Continue

Are you changing an existing model?
│
├─ Adding field with default value → Use LIGHTWEIGHT migration
│
├─ Removing field → Use CUSTOM migration (may need data cleanup)
│
├─ Changing field type → 
│   ├─ Data loss acceptable → Use LIGHTWEIGHT migration
│   └─ Need to preserve data → Use CUSTOM migration with transformation
│
└─ Adding/changing relationship →
    │
    └─ Redefine related models + Use CUSTOM migration
```

---

## 🧪 Testing Checklist

### Pre-Deployment Testing

```markdown
## Fresh Install Testing
- [ ] Simulator: iPhone 14 Pro (iOS 17)
- [ ] Simulator: iPhone SE (iOS 17)
- [ ] Real Device: iPhone (latest iOS)
- [ ] Real Device: iPad (latest iOS)

## Migration Testing
- [ ] Migrate from V(X-1) to VX on simulator
- [ ] Migrate from V(X-1) to VX on real device
- [ ] Migrate with existing data (populated database)
- [ ] Migrate with empty database

## Functionality Testing
- [ ] All read operations work
- [ ] All write operations work
- [ ] All update operations work
- [ ] All delete operations work
- [ ] Relationships are properly maintained
- [ ] CloudKit sync works
- [ ] Background sync works
- [ ] Outbox pattern works

## Data Integrity Testing
- [ ] No data loss during migration
- [ ] Relationships are preserved
- [ ] Timestamps are preserved
- [ ] User-created content is preserved
- [ ] HealthKit data syncs correctly

## Performance Testing
- [ ] Migration completes in reasonable time
- [ ] App remains responsive during migration
- [ ] No memory leaks
- [ ] No excessive CPU usage
```

---

## 📚 Reference Templates

### Template: New Schema Version File

```swift
//
//  SchemaVX.swift
//  FitIQ
//
//  Created by [Your Name] on [Date].
//  Schema VX: [Brief description of changes]
//

import Foundation
import SwiftData

enum SchemaVX: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, X, 0)
    
    // MARK: - Reuse Models WITHOUT Relationships to Changed Models
    
    typealias SDOutboxEvent = SchemaV(X-1).SDOutboxEvent
    // Add other standalone models here
    
    // MARK: - Redefine Models WITH Relationships to Changed Models
    
    @Model final class SDModelName {
        // Properties
        var id: UUID = UUID()
        // ... other properties
        
        // Relationships
        @Relationship
        var userProfile: SDUserProfileVX?
        
        // Init
        init(/* parameters */) {
            // Initialization
        }
    }
    
    // MARK: - Main User Profile Model
    
    @Model final class SDUserProfileVX {
        // Properties
        var id: UUID = UUID()
        // ... other properties
        
        // Relationships (with fully qualified inverse)
        @Relationship(deleteRule: .cascade, inverse: \SchemaVX.SDModelName.userProfile)
        var modelNames: [SDModelName]? = []
        
        // Init
        init(/* parameters */) {
            // Initialization
        }
    }
    
    // MARK: - Schema Models Array
    
    static var models: [any PersistentModel.Type] {
        [
            SDUserProfileVX.self,
            SDModelName.self,
            // List ALL model types here
        ]
    }
}
```

---

### Template: Migration Stage

```swift
// In PersistenceMigrationPlan.swift

// Lightweight Migration (simple changes)
MigrationStage.lightweight(
    fromVersion: SchemaV(X-1).self,
    toVersion: SchemaVX.self
),

// Custom Migration (relationship changes or data transformation)
MigrationStage.custom(
    fromVersion: SchemaV(X-1).self,
    toVersion: SchemaVX.self,
    willMigrate: nil,  // Optional: pre-migration logic
    didMigrate: { context in
        // Post-migration logic
        // Example: Data transformation, cleanup, etc.
        
        // Always save to ensure metadata is updated
        try context.save()
    }
),
```

---

## 🎓 Additional Resources

### Apple Documentation
- [SwiftData Migration Guide](https://developer.apple.com/documentation/swiftdata/migrating-your-swiftdata-app)
- [Schema Versioning](https://developer.apple.com/documentation/swiftdata/versionedschema)
- [Migration Planning](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)

### Internal Documentation
- `V10_MIGRATION_FIX.md` - Case study of V9→V10 migration issue
- `USER_REINSTALL_GUIDE.md` - User-facing reinstall instructions
- `CLOUDKIT_SCHEMA_FIX.md` - CloudKit relationship patterns

---

## ✅ Quick Reference: Do's and Don'ts

### ✅ DO

- **DO** redefine models with relationships when parent models change
- **DO** use fully qualified type names in inverse relationships
- **DO** use custom migration when redefining relationship models
- **DO** test migration on real devices before deployment
- **DO** document what changed and why
- **DO** update PersistenceHelper typealiases
- **DO** verify CloudKit compatibility

### ❌ DON'T

- **DON'T** reuse models with relationships via typealias across versions
- **DON'T** use bare type names in inverse relationship keypaths
- **DON'T** use lightweight migration for relationship changes
- **DON'T** skip testing on real devices
- **DON'T** forget to increment version number
- **DON'T** deploy without thorough testing
- **DON'T** forget to update schema definition enum

---

**Last Updated:** 2025-01-28  
**Next Review:** After each major schema change  
**Maintainer:** iOS Engineering Team