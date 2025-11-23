# Authentication Unification - Action Plan

**Date:** 2025-01-27  
**Priority:** 🔴 Critical  
**Estimated Effort:** 2-3 days  
**Status:** 🟡 Ready to Start

---

## 🎯 Objective

Unify authentication between FitIQ and Lume by extracting FitIQ's superior auth implementation to FitIQCore, then migrating both apps to use it.

**Why:** FitIQ has production-ready auth with JWT parsing, synchronized token refresh, and automatic retry. Lume's auth is basic and lacks critical features.

---

## 📋 Three-Phase Plan

### Phase 1: Enhance FitIQCore (1 day)

Extract FitIQ's authentication components to FitIQCore.

#### Tasks

**1.1 Extract AuthToken Entity**
- [ ] Copy `FitIQ/Domain/Entities/Auth/AuthToken.swift` → `FitIQCore/Sources/FitIQCore/Auth/Domain/AuthToken.swift`
- [ ] Make all types and methods `public`
- [ ] Keep JWT parsing methods (parseExpirationFromJWT, parseUserIdFromJWT)
- [ ] Keep validation logic
- [ ] Keep sanitized logging
- [ ] Add comprehensive documentation

**Expected Result:** Complete `AuthToken` entity in FitIQCore (~280 lines)

---

**1.2 Create TokenRefreshClient**
- [ ] Create `FitIQCore/Sources/FitIQCore/Auth/Infrastructure/TokenRefreshClient.swift`
- [ ] Implement synchronized token refresh (NSLock)
- [ ] Add task deduplication (share in-progress refreshes)
- [ ] Handle token refresh endpoint (`/api/v1/auth/refresh`)
- [ ] Return AuthToken with parsed expiration
- [ ] Add comprehensive logging

**Features:**
```swift
public final class TokenRefreshClient {
    private var refreshTask: Task<AuthToken, Error>?
    private let refreshLock = NSLock()
    
    public func refreshToken(_ refreshToken: String) async throws -> AuthToken
}
```

**Expected Result:** Thread-safe token refresh client (~150 lines)

---

**1.3 Add Automatic Retry Extension**
- [ ] Create `FitIQCore/Sources/FitIQCore/Network/NetworkClientRetry.swift`
- [ ] Extend `NetworkClientProtocol` with `executeWithAutoRetry` method
- [ ] Auto-detect 401 Unauthorized
- [ ] Trigger token refresh automatically
- [ ] Retry original request with new token
- [ ] Prevent infinite retry loops (max 1 retry)

**Signature:**
```swift
public extension NetworkClientProtocol {
    func executeWithAutoRetry(
        request: URLRequest,
        tokenRefreshClient: TokenRefreshClient,
        authTokenPersistence: AuthTokenPersistenceProtocol,
        retryCount: Int = 0
    ) async throws -> (Data, HTTPURLResponse)
}
```

**Expected Result:** Automatic retry extension (~100 lines)

---

**1.4 Write Tests**
- [ ] Create `FitIQCore/Tests/FitIQCoreTests/Auth/AuthTokenTests.swift`
- [ ] Test JWT parsing (valid/invalid tokens)
- [ ] Test expiration checks (isExpired, willExpireSoon)
- [ ] Test validation logic
- [ ] Create `FitIQCore/Tests/FitIQCoreTests/Auth/TokenRefreshClientTests.swift`
- [ ] Test synchronized refresh (concurrent calls)
- [ ] Test task deduplication
- [ ] Mock network client for testing

**Expected Result:** 95%+ test coverage (~200 lines of tests)

---

**1.5 Update Documentation**
- [ ] Update `FitIQCore/README.md` with AuthToken usage
- [ ] Add TokenRefreshClient usage examples
- [ ] Update CHANGELOG.md (version 0.1.1)
- [ ] Document automatic retry feature

**Expected Result:** Complete documentation updates

---

### Phase 2: Migrate FitIQ (0.5 days)

Update FitIQ to use FitIQCore's enhanced auth.

#### Tasks

**2.1 Remove Duplicated Code**
- [ ] Delete `FitIQ/Domain/Entities/Auth/AuthToken.swift` (~280 lines)
- [ ] Update imports: `import FitIQCore` in auth-related files
- [ ] Verify all references to `AuthToken` resolve to FitIQCore

**Expected Result:** ~280 lines removed, FitIQ uses FitIQCore's AuthToken

---

**2.2 Add TokenRefreshClient to AppDependencies**
- [ ] Update `FitIQ/DI/AppDependencies.swift`
- [ ] Add `tokenRefreshClient: TokenRefreshClient`
- [ ] Initialize with FitIQCore's implementation

```swift
lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        networkClient: networkClient,
        baseURL: URL(string: Config.baseURL)!,
        apiKey: Config.apiKey
    )
}()
```

