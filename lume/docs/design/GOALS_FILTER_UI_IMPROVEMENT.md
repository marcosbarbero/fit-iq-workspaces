# Goals Filter UI Improvement

**Date:** 2025-01-29  
**Status:** ✅ Implemented  
**Component:** GoalsListView  
**Inspiration:** ChatListView custom segmented control

---

## Problem

The Goals list view used the native iOS `.segmented` picker style, which appeared grey and didn't match the warm, calm Lume design aesthetic.

### Before

```swift
Picker("", selection: $selectedTab) {
    Text("Active (\(viewModel.activeGoals.count))").tag(0)
    Text("Completed (\(viewModel.completedGoals.count))").tag(1)
    Text("Paused (\(viewModel.pausedGoals.count))").tag(2)
    Text("Archived (\(viewModel.archivedGoals.count))").tag(3)
}
.pickerStyle(.segmented)
```

**Issues:**
- Grey iOS default appearance
- Didn't match Lume's warm color palette
- Inconsistent with ChatListView design
- Less visually engaging

---

## Solution

Created custom styled tabs component (`GoalTabsStyled`) inspired by the ChatListView implementation, matching Lume's design system.

### Design Features

1. **Warm Accent Color**: Uses `#F2C9A7` (Lume primary accent) for selected state
2. **Two-Line Layout**: Tab name + count displayed vertically for clarity
3. **Smooth Animations**: 0.2s ease-in-out transitions between tabs
4. **Clear Visual Hierarchy**: 
   - Selected: Bold text with accent background
   - Unselected: Regular text with transparent background
5. **Subtle Background**: White with 30% opacity for soft container effect
6. **Rounded Corners**: 8pt radius for cozy, friendly feel

### Implementation

```swift
struct GoalTabsStyled: View {
    @Binding var selection: Int
    let viewModel: GoalsViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Four tabs: Active, Done, Paused, Archived
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = 0
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Active")
                        .font(.system(size: 14, weight: selection == 0 ? .semibold : .regular))
                    Text("\(viewModel.activeGoals.count)")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.7)
                }
                .foregroundColor(
                    selection == 0 ? LumeColors.textPrimary : LumeColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    selection == 0 ? Color(hex: "#F2C9A7") : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
            
            // ... similar for Done, Paused, Archived
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}
```

---

## Visual Improvements

### Color Scheme

