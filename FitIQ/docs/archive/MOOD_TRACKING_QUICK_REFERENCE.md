# Mood Tracking - Quick Reference Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**For:** Developers working on mood tracking features

---

## 🚀 Quick Start

### Save a Mood Entry
```swift
let viewModel = moodEntryViewModel
viewModel.moodScore = 8
viewModel.notes = "Feeling great today!"
await viewModel.saveMoodEntry()
```

### Load Mood History
```swift
let viewModel = moodDetailViewModel
await viewModel.loadHistoricalData()
// Access: viewModel.historicalData
```

### Get Latest Mood
```swift
let viewModel = summaryViewModel
await viewModel.fetchLatestMoodEntry()
// Display: viewModel.moodEmoji + viewModel.moodDisplayText
```

---

## 📝 Constants Reference

### Scores
```swift
MoodScoreConstants.minScore        // 1
MoodScoreConstants.maxScore        // 10
MoodScoreConstants.defaultScore    // 5
MoodScoreConstants.maxNotesLength  // 500
```

### Time Ranges
```swift
MoodTrackingConstants.TimeRangeDays.week     // 7
MoodTrackingConstants.TimeRangeDays.month    // 30
MoodTrackingConstants.TimeRangeDays.quarter  // 90
MoodTrackingConstants.TimeRangeDays.year     // 365
```

---

## 🎨 Mood Display

### Text Labels
| Score | Display Text |
|-------|-------------|
| None | "Not Logged" |
| 1-3 | "Poor" |
| 4-5 | "Below Average" |
| 6 | "Neutral" |
| 7-8 | "Good" |
| 9-10 | "Excellent" |

### Emojis
| Score | Emoji |
|-------|-------|
| None | 😶 |
| 1-3 | 😔 |
| 4-5 | 🙁 |
| 6 | 😐 |
| 7-8 | 😊 |
| 9-10 | 🤩 |

### Colors
- **Primary:** Serenity Lavender `#B58BEF`
- **SwiftUI:** `Color.serenityLavender`

---

## 🔧 Key Components

### Use Cases
```swift
// Save mood
SaveMoodProgressUseCase.execute(
    score: Int,        // 1-10
    notes: String?,    // Optional, max 500 chars
    date: Date         // Defaults to now
) async throws -> UUID

// Get history
GetHistoricalMoodUseCase.execute(
    startDate: Date,
    endDate: Date
) async throws -> [ProgressEntry]
```

### ViewModels
```swift
// Entry
MoodEntryViewModel
    .moodScore: Int
    .notes: String
    .selectedDate: Date
    .saveMoodEntry() async
    .canSave: Bool

// History
MoodDetailViewModel
    .historicalData: [MoodRecord]
    .selectedRange: TimeRange
    .averageMoodScore: Double?
    .moodTrend: String
    .loadHistoricalData() async

// Summary
SummaryViewModel
    .latestMoodScore: Int?
    .moodDisplayText: String
    .moodEmoji: String
    .fetchLatestMoodEntry() async
```

---

## 🗄️ Data Models

### ProgressEntry
```swift
ProgressEntry(
    id: UUID,
    userID: String,
    type: .moodScore,           // ProgressMetricType
    quantity: Double,           // Score as Double
    date: Date,                 // Normalized to midnight
    notes: String?,
    createdAt: Date,
    updatedAt: Date?,
    backendID: String?,
    syncStatus: SyncStatus      // .pending, .syncing, .synced, .failed
)
```

### MoodRecord (UI Model)
```swift
MoodRecord(
    id: UUID,
    date: Date,
    score: Int,         // 1-10
    notes: String?
)
```

---

## 🔄 Data Flow

### Save Flow
```
User Input → ViewModel → UseCase → Repository → [SwiftData, Backend, HealthKit]
```

### Load Flow
```
Repository → UseCase → ViewModel → View
```

### Sync Flow
```
SwiftData (.pending) → LocalDataChangeMonitor → RemoteSyncService → Backend API
```

---

## 🏥 HealthKit Integration

### Category Type
```swift
HKCategoryTypeIdentifier.moodChanges
```

### Metadata
```swift
[
    "MoodScore": Int,
    "UserEnteredNotes": String?,
    "HKMetadataKeyUserMotivatedDelay": false
]
```

### Save to HealthKit
```swift
healthRepository.saveCategorySample(
    value: score,                           // 1-10
    typeIdentifier: .moodChanges,
    date: date,
    metadata: metadata
)
```

---

## 📊 API Integration

### Endpoint
```
POST /api/v1/progress
GET  /api/v1/progress?type=mood_score
```

### Request Body
```json
{
    "type": "mood_score",
    "quantity": 8.0,
    "logged_at": "2025-01-27T10:30:00Z",
    "notes": "Feeling great!"
}
```

### Response
```json
{
    "success": true,
    "data": {
        "id": "uuid",
        "type": "mood_score",
        "quantity": 8.0,
        "date": "2025-01-27T00:00:00Z",
        "notes": "Feeling great!",
        "created_at": "2025-01-27T10:30:05Z"
    }
}
```

