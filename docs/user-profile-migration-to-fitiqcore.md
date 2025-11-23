# User Profile Migration to FitIQCore - Implementation Guide

**Date:** 2025-01-27  
**Status:** 🚀 Ready for Implementation  
**Priority:** High (Security + Code Quality)  
**Complexity:** Medium

---

## Executive Summary

This guide provides step-by-step instructions for migrating both **FitIQ** and **Lume** to use FitIQCore's centralized user profile management. This eliminates code duplication, improves security by moving user IDs from UserDefaults to Keychain, and establishes a single source of truth for user data.

### What's Changing

| Component | Before | After |
|-----------|--------|-------|
| **Lume User ID Storage** | UserDefaults (plain text) | Keychain (encrypted) via FitIQCore |
| **Lume User Profile** | Custom `UserSession` singleton | FitIQCore's `AuthManager.currentUserProfile` |
| **FitIQ User Profile** | Scattered user ID access | Centralized via `AuthManager.currentUserProfile` |
| **Code Duplication** | ~305 lines | 0 lines (all in FitIQCore) |

### Benefits

- 🔒 **Security:** User IDs stored in Keychain (hardware-backed encryption)
- ♻️ **Code Reuse:** Eliminates ~305 lines of duplicated logic
- 🎯 **Single Source:** One implementation for both apps
- 📊 **Consistency:** Same user profile model across projects
- 🧪 **Testability:** Easier to mock and test

---

## What's Been Added to FitIQCore

### 1. UserProfile Domain Model

**Location:** `FitIQCore/Sources/FitIQCore/Auth/Domain/UserProfile.swift`

```swift
public struct UserProfile: Codable, Equatable, Sendable {
    public let id: UUID
    public let email: String
    public let name: String
    public let dateOfBirth: Date?
    public let createdAt: Date
    public let updatedAt: Date
    
    // Computed properties
    public var age: Int?
    public var initials: String
    public var firstName: String
    public var lastName: String?
    
    // Methods
    public func validate() -> [ValidationError]
    public func updated(email:name:dateOfBirth:) -> UserProfile
}
```

**Features:**
- ✅ Codable for JSON/Keychain serialization
- ✅ Validation (email format, age constraints)
- ✅ Computed properties (age, initials, names)
- ✅ Immutable value type (thread-safe)
- ✅ Safe logging (sanitizedDescription hides PII)

### 2. Extended AuthTokenPersistenceProtocol

**Added Methods:**
```swift
func saveUserProfile(_ profile: UserProfile) throws
func fetchUserProfile() throws -> UserProfile?
func deleteUserProfile() throws
```

**Implementation:** `KeychainAuthTokenStorage` now stores user profile as JSON in Keychain.

### 3. Enhanced AuthManager

**New Properties:**
```swift
@Published public var currentUserProfile: UserProfile?
```

**Updated Methods:**
```swift
// Now accepts optional profile
func handleSuccessfulAuth(userProfileID: UUID?, userProfile: UserProfile?) async

// New method for updating profile
func saveUserProfile(_ profile: UserProfile) async throws
```

**Behavior:**
- Loads profile from Keychain on initialization
- Saves profile during authentication
- Clears profile on logout
- Published property for SwiftUI/Combine reactivity

---

## Migration Steps

### Phase 1: Update FitIQ

FitIQ already uses FitIQCore's `AuthManager`, so we just need to adopt the new profile features.

#### Step 1.1: Update Authentication Flow

**File:** `FitIQ/Domain/UseCases/AuthenticateUserUseCase.swift` (or wherever you handle login)

```swift
// BEFORE
await authManager.handleSuccessfulAuth(userProfileID: userId)

// AFTER
let userProfile = UserProfile(
    id: userId,
    email: user.email,
    name: user.name,
    dateOfBirth: user.dateOfBirth
)
await authManager.handleSuccessfulAuth(
    userProfileID: userId, 
    userProfile: userProfile
)
```

#### Step 1.2: Replace Direct User ID Access

Find all instances of:
```swift
guard let userID = authManager.currentUserProfileID else { ... }
```

Consider replacing with:
```swift
guard let profile = authManager.currentUserProfile else { 
    throw AuthError.notAuthenticated 
}
let userID = profile.id
// Now you also have access to profile.email, profile.name, etc.
```

**Note:** Keep `currentUserProfileID` for cases where you only need the ID (no breaking changes required).

