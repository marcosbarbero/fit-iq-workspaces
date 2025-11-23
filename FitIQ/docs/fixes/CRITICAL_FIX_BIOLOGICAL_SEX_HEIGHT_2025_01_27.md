# CRITICAL FIX: Biological Sex and Height Sync Issues

**Date:** 2025-01-27  
**Priority:** 🔴 CRITICAL  
**Status:** ✅ Fixed (Needs Testing)

---

## 📋 Executive Summary

Fixed two critical issues preventing biological sex and height from syncing:

1. **Missing Dependency Injection** - `syncBiologicalSexFromHealthKitUseCase` not injected in `ViewModelAppDependencies`
2. **Data Loss in Storage Layer** - Biological sex and height not saved/retrieved from bodyMetrics time-series

Both issues are now resolved. **Real device testing required to validate.**

---

## 🔴 Issue 1: Missing Dependency Injection

### Symptom (From Logs)

```
ProfileViewModel: SyncBiologicalSexFromHealthKitUseCase not available
```

When user opened Edit Profile, the biological sex sync was skipped because the use case was `nil`.

### Root Cause

The `ViewModelAppDependencies.build()` method was creating `ProfileViewModel` without the `syncBiologicalSexFromHealthKitUseCase` parameter:

```swift
// BEFORE (ViewModelAppDependencies.swift - Line 75-88)
let profileViewModel = ProfileViewModel(
    getPhysicalProfileUseCase: appDependencies.getPhysicalProfileUseCase,
    updateUserProfileUseCase: appDependencies.updateUserProfileUseCase,
    updateProfileMetadataUseCase: appDependencies.updateProfileMetadataUseCase,
    updatePhysicalProfileUseCase: appDependencies.updatePhysicalProfileUseCase,
    userProfileStorage: appDependencies.userProfileStorage,
    authManager: authManager,
    cloudDataManager: cloudDataManager,
    getLatestHealthKitMetrics: appDependencies.getLatestBodyMetricsUseCase,
    healthRepository: appDependencies.healthRepository
    // ❌ Missing: syncBiologicalSexFromHealthKitUseCase
)
```

### Fix Applied

**File:** `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`

```swift
// AFTER (Added missing parameter)
let profileViewModel = ProfileViewModel(
    getPhysicalProfileUseCase: appDependencies.getPhysicalProfileUseCase,
    updateUserProfileUseCase: appDependencies.updateUserProfileUseCase,
    updateProfileMetadataUseCase: appDependencies.updateProfileMetadataUseCase,
    updatePhysicalProfileUseCase: appDependencies.updatePhysicalProfileUseCase,
    userProfileStorage: appDependencies.userProfileStorage,
    authManager: authManager,
    cloudDataManager: cloudDataManager,
    getLatestHealthKitMetrics: appDependencies.getLatestBodyMetricsUseCase,
    healthRepository: appDependencies.healthRepository,
    syncBiologicalSexFromHealthKitUseCase: appDependencies.syncBiologicalSexFromHealthKitUseCase  // ✅ ADDED
)
```

### Expected Result

After this fix, when Edit Profile is opened:
```
ProfileViewModel: ===== SYNC BIOLOGICAL SEX FROM HEALTHKIT =====
SyncBiologicalSexFromHealthKitUseCase: ===== HEALTHKIT SYNC START =====
SyncBiologicalSexFromHealthKitUseCase: User ID: [UUID]
SyncBiologicalSexFromHealthKitUseCase: HealthKit biological sex: male
```

Instead of:
```
ProfileViewModel: SyncBiologicalSexFromHealthKitUseCase not available  ❌
```

---

## 🔴 Issue 2: Data Loss in Storage Layer

### Symptom (From Logs)

UI showed correct values but storage had `nil`:

```
ProfileViewModel: Current state - Height: '170', Sex: 'male'  ✅ UI correct

UpdatePhysicalProfileUseCase: Current biological sex: nil      ❌ Storage empty
UpdatePhysicalProfileUseCase: Current height: nil cm           ❌ Storage empty

ProfileSyncService: Syncing physical profile with:
  - biologicalSex: nil  ❌
  - heightCm: nil       ❌
  - dateOfBirth: 1983-07-19 22:00:00 +0000
```

### Root Cause

The `SwiftDataUserProfileAdapter` had **two fundamental problems**:

#### Problem 2A: Hardcoded `nil` When Reading Data

