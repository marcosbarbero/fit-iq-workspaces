# 📚 FitIQ iOS API Reference

**Backend Version:** 0.22.0  
**API Base URL:** `https://fit-iq-backend.fly.dev/api/v1`  
**Last Updated:** 2025-01-27  
**Purpose:** Complete iOS API reference with Swift examples

---

## 📋 Overview

This reference provides **iOS-specific examples** for all major FitIQ API endpoints using:

- ✅ **URLSession** (native, recommended)
- ✅ **Async/Await** (modern Swift)
- ✅ **Complete request/response examples**
- ✅ **Error handling patterns**
- ✅ **Pagination support**
- ✅ **Common workflows**

---

## 🔧 Setup

### Base API Service

```swift
import Foundation

class FitIQAPI {
    
    static let shared = FitIQAPI()
    
    private let baseURL = "https://fit-iq-backend.fly.dev/api/v1"
    private let apiKey = "YOUR_API_KEY_HERE" // Get from backend admin
    
    private init() {}
    
    // MARK: - Generic Request Method
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        var urlComponents = URLComponents(string: baseURL + endpoint)!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        if requiresAuth {
            let token = try KeychainHelper.loadString(for: "fitiq_access_token")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle 401 - Token expired
        if httpResponse.statusCode == 401 && requiresAuth {
            try await AuthManager.shared.refreshAccessToken()
            return try await self.request(
                endpoint: endpoint,
                method: method,
                body: body,
                queryItems: queryItems,
                requiresAuth: requiresAuth
            )
        }
        
        // Handle errors
        if httpResponse.statusCode >= 400 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.error.message
            )
        }
        
        // Decode success response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
        
        guard apiResponse.success, let data = apiResponse.data else {
            throw APIError.serverError(message: apiResponse.error?.message)
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
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case serverError(message: String?)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return message ?? "HTTP error \(code)"
        case .serverError(let message):
            return message ?? "Server error"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
```

---

## 🔐 1. Authentication Endpoints

### 1.1 Register

```swift
// POST /auth/register

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let fullName: String
    let dateOfBirth: String // Format: "YYYY-MM-DD"
}

struct RegisterResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// Usage
func register(email: String, password: String, fullName: String, dob: String) async throws -> RegisterResponse {
    let request = RegisterRequest(
        email: email,
        password: password,
        fullName: fullName,
        dateOfBirth: dob
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/auth/register",
        method: .post,
        body: request,
        requiresAuth: false
    )
}

// Example
Task {
    do {
        let response = try await register(
            email: "user@example.com",
            password: "SecurePass123!",
            fullName: "John Doe",
            dob: "1990-01-01"
        )
        print("User ID: \(response.user.id)")
        print("Token expires in: \(response.expiresIn) seconds")
    } catch {
        print("Registration failed: \(error.localizedDescription)")
    }
}
```

### 1.2 Login

```swift
// POST /auth/login

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// Usage
func login(email: String, password: String) async throws -> LoginResponse {
    let request = LoginRequest(email: email, password: password)
    
    return try await FitIQAPI.shared.request(
        endpoint: "/auth/login",
        method: .post,
        body: request,
        requiresAuth: false
    )
}
```

### 1.3 Refresh Token

```swift
// POST /auth/refresh

struct RefreshRequest: Codable {
    let refreshToken: String
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// Usage
func refreshToken(refreshToken: String) async throws -> RefreshResponse {
    let request = RefreshRequest(refreshToken: refreshToken)
    
    return try await FitIQAPI.shared.request(
        endpoint: "/auth/refresh",
        method: .post,
        body: request,
        requiresAuth: false
    )
}
```

### 1.4 Logout

```swift
// POST /auth/logout

struct LogoutRequest: Codable {
    let refreshToken: String
}

// Usage
func logout(refreshToken: String) async throws {
    let request = LogoutRequest(refreshToken: refreshToken)
    
    let _: EmptyResponse = try await FitIQAPI.shared.request(
        endpoint: "/auth/logout",
        method: .post,
        body: request
    )
}

struct EmptyResponse: Codable {}
```

---

## 👤 2. User Management

### 2.1 Get User

```swift
// GET /users/{id}

struct User: Codable {
    let id: String
    let email: String
    let fullName: String
    let role: String
    let dateOfBirth: String?
    let createdAt: String?
    let updatedAt: String?
}

// Usage
func getUser(id: String) async throws -> User {
    return try await FitIQAPI.shared.request(
        endpoint: "/users/\(id)",
        method: .get
    )
}
```

### 2.2 Update User

