# Mood Tracking UX Alignment with Journal Entry

**Date:** 2025-01-15  
**Status:** Completed  
**Related:** [Journaling Tag Visibility UI Issue](../journaling/)

---

## Overview

This document describes the UX alignment between Mood Tracking and Journal Entry features, specifically focusing on date/time picker consistency and visual hierarchy improvements.

---

## Problem Statement

The Mood Tracking feature had a very prominent date/time picker section that took up significant visual space and created an inconsistent experience compared to the Journal Entry view:

### Before

**Mood Tracking:**
- Large, prominent date picker section with icon, labels, and expandable UI
- "When" heading with calendar icon
- Large button showing date and time separately
- Graphical date picker expanding inline
- Multiple visual elements competing for attention

**Journal Entry:**
- Subtle date/time button in the top toolbar
- Compact, unobtrusive design
- Sheet-style date picker overlay

### Issues
1. **Visual Weight:** Date picker dominated the mood entry screen
2. **Inconsistency:** Different interaction patterns between features
3. **Hierarchy:** Date selection competed with mood reflection and notes
4. **Screen Real Estate:** Large date picker reduced space for mood context

---

## Solution

Aligned the Mood Tracking date picker with the Journal Entry's subtle approach while reorganizing the entire view for better visual flow.

### Key Changes

#### 1. Date Picker in Toolbar

**Location:** Top toolbar, next to back button  
**Style:** Subtle text button showing formatted date and time  
**Interaction:** Opens sheet-style date picker overlay

```swift
private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: moodDate)
}
```

#### 2. Sheet-Style Date Picker

**Design:**
- Full-width bottom sheet with rounded top corners
- Header with Cancel/Done buttons
- Title "Select Date & Time"
- Graphical date picker tinted with mood color
- Semi-transparent backdrop overlay
- Smooth slide-up animation

**Benefits:**
- Consistent with iOS design patterns
- Doesn't interrupt visual flow
- Clear dismissal options
- More screen space for mood context

#### 3. Reorganized Layout

**New Visual Hierarchy:**

1. **Mood Visual** (top)
   - Mood icon in colored circle
   - Mood name and description
   - Compact and centered

2. **Valence Indicator**
   - Shows pleasant/unpleasant scale
   - Visual representation of mood valence
   - Educational context

3. **Reflection Prompt**
   - Contextual question related to selected mood
   - Soft background card
   - Encourages thoughtful reflection

4. **Notes Section** (bottom)
   - Largest, most prominent input area
   - Focus on user expression
   - Mood-colored focus border

**Spacing:** Increased from 120pt to 150pt minimum height for notes

---

## Technical Implementation

### File Structure

**Modified Files:**
- `lume/Presentation/Features/Mood/MoodTrackingView.swift`
  - Removed prominent date picker section
  - Added toolbar date button
  - Implemented sheet-style date picker overlay
  - Reorganized content hierarchy

**New Files:**
- `lume/Core/Extensions/ViewExtension.swift`
  - Custom corner radius helper for specific corners
  - Supports bottom sheet rounded top corners

### Code Structure

#### Toolbar Date Button

```swift
ToolbarItem(placement: .topBarLeading) {
    HStack(spacing: 12) {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .foregroundColor(LumeColors.textPrimary)
        }

        // Subtle date/time button
        Button {
            withAnimation {
                showingDatePicker = true
            }
        } label: {
            Text(formattedDate)
                .font(LumeTypography.caption)
                .foregroundColor(LumeColors.textSecondary)
        }
    }
}
```

#### Sheet-Style Date Picker

```swift
if showingDatePicker {
    Color.black.opacity(0.3)
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation {
                showingDatePicker = false
            }
        }

    VStack {
        Spacer()

        VStack(spacing: 0) {
            // Header with Cancel/Done
            HStack {
                Button("Cancel") { /* ... */ }
                Spacer()
                Text("Select Date & Time")
                Spacer()
                Button("Done") { /* ... */ }
            }
            
            Divider()
            
            // Date picker
            DatePicker(/* ... */)
                .datePickerStyle(.graphical)
                .tint(Color(hex: selectedMood.color))
        }
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
}
```

### View Extension

