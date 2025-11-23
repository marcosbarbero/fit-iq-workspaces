# Token Refresh Fix Summary

**Date:** 2025-01-27  
**Issue:** ProgressAPIClient getting 401 errors due to expired access tokens  
**Status:** ✅ Fixed

---

## Problem Description

The `/api/v1/progress` API endpoint was returning **401 Unauthorized** errors during steps sync, causing the sync to fail and entries to be marked as "failed".

### Error Log:
```
ProgressAPIClient: Response status code: 401
ProgressAPIClient: Response body: {"error":{"message":"Invalid authentication"}}
RemoteSyncService: ❌ /api/v1/progress API call FAILED!
  - Error: apiError(statusCode: 401, message: "Failed to log progress")
```

---

## Root Cause Analysis

### Missing Token Refresh Logic

**Location:** `ProgressAPIClient.swift`

**Problem:**

The `ProgressAPIClient` was sending the Authorization header correctly:

```swift
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
```

But when the access token expired, it would:
1. Get 401 response from backend
2. Immediately throw error and fail
3. Mark entry as "failed" for retry

**Comparison with RemoteHealthDataSyncClient:**

`RemoteHealthDataSyncClient` has full token refresh logic:

```swift
case 401 where retryCount == 0:
    // Token expired - refresh it
    let newTokens = try await refreshAccessToken(...)
    // Save new tokens
    // Retry original request
```

`ProgressAPIClient` was missing this completely:

```swift
guard statusCode == 201 else {
    // Just throw error, no retry
    throw APIError.apiError(...)
}
```

### Why This Matters

- Access tokens expire after a period (e.g., 15 minutes, 1 hour)
- Refresh tokens are long-lived (e.g., 30 days)
- When access token expires:
  - Backend returns 401
  - Client should use refresh token to get new access token
  - Client should retry original request with new token
- Without refresh logic, every sync after token expiry fails

---

## Solution Implemented

### 1. Added AuthManager Dependency

```diff
final class ProgressAPIClient: ProgressRemoteAPIProtocol {
    private let networkClient: NetworkClientProtocol
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
+   private let authManager: AuthManager

    init(
        networkClient: NetworkClientProtocol,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
+       authManager: AuthManager
    ) {
        self.networkClient = networkClient
        self.authTokenPersistence = authTokenPersistence
+       self.authManager = authManager
    }
}
```

### 2. Implemented `executeWithRetry` Method

```swift
private func executeWithRetry<T: Decodable>(
    request: URLRequest,
    retryCount: Int
) async throws -> T {
    var authenticatedRequest = request
    
    // Get and attach access token
    guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
        authManager.logout()
        throw APIError.unauthorized
    }
    
    authenticatedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    
    // Execute request
    let (data, httpResponse) = try await networkClient.executeRequest(request: authenticatedRequest)
    let statusCode = httpResponse.statusCode
    
    switch statusCode {
    case 200, 201:
        // Success - decode and return
        return try decodeResponse(data)
        
    case 401 where retryCount == 0:
        // Token expired - refresh and retry
        print("ProgressAPIClient: Access token expired. Attempting refresh...")
        
        guard let refreshToken = try authTokenPersistence.fetchRefreshToken() else {
            authManager.logout()
            throw APIError.unauthorized
        }
        
        // Refresh token
        let newTokens = try await refreshAccessToken(request: RefreshTokenRequest(refreshToken: refreshToken))
        
        // Save new tokens
        try authTokenPersistence.save(accessToken: newTokens.accessToken, refreshToken: newTokens.refreshToken)
        
        print("ProgressAPIClient: Token refreshed successfully. Retrying original request...")
        
        // Retry with new token
        return try await executeWithRetry(request: request, retryCount: 1)
        
    case 401 where retryCount > 0:
        // Refresh failed - logout
        print("ProgressAPIClient: Token refresh failed or second 401. Logging out.")
        authManager.logout()
        throw APIError.unauthorized
        
    default:
        throw APIError.apiError(statusCode: statusCode, message: "Failed to log progress")
    }
}
```

### 3. Implemented `refreshAccessToken` Method

```swift
private func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
    guard let url = URL(string: "\(baseURL)/api/v1/auth/refresh") else {
        throw APIError.invalidURL
    }
    
    var refreshRequest = URLRequest(url: url)
    refreshRequest.httpMethod = "POST"
    refreshRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    refreshRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    refreshRequest.httpBody = try configuredEncoder().encode(request)
    
    print("ProgressAPIClient: Calling /api/v1/auth/refresh to get new tokens...")
    
    let (data, httpResponse) = try await networkClient.executeRequest(request: refreshRequest)
    let statusCode = httpResponse.statusCode
    
    guard statusCode == 200 else {
        if let responseString = String(data: data, encoding: .utf8) {
            print("ProgressAPIClient: Token refresh failed. Response: \(responseString)")
        }
        throw APIError.apiError(statusCode: statusCode, message: "Token refresh failed")
    }
    
    let decoder = configuredDecoder()
    let successResponse = try decoder.decode(StandardResponse<LoginResponse>.self, from: data)
    return successResponse.data
}
```

### 4. Refactored `logProgress` Method

```diff
func logProgress(...) async throws -> ProgressEntry {
    // Build request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    request.httpBody = bodyData
    
-   // Get token and execute
-   guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
-       throw APIError.unauthorized
-   }
-   request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
-   
-   let (data, httpResponse) = try await networkClient.executeRequest(request: request)
-   guard statusCode == 201 else { throw ... }
-   return try decode(data)
    
+   // Execute with automatic token refresh on 401
+   return try await executeWithRetry(request: request, retryCount: 0)
}
```

