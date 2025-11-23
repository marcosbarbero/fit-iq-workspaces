# Mood Entry Visual Guide

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Purpose:** Visual mockups of the redesigned mood entry UI

---

## 📱 Full Screen Layout

```
┌─────────────────────────────────────┐
│ ← Cancel    Daily Check-In          │
├─────────────────────────────────────┤
│                                     │
│     How are you feeling?            │
│                                     │
│          ╱─────────╲                │
│         ╱           ╲               │
│        │             │              │
│        │     🤩      │              │
│        │             │              │
│        │      9      │  ◀─ Score    │
│        │             │              │
│        │  Excellent  │  ◀─ Label    │
│        │             │              │
│         ╲           ╱               │
│          ╲─────────╱                │
│                                     │
│   ━━━━━━━━━━━━━━━━━━━●━━━━━━       │
│   Very Bad         Excellent        │
│                                     │
│ ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ │
│                                     │
│  What emotions are you feeling?     │
│  Tap to select (optional)  3 selected│
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐           │
│  │ 😊  │ │ 😢  │ │ 😰  │           │
│  │Happy│ │ Sad │ │Anxious│         │
│  └─────┘ └─────┘ └─────┘           │
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐           │
│  │ 🍃  │ │ ⚡  │ │ 🔋  │           │
│  │Calm │ │Energetic│Tired│         │
│  └─────┘ └─────┘ └─────┘           │
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐           │
│  │ 😤  │ │ 😌  │ │ 😡  │           │
│  │Stressed│Relaxed│Angry│          │
│  └─────┘ └─────┘ └─────┘           │
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐           │
│  │ ✅  │ │ ❌  │ │ ⭐  │           │
│  │Content│Frustrated│Motivated│    │
│  └─────┘ └─────┘ └─────┘           │
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐           │
│  │ 📚  │ │ 🌙  │ │ ✨  │           │
│  │Overwhelmed│Peaceful│Excited│    │
│  └─────┘ └─────┘ └─────┘           │
│                                     │
│ ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ │
│                                     │
│  Add a note (optional)              │
│  ┌─────────────────────────────┐   │
│  │ What's on your mind?        │   │
│  │                             │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                          0/500 ─┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │     ✓  Log Mood             │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

---

## 🎯 Component Details

### 1. Circular Progress Dial

**Neutral State (Score: 5)**
```
          ╱─────────╲
         ╱     😐     ╲
        │              │
        │      5       │  ← Serenity Lavender (#B58BEF)
        │              │
        │   Neutral    │
         ╲           ╱
          ╲─────────╱
         
Ring: 50% filled (gray background)
Color: Lavender gradient
```

**Excellent State (Score: 9)**
```
          ╱─────────╲
         ╱     🤩     ╲
        │              │
        │      9       │  ← Large, bold
        │              │
        │  Excellent   │  ← Subtitle
         ╲           ╱
          ╲─────────╱
         
Ring: 90% filled
Color: Bright lavender gradient
Shadow: Soft glow effect
```

**Very Bad State (Score: 2)**
```
          ╱─────────╲
         ╱     😢     ╲
        │              │
        │      2       │
        │              │
        │  Very Bad    │
         ╲           ╱
          ╲─────────╱
         
Ring: 20% filled
Color: Muted lavender
```

---

### 2. Emotion Chips

**Unselected State**
```
┌─────────────┐
│   SF Symbol │  ← Gray (.systemGray6)
│             │
│  Emotion    │  ← Primary text color
└─────────────┘
```

**Selected State**
```
┌═════════════┐
║   SF Symbol ║  ← White icon
║             ║     Lavender gradient background
║  Emotion    ║  ← White text
╚═════════════╝
    ▼ Shadow
```

**Example Grid Layout**
```
Row 1:
┌─────┐ ┌─────┐ ┌─────┐
│ 😊  │ │ 😢  │ │ 😰  │
│Happy│ │ Sad │ │Anxious│
└─────┘ └─────┘ └─────┘

Row 2:
┌─────┐ ┌─────┐ ┌─────┐
│ 🍃  │ │ ⚡  │ │ 🔋  │
│Calm │ │Energetic│Tired│
└─────┘ └─────┘ └─────┘

... (5 rows total)
```

---

### 3. Slider with Labels

```
┌────────────────────────────────┐
│                                │
│   ━━━━━━━━━━━━━━●━━━━━━       │  ← Lavender tint
│                                │
└────────────────────────────────┘
Very Bad               Excellent
   ↑                      ↑
Min (1)               Max (10)
```

---

### 4. Notes Section

**Empty State**
```
Add a note (optional)

┌──────────────────────────────┐
│ What's on your mind?         │  ← Placeholder (gray)
│                              │
│                              │
└──────────────────────────────┘
                        0/500 ─┘
```

**With Content**
```
Add a note (optional)

┌──────────────────────────────┐
│ Had a great workout today,   │  ← User text (black)
│ feeling really energized!    │
│                              │
└──────────────────────────────┘
                       48/500 ─┘  ← Character count
```

**Over Limit**
```
Add a note (optional)

┌──────────────────────────────┐
│ Lorem ipsum dolor sit amet,  │
│ consectetur adipiscing elit. │
│ ... (lots of text)           │
└──────────────────────────────┘
                      512/500 ─┘  ← Red text!
```

---

### 5. Save Button

**Enabled State**
```
┌═══════════════════════════════┐
║    ✓  Log Mood                ║  ← White text
╚═══════════════════════════════╝
      ▼ Shadow                       Lavender gradient
```

**Disabled State**
```
┌───────────────────────────────┐
│    ✓  Log Mood                │  ← Gray text
└───────────────────────────────┘
                                    Gray background
```

**Loading State**
```
┌═══════════════════════════════┐
║    ⊙  Loading...              ║  ← White spinner
╚═══════════════════════════════╝
      ▼ Shadow                       Lavender gradient
```

---

### 6. Error Message

```
┌─────────────────────────────────────┐
│ ⚠️ Notes cannot exceed 500 chars [Dismiss] │
└─────────────────────────────────────┘
   Red background (.red.opacity(0.1))
```

---

### 7. Success Alert

```
┌─────────────────────────────┐
│         Success             │
│                             │
│  Your mood has been logged  │
│  successfully!              │
│                             │
│  ┌─────────────────────┐   │
│  │         OK          │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

---

## 🎨 Color Specifications

### Primary Color: Serenity Lavender

```
Hex: #B58BEF
RGB: (181, 139, 239)
HSL: (267°, 74%, 74%)

Usage:
- Progress dial ring
- Selected emotion chips
- CTA button background
- Slider tint
- Focus states
```

### Supporting Colors

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| **Background** | #FFFFFF | #1C1C1E |
| **Text Primary** | #000000 | #FFFFFF |
| **Text Secondary** | #8E8E93 | #8E8E93 |
| **Chip Unselected BG** | #F2F2F7 | #2C2C2E |
| **Chip Selected BG** | #B58BEF | #B58BEF |
| **Error BG** | #FF3B3010 | #FF3B3020 |
| **Error Text** | #FF3B30 | #FF453A |

---

## 📐 Layout Specifications

### Spacing

```
Vertical Spacing:
- Section padding: 30pt
- Component spacing: 20pt
- Label to input: 10pt
- Grid row spacing: 10pt

Horizontal Spacing:
- Screen padding: 25pt
- Grid column spacing: 10pt
- Chip internal padding: 8pt (horizontal), 12pt (vertical)
```

### Typography

```
Navigation Title: .inline
Section Headers: .headline (17pt, semibold)
Score Number: 44pt, heavy, rounded
Score Label: .subheadline (15pt, medium)
Emoji: 64pt
Emotion Label: .caption2 (11pt, medium)
Notes Placeholder: .body (17pt)
Character Count: .caption2 (11pt)
Button: .headline (17pt, semibold)
```

### Component Sizes

```
Progress Dial:
- Outer diameter: 240pt
- Ring width: 12pt

Emotion Chips:
- Height: ~70pt (flexible)
- Width: (screenWidth - 70pt) / 3
- Icon size: 24pt
- Border radius: 12pt

Notes Field:
- Min height: 100pt
- Max height: unlimited (scrollable)

CTA Button:
- Height: 48pt (16pt padding vertical)
- Width: Full width - 50pt
- Border radius: 14pt
```

---

## 🎭 Interaction States

### Mood Score Slider

```
State 1: Touching
━━━━━━━━━━━━━━━━━━━●━━━━━━
                    ↑
               Haptic feedback!

State 2: Changed
━━━━━━━━━━━━━━━━━━●━━━━━━━
                   ↑
          Emoji + label update
          (0.3s spring animation)
```

### Emotion Chip

```
State 1: Tap (Unselected → Selected)
┌─────┐        ┌═════┐
│ 😊  │   →    ║ 😊  ║  (0.2s ease)
│Happy│        ║Happy║  + Haptic feedback (soft)
└─────┘        ╚═════╝
                  ▼ Shadow appears

State 2: Tap (Selected → Unselected)
┌═════┐        ┌─────┐
║ 😊  ║   →    │ 😊  │  (0.2s ease)
║Happy║        │Happy│  + Haptic feedback (soft)
╚═════╝        └─────┘
  ▼ Shadow fades
```

### Save Button

```
State 1: Idle (Enabled)
┌═══════════════════════════════┐
║    ✓  Log Mood                ║
╚═══════════════════════════════╝
      ▼ Shadow (lavender)

State 2: Pressed
┌═══════════════════════════════┐
║    ✓  Log Mood                ║  (0.1s scale: 0.98)
╚═══════════════════════════════╝
      ▼ Shadow (reduced)

State 3: Loading
┌═══════════════════════════════┐
║    ⊙  Loading...              ║  (spinner animation)
╚═══════════════════════════════╝
      ▼ Shadow (lavender)

State 4: Success (then dismiss)
Alert appears → User taps OK → View dismisses
```

---

## 📱 Responsive Behavior

### Landscape Orientation

```
┌─────────────────────────────────────────────────────┐
│ ← Cancel    Daily Check-In                          │
├────────────────────┬────────────────────────────────┤
│                    │                                │
│   ╱─────────╲      │  What emotions are you feeling?│
│  ╱     🤩     ╲    │                                │
│ │      9       │   │  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐│
│ │  Excellent   │   │  │😊 │ │😢 │ │😰 │ │🍃 │ │⚡ ││
│  ╲           ╱     │  └───┘ └───┘ └───┘ └───┘ └───┘│
│   ╲─────────╱      │                                │
│                    │  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐│
│ ━━━━━━━━●━━━━━━    │  │🔋 │ │😤 │ │😌 │ │😡 │ │✅ ││
│                    │  └───┘ └───┘ └───┘ └───┘ └───┘│
│                    │                                │
│                    │  ┌───┐ ┌───┐ ┌───┐            │
│                    │  │❌ │ │⭐ │ │📚 │ ...       │
│                    │  └───┘ └───┘ └───┘            │
│                    │                                │
│                    │  Add a note (optional)         │
│                    │  ┌─────────────────────┐      │
│                    │  │ What's on your mind?│      │
│                    │  └─────────────────────┘      │
└────────────────────┴────────────────────────────────┘
```

**Adapts to:**
- 2-column layout (dial left, emotions/notes right)
- 5-column emotion grid
- Maintains tap targets (44pt minimum)

---

## ♿ Accessibility Features

### VoiceOver Labels

```
Progress Dial:
"Mood score, 9 out of 10, Excellent. Adjustable."

Slider:
"Mood score, 9, Excellent. Swipe up or down to adjust value."

Emotion Chip (Unselected):
"Happy, button, not selected. Double-tap to select."

Emotion Chip (Selected):
"Happy, button, selected. Double-tap to deselect."

Notes Field:
"Add a note, text editor, optional. What's on your mind?"

Character Count:
"48 characters out of 500"

Save Button:
"Log Mood, button, enabled"
```

### Dynamic Type Support

```
Small (contentSizeCategory = .small):
Emoji: 56pt
Score: 38pt
Labels: Proportionally smaller

Large (contentSizeCategory = .xxxLarge):
Emoji: 80pt
Score: 56pt
Labels: Proportionally larger
Minimum scale factor: 0.8 on emotion labels
```

### High Contrast Mode

```
Standard Mode:
- Emotion chip border: None (solid background)
- Selected chip: Lavender gradient

High Contrast Mode:
- Emotion chip border: 2pt solid (increased visibility)
- Selected chip: Solid lavender + thicker border
- Progress dial: Thicker ring (14pt → 16pt)
```

---

## 🎬 Animation Specifications

### Score Change Animation

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: score)
```

**Behavior:**
- Emoji transitions smoothly (0.3s spring)
- Number uses `.contentTransition(.numericText())`
- Label fades and scales (0.2s ease-in-out)

### Emotion Selection Animation

```swift
.animation(.easeInOut(duration: 0.2), value: isSelected)
```

**Behavior:**
- Background color transition (0.2s)
- Shadow appears/disappears (0.2s)
- Scale effect on tap (0.1s to 0.98)

### Progress Ring Animation

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
```

