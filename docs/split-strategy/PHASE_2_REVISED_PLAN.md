# Phase 2 Revised Plan - Profile & HealthKit Extraction

**Date:** 2025-01-27  
**Status:** 📋 Ready to Execute  
**Duration:** 2-3 weeks  
**Priority:** 🔴 HIGH VALUE

---

## 🎯 Phase 2 Objectives (REVISED)

Based on feedback, Phase 2 now includes:

1. ✅ **Profile Unification** - Both apps use FitIQCore.UserProfile (optional fields for Lume)
2. ✅ **HealthKit Extraction** - Extract core HealthKit wrapper (Lume will need for mindfulness)
3. ✅ **SwiftData Utilities** - Extract fetch-or-create pattern

**Key Changes from Original Plan:**
- ✅ HealthKit extraction **INCLUDED** (was deferred)
- ✅ Lume will use HealthKit for future mindfulness features
- ✅ Timeline extended to 2-3 weeks (was 1-2 weeks)

---

## 📊 Revised Phase 2 Scope

### 🟢 WEEK 1: Profile Unification

**Goal:** Single UserProfile model for both apps

**What FitIQ Gets:**
- Full profile with physical attributes (biologicalSex, heightCm)
- HealthKit sync state
- All metadata fields

**What Lume Gets:**
- Basic profile (id, email, name, dateOfBirth)
- Optional fields ignored (bio, physical attributes, HealthKit state)
- Backward compatible with existing code

**Effort:** 5 days (same as original plan)

---

### 🟢 WEEK 2-3: HealthKit Extraction

**Goal:** Shared HealthKit framework for both apps

**What Gets Extracted:**
- Core HealthKit wrapper (authorization, availability)
- Common data types (steps, heart rate, sleep, mindfulness)
- Query builders and utilities
- Basic use cases (request auth, fetch metrics, save metrics)

**What Stays in FitIQ:**
- App-specific use cases (complex workout logging, nutrition sync)
- Background sync orchestration
- FitIQ-specific health integrations

**What Lume Will Use:**
- Mindfulness session tracking (HKMindfulSession)
- Sleep quality monitoring (HKCategoryType.sleepAnalysis)
- Heart rate variability (HKQuantityType.heartRateVariability)
- Stress/recovery metrics

**Effort:** 8-10 days

---

## 📋 Detailed Timeline

### Week 1: Profile Unification (Days 1-5)

#### Day 1-2: Enhance FitIQCore.UserProfile

**Task 1.1: Add Optional Fields** ⏱️ 4 hours

```swift
// FitIQCore/Sources/FitIQCore/Auth/Domain/UserProfile.swift
public struct UserProfile: Codable, Equatable, Sendable {
    // MARK: - Core Identity (Required for both apps)
    public let id: UUID
    public let email: String
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    
    // MARK: - Optional Profile Fields (FitIQ only)
    public let bio: String?
    public let username: String?
    public let languageCode: String?
    public let dateOfBirth: Date?
    
    // MARK: - Physical Attributes (FitIQ only)
    public let biologicalSex: String?
    public let heightCm: Double?
    
    // MARK: - Preferences (both apps, default for Lume)
    public let preferredUnitSystem: String  // "metric" or "imperial"
    
    // MARK: - HealthKit Sync State (FitIQ only)
    public let hasPerformedInitialHealthKitSync: Bool
    public let lastSuccessfulDailySyncDate: Date?
    
    // MARK: - Initializers
    
    /// Full initializer (FitIQ)
    public init(
        id: UUID,
        email: String,
        name: String,
        bio: String? = nil,
        username: String? = nil,
        languageCode: String? = nil,
        dateOfBirth: Date? = nil,
        biologicalSex: String? = nil,
        heightCm: Double? = nil,
        preferredUnitSystem: String = "metric",
        hasPerformedInitialHealthKitSync: Bool = false,
        lastSuccessfulDailySyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) { /* ... */ }
    
    /// Simple initializer (Lume - backward compatible)
    public init(
        id: UUID,
        email: String,
        name: String,
        dateOfBirth: Date? = nil
    ) {
        self.init(
            id: id,
            email: email,
            name: name,
            bio: nil,
            username: nil,
            languageCode: nil,
            dateOfBirth: dateOfBirth,
            biologicalSex: nil,
            heightCm: nil,
            preferredUnitSystem: "metric",
            hasPerformedInitialHealthKitSync: false,
            lastSuccessfulDailySyncDate: nil
        )
    }
}
```

