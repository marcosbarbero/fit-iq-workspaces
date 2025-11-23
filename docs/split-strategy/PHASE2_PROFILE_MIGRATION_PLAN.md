# Phase 2: Profile Unification Migration Plan

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** 🚧 In Progress  
**Phase:** 2.1 - Profile Unification (Week 1)

---

## 📋 Executive Summary

This document outlines the detailed migration plan for moving FitIQ from its current complex `UserProfile` model (composition of `UserProfileMetadata` + `PhysicalProfile`) to the unified `FitIQCore.UserProfile` model.

**Goal:** Eliminate duplicate profile code and establish FitIQCore as the single source of truth for user profile data.

**Outcome:** FitIQ uses `FitIQCore.UserProfile` directly, with all old profile entities removed.

---

## 🎯 Current State Analysis

### FitIQ's Current Profile Architecture

```
FitIQ/Domain/Entities/Profile/
├── UserProfile.swift          # Composite model (metadata + physical + sync state)
├── UserProfileMetadata.swift  # Profile info (name, bio, preferences)
└── PhysicalProfile.swift      # Physical attributes (biologicalSex, heightCm, dateOfBirth)
```

**Key Characteristics:**
- **Composite Structure:** `UserProfile` combines `UserProfileMetadata` + `PhysicalProfile`
- **Local State:** Includes `hasPerformedInitialHealthKitSync`, `lastSuccessfulDailySyncDate`
- **Auth Data:** Includes `email`, `username` (from JWT, not backend profile)
- **Complex Updates:** Separate update methods for metadata vs. physical
- **Validation:** Nested validation (metadata errors + physical errors)

### FitIQCore's Profile Model

```
FitIQCore/Sources/FitIQCore/Auth/Domain/UserProfile.swift
```

**Key Characteristics:**
- **Unified Structure:** Single struct with all fields (core + optional)
- **Multi-App Support:** Optional fields for app-specific data
- **Immutable:** Value type with update methods returning new instances
- **Thread-Safe:** Sendable, Codable, Equatable
- **Validation:** Built-in validation with typed errors
- **Update Methods:** 
  - `updated(email:name:dateOfBirth:)` - Basic info
  - `updatingPhysical(biologicalSex:heightCm:)` - Physical attributes
  - `updatingHealthKitSync(hasPerformedInitialSync:lastSyncDate:)` - Sync state

---

## 🔄 Migration Strategy

### Phase 2.1: Profile Model Migration (This Phase)

**Objective:** Replace FitIQ's profile models with FitIQCore.UserProfile

**Steps:**
1. ✅ **Analyze Current Usage** - Map all usages of FitIQ's UserProfile
2. 🔄 **Update Protocols** - Adapt ports to use FitIQCore.UserProfile
3. 🔄 **Migrate Repositories** - Update SwiftData adapters
4. 🔄 **Migrate Use Cases** - Update all profile-related use cases
5. 🔄 **Update ViewModels** - Adapt presentation layer
6. 🔄 **Remove Old Models** - Delete FitIQ's profile entities
7. ⏳ **Testing & QA** - Comprehensive validation

---

## 📊 Impact Analysis

### Files to Update (Ports)

| File | Changes Required | Complexity |
|------|------------------|------------|
| `Domain/Ports/UserProfileStoragePortProtocol.swift` | Change `UserProfile` to `FitIQCore.UserProfile` | Low |
| `Domain/Ports/UserProfileRepositoryProtocol.swift` | Change return type to `FitIQCore.UserProfile` | Low |
| `Domain/Ports/AuthRepositoryProtocol.swift` | Update tuple return types | Low |

### Files to Update (Repositories)

| File | Changes Required | Complexity |
|------|------------------|------------|
| `Infrastructure/Repositories/SwiftDataUserProfileAdapter.swift` | Map `SDUserProfile` ↔️ `FitIQCore.UserProfile` | Medium |
| `Infrastructure/Network/UserProfileAPIClient.swift` | Update DTO mapping to FitIQCore model | Medium |
| `Infrastructure/Network/UserAuthAPIClient.swift` | Update authentication response mapping | Medium |

### Files to Update (Use Cases)