```swift
// PUT /users/{id}

struct UpdateUserRequest: Codable {
    let fullName: String?
    let dateOfBirth: String?
}

// Usage
func updateUser(id: String, fullName: String?, dob: String?) async throws -> User {
    let request = UpdateUserRequest(fullName: fullName, dateOfBirth: dob)
    
    return try await FitIQAPI.shared.request(
        endpoint: "/users/\(id)",
        method: .put,
        body: request
    )
}
```

### 2.3 Change Password

```swift
// PUT /users/{id}/password

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

// Usage
func changePassword(userId: String, current: String, new: String) async throws {
    let request = ChangePasswordRequest(
        currentPassword: current,
        newPassword: new
    )
    
    let _: EmptyResponse = try await FitIQAPI.shared.request(
        endpoint: "/users/\(userId)/password",
        method: .put,
        body: request
    )
}
```

---

## 📊 3. User Profile

### 3.1 Get Profile

```swift
// GET /profiles/{user_id}

struct UserProfile: Codable {
    let id: String
    let userId: String
    let age: Int?
    let heightCm: Double?
    let weightKg: Double?
    let bmi: Double?
    let bodyFatPercent: Double?
    let restingHeartRate: Int?
    let gender: String?
    let activityLevel: String?
    let createdAt: String
    let updatedAt: String
}

// Usage
func getProfile(userId: String) async throws -> UserProfile {
    return try await FitIQAPI.shared.request(
        endpoint: "/profiles/\(userId)",
        method: .get
    )
}
```

### 3.2 Update Profile

```swift
// PUT /profiles/{user_id}

struct UpdateProfileRequest: Codable {
    let age: Int?
    let gender: String?
    let activityLevel: String?
}

// Usage
func updateProfile(userId: String, age: Int?, gender: String?, activityLevel: String?) async throws -> UserProfile {
    let request = UpdateProfileRequest(
        age: age,
        gender: gender,
        activityLevel: activityLevel
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/profiles/\(userId)",
        method: .put,
        body: request
    )
}
```

### 3.3 Update Physical Stats

```swift
// PUT /profiles/{user_id}/physical

struct UpdatePhysicalRequest: Codable {
    let heightCm: Double?
    let weightKg: Double?
    let bodyFatPercent: Double?
    let restingHeartRate: Int?
}

// Usage
func updatePhysicalStats(
    userId: String,
    height: Double?,
    weight: Double?,
    bodyFat: Double?,
    restingHR: Int?
) async throws -> UserProfile {
    let request = UpdatePhysicalRequest(
        heightCm: height,
        weightKg: weight,
        bodyFatPercent: bodyFat,
        restingHeartRate: restingHR
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/profiles/\(userId)/physical",
        method: .put,
        body: request
    )
}
```

---

## ⚙️ 4. User Preferences

### 4.1 Get Preferences

```swift
// GET /preferences/{user_id}

struct UserPreferences: Codable {
    let userId: String
    let units: String // "metric" or "imperial"
    let dailyCalorieGoal: Int?
    let dailyWaterGoalMl: Int?
    let theme: String? // "light", "dark", "system"
    let language: String? // "en", "es", etc.
    let notificationsEnabled: Bool
}

// Usage
func getPreferences(userId: String) async throws -> UserPreferences {
    return try await FitIQAPI.shared.request(
        endpoint: "/preferences/\(userId)",
        method: .get
    )
}
```

### 4.2 Update Preferences

```swift
// PUT /preferences/{user_id}

struct UpdatePreferencesRequest: Codable {
    let units: String?
    let dailyCalorieGoal: Int?
    let dailyWaterGoalMl: Int?
    let theme: String?
    let language: String?
    let notificationsEnabled: Bool?
}

// Usage
func updatePreferences(userId: String, request: UpdatePreferencesRequest) async throws -> UserPreferences {
    return try await FitIQAPI.shared.request(
        endpoint: "/preferences/\(userId)",
        method: .put,
        body: request
    )
}
```

---

## 🍎 5. Nutrition - Food Database

### 5.1 Search Foods

```swift
// GET /foods/search?q={query}&page={page}&page_size={size}

struct FoodSearchResponse: Codable {
    let foods: [Food]
    let total: Int
    let page: Int
    let pageSize: Int
}

struct Food: Codable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let servingSize: String
    let servingSizeG: Double?
    let isUserCreated: Bool
}

// Usage
func searchFoods(query: String, page: Int = 1, pageSize: Int = 20) async throws -> FoodSearchResponse {
    let queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "page_size", value: "\(pageSize)")
    ]
    
    return try await FitIQAPI.shared.request(
        endpoint: "/foods/search",
        method: .get,
        queryItems: queryItems
    )
}

// Example
Task {
    let results = try await searchFoods(query: "chicken breast", page: 1)
    print("Found \(results.total) foods")
    for food in results.foods {
        print("\(food.name) - \(food.calories) cal")
    }
}
```