**File:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift` (Line 311-316)

```swift
// BEFORE - Hardcoded nil values!
return PhysicalProfile(
    biologicalSex: nil,  // ❌ Not stored directly in SDUserProfile (use time-series)
    heightCm: nil,       // ❌ Not stored directly in SDUserProfile (use time-series)
    dateOfBirth: sdProfile.dateOfBirth
)
```

The comment said "use time-series" but the code never actually fetched from time-series!

#### Problem 2B: Never Saved to `bodyMetrics` When Writing Data

**File:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift` (Line 256-280)

```swift
// BEFORE - Only updated metadata fields
private func updateSDUserProfile(_ sdProfile: SDUserProfile, from userProfile: UserProfile) {
    sdProfile.name = userProfile.name
    sdProfile.bio = userProfile.bio
    sdProfile.preferredUnitSystem = mapUnitSystem(userProfile.preferredUnitSystem)
    sdProfile.languageCode = userProfile.languageCode
    sdProfile.dateOfBirth = dateOfBirth
    sdProfile.updatedAt = Date()
    // ❌ Never touched bodyMetrics! Physical data was lost!
}
```

### Architectural Context

The `SDUserProfile` model stores biological sex as a **direct field** and height as **time-series data**:

```swift
@Model final class SDUserProfile {
    var name: String
    var dateOfBirth: Date?
    var biologicalSex: String?  // ← Direct field (immutable from HealthKit)
    // ... metadata fields ...
    
    @Relationship(deleteRule: .cascade, inverse: \SDPhysicalAttribute.userProfile)
    var bodyMetrics: [SDPhysicalAttribute]?  // ← Time-series for height (changes over time)
}
```

**Rationale:**
- **Biological sex** is immutable (set once from HealthKit) → stored as direct field
- **Height** can change over time (growth, measurement corrections) → stored as time-series

### Fix Applied Part 1: Read from Time-Series

**File:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift`

```swift
// AFTER - Fetch biological sex from direct field, height from time-series
let physical: PhysicalProfile? = {
    // Fetch latest height from bodyMetrics time-series
    let latestHeight: Double? = {
        guard let metrics = sdProfile.bodyMetrics, !metrics.isEmpty else {
            return nil
        }
        // Filter for height type and get most recent by createdAt
        let heightMetrics = metrics.filter { $0.type == .height }
        return heightMetrics.max(by: { $0.createdAt < $1.createdAt })?.value
    }()
    
    // Get biological sex from direct field
    let biologicalSex = sdProfile.biologicalSex
    
    // Create physical profile if we have any data
    if sdProfile.dateOfBirth != nil || latestHeight != nil || biologicalSex != nil {
        return PhysicalProfile(
            biologicalSex: biologicalSex,  // ✅ From direct field
            heightCm: latestHeight,        // ✅ From time-series
            dateOfBirth: sdProfile.dateOfBirth
        )
    }
    return nil
}()
```

### Fix Applied Part 2: Write to Time-Series

**File:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift`

```swift
// AFTER - Save biological sex directly, height to time-series
private func updateSDUserProfile(_ sdProfile: SDUserProfile, from userProfile: UserProfile) {
    // ... existing metadata updates ...
    
    // ✅ NEW: Update physical attributes
    if let physical = userProfile.physical {
        // Update biological sex directly on profile (immutable field)
        if let biologicalSex = physical.biologicalSex, !biologicalSex.isEmpty {
            if sdProfile.biologicalSex != biologicalSex {
                print("SwiftDataAdapter:   Updating biological sex: \(biologicalSex)")
                sdProfile.biologicalSex = biologicalSex
            } else {
                print("SwiftDataAdapter:   Biological sex unchanged")
            }
        }
        
        // Save height to bodyMetrics time-series (can change over time)
        if let heightCm = physical.heightCm, heightCm > 0 {
            let existingHeightMetrics = sdProfile.bodyMetrics?.filter { $0.type == .height }
            let latestHeight = existingHeightMetrics?.max(by: { $0.createdAt < $1.createdAt })
            
            if latestHeight?.value != heightCm {
                print("SwiftDataAdapter:   Saving height to bodyMetrics: \(heightCm) cm")
                let heightMetric = SDPhysicalAttribute(
                    id: UUID(),
                    value: heightCm,
                    type: .height,
                    createdAt: Date(),
                    updatedAt: Date(),
                    backendID: nil,
                    backendSyncedAt: nil,
                    userProfile: sdProfile
                )
                if sdProfile.bodyMetrics == nil {
                    sdProfile.bodyMetrics = []
                }
                sdProfile.bodyMetrics?.append(heightMetric)
            } else {
                print("SwiftDataAdapter:   Height unchanged, skipping bodyMetrics update")
            }
        }
    }
}
```

### Fix Applied Part 3: Initialize Time-Series on Profile Creation