**Expected Result:** TokenRefreshClient available in DI container

---

**2.3 Update API Clients (Optional - Already Working)**
- [ ] Review `ProgressAPIClient.swift` - already has synchronized refresh
- [ ] Review `UserAuthAPIClient.swift` - already has synchronized refresh
- [ ] Consider refactoring to use FitIQCore's `executeWithAutoRetry` (future enhancement)

**Note:** FitIQ already implements this pattern correctly. Migration to use FitIQCore's extension is optional and can be done incrementally.

**Expected Result:** FitIQ continues working as before, now using FitIQCore

---

**2.4 Test and Verify**
- [ ] Run FitIQ unit tests - all should pass
- [ ] Build FitIQ - no errors
- [ ] Test authentication flow (login/logout)
- [ ] Test token refresh (wait for expiration or force 401)
- [ ] Verify no regressions

**Expected Result:** ✅ FitIQ fully functional with FitIQCore auth

---

### Phase 3: Migrate Lume (1 day)

Upgrade Lume to use FitIQCore's production-ready auth.

#### Tasks

**3.1 Remove Lume's Basic Auth**
- [ ] Delete `lume/Domain/Entities/AuthToken.swift` (~50 lines)
- [ ] Delete `lume/Services/Authentication/KeychainTokenStorage.swift` (~200 lines)
- [ ] Update imports: `import FitIQCore` in auth files

**Expected Result:** ~250 lines removed from Lume

---

**3.2 Update Token Storage**
- [ ] Update `lume/DI/AppDependencies.swift`
- [ ] Replace `tokenStorage: TokenStorageProtocol` with `authTokenStorage: AuthTokenPersistenceProtocol`
- [ ] Use FitIQCore's `KeychainAuthTokenStorage()`

```swift
// Before
private(set) lazy var tokenStorage: TokenStorageProtocol = {
    KeychainTokenStorage()
}()

// After
private(set) lazy var authTokenStorage: AuthTokenPersistenceProtocol = {
    KeychainAuthTokenStorage()
}()
```

**Expected Result:** Lume uses FitIQCore's token storage

---

**3.3 Add TokenRefreshClient**
- [ ] Add to `lume/DI/AppDependencies.swift`

```swift
private(set) lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        networkClient: URLSessionNetworkClient(),
        baseURL: AppConfiguration.shared.backendBaseURL,
        apiKey: AppConfiguration.shared.apiKey
    )
}()
```

**Expected Result:** Lume has thread-safe token refresh

---

**3.4 Update RemoteAuthService**
- [ ] Update `lume/Services/Authentication/RemoteAuthService.swift`
- [ ] Use FitIQCore's `AuthToken` (with JWT parsing)
- [ ] Remove manual `refreshToken` method
- [ ] Let `executeWithAutoRetry` handle refreshes automatically

```swift
// Before - manual refresh
func refreshToken(_ token: String) async throws -> AuthToken {
    // ~50 lines of manual refresh logic
}

// After - automatic refresh via NetworkClient
// No manual method needed - executeWithAutoRetry handles it
```

**Expected Result:** ~100 lines of manual refresh logic removed

---

**3.5 Update HTTPClient**
- [ ] Already done! HTTPClient uses FitIQCore's NetworkClientProtocol
- [ ] Add `executeWithAutoRetry` usage (instead of basic executeRequest)

```swift
// Before
let (data, httpResponse) = try await networkClient.executeRequest(request: request)

// After (when auth needed)
let (data, httpResponse) = try await networkClient.executeWithAutoRetry(
    request: request,
    tokenRefreshClient: tokenRefreshClient,
    authTokenPersistence: authTokenStorage
)
```

**Expected Result:** Automatic token refresh on 401

---

**3.6 Update Auth Services**
- [ ] Update login/register methods to return FitIQCore's `AuthToken`
- [ ] Use `AuthToken.withParsedExpiration()` to auto-parse JWT expiration

```swift
// After successful login
let token = AuthToken.withParsedExpiration(
    accessToken: response.accessToken,
    refreshToken: response.refreshToken
)

// Expiration is automatically parsed from JWT!
```

**Expected Result:** No manual expiration tracking needed

---

**3.7 Test and Verify**
- [ ] Run Lume unit tests - update mocks for FitIQCore types
- [ ] Build Lume - no errors
- [ ] Test authentication flow (login/logout)
- [ ] Test token refresh (automatic on 401)
- [ ] Test mood tracking (verify auth still works)
- [ ] Test journal entries (verify auth still works)
- [ ] Test AI insights (verify auth still works)
- [ ] Verify no regressions

**Expected Result:** ✅ Lume fully functional with production-ready auth

---

## 📊 Success Metrics

