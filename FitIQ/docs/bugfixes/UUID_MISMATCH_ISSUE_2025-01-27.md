# UUID Mismatch Issue - Auth vs Profile

**Date:** 2025-01-27  
**Status:** 🔴 CRITICAL  
**Priority:** P0  
**Impact:** Prevents Force Re-sync, may affect data sync

---

## 🐛 Problem

Force Re-sync fails with error:
```
User ID: B8430693-CD74-4561-9B54-943A9842B24D
❌ User profile not found
❌ Force re-sync failed: User profile not found
```

**Root Cause:**
The user ID stored in keychain doesn't match the profile ID in the database.

---

## 🔍 Diagnostic Output

```
SwiftDataAdapter: Fetching profile for user ID: B8430693-CD74-4561-9B54-943A9842B24D
SwiftDataAdapter: Found 1 total profiles in storage
SwiftDataAdapter:   - Profile ID: E4865493-ABE1-4BCF-8F51-B7F70E57F8EB, Name: 'Marcos Barbero'
SwiftDataAdapter: No profile found for user B8430693-CD74-4561-9B54-943A9842B24D
```

**Analysis:**
- **Auth Manager has:** `B8430693-CD74-4561-9B54-943A9842B24D` (from keychain)
- **Database has:** `E4865493-ABE1-4BCF-8F51-B7F70E57F8EB` (actual profile)
- **Result:** UUID mismatch → profile not found → operations fail

---

## 💥 Impact

### What's Broken:
- ❌ Force Re-sync feature (cannot find profile)
- ❌ Any operation requiring `currentUserProfileID`
- ❌ Potentially data sync (if using wrong user ID)
- ❌ Profile operations (fetch/update)

### What Still Works:
- ✅ App launches
- ✅ View displays data (uses HealthKit directly)
- ✅ Current weight shows correctly
- ✅ Charts render (from local storage)

---

## 🎯 Root Cause Analysis

### How This Happens:

1. **Scenario A: Account Switch Without Logout**
   - User logged in with Account A
   - Database cleared/reset
   - User logged in again (new profile created with different UUID)
   - Keychain still has old UUID

2. **Scenario B: Development/Testing**
   - Database reset during development
   - Keychain not cleared
   - Old UUID persists in keychain
   - New profile has different UUID

3. **Scenario C: Backend User ID Changed**
   - Backend changed user's UUID
   - App still has old UUID in keychain
   - Profile lookup fails

### Why It Persists:

- **Keychain survives app reinstalls**
- **Database is local but keychain is system-level**
- **No validation on app startup to check UUID match**

---

## ✅ Solutions

### Solution 1: Logout and Login (Recommended)

**Steps:**
1. Tap **Profile** tab
2. Scroll down
3. Tap **"Logout"** button
4. Login again with same credentials
5. UUID will be reset to match current profile

**Why This Works:**
- `AuthManager.logout()` clears keychain
- Login fetches fresh profile from backend
- Saves correct UUID to keychain
- Everything syncs up

**Time Required:** 30 seconds

---

### Solution 2: Delete and Reinstall App

**Steps:**
1. Delete FitIQ app from device
2. Reinstall from App Store or Xcode
3. Login again

**Why This Works:**
- Clears ALL local data (database + keychain)
- Fresh start with correct UUIDs
- Guaranteed to fix mismatch

**Time Required:** 2 minutes

**⚠️ WARNING:**
- Loses all local data
- Loses pending sync entries
- Only use if logout doesn't work

---

### Solution 3: Developer Fix (Future)

Add UUID validation on app startup:

```swift
// In AuthManager.checkAuthenticationStatus()
if let userID = currentUserProfileID {
    // Verify profile exists with this ID
    let profile = try? await userProfileStorage.fetch(forUserID: userID)
    
    if profile == nil {
        print("⚠️ UUID mismatch detected: keychain ID doesn't match database")
        print("⚠️ Clearing invalid keychain entry and logging out")
        
        // Clear invalid UUID and force re-authentication
        try? authTokenPersistence.deleteUserProfileID()
        await logout()
    }
}
```

**Benefits:**
- Automatically detects mismatches
- Forces re-authentication to fix
- Prevents operations from failing silently
- Better user experience

---

## 🧪 How to Diagnose

### Check Current State:

**1. Check Auth Manager UUID:**
```swift
print("Auth User ID: \(authManager.currentUserProfileID)")
// Output: B8430693-CD74-4561-9B54-943A9842B24D
```

**2. Check Database Profiles:**
```swift
// Run in SwiftDataAdapter
let descriptor = FetchDescriptor<SDUserProfile>()
let profiles = try modelContext.fetch(descriptor)
profiles.forEach { profile in
    print("Profile ID: \(profile.id), Name: '\(profile.name)'")
}
// Output: Profile ID: E4865493-ABE1-4BCF-8F51-B7F70E57F8EB, Name: 'Marcos Barbero'
```

**3. Compare UUIDs:**
- If they don't match → UUID mismatch issue
- If they match → Different problem

