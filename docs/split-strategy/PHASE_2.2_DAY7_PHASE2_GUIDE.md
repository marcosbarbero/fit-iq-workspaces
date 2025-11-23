# Phase 2.2 Day 7 - Phase 2 Quick Reference Guide

**Date:** 2025-01-27  
**Phase:** Phase 2 - Create New Infrastructure  
**Time Estimate:** 30 minutes  
**Status:** 🟡 Ready to Start  

---

## 🎯 Goal

Add FitIQCore's `HealthKitServiceProtocol` and `HealthAuthorizationServiceProtocol` to AppDependencies while keeping the bridge adapter temporarily for comparison.

---

## 📋 Quick Checklist

- [ ] Add `healthKitService` property to AppDependencies
- [ ] Add `authService` property to AppDependencies
- [ ] Wire up HealthKitService initialization
- [ ] Wire up HealthAuthorizationService initialization
- [ ] Verify compilation succeeds
- [ ] Keep bridge adapter (don't remove yet)

---

## 🔧 Implementation Steps

### Step 1: Import FitIQCore (If Not Already)

Add to top of `AppDependencies.swift`:

```swift
import FitIQCore
import HealthKit
```

### Step 2: Add FitIQCore Service Properties

Add these properties to `AppDependencies` class (after existing properties):

```swift
// MARK: - FitIQCore Services (NEW - Direct Integration)

/// FitIQCore's modern HealthKit service for querying and writing health data
lazy var healthKitService: HealthKitServiceProtocol = {
    let converter = HealthKitSampleConverter()
    let mapper = HealthKitTypeMapper()
    return HealthKitService(
        healthStore: HKHealthStore(),
        sampleConverter: converter,
        typeMapper: mapper
    )
}()

/// FitIQCore's authorization service for managing HealthKit permissions
lazy var authService: HealthAuthorizationServiceProtocol = {
    let mapper = HealthKitTypeMapper()
    return HealthAuthorizationService(
        healthStore: HKHealthStore(),
        typeMapper: mapper
    )
}()
```

### Step 3: Verify Existing Bridge (Keep for Now)

Ensure these properties still exist (don't remove):

```swift
// MARK: - Legacy (Keep for Day 7 comparison)

/// Bridge adapter (Day 6) - will be removed after migration
let healthRepository: HealthRepositoryProtocol
```

### Step 4: Build and Verify

1. Build the project: `Cmd+B`
2. Verify 0 errors
3. Verify 0 warnings
4. Services are ready to use but not yet consumed

---

## 📝 Expected File Location

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`

**Location in File:** Add new properties after existing service properties, before init method

---

## 🔍 Verification

### Compilation Check
```bash
# Should build successfully
xcodebuild -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Property Check
After adding, verify you can access:
- `appDependencies.healthKitService`
- `appDependencies.authService`
- `appDependencies.healthRepository` (still exists)

---

## 📊 What This Achieves

### Before Phase 2
```
FitIQ Use Cases
    ↓
HealthRepositoryProtocol (interface)
    ↓
FitIQHealthKitBridge (adapter)
    ↓
FitIQCore Services
```

### After Phase 2
```
FitIQ Use Cases (still using bridge)
    ↓
HealthRepositoryProtocol (interface)
    ↓
FitIQHealthKitBridge (adapter)
    ↓
FitIQCore Services ←─ ALSO AVAILABLE DIRECTLY

Direct Access Available:
appDependencies.healthKitService ✅
appDependencies.authService ✅
```

**Key Point:** We now have BOTH paths available:
- Legacy path via bridge (still works)
- Direct path via FitIQCore (ready for Phase 3 migration)

---

## 🚨 Important Notes

### DO NOT Remove Yet
- ❌ Don't remove `healthRepository` property
- ❌ Don't remove `FitIQHealthKitBridge` class
- ❌ Don't remove `HealthRepositoryProtocol`
- ❌ Don't update any use cases yet (that's Phase 3)

### Only Add, Don't Modify
- ✅ Add new FitIQCore service properties
- ✅ Keep all existing code unchanged
- ✅ Verify compilation succeeds
- ✅ Move to Phase 3 when ready

---

## 🎯 Success Criteria

- [x] FitIQCore imported
- [ ] `healthKitService` property added
- [ ] `authService` property added
- [ ] Bridge still exists and works
- [ ] Build succeeds (0 errors)
- [ ] No warnings introduced
- [ ] Ready for Phase 3 (use case migration)

---

## ⏭️ Next Phase

**Phase 3: Migrate Use Cases**
- Start with `GetLatestHeartRateUseCase` (simple query)
- Update to use `healthKitService` instead of `healthRepository`
- Verify it works before continuing

---

## 🔧 Troubleshooting

### Issue: FitIQCore types not found
**Solution:** Ensure FitIQCore is properly imported in Package.swift or Xcode project

### Issue: Circular dependency
**Solution:** FitIQCore services should have no dependencies on FitIQ - only on Foundation and HealthKit

### Issue: HKHealthStore init fails
**Solution:** This is normal - HealthKit only works on physical devices or simulators with HealthKit capability. The code will compile fine.

---

## 📚 Reference

### FitIQCore Service Protocols

**HealthKitServiceProtocol:**
- `queryLatest(type:unit:) -> HealthMetric?`
- `query(type:unit:options:) -> [HealthMetric]`
- `queryStatistics(type:unit:from:to:statisticsOption:) -> Double?`
- `save(_ metric: HealthMetric)`
- `saveWorkout(...)`
- `queryWorkouts(from:to:)`

**HealthAuthorizationServiceProtocol:**
- `requestAuthorization(toRead:toWrite:)`
- `authorizationStatus(for:) -> HKAuthorizationStatus`
- `isHealthKitAvailable: Bool`

### Supporting Types
- `HealthKitService` - Concrete implementation
- `HealthAuthorizationService` - Concrete implementation
- `HealthKitTypeMapper` - Type mapping (HK ↔ FitIQCore)
- `HealthKitSampleConverter` - Sample conversion

---

**Status:** 📋 Ready to Implement  
**Estimated Time:** 10-15 minutes  
**Risk:** 🟢 Low - Only adding new code, not changing existing  

**Let's add FitIQCore services! 🚀**