### 5.2 Get Food by ID

```swift
// GET /foods/{id}

// Usage
func getFood(id: String) async throws -> Food {
    return try await FitIQAPI.shared.request(
        endpoint: "/foods/\(id)",
        method: .get
    )
}
```

### 5.3 Search by Barcode

```swift
// GET /foods/barcode/{barcode}

// Usage
func getFoodByBarcode(barcode: String) async throws -> Food {
    return try await FitIQAPI.shared.request(
        endpoint: "/foods/barcode/\(barcode)",
        method: .get
    )
}

// Example with AVFoundation barcode scanner
import AVFoundation

func handleScannedBarcode(_ barcode: String) {
    Task {
        do {
            let food = try await getFoodByBarcode(barcode: barcode)
            print("Found: \(food.name)")
            // Show food details to user
        } catch {
            print("Food not found for barcode: \(barcode)")
            // Prompt user to create custom food
        }
    }
}
```

### 5.4 Create Custom Food

```swift
// POST /foods

struct CreateFoodRequest: Codable {
    let name: String
    let brand: String?
    let barcode: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double?
    let sugarG: Double?
    let sodiumMg: Double?
    let servingSize: String
    let servingSizeG: Double?
}

// Usage
func createCustomFood(request: CreateFoodRequest) async throws -> Food {
    return try await FitIQAPI.shared.request(
        endpoint: "/foods",
        method: .post,
        body: request
    )
}
```

### 5.5 Get User's Custom Foods

```swift
// GET /foods/user/{user_id}

// Usage
func getUserFoods(userId: String) async throws -> [Food] {
    return try await FitIQAPI.shared.request(
        endpoint: "/foods/user/\(userId)",
        method: .get
    )
}
```

---

## 📝 6. Nutrition - Food Logging

### 6.1 Log Food

```swift
// POST /food-logs

struct CreateFoodLogRequest: Codable {
    let userId: String
    let foodId: String
    let mealType: String // "breakfast", "lunch", "dinner", "snack"
    let servings: Double
    let loggedAt: String? // ISO 8601 format, defaults to now
}

struct FoodLog: Codable {
    let id: String
    let userId: String
    let foodId: String
    let foodName: String
    let mealType: String
    let servings: Double
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let loggedAt: String
    let createdAt: String
}

// Usage
func logFood(
    userId: String,
    foodId: String,
    mealType: String,
    servings: Double
) async throws -> FoodLog {
    let request = CreateFoodLogRequest(
        userId: userId,
        foodId: foodId,
        mealType: mealType,
        servings: servings,
        loggedAt: nil
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/food-logs",
        method: .post,
        body: request
    )
}
```

### 6.2 Get Food Logs

```swift
// GET /food-logs?user_id={id}&date={date}&meal_type={type}&page={page}

struct FoodLogsResponse: Codable {
    let logs: [FoodLog]
    let total: Int
    let page: Int
    let pageSize: Int
}

// Usage
func getFoodLogs(
    userId: String,
    date: String? = nil,
    mealType: String? = nil,
    page: Int = 1
) async throws -> FoodLogsResponse {
    var queryItems = [
        URLQueryItem(name: "user_id", value: userId),
        URLQueryItem(name: "page", value: "\(page)")
    ]
    
    if let date = date {
        queryItems.append(URLQueryItem(name: "date", value: date))
    }
    
    if let mealType = mealType {
        queryItems.append(URLQueryItem(name: "meal_type", value: mealType))
    }
    
    return try await FitIQAPI.shared.request(
        endpoint: "/food-logs",
        method: .get,
        queryItems: queryItems
    )
}

// Example: Get today's food logs
Task {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let today = dateFormatter.string(from: Date())
    
    let logs = try await getFoodLogs(userId: "user_123", date: today)
    print("Logged \(logs.total) meals today")
}
```

### 6.3 Delete Food Log

```swift
// DELETE /food-logs/{id}

// Usage
func deleteFoodLog(id: String) async throws {
    let _: EmptyResponse = try await FitIQAPI.shared.request(
        endpoint: "/food-logs/\(id)",
        method: .delete
    )
}
```

### 6.4 Daily Nutrition Summary

```swift
// GET /food-logs/summary?user_id={id}&date={date}

struct NutritionSummary: Codable {
    let date: String
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let totalFiberG: Double
    let mealBreakdown: [String: MealNutrition]
}

struct MealNutrition: Codable {
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let itemCount: Int
}

// Usage
func getDailySummary(userId: String, date: String) async throws -> NutritionSummary {
    let queryItems = [
        URLQueryItem(name: "user_id", value: userId),
        URLQueryItem(name: "date", value: date)
    ]
    
    return try await FitIQAPI.shared.request(
        endpoint: "/food-logs/summary",
        method: .get,
        queryItems: queryItems
    )
}
```

