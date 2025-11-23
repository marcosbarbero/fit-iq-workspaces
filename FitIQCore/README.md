# FitIQCore

**Version:** 0.2.0 (Phase 1 - Enhanced Authentication)  
**Platform:** iOS 17+  
**Language:** Swift 5.9+

---

## 📋 Overview

FitIQCore is a shared Swift Package containing common infrastructure code used by both the **FitIQ** (fitness tracking) and **Lume** (wellness/mood tracking) iOS applications.

This package follows **Hexagonal Architecture** (Ports & Adapters) principles, ensuring clean separation between domain logic and infrastructure implementations.

---

## 🎯 Purpose

FitIQCore was created to:
- **Eliminate code duplication** between FitIQ and Lume apps
- **Provide shared infrastructure** (authentication, networking, HealthKit, etc.)
- **Ensure consistency** in how both apps handle core functionality
- **Speed up development** of new apps by reusing battle-tested code
- **Simplify maintenance** by fixing bugs once and benefiting both apps

---

## 📦 What's Included

### Phase 1: Critical Infrastructure (Current)

#### ✅ Authentication (Enhanced)
- `AuthManager` - Manages authentication state and user sessions
- `AuthState` - Authentication state enum (logged out, needs setup, logged in, etc.)
- `AuthToken` - **NEW** Production-ready JWT token entity with parsing, validation, expiration tracking
- `AuthTokenPersistenceProtocol` - Domain port for token storage
- `KeychainAuthTokenStorage` - Keychain-based token storage implementation
- `TokenRefreshClient` - **NEW** Thread-safe token refresh with synchronized deduplication
- `KeychainManager` - Low-level Keychain operations
- `KeychainError` - Keychain-specific errors

**New Features:**
- JWT payload parsing (exp, sub, email claims)
- Automatic expiration detection
- Proactive refresh triggering (5-minute window)
- Thread-safe token refresh synchronization
- Automatic retry on 401 with token refresh

#### ✅ Networking (Enhanced)
- `NetworkClientProtocol` - Network client abstraction
- `URLSessionNetworkClient` - URLSession-based network client
- `NetworkClient+AutoRetry` - **NEW** Automatic retry extension with token refresh on 401 errors
- `StandardAPIResponse<T>` - **NEW** Wrapper for FitIQ backend response format
- `APIError` - Common API error types
- `NetworkError` - Network-specific errors

**New Features:**
- Automatic 401 detection and token refresh
- Single retry attempt to prevent infinite loops
- Standard response unwrapping utilities
- Thread-safe token update callbacks

#### ✅ Common Errors
- `APIError` - API-related errors
- `KeychainError` - Keychain-related errors

---

## 🏗️ Architecture

FitIQCore follows **Hexagonal Architecture**:

```
┌─────────────────────────────────────────────────┐
│              App Layer (FitIQ/Lume)             │
│                                                 │
│   ┌─────────────────────────────────────────┐  │
│   │         Domain Layer (Ports)            │  │
│   │  • Protocols (AuthTokenPersistence)     │  │
│   │  • Entities (AuthState, User)           │  │
│   │  • Use Cases (AuthManager)              │  │
│   └─────────────────────────────────────────┘  │
│                      ▲                          │
│                      │ depends on              │
│                      │                          │
│   ┌─────────────────────────────────────────┐  │
│   │    Infrastructure Layer (Adapters)      │  │
│   │  • KeychainAuthTokenStorage             │  │
│   │  • URLSessionNetworkClient              │  │
│   │  • HealthKitAdapter (Phase 2)           │  │
│   └─────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Key Principles:**
- Domain defines interfaces (ports via protocols)
- Infrastructure implements interfaces (adapters)
- Apps depend only on domain abstractions
- Use dependency injection for all dependencies

---

## 🚀 Installation

### Option 1: Swift Package Manager (Recommended)

Add FitIQCore as a local package dependency in your Xcode project:

1. File → Add Packages...
2. Select "Add Local..."
3. Navigate to `fit-iq/FitIQCore`
4. Select "Add Package"

### Option 2: Package.swift

Add FitIQCore to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../FitIQCore")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["FitIQCore"]
    )
]
```

---

## 💻 Usage

### Authentication

#### Basic Authentication Flow

```swift
import FitIQCore

// 1. Create token persistence
let tokenStorage = KeychainAuthTokenStorage()

// 2. Initialize AuthManager
let authManager = AuthManager(
    authTokenPersistence: tokenStorage,
    onboardingKey: "hasFinishedOnboardingSetup"
)

// 3. Use in your app
// Check authentication status
await authManager.checkAuthenticationStatus()

// Handle successful login
await authManager.handleSuccessfulAuth(userProfileID: userID)

// Logout
await authManager.logout()

// Access current state
if authManager.isAuthenticated {
    print("User is logged in: \(authManager.currentUserProfileID)")
}
```

