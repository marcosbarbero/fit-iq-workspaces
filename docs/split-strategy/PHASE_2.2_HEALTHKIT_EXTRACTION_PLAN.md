# Phase 2.2: HealthKit Extraction to FitIQCore

**Date:** 2025-01-27  
**Status:** 📋 Planning  
**Duration:** 2-3 weeks (estimated)  
**Depends On:** Phase 2.1 Profile Unification ✅ Complete  
**Enables:** Lume mindfulness & wellness features via HealthKit

---

## 🎯 Objectives

### Primary Goals
1. **Extract HealthKit abstractions** from FitIQ to FitIQCore
2. **Enable Lume to use HealthKit** for mindfulness tracking (meditation, breathing)
3. **Share common health data models** between FitIQ and Lume
4. **Maintain FitIQ-specific implementations** for fitness tracking
5. **Zero breaking changes** to existing FitIQ functionality

### Success Criteria
- ✅ HealthKit protocols extracted to FitIQCore
- ✅ Shared health data models in FitIQCore
- ✅ FitIQ using FitIQCore HealthKit abstractions
- ✅ Lume can request HealthKit authorization
- ✅ Zero compilation errors or warnings
- ✅ All existing tests passing
- ✅ Documentation complete

---

## 📊 Current State Analysis

### FitIQ HealthKit Components

#### Domain Layer (Ports)
- `HealthRepositoryProtocol` - Main HealthKit interface
- `HealthMetricSyncHandlerProtocol` - Sync coordination
- `LocalHealthDataStorePort` - Local health data storage
- `ProcessDailyHealthDataUseCaseProtocol` - Daily sync orchestration

#### Domain Layer (Use Cases)
- `RequestHealthKitAuthorizationUseCase` - Authorization flow
- `HealthKitUseCases.swift` - Common use case patterns

#### Infrastructure Layer
- `HealthKitAdapter` - Main HealthKit implementation
- `HealthKitProfileSyncService` - Profile data sync
- `HealthKitWorkoutSyncService` - Workout sync
- `HealthDataSyncOrchestrator` - Overall sync coordination
- `BackgroundOperations` - Background sync handling

#### Entities/Models
- `ActivitySnapshot` - Daily activity summary
- `BodyMetrics` - Weight, height, BMI
- `WorkoutSession` - Workout data
- `SleepSession` - Sleep tracking
- `MoodEntry` - Mood/energy tracking

### What Lume Needs

#### Core HealthKit Features
1. **Authorization**
   - Request mindful minutes permission
   - Request meditation session permission
   - Request heart rate variability permission
   - Request respiratory rate permission

2. **Data Querying**
   - Fetch mindful minutes (HKCategoryType)
   - Fetch meditation sessions (HKWorkout)
   - Query heart rate variability
   - Query respiratory rate

3. **Data Writing**
   - Save meditation sessions
   - Save mindful minutes
   - Update wellness metrics

### What Should NOT Move to FitIQCore
- Fitness-specific sync logic (steps, running, cycling)
- FitIQ backend API integration
- Activity snapshot calculations
- Workout template management
- Food/nutrition tracking

---

## 🏗️ Architecture Design

### FitIQCore HealthKit Module Structure

```
FitIQCore/
└── Sources/
    └── FitIQCore/
        └── Health/
            ├── Domain/
            │   ├── Models/
            │   │   ├── HealthDataType.swift
            │   │   ├── HealthMetric.swift
            │   │   ├── HealthAuthorizationScope.swift
            │   │   └── HealthQueryOptions.swift
            │   ├── Ports/
            │   │   ├── HealthKitServiceProtocol.swift
            │   │   ├── HealthAuthorizationServiceProtocol.swift
            │   │   └── HealthDataQueryServiceProtocol.swift
            │   └── UseCases/
            │       ├── RequestHealthAuthorizationUseCase.swift
            │       └── CheckHealthAuthorizationStatusUseCase.swift
            └── Infrastructure/
                ├── HealthKitService.swift
                ├── HealthAuthorizationService.swift
                └── HealthDataQueryService.swift
```

