# Phase 2 Implementation Plan - Profile Unification

**Date:** 2025-01-27  
**Status:** 📋 Ready to Execute  
**Duration:** 1-2 weeks  
**Priority:** 🟢 HIGH VALUE

---

## 🎯 Phase 2 Objectives

Based on the assessment, Phase 2 focuses on:

1. **Profile Unification** - Migrate FitIQ to use FitIQCore.UserProfile
2. **SwiftData Utilities** - Extract fetch-or-create pattern (optional)
3. **Defer HealthKit** - Keep in FitIQ until Lume needs it

**Expected Outcome:** ~400 lines of duplication removed, consistent profile management

---

## 📋 Phase 2.1: Profile Unification (Week 1)

### Day 1-2: Enhance FitIQCore.UserProfile

#### Task 1.1: Analyze FitIQ's UserProfile Requirements ⏱️ 2 hours

**Goal:** Understand what fields FitIQ needs that aren't in FitIQCore.UserProfile

**Steps:**
1. Open `FitIQ/FitIQ/Domain/Entities/Profile/UserProfile.swift`
2. List all properties in FitIQ's UserProfile
3. Compare with FitIQCore's UserProfile
4. Document missing fields and their purposes

**Current FitIQCore.UserProfile:**
```swift
public struct UserProfile {
    public let id: UUID
    public let email: String
    public let name: String
    public let dateOfBirth: Date?
}
```

**FitIQ's Additional Fields:**
```swift
// From UserProfileMetadata
- bio: String?
- preferredUnitSystem: String
- languageCode: String?
- userId: UUID (separate from id)
- createdAt: Date
- updatedAt: Date

// From PhysicalProfile
- biologicalSex: String?
- heightCm: Double?

// HealthKit sync state
- hasPerformedInitialHealthKitSync: Bool
- lastSuccessfulDailySyncDate: Date?

// Auth fields
- username: String?
```

**Deliverable:** ✅ Document with complete field mapping

---

#### Task 1.2: Update FitIQCore.UserProfile ⏱️ 4 hours

**Goal:** Add FitIQ-specific fields to FitIQCore.UserProfile

**Steps:**

1. **Backup current FitIQCore.UserProfile**
   ```bash
   cd FitIQCore/Sources/FitIQCore/Auth/Domain
   cp UserProfile.swift UserProfile.swift.backup
   ```

2. **Add new fields to UserProfile struct**
   ```swift
   // FitIQCore/Sources/FitIQCore/Auth/Domain/UserProfile.swift
   public struct UserProfile: Codable, Equatable, Sendable {
       // MARK: - Core Identity (existing)
       public let id: UUID
       public let email: String
       public let name: String
       
       // MARK: - Optional Profile Fields (NEW)
       public let bio: String?
       public let username: String?
       public let languageCode: String?
       public let dateOfBirth: Date?
       
       // MARK: - Physical Attributes (NEW - for FitIQ)
       public let biologicalSex: String?
       public let heightCm: Double?
       
       // MARK: - Preferences (NEW)
       public let preferredUnitSystem: String
       
       // MARK: - HealthKit Sync State (NEW - for FitIQ)
       public let hasPerformedInitialHealthKitSync: Bool
       public let lastSuccessfulDailySyncDate: Date?
       
       // MARK: - Metadata
       public let createdAt: Date
       public let updatedAt: Date
   }
   ```

3. **Update initializer**
   ```swift
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
   ) {
       self.id = id
       self.email = email
       self.name = name
       self.bio = bio
       self.username = username
       self.languageCode = languageCode
       self.dateOfBirth = dateOfBirth
       self.biologicalSex = biologicalSex
       self.heightCm = heightCm
       self.preferredUnitSystem = preferredUnitSystem
       self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
       self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
       self.createdAt = createdAt
       self.updatedAt = updatedAt
   }
   ```

4. **Add convenience initializers for backward compatibility**
   ```swift
   // Simple initializer (for Lume - backward compatible)
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
           lastSuccessfulDailySyncDate: nil,
           createdAt: Date(),
           updatedAt: Date()
       )
   }
   ```

