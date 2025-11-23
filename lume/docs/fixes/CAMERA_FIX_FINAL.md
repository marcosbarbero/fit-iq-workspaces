# Camera Fix - Final Solution

## The Actual Problem Found

Looking at the console logs:
```
📸 Camera option selected
📸 Camera is available, setting source type to .camera
📸 About to show image picker for camera
📸 [ImagePickerView] Created picker with source type: Photo Library  ← BUG!
📸 Opening image picker with source type: Camera
```

**The bug:** `makeUIViewController` was being called with the OLD value of `imageSourceType` before our state change took effect!

## Root Cause

SwiftUI timing issue:
1. User taps "Take Photo"
2. We set `imageSourceType = .camera`
3. We set `showingImagePicker = true`
4. SwiftUI creates the view
5. **But `makeUIViewController` captures the OLD state value!**
6. Picker created with `.photoLibrary` (default)
7. Our `updateUIViewController` tries to fix it, but too late

This is a classic SwiftUI state synchronization bug.

## The Solution

**Use separate sheet states instead of switching source types!**

### Before (Broken):
```swift
@State private var showingImagePicker = false
@State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary

// Try to switch source type
imageSourceType = .camera  // Set state
showingImagePicker = true  // Show sheet
// But view created with old imageSourceType value! ❌
```

### After (Fixed):
```swift
@State private var showingCameraPicker = false
@State private var showingLibraryPicker = false

// Dedicated sheet for camera
.sheet(isPresented: $showingCameraPicker) {
    ImagePickerView(sourceType: .camera) { ... }
}

// Dedicated sheet for library
.sheet(isPresented: $showingLibraryPicker) {
    ImagePickerView(sourceType: .photoLibrary) { ... }
}
```

## Benefits

✅ **No state synchronization issues** - Each sheet has hardcoded source type
✅ **No timing bugs** - Source type never changes
✅ **More reliable** - SwiftUI can't get confused
✅ **Simpler logic** - No source type switching
✅ **Better performance** - No view updates needed

## What Changed

### ProfileDetailView.swift

**Removed:**
- `imageSourceType` state variable
- Source type switching logic
- Single `showingImagePicker` state

**Added:**
- `showingCameraPicker` state
- `showingLibraryPicker` state
- Separate `.sheet()` modifiers for each

**Updated:**
- `onCameraSelected`: Sets `showingCameraPicker = true`
- `onPhotoLibrarySelected`: Sets `showingLibraryPicker = true`

## Expected Console Output

When you tap "Take Photo" now:
```
📸 Camera option selected
📸 Camera is available, will show camera picker
📸 About to show camera picker
📸 [ImagePickerView] Created picker with source type: Camera  ✅
📸 Image picked from camera
```

When you tap "Choose from Library":
```
📸 Photo Library option selected
📸 About to show library picker
📸 [ImagePickerView] Created picker with source type: Photo Library  ✅
📸 Image picked from photo library
```

## Testing

### On Physical Device:
1. Clean build (Cmd+Shift+K)
2. Run on device
3. Tap camera icon
4. Tap "Take Photo"
5. **Camera should open immediately!** ✅
6. Check console - should see "Camera" in logs

### On Simulator:
1. Run on simulator
2. Tap camera icon
3. Tap "Choose from Library"
4. **Photo library should open immediately!** ✅
5. Check console - should see "Photo Library" in logs

## Why This Works

SwiftUI's `sheet(isPresented:)` modifier captures the view content **at declaration time**, not at presentation time.

With separate sheets:
- Camera sheet always has `.camera` source type
- Library sheet always has `.photoLibrary` source type
- No runtime state changes needed
- No timing issues possible

## Files Modified

- `ProfileDetailView.swift`
  - Replaced single picker state with two separate states
  - Added dedicated sheet for camera
  - Added dedicated sheet for library
  - Removed source type switching logic

---

**Status:** Final fix applied! Should work perfectly now! ✅

Test on physical device for camera, simulator for photo library.
