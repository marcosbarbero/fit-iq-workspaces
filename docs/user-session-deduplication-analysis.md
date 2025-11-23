# User Session & ID Storage Deduplication Analysis

**Date:** 2025-01-27  
**Status:** 🔍 Analysis Complete | ⏳ Migration Pending  
**Priority:** High (Security & Code Quality)

---

## Executive Summary

Both **Lume** and **FitIQ** maintain separate implementations for storing and accessing the current user's ID. This analysis identifies the duplication, security concerns, and proposes a migration path to consolidate user session management in **FitIQCore**.

### Key Findings

- ✅ **FitIQ** uses FitIQCore's `AuthManager` with **Keychain storage** (secure)
- ⚠️ **Lume** uses custom `UserSession` with **UserDefaults storage** (less secure)
- 🔄 **Duplication:** ~165 lines of duplicated user session logic
- 🔒 **Security Issue:** User IDs should be stored in Keychain, not UserDefaults

---

## Current Implementation Comparison

### Lume: UserSession (UserDefaults)

**Location:** `lume/Core/UserSession.swift`

**Storage:**
```swift
// Stored in UserDefaults (not secure)
private enum Keys {
    static let userId = "lume.user.id"
    static let userEmail = "lume.user.email"
    static let userName = "lume.user.name"
    static let dateOfBirth = "lume.user.dateOfBirth"
    static let isAuthenticated = "lume.user.isAuthenticated"
}
```

**Access Pattern:**
```swift
// Singleton with thread-safe access
UserSession.shared.currentUserId  // UUID?
UserSession.shared.currentUserEmail  // String?
UserSession.shared.startSession(userId:email:name:dateOfBirth:)
UserSession.shared.endSession()
```

**Features:**
- ✅ Thread-safe (dispatch queue)
- ✅ Singleton pattern
- ✅ Stores user profile data (email, name, dob)
- ❌ Uses UserDefaults (less secure)
- ❌ Separate from auth token storage

**Usage Pattern:**
```swift
// Repositories conform to protocol
protocol UserAuthenticatedRepository {
    func getCurrentUserId() throws -> UUID
}

// Default implementation
extension UserAuthenticatedRepository {
    func getCurrentUserId() throws -> UUID {
        guard let userId = UserSession.shared.currentUserId else {
            throw RepositoryAuthError.notAuthenticated
        }
        return userId
    }
}
```

**Files Using UserSession:**
- `AIInsightRepository.swift`
- `ChatRepository.swift`
- `GoalRepository.swift`
- `MoodRepository.swift`
- `StatisticsRepository.swift`
- `SwiftDataJournalRepository.swift`
- `RepositoryUserSession.swift` (protocol definition)

---

### FitIQ: AuthManager (Keychain)

**Location:** `FitIQCore/Sources/FitIQCore/Auth/Domain/AuthManager.swift`

**Storage:**
```swift
// Stored in Keychain (secure)
// Via KeychainAuthTokenStorage
private enum KeychainKey: String {
    case userProfileID = "com.marcosbarbero.FitIQ.userProfileID"
    // Also stores tokens in keychain
}
```

**Access Pattern:**
```swift
// Injected AuthManager instance
authManager.currentUserProfileID  // UUID?
authManager.handleSuccessfulAuth(userProfileID: UUID)
authManager.logout()
authManager.checkAuthenticationStatus()
```

**Features:**
- ✅ Keychain storage (secure)
- ✅ Integrated with token storage
- ✅ Observable (Combine/SwiftUI)
- ✅ State machine for auth flow
- ❌ Doesn't store user profile data (email, name)
- ✅ Already in FitIQCore (shared)

**Usage Pattern:**
```swift
// Use cases access directly
guard let currentUserID = authManager.currentUserProfileID else {
    throw UserProfileError.notAuthenticated
}

// Or string version
guard let userID = authManager.currentUserProfileID?.uuidString else {
    throw Error.userNotAuthenticated
}
```

**Files Using AuthManager in FitIQ:**
- 50+ use cases and services
- All access `authManager.currentUserProfileID`
- Consistent pattern across entire app

