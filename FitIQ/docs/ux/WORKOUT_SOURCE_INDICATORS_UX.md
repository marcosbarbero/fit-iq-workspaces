# Workout Source Indicators UX

**Version:** 1.0.0  
**Last Updated:** 2025-01-28  
**Status:** ✅ Implemented  
**Feature:** Visual indicators for workout data sources (FitIQ app vs. Apple Watch/HealthKit)

---

## 📋 Overview

This document specifies the UX design for visual indicators that distinguish between workouts logged directly in the FitIQ app versus workouts imported from Apple Watch/HealthKit. The design ensures users can quickly identify the source of each workout entry and understand the available actions (editable vs. read-only).

---

## 🎯 Design Goals

1. **Clear Source Identification** - Users should immediately know if a workout came from their Apple Watch or was logged in FitIQ
2. **Visual Consistency** - Follow established color profile (Vitality Teal for fitness activities)
3. **Accessible Design** - Icons, colors, and labels work together for clarity
4. **Contextual Actions** - Different sources enable different actions (edit/delete vs. hide)
5. **Subtle but Noticeable** - Indicators are prominent without overwhelming the interface

---

## 🎨 Visual Design

### Color Usage

Following the [COLOR_PROFILE.md](./COLOR_PROFILE.md) specification:

| Element | FitIQ App Logged | Apple Watch/HealthKit |
|---------|------------------|----------------------|
| **Primary Color** | Vitality Teal (`#00C896`) | Secondary Gray |
| **Background Circle** | Vitality Teal (15% opacity) | Tertiary System Fill |
| **Icon Color** | Vitality Teal | Secondary Gray |
| **Badge Color** | Vitality Teal (15% bg) | Tertiary System Fill |
| **Text Color** | Vitality Teal | Secondary Gray |

### Icons

| Source | Icon | SF Symbol | Rationale |
|--------|------|-----------|-----------|
| **FitIQ App** | 📱 | `appclip` | Represents app-originated data; editable |
| **Apple Watch** | ⌚ | `applewatch` | Represents HealthKit import; read-only |

**Note:** In detail views, `inset.filled.applewatch.case` is used in the navigation bar for a filled variant.

---

## 📱 UI Components

### 1. CompletedWorkoutRow (List View)

**Location:** `WorkoutView.swift` → "Completed Sessions" section

#### Layout Structure

```
┌─────────────────────────────────────────────────────────┐
│  ┌────┐  Workout Name                          Jan 28   │
│  │ 📱 │  ⏱️ 45 min     🔥 425 kcal          [FitIQ]     │
│  └────┘                                                  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ┌────┐  Morning Run                           Jan 28   │
│  │ ⌚ │  ⏱️ 32 min     🔥 280 kcal          [Watch]     │
│  └────┘                                                  │
└─────────────────────────────────────────────────────────┘
```

#### Component Specifications

**Left Icon Circle:**
- Size: 44x44 pt
- Background: Circle fill
  - FitIQ: Vitality Teal 15% opacity
  - Watch: Tertiary System Fill
- Icon: 20pt system size
  - FitIQ: `appclip` in Vitality Teal
  - Watch: `applewatch` in Secondary Gray
- Purpose: Primary visual indicator

**Top Row:**
- Left: Workout name (Body weight, Semibold, Primary color)
- Right: Date (Caption, Secondary color)
- Alignment: firstTextBaseline with 8pt spacing

**Bottom Row:**
- Duration: Label with `clock.fill` icon (Subheadline, Secondary)
- Calories: Label with `flame.fill` icon (Subheadline, Vitality Teal, Medium weight)
- Source Badge: Capsule pill
  - Text: "FitIQ" or "Watch"
  - Font: Caption2, Medium weight
  - Padding: 8pt horizontal, 3pt vertical
  - Background: 
    - FitIQ: Vitality Teal 15% opacity
    - Watch: Tertiary System Fill
  - Color:
    - FitIQ: Vitality Teal
    - Watch: Secondary Gray

**Row Dimensions:**
- Vertical padding: 14pt (increased for better tap targets)
- Horizontal padding: 16pt
- Corner radius: 12pt
- Background: Secondary System Background

### 2. CompletedWorkoutDetailView (Detail View)

**Location:** `CompletedWorkoutDetailView.swift` → Navigation bar

