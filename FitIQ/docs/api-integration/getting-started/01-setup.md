# 🚀 Setup Guide

**Time Required:** 15 minutes  
**Difficulty:** ⭐ Easy  
**Prerequisites:** None (start here!)

---

## 📋 What You'll Learn

- ✅ Get your API key
- ✅ Configure base URL
- ✅ Set up Xcode project
- ✅ Verify backend connection
- ✅ Install dependencies (optional)

---

## 🔑 Step 1: Get Your API Key

The FitIQ backend requires an **API key** for all requests (even public endpoints).

### Contact Backend Admin

**Where to get it:**
- Contact the backend administrator
- Request an iOS API key
- You'll receive something like: `fitiq-ios-app-2025`

### What is it for?

The API key identifies your **client application** (not the user). Think of it as:
- User authentication = JWT token (who you are)
- Client identification = API key (which app you're using)

---

## 🌐 Step 2: Backend URLs

### Production Backend

```
Base URL: https://fit-iq-backend.fly.dev
API Base: https://fit-iq-backend.fly.dev/api/v1
WebSocket: wss://fit-iq-backend.fly.dev/ws
```

### Verify Backend is Running

Test the health endpoint:

```bash
curl https://fit-iq-backend.fly.dev/health
```

**Expected response:**
```json
{
  "status": "ok"
}
```

✅ If you see this, the backend is up and running!

---

## 📱 Step 3: Xcode Project Setup

### Create Configuration File

**Option A: Using Config.swift (Recommended)**

Create a file called `Config.swift` in your project:

```swift
import Foundation

enum Config {
    // MARK: - API Configuration
    
    static let apiBaseURL = "https://fit-iq-backend.fly.dev/api/v1"
    static let websocketURL = "wss://fit-iq-backend.fly.dev/ws"
    static let apiKey = "YOUR_API_KEY_HERE" // Replace with actual key
    
    // MARK: - Environment
    
    enum Environment {
        case development
        case staging
        case production
    }
    
    static let currentEnvironment: Environment = .production
    
    // MARK: - Feature Flags
    
    static let enableAIConsultation = true
    static let enableHealthKitSync = true
    static let enableOfflineMode = false
    
    // MARK: - Network Settings
    
    static let requestTimeout: TimeInterval = 30
    static let maxRetryAttempts = 3
}
```

**Option B: Using .xcconfig File**

Create `Config.xcconfig`:

```
API_BASE_URL = https:/$()/fit-iq-backend.fly.dev/api/v1
API_KEY = YOUR_API_KEY_HERE
```

Then in your Swift code:

```swift
guard let apiKey = Bundle.main.object(forInfoPlistKey: "API_KEY") as? String else {
    fatalError("API Key not configured")
}
```

**⚠️ Important:** Add `Config.xcconfig` to `.gitignore` to avoid committing secrets!

---

## 🔒 Step 4: Secure Your API Key

### ✅ DO:

1. **Use environment variables**
   ```swift
   static let apiKey = ProcessInfo.processInfo.environment["FITIQ_API_KEY"] ?? ""
   ```

2. **Add to .gitignore**
   ```
   Config.xcconfig
   Secrets.plist
   ```

3. **Use different keys for dev/prod**
   ```swift
   static let apiKey: String {
       #if DEBUG
       return "fitiq-ios-dev-key"
       #else
       return "fitiq-ios-prod-key"
       #endif
   }
   ```

### ❌ DON'T:

1. ❌ Hardcode API key in committed code
2. ❌ Store in UserDefaults
3. ❌ Include in source control
4. ❌ Share API keys publicly

---

## 📦 Step 5: Install Dependencies (Optional)

### URLSession (Native) - Recommended

No installation needed! URLSession is built into iOS.

**Pros:**
- ✅ Native Apple framework
- ✅ No dependencies
- ✅ Full async/await support (iOS 15+)
- ✅ Smaller app size

**Cons:**
- ⚠️ More boilerplate code
- ⚠️ Manual request building

### Alamofire (Third-Party) - Optional

If you prefer Alamofire:

**Swift Package Manager:**
1. File → Add Packages
2. Enter: `https://github.com/Alamofire/Alamofire.git`
3. Select version: 5.0+
4. Add to your target

**Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0")
]
```

### Starscream (For AI Chat Only)

Only needed if implementing AI consultation with WebSocket.

**Swift Package Manager:**
1. File → Add Packages
2. Enter: `https://github.com/daltoniam/Starscream.git`
3. Select version: 4.0+
4. Add to your target

