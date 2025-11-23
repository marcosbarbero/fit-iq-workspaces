# FitIQ Integration Guide - FitIQCore

**Date:** 2025-01-27  
**Version:** 1.0  
**Target:** Integrate FitIQCore v0.1.0 into FitIQ app

---

## 📋 Overview

This guide walks through integrating the newly created **FitIQCore** shared library into the **FitIQ** iOS app. The integration will replace FitIQ's internal authentication and networking code with the shared FitIQCore implementations.

### Goals

✅ Add FitIQCore as a package dependency  
✅ Migrate authentication to use FitIQCore  
✅ Remove duplicated code from FitIQ  
✅ Verify all tests passing  
✅ No breaking changes to existing functionality

### Estimated Effort

**Total:** 3-5 days (1 developer)
- Day 1: Add package dependency and initial setup (2-3 hours)
- Day 2: Migrate authentication code (4-6 hours)
- Day 3: Update network clients (3-4 hours)
- Day 4: Remove old code and clean up (2-3 hours)
- Day 5: Testing and verification (4-6 hours)

---

## 🚀 Step-by-Step Integration

### Step 1: Add FitIQCore Package Dependency

#### 1.1 Add Package to Xcode Project

1. Open `FitIQ.xcodeproj` in Xcode
2. Select the project in the Project Navigator
3. Select the **FitIQ** target
4. Go to **General** tab → **Frameworks, Libraries, and Embedded Content**
5. Click **+** → **Add Package Dependency...**
6. Click **Add Local...** (bottom left)
7. Navigate to `fit-iq/FitIQCore`
8. Click **Add Package**
9. Ensure **FitIQCore** is checked
10. Click **Add Package**

#### 1.2 Verify Package Added

```swift
// In any FitIQ file, try importing:
import FitIQCore

// If import succeeds, package is correctly added ✅
```

#### 1.3 Build Project

```bash
# In terminal
cd fit-iq/FitIQ
xcodebuild -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Expected: ✅ Build succeeds with no errors

---

### Step 2: Migrate Authentication Code

#### 2.1 Update AppDependencies

**File:** `FitIQ/DI/AppDependencies.swift`

```swift
// Add import at top
import FitIQCore

final class AppDependencies {
    // ... existing properties ...
    
    // MARK: - FitIQCore - Authentication
    
    lazy var authTokenStorage: AuthTokenPersistenceProtocol = KeychainAuthTokenStorage()
    
    lazy var authManager: AuthManager = AuthManager(
        authTokenPersistence: authTokenStorage,
        onboardingKey: "hasFinishedOnboardingSetup"
    )
    
    // ... rest of dependencies ...
}
```

#### 2.2 Update Existing Auth Manager References

Find all files that import or use the old `AuthManager`:

```bash
# Search for AuthManager usage
cd fit-iq/FitIQ/FitIQ
grep -r "AuthManager" --include="*.swift" .
```

**Files to update:**
- `Infrastructure/Security/AuthManager.swift` → **DELETE (replaced by FitIQCore)**
- `Domain/UseCases/AuthTokenPersistencePortProtocol.swift` → **DELETE (replaced by FitIQCore)**
- `Domain/UseCases/KeychainAuthTokenAdapter.swift` → **DELETE (replaced by FitIQCore)**
- `Infrastructure/Security/KeychainManager.swift` → **DELETE (replaced by FitIQCore)**

**Files to import FitIQCore:**
- Any use case that depends on `AuthManager`
- Any view model that uses authentication
- Any service that needs auth tokens

Example update:

```swift
// Before
import Foundation

class SomeUseCase {
    private let authManager: AuthManager
    // ...
}

// After
import Foundation
import FitIQCore

class SomeUseCase {
    private let authManager: AuthManager
    // ...
}
```

#### 2.3 Update Protocol References

Replace all `AuthTokenPersistencePortProtocol` with `AuthTokenPersistenceProtocol`:

```swift
// Before
private let authTokenPersistence: AuthTokenPersistencePortProtocol

// After
import FitIQCore
private let authTokenPersistence: AuthTokenPersistenceProtocol
```

#### 2.4 Update Use Cases

For any use case that uses `AuthManager`, add `import FitIQCore`:

**Example files:**
- `Domain/UseCases/BackgroundSyncManager.swift`
- `Domain/UseCases/ConfirmPhotoRecognitionUseCase.swift`
- `Domain/UseCases/Debug/DebugOutboxStatusUseCase.swift`
- `Domain/UseCases/Debug/TestOutboxSyncUseCase.swift`
- `Domain/UseCases/Debug/VerifyOutboxIntegrationUseCase.swift`
- `Domain/UseCases/Debug/VerifyRemoteSyncUseCase.swift`

Pattern for each file:

```swift
import FitIQCore  // Add this import

