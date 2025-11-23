# Lume Integration Guide - FitIQCore

**Date:** 2025-01-27  
**Version:** 1.0  
**Target:** Integrate FitIQCore v0.1.0 into Lume app

---

## 📋 Overview

This guide walks through integrating the **FitIQCore** shared library into the **Lume** wellness app. The integration will replace Lume's internal authentication and networking code with the shared FitIQCore implementations.

### Goals

✅ Add FitIQCore as a package dependency  
✅ Migrate authentication to use FitIQCore  
✅ Migrate networking to use FitIQCore  
✅ Remove duplicated code from Lume  
✅ Verify all tests passing  
✅ No breaking changes to existing functionality

### Estimated Effort

**Total:** 2-4 days (1 developer)
- Day 1: Add package dependency and initial setup (2-3 hours)
- Day 2: Migrate authentication code (3-4 hours)
- Day 3: Update network client and backend services (4-5 hours)
- Day 4: Testing and verification (3-4 hours)

---

## 🚀 Step-by-Step Integration

### Step 1: Add FitIQCore Package Dependency

#### 1.1 Add Package to Xcode Project

1. Open `lume.xcodeproj` in Xcode
2. Select the project in the Project Navigator
3. Select the **lume** target
4. Go to **General** tab → **Frameworks, Libraries, and Embedded Content**
5. Click **+** → **Add Package Dependency...**
6. Click **Add Local...** (bottom left)
7. Navigate to `fit-iq/FitIQCore`
8. Click **Add Package**
9. Ensure **FitIQCore** is checked
10. Click **Add Package**

#### 1.2 Verify Package Added

```swift
// In any Lume file, try importing:
import FitIQCore

// If import succeeds, package is correctly added ✅
```

#### 1.3 Build Project

```bash
# In terminal
cd fit-iq/lume
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Expected: ✅ Build succeeds with no errors

---

### Step 2: Migrate Authentication Code

#### 2.1 Update AppDependencies

**File:** `lume/DI/AppDependencies.swift`

```swift
// Add import at top
import FitIQCore

@MainActor
final class AppDependencies {
    // ... existing properties ...
    
    // MARK: - FitIQCore - Authentication
    
    private(set) lazy var authTokenStorage: AuthTokenPersistenceProtocol = {
        KeychainAuthTokenStorage()
    }()
    
    private(set) lazy var authManager: AuthManager = {
        AuthManager(
            authTokenPersistence: authTokenStorage,
            onboardingKey: "lume_onboarding_complete"  // Lume-specific key
        )
    }()
    
    // Update existing auth service to use FitIQCore's AuthManager
    private(set) lazy var authService: AuthServiceProtocol = {
        if AppMode.useMockData {
            return MockAuthService()
        } else {
            return RemoteAuthService(authManager: authManager)  // Pass authManager
        }
    }()
    
    // ... rest of dependencies ...
}
```

#### 2.2 Create Bridge Protocol (Optional)

If Lume's `TokenStorageProtocol` differs from FitIQCore's `AuthTokenPersistenceProtocol`, create a bridge:

**File:** `lume/Services/Authentication/FitIQCoreAuthBridge.swift`

```swift
import Foundation
import FitIQCore

/// Bridges Lume's AuthToken to FitIQCore's token persistence
final class FitIQCoreAuthBridge {
    private let authTokenPersistence: AuthTokenPersistenceProtocol
    
    init(authTokenPersistence: AuthTokenPersistenceProtocol) {
        self.authTokenPersistence = authTokenPersistence
    }
    
    func saveToken(_ token: AuthToken) async throws {
        try authTokenPersistence.save(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken
        )
    }
    
    func getToken() async throws -> AuthToken? {
        guard let accessToken = try authTokenPersistence.fetchAccessToken(),
              let refreshToken = try authTokenPersistence.fetchRefreshToken() else {
            return nil
        }
        
        // Note: FitIQCore doesn't store expiresAt, Lume will need to handle this
        // Option 1: Store expiresAt separately in UserDefaults
        // Option 2: Extend FitIQCore's protocol to support expiresAt
        
        let expiresAt = Date()  // TODO: Retrieve from separate storage
        
        return AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }
    
