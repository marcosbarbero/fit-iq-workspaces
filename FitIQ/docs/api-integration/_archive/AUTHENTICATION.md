# 🔐 FitIQ iOS Authentication Guide

**Backend Version:** 0.22.0  
**API Base URL:** `https://fit-iq-backend.fly.dev`  
**Last Updated:** 2025-01-27  
**Purpose:** Complete authentication implementation guide for iOS

---

## 📋 Overview

This guide covers **complete authentication implementation** for iOS, including:

- ✅ User registration with validation
- ✅ Login with JWT tokens
- ✅ Secure token storage in Keychain
- ✅ Automatic token refresh
- ✅ Logout and session management
- ✅ Error handling and retry logic
- ✅ Complete Swift code examples

---

## 🎯 Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    REGISTRATION FLOW                         │
│                                                              │
│  User enters:                                                │
│  - Email                                                     │
│  - Password                                                  │
│  - Full Name                                                 │
│  - Date of Birth                                             │
│         ↓                                                    │
│  Validate locally (email format, password strength, age)     │
│         ↓                                                    │
│  POST /api/v1/auth/register                                  │
│         ↓                                                    │
│  Backend returns:                                            │
│  - User object                                               │
│  - Access token (JWT, expires 24h)                           │
│  - Refresh token (expires 30 days)                           │
│         ↓                                                    │
│  Store tokens in Keychain                                    │
│         ↓                                                    │
│  Navigate to onboarding/home                                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      LOGIN FLOW                              │
│                                                              │
│  User enters:                                                │
│  - Email                                                     │
│  - Password                                                  │
│         ↓                                                    │
│  POST /api/v1/auth/login                                     │
│         ↓                                                    │
│  Backend returns:                                            │
│  - User object                                               │
│  - Access token (JWT, expires 24h)                           │
│  - Refresh token (expires 30 days)                           │
│         ↓                                                    │
│  Store tokens in Keychain                                    │
│         ↓                                                    │
│  Navigate to home                                            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   TOKEN REFRESH FLOW                         │
│                                                              │
│  Make API request with access token                          │
│         ↓                                                    │
│  Response 401 (token expired)                                │
│         ↓                                                    │
│  POST /api/v1/auth/refresh with refresh token                │
│         ↓                                                    │
│  Backend returns new tokens                                  │
│         ↓                                                    │
│  Update tokens in Keychain                                   │
│         ↓                                                    │
│  Retry original request with new token                       │
│         ↓                                                    │
│  If refresh fails (401) → Logout user                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     LOGOUT FLOW                              │
│                                                              │
│  User clicks logout                                          │
│         ↓                                                    │
│  POST /api/v1/auth/logout with refresh token                 │
│         ↓                                                    │
│  Backend invalidates refresh token                           │
│         ↓                                                    │
│  Clear all tokens from Keychain                              │
│         ↓                                                    │
│  Clear user data from local storage                          │
│         ↓                                                    │
│  Navigate to login screen                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔑 Token Types

### Access Token (JWT)
- **Format:** `eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Lifetime:** 24 hours
- **Usage:** Include in `Authorization: Bearer {token}` header for all API requests
- **Storage:** Keychain
- **Renewal:** Use refresh token when expired

### Refresh Token
- **Format:** `eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...`
- **Lifetime:** 30 days
- **Usage:** Get new access token when current one expires
- **Storage:** Keychain
- **Renewal:** User must login again after 30 days

### API Key
- **Format:** Plain string (e.g., `fitiq-ios-app-2025`)
- **Lifetime:** Never expires
- **Usage:** Include in `X-API-Key: {key}` header for ALL requests
- **Storage:** Hardcoded in app configuration (not in Keychain)
- **Purpose:** Client identification (not user authentication)

---

## 📱 Swift Implementation

### 1. Keychain Helper

```swift
import Foundation
import Security

/// Helper class for secure Keychain storage
class KeychainHelper {
    
    enum KeychainError: Error {
        case duplicateItem
        case unknown(OSStatus)
        case itemNotFound
    }
    
    // MARK: - Save
    
    static func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to add
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unknown(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }
    