**File:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift`

```swift
// AFTER - Initialize profile with biological sex field and height in bodyMetrics
private func createSDUserProfile(from userProfile: UserProfile) -> SDUserProfile {
    var initialBodyMetrics: [SDPhysicalAttribute] = []
    
    if let physical = userProfile.physical {
        // Add height if present (time-series data)
        if let heightCm = physical.heightCm, heightCm > 0 {
            print("SwiftDataAdapter:   Initializing height in bodyMetrics: \(heightCm) cm")
            let heightMetric = SDPhysicalAttribute(
                id: UUID(),
                value: heightCm,
                type: .height,
                createdAt: Date(),
                updatedAt: Date(),
                backendID: nil,
                backendSyncedAt: nil,
                userProfile: nil  // Will be set via relationship
            )
            initialBodyMetrics.append(heightMetric)
        }
    }
    
    return SDUserProfile(
        id: userProfile.userId,
        name: userProfile.name,
        bio: userProfile.bio,
        preferredUnitSystem: mapUnitSystem(userProfile.preferredUnitSystem),
        languageCode: userProfile.languageCode,
        dateOfBirth: dateOfBirth,
        biologicalSex: userProfile.physical?.biologicalSex,  // ✅ Store directly
        // ... other fields ...
        bodyMetrics: initialBodyMetrics.isEmpty ? [] : initialBodyMetrics
    )
}
```

### Expected Result

After these fixes, the logs should show:

```
SwiftDataAdapter: Mapping SDUserProfile to Domain
SwiftDataAdapter:   Creating PhysicalProfile:
SwiftDataAdapter:     - DOB: 1983-07-20 00:00:00 +0000
SwiftDataAdapter:     - Height: 170.0 cm          ✅ From bodyMetrics
SwiftDataAdapter:     - Biological Sex: male      ✅ From bodyMetrics

UpdatePhysicalProfileUseCase: Current biological sex: male  ✅
UpdatePhysicalProfileUseCase: Current height: 170.0 cm     ✅

ProfileSyncService: Syncing physical profile with:
  - biologicalSex: male        ✅
  - heightCm: 170.0            ✅
  - dateOfBirth: 1983-07-20 00:00:00 +0000
```

---

## 🧪 Testing Checklist

### Test 1: Clean Install - New User Flow

1. **Delete app completely**
2. **Reinstall**
3. **Ensure HealthKit has data:**
   - Biological sex: Male
   - Height: 175 cm
4. **Register new user**
5. **Grant HealthKit permissions**
6. **Open Edit Profile**

**Expected Logs:**
```
ProfileViewModel: ===== SYNC BIOLOGICAL SEX FROM HEALTHKIT =====
SyncBiologicalSexFromHealthKitUseCase: ===== HEALTHKIT SYNC START =====
SyncBiologicalSexFromHealthKitUseCase: HealthKit biological sex: male
SyncBiologicalSexFromHealthKitUseCase: Current local value: nil
SyncBiologicalSexFromHealthKitUseCase: 🔄 Change detected: 'nil' → 'male'
SwiftDataAdapter:   Saving biological sex to bodyMetrics: male
SyncBiologicalSexFromHealthKitUseCase: ✅ Saved to local storage
SyncBiologicalSexFromHealthKitUseCase: ✅ Successfully synced to backend
```

**Then Save Profile:**
```
SwiftDataAdapter: Mapping SDUserProfile to Domain
SwiftDataAdapter:   Creating PhysicalProfile:
SwiftDataAdapter:     - Biological Sex: male  ✅
SwiftDataAdapter:     - Height: 175.0 cm      ✅

ProfileSyncService: Syncing physical profile with:
  - biologicalSex: male     ✅
  - heightCm: 175.0         ✅