| File | Changes Required | Complexity |
|------|------------------|------------|
| `Domain/UseCases/GetUserProfileUseCase.swift` | Return `FitIQCore.UserProfile` | Low |
| `Domain/UseCases/LoginUserUseCase.swift` | Use FitIQCore model for profile comparison | Medium |
| `Domain/UseCases/RegisterUserUseCase.swift` | Use FitIQCore model | Low |
| `Domain/UseCases/GetPhysicalProfileUseCase.swift` | **DELETE** - No longer needed | Low |
| `Domain/UseCases/ForceHealthKitResyncUseCase.swift` | Update sync state using FitIQCore methods | Low |
| `Domain/UseCases/UpdateProfileMetadataUseCase.swift` | Use FitIQCore update methods | Medium |
| `Domain/UseCases/UpdatePhysicalProfileUseCase.swift` | Use FitIQCore update methods | Medium |

### Files to Update (ViewModels)

| File | Changes Required | Complexity |
|------|------------------|------------|
| `Presentation/ViewModels/ProfileViewModel.swift` | Use `FitIQCore.UserProfile` | Medium |
| `Presentation/ViewModels/OnboardingViewModel.swift` | Use FitIQCore model | Low |
| Other ViewModels referencing profile | Update type references | Low |

### Files to DELETE

| File | Reason |
|------|--------|
| `Domain/Entities/Profile/UserProfile.swift` | Replaced by FitIQCore.UserProfile |
| `Domain/Entities/Profile/UserProfileMetadata.swift` | Merged into FitIQCore.UserProfile |
| `Domain/Entities/Profile/PhysicalProfile.swift` | Merged into FitIQCore.UserProfile |
| `Domain/UseCases/GetPhysicalProfileUseCase.swift` | No longer needed (unified model) |

---

## 🔧 Detailed Migration Steps

### Step 1: Update Domain Ports ✅ READY

**Action:** Update protocol signatures to use `FitIQCore.UserProfile`

**Files:**
```swift
// Domain/Ports/UserProfileStoragePortProtocol.swift
import FitIQCore

public protocol UserProfileStoragePortProtocol {
    func save(userProfile: FitIQCore.UserProfile) async throws
    func fetch(forUserID userID: UUID) async throws -> FitIQCore.UserProfile?
    func delete(forUserID userID: UUID) async throws
}
```

```swift
// Domain/Ports/UserProfileRepositoryProtocol.swift
import FitIQCore

protocol UserProfileRepositoryProtocol {
    func getUserProfile(userId: String) async throws -> FitIQCore.UserProfile
    func updateProfileMetadata(userId: String, name: String?, bio: String?, languageCode: String?) async throws -> FitIQCore.UserProfile
    func updatePhysicalProfile(userId: String, biologicalSex: String?, heightCm: Double?) async throws -> FitIQCore.UserProfile
}
```

```swift
// Domain/Ports/AuthRepositoryProtocol.swift
import FitIQCore

protocol AuthRepositoryProtocol {
    func register(userData: RegisterUserData) async throws -> (
        profile: FitIQCore.UserProfile, 
        accessToken: String, 
        refreshToken: String
    )
    
    func login(credentials: LoginCredentials) async throws -> (
        profile: FitIQCore.UserProfile, 
        accessToken: String, 
        refreshToken: String
    )
}
```

---

### Step 2: Update SwiftData Repository ⏳ NEXT

**File:** `Infrastructure/Repositories/SwiftDataUserProfileAdapter.swift`

**Current Structure:**
```swift
@Model
final class SDUserProfile {
    var id: UUID
    var userId: UUID
    var name: String
    var bio: String?
    var email: String?
    var username: String?
    var biologicalSex: String?
    var heightCm: Double?
    var dateOfBirth: Date?
    var preferredUnitSystem: String
    var languageCode: String?
    var hasPerformedInitialHealthKitSync: Bool
    var lastSuccessfulDailySyncDate: Date?
    var createdAt: Date
    var updatedAt: Date
}
```

**Migration Strategy:**

