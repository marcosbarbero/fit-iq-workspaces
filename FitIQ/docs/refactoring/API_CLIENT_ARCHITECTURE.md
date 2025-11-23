# API Client Architecture - Separation of Concerns

**Version:** 1.0.0  
**Date:** 2025-01-27  
**Status:** ✅ Complete

---

## 🎯 Overview

This document describes the API client architecture refactoring that splits large client classes into focused, single-responsibility components.

### Motivation

Previously, API clients were growing too large and handling too many responsibilities. This refactoring splits them by **API endpoint patterns** to:

1. ✅ Maintain Single Responsibility Principle
2. ✅ Make clients easier to maintain and test
3. ✅ Prepare for future feature additions
4. ✅ Improve code readability and navigation

---

## 📊 Client Architecture

```
┌─────────────────────────────┐
│  UserAuthAPIClient          │ → Authentication Only
│  /auth/*                    │
├─────────────────────────────┤
│  - register()               │   POST /auth/register
│  - login()                  │   POST /auth/login
│  - refreshAccessToken()     │   POST /auth/refresh
│  - JWT token parsing        │
└─────────────────────────────┘

┌─────────────────────────────┐
│  UserProfileMetadataClient  │ → Profile Metadata
│  /api/v1/users/me           │
├─────────────────────────────┤
│  - createProfile()          │   POST /api/v1/users/me
│  - getProfile()             │   GET /api/v1/users/me
│  - updateMetadata()         │   PUT /api/v1/users/me
└─────────────────────────────┘

┌─────────────────────────────┐
│  PhysicalProfileAPIClient   │ → Physical Attributes
│  /api/v1/users/me/physical  │
├─────────────────────────────┤
│  - getPhysicalProfile()     │   GET /api/v1/users/me/physical
│  - updatePhysicalProfile()  │   PATCH /api/v1/users/me/physical
└─────────────────────────────┘
```

---

## 🗂️ Client Responsibilities

### 1. UserAuthAPIClient

**File:** `FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`

**Purpose:** Handles all authentication-related operations

**Endpoints:**
- `POST /auth/register` - Create new user account
- `POST /auth/login` - Authenticate user
- `POST /auth/refresh` - Refresh access token
- JWT token parsing and validation

**Methods:**
```swift
func register(userData: RegisterUserData) async throws -> (UserProfile, String, String)
func login(credentials: LoginCredentials) async throws -> (UserProfile, String, String)
func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse
func decodeUserIdFromJWT(_ token: String) -> String?
func extractEmailFromJWT(_ token: String) -> String?
```

**Key Points:**
- ✅ Does NOT handle profile CRUD operations
- ✅ Returns tokens and basic user info only
- ✅ Registration creates auth user, not profile
- ✅ JWT token utilities for parsing

---

### 2. UserProfileMetadataClient (NEW!)

**File:** `FitIQ/Infrastructure/Network/UserProfileMetadataClient.swift`

**Purpose:** Handles user profile metadata (name, bio, preferences)

**Endpoints:**
- `POST /api/v1/users/me` - Create profile on backend
- `GET /api/v1/users/me` - Fetch profile metadata
- `PUT /api/v1/users/me` - Update profile metadata

**Methods:**
```swift
func createProfile(
    userId: String,
    name: String,
    bio: String?,
    preferredUnitSystem: String,
    languageCode: String?,
    dateOfBirth: Date?
) async throws -> UserProfile

func getProfile(userId: String) async throws -> UserProfile

func updateMetadata(
    userId: String,
    name: String,
    bio: String?,
    preferredUnitSystem: String,
    languageCode: String?
) async throws -> UserProfile
```

**Key Points:**
- ✅ Focused on profile metadata only
- ✅ Handles profile creation (critical for registration flow)
- ✅ Separate from authentication concerns
- ✅ Comprehensive debug logging

**When to Use:**
- After registration → `createProfile()` to create backend profile
- Profile load → `getProfile()` to fetch latest metadata
- Profile edit → `updateMetadata()` to update name/bio/preferences

---

### 3. PhysicalProfileAPIClient

**File:** `FitIQ/Infrastructure/Network/PhysicalProfileAPIClient.swift`

**Purpose:** Handles physical health attributes

**Endpoints:**
- `GET /api/v1/users/me/physical` - Fetch physical profile
- `PATCH /api/v1/users/me/physical` - Update physical attributes

**Methods:**
```swift
func getPhysicalProfile(userId: String) async throws -> PhysicalProfile

func updatePhysicalProfile(
    userId: String,
    biologicalSex: String?,
    heightCm: Double?,
    dateOfBirth: Date?
) async throws -> PhysicalProfile
```

**Key Points:**
- ✅ Focused on physical attributes only
- ✅ Separate from profile metadata
- ✅ Health-specific data (height, sex, DOB)
- ✅ Uses PATCH (partial updates)