---

## 🔧 Implementation Notes

### Where UUID is Stored:

**Keychain (AuthManager):**
- Key: `KeychainKey.userProfileID`
- Managed by: `KeychainAuthTokenAdapter`
- Survives: App reinstall
- Cleared by: Logout or manual deletion

**Database (SwiftData):**
- Model: `SDUserProfile`
- Field: `id: UUID`
- Survives: App launches
- Cleared by: App deletion or manual reset

### Where UUID is Used:

1. **AuthManager.currentUserProfileID**
   - Used by all authenticated operations
   - Passed to use cases
   - Stored in keychain

2. **UserProfile.id**
   - Unique identifier in database
   - Returned from backend on registration/login
   - Used for data queries

### Critical Paths:

```
Login Flow:
1. User logs in
2. Backend returns user profile with ID
3. AuthManager saves ID to keychain
4. All operations use this ID

Mismatch Flow:
1. Keychain has old ID (A)
2. Database has new profile with ID (B)
3. Operation tries to fetch with ID (A)
4. No profile found → FAIL
```

---

## 📊 Error Messages

### Before Fix:
```
User ID: B8430693-CD74-4561-9B54-943A9842B24D
❌ User profile not found
```

### After Fix (Improved):
```
User ID: B8430693-CD74-4561-9B54-943A9842B24D
❌ User profile not found for ID: B8430693-CD74-4561-9B54-943A9842B24D

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
UUID MISMATCH DETECTED!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

The user ID in keychain doesn't match any profile in the database.

Possible causes:
  1. User logged in with different account
  2. Database was cleared but keychain wasn't
  3. Profile was deleted but session remained active

🔧 SOLUTION:
  1. Log out from the app
  2. Log back in
  3. This will reset the user ID in keychain

If issue persists:
  - Delete and reinstall the app
  - This will clear all local data and keychain
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
```

---

## 🎓 Prevention

### For Development:

1. **Always logout before resetting database**
   ```swift
   // In development/testing
   await authManager.logout()  // Clear keychain
   // Then reset database
   ```

2. **Clear keychain with database**
   ```swift
   // When clearing all data
   try modelContext.delete(model: SDUserProfile.self)
   try authTokenPersistence.deleteUserProfileID()
   ```

3. **Add validation on startup**
   - Check UUID match on authentication
   - Auto-logout if mismatch detected
   - Show clear error message to user

### For Production:

1. **Never change user UUIDs on backend**
   - UUIDs should be immutable
   - Use email/username for identification
   - UUID is internal reference only

2. **Sync keychain with database**
   - Always fetch fresh profile on login
   - Validate UUID exists before saving
   - Clear invalid UUIDs proactively

3. **Handle migration gracefully**
   - If backend changes user system
   - Force re-authentication for all users
   - Clear old keychain entries

---

## 📝 Action Items

### Immediate (User):
- [x] User should logout and login again
- [ ] Verify Force Re-sync works after login
- [ ] Check if backend sync resumes

### Short-term (Developer):
- [ ] Add UUID validation on app startup
- [ ] Add diagnostic button to check UUID match
- [ ] Improve error messages (already done)
- [ ] Add logging for UUID mismatches

### Long-term (Architecture):
- [ ] Implement automatic UUID validation
- [ ] Add UUID sync health check
- [ ] Alert user if mismatch detected
- [ ] Provide in-app fix (not just logout)
- [ ] Add analytics to track mismatch frequency

---

## 🔗 Related Issues

### Potentially Related:
- Backend only has 1 entry (UUID mismatch prevents sync)
- RemoteSyncService might be using wrong user ID
- Profile operations might be failing silently

### To Investigate:
- [ ] Check RemoteSyncService logs for user ID used
- [ ] Verify sync events are using correct user ID
- [ ] Check if progress entries have correct user ID
- [ ] Verify HealthKit sync uses correct user ID

---

## ✅ Success Criteria

Issue is resolved when:
1. ✅ Auth Manager UUID matches Database Profile UUID
2. ✅ Force Re-sync completes successfully
3. ✅ Profile operations work (fetch/update)
4. ✅ Data sync resumes (local → backend)
5. ✅ No "profile not found" errors

---

## 📞 Support Script

**If user reports similar issue:**

1. **Diagnose:**
   - "Can you try the Force Re-sync feature?"
   - If it says "User profile not found" → UUID mismatch

2. **Solution:**
   - "Please log out and log back in"
   - "This will reset your session and fix the issue"

3. **If that doesn't work:**
   - "Delete and reinstall the app"
   - "Login again with your credentials"
   - "Your data in HealthKit is safe"

4. **Escalate if:**
   - Issue persists after reinstall
   - User can't login
   - Multiple users affected
   → Backend UUID might have changed

---

**Last Updated:** 2025-01-27  
**Status:** Documented with clear solution  
**Resolution:** User should logout and login again  
**Estimated Fix Time:** 30 seconds (logout/login)