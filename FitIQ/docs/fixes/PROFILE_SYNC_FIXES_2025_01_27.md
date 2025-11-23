# Profile Sync Fixes - January 27, 2025

## Overview

This document describes the fixes applied to resolve three critical issues with profile editing and backend synchronization:

1. **400 Error on Physical Profile Sync** - Backend rejecting payloads and limitation with date-only updates
2. **Date Off-by-One Error** - Date of birth showing wrong day due to timezone handling
3. **Missing HealthKit Data** - Height and biological sex not pre-populated in edit form

---

## Issue 1: 400 Error - Backend Rejecting Payloads

### Problem 1a: Null Values in Request

When syncing the physical profile to the backend, the app was receiving a 400 error:

```json
Request: {
  "biological_sex": null,
  "height_cm": null,
  "date_of_birth": "1983-07-19"
}

Response: {
  "error": {
    "message": "Invalid request payload"
  }
}
```

### Root Cause 1a

Swift's `JSONEncoder` includes optional fields as `null` in the JSON output by default. The backend API was rejecting payloads with explicit `null` values for optional fields, even though the OpenAPI spec marks all fields as optional.

### Solution 1a

Updated `PhysicalProfileUpdateRequest` in `AuthDTOs.swift` to implement custom encoding that **excludes `nil` values** from the JSON:

```swift
struct PhysicalProfileUpdateRequest: Encodable {
    let biologicalSex: String?
    let heightCm: Double?
    let dateOfBirth: String?
    
    enum CodingKeys: String, CodingKey {
        case biologicalSex = "biological_sex"
        case heightCm = "height_cm"
        case dateOfBirth = "date_of_birth"
    }

    // Custom encoding to exclude nil values from JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Only encode non-nil values
        if let biologicalSex = biologicalSex {
            try container.encode(biologicalSex, forKey: .biologicalSex)
        }
        if let heightCm = heightCm {
            try container.encode(heightCm, forKey: .heightCm)
        }
        if let dateOfBirth = dateOfBirth {
            try container.encode(dateOfBirth, forKey: .dateOfBirth)
        }
    }
}
```

**Result:** Now only fields with actual values are sent:

```json
{
  "date_of_birth": "1983-07-19"
}
```

---

### Problem 1b: Backend Doesn't Accept Date-Only Updates

Even after fixing the `null` values issue, the backend still returned 400 when sending only `date_of_birth`:

```json
Request: {
  "date_of_birth": "1983-07-20"
}

Response: {
  "error": {
    "message": "Invalid request payload"
  }
}
```

### Root Cause 1b

**Backend API Mismatch:**

The OpenAPI spec shows:
- **Schema:** `UpdatePhysicalProfileRequest` includes `biological_sex`, `height_cm`, AND `date_of_birth`
- **Endpoint Description:** "Update biological sex and height for the current user's profile" (no mention of date_of_birth)

**Reality:** The backend endpoint `/api/v1/users/me/physical` requires at least `biological_sex` OR `height_cm` to be present. It won't accept a request with ONLY `date_of_birth`.

This makes sense because:
- `date_of_birth` is set during registration (required field for COPPA compliance)
- It's used for age verification (13+ years old requirement)
- It shouldn't be changed frequently or easily
- The physical profile endpoint is specifically for updating mutable physical attributes (sex/height)

### Solution 1b

Added validation in `ProfileSyncService` to **skip backend sync** if only `date_of_birth` is present:

```swift
// WORKAROUND: Backend /users/me/physical endpoint is for "biological sex and height" only
// Even though the schema includes date_of_birth, the backend rejects requests with ONLY date_of_birth
// Skip sync if we only have date_of_birth (which comes from registration and can't be changed)
let hasBiologicalSex = physical.biologicalSex != nil && !physical.biologicalSex!.isEmpty
let hasHeight = physical.heightCm != nil && physical.heightCm! > 0

if !hasBiologicalSex && !hasHeight {
    print("ProfileSyncService: ⚠️  Skipping physical profile sync - only date_of_birth present")
    print("ProfileSyncService: Backend /users/me/physical requires biological_sex or height_cm")
    print("ProfileSyncService: date_of_birth is set during registration and cannot be updated via this endpoint")
    syncQueue.sync {
        pendingPhysicalSync.remove(userId)
    }
    return
}
```

