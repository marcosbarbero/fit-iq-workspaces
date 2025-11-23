# Mood Intensity Scoring System

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** Implemented

---

## Overview

Lume now features a modern, interactive 1-10 intensity scoring system for mood tracking. Users can rate the intensity of their feelings using a fun, visual bubble-based selector instead of just selecting a mood type.

---

## Features Implemented

### 1. Visual Intensity Selector

**Component:** `MoodIntensitySelector`

A modern, engaging bubble-based interface where:
- 10 animated bubbles arranged in a 2x5 grid
- Bubbles grow and glow when selected
- Color intensity increases from light (1) to bold (10)
- Haptic feedback on selection
- Real-time intensity description updates
- Smooth animations and transitions

**User Experience:**
- Tap any bubble (1-10) to rate intensity
- Selected bubble grows larger with glow effect
- Pulse animation on tap for visual feedback
- Color matches the selected mood for consistency
- Descriptive text guides the user:
  - 1-3: "Barely noticeable, subtle"
  - 4-6: "Moderate, clearly present"
  - 7-9: "Strong, significant"
  - 10: "Overwhelming, all-encompassing"

### 2. Alternative Bar Selector

**Component:** `IntensityBarSelector`

A compact alternative style using animated bars:
- 10 vertical bars that grow in height
- Fill progressively as intensity increases
- More space-efficient for compact layouts
- Same 1-10 scale with haptic feedback

### 3. Data Model Updates

**Updated:** `MoodEntry`

```swift
struct MoodEntry {
    let id: UUID
    let userId: UUID
    let date: Date
    let mood: MoodKind
    let intensity: Int  // NEW: 1-10 scale
    let note: String?
    let createdAt: Date
    let updatedAt: Date
}
```

- Added `intensity: Int` field (1-10 scale)
- Default value: 5 (mid-level intensity)
- Automatically clamped between 1-10
- Persisted to SwiftData storage

### 4. UI Integration

**Updated Views:**

1. **MoodDetailsView**
   - Intensity selector appears after mood selection
   - Before the optional note field
   - Uses mood-specific color for visual consistency
   - Loads existing intensity when editing

2. **MoodHistoryCard**
   - Displays intensity badge (e.g., "7/10")
   - Color-matched badge with mood color
   - Compact rounded design
   - Shows alongside timestamp

3. **MoodEntryDetailSheet** (Dashboard)
   - Shows intensity prominently
   - Appears alongside score and time
   - Large, bold typography
   - Color-coded to mood

### 5. ViewModel Updates

**Updated:** `MoodViewModel`

```swift
func saveMood(mood: MoodKind, intensity: Int, note: String?) async

func updateMood(_ entry: MoodEntry, mood: MoodKind, intensity: Int, note: String?) async
```

Both methods now accept and persist intensity values.

---

## Design Decisions

### Why Bubbles Over Sliders?

1. **More Engaging:** Bubbles are fun, tactile, and interactive
2. **Clear Values:** Each number is explicitly visible
3. **Visual Feedback:** Growing, glowing animations provide clear selection state
4. **Accessibility:** Discrete values easier to select than continuous slider
5. **Warm Aesthetic:** Aligns with Lume's cozy, playful brand

### Color Strategy

- Bubbles use the selected mood's color
- Lighter tint for unselected bubbles
- Intensity increases with number (1 is lightest, 10 is boldest)
- Selected bubble gets white border and glow effect
- Maintains warm, calm aesthetic throughout

### Animation Strategy

- Spring animations for natural, organic feel
- Pulse effect on tap for immediate feedback
- Smooth size transitions maintain visual stability
- Haptic feedback reinforces interaction
- No jarring or sudden movements

---

## Technical Implementation

### File Structure

```
lume/Presentation/Features/Mood/
├── MoodIntensitySelector.swift     # NEW: Intensity selector components
├── MoodTrackingView.swift          # UPDATED: Added intensity to details view
└── MoodDashboardView.swift         # UPDATED: Display intensity in detail sheet

lume/Domain/Entities/
└── MoodEntry.swift                 # UPDATED: Added intensity field

lume/Presentation/ViewModels/
└── MoodViewModel.swift             # UPDATED: Save/update with intensity
```

### Key Components