---

## 💪 7. Workouts - Exercise Database

### 7.1 Search Exercises

```swift
// GET /exercises/search?q={query}&category={category}

struct ExerciseSearchResponse: Codable {
    let exercises: [Exercise]
    let total: Int
}

struct Exercise: Codable {
    let id: String
    let name: String
    let category: String // "strength", "cardio", "flexibility"
    let muscleGroups: [String]?
    let equipment: [String]?
    let description: String?
    let isUserCreated: Bool
}

// Usage
func searchExercises(query: String, category: String? = nil) async throws -> ExerciseSearchResponse {
    var queryItems = [URLQueryItem(name: "q", value: query)]
    
    if let category = category {
        queryItems.append(URLQueryItem(name: "category", value: category))
    }
    
    return try await FitIQAPI.shared.request(
        endpoint: "/exercises/search",
        method: .get,
        queryItems: queryItems
    )
}
```

### 7.2 Get Exercise

```swift
// GET /exercises/{id}

// Usage
func getExercise(id: String) async throws -> Exercise {
    return try await FitIQAPI.shared.request(
        endpoint: "/exercises/\(id)",
        method: .get
    )
}
```

### 7.3 Create Custom Exercise

```swift
// POST /exercises

struct CreateExerciseRequest: Codable {
    let name: String
    let category: String
    let muscleGroups: [String]?
    let equipment: [String]?
    let description: String?
}

// Usage
func createCustomExercise(request: CreateExerciseRequest) async throws -> Exercise {
    return try await FitIQAPI.shared.request(
        endpoint: "/exercises",
        method: .post,
        body: request
    )
}
```

---

## 🏋️ 8. Workouts - Workout Logging

### 8.1 Create Workout

```swift
// POST /workouts

struct CreateWorkoutRequest: Codable {
    let userId: String
    let title: String
    let scheduledAt: String? // ISO 8601
    let notes: String?
}

struct Workout: Codable {
    let id: String
    let userId: String
    let title: String
    let scheduledAt: String?
    let completedAt: String?
    let durationMinutes: Int?
    let notes: String?
    let exercises: [WorkoutExercise]?
    let createdAt: String
}

struct WorkoutExercise: Codable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    let sets: Int?
    let reps: Int?
    let weightKg: Double?
    let durationSeconds: Int?
    let distanceKm: Double?
    let restSeconds: Int?
    let notes: String?
}

// Usage
func createWorkout(userId: String, title: String, notes: String? = nil) async throws -> Workout {
    let request = CreateWorkoutRequest(
        userId: userId,
        title: title,
        scheduledAt: nil,
        notes: notes
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/workouts",
        method: .post,
        body: request
    )
}
```

### 8.2 Add Exercise to Workout

```swift
// POST /workouts/{workout_id}/exercises

struct AddExerciseToWorkoutRequest: Codable {
    let exerciseId: String
    let sets: Int?
    let reps: Int?
    let weightKg: Double?
    let durationSeconds: Int?
    let distanceKm: Double?
    let restSeconds: Int?
    let notes: String?
}

// Usage
func addExerciseToWorkout(
    workoutId: String,
    exerciseId: String,
    sets: Int?,
    reps: Int?,
    weight: Double?
) async throws -> WorkoutExercise {
    let request = AddExerciseToWorkoutRequest(
        exerciseId: exerciseId,
        sets: sets,
        reps: reps,
        weightKg: weight,
        durationSeconds: nil,
        distanceKm: nil,
        restSeconds: 90,
        notes: nil
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/workouts/\(workoutId)/exercises",
        method: .post,
        body: request
    )
}
```

### 8.3 Get Workouts

```swift
// GET /workouts?user_id={id}&start_date={date}&end_date={date}&page={page}

struct WorkoutsResponse: Codable {
    let workouts: [Workout]
    let total: Int
    let page: Int
    let pageSize: Int
}

// Usage
func getWorkouts(
    userId: String,
    startDate: String? = nil,
    endDate: String? = nil,
    page: Int = 1
) async throws -> WorkoutsResponse {
    var queryItems = [
        URLQueryItem(name: "user_id", value: userId),
        URLQueryItem(name: "page", value: "\(page)")
    ]
    
    if let startDate = startDate {
        queryItems.append(URLQueryItem(name: "start_date", value: startDate))
    }
    
    if let endDate = endDate {
        queryItems.append(URLQueryItem(name: "end_date", value: endDate))
    }
    
    return try await FitIQAPI.shared.request(
        endpoint: "/workouts",
        method: .get,
        queryItems: queryItems
    )
}
```