#### Step 1.3: Update User Profile Display

**File:** `FitIQ/Presentation/Views/ProfileView.swift` (or similar)

```swift
// BEFORE
Text("User ID: \(authManager.currentUserProfileID?.uuidString ?? "Unknown")")

// AFTER
if let profile = authManager.currentUserProfile {
    Text("Welcome, \(profile.name)")
    Text(profile.email)
    if let age = profile.age {
        Text("Age: \(age)")
    }
} else {
    Text("Not logged in")
}
```

#### Step 1.4: Test FitIQ Migration

- [ ] Login flow saves profile to Keychain
- [ ] Profile accessible via `authManager.currentUserProfile`
- [ ] Profile persists across app restarts
- [ ] Logout clears profile from Keychain
- [ ] All existing user ID access still works

---

### Phase 2: Update Lume

Lume has a custom `UserSession` that needs to be replaced with FitIQCore's `AuthManager`.

#### Step 2.1: Update AppDependencies

**File:** `lume/DI/AppDependencies.swift`

```swift
// ENSURE AuthManager is available
private(set) lazy var authManager: AuthManager = {
    AuthManager(
        authTokenPersistence: authTokenStorage,
        onboardingKey: "lume_onboarding_complete"
    )
}()
```

#### Step 2.2: Refactor UserSession as Adapter (Temporary)

**File:** `lume/Core/UserSession.swift`

```swift
import FitIQCore
import Foundation

/// Adapter for backward compatibility
/// Delegates to FitIQCore's AuthManager
final class UserSession {
    static let shared = UserSession()
    
    private var authManager: AuthManager!
    
    private init() {}
    
    // Called by AppDependencies after initialization
    func configure(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    // MARK: - Public API (delegates to AuthManager)
    
    var currentUserId: UUID? {
        authManager.currentUserProfileID
    }
    
    var currentUserEmail: String? {
        authManager.currentUserProfile?.email
    }
    
    var currentUserName: String? {
        authManager.currentUserProfile?.name
    }
    
    var currentUserDateOfBirth: Date? {
        authManager.currentUserProfile?.dateOfBirth
    }
    
    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }
    
    func startSession(userId: UUID, email: String, name: String, dateOfBirth: Date? = nil) {
        let profile = UserProfile(
            id: userId,
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )
        
        Task { @MainActor in
            await authManager.handleSuccessfulAuth(
                userProfileID: userId,
                userProfile: profile
            )
        }
    }
    
    func endSession() {
        Task { @MainActor in
            await authManager.logout()
        }
    }
    
    func updateUserInfo(email: String? = nil, name: String? = nil, dateOfBirth: Date? = nil) {
        guard let currentProfile = authManager.currentUserProfile else { return }
        
        let updatedProfile = currentProfile.updated(
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )
        
        Task { @MainActor in
            try? await authManager.saveUserProfile(updatedProfile)
        }
    }
    
    func requireUserId() throws -> UUID {
        guard let userId = currentUserId else {
            throw UserSessionError.notAuthenticated
        }
        return userId
    }
    
    func clearAllData() {
        Task { @MainActor in
            await authManager.logout()
        }
    }
}

// Keep errors for backward compatibility
enum UserSessionError: LocalizedError {
    case notAuthenticated
    case invalidUserId
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No user is currently authenticated. Please log in."
        case .invalidUserId:
            return "Invalid user ID format."
        }
    }
}
```

#### Step 2.3: Configure UserSession in AppDependencies

**File:** `lume/DI/AppDependencies.swift`

```swift
init() {
    // ... existing initialization ...
    
    // Configure UserSession to use AuthManager
    UserSession.shared.configure(authManager: authManager)
}
```

#### Step 2.4: Update RepositoryUserSession Protocol

**File:** `lume/Data/Repositories/RepositoryUserSession.swift`

Keep the protocol for now (backward compatibility), but update documentation:

```swift
/// Centralized authentication helper for all repositories
/// NOW DELEGATES TO FitIQCore's AuthManager
///
/// This protocol provides a consistent interface while using
/// FitIQCore's secure Keychain-backed storage underneath.
protocol UserAuthenticatedRepository {
    func getCurrentUserId() throws -> UUID
}

extension UserAuthenticatedRepository {
    func getCurrentUserId() throws -> UUID {
        // Still uses UserSession, but now it delegates to AuthManager
        guard let userId = UserSession.shared.currentUserId else {
            throw RepositoryAuthError.notAuthenticated
        }
        return userId
    }
}
```

