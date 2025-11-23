# Camera Permissions Setup

## Required Info.plist Entries

To enable camera and photo library access, you need to add usage descriptions to your Info.plist.

### Option 1: Through Xcode (Recommended)

1. Open the project in Xcode
2. Select the `lume` project in the Project Navigator
3. Select the `lume` target
4. Go to the **Info** tab
5. Click the **+** button to add new entries
6. Add these two keys:
   - **Privacy - Camera Usage Description**
   - **Privacy - Photo Library Usage Description**
7. Set their values:
   - Camera: "Lume would like to access your camera to take profile photos"
   - Photo Library: "Lume would like to access your photo library to select profile photos"

### Option 2: Direct Info.plist Edit

If you have an Info.plist file, add these entries:

```xml
<key>NSCameraUsageDescription</key>
<string>Lume would like to access your camera to take profile photos</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Lume would like to access your photo library to select profile photos</string>
```

## Testing

After adding the permissions:

1. Clean build folder (Cmd+Shift+K)
2. Rebuild the project (Cmd+B)
3. Run on a physical device (camera unavailable on simulator)
4. Navigate to Profile → Tap camera icon
5. Select "Take Photo" → System should prompt for camera permission
6. Select "Choose from Library" → System should prompt for photo library permission

## Troubleshooting

**Permission prompt doesn't appear:**
- Clean build folder
- Delete app from device/simulator
- Rebuild and reinstall

**"This app has crashed because it attempted to access privacy-sensitive data...":**
- The Info.plist entries are missing or have incorrect keys
- Double-check the key names match exactly

**Camera shows black screen:**
- Check if another app is using the camera
- Restart the device
- Check System Settings → Privacy → Camera → Ensure Lume has permission
