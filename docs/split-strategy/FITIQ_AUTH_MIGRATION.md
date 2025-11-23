# FitIQ Authentication Migration to FitIQCore

**Status:** In Progress (10% Complete)  
**Created:** 2025-01-27  
**Last Updated:** 2025-01-27  

---

## Overview

This document tracks the migration of FitIQ's authentication system to use FitIQCore's unified, production-ready authentication components.

### Goals

1. **Eliminate Duplication:** Remove ~630 lines of duplicated auth code from FitIQ
2. **Thread-Safe Authentication:** Use FitIQCore's TokenRefreshClient for coordinated token refresh
3. **Automatic Retry:** Replace manual 401 retry logic with NetworkClient+AutoRetry
4. **Production-Ready:** Leverage FitIQCore's tested, robust authentication
5. **Maintainability:** Centralize auth improvements in FitIQCore

---

## Architecture Changes

### Before (Current State)
```
FitIQ API Clients
├── Manual token refresh logic (isRefreshing, refreshTask, refreshLock)
├── Manual 401 retry logic (executeWithRetry)
├── Direct AuthTokenPersistencePortProtocol usage
└── Duplicated refresh coordination across 10+ clients
```

### After (Target State)
```
FitIQ API Clients
├── Import FitIQCore
├── Use TokenRefreshClient for coordinated refresh
├── Use NetworkClient+AutoRetry for automatic 401 handling
└── Simplified, unified authentication
```

---

## Migration Phases

### Phase 1: Foundation ✅ COMPLETE
- [x] Extract AuthToken entity to FitIQCore
- [x] Create TokenRefreshClient in FitIQCore
- [x] Create NetworkClient+AutoRetry in FitIQCore
- [x] Write comprehensive tests (88/88 passing)
- [x] Update FitIQCore documentation

### Phase 2: FitIQ Integration 🚧 IN PROGRESS (30%)
- [x] Delete local AuthToken from FitIQ
- [x] Add `import FitIQCore` to relevant files
- [x] Add TokenRefreshClient to AppDependencies ✅
- [x] Configure FitIQCore package dependency in Xcode project ✅
- [x] Build successfully with FitIQCore integration ✅
- [x] Migrate UserAuthAPIClient (1/10 clients) ✅
- [ ] Migrate remaining API clients to use TokenRefreshClient (9/10 clients)
- [ ] Remove duplicated refresh logic from remaining clients
- [ ] Build and test authentication flows

### Phase 3: Testing & Validation
- [ ] Unit tests for all migrated clients
- [ ] Integration tests for authentication flows
- [ ] Manual testing (login, refresh, logout, 401 handling)
- [ ] Performance testing (concurrent requests)

### Phase 4: Cleanup
- [ ] Remove all manual refresh logic
- [ ] Remove manual retry logic
- [ ] Update documentation
- [ ] Code review and final validation

---

## API Clients Requiring Migration

### High Priority (Active Auth Logic)
1. **UserAuthAPIClient** - Core authentication client ✅
   - ~~Has manual refresh logic~~ **REMOVED**
   - ~~Has executeWithRetry logic~~ **MIGRATED to FitIQCore**
   - Status: ✅ **COMPLETE** (2025-01-27)
   
2. **NutritionAPIClient** - Meal logging
   - Has manual refresh coordination (isRefreshing, refreshTask, refreshLock)
   - Has executeWithRetry logic
   - Status: Not Started
   
3. **PhotoRecognitionAPIClient** - Image analysis
   - Has manual refresh coordination
   - Has executeWithRetry logic
   - Status: Not Started
   
4. **ProgressAPIClient** - Progress tracking
   - Has manual refresh coordination
   - Has executeWithRetry logic
   - Status: Not Started
   
5. **SleepAPIClient** - Sleep data
   - Has manual refresh coordination
   - Has executeWithRetry logic
   - Status: Not Started
   