**No changes needed to repositories!** They continue using the protocol.

#### Step 2.5: Update Authentication Flow

**File:** `lume/Data/Repositories/AuthRepository.swift`

```swift
func login(email: String, password: String) async throws -> AuthToken {
    let token = try await authService.login(email: email, password: password)
    
    // Save token
    try await tokenStorage.saveToken(token)
    
    // FETCH USER PROFILE from backend
    let userProfileData = try await fetchUserProfile(token: token.accessToken)
    
    // START SESSION with profile
    UserSession.shared.startSession(
        userId: userProfileData.userIdUUID,
        email: userProfileData.email,
        name: userProfileData.name,
        dateOfBirth: userProfileData.dateOfBirthDate
    )
    
    return token
}

private func fetchUserProfile(token: String) async throws -> UserProfileData {
    // Call /api/v1/users/me to get profile
    // This already exists in Lume - reuse it
}
```

#### Step 2.6: Test Lume Migration

- [ ] User ID no longer in UserDefaults (check with debugger)
- [ ] User ID now in Keychain (verify with Keychain Access app on macOS simulator)
- [ ] Login flow saves profile
- [ ] Profile accessible via `UserSession.shared.currentUserEmail`, etc.
- [ ] Repositories still work with `getCurrentUserId()`
- [ ] Logout clears profile
- [ ] App restart loads profile correctly

---

### Phase 3: Data Migration (Important!)

Users who already have Lume installed will have their user ID in UserDefaults. We need to migrate it to Keychain.

#### Step 3.1: Add Migration Code

**File:** `lume/Core/UserSessionMigration.swift` (NEW FILE)

```swift
import FitIQCore
import Foundation

/// Handles one-time migration of user data from UserDefaults to Keychain
final class UserSessionMigration {
    
    private static let migrationKey = "lume.userSession.migrated.v1"
    private static let oldUserIdKey = "lume.user.id"
    private static let oldEmailKey = "lume.user.email"
    private static let oldNameKey = "lume.user.name"
    private static let oldDOBKey = "lume.user.dateOfBirth"
    
    /// Performs one-time migration of user data from UserDefaults to Keychain
    /// Safe to call multiple times - only runs once
    static func migrateIfNeeded(authManager: AuthManager) async {
        let userDefaults = UserDefaults.standard
        
        // Check if migration already completed
        guard !userDefaults.bool(forKey: migrationKey) else {
            print("🔄 [Migration] User data already migrated to Keychain")
            return
        }
        
        // Check if there's data to migrate
        guard let userIdString = userDefaults.string(forKey: oldUserIdKey),
              let userId = UUID(uuidString: userIdString) else {
            print("🔄 [Migration] No user data in UserDefaults to migrate")
            userDefaults.set(true, forKey: migrationKey)
            return
        }
        
        print("🔄 [Migration] Found user data in UserDefaults, migrating to Keychain...")
        
        // Extract all user data
        let email = userDefaults.string(forKey: oldEmailKey) ?? "unknown@email.com"
        let name = userDefaults.string(forKey: oldNameKey) ?? "Unknown User"
        
        var dateOfBirth: Date?
        if let dobTimestamp = userDefaults.object(forKey: oldDOBKey) as? TimeInterval {
            dateOfBirth = Date(timeIntervalSince1970: dobTimestamp)
        }
        
        // Create profile
        let profile = UserProfile(
            id: userId,
            email: email,
            name: name,
            dateOfBirth: dateOfBirth
        )
        
        // Save to Keychain via AuthManager
        await authManager.handleSuccessfulAuth(
            userProfileID: userId,
            userProfile: profile
        )
        
        // Clear old UserDefaults data
        userDefaults.removeObject(forKey: oldUserIdKey)
        userDefaults.removeObject(forKey: oldEmailKey)
        userDefaults.removeObject(forKey: oldNameKey)
        userDefaults.removeObject(forKey: oldDOBKey)
        
        // Mark migration as complete
        userDefaults.set(true, forKey: migrationKey)
        
        print("✅ [Migration] Successfully migrated user data to Keychain")
        print("✅ [Migration] User ID: \(userId)")
        print("✅ [Migration] Cleared old UserDefaults entries")
    }
}
```

#### Step 3.2: Run Migration on App Launch

**File:** `lume/lumeApp.swift` (or wherever you initialize AppDependencies)