### Code Quality
- [ ] Zero compiler warnings
- [ ] 95%+ test coverage for new FitIQCore code
- [ ] All unit tests passing (FitIQ + Lume)
- [ ] No force unwraps in production code

### Functionality
- [ ] Both apps authenticate successfully
- [ ] Token refresh works automatically on 401
- [ ] No race conditions during concurrent refreshes
- [ ] JWT expiration parsed correctly
- [ ] Logout clears all tokens

### Code Reduction
- [ ] ~280 lines removed from FitIQ (AuthToken duplication)
- [ ] ~350 lines removed from Lume (basic auth + storage)
- [ ] ~630 total lines eliminated
- [ ] Single source of truth in FitIQCore

---

## 🎯 Benefits Delivered

### For FitIQ
✅ Reduced code duplication  
✅ Shared auth improvements benefit both apps  
✅ Consistent behavior with Lume  

### For Lume
✅ **Production-ready auth** (was basic before)  
✅ **Thread-safe token refresh** (was missing)  
✅ **Automatic retry on 401** (was manual)  
✅ **JWT parsing** (was manual tracking)  
✅ **Proactive refresh** (willExpireSoon - was reactive only)  
✅ **Sanitized logging** (no token leaks)  

### For Both
✅ **Single source of truth** - fix once, both benefit  
✅ **Better tested** - comprehensive test coverage  
✅ **Production-ready** - handles all edge cases  
✅ **Maintainable** - one place to update auth logic  

---

## 🚧 Risk Mitigation

### Risk 1: Breaking Changes During Migration
**Mitigation:**
- Migrate FitIQ first (lower risk - already uses this pattern)
- Comprehensive testing at each phase
- Keep old code until new code verified

### Risk 2: Token Storage Incompatibility
**Mitigation:**
- FitIQCore uses same Keychain keys as FitIQ (compatible)
- Lume may need migration for existing users (parse expiresAt from JWT)
- Test with existing auth tokens

### Risk 3: Concurrent Refresh Race Conditions
**Mitigation:**
- NSLock ensures thread safety
- Task deduplication prevents duplicate refreshes
- Comprehensive tests for concurrent scenarios

---

## 📝 Implementation Order

### Day 1: FitIQCore Enhancement
- Morning: Extract AuthToken entity (~2 hours)
- Afternoon: Create TokenRefreshClient (~3 hours)
- Evening: Add automatic retry extension + tests (~3 hours)

### Day 2: FitIQ Migration
- Morning: Remove duplicated code, update imports (~2 hours)
- Afternoon: Add TokenRefreshClient to DI, test (~2 hours)

### Day 3: Lume Migration
- Morning: Remove basic auth, add FitIQCore components (~3 hours)
- Afternoon: Update auth services, remove manual refresh (~2 hours)
- Evening: Comprehensive testing (~3 hours)

---

## 🔗 Related Documentation

- [AUTH_UNIFICATION_ANALYSIS.md](./AUTH_UNIFICATION_ANALYSIS.md) - Detailed comparison
- [LUME_INTEGRATION_GUIDE.md](./LUME_INTEGRATION_GUIDE.md) - Lume integration guide
- [FITIQ_INTEGRATION_GUIDE.md](./FITIQ_INTEGRATION_GUIDE.md) - FitIQ integration guide
- [FitIQCore README](../../FitIQCore/README.md) - Package documentation

---

## ✅ Completion Checklist

### Phase 1: FitIQCore
- [ ] AuthToken entity extracted
- [ ] TokenRefreshClient created
- [ ] Automatic retry extension added
- [ ] Tests written (95%+ coverage)
- [ ] Documentation updated
- [ ] CHANGELOG updated (v0.1.1)

### Phase 2: FitIQ
- [ ] Old AuthToken deleted
- [ ] FitIQCore imports added
- [ ] TokenRefreshClient in AppDependencies
- [ ] All tests passing
- [ ] No regressions
- [ ] ~280 lines removed

### Phase 3: Lume
- [ ] Basic auth code deleted
- [ ] FitIQCore imports added
- [ ] TokenRefreshClient in AppDependencies
- [ ] Manual refresh removed
- [ ] All tests passing
- [ ] No regressions
- [ ] ~350 lines removed

### Final Verification
- [ ] Both apps build successfully
- [ ] Both apps authenticate correctly
- [ ] Token refresh works in both apps
- [ ] No race conditions observed
- [ ] Documentation complete
- [ ] Ready for production

---

**Status:** 🟡 Ready to Start  
**Priority:** 🔴 Critical  
**Estimated Effort:** 2-3 days  
**Expected Completion:** 2025-01-30

**Note:** This unification is critical for production readiness. Lume's current auth lacks thread safety and automatic retry, which are essential for production use.