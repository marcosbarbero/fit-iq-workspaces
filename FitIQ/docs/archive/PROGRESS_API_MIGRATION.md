# Progress API Migration Guide

**Date:** 2025-01-27  
**Status:** ✅ Complete  
**Breaking Changes:** Yes

---

## 🎯 Overview

The backend `/progress` API has been updated with breaking changes. This document outlines the changes made to the iOS app to accommodate the new API structure.

---

## 📋 Backend API Changes

### 1. POST /api/v1/progress - Request Body Changes

**OLD (Deprecated):**
```json
{
  "type": "weight",
  "quantity": 70.5,
  "date": "2024-01-15",      // YYYY-MM-DD
  "time": "08:00:00",         // HH:MM:SS
  "notes": "Morning weight"
}
```

**NEW (Current):**
```json
{
  "type": "weight",
  "quantity": 70.5,
  "logged_at": "2024-01-15T08:00:00Z",  // RFC3339 timestamp
  "notes": "Morning weight"
}
```

**Change:** The separate `date` and `time` fields have been replaced with a single `logged_at` field using RFC3339 format.

---

### 2. GET /api/v1/progress - Enhanced Capabilities

**OLD Behavior:**
- `/api/v1/progress` - Latest values only, no date filtering
- `/api/v1/progress/history` - Historical data with date filtering

**NEW Behavior:**
- `/api/v1/progress` - Unified endpoint with pagination and date filtering
- `/api/v1/progress/history` - **DEPRECATED** (removed immediately)

**Query Parameters (NEW):**
- `type` - Filter by metric type (e.g., "weight", "steps")
- `from` - Start date for filtering (YYYY-MM-DD)
- `to` - End date for filtering (YYYY-MM-DD)
- `page` - Page number for pagination (starts at 1)
- `limit` - Page size (number of entries per page)

**Example:**
```bash
GET /api/v1/progress?type=weight&from=2024-01-01&to=2024-01-31&page=1&limit=50
```

---

## 🔧 iOS App Changes

### Files Modified

1. **DTOs:**
   - `FitIQ/Infrastructure/Network/DTOs/ProgressDTOs.swift`

2. **Protocols:**
   - `FitIQ/Domain/Ports/ProgressRepositoryProtocol.swift`

3. **Infrastructure:**
   - `FitIQ/Infrastructure/Network/ProgressAPIClient.swift`
   - `FitIQ/Infrastructure/Persistence/CompositeProgressRepository.swift`

4. **Use Cases:**
   - `FitIQ/Domain/UseCases/LogHeightProgressUseCase.swift`
   - `FitIQ/Domain/UseCases/GetHistoricalWeightUseCase.swift`

5. **Entities:**
   - `FitIQ/Domain/Entities/Progress/ProgressMetricType.swift`

---

## 📝 Detailed Changes

### 1. ProgressLogRequest DTO

**File:** `Infrastructure/Network/DTOs/ProgressDTOs.swift`

**Before:**
```swift
struct ProgressLogRequest: Encodable {
    let type: String
    let quantity: Double
    let date: String?  // YYYY-MM-DD
    let time: String?  // HH:MM:SS
    let notes: String?
}
```

**After:**
```swift
struct ProgressLogRequest: Encodable {
    let type: String
    let quantity: Double
    let loggedAt: String?  // RFC3339 format
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case quantity
        case loggedAt = "logged_at"  // Maps to backend field
        case notes
    }
}
```

---

### 2. ProgressRemoteAPIProtocol

**File:** `Domain/Ports/ProgressRepositoryProtocol.swift`

**Changes:**
- `logProgress()` method signature updated to use `loggedAt: Date?` instead of `date: Date?` and `time: String?`
- Removed `getCurrentProgress()` method (no longer needed)
- Renamed `getProgressHistory()` to `getProgress()` with updated parameters (`from`/`to` instead of `startDate`/`endDate`)

**Before:**
```swift
func logProgress(
    type: ProgressMetricType,
    quantity: Double,
    date: Date?,
    time: String?,
    notes: String?
) async throws -> ProgressEntry

func getCurrentProgress(type: ProgressMetricType?) async throws -> [ProgressEntry]

func getProgressHistory(
    type: ProgressMetricType?,
    startDate: Date?,
    endDate: Date?,
    page: Int?,
    limit: Int?
) async throws -> [ProgressEntry]
```

**After:**
```swift
func logProgress(
    type: ProgressMetricType,
    quantity: Double,
    loggedAt: Date?,
    notes: String?
) async throws -> ProgressEntry

func getProgress(
    type: ProgressMetricType?,
    from: Date?,
    to: Date?,
    page: Int?,
    limit: Int?
) async throws -> [ProgressEntry]
```

---

### 3. ProgressAPIClient Implementation

**File:** `Infrastructure/Network/ProgressAPIClient.swift`

**Changes:**
- Updated `logProgress()` to use `toISO8601TimestampString()` for RFC3339 format
- Removed `getCurrentProgress()` method
- Renamed `getProgressHistory()` to `getProgress()` 
- Updated query parameters: `from` and `to` instead of date range
- Now uses unified `/api/v1/progress` endpoint for all queries

**Before:**
```swift
func logProgress(..., date: Date?, time: String?, ...) async throws -> ProgressEntry {
    let dateString = date?.toISO8601DateString()  // YYYY-MM-DD
    let requestDTO = ProgressLogRequest(
        type: type.rawValue,
        quantity: quantity,
        date: dateString,
        time: time,
        notes: notes
    )
    // ...
}

func getProgressHistory(...) async throws -> [ProgressEntry] {
    var urlComponents = URLComponents(string: "\(baseURL)/api/v1/progress/history")!
    // ...
}
```

