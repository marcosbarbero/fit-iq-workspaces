# Centralized User ID Management for Repositories

**Created:** 2025-01-29  
**Status:** ✅ Implemented  
**Affected Components:** All Data Layer Repositories

---

## Overview

This document describes the centralized approach to user ID management across all repositories in the Lume app. Prior to this implementation, each repository had its own `getCurrentUserId()` method with varying implementations, leading to inconsistencies and critical bugs.

---

## Problem Statement

### Issues with Decentralized Approach

Before centralization, repositories used different methods to get the current user ID:

1. **AIInsightRepository** (BROKEN):
   ```swift
   private func getCurrentUserId() async throws -> UUID {
       return UUID()  // ❌ New random UUID every time!
   }
   ```

2. **GoalRepository** (OVERLY COMPLEX):
   ```swift
   private func getCurrentUserId() async throws -> UUID {
       // Parse JWT token, decode base64url, extract user ID
       // 40+ lines of complex, error-prone code
       // Falls back to hardcoded UUID on failure
   }
   ```

3. **ChatRepository, MoodRepository, JournalRepository** (CORRECT):
   ```swift
   private func getCurrentUserId() async throws -> UUID {
       return try UserSession.shared.requireUserId()
   }
   ```

### Critical Bug Impact

The AIInsightRepository bug caused **100% failure of insights persistence**:
- Insights saved with backend user ID (`15d3af32-...`)
- Queries used random UUID (`A1B2C3D4-...`)
- Result: Saved insights could never be retrieved
- Impact: Backend called on every dashboard visit instead of using cache

---

## Solution: UserAuthenticatedRepository Protocol

### Protocol Definition

```swift
/// Centralized authentication helper for all repositories
protocol UserAuthenticatedRepository {
    /// Get the current authenticated user's ID
    func getCurrentUserId() throws -> UUID
}
```

### Default Implementation

```swift
extension UserAuthenticatedRepository {
    /// Default implementation using UserSession
    func getCurrentUserId() throws -> UUID {
        guard let userId = UserSession.shared.currentUserId else {
            print("❌ [\(String(describing: Self.self))] No user ID in session")
            throw RepositoryAuthError.notAuthenticated
        }
        return userId
    }
}
```

### Async/Sync Compatibility

**Note:** The synchronous `getCurrentUserId()` works perfectly in async contexts. Swift allows calling synchronous throwing functions with `try` in async methods. Since `UserSession.currentUserId` is a simple property access (thread-safe), there's no need for a separate async implementation.

```swift
// Works in both sync and async contexts
func fetchData() async throws -> [Data] {
    let userId = try getCurrentUserId()  // ✅ No 'await' needed
    // Use userId
}
```

---

## Architecture

### Single Source of Truth

```
┌─────────────────────────────────────────┐
│        UserSession.shared               │
│  (UserDefaults-backed, thread-safe)     │
│                                         │
│  currentUserId: UUID?                   │
└─────────────────┬───────────────────────┘
                  │
                  │ accessed by
                  ▼
┌─────────────────────────────────────────┐
│  UserAuthenticatedRepository Protocol   │
│                                         │
│  + getCurrentUserId() throws -> UUID    │
│  + getCurrentUserId() async throws      │
└─────────────────┬───────────────────────┘
                  │
                  │ conforms to
                  ▼
┌─────────────────────────────────────────┐
│          All Repositories               │
│                                         │
│  • AIInsightRepository                  │
│  • ChatRepository                       │
│  • GoalRepository                       │
│  • MoodRepository                       │
│  • SwiftDataJournalRepository           │
│  • StatisticsRepository                 │
└─────────────────────────────────────────┘
```

---

## Implementation

### File Location

`lume/lume/Data/Repositories/RepositoryUserSession.swift`

### Repository Adoption

#### Step 1: Add Protocol Conformance

```swift
// BEFORE
final class MyRepository: MyRepositoryProtocol {
    // ...
}

// AFTER
final class MyRepository: MyRepositoryProtocol, UserAuthenticatedRepository {
    // ...
}
```

#### Step 2: Remove Custom Implementation