1. **SDUserProfile → FitIQCore.UserProfile Mapping:**
```swift
extension SDUserProfile {
    func toDomain() -> FitIQCore.UserProfile {
        FitIQCore.UserProfile(
            id: self.id,
            email: self.email ?? "",
            name: self.name,
            bio: self.bio,
            username: self.username,
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
    
    func updateFrom(profile: FitIQCore.UserProfile) {
        self.id = profile.id
        self.userId = profile.id // Use profile.id as userId
        self.email = profile.email
        self.name = profile.name
        self.bio = profile.bio
        self.username = profile.username
        self.languageCode = profile.languageCode
        self.dateOfBirth = profile.dateOfBirth
        self.biologicalSex = profile.biologicalSex
        self.heightCm = profile.heightCm
        self.preferredUnitSystem = profile.preferredUnitSystem
        self.hasPerformedInitialHealthKitSync = profile.hasPerformedInitialHealthKitSync
        self.lastSuccessfulDailySyncDate = profile.lastSuccessfulDailySyncDate
        self.createdAt = profile.createdAt
        self.updatedAt = profile.updatedAt
    }
    
    static func from(profile: FitIQCore.UserProfile) -> SDUserProfile {
        SDUserProfile(
            id: profile.id,
            userId: profile.id,
            name: profile.name,
            bio: profile.bio,
            email: profile.email,
            username: profile.username,
            biologicalSex: profile.biologicalSex,
            heightCm: profile.heightCm,
            dateOfBirth: profile.dateOfBirth,
            preferredUnitSystem: profile.preferredUnitSystem,
            languageCode: profile.languageCode,
            hasPerformedInitialHealthKitSync: profile.hasPerformedInitialHealthKitSync,
            lastSuccessfulDailySyncDate: profile.lastSuccessfulDailySyncDate,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt
        )
    }
}
```

2. **Update Repository Methods:**
```swift
final class SwiftDataUserProfileAdapter: UserProfileStoragePortProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(userProfile: FitIQCore.UserProfile) async throws {
        // Fetch-or-create pattern to prevent duplicates
        let descriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate { $0.userId == userProfile.id }
        )
        
        let existing = try modelContext.fetch(descriptor).first
        
        if let existingProfile = existing {
            // Update existing
            existingProfile.updateFrom(profile: userProfile)
        } else {
            // Insert new
            let newProfile = SDUserProfile.from(profile: userProfile)
            modelContext.insert(newProfile)
        }
        
        try modelContext.save()
    }
    
    func fetch(forUserID userID: UUID) async throws -> FitIQCore.UserProfile? {
        let descriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate { $0.userId == userID }
        )
        
        guard let sdProfile = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return sdProfile.toDomain()
    }
    
    func delete(forUserID userID: UUID) async throws {
        let descriptor = FetchDescriptor<SDUserProfile>(
            predicate: #Predicate { $0.userId == userID }
        )
        
        guard let profile = try modelContext.fetch(descriptor).first else {
            return
        }
        
        modelContext.delete(profile)
        try modelContext.save()
    }
}
```

---

### Step 3: Update Network Clients ⏳ PENDING

**File:** `Infrastructure/Network/UserProfileAPIClient.swift`

**Update DTO Mapping:**
```swift
// Response DTOs remain the same
struct ProfileMetadataResponseDTO: Codable {
    let id: String
    let user_id: String
    let name: String
    let bio: String?
    let preferred_unit_system: String
    let language_code: String?
    let date_of_birth: String?
    let created_at: String
    let updated_at: String
}

struct PhysicalProfileResponseDTO: Codable {
    let biological_sex: String?
    let height_cm: Double?
    let date_of_birth: String?
}

// NEW: Map to FitIQCore.UserProfile
extension ProfileMetadataResponseDTO {
    func toDomain(
        physical: PhysicalProfileResponseDTO?,
        email: String?
    ) -> FitIQCore.UserProfile? {
        guard let profileId = UUID(uuidString: id),
              let createdDate = ISO8601DateFormatter().date(from: created_at),
              let updatedDate = ISO8601DateFormatter().date(from: updated_at) else {
            return nil
        }
        
        let dateOfBirth: Date?
        if let dobString = date_of_birth ?? physical?.date_of_birth {
            dateOfBirth = ISO8601DateFormatter().date(from: dobString)
        } else {
            dateOfBirth = nil
        }
        
        return FitIQCore.UserProfile(
            id: profileId,
            email: email ?? "",
            name: name,
            bio: bio,
            username: nil,
            languageCode: language_code,
            dateOfBirth: dateOfBirth,
            biologicalSex: physical?.biological_sex,
            heightCm: physical?.height_cm,
            preferredUnitSystem: preferred_unit_system,
            hasPerformedInitialHealthKitSync: false, // Local only
            lastSuccessfulDailySyncDate: nil, // Local only
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}
```