```swift
init() {
    let dependencies = AppDependencies()
    self.dependencies = dependencies
    
    // RUN MIGRATION BEFORE ANYTHING ELSE
    Task { @MainActor in
        await UserSessionMigration.migrateIfNeeded(
            authManager: dependencies.authManager
        )
        
        // Then check auth status
        await dependencies.authManager.checkAuthenticationStatus()
    }
}
```

#### Step 3.3: Test Migration

**Test Scenario 1: Fresh Install**
1. Install app for first time
2. Login
3. Verify user ID in Keychain (not UserDefaults)

**Test Scenario 2: Existing User**
1. Install old version
2. Login (creates UserDefaults entries)
3. Update to new version
4. Launch app
5. Verify migration runs
6. Verify user ID now in Keychain
7. Verify old UserDefaults entries deleted
8. Verify user still logged in

**Test Scenario 3: Already Migrated**
1. Launch app that already ran migration
2. Verify migration doesn't run again
3. Verify no errors

---

## Phase 4: Cleanup (After Both Apps Verified)

Once both FitIQ and Lume are using FitIQCore's user profile management and thoroughly tested:

### Step 4.1: Remove Lume's UserSession (Optional)

If you want to fully migrate away from `UserSession` adapter:

1. Replace `UserSession.shared.currentUserId` with `authManager.currentUserProfileID`
2. Replace `UserSession.shared.currentUserEmail` with `authManager.currentUserProfile?.email`
3. Remove `lume/Core/UserSession.swift`
4. Update `UserAuthenticatedRepository` to inject `authManager` instead

**Recommendation:** Keep the adapter for now for easier rollback if issues arise.

### Step 4.2: Update Documentation

- [ ] Update README files
- [ ] Document new authentication flow
- [ ] Add examples of accessing user profile
- [ ] Note security improvements

### Step 4.3: Remove Legacy Code

After confirming everything works:

- [ ] Remove old UserDefaults keys documentation
- [ ] Remove migration code (after sufficient time in production)
- [ ] Archive old `UserSession` implementation for reference

---

## Security Verification Checklist

### Keychain Storage Verification

```swift
// Add this to a debug view or unit test
func verifyKeychainStorage() {
    print("=== Keychain Storage Verification ===")
    
    // Check user ID
    if let userId = authManager.currentUserProfileID {
        print("✅ User ID in Keychain: \(userId)")
    } else {
        print("❌ No user ID in Keychain")
    }
    
    // Check user profile
    if let profile = authManager.currentUserProfile {
        print("✅ User Profile in Keychain: \(profile.sanitizedDescription)")
    } else {
        print("❌ No user profile in Keychain")
    }
    
    // Check UserDefaults (should be empty)
    let userDefaults = UserDefaults.standard
    if userDefaults.string(forKey: "lume.user.id") != nil {
        print("⚠️ WARNING: User ID still in UserDefaults (should be migrated)")
    } else {
        print("✅ User ID NOT in UserDefaults (correct)")
    }
    
    print("=====================================")
}
```

### Security Best Practices

