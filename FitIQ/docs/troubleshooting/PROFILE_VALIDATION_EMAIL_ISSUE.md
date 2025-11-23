# Profile Validation Email Issue

**Date:** 2025-01-27  
**Status:** 🟡 Known Issue (Not Blocking)  
**Priority:** Medium  
**Related:** Phase 2.1 Profile Unification Migration

---

## Issue Description

When updating profile metadata, validation fails with "Email address cannot be empty" error, even though the user profile was successfully fetched from storage.

### Error Messages

```
SwiftDataAdapter: Fetched profile for user 8998A287-93D2-4FDC-8175-96FA26E8DF80
ProfileViewModel: ❌ Failed to update profile metadata: Validation failed: Email address cannot be empty
ProfileViewModel: ⚠️  Skipping physical profile save due to metadata save failure
```

---

## Root Cause Analysis

### Likely Causes

1. **Empty Email Field in Form**
   - User may be editing profile with email field left blank
   - Form validation not preventing submission with empty email
   - ViewModel passing empty string instead of preserving existing email

2. **ViewModel State Issue**
   - `ProfileViewModel` may not be properly initializing email field from fetched profile
   - State binding may be losing email value during edit
   - Email field not being populated when edit sheet opens

3. **Validation Timing**
   - Validation occurring before profile data is fully loaded
   - Email field binding not synchronized with loaded profile

4. **Backend API Requirements**
   - Backend may require email in update request even if unchanged
   - ViewModel not including existing email when user doesn't modify it

---

## Current Behavior

### Success Case (Normal Flow)
1. User profile fetched from local storage ✅
2. Profile contains valid email ✅
3. User opens edit profile sheet
4. Makes changes to name/bio/preferences
5. Saves profile ❌ **FAILS HERE**

### Failure Point
- **Where:** `ProfileViewModel.saveProfileMetadata()`
- **When:** During profile update to backend API
- **Why:** Email validation fails (empty string detected)

---

## Impact

