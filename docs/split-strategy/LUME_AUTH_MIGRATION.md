# Lume Authentication Migration to FitIQCore

**Status:** Ready to Start  
**Created:** 2025-01-27  
**Priority:** High (Production App)

---

## Overview

This document outlines the migration of Lume's authentication system to use FitIQCore's unified, production-ready authentication components. Lume is currently production-ready and should be migrated carefully to avoid breaking existing functionality.

### Goals

1. **Replace Local AuthToken:** Remove Lume's local `AuthToken` entity, use FitIQCore's version
2. **Use TokenRefreshClient:** Replace manual token refresh logic with FitIQCore's thread-safe implementation
3. **Simplify Code:** Remove ~200 lines of duplicated auth code
4. **Production Ready:** Leverage FitIQCore's tested, robust authentication
5. **Maintain Stability:** No breaking changes to existing user sessions

---

## Current State Assessment

### Lume's Authentication Components

1. **Domain/Entities/AuthToken.swift** (~25 lines)
   - Manual expiration tracking
   - Simple `isExpired` and `needsRefresh` logic
   - No JWT parsing

2. **Services/Authentication/RemoteAuthService.swift** (~300 lines)
   - Manual JWT decoding for expiration
   - No thread-safe refresh coordination
   - Basic retry logic
   - Conservative 15-minute default expiration

3. **Data/Repositories/AuthRepository.swift** (~200 lines)
   - Token refresh with basic error handling
   - No automatic retry on 401
   - Manual token storage coordination

4. **DI/AppDependencies.swift**
   - Already imports FitIQCore ✅
   - Uses some FitIQCore components (AuthManager, KeychainAuthTokenStorage)
   - Missing: TokenRefreshClient integration

### What's Already Using FitIQCore ✅

- `AuthManager` - Already using FitIQCore's version
- `KeychainAuthTokenStorage` - Already using FitIQCore's version
- `AuthTokenPersistenceProtocol` - Already using FitIQCore's version

### What Needs Migration

- `AuthToken` entity - Replace with FitIQCore's version
- Token refresh logic - Use TokenRefreshClient
- JWT parsing - Use FitIQCore's built-in parsing
- Manual expiration tracking - Use FitIQCore's automatic tracking

---

## Migration Phases

### Phase 1: Package Setup ⏸️ BLOCKED

**Status:** BLOCKED - Requires Xcode GUI to add package reference

**Required Action:**
1. Open `lume.xcodeproj` in Xcode
2. Go to **File > Add Package Dependencies**
3. Select **Add Local Package**
4. Navigate to `../FitIQCore`
5. Click **Add Package**
6. Ensure `FitIQCore` is added to `lume` target

**Why Manual?**
- Xcode's pbxproj format for local packages is version-specific
- Manual editing causes: `-[XCLocalSwiftPackageReference group]: unrecognized selector`
- Safe to add through Xcode GUI

**Verification:**
```bash
cd lume
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 17' build
# Should build successfully
```

### Phase 2: Replace Local AuthToken ✅ READY

**Files to Modify:**
1. Delete `lume/Domain/Entities/AuthToken.swift`
2. Update imports to use `import FitIQCore`
3. Replace `AuthToken` references with `FitIQCore.AuthToken`

**Affected Files:**
- `Data/Repositories/AuthRepository.swift`
- `Services/Authentication/RemoteAuthService.swift`
- `Services/Authentication/KeychainTokenStorage.swift`
- `Domain/Ports/AuthServiceProtocol.swift`

**Search & Replace:**
```swift
// Before
struct AuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

// After
import FitIQCore
// Use FitIQCore.AuthToken (which has JWT parsing built-in)
```

### Phase 3: Add TokenRefreshClient to DI ✅ READY

**File:** `lume/DI/AppDependencies.swift`

**Changes:**
```swift
// Add after existing FitIQCore dependencies
private(set) lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        baseURL: AppConfiguration.shared.backendBaseURL.absoluteString,
        apiKey: AppConfiguration.shared.apiKey,
        networkClient: FitIQCore.URLSessionNetworkClient(),
        refreshPath: AppConfiguration.Endpoints.authRefresh
    )
}()
```

### Phase 4: Migrate RemoteAuthService ✅ READY

**File:** `lume/Services/Authentication/RemoteAuthService.swift`

**Changes:**
1. Remove manual JWT decoding methods (~50 lines)
   - `decodeJWTExpiration(token:)`
   - `getTokenExpiration(accessToken:)`