### 8.4 Complete Workout

```swift
// PUT /workouts/{id}

struct UpdateWorkoutRequest: Codable {
    let completedAt: String?
    let durationMinutes: Int?
    let notes: String?
}

// Usage
func completeWorkout(id: String, duration: Int) async throws -> Workout {
    let now = ISO8601DateFormatter().string(from: Date())
    let request = UpdateWorkoutRequest(
        completedAt: now,
        durationMinutes: duration,
        notes: nil
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/workouts/\(id)",
        method: .put,
        body: request
    )
}
```

---

## 🎯 9. Goals

### 9.1 Create Goal

```swift
// POST /goals

struct CreateGoalRequest: Codable {
    let userId: String
    let goalType: String // "weight_loss", "muscle_gain", "strength", etc.
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let deadline: String? // ISO 8601
    let notes: String?
}

struct Goal: Codable {
    let id: String
    let userId: String
    let goalType: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let deadline: String?
    let status: String // "active", "completed", "paused"
    let progress: Double
    let notes: String?
    let createdAt: String
    let updatedAt: String
}

// Usage
func createGoal(request: CreateGoalRequest) async throws -> Goal {
    return try await FitIQAPI.shared.request(
        endpoint: "/goals",
        method: .post,
        body: request
    )
}
```

### 9.2 Get Goals

```swift
// GET /goals?user_id={id}&status={status}

struct GoalsResponse: Codable {
    let goals: [Goal]
    let total: Int
}

// Usage
func getGoals(userId: String, status: String? = nil) async throws -> GoalsResponse {
    var queryItems = [URLQueryItem(name: "user_id", value: userId)]
    
    if let status = status {
        queryItems.append(URLQueryItem(name: "status", value: status))
    }
    
    return try await FitIQAPI.shared.request(
        endpoint: "/goals",
        method: .get,
        queryItems: queryItems
    )
}
```

### 9.3 Update Goal Progress

```swift
// PUT /goals/{id}

struct UpdateGoalRequest: Codable {
    let currentValue: Double?
    let status: String?
    let notes: String?
}

// Usage
func updateGoalProgress(goalId: String, currentValue: Double) async throws -> Goal {
    let request = UpdateGoalRequest(
        currentValue: currentValue,
        status: nil,
        notes: nil
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/goals/\(goalId)",
        method: .put,
        body: request
    )
}
```

---

## 😴 10. Sleep Tracking

### 10.1 Log Sleep

```swift
// POST /sleep

struct CreateSleepLogRequest: Codable {
    let userId: String
    let date: String // "YYYY-MM-DD"
    let hoursSlept: Double
    let quality: String // "poor", "fair", "good", "excellent"
    let sleepStart: String? // ISO 8601
    let sleepEnd: String? // ISO 8601
    let notes: String?
}

struct SleepLog: Codable {
    let id: String
    let userId: String
    let date: String
    let hoursSlept: Double
    let quality: String
    let sleepStart: String?
    let sleepEnd: String?
    let notes: String?
    let createdAt: String
}

// Usage
func logSleep(request: CreateSleepLogRequest) async throws -> SleepLog {
    return try await FitIQAPI.shared.request(
        endpoint: "/sleep",
        method: .post,
        body: request
    )
}
```

### 10.2 Get Sleep Logs

```swift
// GET /sleep?user_id={id}&start_date={date}&end_date={date}

struct SleepLogsResponse: Codable {
    let logs: [SleepLog]
    let total: Int
    let averageHours: Double
}

// Usage
func getSleepLogs(userId: String, startDate: String, endDate: String) async throws -> SleepLogsResponse {
    let queryItems = [
        URLQueryItem(name: "user_id", value: userId),
        URLQueryItem(name: "start_date", value: startDate),
        URLQueryItem(name: "end_date", value: endDate)
    ]
    
    return try await FitIQAPI.shared.request(
        endpoint: "/sleep",
        method: .get,
        queryItems: queryItems
    )
}
```

---

## 📸 11. Activity Snapshots

### 11.1 Log Activity Snapshot