**Behavior:**
- Ring fills smoothly as slider moves
- Spring effect on release
- Color interpolates from muted to bright lavender

---

## 📊 Performance Considerations

### Rendering Optimization

```
Emotion Grid:
- LazyVGrid (only renders visible cells)
- 15 emotions total (lightweight)
- No complex calculations

Progress Dial:
- SwiftUI shape primitives (GPU-accelerated)
- Single trim animation
- No custom drawing

Notes Field:
- Standard TextEditor (optimized by Apple)
- Character count updates on change (O(1) operation)
```

### Memory Usage

```
View State:
- moodScore: Int (8 bytes)
- selectedEmotions: Set<String> (~240 bytes max)
- notes: String (~4KB max)

Total: ~4.5KB per entry (negligible)
```

---

## ✅ Design Checklist

- [x] Follows iOS Human Interface Guidelines
- [x] Uses Serenity Lavender from COLOR_PROFILE.md
- [x] Meets WCAG AA contrast standards
- [x] Supports Dynamic Type
- [x] Supports VoiceOver
- [x] Supports High Contrast Mode
- [x] Supports Dark Mode
- [x] Minimum tap target: 44pt
- [x] Smooth animations (<0.3s)
- [x] Haptic feedback on interactions
- [x] Clear visual hierarchy
- [x] Consistent spacing/padding
- [x] Error states handled
- [x] Loading states handled
- [x] Success states handled

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-27  
**Designer:** AI Assistant  
**Status:** ✅ Ready for Implementation Review