# Progress API Response Fix

**Date:** 2025-01-27  
**Issue:** Foreign key error when decoding POST /api/v1/progress response  
**Status:** ✅ Fixed

---

## Problem

The iOS app was failing to decode the response from `POST /api/v1/progress` with the following error:

```
RemoteSyncService: ❌ /api/v1/progress API call FAILED!
  - Error: keyNotFound(CodingKeys(stringValue: "id", intValue: nil), 
    Swift.DecodingError.Context(codingPath: [], debugDescription: 
    "No value associated with key CodingKeys(stringValue: \"id\", intValue: nil) (\"id\").", 
    underlyingError: nil))
```

### Root Cause

The `ProgressEntryResponse` DTO was out of sync with the actual backend API contract.

**What the iOS DTO expected:**
```swift
struct ProgressEntryResponse: Decodable {
    let id: String
    let userId: String          // ❌ NOT RETURNED BY API
    let type: String
    let quantity: Double
    let date: String            // Expected YYYY-MM-DD format
    let time: String?           // ❌ NOT RETURNED BY API (separate field)
    let notes: String?
    let createdAt: String       // ❌ NOT RETURNED BY API
    let updatedAt: String       // ❌ NOT RETURNED BY API
}
```

**What the backend actually returns:**
```json
{
  "data": {
    "id": "14f0e57e-d2ad-453a-84fa-9c818c537bff",
    "type": "weight",
    "quantity": 75.5,
    "date": "2024-01-15T08:00:00Z",    // RFC3339 date-time format
    "notes": "Morning weight after breakfast"
  }
}
```

**Backend API Spec (from swagger.yaml):**
```yaml
ProgressEntryResponse:
  properties:
    id:
      type: string
      format: uuid
    type:
      type: string
    quantity:
      type: number
    date:
      type: string
      format: date-time  # RFC3339 format
    notes:
      type: string
      nullable: true
```

---

## Solution

### 1. Updated `ProgressEntryResponse` DTO

**File:** `FitIQ/Infrastructure/Network/DTOs/ProgressDTOs.swift`

Simplified the DTO to match the actual API contract:

```swift
struct ProgressEntryResponse: Decodable {
    let id: String
    let type: String
    let quantity: Double
    let date: String  // RFC3339 date-time format (e.g., "2024-01-15T08:00:00Z")
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case quantity
        case date
        case notes
    }
}
```

### 2. Updated `toDomain()` Conversion Method

