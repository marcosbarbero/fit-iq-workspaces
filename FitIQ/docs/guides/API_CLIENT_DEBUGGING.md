# API Client Debugging Guide

**Purpose:** Quick reference for debugging API client issues in FitIQ iOS app  
**Last Updated:** 2025-01-27  
**Audience:** iOS developers working on API integration

---

## Overview

All API clients in FitIQ follow a standardized pattern:
- Token refresh on 401 (Unauthorized)
- NSLock synchronization to prevent race conditions
- Single retry per request
- Automatic logout on revoked tokens
- Comprehensive request/response logging

---

## Common Issues & Solutions

### 1. 400 Bad Request

**Symptoms:**
```
APIClient: ❌ 400 Bad Request
Network error: The operation couldn't be completed. (API error 400.)
```

**Debugging Steps:**

1. **Check Request Payload**
   ```swift
   // Add logging in API client
   let encoder = JSONEncoder()
   encoder.outputFormatting = .prettyPrinted
   urlRequest.httpBody = try encoder.encode(request)
   
   if let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8) {
       print("APIClient: Request payload:")
       print(bodyString)
   }
   ```

2. **Check Response Details**
   ```swift
   // Add in executeWithRetry
   case 400:
       print("APIClient: ❌ 400 Bad Request")
       if let responseString = String(data: data, encoding: .utf8) {
           print("APIClient: Error details: \(responseString)")
       }
   ```

3. **Common Causes:**
   - ❌ Invalid date format (must be RFC3339: `2024-01-16T06:30:00Z`)
   - ❌ Missing required fields
   - ❌ Invalid enum values
   - ❌ Negative or out-of-range numbers
   - ❌ Foreign key violations (invalid user_id, etc.)

4. **Fixes:**
   - Use `ISO8601DateFormatter` with `.withInternetDateTime` (no fractional seconds)
   - Validate data before encoding
   - Check API spec for required fields: `docs/be-api-spec/swagger.yaml`

---

### 2. 401 Unauthorized (Token Expired)

**Symptoms:**
```
APIClient: Response status code: 401
APIClient: Access token expired. Attempting refresh...
```

**Expected Behavior:**
- Should automatically refresh token and retry request
- Should succeed on retry

**If Refresh Fails:**
```
APIClient: ❌ Token refresh failed or second 401. Logging out.
```

**Debugging Steps:**

1. **Check Token Persistence**
   ```swift
   // Verify tokens exist in keychain
   if let accessToken = try? authTokenPersistence.fetchAccessToken() {
       print("Access token: \(accessToken.prefix(10))...")
   } else {
       print("❌ No access token in keychain")
   }
   
   if let refreshToken = try? authTokenPersistence.fetchRefreshToken() {
       print("Refresh token: \(refreshToken.prefix(10))...")
   } else {
       print("❌ No refresh token in keychain")
   }
   ```

2. **Check Refresh Token Validity**
   - Refresh tokens expire after 7 days (default)
   - Check backend logs for revocation
   - Verify user hasn't logged out in another session

3. **Verify Token Refresh Logic**
   ```swift
   // All API clients should have this pattern
   case 401 where retryCount == 0:
       // Refresh token
       let newTokens = try await refreshAccessToken(...)
       try authTokenPersistence.save(
           accessToken: newTokens.accessToken,
           refreshToken: newTokens.refreshToken
       )
       // Retry with new token
       return try await executeWithRetry(request: request, retryCount: 1)
   
   case 401 where retryCount > 0:
       // Refresh failed, logout
       authManager.logout()
       throw APIError.unauthorized
   ```

---

### 3. Race Condition (Multiple Concurrent Requests)

**Symptoms:**
```
APIClient: Token refresh already in progress, waiting for result...
APIClient: Token refresh already in progress, waiting for result...
```

**Expected Behavior:**
- Only ONE token refresh occurs
- Concurrent requests wait for the refresh to complete
- All requests succeed after refresh

**Debugging Steps:**

