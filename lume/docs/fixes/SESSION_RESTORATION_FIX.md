# Session Restoration Fix

**Date:** 2025-01-16  
**Issue:** App shows authenticated view without data after failed login  
**Status:** ✅ Fixed

---

## Problem

### Symptoms
1. User attempts to login but profile fetch fails (e.g., parsing error)
2. App shows error, user dismisses it
3. User closes and reopens app
4. App shows authenticated view (MainTabView) but with no data
5. Attempting to view moods/journals shows "User not authenticated" error

### Root Cause

**Login Flow Issue:**
```
1. User enters credentials
2. AuthRepository.login() is called
3. Token is saved to Keychain ✅
4. Profile fetch fails ❌ (parsing error, network issue, etc.)
5. Exception thrown, but token is ALREADY saved
6. AuthViewModel catches error, sets isAuthenticated = false
7. Login screen shown again (correct)

8. User closes app
9. App reopens
10. RootView.checkAuthenticationStatus() runs
11. Finds token in Keychain ✅
12. Token is valid and not expired ✅
13. Sets isAuthenticated = true ✅
14. BUT UserSession was never initialized ❌
15. Shows MainTabView with no data
```

**The Problem:**
- Token exists in Keychain (saved during failed login)
- UserSession was never started (profile fetch failed)
- RootView checked token existence but not UserSession state
- App showed authenticated UI without actual session data

---

## Solution

### 1. Check UserSession Before Token
Modified `RootView.checkAuthenticationStatus()` to prioritize UserSession:

**Flow:**
```
1. Check UserSession.isAuthenticated first
   - If true → User is authenticated, show app
   - If false → Continue to token check

2. Check if token exists in Keychain
   - If no token → Show login
   - If token exists → Continue

3. Fetch profile to restore UserSession
   - Success → Start session, show app
   - Failure → Clear token, show login
```

### 2. Fetch Profile on Token-Only Restart
When app finds token but no UserSession, fetch profile to restore session:

**Code:**
```swift
// Token is valid, need to fetch profile to restore session
let profile = try await dependencies.userProfileService.fetchCurrentUserProfile(
    accessToken: token.accessToken
)

guard let userId = profile.userIdUUID else {
    // Invalid profile, clear token
    try? await dependencies.tokenStorage.deleteToken()
    authViewModel.isAuthenticated = false
    return
}

// Restore UserSession
UserSession.shared.startSession(
    userId: userId,
    email: profile.email,
    name: profile.name,
    dateOfBirth: profile.dateOfBirthDate
)

// Migrate existing data
Task {
    let migration = UserIdMigration(modelContext: dependencies.modelContext)
    try? await migration.migrateToAuthenticatedUser(newUserId: userId)
}

authViewModel.isAuthenticated = true
```

### 3. Clear Token on Profile Fetch Failure
If profile fetch fails, delete the orphaned token:

```swift
catch {
    print("❌ [RootView] Failed to restore session: \(error)")
    // Clear invalid token
    try? await dependencies.tokenStorage.deleteToken()
    authViewModel.isAuthenticated = false
}
```

### 4. Offline Requires Prior Session
Offline mode only works if UserSession was previously established:

```swift
// Offline with token but no session
if !UserSession.shared.isAuthenticated && !networkMonitor.isConnected {
    print("📴 [RootView] Offline with token but no session - need to login online first")
    // Can't fetch profile without internet
    try? await dependencies.tokenStorage.deleteToken()
    authViewModel.isAuthenticated = false
}
```

---

## Implementation

### Updated File: RootView.swift

**Changes:**
1. Profile fetch when token exists but session doesn't
2. Proper error handling with token cleanup
3. UserSession restoration with migration
4. Offline check for session existence

**Key Logic:**
```swift
// STEP 1: Check UserSession first (offline-first)
if UserSession.shared.isAuthenticated {
    authViewModel.isAuthenticated = true
    return
}

// STEP 2: No session but token exists
guard let token = try await tokenStorage.getToken() else {
    authViewModel.isAuthenticated = false
    return
}

// STEP 3: Fetch profile to restore session
if !token.isExpired {
    let profile = try await fetchProfile(token: token.accessToken)
    UserSession.shared.startSession(...)
    authViewModel.isAuthenticated = true
}
```

---

## Testing

### Test Case 1: Failed Login Recovery
**Steps:**
1. Attempt login (let it fail at profile fetch)
2. Close app
3. Reopen app

**Expected:**
- Shows login screen (not authenticated view)
- No orphaned token in Keychain
- Clean slate for retry

**Before Fix:** ❌ Showed authenticated view with no data  
**After Fix:** ✅ Shows login screen

### Test Case 2: Successful Login Then Restart
**Steps:**
1. Login successfully
2. Close app
3. Reopen app (online)

**Expected:**
- Fetches profile to restore UserSession
- Shows authenticated view with data
- All moods/journals visible

**Before Fix:** ✅ Already worked  
**After Fix:** ✅ Still works

### Test Case 3: Offline Restart
**Steps:**
1. Login successfully online
2. Close app
3. Enable Airplane Mode
4. Reopen app

**Expected:**
- UserSession exists from previous login
- Shows authenticated view with local data
- No network calls attempted

**Before Fix:** ✅ Worked if session existed  
**After Fix:** ✅ Works, better validation

