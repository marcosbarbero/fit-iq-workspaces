# Date of Birth Timezone Mismatch Fix

## Issue Summary

**Problem:** Date of birth values were experiencing timezone-related shifts when being sent to and received from the backend API. For example, a user selecting "July 20, 1983" might see "July 19, 1983" after saving and reloading.

**Root Cause:** Inconsistent timezone handling between date serialization (Date → String) and deserialization (String → Date).

## Technical Details

### Before the Fix

#### Sending Dates (Date → String)
```swift
// Used Calendar.dateComponents WITHOUT explicit timezone
let calendar = Calendar(identifier: .gregorian)
let components = calendar.dateComponents([.year, .month, .day], from: date)
// Default behavior: Uses system timezone
```

#### Receiving Dates (String → Date)
```swift
// Used DateFormatter WITHOUT explicit timezone
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"
// Default behavior: Uses system timezone
```

### The Problem

1. **Internal Date Representation:** Swift's `Date` type represents an absolute point in time (timestamp), not a calendar date
2. **Timezone Conversion:** When extracting components or parsing strings without an explicit timezone, the system timezone is used
3. **Mismatch Example:**
   - User in PST (UTC-8) selects "July 20, 1983"
   - DatePicker creates: "1983-07-20 07:00:00 UTC" (midnight PST = 8am UTC)
   - Sending: Calendar extracts components in PST → "1983-07-20" ✓
   - Backend stores: "1983-07-20"
   - Receiving: DateFormatter parses in PST → "1983-07-20 07:00:00 UTC" ✓
   - BUT if timezone changes or Date is manipulated: Shifts can occur

### The Solution

Use **UTC timezone explicitly** for all date-only operations to ensure consistency.

#### After the Fix

#### Sending Dates (Date → String)
```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!  // UTC
let components = calendar.dateComponents([.year, .month, .day], from: date)
// Always uses UTC, regardless of device timezone
```

#### Receiving Dates (String → Date)
```swift
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"
dateFormatter.calendar = Calendar(identifier: .gregorian)
dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)  // UTC
// Always parses in UTC, regardless of device timezone
```

## Files Modified

### 1. `Infrastructure/Network/DTOs/AuthDTOs.swift`
- **`String.toDateFromISO8601()`:** Added `timeZone = UTC` to DateFormatter
- **`Date.toISO8601DateString()`:** Added `timeZone = UTC` to Calendar

### 2. `Infrastructure/Network/UserAuthAPIClient.swift`
- **`register()`:** Updated date formatting to use UTC timezone

### 3. `Infrastructure/Network/UserProfileAPIClient.swift`
- **`updateProfile()`:** Updated date formatting to use UTC timezone
- **`createProfile()`:** Updated date formatting to use UTC timezone

### 4. `Infrastructure/Network/UserProfileMetadataClient.swift`
- **`createProfile()`:** Updated date formatting to use UTC timezone

## Benefits

1. **Consistency:** Date of birth is always parsed and formatted using UTC
2. **No Timezone Shifts:** "1983-07-20" always represents July 20, 1983, regardless of device timezone
3. **Predictability:** Same date value is preserved across save/load cycles
4. **Backend Compatibility:** Matches backend expectation of date-only format (YYYY-MM-DD)

## Testing Recommendations

### Manual Testing
1. **Different Timezones:**
   - Test on devices in PST (UTC-8), EST (UTC-5), GMT+8, etc.
   - Verify date of birth remains consistent after save/load
   
2. **Edge Cases:**
   - Test dates near timezone boundaries (midnight)
   - Test historic dates (1900s) and recent dates (2020s)
   
3. **Round Trip:**
   - Select a date → Save profile → Reload profile → Verify same date appears

### Automated Testing (Recommended)
```swift
func testDateOfBirthTimezoneConsistency() {
    // Arrange
    let dobString = "1983-07-20"
    
    // Act: Parse from API
    let parsedDate = try? dobString.toDateFromISO8601()
    
    // Act: Format back to string
    let formattedString = parsedDate?.toISO8601DateString()
    
    // Assert: Should match original
    XCTAssertEqual(formattedString, dobString)
}

func testDateOfBirthAcrossTimezones() {
    // Test in different timezone contexts
    let timezones = ["America/Los_Angeles", "America/New_York", "Asia/Tokyo", "UTC"]
    
    for tzIdentifier in timezones {
        // Temporarily set timezone context
        let originalTZ = TimeZone.current
        defer { TimeZone.current = originalTZ }
        
        // ... test date parsing/formatting consistency
    }
}
```

## API Format Reference

### Backend Expected Format
- **Date of Birth:** `"YYYY-MM-DD"` (e.g., `"1983-07-20"`)
- **Timestamps:** ISO 8601 with timezone (e.g., `"2024-01-15T14:30:00Z"`)

### iOS Internal Representation
- **Date of Birth:** `Date` object parsed at midnight UTC
- **Display:** Extracted as calendar date components in UTC
- **API Encoding:** Formatted as `"YYYY-MM-DD"` from UTC components

## Migration Notes

### Existing Data
- **No migration needed:** The fix only affects future date operations
- **Existing dates:** Will be normalized to UTC on next save
- **User impact:** May see slight date shifts (±1 day) for existing profiles if they were affected by the bug

### Backward Compatibility
- **API:** No changes to API format (still `"YYYY-MM-DD"`)
- **Storage:** SwiftData stores `Date` objects (no format change)
- **Display:** No changes to how dates are displayed to users

## Related Issues

- **Profile Save/Load Issue:** This fix resolves date inconsistencies during profile updates
- **Physical Profile API:** Date of birth is part of physical profile (`/api/v1/users/me/physical`)

## References

- **API Spec:** `docs/api-spec.yaml` - Physical Profile schema
- **Apple Documentation:** [DateFormatter](https://developer.apple.com/documentation/foundation/dateformatter)
- **ISO 8601 Standard:** Date format specification

---

**Status:** ✅ Fixed  
**Date:** 2025-01-27  
**Related PR:** [Link to PR when merged]
