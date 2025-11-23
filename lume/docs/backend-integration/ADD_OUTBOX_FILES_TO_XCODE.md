# Adding Outbox Pattern Files to Xcode Project

**Date:** 2025-01-15  
**Estimated Time:** 10-15 minutes  
**Status:** Required for Backend Synchronization

---

## Overview

This guide walks you through adding the newly created Outbox Pattern files to your Xcode project. These files enable reliable backend synchronization for mood tracking data.

---

## Files to Add (4 New Files)

### Core Network Infrastructure
- ✅ `lume/Core/Network/HTTPClient.swift`

### Backend Services
- ✅ `lume/Services/Backend/MoodBackendService.swift`
- ✅ `lume/Services/Outbox/OutboxProcessorService.swift`

### Documentation
- ✅ `lume/docs/backend-integration/OUTBOX_PATTERN_IMPLEMENTATION.md`
- ✅ `lume/docs/backend-integration/OUTBOX_IMPLEMENTATION_SUMMARY.md`
- ✅ `lume/docs/backend-integration/ADD_OUTBOX_FILES_TO_XCODE.md` (this file)

**Note:** 3 existing files were also modified but are already in your Xcode project.

---

## Step-by-Step Instructions

### Step 1: Open Xcode Project

1. Open Xcode
2. Open `lume.xcodeproj`
3. Wait for project to load and index

---

### Step 2: Add HTTPClient.swift

**Location:** `lume/Core/Network/HTTPClient.swift`

1. In Xcode Project Navigator (left sidebar), locate the **`Core`** group
2. Right-click on **`Core`** → **New Group**
3. Name it: **`Network`**
4. Right-click on the new **`Network`** group → **Add Files to "lume"...**
5. Navigate to: `lume/Core/Network/`
6. Select: **`HTTPClient.swift`**
7. ✅ Ensure **"Copy items if needed"** is UNCHECKED (file is already in correct location)
8. ✅ Ensure **"Create groups"** is selected
9. ✅ Ensure **"lume" target is checked** under "Add to targets"
10. Click **Add**

**Verify:**
- `HTTPClient.swift` appears under `Core/Network/` in Project Navigator
- File has **"lume"** target membership (check File Inspector)

---

### Step 3: Add Backend Services

**Location:** `lume/Services/Backend/MoodBackendService.swift`

1. In Xcode Project Navigator, locate the **`Services`** group
2. Right-click on **`Services`** → **New Group**
3. Name it: **`Backend`**
4. Right-click on the new **`Backend`** group → **Add Files to "lume"...**
5. Navigate to: `lume/Services/Backend/`
6. Select: **`MoodBackendService.swift`**
7. ✅ Ensure **"Copy items if needed"** is UNCHECKED
8. ✅ Ensure **"Create groups"** is selected
9. ✅ Ensure **"lume" target is checked**
10. Click **Add**

**Verify:**
- `MoodBackendService.swift` appears under `Services/Backend/` in Project Navigator

---

### Step 4: Add Outbox Processor Service

**Location:** `lume/Services/Outbox/OutboxProcessorService.swift`

1. In Xcode Project Navigator, locate the **`Services`** group
2. Right-click on **`Services`** → **New Group**
3. Name it: **`Outbox`**
4. Right-click on the new **`Outbox`** group → **Add Files to "lume"...**
5. Navigate to: `lume/Services/Outbox/`
6. Select: **`OutboxProcessorService.swift`**
7. ✅ Ensure **"Copy items if needed"** is UNCHECKED
8. ✅ Ensure **"Create groups"** is selected
9. ✅ Ensure **"lume" target is checked**
10. Click **Add**

**Verify:**
- `OutboxProcessorService.swift` appears under `Services/Outbox/` in Project Navigator

---

### Step 5: Build the Project

1. Press **⌘+B** (or Product → Build)
2. Wait for build to complete
3. **Expected:** Build Succeeds ✅

**If build fails:**
- Check that all 3 files are added to the "lume" target
- Check File Inspector for each file (right sidebar)
- Target Membership should show "lume" with checkmark

---

### Step 6: Verify File Structure

Your Xcode project structure should now look like this:

```
lume/
├── Core/
│   ├── Configuration/
│   │   ├── AppConfiguration.swift
│   │   └── AppMode.swift
│   ├── Extensions/
│   └── Network/                    ← NEW GROUP
│       └── HTTPClient.swift        ← ADDED
├── Services/
│   ├── Authentication/
│   │   ├── KeychainTokenStorage.swift
│   │   ├── MockAuthService.swift
│   │   └── RemoteAuthService.swift
│   ├── Backend/                    ← NEW GROUP
│   │   └── MoodBackendService.swift ← ADDED
│   └── Outbox/                     ← NEW GROUP
│       └── OutboxProcessorService.swift ← ADDED
├── DI/
│   └── AppDependencies.swift       (modified)
├── Data/
│   └── Repositories/
│       └── MoodRepository.swift    (modified)
└── lumeApp.swift                   (modified)
```

---

## Verification Checklist

After adding files, verify:

### File Presence
- [ ] `HTTPClient.swift` visible in Project Navigator under `Core/Network/`
- [ ] `MoodBackendService.swift` visible under `Services/Backend/`
- [ ] `OutboxProcessorService.swift` visible under `Services/Outbox/`

### Target Membership
- [ ] All 3 files have "lume" target checked
- [ ] Check in File Inspector (⌥+⌘+1) for each file

