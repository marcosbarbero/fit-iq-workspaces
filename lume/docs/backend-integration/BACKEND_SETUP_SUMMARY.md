# 🔌 Backend Configuration Setup - Summary

**Date:** 2025-01-15  
**Status:** ✅ Complete and Ready  
**Purpose:** Quick guide to backend configuration

---

## What Was Done

### 1. Created Configuration System
- `lume/Core/Configuration/AppConfiguration.swift` - Centralized config manager
- Reads from `config.plist` at runtime
- Type-safe access to backend URLs and API keys
- Environment detection (production vs development)

### 2. Updated Authentication Service
- `RemoteAuthService.swift` now uses `AppConfiguration`
- Automatically includes API key in all requests (`X-API-Key` header)
- Uses configured backend URL instead of hardcoded values

### 3. Integrated with Dependency Injection
- `AppDependencies.swift` simplified to use configuration
- No more hardcoded URLs in code
- Single source of truth in `config.plist`

---

## Current Configuration

### config.plist Location
```
lume/lume/config.plist
```

### Current Values
```xml
BACKEND_BASE_URL: https://fit-iq-backend.fly.dev
API_KEY: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW
WebSocketURL: wss://fit-iq-backend.fly.dev/ws/meal-logs
```

✅ **Note:** These URLs point to the partner backend infrastructure (fit-iq-backend.fly.dev) which is correct! Lume is part of a broader solution landscape.

---

## How It Works

### 1. Configuration Loading
```swift
// App reads config.plist on launch
let config = AppConfiguration.shared

// Provides type-safe access
let baseURL = config.backendBaseURL  // URL
let apiKey = config.apiKey           // String
```

### 2. API Requests
All authentication requests automatically:
- Use `backendBaseURL` from config
- Include `X-API-Key` header with your API key
- Append correct endpoint paths

Example:
```
POST https://fit-iq-backend.fly.dev/api/v1/auth/register
Headers:
  Content-Type: application/json
  X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW
```

### 3. API Endpoints
The app calls these endpoints:

| Endpoint | Purpose |
|----------|---------|
| `/api/v1/auth/register` | User registration |
| `/api/v1/auth/login` | User login |
| `/api/v1/auth/refresh` | Token refresh |
| `/api/v1/auth/logout` | User logout |

---

## Quick Start

### For Development
1. Update `config.plist` with your backend URL:
   ```xml
   <key>BACKEND_BASE_URL</key>
   <string>http://localhost:8080</string>
   ```

2. Set your API key:
   ```xml
   <key>API_KEY</key>
   <string>your-dev-api-key</string>
   ```

3. Build and run - the app will use your configuration!

### For Production
1. Use HTTPS URL:
   ```xml
   <key>BACKEND_BASE_URL</key>
   <string>https://api.lume.app</string>
   ```

2. Use production API key:
   ```xml
   <key>API_KEY</key>
   <string>your-secure-production-key</string>
   ```

3. Keep production config secret!

---

## Testing Backend Connection

### Debug Output
Add this to see configuration on launch:

```swift
// In lumeApp.swift or AppDelegate
#if DEBUG
AppConfiguration.shared.printConfiguration()
#endif
```

Output:
```
=== App Configuration ===
Backend URL: https://fit-iq-backend.fly.dev
API Key: ********************************
Environment: Development
========================
```

### Test Registration Flow
1. Launch app
2. Tap "Sign Up"
3. Fill in details
4. Tap "Create Account"
5. Check console for network requests

### Expected Request
```
POST https://fit-iq-backend.fly.dev/api/v1/auth/register
Content-Type: application/json
X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

---

## Backend Requirements

Your backend must:

### 1. Accept API Key
Check `X-API-Key` header in all requests:
```
X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW
```

Return 401 if missing or invalid.

### 2. Implement Auth Endpoints

**POST /api/v1/auth/register**
- Accept: `email`, `password`, `name`
- Return: `user_id`, `email`, `name`, `created_at`, `access_token`, `refresh_token`
- Status: 201 (success), 400 (invalid), 409 (already exists)

**POST /api/v1/auth/login**
- Accept: `email`, `password`
- Return: `access_token`, `refresh_token`
- Status: 200 (success), 401 (invalid credentials)

**POST /api/v1/auth/refresh**
- Accept: `refresh_token`
- Return: `access_token`, `refresh_token`
- Status: 200 (success), 401 (token expired)

### 3. Response Format
```json
{
  "data": {
    "user_id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2025-01-15T10:00:00Z",
    "access_token": "jwt_token_here",
    "refresh_token": "refresh_token_here"
  }
}
```

---

## Security Notes

### ✅ Good Practices
- API key sent in headers (not URL)
- HTTPS for production
- Tokens stored in iOS Keychain
- Configuration outside source code

### ⚠️ Important
- Don't commit production API keys to public repos
- Rotate keys periodically
- Use different keys per environment
- Monitor API key usage

---

## Troubleshooting

### "config.plist not found"
**Solution:** Add `config.plist` to Xcode target
1. Drag file into Xcode
2. Check "lume" target membership
3. Verify in "Copy Bundle Resources"

### "BACKEND_BASE_URL not configured"
**Solution:** Check plist key spelling
```xml
<key>BACKEND_BASE_URL</key>  ✅ Correct
<key>backend_base_url</key>  ❌ Wrong case
```

### "Connection failed"
**Solutions:**
- Check backend is running
- Verify URL is correct (with protocol: https://)
- Check API key is valid
- Test with curl or Postman first

### "Invalid API Key"
**Solutions:**
- Verify key in config.plist matches backend
- Check backend is validating `X-API-Key` header
- Ensure no extra spaces in key

---

## Next Steps

1. ~~**Update URLs**~~ ✅ Already configured with partner backend (fit-iq-backend.fly.dev)
2. ~~**Get API Key**~~ ✅ Already configured
3. **Add to Xcode** - Ensure config.plist is in the Xcode target
4. **Test Authentication** - Try registration and login flows
5. **Verify Backend** - Ensure partner backend endpoints are live
6. **Test End-to-End** - Full auth flow with partner backend

---

## Files to Review

- **Configuration:** `lume/Core/Configuration/AppConfiguration.swift`
- **Auth Service:** `lume/Services/Authentication/RemoteAuthService.swift`
- **Dependencies:** `lume/DI/AppDependencies.swift`
- **Config File:** `lume/config.plist`
- **Full Docs:** `docs/BACKEND_CONFIGURATION.md`

---

## Quick Reference

```swift
// Access configuration
AppConfiguration.shared.backendBaseURL  // URL
AppConfiguration.shared.apiKey          // String
AppConfiguration.shared.isProduction    // Bool

// Endpoint paths
AppConfiguration.Endpoints.authRegister  // "/api/v1/auth/register"
AppConfiguration.Endpoints.authLogin     // "/api/v1/auth/login"
AppConfiguration.Endpoints.authRefresh   // "/api/v1/auth/refresh"
```

---

## Status: Ready for Backend Integration ✨

The configuration system is complete. Update `config.plist` with your backend details and you're ready to test authentication!

**Remember:** The app will automatically use these values - no code changes needed to switch environments!