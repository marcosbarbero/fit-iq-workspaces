# 🔄 FitIQ iOS Profile Refactoring Plan

**Date:** 2025-01-27  
**Version:** 1.0.0  
**Status:** 📋 Planning Phase  
**Priority:** 🔴 Critical - Backend API Alignment

---

## 📋 Executive Summary

The current iOS app's profile structure is fundamentally misaligned with the backend API. This document outlines a complete refactoring plan to separate concerns properly and align with the backend's architecture.

### Current Problems

❌ **Single Monolithic Model:** `UserProfile` combines profile metadata, physical attributes, and auth data  
❌ **Wrong Fields:** App uses fields that don't exist in backend (`username`, `weight`, `activityLevel`)  
❌ **Missing Fields:** App is missing backend fields (`bio`, `language_code`)  
❌ **Wrong Endpoints:** Physical attributes mixed with profile metadata  
❌ **DTO Mismatch:** DTOs don't properly map to domain models

### Target Architecture

✅ **Separated Concerns:** Profile metadata, physical attributes, and auth data separated  
✅ **Correct Fields:** All fields match backend API exactly  
✅ **Proper Endpoints:** `/api/v1/users/me` for profile, `/api/v1/users/me/physical` for physical data  
✅ **Clean DTOs:** Perfect 1:1 mapping between backend and domain  
✅ **Hexagonal Architecture:** Clean separation of domain, infrastructure, and presentation

---

## 🎯 Backend API Structure (Source of Truth)

### 1. Profile Metadata Endpoint

**Endpoint:** `GET/PUT /api/v1/users/me`

**Response Structure:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "user_id": "uuid",
    "name": "John Doe",
    "bio": "Fitness enthusiast",
    "preferred_unit_system": "metric",
    "language_code": "en",
    "date_of_birth": "1990-01-15",
    "created_at": "2025-01-27T10:00:00Z",
    "updated_at": "2025-01-27T10:00:00Z"
  }
}
```

**Update Request:**
```json
{
  "name": "John Doe",                    // REQUIRED
  "preferred_unit_system": "metric",     // REQUIRED
  "bio": "Updated bio",                  // OPTIONAL
  "language_code": "en"                  // OPTIONAL
}
```

### 2. Physical Profile Endpoint

**Endpoint:** `PATCH /api/v1/users/me/physical`

**Response Structure:**
```json
{
  "success": true,
  "data": {
    "biological_sex": "male",
    "height_cm": 180.5,
    "date_of_birth": "1990-01-15"
  }
}
```

**Update Request:**
```json
{
  "biological_sex": "male",    // OPTIONAL: "male", "female", "other"
  "height_cm": 180.5,          // OPTIONAL
  "date_of_birth": "1990-01-15" // OPTIONAL
}
```

### 3. Authentication Endpoints

**Endpoint:** `POST /api/v1/auth/register`, `POST /api/v1/auth/login`

**Response Structure:**
```json
{
  "success": true,
  "data": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token"
  }
}
```

**Note:** Auth endpoints do NOT return profile data. Profile must be fetched separately.

---

## 🏗️ New Domain Model Architecture

### Domain Layer Separation

```
Domain/Entities/
├── Profile/
│   ├── UserProfileMetadata.swift      # NEW: Profile metadata only
│   ├── PhysicalProfile.swift          # NEW: Physical attributes only
│   └── UserProfile.swift              # REFACTORED: Composition of both
└── Auth/
    └── AuthToken.swift                # NEW: Auth token data only
```

### 1. UserProfileMetadata (NEW)

**Purpose:** Profile metadata from `/api/v1/users/me`

```swift
public struct UserProfileMetadata: Identifiable, Equatable {
    public let id: UUID                    // Profile ID
    public let userId: UUID                // User ID (from JWT)
    public let name: String                // Full name (REQUIRED)
    public let bio: String?                // Biography/description
    public let preferredUnitSystem: String // "metric" or "imperial" (REQUIRED)
    public let languageCode: String?       // Language preference (e.g., "en", "pt")
    public let dateOfBirth: Date?          // Date of birth
    public let createdAt: Date             // Profile creation timestamp
    public let updatedAt: Date             // Last update timestamp
    
