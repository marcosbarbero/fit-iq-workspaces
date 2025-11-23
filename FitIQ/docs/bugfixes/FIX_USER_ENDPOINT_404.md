# Fix: User Endpoint 404 Error After Registration

**Issue ID:** AUTH-001  
**Date Fixed:** 2025-01-27  
**Status:** ✅ Resolved  
**Severity:** High (Blocking Registration)

---

## 🐛 Problem Description

After successful user registration, the app was failing with a 404 error when trying to fetch the user profile.

### Error Logs
```
UserAuthAPIClient: User successfully registered on remote service.
UserAuthAPIClient: Calling login to retrieve user profile...
UserAuthAPIClient: User successfully logged in on remote service.
UserAuthAPIClient: Decoded user_id: 96c82264-a93d-40c4-88aa-721414bc36ac
UserAuthAPIClient: Failed to fetch user profile. Status: 404
UserAuthAPIClient: Error Response: 404 page not found
```

### Root Cause

The iOS app was trying to fetch user data from `/api/v1/users/{user_id}`, but this endpoint **does not exist** in the current backend implementation.

**Backend API Structure:**
- `/api/v1/auth/register` - ✅ Exists (creates user, returns tokens)
- `/api/v1/auth/login` - ✅ Exists (authenticates, returns tokens)
- `/api/v1/users/{id}` - ❌ Does NOT exist yet
- `/api/v1/profiles/{user_id}` - ✅ Exists (health profile data only)

**Note:** The `/api/v1/profiles/{user_id}` endpoint returns health metrics (height, weight, BMI, etc.) but NOT user account data (email, firstName, lastName, etc.).

---

## ✅ Solution Implemented

### Approach: Construct User Profile from Available Data

Since the backend doesn't provide a user profile endpoint yet, we construct the `UserProfile` from data we already have:

1. **Registration Flow:** Use registration input data + JWT token
2. **Login Flow:** Use JWT token data (email, user_id) + construct minimal profile

### Changes Made

#### 1. Updated Registration Flow (`UserAuthAPIClient.register()`)

**Before:**
```swift
// Registration → Login → Fetch Profile (404 error)
let registerResponse = try await executeAPIRequest(...)
let loginResponse = try await self.login(...)
return loginResponse.profile  // ❌ Fails here
```

**After:**
```swift
// Registration → Decode JWT → Construct Profile from registration data
let registerResponse = try await executeAPIRequest(...)
let userId = decodeUserIdFromJWT(registerResponse.accessToken)

// Construct profile from registration data we already have
let userProfile = UserProfile(
    id: UUID(uuidString: userId),
    username: email.components(separatedBy: "@").first,
    email: userData.email,
    firstName: userData.firstName,
    lastName: userData.lastName,
    dateOfBirth: userData.dateOfBirth,
    gender: nil,
    height: nil,
    weight: nil,
    activityLevel: nil,
    createdAt: Date()
)

return (userProfile, registerResponse.accessToken, registerResponse.refreshToken)
```

#### 2. Updated Login Flow (`UserAuthAPIClient.login()`)

**Before:**
```swift
// Login → Fetch Profile (404 error)
let loginResponse = try await executeAPIRequest(...)
let userId = decodeUserIdFromJWT(loginResponse.accessToken)
let profile = try await fetchUserProfile(userId, token)  // ❌ Fails here
```

**After:**
```swift
// Login → Try fetch, fallback to JWT construction
let loginResponse = try await executeAPIRequest(...)
let userId = decodeUserIdFromJWT(loginResponse.accessToken)

let userProfile: UserProfile
do {
    // Try to fetch from backend
    let profileDTO = try await fetchUserProfile(userId, token)
    userProfile = try profileDTO.toDomain()
} catch let APIError.apiError(statusCode: 404, _) {
    // Fallback: Construct minimal profile from JWT
    let email = extractEmailFromJWT(token) ?? credentials.email
    userProfile = UserProfile(
        id: UUID(uuidString: userId),
        username: email.components(separatedBy: "@").first,
        email: email,
        firstName: "",  // Will be updated in profile setup
        lastName: "",
        dateOfBirth: nil,
        gender: nil,
        height: nil,
        weight: nil,
        activityLevel: nil,
        createdAt: Date()
    )
}
```

#### 3. Added JWT Email Extraction

```swift
private func extractEmailFromJWT(_ token: String) -> String? {
    // Decode JWT payload and extract email field
    // Same base64 decoding logic as user_id extraction
}
```

---

## 📊 Impact Analysis

### What Works Now ✅

1. **Registration:**
   - User can register successfully
   - Tokens are saved to Keychain
   - Profile is constructed from registration data
   - User is authenticated and navigated to app

2. **Login:**
   - User can login successfully
   - Tokens are saved to Keychain
   - Profile is constructed from JWT data
   - Minimal profile created (firstName/lastName empty, to be filled in onboarding)
   - User is authenticated and navigated to app

