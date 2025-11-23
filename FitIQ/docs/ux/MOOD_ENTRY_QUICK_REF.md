# Mood Entry Quick Reference Card

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Purpose:** Quick reference for implementing mood entry feature

---

## 🎯 TL;DR

**What:** Mood tracking with 1-10 score + emotion selection + notes  
**Color:** Serenity Lavender (#B58BEF)  
**API:** POST `/api/v1/mood`  
**Time:** ~10-30 seconds to complete

---

## 📦 Files Changed

```
Domain/
├── Entities/Mood/MoodEntry.swift                    ✅ Simplified
└── UseCases/SaveMoodProgressUseCase.swift           ✅ Added emotions param

Presentation/
├── ViewModels/MoodEntryViewModel.swift              ✅ Added emotion state
└── UI/Summary/MoodEntryView.swift                   ✅ Full redesign
```

---

## 🔌 API Contract

### Request
```json
POST /api/v1/mood
{
  "mood_score": 7,
  "emotions": ["happy", "energetic", "motivated"],
  "notes": "Had a great workout today!",
  "logged_at": "2025-01-27T14:30:00Z"
}
```

### Allowed Emotions (15 total)
```
happy, sad, anxious, calm, energetic,
tired, stressed, relaxed, angry, content,
frustrated, motivated, overwhelmed, peaceful, excited
```

### Validation Rules
- `mood_score`: 1-10 (required)
- `emotions`: Array of allowed emotions (optional)
- `notes`: Max 500 chars (optional)
- `logged_at`: RFC3339 timestamp (required)

---

## 💻 Code Snippets

### 1. Domain Model
```swift
struct MoodEntry {
    let id: UUID
    let userID: String
    let date: Date
    let score: Int              // 1-10
    let emotions: [String]      // ["happy", "energetic"]
    let notes: String?          // Max 500 chars
    let backendID: String?
    let syncStatus: SyncStatus  // .pending, .synced, .failed
}
```

### 2. ViewModel State
```swift
@Observable
final class MoodEntryViewModel {
    var moodScore: Int = 5
    var selectedEmotions: Set<String> = []
    var notes: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    func toggleEmotion(_ emotion: String) { /* ... */ }
    func saveMoodEntry() async { /* ... */ }
}
```

### 3. Use Case Call
```swift
let localID = try await saveMoodProgressUseCase.execute(
    score: 7,
    emotions: ["happy", "energetic", "motivated"],
    notes: "Had a great workout today!",
    date: Date()
)
```

### 4. View Binding
```swift
// Score slider
Slider(value: $selectedScore, in: 1...10, step: 1)
    .tint(primaryColor)
    .onChange(of: selectedScore) { oldValue, newValue in
        viewModel.moodScore = Int(round(newValue))
    }

// Emotion chip
Button {
    viewModel.toggleEmotion("happy")
} label: {
    EmotionChip(
        emotion: "happy",
        isSelected: viewModel.isEmotionSelected("happy"),
        primaryColor: Color(hex: "#B58BEF")
    )
}

// Notes field
TextEditor(text: $viewModel.notes)
    .frame(minHeight: 100)

// Save button
Button("Log Mood") {
    Task { await viewModel.saveMoodEntry() }
}
.disabled(!viewModel.canSave)
```

---

## 🎨 UI Components

### Circular Progress Dial
```
Size: 240x240pt
Ring width: 12pt
Color: #B58BEF (gradient)
Animation: Spring (0.3s)
```

### Emotion Grid
```
Layout: 3 columns (LazyVGrid)
Spacing: 10pt
Chips: Icon (24pt) + Label (caption2)
Selected: Lavender gradient + shadow
Unselected: Gray background
```

### Notes Field
```
Min height: 100pt
Max chars: 500
Background: .systemGray6
Placeholder: "What's on your mind?"
Counter: "{count}/500" (red if over)
```

### Save Button
```
Height: 48pt
Color: Lavender gradient (enabled) / Gray (disabled)
Shadow: 8pt radius (enabled only)
Icon: checkmark.circle.fill
```

---

## 🎯 Score to Emoji Mapping

| Score | Emoji | Label |
|-------|-------|-------|
| 1-2 | 😢 | Very Bad |
| 3-4 | 🙁 | Below Average |
| 5-6 | 😐 | Neutral |
| 7-8 | 😊 | Good |
| 9-10 | 🤩 | Excellent |

---

## 🎨 Color Specs

```swift
// Primary (Serenity Lavender)
Color(hex: "#B58BEF")

// Backgrounds
Color(.systemGray5)  // Unselected chip
Color(.systemGray6)  // Notes field

// Text
Color.primary        // Labels
Color.secondary      // Supporting text

// States
Color.white          // Selected chip text
Color.red            // Error text
```

---

## 🔊 Haptic Feedback

```swift
// Score change
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// Emotion toggle
UIImpactFeedbackGenerator(style: .soft).impactOccurred()

// Save success
UINotificationFeedbackGenerator().notificationOccurred(.success)

// Save error
UINotificationFeedbackGenerator().notificationOccurred(.error)
```

---

## ✨ Animations

```swift
// Progress ring
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: score)

// Emoji change
.animation(.spring(response: 0.3), value: scoreInt)

// Chip selection
.animation(.easeInOut(duration: 0.2), value: isSelected)

// Button press
.scaleEffect(isPressed ? 0.98 : 1.0)
```

---

## ♿ Accessibility

### VoiceOver Labels
```swift
// Slider
.accessibilityLabel("Mood score")
.accessibilityValue("\(score) out of 10, \(moodDescription)")

// Emotion chip
.accessibilityLabel("\(emotion)")
.accessibilityHint("Double-tap to \(isSelected ? "deselect" : "select")")
.accessibilityAddTraits(isSelected ? .isSelected : [])
```

### Dynamic Type
```swift
// Auto-scaling
Text("Happy").font(.caption2)  // Auto-scales

// Manual constraints
Text("Happy")
    .font(.caption2)
    .minimumScaleFactor(0.8)
    .lineLimit(1)
```

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] `testToggleEmotion_AddsWhenNotSelected`
- [ ] `testToggleEmotion_RemovesWhenSelected`
- [ ] `testSaveMoodEntry_ValidInput_CallsUseCase`
- [ ] `testSaveMoodEntry_InvalidEmotion_ShowsError`
- [ ] `testSaveMoodEntry_NotesTooLong_ShowsError`

