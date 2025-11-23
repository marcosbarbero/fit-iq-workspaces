# Phase 2.2 Day 6: FitIQHealthKitBridge Integration Guide

**Date:** 2025-01-27  
**Status:** 📋 Ready for Implementation  
**Purpose:** Step-by-step guide to integrate FitIQHealthKitBridge with FitIQCore

---

## 🎯 Overview

This guide provides detailed instructions for integrating the newly created `FitIQHealthKitBridge` adapter into the FitIQ app, enabling it to use FitIQCore's modern HealthKit infrastructure while maintaining backward compatibility with existing use cases.

---

## 📋 Prerequisites

Before starting, ensure:
- ✅ FitIQCore Phase 2.2 Days 2-5 complete (Health module implemented)
- ✅ FitIQHealthKitBridge.swift created (761 lines)
- ✅ HealthKitTypeTranslator.swift created (581 lines)
- ✅ HealthKitAdapter.swift marked as deprecated
- ✅ Xcode 15+ with Swift 5.9+
- ✅ iOS 17+ deployment target

---

## 🔧 Integration Steps

### Step 1: Add FitIQCore Package Dependency (Xcode)

Since FitIQCore is a local Swift package in the workspace:

1. **Open FitIQ.xcodeproj in Xcode**

2. **Select FitIQ target:**
   - In Project Navigator, click on FitIQ project (top)
   - Select "FitIQ" target (under Targets)

