# SwiftData Relationship Patterns - Best Practices

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Guidelines for implementing SwiftData relationships in FitIQ

---

## 🎯 Core Principle

**Use SwiftData relationships directly. Never duplicate relationship data with string IDs.**

---

## ✅ Correct Pattern: Relationship Only

### Example: SDMealLog → SDUserProfile

```swift
@Model final class SDMealLog {
    var id: UUID = UUID()
    
    /// ✅ CORRECT: Use relationship only
    @Relationship(inverse: \SDUserProfile.mealLogs)
    var userProfile: SDUserProfile?
    
    var rawInput: String = ""
    var mealType: String = ""
    // ... other properties
    
    init(
        id: UUID = UUID(),
        userProfile: SDUserProfile? = nil,  // ✅ Pass the relationship
        rawInput: String,
        mealType: String
    ) {
        self.id = id
        self.userProfile = userProfile
        self.rawInput = rawInput
        self.mealType = mealType
    }
}
```

### Parent Side (SDUserProfile)

```swift
@Model final class SDUserProfile {
    var id: UUID = UUID()
    var name: String = ""
    
    /// ✅ One-to-many relationship with cascade delete
    @Relationship(deleteRule: .cascade, inverse: \SDMealLog.userProfile)
    var mealLogs: [SDMealLog]? = []
    
    // ... other properties and relationships
}
```

---

## ❌ Anti-Pattern: Redundant ID Field

### What NOT to Do

```swift
@Model final class SDMealLog {
    var id: UUID = UUID()
    
    /// ❌ WRONG: Don't use both relationship AND string ID
    @Relationship(inverse: \SDUserProfile.mealLogs)
    var userProfile: SDUserProfile?
    
    /// ❌ REDUNDANT: This duplicates userProfile.id
    var userID: String = ""
    
    // ...
}
```

### Why This Is Wrong

1. **Data Duplication**: Same information stored twice
2. **Potential Inconsistency**: `userID` could drift from `userProfile?.id`
3. **Violates Normalization**: Relationships handle foreign keys automatically
4. **Maintenance Burden**: Must keep both in sync manually
5. **Not SwiftData Idiomatic**: Relationships are type-safe and automatic

---

## 📋 Relationship Patterns in FitIQ

### Pattern 1: One-to-Many (Most Common)

**Example:** User has many Progress Entries

```swift
// Child model
@Model final class SDProgressEntry {
    var id: UUID = UUID()
    
    // ✅ Child side: NO @Relationship attribute needed
    var userProfile: SDUserProfile?
    
    var type: ProgressType
    var quantity: Double
    // ...
}

// Parent model
@Model final class SDUserProfile {
    var id: UUID = UUID()
    
    // ✅ Parent side: @Relationship with inverse specification
    @Relationship(deleteRule: .cascade, inverse: \SDProgressEntry.userProfile)
    var progressEntries: [SDProgressEntry]? = []
    // ...
}
```

**Key Points:**
- Child has single parent reference (NO `@Relationship` attribute)
- Parent has array of children (WITH `@Relationship` attribute)
- Use `deleteRule: .cascade` to auto-delete children when parent is deleted
- Specify `inverse:` on parent side only (avoids circular reference errors)

---

### Pattern 2: One-to-One

**Example:** User has one Dietary Preferences

```swift
// Child model
@Model final class SDDietaryAndActivityPreferences {
    var id: UUID = UUID()
    
    @Relationship
    var userProfile: SDUserProfile?
    
    var dietType: String?
    var activityGoal: String?
    // ...
}

// Parent model
@Model final class SDUserProfile {
    var id: UUID = UUID()
    
    @Relationship(
        deleteRule: .cascade,
        inverse: \SDDietaryAndActivityPreferences.userProfile
    )
    var dietaryAndActivityPreferences: SDDietaryAndActivityPreferences?
    // ...
}
```

**Key Points:**
- Both sides use optional singular reference
- Parent typically owns the child (cascade delete)
- Inverse relationship maintains consistency

---

### Pattern 3: One-to-Many with Nested Children

**Example:** MealLog has many MealLogItems

```swift
// Grandchild model
@Model final class SDMealLogItem {
    var id: UUID = UUID()
    
    // ✅ Child side: NO @Relationship attribute
    var mealLog: SDMealLog?
    
    var name: String = ""
    var calories: Double = 0.0
    // ...
}

// Child model (parent of SDMealLogItem)
@Model final class SDMealLog {
    var id: UUID = UUID()
    
    // ✅ Child side (to User): NO @Relationship attribute
    var userProfile: SDUserProfile?
    
    // ✅ Parent side (to Items): @Relationship with inverse
    @Relationship(deleteRule: .cascade, inverse: \SDMealLogItem.mealLog)
    var items: [SDMealLogItem]? = []
    
    // ...
}

// Root parent model
@Model final class SDUserProfile {
    var id: UUID = UUID()
    
    // ✅ Parent side: @Relationship with inverse
    @Relationship(deleteRule: .cascade, inverse: \SDMealLog.userProfile)
    var mealLogs: [SDMealLog]? = []
    // ...
}
```

**Key Points:**
- Three-level hierarchy: User → MealLog → MealLogItem
- Cascade deletes propagate down the tree
- Each child knows only its immediate parent (NO `@Relationship` attribute)
- Parent arrays use `@Relationship` with `inverse:` and `deleteRule:`
- No need for `userID` in `SDMealLogItem` (access via `mealLog?.userProfile`)