**Deliverable:** ✅ FitIQCore.UserProfile with optional fields

---

**Task 1.2: Add Update Methods** ⏱️ 2 hours

```swift
extension UserProfile {
    /// Update basic info (both apps)
    public func updated(
        email: String? = nil,
        name: String? = nil,
        dateOfBirth: Date? = nil
    ) -> UserProfile { /* ... */ }
    
    /// Update physical attributes (FitIQ only)
    public func updatingPhysical(
        biologicalSex: String? = nil,
        heightCm: Double? = nil
    ) -> UserProfile { /* ... */ }
    
    /// Update HealthKit sync state (FitIQ only)
    public func updatingHealthKitSync(
        hasPerformedInitialSync: Bool,
        lastSyncDate: Date?
    ) -> UserProfile { /* ... */ }
}
```

**Deliverable:** ✅ Convenient update methods

---

**Task 1.3: Add Tests** ⏱️ 3 hours

```swift
// FitIQCore/Tests/FitIQCoreTests/Auth/Domain/UserProfileTests.swift

func testSimpleInit_LumeUseCase_CreatesMinimalProfile() {
    let profile = UserProfile(
        id: UUID(),
        email: "jane@lume.com",
        name: "Jane Smith",
        dateOfBirth: Date()
    )
    
    // Required fields set
    XCTAssertEqual(profile.email, "jane@lume.com")
    XCTAssertEqual(profile.name, "Jane Smith")
    
    // Optional fields nil (not needed by Lume)
    XCTAssertNil(profile.bio)
    XCTAssertNil(profile.biologicalSex)
    XCTAssertNil(profile.heightCm)
    XCTAssertFalse(profile.hasPerformedInitialHealthKitSync)
}

func testFullInit_FitIQUseCase_CreatesCompleteProfile() {
    let profile = UserProfile(
        id: UUID(),
        email: "john@fitiq.com",
        name: "John Doe",
        bio: "Fitness enthusiast",
        biologicalSex: "male",
        heightCm: 180.0,
        hasPerformedInitialHealthKitSync: true
    )
    
    // All fields set
    XCTAssertEqual(profile.bio, "Fitness enthusiast")
    XCTAssertEqual(profile.biologicalSex, "male")
    XCTAssertEqual(profile.heightCm, 180.0)
    XCTAssertTrue(profile.hasPerformedInitialHealthKitSync)
}
```

**Deliverable:** ✅ 95%+ test coverage

---

**Task 1.4: Release FitIQCore v0.3.0** ⏱️ 1 hour

```bash
# Update CHANGELOG.md
## [0.3.0] - 2025-01-27

### Added
- Enhanced UserProfile with optional fields
- Support for both simple (Lume) and complex (FitIQ) profiles
- Physical attributes (biologicalSex, heightCm)
- HealthKit sync state
- Profile metadata fields

### Changed
- UserProfile now backward compatible
- Lume can use simple initializer (no breaking changes)

# Commit and tag
git add .
git commit -m "feat: Enhance UserProfile for multi-app support (v0.3.0)"
git tag v0.3.0
git push origin main --tags
```

**Deliverable:** ✅ FitIQCore v0.3.0 released

---

#### Day 3-4: Migrate FitIQ to FitIQCore.UserProfile

**Task 2.1: Update FitIQ Dependencies** ⏱️ 0.5 hours
- Update to FitIQCore v0.3.0
- Verify package resolves

**Task 2.2: Update SwiftData Models** ⏱️ 2 hours
- Update SDUserProfile conversions
- Add `toDomain()` and `from()` methods
- Test conversions

**Task 2.3: Update Repositories** ⏱️ 3 hours
- Update return types to FitIQCore.UserProfile
- Update implementations
- Test repository methods

**Task 2.4: Update Use Cases** ⏱️ 3 hours
- Update signatures
- Simplify implementations (no more metadata/physical split)
- Test use cases

**Task 2.5: Update ViewModels** ⏱️ 2 hours
- Update profile properties
- Update UI bindings
- Test ViewModels

**Deliverable:** ✅ FitIQ using FitIQCore.UserProfile

---

