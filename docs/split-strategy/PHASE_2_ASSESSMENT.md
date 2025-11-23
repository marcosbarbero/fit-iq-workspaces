# Phase 2 Assessment - Domain Extraction

**Date:** 2025-01-27  
**Status:** 📋 Planning Phase  
**Estimated Duration:** 2-3 weeks (based on Phase 1.5 efficiency gains)

---

## 📊 Executive Summary

Phase 2 focuses on extracting **domain-specific functionality** from FitIQ and Lume into FitIQCore. Based on initial assessment:

**Key Findings:**
- ✅ **UserProfile already in FitIQCore** - Lume using it, FitIQ has local version
- 🔴 **HealthKit only in FitIQ** - Lume doesn't use HealthKit at all
- 🟡 **SwiftData patterns differ** - Both apps use SwiftData but with different models

**Recommendation:** Focus on **Profile unification** first (quick win), then assess HealthKit extraction value.

---

## 🎯 Phase 2 Goals

### Primary Objectives

1. **Unify Profile Management**
   - Migrate FitIQ to use FitIQCore.UserProfile
   - Eliminate duplicated profile code
   - Consistent profile behavior across apps

2. **Assess HealthKit Extraction**
   - Determine if HealthKit should be extracted
   - FitIQ-only vs. shared library trade-offs
   - Cost-benefit analysis

3. **Evaluate SwiftData Utilities**
   - Identify common patterns
   - Assess extraction value
   - Consider app-specific vs. shared utilities

### Success Criteria

- [x] Profile management unified (both apps use FitIQCore.UserProfile)
- [ ] HealthKit extraction decision made (extract vs. keep in FitIQ)
- [ ] SwiftData utilities assessed
- [ ] Zero code duplication for extracted components
- [ ] Both apps build with zero errors
- [ ] All tests passing

---

## 🔍 Component Analysis

### 1. Profile Management 🟢 HIGH PRIORITY

#### Current State

**FitIQCore (v0.2.0):**
```swift
// Already exists in FitIQCore
public struct UserProfile {
    public let id: UUID
    public let email: String
    public let name: String
    public let dateOfBirth: Date?
    
    // Methods for updating profile
    public func updated(email:name:dateOfBirth:) -> UserProfile
}
```

**Lume Status:** ✅ ALREADY USING FitIQCore.UserProfile
```swift
// lume/lume/Core/UserSession.swift
let profile = FitIQCore.UserProfile(
    id: userId,
    email: email,
    name: name,
    dateOfBirth: dateOfBirth
)
```

**FitIQ Status:** ❌ USING LOCAL VERSION
```swift
// FitIQ/FitIQ/Domain/Entities/Profile/UserProfile.swift
public struct UserProfile: Identifiable, Equatable {
    public let metadata: UserProfileMetadata
    public let physical: PhysicalProfile?
    public let email: String?
    public let username: String?
    // ... 400+ lines
}
```

#### Key Differences

| Feature | FitIQCore.UserProfile | FitIQ.UserProfile |
|---------|----------------------|-------------------|
| **Complexity** | Simple (4 fields) | Complex (metadata + physical) |
| **Lines of Code** | ~50 lines | ~400 lines |
| **Components** | Flat structure | Composition (metadata + physical) |
| **HealthKit Integration** | No | Yes (physical profile) |
| **Backend Mapping** | Basic | Advanced (multiple endpoints) |

#### Migration Strategy: OPTION A (Recommended)

**Enhance FitIQCore.UserProfile to Support FitIQ's Needs**

```swift
// Add to FitIQCore v0.3.0
public struct UserProfile {
    // Basic fields (already exist)
    public let id: UUID
    public let email: String
    public let name: String
    public let dateOfBirth: Date?
    
    // NEW: Optional physical attributes (for FitIQ)
    public let biologicalSex: String?
    public let heightCm: Double?
    public let preferredUnitSystem: String
    public let bio: String?
    public let languageCode: String?
    
    // NEW: HealthKit sync state (for FitIQ)
    public let hasPerformedInitialHealthKitSync: Bool
    public let lastSuccessfulDailySyncDate: Date?
    
    // Timestamps
    public let createdAt: Date
    public let updatedAt: Date
}
```

**Pros:**
- ✅ Single UserProfile model for both apps
- ✅ Lume can ignore optional fields (backward compatible)
- ✅ FitIQ gets full functionality
- ✅ Consistent profile management

**Cons:**
- ⚠️ FitIQCore.UserProfile becomes more complex
- ⚠️ Lume includes unused fields (minor overhead)

**Estimated Effort:** 1-2 days

#### Migration Strategy: OPTION B (Alternative)

**Keep FitIQ's Complex Profile, Use FitIQCore for Lume Only**

