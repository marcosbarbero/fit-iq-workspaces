# Mood Intensity Selector - Visual Preview

**Component:** `MoodIntensitySelector`  
**Style:** Modern, fun, bubble-based rating  
**Range:** 1-10 intensity scale

---

## Visual Layout

```
┌─────────────────────────────────────────────────┐
│  Intensity                            7 / 10    │
│                                                  │
│  Strong, significant                            │
│                                                  │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐          │
│  │ 1  │ │ 2  │ │ 3  │ │ 4  │ │ 5  │          │
│  └────┘ └────┘ └────┘ └────┘ └────┘          │
│                                                  │
│  ┌────┐ ┌────┐ ┌─────┐ ┌────┐ ┌────┐         │
│  │ 6  │ │ 7  │ │  8  │ │ 9  │ │ 10 │         │
│  └────┘ └────┘ └─────┘ └────┘ └────┘         │
│         (selected - larger with glow)           │
└─────────────────────────────────────────────────┘
```

---

## Interaction States

### Unselected State
```
   ○ 1      Bubble size: 48-56pt
            Opacity: 0.4-0.7
            Color: Light tint of mood color
            Label: Number (18pt, medium weight)
```

### Selected State
```
   ◉ 7      Bubble size: 64pt (grows)
            Opacity: 1.0
            Color: Full mood color
            Glow: 16pt radius
            Border: 2pt white outline
            Label: Number (24pt, bold)
```

### Animation on Tap
```
   ◉ → ◎    1. Pulse outward (1.5x scale)
   (7)      2. Fade out
            3. Haptic feedback (light impact)
            Duration: 0.4s spring animation
```

---

## Color Progression

Intensity increases both in SIZE and COLOR SATURATION:

```
1-3:  ○ ○ ○        Subtle    (48pt, 30-40% opacity)
4-6:  ○ ○ ○        Moderate  (52pt, 45-55% opacity)
7-9:  ○ ○ ○        Strong    (56pt, 60-70% opacity)
10:   ○             Intense   (56pt, 80% opacity)

SELECTED: ◉          Any       (64pt, 100% opacity + glow)
```

---

## Descriptive Text

Automatically updates based on selection:

| Intensity | Description |
|-----------|-------------|
| 0 (none)  | "Tap a bubble to rate the intensity of this feeling" |
| 1-3       | "Barely noticeable, subtle" |
| 4-6       | "Moderate, clearly present" |
| 7-9       | "Strong, significant" |
| 10        | "Overwhelming, all-encompassing" |

---

## Color Mapping

Each mood has its own color that applies to the bubbles:

| Mood       | Color    | Hex       | Visual |
|------------|----------|-----------|--------|
| Peaceful   | Lavender | #E8E3F0   | 🟣     |
| Calm       | Lavender | #D8C8EA   | 🟣     |
| Content    | Blue     | #B8D4E8   | 🔵     |
| Happy      | Yellow   | #F5DFA8   | 🟡     |
| Excited    | Pink     | #FFD4E5   | 🩷     |
| Energetic  | Green    | #C5E8C0   | 🟢     |
| Tired      | Gray     | #D4D9E8   | ⚪     |
| Sad        | Blue     | #C8D4E8   | 🔵     |
| Anxious    | Tan      | #E8D9C8   | 🟤     |
| Stressed   | Coral    | #F0B8A4   | 🟠     |

---

## Example User Flow

### 1. Initial State
```
┌─────────────────────────────────────────────────┐
│  Intensity                                       │
│                                                  │
│  Tap a bubble to rate the intensity of this     │
│  feeling                                         │
│                                                  │
│  ○ 1  ○ 2  ○ 3  ○ 4  ○ 5                      │
│  ○ 6  ○ 7  ○ 8  ○ 9  ○ 10                     │
└─────────────────────────────────────────────────┘
```

### 2. User Taps "7"
```
┌─────────────────────────────────────────────────┐
│  Intensity                            7 / 10    │
│                                                  │
│  Strong, significant                            │
│                                                  │
│  ○ 1  ○ 2  ○ 3  ○ 4  ○ 5                      │
│  ○ 6  ◉ 7  ○ 8  ○ 9  ○ 10                     │
│       ↑                                          │
│    (glows, vibrates)                            │
└─────────────────────────────────────────────────┘
```

