# Mood Tracking UI Visual Guide

**Date:** 2025-01-15  
**Version:** 1.0.0  
**Purpose:** Visual reference for UI improvements

---

## Overview

This guide provides visual descriptions of all UI changes made to the mood tracking feature. Use this as a reference for understanding the design improvements and their rationale.

---

## 1. Mood History Card Redesign

### Before (Old Layout)

```
┌─────────────────────────────────────────────────┐
│  ╭───╮  Happy                    ▮▯▯▯▯  3:45 PM │
│  │ 😊 │  Tap to view note                       │
│  ╰───╯                                           │
│  [50px]                                          │
└─────────────────────────────────────────────────┘
```

**Issues:**
- Icon dominates visual hierarchy
- Time buried at the end
- Hard to scan chronologically
- Too many competing visual elements

### After (New Layout)

```
┌─────────────────────────────────────────────────┐
│  3:45 PM                    ╭───╮      ▮▮▮▯▯   │
│  January 15, 2025           │ 😊 │              │
│                             ╰───╯              │
│  [44px]                                         │
│  📝 Tap to view note                            │
└─────────────────────────────────────────────────┘
```

**Improvements:**
- ✅ Time is primary (large, bold)
- ✅ Date is secondary (small, gray)
- ✅ Icon reduced to 44px (vs 50px)
- ✅ Bar chart at end for quick scan
- ✅ Cleaner, less visually heavy

### Information Hierarchy

```
Priority 1: TIME (17pt, semibold, primary color)
           ↓
Priority 2: DATE (13pt, regular, secondary color)
           ↓
Priority 3: ICON (44px circle, mood color)
           ↓
Priority 4: BAR CHART (36×24px, valence indicator)
           ↓
Priority 5: NOTE INDICATOR (if present)
```

**Design Rationale:**
- Users scan for "when" first, then "what"
- Vertical text layout reduces horizontal eye movement
- Icon provides color context without dominating
- Bar chart offers instant valence reading

---

## 2. Valence Bar Chart Enhancement

### Before (Low Contrast)

```
Individual Bar:
┌───┐
│   │ ← Filled: 70% opacity
└───┘    Unfilled: 30% opacity
         No border
```

**Issues:**
- Bars blend with background
- Hard to distinguish filled vs unfilled
- No visual definition

### After (High Contrast)

```
Individual Bar:
╔═══╗
║███║ ← Filled: Color + 40% border
╚═══╝    Unfilled: 25% opacity + gray border
         Clear definition
```

**Improvements:**
- ✅ Subtle borders on all bars
- ✅ Better opacity contrast (25% vs 30%)
- ✅ Stroke borders for definition
- ✅ Filled bars have color-matched borders

### Full Chart Comparison

```
Before:  ▯ ▯ ▮ ▯ ▯  (Hard to read)

After:   ▯̲ ▯̲ ▮̲ ▯̲ ▯̲  (Clear, defined)
```

---

## 3. Dashboard Chart Enhancements

### Before (Blended Background)

```
┌───────────────────────────────────────────┐
│ [Chart rendered directly on page bg]      │
│                                            │
│   ╱──────╲                                │
│  ╱        ╲                               │
│ ╱          ╲────                          │
│                                            │
│ Low contrast, blends with background      │
└───────────────────────────────────────────┘
```

