# SwiftData KeyPath Predicate Fix

**Date:** 2025-01-27  
**Status:** ✅ Fixed  
**Severity:** Critical (Runtime Crash)

---

## Problem

The app was crashing on launch with the following fatal error:

```
SwiftData/Schema.swift:336: Fatal error: Invalid KeyPath id.uuidString on SDUserProfileV9 
points to a value type: UUID but has additional descendant: uuidString
```

---

## Root Cause

SwiftData predicates cannot use computed properties in KeyPath chains. The issue occurred in `SwiftDataProgressRepository.swift` where predicates were trying to access `userProfile?.id.uuidString`:

```swift
// ❌ INVALID - Cannot use .uuidString in predicate
let predicate = #Predicate<SDProgressEntry> { entry in
    entry.userProfile?.id.uuidString == userID  // CRASH!
}
```

**Why this fails:**
- `.uuidString` is a **computed property** on `UUID`
- SwiftData/CloudKit predicates only support **stored properties**
- KeyPath chaining to computed properties causes a compiler/runtime error

---

## Solution

Convert the `String` userID to `UUID` **before** the predicate, then compare `UUID` values directly:

```swift
// ✅ CORRECT - Convert to UUID first, then compare
guard let userUUID = UUID(uuidString: userID) else {
    throw ProgressRepositoryError.invalidUserID
}

let predicate = #Predicate<SDProgressEntry> { entry in
    entry.userProfile?.id == userUUID  // Direct UUID comparison
}
```

---

## Files Changed

### `SwiftDataProgressRepository.swift`

Fixed **11 predicate instances** across the following methods:

1. **`save(progressEntry:forUserID:)`** - 2 predicates (with/without time field)
2. **`fetchRecent(forUserID:type:startDate:endDate:limit:)`** - 2 predicates (with/without type filter)
3. **`fetchLatestEntryDate(forUserID:type:)`** - 1 predicate
4. **`updateBackendID(forLocalID:backendID:forUserID:)`** - 1 predicate
5. **`updateSyncStatus(forLocalID:status:forUserID:)`** - 1 predicate
6. **`deleteAll(forUserID:type:)`** - 1 predicate
7. **`delete(progressEntryID:forUserID:)`** - 1 predicate
8. **`removeDuplicates(forUserID:type:)`** - 1 predicate

### `SchemaCompatibilityLayer.swift`

Fixed **1 predicate instance** in:

1. **`safeFetchProgressEntries(from:userID:type:syncStatus:limit:)`** - 1 predicate

Also added `SchemaCompatibilityError.invalidUserID` error case for proper error handling.

**Note:** The `fallbackFetchProgressEntries` and `fallbackDeleteProgressEntries` methods use `.uuidString` in regular Swift `filter` closures, which is allowed (only predicates are restricted).

### Error Handling

Added new error case:

```swift
enum ProgressRepositoryError: Error, LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case entryNotFound
    case invalidUserID  // ✅ NEW
    
    var errorDescription: String? {
        switch self {
        // ...
        case .invalidUserID:
            return "Invalid user ID format"
        }
    }
}

// In SchemaCompatibilityLayer.swift
enum SchemaCompatibilityError: Error, LocalizedError {
    case invalidUserID
    case incompatibleSchema(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidUserID:
            return "Invalid user ID format for schema compatibility layer"
        case .incompatibleSchema(let error):
            return "Incompatible schema: \(error.localizedDescription)"
        }
    }
}
```

---

## Pattern to Follow

**Whenever you need to compare a relationship's UUID in a SwiftData predicate:**

### ❌ DON'T DO THIS:
```swift
// Invalid - computed property in predicate
let predicate = #Predicate<SDModel> { model in
    model.relationship?.id.uuidString == someStringID
}
```

### ✅ DO THIS:
```swift
// Valid - convert to UUID first
guard let uuid = UUID(uuidString: someStringID) else {
    throw SomeError.invalidID
}

let predicate = #Predicate<SDModel> { model in
    model.relationship?.id == uuid  // Direct UUID comparison
}
```

---

## Why This Pattern is Safe

1. **UUID Validation**: `UUID(uuidString:)` validates the string format
2. **Early Failure**: Fails fast with clear error if ID is invalid
3. **SwiftData Compatible**: Compares stored properties only
4. **CloudKit Compatible**: Works with CloudKit sync
5. **Type Safe**: Compiler enforces UUID comparison

---

## Related Files

### Files Using `.uuidString` Safely

These files use `.uuidString` in **non-predicate contexts** (data conversion), which is fine:

- `PersistenceHelper.swift` - Domain model conversions
- `RemoteHealthDataSyncClient.swift` - API request DTOs
- `OutboxProcessorService.swift` - Logging and service calls
- `KeychainAuthTokenAdapter.swift` - Keychain storage
- Various use cases - Parameter passing

**Rule:** `.uuidString` is only problematic **inside `#Predicate` macros**.

---

## Testing

After the fix:

- ✅ App launches successfully
- ✅ No SwiftData/CloudKit errors
- ✅ All predicates compile and run correctly
- ✅ Progress tracking works as expected
- ✅ Outbox processing continues normally
- ✅ Schema compatibility layer works correctly
- ✅ Data fetching and deletion operations work as expected

---

## Prevention

**When writing SwiftData predicates:**

1. **Never use computed properties** in KeyPath chains
2. **Convert external IDs to proper types** before predicates
3. **Compare stored properties directly** (e.g., `id == uuid`, not `id.uuidString == string`)
4. **Test with CloudKit enabled** to catch these errors early

---

## Important Notes

### What's Allowed vs. Not Allowed

**❌ NOT ALLOWED - `.uuidString` in predicates:**
```swift
let predicate = #Predicate<SDModel> { model in
    model.relationship?.id.uuidString == someString  // CRASH!
}
```

**✅ ALLOWED - `.uuidString` in regular Swift code:**
```swift
let filtered = allEntries.filter { entry in
    entry.userProfile?.id.uuidString == userID  // OK - regular closure
}
```

The restriction **only applies to `#Predicate` macros**, not regular Swift closures.

---

## Key Takeaway

**SwiftData predicates must use stored properties only. Convert external string IDs to UUIDs before predicate comparison, not inside the predicate closure.**

---

**Status:** 🟢 **Production Ready - All SwiftData predicates are now CloudKit-compatible**