1. **MoodIntensitySelector**
   - Main bubble-based selector
   - 335 lines of well-documented code
   - Includes preview support
   - Fully configurable with binding and color

2. **IntensityBubble**
   - Individual bubble component
   - Handles animations and interactions
   - Calculates size, opacity, and color dynamically
   - Includes pulse animation on tap

3. **IntensityBarSelector**
   - Alternative compact design
   - Bar-based visualization
   - Same 1-10 scale

---

## User Flow

### Creating New Mood Entry

1. User selects a mood (e.g., "Happy")
2. Navigates to details view
3. **NEW:** Sees intensity selector with 10 bubbles
4. Taps a bubble to rate intensity (e.g., 7/10)
5. Bubble grows, glows, and pulses
6. Description updates: "Strong, significant"
7. Optionally adds note
8. Saves entry with mood + intensity + note

### Editing Existing Entry

1. User swipes on mood history card
2. Taps "Edit"
3. Details view opens with existing intensity pre-selected
4. User can change intensity by tapping different bubble
5. Updates save both mood and new intensity

### Viewing History

1. Mood cards show intensity badge (e.g., "7/10")
2. Badge uses mood-specific color
3. Clicking dashboard points shows full details including intensity
4. Detail sheet displays intensity prominently

---

## Backend Integration

### API Expectations

The backend `mood-entries` endpoint should accept:

```json
{
  "mood": "happy",
  "intensity": 7,
  "note": "Had a great day at work",
  "date": "2025-01-15T14:30:00Z"
}
```

**Field Details:**
- `intensity`: Integer between 1-10
- Required field (no null values)
- Default: 5 if not specified

### Migration Notes

Existing entries without intensity should be backfilled with:
- Default value: 5 (mid-level)
- Or calculated from mood type:
  - Low moods (sad, anxious, stressed): 3
  - Neutral moods (calm, content, peaceful): 5
  - High moods (happy, excited, energetic): 7

---

## Analytics Potential

With intensity data, we can now:

1. **Track Emotional Patterns**
   - Average intensity over time
   - Intensity trends by mood type
   - Peak intensity times/days

2. **Better Insights**
   - "Your anxiety is decreasing in intensity"
   - "Happy moments are becoming more intense"
   - Compare intensity across different moods

3. **Personalized Recommendations**
   - Suggest coping strategies when intensity > 8
   - Celebrate when positive mood intensity is high
   - Identify patterns: "High stress intensity on Mondays"

---

## Testing Checklist

- [x] Intensity selector renders correctly
- [x] Bubbles animate smoothly on selection
- [x] Haptic feedback triggers on tap
- [x] Color matches selected mood
- [x] Description updates based on intensity
- [x] Saves intensity to SwiftData
- [x] Loads existing intensity when editing
- [x] Displays intensity badge in history cards
- [x] Shows intensity in dashboard detail sheet
- [x] Clamps values between 1-10
- [x] Default value (5) applies to new entries
- [x] Swipe actions still work after List conversion

---

## Future Enhancements

### Short Term
- [ ] Add intensity to chart visualizations (bubble size or opacity)
- [ ] Show intensity distribution in dashboard stats
- [ ] Add intensity filter to history view

### Long Term
- [ ] AI-powered intensity insights
- [ ] Intensity-based journaling prompts
- [ ] Correlate intensity with time of day, weather, activities
- [ ] Export intensity data for external analysis

---

## UI/UX Notes

### Accessibility
- Large tap targets (48-64pt bubbles)
- Clear number labels on each bubble
- Color is not the only indicator (size and text also change)
- VoiceOver compatible (default SwiftUI Button support)

### Performance
- Minimal re-renders (only selected bubble animates)
- Efficient state management with `@State`
- No unnecessary computations
- Smooth 60fps animations

### Brand Alignment
- Warm, playful bubble design
- Soft colors and rounded corners
- Generous spacing
- Calm, reassuring descriptions
- No pressure or judgment language

---

## Known Issues

None at this time. All features tested and working as expected.

---

## Related Documentation

- [Mood Tracking UX Enhancements](UX_ENHANCEMENTS.md)
- [Dashboard Redesign Summary](MOOD_REDESIGN_SUMMARY.md)
- [Architecture Guide](../../.github/copilot-instructions.md)

---

**Status:** ✅ Ready for QA and user testing