5. **Add update methods**
   ```swift
   // Update basic info
   public func updated(
       email: String? = nil,
       name: String? = nil,
       dateOfBirth: Date? = nil
   ) -> UserProfile {
       UserProfile(
           id: self.id,
           email: email ?? self.email,
           name: name ?? self.name,
           bio: self.bio,
           username: self.username,
           languageCode: self.languageCode,
           dateOfBirth: dateOfBirth ?? self.dateOfBirth,
           biologicalSex: self.biologicalSex,
           heightCm: self.heightCm,
           preferredUnitSystem: self.preferredUnitSystem,
           hasPerformedInitialHealthKitSync: self.hasPerformedInitialHealthKitSync,
           lastSuccessfulDailySyncDate: self.lastSuccessfulDailySyncDate,
           createdAt: self.createdAt,
           updatedAt: Date()
       )
   }
   
   // Update physical attributes (for FitIQ)
   public func updatingPhysical(
       biologicalSex: String? = nil,
       heightCm: Double? = nil
   ) -> UserProfile {
       UserProfile(
           id: self.id,
           email: self.email,
           name: self.name,
           bio: self.bio,
           username: self.username,
           languageCode: self.languageCode,
           dateOfBirth: self.dateOfBirth,
           biologicalSex: biologicalSex ?? self.biologicalSex,
           heightCm: heightCm ?? self.heightCm,
           preferredUnitSystem: self.preferredUnitSystem,
           hasPerformedInitialHealthKitSync: self.hasPerformedInitialHealthKitSync,
           lastSuccessfulDailySyncDate: self.lastSuccessfulDailySyncDate,
           createdAt: self.createdAt,
           updatedAt: Date()
       )
   }
   
   // Update HealthKit sync state (for FitIQ)
   public func updatingHealthKitSync(
       hasPerformedInitialSync: Bool,
       lastSyncDate: Date?
   ) -> UserProfile {
       UserProfile(
           id: self.id,
           email: self.email,
           name: self.name,
           bio: self.bio,
           username: self.username,
           languageCode: self.languageCode,
           dateOfBirth: self.dateOfBirth,
           biologicalSex: self.biologicalSex,
           heightCm: self.heightCm,
           preferredUnitSystem: self.preferredUnitSystem,
           hasPerformedInitialHealthKitSync: hasPerformedInitialSync,
           lastSuccessfulDailySyncDate: lastSyncDate,
           createdAt: self.createdAt,
           updatedAt: Date()
       )
   }
   ```

**Deliverable:** ✅ Enhanced FitIQCore.UserProfile with all FitIQ fields

---

#### Task 1.3: Add Tests for Enhanced UserProfile ⏱️ 3 hours

**Goal:** 95%+ test coverage for new UserProfile

**Steps:**

1. **Create test file**
   ```bash
   cd FitIQCore/Tests/FitIQCoreTests/Auth/Domain
   touch UserProfileTests.swift
   ```

2. **Add tests for initialization**
   ```swift
   func testInit_AllFields_CreatesProfile() {
       let profile = UserProfile(
           id: UUID(),
           email: "test@example.com",
           name: "Test User",
           bio: "Test bio",
           username: "testuser",
           languageCode: "en",
           dateOfBirth: Date(),
           biologicalSex: "male",
           heightCm: 180.0,
           preferredUnitSystem: "metric",
           hasPerformedInitialHealthKitSync: true,
           lastSuccessfulDailySyncDate: Date()
       )
       
       XCTAssertNotNil(profile)
       XCTAssertEqual(profile.email, "test@example.com")
       XCTAssertEqual(profile.heightCm, 180.0)
       XCTAssertTrue(profile.hasPerformedInitialHealthKitSync)
   }
   ```

3. **Add tests for backward compatibility**
   ```swift
   func testSimpleInit_BackwardCompatible_CreatesProfile() {
       let profile = UserProfile(
           id: UUID(),
           email: "test@example.com",
           name: "Test User",
           dateOfBirth: Date()
       )
       
       XCTAssertNotNil(profile)
       XCTAssertNil(profile.bio)
       XCTAssertNil(profile.biologicalSex)
       XCTAssertEqual(profile.preferredUnitSystem, "metric")
       XCTAssertFalse(profile.hasPerformedInitialHealthKitSync)
   }
   ```

