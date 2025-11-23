# Mood Entry UX Redesign

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Status:** ✅ Implemented

---

## 📋 Overview

This document describes the redesigned mood entry UX that aligns with the backend API contract and simplifies the user experience while maintaining rich emotional tracking capabilities.

### Key Changes

1. **Simplified Data Model** - Removed complex valence, associations, and HealthKit-specific logic
2. **Backend API Alignment** - Uses `mood_score` (1-10), `emotions` array, and `notes`
3. **Improved UX** - Added emotion selection grid with visual feedback
4. **Color Consistency** - Uses Serenity Lavender (#B58BEF) for wellness/mood tracking

---

## 🎯 Design Goals

### 1. Backend API Compatibility

**Endpoint:** `POST /api/v1/mood`

**Request Body:**
```json
{
  "mood_score": 7,
  "emotions": ["happy", "energetic", "motivated"],
  "notes": "Had a great workout today, feeling energized!",
  "logged_at": "2024-01-15T14:30:00Z"
}
```

### 2. User Experience Principles

- **Simple & Intuitive** - Easy to log mood in under 30 seconds
- **Visual Feedback** - Circular progress dial, emoji, and color-coded score
- **Optional Depth** - Emotions and notes are optional for quick entries
- **Accessibility** - Clear labels, haptic feedback, and readable fonts

### 3. Color Profile Alignment

**Primary Color:** Serenity Lavender (#B58BEF)
- Used for wellness, mood tracking, meditation, and rest
- Conveys mindfulness and introspection
- Applied to: progress dial, selected emotions, CTA button

---

## 🎨 UI Components

### 1. Mood Score Selector (Circular Dial)

**Purpose:** Primary input for mood score (1-10)

**Design:**
```
┌─────────────────────────────┐
│  How are you feeling?       │
│                             │
│       ╱─────────╲           │
│      │    🤩     │          │
│      │           │          │
│      │     9     │          │
│      │           │          │
│      │ Excellent │          │
│       ╲─────────╱           │
│                             │
│   [━━━━━━━━━━━━━━━━━━━━]   │
│   Very Bad      Excellent   │
└─────────────────────────────┘
```

**Features:**
- Circular progress ring fills based on score (0% to 100%)
- Large emoji changes based on score range:
  - 1-2: 😢 "Very Bad"
  - 3-4: 🙁 "Below Average"
  - 5-6: 😐 "Neutral"
  - 7-8: 😊 "Good"
  - 9-10: 🤩 "Excellent"
- Numeric score in center (1-10)
- Descriptive text below score
- Slider control below for easy adjustment
- Haptic feedback on score change
- Smooth animations with spring effect

**Color Coding:**
- Progress ring: Serenity Lavender gradient
- Background ring: System gray (.systemGray5)
- Score number: Serenity Lavender

---

### 2. Emotions Grid

**Purpose:** Multi-select emotions from predefined list

**Design:**
```
┌─────────────────────────────────────┐
│ What emotions are you feeling?  3 selected │
│ Tap to select (optional)             │
│                                      │
│  ┌─────┐  ┌─────┐  ┌─────┐          │
│  │ 😊  │  │ 😢  │  │ 😰  │          │
│  │Happy│  │ Sad │  │Anxious│        │
│  └─────┘  └─────┘  └─────┘          │
│                                      │
│  ┌─────┐  ┌─────┐  ┌─────┐          │
│  │ 🍃  │  │ ⚡  │  │ 🔋  │          │
│  │Calm │  │Energetic│Tired│         │
│  └─────┘  └─────┘  └─────┘          │
│                                      │
│  ... (15 emotions total)             │
└─────────────────────────────────────┘
```

**Features:**
- 3-column grid layout (responsive)
- 15 predefined emotions (matches backend API)
- Each chip shows SF Symbol icon + label
- Multi-select (tap to toggle)
- Selected state: Lavender gradient background + white text
- Unselected state: Gray background (.systemGray6) + primary text
- Selection counter in header
- Haptic feedback on tap
- Shadow effect on selected chips

**Allowed Emotions:**
- happy, sad, anxious, calm, energetic
- tired, stressed, relaxed, angry, content
- frustrated, motivated, overwhelmed, peaceful, excited

**Emotion Icons (SF Symbols):**
| Emotion | Symbol | Visual |
|---------|--------|--------|
| happy | face.smiling.fill | 😊 |
| sad | cloud.rain.fill | ☁️ |
| anxious | tornado | 🌪️ |
| calm | leaf.fill | 🍃 |
| energetic | bolt.fill | ⚡ |
| tired | battery.0 | 🔋 |
| stressed | exclamationmark.triangle.fill | ⚠️ |
| relaxed | figure.mind.and.body | 🧘 |
| angry | flame.fill | 🔥 |
| content | checkmark.circle.fill | ✅ |
| frustrated | xmark.circle.fill | ❌ |
| motivated | star.fill | ⭐ |
| overwhelmed | square.stack.3d.up.fill | 📚 |
| peaceful | moon.stars.fill | 🌙 |
| excited | sparkles | ✨ |

---

### 3. Notes Section

**Purpose:** Optional text input for context

**Design:**
```
┌─────────────────────────────┐
│ Add a note (optional)       │
│                             │
│  ┌─────────────────────┐   │
│  │ What's on your mind?│   │
│  │                     │   │
│  │                     │   │
│  └─────────────────────┘   │
│              0/500 ─────┘   │
└─────────────────────────────┘
```

**Features:**
- TextEditor with placeholder text
- Gray background (.systemGray6)
- 500 character limit (matches backend API)
- Character counter (updates live)
- Red text if over limit
- Tap-to-dismiss keyboard
- ScrollView compatibility

---

### 4. Save Button

**Design:**
```
┌─────────────────────────────┐
│  ✓  Log Mood                │
└─────────────────────────────┘
```

**States:**
1. **Enabled:** Lavender gradient + shadow
2. **Disabled:** Gray gradient + no shadow
3. **Loading:** White spinner

**Validation:**
- Score: 1-10 (always valid from UI)
- Emotions: Must be from allowed list (validated)
- Notes: Max 500 characters

---

### 5. Error Display

**Design:**
```
┌─────────────────────────────┐
│ ⚠️ Error message here  [Dismiss] │
└─────────────────────────────┘
```

**Features:**
- Red background (.red.opacity(0.1))
- Warning icon
- Dismissable
- Auto-clears on retry

---

### 6. Success Confirmation

**Design:**
```
Alert: "Success"
Message: "Your mood has been logged successfully!"
Button: "OK" (dismisses view)
```

**Behavior:**
- Shows after successful save
- Automatically dismisses view on "OK"
- Resets form for next entry

---

## 📊 User Flow

### Primary Flow (Quick Entry)

```
1. Open Mood Entry View
   ↓
2. Adjust mood score slider (1-10)
   - See emoji + description update
   - Feel haptic feedback
   ↓
3. Tap "Log Mood"
   ↓
4. Success alert → Dismiss
```

**Time:** ~10 seconds

---

### Enhanced Flow (Detailed Entry)

```
1. Open Mood Entry View
   ↓
2. Adjust mood score slider (1-10)
   ↓
3. Select emotions (optional)
   - Tap chips to toggle
   - See selection count update
   ↓
4. Add notes (optional)
   - Type context/thoughts
   - Monitor character count
   ↓
5. Tap "Log Mood"
   ↓
6. Success alert → Dismiss
```

**Time:** ~30-60 seconds

---

## 🏗️ Architecture

### Data Flow

```
View (MoodEntryView)
    ↓ user interaction
ViewModel (MoodEntryViewModel)
    ↓ validate & call
Use Case (SaveMoodProgressUseCase)
    ↓ validate & save
Repository (ProgressRepository)
    ↓ persist locally
SwiftData (SDProgressEntry)
    ↓ trigger sync
Outbox Pattern
    ↓ sync to backend
Backend API (/api/v1/mood)
```

### Domain Model (MoodEntry)

**Simplified Structure:**
```swift
struct MoodEntry {
    let id: UUID
    let userID: String
    let date: Date
    let score: Int                  // 1-10
    let emotions: [String]          // Array of emotion strings
    let notes: String?              // Optional, max 500 chars
    let createdAt: Date
    let updatedAt: Date?
    let backendID: String?
    let syncStatus: SyncStatus      // .pending, .synced, .failed
}
```

**Key Changes from Previous Version:**
- ❌ Removed: `valence: Double`
- ❌ Removed: `labels: [MoodLabel]` (complex enum)
- ❌ Removed: `associations: [MoodAssociation]`
- ❌ Removed: `sourceType: MoodSourceType`
- ❌ Removed: HealthKit conversion methods
- ✅ Added: `emotions: [String]` (simple strings)

---

### ViewModel (MoodEntryViewModel)

**State:**
```swift
@Observable
final class MoodEntryViewModel {
    var moodScore: Int = 5              // Default to neutral
    var selectedEmotions: Set<String> = []
    var notes: String = ""
    var selectedDate: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?
    var showSuccessMessage: Bool = false
}
```

**Methods:**
- `saveMoodEntry()` - Validates and saves entry
- `toggleEmotion(_ emotion: String)` - Adds/removes emotion
- `isEmotionSelected(_ emotion: String)` - Checks selection state
- `resetForm()` - Clears all inputs
- `clearError()` - Dismisses error message

**Computed Properties:**
- `moodDescription` - "Very Bad" to "Excellent"
- `moodEmoji` - 😢 to 🤩
- `selectedEmotionsCount` - Number of selected emotions
- `selectedEmotionsDisplay` - "Happy, Energetic, Motivated"
- `canSave` - Validation check

---

## 🔌 Backend Integration

### API Contract

**Endpoint:** `POST /api/v1/mood`

**Headers:**
```
X-API-Key: <api_key>
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "mood_score": 7,
  "emotions": ["happy", "energetic", "motivated"],
  "notes": "Had a great workout today, feeling energized!",
  "logged_at": "2024-01-15T14:30:00Z"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "mood_score": 7,
    "emotions": ["happy", "energetic", "motivated"],
    "notes": "Had a great workout today, feeling energized!",
    "logged_at": "2024-01-15T14:30:00Z",
    "created_at": "2024-01-15T14:30:05Z",
    "updated_at": "2024-01-15T14:30:05Z"
  },
  "error": null
}
```

**Error Response (400 Bad Request):**
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "INVALID_MOOD_SCORE",
    "message": "Mood score must be between 1 and 10"
  }
}
```

---

### Sync Strategy (Outbox Pattern)

**Local Save:**
1. User taps "Log Mood"
2. ViewModel validates input
3. Use case creates `ProgressEntry` (type: `.moodScore`, syncStatus: `.pending`)
4. Repository saves to SwiftData
5. Repository creates `SDOutboxEvent` automatically
6. Success feedback shown to user

**Background Sync:**
1. `OutboxProcessorService` polls for pending events
2. Finds mood entry outbox event
3. Calls backend API with retry logic
4. Marks event as `.synced` or `.failed`
5. Updates `ProgressEntry.syncStatus` and `backendID`

**Failure Handling:**
- Automatic retry with exponential backoff
- Error message shown if immediate sync fails
- Background sync continues until successful
- User can view sync status in app

---

## 🎯 Validation Rules

### Score Validation
- **Required:** Yes
- **Range:** 1-10 (integer)
- **UI Enforced:** Yes (slider with step: 1)

### Emotions Validation
- **Required:** No (optional)
- **Allowed Values:** 15 predefined emotions (see list above)
- **Max Count:** No limit (but UI shows 15 options)
- **Case Sensitivity:** Lowercased before save

### Notes Validation
- **Required:** No (optional)
- **Max Length:** 500 characters
- **UI Indicator:** Character counter with red text if over limit
- **Trimming:** Leading/trailing whitespace removed

---

## 📱 Accessibility

### VoiceOver Support
- Mood score slider: "Mood score, 7 out of 10, Good"
- Emotion chips: "Happy, button, selected" / "Sad, button, not selected"
- Notes field: "Add a note, text editor, optional"
- Save button: "Log Mood, button, enabled"

### Haptic Feedback
- Score adjustment: Light impact on each step
- Emotion selection: Soft impact on toggle
- Save success: Success notification
- Error: Error notification

### Dynamic Type
- All text scales with system font size
- Minimum scale factor on emotion labels (0.8)
- ScrollView for overflow content

### Color Contrast
- Meets WCAG AA standards
- High contrast mode compatible
- Dark mode supported (Serenity Lavender + dark background)

---

## 🧪 Testing

### Unit Tests (ViewModel)
- `testSaveMoodEntry_ValidInput_CallsUseCase`
- `testSaveMoodEntry_InvalidScore_ShowsError`
- `testSaveMoodEntry_NotesTooLong_ShowsError`
- `testToggleEmotion_AddsWhenNotSelected`
- `testToggleEmotion_RemovesWhenSelected`
- `testCanSave_ValidInput_ReturnsTrue`
- `testCanSave_InvalidInput_ReturnsFalse`

### Integration Tests (Use Case)
- `testExecute_ValidMoodEntry_SavesLocally`
- `testExecute_DuplicateEntry_SkipsSave`
- `testExecute_UpdatedEntry_UpdatesExisting`
- `testExecute_InvalidEmotion_ThrowsError`

### UI Tests
- `testMoodEntryFlow_QuickEntry_Success`
- `testMoodEntryFlow_DetailedEntry_Success`
- `testEmotionSelection_MultiSelect_UpdatesCount`
- `testNotesInput_OverLimit_ShowsError`

---

## 🚀 Future Enhancements

### Phase 2 (Future)
- [ ] Mood history chart (trend over time)
- [ ] Emotion frequency analytics
- [ ] Mood journal view (calendar + entries)
- [ ] Custom emotion tags (user-defined)
- [ ] Mood reminders (push notifications)
- [ ] Share mood summary (social features)

### Phase 3 (AI Integration)
- [ ] AI mood insights (patterns, triggers)
- [ ] Personalized wellness suggestions
- [ ] Mood prediction based on activity
- [ ] Correlation with sleep/exercise/nutrition

---

## 📚 References

### Design System
- [COLOR_PROFILE.md](./COLOR_PROFILE.md) - Serenity Lavender for wellness
- SF Symbols 5.0+ for emotion icons
- iOS Human Interface Guidelines - Mood tracking patterns

### API Documentation
- [Backend API Spec](../be-api-spec/swagger.yaml) - `/api/v1/mood` endpoints
- [Integration Handoff](../IOS_INTEGRATION_HANDOFF.md) - Progress tracking patterns

### Architecture
- [Copilot Instructions](../../.github/copilot-instructions.md) - Hexagonal architecture
- [Outbox Pattern](../architecture/OUTBOX_PATTERN.md) - Reliable sync strategy

---

## ✅ Checklist

Before considering this feature complete:

- [x] Domain model updated (MoodEntry simplified)
- [x] Use case updated (SaveMoodProgressUseCase with emotions)
- [x] ViewModel updated (MoodEntryViewModel with emotion selection)
- [x] View redesigned (MoodEntryView with emotion grid)
- [x] Emotion chips component created
- [x] Color profile applied (Serenity Lavender)
- [x] Validation implemented (score, emotions, notes)
- [x] Outbox pattern integrated
- [x] Error handling added
- [x] Success feedback added
- [ ] Unit tests written
- [ ] Integration tests written
- [ ] UI tests written
- [ ] Accessibility audit completed
- [ ] UX review completed
- [ ] Backend API integration tested
- [ ] Documentation updated

---

**Status:** ✅ UX Implementation Complete  
**Next Steps:** Testing & Validation  
**Owner:** AI Assistant  
**Reviewer:** Product/UX Team