---

## 🔧 Accessing Related Data

### ✅ Correct: Use Relationship Navigation

```swift
// Get user ID from meal log
if let userID = mealLog.userProfile?.id.uuidString {
    print("User ID: \(userID)")
}

// Get all meal logs for a user
if let logs = userProfile.mealLogs {
    print("Total logs: \(logs.count)")
}

// Get user from nested item
if let user = mealLogItem.mealLog?.userProfile {
    print("Owner: \(user.name)")
}
```

### ❌ Wrong: Storing and Using String IDs

```swift
// ❌ DON'T DO THIS
let userID = mealLog.userID  // Redundant field
```

---

## 🚨 Common Mistakes & Fixes

### Mistake 1: Storing Foreign Key IDs

```swift
// ❌ WRONG
@Model final class SDMealLog {
    var userID: String = ""  // Don't store this!
    var userProfile: SDUserProfile?
}

// ✅ CORRECT
@Model final class SDMealLog {
    @Relationship(inverse: \SDUserProfile.mealLogs)
    var userProfile: SDUserProfile?
    // No userID needed!
}
```

---

### Mistake 2: Using @Relationship on Child Side

```swift
// ❌ WRONG: Causes circular reference errors
@Model final class SDMealLogItem {
    @Relationship  // Don't use on child side!
    var mealLog: SDMealLog?
}

@Model final class SDMealLog {
    @Relationship(deleteRule: .cascade, inverse: \SDMealLogItem.mealLog)
    var items: [SDMealLogItem]? = []
}

// ✅ CORRECT: Only parent side has @Relationship
@Model final class SDMealLogItem {
    var mealLog: SDMealLog?  // No @Relationship attribute
}

@Model final class SDMealLog {
    @Relationship(deleteRule: .cascade, inverse: \SDMealLogItem.mealLog)
    var items: [SDMealLogItem]? = []
}
```

---

### Mistake 3: Not Using Cascade Delete

```swift
// ❌ WRONG: Orphaned children when parent is deleted
@Model final class SDUserProfile {
    @Relationship(inverse: \SDMealLog.userProfile)
    var mealLogs: [SDMealLog]? = []
}

// ✅ CORRECT: Children are auto-deleted with parent
@Model final class SDUserProfile {
    @Relationship(deleteRule: .cascade, inverse: \SDMealLog.userProfile)
    var mealLogs: [SDMealLog]? = []
}
```

---

## 📝 Schema Migration Considerations

### Adding Relationships to Existing Models

When adding a new relationship to an existing model in a new schema version:

```swift
enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 6)
    
    // ✅ MUST redefine models that have new relationships
    @Model final class SDUserProfile {
        var id: UUID = UUID()
        var name: String = ""
        
        // Existing relationships (redefined)
        @Relationship(deleteRule: .cascade, inverse: \SDProgressEntry.userProfile)
        var progressEntries: [SDProgressEntry]? = []
        
        // NEW relationship in V6
        @Relationship(deleteRule: .cascade, inverse: \SDMealLog.userProfile)
        var mealLogs: [SDMealLog]? = []
    }
    
    // ✅ MUST redefine related models for type compatibility
    @Model final class SDProgressEntry {
        var id: UUID = UUID()
        
        @Relationship(inverse: \SDUserProfile.progressEntries)
        var userProfile: SDUserProfile?  // Points to V6 type
    }
    
    // NEW model in V6
    @Model final class SDMealLog {
        var id: UUID = UUID()
        
        @Relationship(inverse: \SDUserProfile.mealLogs)
        var userProfile: SDUserProfile?  // Points to V6 type
    }
}
```

**Important:**
- Adding relationships requires redefining related models
- Use custom migration stage (not lightweight)
- Initialize new relationship fields in migration

---

## 🎓 Summary

### Do's ✅

- ✅ Use `@Relationship` on parent side (array side) only
- ✅ Specify `inverse:` on parent side for bidirectional relationships
- ✅ Use `deleteRule: .cascade` for parent-child relationships
- ✅ Navigate relationships directly (e.g., `mealLog.userProfile?.id`)
- ✅ Redefine models when adding relationships in new schema versions
- ✅ Follow existing patterns from `SDProgressEntry`, `SDActivitySnapshot`, etc.
- ✅ Keep child side simple (no `@Relationship` attribute)

### Don'ts ❌

- ❌ Never store foreign key IDs as string properties
- ❌ Never duplicate relationship data with ID fields
- ❌ Never use `var userID: String` when `var userProfile: SDUserProfile?` exists
- ❌ Never use `@Relationship` attribute on child side (causes circular references)
- ❌ Don't forget cascade delete rules for parent-child relationships
- ❌ Don't use `SchemaVX.ModelName` types across schema versions

---

## 📚 Reference Examples in Codebase

**Study these for correct patterns:**

- `Infrastructure/Persistence/Schema/SchemaV6.swift`
  - `SDUserProfile` → `SDMealLog` (one-to-many)
  - `SDMealLog` → `SDMealLogItem` (one-to-many)
  - `SDUserProfile` → `SDProgressEntry` (one-to-many)
  - `SDUserProfile` → `SDActivitySnapshot` (one-to-many)
  - `SDUserProfile` → `SDDietaryAndActivityPreferences` (one-to-one)

---

**Remember: Relationships are type-safe, automatic, and eliminate the need for manual foreign key management. Trust SwiftData!**