# TextField Border Enhancement

**Date:** 2025-01-28  
**Issue:** TextField nearly invisible against pastel background  
**Fix:** Added visible border

## Change

Added overlay with stroke to TextField:

```swift
.overlay(
    RoundedRectangle(cornerRadius: 22)
        .stroke(LumeColors.accentPrimary.opacity(0.3), lineWidth: 1)
)
```

## Visual Effect

**Before:**
- White 50% opacity background only
- Nearly invisible against `LumeColors.appBackground` (pastel beige)
- Hard to see where to type

**After:**
- White 50% opacity background
- + Peach border (accent primary at 30% opacity)
- Clear, visible input field
- Matches Lume's warm color palette

## Colors Used

- **Background:** `Color.white.opacity(0.5)` (light fill)
- **Border:** `LumeColors.accentPrimary.opacity(0.3)` (peach/warm outline)
- **Text:** `LumeColors.textPrimary` (dark brown)

## File Modified

`ChatView.swift` - Lines 204-207

## Result

✅ TextField clearly visible  
✅ Maintains WhatsApp-style rounded corners  
✅ Stays within Lume's warm color palette  
✅ Better user experience