4. **Add tests for update methods**
   ```swift
   func testUpdated_ChangesBasicInfo() {
       let original = UserProfile(
           id: UUID(),
           email: "old@example.com",
           name: "Old Name"
       )
       
       let updated = original.updated(
           email: "new@example.com",
           name: "New Name"
       )
       
       XCTAssertEqual(updated.email, "new@example.com")
       XCTAssertEqual(updated.name, "New Name")
       XCTAssertEqual(updated.id, original.id)
       XCTAssertNotEqual(updated.updatedAt, original.updatedAt)
   }
   ```

5. **Run tests**
   ```bash
   cd FitIQCore
   swift test
   ```

**Deliverable:** ✅ Comprehensive test suite for UserProfile

---

#### Task 1.4: Update FitIQCore Version and Documentation ⏱️ 1 hour

**Goal:** Release FitIQCore v0.3.0 with enhanced UserProfile

**Steps:**

1. **Update version in Package.swift**
   ```swift
   // FitIQCore/Package.swift
   // Add comment or tag
   // Version 0.3.0 - Enhanced UserProfile with physical attributes and HealthKit sync
   ```

2. **Update CHANGELOG.md**
   ```markdown
   ## [0.3.0] - 2025-01-27
   
   ### Added
   - Enhanced `UserProfile` with optional physical attributes (biologicalSex, heightCm)
   - Added HealthKit sync state fields (hasPerformedInitialHealthKitSync, lastSuccessfulDailySyncDate)
   - Added profile metadata fields (bio, username, languageCode, preferredUnitSystem)
   - Added timestamps (createdAt, updatedAt)
   - Added convenience update methods (updated, updatingPhysical, updatingHealthKitSync)
   - Backward compatible simple initializer for Lume
   
   ### Changed
   - UserProfile now supports both simple (Lume) and complex (FitIQ) use cases
   - All new fields are optional for backward compatibility
   
   ### Migration Guide
   - Lume: No changes needed, simple initializer still works
   - FitIQ: Can now use FitIQCore.UserProfile instead of local version
   ```

3. **Update README.md**
   ```markdown
   ## UserProfile
   
   Enhanced user profile supporting both basic and advanced use cases.
   
   ### Basic Usage (Lume)
   ```swift
   let profile = UserProfile(
       id: UUID(),
       email: "user@example.com",
       name: "John Doe",
       dateOfBirth: Date()
   )
   ```
   
   ### Advanced Usage (FitIQ)
   ```swift
   let profile = UserProfile(
       id: UUID(),
       email: "user@example.com",
       name: "John Doe",
       bio: "Fitness enthusiast",
       biologicalSex: "male",
       heightCm: 180.0,
       dateOfBirth: Date(),
       hasPerformedInitialHealthKitSync: true
   )
   ```
   ```

4. **Commit and tag**
   ```bash
   git add .
   git commit -m "feat: Enhance UserProfile for FitIQ compatibility (v0.3.0)

   - Add optional physical attributes (biologicalSex, heightCm)
   - Add HealthKit sync state
   - Add profile metadata fields
   - Maintain backward compatibility with Lume
   - Add comprehensive tests (95%+ coverage)"
   
   git tag v0.3.0
   git push origin main --tags
   ```

**Deliverable:** ✅ FitIQCore v0.3.0 released

---

### Day 3-4: Migrate FitIQ to FitIQCore.UserProfile

#### Task 2.1: Update FitIQ Package Dependency ⏱️ 0.5 hours

**Goal:** Point FitIQ to FitIQCore v0.3.0

**Steps:**

1. **Update Package.swift or Xcode project**
   ```swift
   // If using SPM locally, just rebuild
   // Xcode will detect the new version
   ```

2. **Build to verify package updates**
   ```bash
   cd FitIQ
   xcodebuild -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15' build
   ```

**Deliverable:** ✅ FitIQ using FitIQCore v0.3.0

---

#### Task 2.2: Create UserProfile Adapter/Mapper ⏱️ 2 hours

**Goal:** Smooth migration by mapping between FitIQ's old structure and FitIQCore

**Steps:**

1. **Create adapter file**
   ```bash
   touch FitIQ/FitIQ/Infrastructure/Adapters/UserProfileAdapter.swift
   ```

