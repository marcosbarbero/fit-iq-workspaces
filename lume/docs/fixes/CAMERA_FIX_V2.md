# Camera Opening Fix - V2

## Issue
Camera only opens after clicking multiple times, otherwise opens photo library.

## Root Cause
The source type was being set at the same time as showing the sheet, causing a race condition where the UIImagePickerController would be created with the default (or previous) source type.

## Solution Applied

### 1. Set Source Type BEFORE Showing Sheet
```swift
// ✅ CORRECT: Set source type first, then show sheet
onCameraSelected: {
    imageSourceType = .camera  // Set first
    showingImageSourcePicker = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
        showingImagePicker = true  // Show after delay
    }
}
```

### 2. Added updateUIViewController
Updated ImagePickerView to ensure source type is correct even if the view updates:
```swift
func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    if uiViewController.sourceType != sourceType {
        uiViewController.sourceType = sourceType
    }
}
```

### 3. Increased Delay
Changed from 0.5s to 0.6s to ensure smoother transitions.

### 4. Added Debug Logging
Added extensive logging to track the flow:
- When camera/library option selected
- Camera availability check result
- Source type being set
- When picker is about to show
- When picker actually opens
- Which source type was used

## Testing with Debug Logs

When you tap "Take Photo", you should see in console:
```
📸 Camera option selected
📸 Camera is available, setting source type to .camera
📸 About to show image picker for camera
📸 [ImagePickerView] Created picker with source type: Camera
📸 Opening image picker with source type: Camera
📸 [ImagePickerView] Image picked successfully from Camera
```

When you tap "Choose from Library", you should see:
```
📸 Photo Library option selected
📸 About to show image picker for photo library
📸 [ImagePickerView] Created picker with source type: Photo Library
📸 Opening image picker with source type: Photo Library
📸 [ImagePickerView] Image picked successfully from Photo Library
```

## What Changed

**ProfileDetailView.swift:**
- Source type now set BEFORE dismissing source picker
- Increased delay to 0.6s
- Added comprehensive debug logging

**ImagePickerView:**
- Added updateUIViewController to ensure correct source type
- Added debug logging at all lifecycle points

## Testing Steps

1. **Clean Build**
   ```bash
   # In Xcode: Product → Clean Build Folder (Cmd+Shift+K)
   ```

2. **Run on Physical Device**
   - Simulator won't have camera, so test library only

3. **Test Camera**
   - Tap camera icon on profile
   - Tap "Take Photo"
   - Should open camera IMMEDIATELY on first tap
   - Check console logs

4. **Test Photo Library**
   - Tap camera icon on profile
   - Tap "Choose from Library"
   - Should open photo library on first tap
   - Check console logs

## Expected Behavior

✅ **Camera:** Opens immediately when "Take Photo" tapped (first time)
✅ **Photo Library:** Opens immediately when "Choose from Library" tapped
✅ **No Multiple Taps Needed:** Works on first tap every time
✅ **Debug Logs:** Show correct source type being used

## If Still Having Issues

Check the console logs. If you see:
```
📸 [ImagePickerView] Updating source type from Photo Library to Camera
```

This means the view was being recreated with wrong source type, but we're correcting it.

If camera still doesn't open, check:
1. Camera permissions granted?
2. Camera not in use by another app?
3. Console shows FigCapture errors? (Hardware issue)

## Rollback (If Needed)

If this doesn't work, we can try a different approach:
- Use two separate sheet states (one for camera, one for library)
- Eliminate the source picker entirely
- Show camera and library as side-by-side options in profile view

---

**Status:** Fix applied, ready for testing!
