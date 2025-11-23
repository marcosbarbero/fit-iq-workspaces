# Lume Mood Tracking UX Design

**Version:** 3.0.0  
**Date:** January 15, 2025  
**Design:** Original Phased Interaction Pattern

---

## Design Philosophy

This mood tracking experience is **completely original to Lume** - not a copy of any existing app. Every interaction is designed to be:

- **Phased** - One focused step at a time
- **Gentle** - Soft animations and warm colors
- **Light** - No dark colors, only warm tones from our palette
- **Clear** - Each screen has one clear purpose
- **Optional** - Deep reflection is encouraged, never required

---

## User Flow

### Phase 1: Main Screen (History + FAB)

**Purpose:** Show mood history and provide entry point for new tracking

**Layout:**
- Navigation title: "Mood"
- Content area: Scrollable list of mood history cards
- Bottom right: Floating Action Button (FAB) with "Track Mood" text

**FAB Design:**
- Background: `LumeColors.accentPrimary` (warm peach)
- Icon: Plus symbol
- Label: "Track Mood"
- Shadow: Subtle drop shadow for elevation
- Position: Fixed bottom-right, 20pt padding

**Empty State:**
- Centered icon (sun symbol) in light circle
- "Start your journey" title
- Descriptive text
- Arrow pointing down to FAB
- Spacious, welcoming layout

**Why FAB?**
- Always accessible (no hiding in sheets)
- Clear call-to-action
- Modern iOS pattern
- Doesn't obstruct content
- No swipe conflicts

---

### Phase 2: Mood Selection

**Purpose:** Choose your current mood - focused, uncluttered

**Navigation:** Push navigation (NOT sheet) to avoid swipe conflicts

**Layout:**
- Title: "How are you feeling?"
- Subtitle: "Choose what resonates with you"
- 5 vertical mood option buttons

**Background Behavior:**
- Starts with `LumeColors.appBackground`
- Transitions to selected mood's light color (30% opacity)
- Smooth animation (0.6s ease-in-out)

**Mood Option Button Design:**
```
┌─────────────────────────────────────┐
│  ○  Dawn                            │
│     Just getting started        ✓   │
└─────────────────────────────────────┘
```

Each button contains:
- Left: Circular icon background (56x56pt)
  - Unselected: 15% opacity mood color
  - Selected: 30% opacity with scale 1.1
  - Pulsing ring when selected (animates outward, fades)
- Center: Text content
  - Mood name (body font)
  - Description (small font)
- Right: Checkmark when selected

**Selection Behavior:**
1. Tap mood → Button animates (scale + color)
2. Background color transitions
3. Pulsing ring animation starts
4. After 0.6s → Auto-navigate to details

