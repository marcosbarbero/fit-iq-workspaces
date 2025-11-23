# Meal Log API Response and SwiftData Predicate Fix

**Date:** 2025-01-27  
**Issues:** 
1. API response parsing error (keyNotFound: "entries")
2. SwiftData predicate error with enum types
**Status:** ✅ Resolved

---

## Problems

### Problem 1: API Response Parsing Error

```
NutritionAPIClient: ❌ JSON decode error: keyNotFound(CodingKeys(stringValue: "entries", intValue: nil), ...)
NutritionAPIClient: Response body: {"data":{"meal_logs":[],"total_count":0,"limit":50,"offset":0,"has_more":false}}
```

**Root Cause:** Backend API returns:
- `meal_logs` (not `entries`)
- `total_count` (not `total`)

But the iOS client was expecting:
- `entries`
- `total`

### Problem 2: SwiftData Predicate Error

```
NutritionViewModel: Failed to load meals: SwiftDataError(_error: SwiftData.SwiftDataError._Error.unsupportedPredicate, 
_explanation: Optional("Unsupported Predicate: Captured/constant values of type 'MealLogStatus' are not supported"))
```

**Root Cause:** SwiftData predicates cannot directly capture enum values. Even though `SDMeal` stores enums in the schema, when building predicates with captured values, you must convert enums to their raw values first.

---

## Solutions

### Fix 1a: Add APIDataWrapper for Backend Response Structure

**File:** `Infrastructure/Network/NutritionAPIClient.swift` (Lines 392-394)

**Problem:** Backend wraps responses in a `"data"` field:
```json
{
  "data": {
    "meal_logs": [],
    "total_count": 0,
    ...
  }
}
```

**Solution:** Added `APIDataWrapper<T>` generic struct to unwrap the `"data"` field:

```swift
/// Wrapper for backend API responses that include a "data" field
struct APIDataWrapper<T: Codable>: Codable {
    let data: T
}
```

**Usage in getMealLogs:**
```swift
// Before:
let response: MealLogListAPIResponse = try await executeWithRetry(...)
return response.entries

// After:
let wrapper: APIDataWrapper<MealLogListAPIResponse> = try await executeWithRetry(...)
return wrapper.data.entries
```

### Fix 1b: Update API Response CodingKeys

**File:** `Infrastructure/Network/NutritionAPIClient.swift` (Lines 401-402)

**Before:**
```swift
enum CodingKeys: String, CodingKey {
    case entries
    case total
    case limit
    case offset
}
```

**After:**
```swift
enum CodingKeys: String, CodingKey {
    case entries = "meal_logs"       // ✅ Map to backend field name
    case total = "total_count"       // ✅ Map to backend field name
    case limit
    case offset
}
```

### Fix 2: Filter Enums in Memory Instead of in Predicate

**File:** `Infrastructure/Repositories/SwiftDataMealLogRepository.swift` (Lines 111-163)

**Problem:** SwiftData's `#Predicate` macro cannot capture enum values from outside the closure, even when converted to raw values.

**Solution:** Filter by user and dates in the predicate, then filter by status/syncStatus in memory.

**Before:**
```swift
// Build predicate based on filters
var predicates: [Predicate<SDMealLog>] = []

// User filter (required)
predicates.append(#Predicate { $0.userProfile?.id == userUUID })

// Status filter
if let status = status {
    predicates.append(#Predicate { $0.status == status })  // ❌ Predicate macro error
}

// Sync status filter
if let status = syncStatus {
    predicates.append(#Predicate { $0.syncStatus == status })  // ❌ Predicate macro error
}

// Combine predicates...
let sdMealLogs = try modelContext.fetch(descriptor)
```

**After:**
```swift
// Build predicate for user and date filters only
// (Status and syncStatus will be filtered in memory)
var descriptor: FetchDescriptor<SDMealLog>

switch (startDate, endDate) {
case (.some(let start), .some(let end)):
    descriptor = FetchDescriptor<SDMealLog>(
        predicate: #Predicate { meal in
            meal.userProfile?.id == userUUID
                && meal.loggedAt >= start
                && meal.loggedAt <= end
        },
        sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
case (.some(let start), nil):
    descriptor = FetchDescriptor<SDMealLog>(
        predicate: #Predicate { meal in
            meal.userProfile?.id == userUUID && meal.loggedAt >= start
        },
        sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
case (nil, .some(let end)):
    descriptor = FetchDescriptor<SDMealLog>(
        predicate: #Predicate { meal in
            meal.userProfile?.id == userUUID && meal.loggedAt <= end
        },
        sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
case (nil, nil):
    descriptor = FetchDescriptor<SDMealLog>(
        predicate: #Predicate { meal in
            meal.userProfile?.id == userUUID
        },
        sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
    )
}

var sdMealLogs = try modelContext.fetch(descriptor)

// ✅ Filter by status in memory if provided
if let status = status {
    sdMealLogs = sdMealLogs.filter { $0.status == status }
}

// ✅ Filter by syncStatus in memory if provided
if let syncStatus = syncStatus {
    sdMealLogs = sdMealLogs.filter { $0.syncStatus == syncStatus }
}
```