6. **WorkoutAPIClient** - Workout data
   - Has manual refresh coordination
   - Has refreshTokenIfNeeded logic
   - Status: Not Started
   
7. **WorkoutTemplateAPIClient** - Workout templates
   - Has manual refresh coordination
   - Has executeWithRetry logic
   - Status: Not Started
   
8. **RemoteHealthDataSyncClient** - Health data sync
   - Has manual refresh coordination
   - Has executeWithRetry logic
   - Status: Not Started

### Medium Priority (Simpler Auth)
9. **UserProfileAPIClient** - User profile operations
   - Uses auth token but simpler refresh pattern
   - Status: Not Started
   
10. **PhysicalProfileAPIClient** - Physical metrics
    - Uses auth token but simpler refresh pattern
    - Status: Not Started

---

## Migration Pattern

### Step 1: Add TokenRefreshClient to AppDependencies

```swift
// DI/AppDependencies.swift

import FitIQCore

final class AppDependencies {
    // MARK: - Authentication
    lazy var tokenRefreshClient: TokenRefreshClient = {
        TokenRefreshClient(
            tokenStorage: authTokenPersistence,
            refreshEndpoint: "\(Config.baseURL)/api/v1/auth/refresh",
            apiKey: Config.apiKey
        )
    }()
    
    // ... rest of dependencies
}
```

### Step 2: Update API Client Constructor

**Before:**
```swift
final class NutritionAPIClient: MealLogRemoteAPIProtocol {
    private let networkClient: NetworkClientProtocol
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let authManager: AuthManager
    
    // Manual refresh coordination
    private var isRefreshing = false
    private var refreshTask: Task<LoginResponse, Error>?
    private let refreshLock = NSLock()
    
    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        baseURL: String,
        apiKey: String,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        authManager: AuthManager
    ) {
        self.networkClient = networkClient
        // ...
    }
}
```

**After:**
```swift
import FitIQCore

final class NutritionAPIClient: MealLogRemoteAPIProtocol {
    private let networkClient: NetworkClientProtocol
    private let tokenRefreshClient: TokenRefreshClient
    private let authManager: AuthManager
    
    // ✅ No manual refresh coordination needed
    
    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        baseURL: String,
        apiKey: String,
        tokenRefreshClient: TokenRefreshClient,
        authManager: AuthManager
    ) {
        self.networkClient = networkClient
        self.tokenRefreshClient = tokenRefreshClient
        // ...
    }
}
```

### Step 3: Replace Manual Refresh Logic

**Before:**
```swift
private func executeWithRetry<T: Decodable>(
    request: URLRequest,
    retryCount: Int = 0
) async throws -> T {
    do {
        // Add auth token
        var authenticatedRequest = request
        if let token = try? await authTokenPersistence.retrieveToken() {
            authenticatedRequest.setValue(
                "Bearer \(token.accessToken)",
                forHTTPHeaderField: "Authorization"
            )
        }
        
        return try await networkClient.request(authenticatedRequest)
    } catch {
        // Handle 401 and refresh
        if retryCount == 0,
           case NetworkError.unauthorized = error {
            try await refreshAccessToken()
            return try await executeWithRetry(request: request, retryCount: 1)
        }
        throw error
    }
}

private func refreshAccessToken() async throws {
    refreshLock.lock()
    defer { refreshLock.unlock() }
    
    if isRefreshing, let task = refreshTask {
        _ = try await task.value
        return
    }
    
    isRefreshing = true
    // ... manual refresh logic ...
    isRefreshing = false
}
```

**After:**
```swift
import FitIQCore

// ✅ Use FitIQCore's automatic retry extension
private func executeRequest<T: Decodable>(
    _ request: URLRequest
) async throws -> T {
    return try await networkClient.executeWithAutoRetry(
        request,
        tokenRefreshClient: tokenRefreshClient
    )
}
```

### Step 4: Update All API Methods

