# Mood Tracking Redesign - Summary

**Date:** 2025-01-15  
**Status:** Complete  
**Impact:** Major UX and domain model changes

---

## What Changed

### 1. Domain Model - Sunlight Metaphor

**Before:** 7-level clinical scale (Very Unpleasant → Very Pleasant)  
**After:** 5-level sunlight metaphor (Dawn → Sunrise → Noon → Sunset → Twilight)

**Why the change:**
- More human and less clinical
- Uses natural cycles everyone understands
- No judgment (twilight isn't "bad")
- Aligns with Lume's warm, cozy philosophy
- Differentiates from Mindfulness app's darker aesthetic

### 2. Mood Types Redesign

```swift
// OLD: Integer-based clinical scale
enum MoodKind: Int {
    case veryUnpleasant = 1
    case unpleasant = 2
    case slightlyUnpleasant = 3
    case neutral = 4
    case slightlyPleasant = 5
    case pleasant = 6
    case veryPleasant = 7
}

// NEW: String-based sunlight metaphor
enum MoodKind: String {
    case dawn = "dawn"           // Just getting started
    case sunrise = "sunrise"     // Things are looking up
    case noon = "noon"           // Feeling bright
    case sunset = "sunset"       // Winding down peacefully
    case twilight = "twilight"   // Ready for rest
}
```

### 3. Visual Design - Warm Gradients

**Before:** Dark, moody backgrounds (clinical feel)  
**After:** Warm, branded gradients

Each mood has a unique gradient from Lume's color palette:

- **Dawn:** Soft pink → Lavender
- **Sunrise:** Warm peach → Coral
- **Noon:** Bright yellow → Warm sand
- **Sunset:** Warm rose → Soft purple
- **Twilight:** Lavender → Soft blue

### 4. Data Model - Gratitude Over Factors

**Before:**
```swift
struct MoodEntry {
    let factors: [MoodFactor]  // Clinical checkboxes
}
```

**After:**
```swift
struct MoodEntry {
    let gratitude: String?     // Positive reflection
}
```

**Why:** Gratitude builds positive psychology habits; clinical factors feel like homework.

### 5. User Experience - Quick OR Deep

**Two Interaction Modes:**

1. **Quick Check-In (3 seconds)**
   - Tap mood button from main screen
   - Saves immediately
   - Perfect for busy moments

2. **Deep Reflection (2-5 minutes)**
   - Full-screen immersive view
   - Add context note
   - Share gratitude
   - Prompted reflection questions

**Design principle:** No pressure. Users choose their level of engagement.

### 6. Simplified Architecture

**Before:** Use cases layer with separate save/fetch operations  
**After:** Direct repository access with entity-based API

```swift
// OLD
func save(mood: MoodKind, note: String?, date: Date, factors: [MoodFactor]) async throws -> MoodEntry

// NEW
func save(_ entry: MoodEntry) async throws
```

**Benefits:**
- Simpler ViewModel logic
- More flexible (pass complete entity)
- Easier to test
- Follows repository pattern properly

---

## Files Changed

### Domain Layer
- `lume/Domain/Entities/MoodEntry.swift` - Complete redesign with sunlight metaphor
- `lume/Domain/Ports/MoodRepositoryProtocol.swift` - Simplified API

### Data Layer
- `lume/Data/Persistence/SDMoodEntry.swift` - Updated to store gratitude instead of factors
- `lume/Data/Repositories/MoodRepository.swift` - Simplified implementation

### Presentation Layer
- `lume/Presentation/Features/Mood/MoodTrackingView.swift` - Complete redesign
- `lume/Presentation/ViewModels/MoodViewModel.swift` - Simplified with direct repository access

### Infrastructure
- `lume/DI/AppDependencies.swift` - Removed use case layer for mood tracking

### Documentation
- `lume/DESIGN_PHILOSOPHY.md` - NEW: Core design principles
- `lume/MOOD_REDESIGN_SUMMARY.md` - NEW: This file

---

## Design Principles Applied

From `DESIGN_PHILOSOPHY.md`:

✅ **Warm, not clinical** - Sunlight metaphor vs numeric scales  
✅ **Simple, not simplistic** - 5 levels vs overwhelming 7  
✅ **Human, not mechanical** - "How's your day?" vs "Rate your mood"  
✅ **No pressure** - Quick tap or deep reflection, user chooses  
✅ **Celebration** - Gratitude focus builds positive habits  

---

## Migration Notes

### Breaking Changes

1. **MoodKind rawValue type changed:** `Int` → `String`
2. **MoodEntry.factors removed:** Replaced with `gratitude: String?`
3. **Repository API simplified:** Now accepts `MoodEntry` entity directly
4. **Use cases removed:** ViewModels now use repositories directly

### Database Migration Required

SwiftData will need to migrate existing mood entries:

- Convert integer mood values to string equivalents
- Map old mood scales to new sunlight metaphor
- Drop factors array, add gratitude field

**Mapping:**
```
1-2: veryUnpleasant/unpleasant → dawn
3: slightlyUnpleasant → sunrise
4: neutral → noon
5-6: slightlyPleasant/pleasant → sunset
7: veryPleasant → twilight
```

Note: This is a simplification. Adjust based on semantic meaning if needed.

---

## Testing Checklist

- [ ] Build succeeds with no errors
- [ ] Quick mood selection works
- [ ] Full-screen mood entry opens
- [ ] All 5 mood types display correct gradients
- [ ] Note field saves and displays
- [ ] Gratitude field saves and displays
- [ ] Mood history shows all entries
- [ ] Today's mood card appears when entry exists
- [ ] Empty state shows for new users
- [ ] Colors meet WCAG AA contrast standards
- [ ] Animations are smooth (60fps)
- [ ] Offline mode works (no backend needed)

---

## User Impact

### Positive Changes

✨ **More intuitive** - "Noon" is easier to understand than "5/7"  
✨ **More beautiful** - Warm gradients vs dark backgrounds  
✨ **More positive** - Gratitude focus vs clinical factors  
✨ **More flexible** - Quick tap or deep reflection  
✨ **More personal** - Natural metaphors feel less judgmental  

### Considerations

⚠️ **Learning curve** - Users must understand sunlight metaphor  
⚠️ **Migration** - Existing data needs thoughtful conversion  
⚠️ **Differentiation** - Must clearly communicate we're not Mindfulness app  

---

## Next Steps

1. **Test thoroughly** - All interaction patterns and edge cases
2. **User feedback** - Does the sunlight metaphor resonate?
3. **Analytics** - Track which mode users prefer (quick vs deep)
4. **Insights view** - Visualize mood patterns with warm gradients
5. **AI integration** - Use mood + gratitude for personalized suggestions

---

## Success Metrics

We'll know this redesign succeeded if:

- ✅ Users check in more frequently
- ✅ More users add notes and gratitude (deeper engagement)
- ✅ Positive feedback about "warm" and "calm" experience
- ✅ Lower drop-off rates in onboarding
- ✅ Higher NPS scores mentioning "unique" or "different"

---

## Philosophy in Action

This redesign embodies Lume's core principle:

> **"We're not a tracking app. We're a warm companion for emotional wellness."**

Every change—from sunlight metaphors to warm gradients to gratitude prompts—serves this vision.

---

**Questions?** See `DESIGN_PHILOSOPHY.md` for the complete reasoning.  
**Technical details?** See `.github/copilot-instructions.md` for architecture.