---

## Security Analysis

### Current Security Posture

| Aspect | Lume (UserDefaults) | FitIQ (Keychain) | Risk Level |
|--------|---------------------|------------------|------------|
| **User ID Storage** | UserDefaults (plain text) | Keychain (encrypted) | 🔴 High |
| **Access Control** | No system protection | Keychain ACL protected | 🔴 High |
| **Backup Handling** | Included in iCloud backups | Can be excluded | 🟡 Medium |
| **Process Isolation** | Accessible by debugger | Protected by system | 🔴 High |
| **Data at Rest** | Plain text on disk | Encrypted by system | 🔴 High |

### Security Concerns with UserDefaults

1. **Plain Text Storage:**
   - User IDs stored in `.plist` file in app's Documents directory
   - Readable with simple file access or device backup extraction
   - Not encrypted at rest

2. **No Access Control:**
   - Any process with file system access can read
   - Vulnerable to jailbreak/root access attacks
   - No hardware-backed security

3. **Backup Exposure:**
   - Included in iTunes/iCloud backups by default
   - User IDs exposed if backup is compromised

4. **Debugging Risk:**
   - Visible in debugger/memory inspection
   - Logged in crash reports if accidentally printed

### Keychain Benefits

1. **System-Level Encryption:**
   - Hardware-backed encryption on supported devices
   - Encrypted at rest automatically

2. **Access Control Lists (ACL):**
   - Only accessible by the app that stored it
   - Protected from other processes