    func deleteToken() async throws {
        try authTokenPersistence.deleteTokens()
    }
}
```

#### 2.3 Update RemoteAuthService

**File:** `lume/Services/Authentication/RemoteAuthService.swift`

```swift
import Foundation
import FitIQCore  // Add this import

final class RemoteAuthService: AuthServiceProtocol {
    private let httpClient: HTTPClient
    private let authManager: AuthManager  // Use FitIQCore's AuthManager
    
    init(
        httpClient: HTTPClient = HTTPClient(),
        authManager: AuthManager
    ) {
        self.httpClient = httpClient
        self.authManager = authManager
    }
    
    func login(email: String, password: String) async throws -> AuthToken {
        // ... existing login logic ...
        
        // After successful login, save to FitIQCore
        try authManager.authTokenPersistence.save(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken
        )
        
        // Handle successful auth
        await authManager.handleSuccessfulAuth(userProfileID: userID)
        
        return token
    }
    
    func logout() async throws {
        // Use FitIQCore's logout
        await authManager.logout()
    }
    
    // ... rest of implementation ...
}
```

#### 2.4 Alternative: Extend FitIQCore Protocol (Recommended)

If Lume needs `expiresAt` support, consider extending FitIQCore:

**Option A: Add to FitIQCore (Phase 1.1 update)**

Update `FitIQCore/Sources/FitIQCore/Auth/Domain/AuthTokenPersistenceProtocol.swift`:

```swift
public protocol AuthTokenPersistenceProtocol {
    func save(accessToken: String, refreshToken: String) throws
    func fetchAccessToken() throws -> String?
    func fetchRefreshToken() throws -> String?
    func deleteTokens() throws
    
    func saveUserProfileID(_ userID: UUID) throws
    func fetchUserProfileID() throws -> UUID?
    func deleteUserProfileID() throws
    
    // NEW: Optional token expiration support
    func saveTokenExpiration(_ expiresAt: Date) throws
    func fetchTokenExpiration() throws -> Date?
}
```

**Option B: Store expiresAt in UserDefaults (Quick fix)**

```swift
extension AuthManager {
    private var expiresAtKey: String { "lume.auth.expiresAt" }
    
    func saveTokenExpiration(_ expiresAt: Date) {
        UserDefaults.standard.set(expiresAt, forKey: expiresAtKey)
    }
    
    func fetchTokenExpiration() -> Date? {
        return UserDefaults.standard.object(forKey: expiresAtKey) as? Date
    }
    
    func deleteTokenExpiration() {
        UserDefaults.standard.removeObject(forKey: expiresAtKey)
    }
}
```

---

### Step 3: Migrate Network Code

#### 3.1 Update HTTPClient to Use FitIQCore

**File:** `lume/Core/Network/HTTPClient.swift`

```swift
import Foundation
import FitIQCore  // Add this import

/// HTTP client for backend API communication
/// Now uses FitIQCore's NetworkClientProtocol as foundation
final class HTTPClient {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let apiKey: String
    private let networkClient: NetworkClientProtocol  // Use FitIQCore's network client
    
    // MARK: - Initialization
    
    init(
        baseURL: URL = AppConfiguration.shared.backendBaseURL,
        apiKey: String = AppConfiguration.shared.apiKey,
        networkClient: NetworkClientProtocol = URLSessionNetworkClient()  // Use FitIQCore
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.networkClient = networkClient
    }
    
    // MARK: - Request Methods
    
    func get<T: Decodable>(
        path: String,
        headers: [String: String] = [:],
        accessToken: String? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        addCommonHeaders(to: &request, additionalHeaders: headers, accessToken: accessToken)
        
        // Use FitIQCore's network client
        let (data, response) = try await networkClient.executeRequest(request: request)
        
        return try decodeResponse(data: data, response: response)
    }
    
    // ... similar updates for post, put, delete, patch ...
    
    // MARK: - Private Helpers
    
