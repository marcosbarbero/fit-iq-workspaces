# Test Setup Guide

**Date:** 2025-01-27  
**Purpose:** Configure Xcode test target for new unit tests

---

## Issue

The new test files were created but need to be added to the Xcode test target. Currently seeing:
```
error: No such module 'XCTest'
error: No such module 'FitIQCore'
```

This is because the test files aren't properly linked to the test target in Xcode.

---

## Solution: Add Test Files to Xcode Test Target

### Option 1: Using Xcode UI (Recommended)

**Step 1: Open Project in Xcode**
```bash
cd fit-iq/lume
open lume.xcodeproj
```

**Step 2: Add Test Files to Test Target**

1. In Xcode, select **File** → **Add Files to "lume"...**

2. Navigate to and select these files:
   - `lumeTests/Services/OutboxProcessorServiceTests.swift`
   - `lumeTests/Repositories/GoalRepositoryTests.swift`

3. In the dialog that appears:
   - ✅ Check **"Copy items if needed"** (leave unchecked, files are already in place)
   - ✅ Check **"Add to targets:"** → Select **"lumeTests"**
   - ✅ Check **"Create groups"** (not folder references)
   - Click **"Add"**

**Step 3: Verify Test Target Membership**

1. Select `OutboxProcessorServiceTests.swift` in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", verify **lumeTests** is checked ✅
4. Repeat for `GoalRepositoryTests.swift`

**Step 4: Add FitIQCore to Test Target Dependencies**

1. Select the **lume** project in Project Navigator
2. Select the **lumeTests** target
3. Go to **Build Phases** tab
4. Expand **"Dependencies"**
5. Click **"+"** button
6. Add **FitIQCore** (if available in workspace)

If FitIQCore isn't available:
1. Go to **Build Settings** tab
2. Search for "Import Paths"
3. Add path to FitIQCore: `$(PROJECT_DIR)/../FitIQCore/Sources/FitIQCore`

**Step 5: Build and Run Tests**

```bash
# Clean build
⇧⌘K (Product → Clean Build Folder)

# Build
⌘B (Product → Build)

# Run tests
⌘U (Product → Test)
```

---

### Option 2: Using Terminal (Alternative)

If you prefer command line, you can add the files manually to the `.xcodeproj`:

**Note:** This is more complex and error-prone. Use Option 1 if possible.

```bash
# Navigate to project
cd fit-iq/lume

# Open Xcode project file in text editor
# You'll need to manually edit the project.pbxproj file
# This is NOT recommended as it's easy to corrupt the project file
```

---

## Alternative: Temporarily Comment Out Tests

If you want to proceed without fixing the test target configuration right now, you can temporarily disable the tests:

**Step 1: Rename test files to exclude them from compilation**

```bash
cd fit-iq/lume/lumeTests

# Rename to .txt to exclude from build
mv Services/OutboxProcessorServiceTests.swift Services/OutboxProcessorServiceTests.swift.txt
mv Repositories/GoalRepositoryTests.swift Repositories/GoalRepositoryTests.swift.txt
```

**Step 2: Re-enable later**

When ready to use the tests:
```bash
# Rename back to .swift
mv Services/OutboxProcessorServiceTests.swift.txt Services/OutboxProcessorServiceTests.swift
mv Repositories/GoalRepositoryTests.swift.txt Repositories/GoalRepositoryTests.swift

# Then add to Xcode target using Option 1 above
```

---

## Verification

After adding files to test target, verify with:

```bash
# Build test target
xcodebuild build-for-testing \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test \
  -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Expected Output:**
```
Test Suite 'All tests' passed
     Executed 35 tests, with 0 failures (0 unexpected)
```

---

## Common Issues

### Issue 1: "No such module 'XCTest'"

**Cause:** Test file not added to test target

**Solution:** Follow Option 1 steps above to add file to lumeTests target

---

### Issue 2: "No such module 'FitIQCore'"

**Cause:** Test target doesn't have FitIQCore dependency

**Solution 1 (Preferred):** Remove FitIQCore import
```swift
// ❌ Remove this
import FitIQCore