3. **Secure Backup:**
   - Can be configured to not backup (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
   - If backed up, encrypted in backup

4. **System Integration:**
   - Uses iOS Secure Enclave when available
   - Integrated with device passcode/biometrics

### Recommendation

**Action:** Migrate Lume's user ID storage from UserDefaults to Keychain via FitIQCore's AuthManager.

**Rationale:**
- User IDs are personally identifiable information (PII)
- Should be stored securely like access tokens
- FitIQCore already provides secure storage mechanism
- Eliminates code duplication
- Improves overall security posture

---

## Code Duplication Metrics

### Lines of Code

| Component | Location | Lines | Purpose |
|-----------|----------|-------|---------|
| **Lume UserSession** | `lume/Core/UserSession.swift` | 165 | User session management |
| **Lume Protocol** | `lume/Data/Repositories/RepositoryUserSession.swift` | 140 | Repository helper protocol |
| **FitIQ Usage** | Various use cases | N/A | Direct AuthManager usage |
| **FitIQCore AuthManager** | `FitIQCore/Auth/Domain/AuthManager.swift` | 210 | Auth state + user ID management |

**Total Duplicated Logic:** ~305 lines (UserSession + Protocol vs. AuthManager usage)

### Feature Comparison

| Feature | Lume UserSession | FitIQCore AuthManager |
|---------|------------------|----------------------|
| User ID Storage | ✅ UserDefaults | ✅ Keychain |
| Thread Safety | ✅ Dispatch queue | ✅ MainActor |
| Email Storage | ✅ | ❌ |
| Name Storage | ✅ | ❌ |
| Date of Birth Storage | ✅ | ❌ |
| Auth State Machine | ❌ | ✅ |
| Onboarding Tracking | ❌ | ✅ |
| Observable | ❌ | ✅ @Published |
| Token Integration | ❌ Separate | ✅ Integrated |
| Reusable | ❌ Lume-specific | ✅ FitIQCore shared |

---

## Migration Strategy

### Phase 1: Enhance FitIQCore (If Needed)

**Option A: Keep Profile Data in UserDefaults**
- User ID → Keychain (via AuthManager)
- Email, Name, DOB → UserDefaults (non-sensitive)
- Simple migration, minimal changes

**Option B: Move Everything to FitIQCore**
- Add `UserProfile` model to FitIQCore
- Store profile data in Keychain alongside user ID
- More comprehensive, better long-term solution

**Recommendation:** Start with **Option A** (pragmatic), consider **Option B** later if both apps need profile storage.

### Phase 2: Update Lume's UserSession

**Create Adapter Around AuthManager:**

```swift
// New implementation in lume/Core/UserSession.swift
import FitIQCore

final class UserSession {
    static let shared = UserSession()
    
    // Delegate to FitIQCore's AuthManager
    private let authManager: AuthManager
    private let userDefaults = UserDefaults.standard
    
    // User ID now from Keychain (via AuthManager)
    var currentUserId: UUID? {
        authManager.currentUserProfileID
    }
    
    // Profile data still in UserDefaults (non-sensitive)
    var currentUserEmail: String? {
        userDefaults.string(forKey: Keys.userEmail)
    }
    
    // ... other profile properties
    
    func startSession(userId: UUID, email: String, name: String, dateOfBirth: Date?) {
        // Store user ID in Keychain via AuthManager
        Task { @MainActor in
            await authManager.handleSuccessfulAuth(userProfileID: userId)
        }
        
        // Store profile data in UserDefaults
        userDefaults.set(email, forKey: Keys.userEmail)
        userDefaults.set(name, forKey: Keys.userName)
        // ...
    }
    
    func endSession() {
        Task { @MainActor in
            await authManager.logout()
        }
        
        // Clear profile data
        userDefaults.removeObject(forKey: Keys.userEmail)
        // ...
    }
}
```

**Changes Required:**
- ✅ User ID now stored in Keychain (secure)
- ✅ Maintains backward compatibility
- ✅ No changes needed to repositories (keep `UserAuthenticatedRepository` protocol)
- ✅ Profile data (email, name, dob) still in UserDefaults (acceptable)

### Phase 3: Update Repositories

**Option A: Keep Current Pattern (Minimal Changes)**
```swift
// Keep protocol, update implementation
extension UserAuthenticatedRepository {
    func getCurrentUserId() throws -> UUID {
        // Now reads from Keychain via AuthManager
        guard let userId = UserSession.shared.currentUserId else {
            throw RepositoryAuthError.notAuthenticated
        }
        return userId
    }
}
```

**Option B: Inject AuthManager (Better Architecture)**
```swift
// Repositories get AuthManager injected
final class MoodRepository: MoodRepositoryProtocol {
    private let authManager: AuthManager
    
    init(..., authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func save() async throws {
        guard let userId = authManager.currentUserProfileID else {
            throw RepositoryAuthError.notAuthenticated
        }
        // Use userId
    }
}
```

**Recommendation:** Start with **Option A** (less refactoring), migrate to **Option B** incrementally.

---

## Implementation Checklist

### Step 1: Enhance FitIQCore (If Needed)
- [ ] Review if profile data storage needed in FitIQCore
- [ ] Decide on Option A vs. Option B
- [ ] Update FitIQCore if choosing Option B

### Step 2: Update Lume's UserSession
- [ ] Add FitIQCore dependency to UserSession
- [ ] Inject AuthManager into UserSession
- [ ] Delegate user ID to `authManager.currentUserProfileID`
- [ ] Keep profile data in UserDefaults (Option A)
- [ ] Update `startSession()` to use `authManager.handleSuccessfulAuth()`
- [ ] Update `endSession()` to use `authManager.logout()`

### Step 3: Update DI Container
- [ ] Ensure `AppDependencies.authManager` is available
- [ ] Inject `authManager` into `UserSession`
- [ ] Verify initialization order

### Step 4: Test Migration
- [ ] Test login flow (user ID stored in Keychain)
- [ ] Test logout flow (user ID removed from Keychain)
- [ ] Test app restart (user ID persists)
- [ ] Test profile data still accessible (email, name, dob)
- [ ] Verify repositories still work with `getCurrentUserId()`

### Step 5: Security Verification
- [ ] Confirm user ID no longer in UserDefaults
- [ ] Confirm user ID in Keychain
- [ ] Test Keychain access from debugger (should be protected)
- [ ] Verify backup behavior (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)

### Step 6: Clean Up
- [ ] Remove old UserDefaults user ID key
- [ ] Add migration code if needed (read old UserDefaults, write to Keychain)
- [ ] Update documentation
- [ ] Remove redundant code

---

## Benefits of Migration

### Security Improvements
- 🔒 **User IDs in Keychain:** Hardware-backed encryption
- 🔒 **Access Control:** System-protected storage
- 🔒 **Backup Security:** Can be excluded from backups
- 🔒 **Process Isolation:** Protected from other processes

### Code Quality Improvements
- ♻️ **Eliminated Duplication:** ~305 lines of duplicated logic
- 🎯 **Single Source of Truth:** FitIQCore's AuthManager
- 🧪 **Better Testability:** Consistent mocking via AuthManager
- 📖 **Improved Maintainability:** Changes in one place

### Architecture Improvements
- 🏗️ **Consistent Pattern:** Both apps use AuthManager
- 🔗 **Integrated State:** User ID + tokens managed together
- 📊 **Observable State:** AuthManager is @Published
- 🎨 **Clean Separation:** FitIQCore handles auth concerns

---

## Risk Assessment

### Migration Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Data Loss** | High | Implement migration code to copy from UserDefaults to Keychain |
| **Breaking Changes** | Medium | Use adapter pattern to maintain `UserSession` interface |
| **State Sync Issues** | Medium | Test all login/logout flows thoroughly |
| **Keychain Errors** | Low | Handle Keychain errors gracefully, fallback to re-auth |

### Rollback Plan

If issues arise:
1. Keep old `UserSession` implementation in git history
2. Feature flag the migration
3. Test with beta users first
4. Monitor crash reports for Keychain errors
5. Can revert to UserDefaults if critical issues found

---

## Timeline Estimate

| Phase | Effort | Duration |
|-------|--------|----------|
| **Analysis** | Complete | ✅ Done |
| **FitIQCore Enhancement** | Optional | 2-4 hours |
| **Lume UserSession Update** | Required | 2-3 hours |
| **Repository Updates** | Required | 1-2 hours |
| **Testing** | Required | 3-4 hours |
| **Documentation** | Required | 1 hour |
| **Total** | | **9-14 hours** |

---

## Related Work

### Already Migrated to FitIQCore
- ✅ Authentication tokens (access + refresh)
- ✅ Token refresh logic
- ✅ Keychain storage implementation
- ✅ Auth state management

### Next Migration Candidates
1. **User Session (This Document)** - High Priority 🔴
2. Network client consolidation - Medium Priority 🟡
3. Health data models - Low Priority 🟢
4. Error handling patterns - Low Priority 🟢

---

## References

### Related Documentation
- **FitIQCore Auth:** `FitIQCore/Sources/FitIQCore/Auth/README.md`
- **Auth Migration Complete:** `docs/lume-fitiqcore-migration-complete.md`
- **Deduplication Analysis:** `docs/lume-authentication-deduplication.md`

### Code Locations
- **Lume UserSession:** `lume/Core/UserSession.swift`
- **Lume Protocol:** `lume/Data/Repositories/RepositoryUserSession.swift`
- **FitIQCore AuthManager:** `FitIQCore/Sources/FitIQCore/Auth/Domain/AuthManager.swift`
- **FitIQCore Keychain:** `FitIQCore/Sources/FitIQCore/Auth/Infrastructure/KeychainAuthTokenStorage.swift`

### Apple Documentation
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Protecting Keys with the Secure Enclave](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/protecting_keys_with_the_secure_enclave)
- [Data Storage Best Practices](https://developer.apple.com/documentation/security/storing_cryptographic_keys_in_the_keychain)

---

## Next Steps

1. **Immediate:** Review this analysis with team
2. **Short-term:** Decide on Option A vs. Option B for profile data
3. **Implementation:** Follow migration checklist
4. **Testing:** Comprehensive security and functionality testing
5. **Deployment:** Gradual rollout with monitoring

---

**Status:** 🔍 Analysis Complete | Ready for Implementation  
**Priority:** High - Security improvement + code deduplication  
**Complexity:** Medium - Adapter pattern makes it manageable  
**Risk:** Low-Medium - With proper testing and migration code

---

**Recommendation:** Proceed with migration using adapter pattern (Option A) to maintain backward compatibility while improving security.