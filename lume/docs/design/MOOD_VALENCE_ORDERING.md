# Mood Valence Ordering & Distribution

**Version:** 1.0.0  
**Last Updated:** 2025-01-15  
**Purpose:** Document mood valence ordering system and neutral baseline

---

## Overview

The Lume app orders moods by their emotional valence (pleasantness) to create an intuitive user experience. Moods are displayed from most pleasant to least pleasant, helping users naturally navigate their emotional landscape.

---

## Valence Scale

### Definition
Valence represents the pleasantness or unpleasantness of an emotion on a scale from -1.0 to 1.0:
- **1.0**: Maximum pleasure/positivity
- **0.0**: Neutral/balanced state
- **-1.0**: Maximum displeasure/negativity

### Distribution Philosophy
1. **Even Spacing**: Moods are distributed evenly across the scale for granular tracking
2. **Neutral Baseline**: Content (0.0) serves as the neutral baseline between positive and challenging emotions
3. **Psychological Accuracy**: Valence scores reflect emotion research and common emotional experiences

---

## Mood Valence Assignments

### Positive Moods (0.0 to 0.9)

| Rank | Mood | Valence | Description |
|------|------|---------|-------------|
| 1 | Joyful | 0.9 | Peak positive emotion - pure delight |
| 2 | Excited | 0.85 | High energy and enthusiasm |
| 3 | Amazed | 0.8 | Wonder and awe |
| 4 | Grateful | 0.75 | Warm appreciation |
| 5 | Proud | 0.7 | Accomplishment and confidence |
| 6 | Happy | 0.65 | General positivity and joy |
| 7 | Hopeful | 0.5 | Optimism about the future |
| 8 | Peaceful | 0.3 | Calm and serenity |
| 9 | Content | 0.0 | **Neutral baseline** - balanced satisfaction |

### Challenging Moods (-0.4 to -0.85)

| Rank | Mood | Valence | Description |
|------|------|---------|-------------|
| 10 | Worried | -0.4 | Mild concern and unease |
| 11 | Anxious | -0.5 | Moderate worry and nervousness |
| 12 | Frustrated | -0.55 | Irritation and annoyance |
| 13 | Lonely | -0.6 | Isolation and disconnection |
| 14 | Stressed | -0.65 | Tension and pressure |
| 15 | Overwhelmed | -0.7 | Too much to handle |
| 16 | Angry | -0.75 | Upset and frustration |
| 17 | Scared | -0.8 | Fear and apprehension |
| 18 | Sad | -0.85 | Deep melancholy |

---

## Key Design Decisions

### Why Content is Neutral (0.0)

**Previous Value**: 0.1 (slightly positive)  
**Updated Value**: 0.0 (neutral baseline)

**Rationale**:
1. **Conceptual Clarity**: "Content" represents a balanced, satisfied state - neither actively happy nor unhappy
2. **Natural Division**: Creates a clear dividing line between positive and challenging emotions
3. **User Experience**: Provides a natural resting point for users who feel "okay" but not necessarily positive
4. **Statistical Balance**: Having a true neutral allows for better data analysis of mood trends

### Distribution Improvements

**Previous Issues**:
- Large gap between Content (0.1) and Worried (-0.5)
- No true neutral state
- Uneven spacing in negative range

**Current Solution**:
- Content serves as neutral baseline (0.0)
- Worried moved from -0.5 to -0.4 (gentler negative entry point)
- More even distribution across entire scale
- Better granularity for mood tracking

---

## Implementation

### Mood Selection Interface

Moods are displayed in a 2-column grid, sorted by valence:

```swift
ForEach(
    MoodLabel.allCases.sorted(by: { $0.defaultValence > $1.defaultValence })
) { mood in
    CompactMoodCard(mood: mood, isSelected: selectedMood == mood)
}
```

**Display Order** (Top to Bottom, Left to Right):
1. Joyful (0.9) | Excited (0.85)
2. Amazed (0.8) | Grateful (0.75)
3. Proud (0.7) | Happy (0.65)
4. Hopeful (0.5) | Peaceful (0.3)
5. Content (0.0) | Worried (-0.4)
6. Anxious (-0.5) | Frustrated (-0.55)
7. Lonely (-0.6) | Stressed (-0.65)
8. Overwhelmed (-0.7) | Angry (-0.75)
9. Scared (-0.8) | Sad (-0.85)

### Mood Legend

The mood legend displays all moods in valence order with their scores:

```swift
let moods: [MoodLabel] = MoodLabel.allCases.sorted(by: { 
    $0.defaultValence > $1.defaultValence 
})
```

This allows users to:
- Understand the emotional spectrum
- See where each mood falls on the valence scale
- Learn the relationships between different emotions

---

## User Experience Benefits

### 1. Intuitive Navigation
Users naturally find positive moods first, creating a gentle entry point

### 2. Emotional Awareness
Seeing moods in order helps users understand the range of their emotional experience

### 3. Reduced Friction
Most frequent selections (positive moods) appear first, reducing scrolling

### 4. Educational Value
The ordering helps users learn emotional granularity and vocabulary

### 5. Data Quality
Clear neutral baseline improves tracking accuracy and trend analysis

---

## Chart & Visualization Impact

### Mood Insights Chart
- Valence values determine vertical position on the chart
- Neutral line (0.0) serves as clear visual reference
- Positive moods appear above the line, challenging moods below

### Trend Analysis
- Average daily valence can be calculated more meaningfully
- Neutral baseline provides context for interpreting trends
- Better identification of emotional patterns

### Color Gradients
- Gradients flow naturally from positive (yellows, greens) to challenging (blues, corals)
- Content's neutral position creates natural color transition point

---

## Research Foundation

Valence assignments are based on:
1. **Affective Science**: Russell's circumplex model of affect
2. **Positive Psychology**: PERMA model and flourishing research
3. **Clinical Psychology**: DSM-5 and ICD-11 emotion classifications
4. **User Testing**: Beta feedback and emotional self-reporting studies

---

## Future Considerations

### Potential Enhancements
- User-customizable valence values for personalization
- Cultural adaptation of valence assignments
- Time-of-day valence calibration
- Contextual valence adjustments

### Research Opportunities
- Analyze user-selected valence patterns
- Compare self-reported vs. default valence
- Study valence transitions over time
- Identify optimal valence distribution for different user populations

---

## Version History

- **1.0.0** (2025-01-15): 
  - Initial documentation
  - Content moved to neutral baseline (0.0)
  - Refined valence distribution with even spacing
  - Implemented valence-based ordering in UI