// Rest of the file remains the same
// AuthManager usage is compatible (same API)
```

---

### Step 3: Migrate Network Code

#### 3.1 Update Network Client Protocol References

**File:** `Infrastructure/Network/URLSessionNetworkClient.swift`

```swift
// Before
import Foundation

final class URLSessionNetworkClient: NetworkClientProtocol {
    func executeRequest(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, httpResponse)
    }
}

// After
import Foundation
import FitIQCore

// Delete this file - it's now in FitIQCore
// Update AppDependencies to use FitIQCore's URLSessionNetworkClient
```

#### 3.2 Update AppDependencies Network Client

```swift
import FitIQCore

lazy var networkClient: NetworkClientProtocol = URLSessionNetworkClient()
```

#### 3.3 Update API Clients

Find all files that use `NetworkClientProtocol`:

```bash
grep -r "NetworkClientProtocol" --include="*.swift" .
```

**Files to update:**
- `Infrastructure/Network/UserAuthAPIClient.swift`
- `Infrastructure/Network/RemoteHealthDataSyncClient.swift`
- Any other API clients

Pattern:

```swift
import Foundation
import FitIQCore  // Add this

final class UserAuthAPIClient {
    private let networkClient: NetworkClientProtocol
    // ... rest remains the same
}
```

#### 3.4 Update Error Handling

Replace references to old `APIError` with `FitIQCore.APIError`:

```swift
// Before
throw APIError.invalidResponse

// After
import FitIQCore
throw APIError.invalidResponse  // Same API, just from FitIQCore now
```

---

### Step 4: Remove Old Code

**CRITICAL:** Only delete files AFTER verifying everything compiles with FitIQCore!

#### 4.1 Files to Delete

```
FitIQ/Infrastructure/Security/
├── AuthManager.swift                           ❌ DELETE
└── KeychainManager.swift                       ❌ DELETE

FitIQ/Domain/UseCases/
├── AuthTokenPersistencePortProtocol.swift      ❌ DELETE
└── KeychainAuthTokenAdapter.swift              ❌ DELETE

FitIQ/Infrastructure/Network/
├── NetworkClientProtocol.swift                 ❌ DELETE
└── URLSessionNetworkClient.swift               ❌ DELETE
```

#### 4.2 Verify No References Remain

```bash
# Search for deleted file names
cd fit-iq/FitIQ/FitIQ

# Should return no results
grep -r "AuthManager.swift" .
grep -r "KeychainManager.swift" .
grep -r "KeychainAuthTokenAdapter.swift" .
grep -r "URLSessionNetworkClient.swift" .
```

---

### Step 5: Update Tests

#### 5.1 Update Test Imports

Find all test files that use authentication:

```bash
cd ../FitIQTests
grep -r "AuthManager" --include="*.swift" .
```

**Pattern for test updates:**

```swift
import XCTest
@testable import FitIQ
import FitIQCore  // Add this

final class SomeUseCaseTests: XCTestCase {
    // Tests remain the same - AuthManager API is compatible
}
```

#### 5.2 Create Mock for Tests

If tests need a mock `AuthTokenPersistenceProtocol`:

```swift
import FitIQCore

final class MockAuthTokenStorage: AuthTokenPersistenceProtocol {
    var accessToken: String?
    var refreshToken: String?
    var userProfileID: UUID?
    
