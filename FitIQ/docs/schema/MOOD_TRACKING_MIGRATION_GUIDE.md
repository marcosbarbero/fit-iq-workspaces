# Mood Tracking Migration Guide

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Purpose:** Guide for migrating from old to new mood tracking implementation

---

## 📋 Overview

The FitIQ iOS app now has **two mood tracking implementations**:

1. **Old Implementation** (Deprecated) - Complex HealthKit-based system
2. **New Implementation** (Active) - Simplified backend-aligned system

This guide explains the differences and how to migrate existing code.

---

## 🔄 Implementation Comparison

### Old Implementation (⚠️ DEPRECATED)

**Files:**
- `Domain/UseCases/Mood/SaveMoodUseCase.swift`
- `Domain/Entities/Mood/MoodTranslationUtility.swift`
- `Domain/Entities/Mood/MoodLabel.swift` (32+ labels)
- `Domain/Entities/Mood/MoodAssociation.swift` (22+ associations)
- `Domain/Entities/Mood/MoodSourceType.swift`

**Data Structure:**
```swift
struct MoodEntry {
    let score: Int                      // 1-10
    let valence: Double                 // -1.0 to +1.0
    let labels: [MoodLabel]             // 32+ enum options
    let associations: [MoodAssociation] // 22+ enum options
    let sourceType: MoodSourceType      // .userEntry, .healthKit, .backend
}
```

**Use Case:**
```swift
protocol SaveMoodUseCase {
    func execute(
        score: Int,
        labels: [MoodLabel]?,
        associations: [MoodAssociation]?,
        notes: String?,
        date: Date
    ) async throws -> UUID
}
```

**Issues:**
- ❌ Not compatible with backend API
- ❌ Over-engineered (HealthKit integration unused)
- ❌ Complex valence/label calculations
- ❌ Too many options (overwhelming users)

---

### New Implementation (✅ ACTIVE)

**Files:**
- `Domain/UseCases/SaveMoodProgressUseCase.swift`
- `Domain/Entities/Mood/MoodEntry.swift` (simplified)
- `Presentation/ViewModels/MoodEntryViewModel.swift`
- `Presentation/UI/Summary/MoodEntryView.swift`

**Data Structure:**
```swift
struct MoodEntry {
    let score: Int              // 1-10
    let emotions: [String]      // Array of emotion strings
    let notes: String?          // Max 500 chars
}
```

**Use Case:**
```swift
protocol SaveMoodProgressUseCase {
    func execute(
        score: Int,
        emotions: [String],
        notes: String?,
        date: Date
    ) async throws -> UUID
}
```

**Benefits:**
- ✅ 100% backend API compatible
- ✅ Simplified data model
- ✅ Rich emotion selection (15 options)
- ✅ Better UX with visual feedback

---

## 📊 Data Model Migration

### Field Mapping

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `score: Int` | `score: Int` | ✅ Unchanged (1-10) |
| `valence: Double` | ❌ Removed | Not supported by backend |
| `labels: [MoodLabel]` | `emotions: [String]` | Simplified to string array |
| `associations: [MoodAssociation]` | ❌ Removed | Not supported by backend |
| `sourceType: MoodSourceType` | ❌ Removed | Not needed |
| `notes: String?` | `notes: String?` | ✅ Unchanged |

### Emotion Mapping

Old labels (32 options) → New emotions (15 options):

| Old MoodLabel | New Emotion | Status |
|---------------|-------------|--------|
| `.happy` | `"happy"` | ✅ Mapped |
| `.sad` | `"sad"` | ✅ Mapped |
| `.anxious` | `"anxious"` | ✅ Mapped |
| `.calm` | `"calm"` | ✅ Mapped |
| `.confident` | `"content"` | ✅ Similar |
| `.excited` | `"excited"` | ✅ Mapped |
| `.stressed` | `"stressed"` | ✅ Mapped |
| `.relaxed` | `"relaxed"` | ✅ Mapped |
| `.angry` | `"angry"` | ✅ Mapped |
| `.frustrated` | `"frustrated"` | ✅ Mapped |
| `.overwhelmed` | `"overwhelmed"` | ✅ Mapped |
| `.peaceful` | `"peaceful"` | ✅ Mapped |
| `.drained` | `"tired"` | ✅ Similar |
| `.passionate` | `"energetic"` | ✅ Similar |
| `.hopeful` | `"motivated"` | ✅ Similar |
| Others (17+) | ❌ Removed | Not in backend API |