**Pros:**
- ✅ No changes to FitIQ
- ✅ FitIQCore stays simple

**Cons:**
- ❌ Profile duplication continues
- ❌ Inconsistent behavior
- ❌ Misses Phase 2 goal

**Verdict:** Not recommended

---

### 2. HealthKit Integration 🟡 ASSESS CAREFULLY

#### Current State

**FitIQ:** Extensive HealthKit usage (20+ files)
```swift
// Examples:
- Domain/Entities/HealthMetricsSnapshot.swift
- Domain/Ports/HealthRepositoryProtocol.swift
- Infrastructure/Repositories/HealthKitAdapter.swift
- Domain/UseCases/RequestHealthKitAuthorizationUseCase.swift
- Domain/UseCases/GetHistoricalWeightUseCase.swift
- Domain/UseCases/SaveMoodUseCase.swift
- Domain/UseCases/BackgroundSyncManager.swift
// ... 20+ more files
```

**Lume:** Zero HealthKit usage
```bash
$ grep -r "import HealthKit" lume/
# No matches found
```

#### Key Questions

**1. Will Lume ever use HealthKit?**
- 🟢 **Likely YES** - Wellness apps benefit from health data
- Sleep tracking, heart rate variability, mindfulness sessions
- But not urgent/required currently

**2. What's the extraction cost?**
- 🔴 **HIGH** - 20+ files, complex domain logic
- HealthKit wrapper layer
- Use cases specific to health metrics
- Background sync orchestration

**3. What's the maintenance benefit?**
- 🟡 **MODERATE** - Only if Lume adopts HealthKit soon
- Otherwise, just maintenance overhead in shared library

#### Extraction Options

**OPTION A: Extract Core HealthKit Wrapper Only**

Extract minimal HealthKit abstraction:
```swift
// FitIQCore/Sources/FitIQCore/HealthKit/
- HealthKitManager.swift          (authorization, availability)
- HealthKitDataType.swift          (quantity types, categories)
- HealthKitQueryBuilder.swift      (query utilities)
```

**Pros:**
- ✅ Smaller scope (3-5 files)
- ✅ Reusable if Lume adds HealthKit
- ✅ Core functionality shared

**Cons:**
- ⚠️ Use cases remain in FitIQ
- ⚠️ Still app-specific logic duplication

**Estimated Effort:** 3-5 days

---

**OPTION B: Extract Full HealthKit Domain**

Extract all HealthKit-related code:
```swift
// FitIQCore/Sources/FitIQCore/HealthKit/
- Core/
  - HealthKitManager.swift
  - HealthKitDataType.swift
- UseCases/
  - RequestAuthorizationUseCase.swift
  - FetchMetricsUseCase.swift
  - SaveMetricsUseCase.swift
- Domain/
  - HealthMetric.swift
  - HealthMetricType.swift
```

**Pros:**
- ✅ Complete HealthKit abstraction
- ✅ Ready for Lume integration
- ✅ Centralized health logic

**Cons:**
- 🔴 Large scope (20+ files)
- 🔴 Complex migration (2-3 weeks)
- 🔴 Premature if Lume doesn't need it

**Estimated Effort:** 2-3 weeks

---

**OPTION C: Keep HealthKit in FitIQ (Recommended)**

**Reasoning:**
- Lume doesn't currently need HealthKit
- FitIQ's HealthKit code is highly app-specific
- Can extract later if/when Lume needs it
- Focus efforts on higher-value items (Profile)

**Pros:**
- ✅ No migration effort
- ✅ Avoid premature abstraction
- ✅ Keep FitIQ-specific logic where it belongs

**Cons:**
- ⚠️ No code sharing for HealthKit
- ⚠️ Lume will need separate implementation if needed

**Verdict:** **Defer HealthKit extraction to Phase 3 or later**

---

### 3. SwiftData Utilities 🟡 LOW PRIORITY

#### Current State

**FitIQ SwiftData Usage:**
```
Schema:
- SchemaV11 (current)
- SDUserProfile
- SDProgressEntry
- SDOutboxEvent
- SDSleepSession
- SDActivitySnapshot
- SDMealLog
- SDWorkout
- ... 15+ models

Repositories:
- SwiftDataProgressRepository
- SwiftDataMealLogRepository
- SwiftDataSleepRepository
- SwiftDataWorkoutRepository
- SwiftDataOutboxRepository
- ... 10+ repositories
```

**Lume SwiftData Usage:**
```
Schema:
- SchemaV1 (current)
- SDUserProfile
- SDMoodEntry
- SDSleepLog
- SDJournalEntry
- ... 8+ models

Repositories:
- MoodRepository
- SleepRepository
- JournalRepository
- ... 6+ repositories
```

#### Common Patterns

**Potential Shared Utilities:**

