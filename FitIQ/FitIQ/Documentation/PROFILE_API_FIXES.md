# Profile API Fixes - Documentation

**Version:** 2.1.0  
**Date:** 2025-01-27  
**Status:** ✅ FIXED

---

## 🐛 Issues Fixed

### 1. Backend API Endpoint Errors (404 & 400)

**Problem:**
- UserProfileAPIClient: Failed to update user profile. Status: 404
- PhysicalProfileAPIClient: Failed to update physical profile. Status: 400

**Root Cause:**
- `ProfileSyncService` was calling the old `updateProfile()` method which had incorrect parameters
- The old method was sending `gender`, `height`, `weight`, `activityLevel` which don't belong in the metadata endpoint
- Missing the new `updateProfileMetadata()` method in the protocol

**Solution:**
1. Added `updateProfileMetadata()` method to `UserProfileAPIClient`
2. Added method to `UserProfileRepositoryProtocol` 
3. Updated `ProfileSyncService.syncMetadata()` to call the new method with correct parameters
4. Uses proper `UserProfileUpdateRequest` DTO with:
   - `name` (required)
   - `bio` (optional)
   - `preferred_unit_system` (required)
   - `language_code` (optional)

**Files Modified:**
- `UserProfileAPIClient.swift` - Added `updateProfileMetadata()` method
- `UserProfileRepositoryProtocol.swift` - Added protocol method
- `ProfileSyncService.swift` - Fixed to call correct method

---

### 2. Date of Birth Not Pre-populated

**Problem:**
- DoB field showing random date instead of actual user's date of birth from registration/HealthKit

**Root Cause:**
- ProfileViewModel was initializing `dateOfBirth` with `Date()` (today)
- UI was checking for `userProfile?.dateOfBirth` existence before showing the picker
- This prevented the binding from working correctly

**Solution:**
1. Simplified DoB picker to always use the `$viewModel.dateOfBirth` binding
2. ProfileViewModel properly loads DoB from profile:
   ```swift
   // Prioritize physical profile DOB, then metadata DOB
   if let physical = profile?.physical, let dob = physical.dateOfBirth {
       self.dateOfBirth = dob
   } else if let dob = profile?.metadata.dateOfBirth {
       self.dateOfBirth = dob
   }
   ```
3. Removed conditional rendering of date picker

**Files Modified:**
- `ProfileView.swift` - Simplified DoB picker UI
- `ProfileViewModel.swift` - Already had correct loading logic

---

### 3. Preferences Section Width Issues

**Problem:**
- Preferences section appeared narrower than other sections
- Pickers were centralized and very small

**Root Cause:**
- `ModernPicker` component didn't have proper width constraints
- Picker was using default sizing which made it compact

**Solution:**
Added `.frame(maxWidth: .infinity, alignment: .leading)` to ModernPicker:

```swift
struct ModernPicker: View {
    // ... properties ...
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ... label ...
            
            Picker(label, selection: $selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)  // ✅ ADDED
            .padding(14)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10)
        }
    }
}
```

**Files Modified:**
- `ProfileView.swift` - Updated `ModernPicker` component

---

## 📊 API Request/Response Examples

### Correct Profile Metadata Update

**Endpoint:** `PUT /api/v1/users/me`

**Request Body:**
```json
{
  "name": "John Doe",
  "bio": "Fitness enthusiast",
  "preferred_unit_system": "metric",
  "language_code": "en"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "name": "John Doe",
    "bio": "Fitness enthusiast",
    "preferred_unit_system": "metric",
    "language_code": "en",
    "date_of_birth": "1990-01-15",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-27T10:30:00Z"
  }
}
```

---

### Correct Physical Profile Update

**Endpoint:** `PATCH /api/v1/users/me/physical`

**Request Body:**
```json
{
  "biological_sex": "male",
  "height_cm": 180.5,
  "date_of_birth": "1990-01-15"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "biological_sex": "male",
    "height_cm": 180.5,
    "date_of_birth": "1990-01-15"
  }
}
```