**Skip this for now if you're starting with basic features.**

---

## ✅ Step 6: Verify Setup

### Create Test File

Create `APITest.swift`:

```swift
import Foundation

class APITest {
    
    static func verifyConnection() async {
        let url = URL(string: "https://fit-iq-backend.fly.dev/health")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return
            }
            
            print("Status Code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ Backend is reachable!")
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Response: \(json)")
                }
            } else {
                print("❌ Backend returned error: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ Connection failed: \(error.localizedDescription)")
        }
    }
}
```

### Run Test

In your app's `AppDelegate` or SwiftUI `App` file:

```swift
// SwiftUI
@main
struct FitIQApp: App {
    
    init() {
        Task {
            await APITest.verifyConnection()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Expected Output

Check Xcode console for:

```
Status Code: 200
✅ Backend is reachable!
Response: ["status": "ok"]
```

---

## 🎯 Step 7: Create Base API Service

Create `APIService.swift`:

```swift
import Foundation

class APIService {
    
    static let shared = APIService()
    
    private let baseURL = Config.apiBaseURL
    private let apiKey = Config.apiKey
    
    private init() {
        // Verify configuration
        guard !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            fatalError("⚠️ API Key not configured! Check Config.swift")
        }
        
        print("✅ APIService initialized")
        print("📍 Base URL: \(baseURL)")
    }
    
    // MARK: - Generic Request Method
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        // Add auth header if needed (we'll implement this in authentication guide)
        if requiresAuth {
            // TODO: Add JWT token
        }
        
        // Add body if present
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
        
        guard let data = apiResponse.data else {
            throw APIError.noData
        }
        
        return data
    }
    
    // MARK: - HTTP Methods
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

// MARK: - Response Models

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: ErrorDetail?
}

struct ErrorDetail: Decodable {
    let code: String
    let message: String
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noData:
            return "No data received"
        }
    }
}
```

---

## 🧪 Step 8: Test API Service

Create `APIServiceTests.swift`:

```swift
import XCTest
@testable import YourAppName

class APIServiceTests: XCTestCase {
    
    func testAPIServiceInitialization() {
        // Verify API service is properly configured
        let service = APIService.shared
        XCTAssertNotNil(service)
    }
    
    func testHealthEndpoint() async throws {
        // Test basic connectivity
        let url = URL(string: "https://fit-iq-backend.fly.dev/health")!
        let (_, response) = try await URLSession.shared.data(from: url)
        
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)
    }
}
```

---

## ✅ Verification Checklist

Before moving to the next guide, verify:

- [ ] API key obtained from backend admin
- [ ] Config.swift created with API key
- [ ] Config.swift added to .gitignore
- [ ] Health endpoint returns 200
- [ ] APIService.swift created
- [ ] No fatal errors on app launch
- [ ] Console shows "✅ APIService initialized"

---

## 🚨 Common Issues

### Issue: "API Key not configured" error

**Solution:**
```swift
// Check Config.swift
static let apiKey = "fitiq-ios-app-2025" // ✅ Real key
static let apiKey = "YOUR_API_KEY_HERE"   // ❌ Placeholder
```

### Issue: "Cannot connect to backend"

**Diagnose:**
```bash
# Test from terminal
curl https://fit-iq-backend.fly.dev/health

# Check DNS
ping fit-iq-backend.fly.dev

# Check if blocked by firewall
curl -v https://fit-iq-backend.fly.dev/health
```

**Common causes:**
- ❌ Corporate firewall blocking Fly.io
- ❌ No internet connection
- ❌ Backend is down (check status)

### Issue: "The resource could not be loaded because the App Transport Security policy"

**Solution:**
Backend already uses HTTPS, but if testing locally:

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 📝 What You've Accomplished

✅ API key configured  
✅ Backend URL set up  
✅ Base API service created  
✅ Connection verified  
✅ Ready for authentication implementation

**Estimated time:** 15 minutes ⏱️

---

## 🎯 Next Steps

Now that setup is complete, move to authentication:

➡️ **Next:** [02-authentication.md](02-authentication.md)

This guide will show you how to:
- Implement user registration
- Build login flow
- Store JWT tokens securely in Keychain
- Handle token refresh

---

## 📞 Need Help?

- **Backend status:** https://fit-iq-backend.fly.dev/health
- **API docs:** https://fit-iq-backend.fly.dev/swagger/index.html
- **Issues:** Check console for error messages

---

**Setup complete! Time to build authentication! 🚀**