1. **Fetch-or-Create Pattern** (from recent fix)
   ```swift
   // Common pattern for idempotent saves
   func fetchOrCreate<T: PersistentModel>(
       id: UUID,
       create: () -> T
   ) -> T
   ```

2. **Repository Base Protocol**
   ```swift
   protocol RepositoryProtocol {
       associatedtype Entity
       func save(_ entity: Entity) async throws
       func fetch(id: UUID) async throws -> Entity?
       func fetchAll() async throws -> [Entity]
       func delete(id: UUID) async throws
   }
   ```

3. **SwiftData Error Handling**
   ```swift
   enum SwiftDataError: Error {
       case saveFailed(Error)
       case fetchFailed(Error)
       case notFound(UUID)
   }
   ```

#### Extraction Assessment

**Should we extract?**

**Arguments FOR:**
- ✅ Reduce boilerplate in repositories
- ✅ Consistent error handling
- ✅ Shared best practices (fetch-or-create)

**Arguments AGAINST:**
- ❌ Models are app-specific (can't share)
- ❌ Repositories are tightly coupled to domain
- ❌ Limited reuse opportunity
- ❌ May constrain app-specific optimizations

**Recommendation:** Extract small utilities only (fetch-or-create helper)

**Estimated Effort:** 1-2 days

---

## 📋 Phase 2 Scope - RECOMMENDED

Based on analysis, here's the recommended Phase 2 scope:

### 🟢 IN SCOPE (High Value)

#### 1. Profile Unification ✅ HIGH PRIORITY
- **Goal:** Both apps use FitIQCore.UserProfile
- **Approach:** Enhance FitIQCore.UserProfile to support FitIQ's needs
- **Files to Migrate:** 3-5 files in FitIQ
- **Estimated Effort:** 1-2 days
- **Value:** Eliminates 400+ lines of duplication, consistent profiles

#### 2. SwiftData Fetch-or-Create Utility ✅ MEDIUM PRIORITY
- **Goal:** Shared utility for idempotent saves
- **Approach:** Extract pattern from recent duplicate fix
- **Files to Create:** 1 file in FitIQCore
- **Estimated Effort:** 0.5 days
- **Value:** Prevents duplicate registration bugs, reusable pattern

### 🟡 OUT OF SCOPE (Defer)

#### 3. HealthKit Extraction ⏸️ DEFERRED TO PHASE 3+
- **Reason:** Lume doesn't currently use HealthKit
- **Decision:** Keep in FitIQ until Lume needs it
- **Re-assess:** When Lume adds health features

#### 4. Full SwiftData Abstraction ⏸️ DEFERRED
- **Reason:** Models and repositories are app-specific
- **Decision:** Keep repositories in each app
- **Extract:** Only small utilities (fetch-or-create)

---

## 📊 Phase 2 Timeline

### Week 1: Profile Unification

**Day 1-2: Enhance FitIQCore.UserProfile**
- [ ] Add optional fields for FitIQ (biologicalSex, heightCm, etc.)
- [ ] Add HealthKit sync state fields
- [ ] Update Codable implementation
- [ ] Add update methods
- [ ] Add tests (target: 95%+ coverage)
- [ ] Update FitIQCore to v0.3.0

**Day 3-4: Migrate FitIQ to FitIQCore.UserProfile**
- [ ] Update FitIQ imports to use FitIQCore.UserProfile
- [ ] Update SwiftData models (SDUserProfile)
- [ ] Update repositories
- [ ] Update use cases
- [ ] Update ViewModels
- [ ] Fix compilation errors

**Day 5: Testing & Cleanup**
- [ ] Delete old FitIQ UserProfile files
- [ ] Run all tests
- [ ] Manual QA testing
- [ ] Verify Lume still works (backward compatibility)
- [ ] Update documentation

**Deliverables:**
- ✅ FitIQCore v0.3.0 with enhanced UserProfile
- ✅ FitIQ using FitIQCore.UserProfile
- ✅ Lume still using FitIQCore.UserProfile (unchanged)
- ✅ ~400 lines of duplication removed
- ✅ All tests passing

### Week 2: SwiftData Utilities (Optional)

**Day 6-7: Extract Fetch-or-Create Utility**
- [ ] Create FitIQCore/SwiftData/Utilities.swift
- [ ] Extract fetch-or-create pattern
- [ ] Add comprehensive tests
- [ ] Document usage

**Day 8-9: Integrate into Both Apps**
- [ ] Update FitIQ repositories to use utility
- [ ] Update Lume repositories to use utility
- [ ] Test for duplicate registration issues
- [ ] Verify all saves work correctly

**Day 10: Buffer/Documentation**
- [ ] Final testing
- [ ] Update all documentation
- [ ] Create Phase 2 completion report
- [ ] Plan Phase 3 (if needed)

**Deliverables:**
- ✅ FitIQCore SwiftData utilities
- ✅ Both apps using shared utilities
- ✅ Consistent error handling
- ✅ Documentation complete

---

## 🎯 Success Metrics

### Code Quality

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Duplication Removed** | ~400 lines | Git diff |
| **Test Coverage** | 95%+ | Xcode coverage reports |
| **Compilation Errors** | 0 | Xcode build |
| **Runtime Crashes** | 0 | Manual QA |

### Performance

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Build Time Change** | < +5% | Xcode build analytics |
| **App Launch Time** | No regression | Instruments |
| **Profile Load Time** | No regression | Manual testing |

### Developer Experience

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Code Consistency** | 100% | Both apps use same UserProfile |
| **API Clarity** | Clear | Developer feedback |
| **Documentation** | Complete | All APIs documented |

---

## 🚨 Risks & Mitigations

### Risk 1: Breaking Lume's UserProfile Usage 🔴 HIGH

**Risk:** Enhancing FitIQCore.UserProfile might break Lume

**Mitigation:**
- ✅ Make all new fields optional
- ✅ Maintain backward compatibility
- ✅ Test Lume after each change
- ✅ Add integration tests

### Risk 2: FitIQ Migration Complexity 🟡 MEDIUM

**Risk:** FitIQ has 400+ lines of profile code to migrate

**Mitigation:**
- ✅ Incremental migration (one file at a time)
- ✅ Keep old code until fully tested
- ✅ Comprehensive tests before deletion
- ✅ Use Phase 1.5 patterns (fetch-or-create)

### Risk 3: SwiftData Utility Adoption 🟢 LOW

**Risk:** Teams might not adopt new utilities

**Mitigation:**
- ✅ Clear documentation with examples
- ✅ Demonstrate value (prevent crashes)
- ✅ Easy to use API
- ✅ Gradual rollout

---

## 📚 Related Documents

### Phase 1 Documents
- [Phase 1.5 Complete](./PHASE_1_5_COMPLETE.md)
- [Phase 1.5 Status](./PHASE_1_5_STATUS.md)
- [Implementation Status](./IMPLEMENTATION_STATUS.md)

### FitIQCore Documents
- [FitIQCore README](../../FitIQCore/README.md)
- [FitIQCore CHANGELOG](../../FitIQCore/CHANGELOG.md)

### Architecture Documents
- [Duplicate Registration Fix](../../FitIQ/docs/fixes/DUPLICATE_REGISTRATION_FIX.md)
- [Profile Refactoring](../../FitIQ/docs/architecture/PROFILE_REFACTORING.md) (if exists)

---

## ✅ Phase 2 Checklist

Before starting Phase 2:

- [x] Phase 1.5 complete
- [x] Both apps deployed to TestFlight
- [x] No outstanding critical bugs
- [x] Phase 2 assessment complete
- [x] Scope defined and approved
- [x] Timeline agreed upon

During Phase 2:

- [ ] Daily progress updates
- [ ] Continuous integration testing
- [ ] Documentation as we go
- [ ] Regular communication with team

After Phase 2:

- [ ] All tests passing
- [ ] Both apps build successfully
- [ ] TestFlight deployment
- [ ] Phase 2 completion report
- [ ] Phase 3 planning (if needed)

---

## 🎉 Expected Outcomes

**By End of Phase 2:**

✅ **Single UserProfile Model**
- Both FitIQ and Lume use FitIQCore.UserProfile
- ~400 lines of duplication removed
- Consistent profile behavior

✅ **Shared SwiftData Utilities**
- Fetch-or-create pattern available
- Prevents duplicate registration bugs
- Consistent error handling

✅ **Production-Ready Apps**
- Zero compilation errors
- All tests passing
- Deployed to TestFlight

✅ **Clear Path Forward**
- HealthKit extraction decision documented
- Phase 3 scope defined (if needed)
- Team aligned on next steps

---

## 🚀 Next Steps

### Immediate Actions

1. **Review this assessment** with team
2. **Approve Phase 2 scope** (Profile + SwiftData utilities)
3. **Schedule Phase 2 kick-off** (1-2 week sprint)
4. **Assign resources** (engineer time)

### Phase 2 Execution

1. **Week 1:** Profile unification
2. **Week 2:** SwiftData utilities (optional)
3. **Testing & deployment**
4. **Phase 2 completion report**

### Post-Phase 2

1. **Evaluate results** vs. success metrics
2. **Document lessons learned**
3. **Decide on Phase 3** (HealthKit? Other?)
4. **Celebrate success!** 🎉

---

**Document Version:** 1.0  
**Created:** 2025-01-27  
**Status:** 📋 Planning - Ready for Review  
**Next Review:** After team approval  
**Estimated Start:** 2025-01-28 or when approved