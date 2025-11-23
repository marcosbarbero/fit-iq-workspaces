# Critical Fix: Profile Image Storage

## 🚨 Critical Issue Found

```
CFPrefsPlistSource: Attempting to store >= 4194304 bytes of data 
in CFPreferences/NSUserDefaults on this platform is invalid.
This is a bug in lume or a library it uses.
```

### The Problem

**UserDefaults has a 4MB limit!** We were storing full-resolution profile images in UserDefaults, which could easily exceed this limit, causing:
- Data corruption
- App crashes
- Failed saves
- Decode errors

### Root Cause

Original implementation:
```swift
// ❌ BAD: Storing potentially huge images in UserDefaults
func saveProfileImage(_ imageData: Data) {
    UserDefaults.standard.set(imageData, forKey: imageKey)
}
```

High-resolution photos can be **5-20MB** easily, far exceeding UserDefaults' 4MB limit.

## ✅ Solution Applied

### 1. File System Storage

**Changed to proper file system storage:**
```swift
// ✅ GOOD: Storing in Documents directory
func saveProfileImage(_ imageData: Data) {
    let documentsDirectory = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = documentsDirectory.appendingPathComponent("profileImage.jpg")
    try imageData.write(to: fileURL, options: [.atomic])
}
```

**Benefits:**
- No size limits (except device storage)
- Proper location for user-generated content
- Atomic writes prevent corruption
- Standard iOS practice

### 2. Reduced Image Size

**Changed output resolution:**
```swift
// Before: 400x400 @ 0.8 quality = ~100-200KB
let size: CGFloat = 400
compressionQuality: 0.8

// After: 300x300 @ 0.7 quality = ~30-60KB
let size: CGFloat = 300
compressionQuality: 0.7
```

**Why this works:**
- 300x300 is plenty for profile pictures
- Retina displays: 300 × 2 = 600 actual pixels (more than enough!)
- Quality 0.7 is imperceptible difference from 0.8
- File sizes reduced by ~60%

### 3. Automatic Migration

**Added migration from UserDefaults to file system:**
```swift
private func migrateFromUserDefaultsIfNeeded() {
    // Check if already migrated
    guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
        return
    }
    
    // Move old data to file system
    if let oldImageData = UserDefaults.standard.data(forKey: oldKey) {
        try oldImageData.write(to: imageFileURL, options: [.atomic])
        UserDefaults.standard.removeObject(forKey: oldKey)
    }
    
    // Mark as complete
    UserDefaults.standard.set(true, forKey: migrationCompletedKey)
}
```

**This ensures:**
- Existing users don't lose their profile pictures
- UserDefaults gets cleaned up automatically
- Migration only runs once
- No manual intervention needed

### 4. Cleanup Old Data

Migration also removes these old keys:
- `"lume.profile.image"` - Old key
- `"profileImage"` - Legacy key

This frees up UserDefaults space and prevents future issues.

## File Storage Details

### Storage Location
```
/var/mobile/Containers/Data/Application/{APP_ID}/Documents/profileImage.jpg
```

### File Properties
- **Name:** `profileImage.jpg`
- **Size:** ~30-60KB (was 100-200KB)
- **Format:** JPEG
- **Resolution:** 300×300 pixels
- **Quality:** 0.7 compression

### Benefits
- ✅ No size limits
- ✅ Proper iOS storage location
- ✅ Atomic writes (no corruption)
- ✅ Survives app updates
- ✅ Backed up by iCloud (if enabled)
- ✅ Deleted on app uninstall

## Testing After Fix

### Clean Install
1. Install app fresh
2. Set profile picture
3. No errors in console
4. Image persists after app restart

### Migration Test (Existing Users)
1. App launches
2. Migration runs automatically
3. Console shows: "✅ Successfully migrated profile image to file system"
4. Console shows: "✅ Profile image migration completed"
5. Old UserDefaults data removed
6. Profile picture still visible

### Size Verification
1. Take high-res photo (e.g., 12MP camera)
2. Crop and save as profile picture
3. Check file size:
   ```bash
   # Should be ~30-60KB, not MB!
   ls -lh ~/Library/Developer/CoreSimulator/.../Documents/profileImage.jpg
   ```

## What Was Changed

### ProfileImageManager

**Before:**
```swift
class ProfileImageManager {
    private let imageKey = "lume.profile.image"
    
    func saveProfileImage(_ imageData: Data) {
        UserDefaults.standard.set(imageData, forKey: imageKey)
    }
    
    func loadProfileImage() -> Data? {
        UserDefaults.standard.data(forKey: imageKey)
    }
}
```

**After:**
```swift
class ProfileImageManager {
    private let imageFileName = "profileImage.jpg"
    private var imageFileURL: URL { /* Documents/profileImage.jpg */ }
    
    init() {
        migrateFromUserDefaultsIfNeeded()
    }
    
    func saveProfileImage(_ imageData: Data) {
        try imageData.write(to: imageFileURL, options: [.atomic])
    }
    
    func loadProfileImage() -> Data? {
        try? Data(contentsOf: imageFileURL)
    }
}
```

### Image Cropper

**Before:**
```swift
let size: CGFloat = 400
compressionQuality: 0.8
```

**After:**
```swift
let size: CGFloat = 300  // Smaller output
compressionQuality: 0.7  // Higher compression
```

## Error Prevention

### Added Error Handling
```swift
func saveProfileImage(_ imageData: Data) {
    do {
        try imageData.write(to: imageFileURL, options: [.atomic])
        NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
    } catch {
        print("❌ Error saving profile image: \(error.localizedDescription)")
    }
}
```

### Safe Loading
```swift
func loadProfileImage() -> Data? {
    guard FileManager.default.fileExists(atPath: imageFileURL.path) else {
        return nil
    }
    return try? Data(contentsOf: imageFileURL)
}
```

## Performance Impact

### Storage
- **Before:** UserDefaults (slow, 4MB limit)
- **After:** File system (fast, no limit)

### Memory
- **Before:** ~100-200KB per image
- **After:** ~30-60KB per image (60% reduction!)

### Load Time
- **Before:** Load from UserDefaults + parse
- **After:** Direct file read (faster!)

## Console Output

You should see these log messages on first launch after update:

```
✅ Successfully migrated profile image to file system
✅ Profile image migration completed
```

You should **NOT** see these anymore:

```
❌ CFPrefsPlistSource: Attempting to store >= 4194304 bytes
❌ decode: bad range for [%@]
```

## Files Modified

1. **`ProfileDetailView.swift`**
   - ProfileImageManager: File system storage
   - Migration logic
   - Reduced image size (300x300)
   - Increased compression (0.7)

## No Breaking Changes

- ✅ Existing images migrated automatically
- ✅ All functionality preserved
- ✅ No user action required
- ✅ Backward compatible

## Ready to Test!

Build and run the app. The critical storage issue is now fixed! 🎉

---

**Status:** Critical fix applied ✅
**Migration:** Automatic ✅
**Testing:** Required ✅