Custom corner radius helper for rounded top corners:

```swift
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
```

---

## Design Principles Applied

### 1. Visual Hierarchy
**Before:** Date picker competed with mood content  
**After:** Mood and reflection are primary, date is metadata

### 2. Consistency
**Before:** Different patterns between Journal and Mood  
**After:** Unified date picker approach across features

### 3. Minimalism
**Before:** Multiple sections with icons and labels  
**After:** Clean, focused layout with essential elements

### 4. Calm Design
- Subtle date button doesn't demand attention
- Sheet overlay is non-intrusive
- Smooth animations maintain calm feeling
- Generous spacing between sections

---

## User Experience Flow

### Entering a Mood

1. User selects mood from picker
2. Navigates to mood details screen
3. Sees mood visual and description (primary focus)
4. Reads reflection prompt for context
5. Can optionally adjust date via toolbar button
6. Adds notes if desired
7. Saves with checkmark button

### Editing Date

1. User taps subtle date in toolbar
2. Sheet slides up from bottom
3. User adjusts date/time in graphical picker
4. Taps "Done" to confirm or "Cancel" to revert
5. Sheet slides down smoothly
6. Updated date appears in toolbar

---

## Benefits

### For Users
✅ **Less Cognitive Load:** Date selection doesn't interrupt mood flow  
✅ **Consistent Experience:** Same pattern as Journal Entry  
✅ **Better Focus:** Mood and reflection are central  
✅ **More Space:** Larger notes area for expression  
✅ **Calm Feeling:** Subtle, unobtrusive date selection

### For Developers
✅ **Code Consistency:** Reusable patterns across features  
✅ **Maintainability:** Unified date picker implementation  
✅ **Extensibility:** Easy to apply to future features  
✅ **Clean Architecture:** Separation of concerns

---

## Accessibility Considerations

1. **VoiceOver Support:** Date button clearly labeled with formatted date
2. **Tap Targets:** All interactive elements meet minimum size requirements
3. **Contrast:** Date text maintains readable contrast
4. **Keyboard Navigation:** Date picker supports standard keyboard controls

---

## Future Enhancements

### Potential Improvements
- [ ] Add date range presets ("Today", "Yesterday", "Last Week")
- [ ] Show relative time ("2 hours ago") alongside formatted date
- [ ] Consider time zone handling for travelers
- [ ] Add haptic feedback when opening date picker
- [ ] Implement swipe gestures to change date quickly

### Feature Parity
- [ ] Apply same pattern to Goals tracking (when implemented)
- [ ] Consider for any future time-based entries
- [ ] Document as standard pattern in design system

---

## Testing Checklist

### Visual Testing
- [x] Date button displays correctly in toolbar
- [x] Sheet animation is smooth and natural
- [x] Backdrop overlay is visible and dismissable
- [x] Rounded corners appear on top of sheet
- [x] Date picker tinted with mood color
- [x] Layout adapts to different screen sizes

### Interaction Testing
- [x] Tapping date button opens sheet
- [x] Tapping backdrop dismisses sheet
- [x] Cancel button dismisses without changes
- [x] Done button applies changes and dismisses
- [x] Date picker restricts future dates
- [x] Selected date persists correctly

### Integration Testing
- [x] Date saves correctly with mood entry
- [x] Edited date updates existing mood entry
- [x] Date format matches Journal Entry
- [x] Time zone handling is consistent
- [x] No conflicts with keyboard dismissal

---

## Lessons Learned

1. **Subtle is Better:** Metadata like dates shouldn't dominate the experience
2. **Consistency Matters:** Users expect similar features to work the same way
3. **Hierarchy is Key:** Primary content should be visually prominent
4. **Sheet Pattern Works:** iOS users understand bottom sheet interactions
5. **Animations Matter:** Smooth transitions maintain the calm feeling

---

## Related Documentation

- [Journaling Tag Visibility UI Issue](../journaling/)
- [Design System](../design/)
- [Architecture Guidelines](../architecture/)
- [Copilot Instructions](../../.github/copilot-instructions.md)

---

## Status

**Completed:** 2025-01-15  
**Verified:** All tests passing  
**Next Steps:** User testing and feedback collection