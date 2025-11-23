# SleepAPIClient Configuration Pattern

**Date:** 2025-01-27  
**Pattern:** Constructor-Based Configuration  
**Status:** ✅ Implemented

---

## Overview

The `SleepAPIClient` follows a clean dependency injection pattern where configuration values (`apiKey` and `baseURL`) are passed as constructor parameters. This is the **recommended pattern** for all API clients in the application.

---

## Design Philosophy

### ✅ Good Pattern (Constructor Injection)

```swift
init(
    networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
    baseURL: String,
    apiKey: String,
    authTokenPersistence: AuthTokenPersistencePortProtocol,
    authManager: AuthManager
) {
    self.networkClient = networkClient
    self.baseURL = baseURL
    self.apiKey = apiKey
    self.authTokenPersistence = authTokenPersistence
    self.authManager = authManager
}
```

**Benefits:**
- ✅ **Explicit Dependencies** - Clear what the client needs
- ✅ **Testability** - Easy to inject mock values
- ✅ **Single Configuration Point** - Load config once in AppDependencies
- ✅ **Fail Fast** - App crashes at startup if misconfigured
- ✅ **Type Safety** - Compiler ensures all parameters are provided

### ❌ Anti-Pattern (Internal Configuration Loading)

```swift
init(
    networkClient: NetworkClientProtocol,
    authTokenPersistence: AuthTokenPersistencePortProtocol,
    authManager: AuthManager
) {
    self.networkClient = networkClient
    self.authTokenPersistence = authTokenPersistence
    self.authManager = authManager
    self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
    self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
}
```

**Problems:**
- ❌ **Hidden Dependencies** - Config loading not visible in signature
- ❌ **Hard to Test** - Can't inject test values easily
- ❌ **Multiple Config Loads** - Each client loads config separately
- ❌ **Silent Failures** - `?? ""` hides missing config until runtime
- ❌ **Tight Coupling** - Client depends on ConfigurationProperties

---

## Implementation

### 1. SleepAPIClient (Constructor)

```swift
final class SleepAPIClient: SleepAPIClientProtocol {
    
    // MARK: - Dependencies
    
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let authManager: AuthManager
    
    // MARK: - Initialization
    
    init(
        networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
        baseURL: String,
        apiKey: String,
        authTokenPersistence: AuthTokenPersistencePortProtocol,
        authManager: AuthManager
    ) {
        self.networkClient = networkClient
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.authTokenPersistence = authTokenPersistence
        self.authManager = authManager
    }
    
    // ... API methods
}
```

### 2. AppDependencies (Configuration Loading)

```swift
static func build(authManager: AuthManager) -> AppDependencies {
    print("--- AppDependencies.build() called ---")
    
    // MARK: - Configuration (Load Once, Crash if Missing)
    guard let baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL"),
          !baseURL.isEmpty else {
        fatalError("BACKEND_BASE_URL not configured in config.plist")
    }
    
    guard let apiKey = ConfigurationProperties.value(for: "API_KEY"),
          !apiKey.isEmpty else {
        fatalError("API_KEY not configured in config.plist")
    }
    
    print("AppDependencies: Configuration loaded - baseURL: \(baseURL)")
    
    // ... other dependencies
    
    // MARK: - Sleep Tracking
    let sleepAPIClient = SleepAPIClient(
        networkClient: networkClient,
        baseURL: baseURL,  // ✅ Pass from config
        apiKey: apiKey,     // ✅ Pass from config
        authTokenPersistence: keychainAuthTokenAdapter,
        authManager: authManager
    )
    
    // ... rest of build
}
```

---

## Why Fail Fast?

### The Problem with `?? ""`

```swift
// ❌ BAD: Silent failure
let baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
// App continues running with empty string
// API calls fail at runtime with cryptic errors
// Hard to debug in production
```

### The Solution: `fatalError()`

```swift
// ✅ GOOD: Immediate failure
guard let baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL"),
      !baseURL.isEmpty else {
    fatalError("BACKEND_BASE_URL not configured in config.plist")
}
// App crashes immediately at startup
// Clear error message in logs
// Impossible to ship misconfigured app
```

**Benefits:**
- 🚀 **Catch Before Production** - Crashes in dev/QA, never reaches users
- 🔍 **Clear Error Messages** - Exact problem stated in crash log
- 🛡️ **Prevents Silent Bugs** - No mysterious API failures later
- 📱 **App Store Review** - Catches issues during testing phase