    static func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.unknown(-1)
        }
        try save(data, for: key)
    }
    
    // MARK: - Load
    
    static func load(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.unknown(-1)
        }
        
        return data
    }
    
    static func loadString(for key: String) throws -> String {
        let data = try load(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unknown(-1)
        }
        return string
    }
    
    // MARK: - Delete
    
    static func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    // MARK: - Clear All
    
    static func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### 2. Auth Manager

```swift
import Foundation
import Combine

/// Main authentication manager
class AuthManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    // Keychain keys
    private let accessTokenKey = "fitiq_access_token"
    private let refreshTokenKey = "fitiq_refresh_token"
    private let userIdKey = "fitiq_user_id"
    private let tokenExpiryKey = "fitiq_token_expiry"
    
    // MARK: - Init
    
    init(apiService: APIService = .shared) {
        self.apiService = apiService
        checkAuthStatus()
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() {
        do {
            let accessToken = try KeychainHelper.loadString(for: accessTokenKey)
            let userId = try KeychainHelper.loadString(for: userIdKey)
            
            // Check if token is expired
            if isTokenExpired() {
                // Try to refresh
                Task {
                    do {
                        try await refreshAccessToken()
                        isAuthenticated = true
                    } catch {
                        // Refresh failed, need re-login
                        await logout()
                    }
                }
            } else {
                isAuthenticated = true
                // Optionally fetch user details
                Task {
                    await fetchCurrentUser(userId: userId)
                }
            }
        } catch {
            isAuthenticated = false
        }
    }
    
    // MARK: - Registration
    
    func register(email: String, password: String, fullName: String, dateOfBirth: String) async throws {
        let request = RegisterRequest(
            email: email,
            password: password,
            fullName: fullName,
            dateOfBirth: dateOfBirth
        )
        
        let response: AuthResponse = try await apiService.request(
            endpoint: "/auth/register",
            method: .post,
            body: request,
            requiresAuth: false
        )
        
        try saveTokens(response: response)
        currentUser = response.user
        isAuthenticated = true
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) async throws {
        let request = LoginRequest(
            email: email,
            password: password
        )
        
        let response: AuthResponse = try await apiService.request(
            endpoint: "/auth/login",
            method: .post,
            body: request,
            requiresAuth: false
        )
        
        try saveTokens(response: response)
        currentUser = response.user
        isAuthenticated = true
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken() async throws {
        guard let refreshToken = try? KeychainHelper.loadString(for: refreshTokenKey) else {
            throw AuthError.noRefreshToken
        }
        
        let request = RefreshRequest(refreshToken: refreshToken)
        
        let response: RefreshResponse = try await apiService.request(
            endpoint: "/auth/refresh",
            method: .post,
            body: request,
            requiresAuth: false
        )
        
        // Update tokens
        try KeychainHelper.save(response.accessToken, for: accessTokenKey)
        try KeychainHelper.save(response.refreshToken, for: refreshTokenKey)
        
        // Update expiry
        let expiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        UserDefaults.standard.set(expiry, forKey: tokenExpiryKey)
    }
    
    // MARK: - Logout
    
    func logout() async {
        // Call logout endpoint (best effort)
        if let refreshToken = try? KeychainHelper.loadString(for: refreshTokenKey) {
            let request = LogoutRequest(refreshToken: refreshToken)
            try? await apiService.request(
                endpoint: "/auth/logout",
                method: .post,
                body: request,
                requiresAuth: true
            )
        }
        
        // Clear local storage
        clearLocalStorage()
        
        isAuthenticated = false
        currentUser = nil
    }
    
    // MARK: - Helper Methods
    
    private func saveTokens(response: AuthResponse) throws {
        try KeychainHelper.save(response.accessToken, for: accessTokenKey)
        try KeychainHelper.save(response.refreshToken, for: refreshTokenKey)
        try KeychainHelper.save(response.user.id, for: userIdKey)
        
        let expiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        UserDefaults.standard.set(expiry, forKey: tokenExpiryKey)
    }
    
    private func clearLocalStorage() {
        try? KeychainHelper.delete(for: accessTokenKey)
        try? KeychainHelper.delete(for: refreshTokenKey)
        try? KeychainHelper.delete(for: userIdKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
    }
    
    func isTokenExpired() -> Bool {
        guard let expiry = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date else {
            return true
        }
        // Add 5 minute buffer
        return Date().addingTimeInterval(300) >= expiry
    }
    
    func getAccessToken() throws -> String {
        try KeychainHelper.loadString(for: accessTokenKey)
    }
    
    private func fetchCurrentUser(userId: String) async {
        do {
            let user: User = try await apiService.request(
                endpoint: "/users/\(userId)",
                method: .get,
                requiresAuth: true
            )
            currentUser = user
        } catch {
            print("Failed to fetch user: \(error)")
        }
    }
}

// MARK: - Models

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let fullName: String
    let dateOfBirth: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RefreshRequest: Codable {
    let refreshToken: String
}

struct LogoutRequest: Codable {
    let refreshToken: String
}

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct User: Codable {
    let id: String
    let email: String
    let fullName: String
    let role: String
    let createdAt: String?
}

enum AuthError: LocalizedError {
    case noRefreshToken
    case invalidCredentials
    case registrationFailed
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available. Please log in again."
        case .invalidCredentials:
            return "Invalid email or password."
        case .registrationFailed:
            return "Registration failed. Please try again."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        }
    }
}
```