```swift
// DELETE THIS:
private func getCurrentUserId() async throws -> UUID {
    // Any custom implementation
}

// ADD THIS (optional comment):
// getCurrentUserId() is provided by UserAuthenticatedRepository protocol
```

#### Step 3: Use in Repository Methods

```swift
func fetchAll() async throws -> [MyEntity] {
    // Get user ID (throws if not authenticated)
    let userId = try await getCurrentUserId()
    
    let descriptor = FetchDescriptor<SDMyEntity>(
        predicate: #Predicate { $0.userId == userId }
    )
    
    return try modelContext.fetch(descriptor).map(toDomain)
}
```

---

## Migrated Repositories

### ✅ AIInsightRepository
- **Before**: Generated random UUID on every call (CRITICAL BUG)
- **After**: Uses UserSession.shared.currentUserId
- **Impact**: Fixed insights persistence completely

### ✅ GoalRepository
- **Before**: 40+ lines of JWT parsing with fallback UUID
- **After**: Uses protocol default implementation
- **Impact**: Removed complex, error-prone code

### ✅ ChatRepository
- **Before**: Called UserSession.shared.requireUserId() directly
- **After**: Uses protocol (same underlying implementation)
- **Impact**: Standardized interface

### ✅ MoodRepository
- **Before**: Called UserSession.shared.requireUserId() directly
- **After**: Uses protocol (same underlying implementation)
- **Impact**: Standardized interface

### ✅ SwiftDataJournalRepository
- **Before**: Called UserSession.shared.requireUserId() directly
- **After**: Uses protocol (same underlying implementation)
- **Impact**: Standardized interface

### ✅ StatisticsRepository
- **Before**: Directly accessed UserSession.shared.currentUserId
- **After**: Uses protocol via getCurrentUserId()
- **Impact**: Consistent error handling and interface

---

## Benefits

### 1. Consistency
- **One implementation** across all repositories
- **No duplicate code** or logic drift
- **Single source of truth** for user authentication

### 2. Reliability
- **No random UUIDs** breaking persistence
- **No complex JWT parsing** that can fail
- **Thread-safe** access via UserSession's dispatch queue

### 3. Maintainability
- **Easy to update** - change in one place affects all repositories
- **Clear interface** - protocol makes intent explicit
- **Self-documenting** - protocol name explains purpose

### 4. Testability
- **Mock UserSession** for unit tests
- **Inject test user IDs** easily
- **Test authentication errors** consistently

### 5. Error Handling
- **Consistent error type** (RepositoryAuthError.notAuthenticated)
- **Clear error messages** with repository name in logs
- **Predictable failure behavior**

---

## UserSession Integration

### How UserSession Works

```swift
final class UserSession {
    static let shared = UserSession()
    
    // Thread-safe property using dispatch queue
    var currentUserId: UUID? {
        queue.sync {
            guard let uuidString = userDefaults.string(forKey: Keys.userId) else {
                return nil
            }
            return UUID(uuidString: uuidString)
        }
    }
    
    // Throws if not authenticated
    func requireUserId() throws -> UUID {
        guard let userId = currentUserId else {
            throw UserSessionError.notAuthenticated
        }
        return userId
    }
}
```

### Session Lifecycle

1. **Login**: `UserSession.shared.startSession(userId:email:name:)`
2. **Access**: `UserSession.shared.currentUserId` (optional) or `requireUserId()` (throws)
3. **Logout**: `UserSession.shared.endSession()`

### Storage

- **Backend**: UserDefaults (persistent across app launches)
- **Key**: `"lume.user.id"`
- **Thread Safety**: Dispatch queue with concurrent reads, barrier writes

---

## Error Handling

### RepositoryAuthError

```swift
enum RepositoryAuthError: LocalizedError {
    case notAuthenticated
    case invalidUserId
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No user is currently authenticated. Please log in."
        case .invalidUserId:
            return "Invalid user ID format in session."
        case .sessionExpired:
            return "User session has expired. Please log in again."
        }
    }
}
```

### Catching in Repositories

```swift
func fetchData() async throws -> [Data] {
    do {
        let userId = try getCurrentUserId()
        // Use userId
    } catch {
        // Re-throw as repository-specific error if needed
        throw MyRepositoryError.notAuthenticated
    }
}
```

---

## Helper Methods

### Logging