---

## Configuration File

**Location:** `Resources/config.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_KEY</key>
    <string>YOUR_API_KEY_HERE</string>
    <key>BACKEND_BASE_URL</key>
    <string>https://fit-iq-backend.fly.dev</string>
</dict>
</plist>
```

**Important:** Both values are **REQUIRED**. The app will crash at startup if either is missing or empty.

---

## Request Headers

All API requests now properly include:

```swift
var urlRequest = URLRequest(url: URL(string: "\(baseURL)/api/v1/sleep")!)
urlRequest.httpMethod = "POST"
urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

// Add JWT token for authenticated requests
if let token = try? await authTokenPersistence.retrieveAccessToken() {
    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

**Result:**
```
POST /api/v1/sleep HTTP/1.1
Host: fit-iq-backend.fly.dev
Content-Type: application/json
X-API-Key: <your-api-key>
Authorization: Bearer <jwt-token>
```

---

## Testing

### Unit Tests

```swift
func testSleepAPIClient() async throws {
    let mockNetworkClient = MockNetworkClient()
    let mockAuthPersistence = MockAuthTokenPersistence()
    let mockAuthManager = MockAuthManager()
    
    let client = SleepAPIClient(
        networkClient: mockNetworkClient,
        baseURL: "https://test.example.com",  // ✅ Easy to inject
        apiKey: "test-api-key",                // ✅ Easy to inject
        authTokenPersistence: mockAuthPersistence,
        authManager: mockAuthManager
    )
    
    // ... test API calls
}
```

### Integration Tests

```swift
func testAppDependencies() {
    // This will crash if config is missing (expected behavior)
    let deps = AppDependencies.build(authManager: authManager)
    
    XCTAssertNotNil(deps.sleepAPIClient)
}
```

---

## Migration Guide

### For Other API Clients

To refactor existing API clients to this pattern:

1. **Add constructor parameters:**
   ```swift
   init(
       networkClient: NetworkClientProtocol = URLSessionNetworkClient(),
       baseURL: String,  // ✅ Add this
       apiKey: String,   // ✅ Add this
       // ... other dependencies
   )
   ```

2. **Remove internal config loading:**
   ```swift
   // ❌ Remove this
   self.baseURL = ConfigurationProperties.value(for: "BACKEND_BASE_URL") ?? ""
   self.apiKey = ConfigurationProperties.value(for: "API_KEY") ?? ""
   ```

3. **Update AppDependencies:**
   ```swift
   let myAPIClient = MyAPIClient(
       networkClient: networkClient,
       baseURL: baseURL,  // ✅ Pass from top-level config
       apiKey: apiKey,    // ✅ Pass from top-level config
       // ... other dependencies
   )
   ```

---

## Recommended Pattern for All API Clients

| Client | Pattern | Status |
|--------|---------|--------|
| `SleepAPIClient` | ✅ Constructor Injection | Implemented |
| `ProgressAPIClient` | ⏳ Internal Config Loading | **Should Refactor** |
| `UserAuthAPIClient` | ⏳ Internal Config Loading | **Should Refactor** |
| `RemoteHealthDataSyncClient` | ⏳ Internal Config Loading | **Should Refactor** |
| `ProfileMetadataClient` | ⏳ Internal Config Loading | **Should Refactor** |

**Goal:** All API clients should use constructor injection for `baseURL` and `apiKey`.

---

## Summary

### What Changed
- ✅ `SleepAPIClient` accepts `baseURL` and `apiKey` as constructor parameters
- ✅ `AppDependencies` loads config once at the top with `fatalError()` on missing values
- ✅ Config values passed downstream to all clients that need them
- ✅ App crashes immediately at startup if misconfigured

### Why This Is Better
- 🎯 **Single Responsibility** - Client focuses on API calls, not config loading
- 🧪 **Testability** - Easy to inject test values
- 🚀 **Fail Fast** - Catches config issues in dev/QA
- 📦 **Explicit Dependencies** - Clear what each client needs
- 🔄 **Consistency** - One config loading point for entire app

---

**Status:** ✅ Implemented and verified  
**Next Steps:** Consider refactoring other API clients to use this pattern