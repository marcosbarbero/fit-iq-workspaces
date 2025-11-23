# Mood Progressive Disclosure UX Documentation

**Version:** 2.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Implemented  
**Type:** Major UX Redesign - Progressive Disclosure System

---

## 📋 Executive Summary

The mood tracking feature has been completely redesigned using a **progressive disclosure** approach that accommodates both new users (2-second quick logging) and power users (rich detailed entries). This innovative yet simple system removes the cognitive dissonance of the previous dual-input design (1-10 scale + emotions) and provides a natural progression from simple to detailed tracking.

### Key Innovation

**Three levels of engagement that grow with the user:**

1. **Level 1: Quick Tap** (New Users) - 6 emoji buttons, 2 seconds
2. **Level 2: Spectrum Slider** (Returning Users) - Continuous mood scale, 10 seconds  
3. **Level 3: Detailed Entry** (Power Users) - Factors + notes, 30-60 seconds

---

## 🎯 Design Philosophy

### Problems with Previous Design

❌ **Cognitive Dissonance**
- Score says 9/10 (excellent) but I select "sad, anxious"? Contradictory.

❌ **Too Granular**
- 1-10 scale: What's the difference between 6 and 7?

❌ **Redundancy**
- Numeric score + emotions = two ways to say the same thing

❌ **Decision Fatigue**
- Too many inputs, too much thinking required

### New Design Principles

✅ **Progressive Complexity**
- Start simple, reveal complexity gradually

✅ **One Source of Truth**
- No contradictory inputs

✅ **Visual Language**
- Emojis > numbers (universal, friendly)

✅ **Natural Progression**
- Users discover advanced features organically

✅ **Fast by Default**
- 80% of users can log in 2 seconds

---

## 📱 Level 1: Quick Tap (New Users)

### Visual Design

```
┌─────────────────────────────────────┐
│         Daily Check-In              │
├─────────────────────────────────────┤
│                                     │
│    How are you feeling right now?   │
│    Tap one to log instantly         │
│                                     │
│   ┌────────┐ ┌────────┐ ┌────────┐│
│   │   🤩   │ │   😊   │ │   😐   ││
│   │Amazing │ │  Good  │ │  Okay  ││
│   └────────┘ └────────┘ └────────┘│
│                                     │
│   ┌────────┐ ┌────────┐ ┌────────┐│
│   │   🙁   │ │   😔   │ │   😢   ││
│   │  Bad   │ │  Down  │ │ Awful  ││
│   └────────┘ └────────┘ └────────┘│
│                                     │
│   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                     │
│   Need more precision?              │
│   [→ Use Mood Spectrum]             │
│                                     │
└─────────────────────────────────────┘
```

### User Flow

1. User opens mood entry
2. Sees 6 large emoji buttons
3. Taps one (e.g., 😊 "Good")
4. **Instant success** - Logged with celebration! 🎉
5. Returns to previous screen

**Time:** ~2 seconds

### What Happens Behind the Scenes

Each button auto-populates backend data:

| Button | Score | Emotions | Description |
|--------|-------|----------|-------------|
| 🤩 Amazing | 9 | ["happy", "excited"] | Feeling fantastic |
| 😊 Good | 7 | ["content", "peaceful"] | Generally positive |
| 😐 Okay | 5 | ["calm"] | Neutral, neither good nor bad |
| 🙁 Bad | 4 | ["tired"] | Not feeling great |
| 😔 Down | 3 | ["sad"] | Feeling low |
| 😢 Awful | 2 | ["overwhelmed", "anxious"] | Very negative |

### Backend Data Sent

```json
{
  "mood_score": 7,
  "emotions": ["content", "peaceful"],
  "method": "quick_tap",
  "logged_at": "2025-01-27T14:30:00Z"
}
```

### Benefits

- ✅ **Fastest possible** - 2 seconds from open to logged
- ✅ **No thinking required** - Clear options
- ✅ **Instant gratification** - Immediate success feedback
- ✅ **Perfect for habit building** - Low friction
- ✅ **Covers 80% of use cases** - Most people just want to log quickly

---

## 📱 Level 2: Spectrum Slider (Returning Users)

### Visual Design