1. **Verify NSLock Implementation**
   ```swift
   private let refreshLock = NSLock()
   private var refreshTask: Task<LoginResponse, Error>?
   
   private func refreshAccessToken(...) async throws -> LoginResponse {
       refreshLock.lock()
       if let existingTask = refreshTask {
           refreshLock.unlock()
           return try await existingTask.value  // Wait for existing refresh
       }
       
       let task = Task<LoginResponse, Error> {
           defer {
               refreshLock.lock()
               self.refreshTask = nil
               refreshLock.unlock()
           }
           // Perform refresh
       }
       
       self.refreshTask = task
       refreshLock.unlock()
       return try await task.value
   }
   ```

2. **Check for Missing NSLock**
   - If multiple refreshes occur, NSLock is missing or incorrect
   - Compare with `ProgressAPIClient.swift` for reference

---

### 4. User Unexpectedly Logged Out

**Symptoms:**
- User is redirected to login screen
- No obvious error message

**Causes:**

1. **Refresh Token Revoked (Legitimate)**
   - Backend returns 401 during token refresh
   - Expected behavior: logout user
   ```
   APIClient: ❌ Refresh token revoked or expired (401). Logging out.
   ```

2. **Multiple Token Refreshes (Race Condition)**
   - Each refresh invalidates previous refresh token
   - If two refreshes happen, second one fails
   - Fix: Implement NSLock synchronization

3. **Token Rotation Not Saved**
   - Refresh succeeds but new tokens not saved to keychain
   - Next request uses old (revoked) refresh token
   - Fix: Ensure `authTokenPersistence.save()` is called after refresh

**Debugging Steps:**

1. **Add Keychain Logging**
   ```swift
   // After token refresh
   print("APIClient: ✅ New tokens saved to keychain")
   print("New access token: \(newTokens.accessToken.prefix(10))...")
   print("New refresh token: \(newTokens.refreshToken.prefix(10))...")
   ```

2. **Check AuthManager Logout Calls**
   ```bash
   # Search for logout calls
   grep -r "authManager.logout()" FitIQ/
   ```

3. **Monitor Backend Logs**
   - Check for "refresh token has been revoked" errors
   - Verify only one refresh per expiration

---

### 5. Network Client Errors

**Symptoms:**
```
Failed to execute request: The operation couldn't be completed.
```

**Debugging Steps:**

1. **Check NetworkClientProtocol Implementation**
   ```swift
   let (data, httpResponse) = try await networkClient.executeRequest(request: request)
   ```

2. **Verify URL Construction**
   ```swift
   guard let url = URL(string: endpoint) else {
       throw APIError.invalidURL
   }
   print("APIClient: Endpoint: \(endpoint)")
   ```

3. **Check Headers**
   ```swift
   request.setValue("application/json", forHTTPHeaderField: "Content-Type")
   request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
   request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
   
   // Debug: Print headers
   print("Headers: \(request.allHTTPHeaderFields ?? [:])")
   ```

---

## API Client Checklist

When implementing a new API client, ensure:

- [ ] Uses `executeWithRetry()` for all requests
- [ ] Implements token refresh on 401
- [ ] Has NSLock synchronization for token refresh
- [ ] Logs request payloads (pretty-printed JSON)
- [ ] Logs response status codes and bodies
- [ ] Calls `authManager.logout()` on revoked tokens
- [ ] Saves new tokens after refresh
- [ ] Uses correct date format (RFC3339, no fractional seconds)
- [ ] Follows pattern from `ProgressAPIClient.swift`

---

## Standard API Client Pattern

