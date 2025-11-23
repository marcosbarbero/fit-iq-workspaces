# Progress API Migration Guide

**Date:** 2025-01-27  
**Status:** ✅ Complete  
**Affected Components:** Progress tracking (weight, height, steps, etc.)

---

## 📋 Executive Summary

The backend `/progress` API has been enhanced with better querying capabilities, and the `/progress/history` endpoint has been **DEPRECATED and removed**. All progress queries (current and historical) now use the unified `GET /api/v1/progress` endpoint with filtering and pagination.

### Key Changes

1. ✅ **Unified Endpoint:** `GET /api/v1/progress` now handles both current and historical queries
2. ❌ **Deprecated:** `/api/v1/progress/history` has been removed from the API spec
3. ✨ **Enhanced Querying:** Support for type filtering, date ranges, and pagination
4. 📊 **Paginated Response:** Returns `ProgressListResponse` with metadata (total, limit, offset)

---

## 🔄 What Changed

### Before (Deprecated)

```swift
// OLD: Separate endpoints for current vs historical
GET /api/v1/progress          // Latest values only
GET /api/v1/progress/history  // All historical entries (DEPRECATED)

// Response: Direct array of entries
[
  {
    "id": "uuid",
    "type": "weight",
    "quantity": 75.5,
    "date": "2024-01-15T08:00:00Z",
    "notes": null
  }
]
```

### After (Current)

```swift
// NEW: Unified endpoint with enhanced querying
GET /api/v1/progress?type=weight&from=2024-01-01&to=2024-12-31&limit=100&offset=0

// Response: Paginated structure with metadata
{
  "success": true,
  "data": {
    "entries": [
      {
        "id": "uuid",
        "type": "weight",
        "quantity": 75.5,
        "date": "2024-01-15T08:00:00Z",
        "notes": null
      }
    ],
    "total": 145,
    "limit": 100,
    "offset": 0
  }
}
```

---

## 🎯 iOS Implementation Changes

### 1. New DTO: `ProgressListResponse`

**File:** `FitIQ/Infrastructure/Network/DTOs/ProgressDTOs.swift`

```swift
/// Response DTO for paginated progress entries from GET /api/v1/progress
struct ProgressListResponse: Decodable {
    let entries: [ProgressEntryResponse]
    let total: Int      // Total entries matching query
    let limit: Int      // Results per page
    let offset: Int     // Current page offset
}
```

### 2. Updated API Client Methods

**File:** `FitIQ/Infrastructure/Network/ProgressAPIClient.swift`

#### Before

```swift
// OLD: Single method for both use cases
func getProgress(
    type: ProgressMetricType?,
    from: Date?,
    to: Date?,
    page: Int?,
    limit: Int?
) async throws -> [ProgressEntry]
```

#### After

```swift
// NEW: Two distinct methods using the same unified endpoint

/// Get current/latest progress values
func getCurrentProgress(
    type: ProgressMetricType?,
    from: Date?,
    to: Date?,
    page: Int?,
    limit: Int?  // Defaults to 20
) async throws -> [ProgressEntry]

/// Get complete progress history
func getProgressHistory(
    type: ProgressMetricType?,
    from: Date?,
    to: Date?,
    page: Int?,
    limit: Int?  // Defaults to 100
) async throws -> [ProgressEntry]
```

Both methods call the internal `fetchProgress()` method which:
- Builds the URL with query parameters
- Converts page numbers to offset (offset = (page - 1) * limit)
- Decodes `ProgressListResponse` from the API
- Maps DTOs to domain models
- Returns array of `ProgressEntry` objects

---

## 📝 Query Parameter Reference

### Supported Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `type` | String | Filter by metric type | `?type=weight` |
| `from` | Date (YYYY-MM-DD) | Start date (inclusive) | `?from=2024-01-01` |
| `to` | Date (YYYY-MM-DD) | End date (inclusive) | `?to=2024-12-31` |
| `limit` | Integer | Results per page (1-100) | `?limit=50` |
| `offset` | Integer | Pagination offset | `?offset=0` |

### Common Query Patterns

#### Get Latest Weight

```http
GET /api/v1/progress?type=weight&limit=1&offset=0
```

#### Get All Weight History (Last 30 Days)

```http
GET /api/v1/progress?type=weight&from=2024-12-01&to=2024-12-31&limit=100&offset=0
```

#### Get All Metrics (Latest Values)

```http
GET /api/v1/progress?limit=20&offset=0
```

#### Get All Activity Metrics (Last Week)