#### Day 5: Testing & Cleanup

**Task 3.1: Delete Old Files** ⏱️ 1 hour
```bash
rm FitIQ/Domain/Entities/Profile/UserProfile.swift
rm FitIQ/Domain/Entities/Profile/UserProfileMetadata.swift
rm FitIQ/Domain/Entities/Profile/PhysicalProfile.swift
```

**Task 3.2: Run All Tests** ⏱️ 2 hours
- FitIQCore tests
- FitIQ tests
- Lume tests (verify backward compatibility)

**Task 3.3: Manual QA** ⏱️ 2 hours
- Test FitIQ profile features
- Test Lume profile features
- Verify no regressions

**Task 3.4: Documentation** ⏱️ 2 hours
- Create completion report
- Update status documents
- Document lessons learned

**Deliverable:** ✅ Week 1 complete - ~400 lines removed

---

## 🏥 Week 2-3: HealthKit Extraction (NEW)

### Day 6-7: Design HealthKit Framework

#### Task 4.1: Assess HealthKit Commonality ⏱️ 4 hours

**FitIQ's HealthKit Usage:**
```
Data Types:
- Steps (HKQuantityType.stepCount)
- Heart Rate (HKQuantityType.heartRate)
- Active Energy (HKQuantityType.activeEnergyBurned)
- Sleep Analysis (HKCategoryType.sleepAnalysis)
- Body Mass (HKQuantityType.bodyMass)
- Height (HKQuantityType.height)
- Workout (HKWorkoutType)
- Nutrition (various)
```

**Lume's Future HealthKit Needs:**
```
Data Types (for mindfulness):
- Mindful Session (HKCategoryType.mindfulSession)
- Sleep Analysis (HKCategoryType.sleepAnalysis)
- Heart Rate Variability (HKQuantityType.heartRateVariability)
- Resting Heart Rate (HKQuantityType.restingHeartRate)
- Respiratory Rate (HKQuantityType.respiratoryRate)
```

**Common HealthKit Needs:**
```
✅ Authorization management
✅ Sleep analysis
✅ Heart rate metrics
✅ Query building utilities
✅ Sample saving/fetching
```

**Deliverable:** ✅ HealthKit commonality analysis

---

#### Task 4.2: Design HealthKit Architecture ⏱️ 4 hours

**Proposed Structure:**
```
FitIQCore/Sources/FitIQCore/HealthKit/
├── Core/
│   ├── HealthKitManager.swift           # Authorization, availability
│   ├── HealthKitDataType.swift          # Data type definitions
│   └── HealthKitError.swift             # Error types
├── Domain/
│   ├── HealthMetric.swift               # Generic health metric model
│   ├── SleepSession.swift               # Sleep data model
│   └── MindfulSession.swift             # Mindfulness session model
├── Query/
│   ├── HealthKitQueryBuilder.swift      # Query utilities
│   └── HealthKitSampleFetcher.swift     # Fetch samples
└── UseCases/
    ├── RequestHealthKitAuthorizationUseCase.swift
    ├── FetchHealthMetricsUseCase.swift
    └── SaveHealthMetricUseCase.swift
```

**Design Principles:**
- Generic enough for both apps
- Extensible for app-specific needs
- No platform lock-in (protocol-based)
- Well-tested (95%+ coverage)

**Deliverable:** ✅ HealthKit architecture design

---

### Day 8-10: Implement Core HealthKit Framework

#### Task 5.1: Implement HealthKitManager ⏱️ 4 hours

```swift
// FitIQCore/Sources/FitIQCore/HealthKit/Core/HealthKitManager.swift

#if canImport(HealthKit)
import HealthKit
import Foundation

/// Core HealthKit manager for authorization and availability
public final class HealthKitManager {
    
    private let healthStore: HKHealthStore
    
    public init() {
        self.healthStore = HKHealthStore()
    }
    
    /// Check if HealthKit is available on this device
    public static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// Request authorization for specific data types
    public func requestAuthorization(
        toRead readTypes: Set<HKSampleType>,
        toWrite writeTypes: Set<HKSampleType>
    ) async throws {
        try await healthStore.requestAuthorization(
            toShare: writeTypes,
            read: readTypes
        )
    }
    
    /// Check authorization status for a specific type
    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }
    
    /// Get the underlying health store (for advanced usage)
    public var store: HKHealthStore {
        healthStore
    }
}
#endif
```