### 3. API Service with Auto-Refresh

```swift
import Foundation

class APIService {
    
    static let shared = APIService()
    
    private let baseURL = "https://fit-iq-backend.fly.dev/api/v1"
    private let apiKey = "YOUR_API_KEY_HERE" // TODO: Get from backend admin
    
    private init() {}
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        // Add auth token if required
        if requiresAuth {
            let token = try KeychainHelper.loadString(for: "fitiq_access_token")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if present
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle 401 (token expired)
        if httpResponse.statusCode == 401 && requiresAuth {
            // Try to refresh token
            try await AuthManager.shared.refreshAccessToken()
            
            // Retry original request with new token
            return try await self.request(
                endpoint: endpoint,
                method: method,
                body: body,
                requiresAuth: requiresAuth
            )
        }
        
        // Handle other errors
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorResponse?.error.message)
        }
        
        // Parse success response
        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        
        guard apiResponse.success, let data = apiResponse.data else {
            throw APIError.serverError(message: apiResponse.error?.message)
        }
        
        return data
    }
    
    // MARK: - HTTP Method
    
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

struct ErrorResponse: Decodable {
    let success: Bool
    let error: ErrorDetail
}

struct ErrorDetail: Decodable {
    let code: String
    let message: String
    let details: [String: String]?
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case serverError(message: String?)
    case decodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP error \(statusCode)"
        case .serverError(let message):
            return message ?? "Server error"
        case .decodingError:
            return "Failed to decode response"
        case .networkError:
            return "Network connection error"
        }
    }
}
```

---

## 🎨 SwiftUI Views

### Registration View

```swift
import SwiftUI

struct RegistrationView: View {
    
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var dateOfBirth = Date()
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $fullName)
                        .textContentType(.name)
                    
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: register) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account")
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .navigationTitle("Sign Up")
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        !fullName.isEmpty &&
        age >= 13
    }
    
    private var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    private func register() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dobString = dateFormatter.string(from: dateOfBirth)
                
                try await authManager.register(
                    email: email,
                    password: password,
                    fullName: fullName,
                    dateOfBirth: dobString
                )
                
                // Navigation handled by @Published isAuthenticated
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
}
```

### Login View

```swift
import SwiftUI

struct LoginView: View {
    
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingRegistration = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo or app name
                Text("FitIQ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 60)
                
                Spacer()
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Log In")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isFormValid || isLoading)
                }
                .padding(.horizontal, 32)
                
                Button(action: { showingRegistration = true }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRegistration) {
                RegistrationView()
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.login(email: email, password: password)
                // Navigation handled by @Published isAuthenticated
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isLoading = false
        }
    }
}
```

### Root App View

```swift
import SwiftUI

@main
struct FitIQApp: App {
    
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    HomeView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
        }
    }
}
```

---

## ✅ Validation Rules

### Email Validation

```swift
extension String {
    func isValidEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
}
```

### Password Validation