---

## 🐛 Common Issues

### Issue: Mood not saving
**Check:**
1. User authenticated? `authManager.currentUserProfileID`
2. Score valid? `1...10`
3. Console logs? Look for errors
4. Repository working? Check SwiftData

### Issue: Wrong mood displayed
**Check:**
1. Latest fetch working? `fetchLatestMoodEntry()`
2. Multiple entries same day? Check duplicates
3. Score conversion? `Int(entry.quantity)`
4. Cache issue? Force refresh

### Issue: Not syncing to backend
**Check:**
1. Network connection
2. Auth token valid
3. RemoteSyncService running
4. Entry marked `.pending`
5. Backend API available

### Issue: Not appearing in HealthKit
**Check:**
1. HealthKit permissions granted
2. Console logs for HealthKit save
3. Open Health app → Mental Wellbeing
4. Check error handling in SaveMoodProgressUseCase

---

## 🧪 Testing

### Manual Test Scenarios
```swift
// 1. Basic save
viewModel.moodScore = 8
await viewModel.saveMoodEntry()
// Verify: Entry appears in history

// 2. Duplicate detection
// Save score 7 today
// Save score 8 today (same date)
// Verify: Only 1 entry, updated to score 8

// 3. Validation
viewModel.moodScore = 11  // Invalid
await viewModel.saveMoodEntry()
// Verify: Error shown

// 4. Offline mode
// Disable network
// Save mood
// Enable network
// Verify: Entry syncs automatically

// 5. HealthKit export
// Save mood
// Open Health app
// Verify: Entry in Mental Wellbeing
```

---

## 📁 File Locations

### Domain
```
Domain/
├── Entities/Progress/ProgressMetricType.swift  # .moodScore enum
├── UseCases/
│   ├── SaveMoodProgressUseCase.swift
│   └── GetHistoricalMoodUseCase.swift
└── Ports/HealthRepositoryProtocol.swift  # saveCategorySample()
```

### Infrastructure
```
Infrastructure/
├── Configuration/
│   ├── AppDependencies.swift           # DI registration
│   └── ViewModelAppDependencies.swift  # ViewModel wiring
└── Integration/
    └── HealthKitAdapter.swift          # HealthKit implementation
```

### Presentation
```
Presentation/
├── ViewModels/
│   ├── MoodEntryViewModel.swift
│   ├── MoodDetailViewModel.swift
│   └── SummaryViewModel.swift
└── UI/
    ├── Mood/MoodDetailView.swift
    └── Summary/SummaryView.swift
```

---

## 🔗 Related Features

### Similar Patterns
- **Body Mass Tracking** - Same architecture, use as reference
- **Steps Tracking** - Same progress repository
- **Activity Snapshots** - Similar sync pattern

### Shared Infrastructure
- **ProgressRepository** - Used by all metrics
- **RemoteSyncService** - Syncs all progress data
- **LocalDataChangeMonitor** - Triggers sync for all changes

---

## 💡 Tips & Tricks

### Performance
```swift
// Efficient date range query
let entries = try await getHistoricalMoodUseCase.execute(
    startDate: startDate,  // Only fetch needed range
    endDate: endDate
)
```

### Error Handling
```swift
// Non-critical errors (HealthKit)
do {
    try await healthRepository.saveCategorySample(...)
} catch {
    print("⚠️ HealthKit save failed: \(error)")
    // Continue - local and backend save still succeeded
}
```

### Debugging
```swift
// Enable verbose logging
print("SaveMoodProgressUseCase: Saving score \(score) for user \(userID)")
print("MoodDetailViewModel: Loaded \(historicalData.count) entries")
print("SummaryViewModel: Latest mood - Score: \(latestMoodScore ?? 0)")
```

---

## 📚 Documentation

**Comprehensive Guides:**
- `MOOD_TRACKING_IMPLEMENTATION.md` - Full implementation details
- `MOOD_TRACKING_CONSTANTS.md` - All constants reference
- `MOOD_TRACKING_TROUBLESHOOTING.md` - Debug guide
- `MOOD_TRACKING_HEALTHKIT_INTEGRATION.md` - HealthKit details
- `MOOD_TRACKING_HANDOFF.md` - Project handoff document

**Quick References:**
- This file - Quick lookup
- `.github/copilot-instructions.md` - Project standards

---

## 🎯 Key Takeaways

1. **Architecture:** Hexagonal (Domain → Infrastructure → Presentation)
2. **Data Storage:** Local-first (SwiftData → Backend → HealthKit)
3. **Sync:** Automatic background sync when online
4. **Validation:** 1-10 score, max 500 char notes
5. **Deduplication:** One entry per day (normalized to midnight)
6. **Constants:** Always use defined constants, never magic numbers
7. **Color:** Serenity Lavender for all mood UI elements
8. **Time Ranges:** 7D, 30D, 90D, 1Y (no magic numbers)

---

**Version:** 1.0.0  
**Status:** ✅ Production Ready (with noted polish items)  
**Last Updated:** 2025-01-27