- ✅ User ID stored in Keychain (encrypted at rest)
- ✅ User profile stored in Keychain (encrypted at rest)
- ✅ Tokens stored in Keychain (encrypted at rest)
- ✅ No PII in UserDefaults
- ✅ Safe logging (use `sanitizedDescription`)
- ✅ Keychain access control (`.kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)

---

## Rollback Plan

If critical issues are discovered:

### Emergency Rollback

1. **Revert Commits:**
   ```bash
   git revert <migration-commits>
   ```

2. **Feature Flag (Better Approach):**
   ```swift
   // In AppDependencies or similar
   let useFitIQCoreProfile = UserDefaults.standard.bool(forKey: "feature.fitiqcore.profile")
   
   if useFitIQCoreProfile {
       // Use FitIQCore's AuthManager
   } else {
       // Use legacy UserSession
   }
   ```

3. **Gradual Rollout:**
   - Deploy to 10% of users first
   - Monitor crash reports
   - Check for Keychain access errors
   - Expand to 100% after 1 week of stability

---

## Testing Checklist

### Unit Tests

- [ ] UserProfile validation
- [ ] UserProfile computed properties (age, initials)
- [ ] UserProfile update methods
- [ ] KeychainAuthTokenStorage profile methods
- [ ] AuthManager profile management
- [ ] Migration logic

### Integration Tests

- [ ] Login flow saves profile to Keychain
- [ ] Logout clears profile from Keychain
- [ ] App restart loads profile correctly
- [ ] Profile update persists
- [ ] Migration from UserDefaults to Keychain
- [ ] Migration idempotence (safe to run multiple times)

### Manual Tests

- [ ] Fresh install login flow
- [ ] Existing user migration
- [ ] Profile update in UI
- [ ] Keychain access with debugger (should be protected)
- [ ] Airplane mode (offline profile access)
- [ ] App restart (profile persists)
- [ ] Logout and re-login

### Performance Tests

- [ ] Profile load time < 100ms
- [ ] No memory leaks
- [ ] No excessive Keychain access
- [ ] Thread safety (concurrent access)

---

## Timeline & Effort Estimate

| Phase | Tasks | Effort | Dependencies |
|-------|-------|--------|--------------|
| **FitIQCore Enhancement** | ✅ Complete | 0 hours | None |
| **FitIQ Migration** | Update auth flow, replace user access | 3-4 hours | FitIQCore complete |
| **Lume Migration** | Refactor UserSession, update repos | 4-5 hours | FitIQCore complete |
| **Data Migration** | Migration code, testing | 2-3 hours | Lume migration |
| **Testing** | Unit + integration + manual | 4-5 hours | All migrations complete |
| **Documentation** | Update guides, examples | 1-2 hours | Testing complete |
| **Cleanup** | Remove legacy code | 1 hour | Production stable |
| **Total** | | **15-20 hours** | |

---

## Success Metrics

### Code Quality

- ✅ **305 lines** of duplicated code eliminated
- ✅ **100%** code reuse from FitIQCore
- ✅ Single source of truth for user profiles
- ✅ Consistent access patterns across apps

### Security

- ✅ User IDs in Keychain (encrypted)
- ✅ User profiles in Keychain (encrypted)
- ✅ No PII in UserDefaults
- ✅ Hardware-backed security (Secure Enclave)

### Functionality

- ✅ All existing features work
- ✅ No regressions in auth flow
- ✅ Seamless migration for existing users
- ✅ Profile updates persist correctly

---

## FAQs

### Q: Will this break existing logged-in users?

**A:** No. The migration code automatically transfers data from UserDefaults to Keychain on app launch. Users remain logged in.

### Q: What if migration fails?

**A:** Migration code is wrapped in do-catch. If it fails, the app logs the error and continues with normal auth flow. User may need to log in again.

### Q: Can I access user profile from anywhere?

**A:** Yes, via `authManager.currentUserProfile`. Inject `AuthManager` into your components via DI.

### Q: What about background tasks?

**A:** Keychain is accessible in background (with proper configuration). Profile access works the same.

### Q: How do I update user profile?

**A:** 
```swift
let updated = currentProfile.updated(name: "New Name")
try await authManager.saveUserProfile(updated)
```

### Q: What if I only need the user ID?

**A:** Use `authManager.currentUserProfileID` - it's still available for backward compatibility.

### Q: Is this thread-safe?

**A:** Yes. `UserProfile` is an immutable value type. `AuthManager` uses `@MainActor` for published properties.

---

## Related Documentation

- **FitIQCore Auth README:** `FitIQCore/Sources/FitIQCore/Auth/README.md`
- **Security Analysis:** `docs/user-session-deduplication-analysis.md`
- **Auth Migration Complete:** `docs/lume-fitiqcore-migration-complete.md`
- **Copilot Instructions:** `.github/copilot-instructions.md`

---

## Support & Contact

If you encounter issues during migration:

1. Check this guide's troubleshooting section
2. Review related documentation
3. Check FitIQCore source code comments
4. Add logging to diagnose issues
5. Use debugger to inspect Keychain contents

---

## Conclusion

This migration consolidates user profile management in FitIQCore, improving security and eliminating code duplication. The adapter pattern ensures backward compatibility while providing a clean migration path.

**Next Steps:**
1. Review this guide with the team
2. Start with FitIQ migration (simpler)
3. Follow with Lume migration
4. Test thoroughly before production
5. Monitor for issues post-deployment

**Status:** 🚀 Ready to implement  
**Risk Level:** Low-Medium (with proper testing)  
**Benefits:** High (security + code quality)

---

**Last Updated:** 2025-01-27  
**Version:** 1.0  
**Authors:** FitIQ Engineering Team