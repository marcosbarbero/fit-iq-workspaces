# Mood Color Palette Design

**Version:** 2.0.0  
**Last Updated:** 2025-01-15  
**Purpose:** Document the expanded mood color palette for Lume iOS app

---

## Overview

The Lume app uses a diverse, warm color palette to visually differentiate mood states while maintaining the app's core principle of being calm, cozy, and non-judgmental. Each mood has a unique color that reflects its emotional tone while remaining soft and accessible.

---

## Design Philosophy

### Core Principles

1. **Visual Differentiation**: Each mood has a distinct color to help users quickly identify and differentiate emotions
2. **Warm & Welcoming**: Even challenging emotions use soft, muted colors that feel supportive rather than alarming
3. **Accessibility**: All colors meet WCAG contrast requirements when paired with appropriate text
4. **Emotional Resonance**: Colors are chosen to reflect the emotional quality of each mood (e.g., mint green for hope, soft blue for calm)

### Color Categories

- **Positive Emotions**: Use vibrant but soft colors - yellows, greens, purples, and warm oranges
- **Challenging Emotions**: Use softer, muted tones - blues, corals, beiges, and mauves
- **Consistency**: All colors maintain the same saturation and lightness levels for visual harmony

---

## Positive Mood Colors

### Amazed (`#E8D4F0`)
- **Color**: Light purple
- **Emotion**: Wonder and awe
- **Icon**: `star.circle.fill`
- **Valence**: 0.8
- **Rationale**: Purple evokes mystery and wonder, perfect for feeling amazed

### Grateful (`#FFD4E5`)
- **Color**: Light rose
- **Emotion**: Warmth and appreciation
- **Icon**: `heart.fill`
- **Valence**: 0.75
- **Rationale**: Rose/pink conveys warmth, love, and appreciation

### Happy (`#F5DFA8`)
- **Color**: Bright yellow
- **Emotion**: Joy and positivity
- **Icon**: `sun.max.fill`
- **Valence**: 0.65
- **Rationale**: Yellow is universally associated with happiness and sunshine

### Proud (`#D4B8F0`)
- **Color**: Soft purple
- **Emotion**: Achievement and confidence
- **Icon**: `trophy.fill`
- **Valence**: 0.7
- **Rationale**: Purple conveys dignity, accomplishment, and pride

### Hopeful (`#B8E8D4`)
- **Color**: Light mint
- **Emotion**: Optimism and encouragement
- **Icon**: `sunrise.fill`
- **Valence**: 0.5
- **Rationale**: Mint green evokes freshness, new beginnings, and growth

### Content (`#D8E8C8`)
- **Color**: Sage green
- **Emotion**: Peace and satisfaction
- **Icon**: `checkmark.circle.fill`
- **Valence**: 0.0 (Neutral)
- **Rationale**: Sage green is calming and represents balance and contentment; serves as the neutral baseline between positive and challenging emotions

### Peaceful (`#C8D8EA`)
- **Color**: Soft sky blue
- **Emotion**: Calm and serenity
- **Icon**: `moon.stars.fill`
- **Valence**: 0.3
- **Rationale**: Light blue evokes tranquility and peaceful skies

### Excited (`#FFE4B5`)
- **Color**: Light orange
- **Emotion**: Energy and enthusiasm
- **Icon**: `sparkles`
- **Valence**: 0.85
- **Rationale**: Orange conveys energy and enthusiasm without being overwhelming

### Joyful (`#F5E8A8`)
- **Color**: Bright lemon
- **Emotion**: Delight and cheerfulness
- **Icon**: `star.fill`
- **Valence**: 0.9
- **Rationale**: Bright yellow-green evokes pure joy and celebration; highest positive valence

---

## Challenging Mood Colors

### Sad (`#C8D4E8`)
- **Color**: Light blue
- **Emotion**: Melancholy and down
- **Icon**: `cloud.rain.fill`
- **Valence**: -0.85
- **Rationale**: Soft blue reflects the "blue" feeling of sadness without being harsh

### Angry (`#F0B8A4`)
- **Color**: Soft coral
- **Emotion**: Frustration and upset
- **Icon**: `flame.fill`
- **Valence**: -0.75
- **Rationale**: Coral-red conveys anger but in a gentle, supportive way

### Stressed (`#E8C4B4`)
- **Color**: Soft peach
- **Emotion**: Tension and overwhelm
- **Icon**: `cloud.fill`
- **Valence**: -0.65
- **Rationale**: Warm peach feels supportive while acknowledging the heat of stress