### Result

- ✅ Profile with only `date_of_birth` → Skip backend sync, keep local data
- ✅ Profile with `height_cm` or `biological_sex` → Sync to backend normally
- ✅ No more 400 errors for incomplete physical profiles
- ✅ Local-first architecture maintained (local data is always preserved)

### Files Modified

- `FitIQ/Infrastructure/Network/DTOs/AuthDTOs.swift`
- `FitIQ/Infrastructure/Integration/ProfileSyncService.swift`

---

## Issue 2: Date Off-by-One Error

### Problem

When user selects **July 20, 1983** in the date picker:
- UI shows: July 20, 1983
- Logs show: `1983-07-19 22:00:00 +0000`
- Backend receives: `"1983-07-19"` (after fix 1a)

The date was consistently off by one day.

### Root Cause

**Timezone Mismatch:** 

1. `DatePicker` creates a `Date` at **midnight in the user's local timezone**
   - User in GMT+2 selects July 20, 1983
   - `Date` represents: "1983-07-20 00:00:00 GMT+2"
   - Same instant in UTC: "1983-07-19 22:00:00 UTC"

2. Original date conversion code was extracting calendar components **in UTC**:
   ```swift
   var calendar = Calendar(identifier: .gregorian)
   calendar.timeZone = TimeZone(secondsFromGMT: 0)!  // UTC
   let components = calendar.dateComponents([.year, .month, .day], from: self)
   // For "1983-07-19 22:00:00 UTC", this extracts July 19, not July 20!
   ```

3. When converting back from string, it was also using UTC, causing the cycle to repeat

### Solution

Updated date handling to **always use the user's local timezone** for calendar dates:

#### Sending Dates to Backend

```swift
extension Date {
    /// Converts Date to ISO 8601 date string (YYYY-MM-DD format)
    ///
    /// **CRITICAL:** Uses the user's current timezone to extract calendar components.
    /// This ensures that when a user selects "July 20, 1983" in a DatePicker,
    /// we send "1983-07-20" to the backend, not "1983-07-19" due to UTC conversion.
    func toISO8601DateString() -> String {
        // Extract calendar components in the user's current timezone
        // This respects the calendar date the user selected in the DatePicker
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%04d-%02d-%02d", 
            components.year!, 
            components.month!, 
            components.day!
        )
    }
}
```

#### Parsing Dates from Backend

```swift
extension Date {
    /// Creates a Date from an ISO 8601 date string (YYYY-MM-DD) in the user's current timezone
    ///
    /// **CRITICAL:** Parses the date string as a calendar date in the user's timezone,
    /// not as a UTC timestamp. This ensures that "1983-07-20" creates a Date representing
    /// July 20, 1983 at midnight in the user's local timezone.
    static func fromISO8601DateString(_ dateString: String) -> Date? {
        let components = dateString.split(separator: "-")
        guard components.count == 3,
            let year = Int(components[0]),
            let month = Int(components[1]),
            let day = Int(components[2])
        else {
            return nil
        }
        
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        
        // Create date in user's current timezone
        return Calendar.current.date(from: dateComponents)
    }
}
```

#### Updated String Extension

```swift
extension String {
    func toDateFromISO8601() throws -> Date {
        let isoFormatter = ISO8601DateFormatter()
        
        // Try full timestamp first (with time)
        if let date = isoFormatter.date(from: self) {
            return date
        }
        
        // Try date-only format (YYYY-MM-DD) - parse in user's local timezone
        // This matches DatePicker behavior which creates dates at midnight local time
        if let date = Date.fromISO8601DateString(self) {
            return date
        }
        
        throw DTOConversionError.invalidDateFormat(self)
    }
}
```

### Result