### UI Tests
- [ ] Score slider adjusts from 1-10
- [ ] Emoji updates based on score
- [ ] Emotion chips toggle on tap
- [ ] Notes field enforces 500 char limit
- [ ] Save button disabled when invalid
- [ ] Success alert appears after save

### Integration Tests
- [ ] Mood entry syncs to backend
- [ ] Outbox pattern creates sync event
- [ ] Failed sync retries automatically

---

## 🐛 Common Issues

### Issue 1: Emotions not validating
**Cause:** Emotion string not lowercase  
**Fix:** `emotion.lowercased()` before validation

### Issue 2: Character counter not updating
**Cause:** Notes binding not propagating  
**Fix:** Use `$viewModel.notes` not `viewModel.notes`

### Issue 3: Slider jumping on first touch
**Cause:** Initial value not synced with ViewModel  
**Fix:** Set `_selectedScore = State(initialValue: Double(viewModel.moodScore))`

### Issue 4: Emotion grid not responsive
**Cause:** Fixed width chips  
**Fix:** Use `GridItem(.flexible())` not `GridItem(.fixed(...))`

---

## 📊 Performance Tips

1. **LazyVGrid** - Only renders visible emotions (not all 15)
2. **Set<String>** - O(1) emotion lookup (not Array)
3. **Debounce** - Don't validate notes on every keystroke
4. **Haptics** - Reuse generators (don't create new each time)

---

## 🔗 Full Documentation

- **Complete Spec:** [MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md)
- **Changelog:** [MOOD_ENTRY_CHANGELOG.md](./MOOD_ENTRY_CHANGELOG.md)
- **Visual Guide:** [MOOD_ENTRY_VISUAL_GUIDE.md](./MOOD_ENTRY_VISUAL_GUIDE.md)
- **API Spec:** [../be-api-spec/swagger.yaml](../be-api-spec/swagger.yaml) (search `/api/v1/mood`)

---

## 🚀 Implementation Steps

1. ✅ Update `MoodEntry.swift` (remove valence, add emotions)
2. ✅ Update `SaveMoodProgressUseCase.swift` (add emotions param)
3. ✅ Update `MoodEntryViewModel.swift` (add emotion state)
4. ✅ Redesign `MoodEntryView.swift` (add emotion grid)
5. ✅ Create `EmotionChip` component
6. ✅ Apply Serenity Lavender color theme
7. ✅ Add haptic feedback
8. ✅ Add accessibility labels
9. ⏳ Write unit tests
10. ⏳ Write UI tests
11. ⏳ Test backend integration

---

## 💡 Pro Tips

- **Quick entry:** Most users will only set score (10s)
- **Detailed entry:** Power users will use emotions + notes (30-60s)
- **Color consistency:** Use Serenity Lavender (#B58BEF) everywhere
- **Animation timing:** Keep under 0.3s for responsiveness
- **Emotion limit:** Don't enforce max selections (let users pick many)
- **Notes optional:** Never require notes (friction point)

---

**Status:** ✅ Ready for Implementation  
**Complexity:** Medium (3-5 days)  
**Priority:** High (Backend API alignment)