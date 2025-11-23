# Phase 2.2 HealthKit Extraction - Quick Start Guide

**Date:** 2025-01-27  
**Status:** 📋 Ready to Start  
**Duration:** 2-3 weeks  
**Prerequisites:** Phase 2.1 Complete ✅

---

## 🎯 What We're Doing

Extracting HealthKit abstractions from FitIQ to FitIQCore so that:
- ✅ Lume can use HealthKit for mindfulness tracking
- ✅ FitIQ continues fitness tracking without changes
- ✅ Both apps share common health data infrastructure
- ✅ Zero breaking changes

---

## 📋 Before You Start

### ✅ Prerequisites Checklist
- [x] Phase 2.1 Profile Unification complete
- [ ] All Phase 2.1 tests passing
- [ ] FitIQ builds with zero errors/warnings
- [ ] Read Phase 2.2 implementation plan
- [ ] Team alignment on architecture
- [ ] Development environment set up

### 📚 Required Reading (15 min)
1. [Phase 2.2 Implementation Plan](./PHASE_2.2_HEALTHKIT_EXTRACTION_PLAN.md) - Full details
2. [Phase 2.1 Final Status](../FitIQ/docs/fixes/PHASE_2.1_FINAL_STATUS.md) - Previous phase
3. [FitIQCore README](../../FitIQCore/README.md) - Library overview

---

## 🚀 Getting Started

### Step 1: Review Existing HealthKit Code (30 min)

```bash
cd fit-iq-workspaces/FitIQ

# Find all HealthKit-related files
find . -name "*HealthKit*" -type f

# Key files to study:
# - Domain/Ports/HealthRepositoryProtocol.swift
# - Infrastructure/Integration/HealthKitAdapter.swift
# - Domain/UseCases/HealthKit/RequestHealthKitAuthorizationUseCase.swift
```

**What to look for:**
- Authorization flow patterns
- Query builders
- Data type mappings
- Error handling strategies
- Background sync mechanisms

### Step 2: Set Up FitIQCore Health Module (15 min)

```bash
cd fit-iq-workspaces/FitIQCore

# Create module structure
mkdir -p Sources/FitIQCore/Health/Domain/Models
mkdir -p Sources/FitIQCore/Health/Domain/Ports
mkdir -p Sources/FitIQCore/Health/Domain/UseCases
mkdir -p Sources/FitIQCore/Health/Infrastructure
mkdir -p Tests/FitIQCoreTests/Health
```

### Step 3: Create Your First File (30 min)

**File:** `Sources/FitIQCore/Health/Domain/Models/HealthDataType.swift`

```swift
//
//  HealthDataType.swift
//  FitIQCore
//
//  Created by FitIQ Team
//

import Foundation

/// Represents types of health data that can be read/written via HealthKit
public enum HealthDataType: Sendable, Hashable {
    // MARK: - Quantity Types
    
    /// Step count (count/day)
    case stepCount
    
    /// Heart rate (bpm)
    case heartRate
    
    /// Active energy burned (kcal)
    case activeEnergyBurned
    
    /// Body mass/weight (kg)
    case bodyMass
    
    /// Height (cm)
    case height
    
    /// Respiratory rate (breaths/min)
    case respiratoryRate
    
    /// Heart rate variability (ms)
    case heartRateVariability
    
    // MARK: - Category Types
    
    /// Sleep analysis
    case sleepAnalysis
    
    /// Mindful session (meditation, breathing)
    case mindfulSession
    
    // MARK: - Workout Types
    
    /// Workout/exercise session
    case workout(WorkoutType)
    
    /// Types of workout activities
    public enum WorkoutType: String, Sendable, Hashable {
        case running
        case cycling
        case walking
        case yoga
        case meditation
        case traditionalStrengthTraining
        case highIntensityIntervalTraining
        case functionalStrengthTraining
    }
}

// MARK: - CustomStringConvertible

extension HealthDataType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stepCount: return "Step Count"
        case .heartRate: return "Heart Rate"
        case .activeEnergyBurned: return "Active Energy"
        case .bodyMass: return "Body Mass"
        case .height: return "Height"
        case .respiratoryRate: return "Respiratory Rate"
        case .heartRateVariability: return "Heart Rate Variability"
        case .sleepAnalysis: return "Sleep"
        case .mindfulSession: return "Mindful Minutes"
        case .workout(let type): return "Workout (\(type.rawValue))"
        }
    }
}
```

### Step 4: Write Tests (20 min)

**File:** `Tests/FitIQCoreTests/Health/HealthDataTypeTests.swift`