3. **Add FitIQCore dependency:**
   - Go to "General" tab
   - Scroll to "Frameworks, Libraries, and Embedded Content"
   - Click the "+" button
   - Select "FitIQCore" from the list
   - Set "Embed" to "Do Not Embed" (it's a static library)

4. **Verify build settings:**
   - Go to "Build Phases" tab
   - Expand "Link Binary With Libraries"
   - Verify FitIQCore.framework is listed

5. **Build to verify:**
   ```bash
   # In Xcode, press Cmd+B to build
   # Should complete with no errors
   ```

**Expected Result:** FitIQCore imports work throughout FitIQ project

---

### Step 2: Update AppDependencies.swift

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`

**Location in file:** Around line 437 (where `healthRepository` is created)

**Current code (to replace):**
```swift
let healthRepository = HealthKitAdapter()
```

**New code:**
```swift
// MARK: - FitIQCore Health Services (Phase 2.2 Day 6)
// New: Use FitIQCore infrastructure with bridge adapter for backward compatibility

// 1. Create FitIQCore HealthKit service
let healthKitService = HealthKitService(
    userProfile: userProfileService
)

// 2. Create FitIQCore authorization service
let healthAuthService = HealthAuthorizationService()

// 3. Create bridge adapter (implements HealthRepositoryProtocol using FitIQCore)
let healthRepository = FitIQHealthKitBridge(
    healthKitService: healthKitService,
    authService: healthAuthService,
    userProfile: userProfileService
)

// Note: Legacy HealthKitAdapter is deprecated and will be removed in Day 7-8
// let healthRepository = HealthKitAdapter() // ❌ DEPRECATED
```

**Important:** This change is near line 437 in `convenience init()` method, right before:
```swift
let healthKitAuthUseCase = HealthKitAuthorizationUseCase(healthRepository: healthRepository)
```

---

### Step 3: Import FitIQCore in Bridge Files

The bridge files already have the import, but verify:

**FitIQHealthKitBridge.swift:**
```swift
import FitIQCore  // ✅ Should be present
import Foundation
import HealthKit
```

**HealthKitTypeTranslator.swift:**
```swift
import FitIQCore  // ✅ Should be present
import Foundation
import HealthKit
```

---

### Step 4: Add New Files to Xcode Project (if not already added)

If you created the files outside Xcode, add them to the project:

1. **Right-click on `Infrastructure/Integration` folder in Xcode**
2. **Select "Add Files to FitIQ..."**
3. **Navigate to and select:**
   - `FitIQHealthKitBridge.swift`
   - `HealthKitTypeTranslator.swift`
4. **Ensure:**
   - ✅ "Copy items if needed" is UNCHECKED (files already in place)
   - ✅ "FitIQ" target is CHECKED
   - ✅ "Create groups" is selected

---

### Step 5: Build and Fix Compilation Errors

1. **Clean build folder:**
   ```
   Xcode menu: Product > Clean Build Folder
   Or: Cmd+Shift+K
   ```

2. **Build project:**
   ```
   Xcode menu: Product > Build
   Or: Cmd+B
   ```

3. **Common issues and fixes:**

   **Issue:** `Cannot find type 'HealthKitService' in scope`
   - **Fix:** Verify FitIQCore is added as dependency (Step 1)
   - **Fix:** Verify `import FitIQCore` at top of file

   **Issue:** `Cannot find type 'UserProfileServiceProtocol' in scope`
   - **Fix:** This is from FitIQCore.Profile module
   - **Fix:** Ensure using `FitIQCore.UserProfileServiceProtocol`

   **Issue:** `Value of type 'AppDependencies' has no member 'userProfileService'`
   - **Fix:** Check if `userProfileService` exists in AppDependencies
   - **Alternative:** Use `userProfileStorageAdapter` if that's what's available
   - **See "Adaptation Notes" section below**

4. **Expected warnings:**
   - Deprecation warning on `HealthKitAdapter` (expected, ignore)
   - Swift 6 concurrency warnings (non-blocking, address later)

---

### Step 6: Adaptation for AppDependencies Compatibility

FitIQ's AppDependencies may not have `userProfileService` as a standalone service. Adapt the bridge initialization:

**Option A: Use existing userProfileStorage**

If `userProfileService` doesn't exist, modify the bridge initialization in AppDependencies:

```swift
// MARK: - FitIQCore Health Services (Phase 2.2 Day 6)

// Create a wrapper that conforms to FitIQCore.UserProfileServiceProtocol
// This bridges FitIQ's SwiftDataUserProfileAdapter to FitIQCore's protocol
final class UserProfileServiceAdapter: UserProfileServiceProtocol {
    private let storage: UserProfileStoragePortProtocol
    
    init(storage: UserProfileStoragePortProtocol) {
        self.storage = storage
    }
    
    var currentProfile: UserProfile? {
        // Fetch from storage and convert to FitIQCore.UserProfile
        // For now, return nil (will implement proper conversion in Day 7)
        return nil
    }
}

let userProfileServiceAdapter = UserProfileServiceAdapter(
    storage: userProfileStorageAdapter
)

let healthKitService = HealthKitService(
    userProfile: userProfileServiceAdapter
)

let healthAuthService = HealthAuthorizationService()

let healthRepository = FitIQHealthKitBridge(
    healthKitService: healthKitService,
    authService: healthAuthService,
    userProfile: userProfileServiceAdapter
)
```

**Option B: Pass nil for now (Day 7 integration)**

For Day 6 testing, if full profile integration is complex:

```swift
// Temporary: Create minimal profile service for Day 6 testing
// Will be properly integrated in Day 7 when migrating use cases

// Note: HealthKitService can work with default unit system if userProfile is nil
let healthKitService = HealthKitService(
    userProfile: nil  // Uses metric as default
)

let healthAuthService = HealthAuthorizationService()

let healthRepository = FitIQHealthKitBridge(
    healthKitService: healthKitService,
    authService: healthAuthService,
    userProfile: nil  // Bridge will use default units
)
```

**Recommendation:** Use Option B for Day 6 to maintain focus on bridge functionality. Full profile integration happens in Day 7.

---

### Step 7: Run Unit Tests

1. **Run FitIQCore tests:**
   ```
   Xcode: Cmd+U on FitIQCore scheme
   ```
   - Expected: All pass (already tested Days 2-5)

2. **Run FitIQ tests:**
   ```
   Xcode: Cmd+U on FitIQ scheme
   ```
   - Expected: All existing tests pass
   - Some tests may need updates if they mock HealthKitAdapter directly

3. **Address test failures:**
   - Update mocks to use bridge if needed
   - Ensure tests don't depend on HealthKitAdapter internals

---

### Step 8: Manual Testing Checklist

#### Test 1: App Launch
- [ ] App launches without crashes
- [ ] No errors in console
- [ ] Bridge initialization log appears: `✅ FitIQHealthKitBridge initialized`

#### Test 2: HealthKit Authorization
- [ ] Navigate to profile or health settings
- [ ] Tap "Connect HealthKit" or similar
- [ ] HealthKit authorization prompt appears
- [ ] Grant permissions
- [ ] App receives authorization successfully
- [ ] No crashes or errors

#### Test 3: Query Health Data
- [ ] View displaying step count loads
- [ ] Step count shows correct value
- [ ] View displaying body mass loads
- [ ] Body mass shows correct value (in correct units)
- [ ] View displaying heart rate loads
- [ ] Heart rate shows correct value

#### Test 4: Save Health Data
- [ ] Navigate to body mass entry screen
- [ ] Enter weight (e.g., 70 kg)
- [ ] Tap save
- [ ] Data saves successfully
- [ ] Verify in Apple Health app that data appears
- [ ] Verify FitIQ displays saved value

#### Test 5: Background Sync
- [ ] Background sync triggers (check logs)
- [ ] Data syncs to backend
- [ ] No crashes during background operations

#### Test 6: Unit System (if profile integration complete)
- [ ] Change unit system in profile (metric ↔ imperial)
- [ ] Verify body mass displays in correct unit (kg vs lbs)
- [ ] Verify height displays in correct unit (cm vs ft/in)
- [ ] Verify distance displays in correct unit (km vs mi)

---

## 🧪 Testing Strategy

### Unit Tests for Bridge Adapter (Create in Day 7)

For Day 6, manual testing is sufficient. Day 7 will add comprehensive unit tests.

**Future test file:** `FitIQTests/Infrastructure/Integration/FitIQHealthKitBridgeTests.swift`

**Test cases to add later:**
```swift
// Test type conversion
func testConvertHKQuantityTypeToHealthDataType()

// Test query methods
func testFetchLatestQuantitySample_StepCount()
func testFetchQuantitySamples_WithPredicate()
func testFetchSumOfQuantitySamples()
func testFetchAverageQuantitySample()

// Test save methods
func testSaveQuantitySample_BodyMass()
func testSaveCategorySample_Mood()

// Test unit conversion
func testUnitConversion_KilogramsToMetric()
func testUnitConversion_KilogramsToImperial()

// Test observer pattern
func testStartObserving_Success()
func testStopObserving_Success()
```

---

## 🚨 Troubleshooting

### Build Error: "Cannot find type 'HealthKitService'"

**Cause:** FitIQCore not properly linked

**Solution:**
1. Verify FitIQCore is added to "Frameworks and Libraries" in target settings
2. Clean build folder (Cmd+Shift+K)
3. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
4. Rebuild

### Build Error: "Ambiguous use of 'UserProfile'"

**Cause:** Conflict between FitIQ's UserProfile and FitIQCore's UserProfile

**Solution:**
1. Fully qualify types: `FitIQCore.UserProfile` vs `UserProfile` (FitIQ's)
2. Use typealias to disambiguate:
   ```swift
   typealias CoreUserProfile = FitIQCore.UserProfile
   ```

### Runtime Error: "FitIQHealthKitBridge initialization failed"

**Cause:** Dependencies not properly initialized

**Solution:**
1. Check AppDependencies initialization order
2. Ensure `healthKitService` is created before bridge
3. Ensure `healthAuthService` is created before bridge
4. Check console logs for specific error

### Data Not Syncing

**Cause:** Observer pattern not properly set up

**Solution:**
1. Check that `onDataUpdate` callback is set in use cases
2. Verify observer queries are registered
3. Check HealthKit authorization status
4. Review console logs for errors

### Wrong Unit Displayed (kg shown as lbs)

**Cause:** User profile unit system not properly passed to bridge

**Solution:**
1. Verify `userProfile` parameter in bridge initialization
2. Check `UserProfile.unitSystem` property
3. Ensure conversion methods respect unit system
4. Test with both metric and imperial profiles

---

## 📊 Verification Checklist

### Build Verification
- [ ] FitIQ builds successfully
- [ ] No compilation errors
- [ ] Only expected deprecation warnings
- [ ] FitIQCore builds successfully

### Runtime Verification
- [ ] App launches without crashes
- [ ] Bridge initialization log appears
- [ ] HealthKit authorization works
- [ ] Step count query works
- [ ] Body mass query works
- [ ] Heart rate query works
- [ ] Body mass save works
- [ ] Background sync works

### Code Quality
- [ ] Bridge adapter properly implements all protocol methods
- [ ] Type conversions are comprehensive
- [ ] Unit conversions respect user preferences
- [ ] Error handling is robust
- [ ] Code is well-documented
- [ ] No code duplication

---

## 🎯 Success Criteria

Day 6 is complete when:

1. ✅ FitIQ builds with zero errors
2. ✅ FitIQ uses FitIQHealthKitBridge instead of HealthKitAdapter
3. ✅ All existing HealthKit features work identically
4. ✅ Unit tests pass (existing tests)
5. ✅ Manual testing checklist complete
6. ✅ No regression in functionality
7. ✅ Console shows bridge initialization log
8. ✅ HealthKit authorization flow works
9. ✅ Data queries return correct values
10. ✅ Data saves persist to HealthKit

---

## 📝 Known Limitations (Day 6)

These are expected and will be addressed in Day 7-8:

1. **Profile Integration:** May use nil/default profile for Day 6
2. **Unit System:** May default to metric if profile not integrated
3. **Workout Operations:** Bridge uses direct HKHealthStore for workouts
4. **Characteristics:** Bridge uses direct HKHealthStore for DOB/sex
5. **Observer Pattern:** Uses legacy callback pattern, not AsyncStream
6. **Type Coverage:** Some exotic health types may not be mapped

**Note:** All limitations are documented and have migration plans for Day 7-8.

---

## 🔄 Rollback Plan

If integration causes critical issues:

1. **Revert AppDependencies.swift:**
   ```swift
   let healthRepository = HealthKitAdapter()
   ```

2. **Comment out bridge initialization:**
   ```swift
   // let healthKitService = HealthKitService(...)
   // let healthAuthService = HealthAuthorizationService()
   // let healthRepository = FitIQHealthKitBridge(...)
   ```

3. **Build and verify app works with legacy adapter**

4. **Document issues for investigation**

5. **Resume integration after resolving blockers**

---

## 📚 Related Documents

- [Phase 2.2 Implementation Plan](../../docs/split-strategy/PHASE_2.2_HEALTHKIT_EXTRACTION_PLAN.md)
- [Day 6 Progress Tracking](../../docs/split-strategy/PHASE_2.2_DAY6_PROGRESS.md)
- [FitIQCore Health Module README](../../FitIQCore/Sources/FitIQCore/Health/README.md)
- [FitIQCore Health Service Protocol](../../FitIQCore/Sources/FitIQCore/Health/Domain/Ports/HealthKitServiceProtocol.swift)

---

## 🚀 Next Steps (Day 7)

After Day 6 completion and verification:

1. **Migrate Use Cases to FitIQCore Types**
   - Update use cases to use `HealthDataType` instead of `HKQuantityTypeIdentifier`
   - Update method signatures to use FitIQCore models
   - Remove HKUnit parameters (handled by user profile)

2. **Remove Bridge Layer**
   - Delete `HealthRepositoryProtocol` (replace with direct FitIQCore usage)
   - Delete `FitIQHealthKitBridge` (no longer needed)
   - Delete `HealthKitAdapter` (legacy)

3. **Direct FitIQCore Integration**
   - Use cases directly use `HealthKitServiceProtocol`
   - ViewModels directly use `HealthKitServiceProtocol`
   - Remove all HealthKit type dependencies from domain layer

4. **Migrate Observer Pattern**
   - Replace legacy callbacks with AsyncStream
   - Use `healthKitService.observeChanges(for:)` directly
   - Remove observer query management code

---

## 📞 Support

If you encounter issues:

1. **Check console logs** for error messages
2. **Review troubleshooting section** above
3. **Check FitIQCore tests** to verify infrastructure is working
4. **Consult Phase 2.2 planning docs** for architecture context
5. **Create issue** with detailed logs and steps to reproduce

---

**Last Updated:** 2025-01-27  
**Status:** Ready for implementation  
**Estimated Time:** 2-3 hours for full integration and testing