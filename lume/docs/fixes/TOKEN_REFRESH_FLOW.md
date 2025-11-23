# Token Refresh Flow - Complete Code Path

## Where Token Refresh is Triggered

### 1. RootView - App Startup (Line 128)
```swift
// File: Presentation/RootView.swift
func checkAuthenticationStatus() async {
    // ...
    if token.needsRefresh {
        _ = try await dependencies.refreshTokenUseCase.execute()
    }
}
```

### 2. RootView - Background Validation (Line 179)
```swift
// File: Presentation/RootView.swift
func validateAndRefreshTokenIfNeeded() async {
    if token.needsRefresh {
        _ = try await dependencies.refreshTokenUseCase.execute()
    }
}
```

### 3. OutboxProcessor - Before Processing Events (Line 129-133)
```swift
// File: Services/Outbox/OutboxProcessorService.swift
func processOutbox() async {
    if token.isExpired || token.needsRefresh {
        token = try await refreshUseCase.execute()
    }
}
```

## Complete Call Stack

```
1. User Action / App Event
   ↓
2. Check: token.needsRefresh or token.isExpired
   ↓
3. Call: refreshTokenUseCase.execute()
   ↓
4. Domain/UseCases/RefreshTokenUseCase.swift
   func execute() async throws -> AuthToken {
       return try await authRepository.refreshToken()
   }
   ↓
5. Data/Repositories/AuthRepository.swift
   func refreshToken() async throws -> AuthToken {
       // Get current token
       guard let currentToken = try await tokenStorage.getToken()
       
       // Call auth service
       let newToken = try await authService.refreshToken(currentToken.refreshToken)
       
       // Save new token
       try await tokenStorage.saveToken(newToken)
       
       return newToken
   }
   ↓
6. Services/Authentication/RemoteAuthService.swift
   func refreshToken(_ token: String) async throws -> AuthToken {
       // POST /api/v1/auth/refresh
       // Body: {"refresh_token": "..."}
       
       // Decode response
       let apiResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
       
       // PROBLEM: Hardcoded expiration!
       return AuthToken(
           accessToken: apiResponse.data.accessToken,
           refreshToken: apiResponse.data.refreshToken,
           expiresAt: Date().addingTimeInterval(3600) // ← WRONG!
       )
   }
   ↓
7. NEW TOKEN SAVED TO KEYCHAIN (Services/Authentication/KeychainTokenStorage.swift)
   func saveToken(_ token: AuthToken) async throws {
       // Save to iOS Keychain
   }
```

## Token Expiration Check Logic

```swift
// File: Domain/Entities/AuthToken.swift

var isExpired: Bool {
    Date() >= expiresAt  // Has expiration passed?
}

var needsRefresh: Bool {
    // Refresh if token expires within the next 5 minutes
    let refreshThreshold = Date().addingTimeInterval(5 * 60)
    return expiresAt <= refreshThreshold
}
```

## The Problem in Detail

### Current Flow (BROKEN):
```
1. Backend returns token with actual expiration (e.g., 15 min)
2. App ignores this and sets expiresAt = now + 1 hour
3. After 15 min: access_token expired on backend
4. After 15 min: app thinks token valid for 45 more minutes!
5. App makes API call with expired access_token
6. Backend: 401 Unauthorized
7. App: "Why 401? Token should be valid!" 🤔
8. Eventually triggers refresh
9. Backend: "Refresh token revoked" (too late)
10. Loop continues...
```

### Fixed Flow (with JWT decoding):
```
1. Backend returns token
2. App decodes JWT "exp" claim → Real expiration = 15 min
3. App sets expiresAt = decoded value (15 min)
4. After 10 min: needsRefresh = true (5 min buffer)
5. App refreshes proactively BEFORE expiration
6. Backend: Here's new token
7. App continues working ✅
```

## All Files Involved

1. **Domain/Entities/AuthToken.swift** - Token model
2. **Domain/Ports/AuthServiceProtocol.swift** - Service interface
3. **Domain/Ports/AuthRepositoryProtocol.swift** - Repository interface
4. **Domain/UseCases/RefreshTokenUseCase.swift** - Use case
5. **Data/Repositories/AuthRepository.swift** - Repository implementation
6. **Services/Authentication/RemoteAuthService.swift** - HTTP client
7. **Services/Authentication/KeychainTokenStorage.swift** - Storage
8. **Presentation/RootView.swift** - Trigger point
9. **Services/Outbox/OutboxProcessorService.swift** - Another trigger

## My Fix

In `RemoteAuthService.swift`, I added:

```swift
// Decode JWT to get real expiration
private func decodeJWTExpiration(token: String) -> Date? {
    // Parse JWT payload
    // Extract "exp" claim
    // Convert to Date
}

// Use JWT expiration or conservative fallback
private func getTokenExpiration(accessToken: String) -> Date {
    if let jwtExp = decodeJWTExpiration(token: accessToken) {
        return jwtExp  // Use real expiration
    }
    return Date().addingTimeInterval(15 * 60)  // 15 min fallback
}
```

Then replaced:
```swift
expiresAt: Date().addingTimeInterval(3600)  // OLD
```

With:
```swift
expiresAt: getTokenExpiration(accessToken: apiResponse.data.accessToken)  // NEW
```

## Testing the Fix

Check logs for:
```
✅ [RemoteAuthService] Decoded JWT expiration: 2025-01-28 12:30:00
```

Or:
```
⚠️ [RemoteAuthService] Using conservative default expiration: 15 minutes
```

Then verify no premature 401 errors before token should expire.
