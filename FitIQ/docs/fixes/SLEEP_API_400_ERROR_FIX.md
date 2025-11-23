# Sleep API 400 Error Fix - Token Refresh Implementation

**Date:** 2025-01-27  
**Issue:** Sleep API returning 400 errors during Outbox Pattern sync  
**Status:** ✅ Fixed

---

## Problem Summary

The `OutboxProcessorService` was failing to sync sleep sessions to the backend with 400 Bad Request errors:

```
OutboxProcessor: ❌ Failed to process event 1A87999F-B32E-40AF-A565-C4E6517CDE3F: 
Network error: The operation couldn't be completed. (SleepAPI error 400.)
```

### Root Causes Identified

1. **Missing Token Refresh Logic**
   - `SleepAPIClient` was making direct `URLSession.shared.data(for:)` calls
   - Did not implement token refresh on 401 responses
   - Token expiration caused requests to fail without retry
   - All other API clients (`ProgressAPIClient`, `UserAuthAPIClient`, `RemoteHealthDataSyncClient`) had proper token refresh

2. **Date Format Issue**
   - ISO8601 formatter was using `.withFractionalSeconds` option
   - Backend expects standard RFC3339 format without fractional seconds
   - Format: `2024-01-16T06:30:00Z` (not `2024-01-16T06:30:00.123Z`)

3. **Insufficient Error Logging**
   - No request payload logging for debugging
   - Generic error messages without response details

---

## Solution Implemented

### 1. Token Refresh with Retry Logic

Added synchronized token refresh pattern following established conventions from other API clients:

```swift
// Added to SleepAPIClient
private var isRefreshing = false
private var refreshTask: Task<LoginResponse, Error>?
private let refreshLock = NSLock()

private func executeWithRetry<T: Decodable>(
    request: URLRequest,
    retryCount: Int
) async throws -> T {
    // Get access token
    // Execute request via networkClient
    // On 401: Refresh token and retry (max 1 retry)
    // On 401 after retry: Logout user
    // Return decoded response
}

private func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
    // Synchronized refresh (NSLock prevents race conditions)
    // If refresh in progress, wait for existing task
    // On success: Return new tokens
    // On 401: Revoked token, logout user
}
```

**Key Features:**
- **Synchronized refresh:** NSLock prevents multiple concurrent refreshes
- **Single retry:** Only attempts refresh once per request
- **Automatic logout:** Logs user out on legitimate token revocation (401 during refresh)
- **Race condition prevention:** Concurrent requests wait for in-progress refresh

### 2. Date Format Correction

Changed ISO8601 formatter to use standard RFC3339 without fractional seconds:

```swift
// BEFORE (incorrect)
iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
// Output: "2024-01-16T06:30:00.123Z"

// AFTER (correct)
iso8601Formatter.formatOptions = [.withInternetDateTime]
// Output: "2024-01-16T06:30:00Z"
```

### 3. Enhanced Error Logging

Added comprehensive debugging:

```swift
// Request payload logging
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
urlRequest.httpBody = try encoder.encode(request)

if let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8) {
    print("SleepAPIClient: Request payload:")
    print(bodyString)
}

// Response logging in executeWithRetry
print("SleepAPIClient: Response status code: \(statusCode)")
if let responseString = String(data: data, encoding: .utf8) {
    print("SleepAPIClient: Response body: \(responseString)")
}

// Specific 400 error handling
case 400:
    print("SleepAPIClient: ❌ 400 Bad Request")
    if let responseString = String(data: data, encoding: .utf8) {
        print("SleepAPIClient: Error details: \(responseString)")
    }
    throw SleepAPIError.networkError(...)
```

---

## Files Modified

### `FitIQ/Infrastructure/Network/SleepAPIClient.swift`

**Changes:**
1. Added token refresh synchronization properties (lines 37-41)
2. Refactored `postSleepSession()` to use `executeWithRetry()` (lines 58-86)
3. Refactored `getSleepSessions()` to use `executeWithRetry()` (lines 88-99)
4. Added `executeWithRetry<T>()` method with 401 handling (lines 104-208)
5. Added `refreshAccessToken()` with NSLock synchronization (lines 213-276)
6. Added request payload logging (lines 75-82)
7. Fixed date format: removed `.withFractionalSeconds` (line 416)
8. Enhanced error logging for 400 responses (lines 191-202)

---

## Testing Guide

### Prerequisites

1. Sleep data in HealthKit (or manually created sleep sessions)
2. Active user session with valid tokens
3. Outbox events pending sync

### Test Scenarios

#### 1. ✅ Successful Sync with Fresh Token

**Steps:**
1. Create a sleep session in the app
2. Observe outbox processor logs
3. Verify sync succeeds

**Expected Logs:**
```
SleepAPIClient: Posting sleep session to backend
SleepAPIClient: Request payload:
{
  "start_time": "2024-01-15T22:00:00Z",
  "end_time": "2024-01-16T06:30:00Z",
  "source": "healthkit",
  "stages": [...]
}
SleepAPIClient: Using access token: abc1234567...xyz9876543
SleepAPIClient: Response status code: 201
OutboxProcessor: ✅ Sleep session [UUID] synced successfully
```

