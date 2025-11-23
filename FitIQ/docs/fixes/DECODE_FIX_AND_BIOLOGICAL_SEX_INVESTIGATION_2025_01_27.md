# Decode Fix and Biological Sex Investigation - January 27, 2025

**Status:** ✅ Decode Fixed, 🔍 Biological Sex Under Investigation  
**Date:** January 27, 2025  
**Issues:** 
1. Response decode warning (extra nesting level)
2. Biological sex not appearing in sync despite HealthKit data available  
**Build Status:** ✅ BUILD SUCCEEDED

---

## 📋 Problem Summary

### Issue 1: Response Decode Warning ✅ FIXED

**Symptom:**
```
UserProfileAPIClient: Metadata Update Response (200): 
{"data":{"profile":{"id":"...","name":"Marcos Barbero",...}}}

UserProfileAPIClient: Failed to decode wrapped response, trying direct decode...
```

**Root Cause:**
Backend response has **extra nesting level** with `"profile"` wrapper:

```json
// Actual backend response:
{
  "data": {
    "profile": {        // ← Extra wrapper!
      "id": "...",
      "name": "...",
      ...
    }
  }
}

// What StandardResponse expected:
{
  "data": {
    "id": "...",      // ← Direct profile fields
    "name": "...",
    ...
  }
}
```

### Issue 2: Biological Sex Not Syncing 🔍 INVESTIGATING

**Symptom:**
```
ProfileSyncService: Syncing physical profile with:
  - biologicalSex: nil
  - heightCm: nil (now fixed)
  - dateOfBirth: 1983-07-19 22:00:00 +0000
```

Despite:
- UI shows biological sex (e.g., "Male")
- `syncBiologicalSexFromHealthKit()` is called
- HealthKit has the data

---

## ✅ Fix 1: Response Decode Issue

### Solution
Created wrapper DTO to match backend response structure.

### Code Changes

**File:** `FitIQ/Infrastructure/Network/DTOs/AuthDTOs.swift`

**Added (after line 40):**
```swift
/// Wrapper for the actual profile response structure from backend
/// Backend returns: {"data": {"profile": {...}}}
struct UserProfileDataWrapper: Decodable {
    let profile: UserProfileResponseDTO
}
```

**File:** `FitIQ/Infrastructure/Network/UserProfileAPIClient.swift`

**Before (Lines 331-340):**
```swift
let decoder = configuredDecoder()
let metadata: UserProfileMetadata
do {
    let successResponse = try decoder.decode(
        StandardResponse<UserProfileResponseDTO>.self, from: data)
    metadata = try successResponse.data.toDomain()
    print("UserProfileAPIClient: Successfully updated profile metadata")
} catch {
    print("UserProfileAPIClient: Failed to decode wrapped response, trying direct decode...")
    let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
    metadata = try profileDTO.toDomain()
    print("UserProfileAPIClient: Successfully updated profile metadata")
}
```

**After (Lines 331-348):**
```swift
// Backend returns: {"data": {"profile": {...}}}
let decoder = configuredDecoder()
let metadata: UserProfileMetadata
do {
    let successResponse = try decoder.decode(
        StandardResponse<UserProfileDataWrapper>.self, from: data)
    metadata = try successResponse.data.profile.toDomain()
    print("UserProfileAPIClient: Successfully decoded wrapped profile response")
} catch {
    print(
        "UserProfileAPIClient: Failed to decode with wrapper, trying direct profile decode..."
    )
    // Fallback: try decoding profile directly (for backward compatibility)
    let profileDTO = try decoder.decode(UserProfileResponseDTO.self, from: data)
    metadata = try profileDTO.toDomain()
    print("UserProfileAPIClient: Successfully decoded direct profile response")
}
```

### What Changed
1. Decode now expects `StandardResponse<UserProfileDataWrapper>` instead of `StandardResponse<UserProfileResponseDTO>`
2. Access profile via `successResponse.data.profile` instead of `successResponse.data`
3. Updated log messages for clarity
4. Kept fallback for backward compatibility

### Expected Result
- ✅ Primary decode path succeeds (no fallback needed)
- ✅ No more "Failed to decode wrapped response" warnings
- ✅ Cleaner logs

---

## 🔍 Investigation: Biological Sex Not Syncing

### Current Understanding

#### The Flow (How It Should Work)

```
1. User opens Edit Profile sheet
    ↓
2. startEditing() is called
    ↓
3. loadFromHealthKitIfNeeded() loads biological sex
    ↓
4. syncBiologicalSexFromHealthKit() is called
    ↓
5. SyncBiologicalSexFromHealthKitUseCase.execute()
    ↓
6. Should:
   a. Save to local storage ✅
   b. Sync to backend ✅
   c. Update profile.physical.biologicalSex ✅
```