---

## 🔧 Code Migration Examples

### Example 1: Creating a Mood Entry

#### Old Way (Deprecated)
```swift
let entry = MoodTranslationUtility.createMoodEntry(
    score: 7,
    notes: "Feeling great!",
    userID: userID,
    date: Date()
)
// Returns: MoodEntry with valence, labels, associations auto-calculated
```

#### New Way (Recommended)
```swift
let localID = try await saveMoodProgressUseCase.execute(
    score: 7,
    emotions: ["happy", "energetic", "motivated"],
    notes: "Feeling great!",
    date: Date()
)
// Returns: UUID of local entry (syncs to backend automatically)
```

---

### Example 2: Saving from ViewModel

#### Old Way (Deprecated)
```swift
class OldMoodViewModel {
    func saveMood() async {
        let labels: [MoodLabel] = [.happy, .confident, .excited]
        let associations: [MoodAssociation] = [.exercise, .friends]
        
        try await saveMoodUseCase.execute(
            score: moodScore,
            labels: labels,
            associations: associations,
            notes: notes,
            date: Date()
        )
    }
}
```

#### New Way (Recommended)
```swift
@Observable
final class MoodEntryViewModel {
    var moodScore: Int = 5
    var selectedEmotions: Set<String> = []
    var notes: String = ""
    
    func saveMoodEntry() async {
        let emotionsArray = Array(selectedEmotions)
        
        try await saveMoodProgressUseCase.execute(
            score: moodScore,
            emotions: emotionsArray,
            notes: notes,
            date: Date()
        )
    }
}
```

---

### Example 3: Validating Emotions

#### Old Way (Deprecated)
```swift
let labels: [MoodLabel] = [.happy, .confident]
// Enum enforces valid options at compile time
```

#### New Way (Recommended)
```swift
let emotions = ["happy", "energetic", "motivated"]

// Runtime validation
for emotion in emotions {
    guard MoodEmotion.allEmotions.contains(emotion.lowercased()) else {
        throw SaveMoodProgressError.invalidEmotion(emotion)
    }
}
```

---

## 🚀 Migration Steps

### For Developers

1. **Identify Usage**
   - Search for `SaveMoodUseCase` in your code
   - Search for `MoodTranslationUtility`
   - Search for `MoodLabel`, `MoodAssociation`

2. **Replace with New Implementation**
   - Replace `SaveMoodUseCase` with `SaveMoodProgressUseCase`
   - Replace `MoodLabel` enum with `String` from allowed list
   - Remove `MoodAssociation` usage
   - Remove `valence` calculations

3. **Update UI**
   - Use `MoodEntryView` for mood logging
   - Use `MoodEntryViewModel` for state management
   - Implement emotion selection (see examples)

4. **Test**
   - Verify backend sync works
   - Test emotion validation
   - Test notes character limit (500)

---

### For Existing Data

**Good News:** No migration needed!

- Old mood entries are stored in `SDProgressEntry` (type: `.moodScore`)
- New mood entries also use `SDProgressEntry` (type: `.moodScore`)
- Both use the same underlying storage
- Emotions are temporarily encoded in `notes` metadata

**Future:** We'll add a dedicated `emotions` field to `SDProgressEntry` schema.

---

## 📚 File Status Reference

### Deprecated Files (⚠️ Keep for Backward Compatibility)

| File | Status | Action |
|------|--------|--------|
| `SaveMoodUseCase.swift` | Deprecated | Keep, but don't use for new code |
| `MoodTranslationUtility.swift` | Deprecated | Keep, marked with warnings |
| `MoodLabel.swift` | Deprecated | Keep, used by old code |
| `MoodAssociation.swift` | Deprecated | Keep, used by old code |
| `MoodSourceType.swift` | Deprecated | Keep, used by old code |

### Active Files (✅ Use These)

