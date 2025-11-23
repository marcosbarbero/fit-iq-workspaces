# Profile Update API Fix - Complete API Mismatch Discovery

**Date:** 2025-01-27  
**Issue:** Profile update failing with 400 error + Major API mismatch discovered  
**Status:** 🚧 In Progress - Requires Major Refactoring  
**Related:** HANDOFF_PROFILE_UPDATE_2025-01-27.md

---

## 🚨 CRITICAL DISCOVERY

While investigating the "Preferred unit system is required" error, we discovered a **massive mismatch** between the iOS app's data model and the actual backend API specification.

**The iOS app is NOT aligned with the backend API at all.**

---

## 📊 API Specification Analysis (Source of Truth)

### Backend API Structure

The backend has **THREE SEPARATE ENDPOINTS** for user data:

#### 1. **GET/PUT `/api/v1/users/me`** - User Profile Metadata

**Returns:**
```json
{
  "id": "uuid",                          // Profile ID
  "user_id": "uuid",                     // User ID
  "name": "Full Name",                   // ✅ ONLY name field
  "bio": "Biography text",               // ✅ Biography
  "preferred_unit_system": "metric",     // ✅ REQUIRED: "metric" or "imperial"
  "language_code": "en",                 // ✅ Language preference
  "date_of_birth": "1990-05-15",        // ✅ Date of birth (YYYY-MM-DD)
  "created_at": "2025-01-27T...",       // Timestamp
  "updated_at": "2025-01-27T..."        // Timestamp
}
```

**Request (PUT):**
```json
{
  "name": "string",                      // REQUIRED
  "preferred_unit_system": "metric",     // REQUIRED: "metric" or "imperial"
  "bio": "string",                       // OPTIONAL
  "language_code": "en"                  // OPTIONAL
}
```

#### 2. **PATCH `/api/v1/users/me/physical`** - Physical Attributes

**Request:**
```json
{
  "biological_sex": "male",              // OPTIONAL: "male", "female", "other"
  "height_cm": 175.5,                    // OPTIONAL: Height in centimeters
  "date_of_birth": "1990-05-15"         // OPTIONAL: Can be updated here too
}
```

**Note:** There is NO `weight` field in this endpoint either!

#### 3. **Auth Endpoints** - Registration/Login

These return JWT tokens and user_id, but NOT full profile data.

---

## ❌ What the iOS App Currently Has (WRONG)

### iOS `UserProfileResponseDTO` Structure:

```swift
struct UserProfileResponseDTO: Decodable {
    let id: String                    // ✅ Correct
    let username: String              // ❌ NOT IN API
    let email: String                 // ❌ NOT IN PROFILE API (from auth)
    let name: String                  // ✅ Correct (but was firstName/lastName)
    let dateOfBirth: Date?            // ✅ In API (but wrong format handling)
    let gender: String?               // ❌ Wrong field name (should be biological_sex)
                                      // ❌ Wrong endpoint (/physical, not /me)
    let height: Double?               // ❌ Wrong field name (should be height_cm)
                                      // ❌ Wrong endpoint (/physical, not /me)
    let weight: Double?               // ❌ NOT IN API AT ALL
    let activityLevel: String?        // ❌ NOT IN API AT ALL
    let preferredUnitSystem: String?  // ⚠️  In API but was MISSING
    let createdAt: Date               // ✅ Correct
    let updatedAt: Date               // ✅ Correct
}
```

### Fields That Don't Exist in Backend:
- ❌ `username` - Not in profile API
- ❌ `email` - Comes from auth, not profile
- ❌ `weight` - Not in profile OR physical API
- ❌ `activityLevel` - Not in any API endpoint

### Fields in Wrong Endpoint:
- ⚠️  `gender` → Should be `biological_sex` from `/api/v1/users/me/physical`
- ⚠️  `height` → Should be `height_cm` from `/api/v1/users/me/physical`
- ⚠️  `dateOfBirth` → Can be in BOTH `/me` and `/physical` endpoints

### Missing Fields:
- ❌ `bio` - Biography field exists in API but not in iOS
- ❌ `language_code` - Language preference exists in API but not in iOS
- ❌ `preferred_unit_system` - Was missing (now added)

---

## 🔧 Refactoring Strategy

### Phase 1: Separate DTOs (✅ In Progress)

Create distinct DTOs for each API endpoint:

```swift
// Profile metadata (/api/v1/users/me)
struct UserProfileResponseDTO {
    let id: String
    let userId: String
    let name: String
    let bio: String?
    let preferredUnitSystem: String
    let languageCode: String?
    let dateOfBirth: String?
    let createdAt: String
    let updatedAt: String
}

// Physical attributes (/api/v1/users/me/physical)
struct PhysicalProfileResponseDTO {
    let biologicalSex: String?
    let heightCm: Double?
    let dateOfBirth: String?
}

// Combined in-memory model
struct UserProfile {
    // From auth
    let id: UUID
    let email: String
    
    // From /api/v1/users/me
    let name: String
    let bio: String?
    let preferredUnitSystem: String
    let languageCode: String?
    
    // From /api/v1/users/me/physical
    let biologicalSex: String?
    let heightCm: Double?
    let dateOfBirth: Date?
    
    // App-specific
    let createdAt: Date
    
    // ❌ Remove these (not in API):
    // - username (use name instead)
    // - weight (not in API)
    // - activityLevel (not in API)
    // - gender (wrong name, use biologicalSex)
    // - height (wrong name, use heightCm)
}
```

### Phase 2: Separate API Clients

```swift
// Profile metadata client
class UserProfileAPIClient {
    func getProfile() async throws -> UserProfileResponseDTO
    func updateProfile(request: UserProfileUpdateRequest) async throws
}

// Physical attributes client
class PhysicalProfileAPIClient {
    func getPhysicalProfile() async throws -> PhysicalProfileResponseDTO
    func updatePhysicalProfile(request: PhysicalProfileUpdateRequest) async throws
}
```

### Phase 3: Update Use Cases

```swift
// Separate use cases for different concerns
protocol UpdateProfileMetadataUseCase {
    func execute(name: String, bio: String?, unitSystem: String, language: String?) async throws
}

protocol UpdatePhysicalAttributesUseCase {
    func execute(biologicalSex: String?, heightCm: Double?, dateOfBirth: Date?) async throws
}
```

### Phase 4: Update ViewModels

```swift
class ProfileViewModel {
    // Profile metadata
    @Published var name: String = ""
    @Published var bio: String = ""
    @Published var preferredUnitSystem: String = "metric"
    @Published var languageCode: String = "en"
    
    // Physical attributes
    @Published var biologicalSex: String = ""
    @Published var heightCm: String = ""
    @Published var dateOfBirth: Date? = nil
    
    // Remove these (not in API):
    // @Published var username: String
    // @Published var weight: String
    // @Published var activityLevel: String
}
```

---

## 🚧 Current Status

### What We've Done So Far:

1. ✅ Identified the missing `preferred_unit_system` field
2. ✅ Added `preferredUnitSystem` to domain model with default value
3. ✅ Updated API client to send `preferred_unit_system: "metric"`
4. ✅ Completely refactored `AuthDTOs.swift` to match actual API spec
5. ✅ Created separate DTOs for profile and physical endpoints
6. ✅ Added proper error types for DTO conversion

### What's Still Broken:

1. ❌ `UserProfile` domain entity still has wrong fields
2. ❌ API client still mixes profile and physical endpoints
3. ❌ ViewModel still uses old field names
4. ❌ UI still references non-existent fields
5. ❌ No way to update bio or language
6. ❌ Gender field uses wrong name and endpoint

---

## 🎯 Immediate Fix (Minimal)

To get profile updates working **right now** without major refactoring:

### Option A: Just Fix the Request Body

Keep the current `UserProfile` domain model but fix the API request:

```swift
// In UserProfileAPIClient.updateProfile()
var requestBody: [String: Any?] = [:]

// Only send fields that /api/v1/users/me accepts
if let name = name {
    requestBody["name"] = name
}
requestBody["preferred_unit_system"] = "metric"  // REQUIRED

// ❌ DON'T send these to /api/v1/users/me:
// - gender (wrong endpoint)
// - height (wrong endpoint)
// - weight (not in API)
// - activity_level (not in API)

// Send physical attributes to separate endpoint if needed
if let gender = gender, let height = height {
    try await updatePhysicalAttributes(
        biologicalSex: gender,
        heightCm: height
    )
}
```

### Option B: Proper Fix (Recommended)

1. **Update `UserProfile` domain model** to match API
2. **Create separate API clients** for profile vs physical
3. **Update ViewModels** to use correct field names
4. **Update UI** to match new model
5. **Add migration logic** for existing data

---

## 📝 Decision Required

**We need to decide:**

1. **Quick Fix:** Just make profile updates work with minimal changes?
2. **Proper Fix:** Fully refactor to match backend API structure?