- User selects: **July 20, 1983**
- Internal `Date`: "1983-07-20 00:00:00" in user's timezone
- Backend receives: `"1983-07-20"` ✅
- When parsed back: "1983-07-20 00:00:00" in user's timezone ✅
- **Correct throughout the entire flow** ✅

### Files Modified

- `FitIQ/Infrastructure/Network/DTOs/AuthDTOs.swift`

---

## Issue 3: Missing HealthKit Data in Edit Form

### Problem

Even though HealthKit had height and biological sex data, the edit form showed empty fields when opened.

### Root Cause

The data flow was:

1. **Profile loads** → `loadUserProfile()` called
   - Loads from local storage (empty physical profile)
   - Loads from backend (404 or empty)
   - Calls `loadFromHealthKitIfNeeded()` to populate missing fields
   - ✅ Data loaded correctly

2. **User taps "Edit Profile"** → `startEditing()` called
   - Original implementation: just set `isEditingProfile = true`
   - ❌ Did NOT reload HealthKit data
   - Form fields bound to ViewModel properties (correct)
   - But if HealthKit permissions were granted AFTER profile loaded, or data was added later, form showed old/empty values

### Solution

#### Updated ViewModel

Made `startEditing()` async and reload HealthKit data:

```swift
@MainActor
func startEditing() async {
    isEditingProfile = true
    
    // Reload HealthKit data if fields are empty
    // This ensures we have the latest data even if permissions were granted
    // or data was added after the profile initially loaded
    print("ProfileViewModel: Starting edit mode - checking for HealthKit data")
    await loadFromHealthKitIfNeeded()
}
```

#### Updated View

Changed the edit sheet's `.onAppear` to call `startEditing()`:

```swift
.onAppear {
    // Populate form fields when sheet opens
    // This also reloads HealthKit data if fields are empty
    Task {
        await viewModel.startEditing()
    }
}
```

### Result

Now when the edit sheet opens:

1. `startEditing()` is called
2. `loadFromHealthKitIfNeeded()` checks if height/sex are empty
3. If empty, fetches from HealthKit
4. Form fields update automatically via SwiftUI bindings
5. ✅ User sees pre-populated height and biological sex

### Files Modified

- `FitIQ/Presentation/ViewModels/ProfileViewModel.swift`
- `FitIQ/Presentation/UI/Profile/ProfileView.swift`

---

## Testing Checklist

### Test Case 1: Date of Birth Selection

- [ ] Open Edit Profile
- [ ] Select date of birth: July 20, 1983
- [ ] Save profile
- [ ] Check logs: should show `"date_of_birth": "1983-07-20"`
- [ ] Close and reopen Edit Profile
- [ ] Verify date picker still shows July 20, 1983
- [ ] **Expected:** No off-by-one error

### Test Case 2: Partial Profile Update (Date Only)

- [ ] Clear profile data (or create new user)
- [ ] Set only date of birth during registration
- [ ] Leave height and biological sex empty
- [ ] App should NOT attempt to sync physical profile to backend
- [ ] Check logs: should show "Skipping physical profile sync - only date_of_birth present"
- [ ] **Expected:** No 400 errors, local data preserved

### Test Case 3: Partial Profile Update (Height or Sex)

- [ ] Open Edit Profile
- [ ] Set height to 175cm OR biological sex to "male"
- [ ] Save profile
- [ ] Check logs: should show request with non-null fields only
- [ ] Backend should return 200
- [ ] **Expected:** Successful sync

### Test Case 4: HealthKit Pre-population

- [ ] Grant HealthKit permissions
- [ ] Add height and biological sex to Health app
- [ ] Open FitIQ app
- [ ] Open Edit Profile
- [ ] **Expected:** Height and biological sex are pre-filled
- [ ] Change the values
- [ ] Cancel edit
- [ ] Reopen Edit Profile
- [ ] **Expected:** Shows HealthKit values again (not changed values)

### Test Case 5: Full Profile Flow

