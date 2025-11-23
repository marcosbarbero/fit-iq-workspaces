# Token Refresh Root Cause Analysis

## Investigation Summary

After tracing the entire token refresh flow, I've identified the **ROOT CAUSE** of the token refresh issues.

## The Root Cause

**File:** `RemoteAuthService.swift` Line 139

```swift
return AuthToken(
    accessToken: apiResponse.data.accessToken,
    refreshToken: apiResponse.data.refreshToken,
    expiresAt: Date().addingTimeInterval(3600)  // ← HARDCODED 1 HOUR!
)
```

### The Problem

1. **Hardcoded Expiration:** The app assumes ALL tokens expire in exactly 1 hour (3600 seconds)
2. **Backend Reality:** The backend likely returns tokens with different expiration times
3. **Mismatch:** App thinks token is valid when it's actually expired
4. **Result:** App uses expired access token → Gets 401 → Triggers refresh → Loop

## Evidence

### Same Issue in Multiple Places

**Login** (Line 95):
```swift
expiresAt: Date().addingTimeInterval(3600)  // 1 hour default
```

**Register** (Line 53):
```swift
expiresAt: Date().addingTimeInterval(3600)  // 1 hour default
```

**Refresh** (Line 139):
```swift
expiresAt: Date().addingTimeInterval(3600)  // 1 hour default
```

### Response Models Missing Expiration

```swift
struct RefreshTokenResponseData: Decodable {
    let accessToken: String
    let refreshToken: String
    // NO expires_at or expires_in field!
}
```

## The Actual Flow

```
1. User logs in
   └─> Backend returns token with REAL expiration (maybe 15 min?)
   └─> App saves token with FAKE expiration (1 hour)

2. After 15 minutes (real expiration)
   └─> App thinks token still valid for 45 more minutes
   └─> Makes API call with expired access token
   └─> Backend returns 401

3. App doesn't understand why 401
   └─> Tries to use "valid" access token again
   └─> Another 401
   └─> Confusion and loops

4. Eventually triggers token refresh
   └─> Backend: "refresh token is revoked" (because too much time passed)
   └─> App: *surprised pikachu face*
```

## The Solution

### Option 1: Get expiration from backend (BEST)

Ask backend to return `expires_at` or `expires_in` in response:

```json
{
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 900  // 15 minutes in seconds
  }
}
```

Update response models:
```swift
struct RefreshTokenResponseData: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int  // seconds until expiration
}
```

Calculate correct expiration:
```swift
expiresAt: Date().addingTimeInterval(TimeInterval(apiResponse.data.expiresIn))
```

### Option 2: Decode JWT (if using JWT)

If access tokens are JWTs, decode the `exp` claim:

```swift
func decodeJWTExpiration(token: String) -> Date? {
    let segments = token.components(separatedBy: ".")
    guard segments.count > 1 else { return nil }
    
    guard let payloadData = Data(base64Encoded: segments[1]) else { return nil }
    let payload = try? JSONDecoder().decode([String: Any].self, from: payloadData)
    
    if let exp = payload?["exp"] as? TimeInterval {
        return Date(timeIntervalSince1970: exp)
    }
    return nil
}
```

### Option 3: Conservative default (TEMPORARY FIX)

Use a much shorter default expiration:

```swift
expiresAt: Date().addingTimeInterval(600)  // 10 minutes (conservative)
```

This will cause more frequent refreshes, but prevents using expired tokens.

## Recommended Fix

1. **Immediate:** Use Option 3 (conservative default of 10-15 minutes)
2. **Proper:** Implement Option 1 or 2 after coordinating with backend team

## Testing

To verify this is the root cause:

1. Add logging to see actual vs expected token expiration
2. Make API calls and watch for 401s when token should be "valid"
3. Check how long tokens are actually valid from backend
4. Compare with app's assumption

## Files to Fix

1. `RemoteAuthService.swift` - All three places (login, register, refresh)
2. Response models - Add `expiresIn` or `expiresAt` fields
3. Documentation - Update API contract

## Prevention

- Never hardcode security-related timeouts
- Always get expiration from authoritative source (backend)
- Add validation to ensure expiration makes sense
- Log mismatches between expected and actual token validity