**Issues:**
- Chart blends with page background (#F8F4EC)
- Lines too thin (2pt)
- Area gradient too subtle
- Points blend in
- Grid lines barely visible

### After (White Panel Background)

```
┌───────────────────────────────────────────┐
│ ╔═══════════════════════════════════════╗ │
│ ║ [White background panel with shadow]  ║ │
│ ║                                       ║ │
│ ║   ╱━━━━━━╲                           ║ │
│ ║  ╱        ╲                          ║ │
│ ║ ●          ●━━━━●                    ║ │
│ ║                                       ║ │
│ ║ Strong contrast, clear visibility    ║ │
│ ╚═══════════════════════════════════════╝ │
└───────────────────────────────────────────┘
```

**Improvements:**
- ✅ White (#FFFFFF) background panel
- ✅ Subtle shadow for depth
- ✅ Thicker lines (2.5pt vs 2pt)
- ✅ Stronger gradient (30% → 8% vs 20% → 5%)
- ✅ Larger points with white borders
- ✅ Darker axis labels
- ✅ More visible grid lines

### Chart Element Details

```
LINE:
  Before: rgba(216,200,234, 0.5) @ 2pt
  After:  rgba(216,200,234, 0.8) @ 2.5pt
  
AREA GRADIENT:
  Before: 20% → 5% opacity
  After:  30% → 8% opacity
  
POINTS:
  Before: 200px size, solid color
  After:  250px size, white 2pt border
  
GRID LINES:
  Before: 20% opacity
  After:  30% opacity
  
AXIS LABELS:
  Before: textSecondary
  After:  textPrimary @ 70% opacity
```

---

## 4. FAB (Floating Action Button) Spacing

### Before (Overlapping)

```
┌─────────────────────────────────────┐
│ 3:30 PM                             │
│ January 15                          │
│                                     │
├─────────────────────────────────────┤
│ 2:15 PM                    ╭────╮  │ ← FAB covers
│ January 15                 │ +  │  │   last entry
└────────────────────────────╰────╯──┘
     Last entry not fully visible
```

**Issue:** Users can't tap last entry

### After (Proper Spacing)

```
┌─────────────────────────────────────┐
│ 3:30 PM                             │
│ January 15                          │
│                                     │
├─────────────────────────────────────┤
│ 2:15 PM                             │
│ January 15                          │
├─────────────────────────────────────┤
│                                     │ ← 80px spacer
│             ╭────╮                  │
│             │ +  │ FAB             │
└─────────────╰────╯─────────────────┘
     Last entry fully accessible
```

**Solution:**
```swift
Color.clear
    .frame(height: 80)
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
```

---

## 5. Color Contrast Specifications

### Dashboard Chart Background

```
Component Stack:
┌─────────────────────────────────────┐
│ App Background: #F8F4EC (cream)     │
│                                     │
│  ┌───────────────────────────────┐  │
│  │ Chart Panel: #FFFFFF (white) │  │
│  │ Shadow: rgba(59,51,44, 0.08) │  │
│  │ Radius: 4pt, Y-offset: 2pt   │  │
│  │                               │  │
│  │ [Chart content here]          │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘

Contrast Ratio:
- Chart on White: ~21:1 (AAA)
- White on Cream: ~1.1:1 (subtle depth)
```

### Text Contrast

```
On White Background:
  Primary Text (#3B332C):    ~12:1 (AAA)
  Secondary Text (#6E625A):  ~5:1 (AA)
  Axis Labels (70% opacity): ~8:1 (AAA)
  
On Cream Background (#F8F4EC):
  Primary Text (#3B332C):    ~10:1 (AAA)
  Secondary Text (#6E625A):  ~4:1 (AA+)
```

---

## 6. Typography Scale

### History Card Text Hierarchy

```
┌────────────────────────────────────┐
│  3:45 PM        ← Body (17pt, semibold, #3B332C)
│  January 15     ← Caption (13pt, regular, #6E625A)
│                                    │
│  📝 Tap to view note               │
│     └─ Small (13pt, italic, #6E625A)
└────────────────────────────────────┘

Font: SF Pro Rounded
Line Height: 1.2 (generous spacing)
Letter Spacing: Default (comfortable reading)
```

### Dashboard Chart Labels

```
Title:       TitleMedium (22pt, semibold)
Axis Labels: Caption (13pt, regular, 70% opacity)
Y-Values:    Caption (13pt, regular)
Legend:      BodySmall (15pt, regular)
```

---

## 7. Spacing & Layout

### History Card Padding

```
┌─16pt─────────────────────────16pt─┐
│                                   │ 12pt
│  TIME/DATE    ICON    CHART       │
│                                   │ 12pt
│  NOTE INDICATOR                   │
│                                   │ 16pt
└───────────────────────────────────┘

Card Background: Surface (#E8DFD6)
Corner Radius: 16pt
Shadow: rgba(59,51,44, 0.05), radius 8pt
```

### Dashboard Chart Panel

```
┌─20pt─────────────────────────20pt─┐
│                                   │ 24pt
│  ┌─16pt───────────────────16pt─┐  │
│  │                             │  │ 16pt
│  │  [CHART AREA]               │  │
│  │                             │  │ 16pt
│  └─────────────────────────────┘  │
│                                   │ 24pt
└───────────────────────────────────┘

Chart Panel: White (#FFFFFF)
Corner Radius: 12pt
Shadow: rgba(59,51,44, 0.08), radius 4pt
```

---

## 8. Animation & Transitions

### History Card Expansion

```
Collapsed:
┌─────────────────────────────────────┐
│  3:45 PM          📝 Tap to view    │
└─────────────────────────────────────┘

         ↓ (easeInOut, 0.3s)

Expanded:
┌─────────────────────────────────────┐
│  3:45 PM                            │
│                                     │
│  Had a great day with friends at    │
│  the park. Felt really connected.   │
└─────────────────────────────────────┘

Duration: 0.3 seconds
Easing: easeInOut
Property: note text opacity + height
```

### Chart Animations

```
Bar Chart:
  Entry animation: spring(0.4, 0.7)
  Stagger delay: 0.05s per bar
  Scale from: y = 0 (bottom anchor)
  
Line Chart:
  On appear: fade + draw (0.5s)
  On selection: highlight (0.2s)
  Points: scale pulse on tap
```

---

## 9. Accessibility Considerations

### VoiceOver Labels

```
History Card:
  "Mood entry from 3:45 PM, January 15th, 2025.
   Feeling happy with valence 0.6.
   Has note. Double tap to expand."

Bar Chart:
  "Valence indicator showing 3 out of 5 bars filled.
   Representing positive mood at 0.6."

Dashboard Chart:
  "Mood timeline chart showing 7 entries over the past week.
   Average valence: 0.4. Double tap for details."
```

### Dynamic Type Support

```
All text scales with user preferences:
  - Body: 17pt → 28pt (max)
  - Caption: 13pt → 23pt (max)
  - Minimum contrast maintained at all sizes
  - Layout adapts to larger text
```

---

## 10. Design System Compliance

### Color Usage

```
✅ App Background: #F8F4EC (warm cream)
✅ Surface: #E8DFD6 (elevated cards)
✅ Chart Panel: #FFFFFF (contrast boost)
✅ Primary Accent: #F2C9A7 (buttons, highlights)
✅ Secondary Accent: #D8C8EA (charts, data viz)
✅ Text Primary: #3B332C (headings, body)
✅ Text Secondary: #6E625A (supporting text)
```

### Typography

```
✅ SF Pro Rounded (system font family)
✅ Comfortable line heights (1.2-1.5)
✅ Generous spacing between elements
✅ Size scale: 28pt → 22pt → 17pt → 15pt → 13pt
```

### Mood Colors (Used in Charts)

```
Ecstatic:  #FFE4B5 (valence: 1.0)
Happy:     #F5DFA8 (valence: 0.8)
Content:   #D8C8EA (valence: 0.5)
Calm:      #B8D4E8 (valence: 0.3)
Neutral:   #E8D9C8 (valence: 0.0)
Anxious:   #C8B4D8 (valence: -0.3)
Sad:       #E8D9C8 (valence: -0.5)
Stressed:  #D8C8C8 (valence: -0.7)
Unpleasant:#F0B8A4 (valence: -0.8)
```

---

## Summary

All visual changes maintain Lume's **warm, calm, and non-judgmental** design principles while significantly improving:

1. **Information hierarchy** - Time-first layout for better scanning
2. **Visual contrast** - White chart panels and stronger colors
3. **Definition** - Borders and shadows for clear element separation
4. **Accessibility** - Better contrast ratios and VoiceOver support
5. **Polish** - Smooth animations and generous spacing

The result is a cleaner, more readable, and more professional mood tracking experience that feels both **modern and cozy**.

---

**For Developers:** Use this guide when implementing similar patterns elsewhere in the app.  
**For Designers:** Reference these specifications when creating new mood-related features.  
**For QA:** Validate all measurements and behaviors against this guide.