**When to Use:**
- Profile load → `getPhysicalProfile()` to get physical data
- Profile edit → `updatePhysicalProfile()` to update physical attributes

---

## 🔄 Data Flow Examples

### Registration Flow

```
User Registers
    ↓
UserAuthAPIClient.register()
    ↓ Creates auth user
Access Token Saved
    ↓
UserProfileMetadataClient.createProfile() ⭐ NEW!
    ↓ Creates profile on backend
Profile Saved Locally
    ↓
Auto-authenticate
```

### Profile Edit Flow

```
User Edits Profile
    ↓
1. UserProfileMetadataClient.updateMetadata()
   (name, bio, preferences)
    ↓
2. PhysicalProfileAPIClient.updatePhysicalProfile()
   (height, sex, DOB)
    ↓
Both Save to Local Storage
    ↓
Profile Updated ✅
```

### Profile Load Flow

```
App Loads Profile
    ↓
1. UserProfileMetadataClient.getProfile()
   (metadata from backend)
    ↓
2. PhysicalProfileAPIClient.getPhysicalProfile()
   (physical data from backend)
    ↓
Merge with Local Data
    ↓
Display in UI
```

---

## 🏗️ Architecture Benefits

### 1. Single Responsibility Principle

Each client handles ONE domain:
- **Auth** → Authentication operations
- **Profile Metadata** → Profile information
- **Physical Profile** → Health attributes

### 2. Easy to Maintain

Changes to one area don't affect others:
- Add new auth method → Only touch `UserAuthAPIClient`
- Add profile field → Only touch `UserProfileMetadataClient`
- Add health metric → Only touch `PhysicalProfileAPIClient`

### 3. Testable

Each client can be tested independently:
- Mock network responses for each endpoint
- Test error handling per client
- Isolated unit tests

### 4. Scalable

Easy to add new clients:
- `UserPreferencesClient` - Settings/preferences
- `UserActivityClient` - Activity/workout data
- `UserNutritionClient` - Food/meal tracking

---

## 📋 Migration Guide

### Before (Old Code)

```swift
// Registration was calling UserProfileAPIClient
if let apiClient = userProfileRepository as? UserProfileAPIClient {
    try await apiClient.createProfile(...)
}
```

### After (New Code)

```swift
// Now uses dedicated client
let profile = try await profileMetadataClient.createProfile(
    userId: userId,
    name: name,
    bio: bio,
    preferredUnitSystem: preferredUnitSystem,
    languageCode: languageCode,
    dateOfBirth: dateOfBirth
)
```

---

## 🔧 Implementation Details

### AppDependencies Integration

```swift
class AppDependencies {
    // NEW: Profile Metadata Client
    let profileMetadataClient: UserProfileMetadataClient
    
    static func build(authManager: AuthManager) -> AppDependencies {
        // Create metadata client
        let profileMetadataClient = UserProfileMetadataClient(
            networkClient: networkClient,
            authTokenPersistence: keychainAuthTokenAdapter,
            userProfileStorage: userProfileStorageAdapter
        )
        
        // Use in registration
        let registerUserUseCase = CreateUserUseCase(
            authRepository: authRepository,
            authManager: authManager,
            userProfileStorage: userProfileStorageAdapter,
            authTokenPersistence: keychainAuthTokenAdapter,
            profileMetadataClient: profileMetadataClient  // ⭐ NEW
        )
        
        return AppDependencies(...)
    }
}
```

### Dependency Injection Flow

```
AppDependencies
    ↓ creates
UserProfileMetadataClient
    ↓ injected into
RegisterUserUseCase
    ↓ injected into
RegistrationViewModel
    ↓ used by
RegistrationView
```

---

## 🧪 Testing Strategy

### Unit Tests

Each client should have its own test suite:

```swift
// UserProfileMetadataClientTests.swift
class UserProfileMetadataClientTests: XCTestCase {
    var sut: UserProfileMetadataClient!
    var mockNetworkClient: MockNetworkClient!
    var mockAuthPersistence: MockAuthTokenPersistence!
    var mockStorage: MockUserProfileStorage!
    
    func testCreateProfile_Success() async throws {
        // Given
        mockNetworkClient.stubResponse(statusCode: 201, body: validProfileJSON)
        
        // When
        let profile = try await sut.createProfile(
            userId: "test-id",
            name: "John Doe",
            bio: nil,
            preferredUnitSystem: "metric",
            languageCode: "en",
            dateOfBirth: Date()
        )
        
        // Then
        XCTAssertEqual(profile.name, "John Doe")
        XCTAssertEqual(mockNetworkClient.requestCount, 1)
    }
    
    func testCreateProfile_409Conflict_FetchesExisting() async throws {
        // Given
        mockNetworkClient.stubResponse(statusCode: 409, body: conflictJSON)
        mockNetworkClient.stubResponse(statusCode: 200, body: existingProfileJSON)
        
        // When
        let profile = try await sut.createProfile(...)
        
        // Then
        XCTAssertEqual(mockNetworkClient.requestCount, 2) // POST + GET
    }
}
```