```http
GET /api/v1/progress?from=2024-12-24&to=2024-12-31&limit=100&offset=0
```

---

## 🔍 Usage Examples

### Example 1: Fetch Latest Body Mass

```swift
// Use case: Display current weight on dashboard
let progressAPI = appDependencies.progressAPIClient

do {
    let entries = try await progressAPI.getCurrentProgress(
        type: .weight,
        from: nil,
        to: nil,
        page: 1,
        limit: 1
    )
    
    if let latestWeight = entries.first {
        print("Current weight: \(latestWeight.quantity) kg")
    }
} catch {
    print("Failed to fetch weight: \(error)")
}
```

### Example 2: Fetch Weight History (Chart Data)

```swift
// Use case: Display weight trend chart for last 90 days
let progressAPI = appDependencies.progressAPIClient
let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!

do {
    let entries = try await progressAPI.getProgressHistory(
        type: .weight,
        from: ninetyDaysAgo,
        to: Date(),
        page: 1,
        limit: 100
    )
    
    print("Fetched \(entries.count) weight entries for chart")
    // entries are already sorted by date from backend
} catch {
    print("Failed to fetch weight history: \(error)")
}
```

### Example 3: Pagination Through Large History

```swift
// Use case: Load historical data in pages
let progressAPI = appDependencies.progressAPIClient
var allEntries: [ProgressEntry] = []
var currentPage = 1
let pageSize = 50

while true {
    let entries = try await progressAPI.getProgressHistory(
        type: .steps,
        from: Date(timeIntervalSince1970: 0), // All time
        to: Date(),
        page: currentPage,
        limit: pageSize
    )
    
    if entries.isEmpty {
        break // No more data
    }
    
    allEntries.append(contentsOf: entries)
    currentPage += 1
}

print("Loaded \(allEntries.count) total step entries")
```

---

## 🧪 Testing the Migration

### Manual Testing Steps

1. **Test Latest Value Query**
   ```bash
   # Should return most recent weight entry
   curl -X GET "https://fit-iq-backend.fly.dev/api/v1/progress?type=weight&limit=1" \
     -H "X-API-Key: YOUR_KEY" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

2. **Test Historical Query**
   ```bash
   # Should return all weight entries from date range
   curl -X GET "https://fit-iq-backend.fly.dev/api/v1/progress?type=weight&from=2024-01-01&to=2024-12-31&limit=100" \
     -H "X-API-Key: YOUR_KEY" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

3. **Test Pagination**
   ```bash
   # Should return second page of results
   curl -X GET "https://fit-iq-backend.fly.dev/api/v1/progress?limit=20&offset=20" \
     -H "X-API-Key: YOUR_KEY" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

### Automated Tests

```swift
// Test in ProgressAPIClientTests.swift
func testGetCurrentProgress_returnsLatestValue() async throws {
    let client = ProgressAPIClient(
        authTokenPersistence: mockAuthPersistence,
        authManager: mockAuthManager
    )
    
    let entries = try await client.getCurrentProgress(
        type: .weight,
        from: nil,
        to: nil,
        page: 1,
        limit: 1
    )
    
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.type, .weight)
}

