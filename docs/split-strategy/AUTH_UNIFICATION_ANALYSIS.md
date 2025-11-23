# Authentication Unification Analysis

**Date:** 2025-01-27  
**Version:** 1.0  
**Purpose:** Analyze authentication differences between FitIQ and Lume, propose unified approach

---

## 📋 Executive Summary

After examining both FitIQ and Lume authentication implementations, **FitIQ has a significantly more robust and production-ready authentication strategy**. The key differences are:

1. **FitIQ uses a comprehensive `AuthToken` entity** with JWT parsing, expiration tracking, and validation
2. **FitIQ has sophisticated token refresh synchronization** using locks to prevent race conditions
3. **FitIQ handles token expiration proactively** with `willExpireSoon` checks
4. **FitIQ has automatic retry-with-refresh** logic built into API clients
5. **Lume's approach is simpler** but lacks critical production features

**Recommendation:** Extract FitIQ's auth approach to FitIQCore and migrate Lume to use it.

---

## 🔍 Detailed Comparison

### 1. Token Storage and Representation

#### FitIQ Approach ✅ (Superior)

**File:** `FitIQ/Domain/Entities/Auth/AuthToken.swift` (280 lines)

**Features:**
```swift
public struct AuthToken: Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date?  // ✅ Tracks expiration
    
    // ✅ Computed properties
    public var isExpired: Bool
    public var willExpireSoon: Bool  // ✅ Proactive refresh (5 min threshold)
    public var secondsUntilExpiration: TimeInterval?
    public var isValid: Bool
    
    // ✅ JWT parsing capabilities
    func parseExpirationFromJWT() -> Date?
    func parseUserIdFromJWT() -> String?
    
    // ✅ Factory method with auto-parsing
    static func withParsedExpiration(accessToken:, refreshToken:) -> AuthToken
    
    // ✅ Security
    var sanitizedDescription: String  // Hides sensitive data in logs
    
    // ✅ Validation
    func validate() -> [ValidationError]
}
```

**Benefits:**
- ✅ Complete domain entity with business logic
- ✅ Tracks expiration automatically from JWT
- ✅ Proactive refresh (before actual expiration)
- ✅ Built-in validation
- ✅ Secure logging (no token leaks)

---

#### Lume Approach ⚠️ (Basic)

**File:** `lume/Domain/Entities/AuthToken.swift`

**Features:**
```swift
struct AuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date  // ⚠️ Stored but not parsed from JWT
}
```

**Limitations:**
- ❌ No JWT parsing
- ❌ No validation logic
- ❌ No proactive refresh checks
- ❌ No sanitized logging
- ❌ Manual expiration tracking required

---

### 2. Token Refresh Strategy

#### FitIQ Approach ✅ (Sophisticated)

**File:** `FitIQ/Infrastructure/Network/UserAuthAPIClient.swift`

**Features:**
```swift
class UserAuthAPIClient: AuthRepositoryProtocol {
    // ✅ Race condition prevention
    private var isRefreshing = false
    private var refreshTask: Task<LoginResponse, Error>?
    private let refreshLock = NSLock()
    
    func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
        // ✅ Synchronization - only one refresh at a time
        refreshLock.lock()
        if let existingTask = refreshTask {
            refreshLock.unlock()
            // ✅ Reuse in-progress refresh
            return try await existingTask.value
        }
        
        // ✅ Create new refresh task
        let task = Task<LoginResponse, Error> {
            defer {
                // ✅ Cleanup on completion
                refreshLock.lock()
                self.refreshTask = nil
                self.isRefreshing = false
                refreshLock.unlock()
            }
            
            // Perform refresh...
            let response: LoginResponse = try await executeAPIRequest(...)
            
            return response
        }
        
        self.refreshTask = task
        self.isRefreshing = true
        refreshLock.unlock()
        
        return try await task.value
    }
}
```

**Benefits:**
- ✅ **Thread-safe** refresh (NSLock prevents race conditions)
- ✅ **Deduplication** - multiple requests share same refresh task
- ✅ **Automatic cleanup** with defer
- ✅ **Handles revoked tokens** - auto-logout on invalid refresh token

**Pattern used across ALL API clients:**
- `ProgressAPIClient.swift` - Uses synchronized refresh
- `SleepAPIClient.swift` - Uses synchronized refresh
- `RemoteHealthDataSyncClient.swift` - Uses synchronized refresh
- `NutritionAPIClient.swift` - Uses synchronized refresh
- `PhotoRecognitionAPIClient.swift` - Uses synchronized refresh