### Shared vs App-Specific

| Component | Location | Reason |
|-----------|----------|--------|
| **HealthKit Authorization** | FitIQCore | Both apps need it |
| **Basic Query Interface** | FitIQCore | Common data access |
| **Health Data Types Enum** | FitIQCore | Shared vocabulary |
| **Authorization Use Cases** | FitIQCore | Common flow |
| **Fitness Sync Logic** | FitIQ | App-specific |
| **Mindfulness Sync Logic** | Lume | App-specific |
| **Backend Integration** | FitIQ/Lume | App-specific APIs |
| **Activity Snapshots** | FitIQ | Fitness-specific |

---

## 📝 Implementation Plan

### Step 1: Define Shared Abstractions (Days 1-2)

#### 1.1 Create Health Data Type Enumeration

**File:** `FitIQCore/Sources/FitIQCore/Health/Domain/Models/HealthDataType.swift`

```swift
public enum HealthDataType {
    // Quantity Types
    case stepCount
    case heartRate
    case activeEnergyBurned
    case bodyMass
    case height
    case respiratoryRate
    case heartRateVariability
    
    // Category Types
    case sleepAnalysis
    case mindfulSession
    
    // Workout Types
    case workout(WorkoutType)
    
    public enum WorkoutType {
        case running
        case cycling
        case walking
        case yoga
        case meditation
        case traditionalStrengthTraining
        // ... more types
    }
}
```

#### 1.2 Create Health Authorization Scope

**File:** `FitIQCore/Sources/FitIQCore/Health/Domain/Models/HealthAuthorizationScope.swift`

```swift
public struct HealthAuthorizationScope {
    public let readTypes: Set<HealthDataType>
    public let writeTypes: Set<HealthDataType>
    
    public init(read: Set<HealthDataType>, write: Set<HealthDataType>) {
        self.readTypes = read
        self.writeTypes = write
    }
    
    // Predefined scopes
    public static var fitness: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [.stepCount, .heartRate, .activeEnergyBurned, .bodyMass],
            write: [.bodyMass, .workout(.running)]
        )
    }
    
    public static var mindfulness: HealthAuthorizationScope {
        HealthAuthorizationScope(
            read: [.mindfulSession, .heartRateVariability, .respiratoryRate],
            write: [.mindfulSession, .workout(.meditation)]
        )
    }
}
```

#### 1.3 Create Health Service Protocol

**File:** `FitIQCore/Sources/FitIQCore/Health/Domain/Ports/HealthKitServiceProtocol.swift`

```swift
public protocol HealthKitServiceProtocol {
    /// Check if HealthKit is available on this device
    func isHealthKitAvailable() -> Bool
    
    /// Request authorization for specific health data types
    func requestAuthorization(scope: HealthAuthorizationScope) async throws
    
    /// Check authorization status for a specific type
    func authorizationStatus(for type: HealthDataType) -> HealthAuthorizationStatus
    
    /// Query health data
    func query(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> [HealthMetric]
    
    /// Save health data
    func save(metric: HealthMetric) async throws
}

public enum HealthAuthorizationStatus {
    case notDetermined
    case sharingDenied
    case sharingAuthorized
}
```

### Step 2: Extract Core HealthKit Implementation (Days 3-5)

#### 2.1 Create Base HealthKit Service

**File:** `FitIQCore/Sources/FitIQCore/Health/Infrastructure/HealthKitService.swift`

- Implement `HealthKitServiceProtocol`
- Wrap HealthKit framework calls
- Handle authorization flow
- Provide query builders
- Thread-safe implementation
- Comprehensive error handling

#### 2.2 Extract Authorization Use Case

**File:** `FitIQCore/Sources/FitIQCore/Health/Domain/UseCases/RequestHealthAuthorizationUseCase.swift`