**After:**
```swift
func logProgress(..., loggedAt: Date?, ...) async throws -> ProgressEntry {
    let loggedAtString = loggedAt?.toISO8601TimestampString()  // RFC3339
    let requestDTO = ProgressLogRequest(
        type: type.rawValue,
        quantity: quantity,
        loggedAt: loggedAtString,
        notes: notes
    )
    // ...
}

func getProgress(...) async throws -> [ProgressEntry] {
    var urlComponents = URLComponents(string: "\(baseURL)/api/v1/progress")!
    // Unified endpoint with pagination and date filtering
    // ...
}
```

---

### 4. Use Case Updates

**File:** `Domain/UseCases/LogHeightProgressUseCase.swift`

**Changed parameter name:**
```swift
// Before
func execute(userId: String, heightCm: Double, date: Date?, notes: String?) async throws -> ProgressEntry

// After
func execute(userId: String, heightCm: Double, loggedAt: Date?, notes: String?) async throws -> ProgressEntry
```

**File:** `Domain/UseCases/GetHistoricalWeightUseCase.swift`

**Updated method call:**
```swift
// Before
backendEntries = try await progressRepository.getProgressHistory(
    type: .weight,
    startDate: startDate,
    endDate: endDate,
    page: nil,
    limit: nil
)

// After
backendEntries = try await progressRepository.getProgress(
    type: .weight,
    from: startDate,
    to: endDate,
    page: nil,
    limit: nil
)
```

---

### 5. CompositeProgressRepository

**File:** `Infrastructure/Persistence/CompositeProgressRepository.swift`

**Changes:**
- Updated `logProgress()` signature to use `loggedAt`
- Removed `getCurrentProgress()` method
- Renamed `getProgressHistory()` to `getProgress()`
- Enhanced `syncToBackend()` to combine date and time fields into `loggedAt` timestamp when syncing local entries to backend

**Key Logic:**
```swift
// Combine separate date and time fields into single timestamp
let calendar = Calendar.current
let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.date)

var loggedAtDate = entry.date
if let time = entry.time {
    let timeComponents = time.split(separator: ":").compactMap { Int($0) }
    if timeComponents.count >= 2 {
        var components = dateComponents
        components.hour = timeComponents[0]
        components.minute = timeComponents[1]
        components.second = timeComponents.count > 2 ? timeComponents[2] : 0
        if let combinedDate = calendar.date(from: components) {
            loggedAtDate = combinedDate
        }
    }
}

let backendEntry = try await logProgress(
    type: entry.type,
    quantity: entry.quantity,
    loggedAt: loggedAtDate,  // Combined timestamp
    notes: entry.notes
)
```

---

## 🔄 Backwards Compatibility

### Local Storage (SwiftData)

**No Changes Required** - Local `ProgressEntry` model still uses separate `date` and `time` fields for local-first architecture. The transformation to `logged_at` happens only when syncing to the backend.

This preserves existing local data structure and avoids data migration.

---

## ✅ Testing Checklist

- [ ] Verify weight logging creates correct `logged_at` timestamp
- [ ] Verify steps logging creates correct `logged_at` timestamp
- [ ] Verify height logging creates correct `logged_at` timestamp
- [ ] Test historical weight fetching with date range
- [ ] Test pagination on progress queries
- [ ] Verify local-to-remote sync converts date/time to `logged_at`
- [ ] Test initial HealthKit sync for historical data
- [ ] Verify no calls are made to deprecated `/progress/history` endpoint

---

## 🚨 Breaking Changes Impact

### High Impact
1. **All progress logging operations** - API contract changed
2. **Historical data queries** - Endpoint and parameters changed
3. **Sync operations** - Must handle date/time to `logged_at` conversion

### No Impact
1. **Local storage** - SwiftData models unchanged
2. **UI/Views** - No changes required (domain layer absorbed the changes)
3. **ViewModels** - No changes required (use cases handle the abstraction)

---

## 📚 Related Documentation

- **API Spec:** `docs/api-spec.yaml`
- **Integration Guide:** `docs/IOS_INTEGRATION_HANDOFF.md`
- **Copilot Instructions:** `FitIQ/.github/copilot-instructions.md`

---

## 🔗 Migration Path for Future Features

When adding new progress tracking features:

1. **Use `loggedAt` parameter** - Single timestamp, not separate date/time
2. **Use `getProgress()` method** - Unified endpoint with filtering
3. **Use `from`/`to` parameters** - For date range queries
4. **Add pagination** - Consider page/limit for large datasets

**Example:**
```swift
// Log new metric
let entry = try await progressRepository.logProgress(
    type: .caloriesIn,
    quantity: 2000,
    loggedAt: Date(),  // Current timestamp
    notes: "Lunch"
)

// Query historical data
let entries = try await progressRepository.getProgress(
    type: .caloriesIn,
    from: thirtyDaysAgo,
    to: Date(),
    page: 1,
    limit: 100
)
```

---

## ✨ Summary

All changes have been implemented following the Hexagonal Architecture pattern:

1. **Domain layer** defines the new interface
2. **Infrastructure layer** implements the backend integration
3. **Use cases** updated to use new signatures
4. **Local storage** remains unchanged (no migration needed)
5. **ViewModels/Views** unaffected (changes isolated to domain/infrastructure)

**Status:** ✅ **Migration Complete**

---

**Last Updated:** 2025-01-27  
**Migrated By:** AI Assistant  
**Reviewed By:** _Pending_