**Recommendation:** Start with Quick Fix to unblock users, then plan Proper Fix for next sprint.

---

## 🔍 Missing Features in iOS App

Based on the API spec, the iOS app is missing:

1. ✅ `preferred_unit_system` - Now added
2. ❌ `bio` field - User biography/description
3. ❌ `language_code` - User language preference
4. ❌ Proper `biological_sex` handling (currently called `gender`)
5. ❌ Progress tracking (entire `/api/v1/progress` endpoint)
6. ❌ Dietary preferences (entire `/api/v1/users/me/preferences` endpoint)
7. ❌ Many other endpoints...

---

## 🧪 Testing the Current Fix

### Expected Behavior (After Current Changes):

```
UserProfileAPIClient: Updating user profile via /api/v1/users/me
UserProfileAPIClient: Update Request Body: {
  "name": "Marcos Barbero",
  "preferred_unit_system": "metric"
}
UserProfileAPIClient: Update Response (200): {"success":true,...}
```

**Note:** Height, weight, gender will NOT be updated because they're being sent to the wrong endpoint!

### To Actually Update Physical Attributes:

Need to call:
```
PATCH /api/v1/users/me/physical
Body: {
  "biological_sex": "male",
  "height_cm": 170
}
```

---

## 📞 Questions for Backend Team

1. **Weight Tracking:** Where is weight stored? Progress endpoint? Physical endpoint?
2. **Activity Level:** Is this tracked anywhere in the backend?
3. **Username:** Should this exist? Or just use `name`?
4. **Email:** Available in profile endpoint or only from auth?
5. **Date of Birth:** Should it be in both `/me` and `/physical` or just one?

---

## 📊 Files Modified (So Far)

| File | Status | Notes |
|------|--------|-------|
| `Domain/Entities/UserProfile.swift` | ⚠️ Partially Updated | Added `preferredUnitSystem` but still has wrong fields |
| `Infrastructure/Network/DTOs/AuthDTOs.swift` | ✅ Refactored | Now matches actual API spec |
| `Infrastructure/Network/UserProfileAPIClient.swift` | ⚠️ Partially Fixed | Sends `preferred_unit_system` but still mixes endpoints |
| `Infrastructure/Network/UserAuthAPIClient.swift` | ⚠️ Partially Updated | Uses new DTO but model mismatch remains |
| `Domain/UseCases/SwiftDataUserProfileAdapter.swift` | ⚠️ Partially Updated | Added default but model mismatch remains |

---

## 🎯 Next Steps

### Immediate (To Fix 400 Error):

1. ✅ Send `preferred_unit_system` in request - **DONE**
2. ⏳ Test in Xcode to verify 400 is fixed
3. ⏳ Verify backend accepts the request

### Short-term (Proper API Alignment):

1. ❌ Remove fields not in API from `UserProfile`
2. ❌ Create `PhysicalProfileAPIClient` for `/physical` endpoint
3. ❌ Update `ProfileViewModel` to use correct fields
4. ❌ Update UI to separate profile metadata from physical attributes
5. ❌ Add bio and language_code to UI

### Long-term (Complete Feature Parity):

1. ❌ Implement Progress tracking (`/api/v1/progress`)
2. ❌ Implement Dietary preferences (`/api/v1/users/me/preferences`)
3. ❌ Implement all other missing endpoints
4. ❌ Create comprehensive integration tests
5. ❌ Add API spec validation in CI/CD

---

## 🚨 Breaking Changes Alert

**When we properly fix this, it will break:**

- Existing local SwiftData storage (schema change)
- Any views that reference removed fields
- ViewModels that use old field names
- Any deep links or navigation that depends on current structure

**Migration Plan Needed:**
1. Migrate local data to new schema
2. Update all UI references
3. Add backward compatibility layer if needed
4. Communicate changes to team

---

## 📋 Summary

**Original Issue:** Missing `preferred_unit_system` field causing 400 error

**Actual Issue:** **Entire iOS data model doesn't match backend API**

**Current Status:** 
- ✅ Added missing `preferred_unit_system` field
- ✅ Refactored DTOs to match API spec
- ⚠️ Domain model still has wrong structure
- ⚠️ API client still mixes endpoints
- 🚧 Major refactoring needed for full alignment

**Recommendation:** Deploy current fix to unblock users, then plan proper refactoring.

---

**Last Updated:** 2025-01-27  
**Author:** AI Assistant  
**Severity:** HIGH - Affects entire profile system  
**Impact:** Major refactoring required  

---

**End of Document**