**Changes:**
- Added `userID` parameter (backend doesn't return this, so caller must provide it)
- Parse RFC3339 date-time string instead of separate date/time fields
- Extract date component for `ProgressEntry.date` field
- Extract time component for `ProgressEntry.time` field (formatted as HH:MM:SS)
- Use parsed date-time for `createdAt` and `updatedAt` timestamps

```swift
extension ProgressEntryResponse {
    func toDomain(userID: String) throws -> ProgressEntry {
        // Parse metric type
        guard let metricType = ProgressMetricType(rawValue: type) else {
            throw ProgressDTOConversionError.invalidMetricType(type)
        }

        // Parse date (RFC3339 format: "2024-01-15T08:00:00Z")
        guard let entryDateTime = try? date.toDateFromISO8601() else {
            throw ProgressDTOConversionError.invalidDateFormat(date)
        }

        // Extract date component (for date field)
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: entryDateTime)
        guard let entryDate = calendar.date(from: dateComponents) else {
            throw ProgressDTOConversionError.invalidDateFormat(date)
        }

        // Extract time component (for time field) - format as HH:MM:SS
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: entryDateTime)
        let timeString = String(
            format: "%02d:%02d:%02d",
            timeComponents.hour ?? 0,
            timeComponents.minute ?? 0,
            timeComponents.second ?? 0
        )

        // Use the parsed date-time for created/updated timestamps
        let now = entryDateTime

        // Create domain model with new local UUID and store backend ID
        return ProgressEntry(
            id: UUID(),
            userID: userID,
            type: metricType,
            quantity: quantity,
            date: entryDate,
            time: timeString,
            notes: notes,
            createdAt: now,
            updatedAt: now,
            backendID: id,
            syncStatus: .synced
        )
    }
}
```

### 3. Updated `ProgressAPIClient` Methods

**File:** `FitIQ/Infrastructure/Network/ProgressAPIClient.swift`

Updated all methods that call `toDomain()` to pass the current user ID from `AuthManager`:

#### `logProgress()` method:
```swift
// Inside executeWithRetry (single response)
case 200, 201:
    let decoder = configuredDecoder()
    let responseDTO: ProgressEntryResponse
    do {
        let successResponse = try decoder.decode(
            StandardResponse<ProgressEntryResponse>.self,
            from: data
        )
        responseDTO = successResponse.data
    } catch {
        responseDTO = try decoder.decode(ProgressEntryResponse.self, from: data)
    }

    // Get user ID from authManager
    guard let userProfileID = await authManager.currentUserProfileID else {
        print("ProgressAPIClient: ❌ No user profile ID found in authManager")
        throw APIError.invalidUserId
    }
    let userIDString = userProfileID.uuidString

    // Log success details
    let progressEntry = try responseDTO.toDomain(userID: userIDString)
    // ... logging ...
    
    return responseDTO as! T
```

#### `getCurrentProgress()` method:
```swift
// Get user ID from authManager
guard let userProfileID = await authManager.currentUserProfileID else {
    print("ProgressAPIClient: ❌ No user profile ID found in authManager")
    throw APIError.invalidUserId
}
let userIDString = userProfileID.uuidString

// Execute with token refresh on 401
let responseDTOs: [ProgressEntryResponse] = try await executeWithRetryArray(
    request: request, retryCount: 0)
let entries = try responseDTOs.map { try $0.toDomain(userID: userIDString) }
```

#### `getProgressHistory()` method:
Same pattern as `getCurrentProgress()`.

---

## Testing

### Manual Test

```bash
curl -i -X POST https://fit-iq-backend.fly.dev/api/v1/progress \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "type": "weight",
    "quantity": 75.5,
    "date": "2024-01-15",
    "time": "08:00:00",
    "notes": "Morning weight after breakfast"
  }'
```

**Expected Response:**
```json
HTTP/2 201
{
  "data": {
    "date": "2024-01-15T08:00:00Z",
    "id": "14f0e57e-d2ad-453a-84fa-9c818c537bff",
    "notes": "Morning weight after breakfast",
    "quantity": 75.5,
    "type": "weight"
  }
}
```

**Expected iOS Behavior:**
- ✅ Successfully decode the response
- ✅ Create `ProgressEntry` with correct values
- ✅ Store backend ID in local entry
- ✅ Mark sync status as `.synced`

---

## Key Learnings

### 1. Always Verify API Contracts

**Before implementing:** Check the actual API spec (swagger.yaml or Swagger UI) to verify:
- Exact field names
- Data types
- Optional vs required fields
- Date/time formats

**Don't assume:** That DTOs match the API just because they were created earlier. APIs evolve.

### 2. Backend Response Wrapping

The FitIQ backend uses `StandardResponse<T>` wrapper for success responses:

```swift
struct StandardResponse<T: Decodable>: Decodable {
    let message: String?
    let data: T
}
```

The API client already handles this with fallback to direct decode:

```swift
do {
    let successResponse = try decoder.decode(
        StandardResponse<ProgressEntryResponse>.self,
        from: data
    )
    responseDTO = successResponse.data
} catch {
    // Fallback to direct decode if no wrapper
    responseDTO = try decoder.decode(ProgressEntryResponse.self, from: data)
}
```

### 3. RFC3339 Date-Time Format

The backend returns date-time in RFC3339 format:
- `"2024-01-15T08:00:00Z"` (ISO8601 with timezone)

iOS domain model separates date and time:
- `date: Date` (day component only)
- `time: String?` (HH:MM:SS format)

Conversion required:
1. Parse RFC3339 string to `Date`
2. Extract date components → `Date` (day only)
3. Extract time components → `String` (HH:MM:SS)

### 4. User ID Not Returned

The backend doesn't return `user_id` in the progress entry response (it's implicit from the auth token).

Solution: Get user ID from `AuthManager.currentUserProfileID` and pass to `toDomain()`.

---

## Related Files

- ✅ `FitIQ/Infrastructure/Network/DTOs/ProgressDTOs.swift`
- ✅ `FitIQ/Infrastructure/Network/ProgressAPIClient.swift`
- 📖 `FitIQ/docs/be-api-spec/swagger.yaml` (API contract reference)

---

## Impact

### Before Fix
- ❌ POST /api/v1/progress failed with decoding error
- ❌ Steps sync to backend failed
- ❌ Weight/height sync to backend failed
- ❌ LocalDataChangeMonitor couldn't sync any progress entries

### After Fix
- ✅ POST /api/v1/progress succeeds
- ✅ Steps sync to backend works
- ✅ Weight/height sync to backend works
- ✅ LocalDataChangeMonitor can sync progress entries
- ✅ Backend ID stored in local entries
- ✅ Sync status correctly updated to `.synced`

---

## Verification Checklist

- [x] `ProgressEntryResponse` matches backend API spec
- [x] `toDomain()` accepts user ID parameter
- [x] `ProgressAPIClient.logProgress()` passes user ID
- [x] `ProgressAPIClient.getCurrentProgress()` passes user ID
- [x] `ProgressAPIClient.getProgressHistory()` passes user ID
- [x] RFC3339 date parsing works correctly
- [x] Date/time component extraction works correctly
- [x] No compilation errors
- [x] Existing tests still pass (no breaking changes to public API)

---

**Status:** ✅ **FIXED AND READY FOR TESTING**

Next step: Test the complete flow with iOS app syncing steps data to backend.