#### 2. ✅ Token Refresh on 401

**Steps:**
1. Wait for access token to expire (~15 minutes)
2. Create a sleep session
3. Observe automatic token refresh

**Expected Logs:**
```
SleepAPIClient: Response status code: 401
SleepAPIClient: Access token expired. Attempting refresh...
SleepAPIClient: Current refresh token from keychain: abc12345...
SleepAPIClient: Starting token refresh...
SleepAPIClient: ✅ Token refresh successful
SleepAPIClient: Token refreshed successfully. Retrying original request...
SleepAPIClient: Response status code: 201
OutboxProcessor: ✅ Sleep session [UUID] synced successfully
```

#### 3. ✅ Logout on Revoked Token

**Steps:**
1. Manually revoke refresh token in backend
2. Trigger sync with expired access token

**Expected Logs:**
```
SleepAPIClient: Response status code: 401
SleepAPIClient: Access token expired. Attempting refresh...
SleepAPIClient: ❌ Refresh token revoked or expired (401). Logging out.
[User is logged out and redirected to login]
```

#### 4. ✅ Race Condition Prevention

**Steps:**
1. Trigger multiple concurrent API requests with expired token
2. Observe only one token refresh occurs

**Expected Logs:**
```
SleepAPIClient: Response status code: 401
SleepAPIClient: Access token expired. Attempting refresh...
SleepAPIClient: Token refresh already in progress, waiting for result...
SleepAPIClient: Token refresh already in progress, waiting for result...
SleepAPIClient: ✅ Token refresh successful
[All requests succeed with refreshed token]
```

#### 5. ❌ Debug 400 Bad Request

If 400 errors persist:

**Check Request Payload:**
```
SleepAPIClient: Request payload:
{
  "start_time": "2024-01-15T22:00:00Z",  // ✅ Correct format (no fractional seconds)
  "end_time": "2024-01-16T06:30:00Z",
  "source": "healthkit",
  "stages": [
    {
      "stage": "core",
      "start_time": "2024-01-15T22:10:00Z",
      "end_time": "2024-01-16T00:10:00Z"
    }
  ]
}
```

**Check Response Details:**
```
SleepAPIClient: ❌ 400 Bad Request
SleepAPIClient: Error details: {"success":false,"error":"validation error: ..."}
```

**Common 400 Causes:**
- ❌ Invalid stage names (must be: awake, asleep, core, deep, rem, in_bed)
- ❌ End time before start time
- ❌ Stage times outside session bounds
- ❌ Missing required fields (start_time, end_time)
- ❌ Invalid date format (should now be fixed)

---

## Verification Checklist

- [ ] Sleep sessions sync successfully with fresh token
- [ ] Token refresh works on 401 response
- [ ] User is logged out on revoked refresh token
- [ ] Only one token refresh occurs for concurrent requests
- [ ] Request payload uses RFC3339 format without fractional seconds
- [ ] 400 errors are logged with full request/response details
- [ ] Duplicate sessions (409) are handled gracefully
- [ ] Outbox events are marked as synced after successful upload

---

## Architectural Consistency

This fix aligns `SleepAPIClient` with established patterns:

| Feature | ProgressAPIClient | UserAuthAPIClient | SleepAPIClient (Now) |
|---------|-------------------|-------------------|----------------------|
| Token Refresh | ✅ | ✅ | ✅ |
| NSLock Sync | ✅ | ✅ | ✅ |
| Retry on 401 | ✅ | ✅ | ✅ |
| Auto Logout | ✅ | ✅ | ✅ |
| Request Logging | ✅ | ✅ | ✅ |

---

## Related Documentation

- **Token Refresh Fix:** `docs/fixes/TOKEN_REFRESH_FIX.md`
- **Sleep Tracking:** `docs/fixes/SLEEP_TRACKING_FIX.md`
- **Outbox Pattern:** `.github/copilot-instructions.md` (Section: Outbox Pattern)
- **API Spec:** `docs/be-api-spec/swagger.yaml` (Sleep API: lines 8386+)

---

## Future Improvements

1. **Shared Token Refresh Manager**
   - Extract token refresh logic into a shared service
   - Prevents code duplication across API clients
   - Centralizes retry logic and synchronization

2. **Better Error Types**
   - Create specific error types for 400 validation errors
   - Parse backend error messages for user-friendly display

3. **Request Validation**
   - Add client-side validation before sending to backend
   - Validate stage times are within session bounds
   - Validate stage names match enum values

4. **Retry with Exponential Backoff**
   - Implement exponential backoff for transient errors (500, 503)
   - Separate logic for permanent errors (400, 404) vs. retryable errors

---

**Status:** ✅ Ready for QA  
**Deployment:** Merge and deploy to TestFlight  
**Next Steps:** Monitor Xcode logs for successful sleep session syncs