### 3. User Changes to "3"
```
┌─────────────────────────────────────────────────┐
│  Intensity                            3 / 10    │
│                                                  │
│  Barely noticeable, subtle                      │
│                                                  │
│  ○ 1  ○ 2  ◉ 3  ○ 4  ○ 5                      │
│  ○ 6  ○ 7  ○ 8  ○ 9  ○ 10                     │
│            ↑                                     │
│    (previous selection fades, new one grows)    │
└─────────────────────────────────────────────────┘
```

---

## In Context: MoodDetailsView

Full screen view showing intensity selector:

```
┌─────────────────────────────────────────────────┐
│ ← How are you feeling?                          │
├─────────────────────────────────────────────────┤
│                                                  │
│                    🌞                           │
│                   Happy                          │
│              Joyful and positive                 │
│                                                  │
│ ┌───────────────────────────────────────────┐  │
│ │  Intensity                       7 / 10    │  │
│ │                                             │  │
│ │  Strong, significant                        │  │
│ │                                             │  │
│ │  ○ 1  ○ 2  ○ 3  ○ 4  ○ 5                 │  │
│ │  ○ 6  ◉ 7  ○ 8  ○ 9  ○ 10                │  │
│ └───────────────────────────────────────────┘  │
│                                                  │
│ ┌───────────────────────────────────────────┐  │
│ │ 📝 What brought you joy today? (Optional)  │  │
│ │                                             │  │
│ │ Add some notes about your day...            │  │
│ │                                             │  │
│ │                                             │  │
│ └───────────────────────────────────────────┘  │
│                                                  │
│ ┌───────────────────────────────────────────┐  │
│ │              ✓ Save                         │  │
│ └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## In History: Mood Card Badge

Compact intensity display in mood history:

```
┌─────────────────────────────────────────────────┐
│  🌞  Happy                 [7/10]  2:30 PM      │
│      Joyful and positive    ↑                   │
│                         intensity badge          │
│      📝 Tap to view note                        │
└─────────────────────────────────────────────────┘
```

Badge styling:
- Background: Mood color at 15% opacity
- Text: "7" in mood color (bold, 14pt)
- Suffix: "/10" in secondary text (medium, 11pt)
- Padding: 8px horizontal, 4px vertical
- Corner radius: 8pt

---

## Alternative: Bar Style Selector

More compact alternative using bars instead of bubbles:

```
┌─────────────────────────────────────────────────┐
│  Intensity                            7 / 10    │
│                                                  │
│  ▂ ▃ ▄ ▅ ▆ ▆ ▇ █ ▇ ▇                          │
│  1 2 3 4 5 6 7 8 9 10                           │
│              ↑ selected                          │
│                                                  │
│  Subtle ─────────────────────────── Intense     │
└─────────────────────────────────────────────────┘
```

Features:
- Bars grow in height (30pt to 110pt)
- Filled bars (1-7) use full mood color
- Empty bars (8-10) use light gray
- Tap any bar to select
- More compact than bubbles

---

## Accessibility

### VoiceOver Support
- Label: "Intensity selector"
- Value: "7 out of 10, Strong significant"
- Hint: "Tap to select different intensity"
- Each bubble: "Rate intensity 7, Button"

### Dynamic Type
- Text scales with system preferences
- Bubble sizes remain fixed for tap targets
- Minimum 44pt tap target (exceeds Apple's 44x44pt guideline)

### Color Contrast
- Numbers always have sufficient contrast
- Not relying on color alone (size changes too)
- White outline on selected bubble for clarity

---

## Performance

- **Render Time:** < 16ms (60fps)
- **Animation:** Spring-based, no jank
- **State Updates:** Minimal re-renders
- **Memory:** Lightweight, no heavy resources

---

## Comparison to Alternatives

### vs. Slider
✅ Bubbles: Discrete values, fun interaction, clear selection  
❌ Slider: Continuous, harder to select exact value, less engaging

### vs. Stepper
✅ Bubbles: Visual overview, faster selection, better feedback  
❌ Stepper: Linear navigation, slower, less visual

### vs. Number Input
✅ Bubbles: Intuitive, no keyboard needed, visual appeal  
❌ Number Input: Requires keyboard, no visual context, clinical

---

## Design Inspiration

The bubble selector draws inspiration from:
- ⭐ App Store rating bubbles
- 🎨 Color pickers with size/opacity variations
- 🎮 Game difficulty selectors
- 🏋️ Fitness intensity ratings

But maintains Lume's unique warm, calm, and cozy aesthetic.

---

**Status:** ✅ Implemented and ready for user testing