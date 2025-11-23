# Sleep API Spec Update - Implementation Fixes

**Date:** 2025-01-27  
**Status:** ✅ Completed  
**Impact:** Sleep session sync to backend (`/api/v1/sleep`)

---

## Overview

The backend `/api/v1/sleep` API specification was updated with a different response schema. Our iOS implementation had mismatched request/response models that needed to be corrected to ensure proper sleep data synchronization.

---

## Changes Made

### 1. Fixed Request Model (POST /api/v1/sleep)

**Issue:** Debug logging referenced a non-existent `date` field.

**Fix:** 
- Removed invalid debug log line referencing `request.date`
- Fixed optional chaining for `request.stages?.count ?? 0`

**Location:** `SleepAPIClient.swift` lines 81-86

**Correct Request Schema:**
```json
{
  "start_time": "2024-01-15T22:00:00Z",
  "end_time": "2024-01-16T06:30:00Z",
  "source": "healthkit",
  "source_id": "HK-SESS-12345",
  "stages": [
    {
      "stage": "core",
      "start_time": "2024-01-15T22:10:00Z",
      "end_time": "2024-01-16T00:10:00Z"
    }
  ],
  "notes": "Optional notes"
}
```

### 2. Updated Response Model (POST /api/v1/sleep)

**Issue:** Response model was completely wrong - expected a simplified summary but API returns full sleep session object.

**Old (Incorrect) Schema:**
```swift
struct SleepSessionResponse: Codable {
    let sessionID: String
    let timeInBed: Int
    let totalSleepTime: Int
    let sleepEfficiency: Double
    let stagesSummary: [String: StageSummary]?
}
```

**New (Correct) Schema:**
```swift
struct SleepSessionResponse: Codable {
    let id: String
    let userID: String
    let startTime: String  // RFC3339
    let endTime: String  // RFC3339
    let timeInBedMinutes: Int
    let totalSleepMinutes: Int
    let sleepEfficiencyPercentage: Double
    let awakeMinutes: Int
    let remMinutes: Int
    let coreMinutes: Int
    let deepMinutes: Int
    let source: String
    let sourceID: String?
    let notes: String?
    let createdAt: String
    let updatedAt: String
}
```