Move from FitIQ to FitIQCore:
- Authorization flow logic
- Error handling
- User-facing messaging
- Retry logic

### Step 3: Migrate FitIQ to Use FitIQCore HealthKit (Days 6-8)

#### 3.1 Update FitIQ HealthRepositoryProtocol

**Changes:**
- Conform to `FitIQCore.HealthKitServiceProtocol`
- Add FitIQ-specific methods (e.g., `fetchActivitySnapshot`)
- Extend with fitness-specific queries

#### 3.2 Update HealthKitAdapter

**Changes:**
- Use `FitIQCore.HealthKitService` as base
- Keep FitIQ-specific sync logic
- Maintain backward compatibility
- Update dependency injection

#### 3.3 Update Use Cases

**Files to Update:**
- `RequestHealthKitAuthorizationUseCase` → Use FitIQCore version
- `PerformInitialHealthKitSyncUseCase` → Use FitIQCore abstractions
- All fitness-specific use cases → Keep in FitIQ, use FitIQCore ports

### Step 4: Enable Lume HealthKit Integration (Days 9-10)

#### 4.1 Add HealthKit to Lume

**New Files:**
- `lume/Domain/UseCases/RequestMindfulnessAuthorizationUseCase.swift`
- `lume/Infrastructure/HealthKitMindfulnessAdapter.swift`

**Implementation:**
- Use `FitIQCore.HealthKitServiceProtocol`
- Request mindfulness-specific permissions
- Query meditation sessions
- Save mindful minutes

#### 4.2 Update Lume AppDependencies

```swift
// Add HealthKit service
lazy var healthKitService: HealthKitServiceProtocol = HealthKitService()

// Add authorization use case
lazy var requestMindfulnessAuthorizationUseCase = RequestMindfulnessAuthorizationUseCase(
    healthService: healthKitService,
    scope: .mindfulness
)
```

### Step 5: Testing & Validation (Days 11-12)

#### 5.1 Unit Tests

**FitIQCore Tests:**
- HealthKit service authorization flow
- Query building and execution
- Error handling
- Thread safety

**FitIQ Tests:**
- All existing HealthKit tests still pass
- New FitIQCore integration tests
- Backward compatibility verified

**Lume Tests:**
- Mindfulness authorization flow
- Meditation session queries
- Data saving

#### 5.2 Integration Tests

- FitIQ can still sync fitness data
- Lume can request mindfulness permissions
- No conflicts between apps
- Shared HealthKit data accessible

#### 5.3 Manual Testing

- Test on physical device (HealthKit requires real device)
- Verify authorization prompts
- Check data querying
- Validate background sync
- Test edge cases (denied permissions, etc.)

---

## 📋 Detailed Task Breakdown

### Week 1: Foundation & Core Implementation

#### Day 1: Planning & Setup
- [ ] Review existing FitIQ HealthKit code
- [ ] Identify shareable components
- [ ] Create FitIQCore Health module structure
- [ ] Define protocols and interfaces
- [ ] Document architecture decisions

#### Day 2: Shared Models ✅
- [x] Create `HealthDataType.swift`
- [x] Create `HealthAuthorizationScope.swift`
- [x] Create `HealthMetric.swift`
- [x] Create `HealthQueryOptions.swift`
- [x] Add unit tests for models

#### Day 3: Service Protocols
- [ ] Create `HealthKitServiceProtocol.swift`
- [ ] Create `HealthAuthorizationServiceProtocol.swift`
- [ ] Create `HealthDataQueryServiceProtocol.swift`
- [ ] Document protocol contracts
- [ ] Create mock implementations for testing

#### Day 4-5: Core Implementation
- [ ] Implement `HealthKitService.swift`
- [ ] Implement `HealthAuthorizationService.swift`
- [ ] Implement `HealthDataQueryService.swift`
- [ ] Add error handling
- [ ] Add logging
- [ ] Create unit tests

### Week 2: FitIQ Migration

