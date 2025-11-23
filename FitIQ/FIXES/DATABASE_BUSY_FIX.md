# Fix for "CoreData: debug: WAL checkpoint: Database busy" Warnings

## Problem

The app was generating persistent "Database busy" warnings during WAL (Write-Ahead Logging) checkpoint operations:

```
CoreData: debug: WAL checkpoint: Database busy
CoreData: debug: WAL checkpoint: Database busy
```

## Root Cause

Multiple `ModelContext` instances were being created throughout the codebase, causing database contention:

1. **OutboxRepository** created its own context: `ModelContext(container)`
2. **SleepRepository** created its own context: `ModelContext(container)`
3. **ProgressRepository** created its own context: `ModelContext(modelContainer)` internally
4. Various use cases created temporary contexts for operations

When multiple contexts try to write to the same SwiftData/CoreData store simultaneously, they compete for database access, causing:
- WAL checkpoint conflicts
- "Database busy" warnings
- Performance degradation
- Potential data synchronization issues

## Solution

### 1. Created a Shared ModelContext

In `AppDependencies.swift`, create a single shared context that all repositories use:

```swift
// AppDependencies.build() method
let container = buildModelContainer()
let sharedContext = ModelContext(container)  // ✅ Single shared context
```

### 2. Updated SwiftDataProgressRepository

Changed the repository to accept a shared context instead of creating its own:

**Before:**
```swift
init(modelContainer: ModelContainer, outboxRepository: OutboxRepositoryProtocol) {
    self.modelContainer = modelContainer
    self.modelContext = ModelContext(modelContainer)  // ❌ Creates new context
    self.outboxRepository = outboxRepository
}
```

**After:**
```swift
init(
    modelContext: ModelContext,  // ✅ Accept shared context
    modelContainer: ModelContainer,
    outboxRepository: OutboxRepositoryProtocol
) {
    self.modelContext = modelContext
    self.modelContainer = modelContainer
    self.outboxRepository = outboxRepository
}
```

### 3. Updated AppDependencies to Pass Shared Context

**Before:**
```swift
let outboxRepository = SwiftDataOutboxRepository(
    modelContext: ModelContext(container)  // ❌ New context
)

let sleepRepository = SwiftDataSleepRepository(
    modelContext: ModelContext(container),  // ❌ Another new context
    outboxRepository: outboxRepository
)

let swiftDataProgressRepository = SwiftDataProgressRepository(
    modelContainer: container,  // ❌ Would create internal context
    outboxRepository: outboxRepository
)
```

**After:**
```swift
let outboxRepository = SwiftDataOutboxRepository(
    modelContext: sharedContext  // ✅ Shared context
)

let sleepRepository = SwiftDataSleepRepository(
    modelContext: sharedContext,  // ✅ Shared context
    outboxRepository: outboxRepository
)

let swiftDataProgressRepository = SwiftDataProgressRepository(
    modelContext: sharedContext,  // ✅ Shared context
    modelContainer: container,
    outboxRepository: outboxRepository
)
```

## When to Use Separate Contexts

Some operations **should** use isolated contexts:

### ✅ Acceptable to create new context:
- **Read-only diagnostic operations** (e.g., `CheckDatabaseHealthUseCase`)
- **Bulk delete operations** (e.g., `DeleteAllUserDataUseCase`)
- **Background operations** that need isolation from main context
- **Migration operations** that need to be atomic

### ❌ Must use shared context:
- **Normal CRUD operations** in repositories
- **Outbox Pattern operations**
- **Any frequent read/write operations**

## Benefits

1. **Eliminates "Database busy" warnings** - No more competing contexts
2. **Better performance** - Reduced context creation overhead
3. **Consistent data view** - All repositories see the same data state
4. **Fewer race conditions** - Single context serializes operations naturally

## Testing

To verify the fix works:

1. **Delete and reinstall the app** (to clear the old SchemaV2 database)
2. Run the app and perform operations:
   - Log weight entries
   - Sync HealthKit data
   - Save progress entries
   - Force re-sync operations
3. Check console logs - "Database busy" warnings should be **gone** or drastically reduced

## Notes

- This fix does **not** solve the SchemaV2 migration crash
- The SchemaV2 crash requires deleting the app and reinstalling
- This fix improves database performance for all fresh installs and post-migration apps

## Files Changed

1. `Infrastructure/Persistence/SwiftDataProgressRepository.swift`
   - Updated `init()` to accept shared `ModelContext`
   
2. `Infrastructure/Configuration/AppDependencies.swift`
   - Created `sharedContext = ModelContext(container)`
   - Updated all repository instantiations to use `sharedContext`

## Date

2025-01-27