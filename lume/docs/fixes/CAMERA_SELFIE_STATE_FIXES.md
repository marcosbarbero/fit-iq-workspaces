# Camera Picker State Management & Selfie Mirroring Fixes

**Date:** 2025-01-30  
**Status:** Fixed  
**Component:** Profile Picture Camera Capture & Image Cropping

---

## Problems

### 1. Image Picker Returning Null from Camera
When capturing a photo with the camera, the cropper sheet would show but `selectedImage` was nil, resulting in an empty/broken cropper view. Console output:

```
📸 Image picked from camera
📸 Image size: (2316.0, 3088.0)
📸 About to show cropper, selectedImage is: set
⚠️ Cropper sheet showing but selectedImage is nil!
```

### 2. Selfie Orientation Issues
The `fixOrientation()` function was incorrectly handling front camera selfies. It would return early if orientation was `.up`, but selfies from the front camera need to be mirrored to appear natural (as they do in the camera preview).

### 3. Photo Library Works Fine
Selecting images from the photo library worked correctly, indicating the issue was specific to camera capture timing.

---

## Root Causes

### Issue 1: SwiftUI Sheet State Timing Bug
When dismissing one sheet (`showingCameraPicker`) and immediately showing another (`showingImageCropper`), SwiftUI's state management can cause unexpected behavior:

1. Camera picker callback sets `selectedImage` and dismisses picker
2. `DispatchQueue.main.async` tries to show cropper immediately
3. SwiftUI's sheet dismissal animation is still in progress
4. State variables can be cleared or reset during sheet transitions
5. Cropper sheet shows with `selectedImage` already nil

### Issue 2: Incorrect Orientation Handling
The `fixOrientation()` function was trying to "normalize" image orientation but:
- Returned early for `.up` orientation (most camera images)
- Didn't account for front camera mirroring requirements
- Front camera selfies should be mirrored horizontally to match what users see in the preview

---

## Solutions

### 1. Separate State Variable for Camera Images

**File:** `lume/Presentation/Features/Profile/ProfileDetailView.swift`

Added a dedicated state variable to preserve the camera-captured image:

```swift
@State private var imageFromCamera: UIImage?
```

Modified camera picker to store image separately and use `onChange` to handle the transition:

```swift
private var cameraPickerSheet: some View {
    ImagePickerView(sourceType: .camera) { image in
        print("📸 Image picked from camera")
        print("📸 Image size: \(image.size)")
        print("📸 Image orientation: \(image.imageOrientation.rawValue)")

        // Store the camera image in a separate state variable
        imageFromCamera = image
        showingCameraPicker = false
    }
    .onChange(of: showingCameraPicker) { oldValue, newValue in
        // When camera picker is dismissed, show cropper with the captured image
        if oldValue == true && newValue == false, let cameraImage = imageFromCamera {
            print("📸 Camera picker dismissed, preparing to show cropper")
            selectedImage = cameraImage
            imageFromCamera = nil

            // Delay slightly to ensure clean sheet transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📸 Showing cropper with selectedImage: \(selectedImage != nil ? "set" : "nil")")
                showingImageCropper = true
            }
        }
    }
}
```

**Key Points:**
- Camera image stored in `imageFromCamera` immediately
- Picker dismissal triggers `onChange` observer
- 0.3 second delay ensures clean sheet transition
- `selectedImage` set after picker is fully dismissed
- State preserved across sheet transitions

### 2. Proper Selfie Mirroring

Removed the broken `fixOrientation()` function and added proper selfie detection and mirroring:

```swift
extension UIImage {
    /// Check if this image is from the front camera (selfie)
    var isFrontCameraImage: Bool {
        // Front camera images are often mirrored (upMirrored orientation)
        return imageOrientation == .upMirrored || imageOrientation == .downMirrored
            || imageOrientation == .leftMirrored || imageOrientation == .rightMirrored
    }

    /// Mirror the image horizontally (for selfies)
    func mirrored() -> UIImage {
        guard let cgImage = cgImage else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }

        // Flip the context horizontally
        context.translateBy(x: size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)

        // Draw the image
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        let mirroredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return mirroredImage ?? self
    }
}
```

**Key Points:**
- `isFrontCameraImage` detects mirrored orientation flags
- `mirrored()` performs horizontal flip using Core Graphics
- No unnecessary orientation "fixes" that break images
- Simple, predictable behavior

### 3. Cropper Uses Mirrored Display Image

Modified `ImageCropperView` to automatically mirror selfies:

```swift
struct ImageCropperView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var displayImage: UIImage

    init(image: UIImage, onCropped: @escaping (UIImage) -> Void) {
        self.image = image
        self.onCropped = onCropped

        // If this is a front camera image (selfie), mirror it
        if image.isFrontCameraImage {
            print("📸 Detected front camera image, mirroring for natural selfie view")
            _displayImage = State(initialValue: image.mirrored())
        } else {
            _displayImage = State(initialValue: image)
        }
    }

    var body: some View {
        // ... UI code uses displayImage instead of image
        Image(uiImage: displayImage)
            .resizable()
            .scaledToFill()
            // ...
    }

    private func cropImage() {
        // Use displayImage for size calculations and drawing
        let imageSize = displayImage.size
        // ...
        displayImage.draw(in: drawRect)
    }
}
```

