# Backend Response Structure Fix

**Date:** 2025-01-30  
**Issue:** Profile API decoding failure  
**Status:** ✅ Fixed

---

## Problem

The profile API was failing to decode the backend response with the error:

```
❌ [HTTPClient] Decoding failed for type: UserProfileBackendResponse
🔍 Missing key: user_id at path: [CodingKeys(stringValue: "data", intValue: nil)]
```

---

## Root Cause

The backend response structure doesn't match our initial UserProfile domain model expectations.

### Actual Backend Response Structure

```json
{
  "data": {
    "id": "15d3af32-a0f7-424c-952a-18c372476bfe",
    "email": "1411@lume.com",
    "profile": {
      "id": "1fec29c1-5607-4f57-940f-16a48ef037b5",
      "name": "Marcos Barbero",
      "preferred_unit_system": "metric",
      "language_code": "en",
      "date_of_birth": "1983-07-19T00:00:00Z",
      "bio": null,
      "biological_sex": null,
      "height_cm": null,
      "created_at": "2025-01-30T...",
      "updated_at": "2025-01-30T..."
    }
  }
}
```

### Key Observations

1. **Two-level nesting:** `data` contains both user info and nested `profile`
2. **User ID at top level:** `data.id` is the user ID (not inside profile)
3. **Email at top level:** `data.email` is at the user level
4. **Profile nested:** `data.profile` contains the actual profile data
5. **Date as ISO8601:** `date_of_birth` is a full ISO8601 timestamp string

### What We Expected

Our domain model expected a flat structure with `user_id` inside the profile:

```swift
struct UserProfile {
    let id: String           // profile id
    let userId: String       // ❌ Expected this but it doesn't exist in response
    let name: String
    // ...
}
```

---

## Solution

Created a proper Data Transfer Object (DTO) that matches the actual backend structure, then converts it to our domain model.

### Implementation

#### 1. Backend Response DTO

```swift
private struct UserProfileBackendResponse: Decodable {
    let data: UserProfileResponseData

    struct UserProfileResponseData: Decodable {
        let id: String              // user id (top level)
        let email: String           // user email (top level)
        let profile: ProfileData    // nested profile data

        struct ProfileData: Decodable {
            let id: String                      // profile id
            let name: String
            let bio: String?
            let preferredUnitSystem: String
            let languageCode: String
            let dateOfBirth: String?            // ISO8601 string
            let biologicalSex: String?
            let heightCm: Double?
            let createdAt: String?              // ISO8601 string
            let updatedAt: String?              // ISO8601 string

            enum CodingKeys: String, CodingKey {
                case id
                case name
                case bio
                case preferredUnitSystem = "preferred_unit_system"
                case languageCode = "language_code"
                case dateOfBirth = "date_of_birth"
                case biologicalSex = "biological_sex"
                case heightCm = "height_cm"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
    }
}
```

#### 2. DTO to Domain Conversion

```swift
func toDomain() -> UserProfile {
    let isoFormatter = ISO8601DateFormatter()

    // Parse dates from ISO8601 strings
    let dateOfBirth = data.profile.dateOfBirth.flatMap { isoFormatter.date(from: $0) }
    let createdAt = data.profile.createdAt.flatMap { isoFormatter.date(from: $0) } ?? Date()
    let updatedAt = data.profile.updatedAt.flatMap { isoFormatter.date(from: $0) } ?? Date()

    // Parse unit system with fallback
    let unitSystem = UnitSystem(rawValue: data.profile.preferredUnitSystem) ?? .metric

    return UserProfile(
        id: data.profile.id,              // profile id
        userId: data.id,                  // ✅ user id from top level
        name: data.profile.name,
        bio: data.profile.bio,
        preferredUnitSystem: unitSystem,
        languageCode: data.profile.languageCode,
        dateOfBirth: dateOfBirth,
        createdAt: createdAt,
        updatedAt: updatedAt,
        biologicalSex: data.profile.biologicalSex,
        heightCm: data.profile.heightCm
    )
}
```

#### 3. Updated Service Methods