### Anxious (`#E8E4D8`)
- **Color**: Light tan
- **Emotion**: Unease and worry
- **Icon**: `wind`
- **Valence**: -0.5
- **Rationale**: Neutral tan reflects the unsettled feeling of anxiety

### Frustrated (`#F0C8A4`)
- **Color**: Light terracotta
- **Emotion**: Irritation and annoyance
- **Icon**: `exclamationmark.triangle.fill`
- **Valence**: -0.55
- **Rationale**: Warm terracotta acknowledges frustration without being aggressive

### Overwhelmed (`#D4C8E8`)
- **Color**: Light purple-gray
- **Emotion**: Too much to handle
- **Icon**: `tornado`
- **Valence**: -0.7
- **Rationale**: Muted purple-gray reflects the foggy feeling of being overwhelmed

### Lonely (`#B8C8E8`)
- **Color**: Cool lavender-blue
- **Emotion**: Isolation and disconnection
- **Icon**: `figure.stand.line.dotted.figure.stand`
- **Valence**: -0.6
- **Rationale**: Cool blue-lavender evokes the distance and isolation of loneliness

### Scared (`#E8D4C8`)
- **Color**: Warm beige
- **Emotion**: Fear and apprehension
- **Icon**: `bolt.trianglebadge.exclamationmark.fill`
- **Valence**: -0.8
- **Rationale**: Warm beige provides comfort while acknowledging fear

### Worried (`#D8C8D8`)
- **Color**: Light mauve
- **Emotion**: Concern and trouble
- **Icon**: `brain.head.profile`
- **Valence**: -0.4
- **Rationale**: Neutral mauve reflects the mental nature of worry

---

## Color Distribution

### Color Families
- **Purples**: Amazed, Proud, Overwhelmed (3)
- **Greens**: Hopeful, Content (2)
- **Yellows/Oranges**: Happy, Excited, Joyful (3)
- **Blues**: Peaceful, Sad, Lonely (3)
- **Pinks/Corals**: Grateful, Angry, Frustrated (3)
- **Neutrals**: Stressed, Anxious, Scared, Worried (4)

### Variety Strategy
Each mood color is distinct enough to be immediately recognizable in the UI:
- No two positive moods share the same color family
- Challenging moods use softer, more muted versions
- The palette includes vibrant options (yellows, greens) alongside calm options (blues, mauves)

### Valence Distribution
The valence scale ranges from -1.0 (most unpleasant) to 1.0 (most pleasant):
- **Positive Range** (0.0 to 0.9): Nine moods from neutral contentment to peak joy
- **Neutral Point** (0.0): Content serves as the baseline balanced state
- **Negative Range** (-0.4 to -0.85): Nine moods from mild worry to deep sadness
- **Even Distribution**: Moods are spaced to provide granular emotional tracking

In the mood selection interface, moods are **ordered by valence** from most pleasant to least pleasant, helping users intuitively navigate from positive to challenging emotions.

---

## Implementation

### SwiftUI Integration

Colors are defined in `LumeColors.swift` and mapped in `MoodEntry.swift`:

```swift
// In MoodEntry.swift
var color: String {
    switch self {
    case .hopeful: return "#B8E8D4"  // Light mint
    case .content: return "#D8E8C8"  // Sage green
    // ... etc
    }
}
```

### Usage in UI

Colors are accessed via hex strings that are converted to SwiftUI `Color`:

```swift
Color(hex: mood.color)
    .opacity(0.3)
```

---

## Accessibility Considerations

1. **Contrast**: All mood colors are light enough to work with dark text overlays
2. **Differentiation**: Colors are distinct enough for users with color vision deficiencies
3. **Iconography**: Each mood has a unique SF Symbol to provide non-color identification
4. **Labels**: All mood cards include text labels alongside colors

---

## Future Considerations

- Consider adding haptic feedback for mood selection
- Explore animated color transitions between moods
- Test with colorblind users for optimal accessibility
- Monitor user feedback on color-emotion associations

---

## Version History

- **2.0.0** (2025-01-15): 
  - Expanded palette with light green, mint, rose, and diverse colors
  - Updated Amazed icon from `sparkle.magnifyingglass` to `star.circle.fill`
  - Refined valence distribution with neutral baseline at 0.0 (Content)
  - Added mood ordering by valence in selection interface (most pleasant to least pleasant)
- **1.0.0** (2024-11): Initial mood color system with basic palette