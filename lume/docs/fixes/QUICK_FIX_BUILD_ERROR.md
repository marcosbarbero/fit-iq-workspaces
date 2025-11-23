# Quick Fix: Build Error

## ✅ Good News!

Your **Info.plist already has camera permissions** configured correctly at `lume/Info.plist`:
- ✓ Camera Usage Description
- ✓ Photo Library Usage Description

## 🔧 Fix the Build Error

The error happens because Info.plist is in the wrong build phase. Follow these exact steps:

### Visual Step-by-Step

```
┌─────────────────────────────────────────────┐
│ 1. Open Xcode                               │
│    Open lume.xcodeproj                      │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ 2. Select Project & Target                  │
│    • Click "lume" (blue icon) in sidebar    │
│    • Under TARGETS, select "lume"           │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ 3. Go to Build Phases Tab                   │
│    • Click "Build Phases" at the top        │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ 4. Find "Copy Bundle Resources"             │
│    • Click to expand this section           │
│    • Look through the list of files         │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ 5. Remove Info.plist                        │
│    • Find "Info.plist" in the list          │
│    • Select it                              │
│    • Press DELETE or click "-" button       │
│    • (Only remove from this list,           │
│       don't delete the actual file!)        │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ 6. Clean & Rebuild                          │
│    • Product → Clean Build Folder           │
│      (or Cmd+Shift+K)                       │
│    • Product → Build (or Cmd+B)             │
└─────────────────────────────────────────────┘
              ↓
           ✅ FIXED!
```

## What This Does

- **Info.plist** should NOT be in "Copy Bundle Resources"
- Xcode automatically handles Info.plist during the build
- Having it in both places causes the conflict
- Removing it from "Copy Bundle Resources" fixes the error

## Verify It Worked

After the fix, you should see:
- ✓ Build succeeds with no errors
- ✓ App runs normally
- ✓ Camera and photo library permissions work
- ✓ Profile picture features work perfectly

## If Info.plist Is NOT in Copy Bundle Resources

If you don't see Info.plist in that list, the issue might be something else:

1. Check Build Settings:
   - Go to "Build Settings" tab
   - Search for "INFOPLIST_FILE"
   - Should show: `lume/Info.plist` or `$(SRCROOT)/lume/Info.plist`
   
2. Run the included fix script:
   ```bash
   ./fix_build.sh
   ```

3. Try the nuclear option:
   ```bash
   # Close Xcode first, then:
   rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*
   # Reopen Xcode and rebuild
   ```

## Test the Features

Once building successfully:

1. Run on a device (camera won't work on simulator)
2. Go to Profile tab
3. Tap camera icon on profile picture
4. You should see:
   - "Take Photo" option → Opens camera
   - "Choose from Library" option → Opens photo library
5. Select/take a photo
6. Adjust it with pinch and drag
7. Tap "Done"
8. Profile picture updates immediately everywhere!

---

**All code changes are complete!** This is just a build configuration fix in Xcode.
