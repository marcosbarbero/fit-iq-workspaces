# CloudKit SwiftData Quick Reference

**Last Updated:** 2025-01-27  
**Purpose:** Quick reference for CloudKit-compatible SwiftData patterns

---

## ⚡️ Quick Rules

### 1. Relationships Must Have Inverses
```swift
// ✅ CORRECT
@Model final class Parent {
    @Relationship(deleteRule: .cascade)
    var children: [Child]?
}

@Model final class Child {
    @Relationship(inverse: \Parent.children)  // ← Inverse on ONE side only
    var parent: Parent?
}

// ❌ WRONG - No inverse
@Model final class Child {
    @Relationship
    var parent: Parent?
}

// ❌ WRONG - Inverse on BOTH sides (circular reference)
@Model final class Parent {
    @Relationship(deleteRule: .cascade, inverse: \Child.parent)  // ← Don't do this
    var children: [Child]?
}
```

### 2. Relationships Must Be Optional
```swift
// ✅ CORRECT
@Relationship(deleteRule: .cascade)
var items: [Item]? = []

// ❌ WRONG - Non-optional array
@Relationship(deleteRule: .cascade)
var items: [Item] = []
```

### 3. No Unique Constraints
```swift
// ✅ CORRECT
var id: UUID = UUID()

// ❌ WRONG - CloudKit doesn't support unique constraints
@Attribute(.unique) var id: UUID = UUID()
```

---

## 📝 Common Patterns

### Pattern 1: One-to-Many Relationship
```swift
@Model final class User {
    var id: UUID = UUID()
    var name: String = ""
    
    @Relationship(deleteRule: .cascade)
    var posts: [Post]? = []
}

@Model final class Post {
    var id: UUID = UUID()
    var title: String = ""
    
    @Relationship(inverse: \User.posts)
    var author: User?
}
```

### Pattern 2: Many-to-Many Relationship
```swift
@Model final class Student {
    var id: UUID = UUID()
    var name: String = ""
    
    @Relationship(deleteRule: .nullify)
    var courses: [Course]? = []
}

@Model final class Course {
    var id: UUID = UUID()
    var name: String = ""
    
    @Relationship(inverse: \Student.courses)
    var students: [Student]? = []
}
```

### Pattern 3: Self-Referencing Relationship
```swift
@Model final class Comment {
    var id: UUID = UUID()
    var text: String = ""
    
    @Relationship(inverse: \Comment.replies)
    var parent: Comment?
    
    @Relationship(deleteRule: .cascade)
    var replies: [Comment]? = []
}
```

---

## 🛠 Code Patterns

### Reading Optional Arrays
```swift
// Safe iteration
for item in container.items ?? [] {
    process(item)
}

// Safe count
let count = user.posts?.count ?? 0

// Safe isEmpty check
let isEmpty = user.posts?.isEmpty ?? true

// Safe filtering
let active = (user.posts ?? []).filter { $0.isActive }

// Safe first element
let latest = user.posts?.first
```

### Writing to Optional Arrays
```swift
// Safe append
if user.posts == nil {
    user.posts = []
}
user.posts?.append(newPost)

// Safe remove
user.posts?.removeAll { $0.id == postID }

// Safe replace
if user.posts == nil {
    user.posts = []
}
user.posts = newPosts
```

### Checking Array State
```swift
// Check if nil
if user.posts == nil {
    print("Array not initialized")
}

// Check if empty
if user.posts?.isEmpty ?? true {
    print("No posts")
}

// Check if has items
if let posts = user.posts, !posts.isEmpty {
    print("Has \(posts.count) posts")
}
```

---

## 🚨 Common Mistakes

### Mistake 1: Forgetting Inverse
```swift
// ❌ CRASH - No inverse relationship
@Model final class Order {
    @Relationship(deleteRule: .cascade)
    var items: [OrderItem]? = []
}

@Model final class OrderItem {
    @Relationship  // ← Missing inverse!
    var order: Order?
}

// ✅ FIX - Add inverse
@Model final class OrderItem {
    @Relationship(inverse: \Order.items)
    var order: Order?
}
```

