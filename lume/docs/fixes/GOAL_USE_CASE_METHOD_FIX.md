# Goal Use Cases Method Call Fix

**Date:** 2025-01-28  
**Status:** ✅ Resolved  
**Impact:** Fixed method calls to use correct GoalRepository API

---

## Problem

Two goal use cases had compilation errors due to incorrect method calls:

1. **CreateGoalUseCase.swift:69** - `Value of type 'any GoalRepositoryProtocol' has no member 'save'`
2. **FetchGoalsUseCase.swift:56** - Same issue with `save()` method

---

## Root Cause

The `GoalRepositoryProtocol` has a different API design compared to other repositories:

### Other Repositories (AIInsight, Journal)
```swift
protocol AIInsightRepositoryProtocol {
    func save(_ insight: AIInsight) async throws -> AIInsight
}
```

### Goal Repository (Different Design)
```swift
protocol GoalRepositoryProtocol {
    // For NEW goals - takes parameters
    func create(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal
    
    // For EXISTING goals - takes entity
    func update(_ goal: Goal) async throws -> Goal
}
```

**Design Rationale:** The Goal repository uses a **create/update pattern** instead of a generic `save()` pattern to:
- Enforce validation at creation time
- Clearly distinguish between new and existing goals
- Enable Outbox pattern for proper event creation
- Prevent accidentally creating goals with pre-existing IDs

---

## Solution

### Fix 1: CreateGoalUseCase

**Before (Incorrect):**
```swift
// Create goal entity
let goal = Goal(
    id: UUID(),
    userId: UUID(),
    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
    createdAt: Date(),
    updatedAt: Date(),
    targetDate: targetDate,
    progress: 0.0,
    status: .active,
    category: category
)

// Save to local repository (offline-first)
let savedGoal = try await goalRepository.save(goal)
```

**After (Correct):**
```swift
// Create goal in repository (offline-first with Outbox pattern)
let goal = try await goalRepository.create(
    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
    category: category,
    targetDate: targetDate
)
```

**Benefits:**
- ✅ Repository handles entity creation (ID, timestamps, defaults)
- ✅ Repository coordinates Outbox event creation
- ✅ Less code duplication
- ✅ Cleaner separation of concerns

---

### Fix 2: FetchGoalsUseCase

**Before (Incorrect):**
```swift
// Save to local repository
for goal in backendGoals {
    do {
        _ = try await goalRepository.save(goal)
    } catch {
        print("⚠️ [FetchGoalsUseCase] Failed to save goal \(goal.id): \(error)")
    }
}
```

**After (Correct):**
```swift
// Update local repository with backend goals
for goal in backendGoals {
    do {
        _ = try await goalRepository.update(goal)
    } catch {
        print("⚠️ [FetchGoalsUseCase] Failed to update goal \(goal.id): \(error)")
    }
}
```

**Rationale:** Goals fetched from backend already have IDs and are existing entities, so we use `update()` not `create()`.

---

## Repository Method Usage Guide

### When to Use Each Method

| Scenario | Method | Example |
|----------|--------|---------|
| User creates new goal | `create()` | CreateGoalUseCase |
| Sync from backend | `update()` | FetchGoalsUseCase |
| User updates existing goal | `update()` | UpdateGoalUseCase |
| Change progress | `updateProgress()` | Progress tracking |
| Change status | `updateStatus()` | Complete/pause goal |

---

## Pattern Comparison

### Create Pattern (Goals)
```swift
// Use case builds parameters
let goal = try await repository.create(
    title: "Exercise daily",
    description: "30 min workout",
    category: .health,
    targetDate: Date().addingTimeInterval(30 * 24 * 60 * 60)
)

// Repository:
// 1. Creates entity with generated ID
// 2. Sets default values
// 3. Saves to SwiftData
// 4. Creates Outbox event
// 5. Returns complete entity
```

### Save Pattern (Insights, Journals)
```swift
// Use case creates entity
let insight = AIInsight(
    id: UUID(),
    // ... all properties
)

// Repository just saves it
let saved = try await repository.save(insight)

// Repository:
// 1. Saves entity as-is
// 2. Creates Outbox event if needed
// 3. Returns saved entity
```

---

## Why Different Patterns?

