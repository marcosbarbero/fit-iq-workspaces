# Mood Entry Feature - Quick Start Guide

**Last Updated:** January 27, 2025  
**Status:** ✅ Ready for Use

---

## 🚀 Quick Start

### For Developers

#### 1. Using MoodEntryView in Your Code

```swift
import SwiftUI

// In your view where you want to present mood entry:
struct YourView: View {
    @State private var showingMoodEntry = false
    let moodEntryViewModel: MoodEntryViewModel // Inject from AppDependencies
    
    var body: some View {
        Button("Log Mood") {
            showingMoodEntry = true
        }
        .sheet(isPresented: $showingMoodEntry) {
            MoodEntryView(
                viewModel: moodEntryViewModel,
                initialScore: 7
            )
            .onDisappear {
                if moodEntryViewModel.showSuccessMessage {
                    // Refresh your data here
                    Task { await refreshData() }
                }
            }
        }
    }
    
    func refreshData() async {
        // Your refresh logic
    }
}
```

#### 2. Accessing Dependencies

```swift
// From AppDependencies (already configured):
let deps = AppDependencies.build(authManager: authManager)
let moodEntryViewModel = deps.moodEntryViewModel

// Or create manually for testing:
let mockViewModel = MoodEntryViewModel(
    saveMoodProgressUseCase: MockSaveMoodProgressUseCase()
)
```

#### 3. Testing the Feature

```swift
// Run the app
// 1. Navigate to Summary tab
// 2. Tap on Mood card → Opens MoodDetailView
// 3. Tap FAB (Floating Action Button) → Opens MoodEntryView
// 4. Adjust mood slider (1-10)
// 5. Add optional notes
// 6. Tap "Log Mood"
// 7. Verify success alert
// 8. Verify data appears in MoodDetailView chart
```

---

## 📱 User Flow

```
Summary Screen
    ↓ (Tap Mood Card)
Mood Detail Screen
    ↓ (Tap FAB)
Mood Entry Screen
    ↓ (Adjust Slider + Add Notes)
    ↓ (Tap "Log Mood")
Success Alert
    ↓ (Tap "OK")
Back to Mood Detail (Refreshed)
```

---

## 🔧 Architecture Components

### 1. View Layer
- **`MoodEntryView.swift`** - UI for logging mood
  - Location: `Presentation/UI/Summary/MoodEntryView.swift`
  - Circular mood dial (1-10 scale)
  - Optional notes field
  - Real-time validation
  - Success/error feedback

### 2. ViewModel Layer
- **`MoodEntryViewModel.swift`** - Business logic
  - Location: `Presentation/ViewModels/MoodEntryViewModel.swift`
  - Properties: `moodScore`, `notes`, `isLoading`, `errorMessage`
  - Methods: `saveMoodEntry()`, `resetForm()`, `canSave`
  - Uses `@Observable` pattern

### 3. Domain Layer
- **`SaveMoodProgressUseCase.swift`** - Save logic
  - Location: `Domain/UseCases/SaveMoodProgressUseCase.swift`
  - Protocol + Implementation
  - Validation rules
  - Duplicate detection
  - **Uses Outbox Pattern for reliable sync**

### 4. Infrastructure Layer
- **`ProgressRepository`** - Local storage
  - Saves to SwiftData as `ProgressEntry` with type `.mood_score`
  - Automatically creates `OutboxEvent` for backend sync
  
- **`OutboxProcessorService`** - Background sync
  - Polls for pending events
  - Syncs to `/api/v1/mood` endpoint
  - Handles retry logic

---

## 🔌 Backend API

### Endpoint
```
POST /api/v1/mood
```

### Request
```json
{
  "mood_score": 7,
  "emotions": [],
  "notes": "Had a great workout today!",
  "logged_at": "2025-01-27T14:30:00Z"
}
```

### Response
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "mood_score": 7,
    "emotions": [],
    "notes": "Had a great workout today!",
    "logged_at": "2025-01-27T14:30:00Z",
    "created_at": "2025-01-27T14:30:00Z",
    "updated_at": "2025-01-27T14:30:00Z"
  }
}
```

---

## ✅ Validation Rules

### Mood Score
- **Range:** 1-10 (inclusive)
- **Type:** Integer
- **Required:** Yes
- **Default:** 7

### Notes
- **Max Length:** 500 characters
- **Required:** No
- **Default:** Empty string
- **Trimmed:** Leading/trailing whitespace removed

### Date
- **Format:** RFC3339 (ISO 8601)
- **Required:** Yes
- **Default:** Current date/time
- **Validation:** Cannot be in distant future

---

## 🧪 Testing Commands

```bash
# Run unit tests
xcodebuild test -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -scheme FitIQ -only-testing:FitIQTests/SaveMoodProgressUseCaseTests