```swift
struct PasswordValidator {
    static func validate(_ password: String) -> (isValid: Bool, message: String?) {
        if password.count < 8 {
            return (false, "Password must be at least 8 characters")
        }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        
        if !hasUppercase {
            return (false, "Password must contain at least one uppercase letter")
        }
        
        if !hasLowercase {
            return (false, "Password must contain at least one lowercase letter")
        }
        
        if !hasNumber {
            return (false, "Password must contain at least one number")
        }
        
        return (true, nil)
    }
}
```

### Age Validation (COPPA Compliance)

```swift
extension Date {
    func age() -> Int {
        Calendar.current.dateComponents([.year], from: self, to: Date()).year ?? 0
    }
    
    func meetsMinimumAge(_ minimum: Int = 13) -> Bool {
        age() >= minimum
    }
}
```

---

## 🚨 Error Handling

### Common Error Scenarios

```swift
enum AuthenticationError: LocalizedError {
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case underage
    case emailAlreadyExists
    case invalidCredentials
    case networkError
    case tokenExpired
    case serverError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, and a number"
        case .passwordMismatch:
            return "Passwords do not match"
        case .underage:
            return "You must be at least 13 years old to use this app"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .serverError(let message):
            return message
        }
    }
}
```

### Error Response Mapping

```swift
extension APIError {
    static func from(httpStatusCode: Int, apiErrorCode: String?, message: String?) -> AuthenticationError {
        switch httpStatusCode {
        case 400:
            if apiErrorCode == "INVALID_EMAIL" {
                return .invalidEmail
            } else if apiErrorCode == "WEAK_PASSWORD" {
                return .weakPassword
            } else if apiErrorCode == "AGE_RESTRICTION" {
                return .underage
            }
            return .serverError(message: message ?? "Bad request")
            
        case 401:
            return .invalidCredentials
            
        case 409:
            return .emailAlreadyExists
            
        case 500...599:
            return .serverError(message: message ?? "Server error. Please try again later.")
            
        default:
            return .serverError(message: message ?? "Unknown error occurred")
        }
    }
}
```

---

## 🧪 Testing

### Unit Tests

```swift
import XCTest
@testable import FitIQ

class AuthManagerTests: XCTestCase {
    
    var authManager: AuthManager!
    
    override func setUp() {
        super.setUp()
        authManager = AuthManager()
        // Clear keychain
        KeychainHelper.clearAll()
    }
    
    func testRegistrationSuccess() async throws {
        // Given
        let email = "test@example.com"
        let password = "Test123!"
        let fullName = "Test User"
        let dateOfBirth = "1990-01-01"
        
        // When
        try await authManager.register(
            email: email,
            password: password,
            fullName: fullName,
            dateOfBirth: dateOfBirth
        )
        
        // Then
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
        XCTAssertEqual(authManager.currentUser?.email, email)
        
        // Verify tokens are stored
        let accessToken = try KeychainHelper.loadString(for: "fitiq_access_token")
        XCTAssertFalse(accessToken.isEmpty)
    }
    
    func testLoginSuccess() async throws {
        // Given
        let email = "existing@example.com"
        let password = "Test123!"
        
        // When
        try await authManager.login(email: email, password: password)
        
        // Then
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
    }
    
    func testTokenRefresh() async throws {
        // Given - user is logged in with expired token
        try KeychainHelper.save("old_token", for: "fitiq_access_token")
        try KeychainHelper.save("valid_refresh_token", for: "fitiq_refresh_token")
        
        // When
        try await authManager.refreshAccessToken()
        
        // Then
        let newToken = try KeychainHelper.loadString(for: "fitiq_access_token")
        XCTAssertNotEqual(newToken, "old_token")
    }
    
    func testLogout() async {
        // Given - user is logged in
        authManager.isAuthenticated = true
        try? KeychainHelper.save("token", for: "fitiq_access_token")
        
        // When
        await authManager.logout()
        
        // Then
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
        
        // Verify tokens are cleared
        XCTAssertThrowsError(try KeychainHelper.loadString(for: "fitiq_access_token"))
    }
}
```

### Integration Tests