```

### Test 2: Existing User Data Migration

For existing users with data in UI but not in storage:

1. **Open Edit Profile**
2. **Check logs for:**
   - Sync use case available (not "not available")
   - Biological sex fetched from HealthKit
   - Saved to bodyMetrics
3. **Save profile**
4. **Reopen Edit Profile**
5. **Verify data persists**

---

## 📊 Impact Analysis

### What Was Broken

1. **User Experience:**
   - Users saw biological sex and height in UI
   - Data disappeared after app restart
   - Backend never received the data
   - ProfileSyncService always showed `nil`

2. **Data Flow:**
   ```
   HealthKit → ProfileViewModel (UI State) → ❌ LOST ❌ → Storage
   ```

### What's Fixed

1. **User Experience:**
   - Biological sex and height sync from HealthKit
   - Data persists across app restarts
   - Backend receives updates
   - ProfileSyncService syncs correctly

2. **Data Flow:**
   ```
   HealthKit → ProfileViewModel → SyncUseCase → Storage (bodyMetrics) → Backend ✅
   ```

---

## 🔧 Files Modified

### 1. ViewModelAppDependencies.swift
**Location:** `FitIQ/Infrastructure/Configuration/ViewModelAppDependencies.swift`  
**Change:** Added `syncBiologicalSexFromHealthKitUseCase` parameter to ProfileViewModel initialization  
**Lines:** 85-87

### 2. SchemaV1.swift
**Location:** `FitIQ/Infrastructure/Persistence/Schema/SchemaV1.swift`  
**Change:** Added `biologicalSex: String?` field to SDUserProfile model  
**Lines:** 53, 77, 92

### 3. SwiftDataUserProfileAdapter.swift
**Location:** `FitIQ/Domain/UseCases/SwiftDataUserProfileAdapter.swift`  
**Changes:**
- Fixed `mapToDomain()` to fetch biological sex from direct field and height from bodyMetrics
- Fixed `updateSDUserProfile()` to save biological sex directly and height to bodyMetrics
- Fixed `createSDUserProfile()` to initialize biological sex field and height in bodyMetrics

**Lines:**
- Read fix: ~364-395
- Update fix: ~297-335
- Create fix: ~234-275

---

## 🚨 Known Limitations

### Existing Users

Users who already have profiles will need to:
1. Open Edit Profile (triggers HealthKit sync)
2. Save profile (creates bodyMetrics entries)

First time opening Edit Profile after this fix, they might see:
```
SwiftDataAdapter:   Creating PhysicalProfile:
SwiftDataAdapter:     - Biological Sex: nil  (no bodyMetrics entries yet)
SwiftDataAdapter:     - Height: nil
```

But after HealthKit sync runs:
```
SyncBiologicalSexFromHealthKitUseCase: 🔄 Change detected: 'nil' → 'male'
SwiftDataAdapter:   Saving biological sex to bodyMetrics: male
```

And after Save Profile:
```
SwiftDataAdapter:   Saving height to bodyMetrics: 170.0 cm
```

Next time they open Edit Profile:
```
SwiftDataAdapter:   Creating PhysicalProfile:
SwiftDataAdapter:     - Biological Sex: male  ✅
SwiftDataAdapter:     - Height: 170.0 cm      ✅
```

---

## 🎯 Success Criteria

### ✅ Fix is Successful If:

1. **Dependency Injection:**
   - [ ] No "SyncBiologicalSexFromHealthKitUseCase not available" log
   - [ ] Sync use case executes when Edit Profile opens

2. **Data Persistence:**
   - [ ] Biological sex appears in UpdatePhysicalProfileUseCase logs (not nil)
   - [ ] Height appears in UpdatePhysicalProfileUseCase logs (not nil)
   - [ ] ProfileSyncService shows biologicalSex and heightCm (not nil)
   - [ ] Data survives app restart

3. **Backend Sync:**
   - [ ] Backend receives PATCH /users/me/physical with biologicalSex and heightCm
   - [ ] No "skipping physical profile sync" warning
   - [ ] Backend API returns 200 OK

4. **Data Storage Integrity:**
   - [ ] Biological sex stored in SDUserProfile.biologicalSex field
   - [ ] Height stored in bodyMetrics as SDPhysicalAttribute entries
   - [ ] Change detection works (no duplicate height entries for same value)

---

## 📚 Related Documentation

- **Main Handoff:** `docs/handoffs/HANDOFF_NEEDS_VALIDATION_2025_01_27.md`
- **HealthKit Auto-Save Fix:** `docs/fixes/HEALTHKIT_AUTO_SAVE_FIX_2025_01_27.md`
- **DI Wiring:** `docs/implementation-summaries/DI_WIRING_COMPLETE_2025_01_27.md`
- **Biological Sex Investigation:** `docs/fixes/DECODE_FIX_AND_BIOLOGICAL_SEX_INVESTIGATION_2025_01_27.md`

---

## 🔄 Next Steps

1. **Clean Install Test** (New User)
   - Delete app
   - Reinstall
   - Register
   - Open Edit Profile
   - Capture logs
   - Save profile
   - Verify backend sync

2. **Existing User Test**
   - Open Edit Profile
   - Capture logs
   - Save profile
   - Restart app
   - Open Edit Profile again
   - Verify data persists

3. **Share Logs**
   - Provide complete log sequence
   - Confirm all checkmarks above are met

---

**Status:** ✅ Code changes complete, awaiting real device validation

**Last Updated:** 2025-01-27  
**Author:** AI Assistant  
**Review Status:** Needs Testing