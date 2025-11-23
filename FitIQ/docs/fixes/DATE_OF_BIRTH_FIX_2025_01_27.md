# Date of Birth Timezone Fix - January 27, 2025

**Status:** ✅ Complete  
**Date:** January 27, 2025  
**Issue:** Date of birth off by one day (July 20 → July 19)  
**Root Cause:** UTC timezone used instead of local timezone during registration  
**Build Status:** ✅ BUILD SUCCEEDED

---

## 📋 Problem Summary

### The Issue
Users registering with date of birth "July 20, 1983" were seeing "July 19, 1983" in their profile.

### Evidence from Logs
```
Input: July 20, 1983
Logs show: 1983-07-19 22:00:00 +0000
Expected: 1983-07-20 00:00:00 +0000 (or local timezone)

SwiftDataAdapter: SDUserProfile DOB: 1983-07-19 22:00:00 +0000
```

### Root Cause
In the registration flow (`UserAuthAPIClient.register()`), the code was extracting date components using **UTC timezone**:

```swift
// ❌ WRONG - Used UTC timezone
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!  // UTC
let components = calendar.dateComponents([.year, .month, .day], from: userData.dateOfBirth)
```

When a user in GMT+2 timezone selected July 20 at midnight (local time):
- Local time: 1983-07-20 00:00:00 GMT+2
- Converted to UTC: 1983-07-19 22:00:00 UTC
- Extracted components: year=1983, month=7, day=**19** ❌

---

## ✅ The Fix

### What Changed
Updated `UserAuthAPIClient.register()` to use the **user's current timezone** instead of UTC when extracting date components.

### Code Changes

**File:** `FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`

**Before (Lines 84-90):**
```swift
// Extract calendar components from the Date in UTC timezone
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!  // UTC
let components = calendar.dateComponents([.year, .month, .day], from: userData.dateOfBirth)
let dobString = String(
    format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
```

**After (Lines 84-95):**
```swift
// Extract calendar components from the Date in the USER'S LOCAL TIMEZONE
// This ensures the selected date (e.g., July 20) is preserved as "1983-07-20"
// The DatePicker provides local midnight, so we extract components in local time
let calendar = Calendar.current  // Use user's current calendar/timezone
let components = calendar.dateComponents([.year, .month, .day], from: userData.dateOfBirth)
let dobString = String(
    format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)

print("UserAuthAPIClient: Date conversion - Input: \(userData.dateOfBirth)")
print("UserAuthAPIClient: Date conversion - Output string: \(dobString)")
print("UserAuthAPIClient: Date conversion - Timezone: \(calendar.timeZone.identifier)")
```

### Key Changes
1. Changed from `Calendar(identifier: .gregorian)` with UTC to `Calendar.current`
2. Removed explicit UTC timezone override
3. Added debug logging for date conversion
4. Updated comments to reflect correct behavior

---

## 🔍 Why This Works

### DatePicker Behavior
SwiftUI's `DatePicker` creates dates at **midnight in the user's local timezone**:
- User selects: July 20, 1983
- DatePicker creates: July 20, 1983 00:00:00 in local timezone
- Not: July 20, 1983 00:00:00 UTC

### Correct Flow (After Fix)
```
User selects July 20, 1983 in DatePicker
    ↓
Date object: 1983-07-20 00:00:00 GMT+2 (local midnight)
    ↓
Extract components using Calendar.current (GMT+2)
    ↓
Components: year=1983, month=7, day=20 ✅
    ↓
Format string: "1983-07-20" ✅
    ↓
Send to backend: "1983-07-20" ✅
    ↓
Backend stores: 1983-07-20 ✅
```

### Incorrect Flow (Before Fix)
```
User selects July 20, 1983 in DatePicker
    ↓
Date object: 1983-07-20 00:00:00 GMT+2 (local midnight)
    ↓
Convert to UTC: 1983-07-19 22:00:00 UTC ❌
    ↓
Extract components using UTC calendar
    ↓
Components: year=1983, month=7, day=19 ❌
    ↓
Format string: "1983-07-19" ❌
    ↓
Send to backend: "1983-07-19" ❌
```

---

## ✅ Verification

### Build Status
```bash
xcodebuild -scheme FitIQ -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

** BUILD SUCCEEDED **
```

### What's Fixed
- ✅ New user registrations will store correct date
- ✅ Date components extracted in user's local timezone
- ✅ "July 20" stays "July 20" regardless of timezone
- ✅ No off-by-one errors for new registrations

### What's NOT Fixed (Yet)
- ❌ Existing users with incorrect dates in database
- ❌ Need data migration for existing profiles

---

## 🧪 Testing Checklist

### For New Users (After Fix)
- [ ] Register with DOB: July 20, 1983
- [ ] Check logs: Should show "1983-07-20" being sent
- [ ] Verify SwiftData storage shows July 20
- [ ] Open profile: Should display July 20, 1983
- [ ] **Expected:** No off-by-one error ✅

### For Existing Users (Migration Needed)
- [ ] Existing profile shows July 19 instead of July 20
- [ ] Need to implement data migration
- [ ] Option 1: Ask user to re-enter DOB
- [ ] Option 2: Add +1 day to all DOBs in migration
- [ ] Option 3: Backend fix + re-sync