### Mistake 2: Non-Optional Arrays
```swift
// ❌ CRASH - Non-optional relationship array
@Relationship(deleteRule: .cascade)
var items: [Item] = []

// ✅ FIX - Make it optional
@Relationship(deleteRule: .cascade)
var items: [Item]? = []
```

### Mistake 3: Accessing Array Without Nil Check
```swift
// ❌ CRASH - Array might be nil
for item in user.posts {  // ← Crash if nil
    process(item)
}

// ✅ FIX - Use nil-coalescing
for item in user.posts ?? [] {
    process(item)
}
```

### Mistake 4: Using .unique with CloudKit
```swift
// ❌ CRASH - CloudKit doesn't support unique constraints
@Model final class User {
    @Attribute(.unique) var email: String = ""
}

// ✅ FIX - Remove .unique, handle uniqueness in code
@Model final class User {
    var email: String = ""
}

// Manual uniqueness check
func findOrCreateUser(email: String) async throws -> User {
    let predicate = #Predicate<User> { $0.email == email }
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = 1
    
    if let existing = try modelContext.fetch(descriptor).first {
        return existing
    }
    
    let newUser = User(email: email)
    modelContext.insert(newUser)
    return newUser
}
```

---

## 🔍 Migration Checklist

When adding CloudKit to existing schema:

- [ ] All `@Relationship` properties are optional (`?`)
- [ ] All array relationships use `[Type]?` not `[Type]`
- [ ] Inverse relationships defined on ONE side
- [ ] No `@Attribute(.unique)` constraints
- [ ] Code handles nil arrays with `??` operator
- [ ] Code initializes arrays before appending: `if array == nil { array = [] }`
- [ ] Delete rules specified on parent side

---

## 📊 Delete Rules Reference

```swift
// Cascade - Delete children when parent is deleted
@Relationship(deleteRule: .cascade)
var children: [Child]? = []

// Nullify - Set child's parent to nil when parent is deleted
@Relationship(deleteRule: .nullify)
var optionalChildren: [Child]? = []

// Deny - Prevent parent deletion if children exist
@Relationship(deleteRule: .deny)
var protectedChildren: [Child]? = []

// No Action - Don't modify children when parent is deleted
@Relationship(deleteRule: .noAction)
var independentChildren: [Child]? = []
```

---

## 🎯 Testing Your Schema

```swift
// Test 1: Verify relationships work
let parent = Parent()
let child = Child()
parent.children = [child]
child.parent = parent
modelContext.insert(parent)
try modelContext.save()

// Test 2: Verify nil handling
let emptyParent = Parent()
for child in emptyParent.children ?? [] {  // Should not crash
    print(child)
}

// Test 3: Verify cascade delete
let parentToDelete = Parent()
parentToDelete.children = [Child(), Child()]
modelContext.insert(parentToDelete)
try modelContext.save()

modelContext.delete(parentToDelete)
try modelContext.save()
// Children should be deleted too (if deleteRule: .cascade)
```

---

## 🔧 Disable CloudKit (If Needed)

**File:** `AppDependencies.swift`

```swift
private static func buildModelContainer() -> ModelContainer {
    let schema = Schema(versionedSchema: CurrentSchema.self)
    
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        cloudKitDatabase: .none  // ✅ Disable CloudKit
    )
    
    return try ModelContainer(
        for: schema,
        migrationPlan: PersistenceMigrationPlan.self,
        configurations: [modelConfiguration]
    )
}
```

---

## 📚 Further Reading

- [Apple: SwiftData Model Relationships](https://developer.apple.com/documentation/swiftdata/relationships)
- [Apple: CloudKit Integration](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
- [Project: CLOUDKIT_COMPATIBILITY_FIX.md](./CLOUDKIT_COMPATIBILITY_FIX.md)
- [Project: CLOUDKIT_FIX_SUMMARY.md](./CLOUDKIT_FIX_SUMMARY.md)

---

**Remember:** When in doubt, use optional relationships and check for nil! 🎯