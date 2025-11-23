# Troubleshooting 401 Unauthorized Errors

**Last Updated:** 2025-01-15  
**Status:** Active Guide

---

## Overview

This guide helps diagnose and resolve **401 Unauthorized** errors that occur when the Lume iOS app attempts to sync data with the backend.

---

## What is a 401 Error?

**401 Unauthorized** means the backend rejected the request because:
- No authentication token was provided
- The token is invalid or malformed
- The token has expired
- The backend doesn't recognize the token

---

## Automatic Handling in Lume

As of version 2025-01-15, Lume **automatically handles 401 errors**:

1. **Detects 401 response** from backend during outbox processing
2. **Clears invalid token** from Keychain
3. **Logs out user** automatically
4. **Shows login screen** to re-authenticate

### Expected Logs

```
📦 [OutboxProcessor] Processing 1 pending events
=== HTTP Request ===
URL: https://fit-iq-backend.fly.dev/api/v1/wellness/mood-entries
Method: POST
Status: 401
Authorization: Bearer eyJhbGciOiJIUzI1NiIs... (150 chars)
Response: unauthorized
===================
🔐 [OutboxProcessor] 401 Unauthorized - token invalid or expired
⚠️ [OutboxProcessor] User needs to re-authenticate
🛑 [OutboxProcessor] Stopping event processing - authentication required
🔐 [lumeApp] Authentication required - logging out user
```

After these logs, the user is automatically returned to the login screen.

---

## Common Causes & Solutions

### 1. User Not Logged In

**Symptoms:**
- No token logs appear
- 401 errors immediately after app launch
- User ID is all zeros: `00000000-0000-0000-0000-000000000001`

**Solution:**
- Complete registration or login in the app
- App will automatically redirect to login screen

### 2. Token Expired

**Symptoms:**
- 401 errors after using app for a while
- Token logs show: `isExpired: true`
- Refresh token also expired

**Solution:**
- App automatically logs user out
- User needs to log in again
- Token refresh happens automatically if refresh token is still valid

### 3. Mock/Test Token in Production

**Symptoms:**
- Using test data or mock authentication
- Backend returns 401 for valid-looking token
- User ID is hardcoded: `00000000-0000-0000-0000-000000000001`

**Solution:**
- Ensure you're using real authentication, not mock data
- Complete registration through the app's UI
- Backend must have user account matching the token

### 4. Backend Token Validation Issue

**Symptoms:**
- Token looks valid in logs
- Token not expired
- Backend consistently returns 401

**Solution:**
- Verify backend JWT validation is configured correctly
- Check backend expects `Authorization: Bearer <token>` format
- Confirm backend and app use same JWT secret (production only)
- Check backend logs for token validation errors

### 5. Wrong Backend Environment

**Symptoms:**
- App configured for production backend
- Using staging/development token
- 401 errors despite valid login

**Solution:**
- Ensure `config.plist` points to correct backend
- Verify token was issued by the same backend app is calling
- Check `AppConfiguration.shared.backendBaseURL`

---

## Diagnostic Steps

### Step 1: Enable Debug Logging

The app already logs authentication details. Look for these key messages:

```
🔑 [OutboxProcessor] Token retrieved: expires at <date>, isExpired: <bool>, needsRefresh: <bool>
🔑 [OutboxProcessor] Token (first 20 chars): eyJhbGciOiJIUzI1NiIs...
Authorization: Bearer eyJhbGciOiJIUzI1NiIs... (150 chars)
```

### Step 2: Check Token Status

Look for token status in logs:

**Good Token:**
```
🔑 [OutboxProcessor] Token retrieved: expires at Jan 16, 2025, isExpired: false, needsRefresh: false
```

**Expired Token:**
```
🔑 [OutboxProcessor] Token retrieved: expires at Jan 14, 2025, isExpired: true, needsRefresh: true
🔄 [OutboxProcessor] Token expired or needs refresh, attempting refresh...
```

**No Token:**
```
⚠️ [OutboxProcessor] No token available, skipping processing
⚠️ [OutboxProcessor] User needs to log in
```

### Step 3: Verify Authentication State

In the app:
1. Check if you see the login screen or main app
2. If main app is visible, you have a token (might be invalid)
3. If login screen appears, no valid token exists

### Step 4: Test with Fresh Login

1. **Completely log out:**
   - Go to Profile tab
   - Tap "Log Out"
   - Confirm token is cleared from logs

2. **Log in again:**
   - Use valid credentials
   - Watch logs for token retrieval
   - Verify successful authentication

3. **Test sync:**
   - Create a mood entry
   - Watch outbox processing logs
   - Should see 201 Created (not 401)

### Step 5: Check Backend Status

**Using curl:**
```bash
# Test with your actual token
curl -X POST https://fit-iq-backend.fly.dev/api/v1/wellness/mood-entries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "mood_score": 8,
    "emotions": ["happy"],
    "notes": "Testing",
    "logged_at": "2025-01-15T14:30:00Z"
  }'
```

**Expected responses:**
- **201 Created** - Token is valid ✅
- **401 Unauthorized** - Token is invalid ❌
- **404 Not Found** - Endpoint doesn't exist
- **500 Server Error** - Backend issue

---

## Manual Token Management

### Check if Token Exists