```swift
func logUserOperation(_ operation: String) {
    if let userId = UserSession.shared.currentUserId {
        print("👤 [\(Self.self)] \(operation) for user: \(userId)")
    } else {
        print("⚠️ [\(Self.self)] \(operation) - no user in session")
    }
}
```

### Authentication Check

```swift
func isUserAuthenticated() -> Bool {
    UserSession.shared.currentUserId != nil
}
```

---

## Testing

### Mock UserSession for Tests

```swift
// Set test user
UserSession.shared.startSession(
    userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    email: "test@example.com",
    name: "Test User"
)

// Run tests
let repository = MyRepository(...)
let data = try await repository.fetchAll()

// Clean up
UserSession.shared.endSession()
```

### Test Unauthenticated State

```swift
// Ensure no user is logged in
UserSession.shared.endSession()

// Expect error
do {
    let data = try await repository.fetchAll()
    XCTFail("Should have thrown notAuthenticated error")
} catch RepositoryAuthError.notAuthenticated {
    // Expected
} catch {
    XCTFail("Wrong error type: \(error)")
}
```

---

## Performance

### No Performance Impact

- `currentUserId` is a simple UserDefaults read (cached by system)
- Dispatch queue sync is extremely fast (nanoseconds)
- No network calls or heavy computation
- Called once per repository method (not in loops)

### Before vs After

| Repository | Before | After | Lines Removed |
|------------|--------|-------|---------------|
| AIInsightRepository | Random UUID (broken) | Protocol | 8 lines |
| GoalRepository | JWT parsing | Protocol | 43 lines |
| ChatRepository | Direct call | Protocol | 5 lines |
| MoodRepository | Direct call | Protocol | 4 lines |
| JournalRepository | Direct call | Protocol | 4 lines |
| StatisticsRepository | Direct UserSession access | Protocol | 6 lines |
| **Total** | - | - | **70 lines** |

---

## Future Enhancements

### 1. Caching User ID in Repositories

For very high-frequency operations, could cache user ID:

```swift
final class MyRepository: UserAuthenticatedRepository {
    private var cachedUserId: UUID?
    
    func getCurrentUserId() throws -> UUID {
        if let cached = cachedUserId {
            return cached
        }
        let userId = try UserSession.shared.currentUserId ?? throw(...)
        cachedUserId = userId
        return userId
    }
    
    func invalidateUserCache() {
        cachedUserId = nil
    }
}
```

### 2. User Context Object

Instead of just UUID, pass full user context:

```swift
struct UserContext {
    let id: UUID
    let email: String
    let name: String
    let preferences: UserPreferences
}

protocol UserAuthenticatedRepository {
    func getCurrentUserContext() throws -> UserContext
}
```

### 3. Multi-User Support

For future iPad multi-user scenarios:

```swift
protocol UserAuthenticatedRepository {
    var currentUserId: UUID? { get set }
    func switchUser(to userId: UUID)
}
```

---

## Related Documentation

- `docs/fixes/DASHBOARD_EMPTY_STATE_FIX.md` - Critical bug fix that led to this centralization
- `docs/fixes/CRITICAL_USER_ID_PERSISTENCE_BUG.md` - Detailed analysis of random UUID bug
- `Core/UserSession.swift` - UserSession implementation
- `Data/Repositories/RepositoryUserSession.swift` - Protocol definition

---

## Migration Checklist

When creating a new repository:

- [ ] Conform to `UserAuthenticatedRepository` protocol
- [ ] Do NOT implement `getCurrentUserId()` manually
- [ ] Call `getCurrentUserId()` in methods that need user filtering (works in both sync and async)
- [ ] Handle `RepositoryAuthError.notAuthenticated` appropriately
- [ ] Never access `UserSession.shared.currentUserId` directly - always use `getCurrentUserId()`
- [ ] Add unit tests for authenticated and unauthenticated states
- [ ] Document user-scoped operations in repository comments

---

**Status**: ✅ All repositories migrated and tested  
**Repositories Migrated**: 6 (AIInsight, Goal, Chat, Mood, Journal, Statistics)  
**Lines of Code Removed**: 70  
**Last Updated**: 2025-01-29  
**Owner**: Data Layer Team