---

## Why These Fixes Work

### Fix 1a: APIDataWrapper Pattern

Backend APIs often wrap responses in a `"data"` field for consistency. Instead of creating separate wrapper types for each endpoint, we use a generic wrapper:

```swift
struct APIDataWrapper<T: Codable>: Codable {
    let data: T
}
```

This allows us to decode any response type wrapped in a `"data"` field:

```swift
let wrapper: APIDataWrapper<MealLogListAPIResponse> = try await executeWithRetry(...)
// wrapper.data contains the actual MealLogListAPIResponse
```

**Benefits:**
- Reusable for all endpoints that use `"data"` wrapper
- Type-safe access to wrapped data
- Clean separation between API structure and domain models

### Fix 1b: CodingKeys Mapping

Swift's `Codable` uses `CodingKeys` to map between Swift property names and JSON keys. By specifying:

```swift
case entries = "meal_logs"
```

We tell the decoder: "When you see `meal_logs` in the JSON, decode it into the `entries` property."

This allows the internal property names to remain clean (`entries`, `total`) while matching the backend's API contract (`meal_logs`, `total_count`).

### Fix 2: In-Memory Filtering for Enums

SwiftData's `#Predicate` macro has limitations with enum values captured from outside the closure:

**❌ Direct enum capture doesn't work:**
```swift
let status: MealLogStatus = .completed
predicates.append(#Predicate { $0.status == status })  // Error!
```

**❌ Raw value capture also doesn't work reliably:**
```swift
let statusRawValue = status.rawValue
predicates.append(#Predicate { $0.status == statusRawValue })  // Still errors!
```

**✅ In-memory filtering works:**
```swift
// Fetch with simple predicates (user, dates)
var results = try modelContext.fetch(descriptor)

// Filter enum properties in memory
if let status = status {
    results = results.filter { $0.status == status }  // ✅ Works perfectly!
}
```

**Why this approach:**
- Predicates work well for UUID, Date, and primitive types
- Enum comparisons work fine in regular Swift code (in-memory)
- Meal logs are typically small datasets per user, so in-memory filtering is efficient
- Avoids complex predicate macro limitations

---

## Pattern to Follow

### API Response Mapping with Data Wrapper

When backend wraps responses in a `"data"` field:

```swift
// 1. Create wrapper struct (reusable)
struct APIDataWrapper<T: Codable>: Codable {
    let data: T
}

// 2. Create response struct with CodingKeys
struct APIResponse: Codable {
    let entries: [Item]
    let total: Int
    
    enum CodingKeys: String, CodingKey {
        case entries = "backend_field_name"  // ✅ Map to backend
        case total = "total_count"           // ✅ Map to backend
    }
}

// 3. Decode with wrapper
let wrapper: APIDataWrapper<APIResponse> = try decoder.decode(...)
let response = wrapper.data
```

### SwiftData Predicates with Enums

When filtering by enum properties, use in-memory filtering:

```swift
// ✅ CORRECT - Filter in memory
func fetchByStatus(_ status: MyEnum) async throws -> [MyModel] {
    // Fetch with simple predicates
    let descriptor = FetchDescriptor<SDModel>(
        predicate: #Predicate { $0.userID == someUserID }
    )
    
    var results = try modelContext.fetch(descriptor)
    
    // Filter enum in memory
    results = results.filter { $0.enumProperty == status }
    
    return results
}

// ❌ WRONG - Capture enum in predicate
func fetchByStatus(_ status: MyEnum) async throws -> [MyModel] {
    let descriptor = FetchDescriptor<SDModel>(
        predicate: #Predicate { $0.enumProperty == status }  // Error!
    )
    
    return try modelContext.fetch(descriptor)
}
```

**When to use in-memory filtering:**
- Enum properties (status, types, etc.)
- Complex conditional logic
- Small result sets (< 1000 records typically)

**When to use predicates:**
- UUID filtering
- Date range filtering
- String/numeric filtering
- Large datasets needing database-level filtering