**Color Mapping (Light Tones Only):**
- Dawn: `LumeColors.moodLow` (#F0B8A4 - soft coral)
- Sunrise: `LumeColors.accentPrimary` (#F2C9A7 - warm peach)
- Noon: `LumeColors.moodPositive` (#F5DFA8 - bright warm yellow)
- Sunset: `LumeColors.moodNeutral` (#EBDCCF - soft beige)
- Twilight: `LumeColors.accentSecondary` (#D8C8EA - soft lavender)

**Why This Approach?**
- Single-column list is scannable
- Each mood gets space to breathe
- Selection is immediate and clear
- Auto-advance removes friction
- Light colors feel warm and welcoming

---

### Phase 3: Optional Details

**Purpose:** Add context if desired - completely optional

**Navigation:** Push navigation (continues the flow)

**Layout:**
- Top: Mood confirmation with icon (80x80pt circle)
- Selected mood name + description
- Two optional text fields (expandable)
- Action buttons at bottom

**Background:**
- Same light color as selection screen (20% opacity)
- Maintains visual continuity

**Text Fields:**
1. **"What happened today?"**
   - Icon: text.alignleft
   - Label includes "(Optional)"
   - TextEditor with min 100pt height
   - Light background: `LumeColors.surface` at 50% opacity
   - Subtle border

2. **"Something you're grateful for"**
   - Icon: heart
   - Label includes "(Optional)"
   - TextEditor with min 80pt height
   - Same styling as above

**Action Buttons:**
1. **Primary: "Save"**
   - Full width
   - Background: Mood color (solid)
   - Icon: checkmark
   - Progress indicator when saving

2. **Secondary: "Skip and Save"**
   - Full width
   - Text only (no background)
   - Secondary text color
   - Quickly saves without fields

**Toolbar:**
- Right: "Cancel" button (dismisses entire flow)

**Why This Approach?**
- Fields are visible but clearly optional
- No cognitive load deciding to expand/collapse
- "Skip and Save" makes skipping explicit and guilt-free
- Consistent background color reinforces mood choice

---

## Visual Elements

### Icons (SF Symbols Only)

**Mood Icons:**
- Dawn: `sunrise.fill`
- Sunrise: `sun.and.horizon.fill`
- Noon: `sun.max.fill`
- Sunset: `sunset.fill`
- Twilight: `moon.stars.fill`

**Interface Icons:**
- Add mood: `plus`
- Notes: `text.alignleft`
- Gratitude: `heart`
- Confirm: `checkmark`
- Selected: `checkmark.circle.fill`
- Empty state: `sun.max`

**Why SF Symbols?**
- Less "in your face" than emojis
- Consistent with iOS design language
- Scalable and crisp
- Support dynamic type

### Animations

**Selection Animation:**
```swift
.spring(response: 0.5, dampingFraction: 0.7)
```
- Scale: 1.0 → 1.1
- Opacity: 0.15 → 0.3
- Smooth, bouncy feel

**Pulsing Ring (Selected State):**
```swift
.easeInOut(duration: 1.5).repeatForever(autoreverses: false)
```
- Scale: 1.0 → 1.3
- Opacity: 1.0 → 0
- Subtle breathing effect

**Background Color Transition:**
```swift
.easeInOut(duration: 0.6)
```
- Smooth fade between colors
- No jarring transitions

**Checkmark Appearance:**
```swift
.scale.combined(with: .opacity)
```
- Pop-in effect when selected
- Delightful micro-interaction

### Color Usage Rules

**Background Colors (Always Light):**
- Base: `LumeColors.appBackground` (#F8F4EC)
- Cards: `LumeColors.surface` (#E8DFD6)
- Mood tints: 20-30% opacity of mood colors

**Mood Colors (All Light Tones):**
- Dawn: #F0B8A4 (soft coral)
- Sunrise: #F2C9A7 (warm peach)
- Noon: #F5DFA8 (bright warm yellow)
- Sunset: #EBDCCF (soft beige)
- Twilight: #D8C8EA (soft lavender)

**Text Colors:**
- Primary: #3B332C (dark warm brown)
- Secondary: #6E625A (medium warm brown)

**Never Use:**
- ❌ Dark purple backgrounds (#404059)
- ❌ Dark blue backgrounds (#474073)
- ❌ Any color below 50% lightness
- ❌ Pure black or pure white

---

## History Display

### Mood History Card

**Layout:**
```
┌─────────────────────────────────┐
│  ○  Noon              Yesterday │
│     Feeling bright               │
│     Had a great morning...       │
│     ♥ Grateful for sunshine      │
└─────────────────────────────────┘
```

**Contents:**
- Left: Mood icon (48x48pt) with light colored background
- Center top: Mood name (bold) + timestamp
- Center middle: Mood description
- Center bottom: Note preview (2 lines max)
- Below: Gratitude with heart icon (1 line)

**Styling:**
- Background: `LumeColors.surface`
- Corner radius: 16pt
- Light shadow for depth
- 16pt padding
- 16pt spacing between cards

---

## Empty State

**Design Principles:**
- Welcoming, not anxious
- Clear guidance without pressure
- Visual hierarchy guides to FAB
- Spacious layout (not cramped)

**Elements:**
1. Large icon in colored circle (center, above)
2. "Start your journey" headline
3. Descriptive subtext
4. Arrow pointing to FAB
5. "Tap the button below..." hint

**Positioning:**
- Vertically centered
- Horizontal padding: 40pt
- FAB hint 120pt from bottom (clears FAB)

---

## Interaction Patterns

### Tap Targets

**Minimum sizes:**
- FAB: 56pt height minimum
- Mood option button: 72pt height minimum
- Text fields: 100pt+ height (expandable)
- Action buttons: 52pt height

### Navigation

**Stack-based (NO sheets):**
1. Main → Mood Selection (push)
2. Mood Selection → Details (push)
3. Details → Save → Pop to root

**Benefits:**
- Standard iOS back gesture works
- No swipe conflicts
- Clear navigation hierarchy
- Cancel button always available

### Feedback

**Visual:**
- Selection: Scale + color change
- Tap: Spring animation
- Save: Button shows progress indicator
- Success: Navigate back (implicit success)

**Haptic:** (Future)
- Mood selection: Light impact
- Save: Success notification

---

## Accessibility

### Color Contrast

All combinations meet WCAG AA:
- Text on light backgrounds: 4.5:1 minimum
- Mood colors remain distinguishable
- Icons have sufficient contrast

### Dynamic Type

- All text scales with system settings
- Layouts adapt to larger text
- Minimum tap targets maintained

### VoiceOver

- FAB: "Track Mood button"
- Mood options: "Dawn, just getting started"
- Text fields: Labeled with purpose
- Buttons: Clear action labels

---

## Technical Implementation

### View Hierarchy

```
MoodTrackingView (Main)
  ├─ EmptyMoodState OR
  ├─ ScrollView
  │   └─ MoodHistoryCard (foreach)
  └─ FAB Button
      └─ NavigationDestination → MoodSelectionView
          └─ NavigationDestination → MoodDetailsView
```

### State Management

**MoodTrackingView:**
- `@State showingMoodEntry: Bool` (triggers navigation)
- `@Bindable var viewModel: MoodViewModel`

**MoodSelectionView:**
- `@State selectedMood: MoodKind?` (local selection)
- `@State navigateToDetails: Bool` (auto-advance)

**MoodDetailsView:**
- `@State note: String` (local input)
- `@State gratitude: String` (local input)
- `@State isSaving: Bool` (loading state)

### Animation State

- Pulsing ring: Local `@State isAnimating`
- Background transitions: Animated on `selectedMood` change
- Scale effects: Animated on `isSelected` change

---

## Design Rationale

### Why Phased Interactions?

**Problem:** One big form is overwhelming  
**Solution:** Break into focused steps

1. **Choose mood** - Single decision
2. **Add context** - Optional depth

Each step has one clear purpose.

### Why No Sheets?

**Problem:** Swipe gestures conflict with sheet dismissal  
**Solution:** Use push navigation

Benefits:
- Standard back gesture
- No accidental dismissal
- Clear navigation path
- Consistent with iOS patterns

### Why Light Colors Only?

**Problem:** Dark moods feel clinical and heavy  
**Solution:** Light, warm tones from brand palette

Psychology:
- Warm colors feel welcoming
- Light tones reduce anxiety
- Brand consistency throughout
- Accessible contrast ratios

### Why FAB Instead of Inline?

**Problem:** Inline buttons can be missed  
**Solution:** Persistent, obvious FAB

Benefits:
- Always visible
- Clear affordance
- Modern pattern
- Doesn't clutter list

### Why Auto-Advance After Selection?

**Problem:** Extra tap creates friction  
**Solution:** Smart auto-advance with delay

Flow:
1. Tap mood (0.0s)
2. Visual feedback (0.0-0.6s)
3. Auto-navigate (0.6s)

User gets confirmation before moving forward.

---

## Future Enhancements

### Phase 4: Insights (Future)
- Calendar view with colored days
- Weekly mood trends
- Gratitude collection
- Pattern recognition

### Polish (Future)
- Haptic feedback
- Confetti on first mood saved
- Mood streak celebrations
- Export to PDF/CSV

---

## Comparison with Previous Design

### What Changed

| Aspect | Previous (v2.0) | Current (v3.0) |
|--------|----------------|----------------|
| Entry | Quick buttons + Sheet | FAB → Navigation |
| Selection | Horizontal swipe | Vertical list |
| Colors | Dark gradients | Light warm tones |
| Navigation | Sheet (conflicts) | Push (smooth) |
| Fields | Expandable sections | Always visible |
| Steps | 1-2 (combined) | 3 (phased) |

### Why Changed

1. **No more dark colors** - Didn't match brand
2. **Phased interactions** - Less overwhelming
3. **No sheets** - Avoid swipe conflicts
4. **FAB entry point** - Clear, accessible
5. **Light tones** - Warm and welcoming

---

## Success Metrics

This design succeeds if:

- ✅ Users complete mood tracking more frequently
- ✅ Higher percentage add notes/gratitude
- ✅ No reports of "accidental dismissal"
- ✅ Positive feedback on "calm" experience
- ✅ Clear understanding of mood options
- ✅ Smooth navigation with no confusion

---

**Design Principle:** "One step at a time, gently guided, warmly received."

This is uniquely Lume - not a copy of anything else.