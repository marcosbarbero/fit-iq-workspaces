# Registration & Profile Flow Update

**Date:** 2025-01-27  
**Version:** 2.0  
**Status:** ✅ Implemented

---

## 🎯 Overview

The backend API has been updated so that **user registration now creates the profile automatically**. This eliminates the need for a separate `POST /api/v1/users/me` call after registration.

---

## 📋 What Changed

### Backend API Changes

#### Before (Old Flow)
```
POST /api/v1/auth/register
→ Returns: { access_token, refresh_token }
→ Profile NOT created

POST /api/v1/users/me (required)
→ Creates profile
→ Returns: UserProfile
```

#### After (New Flow)
```
POST /api/v1/auth/register
→ Returns: { 
    user_id,
    email,
    name,
    created_at,
    access_token,
    refresh_token
  }
→ Profile AUTOMATICALLY created on backend

GET /api/v1/users/me (optional)
→ Fetches complete profile with profile_id
```

---

## 🔧 iOS Implementation Changes

### 1. Updated DTOs

**File:** `Infrastructure/Network/DTOs/UserRegistrationDTOs.swift`

```swift
// ✅ UPDATED
struct RegisterResponse: Decodable {
    let userId: String          // ✨ NEW
    let email: String           // ✨ NEW
    let name: String            // ✨ NEW
    let createdAt: String       // ✨ NEW
    let accessToken: String
    let refreshToken: String
}
```

### 2. Updated UserAuthAPIClient

**File:** `Infrastructure/Network/UserAuthAPIClient.swift`

#### Changes:
- `register()` method now uses `RegisterResponse` fields directly
- No longer decodes `user_id` from JWT (uses response field)
- Constructs `UserProfile` from registration response data
- Includes `createdAt` timestamp from backend

```swift
// ✅ UPDATED
func register(userData: RegisterUserData) async throws -> (
    profile: UserProfile, accessToken: String, refreshToken: String
) {
    let registerResponse = try await executeAPIRequest(...)
    
    // Use data directly from response
    let userId = UUID(uuidString: registerResponse.userId)
    let createdAt = parseISO8601(registerResponse.createdAt)
    
    // Construct profile from response
    let metadata = UserProfileMetadata(
        id: UUID(),  // Will be fetched from backend
        userId: userId,
        name: registerResponse.name,  // ✨ From response
        bio: nil,
        preferredUnitSystem: "metric",
        languageCode: nil,
        dateOfBirth: userData.dateOfBirth,
        createdAt: createdAt,  // ✨ From response
        updatedAt: createdAt
    )
    
    return (userProfile, accessToken, refreshToken)
}
```

### 3. Updated RegisterUserUseCase

**File:** `Domain/UseCases/RegisterUserUseCase.swift`

#### Changes:
- **Step 3 changed from POST to GET**
- Now uses `getProfile()` instead of `createProfile()`
- Backend profile is fetched (not created)
- Falls back to registration response if fetch fails

```swift
// ✅ UPDATED Flow
func execute(data: RegisterUserData) async throws -> UserProfile {
    // Step 1: Register user (creates auth + profile on backend)
    let (userProfile, accessToken, refreshToken) = 
        try await authRepository.register(userData: data)
    
    // Step 2: Save tokens
    try authTokenPersistence.save(
        accessToken: accessToken, 
        refreshToken: refreshToken
    )
    
    // Step 3: ✨ CHANGED - GET instead of POST
    var backendProfile: UserProfile?
    do {
        backendProfile = try await profileMetadataClient.getProfile()
        // ✅ Profile already exists from registration
    } catch {
        // Continue with registration response if fetch fails
        print("Will sync profile later")
    }
    
    // Step 4: Use backend profile (preferred) or registration profile
    let profileToSave = backendProfile ?? userProfile
    
    // Step 5: Save locally and update auth state
    try await userProfileStorage.save(userProfile: profileToSave)
    authManager.handleSuccessfulAuth(userProfileID: profileToSave.id)
    
    return profileToSave
}
```

---

## 🔄 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ USER REGISTRATION FLOW (Updated)                            │
└─────────────────────────────────────────────────────────────┘