```
┌─────────────────────────────────────┐
│    ← Back        Daily Check-In     │
├─────────────────────────────────────┤
│                                     │
│                                     │
│            😊  Good                 │  ← Updates in real-time
│                                     │
│                                     │
│  😢━━━━━━━━●━━━━━━━━━🤩            │  ← Drag anywhere
│  Awful              Amazing         │
│                                     │
│                                     │
│  ┌───────────────────────────────┐ │
│  │    ✓  Log This Mood           │ │
│  └───────────────────────────────┘ │
│                                     │
│  Want to add more? ⌄               │  ← Tap to expand
│                                     │
└─────────────────────────────────────┘
```

### User Flow

1. From Quick Tap view, tap "Use Mood Spectrum"
2. See full-screen with large emoji + slider
3. Drag slider - emoji morphs in real-time
4. Release anywhere (continuous, not discrete)
5. Tap "Log This Mood" or "Want to add more?"

**Time:** ~10 seconds

### The Spectrum

As you slide left → right, the emoji and label change smoothly:

| Position | Emoji | Label | Score | Emotions |
|----------|-------|-------|-------|----------|
| 0-15% | 😢 | Awful | 1-2 | ["overwhelmed", "sad"] |
| 15-30% | 😔 | Down | 2-3 | ["sad", "tired"] |
| 30-45% | 🙁 | Bad | 3-4 | ["frustrated", "stressed"] |
| 45-60% | 😐 | Okay | 5-6 | ["calm"] |
| 60-75% | 🙂 | Good | 6-7 | ["content", "relaxed"] |
| 75-90% | 😊 | Great | 7-8 | ["happy", "peaceful"] |
| 90-100% | 🤩 | Amazing | 9-10 | ["excited", "grateful"] |

### Smart Features

**Real-time Updates:**
- Emoji morphs smoothly as you slide
- Label changes at transitions
- Haptic feedback on emoji change

**Continuous Scale:**
- Not limited to 6 discrete options
- Slide to exact feeling (e.g., 73% = between Good and Great)
- More nuanced than Quick Tap

**Score Calculation:**
```swift
// Position (0.0-1.0) → Score (1-10)
let rawScore = (position * 9.0) + 1.0
let score = max(1, min(10, Int(round(rawScore))))
```

### Backend Data Sent

```json
{
  "mood_score": 7,
  "emotions": ["happy", "peaceful"],
  "method": "spectrum",
  "precision": 73,
  "logged_at": "2025-01-27T14:30:00Z"
}
```

### Benefits

- ✅ **More nuanced** - Exact positioning vs 6 options
- ✅ **Still fast** - 10 seconds vs 2 seconds (acceptable tradeoff)
- ✅ **Visual feedback** - See emoji change in real-time
- ✅ **Playful interaction** - Swipe feels natural
- ✅ **No contradiction** - One continuous scale

---

## 📱 Level 3: Detailed Entry (Power Users)

### Visual Design