#### Working with JWT Tokens (New!)

```swift
import FitIQCore

// Create token with automatic JWT parsing
let token = AuthToken.withParsedExpiration(
    accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    refreshToken: "refresh_token_abc123"
)

// Check expiration
if token.isExpired {
    print("Token has expired")
} else if token.willExpireSoon {
    print("Token will expire in \(token.secondsUntilExpiration ?? 0) seconds")
    // Proactively refresh
}

// Parse JWT claims
if let userId = token.parseUserIdFromJWT() {
    print("User ID: \(userId)")
}

if let email = token.parseEmailFromJWT() {
    print("Email: \(email)")
}

if let expiration = token.parseExpirationFromJWT() {
    print("Expires at: \(expiration)")
}

// Validate token
let errors = token.validate()
if errors.isEmpty {
    print("Token is valid")
} else {
    print("Validation errors: \(errors)")
}

// Safe logging (hides sensitive data)
print(token.sanitizedDescription)
// Output: AuthToken(access: eyJhbGciOi...VCJ9, refresh: refresh_to...c123, expires: 2025-01-27 15:30:00)
```

#### Thread-Safe Token Refresh (New!)

```swift
import FitIQCore

// 1. Create refresh client
let refreshClient = TokenRefreshClient(
    baseURL: "https://api.example.com",
    apiKey: "your-api-key",
    networkClient: URLSessionNetworkClient()
)

// 2. Refresh token (thread-safe - multiple concurrent calls will share result)
let newTokens = try await refreshClient.refreshToken(
    refreshToken: "old-refresh-token"
)

// 3. Save new tokens
try tokenStorage.save(
    accessToken: newTokens.accessToken,
    refreshToken: newTokens.refreshToken
)

print("New access token: \(newTokens.accessToken)")
print("New refresh token: \(newTokens.refreshToken)")
```

#### Automatic Retry with Token Refresh (New!)

```swift
import FitIQCore

// Network client with automatic retry on 401 errors
let networkClient = URLSessionNetworkClient()
let refreshClient = TokenRefreshClient(...)

var request = URLRequest(url: URL(string: "https://api.example.com/profile")!)
request.httpMethod = "GET"
request.setValue("Bearer \(oldToken)", forHTTPHeaderField: "Authorization")

// If request fails with 401, automatically refreshes token and retries
let (data, response) = try await networkClient.executeWithAutoRetry(
    request: request,
    refreshClient: refreshClient,
    currentRefreshToken: "current-refresh-token",
    onTokenRefreshed: { newAccessToken in
        // Save new token to storage
        try await tokenStorage.save(
            accessToken: newAccessToken,
            refreshToken: "new-refresh-token"
        )
    }
)

// Or decode response directly
let user: User = try await networkClient.executeWithAutoRetry(
    request: request,
    responseType: User.self,
    refreshClient: refreshClient,
    currentRefreshToken: "current-refresh-token",
    onTokenRefreshed: { newAccessToken in
        // Save new token
    }
)

// Or unwrap standard API response
let userData: UserData = try await networkClient.executeWithAutoRetryAndUnwrap(
    request: request,
    dataType: UserData.self,
    refreshClient: refreshClient,
    currentRefreshToken: "current-refresh-token",
    onTokenRefreshed: { newAccessToken in
        // Save new token
    }
)
```

### Networking

```swift
import FitIQCore

// 1. Create network client
let networkClient = URLSessionNetworkClient()

// 2. Build request
var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
request.httpMethod = "GET"
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// 3. Execute request
do {
    let (data, response) = try await networkClient.executeRequest(request: request)
    let user = try JSONDecoder().decode(User.self, from: data)
    print("User: \(user)")
} catch let error as APIError {
    // Handle API errors
    print("API Error: \(error.localizedDescription)")
}
```

### Keychain Storage

```swift
import FitIQCore

// Save data
try KeychainManager.save(key: "myKey", value: "myValue")

// Read data
if let value = try KeychainManager.read(key: "myKey") {
    print("Retrieved: \(value)")
}

// Delete data
try KeychainManager.delete(key: "myKey")
```

---

## 📁 Project Structure