#### Toolbar Title

```
┌─────────────────────────────────────────────────────────┐
│ Close    📱 Workout Name                                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Close    ⌚ Morning Run                                   │
└─────────────────────────────────────────────────────────┘
```

**Specifications:**
- Icon: `appclip` or `inset.filled.applewatch.case`
- Icon size: System default for navigation bar
- Color:
  - FitIQ: Vitality Teal
  - Watch: Secondary Gray
- Spacing: 8pt between icon and title
- Title: Headline weight, Bold, line limit 1

---

## 🔄 User Interactions

### Swipe Actions (Conditional)

#### FitIQ App Logged Workouts (Editable)

**Left Swipe (Trailing):**
- ❌ **Delete** (Red, destructive role)
- ✏️ **Edit** (Ascend Blue)

**Rationale:** User-created data supports full CRUD operations

#### Apple Watch/HealthKit Imported (Read-Only)

**Left Swipe (Trailing):**
- 👁️‍🗨️ **Hide** (System Gray)

**Rationale:** HealthKit data is immutable; users can only hide unwanted entries

### Tap Behavior

**List Row:** Tap to open `CompletedWorkoutDetailView` sheet
- Shows full workout details
- Displays performance charts
- Provides contextual actions based on source

---

## ♿ Accessibility

### VoiceOver Support

**FitIQ App Logged:**
```
"Workout Name, 45 minutes, 425 calories burned, logged in FitIQ app. 
Actions available: Edit, Delete."
```

**Apple Watch Imported:**
```
"Morning Run, 32 minutes, 280 calories burned, synced from Apple Watch. 
Read-only. Actions available: Hide."
```

### Dynamic Type

All text scales with iOS Dynamic Type settings:
- Workout name: Body (scales)
- Date: Caption (scales)
- Duration/Calories: Subheadline (scales)
- Source badge: Caption2 (scales)

### High Contrast Mode

In High Contrast mode:
- Icon circles use stronger borders
- Badge backgrounds have increased opacity
- Text contrast meets WCAG AA standards

### Color Blind Support

The design doesn't rely on color alone:
- ✅ Different icons (`appclip` vs `applewatch`)
- ✅ Text labels ("FitIQ" vs "Watch")
- ✅ Different swipe actions available

---

## 📐 Layout Specifications

### Spacing

| Element | Value | Purpose |
|---------|-------|---------|
| Icon circle size | 44x44 pt | Standard tap target |
| Icon-to-content gap | 12pt | Visual separation |
| Top row vertical spacing | 6pt | Compact grouping |
| Bottom row item spacing | 12pt | Breathing room |
| Horizontal padding | 16pt | Consistent margins |
| Vertical padding | 14pt | Better tap targets |

### Typography

| Element | Font | Size | Weight | Color |
|---------|------|------|--------|-------|
| Workout name | SF Pro | Body (17pt) | Semibold | Primary |
| Date | SF Pro | Caption (12pt) | Regular | Secondary |
| Duration | SF Pro | Subheadline (15pt) | Regular | Secondary |
| Calories | SF Pro | Subheadline (15pt) | Medium | Vitality Teal |
| Source badge | SF Pro | Caption2 (11pt) | Medium | Context-dependent |

### Colors (Reference)

| Color Name | Light Mode | Dark Mode | Usage |
|------------|------------|-----------|-------|
| Vitality Teal | `#00C896` | `#00C896` | FitIQ app indicators |
| Secondary Gray | System | System | Watch indicators |
| Primary | System Black | System White | Workout name |
| Secondary | System Gray | System Gray | Metadata text |

---

## 🎬 Animation Specifications

### Row Appearance

- **Fade in:** 0.3s ease-out
- **Slide up:** 0.3s ease-out with 8pt offset
- **Stagger:** 0.05s delay between rows

### Icon Interaction

- **Tap:** Scale to 0.95 (0.1s)
- **Release:** Spring animation back to 1.0
- **Haptic:** Light impact feedback

### Swipe Actions

- **Reveal:** Follows iOS standard swipe behavior
- **Delete confirm:** Red overlay with 0.2s fade
- **Edit sheet:** Modal presentation with slide up

---

## 📊 Usage Guidelines

### When to Use Each Indicator

