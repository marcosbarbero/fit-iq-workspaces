# Mood Tracking Constants Reference

**Purpose:** Quick reference for all constants used in mood tracking implementation  
**Last Updated:** 2025-01-27

---

## 📊 Mood Score Constants

**Location:** `Domain/UseCases/SaveMoodProgressUseCase.swift`

```swift
enum MoodScoreConstants {
    /// Minimum valid mood score
    static let minScore: Int = 1

    /// Maximum valid mood score
    static let maxScore: Int = 10

    /// Default mood score (neutral/middle value)
    static let defaultScore: Int = 5

    /// Maximum length for mood notes
    static let maxNotesLength: Int = 500
}
```

### Usage

```swift
// Validation
guard score >= MoodScoreConstants.minScore && 
      score <= MoodScoreConstants.maxScore else {
    throw error
}

// Default value
var moodScore = MoodScoreConstants.defaultScore

// Notes validation
if notes.count > MoodScoreConstants.maxNotesLength {
    throw error
}
```

---

## 📅 Time Range Constants

**Location:** `Domain/UseCases/GetHistoricalMoodUseCase.swift`

```swift
enum MoodTrackingConstants {
    /// Maximum number of mood entries to fetch in a single query
    static let maxFetchLimit: Int = 500

    /// Default time range options (in days)
    enum TimeRangeDays {
        static let week: Int = 7
        static let month: Int = 30
        static let quarter: Int = 90
        static let year: Int = 365
    }
}
```

### Usage

```swift
// Calculate date range
let days = MoodTrackingConstants.TimeRangeDays.month
let startDate = Calendar.current.date(
    byAdding: .day, 
    value: -days, 
    to: Date()
)

// Performance check
if entryCount > MoodTrackingConstants.maxFetchLimit {
    print("⚠️ Large dataset detected")
}
```

---

## 🎯 Time Range Enum

**Location:** `Domain/UseCases/GetHistoricalMoodUseCase.swift`

```swift
enum MoodTimeRange {
    case last7Days
    case last30Days
    case last90Days
    case lastYear
    case custom(days: Int)
}
```

### Properties

```swift
// Calculate start date
func startDate(from endDate: Date) -> Date

// Display name: "Last 7 Days", "Last 30 Days", etc.
var displayName: String

// Short label: "7D", "30D", "90D", "1Y"
var shortLabel: String
```

### Usage

```swift
// Fetch data for time range
let entries = try await useCase.execute(
    timeRange: .last30Days
)

// Display in UI
Text(MoodTimeRange.last7Days.displayName)  // "Last 7 Days"
Text(MoodTimeRange.last7Days.shortLabel)   // "7D"
```

---

## 🎨 UI Time Range (ViewModel)

**Location:** `Presentation/ViewModels/MoodDetailViewModel.swift`

```swift
enum TimeRange: String, CaseIterable, Identifiable {
    case last7Days = "7D"
    case last30Days = "30D"
    case last90Days = "90D"
    case lastYear = "1Y"
    
    var id: String { rawValue }
    var days: Int { /* uses MoodTrackingConstants */ }
    var displayName: String
    var toMoodTimeRange: MoodTimeRange
}
```

### Usage

```swift
// In ViewModel
@Published var selectedRange: TimeRange = .last30Days

// Fetch data
let entries = try await getHistoricalMoodUseCase.execute(
    timeRange: selectedRange.toMoodTimeRange
)

// Display in picker
ForEach(TimeRange.allCases) { range in
    Text(range.rawValue)  // "7D", "30D", etc.
}
```

---

## 🔒 Validation Rules

### Mood Score
- **Type:** `Int`
- **Range:** `1...10` (inclusive)
- **Default:** `5`
- **Error:** `SaveMoodProgressError.invalidScore`

### Notes
- **Type:** `String?` (optional)
- **Max Length:** `500` characters
- **Trimming:** Whitespace trimmed before save
- **Empty Handling:** Empty string → `nil`
- **Error:** `SaveMoodProgressError.notesTooLong`