---

#### Lume Approach ⚠️ (Basic)

**File:** `lume/Services/Authentication/RemoteAuthService.swift`

**Features:**
```swift
func refreshToken(_ token: String) async throws -> AuthToken {
    // ⚠️ Simple HTTP request, no synchronization
    let requestBody = RefreshTokenRequest(refreshToken: token)
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    // ... basic request execution
}
```

**Limitations:**
- ❌ **No synchronization** - race conditions possible
- ❌ **No deduplication** - concurrent refreshes can happen
- ❌ **Manual refresh** - no automatic retry logic
- ❌ **No cleanup guarantees**

---

### 3. Automatic Retry with Refresh

#### FitIQ Approach ✅ (Automatic)

**Pattern:** Every API client has `executeWithRetry` method

**Example from `ProgressAPIClient.swift`:**
```swift
private func executeWithRetry<T: Decodable>(
    request: URLRequest,
    retryCount: Int = 0
) async throws -> T {
    do {
        // Try request
        let (data, response) = try await networkClient.executeRequest(request: request)
        return try decodeResponse(data: data, response: response)
    } catch let error as APIError {
        // ✅ Auto-retry on 401 Unauthorized
        if case .unauthorized = error, retryCount < 1 {
            print("API: 401 Unauthorized - attempting token refresh")
            
            // ✅ Get refresh token
            guard let savedRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
                throw APIError.unauthorized
            }
            
            // ✅ Synchronized refresh
            let refreshRequest = RefreshTokenRequest(refreshToken: savedRefreshToken)
            let newTokens: LoginResponse = try await refreshAccessToken(request: refreshRequest)
            
            // ✅ Save new tokens
            try authTokenPersistence.save(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken
            )
            
            // ✅ Retry original request with new token
            var retryRequest = request
            retryRequest.setValue("Bearer \(newTokens.accessToken)", forHTTPHeaderField: "Authorization")
            return try await executeWithRetry(request: retryRequest, retryCount: retryCount + 1)
        }
        
        throw error
    }
}
```

**Benefits:**
- ✅ **Transparent to callers** - automatic refresh + retry
- ✅ **Prevents 401 errors** reaching application layer
- ✅ **Seamless token rotation**
- ✅ **Prevents refresh loops** (retryCount limit)

---

#### Lume Approach ⚠️ (Manual)

**No automatic retry logic** - callers must handle 401 errors manually

**Implications:**
- ⚠️ Every feature must handle token refresh
- ⚠️ Prone to 401 errors reaching UI
- ⚠️ More error handling boilerplate

---

### 4. Token Persistence

#### FitIQ Approach ✅

**Protocol:** `AuthTokenPersistencePortProtocol`
```swift
protocol AuthTokenPersistencePortProtocol {
    func save(accessToken: String, refreshToken: String) throws
    func fetchAccessToken() throws -> String?
    func fetchRefreshToken() throws -> String?
    func deleteTokens() throws
    
    func saveUserProfileID(_ userID: UUID) throws
    func fetchUserProfileID() throws -> UUID?
    func deleteUserProfileID() throws
}
```

**Implementation:** `KeychainAuthTokenAdapter`
- ✅ Stores access token
- ✅ Stores refresh token
- ✅ Stores user profile ID
- ❌ Does NOT store expiresAt (but parsed from JWT when needed)

---

#### Lume Approach ⚠️

**Protocol:** `TokenStorageProtocol`
```swift
protocol TokenStorageProtocol {
    func saveToken(_ token: AuthToken) async throws
    func getToken() async throws -> AuthToken?
    func deleteToken() async throws
}
```

**Implementation:** `KeychainTokenStorage`
- ✅ Stores access token
- ✅ Stores refresh token
- ✅ Stores expiresAt (as encoded Date)
- ❌ No user profile ID storage

**Differences:**
- Lume stores expiresAt explicitly in Keychain
- FitIQ parses expiresAt from JWT when needed
- Lume uses async methods, FitIQ uses synchronous throws

---

## 🎯 Proposed Unified Approach

### Phase 1: Extract FitIQ's Auth to FitIQCore

#### 1. Add `AuthToken` Entity to FitIQCore

**File:** `FitIQCore/Sources/FitIQCore/Auth/Domain/AuthToken.swift`