```swift
// POST /activity-snapshots

struct CreateActivitySnapshotRequest: Codable {
    let userId: String
    let date: String // "YYYY-MM-DD"
    let steps: Int?
    let activeCalories: Int?
    let distanceKm: Double?
    let activityType: String? // "walking", "running", "cycling", etc.
    let durationMinutes: Int?
}

struct ActivitySnapshot: Codable {
    let id: String
    let userId: String
    let date: String
    let steps: Int?
    let activeCalories: Int?
    let distanceKm: Double?
    let activityType: String?
    let durationMinutes: Int?
    let createdAt: String
}

// Usage
func logActivitySnapshot(request: CreateActivitySnapshotRequest) async throws -> ActivitySnapshot {
    return try await FitIQAPI.shared.request(
        endpoint: "/activity-snapshots",
        method: .post,
        body: request
    )
}

// Example with HealthKit integration
import HealthKit

func syncHealthKitData(for date: Date) async throws {
    let healthStore = HKHealthStore()
    
    // Read steps
    let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let steps = try await readQuantity(healthStore, type: stepsType, date: date)
    
    // Read active calories
    let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    let calories = try await readQuantity(healthStore, type: caloriesType, date: date)
    
    // Read distance
    let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    let distance = try await readQuantity(healthStore, type: distanceType, date: date)
    
    // Log to backend
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let request = CreateActivitySnapshotRequest(
        userId: "user_123",
        date: dateFormatter.string(from: date),
        steps: Int(steps),
        activeCalories: Int(calories),
        distanceKm: distance,
        activityType: "walking",
        durationMinutes: nil
    )
    
    let _ = try await logActivitySnapshot(request: request)
}
```

---

## 📊 12. Analytics

### 12.1 Nutrition Analytics

```swift
// GET /analytics/nutrition?user_id={id}&start_date={date}&end_date={date}

struct NutritionAnalytics: Codable {
    let period: DateRange
    let averageDailyCalories: Double
    let averageDailyProtein: Double
    let averageDailyCarbs: Double
    let averageDailyFat: Double
    let topFoods: [FoodFrequency]
    let mealTypeDistribution: [String: Double]
}

struct DateRange: Codable {
    let startDate: String
    let endDate: String
}

struct FoodFrequency: Codable {
    let foodName: String
    let count: Int
    let totalCalories: Double
}

// Usage
func getNutritionAnalytics(userId: String, startDate: String, endDate: String) async throws -> NutritionAnalytics {
    let queryItems = [
        URLQueryItem(name: "user_id", value: userId),
        URLQueryItem(name: "start_date", value: startDate),
        URLQueryItem(name: "end_date", value: endDate)
    ]
    
    return try await FitIQAPI.shared.request(
        endpoint: "/analytics/nutrition",
        method: .get,
        queryItems: queryItems
    )
}
```

### 12.2 Workout Analytics

```swift
// GET /analytics/workouts?user_id={id}&start_date={date}&end_date={date}

struct WorkoutAnalytics: Codable {
    let period: DateRange
    let totalWorkouts: Int
    let totalDurationMinutes: Int
    let averageWorkoutDuration: Double
    let workoutFrequency: Double // workouts per week
    let topExercises: [ExerciseFrequency]
    let categoryDistribution: [String: Int]
}

struct ExerciseFrequency: Codable {
    let exerciseName: String
    let count: Int
    let totalVolume: Double? // for strength exercises
}

// Usage
func getWorkoutAnalytics(userId: String, startDate: String, endDate: String) async throws -> WorkoutAnalytics {
    let queryItems = [
        URLQueryItem(name: "user_id", value: userId),
        URLQueryItem(name: "start_date", value: startDate),
        URLQueryItem(name: "end_date", value: endDate)
    ]
    
    return try await FitIQAPI.shared.request(
        endpoint: "/analytics/workouts",
        method: .get,
        queryItems: queryItems
    )
}
```

---

## 🤖 13. AI Consultation (REST)

### 13.1 Start Consultation

```swift
// POST /consultations

struct CreateConsultationRequest: Codable {
    let userId: String
    let consultationType: String // "nutrition", "workout", "wellness", "general"
    let initialMessage: String?
}

struct Consultation: Codable {
    let id: String
    let userId: String
    let consultationType: String
    let status: String // "active", "completed"
    let createdAt: String
}

// Usage
func startConsultation(userId: String, type: String, message: String?) async throws -> Consultation {
    let request = CreateConsultationRequest(
        userId: userId,
        consultationType: type,
        initialMessage: message
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/consultations",
        method: .post,
        body: request
    )
}
```

### 13.2 Get Consultation

```swift
// GET /consultations/{id}

// Usage
func getConsultation(id: String) async throws -> Consultation {
    return try await FitIQAPI.shared.request(
        endpoint: "/consultations/\(id)",
        method: .get
    )
}
```

### 13.3 List Consultations