**Key Points:**
- Detects selfies in initializer
- Creates mirrored `displayImage` for front camera photos
- All cropping operations use `displayImage`
- Final cropped image is already mirrored correctly
- Back camera photos remain unchanged

### 4. Consistent Timing for Photo Library

Updated photo library picker to use the same delay pattern for consistency:

```swift
private var libraryPickerSheet: some View {
    ImagePickerView(sourceType: .photoLibrary) { image in
        print("📸 Image picked from photo library")
        print("📸 Image size: \(image.size)")
        selectedImage = image
        showingLibraryPicker = false

        // Show cropper after dismissing picker (consistent with camera)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📸 About to show cropper, selectedImage is: \(selectedImage != nil ? "set" : "nil")")
            showingImageCropper = true
        }
    }
}
```

---

## Results

### Camera Capture Flow (Fixed)
1. User taps "Take Photo" → Camera opens
2. User captures photo → Image stored in `imageFromCamera`
3. Camera dismisses → `onChange` detects dismissal
4. After 0.3s delay → `selectedImage` set, cropper shows
5. Cropper displays mirrored selfie (if front camera)
6. User crops → Final image saved correctly

### Photo Library Flow (Improved)
1. User taps "Choose Photo" → Library opens
2. User selects photo → Image stored in `selectedImage`
3. Library dismisses → After 0.3s delay
4. Cropper shows with selected image
5. User crops → Final image saved

### Selfie Mirroring (Fixed)
- Front camera selfies are automatically detected
- Images are mirrored horizontally for natural appearance
- Back camera photos remain unchanged
- Cropping preserves the mirrored orientation

---

## Technical Details

### Why the 0.3s Delay Works
- SwiftUI sheet dismissal animations take ~0.25-0.3 seconds
- Waiting for full dismissal prevents state corruption
- `asyncAfter` ensures UI thread is ready for next sheet
- Consistent timing across both camera and library flows

### Why Separate State for Camera
- Camera picker callback executes during sheet dismissal
- SwiftUI may reset `@State` variables during sheet transitions
- Separate variable preserves image outside the dismissal scope
- `onChange` observer runs after sheet state is stable

### Front Camera Detection
iOS camera images have EXIF metadata with orientation flags:
- `.up` - Normal orientation (back camera)
- `.upMirrored` - Front camera (selfie)
- Other mirrored values indicate front camera with device rotation

### Mirroring vs Rotation
- **Rotation**: Changes which edge is "up" (90°, 180°, 270°)
- **Mirroring**: Horizontal flip (left becomes right)
- Front camera needs mirroring, not rotation
- Users expect selfies to match camera preview (mirrored)

---

## iOS System Logs (Not Errors)

These FigCapture logs are normal iOS internal messages, not app errors:

```
<<<< FigXPCUtilities >>>> signalled err=-17281 at <>:302
<<<< FigCaptureSourceRemote >>>> Fig assert: "err == 0 " at bail (FigCaptureSourceRemote.m:569) - (err=-17281)
```

These occur when:
- Camera hardware is released after capture
- System is cleaning up camera resources
- Normal part of iOS camera lifecycle
- **Not indicative of any problems in our app**

---

## Testing Checklist

- [x] Camera capture works and shows cropper
- [x] Cropper displays captured image (not nil)
- [x] Front camera selfies are mirrored naturally
- [x] Back camera photos are not mirrored
- [x] Photo library selection works
- [x] Cropping produces correct output
- [x] Profile image saves and displays correctly
- [x] State transitions are smooth with no flashing
- [x] No console errors about nil images

---

## Architecture Alignment

✅ **Clean State Management:** Separate concerns with dedicated state variables  
✅ **Predictable Behavior:** Consistent timing and flow for all image sources  
✅ **User Experience:** Natural selfie appearance matching camera preview  
✅ **Error Prevention:** Proper sheet lifecycle management prevents state bugs  
✅ **Maintainability:** Clear, commented code explaining timing requirements

---

## Related Files Modified

- `lume/Presentation/Features/Profile/ProfileDetailView.swift`
  - Added `imageFromCamera` state variable
  - Modified `cameraPickerSheet` with `onChange` observer
  - Updated `libraryPickerSheet` for consistency
  - Removed broken `fixOrientation()` function
  - Added `isFrontCameraImage` and `mirrored()` extensions
  - Modified `ImageCropperView` to handle selfie mirroring

---

## Related Documentation

- [Profile Picture & UI Fixes Thread](../threads/68dcfd7c-6c55-4447-b3cd-dc304241a8fb)
- [Profile Image Padding Fix](PROFILE_IMAGE_PADDING_FIX.md)
- [Camera Permissions Setup](../../CAMERA_PERMISSIONS_SETUP.md)
- [Project Root README](../../README.md)