2. Use FitIQCore.AuthToken which parses JWT automatically:
   ```swift
   // Before
   let token = AuthToken(
       accessToken: apiResponse.data.accessToken,
       refreshToken: apiResponse.data.refreshToken,
       expiresAt: getTokenExpiration(accessToken: apiResponse.data.accessToken)
   )
   
   // After
   let token = try AuthToken(
       accessToken: apiResponse.data.accessToken,
       refreshToken: apiResponse.data.refreshToken
   )
   // FitIQCore.AuthToken automatically parses JWT and extracts expiration
   ```

3. Use TokenRefreshClient for refresh:
   ```swift
   // Before (in refreshToken method)
   let (data, response) = try await session.data(for: request)
   // Manual response parsing...
   
   // After
   // This becomes simpler - just use the TokenRefreshClient injected via DI
   // Or keep RemoteAuthService simple and move refresh logic to repository
   ```

### Phase 5: Simplify AuthRepository ✅ READY

**File:** `lume/Data/Repositories/AuthRepository.swift`

**Current refreshToken() method (~70 lines):**
- Manual token retrieval
- Manual refresh call
- Manual error handling
- Manual token storage

**After (using TokenRefreshClient):**
```swift
func refreshToken() async throws -> AuthToken {
    print("🔄 [AuthRepository] Starting token refresh via FitIQCore")
    
    // Get current refresh token
    guard let currentToken = try await tokenStorage.getToken() else {
        print("❌ [AuthRepository] No current token found")
        throw AuthenticationError.tokenExpired
    }
    
    // Use FitIQCore's TokenRefreshClient (thread-safe, coordinated)
    do {
        let refreshResponse = try await tokenRefreshClient.refreshToken(
            refreshToken: currentToken.refreshToken
        )
        
        // Convert to AuthToken
        let newToken = try AuthToken(
            accessToken: refreshResponse.accessToken,
            refreshToken: refreshResponse.refreshToken
        )
        
        // Save new token
        try await tokenStorage.saveToken(newToken)
        
        print("✅ [AuthRepository] Token refreshed via FitIQCore")
        return newToken
        
    } catch {
        // Handle errors (logout if token is invalid/revoked)
        print("❌ [AuthRepository] Token refresh failed: \(error)")
        try? await tokenStorage.deleteToken()
        UserSession.shared.endSession()
        throw error
    }
}
```

**Lines Removed:** ~50 (manual refresh logic, duplicate error handling)

---

## Migration Pattern (Detailed Steps)

### Step 1: Setup Package (Manual - Xcode GUI)
1. Open `lume.xcodeproj` in Xcode
2. Add FitIQCore local package via File menu
3. Verify build succeeds

### Step 2: Delete Local AuthToken
```bash
cd lume
rm lume/Domain/Entities/AuthToken.swift
```

### Step 3: Update RemoteAuthService
```swift
import FitIQCore

// Remove these methods:
// - decodeJWTExpiration(token:)
// - getTokenExpiration(accessToken:)

// Update register() method:
func register(email: String, password: String, name: String, dateOfBirth: Date) async throws -> (User, AuthToken) {
    // ... existing request setup ...
    
    // After successful response:
    let token = try AuthToken(
        accessToken: apiResponse.data.accessToken,
        refreshToken: apiResponse.data.refreshToken
    )
    // FitIQCore.AuthToken automatically parses JWT
    
    return (user, token)
}

// Update login() method similarly
// Update refreshToken() method similarly
```

### Step 4: Add TokenRefreshClient to AppDependencies
```swift
// In AppDependencies.swift, after existing FitIQCore dependencies:

private(set) lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        baseURL: AppConfiguration.shared.backendBaseURL.absoluteString,
        apiKey: AppConfiguration.shared.apiKey,
        networkClient: FitIQCore.URLSessionNetworkClient()
    )
}()
```

### Step 5: Update AuthRepository
```swift
// Add TokenRefreshClient dependency
private let tokenRefreshClient: TokenRefreshClient

init(
    authService: AuthServiceProtocol,
    tokenStorage: TokenStorageProtocol,
    userProfileService: UserProfileServiceProtocol,
    modelContext: ModelContext,
    tokenRefreshClient: TokenRefreshClient
) {
    self.authService = authService
    self.tokenStorage = tokenStorage
    self.userProfileService = userProfileService
    self.modelContext = modelContext
    self.tokenRefreshClient = tokenRefreshClient
}

// Simplify refreshToken() method (see Phase 5 example above)
```

### Step 6: Update AppDependencies to inject TokenRefreshClient
```swift
private(set) lazy var authRepository: AuthRepositoryProtocol = {
    AuthRepository(
        authService: authService,
        tokenStorage: tokenStorage,
        userProfileService: userProfileService,
        modelContext: modelContext,
        tokenRefreshClient: tokenRefreshClient  // Add this
    )
}()
```

### Step 7: Build and Test
```bash
cd lume
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 17' build
```

---

## Testing Checklist