### Build Status
- [ ] Project builds successfully (⌘+B)
- [ ] No compilation errors
- [ ] No missing type errors

### Modified Files (Already in Xcode)
- [ ] `AppDependencies.swift` contains `outboxProcessorService` property
- [ ] `MoodRepository.swift` has updated `MoodPayload` with `userId`
- [ ] `lumeApp.swift` has `startOutboxProcessing()` method

---

## Common Issues

### Issue: "Cannot find type 'HTTPClient' in scope"

**Cause:** File not added to target

**Fix:**
1. Select `HTTPClient.swift` in Project Navigator
2. Open File Inspector (right sidebar)
3. Under "Target Membership", check "lume"
4. Build again (⌘+B)

---

### Issue: "No such module 'Foundation'"

**Cause:** Xcode indexing issue

**Fix:**
1. Clean build folder (⌘+⇧+K)
2. Close and reopen project
3. Build again (⌘+B)

---

### Issue: Files show in wrong location

**Cause:** Folder structure mismatch

**Fix:**
1. Remove files from Xcode (select → Delete → Remove Reference)
2. Re-add using steps above
3. Ensure "Copy items if needed" is UNCHECKED

---

### Issue: "Circular dependency" errors

**Cause:** Import cycle

**Fix:**
- This shouldn't happen with the provided files
- If it does, check you haven't modified import statements
- Verify file contents match the original implementation

---

## Next Steps

After successfully adding files to Xcode:

### 1. Configure Backend (Required)

Edit `config.plist`:
```xml
<key>BACKEND_BASE_URL</key>
<string>https://fit-iq-backend.fly.dev</string>

<key>API_KEY</key>
<string>your-api-key-here</string>
```

### 2. Enable Production Mode (When Ready)

Edit `lume/Core/Configuration/AppMode.swift`:
```swift
static var current: AppMode = .production
```

**Warning:** Only do this when backend is ready and configured!

### 3. Test the Implementation

1. **Local Mode Test (default):**
   - Track a mood
   - Verify it saves locally
   - No outbox events should be created

2. **Production Mode Test:**
   - Switch to production mode
   - Ensure valid auth token
   - Track a mood
   - Check console for outbox logs
   - Verify sync within 30 seconds

### 4. Read the Documentation

- **Full Guide:** `docs/backend-integration/OUTBOX_PATTERN_IMPLEMENTATION.md`
- **Summary:** `docs/backend-integration/OUTBOX_IMPLEMENTATION_SUMMARY.md`

---

## Testing Checklist

After adding files and building:

### Basic Tests
- [ ] App launches without crash
- [ ] Can track mood in local mode
- [ ] Console shows no errors

### Outbox Tests (Production Mode)
- [ ] Outbox processor starts on launch
- [ ] Mood tracking creates outbox event
- [ ] Event syncs within 30 seconds
- [ ] Console shows successful sync logs

### Offline Tests
- [ ] Track mood while offline
- [ ] Event stays in outbox (pending)
- [ ] Reconnect to network
- [ ] Event syncs automatically

---

## Success Criteria

You'll know everything is working when:

1. ✅ All files added to Xcode project
2. ✅ Project builds without errors (⌘+B)
3. ✅ App runs successfully (⌘+R)
4. ✅ Mood tracking works in local mode
5. ✅ Console shows outbox processor logs
6. ✅ (Production mode) Events sync to backend

---

## Getting Help

### Compilation Errors
- Double-check all 3 files have "lume" target membership
- Clean build folder (⌘+⇧+K) and rebuild
- Check file contents haven't been corrupted

### Runtime Errors
- Check console logs for detailed error messages
- Verify backend configuration in `config.plist`
- Ensure AppMode is set correctly

### Outbox Not Working
- See troubleshooting in `OUTBOX_PATTERN_IMPLEMENTATION.md`
- Check that modified files have latest changes
- Verify you're in production mode (if testing sync)

---

## File Addition Summary

**Total Time:** 10-15 minutes

**New Files Added:** 3 Swift files
- `HTTPClient.swift` - Network infrastructure
- `MoodBackendService.swift` - Mood API client
- `OutboxProcessorService.swift` - Event processor

**Modified Files:** 3 Swift files (already in Xcode)
- `AppDependencies.swift` - DI container updates
- `MoodRepository.swift` - Payload improvements
- `lumeApp.swift` - Lifecycle integration

**Result:** Complete outbox pattern implementation ready for production use

---

## Pro Tips

1. **Use Groups, Not Folders**
   - Xcode groups don't need to match filesystem structure
   - But matching makes navigation easier

2. **Check Target Membership Always**
   - Most "cannot find" errors are missing target membership
   - Quick check: File Inspector → Target Membership

3. **Clean Build for Import Issues**
   - ⌘+⇧+K clears derived data
   - Solves most "no such module" errors

4. **Test in Local Mode First**
   - Verify app works before enabling backend
   - Easier to isolate issues

5. **Read Console Logs**
   - Outbox processor logs everything
   - Logs show exactly what's happening

---

**Ready?** Follow the steps above to add the files and start syncing with the backend!

**Questions?** See the full documentation in `OUTBOX_PATTERN_IMPLEMENTATION.md`.

---

**Status:** Ready for File Addition  
**Next Step:** Follow Step 1 above  
**Estimated Time:** 10-15 minutes