```
FitIQCore/
├── Package.swift                    # Swift Package manifest
├── README.md                        # This file
├── CHANGELOG.md                     # Version history
│
├── Sources/FitIQCore/
│   ├── Auth/                        # Authentication module
│   │   ├── Domain/
│   │   │   ├── AuthManager.swift
│   │   │   ├── AuthState.swift
│   │   │   ├── AuthToken.swift                    # NEW: JWT token with parsing
│   │   │   └── AuthTokenPersistenceProtocol.swift
│   │   └── Infrastructure/
│   │       ├── KeychainAuthTokenStorage.swift
│   │       ├── KeychainManager.swift
│   │       ├── KeychainError.swift
│   │       └── TokenRefreshClient.swift           # NEW: Thread-safe refresh
│   │
│   ├── Network/                     # Networking module
│   │   ├── NetworkClientProtocol.swift
│   │   ├── URLSessionNetworkClient.swift
│   │   └── NetworkClient+AutoRetry.swift          # NEW: Auto-retry extension
│   │
│   └── Common/                      # Common utilities
│       └── Errors/
│           └── APIError.swift
│
└── Tests/FitIQCoreTests/           # Unit tests
    ├── Auth/
    │   ├── AuthManagerTests.swift
    │   ├── AuthTokenTests.swift                   # NEW: 618 lines of tests
    │   ├── KeychainAuthTokenStorageTests.swift
    │   └── TokenRefreshClientTests.swift          # NEW: 484 lines of tests
    └── Network/
```

---

## 🧪 Testing

Run tests using:

```bash
cd FitIQCore
swift test
```

Or in Xcode:
- Open `Package.swift` in Xcode
- Press `Cmd+U` to run tests

---

## 📝 Naming Conventions

### Protocols
- End with `Protocol` (e.g., `AuthTokenPersistenceProtocol`)
- Define contracts/ports in the domain layer

### Implementations
- Descriptive names (e.g., `KeychainAuthTokenStorage`, `URLSessionNetworkClient`)
- Located in Infrastructure layer

### Errors
- End with `Error` (e.g., `APIError`, `KeychainError`)
- Conform to `Error` and `LocalizedError`

---

## 🚧 Roadmap

### ✅ Phase 1: Critical Infrastructure (COMPLETE)
- ✅ Basic authentication (AuthManager, AuthState)
- ✅ Token persistence (Keychain)
- ✅ Basic networking (URLSession client)
- ✅ **Enhanced: JWT parsing and validation**
- ✅ **Enhanced: Thread-safe token refresh**
- ✅ **Enhanced: Automatic retry with token refresh**
- ✅ **Enhanced: Comprehensive test coverage (1000+ lines)**

### Phase 2: Health & Profile (Planned)
- HealthKit integration (authorization, queries, data types)
- User profile management
- Physical attributes tracking
- Profile synchronization

### Phase 3: Utilities & UI (Planned)
- SwiftData utilities
- Common UI components
- Date/String extensions
- Logger utilities

---

## 🤝 Contributing

This is a shared package used by multiple apps. When making changes:

1. **Ensure backward compatibility** - don't break existing apps
2. **Write tests** - all new code should have unit tests
3. **Update documentation** - keep this README and code comments up to date
4. **Follow architecture** - maintain Hexagonal Architecture principles
5. **Use semantic versioning** - increment version appropriately

### Adding New Features

```
1. Create domain entities/protocols (Domain/)
2. Implement infrastructure adapters (Infrastructure/)
3. Write comprehensive unit tests (Tests/)
4. Update README.md with usage examples
5. Update CHANGELOG.md
6. Update Package.swift if needed
7. Increment version number appropriately
```

### Code Quality Standards

- **Test Coverage:** All new code must have unit tests
- **Thread Safety:** Mark types as `Sendable` where appropriate
- **Documentation:** All public APIs must have documentation comments
- **Error Handling:** Use typed errors with `LocalizedError`
- **Security:** Never log sensitive data (use sanitized descriptions)

---

## 📚 Resources

### Related Documentation
- [Split Strategy Cleanup](../docs/split-strategy/SPLIT_STRATEGY_CLEANUP_COMPLETE.md)
- [Shared Library Assessment](../docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md)
- [FitIQ Architecture](../FitIQ/docs/architecture/)
- [Copilot Instructions](../.github/COPILOT_INSTRUCTIONS_UNIFIED.md)

### External Resources
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Swift Package Manager](https://www.swift.org/package-manager/)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

---

## 📄 License

This package is part of the FitIQ project and follows the same license.

---

## 🆘 Support

For questions or issues:
1. Check existing documentation in `docs/`
2. Review the [Shared Library Assessment](../docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md)
3. Consult the [Copilot Instructions](../.github/COPILOT_INSTRUCTIONS_UNIFIED.md)

---

**Version:** 0.2.0 (Phase 1 - Enhanced Authentication)  
**Status:** ✅ Production Ready  
**Last Updated:** 2025-01-27  
**Changes:**
- Added `AuthToken` with JWT parsing, validation, and expiration tracking
- Added `TokenRefreshClient` with thread-safe synchronization
- Added `NetworkClient+AutoRetry` for automatic 401 handling
- Added 1000+ lines of comprehensive unit tests
- Enhanced security with sanitized logging

**Next Phase:** Phase 2 - Health & Profile (HealthKit, Profile Management)