**Before:**
```swift
func submitMealLog(
    rawInput: String,
    mealType: String,
    loggedAt: Date,
    notes: String?
) async throws -> MealLog {
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // Manual retry
    let wrapper: APIDataWrapper<MealLogAPIResponse> = try await executeWithRetry(
        request: urlRequest, retryCount: 0)
    
    return wrapper.data.toDomain()
}
```

**After:**
```swift
func submitMealLog(
    rawInput: String,
    mealType: String,
    loggedAt: Date,
    notes: String?
) async throws -> MealLog {
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // ✅ Automatic retry with FitIQCore
    let wrapper: APIDataWrapper<MealLogAPIResponse> = try await executeRequest(urlRequest)
    
    return wrapper.data.toDomain()
}
```

### Step 5: Remove Manual Refresh Code

Delete these sections from each API client:
- `isRefreshing` property
- `refreshTask` property
- `refreshLock` property
- `refreshAccessToken()` method
- `executeWithRetry()` method

---

## Testing Checklist

### Per-Client Testing
For each migrated API client:
- [ ] Unit tests pass
- [ ] Can make authenticated requests
- [ ] Handles 401 correctly (automatic retry after refresh)
- [ ] Multiple concurrent requests don't cause duplicate refreshes
- [ ] Expired tokens are refreshed proactively

### Integration Testing
- [ ] Login flow works end-to-end
- [ ] Token refresh works automatically
- [ ] 401 triggers refresh and retry
- [ ] Multiple API clients can refresh concurrently
- [ ] AuthManager state updates correctly
- [ ] Logout clears tokens properly

### Performance Testing
- [ ] No performance regression
- [ ] Concurrent requests handled efficiently
- [ ] No memory leaks
- [ ] Token refresh doesn't block unnecessarily

---

## Progress Tracking

### Completion Metrics
- **API Clients Migrated:** 1/10 (10%)
- **Tests Written:** 0/30 estimated
- **Lines of Code Removed:** ~80/630 estimated (13%)
- **Overall Progress:** 30% (Foundation + DI + First client complete)

### Next Steps
1. ✅ ~~Add TokenRefreshClient to AppDependencies~~ **COMPLETE**
2. ✅ ~~Migrate UserAuthAPIClient (most critical)~~ **COMPLETE**
3. Migrate NutritionAPIClient (next priority)
4. Continue with remaining 8 clients
5. Write comprehensive tests
6. Final validation and cleanup

---

## Known Issues & Risks

### Resolved Issues
1. **Type mismatch:** FitIQ's NetworkClientProtocol vs FitIQCore's NetworkClientProtocol
   - Solution: Created separate FitIQCore.URLSessionNetworkClient instance for TokenRefreshClient
   
2. **Protocol conformance:** AuthRepositoryProtocol requires refreshAccessToken method
   - Solution: Added wrapper method that delegates to TokenRefreshClient
   - Maintains protocol compatibility while using FitIQCore internally

### Current Issues
- None

### Risks
1. **Breaking Changes:** Token refresh signature changes
   - Mitigation: Comprehensive testing before migration
   
2. **Concurrent Access:** Multiple clients refreshing simultaneously
   - Mitigation: TokenRefreshClient handles coordination
   
3. **Backward Compatibility:** AuthManager expectations
   - Mitigation: Maintain AuthManager interface

---

## References

- [FitIQCore README](../../FitIQCore/README.md)
- [FitIQCore CHANGELOG](../../FitIQCore/CHANGELOG.md)
- [Authentication Enhancement Design](./AUTHENTICATION_ENHANCEMENT_DESIGN.md)
- [FitIQCore Phase 1 Complete](./FITIQCORE_PHASE1_COMPLETE.md)
- [FitIQ Copilot Instructions](../../.github/copilot-instructions.md)

---

## Notes

- All migration work follows FitIQ's Hexagonal Architecture principles
- TokenRefreshClient is thread-safe and handles deduplication
- NetworkClient+AutoRetry provides transparent 401 handling
- No changes to domain layer required
- AuthManager interface remains unchanged