| Scenario | Source | Indicator |
|----------|--------|-----------|
| User logs workout in FitIQ app | `WorkoutSource.appLogged` | 📱 FitIQ (Teal) |
| Workout synced from Apple Watch | `WorkoutSource.healthKitImport` | ⌚ Watch (Gray) |
| Workout manually entered in Health app | `WorkoutSource.healthKitImport` | ⌚ Watch (Gray) |
| Workout from third-party fitness app | `WorkoutSource.healthKitImport` | ⌚ Watch (Gray) |

**Note:** All HealthKit-sourced workouts use the Watch indicator, regardless of the specific source app.

### Developer Implementation

```swift
// Check workout source
private var isAppLogged: Bool { 
    log.source == .appLogged 
}

// Icon selection
Image(systemName: isAppLogged ? "appclip" : "applewatch")

// Color selection
.foregroundColor(isAppLogged ? primaryColor : .secondary)

// Background selection
.fill(isAppLogged ? primaryColor.opacity(0.15) : Color(.tertiarySystemFill))

// Badge text
Text(isAppLogged ? "FitIQ" : "Watch")
```

---

## 🔍 Edge Cases

### Multiple Workouts Same Time

If a user logs a workout in FitIQ and also has HealthKit data for the same time:
- Both appear in the list
- Each shows its own source indicator
- User can identify and manage duplicates

### Missing Source Data

If `source` field is nil/unknown:
- Default to HealthKit indicator (safer assumption)
- Log warning for debugging
- Treat as read-only to prevent data loss

### Partial Sync

During HealthKit sync:
- Show loading indicator on "Sync" button
- Gray out workout rows during sync
- Update source indicators after sync completes

---

## 🧪 Testing Checklist

### Visual Testing

- [ ] FitIQ workouts show teal icon and badge
- [ ] Watch workouts show gray icon and badge
- [ ] Icons are clearly visible in Light Mode
- [ ] Icons are clearly visible in Dark Mode
- [ ] Badge text is readable at all sizes
- [ ] Layout doesn't break with long workout names

### Interaction Testing

- [ ] Tapping row opens detail view
- [ ] FitIQ workouts show Edit/Delete swipe actions
- [ ] Watch workouts show Hide swipe action
- [ ] VoiceOver announces source correctly
- [ ] Swipe actions work smoothly

### Accessibility Testing

- [ ] VoiceOver reads source information
- [ ] Dynamic Type scales all text
- [ ] High Contrast mode increases visibility
- [ ] Color blind users can distinguish sources
- [ ] Tap targets are at least 44x44 pt

---

## 📈 Success Metrics

### User Comprehension

- Users can identify workout source within 1 second
- <5% confusion rate about which workouts are editable
- Zero reports of accidentally deleting HealthKit data

### Visual Clarity

- Source indicators visible in all lighting conditions
- Icons recognizable at standard viewing distance
- Badge text readable without zooming

### Accessibility

- VoiceOver users can navigate workout list efficiently
- Dynamic Type users report no truncation issues
- High Contrast users report clear visibility

---

## 🚀 Future Enhancements

### Possible Improvements

1. **Source Details**
   - Show specific HealthKit source app (Strava, Nike Run Club, etc.)
   - Add tooltip on long-press for source information
   - Display sync timestamp

2. **Advanced Filtering**
   - Filter view by source (FitIQ only, Watch only, All)
   - Sort by source in workout list
   - Batch hide HealthKit workouts

3. **Visual Variations**
   - Different icon styles for different activity types
   - Custom icons for third-party app sources
   - Animated indicators for recently synced workouts

4. **Integration Points**
   - Link to HealthKit source app
   - Quick re-log HealthKit workout in FitIQ
   - Merge duplicate workouts interface

---

## 📚 Related Documentation

- [COLOR_PROFILE.md](./COLOR_PROFILE.md) - Color system specification
- [Copilot Instructions](../../.github/copilot-instructions.md) - Development guidelines
- [Backend API Spec](../be-api-spec/swagger.yaml) - API contracts for workout data
- [WORKOUT_HEALTHKIT_SYNC_FIX.md](../WORKOUT_HEALTHKIT_SYNC_FIX.md) - HealthKit sync implementation

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-28 | Initial UX specification with source indicators |

---

**Status:** ✅ Implemented  
**Last Review:** 2025-01-28  
**Next Review:** After user feedback collection