```swift
func fetchUserProfile(accessToken: String) async throws -> UserProfile {
    let response: UserProfileBackendResponse = try await httpClient.get(
        path: "/api/v1/users/me",
        accessToken: accessToken
    )
    return response.toDomain()  // ✅ Convert DTO to domain
}

func updateUserProfile(request: UpdateUserProfileRequest, accessToken: String) 
    async throws -> UserProfile 
{
    let response: UserProfileBackendResponse = try await httpClient.put(
        path: "/api/v1/users/me",
        body: request,
        accessToken: accessToken
    )
    return response.toDomain()  // ✅ Convert DTO to domain
}
```

---

## Benefits of This Approach

### 1. Separation of Concerns
- Backend structure changes don't affect domain model
- DTO handles API specifics (snake_case, nested structure)
- Domain model stays clean and business-focused

### 2. Type Safety
- Compiler ensures all fields are mapped
- No runtime surprises from missing fields
- Clear conversion logic in one place

### 3. Flexibility
- Easy to add new fields from backend
- Can handle API versioning
- Simple to add data transformations

### 4. Maintainability
- Single source of truth for API structure
- Clear mapping between API and domain
- Easy to test conversion logic

---

## Testing

### Before Fix
```
❌ [HTTPClient] Decoding failed for type: UserProfileBackendResponse
🔍 Missing key: user_id
```

### After Fix
```
✅ [UserProfileBackendService] Profile fetched: Marcos Barbero
✅ [ProfileViewModel] Profile loaded: Marcos Barbero
```

---

## Lessons Learned

### 1. Always Check Actual API Responses
- Don't assume API structure from documentation alone
- Log raw JSON responses during development
- Test with real backend early

### 2. Use DTOs for API Boundaries
- Keep domain models pure
- Use DTOs to handle API specifics
- Convert at the boundary (service layer)

### 3. Handle Date Formats Properly
- Backend sends ISO8601 strings
- Use `ISO8601DateFormatter` for parsing
- Provide fallbacks for missing dates

### 4. Defensive Parsing
- Use optional chaining (`flatMap`)
- Provide sensible defaults (e.g., `Date()` for missing timestamps)
- Handle enum parsing with fallbacks

---

## Related Files Modified

### UserProfileBackendService.swift
```
Changes:
- Created nested DTO structure matching API
- Added toDomain() conversion method
- Updated all service methods to use DTO conversion
- Improved error handling with proper date parsing
```

### Files Verified (No Changes Needed)
- UserProfile.swift (domain model unchanged)
- ProfileViewModel.swift
- ProfileDetailView.swift
- UserProfileRepository.swift

---

## API Documentation Reference

### Endpoint: GET /api/v1/users/me

**Response Structure:**
```
{
  "data": {
    "id": UUID,                    // User ID
    "email": String,               // User email
    "profile": {
      "id": UUID,                  // Profile ID
      "name": String,              // User's display name
      "bio": String?,              // Optional biography
      "preferred_unit_system": String,  // "metric" | "imperial"
      "language_code": String,     // ISO language code
      "date_of_birth": String?,    // ISO8601 timestamp
      "biological_sex": String?,   // Optional
      "height_cm": Double?,        // Optional height in cm
      "created_at": String,        // ISO8601 timestamp
      "updated_at": String         // ISO8601 timestamp
    }
  }
}
```

---

## Future Improvements

### 1. Centralized DTO Layer
- Create `DTOs/` directory for all API response models
- Shared date parsing utilities
- Consistent conversion patterns

### 2. Comprehensive Tests
- Unit tests for DTO → Domain conversion
- Test all edge cases (null values, invalid dates)
- Mock responses for different scenarios

### 3. API Versioning Support
- Handle multiple API versions if needed
- Version-specific DTOs
- Backward compatibility layer

### 4. Code Generation
- Consider using code generation for DTOs
- Tools like Sourcery or Swift protocols
- Reduces boilerplate and errors

---

## Summary

**Problem:** Backend response structure didn't match domain model expectations  
**Cause:** Assumed flat structure, actual API has two-level nesting  
**Solution:** Created proper DTO layer with conversion to domain model  
**Result:** Profile loading now works correctly with proper data mapping  

**Status:** ✅ Fixed and Verified  
**Impact:** Profile feature now fully functional with backend integration  

---

**Fixed By:** AI Assistant  
**Verified:** 2025-01-30  
**Documentation:** Complete  
**Production Ready:** Yes