**Key Changes:**
- `sessionID` → `id`
- `timeInBed` → `timeInBedMinutes`
- `totalSleepTime` → `totalSleepMinutes`
- `sleepEfficiency` → `sleepEfficiencyPercentage`
- Removed `stagesSummary` (API doesn't return this)
- Added individual stage duration fields: `awakeMinutes`, `remMinutes`, `coreMinutes`, `deepMinutes`
- Added metadata fields: `userID`, `startTime`, `endTime`, `source`, `sourceID`, `notes`, `createdAt`, `updatedAt`

### 3. Updated GET Response Model (GET /api/v1/sleep)

**Issue:** Used a separate `SleepSessionItem` struct, but API returns full `SleepSessionResponse` objects.

**Old (Incorrect) Schema:**
```swift
struct SleepSessionsResponse: Codable {
    let sessions: [SleepSessionItem]  // Separate simplified struct
    let averages: SleepAverages
}
```

**New (Correct) Schema:**
```swift
struct SleepSessionsResponse: Codable {
    let sessions: [SleepSessionResponse]  // Reuses full response
    let averages: SleepAverages?  // Nullable
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

struct SleepAverages: Codable {
    let avgTimeInBedMinutes: Int
    let avgTotalSleepMinutes: Int
    let avgSleepEfficiencyPercentage: Double
}
```

**Key Changes:**
- Removed separate `SleepSessionItem` struct
- Reuse full `SleepSessionResponse` for list items
- Made `averages` optional (nullable)
- Added pagination fields: `total`, `limit`, `offset`, `hasMore`
- Updated averages field names to match API snake_case

### 4. Updated Logging References

**Files Updated:**
- `SleepAPIClient.swift` - Line 176: `response.sessionID` → `response.id`
- `OutboxProcessorService.swift` - Lines 464, 472: `response.sessionID` → `response.id`

---

## API Spec Reference

**Swagger Spec:** `docs/be-api-spec/swagger.yaml`
- POST `/api/v1/sleep` - Lines 8585-8710
- GET `/api/v1/sleep` - Lines 8712-8772
- `SleepSessionResponse` schema - Lines 2849-2918
- `ListSleepSessionsResponse` schema - Lines 2969-3011

---

## Testing Impact

### What Still Works ✅
- Sleep session creation from HealthKit
- Local storage with `SDSleepSession` and `SDSleepStage`
- Outbox Pattern for reliable sync
- Sleep session attribution to wake date
- Deduplication via `source_id`

### What Changed ✅
- Response parsing now correctly maps all backend fields
- Logging shows correct backend IDs
- GET /sleep now includes pagination info

### What to Test
1. **Sync a new sleep session:**
   ```
   1. Sleep overnight (or use HealthKit test data)
   2. Open FitIQ app
   3. Trigger background sync
   4. Check logs for "OutboxProcessor: ✅ Sleep session uploaded successfully"
   5. Verify "Backend ID: <UUID>" appears
   ```

2. **Verify response parsing:**
   ```
   1. Check logs for full sleep session details
   2. Confirm all stage minutes are logged (awake, rem, core, deep)
   3. Verify sleep efficiency percentage is correct
   ```

3. **Test GET endpoint (future feature):**
   ```
   1. Call sleepAPIClient.getSleepSessions(from: "2024-01-01", to: "2024-01-31")
   2. Verify response includes:
      - Full SleepSessionResponse objects
      - Averages (if available)
      - Pagination info (total, limit, offset, hasMore)
   ```

---

## Migration Notes

### Breaking Changes
- Any code expecting `sessionID` must use `id`
- Any code expecting `stagesSummary` must use individual stage minute fields
- Any code expecting simplified list items must handle full `SleepSessionResponse` objects

### Non-Breaking Changes
- All existing functionality preserved
- Outbox Pattern flow unchanged
- Local storage schema unchanged

---

## Files Modified

1. **`Infrastructure/Network/SleepAPIClient.swift`**
   - Fixed debug logging (removed `request.date`)
   - Updated `SleepSessionResponse` struct (complete rewrite)
   - Updated `SleepSessionsResponse` struct (pagination + full objects)
   - Updated `SleepAverages` struct (field name changes)
   - Removed `SleepSessionItem` struct (no longer needed)
   - Removed `StageSummary` struct (not in API)
   - Fixed logging to use `response.id`

2. **`Infrastructure/Network/OutboxProcessorService.swift`**
   - Updated logging to use `response.id` instead of `response.sessionID` (2 locations)

---

## Verification Checklist

- [x] Request model matches API spec exactly
- [x] Response model includes all API fields with correct types
- [x] CodingKeys map snake_case to camelCase correctly
- [x] All logging references use correct field names
- [x] GET /sleep response model matches list spec
- [x] No compilation errors in affected files
- [x] Outbox Pattern flow preserved
- [x] Documentation updated

---

## Related Documentation

- **Sleep Tracking Architecture:** `docs/architecture/SLEEP_TRACKING_ARCHITECTURE.md`
- **Schema V4 (Sleep):** `Infrastructure/Persistence/Schema/SCHEMA_V4_SLEEP_TRACKING.md`
- **Outbox Logging Guide:** `docs/debugging/OUTBOX_LOGGING_GUIDE.md`
- **HealthKit Sleep Sync:** `Infrastructure/Services/HealthKit/Sync/SleepSyncHandler.swift`

---

## Summary

✅ **Status:** All sleep API models now correctly match the backend specification.  
✅ **Impact:** Sleep session sync will now parse responses correctly and log accurate backend IDs.  
✅ **Risk:** Low - changes are isolated to API client and logging, core sync logic unchanged.  
✅ **Testing:** Compile-time verified, ready for runtime testing with real/test sleep data.

---

**Last Updated:** 2025-01-27  
**Next Steps:** Test with real HealthKit sleep data sync to verify end-to-end flow.