#### The Code (What It Does)

**ProfileViewModel.syncBiologicalSexFromHealthKit():**
```swift
// Fetch from HealthKit
let hkBiologicalSex = try await healthRepository.fetchBiologicalSex()
let sexString = "male" // (mapped from HealthKit enum)

// Sync via use case
try await syncUseCase.execute(
    userId: userId.uuidString,
    biologicalSex: sexString
)

// Update UI state
self.biologicalSex = sexString
```

**SyncBiologicalSexFromHealthKitUseCaseImpl.execute():**
```swift
// 1. Fetch current profile
guard let currentProfile = try await userProfileStorage.fetch(forUserID: userUUID) else {
    throw ProfileError.notFound(userId)
}

// 2. Check if changed (change detection)
let currentSex = currentProfile.physical?.biologicalSex
if currentSex == biologicalSex {
    print("No change detected, skipping sync")
    return  // ← Early exit if no change
}

// 3. Update local storage
let updatedPhysical = PhysicalProfile(
    biologicalSex: biologicalSex,
    heightCm: currentProfile.physical?.heightCm,
    dateOfBirth: currentProfile.physical?.dateOfBirth
)
let updatedProfile = currentProfile.updatingPhysical(updatedPhysical)
try await userProfileStorage.save(userProfile: updatedProfile)

// 4. Sync to backend
try await physicalProfileRepository.updatePhysicalProfile(
    userId: userId,
    biologicalSex: biologicalSex,
    heightCm: currentProfile.physical?.heightCm,
    dateOfBirth: currentProfile.physical?.dateOfBirth
)
```

### Possible Causes

#### Theory 1: Change Detection Too Aggressive
If `currentProfile.physical?.biologicalSex` is already set to the HealthKit value, the change detection exits early and doesn't sync.

**Problem:** First time should be `nil → "male"` which is a change.

#### Theory 2: Profile Not Found
If `userProfileStorage.fetch()` returns `nil`, the use case throws an error and never saves.

**Check logs for:**
```
SyncBiologicalSexFromHealthKitUseCase: ❌ Profile not found
```

#### Theory 3: Backend Sync Failing
Local save succeeds, but backend sync fails. The use case doesn't throw (by design), so it appears to succeed but backend never gets the value.

**Check logs for:**
```
SyncBiologicalSexFromHealthKitUseCase: ⚠️ Backend sync failed: ...
```

#### Theory 4: ProfileSyncService Reading Before Save Complete
ProfileSyncService might be reading the profile before `SyncBiologicalSexFromHealthKitUseCase` completes.

**Race condition:**
```
Time 0: syncBiologicalSexFromHealthKit() starts
Time 1: ProfileSyncService reads profile (still has old data)
Time 2: syncBiologicalSexFromHealthKit() completes
```

### Debugging Steps

#### Step 1: Enable Detailed Logging
Check console for these log sequences:

**Expected (Success):**
```
ProfileViewModel: ===== SYNC BIOLOGICAL SEX FROM HEALTHKIT =====
ProfileViewModel: HealthKit biological sex: male
SyncBiologicalSexFromHealthKitUseCase: ===== HEALTHKIT SYNC START =====
SyncBiologicalSexFromHealthKitUseCase: User ID: [UUID]
SyncBiologicalSexFromHealthKitUseCase: HealthKit biological sex: male
SyncBiologicalSexFromHealthKitUseCase: Current local value: nil
SyncBiologicalSexFromHealthKitUseCase: 🔄 Change detected: 'nil' → 'male'
SyncBiologicalSexFromHealthKitUseCase: ✅ Saved to local storage
SyncBiologicalSexFromHealthKitUseCase: 📡 Syncing to backend...
SyncBiologicalSexFromHealthKitUseCase: ✅ Successfully synced to backend
SyncBiologicalSexFromHealthKitUseCase: ===== SYNC COMPLETE =====
ProfileViewModel: ✅ Biological sex sync complete
```

**Failure Pattern 1 (No Change):**
```
SyncBiologicalSexFromHealthKitUseCase: Current local value: male
SyncBiologicalSexFromHealthKitUseCase: ✅ No change detected, skipping sync
```

**Failure Pattern 2 (Profile Not Found):**
```
SyncBiologicalSexFromHealthKitUseCase: ❌ Profile not found
```

**Failure Pattern 3 (Backend Sync Failed):**
```
SyncBiologicalSexFromHealthKitUseCase: ✅ Saved to local storage
SyncBiologicalSexFromHealthKitUseCase: ⚠️ Backend sync failed: [error]
```

#### Step 2: Verify Storage
After sync completes, check what's in storage:

```swift
// In ProfileViewModel or test
let profile = try? await userProfileStorage.fetch(forUserID: userId)
print("Stored biological sex: \(profile?.physical?.biologicalSex ?? "nil")")
```