    public init(
        id: UUID,
        userId: UUID,
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?,
        dateOfBirth: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.bio = bio
        self.preferredUnitSystem = preferredUnitSystem
        self.languageCode = languageCode
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### 2. PhysicalProfile (NEW)

**Purpose:** Physical attributes from `/api/v1/users/me/physical`

```swift
public struct PhysicalProfile: Equatable {
    public let biologicalSex: String?      // "male", "female", "other"
    public let heightCm: Double?           // Height in centimeters
    public let dateOfBirth: Date?          // Date of birth (can differ from profile)
    
    public init(
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) {
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.dateOfBirth = dateOfBirth
    }
}
```

### 3. UserProfile (REFACTORED)

**Purpose:** Composition of profile metadata and physical data

```swift
public struct UserProfile: Identifiable, Equatable {
    // Metadata from /api/v1/users/me
    public let metadata: UserProfileMetadata
    
    // Physical data from /api/v1/users/me/physical
    public let physical: PhysicalProfile?
    
    // Local-only state (not from backend)
    public var hasPerformedInitialHealthKitSync: Bool
    public var lastSuccessfulDailySyncDate: Date?
    
    // Computed properties for convenience
    public var id: UUID { metadata.id }
    public var userId: UUID { metadata.userId }
    public var name: String { metadata.name }
    public var preferredUnitSystem: String { metadata.preferredUnitSystem }
    public var dateOfBirth: Date? { 
        // Prefer physical profile DOB, fallback to metadata DOB
        physical?.dateOfBirth ?? metadata.dateOfBirth 
    }
    
    public init(
        metadata: UserProfileMetadata,
        physical: PhysicalProfile?,
        hasPerformedInitialHealthKitSync: Bool = false,
        lastSuccessfulDailySyncDate: Date? = nil
    ) {
        self.metadata = metadata
        self.physical = physical
        self.hasPerformedInitialHealthKitSync = hasPerformedInitialHealthKitSync
        self.lastSuccessfulDailySyncDate = lastSuccessfulDailySyncDate
    }
}
```

### 4. AuthToken (NEW)

**Purpose:** Authentication tokens (separate from profile)

```swift
public struct AuthToken: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date?
    
    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
```

---

## 📦 Infrastructure Layer Changes

### DTOs (Already Correct)

The current DTOs in `AuthDTOs.swift` are already correctly structured:

✅ `UserProfileResponseDTO` - Maps to `UserProfileMetadata`  
✅ `UserProfileUpdateRequest` - For updating profile metadata  
✅ `PhysicalProfileResponseDTO` - Maps to `PhysicalProfile`  
✅ `PhysicalProfileUpdateRequest` - For updating physical data  
✅ `LoginResponse` - Maps to `AuthToken`

**Action:** Update DTO mapping extensions to use new domain models.

### New API Clients Needed

```
Infrastructure/Network/
├── UserAuthAPIClient.swift           # EXISTS: Auth endpoints
├── UserProfileAPIClient.swift        # EXISTS: Profile endpoints (needs update)
└── PhysicalProfileAPIClient.swift    # NEW: Physical profile endpoints
```

### 1. Update UserProfileAPIClient

**File:** `Infrastructure/Network/UserProfileAPIClient.swift`

**Changes:**
- Remove physical attribute handling
- Focus only on profile metadata
- Return `UserProfileMetadata` instead of `UserProfile`
- Update endpoints to use `/api/v1/users/me` (not `/api/v1/users/{id}`)

```swift
protocol UserProfileRepositoryProtocol {
    func getProfileMetadata() async throws -> UserProfileMetadata
    func updateProfileMetadata(request: UserProfileUpdateRequest) async throws -> UserProfileMetadata
}
```

### 2. Create PhysicalProfileAPIClient (NEW)

**File:** `Infrastructure/Network/PhysicalProfileAPIClient.swift`

**Purpose:** Handle physical profile operations

```swift
protocol PhysicalProfileRepositoryProtocol {
    func getPhysicalProfile() async throws -> PhysicalProfile
    func updatePhysicalProfile(request: PhysicalProfileUpdateRequest) async throws -> PhysicalProfile
}

final class PhysicalProfileAPIClient: PhysicalProfileRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    
    init(networkClient: NetworkClientProtocol, baseURL: String) {
        self.networkClient = networkClient
        self.baseURL = baseURL
    }
    
    func getPhysicalProfile() async throws -> PhysicalProfile {
        // GET /api/v1/users/me/physical
        // Decode PhysicalProfileResponseDTO
        // Map to PhysicalProfile domain model
    }
    
    func updatePhysicalProfile(request: PhysicalProfileUpdateRequest) async throws -> PhysicalProfile {
        // PATCH /api/v1/users/me/physical
        // Encode request
        // Decode PhysicalProfileResponseDTO
        // Map to PhysicalProfile domain model
    }
}
```

---

## 🎯 Use Cases Layer

### New Use Cases Needed

```
Domain/UseCases/
├── Profile/
│   ├── GetUserProfileUseCase.swift       # NEW: Fetch complete profile
│   ├── UpdateProfileMetadataUseCase.swift # REFACTOR: Update metadata only
│   └── UpdatePhysicalProfileUseCase.swift # NEW: Update physical data
└── Auth/
    ├── RegisterUserUseCase.swift         # EXISTS: Update to use new models
    └── LoginUserUseCase.swift            # EXISTS: Update to use new models
```

### 1. GetUserProfileUseCase (NEW)

**Purpose:** Fetch complete profile (metadata + physical)

```swift
protocol GetUserProfileUseCase {
    func execute() async throws -> UserProfile
}

final class GetUserProfileUseCaseImpl: GetUserProfileUseCase {
    private let profileRepository: UserProfileRepositoryProtocol
    private let physicalRepository: PhysicalProfileRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    
    init(
        profileRepository: UserProfileRepositoryProtocol,
        physicalRepository: PhysicalProfileRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol
    ) {
        self.profileRepository = profileRepository
        self.physicalRepository = physicalRepository
        self.userProfileStorage = userProfileStorage
    }
    
    func execute() async throws -> UserProfile {
        // Fetch metadata from /api/v1/users/me
        let metadata = try await profileRepository.getProfileMetadata()
        
        // Fetch physical from /api/v1/users/me/physical
        let physical = try? await physicalRepository.getPhysicalProfile()
        
        // Combine into UserProfile
        let profile = UserProfile(
            metadata: metadata,
            physical: physical
        )
        
        // Save to local storage
        try await userProfileStorage.save(profile)
        
        return profile
    }
}
```

### 2. UpdateProfileMetadataUseCase (REFACTOR)

**Purpose:** Update profile metadata only

```swift
protocol UpdateProfileMetadataUseCase {
    func execute(
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?
    ) async throws -> UserProfileMetadata
}

final class UpdateProfileMetadataUseCaseImpl: UpdateProfileMetadataUseCase {
    private let profileRepository: UserProfileRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    
    init(
        profileRepository: UserProfileRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol
    ) {
        self.profileRepository = profileRepository
        self.userProfileStorage = userProfileStorage
    }
    
    func execute(
        name: String,
        bio: String?,
        preferredUnitSystem: String,
        languageCode: String?
    ) async throws -> UserProfileMetadata {
        // Validate
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
        
        // Create request
        let request = UserProfileUpdateRequest(
            name: name,
            preferredUnitSystem: preferredUnitSystem,
            bio: bio,
            languageCode: languageCode
        )
        
        // Update via API
        let updatedMetadata = try await profileRepository.updateProfileMetadata(request: request)
        
        // Update local storage
        if let currentProfile = try? await userProfileStorage.fetch(forUserID: updatedMetadata.userId) {
            let updatedProfile = UserProfile(
                metadata: updatedMetadata,
                physical: currentProfile.physical,
                hasPerformedInitialHealthKitSync: currentProfile.hasPerformedInitialHealthKitSync,
                lastSuccessfulDailySyncDate: currentProfile.lastSuccessfulDailySyncDate
            )
            try await userProfileStorage.save(updatedProfile)
        }
        
        return updatedMetadata
    }
}
```

### 3. UpdatePhysicalProfileUseCase (NEW)

**Purpose:** Update physical profile only

```swift
protocol UpdatePhysicalProfileUseCase {
    func execute(
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile
}

final class UpdatePhysicalProfileUseCaseImpl: UpdatePhysicalProfileUseCase {
    private let physicalRepository: PhysicalProfileRepositoryProtocol
    private let userProfileStorage: UserProfileStoragePortProtocol
    private let authManager: AuthManagerProtocol
    
    init(
        physicalRepository: PhysicalProfileRepositoryProtocol,
        userProfileStorage: UserProfileStoragePortProtocol,
        authManager: AuthManagerProtocol
    ) {
        self.physicalRepository = physicalRepository
        self.userProfileStorage = userProfileStorage
        self.authManager = authManager
    }
    
    func execute(
        biologicalSex: String?,
        heightCm: Double?,
        dateOfBirth: Date?
    ) async throws -> PhysicalProfile {
        // Create request
        let request = PhysicalProfileUpdateRequest(
            biologicalSex: biologicalSex,
            heightCm: heightCm,
            dateOfBirth: dateOfBirth?.toISO8601DateString()
        )
        
        // Update via API
        let updatedPhysical = try await physicalRepository.updatePhysicalProfile(request: request)
        
        // Update local storage
        guard let userId = authManager.currentUserProfileID else {
            throw AuthError.notAuthenticated
        }
        
        if let currentProfile = try? await userProfileStorage.fetch(forUserID: userId) {
            let updatedProfile = UserProfile(
                metadata: currentProfile.metadata,
                physical: updatedPhysical,
                hasPerformedInitialHealthKitSync: currentProfile.hasPerformedInitialHealthKitSync,
                lastSuccessfulDailySyncDate: currentProfile.lastSuccessfulDailySyncDate
            )
            try await userProfileStorage.save(updatedProfile)
        }
        
        return updatedPhysical
    }
}
```

---

## 🖼️ Presentation Layer Changes

### ProfileViewModel Refactoring

**File:** `Presentation/ViewModels/ProfileViewModel.swift`

**Changes:**

1. **Separate State Variables:**
```swift
// Profile Metadata State
@Published var name: String = ""
@Published var bio: String = ""
@Published var preferredUnitSystem: String = "metric"
@Published var languageCode: String = "en"

// Physical Profile State
@Published var biologicalSex: String = ""
@Published var heightCm: String = ""
@Published var dateOfBirth: Date?

// Combined Profile
@Published var userProfile: UserProfile?
```

2. **Updated Dependencies:**
```swift
init(
    authManager: AuthManager,
    getUserProfileUseCase: GetUserProfileUseCase,
    updateProfileMetadataUseCase: UpdateProfileMetadataUseCase,
    updatePhysicalProfileUseCase: UpdatePhysicalProfileUseCase,
    cloudDataManager: CloudDataManagerProtocol
) {
    // ...
}
```

3. **Separate Save Methods:**
```swift
@MainActor
func saveProfileMetadata() async {
    // Update profile metadata only
    let updatedMetadata = try await updateProfileMetadataUseCase.execute(
        name: name,
        bio: bio,
        preferredUnitSystem: preferredUnitSystem,
        languageCode: languageCode
    )
    // Update local state
}

@MainActor
func savePhysicalProfile() async {
    // Update physical profile only
    let height = Double(heightCm)
    let updatedPhysical = try await updatePhysicalProfileUseCase.execute(
        biologicalSex: biologicalSex,
        heightCm: height,
        dateOfBirth: dateOfBirth
    )
    // Update local state
}

@MainActor
func saveCompleteProfile() async {
    // Save both in sequence
    await saveProfileMetadata()
    await savePhysicalProfile()
}
```

### UI Changes

**File:** `Presentation/UI/Profile/ProfileView.swift`

**Changes:**

1. **Split Edit Form into Sections:**

```swift
Form {
    // SECTION 1: Profile Metadata
    Section("Profile Information") {
        TextField("Full Name", text: $viewModel.name)
        TextField("Bio", text: $viewModel.bio, axis: .vertical)
        
        Picker("Language", selection: $viewModel.languageCode) {
            Text("English").tag("en")
            Text("Portuguese").tag("pt")
        }
        
        Picker("Unit System", selection: $viewModel.preferredUnitSystem) {
            Text("Metric").tag("metric")
            Text("Imperial").tag("imperial")
        }
    }
    
    // SECTION 2: Physical Profile
    Section("Physical Information") {
        Picker("Biological Sex", selection: $viewModel.biologicalSex) {
            Text("Not Specified").tag("")
            Text("Male").tag("male")
            Text("Female").tag("female")
            Text("Other").tag("other")
        }
        
        TextField("Height (cm)", text: $viewModel.heightCm)
            .keyboardType(.decimalPad)
        
        DatePicker("Date of Birth", selection: $viewModel.dateOfBirth, displayedComponents: .date)
    }
    
    // Save Button
    Button("Save Changes") {
        Task {
            await viewModel.saveCompleteProfile()
        }
    }
}
```

---

## 🔄 Migration Strategy

### Phase 1: Create New Domain Models (Week 1, Day 1-2)

**Tasks:**
1. ✅ Create `UserProfileMetadata.swift`
2. ✅ Create `PhysicalProfile.swift`
3. ✅ Create `AuthToken.swift`
4. ✅ Update `UserProfile.swift` to use composition
5. ✅ Update unit tests

**Files to Create:**
- `Domain/Entities/Profile/UserProfileMetadata.swift`
- `Domain/Entities/Profile/PhysicalProfile.swift`
- `Domain/Entities/Auth/AuthToken.swift`

**Files to Update:**
- `Domain/Entities/UserProfile.swift`

### Phase 2: Update DTOs and Mapping (Week 1, Day 3-4)

**Tasks:**
1. ✅ Update `UserProfileResponseDTO.toDomain()` to return `UserProfileMetadata`
2. ✅ Create `PhysicalProfileResponseDTO.toDomain()` to return `PhysicalProfile`
3. ✅ Update `LoginResponse` mapping
4. ✅ Add unit tests for all mappings

**Files to Update:**
- `Infrastructure/Network/DTOs/AuthDTOs.swift`

### Phase 3: Create/Update Repositories (Week 1, Day 5 - Week 2, Day 1)

**Tasks:**
1. ✅ Create `PhysicalProfileAPIClient.swift`
2. ✅ Update `UserProfileAPIClient.swift` to handle metadata only
3. ✅ Update `UserAuthAPIClient.swift` to use new models
4. ✅ Create protocol for `PhysicalProfileRepositoryProtocol`
5. ✅ Update unit tests and mocks

**Files to Create:**
- `Infrastructure/Network/PhysicalProfileAPIClient.swift`
- `Domain/Ports/PhysicalProfileRepositoryProtocol.swift`

**Files to Update:**
- `Infrastructure/Network/UserProfileAPIClient.swift`
- `Infrastructure/Network/UserAuthAPIClient.swift`

### Phase 4: Create/Update Use Cases (Week 2, Day 2-3)

**Tasks:**
1. ✅ Create `GetUserProfileUseCase.swift`
2. ✅ Create `UpdateProfileMetadataUseCase.swift`
3. ✅ Create `UpdatePhysicalProfileUseCase.swift`
4. ✅ Update existing use cases that depend on UserProfile
5. ✅ Add unit tests with mocks

**Files to Create:**
- `Domain/UseCases/Profile/GetUserProfileUseCase.swift`
- `Domain/UseCases/Profile/UpdateProfileMetadataUseCase.swift`
- `Domain/UseCases/Profile/UpdatePhysicalProfileUseCase.swift`

### Phase 5: Update Presentation Layer (Week 2, Day 4-5)

**Tasks:**
1. ✅ Update `ProfileViewModel.swift`
2. ✅ Update `ProfileView.swift` and `EditProfileSheet`
3. ✅ Update `SummaryViewModel.swift` if affected
4. ✅ Test UI with new data flow

**Files to Update:**
- `Presentation/ViewModels/ProfileViewModel.swift`
- `Presentation/UI/Profile/ProfileView.swift`

### Phase 6: Update Dependency Injection (Week 3, Day 1)

**Tasks:**
1. ✅ Register new use cases in `AppDependencies`
2. ✅ Register new repositories
3. ✅ Update ViewModel initialization
4. ✅ Verify all dependencies are correctly wired

**Files to Update:**
- `Infrastructure/Configuration/AppDependencies.swift`
- `Infrastructure/Configuration/ViewModelAppDependencies.swift`

### Phase 7: Data Migration (Week 3, Day 2)

**Tasks:**
1. ✅ Create migration script for local SwiftData storage
2. ✅ Handle existing user profiles gracefully
3. ✅ Test migration with real data
4. ✅ Add fallback mechanisms

**Considerations:**
- Existing users may have local data in old format
- Need to migrate or re-fetch from backend
- Consider forcing a re-login to refresh all data

### Phase 8: Testing & Validation (Week 3, Day 3-5)

**Tasks:**
1. ✅ Unit tests for all new domain models
2. ✅ Integration tests for API clients
3. ✅ UI tests for profile editing flow
4. ✅ Manual testing on device
5. ✅ Verify backend integration end-to-end

---

## ✅ Acceptance Criteria

### Domain Layer
- [ ] `UserProfileMetadata` contains only fields from `/api/v1/users/me`
- [ ] `PhysicalProfile` contains only fields from `/api/v1/users/me/physical`
- [ ] `UserProfile` is composition of metadata + physical
- [ ] No auth data in profile models
- [ ] All domain models have unit tests

### Infrastructure Layer
- [ ] `UserProfileAPIClient` hits `/api/v1/users/me` correctly
- [ ] `PhysicalProfileAPIClient` hits `/api/v1/users/me/physical` correctly
- [ ] DTOs map 1:1 with backend response structure
- [ ] All network clients have integration tests

### Use Cases Layer
- [ ] `GetUserProfileUseCase` fetches and combines metadata + physical
- [ ] `UpdateProfileMetadataUseCase` updates metadata only
- [ ] `UpdatePhysicalProfileUseCase` updates physical only
- [ ] All use cases have unit tests with mocks

### Presentation Layer
- [ ] `ProfileViewModel` separates metadata and physical state
- [ ] Edit form clearly separates sections
- [ ] Save operations call correct use cases
- [ ] UI reflects backend data structure

### Integration
- [ ] Complete profile can be fetched and displayed
- [ ] Metadata can be updated independently
- [ ] Physical data can be updated independently
- [ ] Both can be updated together
- [ ] Error handling works for all scenarios
- [ ] End-to-end tests pass

---

## 🚨 Breaking Changes & Risks

### Breaking Changes

1. **UserProfile Structure Changed**
   - Old: Flat structure with all fields
   - New: Nested structure with metadata + physical
   - **Impact:** All code referencing UserProfile needs updating
   - **Migration:** Use computed properties for backward compatibility

2. **API Client Interfaces Changed**
   - Old: Single client for all profile operations
   - New: Separate clients for metadata and physical
   - **Impact:** Dependency injection needs updating
   - **Migration:** Update AppDependencies registrations

3. **Use Case Signatures Changed**
   - Old: Single update use case with all parameters
   - New: Separate use cases for metadata and physical
   - **Impact:** ViewModels need updating
   - **Migration:** Update ViewModel dependencies

### Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss during migration | Medium | High | Create backup, test thoroughly, add rollback |
| Backend API changes | Low | High | Use API spec as contract, version APIs |
| Regression in existing features | Medium | Medium | Comprehensive testing, feature flags |
| User confusion from UI changes | Low | Low | Clear labeling, gradual rollout |

---

## 📊 Testing Strategy

### Unit Tests

**Domain Models:**
- Test `UserProfileMetadata` initialization and equality
- Test `PhysicalProfile` initialization and equality
- Test `UserProfile` composition and computed properties
- Test edge cases (nil values, empty strings, etc.)

**DTOs:**
- Test `UserProfileResponseDTO.toDomain()` mapping
- Test `PhysicalProfileResponseDTO.toDomain()` mapping
- Test encoding/decoding of request DTOs
- Test error cases (invalid UUIDs, dates, etc.)

**Use Cases:**
- Mock repositories
- Test success paths
- Test error paths
- Test validation logic
- Test state updates

### Integration Tests

**API Clients:**
- Test real network calls (with test backend)
- Test request formatting
- Test response parsing
- Test error handling (404, 401, 500, etc.)

**End-to-End:**
- Full profile fetch and display
- Full profile update (metadata only)
- Full profile update (physical only)
- Full profile update (both)
- Error recovery flows

### UI Tests

- Profile loads correctly
- Edit form displays correct values
- Save triggers correct API calls
- Error messages display correctly
- Loading states work correctly

---

## 📝 Documentation Updates Needed

1. **README.md:** Update architecture diagrams
2. **ARCHITECTURE.md:** Document new domain model structure
3. **API_INTEGRATION.md:** Update endpoint documentation
4. **CHANGELOG.md:** Document breaking changes
5. **MIGRATION_GUIDE.md:** Guide for existing users/data
6. **CODE_COMMENTS:** Update inline documentation

---

## 🎯 Success Metrics

### Code Quality
- [ ] 90%+ unit test coverage on new code
- [ ] Zero compiler warnings
- [ ] SwiftLint passes without errors
- [ ] All diagnostics resolved

### Functionality
- [ ] Profile fetch success rate: 99%+
- [ ] Profile update success rate: 99%+
- [ ] Zero data loss during migration
- [ ] All existing features still work

### Performance
- [ ] Profile fetch < 2 seconds
- [ ] Profile update < 3 seconds
- [ ] UI remains responsive during operations
- [ ] No memory leaks

---

## 📅 Timeline

**Total Estimated Time:** 3 weeks (15 working days)

| Week | Days | Focus | Deliverable |
|------|------|-------|-------------|
| Week 1 | Day 1-2 | Domain Models | New entities created |
| Week 1 | Day 3-4 | DTOs & Mapping | DTOs updated and tested |
| Week 1 | Day 5 - Week 2 Day 1 | Repositories | API clients working |
| Week 2 | Day 2-3 | Use Cases | Business logic implemented |
| Week 2 | Day 4-5 | Presentation | UI updated and working |
| Week 3 | Day 1 | DI | Dependencies wired |
| Week 3 | Day 2 | Migration | Data migration complete |
| Week 3 | Day 3-5 | Testing | All tests passing |

---

## 🚀 Next Steps

### Immediate Actions (This Week)

1. **Review & Approve Plan:** Get team sign-off on refactoring approach
2. **Create Feature Branch:** `feature/profile-refactor-v2`
3. **Start Phase 1:** Create new domain models
4. **Set Up Tests:** Create test suite structure

### Before Starting Development

- [ ] Review backend API spec one more time
- [ ] Set up test backend environment
- [ ] Create backup of current codebase
- [ ] Notify team of upcoming changes
- [ ] Schedule code review sessions

---

## 📞 Questions & Decisions Needed

### Open Questions

1. **Data Migration:** Force re-login vs. migrate local data?
2. **Backward Compatibility:** Support old API during transition?
3. **Feature Flags:** Gradual rollout or all-at-once?
4. **UI Changes:** Keep current design or redesign with sections?

### Technical Decisions

1. **Storage:** Keep SwiftData or switch to separate stores?
2. **Caching:** Cache metadata and physical separately?
3. **Sync:** Fetch both endpoints simultaneously or sequentially?
4. **Error Handling:** Partial success handling (metadata succeeds, physical fails)?

---

## 📚 References

- Backend API Spec: `docs/api-spec.yaml` (symlinked)
- Integration Handoff: `docs/IOS_INTEGRATION_HANDOFF.md`
- Hexagonal Architecture: `.github/copilot-instructions.md`
- Previous Profile Fix: Thread conversation context

---

**Status:** 📋 Ready for Review  
**Next Action:** Team review and approval to begin Phase 1  
**Owner:** TBD  
**Reviewers:** TBD

---

*This document is a living plan and will be updated as the refactoring progresses.*