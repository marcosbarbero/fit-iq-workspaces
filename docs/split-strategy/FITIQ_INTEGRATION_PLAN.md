# FitIQ Integration Plan - FitIQCore v0.2.0

**Date:** 2025-01-27  
**Status:** 🔄 In Progress  
**Target:** Migrate FitIQ to use FitIQCore v0.2.0 enhanced authentication

---

## 📋 Overview

This document outlines the step-by-step plan to integrate FitIQCore v0.2.0 into FitIQ, replacing manual authentication code with the shared, production-ready components.

---

## 🎯 Goals

1. **Replace FitIQ's AuthToken** with FitIQCore's enhanced version
2. **Centralize token refresh** using FitIQCore's `TokenRefreshClient`
3. **Add automatic retry** to all API clients using `executeWithAutoRetry()`
4. **Remove duplicated code** (~630 lines)
5. **Maintain backward compatibility** - no breaking changes to app functionality
6. **Ensure all tests pass** after migration

---

## 📊 Current State Analysis

### Files to Modify/Remove

#### 1. AuthToken Entity
- **Location:** `FitIQ/Domain/Entities/Auth/AuthToken.swift`
- **Lines:** ~230 lines
- **Action:** DELETE (replace with FitIQCore import)
- **References:** 63 files reference AuthToken

#### 2. Token Refresh Logic (Duplicated across 7 files)
- `UserAuthAPIClient.swift` - Main refresh implementation
- `RemoteHealthDataSyncClient.swift` - Duplicated refresh
- `NutritionAPIClient.swift` - Duplicated refresh
- `PhotoRecognitionAPIClient.swift` - Duplicated refresh
- `ProgressAPIClient.swift` - Duplicated refresh
- `SleepAPIClient.swift` - Duplicated refresh
- `WorkoutAPIClient.swift` - Likely duplicated refresh
- `WorkoutTemplateAPIClient.swift` - Likely duplicated refresh
- **Total:** ~400 lines of duplicated refresh logic
- **Action:** REPLACE with `TokenRefreshClient`

#### 3. Manual Retry Logic
- All API clients have manual 401 handling
- **Action:** REPLACE with `executeWithAutoRetry()`

---

## 🚀 Migration Steps

### Phase 1: Add FitIQCore Import (30 min)

**Status:** ✅ Complete (FitIQCore already added as local package)

#### 1.1 Verify Package Dependency
- [x] FitIQCore is in project as local package
- [x] Build succeeds with FitIQCore

---

### Phase 2: Replace AuthToken Entity (1 hour)

**Status:** 🔄 In Progress

#### 2.1 Add FitIQCore Import to Files Using AuthToken
Files that need `import FitIQCore`:
- [ ] `KeychainAuthTokenAdapter.swift`
- [ ] `UserAuthAPIClient.swift`
- [ ] All API clients (8 files)
- [ ] Any ViewModels using AuthToken
- [ ] Any UseCases using AuthToken

#### 2.2 Remove Local AuthToken
- [ ] Delete `FitIQ/Domain/Entities/Auth/AuthToken.swift`
- [ ] Update project file to remove reference
- [ ] Build and fix any compilation errors

#### 2.3 Update References
- [ ] Search for `AuthToken(` constructor calls
- [ ] Replace with `AuthToken.withParsedExpiration()` where appropriate
- [ ] Update any custom initializers

---

### Phase 3: Create Centralized TokenRefreshClient (1 hour)

**Status:** ⏳ Not Started

#### 3.1 Add TokenRefreshClient to AppDependencies
```swift
// DI/AppDependencies.swift

import FitIQCore

lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        baseURL: ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? "",
        apiKey: ConfigurationProperties.value(for: "API_KEY") ?? "",
        networkClient: URLSessionNetworkClient()
    )
}()
```

#### 3.2 Inject into API Clients
- [ ] Update `UserAuthAPIClient` initializer
- [ ] Update `RemoteHealthDataSyncClient` initializer
- [ ] Update `NutritionAPIClient` initializer
- [ ] Update `PhotoRecognitionAPIClient` initializer
- [ ] Update `ProgressAPIClient` initializer
- [ ] Update `SleepAPIClient` initializer
- [ ] Update `WorkoutAPIClient` initializer
- [ ] Update `WorkoutTemplateAPIClient` initializer

---

### Phase 4: Replace Manual Refresh Logic (2 hours)

**Status:** ⏳ Not Started

For each API client, replace manual refresh with `TokenRefreshClient`:

