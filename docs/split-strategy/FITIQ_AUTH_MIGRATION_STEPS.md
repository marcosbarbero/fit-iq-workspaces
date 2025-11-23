# FitIQ Authentication Migration - Step-by-Step Guide

**Date:** 2025-01-27  
**Status:** 🟡 Ready to Execute  
**Estimated Time:** 4-6 hours  
**Difficulty:** Medium

---

## 📋 Overview

This guide migrates FitIQ from manual JWT parsing to FitIQCore's automated AuthToken system.

### What Will Change

**Current State:**
- Manual JWT parsing in `UserAuthAPIClient` (~50 lines)
- Individual token strings stored in Keychain
- Manual extraction of user_id and email from JWT

**After Migration:**
- Use `FitIQCore.AuthToken` with automatic JWT parsing
- Simplified token handling
- Consistent with Lume's implementation
- ~50 lines of duplicated code removed

### What Won't Change

- FitIQ's `AuthManager` (app-specific state management)
- Keychain storage approach (separate access/refresh tokens)
- Authentication flow logic
- User-facing behavior

---

## 🎯 Migration Steps

### Step 1: Update UserAuthAPIClient to Use AuthToken (2-3 hours)

#### 1.1: Import FitIQCore at top of file

**File:** `FitIQ/FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`

Already done ✅ (line 9: `import FitIQCore`)

#### 1.2: Remove Manual JWT Parsing Methods

**Delete these methods (lines ~35-80):**
```swift
// ❌ DELETE THIS METHOD
private func decodeUserIdFromJWT(_ token: String) -> String? {
    let segments = token.split(separator: ".")
    guard segments.count == 3 else { return nil }
    // ... ~20 lines of base64 decoding ...
}

// ❌ DELETE THIS METHOD  
private func extractEmailFromJWT(_ token: String) -> String? {
    let segments = token.split(separator: ".")
    guard segments.count == 3 else { return nil }
    // ... ~20 lines of base64 decoding ...
}
```

**Why:** FitIQCore.AuthToken handles this automatically.

#### 1.3: Update `register` Method

**Find the `register` method (around line 90-140)**

**Current code:**
```swift
func register(credentials: RegistrationCredentials) async throws -> String {
    // ... network request code ...
    
    // Save tokens
    try authTokenPersistence.save(
        accessToken: registerResponseDTO.accessToken,
        refreshToken: registerResponseDTO.refreshToken
    )
    
    // Manual JWT parsing
    guard let userId = decodeUserIdFromJWT(registerResponseDTO.accessToken) else {
        throw APIError.invalidResponse
    }
    
    return userId
}
```

**Replace with:**
```swift
func register(credentials: RegistrationCredentials) async throws -> String {
    // ... keep network request code unchanged ...
    
    // Create AuthToken (automatically parses JWT)
    let authToken = try AuthToken(
        accessToken: registerResponseDTO.accessToken,
        refreshToken: registerResponseDTO.refreshToken
    )
    
    // Save tokens
    try authTokenPersistence.save(
        accessToken: authToken.accessToken,
        refreshToken: authToken.refreshToken
    )
    
    // Use parsed user_id from AuthToken
    guard let userId = authToken.userId else {
        throw APIError.invalidResponse
    }
    
    return userId
}
```

**Changes:**
- ✅ Create `AuthToken` from response tokens
- ✅ JWT parsing happens automatically
- ✅ Use `authToken.userId` instead of manual parsing
- ✅ Validation happens in AuthToken initializer

#### 1.4: Update `login` Method

**Find the `login` method (around line 150-220)**

