# Outbox Metadata Guidelines

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Guidelines for safely constructing metadata dictionaries for Outbox events

---

## Overview

Outbox event metadata is stored as `[String: Any]` and must be JSON-serializable for persistence in SwiftData. This document provides guidelines for safely constructing metadata to avoid runtime crashes.

---

## Critical Rule

**🚨 NEVER pass Swift enum types directly into metadata dictionaries!**

Swift enums (even `String`-backed ones) will cause a crash with:
```
NSInvalidArgumentException: 'Invalid type in JSON write (__SwiftValue)'
```

---

## Safe Types for Metadata

### ✅ Allowed Types

| Type | Example | Notes |
|------|---------|-------|
| `String` | `"breakfast"` | Direct use |
| `Int` | `42` | Direct use |
| `Double` | `3.14` | Direct use |
| `Bool` | `true` | Direct use |
| `String` (from UUID) | `uuid.uuidString` | Must convert |
| `String` (from Date) | `ISO8601DateFormatter().string(from: date)` | Must convert |
| `TimeInterval` (from Date) | `date.timeIntervalSince1970` | Alternative to ISO8601 |
| `String` (from enum) | `mealType.rawValue` | **MUST use .rawValue** |
| `[String: Any]` | Nested dictionaries | Must follow same rules |
| `[Any]` | Arrays | Must follow same rules |

### ❌ Forbidden Types

| Type | Why | Solution |
|------|-----|----------|
| Swift Enum | Not JSON-serializable | Use `.rawValue` |
| UUID | Not JSON-serializable | Use `.uuidString` |
| Date | Not JSON-serializable | Use ISO8601 string or `timeIntervalSince1970` |
| Custom Structs | Not JSON-serializable | Convert to dictionary or JSON string |
| Optionals | Can cause issues | Unwrap or omit from dictionary |

---

## Domain Models vs SwiftData Models

**CRITICAL DISTINCTION:** Know whether you're working with domain models or SwiftData models!

### Domain Models (Enums → `.rawValue` Required)

Domain models use Swift enums for type safety:
- `MealLog` has `mealType: MealType` (enum)
- `ProgressEntry` has `type: ProgressMetricType` (enum)
- These **REQUIRE** `.rawValue` in metadata

### SwiftData Models (Already Strings)

SwiftData models store these as `String` for persistence:
- `SDMealLog` has `mealType: String` 
- `SDProgressEntry` has `type: String`
- These are **ALREADY** strings, use directly

### Quick Reference

```swift
// ✅ Domain model → Use .rawValue
let domainMealLog: MealLog = ...
metadata["mealType"] = domainMealLog.mealType.rawValue  // MealType enum → String

// ✅ SwiftData model → Use directly
let sdMealLog: SDMealLog = ...
metadata["mealType"] = sdMealLog.mealType  // Already a String

// ❌ WRONG - .rawValue on String
let sdMealLog: SDMealLog = ...
metadata["mealType"] = sdMealLog.mealType.rawValue  // Compile error!
```

---

## Pattern Examples

### Example 1: Meal Log Metadata

```swift
// ✅ CORRECT
let metadata: [String: Any] = [
    "mealLogID": mealLog.id.uuidString,                          // UUID → String
    "mealType": mealLog.mealType.rawValue,                       // Enum → String
    "rawInput": mealLog.rawInput,                                // String (direct)
    "loggedAt": ISO8601DateFormatter().string(from: mealLog.loggedAt),  // Date → String
    "hasNotes": mealLog.notes != nil,                            // Bool (direct)
]

// ❌ WRONG - Using types directly
let metadata: [String: Any] = [
    "mealLogID": mealLog.id,              // ❌ UUID will crash
    "mealType": mealLog.mealType,         // ❌ Enum will crash (domain model)
    "loggedAt": mealLog.loggedAt,         // ❌ Date will crash
    "notes": mealLog.notes,               // ❌ Optional String can cause issues
]

// ❌ WRONG - Using .rawValue on String
let sdMealLog: SDMealLog = ...
let metadata: [String: Any] = [
    "mealType": sdMealLog.mealType.rawValue,  // ❌ Compile error! Already a String
]
```</parameter>

<old_text line=77>
### Example 2: Progress Entry Metadata

```swift
// ✅ CORRECT
let metadata: [String: Any] = [
    "type": progressEntry.type.rawValue,                         // Enum → String
    "quantity": progressEntry.quantity,                          // Double (direct)
    "date": progressEntry.date.timeIntervalSince1970,           // Date → TimeInterval
    "hasBackendID": progressEntry.backendID != nil,             // Bool (direct)
]</parameter>
```

### Example 2: Progress Entry Metadata

```swift
// ✅ CORRECT
let metadata: [String: Any] = [
    "type": progressEntry.type.rawValue,                         // Enum → String
    "quantity": progressEntry.quantity,                          // Double (direct)
    "date": progressEntry.date.timeIntervalSince1970,           // Date → TimeInterval
    "hasBackendID": progressEntry.backendID != nil,             // Bool (direct)
]

// If you need to include optional values:
var metadata: [String: Any] = [
    "type": progressEntry.type.rawValue,
    "quantity": progressEntry.quantity,
    "date": progressEntry.date.timeIntervalSince1970,
]

if let backendID = progressEntry.backendID {
    metadata["backendID"] = backendID  // Only add if non-nil
}
```