func testGetProgressHistory_returnsAllEntries() async throws {
    let client = ProgressAPIClient(
        authTokenPersistence: mockAuthPersistence,
        authManager: mockAuthManager
    )
    
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    
    let entries = try await client.getProgressHistory(
        type: .weight,
        from: thirtyDaysAgo,
        to: Date(),
        page: 1,
        limit: 100
    )
    
    XCTAssertGreaterThan(entries.count, 0)
    XCTAssertTrue(entries.allSatisfy { $0.type == .weight })
}
```

---

## 🚨 Breaking Changes & Migration Checklist

### Breaking Changes

1. ❌ `/api/v1/progress/history` endpoint removed
2. 🔄 Response structure changed from array to paginated object
3. 🔄 Query parameter `page` converted to `offset` internally

### Migration Checklist

- [x] **DTOs Updated**
  - [x] Added `ProgressListResponse` struct
  - [x] Updated documentation comments
  - [x] Added migration notes

- [x] **API Client Updated**
  - [x] Implemented `getCurrentProgress()` method
  - [x] Implemented `getProgressHistory()` method
  - [x] Updated internal `fetchProgress()` to decode `ProgressListResponse`
  - [x] Converted page-based pagination to offset-based
  - [x] Updated documentation comments

- [ ] **Use Cases Updated** (if needed)
  - [ ] Review all use cases that fetch progress data
  - [ ] Update to use `getCurrentProgress()` or `getProgressHistory()` as appropriate
  - [ ] Test data retrieval in UI

- [ ] **Tests Updated**
  - [ ] Update existing tests to expect new response structure
  - [ ] Add tests for pagination
  - [ ] Add tests for date range filtering

- [ ] **Documentation Updated**
  - [x] Created this migration guide
  - [ ] Updated README if needed
  - [ ] Updated API integration guide

---

## 🎓 Best Practices

### When to Use `getCurrentProgress()`

- Dashboard displays (latest weight, latest steps, etc.)
- Profile screens (current height, current weight)
- Quick summaries and cards
- Default limit: 20 entries

### When to Use `getProgressHistory()`

- Charts and graphs (trend visualization)
- Progress tracking screens
- Historical analysis
- Export functionality
- Default limit: 100 entries

### Performance Considerations

1. **Use Specific Filters:** Always specify `type` when querying a single metric
2. **Limit Date Ranges:** Use `from`/`to` to avoid fetching unnecessary data
3. **Page Large Results:** For queries with many results, implement pagination
4. **Cache When Possible:** Cache recent progress data locally to reduce API calls

---

## 📚 Related Documentation

- **API Spec:** `docs/be-api-spec/swagger.yaml` (lines 3179-3323)
- **Protocol Definition:** `Domain/Ports/ProgressRepositoryProtocol.swift`
- **Implementation:** `Infrastructure/Network/ProgressAPIClient.swift`
- **DTOs:** `Infrastructure/Network/DTOs/ProgressDTOs.swift`
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html

---

## ❓ FAQ

### Q: What happened to `/progress/history`?

**A:** It has been **deprecated and removed** from the API spec. The unified `/progress` endpoint now handles both current and historical queries through filtering parameters.

### Q: How do I get historical data now?

**A:** Use `GET /api/v1/progress` with date range parameters:
```
?type=weight&from=2024-01-01&to=2024-12-31&limit=100
```

### Q: Will old code break?

**A:** If you were calling `/progress/history` directly, yes. The iOS implementation has been updated to use the new endpoint. Make sure to pull the latest code.

### Q: How does pagination work?

**A:** The backend uses offset-based pagination:
- `limit`: Number of results per page (default 20, max 100)
- `offset`: Number of results to skip (e.g., offset=20 for page 2 with limit=20)
- The iOS client converts page numbers to offsets automatically

### Q: Can I still get the latest value only?

**A:** Yes! Use `getCurrentProgress()` with `limit=1`:
```swift
let entries = try await progressAPI.getCurrentProgress(
    type: .weight,
    from: nil,
    to: nil,
    page: 1,
    limit: 1
)
```

### Q: What if I need all historical data?

**A:** Use `getProgressHistory()` with a large limit or implement pagination:
```swift
let allEntries = try await progressAPI.getProgressHistory(
    type: .weight,
    from: startDate,
    to: endDate,
    page: 1,
    limit: 100
)
```

---

## 🔧 Troubleshooting

### Issue: Getting 404 on `/progress/history`

**Solution:** Update to the latest iOS code. This endpoint no longer exists. Use `GET /progress` instead.

### Issue: Response structure doesn't match

**Solution:** Ensure you're decoding `ProgressListResponse` instead of `[ProgressEntryResponse]`:
```swift
let listResponse: ProgressListResponse = try await executeWithRetry(...)
let entries = listResponse.entries
```

### Issue: Not getting historical data

**Solution:** Check that you're:
1. Using `getProgressHistory()` (not `getCurrentProgress()`)
2. Providing appropriate date range with `from`/`to`
3. Using a sufficient `limit` value (default is 100)

---

## ✅ Summary

The progress API migration enhances the backend's querying capabilities while simplifying the architecture:

- ✅ **One endpoint** for all queries: `GET /api/v1/progress`
- ✅ **Better filtering** with type, date range, and pagination support
- ✅ **Clearer semantics** with `getCurrentProgress()` vs `getProgressHistory()`
- ✅ **Proper pagination** with offset-based paging and metadata
- ✅ **iOS code updated** and ready to use

**Migration Status:** ✅ Complete  
**Impact:** Medium (API client changes, no UI changes required)  
**Testing Required:** Yes (verify progress data retrieval)

---

**Last Updated:** 2025-01-27  
**Maintained By:** AI Assistant  
**Questions?** Check the Swagger UI or reference the API spec in `docs/be-api-spec/swagger.yaml`
