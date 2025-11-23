# Fix: ProfileView Now Displays Data from Local Storage

**Date:** 2025-01-27  
**Status:** ✅ FIXED  
**Priority:** MEDIUM  
**Issue:** ProfileView was displaying data directly from HealthKit instead of local storage  

---

## 🎯 Executive Summary

**Problem:** The ProfileView was fetching height and date of birth directly from HealthKit via `bodyMetrics`, bypassing the local SwiftData storage. This meant that changes saved to the profile weren't immediately reflected in the UI.

**Solution:** Updated ProfileView to display height and date of birth from `userProfile.physical`, which reflects the local SwiftData storage and is always up-to-date with user edits.

**Impact:**
- ✅ Height changes now immediately visible in ProfileView
- ✅ Date of birth displayed from local storage
- ✅ UI reflects saved data without requiring HealthKit sync
- ✅ Better user experience - no delay in seeing updates

---

## 🔍 Problem Analysis

### What Was Happening

**ProfileView.swift (Before):**
```swift
// FIXME: Just a tryout to show data from the HealthKit
VStack(spacing: 1) {
    SettingRow(
        icon: "scalemass.fill",
        title: viewModel.bodyMetrics?.weightKg.map { String(format: "%.1f kg", $0) }
            ?? "Weight (N/A)", color: .gray
    ) {}

    let dob = DateFormatHelper.formatMediumDate(
        viewModel.bodyMetrics?.dateOfBirth ?? Date())

    SettingRow(icon: "gear", title: dob, color: .gray) {}
    SettingRow(
        icon: "gear",
        title: viewModel.bodyMetrics?.heightCm.map { String(format: "%.0f cm", $0) }
            ?? "Height (N/A)", color: .gray
    ) {}
}
```

**Issues:**
1. **`bodyMetrics`** is populated by `GetLatestBodyMetricsUseCase`, which fetches directly from HealthKit
2. **No reactivity** - UI doesn't update when profile is saved locally
3. **Bypasses local storage** - ignores SwiftData as source of truth
4. **Confusing data flow** - user saves profile, but doesn't see changes immediately

### Data Flow (Before)

```
User edits profile → Save to SwiftData → Sync to HealthKit → Sync to Backend
                                              ↓
ProfileView reads data ← HealthKit ← bodyMetrics (separate fetch)
```

❌ **Problem:** ProfileView was reading from HealthKit (step 3) instead of SwiftData (step 1)

---

## ✅ Solution Implemented

### Code Changes

**ProfileView.swift (After):**
```swift
// Physical Profile Data (from local storage)
VStack(spacing: 1) {
    // Weight - still from HealthKit (not stored in UserProfile)
    SettingRow(
        icon: "scalemass.fill",
        title: viewModel.bodyMetrics?.weightKg.map { String(format: "%.1f kg", $0) }
            ?? "Weight (N/A)", color: .gray
    ) {}

    // Date of Birth - from UserProfile.physical
    if let dob = viewModel.userProfile?.dateOfBirth {
        let dobFormatted = DateFormatHelper.formatMediumDate(dob)
        SettingRow(icon: "calendar", title: dobFormatted, color: .gray) {}
    } else {
        SettingRow(icon: "calendar", title: "Date of Birth (N/A)", color: .gray) {}
    }

    // Height - from UserProfile.physical
    if let heightCm = viewModel.userProfile?.physical?.heightCm {
        SettingRow(
            icon: "ruler",
            title: String(format: "%.0f cm", heightCm),
            color: .gray
        ) {}
    } else {
        SettingRow(icon: "ruler", title: "Height (N/A)", color: .gray) {}
    }
}
```

### Key Changes

| Field | Before | After | Reason |
|-------|--------|-------|--------|
| **Weight** | `bodyMetrics?.weightKg` | `bodyMetrics?.weightKg` | No change - weight not in UserProfile |
| **Date of Birth** | `bodyMetrics?.dateOfBirth` | `userProfile?.dateOfBirth` | ✅ From local storage |
| **Height** | `bodyMetrics?.heightCm` | `userProfile?.physical?.heightCm` | ✅ From local storage |

### Data Flow (After)

```
User edits profile → Save to SwiftData → Sync to HealthKit → Sync to Backend
                         ↓
ProfileView reads data ← userProfile (immediate update)
```

✅ **Fixed:** ProfileView now reads from SwiftData (step 1), showing immediate updates

---

## 🏗️ Architecture Explanation

### UserProfile Structure

```swift
public struct UserProfile {
    let metadata: UserProfileMetadata  // Name, bio, preferences
    let physical: PhysicalProfile?     // Height, biological sex, DOB
    let email: String?
    let username: String?
    // ... other fields
}

public struct PhysicalProfile {
    let biologicalSex: String?
    let heightCm: Double?
    let dateOfBirth: Date?
}
```

### Why Weight is Still from HealthKit

Weight is **not** stored in `UserProfile` because:
1. Backend doesn't have weight in profile endpoints
2. Weight is tracked via body mass entries (time-series data)
3. `GetLatestBodyMetricsUseCase` provides current weight from HealthKit