**Current code:**
```swift
func login(credentials: UserCredentials) async throws -> UUID {
    // ... network request code ...
    
    // Save tokens
    try authTokenPersistence.save(
        accessToken: loginResponseDTO.accessToken,
        refreshToken: loginResponseDTO.refreshToken
    )
    
    // Manual JWT parsing
    guard let userId = decodeUserIdFromJWT(loginResponseDTO.accessToken) else {
        throw APIError.invalidResponse
    }
    
    // Create or fetch user profile
    let email = extractEmailFromJWT(loginResponseDTO.accessToken) ?? credentials.email
    let userProfile = try await userProfileStorage.fetchUserProfile(userId: userId)
    // ... rest of method ...
}
```

**Replace with:**
```swift
func login(credentials: UserCredentials) async throws -> UUID {
    // ... keep network request code unchanged ...
    
    // Create AuthToken (automatically parses JWT)
    let authToken = try AuthToken(
        accessToken: loginResponseDTO.accessToken,
        refreshToken: loginResponseDTO.refreshToken
    )
    
    // Save tokens
    try authTokenPersistence.save(
        accessToken: authToken.accessToken,
        refreshToken: authToken.refreshToken
    )
    
    // Use parsed user_id from AuthToken
    guard let userId = authToken.userId else {
        throw APIError.invalidResponse
    }
    
    // Create or fetch user profile
    let email = authToken.email ?? credentials.email
    let userProfile = try await userProfileStorage.fetchUserProfile(userId: userId)
    // ... keep rest of method unchanged ...
}
```

**Changes:**
- ✅ Create `AuthToken` from response tokens
- ✅ Use `authToken.userId` instead of manual parsing
- ✅ Use `authToken.email` instead of manual extraction
- ✅ Fallback to credentials.email if not in token

#### 1.5: Update `refreshToken` Method (if exists)

**Find the `refreshToken` method (if it exists)**

**Current approach:**
```swift
func refreshToken() async throws {
    let currentRefreshToken = try authTokenPersistence.fetchRefreshToken()
    
    // Call TokenRefreshClient
    let response = try await tokenRefreshClient.refreshToken(refreshToken: currentRefreshToken)
    
    // Save new tokens
    try authTokenPersistence.save(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken
    )
}
```

**No change needed** - This already uses TokenRefreshClient from FitIQCore ✅

---

### Step 2: Verify All JWT Parsing is Removed (30 min)

#### 2.1: Search for Remaining Manual JWT Parsing

```bash
cd /Users/marcosbarbero/Develop/GitHub/fit-iq-workspaces/FitIQ

# Search for manual JWT parsing
grep -r "split(separator: \".\")" --include="*.swift" .
grep -r "base64Encoded" --include="*.swift" . | grep -i jwt
grep -r "components(separatedBy:" --include="*.swift" . | grep token

# Should return no results (or only legitimate base64 usage)
```

#### 2.2: Search for Usage of Deleted Methods

```bash
# Search for calls to deleted methods
grep -r "decodeUserIdFromJWT\|extractEmailFromJWT" --include="*.swift" .

# Should return no results after migration
```

---

### Step 3: Update NetworkClient if Needed (1-2 hours)

#### 3.1: Check if FitIQ has Custom NetworkClient

```bash
find FitIQ -name "*NetworkClient*.swift" -type f
```

**If URLSessionNetworkClient exists locally:**
- Compare with `FitIQCore/Sources/FitIQCore/Network/URLSessionNetworkClient.swift`
- If FitIQ's version has same functionality, delete it
- Replace imports with `import FitIQCore`

**If FitIQ has extensions or customizations:**
- Keep FitIQ-specific extensions
- Use FitIQCore's base URLSessionNetworkClient
- Move FitIQ-specific code to extensions

#### 3.2: Update NetworkClientProtocol References

**Files to check:**
- `FitIQ/FitIQ/Infrastructure/Network/UserAuthAPIClient.swift` ✅ (already uses it)
- Any other API clients in `FitIQ/FitIQ/Infrastructure/Network/`

**Verify:**
```swift
import FitIQCore

// Use FitIQCore's protocol
let networkClient: NetworkClientProtocol = URLSessionNetworkClient()
```