    private func decodeResponse<T: Decodable>(data: Data, response: HTTPURLResponse) throws -> T {
        // Handle empty response for EmptyResponse type
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Enhanced error logging
            print("❌ [HTTPClient] Decoding failed for type: \(T.self)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📋 [HTTPClient] Response JSON: \(jsonString)")
            }
            throw HTTPError.decodingFailed(error)
        }
    }
    
    // ... rest of implementation ...
}
```

#### 3.2 Update Error Handling to Use FitIQCore

**Option 1: Map FitIQCore errors to Lume errors**

```swift
extension HTTPError {
    init(from apiError: APIError) {
        switch apiError {
        case .invalidResponse:
            self = .invalidResponse
        case .unauthorized:
            self = .unauthorized
        case .notFound:
            self = .notFound
        case .serverError(let statusCode):
            self = .serverError(statusCode)
        case .apiError(let statusCode, let message):
            self = .backendError(code: "API_ERROR", message: message, statusCode: statusCode)
        default:
            self = .unknown(500)
        }
    }
}
```

**Option 2: Use FitIQCore's APIError directly (Recommended)**

Replace `HTTPError` enum with `APIError` from FitIQCore:

```swift
import FitIQCore

// Remove HTTPError enum definition
// Use APIError from FitIQCore everywhere

// Update method signatures:
func get<T: Decodable>(...) async throws -> T {
    // throws APIError from FitIQCore
}
```

---

### Step 4: Remove Old Code

**CRITICAL:** Only delete files AFTER verifying everything compiles with FitIQCore!

#### 4.1 Files to Delete

```
lume/Services/Authentication/
└── KeychainTokenStorage.swift                  ❌ DELETE (replaced by FitIQCore)