| Element | Before | After |
|---------|--------|-------|
| Selected Tab | Grey (#E0E0E0) | Warm Peach (#F2C9A7) |
| Selected Text | System Blue | Primary Text (#3B332C) |
| Unselected Tab | Light Grey | Transparent |
| Unselected Text | Grey | Secondary Text (#6E625A) |
| Container | Grey Border | White 30% + Subtle Border |

### Typography

| Element | Size | Weight | Purpose |
|---------|------|--------|---------|
| Tab Label | 14pt | Semibold (selected) / Regular (unselected) | Clear hierarchy |
| Count Badge | 13pt | Medium | Subtle but readable |

### Layout

**Before:**
```
[Active (5) | Completed (12) | Paused (2) | Archived (8)]
```
- Single line, cramped
- Counts in parentheses

**After (WhatsApp-style):**
```
[ Active 5 | Done 12 | Paused 2 | Archived 8 ]
```
- Horizontal layout with label and count side-by-side
- Compact and clean
- More breathing room than native segmented control

---

## Consistency with Chat

Both views now share the same design pattern:

### Shared Design Elements

1. **Custom Tab Control**: Both avoid native `.segmented` style
2. **Warm Accent**: `#F2C9A7` for selected state
3. **Smooth Animations**: 0.2s ease-in-out
4. **White Background**: 30% opacity container
5. **Rounded Corners**: 8pt radius
6. **Typography Scale**: Similar font sizes and weights

### Differences (Intentional)

| Aspect | ChatListView | GoalsListView | Reason |
|--------|--------------|---------------|---------|
| Tabs | 2 (Active, Archived) | 4 (Active, Done, Paused, Archived) | Goals have more states |
| Layout | Horizontal (label + count) | Horizontal (label + count) | Same WhatsApp-style layout |
| Label | "Active" / "Archived" | "Active" / "Done" / "Paused" / "Archived" | Different terminology |

---

## User Experience Benefits

1. **Visual Consistency**: Matches ChatListView and overall Lume design
2. **Better Readability**: Counts separated from labels
3. **Clear Selection**: Warm accent makes selected tab obvious
4. **Smooth Transitions**: Animations feel polished
5. **At-a-Glance Info**: See all goal counts without switching tabs
6. **Touch Targets**: Large, easy-to-tap buttons

---

## Technical Details

### Animation

```swift
withAnimation(.easeInOut(duration: 0.2)) {
    selection = newTab
}
```

- **Duration**: 0.2 seconds (feels instant but smooth)
- **Curve**: ease-in-out (natural acceleration/deceleration)
- **Properties**: Background color, font weight, text color

### Accessibility

- Plain button style prevents default iOS button effects
- Full tap targets (`.frame(maxWidth: .infinity)`)
- Clear visual states (selected vs unselected)
- Semantic colors (text primary vs secondary)

---

## Code Changes

### Files Modified

- `lume/Presentation/Features/Goals/GoalsListView.swift`
  - Replaced native `.segmented` picker with `GoalTabsStyled`
  - Added custom tab component (127 lines)
  - Restructured layout to accommodate new tabs

### Structure Changes

**Before:**
```swift
ZStack(alignment: .bottomTrailing) {
    VStack {
        Picker(...).pickerStyle(.segmented)
        // Content
    }
    // FAB
}
```

**After:**
```swift
VStack(spacing: 0) {
    GoalTabsStyled(...)
    ZStack(alignment: .bottomTrailing) {
        // Content
        // FAB
    }
}
```

---

## Future Enhancements

### Potential Improvements

1. **Badge Animations**: Animate count changes
2. **Haptic Feedback**: Add subtle haptics on tab switch
3. **Swipe Gestures**: Allow swiping between tabs
4. **Icon Support**: Add small icons to tabs (optional)
5. **Compact Mode**: Single-line variant for small screens

### Reusability

Consider extracting common tab styling into shared component:

```swift
struct LumeTabsStyled<Tab: Hashable>: View {
    @Binding var selection: Tab
    let tabs: [(tab: Tab, label: String, count: Int?)]
    
    var body: some View {
        // Reusable implementation
    }
}
```

This would allow:
- ChatListView to use same component
- Goals to use same component
- Future views to use same pattern

---

## Testing Checklist

- [x] All four tabs render correctly
- [x] Counts display accurately
- [x] Selection state updates properly
- [x] Animations are smooth
- [x] Colors match design system
- [x] Text is readable in all states
- [x] Tap targets are appropriately sized
- [x] No layout issues on different screen sizes
- [x] Consistent with ChatListView style
- [x] No compilation errors or warnings

---

## Screenshots

### Before
- Grey segmented control
- Single line with counts in parentheses
- iOS default appearance

### After
- Warm peach accent for selected tab
- Horizontal layout (label + count side-by-side, WhatsApp-style)
- Custom Lume design
- More compact than vertical layout

---

## Lessons Learned

1. **Cross-Feature Inspiration**: Looking at similar UI in other features (ChatListView) provided excellent design reference
2. **Consistency Matters**: Unified UI patterns create better UX
3. **Custom > Default**: Custom controls allow brand personality to shine
4. **Animation Details**: Small animation touches make UI feel polished
5. **Horizontal Layout**: WhatsApp-style horizontal layout keeps tabs compact and clean

---

**Status:** ✅ Complete and deployed  
**Next Steps:** Consider extracting shared tab component for reuse  
**Related:** ChatListView `SegmentedControlStyled` implementation