#### 4.1 UserAuthAPIClient
```swift
// BEFORE
func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
    refreshLock.lock()
    // ... manual refresh logic
}

// AFTER
private let tokenRefreshClient: TokenRefreshClient

func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
    let response = try await tokenRefreshClient.refreshToken(
        refreshToken: request.refreshToken
    )
    return LoginResponse(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken
    )
}
```

#### 4.2 Remove Synchronization Code
For each API client:
- [ ] Remove `refreshLock` property
- [ ] Remove `isRefreshing` flag
- [ ] Remove `refreshTask` property
- [ ] Remove manual lock/unlock calls
- [ ] Let `TokenRefreshClient` handle synchronization

#### 4.3 Files to Update
- [ ] `UserAuthAPIClient.swift`
- [ ] `RemoteHealthDataSyncClient.swift`
- [ ] `NutritionAPIClient.swift`
- [ ] `PhotoRecognitionAPIClient.swift`
- [ ] `ProgressAPIClient.swift`
- [ ] `SleepAPIClient.swift`
- [ ] `WorkoutAPIClient.swift`
- [ ] `WorkoutTemplateAPIClient.swift`

---

### Phase 5: Add Automatic Retry (2 hours)

**Status:** ⏳ Not Started

Replace manual 401 handling with `executeWithAutoRetry()`:

#### 5.1 Update API Client Methods
```swift
// BEFORE
func performAuthenticatedRequest<T: Decodable>(
    url: URL,
    httpMethod: String,
    body: Encodable? = nil
) async throws -> T {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await networkClient.executeRequest(request: request)
    
    if response.statusCode == 401 {
        // Manual refresh and retry
        try await refreshAccessToken(...)
        // Retry request
    }
    // ... decode response
}

// AFTER
func performAuthenticatedRequest<T: Decodable>(
    url: URL,
    httpMethod: String,
    body: Encodable? = nil
) async throws -> T {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    return try await networkClient.executeWithAutoRetryAndUnwrap(
        request: request,
        dataType: T.self,
        refreshClient: tokenRefreshClient,
        currentRefreshToken: try getRefreshToken(),
        onTokenRefreshed: { newToken in
            try await self.saveAccessToken(newToken)
        }
    )
}
```

#### 5.2 Files to Update
- [ ] `UserAuthAPIClient.swift`
- [ ] `RemoteHealthDataSyncClient.swift`
- [ ] `NutritionAPIClient.swift`
- [ ] `PhotoRecognitionAPIClient.swift`
- [ ] `ProgressAPIClient.swift`
- [ ] `SleepAPIClient.swift`
- [ ] `WorkoutAPIClient.swift`
- [ ] `WorkoutTemplateAPIClient.swift`

#### 5.3 Remove Manual Retry Logic
- [ ] Remove `executeWithRetry()` helper methods
- [ ] Remove `retryCount` parameters
- [ ] Remove manual 401 checking
- [ ] Simplify error handling

---

### Phase 6: Update AppDependencies (30 min)

**Status:** ⏳ Not Started

#### 6.1 Wire Up New Dependencies
```swift
// DI/AppDependencies.swift

import FitIQCore

final class AppDependencies {
    // MARK: - FitIQCore Components
    
    lazy var tokenRefreshClient: TokenRefreshClient = {
        TokenRefreshClient(
            baseURL: ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? "",
            apiKey: ConfigurationProperties.value(for: "API_KEY") ?? "",
            networkClient: URLSessionNetworkClient()
        )
    }()
    
    // MARK: - API Clients (Updated with TokenRefreshClient)
    
    lazy var userAuthAPIClient: UserAuthAPIClient = {
        UserAuthAPIClient(
            authManager: authManager,
            authTokenPersistence: keychainAuthTokenAdapter,
            tokenRefreshClient: tokenRefreshClient
        )
    }()
    
    lazy var nutritionAPIClient: NutritionAPIClient = {
        NutritionAPIClient(
            networkClient: URLSessionNetworkClient(),
            baseURL: ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? "",
            apiKey: ConfigurationProperties.value(for: "API_KEY") ?? "",
            authTokenPersistence: keychainAuthTokenAdapter,
            authManager: authManager,
            tokenRefreshClient: tokenRefreshClient
        )
    }()
    
    // ... repeat for other API clients
}
```

#### 6.2 Update Initialization Order
- [ ] Ensure `tokenRefreshClient` is created before API clients
- [ ] Update all API client factory methods
- [ ] Verify no circular dependencies