```swift
import XCTest
@testable import FitIQCore

final class HealthDataTypeTests: XCTestCase {
    
    func testHealthDataTypeEquality() {
        XCTAssertEqual(HealthDataType.stepCount, HealthDataType.stepCount)
        XCTAssertEqual(HealthDataType.workout(.running), HealthDataType.workout(.running))
        XCTAssertNotEqual(HealthDataType.workout(.running), HealthDataType.workout(.cycling))
    }
    
    func testHealthDataTypeDescription() {
        XCTAssertEqual(HealthDataType.stepCount.description, "Step Count")
        XCTAssertEqual(HealthDataType.heartRate.description, "Heart Rate")
        XCTAssertEqual(HealthDataType.workout(.meditation).description, "Workout (meditation)")
    }
    
    func testHealthDataTypeHashable() {
        let types: Set<HealthDataType> = [.stepCount, .heartRate, .bodyMass]
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(.stepCount))
    }
}
```

### Step 5: Run Tests (5 min)

```bash
cd fit-iq-workspaces/FitIQCore
swift test

# Should see:
# ✅ All tests passed
```

---

## 📅 Week-by-Week Guide

### Week 1: Foundation (Days 1-5)

**Day 1: Planning & Models**
- [ ] Review existing FitIQ HealthKit code
- [ ] Create FitIQCore Health module structure
- [ ] Implement `HealthDataType.swift`
- [ ] Implement `HealthAuthorizationScope.swift`
- [ ] Write tests

**Day 2: More Models**
- [ ] Implement `HealthMetric.swift`
- [ ] Implement `HealthQueryOptions.swift`
- [ ] Write tests
- [ ] Document model contracts

**Day 3: Service Protocols**
- [ ] Create `HealthKitServiceProtocol.swift`
- [ ] Create `HealthAuthorizationServiceProtocol.swift`
- [ ] Document protocol contracts
- [ ] Create mock implementations

**Day 4-5: Core Implementation**
- [ ] Implement `HealthKitService.swift`
- [ ] Implement authorization logic
- [ ] Implement query builders
- [ ] Add error handling
- [ ] Write comprehensive tests

**End of Week 1 Deliverables:**
- ✅ FitIQCore Health module foundation complete
- ✅ All models and protocols defined
- ✅ Base service implementation done
- ✅ Unit tests passing
- ✅ Documentation up to date

### Week 2: FitIQ Migration (Days 6-10)

**Day 6: Update Protocols**
- [ ] Add `import FitIQCore` to FitIQ health files
- [ ] Update `HealthRepositoryProtocol`
- [ ] Extend with FitIQ-specific methods
- [ ] Update method signatures

**Day 7: Migrate Adapter**
- [ ] Update `HealthKitAdapter.swift`
- [ ] Use FitIQCore base service
- [ ] Keep fitness-specific logic
- [ ] Update tests

**Day 8: Update Use Cases**
- [ ] Migrate authorization use case
- [ ] Update sync use cases
- [ ] Update AppDependencies
- [ ] Run full test suite

**Day 9: Lume Setup**
- [ ] Add HealthKit capability to Lume
- [ ] Create mindfulness authorization use case
- [ ] Create mindfulness adapter
- [ ] Update Lume AppDependencies

**Day 10: Lume Implementation**
- [ ] Implement meditation queries
- [ ] Implement mindful minutes tracking
- [ ] Add UI for authorization
- [ ] Write tests

**End of Week 2 Deliverables:**
- ✅ FitIQ fully migrated to FitIQCore HealthKit
- ✅ All FitIQ functionality unchanged
- ✅ Lume HealthKit integration started
- ✅ Tests passing for both apps

### Week 3: Testing & Polish (Days 11-15)

**Day 11: Testing**
- [ ] Run all unit tests
- [ ] Run integration tests
- [ ] Manual testing on device
- [ ] Fix bugs

**Day 12: Documentation**
- [ ] Update architecture docs
- [ ] Create integration guide
- [ ] Update README files
- [ ] Document breaking changes (if any)

**Day 13-14: Code Review & Refinement**
- [ ] Create PR
- [ ] Address review feedback
- [ ] Refine implementation
- [ ] Update tests

**Day 15: Final Validation**
- [ ] Final test run
- [ ] Performance check
- [ ] Deploy to TestFlight
- [ ] Update status docs

**End of Week 3 Deliverables:**
- ✅ Phase 2.2 complete
- ✅ All tests passing
- ✅ Documentation complete
- ✅ Ready for production

---

## 🎯 Daily Workflow

### Morning (30 min)
1. Review yesterday's progress
2. Check task list for today
3. Pull latest changes
4. Run tests to verify baseline