```swift
// GET /consultations?user_id={id}&status={status}

struct ConsultationsResponse: Codable {
    let consultations: [Consultation]
    let total: Int
}

// Usage
func getConsultations(userId: String, status: String? = nil) async throws -> ConsultationsResponse {
    var queryItems = [URLQueryItem(name: "user_id", value: userId)]
    
    if let status = status {
        queryItems.append(URLQueryItem(name: "status", value: status))
    }
    
    return try await FitIQAPI.shared.request(
        endpoint: "/consultations",
        method: .get,
        queryItems: queryItems
    )
}
```

---

## 🎨 14. Templates

### 14.1 Meal Templates

```swift
// GET /meal-templates/public

struct MealTemplatesResponse: Codable {
    let templates: [MealTemplate]
    let total: Int
}

struct MealTemplate: Codable {
    let id: String
    let name: String
    let description: String?
    let mealType: String
    let totalCalories: Double
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let foods: [TemplateFoodItem]
    let isPublic: Bool
}

struct TemplateFoodItem: Codable {
    let foodId: String
    let foodName: String
    let servings: Double
    let calories: Double
}

// Usage
func getPublicMealTemplates() async throws -> MealTemplatesResponse {
    return try await FitIQAPI.shared.request(
        endpoint: "/meal-templates/public",
        method: .get
    )
}
```

### 14.2 Use Meal Template

```swift
// POST /meal-templates/{id}/use

struct UseMealTemplateRequest: Codable {
    let userId: String
    let mealType: String?
    let loggedAt: String?
}

struct UseMealTemplateResponse: Codable {
    let logs: [FoodLog]
    let totalCalories: Double
}

// Usage
func useMealTemplate(templateId: String, userId: String, mealType: String) async throws -> UseMealTemplateResponse {
    let request = UseMealTemplateRequest(
        userId: userId,
        mealType: mealType,
        loggedAt: nil
    )
    
    return try await FitIQAPI.shared.request(
        endpoint: "/meal-templates/\(templateId)/use",
        method: .post,
        body: request
    )
}
```

---

## 🔄 15. Pagination Pattern

```swift
// Reusable pagination helper

class PaginatedLoader<T: Codable> {
    
    private var currentPage = 1
    private var hasMorePages = true
    private(set) var items: [T] = []
    
    let endpoint: String
    let userId: String
    let pageSize: Int
    
    init(endpoint: String, userId: String, pageSize: Int = 20) {
        self.endpoint = endpoint
        self.userId = userId
        self.pageSize = pageSize
    }
    
    func loadNextPage() async throws {
        guard hasMorePages else { return }
        
        let queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "page", value: "\(currentPage)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        struct PagedResponse: Codable {
            let items: [T]
            let total: Int
            let page: Int
            let pageSize: Int
        }
        
        let response: PagedResponse = try await FitIQAPI.shared.request(
            endpoint: endpoint,
            method: .get,
            queryItems: queryItems
        )
        
        items.append(contentsOf: response.items)
        currentPage += 1
        
        let totalLoaded = response.page * response.pageSize
        hasMorePages = totalLoaded < response.total
    }
    
    func reset() {
        currentPage = 1
        hasMorePages = true
        items.removeAll()
    }
}

// Usage example
class FoodLogViewModel: ObservableObject {
    @Published var foodLogs: [FoodLog] = []
    @Published var isLoading = false
    
    private lazy var loader = PaginatedLoader<FoodLog>(
        endpoint: "/food-logs",
        userId: "user_123"
    )
    
    func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        
        do {
            try await loader.loadNextPage()
            foodLogs = loader.items
        } catch {
            print("Failed to load: \(error)")
        }
        
        isLoading = false
    }
}
```

---

## 🛠️ 16. Common Patterns

### Date Formatting

```swift
extension Date {
    func toAPIDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
    
    func toAPIDateTimeString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
}

extension String {
    func toDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: self)
    }
}
```

### Retry Logic

```swift
extension FitIQAPI {
    func requestWithRetry<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        maxRetries: Int = 3
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await request(
                    endpoint: endpoint,
                    method: method,
                    body: body
                )
            } catch let error as APIError {
                lastError = error
                
                // Don't retry client errors (4xx)
                if case .httpError(let code, _) = error, (400...499).contains(code) {
                    throw error
                }
                
                // Wait before retry (exponential backoff)
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.serverError(message: "Max retries exceeded")
    }
}
```

### Batch Operations

```swift
// Log multiple foods at once
func logMultipleFoods(userId: String, items: [(foodId: String, mealType: String, servings: Double)]) async throws {
    try await withThrowingTaskGroup(of: FoodLog.self) { group in
        for item in items {
            group.addTask {
                try await self.logFood(
                    userId: userId,
                    foodId: item.foodId,
                    mealType: item.mealType,
                    servings: item.servings
                )
            }
        }
        
        // Collect results
        for try await _ in group {
            // Success
        }
    }
}
```

---