2. **Add conversion methods**
   ```swift
   //
   //  UserProfileAdapter.swift
   //  FitIQ
   //
   //  Created by AI Assistant on 2025-01-27.
   //  Purpose: Adapter for migrating from FitIQ.UserProfile to FitIQCore.UserProfile
   //
   
   import FitIQCore
   import Foundation
   
   /// Adapter for converting between FitIQ's old UserProfile and FitIQCore.UserProfile
   enum UserProfileAdapter {
       
       /// Convert FitIQ's UserProfileMetadata + PhysicalProfile to FitIQCore.UserProfile
       static func toDomain(
           metadata: UserProfileMetadata,
           physical: PhysicalProfile?,
           email: String?,
           username: String?,
           hasPerformedInitialHealthKitSync: Bool,
           lastSuccessfulDailySyncDate: Date?
       ) -> FitIQCore.UserProfile {
           FitIQCore.UserProfile(
               id: metadata.id,
               email: email ?? "",
               name: metadata.name,
               bio: metadata.bio,
               username: username,
               languageCode: metadata.languageCode,
               dateOfBirth: metadata.dateOfBirth ?? physical?.dateOfBirth,
               biologicalSex: physical?.biologicalSex,
               heightCm: physical?.heightCm,
               preferredUnitSystem: metadata.preferredUnitSystem,
               hasPerformedInitialHealthKitSync: hasPerformedInitialHealthKitSync,
               lastSuccessfulDailySyncDate: lastSuccessfulDailySyncDate,
               createdAt: metadata.createdAt,
               updatedAt: metadata.updatedAt
           )
       }
       
       /// Convert FitIQCore.UserProfile back to FitIQ's components
       static func fromDomain(
           _ profile: FitIQCore.UserProfile
       ) -> (metadata: UserProfileMetadata, physical: PhysicalProfile?) {
           let metadata = UserProfileMetadata(
               id: profile.id,
               userId: profile.id,
               name: profile.name,
               bio: profile.bio,
               preferredUnitSystem: profile.preferredUnitSystem,
               languageCode: profile.languageCode,
               dateOfBirth: profile.dateOfBirth,
               createdAt: profile.createdAt,
               updatedAt: profile.updatedAt
           )
           
           let physical: PhysicalProfile?
           if profile.biologicalSex != nil || profile.heightCm != nil {
               physical = PhysicalProfile(
                   biologicalSex: profile.biologicalSex,
                   heightCm: profile.heightCm,
                   dateOfBirth: profile.dateOfBirth
               )
           } else {
               physical = nil
           }
           
           return (metadata, physical)
       }
   }
   ```

**Deliverable:** ✅ UserProfile adapter for smooth migration

---

#### Task 2.3: Update SwiftData Models ⏱️ 2 hours

**Goal:** Update SDUserProfile to work with FitIQCore.UserProfile

**Steps:**

1. **Update SDUserProfile conversion methods**
   ```swift
   // FitIQ/FitIQ/Infrastructure/Persistence/Schema/SchemaV11.swift
   
   extension SDUserProfile {
       /// Convert to FitIQCore.UserProfile domain model
       func toDomain() -> FitIQCore.UserProfile {
           FitIQCore.UserProfile(
               id: self.id,
               email: self.email ?? "",
               name: self.name,
               bio: self.bio,
               username: self.email?.components(separatedBy: "@").first,
               languageCode: self.languageCode,
               dateOfBirth: self.dateOfBirth,
               biologicalSex: self.biologicalSex,
               heightCm: self.heightCm,
               preferredUnitSystem: self.preferredUnitSystem,
               hasPerformedInitialHealthKitSync: self.hasPerformedInitialHealthKitSync,
               lastSuccessfulDailySyncDate: self.lastSuccessfulDailySyncDate,
               createdAt: self.createdAt,
               updatedAt: self.updatedAt
           )
       }
       
       /// Update from FitIQCore.UserProfile domain model
       func update(from profile: FitIQCore.UserProfile) {
           self.name = profile.name
           self.email = profile.email
           self.bio = profile.bio
           self.languageCode = profile.languageCode
           self.dateOfBirth = profile.dateOfBirth
           self.biologicalSex = profile.biologicalSex
           self.heightCm = profile.heightCm
           self.preferredUnitSystem = profile.preferredUnitSystem
           self.hasPerformedInitialHealthKitSync = profile.hasPerformedInitialHealthKitSync
           self.lastSuccessfulDailySyncDate = profile.lastSuccessfulDailySyncDate
           self.updatedAt = Date()
       }
       
       /// Create from FitIQCore.UserProfile domain model
       static func from(_ profile: FitIQCore.UserProfile) -> SDUserProfile {
           let sdProfile = SDUserProfile()
           sdProfile.id = profile.id
           sdProfile.name = profile.name
           sdProfile.email = profile.email
           sdProfile.bio = profile.bio
           sdProfile.languageCode = profile.languageCode
           sdProfile.dateOfBirth = profile.dateOfBirth
           sdProfile.biologicalSex = profile.biologicalSex
           sdProfile.heightCm = profile.heightCm
           sdProfile.preferredUnitSystem = profile.preferredUnitSystem
           sdProfile.hasPerformedInitialHealthKitSync = profile.hasPerformedInitialHealthKitSync
           sdProfile.lastSuccessfulDailySyncDate = profile.lastSuccessfulDailySyncDate
           sdProfile.createdAt = profile.createdAt
           sdProfile.updatedAt = profile.updatedAt
           return sdProfile
       }
   }
   ```

