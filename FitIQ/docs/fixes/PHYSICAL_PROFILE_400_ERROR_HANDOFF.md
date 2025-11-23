# Physical Profile 400 Error - Investigation Handoff

## Current Status: IN PROGRESS

**Date:** 2025-01-27  
**Issue:** Backend returning 400 "Invalid request payload" when syncing physical profile  
**Severity:** Medium - Blocks physical profile sync to backend

---

## Problem Summary

The app successfully saves physical profile data to **local storage** (SwiftData), but when attempting to sync to the backend via `PATCH /api/v1/users/me/physical`, the backend returns:

```
PhysicalProfileAPIClient: Update response status code: 400
PhysicalProfileAPIClient: Response body (400): {"error":{"message":"Invalid request payload"}}
```

---

## What We Know

### 1. API Specification (swagger.yaml)

**Endpoint:** `PATCH /api/v1/users/me/physical`

**Request Body Schema:**
```yaml
UpdatePhysicalProfileRequest:
  type: object
  properties:
    biological_sex: { type: string, enum: [male, female, other] }
    height_cm: { type: number, format: float }
    date_of_birth:
      type: string
      format: date
      example: "1990-05-15"
```

**All three fields are OPTIONAL** according to the spec.

### 2. What's Being Sent

From the logs:
```
PhysicalProfileAPIClient: Date of birth input: Optional(1983-07-19 22:00:00 +0000)
PhysicalProfileAPIClient: Date of birth formatted: Optional("1983-07-19")
PhysicalProfileAPIClient: Request body: {
  "date_of_birth" : "1983-07-19"
}
```

**ONLY `date_of_birth` is being sent** - `biological_sex` and `height_cm` are missing/null.

### 3. Local Storage Data

From SwiftData logs:
```
SwiftDataAdapter:   SDUserProfile DOB: 1983-07-19 22:00:00 +0000
SwiftDataAdapter:   Creating PhysicalProfile with DOB: 1983-07-19 22:00:00 +0000
```

The local profile appears to have **only date of birth** set, with biological sex and height as `nil`.

### 4. Sync Code

File: `ProfileSyncService.swift` (lines 337-345)

```swift
// Call backend API to update physical profile
let updatedPhysical = try await physicalProfileRepository.updatePhysicalProfile(
    userId: userId,
    biologicalSex: physical.biologicalSex,  // Likely nil
    heightCm: physical.heightCm,            // Likely nil
    dateOfBirth: physical.dateOfBirth       // "1983-07-19"
)
```

---

## Hypothesis

**The backend is rejecting the request for one of these reasons:**

1. **Missing Required Field:** Despite the spec saying all fields are optional, the backend implementation might require at least one of `biological_sex` or `height_cm` to be present when updating.

2. **Validation Logic:** The backend might have business logic that requires certain field combinations (e.g., if you send `date_of_birth`, you must also send `biological_sex`).

3. **Profile Doesn't Exist:** The physical profile record doesn't exist on the backend yet, and the PATCH endpoint requires it to exist first (should be POST/PUT instead).

4. **Date Format Issue:** The date format `"1983-07-19"` might not be accepted (though it matches the spec example).

---

## What Was Fixed

### 1. Local-First Architecture ✅

**File:** `Domain/UseCases/UpdatePhysicalProfileUseCase.swift`

Changed from backend-first (blocking on API) to local-first:
- Saves to SwiftData immediately
- Publishes event for async sync
- Returns instantly (no network wait)

### 2. Date Timezone Handling ✅

**Files:**
- `Infrastructure/Network/DTOs/AuthDTOs.swift`
- `Infrastructure/Network/UserAuthAPIClient.swift`
- `Infrastructure/Network/UserProfileAPIClient.swift`
- `Infrastructure/Network/UserProfileMetadataClient.swift`

Fixed date parsing/formatting to use **UTC timezone consistently**:
- Parsing: Set `dateFormatter.timeZone = UTC`
- Formatting: Set `calendar.timeZone = UTC`

This prevents timezone shifts (e.g., July 20 → July 19).

### 3. Get Physical Profile ✅

**File:** `Domain/UseCases/GetPhysicalProfileUseCase.swift`

Fixed 405 error by reading from **local storage** instead of trying to GET from `/api/v1/users/me/physical` (which only supports PATCH).

### 4. Debug Logging Added ✅

**Files:**
- `Infrastructure/Network/PhysicalProfileAPIClient.swift` (lines 102-117)
- `Infrastructure/Integration/ProfileSyncService.swift` (lines 338-343)

Added logging to show:
- Date of birth before/after formatting
- Full request body (JSON)
- All physical profile fields being synced

---

## Next Steps

### 1. **Check User Profile Data**

The user needs to verify their profile has:
- ✅ Date of Birth: Set
- ❓ Biological Sex: Missing?
- ❓ Height: Missing?

**Action:** Have the user check the Profile screen and ensure biological sex and height are set, not just date of birth.

### 2. **Run with New Logging**

The new logging will show exactly what's being sent:

```
ProfileSyncService: Syncing physical profile with:
  - biologicalSex: nil    ← THIS IS THE PROBLEM
  - heightCm: nil         ← THIS IS THE PROBLEM
  - dateOfBirth: 1983-07-19 22:00:00 +0000
```