```swift
import Foundation

/// Complete authentication token entity with JWT parsing and validation
public struct AuthToken: Equatable, Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date?
    
    // Computed properties
    public var isExpired: Bool { ... }
    public var willExpireSoon: Bool { ... }
    public var secondsUntilExpiration: TimeInterval? { ... }
    public var isValid: Bool { ... }
    
    // JWT parsing
    public func parseExpirationFromJWT() -> Date? { ... }
    public func parseUserIdFromJWT() -> String? { ... }
    
    // Factory
    public static func withParsedExpiration(...) -> AuthToken { ... }
    
    // Security
    public var sanitizedDescription: String { ... }
    
    // Validation
    public func validate() -> [ValidationError] { ... }
}
```

---

#### 2. Update FitIQCore's Token Persistence Protocol

**Current:**
```swift
public protocol AuthTokenPersistenceProtocol {
    func save(accessToken: String, refreshToken: String) throws
    func fetchAccessToken() throws -> String?
    func fetchRefreshToken() throws -> String?
    func deleteTokens() throws
    
    func saveUserProfileID(_ userID: UUID) throws
    func fetchUserProfileID() throws -> UUID?
    func deleteUserProfileID() throws
}
```

**Enhanced (Option A - Store expiresAt explicitly):**
```swift
public protocol AuthTokenPersistenceProtocol {
    // Token storage
    func saveToken(_ token: AuthToken) throws  // ✅ Store entire token
    func fetchToken() throws -> AuthToken?     // ✅ Retrieve entire token
    func deleteToken() throws
    
    // Legacy support (for apps that need individual access)
    func save(accessToken: String, refreshToken: String) throws
    func fetchAccessToken() throws -> String?
    func fetchRefreshToken() throws -> String?
    func deleteTokens() throws
    
    // User profile
    func saveUserProfileID(_ userID: UUID) throws
    func fetchUserProfileID() throws -> UUID?
    func deleteUserProfileID() throws
}
```

**Enhanced (Option B - Parse from JWT only - RECOMMENDED):**
```swift
// Keep current protocol as-is
// AuthToken.parseExpirationFromJWT() provides expiresAt when needed
// No need to store separately
```

**Recommendation:** Use Option B - parse from JWT. Simpler, no additional storage.

---

#### 3. Add Token Refresh Client to FitIQCore

**File:** `FitIQCore/Sources/FitIQCore/Auth/Infrastructure/TokenRefreshClient.swift`

```swift
import Foundation

/// Handles token refresh with synchronization to prevent race conditions
public final class TokenRefreshClient {
    
    // MARK: - Properties
    
    private let networkClient: NetworkClientProtocol
    private let baseURL: URL
    private let apiKey: String
    
    // Synchronization
    private var isRefreshing = false
    private var refreshTask: Task<AuthToken, Error>?
    private let refreshLock = NSLock()
    
    // MARK: - Initialization
    
    public init(
        networkClient: NetworkClientProtocol,
        baseURL: URL,
        apiKey: String
    ) {
        self.networkClient = networkClient
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    /// Refreshes the access token using the refresh token
    /// Thread-safe - only one refresh happens at a time
    /// Concurrent calls will share the same refresh task
    public func refreshToken(_ refreshToken: String) async throws -> AuthToken {
        // Check if refresh is already in progress
        refreshLock.lock()
        if let existingTask = refreshTask {
            refreshLock.unlock()
            print("[TokenRefreshClient] Refresh already in progress, waiting...")
            return try await existingTask.value
        }
        
        // Create new refresh task
        let task = Task<AuthToken, Error> {
            defer {
                refreshLock.lock()
                self.refreshTask = nil
                self.isRefreshing = false
                refreshLock.unlock()
            }
            
            print("[TokenRefreshClient] Starting token refresh...")
            
            // Build request
            let url = baseURL.appendingPathComponent("/api/v1/auth/refresh")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            
            let requestBody = RefreshTokenRequest(refreshToken: refreshToken)
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            // Execute request
            let (data, response) = try await networkClient.executeRequest(request: request)
            
            // Decode response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            
            // Create AuthToken with parsed expiration
            let token = AuthToken.withParsedExpiration(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken
            )
            
            print("[TokenRefreshClient] ✅ Token refresh successful")
            return token
        }
        
        self.refreshTask = task
        self.isRefreshing = true
        refreshLock.unlock()
        
        return try await task.value
    }
}

// MARK: - DTOs

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}
```

