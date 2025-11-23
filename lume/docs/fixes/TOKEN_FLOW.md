# Token Refresh Flow - Before & After

## Before Fix ❌

```
Token expires
    ↓
RefreshTokenUseCase.execute()
    ↓
AuthRepository.refreshToken()
    ↓
RemoteAuthService.refreshToken()
    ↓
Backend returns 401 "refresh token has been revoked"
    ↓
Throw tokenExpired error
    ↓
RootView catches error
    ↓
Sets isAuthenticated = false
    ↓
BUT: Token still in storage! 🐛
BUT: UserSession still active! 🐛
    ↓
Next time app tries to refresh...
    ↓
Same 401 error again...
    ↓
INFINITE LOOP! 🐛
```

## After Fix ✅

```
Token expires
    ↓
RefreshTokenUseCase.execute()
    ↓
AuthRepository.refreshToken()
    ↓
RemoteAuthService.refreshToken()
    ↓
Backend returns 401 "refresh token has been revoked"
    ↓
Detect "revoked" in response
    ↓
Throw tokenRevoked error (specific!)
    ↓
AuthRepository catches tokenRevoked
    ↓
1. Delete token from storage ✅
2. End UserSession ✅
3. Re-throw error
    ↓
RootView catches error
    ↓
1. Delete token (already done) ✅
2. End session (already done) ✅
3. Set isAuthenticated = false ✅
    ↓
User sees login screen ✅
No retry loop! ✅
Clean state! ✅
```

## Key Changes

### 1. New Error Type
```swift
enum AuthenticationError {
    case tokenExpired     // Generic expiration
    case tokenRevoked     // Specifically revoked (NEW!)
}
```

### 2. Detection
```swift
// RemoteAuthService.swift
if responseString.lowercased().contains("revoked") {
    throw AuthenticationError.tokenRevoked
}
```

### 3. Cleanup
```swift
// AuthRepository.swift
case .tokenExpired, .tokenRevoked:
    try? await tokenStorage.deleteToken()
    UserSession.shared.endSession()
    throw error
```

### 4. All Entry Points
- ✅ RootView (startup)
- ✅ AuthRepository (refresh)
- ✅ OutboxProcessor (background)

## Result

**One revoked token = Clean logout everywhere**