# Run UI tests
xcodebuild test -scheme FitIQUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## 🐛 Troubleshooting

### Issue: Mood entry not saving

**Check:**
1. User is authenticated (`authManager.currentUserProfileID` is not nil)
2. Network connection (for backend sync)
3. SwiftData is initialized properly
4. Check console logs for errors

**Logs to look for:**
```
SaveMoodProgressUseCase: Saving mood score X for user Y
SaveMoodProgressUseCase: Successfully saved new mood progress with local ID: Z
OutboxProcessorService: Processing event [type: progressCreated]
OutboxProcessorService: Successfully synced event
```

### Issue: Duplicate entries

**This is expected behavior:**
- If you log the same mood score with same notes on the same day, it's considered a duplicate
- The system will skip creating a new entry but won't show an error
- Check logs for: "Skipping duplicate"

### Issue: Sync not happening

**Check:**
1. Outbox events exist: Query `SDOutboxEvent` in SwiftData
2. OutboxProcessor is running: Check background sync status
3. Backend API is reachable: Test with Postman/curl
4. JWT token is valid: Check token expiration

**Force sync:**
```swift
// In your debug menu:
await deps.outboxProcessorService.processPendingEvents()
```

---

## 🎨 UI Customization

### Change Primary Color
```swift
// In MoodEntryView.swift, line ~37:
private let primaryColor: Color = Color(hex: "#B58BEF") // Serenity Lavender
```

### Change Initial Score
```swift
// When initializing:
MoodEntryView(
    viewModel: moodEntryViewModel,
    initialScore: 5 // Default to middle of scale
)
```

### Change Slider Steps
```swift
// In MoodEntryView.swift, line ~104:
Slider(value: $selectedScore, in: 1...10, step: 1) // Change step to 0.5 for half-steps
```

---

## 📊 Monitoring

### Key Metrics to Track

1. **Save Success Rate**
   - Target: >99%
   - Alert if: <95%

2. **Sync Latency**
   - Target: <2 seconds
   - Alert if: >5 seconds

3. **Outbox Queue Size**
   - Target: <10 pending events
   - Alert if: >50 pending events

4. **User Engagement**
   - Daily active users logging mood
   - Average mood score
   - Percentage with notes

### Analytics Events

```swift
// Already logged automatically:
// - "mood_entry_viewed"
// - "mood_entry_saved"
// - "mood_entry_failed"
// - "mood_sync_completed"
```

---

## 🔐 Security Notes

### Data Privacy
- Mood data is stored locally in SwiftData (encrypted at rest by iOS)
- Backend sync uses JWT authentication
- Notes are not analyzed by AI (yet)
- User can delete mood entries at any time

### Permissions
- No additional iOS permissions required
- HealthKit integration (future) will require permission

---

## 🚧 Future Enhancements

### Planned Features
1. **Emotion Tags** - Multi-select emotion chips
2. **Date Picker** - Log mood for past dates
3. **Statistics** - Trends, distributions, insights
4. **HealthKit Sync** - Read HKStateOfMind (iOS 18+)
5. **AI Analysis** - Correlate mood with activity/sleep/nutrition

### API Roadmap
- `GET /api/v1/mood/statistics` - Already available, needs UI
- `GET /api/v1/mood/insights` - Planned
- `POST /api/v1/mood/batch` - Planned for bulk import

---

## 📚 Additional Resources

- **Full Integration Doc:** `docs/MOOD_INTEGRATION_SUMMARY.md`
- **Backend API Spec:** `docs/be-api-spec/swagger.yaml` (Lines 9316-9622)
- **Architecture Guide:** `.github/copilot-instructions.md`
- **Outbox Pattern:** Search "Outbox Pattern" in copilot-instructions.md

---

## 💬 Support

**Questions?** Ask in #ios-dev Slack channel  
**Bugs?** File a JIRA ticket with label `mood-tracking`  
**PRs?** Follow the existing patterns and add tests

---

**Happy Coding! 🎉**