### Test Case 4: Offline with Token but No Session
**Steps:**
1. Manually place token in Keychain (simulate partial failure)
2. Ensure no UserSession
3. Enable Airplane Mode
4. Open app

**Expected:**
- Cannot restore session without internet
- Clears orphaned token
- Shows login screen

**Before Fix:** ❌ Showed authenticated view with no data  
**After Fix:** ✅ Shows login screen, clears token

---

## Expected Logs

### Successful Session Restoration
```
⚠️ [RootView] No local session found, checking stored token
🌐 [RootView] Found token, online - validating
✅ [RootView] Token valid, fetching profile to restore session
🔍 [UserProfileService] Fetching user profile from: ...
📊 [UserProfileService] Response status: 200
✅ [UserProfileService] Profile fetched successfully for user: Marcos Barbero
✅ [RootView] Session restored successfully
🔄 [UserIdMigration] Starting migration to user ID: ...
✅ [UserIdMigration] Migration complete: X mood entries, Y journal entries
```

### Failed Session Restoration (Clear Token)
```
⚠️ [RootView] No local session found, checking stored token
🌐 [RootView] Found token, online - validating
✅ [RootView] Token valid, fetching profile to restore session
🔍 [UserProfileService] Fetching user profile from: ...
❌ [UserProfileService] Unexpected error: keyNotFound(...)
❌ [RootView] Failed to restore session: networkError(...)
🗑️ [RootView] Clearing invalid token
```

### Offline with No Session
```
⚠️ [RootView] No local session found, checking stored token
📴 [RootView] Offline with token but no session - need to login online first
🗑️ [RootView] Clearing token, showing login
```

---

## Edge Cases Handled

### 1. Partial Login Failure
- Token saved but profile fetch failed
- **Handled:** Clear token on next launch if can't restore session

### 2. Network Interruption During Login
- Token saved, then network drops before profile fetch
- **Handled:** Next launch attempts profile fetch, clears token if fails

### 3. Invalid Token After Restart
- Token exists but backend rejects it (expired, revoked, etc.)
- **Handled:** Profile fetch fails, token cleared, login required

### 4. Offline First Launch
- Token exists, user offline, no prior UserSession
- **Handled:** Can't restore without internet, clear token, require login

### 5. Multiple Failed Login Attempts
- Each attempt leaves orphaned token
- **Handled:** Token cleared on failed restoration, clean slate for retry

---

## Benefits

### User Experience
- ✅ No confusing "authenticated but no data" state
- ✅ Clear error messages on failure
- ✅ Automatic session restoration when possible
- ✅ Proper offline support when session exists
- ✅ Clean recovery from partial failures

### Technical
- ✅ Token and session states always in sync
- ✅ No orphaned tokens in Keychain
- ✅ Proper error handling at all stages
- ✅ Background migration when session restored
- ✅ Defensive coding against edge cases

---

## Related Issues

### Issue 1: API Parsing Errors
- Fixed separately in `USER_PROFILE_API_FIX.md`
- Ensures profile fetch succeeds with correct model

### Issue 2: Data Migration
- Fixed separately in `USER_DATA_MIGRATION.md`
- Ensures old data visible after authentication

### Combined Effect
All three fixes together provide:
1. Correct API parsing (profile fetch works)
2. Proper session restoration (no orphaned state)
3. Data migration (old entries visible)

---

## Prevention

### Code Review Checklist
When modifying authentication flow:
- [ ] Verify UserSession.startSession() is called on success
- [ ] Check token is cleared on authentication failure
- [ ] Ensure token and session states are consistent
- [ ] Test app restart scenarios (online and offline)
- [ ] Test failed login recovery
- [ ] Verify no "authenticated without data" states

### Testing Checklist
- [ ] Failed login → Close app → Reopen → Should show login
- [ ] Successful login → Close app → Reopen → Should show data
- [ ] Login online → Close → Reopen offline → Should show cached data
- [ ] Partial failure → Reopen → Should recover cleanly

---

## Future Improvements

### 1. Atomic Authentication
Make token save and session start atomic:
```swift
// Either both succeed or both fail
try await withTransaction {
    try await tokenStorage.saveToken(token)
    UserSession.shared.startSession(...)
}
```

### 2. Session Validity Indicator
Add flag to track if session is fully initialized:
```swift
UserSession.isFullyInitialized // true only after profile fetch
```

### 3. Automatic Retry
Add automatic retry for failed profile fetch:
```swift
retry(maxAttempts: 3, delay: 2.0) {
    try await fetchProfile()
}
```

### 4. Session Health Check
Periodic validation that token and session match:
```swift
func validateSessionHealth() async -> Bool {
    let hasToken = (try? await tokenStorage.getToken()) != nil
    let hasSession = UserSession.shared.isAuthenticated
    return hasToken == hasSession // Should always match
}
```

---

## Summary

**Problem:** Failed login left orphaned token, causing authenticated UI without session data

**Solution:** Check UserSession first, fetch profile to restore session on token-only restart, clear token on failure

**Result:** Token and session states always in sync, no orphaned states, proper error recovery

**Status:** ✅ Fixed and tested

**Impact:** Critical - Prevents confusing UI states and ensures data integrity

---

**Files Modified:** 1 (RootView.swift)  
**Lines Changed:** ~60  
**Risk Level:** Low (defensive coding, better error handling)  
**Breaking Changes:** None (behavior improvement only)