---

### Step 4: Build and Test (1-2 hours)

#### 4.1: Clean Build

```bash
cd /Users/marcosbarbero/Develop/GitHub/fit-iq-workspaces
open RootWorkspace.xcworkspace

# In Xcode:
# 1. Select FitIQ scheme
# 2. Product → Clean Build Folder (⌘⇧K)
# 3. Product → Build (⌘B)
```

**Expected:** Build succeeds with 0 errors

#### 4.2: Fix Compilation Errors (if any)

**Common issues:**

**Issue:** "Cannot find 'AuthToken' in scope"
```swift
// Fix: Add import
import FitIQCore
```

**Issue:** "Value of type 'AuthToken' has no member 'userId'"
```swift
// Fix: AuthToken.userId is Optional
guard let userId = authToken.userId else {
    throw APIError.invalidResponse
}

// Or use sub (same thing)
guard let userId = authToken.sub else {
    throw APIError.invalidResponse
}
```

**Issue:** "Ambiguous use of 'AuthToken'"
```swift
// Fix: Explicitly use FitIQCore version
let authToken = try FitIQCore.AuthToken(
    accessToken: response.accessToken,
    refreshToken: response.refreshToken
)
```

#### 4.3: Run Unit Tests

```bash
# In Xcode:
# 1. Select FitIQTests scheme
# 2. Product → Test (⌘U)
```

**If tests fail:**
- Update test imports to include `@testable import FitIQCore`
- Update mocks to use FitIQCore types
- Fix any broken assertions

#### 4.4: Manual Testing Checklist

**Test Registration Flow:**
- [ ] Open FitIQ app
- [ ] Tap "Create Account"
- [ ] Enter email, password, name
- [ ] Tap "Register"
- [ ] Verify: User is registered and logged in
- [ ] Check Console: No JWT parsing errors
- [ ] Verify: User profile ID is saved

**Test Login Flow:**
- [ ] Open FitIQ app (logged out)
- [ ] Tap "Login"
- [ ] Enter existing credentials
- [ ] Tap "Login"
- [ ] Verify: User is logged in
- [ ] Check Console: No JWT parsing errors
- [ ] Verify: User data loads correctly

**Test Token Refresh:**
- [ ] Leave app open for 10+ minutes
- [ ] Make an API request (e.g., log workout)
- [ ] Check Console: Token refresh logs
- [ ] Verify: Request succeeds with refreshed token

**Test Logout:**
- [ ] Tap "Logout" in app
- [ ] Verify: User is logged out
- [ ] Verify: Tokens are deleted from Keychain
- [ ] Verify: Login screen is shown

---

### Step 5: Cleanup and Documentation (30 min)

#### 5.1: Remove Dead Code

**Verify these methods are deleted:**
```bash
# Should return no results
grep -r "decodeUserIdFromJWT\|extractEmailFromJWT" FitIQ --include="*.swift"
```

#### 5.2: Update Comments

**In UserAuthAPIClient.swift, add comment:**
```swift
// Uses FitIQCore.AuthToken for automatic JWT parsing
// No manual parsing needed - AuthToken extracts user_id, email, exp automatically
```

#### 5.3: Git Commit

```bash
cd /Users/marcosbarbero/Develop/GitHub/fit-iq-workspaces/FitIQ

git add .
git commit -m "feat: Migrate FitIQ authentication to use FitIQCore.AuthToken

- Replace manual JWT parsing with FitIQCore.AuthToken
- Use automatic user_id and email extraction
- Remove ~50 lines of duplicated JWT parsing code
- Consistent with Lume's authentication implementation
- All tests passing

Part of Phase 1.5: FitIQCore Integration"
```

#### 5.4: Update Documentation

**Create/Update:** `FitIQ/docs/architecture/AUTHENTICATION.md`