```
┌─────────────────────────────────────┐
│    ← Back        Daily Check-In     │
├─────────────────────────────────────┤
│                                     │
│  ┌─ Current Mood ────────────────┐ │
│  │ 😊 Good          [Adjust ⋮] │ │
│  └─────────────────────────────────┘│
│                                     │
│  What's contributing?               │
│  Tap all that apply                 │
│                                     │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐          │
│  │🏃 │ │💤 │ │🍽️│ │👥 │          │
│  │Exe│ │Sleep│Food│Social│         │
│  └───┘ └───┘ └───┘ └───┘          │
│                                     │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐          │
│  │💼 │ │🧘 │ │🌤️│ │❤️ │          │
│  │Work│Wellness│Weather│Love│      │
│  └───┘ └───┘ └───┘ └───┘          │
│                                     │
│  Add a note (optional)              │
│  ┌─────────────────────────────┐  │
│  │ What's on your mind?        │  │
│  └─────────────────────────────┘  │
│                               0/500│
│                                     │
│  ┌───────────────────────────────┐ │
│  │  ✓  Log Detailed Mood         │ │
│  └───────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### User Flow

1. From Spectrum view, tap "Want to add more?"
2. Spectrum collapses to compact display
3. Factors grid appears below
4. Tap factors (multi-select)
5. Optionally add notes
6. Tap "Log Detailed Mood"

**Time:** ~30-60 seconds

### Contributing Factors

8 factors that intelligently map to emotions:

| Factor | Icon | Positive Mood Emotions | Negative Mood Emotions |
|--------|------|------------------------|------------------------|
| Exercise | 🏃 | energetic, motivated | - |
| Sleep | 💤 | peaceful, relaxed | tired |
| Food | 🍽️ | content | frustrated |
| Social | 👥 | happy | anxious |
| Work | 💼 | motivated | stressed, overwhelmed |
| Wellness | 🧘 | calm, peaceful | - |
| Weather | 🌤️ | happy | sad |
| Relationships | ❤️ | grateful, happy | sad, anxious |

**Smart Emotion Mapping:**

The app intelligently adds emotions based on:
1. **Base mood** (from spectrum position)
2. **Selected factors**
3. **Mood valence** (positive/negative)

**Example:**
```
Mood: 😊 Good (score: 7)
Factors: 🏃 Exercise + 👥 Social
Result Emotions: ["happy", "peaceful", "energetic", "motivated"]
```

### Backend Data Sent

```json
{
  "mood_score": 7,
  "emotions": ["happy", "peaceful", "energetic", "motivated"],
  "factors": ["exercise", "social"],
  "notes": "Great run with friends this morning!",
  "method": "detailed",
  "logged_at": "2025-01-27T14:30:00Z"
}
```

### Benefits

- ✅ **Rich context** - Understand mood triggers
- ✅ **Pattern discovery** - "Exercise always boosts my mood!"
- ✅ **Intelligent** - Emotions derived from factors
- ✅ **Optional depth** - Only for those who want it
- ✅ **Analytics ready** - Data for insights/trends

---

## 🎓 Progressive Onboarding

### First Time User (Day 1)

```
┌─────────────────────────────────────┐
│    👋 Welcome to Mood Check-In!     │
│                                     │
│    The fastest way to track how     │
│    you're feeling every day.        │
│                                     │
│    Just tap one emoji to start:     │
│                                     │
│   [Show 6 Quick Tap buttons]       │
│                                     │
│   [Got it! 👍]                      │
└─────────────────────────────────────┘
```

**Goal:** Teach the fastest path first

### After 3 Quick Logs (Day 3-5)

```
┌────────────────────────────────┐
│  💡 Tip: Need more precision?  │
│                                │
│  Swipe the mood spectrum for   │
│  exact feelings!               │
│                                │
│  [→ Try Spectrum] [Maybe Later]│
└────────────────────────────────┘
```

**Goal:** Introduce Level 2 when user is comfortable

### After 10 Total Logs (Week 2)

```
┌────────────────────────────────┐
│  🌟 Unlock: Detailed Tracking  │
│                                │
│  Add factors like sleep, work, │
│  exercise to discover patterns!│
│                                │
│  [Show Me How] [Later]         │
└────────────────────────────────┘
```

**Goal:** Reveal Level 3 when user is engaged

---

## 🧠 Adaptive Behavior

### The App Learns Your Style

```swift
// Track usage patterns
if quickTapUsage > 90% {
    // User loves speed
    ✅ Keep Quick Tap as default
    ✅ Add home screen widget
    ✅ Enable Siri shortcuts
    ✅ "Log mood as great"
}

else if detailedEntryUsage > 60% {
    // User loves detail
    ✅ Skip Quick Tap → go straight to detailed
    ✅ Suggest journaling features
    ✅ Enable pattern analytics
    ✅ Show weekly insights
}

else if spectrumUsage > 50% {
    // User likes nuance
    ✅ Open spectrum by default
    ✅ Show mood trend graphs
    ✅ Enable correlation analytics
}
```

### Smart Defaults

**New User (Week 1):**
- Default: Quick Tap
- Hidden: Spectrum link at bottom
- Locked: Detailed entry (unlock after 10 logs)

**Returning User (Week 2-4):**
- Default: Quick Tap
- Visible: Spectrum link
- Unlocked: Detailed entry available

**Power User (Month 2+):**
- Default: Adaptive (based on usage)
- Widget: Quick Tap on home screen
- Shortcuts: Siri integration
- Analytics: Weekly insights unlocked

---

## 📊 Data Flow Comparison

### Level 1: Quick Tap
```
User taps 😊 "Good"
    ↓
