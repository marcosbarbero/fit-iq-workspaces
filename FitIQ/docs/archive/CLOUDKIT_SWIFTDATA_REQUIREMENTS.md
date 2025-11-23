# CloudKit + SwiftData Requirements

**Created:** 2025-01-31  
**Purpose:** Document CloudKit requirements for SwiftData models to prevent runtime errors

---

## 🚨 Critical CloudKit Requirements

When using SwiftData with CloudKit sync enabled, Apple enforces strict requirements:

### 1. All Attributes Must Be Optional OR Have Default Values

**❌ CloudKit Does NOT Allow:**
```swift
@Model
final class SDExample {
    var id: UUID              // ❌ Non-optional without default
    var name: String          // ❌ Non-optional without default
    var count: Int            // ❌ Non-optional without default
    var createdAt: Date       // ❌ Non-optional without default
}
```

**✅ CloudKit REQUIRES:**
```swift
@Model
final class SDExample {
    // Option 1: Provide default values
    var id: UUID = UUID()
    var name: String = ""
    var count: Int = 0
    var createdAt: Date = Date()
    
    // Option 2: Make optional
    var optionalField: String?
    var optionalDate: Date?
}
```

---

### 2. Unique Constraints Are Not Supported

**❌ CloudKit Does NOT Allow:**
```swift
@Model
final class SDExample {
    @Attribute(.unique) var id: UUID = UUID()  // ❌ Unique constraint not allowed
}
```

**✅ CloudKit REQUIRES:**
```swift
@Model
final class SDExample {
    var id: UUID = UUID()  // ✅ No unique constraint
}
```

**Note:** Even though you can't enforce uniqueness at the database level, you can still implement uniqueness checks in your repository layer.

---

## 📋 Runtime Error Example

If you violate these requirements, you'll see this error at runtime:

```
Error Domain=NSCocoaErrorDomain Code=134060 "A Core Data error occurred."
UserInfo={
  NSLocalizedFailureReason=CloudKit integration requires that all attributes 
  be optional, or have a default value set. The following attributes are 
  marked non-optional but do not have a default value:
  
  SDOutboxEvent: attemptCount
  SDOutboxEvent: createdAt
  SDOutboxEvent: entityID
  SDOutboxEvent: eventType
  SDOutboxEvent: id
  SDOutboxEvent: isNewRecord
  SDOutboxEvent: maxAttempts
  SDOutboxEvent: priority
  SDOutboxEvent: status
  SDOutboxEvent: userID
  
  CloudKit integration does not support unique constraints. 
  The following entities are constrained:
  SDOutboxEvent: id
}
```

---

## ✅ Compliant Model Example: SDOutboxEvent

```swift
@Model final class SDOutboxEvent {
    // All non-optional attributes MUST have default values
    var id: UUID = UUID()
    var eventType: String = ""
    var entityID: UUID = UUID()
    var userID: String = ""
    var status: String = "pending"
    var createdAt: Date = Date()
    var attemptCount: Int = 0
    var maxAttempts: Int = 5
    var priority: Int = 0
    var isNewRecord: Bool = true
    
    // Optional attributes are fine
    var lastAttemptAt: Date?
    var errorMessage: String?
    var completedAt: Date?
    var metadata: String?
    
    // Custom initializer to override defaults if needed
    init(
        id: UUID = UUID(),
        eventType: String,
        entityID: UUID,
        userID: String,
        status: String = "pending",
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        maxAttempts: Int = 5,
        errorMessage: String? = nil,
        completedAt: Date? = nil,
        metadata: String? = nil,
        priority: Int = 0,
        isNewRecord: Bool = true
    ) {
        self.id = id
        self.eventType = eventType
        self.entityID = entityID
        self.userID = userID
        self.status = status
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.maxAttempts = maxAttempts
        self.errorMessage = errorMessage
        self.completedAt = completedAt
        self.metadata = metadata
        self.priority = priority
        self.isNewRecord = isNewRecord
    }
}
```

---

## 📝 Checklist for New SwiftData Models

When creating a new `@Model` class for use with CloudKit:

- [ ] All non-optional attributes have default values
- [ ] No `@Attribute(.unique)` constraints used
- [ ] Consider making rarely-used fields optional
- [ ] Provide custom `init()` to allow overriding defaults
- [ ] Test model creation and CloudKit sync
- [ ] Verify no runtime errors on app launch

---

## 🔧 Fixing Existing Models

If you have existing models that violate CloudKit requirements:

### Step 1: Add Default Values

```swift
// Before
var count: Int

// After
var count: Int = 0
```

### Step 2: Remove Unique Constraints

```swift
// Before
@Attribute(.unique) var id: UUID

// After
var id: UUID = UUID()
```