**Update Repository:**
```swift
final class UserProfileAPIClient: UserProfileRepositoryProtocol {
    // ... existing setup ...
    
    func getUserProfile(userId: String) async throws -> FitIQCore.UserProfile {
        let endpoint = "\(baseURL)/users/me"
        let request = NetworkRequest(endpoint: endpoint, method: .get)
        
        let response: ProfileMetadataResponseDTO = try await networkClient.request(request)
        
        // Fetch physical profile (optional)
        let physical = try? await getPhysicalProfile(userId: userId)
        
        // Get email from AuthManager (stored from JWT)
        let email = authManager.currentEmail
        
        guard let profile = response.toDomain(physical: physical, email: email) else {
            throw APIError.invalidResponse("Failed to parse profile data")
        }
        
        return profile
    }
    
    func updateProfileMetadata(
        userId: String,
        name: String?,
        bio: String?,
        languageCode: String?
    ) async throws -> FitIQCore.UserProfile {
        // ... API call ...
        let response: ProfileMetadataResponseDTO = try await networkClient.request(request)
        
        let physical = try? await getPhysicalProfile(userId: userId)
        let email = authManager.currentEmail
        
        guard let profile = response.toDomain(physical: physical, email: email) else {
            throw APIError.invalidResponse("Failed to parse profile data")
        }
        
        return profile
    }
    
    func updatePhysicalProfile(
        userId: String,
        biologicalSex: String?,
        heightCm: Double?
    ) async throws -> FitIQCore.UserProfile {
        // ... API call ...
        let physicalResponse: PhysicalProfileResponseDTO = try await networkClient.request(request)
        
        // Re-fetch metadata to construct full profile
        let metadataResponse: ProfileMetadataResponseDTO = try await networkClient.request(metadataRequest)
        let email = authManager.currentEmail
        
        guard let profile = metadataResponse.toDomain(physical: physicalResponse, email: email) else {
            throw APIError.invalidResponse("Failed to parse profile data")
        }
        
        return profile
    }
}
```

---

### Step 4: Update Use Cases ⏳ PENDING

**Priority Order:**
1. `GetUserProfileUseCase` - Read-only, simplest
2. `LoginUserUseCase` - Critical path
3. `RegisterUserUseCase` - Critical path
4. `UpdateProfileMetadataUseCase` - Update operations
5. `UpdatePhysicalProfileUseCase` - Update operations
6. `ForceHealthKitResyncUseCase` - Sync state updates

**Example: GetUserProfileUseCase**
```swift
public final class GetUserProfileUseCase: GetUserProfileUseCaseProtocol {
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager
    
    init(userProfileStorage: UserProfileStoragePortProtocol, authManager: AuthManager) {
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager
    }
    
    public func execute(forUserID userID: UUID) async throws -> FitIQCore.UserProfile? {
        guard userID == authManager.currentUserProfileID else {
            throw ProfileError.unauthorized
        }
        
        return try await userProfileStorage.fetch(forUserID: userID)
    }
    
    public func executeForCurrentUser() async throws -> FitIQCore.UserProfile? {
        guard let currentUserID = authManager.currentUserProfileID else {
            return nil
        }
        
        return try await execute(forUserID: currentUserID)
    }
}
```

**Example: UpdateProfileMetadataUseCase**
```swift
final class UpdateProfileMetadataUseCaseImpl: UpdateProfileMetadataUseCase {
    private let userProfileRepository: UserProfileRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManager
    
    func execute(
        userId: String,
        name: String?,
        bio: String?,
        languageCode: String?
    ) async throws -> FitIQCore.UserProfile {
        // Update on backend
        let updatedProfile = try await userProfileRepository.updateProfileMetadata(
            userId: userId,
            name: name,
            bio: bio,
            languageCode: languageCode
        )
        
        // Save locally
        try await userProfileStorage.save(userProfile: updatedProfile)
        
        return updatedProfile
    }
}
```

**Example: ForceHealthKitResyncUseCase**
```swift
final class ForceHealthKitResyncUseCaseImpl: ForceHealthKitResyncUseCase {
    // ... dependencies ...
    
    func execute(clearExisting: Bool) async throws {
        guard let userID = authManager.currentUserProfileID else {
            throw ResyncError.notAuthenticated
        }
        
        guard var userProfile = try await userProfileStorage.fetch(forUserID: userID) else {
            throw ResyncError.profileNotFound
        }
        
        // Reset sync flag using FitIQCore method
        userProfile = userProfile.updatingHealthKitSync(
            hasPerformedInitialSync: false,
            lastSyncDate: nil
        )
        
        try await userProfileStorage.save(userProfile: userProfile)
        
        // ... rest of resync logic ...
        
        // Update sync flag on success
        userProfile = userProfile.updatingHealthKitSync(
            hasPerformedInitialSync: true,
            lastSyncDate: Date()
        )
        
        try await userProfileStorage.save(userProfile: userProfile)
    }
}
```