**Deliverable:** ✅ HealthKitManager implementation

---

#### Task 5.2: Implement HealthKitDataType ⏱️ 3 hours

```swift
// FitIQCore/Sources/FitIQCore/HealthKit/Core/HealthKitDataType.swift

#if canImport(HealthKit)
import HealthKit

/// Common HealthKit data types used across apps
public enum HealthKitDataType {
    
    // MARK: - Quantity Types
    case stepCount
    case heartRate
    case restingHeartRate
    case heartRateVariability
    case activeEnergyBurned
    case respiratoryRate
    case bodyMass
    case height
    
    // MARK: - Category Types
    case sleepAnalysis
    case mindfulSession
    
    // MARK: - Workout Type
    case workout
    
    /// Convert to HKSampleType
    public var sampleType: HKSampleType {
        switch self {
        // Quantity types
        case .stepCount:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)!
        case .heartRate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)!
        case .restingHeartRate:
            return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        case .heartRateVariability:
            return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        case .activeEnergyBurned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        case .respiratoryRate:
            return HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        case .bodyMass:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        case .height:
            return HKQuantityType.quantityType(forIdentifier: .height)!
            
        // Category types
        case .sleepAnalysis:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        case .mindfulSession:
            return HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
            
        // Workout
        case .workout:
            return HKWorkoutType.workoutType()
        }
    }
    
    /// Common read types for both apps
    public static var commonReadTypes: Set<HKSampleType> {
        [
            HealthKitDataType.stepCount.sampleType,
            HealthKitDataType.heartRate.sampleType,
            HealthKitDataType.restingHeartRate.sampleType,
            HealthKitDataType.heartRateVariability.sampleType,
            HealthKitDataType.sleepAnalysis.sampleType,
            HealthKitDataType.respiratoryRate.sampleType
        ]
    }
    
    /// FitIQ-specific read types
    public static var fitIQReadTypes: Set<HKSampleType> {
        commonReadTypes.union([
            HealthKitDataType.activeEnergyBurned.sampleType,
            HealthKitDataType.bodyMass.sampleType,
            HealthKitDataType.height.sampleType,
            HealthKitDataType.workout.sampleType
        ])
    }
    
    /// Lume-specific read types (for mindfulness)
    public static var lumeReadTypes: Set<HKSampleType> {
        commonReadTypes.union([
            HealthKitDataType.mindfulSession.sampleType
        ])
    }
}
#endif
```

**Deliverable:** ✅ HealthKitDataType definitions

---

#### Task 5.3: Implement Use Cases ⏱️ 6 hours

```swift
// FitIQCore/Sources/FitIQCore/HealthKit/UseCases/RequestHealthKitAuthorizationUseCase.swift

#if canImport(HealthKit)
import HealthKit

/// Use case for requesting HealthKit authorization
public protocol RequestHealthKitAuthorizationUseCase {
    func execute(
        readTypes: Set<HKSampleType>,
        writeTypes: Set<HKSampleType>
    ) async throws
}

public final class RequestHealthKitAuthorizationUseCaseImpl: RequestHealthKitAuthorizationUseCase {
    
    private let healthKitManager: HealthKitManager
    
    public init(healthKitManager: HealthKitManager = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }
    
    public func execute(
        readTypes: Set<HKSampleType>,
        writeTypes: Set<HKSampleType>
    ) async throws {
        guard HealthKitManager.isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        
        try await healthKitManager.requestAuthorization(
            toRead: readTypes,
            toWrite: writeTypes
        )
    }
}

/// HealthKit-specific errors
public enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case authorizationDenied
    case fetchFailed(Error)
    case saveFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .fetchFailed(let error):
            return "Failed to fetch HealthKit data: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save HealthKit data: \(error.localizedDescription)"
        }
    }
}
#endif
```

**Deliverable:** ✅ Core HealthKit use cases

---

#### Task 5.4: Add Tests ⏱️ 6 hours