**Action:** Run the app and trigger a profile save. Check the logs for these debug statements.

### 3. **Backend Investigation**

If biological sex and height are indeed `nil`, we need to:

**Option A:** Contact backend team to clarify:
- Does PATCH `/api/v1/users/me/physical` require all fields?
- Can we send only `date_of_birth` alone?
- Should we use PUT instead of PATCH?

**Option B:** Require users to fill all three fields:
- Update registration flow
- Update profile edit flow
- Add validation

### 4. **Test Different Scenarios**

Test these request bodies:

```json
// Scenario 1: All fields
{
  "biological_sex": "male",
  "height_cm": 180.5,
  "date_of_birth": "1983-07-20"
}

// Scenario 2: Two fields
{
  "biological_sex": "male",
  "date_of_birth": "1983-07-20"
}

// Scenario 3: Only date (current - FAILS)
{
  "date_of_birth": "1983-07-20"
}
```

**Action:** Manually test which combinations the backend accepts.

### 5. **Possible Code Fixes**

#### Option A: Require All Fields

Update `UpdatePhysicalProfileUseCase` to require all three fields:

```swift
// Add validation
guard biologicalSex != nil && heightCm != nil && dateOfBirth != nil else {
    throw PhysicalProfileUpdateValidationError.allFieldsRequired
}
```

#### Option B: Send Empty Object If All Nil

```swift
// Don't send request if all fields are nil
guard physical.biologicalSex != nil || 
      physical.heightCm != nil || 
      physical.dateOfBirth != nil else {
    print("No physical profile data to sync")
    return
}
```

#### Option C: Default Values

```swift
// Provide defaults for missing fields
let requestDTO = PhysicalProfileUpdateRequest(
    biologicalSex: physical.biologicalSex ?? "other",
    heightCm: physical.heightCm ?? 170.0,  // Default height
    dateOfBirth: physical.dateOfBirth?.toISO8601DateString()
)
```

---

## Files Modified (This Session)

1. ✅ `Domain/UseCases/UpdatePhysicalProfileUseCase.swift` - Local-first architecture
2. ✅ `Domain/UseCases/GetPhysicalProfileUseCase.swift` - Read from local storage
3. ✅ `Infrastructure/Configuration/AppDependencies.swift` - Updated DI
4. ✅ `Infrastructure/Network/DTOs/AuthDTOs.swift` - UTC timezone for dates
5. ✅ `Infrastructure/Network/UserAuthAPIClient.swift` - UTC timezone
6. ✅ `Infrastructure/Network/UserProfileAPIClient.swift` - UTC timezone
7. ✅ `Infrastructure/Network/UserProfileMetadataClient.swift` - UTC timezone
8. ✅ `Infrastructure/Network/PhysicalProfileAPIClient.swift` - Debug logging
9. ✅ `Infrastructure/Integration/ProfileSyncService.swift` - Debug logging

---

## Documentation Created

1. ✅ `docs/fixes/DATE_OF_BIRTH_TIMEZONE_FIX.md`
2. ✅ `docs/fixes/PROFILE_SAVE_LOCAL_FIRST_ARCHITECTURE.md`
3. ✅ `docs/fixes/405_ERROR_PHYSICAL_PROFILE_FIX.md`
4. ✅ `docs/fixes/PHYSICAL_PROFILE_400_ERROR_HANDOFF.md` (this document)

---

## Questions for Backend Team

1. **Does PATCH `/api/v1/users/me/physical` require all three fields?**
   - Current behavior: Returns 400 when only `date_of_birth` is sent
   - Expected behavior: Should accept optional fields per OpenAPI spec

2. **Should we use PUT instead of PATCH?**
   - PATCH typically allows partial updates
   - PUT requires full resource replacement

3. **Does the physical profile record need to exist first?**
   - Is this updating an existing record or creating a new one?
   - Should we POST first, then PATCH?

4. **What's the minimum required field set?**
   - Just `date_of_birth`?
   - `date_of_birth` + `biological_sex`?
   - All three fields?

---

## Related Issues

- **405 Error:** Fixed ✅ (was trying to GET from PATCH-only endpoint)
- **Timezone Mismatch:** Fixed ✅ (July 20 → July 19 issue)
- **Local-First Architecture:** Implemented ✅
- **400 Error:** IN PROGRESS ⏳ (this document)

---

## Timeline

- **2025-01-27 15:00** - Identified 400 error
- **2025-01-27 15:30** - Fixed timezone issues
- **2025-01-27 16:00** - Fixed local-first architecture
- **2025-01-27 16:30** - Fixed 405 GET error
- **2025-01-27 17:00** - Added debug logging for 400 error
- **2025-01-27 17:15** - Created handoff document (OUT OF TOKENS)

---

## Next Session Action Items

1. ☐ Run app with new logging
2. ☐ Verify what fields are `nil` in physical profile
3. ☐ Test backend with different field combinations
4. ☐ Contact backend team with questions
5. ☐ Implement fix based on findings
6. ☐ Update documentation

---

**Status:** Ready for Next Developer  
**Priority:** Medium (blocks backend sync but local storage works)  
**Estimated Time to Resolution:** 1-2 hours (pending backend clarification)