┌──────────────────┐
│ User Enters Info │
│ • Email          │
│ • Password       │
│ • Name           │
│ • Date of Birth  │
└────────┬─────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ POST /api/v1/auth/register                                 │
│ {                                                          │
│   email, password, name, date_of_birth                     │
│ }                                                          │
└────────┬───────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ Backend Response                                           │
│ ✅ Creates auth user                                       │
│ ✅ Creates profile automatically                           │
│                                                            │
│ Returns:                                                   │
│ {                                                          │
│   user_id: "abc-123",                                      │
│   email: "user@example.com",                               │
│   name: "John Doe",                                        │
│   created_at: "2025-01-27T10:00:00Z",                      │
│   access_token: "jwt...",                                  │
│   refresh_token: "jwt..."                                  │
│ }                                                          │
└────────┬───────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────────┐
│ iOS App                                                    │
│ 1. ✅ Save tokens to Keychain                             │
│ 2. ✅ Construct UserProfile from response                 │
│ 3. 🔄 Optionally fetch complete profile (GET /users/me)   │
│ 4. ✅ Save profile to SwiftData                           │
│ 5. ✅ Update auth state                                   │
└────────┬───────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ User Logged In  │
│ Profile Ready   │
└─────────────────┘
```

---

## 📝 API Endpoint Reference

### Registration Endpoint

**Endpoint:** `POST /api/v1/auth/register`

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe",
  "date_of_birth": "1990-05-15"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2025-01-27T10:00:00.000Z",
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
  },
  "error": null
}
```

### Profile Endpoints

#### Get Profile (No Change)

**Endpoint:** `GET /api/v1/users/me`

**Headers:**
```
Authorization: Bearer {access_token}
X-API-Key: {api_key}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "650e8400-e29b-41d4-a716-446655440000",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "John Doe",
    "bio": null,
    "preferred_unit_system": "metric",
    "language_code": "en",
    "date_of_birth": "1990-05-15",
    "created_at": "2025-01-27T10:00:00.000Z",
    "updated_at": "2025-01-27T10:00:00.000Z"
  },
  "error": null
}
```

#### Create Profile (Still Available)

**Endpoint:** `POST /api/v1/users/me`

**Note:** This endpoint still exists for edge cases, but should NOT be used after registration since the profile is auto-created.

**Returns:** `409 Conflict` if profile already exists

---

## ⚠️ Important Notes

### 1. Profile Already Exists After Registration
- **Do NOT** call `POST /api/v1/users/me` after registration
- Profile is automatically created by the backend
- Use `GET /api/v1/users/me` to fetch the complete profile if needed

### 2. Registration Response Contains Profile Data
- `user_id` - Use this directly (no need to decode JWT)
- `email` - Confirmed email from backend
- `name` - User's name
- `created_at` - Profile creation timestamp

### 3. Fallback Strategy
- If `GET /users/me` fails after registration, the app continues
- Uses profile constructed from registration response
- Will sync with backend on next app launch

### 4. Date of Birth Handling
- Sent during registration as `date_of_birth` (YYYY-MM-DD)
- Stored in both `UserProfileMetadata` and `PhysicalProfile`
- Required for COPPA compliance (13+ years old)

---

## ✅ Benefits of New Flow

### 1. Simpler Registration
- **Before:** Register → Save tokens → Create profile → Save profile
- **After:** Register → Save tokens → (Optional: Fetch profile) → Save profile

### 2. Fewer API Calls
- Eliminated mandatory `POST /users/me` after registration
- Optional `GET /users/me` for complete profile data

### 3. Better UX
- Faster registration process
- Fewer potential points of failure
- Automatic profile creation ensures consistency

### 4. Consistent Data
- Backend is source of truth for `user_id`
- No discrepancies between auth and profile data
- `created_at` timestamp from server

---

## 🧪 Testing Checklist

### Registration Flow
- [ ] User can register with email, password, name, date_of_birth
- [ ] Registration response includes all expected fields
- [ ] Tokens are saved to Keychain
- [ ] Profile is constructed from registration response
- [ ] Optional profile fetch succeeds (GET /users/me)
- [ ] Profile is saved to SwiftData
- [ ] User is logged in after registration

### Error Handling
- [ ] Registration with existing email returns 409
- [ ] Invalid date_of_birth (under 13) is rejected
- [ ] Registration continues if profile fetch fails
- [ ] User can still log in if profile fetch failed

### Login Flow (No Change Expected)
- [ ] Login returns only tokens (not profile data)
- [ ] Profile is fetched after login via GET /users/me
- [ ] Existing login flow works as before

---

## 📚 Related Files

### Updated Files
- `Infrastructure/Network/DTOs/UserRegistrationDTOs.swift` - Added fields to `RegisterResponse`
- `Infrastructure/Network/UserAuthAPIClient.swift` - Updated `register()` method
- `Domain/UseCases/RegisterUserUseCase.swift` - Changed POST to GET for profile

### No Changes Required
- `Infrastructure/Network/DTOs/AuthDTOs.swift` - LoginResponse unchanged
- `Infrastructure/Network/UserProfileMetadataClient.swift` - Methods remain same
- `Domain/UseCases/LoginUserUseCase.swift` - Login flow unchanged

---

## 🔗 References

- **Backend API Spec:** `docs/be-api-spec/swagger.yaml`
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **Architecture Docs:** `.github/copilot-instructions.md`

---

**Last Updated:** 2025-01-27  
**Updated By:** AI Assistant  
**Review Status:** ✅ Ready for Testing