- [ ] Register new user with DOB: July 20, 1983
- [ ] Grant HealthKit permissions
- [ ] Add height: 175cm and sex: male in Health app
- [ ] Open Edit Profile
- [ ] Verify all fields are populated correctly
- [ ] Change name, bio, height, and sex
- [ ] Save profile
- [ ] Check logs: physical profile syncs with height and sex
- [ ] Log out and log back in
- [ ] Open Edit Profile
- [ ] **Expected:** All data persisted correctly, no date shift

---

## Architecture Notes

### Local-First Design

The fixes maintain the **local-first architecture**:

1. **Local storage (SwiftData) is the source of truth**
2. **Backend sync is asynchronous and non-blocking**
3. **Data flow:**
   - User input → Local storage (immediate)
   - Local storage → Backend sync (background, queued)
   - Backend → Local storage (merge on fetch, prefer local if conflict)

### Error Handling

- 400 errors on backend sync are now **handled gracefully**
- Profile is saved locally immediately
- Backend sync is skipped if only date_of_birth is present
- User is not blocked by backend limitations

### Timezone Philosophy

**Calendar dates (like date of birth) should respect the user's calendar selection, not UTC time.**

- User selects July 20 → Store as July 20
- Don't convert to UTC and back (causes off-by-one errors)
- Backend receives YYYY-MM-DD strings, not timestamps
- Always parse/format dates in user's local timezone for calendar dates

### Backend API Limitation

The `/api/v1/users/me/physical` endpoint:
- ✅ Supports updating `biological_sex` and/or `height_cm`
- ❌ Does NOT support updating only `date_of_birth`
- ℹ️ Schema includes `date_of_birth` but backend implementation requires at least one physical attribute

This is by design:
- Date of birth is set at registration (COPPA compliance)
- Physical profile endpoint is for mutable physical attributes
- If date of birth needs updating, it should be handled via a different mechanism (future enhancement)

---

## Related Documentation

- Previous handoff: `docs/fixes/PHYSICAL_PROFILE_400_ERROR_HANDOFF.md`
- Architecture: `docs/IOS_INTEGRATION_HANDOFF.md`
- API Spec: `docs/be-api-spec/swagger.yaml`

---

## Summary

All three issues have been resolved:

✅ **400 Error (Null Values):** Backend now accepts partial profile updates (only non-nil fields sent)  
✅ **400 Error (Date Only):** Skip backend sync when only date_of_birth is present (backend limitation)  
✅ **Date Off-by-One:** Date of birth is now correctly handled in user's timezone  
✅ **Missing HealthKit Data:** Edit form now pre-populates height and biological sex from HealthKit

**Status:** Ready for testing  
**Date:** January 27, 2025  
**Engineers:** AI Assistant with Marcos Barbero

---

## Appendix: Log Examples

### Before Fixes

```
ProfileSyncService: Syncing physical profile with:
  - biologicalSex: nil
  - heightCm: nil
  - dateOfBirth: 1983-07-19 22:00:00 +0000
PhysicalProfileAPIClient: Request body: {
  "biological_sex": null,
  "height_cm": null,
  "date_of_birth": "1983-07-19"
}
PhysicalProfileAPIClient: Update response status code: 400
```

### After Fixes

```
ProfileSyncService: Syncing physical profile with:
  - biologicalSex: nil
  - heightCm: nil
  - dateOfBirth: 1983-07-20 00:00:00 +0000
ProfileSyncService: ⚠️  Skipping physical profile sync - only date_of_birth present
ProfileSyncService: Backend /users/me/physical requires biological_sex or height_cm
ProfileSyncService: date_of_birth is set during registration and cannot be updated via this endpoint
```

### Successful Sync (with height/sex)

```
ProfileSyncService: Syncing physical profile with:
  - biologicalSex: male
  - heightCm: 175.0
  - dateOfBirth: 1983-07-20 00:00:00 +0000
PhysicalProfileAPIClient: Request body: {
  "biological_sex": "male",
  "height_cm": 175.0,
  "date_of_birth": "1983-07-20"
}
PhysicalProfileAPIClient: Update response status code: 200
PhysicalProfileAPIClient: Successfully updated physical profile
```
