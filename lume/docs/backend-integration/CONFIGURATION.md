# Backend Configuration Guide

**Date:** 2025-01-15  
**Purpose:** Configure backend connection for Lume iOS app  
**Status:** ✅ Production-Ready

---

## Overview

The Lume iOS app uses a `config.plist` file to manage backend configuration. This allows you to:
- Switch between environments (development, staging, production)
- Secure API keys outside of code
- Configure backend URLs without recompiling

---

## Configuration File

### Location
```
lume/
└── lume/
    └── config.plist
```

### Current Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BACKEND_BASE_URL</key>
    <string>https://fit-iq-backend.fly.dev</string>
    
    <key>API_KEY</key>
    <string>4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW</string>
    
    <key>WebSocketURL</key>
    <string>wss://fit-iq-backend.fly.dev/ws/meal-logs</string>
</dict>
</plist>
```

---

## Configuration Keys

### Required Keys

#### `BACKEND_BASE_URL`
- **Type:** String (URL)
- **Required:** Yes
- **Purpose:** Base URL for all API requests
- **Example:** `https://api.lume.app`
- **Current:** `https://fit-iq-backend.fly.dev`

#### `API_KEY`
- **Type:** String
- **Required:** Yes
- **Purpose:** API key for backend authentication
- **Security:** Sent as `X-API-Key` header in all requests
- **Note:** Should be kept secret and not committed to public repos

### Optional Keys

#### `WebSocketURL`
- **Type:** String (URL)
- **Required:** No
- **Purpose:** WebSocket URL for real-time features (future use)
- **Example:** `wss://api.lume.app/ws`

---

## API Endpoints

The app automatically appends these paths to `BACKEND_BASE_URL`:

### Authentication Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/auth/register` | POST | User registration |
| `/api/v1/auth/login` | POST | User login |
| `/api/v1/auth/refresh` | POST | Token refresh |
| `/api/v1/auth/logout` | POST | User logout |

### Full URL Examples

With `BACKEND_BASE_URL = https://fit-iq-backend.fly.dev`:

- Register: `https://fit-iq-backend.fly.dev/api/v1/auth/register`
- Login: `https://fit-iq-backend.fly.dev/api/v1/auth/login`
- Refresh: `https://fit-iq-backend.fly.dev/api/v1/auth/refresh`

---

## AppConfiguration Class

### Usage

The configuration is accessed through a singleton:

```swift
import Foundation

// Get backend URL
let baseURL = AppConfiguration.shared.backendBaseURL
// Returns: https://fit-iq-backend.fly.dev

// Get API key
let apiKey = AppConfiguration.shared.apiKey
// Returns: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW

// Get WebSocket URL (optional)
if let wsURL = AppConfiguration.shared.webSocketURL {
    print("WebSocket: \(wsURL)")
}

// Check environment
if AppConfiguration.shared.isProduction {
    print("Running in production")
} else {
    print("Running in development")
}
```

### Environment Detection

The app automatically detects the environment:

```swift
// Production: URL contains "lume.app" or "production"
var isProduction: Bool

// Development: Everything else
var isDevelopment: Bool
```

### Endpoint Constants

Predefined endpoint paths:

```swift
AppConfiguration.Endpoints.authRegister  // "/api/v1/auth/register"
AppConfiguration.Endpoints.authLogin     // "/api/v1/auth/login"
AppConfiguration.Endpoints.authRefresh   // "/api/v1/auth/refresh"
AppConfiguration.Endpoints.authLogout    // "/api/v1/auth/logout"
```

---

## Integration with Services

### RemoteAuthService

The authentication service automatically uses the configuration:

```swift
final class RemoteAuthService: AuthServiceProtocol {
    init(
        baseURL: URL? = nil,
        apiKey: String? = nil,
        session: URLSession = .shared
    ) {
        // Defaults to config.plist values
        self.baseURL = baseURL ?? AppConfiguration.shared.backendBaseURL
        self.apiKey = apiKey ?? AppConfiguration.shared.apiKey
        self.session = session
    }
}
```

### API Request Headers

All API requests automatically include:

```http
Content-Type: application/json
X-API-Key: 4D4WMSjTfAGxeIM7knn2IzCBgSAiyswW
```

---

## Environment-Specific Configuration

### Development

```xml
<key>BACKEND_BASE_URL</key>
<string>http://localhost:8080</string>

<key>API_KEY</key>
<string>dev-key-12345</string>
```

### Staging

```xml
<key>BACKEND_BASE_URL</key>
<string>https://staging.lume.app</string>

<key>API_KEY</key>
<string>staging-key-67890</string>
```

### Production

```xml
<key>BACKEND_BASE_URL</key>
<string>https://api.lume.app</string>

<key>API_KEY</key>
<string>prod-key-secure-token</string>
```

---

## Security Best Practices

### ✅ Do's