### Work Session (3-4 hours)
1. Implement planned tasks
2. Write tests as you go
3. Run tests frequently
4. Commit small, focused changes

### Afternoon Check (30 min)
1. Run full test suite
2. Verify no regressions
3. Update documentation
4. Commit and push changes

### End of Day (15 min)
1. Review what was completed
2. Update task list
3. Document any blockers
4. Plan tomorrow's work

---

## 🚨 Common Issues & Solutions

### Issue 1: HealthKit Not Available in Simulator
**Solution:** Test on physical device. Use mocks for automated tests.

### Issue 2: Authorization State Persists
**Solution:** Reset simulator or use different test users.

### Issue 3: Complex Type Inference
**Solution:** Add explicit type annotations to help compiler.

### Issue 4: Thread Safety Concerns
**Solution:** Use `@Sendable` closures, ensure HealthKit calls on correct queue.

---

## ✅ Definition of Done

For each component, ensure:
- [ ] Implementation complete
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] No compiler warnings
- [ ] Performance acceptable
- [ ] Works on physical device

---

## 📊 Progress Tracking

Use this checklist to track overall progress:

### Foundation
- [ ] Module structure created
- [ ] Models implemented
- [ ] Protocols defined
- [ ] Base service implemented
- [ ] Tests passing

### FitIQ Migration
- [ ] Protocols updated
- [ ] Adapter migrated
- [ ] Use cases updated
- [ ] Tests passing
- [ ] No regressions

### Lume Integration
- [ ] HealthKit capability added
- [ ] Authorization implemented
- [ ] Queries implemented
- [ ] Tests passing
- [ ] UI functional

### Documentation
- [ ] Architecture documented
- [ ] Integration guide written
- [ ] API reference complete
- [ ] Migration guide available

---

## 🆘 Getting Help

### Quick Questions
- Check [Phase 2.2 Implementation Plan](./PHASE_2.2_HEALTHKIT_EXTRACTION_PLAN.md)
- Review [FitIQCore README](../../FitIQCore/README.md)
- Search existing HealthKit code in FitIQ

### Technical Issues
- Review Apple HealthKit documentation
- Check Stack Overflow for HealthKit questions
- Consult team for architecture decisions

### Blockers
- Document the blocker clearly
- Identify what you've tried
- Reach out to team lead
- Consider alternative approaches

---

## 🎓 Key Principles

### 1. Start Simple
Don't try to extract everything at once. Start with core abstractions and iterate.

### 2. Test Everything
HealthKit is complex. Comprehensive tests prevent regressions.

### 3. Maintain Compatibility
FitIQ functionality must remain unchanged. Test thoroughly.

### 4. Document Decisions
Future developers will thank you. Explain "why" not just "what".

### 5. Iterate Based on Learning
If something doesn't work, adjust the plan. Stay flexible.

---

## 📚 Helpful Resources

### Apple Documentation
- [HealthKit Framework](https://developer.apple.com/documentation/healthkit)
- [HKHealthStore](https://developer.apple.com/documentation/healthkit/hkhealthstore)
- [HKQuery](https://developer.apple.com/documentation/healthkit/hkquery)

### FitIQ Codebase
- `FitIQ/Infrastructure/Integration/HealthKitAdapter.swift`
- `FitIQ/Domain/Ports/HealthRepositoryProtocol.swift`
- `FitIQ/Domain/UseCases/HealthKit/`

### Previous Phases
- [Phase 1 Complete](./FITIQCORE_PHASE1_COMPLETE.md)
- [Phase 1.5 Complete](./PHASE_1_5_COMPLETE.md)
- [Phase 2.1 Final Status](../FitIQ/docs/fixes/PHASE_2.1_FINAL_STATUS.md)

---

## 🎉 Success Criteria

Phase 2.2 is complete when:
- ✅ FitIQCore Health module exists and is functional
- ✅ FitIQ uses FitIQCore HealthKit (backward compatible)
- ✅ Lume can request HealthKit authorization
- ✅ Lume can query mindfulness data
- ✅ All tests passing (100% of existing, 80%+ of new)
- ✅ Zero compilation errors or warnings
- ✅ Documentation complete
- ✅ Both apps working in TestFlight

---

## 🚀 Let's Go!

1. **Read the full implementation plan** (15 min)
2. **Set up your environment** (15 min)
3. **Create first file** (30 min)
4. **Run tests** (5 min)
5. **Commit and celebrate** 🎉

You're ready to start Phase 2.2!

---

**Status:** 📋 Ready  
**Next Step:** Review existing HealthKit code  
**Estimated Start:** After Phase 2.1 validation  
**Estimated Completion:** 2-3 weeks from start

Good luck! 🚀