# 405 Error - Physical Profile GET Endpoint Fix

## Issue Summary

**Problem:** App was getting **405 Method Not Allowed** errors when trying to fetch physical profile.

```
PhysicalProfileAPIClient: Fetching physical profile from /api/v1/users/me/physical
PhysicalProfileAPIClient: Response status code: 405
PhysicalProfileAPIClient: Failed to fetch physical profile. Status: 405
GetPhysicalProfileUseCase: Failed to fetch physical profile: apiError(statusCode: 405, message: "Failed to fetch physical profile")
```

**Root Cause:** The app was trying to **GET** from `/api/v1/users/me/physical`, but this endpoint **only supports PATCH** (update), not GET (fetch).

## API Endpoint Analysis

### Backend API (from swagger.yaml)

```yaml
/api/v1/users/me/physical:
  patch:  # ✅ ONLY PATCH SUPPORTED
    tags: [Profile]
    summary: Update physical profile attributes
    description: Update biological sex and height for the current user's profile
    # ... (NO GET METHOD EXISTS)
```

### What the App Was Doing (WRONG)

```swift
// ❌ WRONG - Trying to GET from endpoint that only supports PATCH
func getPhysicalProfile(userId: String) async throws -> PhysicalProfile {
    let url = "\(baseURL)/api/v1/users/me/physical"
    request.httpMethod = "GET"  // ❌ 405 ERROR!
    // ...
}
```

### Backend API Summary

| Endpoint | Supported Methods | Purpose |
|----------|------------------|---------|
| `/api/v1/users/me` | **GET**, PUT | Fetch/update full user profile (includes physical data) |
| `/api/v1/users/me/physical` | **PATCH only** | Update physical attributes only (NO GET) |

## Architectural Fix (Local-First)

Following the app's **local-first architecture** principle:

**"Local storage is the source of truth"**

Instead of fetching from backend, we read from local storage:

```
User needs physical profile
    ↓
GetPhysicalProfileUseCase.execute()
    ↓
Read from SwiftData (local storage)
    ↓
Return immediately (no network call)
```

Benefits:
- ✅ **No 405 error** (not calling backend GET)
- ✅ **Works offline**
- ✅ **Instant response** (no network latency)
- ✅ **Consistent with architecture** (local as source of truth)

## Technical Details

### Before the Fix

#### GetPhysicalProfileUseCase (WRONG - Backend-First)

```swift
protocol GetPhysicalProfileUseCase {
    func execute(userId: String) async throws -> PhysicalProfile
}

final class GetPhysicalProfileUseCaseImpl: GetPhysicalProfileUseCase {
    private let repository: PhysicalProfileRepositoryProtocol  // ❌ Backend repo
    
    func execute(userId: String) async throws -> PhysicalProfile {
        // ❌ Tries to GET from backend (405 error)
        let profile = try await repository.getPhysicalProfile(userId: userId)
        return profile
    }
}
```

#### PhysicalProfileAPIClient (WRONG - GET request)

```swift
func getPhysicalProfile(userId: String) async throws -> PhysicalProfile {
    let url = URL(string: "\(baseURL)/api/v1/users/me/physical")
    request.httpMethod = "GET"  // ❌ 405 ERROR - Method not allowed!
    
    let (data, httpResponse) = try await networkClient.executeRequest(request)
    // Backend returns 405 because GET is not supported
}
```

### After the Fix

#### GetPhysicalProfileUseCase (CORRECT - Local-First)

```swift
protocol GetPhysicalProfileUseCase {
    /// Fetches from LOCAL STORAGE (source of truth)
    func execute(userId: String) async throws -> PhysicalProfile?
}

final class GetPhysicalProfileUseCaseImpl: GetPhysicalProfileUseCase {
    private let userProfileStorage: UserProfileStoragePortProtocol  // ✅ Local storage
    
    func execute(userId: String) async throws -> PhysicalProfile? {
        // ✅ Reads from local storage (SwiftData)
        let userUUID = UUID(uuidString: userId)!
        let profile = try await userProfileStorage.fetch(forUserID: userUUID)
        
        // ✅ Returns physical profile (may be nil if not set)
        return profile?.physical
    }
}
```

#### No More PhysicalProfileAPIClient.getPhysicalProfile()

The `getPhysicalProfile()` method is **no longer called** because we read from local storage.

The `PhysicalProfileAPIClient` still has `updatePhysicalProfile()` which uses **PATCH** (correct method).

## Files Modified

### 1. `Domain/UseCases/GetPhysicalProfileUseCase.swift`

**Changes:**
- Changed dependency from `PhysicalProfileRepositoryProtocol` (backend) to `UserProfileStoragePortProtocol` (local)
- Reads from local storage instead of backend
- Returns `PhysicalProfile?` (nullable) instead of throwing if not set
- Updated documentation to reflect local-first architecture

**Key Diffs:**
```swift
// BEFORE
- private let repository: PhysicalProfileRepositoryProtocol
- let profile = try await repository.getPhysicalProfile(userId: userId)

// AFTER
+ private let userProfileStorage: UserProfileStoragePortProtocol
+ let profile = try await userProfileStorage.fetch(forUserID: userUUID)
+ return profile?.physical  // May be nil
```

### 2. `Infrastructure/Configuration/AppDependencies.swift`

**Changes:**
- Updated `GetPhysicalProfileUseCaseImpl` initialization to use local storage

**Key Diff:**
```swift
// BEFORE
let getPhysicalProfileUseCase = GetPhysicalProfileUseCaseImpl(
-    repository: physicalProfileRepository
)

// AFTER
let getPhysicalProfileUseCase = GetPhysicalProfileUseCaseImpl(
+    userProfileStorage: userProfileStorageAdapter
)
```

