# Outbox Metadata JSON Serialization Fix

**Date:** 2025-01-27  
**Issue:** App crash with `NSInvalidArgumentException: 'Invalid type in JSON write (__SwiftValue)'`  
**Status:** ✅ Resolved

---

## Problem

The app was crashing when saving meal logs due to attempting to serialize Swift enum values directly into JSON metadata for Outbox events.

### Error Message
```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', 
reason: 'Invalid type in JSON write (__SwiftValue)'
```

### Root Cause

When creating Outbox events, metadata is stored as `[String: Any]` and then serialized to JSON for persistence. Swift enum types (even those conforming to `Codable`) cannot be automatically serialized by `JSONSerialization` when embedded in a dictionary of type `[String: Any]`.

**Problematic Code:**
```swift
let metadata: [String: Any] = [
    "mealLogID": mealLog.id.uuidString,
    "mealType": mealLog.mealType,  // ❌ MealType enum - causes crash!
    "rawInput": mealLog.rawInput,
    "loggedAt": ISO8601DateFormatter().string(from: mealLog.loggedAt),
]
```

---

## Solution

Convert all enum values to their raw `String` representation using `.rawValue` before adding to metadata dictionaries.

**Fixed Code:**
```swift
let metadata: [String: Any] = [
    "mealLogID": mealLog.id.uuidString,
    "mealType": mealLog.mealType.rawValue,  // ✅ Convert to String
    "rawInput": mealLog.rawInput,
    "loggedAt": ISO8601DateFormatter().string(from: mealLog.loggedAt),
]
```

---

## Files Fixed

### 1. `SwiftDataMealLogRepository.swift` (Line 75)
**Changed:**
```swift
"mealType": mealLog.mealType.rawValue,
```
**Reason:** `mealLog` is a domain model where `mealType` is a `MealType` enum.

### 2. `SwiftDataProgressRepository.swift` (Line 240)
**Already Correct:**
```swift
"type": progressEntry.type.rawValue,
```
**Reason:** `progressEntry` is a domain model where `type` is a `ProgressMetricType` enum.

**Note:** Lines 107 and 166 use `existing.type` which is already a `String` in the SwiftData schema and does NOT need `.rawValue`.

---

## Pattern to Follow

### ✅ CORRECT - Use `.rawValue` for enums, direct use for strings

```swift
// When working with DOMAIN models (enums):
let metadata: [String: Any] = [
    "mealType": mealLog.mealType.rawValue,           // ✅ MealType enum (domain)
    "status": mealLog.status.rawValue,               // ✅ MealLogStatus enum (domain)
    "progressType": progress.type.rawValue,          // ✅ ProgressMetricType enum (domain)
    "syncStatus": entry.syncStatus.rawValue,         // ✅ SyncStatus enum (domain)
]

// When working with SWIFTDATA models (already strings):
let metadata: [String: Any] = [
    "type": sdProgressEntry.type,                    // ✅ String (SwiftData schema)
    "syncStatus": sdProgressEntry.syncStatus,        // ✅ String (SwiftData schema)
]
```

### ❌ WRONG - Never use enum directly OR .rawValue on strings

```swift
// ❌ Using enum without .rawValue:
let metadata: [String: Any] = [
    "mealType": mealLog.mealType,        // ❌ Enum will crash!
    "status": mealLog.status,            // ❌ Enum will crash!
]

// ❌ Using .rawValue on strings:
let metadata: [String: Any] = [
    "type": sdProgressEntry.type.rawValue,  // ❌ Compile error! It's already a String
]
```

---

## Why This Happens

1. **Swift Enums are Complex Types**: Even `String`-backed enums are Swift value types with metadata beyond their raw value.

2. **JSONSerialization Limitations**: Foundation's `JSONSerialization` only supports these types directly:
   - `String`
   - `Number` (Int, Double, Bool)
   - `Dictionary<String, Any>`
   - `Array<Any>`
   - `NSNull`

3. **Type Erasure in [String: Any]**: When you put an enum into `[String: Any]`, Swift wraps it in `__SwiftValue`, which `JSONSerialization` cannot handle.

4. **Domain vs SwiftData Models**: 
   - **Domain models** use Swift enums for type safety (`MealType`, `ProgressMetricType`)
   - **SwiftData models** store these as `String` for persistence compatibility
   - When creating metadata from domain models, use `.rawValue`
   - When creating metadata from SwiftData models, use the string directly

---

## Prevention Checklist

When creating Outbox metadata:

- [ ] Check all dictionary values for enum types
- [ ] Convert enums to `.rawValue` (for `String` enums)
- [ ] Convert dates to ISO8601 strings or `TimeInterval`
- [ ] Convert UUIDs to `.uuidString`
- [ ] Convert booleans and numbers directly (no conversion needed)
- [ ] Test with actual data to ensure JSON serialization works

---

## Testing

### Before Fix
```
Saving meal log → Creating outbox event → CRASH 💥
```

### After Fix
```
Saving meal log → Creating outbox event → Success ✅
Outbox event persisted to SwiftData
Background sync processes event successfully
```

---

## Related Enums in Codebase

All these enums require `.rawValue` when used in Outbox metadata **from domain models**:

| Enum | Location | Raw Type |
|------|----------|----------|
| `MealType` | `Domain/Entities/MealModels.swift` | `String` |
| `MealLogStatus` | `Domain/Entities/Nutrition/MealLogEntities.swift` | `String` |
| `ProgressMetricType` | `Domain/Entities/Progress/ProgressMetricType.swift` | `String` |
| `SyncStatus` | `Domain/Entities/Progress/SyncStatus.swift` | `String` |
| `OutboxEventType` | `Domain/Entities/Outbox/OutboxEventTypes.swift` | `String` |
| `OutboxEventStatus` | `Domain/Entities/Outbox/OutboxEventTypes.swift` | `String` |
| `SleepStageType` | `Domain/Entities/Sleep/SDSleepSession.swift` | `String` |
| `MoodSourceType` | `Domain/Entities/Mood/MoodSourceType.swift` | `String` |

---

## Key Takeaways

1. **Always convert Swift enums to their primitive raw values when storing in `[String: Any]` dictionaries that will be JSON-serialized.**

2. **Know your model types:**
   - **Domain models** (e.g., `MealLog`, `ProgressEntry`) → Use `.rawValue` on enum properties
   - **SwiftData models** (e.g., `SDMealLog`, `SDProgressEntry`) → Already strings, use directly

3. **This is especially critical in:**
   - Outbox event metadata
   - UserDefaults storage
   - Network request bodies
   - Any JSON serialization context

---

## Future Improvements

Consider creating a type-safe metadata builder:

```swift
struct OutboxMetadata {
    private var data: [String: Any] = [:]
    
    mutating func set<T: RawRepresentable>(_ key: String, enum value: T) where T.RawValue == String {
        data[key] = value.rawValue
    }
    
    mutating func set(_ key: String, string value: String) {
        data[key] = value
    }
    
    mutating func set(_ key: String, date value: Date) {
        data[key] = ISO8601DateFormatter().string(from: value)
    }
    
    func build() -> [String: Any] {
        return data
    }
}

// Usage
var metadata = OutboxMetadata()
metadata.set("mealType", enum: mealLog.mealType)  // ✅ Type-safe, auto-converts
metadata.set("loggedAt", date: mealLog.loggedAt)
let dict = metadata.build()
```

---

**Status:** ✅ Fixed  
**Verified:** No compilation errors, app runs successfully  
**Tested:** Meal log saving with Outbox Pattern works correctly