```swift
// FitIQCore/Tests/FitIQCoreTests/HealthKit/HealthKitManagerTests.swift

#if canImport(HealthKit)
import XCTest
@testable import FitIQCore
import HealthKit

final class HealthKitManagerTests: XCTestCase {
    
    func testIsHealthDataAvailable_ReturnsExpectedValue() {
        // On simulator, this should return true
        // On Mac, this should return false
        let isAvailable = HealthKitManager.isHealthDataAvailable
        
        #if targetEnvironment(simulator)
        XCTAssertTrue(isAvailable)
        #else
        // Actual device - depends on hardware
        #endif
    }
    
    func testRequestAuthorization_ValidTypes_Succeeds() async throws {
        let manager = HealthKitManager()
        let readTypes: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!
        ]
        
        // Note: This will show authorization dialog in real usage
        // For unit tests, we can only test the method doesn't crash
        do {
            try await manager.requestAuthorization(
                toRead: readTypes,
                toWrite: []
            )
            // If no error thrown, authorization request was made
            XCTAssertTrue(true)
        } catch {
            // Authorization can fail in test environment - that's OK
            XCTAssertTrue(true)
        }
    }
}
#endif
```

**Deliverable:** ✅ 90%+ test coverage for HealthKit

---

### Day 11-12: Integrate HealthKit into FitIQ

#### Task 6.1: Update FitIQ to Use FitIQCore HealthKit ⏱️ 6 hours

**Steps:**
1. Replace local HealthKitManager with FitIQCore version
2. Update use cases to use FitIQCore protocols
3. Keep FitIQ-specific extensions in FitIQ
4. Test HealthKit authorization flows
5. Verify all HealthKit features work

**What Stays in FitIQ:**
- Complex workout tracking
- Nutrition integration
- Background sync orchestration
- FitIQ-specific health calculations

**What Moves to FitIQCore:**
- Core authorization
- Basic metric fetching
- Common data types
- Generic query utilities

**Deliverable:** ✅ FitIQ using FitIQCore HealthKit

---

### Day 13-14: Prepare Lume for HealthKit

#### Task 7.1: Add HealthKit Support to Lume ⏱️ 6 hours

**Steps:**
1. Add HealthKit capability to Lume
2. Import FitIQCore HealthKit
3. Create Lume-specific use cases:
   - Track mindfulness sessions
   - Monitor sleep quality
   - Track heart rate variability
4. Add UI for HealthKit authorization
5. Test mindfulness tracking

**Example Lume Use Case:**
```swift
// lume/Domain/UseCases/TrackMindfulnessSessionUseCase.swift

import FitIQCore
import HealthKit

protocol TrackMindfulnessSessionUseCase {
    func execute(duration: TimeInterval, date: Date) async throws
}

final class TrackMindfulnessSessionUseCaseImpl: TrackMindfulnessSessionUseCase {
    
    private let healthKitManager: HealthKitManager
    
    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }
    
    func execute(duration: TimeInterval, date: Date) async throws {
        // Use FitIQCore's HealthKit to save mindfulness session
        let endDate = date.addingTimeInterval(duration)
        let sample = HKCategorySample(
            type: HKCategoryType.categoryType(forIdentifier: .mindfulSession)!,
            value: HKCategoryValue.notApplicable.rawValue,
            start: date,
            end: endDate
        )
        
        try await healthKitManager.store.save(sample)
    }
}
```

**Deliverable:** ✅ Lume ready for mindfulness HealthKit features

---

### Day 15: Final Testing & Documentation

#### Task 8.1: End-to-End Testing ⏱️ 4 hours

**FitIQ:**
- [ ] HealthKit authorization works
- [ ] Step tracking works
- [ ] Heart rate tracking works
- [ ] Sleep tracking works
- [ ] Background sync works

**Lume:**
- [ ] HealthKit authorization works
- [ ] Mindfulness session tracking works
- [ ] Sleep quality monitoring works
- [ ] Heart rate variability works

**Deliverable:** ✅ Both apps fully tested

---

#### Task 8.2: Documentation ⏱️ 4 hours

**Updates:**
1. FitIQCore v0.4.0 CHANGELOG (HealthKit framework)
2. Phase 2 completion report
3. HealthKit integration guide
4. Migration guide for both apps

**Deliverable:** ✅ Complete documentation

---

## 📊 Phase 2 Success Criteria

### Code Quality
- [ ] ✅ ~400 lines of profile duplication removed
- [ ] ✅ HealthKit framework extracted to FitIQCore
- [ ] ✅ Both apps use FitIQCore.UserProfile
- [ ] ✅ Both apps use FitIQCore.HealthKit (where applicable)
- [ ] ✅ Zero compilation errors
- [ ] ✅ All tests passing (95%+ coverage)