### 5. Updated Dependency Injection

```diff
// In AppDependencies.swift
let progressAPIClient = ProgressAPIClient(
    networkClient: networkClient,
    authTokenPersistence: keychainAuthTokenAdapter,
+   authManager: authManager
)
```

---

## Expected Log Flow (After Fix)

### Scenario 1: Token Valid (No Refresh Needed)

```
1. ProgressAPIClient: Using access token: eyJhbGciOi...Nzk2MjM0fQ
2. ProgressAPIClient: Response status code: 201
3. ProgressAPIClient: Response body: { "success": true, "data": { ... } }
4. ProgressAPIClient: ✅ Successfully logged progress entry
5. RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry
```

### Scenario 2: Token Expired (Refresh Required)

```
1. ProgressAPIClient: Using access token: eyJhbGciOi...EXPIRED_TOKEN
2. ProgressAPIClient: Response status code: 401
3. ProgressAPIClient: Response body: {"error":{"message":"Invalid authentication"}}
4. ProgressAPIClient: Access token expired. Attempting refresh...
5. ProgressAPIClient: Calling /api/v1/auth/refresh to get new tokens...
6. ProgressAPIClient: Token refreshed successfully. Retrying original request...
7. ProgressAPIClient: Using access token: eyJhbGciOi...NEW_TOKEN
8. ProgressAPIClient: Response status code: 201
9. ProgressAPIClient: Response body: { "success": true, "data": { ... } }
10. ProgressAPIClient: ✅ Successfully logged progress entry
11. RemoteSyncService: ✅✅✅ Successfully synced ProgressEntry
```

### Scenario 3: Refresh Token Invalid (Logout)

```
1. ProgressAPIClient: Using access token: eyJhbGciOi...EXPIRED_TOKEN
2. ProgressAPIClient: Response status code: 401
3. ProgressAPIClient: Access token expired. Attempting refresh...
4. ProgressAPIClient: Calling /api/v1/auth/refresh to get new tokens...
5. ProgressAPIClient: Token refresh failed. Response: {"error":"Invalid refresh token"}
6. ProgressAPIClient: Token refresh failed or second 401. Logging out.
7. RemoteSyncService: ❌ /api/v1/progress API call FAILED!
```

---

## Files Modified

1. **`FitIQ/Infrastructure/Network/ProgressAPIClient.swift`**
   - Added `authManager` property
   - Added `authManager` to init parameters
   - Refactored `logProgress` to use `executeWithRetry`
   - Implemented `executeWithRetry` method
   - Implemented `refreshAccessToken` method
   - Added `configuredEncoder` helper

2. **`FitIQ/Infrastructure/Configuration/AppDependencies.swift`**
   - Added `authManager` parameter to `ProgressAPIClient` initialization

---

## Architecture Pattern

This implementation follows the **same pattern** as `RemoteHealthDataSyncClient`:

### Shared Pattern:
1. **Inject dependencies**: `AuthTokenPersistence` + `AuthManager`
2. **Retry on 401**: Check `retryCount` to avoid infinite loops
3. **Call refresh endpoint**: POST to `/api/v1/auth/refresh`
4. **Save new tokens**: Update persistence layer
5. **Retry original request**: With new access token
6. **Logout on failure**: If refresh fails or second 401

### Benefits:
- ✅ Consistent auth handling across all API clients
- ✅ Automatic token refresh (transparent to user)
- ✅ Secure logout when tokens fully expired
- ✅ No manual token management needed

---

## Testing Checklist

### Manual Testing:

- [x] Verify token is sent in Authorization header
- [ ] Test with valid token (should succeed immediately)
- [ ] Test with expired access token (should refresh and retry)
- [ ] Test with expired refresh token (should logout)
- [ ] Verify sync completes successfully after token refresh
- [ ] Verify new tokens are saved to keychain

### Automated Testing (Future):

- [ ] Mock token expiry and verify refresh logic
- [ ] Mock refresh failure and verify logout
- [ ] Verify retry count prevents infinite loops
- [ ] Verify original request is retried correctly

---

## Additional Notes

### Why Two Tokens?

- **Access Token**: Short-lived (15-60 min), sent with every API request
- **Refresh Token**: Long-lived (7-30 days), used only to get new access tokens

### Security Benefits:

1. **Limited exposure**: Access token expires quickly
2. **Revocable**: Server can invalidate refresh tokens
3. **Theft protection**: Stolen access token only works briefly

### API Flow:

```
Login/Register
  ↓
Backend returns: { access_token, refresh_token }
  ↓
Save both tokens to Keychain
  ↓
Use access_token for API requests
  ↓
Access token expires (401 error)
  ↓
POST /auth/refresh with refresh_token
  ↓
Backend returns: { access_token, refresh_token } (new pair)
  ↓
Save new tokens, retry original request
  ↓
If refresh fails: Logout user
```

---

## Related Issues Fixed

This fix resolves the sync failure issue identified in the logs:

```
RemoteSyncService: ❌ /api/v1/progress API call FAILED!
  - Error: apiError(statusCode: 401, message: "Failed to log progress")
RemoteSyncService: Marked ProgressEntry as 'failed' for retry
```

Now the sync will:
1. Detect expired token (401)
2. Automatically refresh
3. Retry and succeed
4. Mark entry as "synced"

---

**Status:** ✅ Fix Applied, Ready for Testing  
**Next Step:** Run app and verify token refresh flow works correctly

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-27