#### Day 6: Update FitIQ Protocols
- [ ] Update `HealthRepositoryProtocol`
- [ ] Add FitIQCore imports
- [ ] Extend with FitIQ-specific methods
- [ ] Update method signatures

#### Day 7: Migrate HealthKitAdapter
- [ ] Update `HealthKitAdapter.swift`
- [ ] Use FitIQCore base service
- [ ] Maintain fitness-specific logic
- [ ] Update tests

#### Day 8: Update Use Cases
- [ ] Migrate `RequestHealthKitAuthorizationUseCase`
- [ ] Update `PerformInitialHealthKitSyncUseCase`
- [ ] Update all HealthKit use cases
- [ ] Update AppDependencies
- [ ] Run full test suite

### Week 3: Lume Integration & Testing

#### Day 9: Lume HealthKit Setup
- [ ] Add HealthKit capability to Lume
- [ ] Create mindfulness authorization use case
- [ ] Create mindfulness adapter
- [ ] Update AppDependencies

#### Day 10: Lume Implementation
- [ ] Implement meditation session queries
- [ ] Implement mindful minutes tracking
- [ ] Add UI for HealthKit authorization
- [ ] Create tests

#### Day 11: Testing & Bug Fixes
- [ ] Run all unit tests (FitIQCore, FitIQ, Lume)
- [ ] Run integration tests
- [ ] Manual testing on device
- [ ] Fix any issues found

#### Day 12: Documentation & Cleanup
- [ ] Update architecture documentation
- [ ] Create integration guide
- [ ] Document breaking changes (if any)
- [ ] Update README files
- [ ] Create PR and get review

---

## 🚨 Risks & Mitigation

### Risk 1: Breaking FitIQ Functionality
**Likelihood:** Medium  
**Impact:** High  
**Mitigation:**
- Comprehensive test coverage before migration
- Incremental migration (one component at a time)
- Feature flags for new code paths
- Thorough manual testing

### Risk 2: HealthKit API Complexity
**Likelihood:** Medium  
**Impact:** Medium  
**Mitigation:**
- Study existing FitIQ implementation thoroughly
- Keep complex logic in app-specific layer initially
- Start with simple abstractions
- Iterate based on learnings

### Risk 3: Lume-Specific Requirements
**Likelihood:** Low  
**Impact:** Medium  
**Mitigation:**
- Design generic abstractions
- Avoid fitness-specific assumptions
- Use composition over inheritance
- Keep app-specific logic in apps

### Risk 4: Performance Issues
**Likelihood:** Low  
**Impact:** Medium  
**Mitigation:**
- Profile HealthKit queries
- Implement caching where appropriate
- Use background queues for heavy operations
- Monitor memory usage

---

## 📊 Success Metrics

### Code Quality
- [ ] Zero compilation errors
- [ ] Zero warnings
- [ ] 100% of existing tests passing
- [ ] 80%+ test coverage for new code

### Functionality
- [ ] FitIQ fitness tracking unchanged
- [ ] Lume can request HealthKit authorization
- [ ] Lume can query mindfulness data
- [ ] No data loss or corruption

### Performance
- [ ] Authorization flow < 2 seconds
- [ ] Query performance maintained
- [ ] Background sync efficiency unchanged
- [ ] Memory usage stable

### Documentation
- [ ] Architecture documented
- [ ] API reference complete
- [ ] Integration guide written
- [ ] Migration guide available

---

## 🎓 Key Considerations

### HealthKit Permissions Model
- HealthKit permissions are per-data-type
- Authorization must be requested upfront
- Users can deny individual permissions
- Apps should gracefully handle denied permissions

### Data Privacy
- HealthKit data never leaves the device without explicit user action
- Background sync respects privacy settings
- Clear user communication about data usage

### Multi-App Considerations
- HealthKit is shared across all apps
- FitIQ and Lume can coexist
- Same permissions affect both apps
- Coordinate data writing to avoid conflicts