## What About Backend Sync?

**Q:** How does the physical profile get synced to the backend?

**A:** Asynchronously via the **ProfileSyncService**:

1. User updates physical profile
2. `UpdatePhysicalProfileUseCase` saves to local storage
3. Publishes `ProfileEvent.physicalProfileUpdated` event
4. `ProfileSyncService` listens to event
5. Queues **PATCH `/api/v1/users/me/physical`** for background sync
6. Sync happens asynchronously when network available

**Q:** What if I need to fetch fresh data from backend?

**A:** Use **GET `/api/v1/users/me`** which returns the full user profile (including physical data):

```swift
// ✅ CORRECT - Use full profile endpoint
let url = "\(baseURL)/api/v1/users/me"
request.httpMethod = "GET"  // ✅ Supported!

// Response includes physical data:
// {
//   "data": {
//     "id": "...",
//     "name": "...",
//     "biological_sex": "male",    // ✅ Physical data included
//     "height_cm": 180.5,           // ✅ Physical data included
//     "date_of_birth": "1983-07-20" // ✅ Physical data included
//   }
// }
```

But per local-first architecture, this should only be used for **periodic sync/enrichment**, not for regular reads.

## Error Resolution

### Before Fix
```
❌ 405 Method Not Allowed
GET /api/v1/users/me/physical
```

### After Fix
```
✅ No network call made
Read from local SwiftData storage
Instant response, works offline
```

## Benefits Summary

| Aspect | Before (Backend GET) | After (Local Storage) |
|--------|-------------------|---------------------|
| **Network Call** | ❌ GET request to backend | ✅ None (local read) |
| **405 Error** | ❌ Always fails | ✅ Not possible |
| **Offline Support** | ❌ Requires network | ✅ Works fully offline |
| **Speed** | ❌ Slow (network latency) | ✅ Instant |
| **Architecture** | ❌ Backend-first | ✅ Local-first |
| **Backend Sync** | ❌ Synchronous | ✅ Async background |

## Testing Recommendations

### Manual Testing

1. **Offline Read:**
   - Turn off network
   - Navigate to profile screen
   - Physical profile data should display (no error)

2. **Profile Edit Flow:**
   - Edit physical profile
   - Save changes
   - Close and reopen app
   - Changes should persist (read from local storage)

3. **No 405 Errors:**
   - Check logs - should see NO requests to `/api/v1/users/me/physical` GET
   - Only PATCH requests for updates (async sync)

### Unit Tests (Recommended)

```swift
func testGetPhysicalProfile_ReadsFromLocalStorage() async throws {
    // Arrange
    let mockStorage = MockUserProfileStorage()
    let useCase = GetPhysicalProfileUseCaseImpl(
        userProfileStorage: mockStorage
    )
    
    // Mock local profile with physical data
    let physicalProfile = PhysicalProfile(
        biologicalSex: "male",
        heightCm: 180,
        dateOfBirth: Date()
    )
    mockStorage.mockProfile = UserProfile(...)
    
    // Act
    let result = try await useCase.execute(userId: "123")
    
    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.biologicalSex, "male")
    XCTAssertEqual(mockStorage.fetchCallCount, 1)
}

func testGetPhysicalProfile_WorksOffline() async throws {
    // Should not make any network calls
    let useCase = GetPhysicalProfileUseCaseImpl(
        userProfileStorage: mockStorage
    )
    
    // No network client injected
    let result = try await useCase.execute(userId: "123")
    
    // Should still work
    XCTAssertNotNil(result)
}
```

## Related Issues

- **Profile Save/Edit:** Now consistent - both metadata and physical use local-first
- **Offline Mode:** Fully supported for profile reads
- **Backend API Design:** Clarified that `/users/me/physical` is PATCH-only
- **Architecture Alignment:** All profile operations now follow local-first principle

## Backend API Clarification

For future reference, here are the correct endpoints for profile operations:

### Fetch Profile (Full)
```http
GET /api/v1/users/me
Authorization: Bearer <token>
X-API-Key: <key>

# Response includes ALL profile data (metadata + physical)
{
  "data": {
    "id": "...",
    "name": "...",
    "email": "...",
    "biological_sex": "male",     # Physical data
    "height_cm": 180.5,            # Physical data
    "date_of_birth": "1983-07-20", # Physical data
    "preferred_unit_system": "metric",
    "language_code": "en"
  }
}
```

### Update Profile Metadata
```http
PUT /api/v1/users/me
Content-Type: application/json

{
  "name": "New Name",
  "bio": "Updated bio",
  "preferred_unit_system": "imperial"
}
```

### Update Physical Profile
```http
PATCH /api/v1/users/me/physical
Content-Type: application/json

{
  "biological_sex": "male",
  "height_cm": 180.5,
  "date_of_birth": "1983-07-20"
}
```

**Note:** `/api/v1/users/me/physical` does **NOT** support GET. Use `/api/v1/users/me` to fetch physical data.

## References

- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Local-First Architecture:** `docs/fixes/PROFILE_SAVE_LOCAL_FIRST_ARCHITECTURE.md`
- **Hexagonal Architecture:** Domain layer defines ports, infrastructure implements adapters
- **Backend API Docs:** https://fit-iq-backend.fly.dev/swagger/index.html

---

**Status:** ✅ Fixed  
**Date:** 2025-01-27  
**Error:** 405 Method Not Allowed  
**Solution:** Read from local storage instead of GET request to backend  
**Architecture:** Local-First (Local Storage as Source of Truth)