---

#### 4. Add Automatic Retry Extension

**File:** `FitIQCore/Sources/FitIQCore/Network/NetworkClientRetry.swift`

```swift
import Foundation

/// Extension providing automatic retry with token refresh
public extension NetworkClientProtocol {
    
    /// Executes a request with automatic retry on 401 Unauthorized
    /// Automatically refreshes token and retries once if 401 is encountered
    func executeWithAutoRetry(
        request: URLRequest,
        tokenRefreshClient: TokenRefreshClient,
        authTokenPersistence: AuthTokenPersistenceProtocol,
        retryCount: Int = 0
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            // Try request
            return try await executeRequest(request: request)
        } catch let error as APIError {
            // Auto-retry on 401 Unauthorized
            if case .unauthorized = error, retryCount < 1 {
                print("[NetworkClient] 401 Unauthorized - attempting token refresh")
                
                // Get refresh token
                guard let refreshToken = try authTokenPersistence.fetchRefreshToken() else {
                    throw APIError.unauthorized
                }
                
                // Refresh token (synchronized)
                let newToken = try await tokenRefreshClient.refreshToken(refreshToken)
                
                // Save new tokens
                try authTokenPersistence.save(
                    accessToken: newToken.accessToken,
                    refreshToken: newToken.refreshToken
                )
                
                // Retry original request with new token
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken.accessToken)", forHTTPHeaderField: "Authorization")
                
                return try await executeWithAutoRetry(
                    request: retryRequest,
                    tokenRefreshClient: tokenRefreshClient,
                    authTokenPersistence: authTokenPersistence,
                    retryCount: retryCount + 1
                )
            }
            
            throw error
        }
    }
}
```

---

### Phase 2: Migrate Both Apps to Use FitIQCore

#### FitIQ Migration

**Update:** Remove `AuthToken.swift` from FitIQ (now in FitIQCore)

```swift
// Before
import Foundation

// After
import FitIQCore

// Use FitIQCore's AuthToken
let token = AuthToken.withParsedExpiration(
    accessToken: accessToken,
    refreshToken: refreshToken
)
```

**Update:** Use FitIQCore's `TokenRefreshClient`

```swift
// In AppDependencies
lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        networkClient: networkClient,
        baseURL: Config.baseURL,
        apiKey: Config.apiKey
    )
}()

// In API clients - use executeWithAutoRetry
let (data, response) = try await networkClient.executeWithAutoRetry(
    request: request,
    tokenRefreshClient: tokenRefreshClient,
    authTokenPersistence: authTokenPersistence
)
```

---

#### Lume Migration

**Update:** Replace Lume's `AuthToken` with FitIQCore's

```swift
// Before
struct AuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

// After
import FitIQCore
// Use FitIQCore's AuthToken (includes JWT parsing)
```

**Update:** Replace Lume's `TokenStorageProtocol` with FitIQCore's

```swift
// Before
private(set) lazy var tokenStorage: TokenStorageProtocol = {
    KeychainTokenStorage()
}()

// After
import FitIQCore

private(set) lazy var authTokenStorage: AuthTokenPersistenceProtocol = {
    KeychainAuthTokenStorage()
}()

private(set) lazy var tokenRefreshClient: TokenRefreshClient = {
    TokenRefreshClient(
        networkClient: networkClient,
        baseURL: AppConfiguration.shared.backendBaseURL,
        apiKey: AppConfiguration.shared.apiKey
    )
}()
```

**Update:** Remove manual refresh logic, use automatic retry

```swift
// Before - manual refresh in RemoteAuthService
func refreshToken(_ token: String) async throws -> AuthToken { ... }

// After - automatic via NetworkClient extension
// No manual refresh needed - executeWithAutoRetry handles it
```

---

## 📊 Migration Impact

### Code Reduction

| App | Files Removed | Lines Removed | Benefit |
|-----|---------------|---------------|---------|
| **FitIQ** | `AuthToken.swift` | ~280 | Use FitIQCore version |
| **Lume** | `AuthToken.swift` | ~50 | Upgrade to FitIQCore |
| **Lume** | `KeychainTokenStorage.swift` | ~200 | Use FitIQCore version |
| **Lume** | Manual refresh logic | ~100 | Automatic via FitIQCore |
| **Total** | 3-4 files | ~630 lines | Single source of truth ✅ |

### Features Gained