### Testing Challenges
- HealthKit requires physical device for testing
- Simulator has limited HealthKit support
- Authorization state persists across runs
- Test data management is complex

---

## 📚 Dependencies

### FitIQCore Updates Required
- Health module (new)
- Updated exports in main module file
- Version bump to 0.3.0

### FitIQ Updates Required
- Import FitIQCore health module
- Update HealthKitAdapter
- Update use cases
- Update tests

### Lume Updates Required
- Add HealthKit capability
- Import FitIQCore health module
- Create mindfulness integration
- Add UI for authorization

---

## 🔄 Migration Strategy

### Phase A: Extract to FitIQCore (No Breaking Changes)
1. Create new FitIQCore health module
2. Keep all existing FitIQ code
3. Add FitIQCore implementations
4. Ensure tests pass with both

### Phase B: Migrate FitIQ (Gradual Replacement)
1. Update one component at a time
2. Run tests after each change
3. Verify functionality unchanged
4. Keep fallback options

### Phase C: Enable Lume (Additive Only)
1. Add HealthKit to Lume
2. Implement mindfulness features
3. Test independently
4. Verify no FitIQ conflicts

---

## 📖 Related Documentation

### Required Reading
- [Phase 2.1 Completion Summary](./PHASE_2.1_FINAL_STATUS.md)
- [FitIQCore Phase 1 Complete](./FITIQCORE_PHASE1_COMPLETE.md)
- [Hexagonal Architecture Guide](../../.github/copilot-instructions.md)

### Reference Materials
- Apple HealthKit Documentation
- FitIQ HealthKit Integration Guide
- SwiftUI HealthKit Best Practices

---

## ✅ Pre-Implementation Checklist

Before starting Phase 2.2:
- [x] Phase 2.1 complete (✅ Done)
- [ ] All Phase 2.1 tests passing
- [ ] FitIQ production-ready
- [ ] Team alignment on architecture
- [ ] HealthKit permissions reviewed
- [ ] Lume requirements clarified
- [ ] Timeline approved

---

## 🚀 Getting Started

### Step 1: Review Current Implementation
```bash
# Study FitIQ HealthKit code
cd fit-iq-workspaces/FitIQ
find . -name "*HealthKit*" -type f

# Review key files
# - Domain/Ports/HealthRepositoryProtocol.swift
# - Infrastructure/Integration/HealthKitAdapter.swift
# - Domain/UseCases/HealthKit/RequestHealthKitAuthorizationUseCase.swift
```

### Step 2: Create FitIQCore Health Module
```bash
cd fit-iq-workspaces/FitIQCore
mkdir -p Sources/FitIQCore/Health/Domain/Models
mkdir -p Sources/FitIQCore/Health/Domain/Ports
mkdir -p Sources/FitIQCore/Health/Domain/UseCases
mkdir -p Sources/FitIQCore/Health/Infrastructure
```

### Step 3: Start with Models
- Create `HealthDataType.swift`
- Create `HealthAuthorizationScope.swift`
- Write unit tests
- Get team review

---

## 📞 Questions & Answers

### Q: Why extract HealthKit now?
**A:** Phase 2.1 unified the profile model. Now that auth and profile are shared, HealthKit is the next logical step to enable Lume's mindfulness features.

### Q: Will this break existing FitIQ users?
**A:** No. We're maintaining backward compatibility and all existing functionality will continue to work unchanged.

### Q: How long will this take?
**A:** Estimated 2-3 weeks for full implementation, testing, and documentation. Based on Phase 1.5 experience, could be faster.

### Q: What about other health data types?
**A:** Starting with core types needed by both apps. Additional types can be added incrementally.

---

**Status:** 📋 Planning Complete - Ready to Start  
**Estimated Start:** After Phase 2.1 validation  
**Estimated Completion:** 2-3 weeks from start  
**Next Phase:** Phase 3 - Utilities & UI Components  

---

**Last Updated:** 2025-01-27  
**Document Owner:** Engineering Team  
**Review Status:** Pending Team Review