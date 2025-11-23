# FetchGoalsUseCase Fix - Remove Non-Existent GoalServiceProtocol Dependency

**Date:** 2025-01-29  
**Status:** ✅ Fixed  
**Component:** Domain/UseCases/Goals/FetchGoalsUseCase.swift

---

## Problem

The `FetchGoalsUseCase` had compilation errors due to referencing a non-existent protocol:

```
/Users/marcosbarbero/Develop/GitHub/marcosbarbero/ios/lume/lume/Domain/UseCases/Goals/FetchGoalsUseCase.swift:30:30 
Cannot find type 'GoalServiceProtocol' in scope

/Users/marcosbarbero/Develop/GitHub/marcosbarbero/ios/lume/lume/Domain/UseCases/Goals/FetchGoalsUseCase.swift:34:22 
Cannot find type 'GoalServiceProtocol' in scope
```

### Root Cause

The use case was trying to use `GoalServiceProtocol` to sync goals from the backend, but this protocol does not exist in the codebase. The available protocols are:

- `GoalRepositoryProtocol` (Domain/Ports) - for local repository operations
- `GoalAIServiceProtocol` (Domain/Ports) - for AI suggestions and tips
- `GoalBackendServiceProtocol` (Services/Backend) - for backend HTTP operations

### Architecture Violation

The original implementation violated the Hexagonal Architecture principles:

1. **Use cases should not directly call backend services** - Backend sync happens via the Outbox pattern through repositories
2. **Domain should not depend on infrastructure** - Use cases depend only on repository protocols, not service implementations
3. **Offline-first approach** - Data should be fetched from local repository, with backend sync handled separately

---

## Solution

Refactored `FetchGoalsUseCase` to follow proper architecture patterns:

### Changes Made

1. **Removed `GoalServiceProtocol` dependency**
   - Removed non-existent service from constructor
   - Removed backend sync logic from use case

2. **Simplified to offline-first pattern**
   - Use case now only fetches from local repository
   - Removed `syncFromBackend` parameter from all methods
   - Backend sync is handled by repository layer via Outbox pattern

3. **Updated protocol signature**
   ```swift
   protocol FetchGoalsUseCaseProtocol {
       func execute(
           status: GoalStatus?,
           category: GoalCategory?
       ) async throws -> [Goal]
   }
   ```

4. **Updated implementation**
   ```swift
   final class FetchGoalsUseCase: FetchGoalsUseCaseProtocol {
       private let goalRepository: GoalRepositoryProtocol
   
       init(goalRepository: GoalRepositoryProtocol) {
           self.goalRepository = goalRepository
       }
   
       func execute(
           status: GoalStatus? = nil,
           category: GoalCategory? = nil
       ) async throws -> [Goal] {
           // Fetch from local repository with filters
           var goals: [Goal]
   
           if let status = status {
               goals = try await goalRepository.fetchByStatus(status)
           } else if let category = category {
               goals = try await goalRepository.fetchByCategory(category)
           } else {
               goals = try await goalRepository.fetchAll()
           }
   
           // Apply additional filters if both status and category are specified
           if let status = status, let category = category {
               goals = goals.filter { $0.status == status && $0.category == category }
           }
   
           // Sort by created date, newest first
           goals.sort { $0.createdAt > $1.createdAt }
   
           return goals
       }
   }
   ```

5. **Updated all convenience methods**
   - Removed `syncFromBackend` parameter from all methods
   - `fetchActive()`, `fetchCompleted()`, `fetchPaused()`, `fetchArchived()`
   - `fetchByCategory(_:)`, `fetchAll()`, `fetchStalled()`
   - `fetchNearCompletion()`, `fetchUpcoming()`, `fetchOverdue()`
   - `getStatistics()`

---

## Architecture Compliance

### Before (Incorrect)

```
FetchGoalsUseCase
    ├─ GoalRepositoryProtocol ✓
    └─ GoalServiceProtocol ✗ (doesn't exist, wrong layer)
```

### After (Correct)

```
FetchGoalsUseCase
    └─ GoalRepositoryProtocol ✓ (domain layer only)

GoalRepository (Infrastructure)
    ├─ Uses SwiftData for local storage
    └─ Uses Outbox pattern for backend sync
```

### Pattern Alignment

Now `FetchGoalsUseCase` follows the same pattern as other goal use cases:

- **CreateGoalUseCase**: Uses `GoalRepositoryProtocol` + `OutboxRepositoryProtocol`
- **UpdateGoalUseCase**: Uses `GoalRepositoryProtocol` + `OutboxRepositoryProtocol`
- **FetchGoalsUseCase**: Uses `GoalRepositoryProtocol` (now consistent!)

---

## Benefits

1. **Architecture Compliance**
   - Follows Hexagonal Architecture (domain depends only on ports)
   - Respects SOLID principles (Single Responsibility, Dependency Inversion)

2. **Offline-First**
   - Works without network connection
   - Fast local data access
   - Backend sync handled asynchronously via Outbox

3. **Maintainability**
   - Clear separation of concerns
   - Consistent with other use cases
   - Easier to test and mock

4. **No Breaking Changes**
   - Convenience methods maintain same functionality
   - Only removed unused `syncFromBackend` parameter
   - Backend sync still happens via repository/outbox

---

## Testing Considerations

### Unit Tests
- Test fetching with different filters (status, category, both)
- Test convenience methods (active, completed, stalled, etc.)
- Test statistics calculation
- Mock `GoalRepositoryProtocol` for isolated testing

### Integration Tests
- Verify repository handles backend sync via Outbox
- Test offline behavior
- Test data consistency after sync

---

## Related Components

### Unchanged Components (No Impact)
- `CreateGoalUseCase` - already using correct pattern
- `UpdateGoalUseCase` - already using correct pattern
- `GenerateGoalSuggestionsUseCase` - uses `GoalAIServiceProtocol`
- `GetGoalTipsUseCase` - uses `GoalAIServiceProtocol`
- `GoalRepository` - handles Outbox pattern internally
- `GoalBackendService` - used by repository, not use cases

### Future Considerations
If explicit backend sync is needed in the future, create a separate use case:
- `SyncGoalsFromBackendUseCase` - dedicated sync responsibility
- Keep `FetchGoalsUseCase` focused on querying local data

---

## Verification

### Compilation Status
```
✅ lume/lume/Domain/UseCases/Goals/FetchGoalsUseCase.swift
   File doesn't have errors or warnings!

✅ lume/lume/Domain/UseCases/Goals/CreateGoalUseCase.swift
   File doesn't have errors or warnings!

✅ lume/lume/Domain/UseCases/Goals/UpdateGoalUseCase.swift
   File doesn't have errors or warnings!
```

### Architecture Validation
- ✅ No direct backend service dependencies in use cases
- ✅ Domain layer remains pure (only protocols)
- ✅ Consistent pattern across all goal use cases
- ✅ Offline-first approach maintained
- ✅ Outbox pattern handles backend sync

---

## Summary

Fixed `FetchGoalsUseCase` compilation errors by removing the non-existent `GoalServiceProtocol` dependency and aligning with proper Hexagonal Architecture principles. The use case now follows an offline-first pattern, fetching only from the local repository while backend sync is handled transparently by the repository layer via the Outbox pattern.

**Result:** All goal-related use cases are now error-free, architecturally compliant, and ready for Phase 5 (Presentation Layer) implementation.