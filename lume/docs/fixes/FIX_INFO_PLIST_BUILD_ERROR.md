# Fix: Multiple commands produce Info.plist

## The Error

```
Multiple commands produce '/path/to/lume.app/Info.plist'
```

This error occurs when Xcode tries to process Info.plist multiple times during the build.

## Root Cause

The most common cause is that Info.plist was accidentally added to the "Copy Bundle Resources" build phase. Xcode already handles Info.plist automatically, so having it in Copy Bundle Resources causes a conflict.

## Solution

Follow these steps in Xcode:

### Step 1: Open Build Phases

1. Open your project in Xcode
2. Select the **lume** project in the Project Navigator (left sidebar)
3. Select the **lume** target (under TARGETS)
4. Click on the **Build Phases** tab at the top

### Step 2: Check Copy Bundle Resources

1. Expand the **Copy Bundle Resources** section
2. Look for any entry named `Info.plist`
3. If you find it, select it and press **Delete** (or click the minus "-" button)
4. **Do not** delete the actual Info.plist file, just remove it from this build phase

### Step 3: Clean and Rebuild

1. In Xcode menu: **Product → Clean Build Folder** (or Cmd+Shift+K)
2. Rebuild: **Product → Build** (or Cmd+B)

The error should now be resolved.

## Alternative Causes

If the above doesn't fix it, check these:

### Check for Duplicate Files

1. In Project Navigator, search for "Info.plist"
2. Make sure there's only ONE Info.plist file in your target
3. If there are multiple, remove the duplicates (keep the one in the main target)

### Check Target Membership

1. Select Info.plist in Project Navigator
2. Look at the File Inspector (right sidebar)
3. Under "Target Membership", ensure only ONE target is checked
4. It should only be checked for the main app target, not any test targets

### Check Build Settings

1. Go to **Build Settings** tab
2. Search for "Info.plist"
3. Find **INFOPLIST_FILE** setting
4. Verify it points to the correct path (usually `lume/Info.plist` or `$(SRCROOT)/lume/Info.plist`)
5. Make sure there's only ONE value, not multiple paths

## For SwiftUI Apps Without Info.plist

Modern SwiftUI projects might not have a separate Info.plist file. Instead, settings are in the target's Info tab. If you don't have an Info.plist file:

1. Go to target → **Info** tab
2. Add the camera permissions directly there:
   - Click **+** button
   - Add **Privacy - Camera Usage Description**
   - Add **Privacy - Photo Library Usage Description**
3. No Info.plist file needed!

## Still Having Issues?

If none of the above works, try this nuclear option:

1. **Product → Clean Build Folder** (Cmd+Shift+K)
2. Close Xcode completely
3. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*
   ```
4. Reopen Xcode
5. Rebuild

## Verify the Fix

After fixing, you should be able to:
1. Build successfully (Cmd+B) with no errors
2. See the camera permissions in target → Info tab
3. Run the app and test profile picture features

---

**Note:** If you're using a modern Xcode project, you might not have a standalone Info.plist file at all. That's perfectly fine - just add the privacy descriptions directly in the target's Info tab.