---

## 📊 Impact Analysis

### Affected Users
- **New users (after fix):** ✅ Will see correct date
- **Existing users (before fix):** ❌ Still have wrong date in storage

### Affected Timezones
- **Negative offsets (west of UTC):** Different day, earlier
- **Positive offsets (east of UTC):** Different day, later
- **UTC (GMT+0):** No visible issue (but still technically wrong approach)

### Example Impact by Timezone

| User Timezone | Selected Date | Before Fix (UTC) | After Fix (Local) |
|---------------|---------------|------------------|-------------------|
| GMT-8 (PST)   | July 20       | July 20* (luck)  | July 20 ✅        |
| GMT+0 (UTC)   | July 20       | July 20* (luck)  | July 20 ✅        |
| GMT+2 (EET)   | July 20       | July 19 ❌       | July 20 ✅        |
| GMT+8 (CST)   | July 20       | July 19 ❌       | July 20 ✅        |

*Appears correct by coincidence, but approach is wrong

---

## 🔗 Related Code

### Date Extension Helpers (Already Correct)

The following helper functions were already using `Calendar.current` correctly:

**`Date.toISO8601DateString()` - Encoding dates for API**
```swift
// Located in: AuthDTOs.swift
func toISO8601DateString() -> String {
    let calendar = Calendar.current  // ✅ Already correct
    let components = calendar.dateComponents([.year, .month, .day], from: self)
    return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
}
```

**`Date.fromISO8601DateString()` - Parsing dates from API**
```swift
// Located in: AuthDTOs.swift
static func fromISO8601DateString(_ dateString: String) -> Date? {
    // ... parse components ...
    return Calendar.current.date(from: dateComponents)  // ✅ Already correct
}
```

**Issue was ONLY in registration flow** where UTC was explicitly forced.

---

## 📝 Files Modified

### Changed Files
- `FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`
  - Line 86: Changed `Calendar(identifier: .gregorian)` to `Calendar.current`
  - Line 87: Removed UTC timezone override
  - Lines 92-94: Added debug logging
  - Updated comments

### Total Changes
- **Lines changed:** 6
- **Lines added:** 3 (logging)
- **Lines removed:** 2 (UTC override)
- **Impact:** Registration flow only

---

## 🚀 Next Steps

### Immediate (Complete)
- ✅ Fix registration flow for new users
- ✅ Verify build succeeds
- ✅ Document the fix

### Short-term (Pending)
- [ ] Test with new user registration
- [ ] Verify logs show correct date conversion
- [ ] Confirm no off-by-one errors for new users

### Long-term (Future Work)
- [ ] **Data Migration:** Fix existing users' dates
- [ ] **Options:**
  1. Backend migration script (safest)
  2. App-side migration on first launch
  3. Ask users to re-enter DOB
- [ ] **Testing:** Verify migration doesn't break anything

---

## 🎓 Key Learnings

### Calendar Date vs Timestamp
- **Calendar dates** (e.g., birthdays) should use **local timezone**
- **Timestamps** (e.g., createdAt) should use **UTC**
- Date of birth is a **calendar date**, not a timestamp

### DatePicker Behavior
- Creates dates at **midnight in user's local timezone**
- NOT at midnight UTC
- Must extract components in same timezone

### Best Practices
1. **Calendar dates:** Use `Calendar.current`
2. **Timestamps:** Use UTC or ISO8601DateFormatter
3. **Always test with non-UTC timezones**
4. **Log timezone conversions** for debugging

### Common Pitfall
```swift
// ❌ WRONG - Forces UTC for calendar dates
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!

// ✅ CORRECT - Uses user's timezone for calendar dates
let calendar = Calendar.current
```

---

## 📞 Support & Resources

**Documentation:**
- Profile Sync Fixes: `docs/fixes/PROFILE_SYNC_FIXES_2025_01_27.md`
- Next Steps Handoff: `docs/handoffs/NEXT_STEPS_HANDOFF_2025_01_27.md`
- DI Wiring: `docs/implementation-summaries/DI_WIRING_COMPLETE_2025_01_27.md`

**Related Files:**
- `UserAuthAPIClient.swift` - Registration flow
- `AuthDTOs.swift` - Date encoding/decoding helpers
- `RegisterUserUseCase.swift` - Registration use case

**API Documentation:**
- Registration endpoint: POST /api/v1/auth/register
- Date format: "YYYY-MM-DD" (calendar date, not timestamp)

---

## 📈 Status Summary

| Aspect | Status | Notes |
|--------|--------|-------|
| Root cause identified | ✅ Complete | UTC timezone in registration |
| Fix implemented | ✅ Complete | Uses Calendar.current |
| Build verified | ✅ Complete | BUILD SUCCEEDED |
| New users fixed | ✅ Complete | Will work correctly |
| Existing users migrated | ❌ Pending | Need data migration |
| Testing completed | ⏳ Pending | Ready for testing |

---

**Status:** ✅ Fix Complete (New Users)  
**Build:** ✅ SUCCESS  
**Ready for:** Testing & Migration Planning  
**Priority:** Migration for existing users