    func save(accessToken: String, refreshToken: String) throws {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    func fetchAccessToken() throws -> String? {
        return accessToken
    }
    
    func fetchRefreshToken() throws -> String? {
        return refreshToken
    }
    
    func deleteTokens() throws {
        accessToken = nil
        refreshToken = nil
    }
    
    func saveUserProfileID(_ userID: UUID) throws {
        self.userProfileID = userID
    }
    
    func fetchUserProfileID() throws -> UUID? {
        return userProfileID
    }
    
    func deleteUserProfileID() throws {
        userProfileID = nil
    }
}
```

---

### Step 6: Build and Test

#### 6.1 Clean Build

```bash
cd fit-iq/FitIQ

# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/FitIQ-*

# Rebuild
xcodebuild -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

Expected: ✅ Build succeeds with no errors

#### 6.2 Run Unit Tests

```bash
xcodebuild -scheme FitIQ -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Expected: ✅ All tests pass

#### 6.3 Run App in Simulator

1. Open FitIQ in Xcode
2. Select iPhone 15 simulator
3. Press `Cmd+R` to run
4. Test authentication flow:
   - ✅ Login works
   - ✅ Logout works
   - ✅ Token persistence works (login survives app restart)
   - ✅ Onboarding flow works

---

## 🧪 Verification Checklist

### Build Verification
- [ ] Project compiles without errors
- [ ] No compiler warnings related to auth or network
- [ ] FitIQCore package loads correctly
- [ ] All imports resolve correctly

### Functionality Verification
- [ ] User can log in successfully
- [ ] User can register successfully
- [ ] Authentication persists across app restarts
- [ ] Logout clears authentication correctly
- [ ] Onboarding flow works end-to-end
- [ ] Network requests work correctly
- [ ] API errors are handled properly

### Test Verification
- [ ] All existing unit tests pass
- [ ] No test failures related to auth changes
- [ ] Mock implementations work correctly
- [ ] Integration tests pass (if any)

### Code Quality
- [ ] No duplicated code remains
- [ ] All old auth files deleted
- [ ] Imports are clean (no unused imports)
- [ ] No force unwraps introduced
- [ ] Error handling is consistent

---

## 🐛 Troubleshooting

### Issue: "Cannot find 'AuthManager' in scope"

**Solution:**
```swift
import FitIQCore  // Add this import at top of file
```

### Issue: "No such module 'FitIQCore'"

**Solution:**
1. Verify FitIQCore is in `fit-iq/FitIQCore/` directory
2. Check Package.swift exists in FitIQCore
3. In Xcode: File → Packages → Reset Package Caches
4. Clean and rebuild project

### Issue: "Type 'AuthTokenPersistencePortProtocol' does not exist"

**Solution:**
```swift
// Replace old protocol name with new one
import FitIQCore
let storage: AuthTokenPersistenceProtocol  // Not AuthTokenPersistencePortProtocol
```

### Issue: Tests fail with "Cannot find type 'MockAuthTokenStorage'"

**Solution:**
Create mock in test file (see Step 5.2 above)

### Issue: "Keychain keys not found after migration"

**Root Cause:** FitIQCore uses the same Keychain keys as FitIQ (compatibility)

**Verification:**
```swift
// FitIQCore uses these keys (same as before):
"com.marcosbarbero.FitIQ.authToken"
"com.marcosbarbero.FitIQ.refreshToken"
"com.marcosbarbero.FitIQ.userProfileID"
```

No action needed - tokens should persist across migration ✅

---

## 📊 Migration Impact

### Code Removed (Duplicates)
- `AuthManager.swift` (~150 lines)
- `KeychainManager.swift` (~100 lines)
- `KeychainAuthTokenAdapter.swift` (~90 lines)
- `AuthTokenPersistencePortProtocol.swift` (~15 lines)
- `NetworkClientProtocol.swift` (~10 lines)
- `URLSessionNetworkClient.swift` (~20 lines)

**Total:** ~385 lines of duplicated code removed ✅

### Code Added (Imports)
- Import statements: ~20 files × 1 line = ~20 lines
- Minor adjustments: ~10 lines

**Net Change:** -365 lines (reduced codebase size)

### Benefits
✅ **Reduced duplication** - Auth code now in one place  
✅ **Shared with Lume** - Future app gets same infrastructure  
✅ **Better tested** - FitIQCore has 95%+ test coverage  
✅ **Easier maintenance** - Fix bugs once, benefit both apps  

---

## 🎯 Success Criteria

Integration is successful when:

✅ FitIQ builds without errors  
✅ All tests pass  
✅ Authentication flow works end-to-end  
✅ No regressions in existing features  
✅ Old auth files deleted  
✅ No code duplication remains  
✅ FitIQCore package is the single source of truth for auth  

---

## 📚 Related Documentation

- [FitIQCore README](../../FitIQCore/README.md)
- [Phase 1 Complete](./FITIQCORE_PHASE1_COMPLETE.md)
- [Shared Library Assessment](./SHARED_LIBRARY_ASSESSMENT.md)
- [Split Strategy Cleanup](./SPLIT_STRATEGY_CLEANUP_COMPLETE.md)

---

## 🆘 Support

If you encounter issues during integration:

1. Review this guide step-by-step
2. Check the [FitIQCore README](../../FitIQCore/README.md) for usage examples
3. Review FitIQCore tests for patterns
4. Check [Copilot Instructions](../../.github/COPILOT_INSTRUCTIONS_UNIFIED.md)

---

**Version:** 1.0  
**Status:** Ready for Integration  
**Last Updated:** 2025-01-27  
**Estimated Effort:** 3-5 days