```markdown
# Authentication Architecture

FitIQ uses FitIQCore's AuthToken for authentication:

- **JWT Parsing:** Automatic via FitIQCore.AuthToken
- **Token Storage:** Keychain via KeychainAuthTokenAdapter
- **Token Refresh:** Automatic via FitIQCore.TokenRefreshClient
- **User ID Extraction:** authToken.userId (from JWT sub claim)
- **Email Extraction:** authToken.email (from JWT email claim)

See: FitIQCore/Sources/FitIQCore/Auth/Domain/AuthToken.swift
```

---

## ✅ Verification Checklist

After completing all steps:

- [ ] ✅ Build succeeds with 0 errors
- [ ] ✅ All unit tests pass
- [ ] ✅ Manual JWT parsing methods deleted
- [ ] ✅ `decodeUserIdFromJWT` method removed
- [ ] ✅ `extractEmailFromJWT` method removed
- [ ] ✅ Registration flow works
- [ ] ✅ Login flow works
- [ ] ✅ Token refresh works
- [ ] ✅ Logout works
- [ ] ✅ No JWT parsing errors in Console
- [ ] ✅ ~50 lines of code removed
- [ ] ✅ Changes committed to git
- [ ] ✅ Documentation updated

---

## 📊 Expected Impact

### Code Reduction

| Component | Before | After | Removed |
|-----------|--------|-------|---------|
| JWT Parsing Methods | ~50 lines | 0 lines | 50 lines |
| Token Creation | ~10 lines | ~5 lines | 5 lines |
| User ID Extraction | ~3 lines | ~3 lines | 0 lines |
| **Total** | **~63 lines** | **~8 lines** | **~55 lines** |

### Quality Improvements

- ✅ **Automatic JWT validation** - Invalid tokens caught early
- ✅ **Automatic expiration parsing** - No conservative defaults
- ✅ **Consistent with Lume** - Same auth pattern across apps
- ✅ **Less error-prone** - No manual base64 decoding
- ✅ **Better tested** - FitIQCore has 38 AuthToken tests

---

## 🚨 Troubleshooting

### Build Errors

**"Cannot find 'AuthToken' in scope"**
```swift
// Add import at top of file
import FitIQCore
```

**"Ambiguous use of 'AuthToken'"**
```swift
// Use explicit namespace
let authToken = try FitIQCore.AuthToken(...)
```

### Runtime Errors

**"Invalid JWT format"**
- Check backend is returning valid JWT tokens
- Verify tokens have 3 segments (header.payload.signature)
- Check tokens are not empty or corrupted

**"Failed to parse JWT"**
- Verify JWT payload contains required claims (sub, exp)
- Check base64 encoding is correct
- Verify tokens are not encrypted (should be signed JWTs)

### Test Failures

**"Mock AuthToken not working"**
```swift
// Create mock token for tests
let mockToken = try AuthToken(
    accessToken: "header.eyJzdWIiOiJ1c2VyMTIzIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiZXhwIjoxNzM4MDAwMDAwfQ.signature",
    refreshToken: "refresh_token"
)

// Or use test helper from FitIQCore
```

---

## 📚 Related Documents

- [FitIQCore AuthToken Documentation](../../FitIQCore/Sources/FitIQCore/Auth/Domain/AuthToken.swift)
- [FitIQCore README](../../FitIQCore/README.md)
- [Lume Auth Migration Complete](./LUME_MIGRATION_COMPLETE.md) (reference implementation)
- [Phase 1.5 Status](./PHASE_1_5_STATUS.md)

---

## 🎯 Next Steps After Completion

1. ✅ Complete auth migration (this document)
2. ⏳ Update network clients (if needed)
3. ⏳ Remove any remaining duplicated code
4. ⏳ Deploy to TestFlight for validation
5. ⏳ Begin Phase 2: HealthKit extraction

---

**Status:** Ready to execute  
**Estimated Time:** 4-6 hours  
**Confidence:** High (Lume took 30 minutes, FitIQ should be similar)