lume/Core/Security/
└── (empty - already empty)                     ✅ Already clean
```

#### 4.2 Files to Update (Not Delete)

```
lume/Services/Authentication/
├── RemoteAuthService.swift                     ✏️ UPDATE (use FitIQCore's AuthManager)
└── MockAuthService.swift                       ✅ KEEP (testing)

lume/Core/Network/
├── HTTPClient.swift                            ✏️ UPDATE (use FitIQCore's NetworkClient)
└── NetworkMonitor.swift                        ✅ KEEP (Lume-specific)
```

#### 4.3 Verify No References Remain

```bash
# Search for deleted file names
cd fit-iq/lume/lume

# Should return no results for deleted files
grep -r "KeychainTokenStorage.swift" .
```

---

### Step 5: Update UserSession

**File:** `lume/Core/UserSession.swift`

If `UserSession` manages auth state, update it to use FitIQCore's `AuthManager`:

```swift
import Foundation
import FitIQCore
import Observation

@Observable
final class UserSession {
    // Use FitIQCore's AuthManager
    private let authManager: AuthManager
    
    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }
    
    var currentAuthState: AuthState {
        authManager.currentAuthState
    }
    
    var currentUserProfileID: UUID? {
        authManager.currentUserProfileID
    }
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    func login(email: String, password: String) async throws {
        // ... login logic ...
        await authManager.handleSuccessfulAuth(userProfileID: userID)
    }
    
    func logout() async {
        await authManager.logout()
    }
}
```

---

### Step 6: Update Tests

#### 6.1 Update Test Imports

Find all test files that use authentication:

```bash
cd ../lumeTests
grep -r "TokenStorage" --include="*.swift" .
grep -r "AuthService" --include="*.swift" .
```

**Pattern for test updates:**

```swift
import XCTest
@testable import lume
import FitIQCore  // Add this

final class AuthServiceTests: XCTestCase {
    var mockAuthManager: AuthManager!
    var mockTokenStorage: MockAuthTokenStorage!
    
    override func setUp() {
        super.setUp()
        mockTokenStorage = MockAuthTokenStorage()
        mockAuthManager = AuthManager(
            authTokenPersistence: mockTokenStorage,
            onboardingKey: "test_lume_onboarding"
        )
    }
    
    // ... tests ...
}
```

#### 6.2 Create Mock for Tests

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

### Step 7: Build and Test

#### 7.1 Clean Build

```bash
cd fit-iq/lume

# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/lume-*

# Rebuild
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

Expected: ✅ Build succeeds with no errors

#### 7.2 Run Unit Tests

```bash
xcodebuild -scheme lume -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Expected: ✅ All tests pass

#### 7.3 Run App in Simulator

1. Open lume in Xcode
2. Select iPhone 15 simulator
3. Press `Cmd+R` to run
4. Test authentication flow:
   - ✅ Login works
   - ✅ Logout works
   - ✅ Token persistence works (login survives app restart)
   - ✅ Onboarding flow works
   - ✅ Mood tracking works
   - ✅ Journal entries work
   - ✅ AI insights work

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
- [ ] Mood tracking saves correctly
- [ ] Journal entries save correctly
- [ ] AI insights load correctly

### Test Verification
- [ ] All existing unit tests pass
- [ ] No test failures related to auth changes
- [ ] Mock implementations work correctly
- [ ] Integration tests pass (if any)

### Code Quality
- [ ] No duplicated code remains
- [ ] Old auth files deleted
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

### Issue: "Type 'TokenStorageProtocol' does not conform to 'AuthTokenPersistenceProtocol'"

**Solution:**
Use the bridge approach (see Step 2.2) or update Lume's protocol to match FitIQCore's

### Issue: "Missing expiresAt property"

**Solution:**
Use Option B from Step 2.4 to store expiresAt in UserDefaults separately

### Issue: Tests fail with "Cannot find type 'MockAuthTokenStorage'"

**Solution:**
Create mock in test file (see Step 6.2 above)

---

## 📊 Migration Impact

### Code Removed (Duplicates)
- `KeychainTokenStorage.swift` (~200 lines)

**Total:** ~200 lines of duplicated code removed ✅

### Code Added (Imports + Bridge)
- Import statements: ~15 files × 1 line = ~15 lines
- Bridge implementation: ~50 lines (if needed)
- Minor adjustments: ~20 lines

**Net Change:** -130 lines (reduced codebase size)

### Benefits
✅ **Reduced duplication** - Auth code now shared with FitIQ  
✅ **Better tested** - FitIQCore has 95%+ test coverage  
✅ **Easier maintenance** - Fix bugs once, benefit both apps  
✅ **Consistent behavior** - Same auth flow in both apps  

---

## 🎯 Success Criteria

Integration is successful when:

✅ Lume builds without errors  
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
- [FitIQ Integration Guide](./FITIQ_INTEGRATION_GUIDE.md)
- [Implementation Status](./IMPLEMENTATION_STATUS.md)
- [Shared Library Assessment](./SHARED_LIBRARY_ASSESSMENT.md)

---

## 🆘 Support

If you encounter issues during integration:

1. Review this guide step-by-step
2. Check the [FitIQCore README](../../FitIQCore/README.md) for usage examples
3. Review FitIQCore tests for patterns
4. Check [FitIQ Integration Guide](./FITIQ_INTEGRATION_GUIDE.md) for similar patterns
5. Check [Copilot Instructions](../../.github/COPILOT_INSTRUCTIONS_UNIFIED.md)

---

## 🎓 Key Differences from FitIQ Integration

### Lume-Specific Considerations

1. **Token Expiration:** Lume tracks `expiresAt`, FitIQCore doesn't (yet)
   - Solution: Store separately or extend FitIQCore

2. **Onboarding Key:** Use `"lume_onboarding_complete"` (not `"hasFinishedOnboardingSetup"`)

3. **Mock Mode:** Lume has `AppMode.useMockData` flag
   - Keep mock services for development/testing

4. **HTTPClient:** Lume's HTTPClient is more feature-rich
   - Keep Lume's HTTPClient as wrapper over FitIQCore's NetworkClient
   - Don't fully replace, just use as foundation

5. **Error Types:** Lume has enhanced error details (conflict with details)
   - Keep Lume's HTTPError enum
   - Map FitIQCore's APIError to HTTPError as needed

---

**Version:** 1.0  
**Status:** Ready for Integration  
**Last Updated:** 2025-01-27  
**Estimated Effort:** 2-4 days