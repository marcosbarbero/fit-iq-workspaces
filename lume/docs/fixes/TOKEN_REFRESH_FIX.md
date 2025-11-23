# Token Refresh Fix - Revoked Token Handling

**Date:** 2025-01-28
**Status:** ✅ Fixed
**Priority:** Critical

## Issue

When refresh token is revoked (401), the app was not properly cleaning up:
- Token remained in storage
- UserSession not ended
- App kept retrying with invalid token

## Error Log
```
🔄 [RemoteAuthService] Token refresh response status: 401
❌ [RemoteAuthService] 401 - Token expired or invalid: {"error":{"message":"refresh token has been revoked"}}
❌ [AuthRepository] Token refresh failed: tokenExpired
❌ [OutboxProcessor] Token refresh failed: Your session has expired. Please log in again
```

## Solution

### 1. New Error Type
Added `tokenRevoked` to `AuthenticationError` enum for clearer distinction.

### 2. Detection in RemoteAuthService
Detect "revoked" in 401 response and throw specific error.

### 3. Complete Cleanup
When token refresh fails:
- ✅ Delete token from storage
- ✅ End UserSession
- ✅ Set isAuthenticated = false
- ✅ Redirect to login

### 4. Files Modified

**RemoteAuthService.swift** - Detect revoked tokens
**AuthRepository.swift** - Handle tokenRevoked, clear storage & session
**RootView.swift** - Clear everything on refresh failure
**OutboxProcessorService.swift** - End session on failure
**RegisterUserUseCase.swift** - Add tokenRevoked case

## Testing

1. Let refresh token expire/get revoked
2. App should:
   - Show login screen
   - Not retry infinitely
   - Clear all local auth state

## Result

✅ Clean logout when refresh token revoked
✅ No infinite retry loops
✅ Proper session cleanup