### User Experience
- ❌ Cannot save profile changes
- ❌ Confusing error message (doesn't mention which field is empty)
- ❌ Physical profile updates also blocked (cascading failure)

### Severity
- **Medium Priority:** Blocks profile editing functionality
- **Not Critical:** User can still use app, just can't edit profile
- **Workaround:** User must ensure email field is filled (may not be visible in UI)

---

## Investigation Steps

### 1. Check ProfileViewModel State Management

**File:** `ProfileViewModel.swift`

Look for:
- How email field is initialized when edit sheet opens
- Whether email state is bound to text field
- If existing email is preserved when user edits other fields

```swift
// Check if email is properly loaded
func loadUserProfile() async {
    // Verify email is set from fetched profile
}

// Check if email is included in save
func saveProfileMetadata() async {
    // Verify email parameter is not empty
}
```

### 2. Check EditProfileSheet Form

**File:** `ProfileView.swift` (EditProfileSheet section)

Verify:
- Email field exists and is visible
- Email field is bound to correct ViewModel property
- Email field has proper placeholder/default value
- Form validation prevents empty email submission

### 3. Check UserProfile Validation

**File:** `FitIQCore/Sources/FitIQCore/Auth/Domain/UserProfile.swift`

Review:
```swift
extension UserProfile {
    func validate() -> [ValidationError] {
        // Check email validation logic
        if email.isEmpty {
            errors.append(.emptyEmail)  // ← This is triggering
        }
    }
}
```

### 4. Check API Client Email Handling

**File:** `UserProfileAPIClient.swift`

Verify:
- `updateProfileMetadata()` method signature
- Whether email is required parameter
- How empty/nil emails are handled

---

## Potential Solutions

### Option 1: Preserve Existing Email (Recommended)

**Location:** `ProfileViewModel.saveProfileMetadata()`

```swift
func saveProfileMetadata() async {
    // ✅ Use existing email if user didn't change it
    let emailToSave = userEmailField.isEmpty ? userProfile?.email ?? "" : userEmailField
    
    let updatedProfile = try await updateProfileMetadataUseCase.execute(
        name: userName,
        bio: userBio,
        email: emailToSave,  // ← Preserve existing email
        // ... other fields
    )
}
```

### Option 2: Make Email Read-Only

**Location:** `EditProfileSheet`

```swift
// Email should not be editable in profile edit
// (Require separate "Change Email" flow with verification)

Text(viewModel.userProfile?.email ?? "")
    .foregroundColor(.secondary)
// Instead of TextField
```

### Option 3: Pre-populate Email Field

**Location:** `ProfileViewModel.loadUserProfile()`

```swift
func loadUserProfile() async {
    guard let profile = try await userProfileStorage.fetch(forUserID: userID) else {
        return
    }
    
    self.userProfile = profile
    self.userName = profile.name
    self.userEmail = profile.email  // ✅ Pre-populate email field
    self.userBio = profile.bio ?? ""
    // ... other fields
}
```

### Option 4: Add Form Validation

**Location:** `EditProfileSheet`

```swift
Button("Save") {
    Task {
        await viewModel.saveProfileMetadata()
    }
}
.disabled(viewModel.userEmail.isEmpty)  // ✅ Prevent save with empty email
```

---

## Recommended Fix (Combination Approach)

### Step 1: Make Email Read-Only in Profile Edit
- Users should not change email in profile edit flow
- Email changes require verification (separate flow)
- Display email as read-only text in EditProfileSheet

### Step 2: Preserve Existing Email in Save
- ViewModel should always use existing email from loaded profile
- Never send empty email to backend
- Backend update should not require email parameter if unchanged

### Step 3: Add Better Error Handling
- Show specific field validation errors in UI
- Highlight which field has validation error
- Provide clear guidance to user

---

## Testing Checklist

After implementing fix, verify:

- [ ] Profile loads with existing email visible
- [ ] Email field is read-only (or hidden) in edit sheet
- [ ] User can edit name/bio/preferences without email error
- [ ] Email is preserved in backend update
- [ ] Physical profile updates work after metadata save
- [ ] Validation errors show specific field names
- [ ] No cascading failures (physical profile saves correctly)

---

## Related Files

### Primary Files to Investigate
- `FitIQ/Presentation/ViewModels/ProfileViewModel.swift`
- `FitIQ/Presentation/UI/Profile/ProfileView.swift` (EditProfileSheet)
- `FitIQ/Domain/UseCases/UpdateProfileMetadataUseCase.swift`
- `FitIQ/Infrastructure/Network/UserProfileAPIClient.swift`

### Related Files
- `FitIQCore/Sources/FitIQCore/Auth/Domain/UserProfile.swift` (Validation logic)
- `FitIQ/Infrastructure/Persistence/Adapters/SwiftDataUserProfileAdapter.swift`

---

## Workaround for Users

Until fixed, users must:
1. Ensure email field is visible and filled in profile edit form
2. Re-enter email if it's blank (should match existing email)
3. Contact support if email is unknown

---

## Priority Justification

**Why Medium Priority:**
- Blocks important user functionality (profile editing)
- Affects user experience negatively
- Simple to fix (likely one-line change)
- Not a data loss risk (validation prevents bad saves)

**Why Not High Priority:**
- App remains functional for core features
- Only affects profile editing, not health tracking
- Workaround exists (manually enter email)
- No security implications

---

## Next Steps

1. **Immediate:** Document issue (✅ Done)
2. **Short-term:** Investigate ProfileViewModel and EditProfileSheet
3. **Implementation:** Apply recommended fix (combination approach)
4. **Testing:** Verify all profile edit flows work correctly
5. **Deploy:** Include fix in next release

---

**Status:** 🟡 Documented  
**Assigned To:** TBD  
**Target Fix:** Next sprint  
**Last Updated:** 2025-01-27

---

## Update Log

| Date | Update | Author |
|------|--------|--------|
| 2025-01-27 | Initial documentation | AI Assistant |