```swift
// In Xcode Console or Debug View
let tokenStorage = dependencies.tokenStorage
let token = try await tokenStorage.getToken()
print("Token exists: \(token != nil)")
if let token = token {
    print("Expires: \(token.expiresAt)")
    print("Expired: \(token.isExpired)")
}
```

### Manually Clear Token

```swift
// Force user to log in again
let tokenStorage = dependencies.tokenStorage
try await tokenStorage.deleteToken()
authViewModel.isAuthenticated = false
```

### Manually Refresh Token

```swift
// Try to refresh current token
let refreshUseCase = dependencies.refreshTokenUseCase
do {
    let newToken = try await refreshUseCase.execute()
    print("Token refreshed successfully")
} catch {
    print("Refresh failed: \(error)")
    // User needs to log in
}
```

---

## Testing Authentication Flow

### Test 1: Fresh Login
1. Delete app from device/simulator
2. Reinstall app
3. Complete registration
4. Create mood entry
5. **Expected:** 201 Created ✅

### Test 2: Token Expiration
1. Log in successfully
2. Wait for token to expire (or manually set past date)
3. Create mood entry
4. **Expected:** Automatic refresh, then 201 ✅

### Test 3: Refresh Token Expiration
1. Log in successfully
2. Expire both access and refresh tokens
3. Create mood entry
4. **Expected:** Automatic logout, show login screen ✅

### Test 4: Invalid Token
1. Manually corrupt token in Keychain
2. Create mood entry
3. **Expected:** 401, automatic logout ✅

---

## Backend Integration Checklist

When setting up backend authentication:

- [ ] Backend accepts `Authorization: Bearer <token>` header
- [ ] Backend validates JWT signature
- [ ] Backend checks token expiration
- [ ] Backend returns 401 for invalid/expired tokens
- [ ] Backend issues both access and refresh tokens on login
- [ ] Refresh endpoint works: `POST /api/v1/auth/refresh`
- [ ] Token expiration times are reasonable (e.g., 1 hour access, 7 days refresh)

---

## AppMode Behavior

### Local Mode
```swift
AppMode.current = .local
```
- ✅ No backend calls
- ✅ No authentication required
- ✅ No 401 errors possible
- ✅ Perfect for offline testing

### Mock Backend Mode
```swift
AppMode.current = .mockBackend
```
- ✅ Uses mock authentication
- ✅ No real backend calls
- ✅ No 401 errors from real backend
- ✅ Good for testing without backend

### Production Mode
```swift
AppMode.current = .production
```
- ⚠️ Real backend calls
- ⚠️ Real authentication required
- ⚠️ 401 errors possible
- ✅ Automatic logout on auth failure

---

## Security Best Practices

### ✅ Current Implementation

- **Keychain Storage:** Tokens stored securely in iOS Keychain (not UserDefaults)
- **Automatic Cleanup:** Invalid tokens removed immediately on 401
- **Secure Logging:** Only first 20-30 chars of token logged
- **HTTPS Only:** All backend communication over HTTPS
- **Token Refresh:** Automatic refresh before expiration
- **Logout on Failure:** User logged out if authentication fails

### ❌ Anti-Patterns to Avoid

- Storing tokens in UserDefaults (insecure)
- Logging full tokens to console (security risk)
- Ignoring 401 errors (infinite retry loops)
- Not refreshing tokens (unnecessary re-logins)
- Hardcoding tokens (never do this)

---

## Emergency Recovery

### User Can't Log In

1. **Delete app** - removes all local data including tokens
2. **Reinstall app** - fresh start
3. **Register new account** - or log in with existing
4. **Test sync** - create mood entry

### Stuck in 401 Loop

This shouldn't happen with automatic logout, but if it does:

1. **Check logs** - verify automatic logout triggered
2. **Force quit app** - swipe up in app switcher
3. **Reopen app** - should show login screen
4. **If still stuck** - delete and reinstall app

### Backend Issues

If backend is returning 401 for valid tokens:

1. **Check backend logs** - look for JWT validation errors
2. **Verify backend config** - JWT secret, expiration times
3. **Test with curl** - isolate if issue is app or backend
4. **Contact backend team** - provide example token and error logs

---

## Related Documentation

- [Outbox Pattern Implementation](OUTBOX_PATTERN_IMPLEMENTATION.md)
- [Backend Integration Guide](BACKEND_INTEGRATION.md)
- [Logging Guide](LOGGING_GUIDE.md)
- [API Specification](swagger.yaml)

---

## Quick Reference

### Log Messages

| Log Message | Meaning | Action |
|-------------|---------|--------|
| `⚠️ No token available` | User not logged in | Log in |
| `🔄 Token expired or needs refresh` | Token expired | Automatic refresh |
| `❌ Token refresh failed` | Can't refresh | Automatic logout |
| `🔐 401 Unauthorized` | Backend rejected token | Automatic logout |
| `✅ Token refreshed successfully` | Refresh worked | Continue |

### HTTP Status Codes

| Code | Meaning | App Response |
|------|---------|--------------|
| 200-299 | Success | Process normally |
| 401 | Unauthorized | Clear token, logout |
| 404 | Not Found | Retry with backoff |
| 500 | Server Error | Retry with backoff |

---

**Remember:** As of the latest update, Lume handles 401 errors automatically. Users are seamlessly logged out and redirected to the login screen when authentication fails.

**If you see persistent 401 errors despite fresh login, the issue is likely on the backend side.**