**Note:** Weight could be moved to local storage in the future by fetching the latest body mass entry from SwiftData instead of HealthKit.

---

## 🧪 Verification

### Test Scenario 1: Height Change

**Steps:**
1. Open ProfileView → Note current height
2. Tap "Edit Profile"
3. Change height from 170 cm to 175 cm
4. Tap "Save"
5. Dismiss edit sheet

**Expected (After Fix):**
```
ProfileView immediately shows: "175 cm"
```

**Before Fix:**
```
ProfileView still shows: "170 cm" (until HealthKit sync completes)
```

### Test Scenario 2: Date of Birth Display

**Steps:**
1. Open ProfileView
2. Check displayed date of birth

**Expected (After Fix):**
```
Date of Birth: July 19, 1983
```
✅ Shows value from `userProfile.dateOfBirth`

**Before Fix:**
```
Date of Birth: [Date from HealthKit, may be out of sync]
```

---

## 📊 Benefits

### 1. Immediate UI Updates

**Before:**
- User saves profile
- UI shows old data
- User confused: "Did my change save?"
- Must wait for HealthKit sync

**After:**
- User saves profile
- UI immediately updates
- Clear feedback
- Professional UX

### 2. Single Source of Truth

**Before:**
- Local storage has one value
- UI shows different value from HealthKit
- Data inconsistency confusion

**After:**
- UI reflects local storage
- Local storage is source of truth
- Consistent data everywhere

### 3. Better Icons

Changed icons to be more semantic:
- `calendar` - for date of birth (was `gear`)
- `ruler` - for height (was `gear`)
- More intuitive and professional

---

## 🔮 Future Improvements

### 1. Display Weight from Local Storage

Instead of fetching from HealthKit, fetch the latest body mass entry from SwiftData:

```swift
// Add to ProfileViewModel
@Published var latestWeight: Double?

func loadLatestWeight() async {
    // Fetch latest SDPhysicalAttribute where type == .bodyMass
    // Set latestWeight
}

// In ProfileView
SettingRow(
    icon: "scalemass.fill",
    title: viewModel.latestWeight.map { String(format: "%.1f kg", $0) } ?? "Weight (N/A)",
    color: .gray
) {}
```

**Benefits:**
- Consistent data source (all from SwiftData)
- Shows saved weight immediately
- No dependency on HealthKit for display

### 2. Add Biological Sex Display

```swift
// In ProfileView
if let biologicalSex = viewModel.userProfile?.physical?.biologicalSex {
    SettingRow(
        icon: "person.fill",
        title: biologicalSex.capitalized,
        color: .gray
    ) {}
}
```

### 3. Make Fields Tappable

Allow tapping on the rows to directly edit values:

```swift
SettingRow(icon: "ruler", title: "175 cm", color: .gray) {
    showingEditSheet = true
    // Optionally scroll to height field
}
```

---

## 🎓 Lessons Learned

### 1. UI Should Reflect Local State

**Principle:** The UI should always display data from the local storage (SwiftData), not from external systems (HealthKit, Backend).

**Why:**
- Local storage is the source of truth
- User edits are saved locally first
- UI should reflect what the user just saved

### 2. HealthKit is an Integration, Not a Database

**Principle:** HealthKit is for syncing and background updates, not for UI display.

**Why:**
- HealthKit sync is asynchronous
- User shouldn't wait for HealthKit to see their changes
- Local-first architecture principles

### 3. ViewModels Should Expose Local Data

**Principle:** ViewModels should primarily expose data from local storage, with external data as fallback.

**Pattern:**
```swift
// ✅ Good
@Published var userProfile: UserProfile?  // Local storage

// ⚠️ Use sparingly
@Published var bodyMetrics: HealthMetricsSnapshot?  // External (HealthKit)
```

---

## 📝 Checklist

- [x] Identified data source issue (HealthKit vs local storage)
- [x] Updated ProfileView to use `userProfile.physical`
- [x] Changed icons to be more semantic
- [x] Added code comments explaining data sources
- [x] Verified no compilation errors
- [x] Documented the fix
- [ ] Test in iOS app (user to verify)
- [ ] Consider moving weight to local storage (future improvement)

---

## 🔗 Related Documentation

- **Height Unchanged Log:** `docs/explanations/HEIGHT_UNCHANGED_LOG_EXPLAINED_2025_01_27.md`
- **Body Mass Sync Fix:** `docs/fixes/BODY_MASS_HEIGHT_SYNC_FIX_2025_01_27.md`
- **405 Error Fix:** `docs/handoffs/FIX_405_ERROR_PHYSICAL_PROFILE_2025_01_27.md`

---

## 💡 Key Takeaway

**Always display data from local storage in the UI, not from external integrations.**

This ensures:
- ✅ Immediate feedback to user
- ✅ Consistent data display
- ✅ Better user experience
- ✅ Local-first architecture

External systems (HealthKit, Backend) are for:
- Background syncing
- Data persistence
- Cross-device synchronization
- NOT for UI display

---

**Status:** ✅ Fixed and Documented  
**Risk:** Low - Simple data source change  
**Impact:** High - Much better user experience  

---

**Author:** AI Assistant  
**Date:** 2025-01-27  
**Version:** 1.0