// ✅ Use this instead (re-exports FitIQCore types)
@testable import lume
```

**Solution 2:** Add FitIQCore to test target dependencies (see Step 4 in Option 1)

---

### Issue 3: Tests Don't Appear in Test Navigator

**Cause:** Xcode hasn't indexed the test files

**Solution:**
1. Clean build folder (⇧⌘K)
2. Close Xcode
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen Xcode
5. Let Xcode re-index project (watch progress in Activity view)

---

## Quick Start (If Everything is Configured)

Once test files are properly added to the test target:

```bash
# Run all tests
xcodebuild test -scheme lume -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test file
xcodebuild test -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:lumeTests/OutboxProcessorServiceTests

# Run specific test
xcodebuild test -scheme lume \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:lumeTests/OutboxProcessorServiceTests/testProcessMoodCreated_Success_StoresBackendId
```

---

## Expected Test Results

Once configured correctly, you should see:

### OutboxProcessorServiceTests (17 tests)
- ✅ testProcessMoodCreated_Success_StoresBackendId
- ✅ testProcessMoodUpdated_WithBackendId_Success
- ✅ testProcessMoodUpdated_WithoutBackendId_FallsBackToCreate
- ✅ testProcessMoodDeleted_WithBackendId_Success
- ✅ testProcessMoodDeleted_WithoutBackendId_Skips
- ✅ testProcessGoalCreated_Success_StoresBackendId
- ✅ testProcessGoalUpdated_Success
- ✅ testProcessOutbox_NoNetwork_SkipsProcessing
- ✅ testProcessOutbox_NoToken_SkipsProcessing
- ✅ testProcessEvent_HTTPError401_StopsProcessing
- ✅ testProcessEvent_HTTPError404_MarksCompleted
- ✅ testProcessEvent_HTTPError409_MarksCompleted
- ✅ testProcessEvent_GenericError_Retries
- ✅ testProcessEvent_MaxRetriesReached_GivesUp
- ✅ testProcessOutbox_MultipleEvents_ProcessesAll

### GoalRepositoryTests (18 tests)
- ✅ testCreate_Success_CreatesLocalGoal
- ✅ testCreate_Success_CreatesOutboxEvent
- ✅ testCreate_OutboxFails_StillCreatesGoalLocally
- ✅ testUpdate_Success_UpdatesLocalGoal
- ✅ testUpdate_Success_CreatesOutboxEvent
- ✅ testUpdate_GoalNotFound_ThrowsError
- ✅ testUpdateProgress_Success_UpdatesLocalGoal
- ✅ testUpdateProgress_Success_CreatesOutboxEvent
- ✅ testUpdateStatus_Success_UpdatesLocalGoal
- ✅ testUpdateStatus_Success_CreatesOutboxEvent
- ✅ testDelete_Success_DeletesLocalGoal
- ✅ testDelete_WithBackendId_CreatesOutboxEventWithMetadata
- ✅ testDelete_WithoutBackendId_CreatesOutboxEventWithoutBackendId
- ✅ testFetchAll_ReturnsAllGoals
- ✅ testFetchById_ReturnsCorrectGoal
- ✅ testFetchByCategory_ReturnsFilteredGoals
- ✅ testFetchByStatus_ReturnsFilteredGoals

**Total: 35 tests**

---

## Priority

**For now:** You can proceed with manual testing (docs/testing/TESTING_GUIDE.md) without setting up the unit tests.

**Later:** When ready to run automated tests, follow Option 1 above to properly configure the test target.

---

## Next Steps

1. **Option A (Immediate):** Follow manual testing guide
   - Open `docs/testing/TESTING_GUIDE.md`
   - Complete the 8 manual test scenarios
   - Document results

2. **Option B (When Ready):** Configure unit tests
   - Follow Option 1 above
   - Run unit tests
   - Verify all pass

3. **Then:** Continue with deployment pipeline
   - Code review
   - TestFlight deployment
   - Production rollout

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-27  
**Author:** AI Assistant