```swift
class AuthIntegrationTests: XCTestCase {
    
    func testFullRegistrationFlow() async throws {
        let authManager = AuthManager()
        
        // 1. Register
        try await authManager.register(
            email: "integration_test_\(UUID().uuidString)@example.com",
            password: "Test123!",
            fullName: "Integration Test",
            dateOfBirth: "1990-01-01"
        )
        
        XCTAssertTrue(authManager.isAuthenticated)
        
        // 2. Logout
        await authManager.logout()
        XCTAssertFalse(authManager.isAuthenticated)
        
        // 3. Login with same credentials
        try await authManager.login(
            email: "integration_test@example.com",
            password: "Test123!"
        )
        
        XCTAssertTrue(authManager.isAuthenticated)
    }
}
```

---

## 🔒 Security Best Practices

### ✅ DO

1. **Store tokens in Keychain** - Never UserDefaults or files
2. **Use HTTPS only** - Enforce App Transport Security
3. **Validate certificates** - Don't disable SSL validation
4. **Clear tokens on logout** - Remove all stored credentials
5. **Use biometric auth** - For quick re-authentication
6. **Implement token refresh** - Automatic and transparent
7. **Handle 401 globally** - Auto-refresh or force logout
8. **Validate input locally** - Before calling API
9. **Use secure text fields** - For passwords
10. **Implement rate limiting** - Prevent brute force

### ❌ DON'T

1. **Never log tokens** - Even in debug builds
2. **Never hardcode credentials** - Use config files
3. **Don't store passwords** - Only tokens
4. **Don't ignore 401 errors** - Always handle them
5. **Don't use HTTP** - Production must use HTTPS
6. **Don't store tokens in UserDefaults** - Not secure
7. **Don't disable ATS** - App Transport Security
8. **Don't skip token refresh** - Avoid bad UX
9. **Don't expose API keys** - Keep in secure config
10. **Don't trust client validation** - Backend validates too

---

## 📱 Biometric Authentication (Optional)

```swift
import LocalAuthentication

class BiometricAuthManager {
    
    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }
        
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access your account"
        )
    }
    
    func enableBiometricLogin() {
        UserDefaults.standard.set(true, forKey: "biometric_enabled")
    }
    
    func isBiometricEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: "biometric_enabled")
    }
}

enum BiometricError: LocalizedError {
    case notAvailable
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed:
            return "Biometric authentication failed"
        }
    }
}
```

---

## 🎯 Summary Checklist

### Registration ✅
- [ ] Create registration form (email, password, name, DOB)
- [ ] Validate email format locally
- [ ] Validate password strength (8+ chars, upper, lower, number)
- [ ] Validate age (13+ for COPPA)
- [ ] Call `/api/v1/auth/register` endpoint
- [ ] Store tokens in Keychain
- [ ] Handle errors (400, 409)
- [ ] Navigate to onboarding on success

### Login ✅
- [ ] Create login form (email, password)
- [ ] Call `/api/v1/auth/login` endpoint
- [ ] Store tokens in Keychain
- [ ] Handle errors (400, 401)
- [ ] Navigate to home on success

### Token Management ✅
- [ ] Store access token in Keychain
- [ ] Store refresh token in Keychain
- [ ] Store token expiry timestamp
- [ ] Implement auto-refresh on 401
- [ ] Call `/api/v1/auth/refresh` when expired
- [ ] Retry original request with new token
- [ ] Force logout if refresh fails

### Logout ✅
- [ ] Call `/api/v1/auth/logout` endpoint
- [ ] Clear all tokens from Keychain
- [ ] Clear user data
- [ ] Navigate to login screen

### Security ✅
- [ ] Use Keychain for token storage
- [ ] Enable App Transport Security
- [ ] Validate certificates
- [ ] Don't log sensitive data
- [ ] Implement biometric auth (optional)

---

## 📞 Support

**Questions?**
- Review the [Integration Roadmap](INTEGRATION_ROADMAP.md)
- Test endpoints in [Swagger UI](https://fit-iq-backend.fly.dev/swagger/index.html)
- Check [API Reference](API_REFERENCE.md) for more examples

**Backend Status:**
- Health check: `https://fit-iq-backend.fly.dev/health`
- API version: 0.22.0
- Uptime: 99.9%

---

**Authentication is the foundation of everything. Get this right, and the rest is easy! 🔐**