```swift
final class MyAPIClient: MyAPIProtocol {
    
    // MARK: - Dependencies
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    private let authTokenPersistence: AuthTokenPersistencePortProtocol
    private let authManager: AuthManager
    
    // MARK: - Token Refresh Synchronization
    private var isRefreshing = false
    private var refreshTask: Task<LoginResponse, Error>?
    private let refreshLock = NSLock()
    
    // MARK: - Public API Methods
    func myAPICall(request: MyRequest) async throws -> MyResponse {
        let endpoint = "\(baseURL)/api/v1/my-endpoint"
        
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        urlRequest.httpBody = try encoder.encode(request)
        
        // Debug logging
        if let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8) {
            print("MyAPIClient: Request payload:")
            print(bodyString)
        }
        
        // Execute with retry
        return try await executeWithRetry(request: urlRequest, retryCount: 0)
    }
    
    // MARK: - Token Refresh & Retry Logic
    private func executeWithRetry<T: Decodable>(
        request: URLRequest,
        retryCount: Int
    ) async throws -> T {
        var authenticatedRequest = request
        
        // Get access token
        guard let accessToken = try authTokenPersistence.fetchAccessToken() else {
            print("MyAPIClient: ❌ No access token found")
            authManager.logout()
            throw APIError.unauthorized
        }
        
        authenticatedRequest.setValue(
            "Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Execute request
        let (data, httpResponse) = try await networkClient.executeRequest(
            request: authenticatedRequest)
        let statusCode = httpResponse.statusCode
        
        print("MyAPIClient: Response status code: \(statusCode)")
        
        // Log response body
        if let responseString = String(data: data, encoding: .utf8) {
            print("MyAPIClient: Response body: \(responseString)")
        }
        
        switch statusCode {
        case 200, 201:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let apiResponse = try decoder.decode(StandardResponse<T>.self, from: data)
            return apiResponse.data
            
        case 401 where retryCount == 0:
            print("MyAPIClient: Access token expired. Attempting refresh...")
            
            guard let savedRefreshToken = try authTokenPersistence.fetchRefreshToken() else {
                print("MyAPIClient: No refresh token found. Logging out.")
                authManager.logout()
                throw APIError.unauthorized
            }
            
            let refreshRequest = RefreshTokenRequest(refreshToken: savedRefreshToken)
            let newTokens = try await refreshAccessToken(request: refreshRequest)
            
            try authTokenPersistence.save(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken)
            
            print("MyAPIClient: Token refreshed successfully. Retrying...")
            return try await executeWithRetry(request: request, retryCount: 1)
            
        case 401 where retryCount > 0:
            print("MyAPIClient: Token refresh failed. Logging out.")
            authManager.logout()
            throw APIError.unauthorized
            
        default:
            throw APIError.apiError(statusCode: statusCode, message: "Request failed")
        }
    }
    
    private func refreshAccessToken(request: RefreshTokenRequest) async throws -> LoginResponse {
        refreshLock.lock()
        if let existingTask = refreshTask {
            refreshLock.unlock()
            print("MyAPIClient: Token refresh already in progress, waiting...")
            return try await existingTask.value
        }
        
        let task = Task<LoginResponse, Error> {
            defer {
                refreshLock.lock()
                self.refreshTask = nil
                self.isRefreshing = false
                refreshLock.unlock()
            }
            
            guard let url = URL(string: "\(baseURL)/api/v1/auth/refresh") else {
                throw APIError.invalidURL
            }
            
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            urlRequest.httpBody = try JSONEncoder().encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                print("MyAPIClient: ❌ Refresh token revoked (401). Logging out.")
                await MainActor.run {
                    authManager.logout()
                }
                throw APIError.unauthorized
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.apiError(statusCode: httpResponse.statusCode, message: "Refresh failed")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let apiResponse = try decoder.decode(StandardResponse<LoginResponse>.self, from: data)
            
            print("MyAPIClient: ✅ Token refresh successful")
            return apiResponse.data
        }
        
        self.refreshTask = task
        self.isRefreshing = true
        refreshLock.unlock()
        
        return try await task.value
    }
}
```

---

## Quick Diagnostics

### Check if API client follows pattern:

```bash
# Check for token refresh implementation
grep -A 20 "func refreshAccessToken" FitIQ/Infrastructure/Network/MyAPIClient.swift

# Check for NSLock
grep "refreshLock" FitIQ/Infrastructure/Network/MyAPIClient.swift

# Check for retry logic
grep "retryCount" FitIQ/Infrastructure/Network/MyAPIClient.swift

# Check for logout calls
grep "authManager.logout()" FitIQ/Infrastructure/Network/MyAPIClient.swift
```

---

## Related Documentation

- **Token Refresh Fix:** `docs/fixes/TOKEN_REFRESH_FIX.md`
- **Sleep API 400 Fix:** `docs/fixes/SLEEP_API_400_ERROR_FIX.md`
- **API Spec:** `docs/be-api-spec/swagger.yaml`
- **Copilot Instructions:** `.github/copilot-instructions.md`

---

**Need Help?**
1. Check existing API clients: `ProgressAPIClient.swift`, `UserAuthAPIClient.swift`, `SleepAPIClient.swift`
2. Compare your implementation with the pattern above
3. Enable verbose logging and check Xcode console
4. Review backend API spec for endpoint requirements