### Integration Tests

Test client interactions:

```swift
func testRegistrationFlow_CreatesProfileOnBackend() async throws {
    // 1. Register user
    let (user, token, _) = try await authClient.register(...)
    
    // 2. Create profile
    let profile = try await metadataClient.createProfile(...)
    
    // 3. Verify profile exists
    let fetchedProfile = try await metadataClient.getProfile(...)
    
    XCTAssertEqual(profile.id, fetchedProfile.id)
}
```

---

## 📖 Best Practices

### 1. Use Correct Client

```swift
// ✅ CORRECT
let profile = try await profileMetadataClient.createProfile(...)

// ❌ WRONG - Don't use auth client for profile operations
let profile = try await authClient.createProfile(...)
```

### 2. Handle Errors Appropriately

```swift
do {
    let profile = try await profileMetadataClient.createProfile(...)
} catch let error as APIError {
    switch error {
    case .unauthorized:
        // Token expired, refresh and retry
    case .apiError(statusCode: 409, _):
        // Profile exists, fetch it
    default:
        // Handle other errors
    }
}
```

### 3. Log Comprehensively

Each client includes comprehensive logging:

```swift
print("UserProfileMetadataClient: ===== CREATE PROFILE =====")
print("UserProfileMetadataClient: Request Body: \(body)")
print("UserProfileMetadataClient: Response (\(statusCode)): \(response)")
print("UserProfileMetadataClient: ✅ Profile created successfully")
```

### 4. Keep Clients Focused

If a client grows > 500 lines, consider splitting further:

```swift
// Future splits if needed:
UserProfileMetadataClient → UserProfileBasicClient + UserProfilePreferencesClient
PhysicalProfileAPIClient → PhysicalAttributesClient + HealthMetricsClient
```

---

## 🎯 Success Criteria

- ✅ Each client has < 500 lines of code
- ✅ Single Responsibility Principle maintained
- ✅ Clear separation by API endpoint pattern
- ✅ Comprehensive debug logging
- ✅ Proper error handling
- ✅ Easy to test independently
- ✅ Easy to extend with new features

---

## 🔮 Future Enhancements

### Planned Clients

1. **UserNutritionClient** - `/api/v1/nutrition/*`
   - Food tracking
   - Meal logging
   - Macronutrient analysis

2. **UserActivityClient** - `/api/v1/activity/*`
   - Workout tracking
   - Exercise logging
   - Activity analysis

3. **UserGoalsClient** - `/api/v1/goals/*`
   - Goal setting
   - Progress tracking
   - Achievements

4. **UserPreferencesClient** - `/api/v1/preferences/*`
   - App settings
   - Notification preferences
   - Privacy settings

---

## 📊 Comparison: Before vs After

### Before

```
UserAuthAPIClient (615 lines)
├── Authentication ✅
├── Profile CRUD ❌ (wrong place)
└── Token management ✅

UserProfileAPIClient (510 lines)
├── Profile operations ✅
├── Physical profile ❌ (mixed concerns)
└── Network utilities ✅
```

**Problems:**
- ❌ Mixed concerns (auth + profile)
- ❌ Large files (> 500 lines)
- ❌ Difficult to maintain
- ❌ Hard to test

### After

```
UserAuthAPIClient (~400 lines)
└── Authentication ONLY ✅

UserProfileMetadataClient (~390 lines)
└── Profile Metadata ONLY ✅

PhysicalProfileAPIClient (~250 lines)
└── Physical Attributes ONLY ✅
```

**Benefits:**
- ✅ Clear separation of concerns
- ✅ Smaller, focused files
- ✅ Easy to maintain
- ✅ Easy to test
- ✅ Ready for future growth

---

## ✅ Checklist for New Clients

When creating a new API client:

- [ ] Name follows pattern: `[Domain][Purpose]Client`
- [ ] File location: `Infrastructure/Network/`
- [ ] Handles single API endpoint pattern
- [ ] < 500 lines of code
- [ ] Comprehensive debug logging
- [ ] Proper error handling
- [ ] Returns domain models (not DTOs)
- [ ] Injected via AppDependencies
- [ ] Unit tests created
- [ ] Documentation updated

---

**This architecture ensures clean separation of concerns, maintainability, and scalability as the app grows.**

---

**Status:** ✅ Implementation Complete  
**Impact:** 🟢 Low Risk - Improved Architecture  
**Next Steps:** Continue pattern for future API clients