#### Step 3: Check Timing
Verify sync completes before ProfileSyncService reads:

```swift
// In ProfileViewModel.startEditing()
await syncBiologicalSexFromHealthKit()
print("✅ Biological sex sync completed")
// Now safe for ProfileSyncService to read
```

---

## 🎯 Recommended Actions

### Immediate (Testing/Debugging)
1. ✅ Deploy decode fix (already done)
2. 🔍 Run app with logging enabled
3. 🔍 Observe log sequence for biological sex sync
4. 🔍 Identify which failure pattern occurs (if any)

### If "No Change Detected"
**Problem:** Value already set (shouldn't happen on first sync)

**Solution:** Check why `currentProfile.physical?.biologicalSex` is already set:
- Previous sync succeeded but ProfileSyncService missed it?
- Data from registration?
- Cached old value?

### If "Profile Not Found"
**Problem:** User profile doesn't exist in storage yet

**Solutions:**
1. Create profile during registration (ensure it happens)
2. Add profile creation in sync use case as fallback
3. Better error handling for missing profiles

### If "Backend Sync Failed"
**Problem:** Local save works, backend rejects

**Solutions:**
1. Check error message (likely 400/404/500)
2. Verify PATCH /users/me/physical endpoint accepts biologicalSex alone
3. Check if backend requires height_cm (should be optional)
4. Review backend logs for rejection reason

### If Timing Issue
**Problem:** ProfileSyncService reads too early

**Solutions:**
1. Ensure `await syncBiologicalSexFromHealthKit()` completes before sync
2. Add explicit sync trigger after HealthKit data loaded
3. Debounce ProfileSyncService (wait for all data to load)

---

## 📝 Files Modified

### Decode Fix
1. `FitIQ/Infrastructure/Network/DTOs/AuthDTOs.swift`
   - Added `UserProfileDataWrapper` struct (6 lines)

2. `FitIQ/Infrastructure/Network/UserProfileAPIClient.swift`
   - Updated decode logic to use wrapper (changed 10 lines)
   - Updated log messages for clarity

### Total Changes
- **Lines added:** 6
- **Lines modified:** 10
- **Build status:** ✅ SUCCESS

---

## 🧪 Testing Checklist

### Decode Fix (Ready to Test)
- [ ] Update profile metadata (name, bio, etc.)
- [ ] Check logs: Should NOT see "Failed to decode wrapped response"
- [ ] Check logs: Should see "Successfully decoded wrapped profile response"
- [ ] Verify profile update succeeds
- [ ] Verify no fallback to direct decode

### Biological Sex Sync (Needs Investigation)
- [ ] Grant HealthKit permission
- [ ] Ensure biological sex set in Health app
- [ ] Open Edit Profile sheet
- [ ] Check logs for sync sequence
- [ ] Verify which pattern occurs (success/no change/not found/backend failed)
- [ ] Check storage after sync
- [ ] Verify ProfileSyncService sees the value

---

## 📊 Status Summary

| Issue | Status | Next Steps |
|-------|--------|------------|
| Decode warning | ✅ Fixed | Test and verify |
| Biological sex not syncing | 🔍 Investigating | Enable logging, identify failure pattern |
| Height auto-save | ✅ Fixed (previous) | Test with HealthKit data |
| Date of birth timezone | ✅ Fixed (previous) | Test with new registrations |
| Duplicate cleanup | ✅ Fixed (previous) | Monitor logs on app launch |

---

## 💡 Key Insights

### Backend Response Structure
- Backend nests profile under `"profile"` key: `{"data": {"profile": {...}}}`
- Need wrapper DTO to match structure
- Always verify actual API response format vs. assumptions

### Change Detection
- Change detection is optimization (avoid unnecessary syncs)
- But can hide issues if value is "already set" when it shouldn't be
- Need to understand WHY value might already be set

### Async Timing
- Async operations can complete out of order
- Use `await` to ensure completion before dependent operations
- Log completion points to verify timing

### Error Handling Patterns
- Non-critical operations (like backend sync) should log warnings, not throw
- But this can mask issues (appears successful but actually failed)
- Need explicit logging at each step to trace execution

---

## 📞 Next Steps for Developer

### Before Next Session
1. Test the decode fix
2. Run app with full logging
3. Capture complete log sequence for biological sex sync
4. Share logs for analysis

### During Next Session
Based on log analysis:
- Implement fix for identified failure pattern
- Add more robust error handling if needed
- Consider adding retry logic for backend sync failures
- Test end-to-end flow

---

**Status:** ✅ Decode Fixed, 🔍 Biological Sex Investigation Ongoing  
**Build:** ✅ SUCCESS  
**Next:** Enable detailed logging and identify biological sex sync failure pattern