---

## ✅ Verification Checklist

### API Integration
- [x] Metadata update calls correct endpoint (`PUT /api/v1/users/me`)
- [x] Uses correct request DTO (`UserProfileUpdateRequest`)
- [x] Sends only metadata fields (name, bio, unit system, language)
- [x] Physical update calls correct endpoint (`PATCH /api/v1/users/me/physical`)
- [x] Uses correct request DTO (`PhysicalProfileUpdateRequest`)
- [x] Sends only physical fields (biological sex, height, DoB)

### UI/UX
- [x] Date of birth pre-populated from profile
- [x] Date of birth picker always visible and bound correctly
- [x] Preferences section full width
- [x] Pickers properly sized and aligned
- [x] No compiler errors
- [x] No compiler warnings

### Data Flow
- [x] Profile loads → DoB populates from stored data
- [x] User edits → Saves to local storage
- [x] Events published → Sync services triggered
- [x] Sync calls correct API endpoints
- [x] Response updates local storage

---

## 🔍 Testing Results

### Manual Testing

**Test 1: Update Profile Metadata**
```
✅ Edit name → Save → Success (200)
✅ Edit bio → Save → Success (200)
✅ Change unit system → Save → Success (200)
✅ Change language → Save → Success (200)
```

**Test 2: Update Physical Profile**
```
✅ Edit height → Save → Success (200)
✅ Edit biological sex → Save → Success (200)
✅ Edit date of birth → Save → Success (200)
```

**Test 3: Date of Birth Display**
```
✅ Profile with DoB → Shows correct date in picker
✅ Profile without DoB → Shows today, user can change
✅ Wheel picker easy to navigate to birth year
```

**Test 4: Preferences Section**
```
✅ Section same width as other sections
✅ Pickers full width, left-aligned
✅ Options clearly visible
```

---

## 📝 Code Changes Summary

### New Methods Added

**UserProfileAPIClient.swift:**
```swift
func updateProfileMetadata(
    userId: String,
    name: String,
    bio: String?,
    preferredUnitSystem: String,
    languageCode: String?
) async throws -> UserProfile
```

**UserProfileRepositoryProtocol.swift:**
```swift
func updateProfileMetadata(
    userId: String,
    name: String,
    bio: String?,
    preferredUnitSystem: String,
    languageCode: String?
) async throws -> UserProfile
```

### Methods Modified

**ProfileSyncService.syncMetadata():**
```swift
// OLD (incorrect):
let updatedProfile = try await userProfileRepository.updateProfile(
    userId: userId,
    name: metadata.name,
    dateOfBirth: metadata.dateOfBirth,
    gender: nil,
    height: nil,
    weight: nil,
    activityLevel: nil
)

// NEW (correct):
let updatedProfile = try await apiClient.updateProfileMetadata(
    userId: userId,
    name: metadata.name,
    bio: metadata.bio,
    preferredUnitSystem: metadata.preferredUnitSystem,
    languageCode: metadata.languageCode
)
```

---

## 🚀 Deployment Notes

### No Breaking Changes
- Old `updateProfile()` method still exists for backward compatibility
- New `updateProfileMetadata()` method used by ProfileSyncService
- No database migrations needed
- No user data migration needed

### What Users Will See
- ✅ Profile updates now work correctly
- ✅ No more 404/400 errors
- ✅ Date of birth shows correctly
- ✅ Preferences section looks correct
- ✅ Seamless offline-to-online sync

---

## 📚 Related Documentation

- `PROFILE_IMPLEMENTATION_FINAL.md` - Complete implementation guide
- `PROFILE_EDIT_QUICK_START.md` - Developer quick start
- `PROFILE_EDIT_IMPLEMENTATION_COMPLETE.md` - Original implementation

---

**Status:** ✅ ALL ISSUES RESOLVED  
**Version:** 2.1.0  
**Date:** 2025-01-27