### Goals Use Create/Update Pattern
1. **Complex Validation:** Title, description, date validation happens in use case
2. **Default Values:** Progress (0.0), status (.active) set by repository
3. **Outbox Events:** Proper event types (goal.created vs goal.updated)
4. **User ID Assignment:** Repository gets userId from token storage
5. **Type Safety:** Can't accidentally create goal with wrong defaults

### Insights Use Save Pattern
1. **AI Generated:** Often created by AI service with all fields
2. **Simpler Structure:** Fewer required fields and defaults
3. **Flexible:** Same method works for sync and creation
4. **Backend ID:** May come with or without backend ID

---

## Architecture Benefits

### Clear Semantics
```swift
// Intent is obvious
let newGoal = try await repository.create(...)     // Creating new
let updated = try await repository.update(goal)     // Updating existing
```

### Type Safety
```swift
// Can't do this (compile error):
let goal = Goal(id: UUID(), ...) // Missing userId, wrong defaults
try await repository.save(goal)   // Method doesn't exist

// Must do this:
let goal = try await repository.create(...) // Repository ensures correctness
```

### Proper Event Creation
```swift
// create() -> Creates "goal.created" event
// update() -> Creates "goal.updated" event
// save()   -> Ambiguous - create or update?
```

---

## Verification

### Before Fix
```
CreateGoalUseCase.swift: 1 error
- Line 69: Value of type 'any GoalRepositoryProtocol' has no member 'save'

FetchGoalsUseCase.swift: 1 error
- Line 56: Value of type 'any GoalRepositoryProtocol' has no member 'save'
```

### After Fix
```
CreateGoalUseCase.swift: 0 errors ✅
FetchGoalsUseCase.swift: 0 errors ✅

All goal use cases compile successfully!
```

---

## Testing Implications

### Mock Repository Implementation
```swift
class MockGoalRepository: GoalRepositoryProtocol {
    var createdGoals: [Goal] = []
    var updatedGoals: [Goal] = []
    
    func create(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal {
        let goal = Goal(
            id: UUID(),
            userId: UUID(),
            title: title,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            targetDate: targetDate,
            progress: 0.0,
            status: .active,
            category: category
        )
        createdGoals.append(goal)
        return goal
    }
    
    func update(_ goal: Goal) async throws -> Goal {
        updatedGoals.append(goal)
        return goal
    }
}
```

### Test Example
```swift
func testCreateGoal() async throws {
    let mockRepo = MockGoalRepository()
    let useCase = CreateGoalUseCase(
        goalRepository: mockRepo,
        outboxRepository: MockOutboxRepository()
    )
    
    let goal = try await useCase.execute(
        title: "Test Goal",
        description: "Test Description",
        category: .health,
        targetDate: nil
    )
    
    XCTAssertEqual(mockRepo.createdGoals.count, 1)
    XCTAssertEqual(goal.title, "Test Goal")
    XCTAssertEqual(goal.progress, 0.0)
    XCTAssertEqual(goal.status, .active)
}
```

---

## Lessons Learned

### ✅ Best Practices

1. **Check Protocol Definitions First:** Always verify method signatures before implementation
2. **Understand Design Rationale:** Different patterns serve different purposes
3. **Respect Repository Contracts:** Each repository may have unique requirements
4. **Use Appropriate Methods:** create() for new, update() for existing

### 🔍 Code Review Checklist

When reviewing repository usage:
- [ ] Verify method exists in protocol
- [ ] Check method signature matches
- [ ] Ensure correct method for use case (create vs update vs save)
- [ ] Validate parameters are properly prepared
- [ ] Confirm error handling is appropriate

---

## Related Files

**Fixed Files:**
- `lume/Domain/UseCases/Goals/CreateGoalUseCase.swift` (Line 52-66)
- `lume/Domain/UseCases/Goals/FetchGoalsUseCase.swift` (Line 53-60)

**Protocol Definition:**
- `lume/Domain/Ports/GoalRepositoryProtocol.swift`

**Repository Implementation:**
- `lume/Data/Repositories/GoalRepository.swift`

---

## Impact Summary

✅ **Compilation:** All errors resolved, use cases compile successfully  
✅ **Architecture:** Proper repository pattern usage maintained  
✅ **Functionality:** Correct method calls ensure proper behavior  
✅ **Consistency:** Aligns with repository protocol design  
✅ **Maintainability:** Clear intent through semantic method names  

---

**Status:** All goal use cases now compile without errors and follow correct repository patterns ✅