---

### Phase 7: Testing & Validation (2 hours)

**Status:** ⏳ Not Started

#### 7.1 Unit Tests
- [ ] Run all existing tests
- [ ] Fix any test compilation errors
- [ ] Update mocks to use FitIQCore types
- [ ] Verify all tests pass

#### 7.2 Integration Tests
- [ ] Test login flow
- [ ] Test token refresh flow
- [ ] Test concurrent API calls (verify deduplication)
- [ ] Test 401 automatic retry
- [ ] Test logout flow

#### 7.3 Manual Testing
- [ ] Test app launch
- [ ] Test registration
- [ ] Test login
- [ ] Test authenticated API calls
- [ ] Test token expiration and refresh
- [ ] Test logout
- [ ] Test offline scenarios

---

### Phase 8: Cleanup (30 min)

**Status:** ⏳ Not Started

#### 8.1 Remove Duplicated Code
- [ ] Delete `FitIQ/Domain/Entities/Auth/AuthToken.swift`
- [ ] Remove `refreshLock` from all API clients
- [ ] Remove `isRefreshing` flags
- [ ] Remove `refreshTask` properties
- [ ] Remove `executeWithRetry` helper methods

#### 8.2 Update Comments
- [ ] Update documentation to reference FitIQCore
- [ ] Remove outdated comments about manual refresh
- [ ] Add comments about FitIQCore integration

#### 8.3 Format Code
- [ ] Run SwiftFormat (if available)
- [ ] Fix any linting issues
- [ ] Review diff for any missed cleanup

---

## 📊 Code Reduction Estimate

| Component | Before | After | Reduction |
|-----------|--------|-------|-----------|
| AuthToken Entity | 230 lines | 0 lines (imported) | -230 |
| Token Refresh Logic | ~400 lines | ~50 lines | -350 |
| Manual Retry Logic | ~50 lines | 0 lines | -50 |
| **Total** | **~680 lines** | **~50 lines** | **-630 lines** |

---

## 🚨 Risk Assessment

### High Risk
- **Breaking Changes:** API client interfaces might change
  - **Mitigation:** Update all call sites systematically
  - **Rollback:** Keep git history clean, commit frequently

### Medium Risk
- **Token Persistence:** Token format might be incompatible
  - **Mitigation:** FitIQCore uses same format as FitIQ
  - **Rollback:** Clear keychain during testing

### Low Risk
- **Performance:** Centralized refresh might be slower
  - **Mitigation:** FitIQCore is more efficient (deduplication)
  - **Rollback:** Unlikely to be needed

---

## 🎯 Success Criteria

- [ ] All existing tests pass
- [ ] App launches successfully
- [ ] Login/logout works
- [ ] Token refresh works automatically
- [ ] Concurrent API calls are handled correctly
- [ ] No duplicate refresh requests
- [ ] Code reduction achieved (~630 lines removed)
- [ ] No regressions in functionality

---

## 📝 Rollback Plan

If integration fails:

1. **Revert Commits:** Use git to revert to last working state
2. **Keep Local Changes:** Stash changes if needed for analysis
3. **Document Issues:** Note what failed for future attempts
4. **Test Thoroughly:** Ensure rollback restores full functionality

---

## 📅 Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Add Import | 30 min | ✅ Complete |
| Phase 2: Replace AuthToken | 1 hour | 🔄 In Progress |
| Phase 3: Create RefreshClient | 1 hour | ⏳ Pending |
| Phase 4: Replace Refresh Logic | 2 hours | ⏳ Pending |
| Phase 5: Add Auto-Retry | 2 hours | ⏳ Pending |
| Phase 6: Update Dependencies | 30 min | ⏳ Pending |
| Phase 7: Testing | 2 hours | ⏳ Pending |
| Phase 8: Cleanup | 30 min | ⏳ Pending |
| **Total** | **~9 hours** | **10% Complete** |

---

## 📚 Related Documents

- [FitIQCore v0.2.0 README](../../FitIQCore/README.md)
- [FitIQCore v0.2.0 CHANGELOG](../../FitIQCore/CHANGELOG.md)
- [Auth Enhancement Complete](./FITIQCORE_AUTH_ENHANCEMENT_COMPLETE.md)
- [Implementation Status](./IMPLEMENTATION_STATUS.md)

---

**Status:** 🔄 In Progress  
**Last Updated:** 2025-01-27  
**Next Step:** Phase 2 - Replace AuthToken Entity