---

### Step 5: Update ViewModels ⏳ PENDING

**Example: ProfileViewModel**
```swift
import SwiftUI
import Observation
import FitIQCore

@Observable
final class ProfileViewModel {
    // MARK: - State
    var userProfile: FitIQCore.UserProfile?
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    private let getUserProfileUseCase: GetUserProfileUseCaseProtocol
    private let updateProfileMetadataUseCase: UpdateProfileMetadataUseCase
    private let updatePhysicalProfileUseCase: UpdatePhysicalProfileUseCase
    
    // MARK: - Computed Properties
    var displayName: String {
        userProfile?.name ?? "User"
    }
    
    var initials: String {
        userProfile?.initials ?? "?"
    }
    
    var age: Int? {
        userProfile?.age
    }
    
    // MARK: - Actions
    @MainActor
    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            userProfile = try await getUserProfileUseCase.executeForCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func updateBasicInfo(name: String, bio: String?) async {
        guard let profile = userProfile else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            userProfile = try await updateProfileMetadataUseCase.execute(
                userId: profile.id.uuidString,
                name: name,
                bio: bio,
                languageCode: profile.languageCode
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func updatePhysical(biologicalSex: String?, heightCm: Double?) async {
        guard let profile = userProfile else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            userProfile = try await updatePhysicalProfileUseCase.execute(
                userId: profile.id.uuidString,
                biologicalSex: biologicalSex,
                heightCm: heightCm
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

---

### Step 6: Delete Old Models ⏳ PENDING

**After all migrations are complete and tests pass:**

1. **Delete Files:**
   - `FitIQ/Domain/Entities/Profile/UserProfile.swift`
   - `FitIQ/Domain/Entities/Profile/UserProfileMetadata.swift`
   - `FitIQ/Domain/Entities/Profile/PhysicalProfile.swift`
   - `FitIQ/Domain/UseCases/GetPhysicalProfileUseCase.swift`

2. **Update Imports:**
   - Search for `import Domain` or local profile imports
   - Replace with `import FitIQCore` where needed

3. **Clean Build:**
   - Product → Clean Build Folder
   - Build and verify no compilation errors

---

## ✅ Testing Strategy

### Unit Tests

**Repositories:**
- [ ] Test `SwiftDataUserProfileAdapter.save()` - Insert new profile
- [ ] Test `SwiftDataUserProfileAdapter.save()` - Update existing profile
- [ ] Test `SwiftDataUserProfileAdapter.fetch()` - Retrieve profile
- [ ] Test `SwiftDataUserProfileAdapter.delete()` - Remove profile
- [ ] Test fetch-or-create pattern (no duplicates)

**Use Cases:**
- [ ] Test `GetUserProfileUseCase.execute()` - Fetch profile
- [ ] Test `UpdateProfileMetadataUseCase.execute()` - Update metadata
- [ ] Test `UpdatePhysicalProfileUseCase.execute()` - Update physical
- [ ] Test `ForceHealthKitResyncUseCase.execute()` - Sync state updates
- [ ] Test `LoginUserUseCase.execute()` - Profile comparison logic
- [ ] Test `RegisterUserUseCase.execute()` - Profile creation

**Network Clients:**
- [ ] Test DTO → FitIQCore.UserProfile mapping
- [ ] Test date parsing (ISO8601 format)
- [ ] Test error handling for invalid responses

### Integration Tests

- [ ] Test full login flow (auth → profile fetch → local save)
- [ ] Test profile update flow (update → backend → local sync)
- [ ] Test HealthKit sync state management
- [ ] Test profile data persistence across app launches

### Manual QA

**Critical Paths:**
- [ ] Register new account → Profile created correctly
- [ ] Login existing account → Profile loads from backend
- [ ] Edit profile → Changes persist to backend and locally
- [ ] Update physical attributes → Physical data syncs correctly
- [ ] Perform HealthKit sync → Sync flags update correctly
- [ ] Logout → Profile clears from local storage
- [ ] Login again → Profile reloads from backend

**Edge Cases:**
- [ ] Network error during profile fetch → Graceful error handling
- [ ] Partial profile data (missing physical) → App doesn't crash
- [ ] Concurrent profile updates → Last write wins (updatedAt timestamp)
- [ ] App restart during profile save → Data consistency maintained

---

## 🚨 Risk Mitigation

### Risk 1: Data Loss During Migration
**Probability:** Low  
**Impact:** High  

**Mitigation:**
- Use fetch-or-create pattern to prevent duplicates
- Test locally before backend changes
- Add extensive logging for debugging
- Keep backup of old models until fully validated

### Risk 2: SwiftData Schema Mismatch
**Probability:** Medium  
**Impact:** Medium  

**Mitigation:**
- `SDUserProfile` schema remains unchanged
- Only mapping logic changes (domain ↔️ persistence)
- No schema migration required

### Risk 3: Breaking Changes in Use Cases
**Probability:** Medium  
**Impact:** High  

**Mitigation:**
- Update use cases one at a time
- Test each use case independently
- Keep old use cases until new ones are validated
- Run full regression test suite

### Risk 4: ViewModel Compilation Errors
**Probability:** Low  
**Impact:** Medium  

**Mitigation:**
- FitIQCore.UserProfile has similar API to old model
- Update methods have equivalent names
- Computed properties match (name, age, initials, etc.)
- Gradual rollout (ViewModel by ViewModel)

---

## 📈 Success Criteria

### Must Have (P0)
- [ ] All compilation errors resolved
- [ ] All unit tests passing
- [ ] Login/Register flows working
- [ ] Profile CRUD operations working
- [ ] HealthKit sync state managed correctly
- [ ] No data loss or corruption
- [ ] Old profile models deleted

### Should Have (P1)
- [ ] Integration tests passing
- [ ] Manual QA complete
- [ ] TestFlight build deployed
- [ ] Documentation updated

### Nice to Have (P2)
- [ ] Performance benchmarks (same or better)
- [ ] Code coverage maintained or improved
- [ ] Refactoring opportunities identified

---

## 📅 Timeline

| Task | Duration | Dependencies | Status |
|------|----------|--------------|--------|
| Update Domain Ports | 0.5 day | None | ✅ Ready |
| Update SwiftData Repository | 1 day | Ports | 🔄 Next |
| Update Network Clients | 1 day | Repository | ⏳ Pending |
| Update Use Cases (Critical) | 1 day | Network | ⏳ Pending |
| Update Use Cases (Others) | 0.5 day | Critical Use Cases | ⏳ Pending |
| Update ViewModels | 1 day | Use Cases | ⏳ Pending |
| Delete Old Models | 0.5 day | ViewModels | ⏳ Pending |
| Testing & QA | 1 day | All migrations | ⏳ Pending |

**Total Estimated Time:** 6-7 days

---

## 🔄 Rollback Plan

If critical issues arise:

1. **Immediate Rollback:**
   - Revert all commits from this migration
   - Re-deploy previous stable version
   - Document issues encountered

2. **Partial Rollback:**
   - Keep FitIQCore.UserProfile
   - Add adapter layer for backward compatibility
   - Gradually re-migrate with fixes

3. **Data Recovery:**
   - `SDUserProfile` schema unchanged → No data loss
   - Old profile entities can be restored from git
   - Backend profile data remains unchanged

---

## 📝 Notes

- **Backward Compatibility:** FitIQCore.UserProfile is designed to be a superset of FitIQ's old model
- **No Backend Changes:** This is purely an iOS client-side migration
- **Lume Alignment:** Lume already uses FitIQCore.UserProfile (simpler, since it has less data)
- **Future-Proofing:** Sets foundation for Phase 2.2 (HealthKit extraction)

---

## 📚 Related Documents

- [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) - Overall Phase 2 status
- [FITIQCORE_PHASE1_COMPLETE.md](./FITIQCORE_PHASE1_COMPLETE.md) - Phase 1 summary
- [FITIQ_INTEGRATION_GUIDE.md](./FITIQ_INTEGRATION_GUIDE.md) - FitIQCore integration patterns
- [copilot-instructions.md](../../.github/copilot-instructions.md) - Architecture guidelines

---

**Status:** 🚧 Ready to Begin Step 2 (SwiftData Repository)  
**Next Action:** Update `SwiftDataUserProfileAdapter.swift` to use `FitIQCore.UserProfile`