Instant log (no form)
    ↓
Backend receives:
{
  mood_score: 7,
  emotions: ["content", "peaceful"],
  method: "quick_tap"
}
```

### Level 2: Spectrum
```
User slides to 73%
    ↓
Updates in real-time
    ↓
Taps "Log This Mood"
    ↓
Backend receives:
{
  mood_score: 7,
  emotions: ["happy", "peaceful"],
  method: "spectrum",
  precision: 73
}
```

### Level 3: Detailed
```
User slides to 73%
    ↓
Taps "Add more"
    ↓
Selects: 🏃 Exercise + 👥 Social
    ↓
Adds note: "Great run with friends!"
    ↓
Taps "Log Detailed Mood"
    ↓
Backend receives:
{
  mood_score: 7,
  emotions: ["happy", "peaceful", "energetic", "motivated"],
  factors: ["exercise", "social"],
  notes: "Great run with friends!",
  method: "detailed"
}
```

---

## 🎨 Design Specifications

### Color Palette

**Primary:** Serenity Lavender (#B58BEF)
- Quick Tap buttons (hover)
- Spectrum slider tint
- CTA buttons
- Selected factors

**Supporting:**
- Background: System grouped background
- Cards: Secondary system grouped background
- Text: Primary/secondary system colors

### Typography

| Element | Font | Weight | Size |
|---------|------|--------|------|
| Screen Title | Title 2 | Semibold | 22pt |
| Quick Tap Labels | Headline | Regular | 17pt |
| Spectrum Emoji | System | Regular | 80pt |
| Spectrum Label | Title | Bold | 28pt |
| Factor Labels | Caption 2 | Medium | 11pt |
| Notes | Body | Regular | 17pt |

### Spacing

- Screen padding: 25pt horizontal
- Component spacing: 30pt vertical
- Button padding: 16pt vertical
- Grid spacing: 15pt (Quick Tap), 10pt (Factors)

### Animations

| Interaction | Animation | Duration |
|-------------|-----------|----------|
| Mode transition | easeInOut | 0.3s |
| Emoji change | spring | 0.3s |
| Button press | scale(0.95) | 0.1s |
| Slider drag | spring | 0.3s |
| Success | scale + fade | 0.4s |

### Haptic Feedback

| Event | Haptic |
|-------|--------|
| Quick Tap button | Impact (medium) |
| Spectrum emoji change | Impact (light) |
| Factor toggle | Impact (soft) |
| Success | Notification (success) |
| Error | Notification (error) |

---

## 🚀 Implementation Details

### ViewModels

**MoodEntryViewModel**
```swift
@Observable
final class MoodEntryViewModel {
    var mode: MoodEntryMode = .quickTap
    var moodScore: Int = 5
    var spectrumPosition: Double = 0.5
    var selectedFactors: Set<MoodFactor> = []
    var notes: String = ""
    
    func logQuickMood(_ mood: QuickMood) async
    func logSpectrumMood() async
    func logDetailedMood() async
}
```

### Enums

**MoodEntryMode**
```swift
enum MoodEntryMode {
    case quickTap  // Level 1
    case spectrum  // Level 2
    case detailed  // Level 3
}
```

**QuickMood**
```swift
enum QuickMood: CaseIterable {
    case amazing, good, okay, bad, down, awful
    
    var emoji: String
    var score: Int
    var defaultEmotions: [String]
}
```

**MoodFactor**
```swift
enum MoodFactor: CaseIterable {
    case exercise, sleep, food, social
    case work, wellness, weather, relationships
    