| File | Status | Purpose |
|------|--------|---------|
| `SaveMoodProgressUseCase.swift` | **Active** | Primary mood saving use case |
| `MoodEntry.swift` | **Active** | Simplified domain model |
| `MoodEntryViewModel.swift` | **Active** | ViewModel for mood entry |
| `MoodEntryView.swift` | **Active** | UI for mood logging |

---

## 🎯 Allowed Emotions Reference

The new implementation supports **15 predefined emotions** matching the backend API:

```swift
enum MoodEmotion {
    static let allEmotions: Set<String> = [
        "happy",
        "sad",
        "anxious",
        "calm",
        "energetic",
        "tired",
        "stressed",
        "relaxed",
        "angry",
        "content",
        "frustrated",
        "motivated",
        "overwhelmed",
        "peaceful",
        "excited"
    ]
}
```

**Validation:**
```swift
// Valid
let emotions = ["happy", "energetic", "motivated"]

// Invalid (throws error)
let emotions = ["joyful"] // Not in allowed list
```

---

## ⚠️ Common Pitfalls

### Pitfall 1: Using Old Enums
```swift
// ❌ Wrong - Old implementation
let labels: [MoodLabel] = [.happy, .confident]

// ✅ Correct - New implementation
let emotions: [String] = ["happy", "content"]
```

### Pitfall 2: Calculating Valence
```swift
// ❌ Wrong - Valence not supported
let valence = MoodTranslationUtility.scoreToValence(7)

// ✅ Correct - Just use score
let score = 7 // That's it!
```

### Pitfall 3: Using Associations
```swift
// ❌ Wrong - Associations not supported
let associations: [MoodAssociation] = [.exercise, .friends]

// ✅ Correct - Use notes instead
let notes = "Had a great workout with friends!"
```

### Pitfall 4: Wrong Use Case
```swift
// ❌ Wrong - Deprecated use case
try await saveMoodUseCase.execute(...)

// ✅ Correct - New use case
try await saveMoodProgressUseCase.execute(...)
```

---

## 🧪 Testing

### Unit Tests

**Old Implementation:**
```swift
func testSaveMood_WithLabels_Success() {
    let labels: [MoodLabel] = [.happy, .confident]
    try await saveMoodUseCase.execute(
        score: 7,
        labels: labels,
        associations: nil,
        notes: nil,
        date: Date()
    )
}
```

**New Implementation:**
```swift
func testSaveMoodProgress_WithEmotions_Success() {
    let emotions = ["happy", "content"]
    try await saveMoodProgressUseCase.execute(
        score: 7,
        emotions: emotions,
        notes: nil,
        date: Date()
    )
}
```

---

## 📞 Support

### Questions?

- **Architecture:** Review [MOOD_ENTRY_REDESIGN.md](./docs/ux/MOOD_ENTRY_REDESIGN.md)
- **API Contract:** Check [swagger.yaml](./docs/be-api-spec/swagger.yaml) → `/api/v1/mood`
- **Code Examples:** See [MOOD_ENTRY_QUICK_REF.md](./docs/ux/MOOD_ENTRY_QUICK_REF.md)

### Deprecation Timeline

| Phase | Date | Action |
|-------|------|--------|
| **Phase 1** | 2025-01-27 | ✅ New implementation active, old marked deprecated |
| **Phase 2** | 2025-02-15 | Remove old UI views (MoodDetailView, MoodLogEntryRow) |
| **Phase 3** | 2025-03-01 | Remove deprecated files entirely |

---

## ✅ Checklist

Before considering migration complete:

- [ ] All `SaveMoodUseCase` calls replaced with `SaveMoodProgressUseCase`
- [ ] All `MoodLabel` usages replaced with emotion strings
- [ ] All `MoodAssociation` usages removed
- [ ] All `valence` calculations removed
- [ ] UI uses `MoodEntryView` instead of old views
- [ ] Tests updated to use new implementation
- [ ] Backend sync verified end-to-end
- [ ] No compilation errors
- [ ] No runtime crashes

---

**Status:** ✅ Migration Guide Complete  
**Last Updated:** 2025-01-27  
**Owner:** AI Assistant