### Date
- **Type:** `Date`
- **Default:** `Date()` (current date/time)
- **Normalization:** Start of day for duplicate checking

---

## 📏 Performance Thresholds

### Fetch Limit
- **Threshold:** `500` entries
- **Action:** Log warning if exceeded
- **Recommendation:** Consider repository-level date filtering if regularly exceeded

### Date Range Options
- **7 Days:** Quick glance, minimal data
- **30 Days:** Default view, balanced
- **90 Days:** Quarterly trend analysis
- **1 Year:** Annual overview, more data

---

## ✅ Best Practices

### DO ✅

```swift
// Use constants
if score >= MoodScoreConstants.minScore && 
   score <= MoodScoreConstants.maxScore {
    // Valid
}

// Use time range enum
let entries = try await useCase.execute(
    timeRange: .last30Days
)

// Reference days constant
let days = MoodTrackingConstants.TimeRangeDays.month
```

### DON'T ❌

```swift
// DON'T use magic numbers
if score >= 1 && score <= 10 {  // ❌
    // Bad: Magic numbers
}

// DON'T hardcode days
let thirtyDaysAgo = Calendar.current.date(
    byAdding: .day, 
    value: -30,  // ❌ Magic number
    to: Date()
)

// DON'T use arbitrary limits
if entries.count > 1000 {  // ❌ Magic number
    print("Too many entries")
}
```

---

## 🔄 Migration Guide

If you need to change constants:

### 1. Update Constant Value
```swift
// Before
static let maxScore: Int = 10

// After
static let maxScore: Int = 15
```

### 2. Update Validation in ProgressMetricType
```swift
// Domain/Entities/Progress/ProgressMetricType.swift
case .moodScore:
    return quantity >= 1 && quantity <= 15  // Updated
```

### 3. Update Tests
```swift
// Update test expectations
func testInvalidScore() {
    // Now 16 is invalid (was 11)
    XCTAssertThrowsError(try useCase.execute(score: 16))
}
```

### 4. Update Documentation
- Update this file
- Update MOOD_TRACKING_IMPLEMENTATION.md
- Update API documentation if backend changes

---

## 📚 Related Files

### Constants Defined In
- `Domain/UseCases/SaveMoodProgressUseCase.swift` - Score validation
- `Domain/UseCases/GetHistoricalMoodUseCase.swift` - Time ranges & limits
- `Presentation/ViewModels/MoodDetailViewModel.swift` - UI time ranges

### Constants Used By
- `Domain/UseCases/SaveMoodProgressUseCaseImpl` - Score & notes validation
- `Domain/UseCases/GetHistoricalMoodUseCaseImpl` - Date range calculations
- `Presentation/ViewModels/MoodEntryViewModel` - Form validation
- `Presentation/ViewModels/MoodDetailViewModel` - Time range display
- `Domain/Entities/Progress/ProgressMetricType.swift` - Score validation

---

## 🎯 Quick Lookup

| Constant | Value | Purpose |
|----------|-------|---------|
| `minScore` | `1` | Minimum mood score |
| `maxScore` | `10` | Maximum mood score |
| `defaultScore` | `5` | Default/neutral score |
| `maxNotesLength` | `500` | Max characters for notes |
| `maxFetchLimit` | `500` | Performance threshold |
| `week` | `7` | Days in week range |
| `month` | `30` | Days in month range |
| `quarter` | `90` | Days in quarter range |
| `year` | `365` | Days in year range |

---

## 💡 Tips

1. **Always import the use case file** to access constants in ViewModels
2. **Use constants in error messages** for consistency
3. **Reference constants in validation** for maintainability
4. **Update all references** if changing a constant value
5. **Add tests** for constant-based validation logic

---

**Status:** ✅ Active  
**Version:** 1.0.0