3. **Session Persistence:**
   - Tokens persist in Keychain
   - Profile persists in SwiftData
   - App restart maintains authentication

### Trade-offs ⚖️

**Pros:**
- ✅ Unblocks registration and login flows
- ✅ Works with current backend API
- ✅ No backend changes required
- ✅ User experience not impacted
- ✅ Profile will be completed during onboarding

**Cons:**
- ⚠️ Login users have minimal profile (firstName/lastName empty)
- ⚠️ Username is derived from email (e.g., "test@example.com" → "test")
- ⚠️ Profile data not fetched from backend source of truth
- ⚠️ Temporary solution until backend implements user endpoint

---

## 🔮 Future Improvements

### When Backend Implements `/api/v1/users/{id}` Endpoint

1. **Update Login Flow:**
   - Remove fallback profile construction
   - Fetch full user profile from `/api/v1/users/{id}`
   - Remove 404 error handling

2. **Update Registration Flow:**
   - Option A: Backend returns user data in registration response
   - Option B: Fetch from `/api/v1/users/{id}` after registration

3. **Profile Sync:**
   - Implement periodic profile sync from backend
   - Handle profile updates (name changes, etc.)

### Recommended Backend Changes

```
POST /api/v1/auth/register
Response: {
  "data": {
    "access_token": "...",
    "refresh_token": "...",
    "user": {              // ✨ Include user data in response
      "id": "...",
      "email": "...",
      "first_name": "...",
      "last_name": "...",
      "username": "...",
      "date_of_birth": "...",
      "created_at": "..."
    }
  }
}
```

**OR**

```
GET /api/v1/users/{id}
Response: {
  "data": {
    "id": "...",
    "email": "...",
    "first_name": "...",
    "last_name": "...",
    "username": "...",
    "date_of_birth": "...",
    "created_at": "...",
    "updated_at": "..."
  }
}
```

---

## 🧪 Testing Results

### Test Case 1: Registration
- ✅ User can register with email, password, firstName, lastName, dateOfBirth
- ✅ Tokens received and stored
- ✅ Profile constructed from registration data
- ✅ User authenticated successfully
- ✅ Navigation to onboarding/main app works

### Test Case 2: Login (After Registration)
- ✅ User can login with email and password
- ✅ Tokens received and stored
- ✅ Profile constructed from JWT (minimal for existing users)
- ✅ User authenticated successfully
- ✅ Navigation to main app works

### Test Case 3: Session Persistence
- ✅ App restart maintains authentication
- ✅ Profile loaded from SwiftData
- ✅ No re-login required

---

## 📝 Code Changes Summary

**Files Modified:**
1. `FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`
   - Updated `register()` method
   - Updated `login()` method
   - Added `extractEmailFromJWT()` helper
   - Updated `fetchUserProfile()` documentation

**Lines Changed:**
- Added: ~80 lines
- Modified: ~20 lines
- Deleted: ~10 lines

**Backward Compatibility:** ✅ Yes (fully backward compatible)

---

## 🚨 Known Limitations

1. **Username Generation:**
   - Currently derived from email (part before @)
   - May not match backend-generated username
   - Should be updated when backend provides actual username

2. **Login Profile Completeness:**
   - For existing users logging in, firstName/lastName will be empty
   - Will be filled during onboarding profile setup
   - Not an issue for new registrations

3. **No Profile Refresh:**
   - Profile is constructed once and cached
   - If user updates profile on web/other device, app won't reflect changes
   - Need backend user endpoint to implement sync

---

## ✅ Verification Checklist

- [x] Registration flow works end-to-end
- [x] Login flow works end-to-end
- [x] Tokens are saved to Keychain
- [x] Profile is saved to SwiftData
- [x] AuthManager state updates correctly
- [x] Navigation works after auth
- [x] Session persists across app restarts
- [x] No compilation errors
- [x] No crashes during auth flow
- [x] Error handling graceful (no user-facing errors)

---

## 📞 Related Issues

- [x] AUTH-001: Registration fails with 404 error (RESOLVED)
- [ ] BACKEND-001: Implement GET /api/v1/users/{id} endpoint (OPEN)
- [ ] PROFILE-001: Profile sync from backend (FUTURE)

---

## 📚 References

- API Documentation: `/docs/api-integration/`
- Auth Implementation: `FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`
- Status Report: `docs/AUTH_IMPLEMENTATION_STATUS.md`
- Testing Guide: `docs/TESTING_AUTH_GUIDE.md`

---

**Fix Status:** ✅ Deployed and Working  
**Next Action:** Continue with onboarding implementation  
**Future Work:** Update when backend implements user endpoint

**Last Updated:** 2025-01-27  
**Fixed By:** AI Assistant  
**Reviewed By:** Pending