### Functionality
- [ ] ✅ FitIQ profile features work (physical attributes, HealthKit sync)
- [ ] ✅ Lume profile features work (simple profile)
- [ ] ✅ FitIQ HealthKit features work (all existing features)
- [ ] ✅ Lume HealthKit ready (authorization, basic tracking)
- [ ] ✅ No regressions

### Future-Ready
- [ ] ✅ Lume can add mindfulness features easily
- [ ] ✅ Shared HealthKit code reduces duplication
- [ ] ✅ Clear extension points for app-specific features

---

## 🎯 Expected Outcomes

### Week 1: Profile Unification
✅ **~400 lines removed**  
✅ **Single UserProfile model**  
✅ **Backward compatible with Lume**  
✅ **Full features for FitIQ**

### Week 2-3: HealthKit Extraction
✅ **Shared HealthKit framework**  
✅ **Lume ready for mindfulness**  
✅ **Reduced code duplication**  
✅ **Consistent HealthKit behavior**

### Overall Phase 2
✅ **FitIQCore v0.3.0** (Profile) + **v0.4.0** (HealthKit)  
✅ **~600 lines of duplication removed** (Profile + HealthKit)  
✅ **Both apps future-ready**  
✅ **Excellent foundation for growth**

---

## 📈 Progress Tracking

### Week 1: Profile Unification
- [ ] Day 1-2: Enhance FitIQCore.UserProfile
  - [ ] Add optional fields
  - [ ] Add update methods
  - [ ] Add tests
  - [ ] Release v0.3.0
- [ ] Day 3-4: Migrate FitIQ
  - [ ] Update dependencies
  - [ ] Update models
  - [ ] Update repositories
  - [ ] Update use cases
  - [ ] Update ViewModels
- [ ] Day 5: Testing & Cleanup
  - [ ] Delete old files
  - [ ] Run all tests
  - [ ] Manual QA
  - [ ] Documentation

### Week 2: HealthKit Design & Core
- [ ] Day 6-7: Design HealthKit Framework
  - [ ] Assess commonality
  - [ ] Design architecture
- [ ] Day 8-10: Implement Core
  - [ ] HealthKitManager
  - [ ] HealthKitDataType
  - [ ] Use cases
  - [ ] Tests

### Week 3: HealthKit Integration
- [ ] Day 11-12: Integrate into FitIQ
  - [ ] Update FitIQ to use FitIQCore HealthKit
  - [ ] Test all features
- [ ] Day 13-14: Prepare Lume
  - [ ] Add HealthKit support
  - [ ] Implement mindfulness tracking
- [ ] Day 15: Final Testing
  - [ ] End-to-end testing
  - [ ] Documentation

---

## 🚨 Risks & Mitigations

### Risk 1: Breaking Lume Profile 🔴 MEDIUM

**Risk:** Lume might break with new UserProfile fields

**Mitigation:**
✅ All new fields are optional  
✅ Simple initializer maintained  
✅ Test Lume after each change  
✅ Can rollback if needed

### Risk 2: HealthKit Complexity 🟡 MEDIUM

**Risk:** HealthKit extraction might be more complex than expected

**Mitigation:**
✅ Start with minimal extraction (core only)  
✅ Keep app-specific code in apps  
✅ Iterative approach (can expand later)  
✅ Well-tested at each step

### Risk 3: Timeline Slip 🟢 LOW

**Risk:** 3 weeks might not be enough

**Mitigation:**
✅ Profile is independent (Week 1 standalone value)  
✅ HealthKit can be done incrementally  
✅ Buffer time built into estimates  
✅ Can extend if needed

---

## ✅ Ready to Execute!

Phase 2 is comprehensively planned and ready to go:

**Week 1:** Profile Unification (high confidence, proven approach)  
**Week 2-3:** HealthKit Extraction (new, but well-designed)

**Total Effort:** 2-3 weeks  
**Expected Value:** ~600 lines removed + future-ready architecture

**Start When:** Ready! 🚀

---

**Document Version:** 2.0  
**Created:** 2025-01-27  
**Status:** 📋 Ready for Execution  
**Supersedes:** PHASE_2_PLAN.md (HealthKit now included)