### Step 3: Create New Schema Version

Since changing attributes requires schema migration:

```swift
enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(0, 0, 4)
    
    // Reuse unchanged models
    typealias SDUserProfile = SchemaV3.SDUserProfile
    
    // Define updated model
    @Model
    final class SDOutboxEvent {
        var id: UUID = UUID()  // Updated: removed unique, added default
        // ... other fields with defaults
    }
    
    static var models: [any PersistentModel.Type] {
        [
            SDUserProfile.self,
            SDOutboxEvent.self,
        ]
    }
}
```

### Step 4: Update Migration Plan

```swift
enum PersistenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self,
            SchemaV2.self,
            SchemaV3.self,
            SchemaV4.self,  // New version
        ]
    }
    
    static var stages: [MigrationStage] {
        [
            // ... existing migrations
            MigrationStage.lightweight(
                fromVersion: SchemaV3.self,
                toVersion: SchemaV4.self
            ),
        ]
    }
}
```

---

## 🎯 Design Considerations

### When to Use Optional vs Default Values

**Use Optional (`var field: Type?`):**
- Field is truly optional in business logic
- Field is not always populated
- Field represents "not set" vs "set to default"
- Examples: `lastAttemptAt`, `errorMessage`, `completedAt`

**Use Default Values (`var field: Type = default`):**
- Field always has a meaningful value
- Default represents initial state
- Field is required for business logic
- Examples: `id`, `createdAt`, `status`, `attemptCount`

### Handling Uniqueness Without Constraints

Since CloudKit doesn't support unique constraints, handle uniqueness in your repository:

```swift
final class OutboxRepository {
    func createEvent(...) async throws -> SDOutboxEvent {
        // Check for duplicates before inserting
        let existing = try await fetchEvent(byID: eventID)
        if existing != nil {
            throw OutboxError.duplicateEvent
        }
        
        let event = SDOutboxEvent(...)
        modelContext.insert(event)
        try modelContext.save()
        return event
    }
}
```

---

## 📚 Additional Resources

### Apple Documentation
- [SwiftData Model Configuration](https://developer.apple.com/documentation/swiftdata/model)
- [CloudKit Integration](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit)
- [Schema Migration](https://developer.apple.com/documentation/swiftdata/migrating-your-app-to-swiftdata)

### Common Patterns

**Pattern 1: ID Generation**
```swift
var id: UUID = UUID()  // ✅ Generates new UUID by default
```

**Pattern 2: Timestamp Defaults**
```swift
var createdAt: Date = Date()  // ✅ Captures current time by default
```

**Pattern 3: Status Defaults**
```swift
var status: String = "pending"  // ✅ Starts in pending state
```

**Pattern 4: Counter Defaults**
```swift
var attemptCount: Int = 0  // ✅ Starts at zero
```

---

## ⚠️ Important Notes

1. **These requirements are enforced at runtime, not compile time** - Your code will compile but crash when CloudKit tries to initialize the persistent store.

2. **Schema versions must be CloudKit-compliant** - All versions in your migration plan must follow these rules.

3. **Default values are evaluated at initialization** - Each new instance gets a fresh `UUID()`, `Date()`, etc.

4. **Custom initializers can override defaults** - You can still control initial values through `init()` parameters.

5. **SwiftData models are reference types** - Multiple references to the same model instance share the same data.

---

## 🧪 Testing CloudKit Compliance

### Manual Test
1. Clean build folder
2. Delete app from simulator/device
3. Run app
4. Check console for CloudKit errors
5. Verify app launches successfully

### Unit Test Pattern
```swift
func testModelCreatesWithDefaults() {
    let event = SDOutboxEvent(
        eventType: "test",
        entityID: UUID(),
        userID: "user123"
    )
    
    XCTAssertNotNil(event.id)
    XCTAssertEqual(event.status, "pending")
    XCTAssertEqual(event.attemptCount, 0)
    XCTAssertEqual(event.maxAttempts, 5)
    XCTAssertNotNil(event.createdAt)
}
```

---

## 📊 Summary Table

| Requirement | CloudKit Allows | Example |
|-------------|-----------------|---------|
| Non-optional with default | ✅ Yes | `var id: UUID = UUID()` |
| Optional | ✅ Yes | `var name: String?` |
| Non-optional without default | ❌ No | `var count: Int` |
| `@Attribute(.unique)` | ❌ No | `@Attribute(.unique) var id` |
| Relationships | ✅ Yes | `var items: [SDItem]?` |
| Computed properties | ✅ Yes | `var fullName: String { ... }` |

---

**Status:** Active  
**Applies To:** All SwiftData models used with CloudKit  
**Last Updated:** 2025-01-31