## 🎯 Complete Workflow Examples

### 1. Complete Registration Flow

```swift
func completeUserOnboarding() async throws {
    // 1. Register
    let registerResponse = try await register(
        email: "user@example.com",
        password: "SecurePass123!",
        fullName: "John Doe",
        dob: "1990-01-01"
    )
    
    let userId = registerResponse.user.id
    
    // 2. Update profile
    let profile = try await updateProfile(
        userId: userId,
        age: 30,
        gender: "male",
        activityLevel: "moderately_active"
    )
    
    // 3. Update physical stats
    let _ = try await updatePhysicalStats(
        userId: userId,
        height: 175.0,
        weight: 75.0,
        bodyFat: 15.0,
        restingHR: 60
    )
    
    // 4. Set preferences
    let preferences = UpdatePreferencesRequest(
        units: "metric",
        dailyCalorieGoal: 2000,
        dailyWaterGoalMl: 2000,
        theme: "dark",
        language: "en",
        notificationsEnabled: true
    )
    let _ = try await updatePreferences(userId: userId, request: preferences)
    
    // 5. Create initial goal
    let goalRequest = CreateGoalRequest(
        userId: userId,
        goalType: "weight_loss",
        targetValue: 70.0,
        currentValue: 75.0,
        unit: "kg",
        deadline: Calendar.current.date(byAdding: .month, value: 3, to: Date())?.toAPIDateString(),
        notes: "Lose 5kg in 3 months"
    )
    let _ = try await createGoal(request: goalRequest)
    
    print("✅ User onboarding complete!")
}
```

### 2. Log Complete Meal

```swift
func logBreakfast() async throws {
    let userId = "user_123"
    
    // Search and log eggs
    let eggsSearch = try await searchFoods(query: "scrambled eggs")
    if let eggs = eggsSearch.foods.first {
        let _ = try await logFood(
            userId: userId,
            foodId: eggs.id,
            mealType: "breakfast",
            servings: 1.0
        )
    }
    
    // Search and log toast
    let toastSearch = try await searchFoods(query: "whole wheat toast")
    if let toast = toastSearch.foods.first {
        let _ = try await logFood(
            userId: userId,
            foodId: toast.id,
            mealType: "breakfast",
            servings: 2.0
        )
    }
    
    // Get today's summary
    let today = Date().toAPIDateString()
    let summary = try await getDailySummary(userId: userId, date: today)
    print("Breakfast logged! Total calories today: \(summary.totalCalories)")
}
```

### 3. Complete Workout Session

```swift
func logWorkoutSession() async throws {
    let userId = "user_123"
    
    // 1. Create workout
    let workout = try await createWorkout(
        userId: userId,
        title: "Upper Body Strength",
        notes: "Chest and triceps day"
    )
    
    // 2. Search and add exercises
    let benchPress = try await searchExercises(query: "bench press")
    if let exercise = benchPress.exercises.first {
        let _ = try await addExerciseToWorkout(
            workoutId: workout.id,
            exerciseId: exercise.id,
            sets: 3,
            reps: 10,
            weight: 80.0
        )
    }
    
    // 3. Complete workout
    let completed = try await completeWorkout(id: workout.id, duration: 45)
    print("✅ Workout completed! Duration: \(completed.durationMinutes ?? 0) minutes")
}
```

---

## 🚨 Error Handling Best Practices

```swift
// Centralized error handler
func handleAPIError(_ error: Error) {
    if let apiError = error as? APIError {
        switch apiError {
        case .httpError(let code, let message):
            if code == 401 {
                // Token expired - handled automatically by retry
                print("Authentication required")
            } else if code == 404 {
                showAlert("Resource not found")
            } else if (500...599).contains(code) {
                showAlert("Server error. Please try again later.")
            } else {
                showAlert(message ?? "An error occurred")
            }
            
        case .networkError:
            showAlert("No internet connection")
            
        case .invalidResponse, .decodingError:
            showAlert("Invalid response from server")
            
        default:
            showAlert(error.localizedDescription)
        }
    } else {
        showAlert(error.localizedDescription)
    }
}

func showAlert(_ message: String) {
    // Show alert to user
    print("⚠️ \(message)")
}
```

---

## 📞 Support

**Backend Endpoints:**
- Health: `https://fit-iq-backend.fly.dev/health`
- Swagger: `https://fit-iq-backend.fly.dev/swagger/index.html`

**Documentation:**
- [Integration Roadmap](INTEGRATION_ROADMAP.md)
- [Authentication Guide](AUTHENTICATION.md)
- [WebSocket Guide](WEBSOCKET_GUIDE.md)

---

**Happy coding! All 119 endpoints are ready for your iOS app! 🚀**