1. **Use HTTPS** - Always use secure connections in production
2. **Rotate API Keys** - Change keys periodically
3. **Environment-specific keys** - Different keys per environment
4. **Validate URLs** - AppConfiguration validates URLs on initialization
5. **Keep keys secret** - Don't commit production keys to public repos

### ❌ Don'ts

1. **Don't hardcode** - Never hardcode URLs or keys in source files
2. **Don't share keys** - Keep production keys confidential
3. **Don't commit** - Add `config.plist` to `.gitignore` for production
4. **Don't use HTTP** - Use HTTPS in staging and production
5. **Don't reuse keys** - Each environment should have unique keys

---

## Xcode Configuration

### Adding config.plist to Xcode

1. **Locate file** in Finder:
   ```
   lume/lume/config.plist
   ```

2. **Drag to Xcode** into the project navigator

3. **Check target membership**:
   - ✅ lume (app target)
   - ⬜ lumeTests (optional)

4. **Verify inclusion**:
   - File appears in project navigator
   - File is in "Copy Bundle Resources" build phase

### Build Phase Verification

1. Select project in Xcode
2. Select "lume" target
3. Go to "Build Phases"
4. Expand "Copy Bundle Resources"
5. Verify `config.plist` is listed

---

## Multiple Configurations

### Using Xcode Schemes

For advanced setups, create multiple config files:

```
lume/
└── lume/
    ├── config-development.plist
    ├── config-staging.plist
    └── config-production.plist
```

Then use build configurations to copy the right file:

1. Create custom build configurations (Debug, Staging, Release)
2. Add Run Script phase to copy appropriate config
3. Update `AppConfiguration` to read from the copied file

---

## Debugging Configuration

### Print Current Configuration

```swift
// In AppDelegate or main app initialization
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
WebSocket URL: wss://fit-iq-backend.fly.dev/ws/meal-logs
========================
```

### Common Issues

#### "config.plist not found"
- **Cause:** File not in bundle
- **Solution:** Add file to Xcode target

#### "BACKEND_BASE_URL not configured"
- **Cause:** Key missing or misspelled
- **Solution:** Check key name in plist matches exactly

#### "Invalid URL"
- **Cause:** Malformed URL string
- **Solution:** Ensure URL includes protocol (https://)

---

## Testing with Different Backends

### Local Backend

```xml
<key>BACKEND_BASE_URL</key>
<string>http://localhost:8080</string>
```

**Note:** Use `http://` for localhost (iOS allows this exception)

### Mock Backend

For UI testing without a real backend:

```swift
// In test setup
let mockAuthService = MockAuthService()
let dependencies = AppDependencies(authService: mockAuthService)
```

### Simulator vs Device

- **Simulator:** Can access `localhost`
- **Device:** Cannot access `localhost`, use network IP or ngrok

---

## API Key Management

### Current Setup

The API key is sent in every request header:

```swift
request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
```

### Backend Validation

Your backend should:
1. Check for `X-API-Key` header
2. Validate key against stored keys
3. Return 401 if invalid or missing
4. Rate limit by API key

### Key Rotation

To rotate keys:
1. Generate new key in backend admin
2. Update `config.plist` with new key
3. Deploy updated app
4. Deprecate old key after transition period

---

## WebSocket Configuration (Future)

Currently, the WebSocket URL is configured but not used. When implementing real-time features:

```swift
let wsURL = AppConfiguration.shared.webSocketURL

// Connect to WebSocket
let socket = WebSocket(url: wsURL)
socket.connect()
```

---

## Checklist for Backend Integration

### Initial Setup
- [ ] `config.plist` exists in project
- [ ] File added to Xcode target
- [ ] `BACKEND_BASE_URL` configured correctly
- [ ] `API_KEY` set (valid for backend)
- [ ] URLs use HTTPS (production/staging)
- [ ] Configuration prints correctly in debug mode

### Before Production
- [ ] Production URL configured
- [ ] Production API key set
- [ ] API key kept secret (not in public repo)
- [ ] HTTPS enforced
- [ ] Backend endpoints tested
- [ ] Error handling tested
- [ ] Token refresh working
- [ ] Network timeouts configured

---

## Summary

The configuration system provides:
- ✅ Centralized backend configuration
- ✅ Environment-specific settings
- ✅ Secure API key management
- ✅ Type-safe access to values
- ✅ Easy testing and debugging
- ✅ Production-ready security

Update `config.plist` to point to your backend, and the app will automatically use the correct URLs and authentication.

---

## Quick Reference

```swift
// Get backend URL
AppConfiguration.shared.backendBaseURL

// Get API key
AppConfiguration.shared.apiKey

// Check environment
AppConfiguration.shared.isProduction

// Endpoint paths
AppConfiguration.Endpoints.authRegister
AppConfiguration.Endpoints.authLogin
AppConfiguration.Endpoints.authRefresh
```

**Configuration is ready to use - just update the URLs and API key in `config.plist`!**