**Lume Benefits:**
- ✅ JWT parsing and validation
- ✅ Proactive token refresh (willExpireSoon)
- ✅ Thread-safe refresh (no race conditions)
- ✅ Automatic retry on 401
- ✅ Sanitized logging
- ✅ Production-ready auth

**FitIQ Benefits:**
- ✅ Reduced code duplication
- ✅ Shared improvements benefit both apps
- ✅ Consistent auth behavior

---

## 🎯 Implementation Checklist

### Phase 1: FitIQCore Enhancement

- [ ] Extract `AuthToken` entity to FitIQCore
- [ ] Add JWT parsing methods
- [ ] Add validation logic
- [ ] Create `TokenRefreshClient` in FitIQCore
- [ ] Add synchronization (NSLock)
- [ ] Create `executeWithAutoRetry` extension
- [ ] Write comprehensive tests
- [ ] Update FitIQCore README
- [ ] Bump version to v0.1.1

### Phase 2: FitIQ Migration

- [ ] Add `import FitIQCore` to auth files
- [ ] Remove `Domain/Entities/Auth/AuthToken.swift`
- [ ] Update to use FitIQCore's `AuthToken`
- [ ] Use FitIQCore's `TokenRefreshClient`
- [ ] Update API clients to use `executeWithAutoRetry`
- [ ] Run tests and verify
- [ ] Remove ~280 lines of duplicated code

### Phase 3: Lume Migration

- [ ] Add `import FitIQCore` to auth files
- [ ] Remove Lume's `AuthToken` struct
- [ ] Remove `KeychainTokenStorage.swift`
- [ ] Update to use FitIQCore's `AuthTokenPersistenceProtocol`
- [ ] Use FitIQCore's `TokenRefreshClient`
- [ ] Remove manual refresh logic
- [ ] Update HTTPClient to use `executeWithAutoRetry`
- [ ] Run tests and verify
- [ ] Remove ~350 lines of code

---

## 🚀 Recommended Approach

### Immediate (This Session)

1. **Extract AuthToken to FitIQCore** - Copy FitIQ's implementation
2. **Add TokenRefreshClient to FitIQCore** - With synchronization
3. **Add executeWithAutoRetry extension** - Automatic retry logic

### Next Session

4. **Test FitIQCore enhancements** - Comprehensive tests
5. **Migrate FitIQ first** - Lower risk (already uses this pattern)
6. **Verify FitIQ works** - End-to-end testing

### Following Session

7. **Migrate Lume** - Use FitIQCore's enhanced auth
8. **Remove Lume's manual refresh** - Replace with automatic
9. **Verify Lume works** - End-to-end testing

---

## 🎓 Key Insights

### Why FitIQ's Approach is Superior

1. **Thread Safety** - NSLock prevents race conditions during concurrent refreshes
2. **Task Deduplication** - Multiple requests share the same refresh task
3. **Automatic Retry** - Transparent to application layer
4. **JWT Parsing** - No manual expiration tracking needed
5. **Proactive Refresh** - Refreshes before expiration (willExpireSoon)
6. **Production-Ready** - Handles all edge cases

### Why Lume's Approach Needs Upgrade

1. **Race Conditions** - No synchronization on refresh
2. **Manual Handling** - Every feature must handle refresh
3. **No Proactive Refresh** - Waits for 401 errors
4. **Basic Implementation** - Minimal production features

---

## 📚 References

### FitIQ Files (Source of Truth)
- `Domain/Entities/Auth/AuthToken.swift` - Complete entity
- `Infrastructure/Network/UserAuthAPIClient.swift` - Synchronized refresh
- `Infrastructure/Network/ProgressAPIClient.swift` - Automatic retry pattern

### Lume Files (To Be Replaced)
- `Domain/Entities/AuthToken.swift` - Basic struct
- `Services/Authentication/KeychainTokenStorage.swift` - Simple storage
- `Services/Authentication/RemoteAuthService.swift` - Manual refresh

### FitIQCore Target Files
- `Auth/Domain/AuthToken.swift` - Extract from FitIQ
- `Auth/Infrastructure/TokenRefreshClient.swift` - New
- `Network/NetworkClientRetry.swift` - New extension

---

**Version:** 1.0  
**Status:** ✅ Analysis Complete - Ready for Implementation  
**Recommendation:** Extract FitIQ's auth to FitIQCore, migrate both apps  
**Estimated Effort:** 2-3 days (1 day FitIQCore, 1 day FitIQ, 1 day Lume)