---

## Testing

### Before Fix 1
```
GET /api/v1/meal-logs → JSON decode error → Fallback to local storage
```

### After Fix 1
```
GET /api/v1/meal-logs → Success ✅ → Returns meal logs from backend
```

### Before Fix 2
```
Fetching local meal logs → SwiftData predicate error → Crash/Error
Error: "Unsupported Predicate: Captured/constant values of type 'MealLogStatus' are not supported"
```

### After Fix 2
```
Fetching local meal logs with user/date predicates → Success ✅
→ Filter by status/syncStatus in memory → Success ✅
→ Returns correctly filtered meal logs
```

---

## Related Issues

### Similar Predicate Issues May Occur With:

- `ProgressMetricType` enum in `SDProgressEntry`
- `SyncStatus` enum in various models
- `MealType` enum in `SDMeal`
- `SleepStageType` enum in `SDSleepStage`
- `MoodSourceType` enum in `SDMoodEntry`

**Pattern:** Always extract `.rawValue` before using in predicates when the value is captured from outside.

### Similar API Mapping Issues May Occur With:

- Snake_case (backend) vs camelCase (Swift)
- Pluralization differences (`meal_log` vs `meal_logs`)
- Nested data structures (`data.meal_logs` vs top-level)

**Pattern:** Always verify API response structure against backend documentation and use `CodingKeys` for mapping.

---

## Prevention Checklist

### For API Integration:

- [ ] Check backend API documentation for exact field names
- [ ] Test with actual API responses (not mock data)
- [ ] Use `CodingKeys` to map between Swift conventions and backend conventions
- [ ] Add debug logging to print raw JSON responses
- [ ] Handle both success and error response formats

### For SwiftData Predicates:

- [ ] When filtering by enum properties, use in-memory filtering instead of predicates
- [ ] Use predicates for UUID, Date, and primitive type filtering
- [ ] Keep predicates simple - filter complex logic in memory
- [ ] Test predicates with actual data in the database
- [ ] Avoid capturing enum values in `#Predicate` closures
- [ ] Consider dataset size - in-memory filtering is fine for small datasets

---

## API Response Structure Reference

### Meal Logs List Endpoint

**Backend Response:**
```json
{
  "data": {
    "meal_logs": [],
    "total_count": 0,
    "limit": 50,
    "offset": 0,
    "has_more": false
  }
}
```

**iOS Mapping:**
```swift
// Step 1: Generic wrapper for "data" field
struct APIDataWrapper<T: Codable>: Codable {
    let data: T
}

// Step 2: Response struct with field mappings
struct MealLogListAPIResponse: Codable {
    let entries: [MealLog]    // ← maps from "meal_logs"
    let total: Int            // ← maps from "total_count"
    let limit: Int            // ← direct mapping
    let offset: Int           // ← direct mapping
    // Note: has_more is optional and not decoded
    
    enum CodingKeys: String, CodingKey {
        case entries = "meal_logs"
        case total = "total_count"
        case limit
        case offset
    }
}

// Step 3: Usage
let wrapper: APIDataWrapper<MealLogListAPIResponse> = try await executeWithRetry(...)
return wrapper.data.entries
```

---

## Key Takeaways

1. **API Response Structure:** Handle backend `"data"` wrappers with a generic `APIDataWrapper<T>` struct for reusability.

2. **API Field Mapping:** Always use `CodingKeys` to map between Swift property names and backend JSON keys.

3. **Predicate Enum Values:** Use in-memory filtering for enum properties instead of capturing them in predicates.

4. **Test with Real Data:** Mock data often hides these issues - always test with actual backend responses and real database queries.

5. **Schema vs Predicate:** Even though schema properties are enums, use in-memory filtering for enum comparisons instead of predicates.

6. **Follow Conventions:** 
   - Swift: `camelCase` for properties
   - Backend: `snake_case` for JSON keys
   - Backend: `"data"` wrappers for responses
   - Use `CodingKeys` and `APIDataWrapper` to bridge the gap

---

## Related Documentation

- [Outbox Metadata JSON Serialization Fix](./OUTBOX_METADATA_JSON_SERIALIZATION_FIX.md)
- [API Integration Guide](../api-integration/getting-started/README.md)
- [SwiftData Predicate Best Practices](../architecture/SWIFTDATA_PATTERNS.md)

---

**Status:** ✅ Fixed  
**Verified:** Meal logs now save, sync, and fetch successfully  
**Impact:** Nutrition tracking feature fully operational