### Example 3: Sleep Session Metadata

```swift
// ✅ CORRECT
let metadata: [String: Any] = [
    "sessionID": session.id.uuidString,                          // UUID → String
    "startTime": ISO8601DateFormatter().string(from: session.startTime),
    "endTime": ISO8601DateFormatter().string(from: session.endTime),
    "duration": session.duration,                                // Double (direct)
    "stageCount": session.stages.count,                          // Int (direct)
]
```

---

## Common Enums in FitIQ

These enums require `.rawValue` when used in metadata:

### Nutrition
- `MealType` → `mealType.rawValue`
- `MealLogStatus` → `status.rawValue`

### Progress Tracking
- `ProgressMetricType` → `type.rawValue`
- `SyncStatus` → `syncStatus.rawValue`

### Outbox
- `OutboxEventType` → `eventType.rawValue`
- `OutboxEventStatus` → `status.rawValue`

### Sleep
- `SleepStageType` → `stageType.rawValue`

### Mood
- `MoodSourceType` → `sourceType.rawValue`

---

## Date Formatting

Choose the appropriate format based on your needs:

### ISO8601 String (Recommended for human readability)
```swift
let dateString = ISO8601DateFormatter().string(from: date)
// Example: "2025-01-27T10:30:00Z"
```

### Unix Timestamp (Recommended for calculations)
```swift
let timestamp = date.timeIntervalSince1970
// Example: 1706351400.0
```

---

## Validation Checklist

Before creating metadata for an Outbox event:

- [ ] Are all enum values converted to `.rawValue`?
- [ ] Are all UUIDs converted to `.uuidString`?
- [ ] Are all Dates converted to ISO8601 strings or `timeIntervalSince1970`?
- [ ] Are optionals either unwrapped or conditionally added?
- [ ] Are all values JSON-serializable primitive types?
- [ ] Have you tested with actual data (not just compilation)?

---

## Testing Metadata

### Quick Test Pattern

```swift
func testMetadataSerialization() {
    let metadata: [String: Any] = [
        "mealType": mealLog.mealType.rawValue,
        "loggedAt": ISO8601DateFormatter().string(from: mealLog.loggedAt),
    ]
    
    // This should not throw
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: metadata)
        print("✅ Metadata is valid JSON")
    } catch {
        print("❌ Metadata is NOT valid JSON: \(error)")
        XCTFail("Metadata serialization failed: \(error)")
    }
}
```

---

## Error Debugging

### If you see: `Invalid type in JSON write (__SwiftValue)`

1. **Find the problematic key:**
   - Add print statements before creating metadata
   - Check recent changes to metadata dictionaries
   
2. **Check for these culprits:**
   - Enum values without `.rawValue` (in domain models)
   - Using `.rawValue` on strings (in SwiftData models)
   - UUID without `.uuidString`
   - Date without conversion
   - Custom struct/class instances

3. **Fix pattern:**
   ```swift
   // Domain model (crashes):
   "key": domainModel.enumProperty
   
   // Domain model (works):
   "key": domainModel.enumProperty.rawValue
   
   // SwiftData model (compile error):
   "key": sdModel.stringProperty.rawValue
   
   // SwiftData model (works):
   "key": sdModel.stringProperty
   ```</parameter>

<old_text line=282>
**Remember:** When in doubt, convert to primitive types (String, Int, Double, Bool) before adding to metadata!</parameter>
   ```

---

## Future Improvements

### Type-Safe Metadata Builder (Proposed)

```swift
struct OutboxMetadata {
    private var data: [String: Any] = [:]
    
    mutating func set<T: RawRepresentable>(_ key: String, enum value: T) 
        where T.RawValue == String 
    {
        data[key] = value.rawValue
    }
    
    mutating func set(_ key: String, string value: String) {
        data[key] = value
    }
    
    mutating func set(_ key: String, uuid value: UUID) {
        data[key] = value.uuidString
    }
    
    mutating func set(_ key: String, date value: Date, format: DateFormat = .iso8601) {
        switch format {
        case .iso8601:
            data[key] = ISO8601DateFormatter().string(from: value)
        case .unixTimestamp:
            data[key] = value.timeIntervalSince1970
        }
    }
    
    mutating func set(_ key: String, number value: Double) {
        data[key] = value
    }
    
    mutating func set(_ key: String, bool value: Bool) {
        data[key] = value
    }
    
    func build() -> [String: Any] {
        return data
    }
}

enum DateFormat {
    case iso8601
    case unixTimestamp
}

// Usage:
var metadata = OutboxMetadata()
metadata.set("mealType", enum: mealLog.mealType)    // ✅ Automatically converts
metadata.set("loggedAt", date: mealLog.loggedAt)
metadata.set("quantity", number: 150.5)
let dict = metadata.build()
```

This would provide compile-time safety and prevent runtime crashes.

---

## Related Documentation

- [Outbox Pattern Documentation](./OUTBOX_PATTERN.md)
- [JSON Serialization Fix](../fixes/OUTBOX_METADATA_JSON_SERIALIZATION_FIX.md)
- [Repository Pattern Guidelines](./REPOSITORY_PATTERN.md)

---

**Remember:** When in doubt, convert to primitive types (String, Int, Double, Bool) before adding to metadata!

---

**Status:** ✅ Active  
**Enforcement:** Mandatory for all Outbox event creation