### Unit Tests
- [ ] AuthToken parsing works with FitIQCore version
- [ ] Token expiration detection works correctly
- [ ] Token refresh succeeds with valid refresh token
- [ ] Token refresh fails gracefully with invalid token

### Integration Tests
- [ ] User registration creates valid token
- [ ] User login creates valid token
- [ ] Token refresh updates stored token
- [ ] Expired tokens trigger automatic refresh
- [ ] Invalid refresh token triggers logout

### Manual Testing
- [ ] Register new user
- [ ] Login with existing user
- [ ] App maintains session after restart
- [ ] Token refresh happens automatically
- [ ] Expired/revoked tokens force logout
- [ ] No session leaks between users

---

## Code Metrics

### Before Migration
- **Total Lines:** ~525 (auth-related code)
  - AuthToken entity: ~25
  - RemoteAuthService: ~300
  - AuthRepository: ~200

### After Migration
- **Estimated Total Lines:** ~325
- **Lines Removed:** ~200 (38% reduction)
- **Code Duplicated with FitIQ:** 0 (was ~200)

### Breakdown
| Component | Before | After | Removed |
|-----------|--------|-------|---------|
| AuthToken entity | 25 | 0 (using FitIQCore) | 25 |
| JWT parsing | 50 | 0 (using FitIQCore) | 50 |
| Token refresh logic | 70 | 20 (simplified) | 50 |
| Error handling | 50 | 25 (simplified) | 25 |
| Manual expiration | 30 | 0 (automatic) | 30 |
| **TOTAL** | **225** | **45** | **180** |

---

## Risks & Mitigations

### Risk 1: Breaking Existing User Sessions
**Impact:** Users forced to re-login  
**Mitigation:**
- Keep token storage format compatible
- Test migration with existing tokens
- Gradual rollout if possible

### Risk 2: Token Expiration Changes
**Impact:** Tokens expire differently (conservative 15min → JWT-based)  
**Mitigation:**
- FitIQCore's JWT parsing is more accurate
- Proactive refresh (5min before expiry) prevents issues
- Better than conservative 15min default

### Risk 3: Thread Safety Issues
**Impact:** Concurrent refresh requests  
**Mitigation:**
- TokenRefreshClient handles thread safety
- Single in-flight refresh shared across callers
- Better than current implementation

---

## Rollback Plan

If issues arise after migration:

1. **Revert Code Changes**
   ```bash
   git revert <migration-commit>
   ```

2. **Keep Old AuthToken** (temporarily)
   - Copy old AuthToken to `LegacyAuthToken`
   - Use as fallback if needed

3. **Monitor Logs**
   - Check for token refresh failures
   - Monitor logout rate
   - Track session stability

---

## Dependencies

### Blocked By
- [ ] **Phase 1:** Manual Xcode package addition (BLOCKER)
  - User must add FitIQCore via Xcode GUI
  - Cannot proceed without package reference

### Blocks
- Lume production deployment with enhanced auth
- Unified auth improvements across FitIQ and Lume

---

## Success Criteria

- [ ] FitIQCore package added to Lume
- [ ] Local AuthToken deleted
- [ ] All references updated to FitIQCore.AuthToken
- [ ] TokenRefreshClient integrated into DI
- [ ] RemoteAuthService simplified (~50 lines removed)
- [ ] AuthRepository simplified (~50 lines removed)
- [ ] All tests passing
- [ ] Manual testing complete
- [ ] No user session disruptions
- [ ] Build successful

---

## Next Steps

1. **IMMEDIATE:** User must add FitIQCore package via Xcode
   - Open lume.xcodeproj in Xcode
   - File > Add Package Dependencies > Add Local > ../FitIQCore
   
2. **After Package Added:** Follow migration phases 2-7

3. **Testing:** Comprehensive testing before production deployment

4. **Deployment:** Gradual rollout with monitoring

---

## References

- [FitIQCore README](../../FitIQCore/README.md)
- [FitIQCore CHANGELOG](../../FitIQCore/CHANGELOG.md)
- [FitIQ Auth Migration](./FITIQ_AUTH_MIGRATION.md) - Same pattern
- [FitIQCore Phase 1 Complete](./FITIQCORE_PHASE1_COMPLETE.md)
- [Authentication Enhancement Design](./AUTHENTICATION_ENHANCEMENT_DESIGN.md)

---

## Notes

- Lume is production-ready, test thoroughly
- FitIQCore.AuthToken is more robust (JWT parsing, validation)
- TokenRefreshClient is thread-safe (better than current)
- No UI changes required
- No API contract changes
- Backward compatible with existing tokens

---

**Status:** Ready to start after package setup  
**Estimated Time:** 2-3 hours  
**Priority:** High (production app)  
**Complexity:** Medium (blocked by manual Xcode step)