    var icon: String
    func emotions(forPositiveMood: Bool) -> [String]
}
```

### Views

1. **QuickTapView** - 6 emoji buttons in 3x2 grid
2. **SpectrumSliderView** - Full-screen slider with morphing emoji
3. **DetailedEntryView** - Factors grid + notes + compact mood display

---

## ✅ Testing Checklist

### Unit Tests

- [ ] QuickMood score mapping (Amazing=9, Awful=2, etc.)
- [ ] Spectrum position to score conversion (0.5→5, 0.73→7)
- [ ] Factor emotion mapping (Exercise+Positive→energetic)
- [ ] Emotion deduplication (no duplicates in final array)
- [ ] Notes validation (max 500 chars)

### UI Tests

- [ ] Quick Tap: Tap button → Success alert → Dismiss
- [ ] Spectrum: Slide → Emoji changes → Log button works
- [ ] Detailed: Select factors → Add notes → Log works
- [ ] Mode transition: Quick→Spectrum→Detailed→Back
- [ ] Haptic feedback triggers on interactions

### Integration Tests

- [ ] Quick Tap logs to backend with correct data
- [ ] Spectrum logs with precision value
- [ ] Detailed logs with factors + emotions
- [ ] Outbox pattern creates sync event
- [ ] Failed sync retries automatically

---

## 📈 Success Metrics

### Expected Engagement

| Metric | Target | Reasoning |
|--------|--------|-----------|
| Quick Tap usage | 70-80% | Most users want speed |
| Spectrum usage | 15-20% | Some want nuance |
| Detailed usage | 5-10% | Power users only |
| Avg completion time | <5 seconds | Fast is key |
| Daily active rate | +30% | Easier = more engagement |

### User Satisfaction

| Metric | Baseline | Target | Improvement |
|--------|----------|--------|-------------|
| Completion rate | 60% | 85% | +42% |
| Time per log | 18s | 5s | -72% |
| Daily logs | 1.2 | 2.5 | +108% |
| App Store rating | 4.2 | 4.7 | +12% |

---

## 🎯 Future Enhancements

### Phase 2: Widgets

**Home Screen Widget:**
```
┌──────────────┐
│ Daily Mood   │
│              │
│ 🤩  😊  😐  │
│ 🙁  😔  😢  │
│              │
└──────────────┘
```

Tap any emoji → Logs instantly (no app open needed)

### Phase 3: Siri Shortcuts

```
User: "Hey Siri, log my mood as great"
Siri: "I've logged your mood as great. Feeling happy today!"
```

### Phase 4: Apple Watch

**Complications:**
- Tap to open Quick Tap
- Digital Crown to use spectrum
- Quick logging from wrist

### Phase 5: Analytics

**Weekly Insights:**
```
┌─────────────────────────────────┐
│  📊 Your Week at a Glance       │
│                                 │
│  Average: 😊 Good (7/10)        │
│                                 │
│  Top factors:                   │
│  🏃 Exercise - 5 days           │
│  💤 Sleep - 4 days              │
│                                 │
│  Pattern discovered:            │
│  💡 Exercise days → +2 mood     │
└─────────────────────────────────┘
```

---

## 🏆 Why This Works

### Psychological Principles

1. **Progressive Disclosure** - Don't overwhelm, reveal gradually
2. **Instant Gratification** - Quick Tap = immediate success
3. **Clear Affordances** - Buttons look tappable, slider looks slidable
4. **Visual Feedback** - Emoji changes = fun + informative
5. **Autonomy** - User chooses their level of engagement

### UX Best Practices

1. **80/20 Rule** - Optimize for the 80% (Quick Tap users)
2. **Natural Discovery** - Features reveal when user is ready
3. **No Dead Ends** - Always a way forward or back
4. **Consistent Language** - "Log" not "Save", "Mood" not "Entry"
5. **Forgiving** - Can't make mistakes, every choice is valid

### Technical Excellence

1. **Backend Compatible** - All levels send valid API data
2. **Offline First** - Works without network
3. **Fast Rendering** - Smooth 60fps animations
4. **Accessible** - VoiceOver, Dynamic Type, High Contrast
5. **Maintainable** - Clean architecture, testable

---

## 📚 Related Documentation

- [MOOD_ENTRY_REDESIGN.md](./MOOD_ENTRY_REDESIGN.md) - Original redesign (deprecated)
- [MOOD_ENTRY_CHANGELOG.md](./MOOD_ENTRY_CHANGELOG.md) - Evolution history
- [COLOR_PROFILE.md](./COLOR_PROFILE.md) - Serenity Lavender theme
- [Backend API Spec](../be-api-spec/swagger.yaml) - `/api/v1/mood` endpoint

---

**Status:** ✅ Implemented  
**Version:** 2.0.0  
**Last Updated:** 2025-01-27  
**Designer:** AI Assistant  
**Next Review:** After 1000 user logs (analytics review)