**Deliverable:** ✅ SDUserProfile compatible with FitIQCore.UserProfile

---

#### Task 2.4: Update Repositories ⏱️ 3 hours

**Goal:** Update repositories to use FitIQCore.UserProfile

**Steps:**

1. **Update UserProfileRepository signatures**
   ```swift
   // Change return types from FitIQ.UserProfile to FitIQCore.UserProfile
   protocol UserProfileRepositoryProtocol {
       func fetchProfile(forUserID userID: UUID) async throws -> FitIQCore.UserProfile?
       func saveProfile(_ profile: FitIQCore.UserProfile) async throws
       func updateProfile(_ profile: FitIQCore.UserProfile) async throws
   }
   ```

2. **Update implementation to use SDUserProfile conversions**
   ```swift
   func fetchProfile(forUserID userID: UUID) async throws -> FitIQCore.UserProfile? {
       let descriptor = FetchDescriptor<SDUserProfile>(
           predicate: #Predicate { $0.id == userID }
       )
       
       guard let sdProfile = try modelContext.fetch(descriptor).first else {
           return nil
       }
       
       return sdProfile.toDomain()
   }
   ```

3. **Test repository changes**
   ```swift
   // Run unit tests
   xcodebuild test -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

**Deliverable:** ✅ Repositories using FitIQCore.UserProfile

---

#### Task 2.5: Update Use Cases ⏱️ 3 hours

**Goal:** Update all use cases that reference UserProfile

**Steps:**

1. **Find all use cases using UserProfile**
   ```bash
   cd FitIQ
   grep -r "UserProfile" Domain/UseCases/ | grep -v "UserProfileMetadata"
   ```

2. **Update signatures to use FitIQCore.UserProfile**
   ```swift
   // Example: CreateUserUseCase
   protocol CreateUserUseCase {
       func execute(userData: RegisterUserData) async throws -> FitIQCore.UserProfile
   }
   ```

3. **Update implementations**
   - Remove conversions between metadata/physical
   - Use FitIQCore.UserProfile directly
   - Simplify code by removing composition logic

4. **Test each use case**
   ```bash
   xcodebuild test -scheme FitIQ
   ```

**Deliverable:** ✅ Use cases using FitIQCore.UserProfile

---

#### Task 2.6: Update ViewModels ⏱️ 2 hours

**Goal:** Update ViewModels to use FitIQCore.UserProfile

**Steps:**

1. **Update ProfileViewModel**
   ```swift
   @Observable
   final class ProfileViewModel {
       var userProfile: FitIQCore.UserProfile?
       
       func loadProfile() async {
           do {
               userProfile = try await repository.fetchProfile(forUserID: currentUserID)
           } catch {
               // Handle error
           }
       }
   }
   ```

2. **Update other ViewModels referencing profile**
   - SummaryViewModel
   - OnboardingViewModel
   - SettingsViewModel

3. **Test ViewModels**
   - Verify data binding works
   - Check UI updates correctly

**Deliverable:** ✅ ViewModels using FitIQCore.UserProfile

---

### Day 5: Testing, Cleanup & Documentation

#### Task 3.1: Delete Old Profile Files ⏱️ 1 hour

**Goal:** Remove FitIQ's local UserProfile implementation

**Steps:**

1. **Verify no references remain**
   ```bash
   cd FitIQ
   grep -r "Domain/Entities/Profile/UserProfile" --exclude-dir=.build
   # Should return no results
   ```

2. **Delete old files**
   ```bash
   rm FitIQ/Domain/Entities/Profile/UserProfile.swift
   rm FitIQ/Domain/Entities/Profile/UserProfileMetadata.swift
   rm FitIQ/Domain/Entities/Profile/PhysicalProfile.swift
   ```

3. **Verify project still builds**
   ```bash
   xcodebuild -scheme FitIQ build
   ```

**Deliverable:** ✅ ~400 lines of duplication removed

---

#### Task 3.2: Run All Tests ⏱️ 2 hours

**Goal:** Verify everything works end-to-end

**Steps:**

1. **Run FitIQCore tests**
   ```bash
   cd FitIQCore
   swift test
   # Expected: All 88+ tests pass
   ```

2. **Run FitIQ tests**
   ```bash
   cd FitIQ
   xcodebuild test -scheme FitIQ
   # Expected: All tests pass
   ```

3. **Run Lume tests**
   ```bash
   cd lume
   xcodebuild test -scheme lume
   # Expected: All tests pass (backward compatibility)
   ```

4. **Fix any failing tests**

**Deliverable:** ✅ All tests passing

---

#### Task 3.3: Manual QA Testing ⏱️ 2 hours

**Goal:** Verify profile functionality works in real app

**FitIQ Test Cases:**
- [ ] User registration creates profile correctly
- [ ] User login loads profile correctly
- [ ] Profile editing saves changes
- [ ] Physical attributes (height, sex) save and load
- [ ] HealthKit sync state updates correctly
- [ ] Profile displays in UI correctly

**Lume Test Cases:**
- [ ] User registration still works (simple profile)
- [ ] User login still works
- [ ] Profile editing still works
- [ ] No regressions from FitIQCore.UserProfile changes

**Deliverable:** ✅ Manual QA checklist complete

---

#### Task 3.4: Update Documentation ⏱️ 2 hours

**Goal:** Document Phase 2.1 completion

**Steps:**

1. **Create completion report**
   ```bash
   touch docs/split-strategy/PHASE_2_1_COMPLETE.md
   ```

2. **Update IMPLEMENTATION_STATUS.md**
   - Mark Phase 2.1 as complete
   - Update progress metrics
   - Document code reduction

3. **Update PHASE_2_STATUS.md**
   - Update timeline
   - Document outcomes
   - Note lessons learned

4. **Commit all documentation**
   ```bash
   git add docs/
   git commit -m "docs: Phase 2.1 Profile Unification complete"
   ```

**Deliverable:** ✅ Complete documentation

---

## 📋 Phase 2.2: SwiftData Utilities (Optional - Week 2)

### Day 6-7: Extract Fetch-or-Create Utility

#### Task 4.1: Create SwiftData Utilities in FitIQCore ⏱️ 3 hours

**Goal:** Extract reusable SwiftData patterns

**Steps:**

1. **Create utilities file**
   ```bash
   cd FitIQCore/Sources/FitIQCore
   mkdir -p SwiftData
   touch SwiftData/ModelContextExtensions.swift
   ```

2. **Add fetch-or-create extension**
   ```swift
   #if canImport(SwiftData)
   import SwiftData
   import Foundation
   
   extension ModelContext {
       /// Fetch or create a model with the given ID
       ///
       /// This method implements the fetch-or-create pattern to prevent
       /// duplicate registration errors in SwiftData.
       ///
       /// - Parameters:
       ///   - id: The UUID to search for
       ///   - create: Closure to create a new instance if not found
       /// - Returns: Existing or newly created model
       public func fetchOrCreate<T: PersistentModel>(
           id: UUID,
           where predicate: Predicate<T>,
           create: () -> T
       ) throws -> T {
           let descriptor = FetchDescriptor<T>(predicate: predicate)
           
           if let existing = try fetch(descriptor).first {
               return existing
           } else {
               let new = create()
               insert(new)
               return new
           }
       }
   }
   #endif
   ```

3. **Add tests**
   ```swift
   // FitIQCore/Tests/FitIQCoreTests/SwiftData/
   // Add comprehensive tests for utility
   ```

**Deliverable:** ✅ Reusable SwiftData utilities

---

#### Task 4.2: Update FitIQ Repositories ⏱️ 4 hours

**Goal:** Use FitIQCore SwiftData utilities in FitIQ

**Steps:**

1. **Update SwiftDataProgressRepository**
   ```swift
   let sdProgressEntry = try modelContext.fetchOrCreate(
       id: progressEntry.id,
       where: #Predicate { $0.id == progressEntry.id },
       create: {
           let entry = SDProgressEntry(/* ... */)
           entry.id = progressEntry.id
           return entry
       }
   )
   ```

2. **Update other repositories similarly**
   - SwiftDataMealLogRepository
   - SwiftDataSleepRepository
   - SwiftDataWorkoutRepository

3. **Test all repositories**

**Deliverable:** ✅ FitIQ using shared SwiftData utilities

---

#### Task 4.3: Update Lume Repositories ⏱️ 4 hours

**Goal:** Use FitIQCore SwiftData utilities in Lume

**Steps:**

1. **Update Lume repositories**
   - MoodRepository
   - SleepRepository
   - JournalRepository

2. **Test all repositories**

**Deliverable:** ✅ Lume using shared SwiftData utilities

---

## ✅ Phase 2 Success Criteria

### Code Quality
- [ ] ✅ ~400 lines of duplicated profile code removed
- [ ] ✅ Both apps use FitIQCore.UserProfile
- [ ] ✅ Zero compilation errors
- [ ] ✅ Zero compilation warnings
- [ ] ✅ All tests passing (FitIQCore + FitIQ + Lume)

### Functionality
- [ ] ✅ FitIQ profile features work (physical attributes, HealthKit sync)
- [ ] ✅ Lume profile features work (backward compatibility)
- [ ] ✅ Profile CRUD operations work in both apps
- [ ] ✅ No regressions from changes

### Documentation
- [ ] ✅ FitIQCore v0.3.0 documented
- [ ] ✅ Migration guide created
- [ ] ✅ Phase 2 completion report
- [ ] ✅ Lessons learned documented

---

## 🚨 Rollback Plan

If Phase 2 encounters critical issues:

1. **Revert FitIQCore changes**
   ```bash
   cd FitIQCore
   git revert v0.3.0
   git tag v0.2.1
   ```

2. **Revert FitIQ changes**
   ```bash
   cd FitIQ
   git revert <commit-hash>
   ```

3. **Restore old UserProfile files** from backup

4. **Document issues** and reassess approach

---

## 📊 Progress Tracking

Use this checklist to track progress:

### Week 1: Profile Unification
- [ ] Day 1-2: Enhance FitIQCore.UserProfile
  - [ ] Task 1.1: Analyze requirements
  - [ ] Task 1.2: Update UserProfile struct
  - [ ] Task 1.3: Add tests
  - [ ] Task 1.4: Release v0.3.0
- [ ] Day 3-4: Migrate FitIQ
  - [ ] Task 2.1: Update package dependency
  - [ ] Task 2.2: Create adapter
  - [ ] Task 2.3: Update SwiftData models
  - [ ] Task 2.4: Update repositories
  - [ ] Task 2.5: Update use cases
  - [ ] Task 2.6: Update ViewModels
- [ ] Day 5: Testing & Cleanup
  - [ ] Task 3.1: Delete old files
  - [ ] Task 3.2: Run all tests
  - [ ] Task 3.3: Manual QA
  - [ ] Task 3.4: Update documentation

### Week 2: SwiftData Utilities (Optional)
- [ ] Day 6-7: Extract utilities
  - [ ] Task 4.1: Create utilities in FitIQCore
  - [ ] Task 4.2: Update FitIQ repositories
  - [ ] Task 4.3: Update Lume repositories

---

## 🎉 Expected Outcomes

By end of Phase 2:

✅ **Unified Profile Management**
- Single UserProfile model (FitIQCore.UserProfile)
- ~400 lines of duplication removed
- Consistent behavior across apps

✅ **Improved Code Quality**
- Better maintainability
- Easier to add features
- Single source of truth

✅ **Production-Ready**
- All tests passing
- Zero errors/warnings
- Ready for TestFlight

✅ **Clear Path Forward**
- HealthKit decision documented
- Phase 3 scope defined (if needed)
- Team aligned

---

**Document Version:** 1.0  
**Created:** 2025-01-27  
**Status:** 📋 Ready for Execution  
**Start Date:** TBD (when approved)  
**Estimated Completion:** 1-2 weeks from start