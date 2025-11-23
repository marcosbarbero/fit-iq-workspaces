# Lume FitIQCore Package Setup - Manual Instructions

**Status:** Required Manual Step  
**Priority:** HIGH - Blocks Lume Authentication Migration  
**Estimated Time:** 5 minutes

---

## Problem

Lume's Xcode project (`lume.xcodeproj`) needs to reference the local FitIQCore Swift package, but:
- Xcode's pbxproj format for local packages is version-specific
- Manual editing causes runtime errors: `-[XCLocalSwiftPackageReference group]: unrecognized selector`
- The package must be added through Xcode's GUI for proper integration

---

## Solution: Add FitIQCore Package via Xcode

### Step 1: Open Lume Project in Xcode

```bash
cd /Users/marcosbarbero/Develop/GitHub/fit-iq/lume
open lume.xcodeproj
```

**Alternative:** Open Xcode and select **File > Open** → Navigate to `lume.xcodeproj`

---

### Step 2: Add Local Package Dependency

1. **In Xcode**, ensure the `lume` project is selected in the Project Navigator (left sidebar)

2. **Click on the project** (top-level `lume` in the navigator)

3. **In the project editor**, select the **`lume` target** (under TARGETS)

4. **Go to the "Frameworks, Libraries, and Embedded Content" section**
   - Or navigate to: **File > Add Package Dependencies...**

5. **Click the "+" button** at the bottom of the frameworks list

6. **Select "Add Local..."** (or "Add Package Dependency" → "Add Local")

7. **Navigate to the FitIQCore directory:**
   ```
   /Users/marcosbarbero/Develop/GitHub/fit-iq/FitIQCore
   ```

8. **Click "Add Package"**

9. **Ensure `FitIQCore` is checked** in the "Add to Target" dialog

10. **Click "Add"**

---

### Step 3: Verify Package Was Added

In Xcode's Project Navigator, you should now see:
```
lume
├── lume (folder)
├── lumeTests (folder)
├── lumeUITests (folder)
└── Package Dependencies
    └── FitIQCore (local package)
```

In the **"Frameworks, Libraries, and Embedded Content"** section of the target, you should see:
```
FitIQCore
```

---

### Step 4: Verify Build

**In Xcode:**
1. Select **Product > Clean Build Folder** (⇧⌘K)
2. Select **Product > Build** (⌘B)
3. Build should succeed

**Or via Terminal:**
```bash
cd /Users/marcosbarbero/Develop/GitHub/fit-iq/lume
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 17' clean build
```

**Expected Output:**
```
** BUILD SUCCEEDED **
```

---

## Troubleshooting

### Issue 1: "Unable to find module dependency: 'FitIQCore'"

**Cause:** Package not properly linked to target

**Fix:**
1. Select `lume` target in Xcode
2. Go to **Build Phases** tab
3. Expand **"Dependencies"**
4. Click **"+"**
5. Add `FitIQCore`

---

### Issue 2: Package Not Visible in Navigator

**Cause:** Xcode cache issue

**Fix:**
1. Close Xcode
2. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*
   ```
3. Reopen Xcode
4. Retry adding package

---

### Issue 3: "Package.resolved" Conflicts

**Cause:** Git conflict or stale package resolution

**Fix:**
1. Delete `lume.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
2. In Xcode: **File > Packages > Reset Package Caches**
3. Rebuild project

---

## Verification Checklist

After adding the package, verify:

- [ ] FitIQCore appears in "Package Dependencies" in Project Navigator
- [ ] FitIQCore appears in "Frameworks, Libraries, and Embedded Content"
- [ ] `import FitIQCore` statements don't show errors
- [ ] Build succeeds without errors
- [ ] Run the following verification:

```bash
cd lume
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "(BUILD SUCCEEDED|error:)"
```

Should output:
```
** BUILD SUCCEEDED **
```

---

## What Happens Next?

Once FitIQCore package is successfully added and verified:

1. **Lume Authentication Migration** can proceed
2. AI assistant will:
   - Delete local `AuthToken.swift`
   - Add `TokenRefreshClient` to `AppDependencies`
   - Migrate `RemoteAuthService` to use FitIQCore
   - Migrate `AuthRepository` to use FitIQCore
   - Run tests and verify

---

## Why Can't This Be Automated?

Xcode's project file format (`.pbxproj`) is a complex, version-specific format:
- Different Xcode versions use different internal representations
- Local package references require specific object graph structures
- Manual editing often breaks internal consistency checks
- Xcode's GUI ensures proper structure and validation

**Best Practice:** Always add Swift packages through Xcode's GUI for local packages.

---

## Alternative: Workspace Approach (If Issues Persist)

If adding the package directly continues to fail, consider using an Xcode workspace:

```bash
cd /Users/marcosbarbero/Develop/GitHub/fit-iq
# Create workspace if it doesn't exist
xcodebuild -create-workspace -name FitIQ.xcworkspace

# Add projects to workspace (via Xcode GUI)
# File > Add Files to Workspace
# - Add FitIQ/FitIQ.xcodeproj
# - Add lume/lume.xcodeproj
# - Add FitIQCore package
```

Then lume can reference FitIQCore through the workspace.

---

## Contact

If issues persist after following these steps, please note:
- Current Xcode version: (run `xcodebuild -version`)
- Error messages from build
- Screenshot of Project Navigator showing Package Dependencies

---

**Last Updated:** 2025-01-27  
**Status:** Awaiting Manual Completion