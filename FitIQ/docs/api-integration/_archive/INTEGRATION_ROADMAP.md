# 🗺️ FitIQ iOS Integration Roadmap

**Backend Version:** 0.22.0  
**API Base URL:** `https://fit-iq-backend.fly.dev`  
**Last Updated:** 2025-01-27  
**Purpose:** Dependency-driven implementation guide for iOS client

---

## 📋 Executive Summary

This roadmap provides a **dependency-based implementation path** for integrating the FitIQ backend (119 endpoints) into your iOS app. Features are organized by:

- ✅ **Dependencies** - What must come first
- ✅ **Complexity** - Simple, Medium, Complex
- ✅ **Priority** - Must Have, Should Have, Nice to Have
- ✅ **Effort** - Time estimates
- ✅ **Mandatory vs Optional** - What you cannot skip

**Key Principle:** You cannot implement feature B if it depends on feature A. Follow this roadmap to avoid blocked work.

---

## 🎯 Dependency Tree (Visual)

```
┌─────────────────────────────────────────────────────────────┐
│                    FOUNDATION LAYER                          │
│               (MANDATORY - NOTHING WORKS WITHOUT THIS)       │
│                                                              │
│  1. Registration → 2. Login → 3. Token Management           │
│                                      ↓                       │
│                              4. Error Handling               │
└──────────────────────────────────────┬───────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│                     PROFILE LAYER                            │
│              (REQUIRED FOR PERSONALIZATION)                  │
│                                                              │
│         5. User Profile → 6. User Preferences                │
└──────────────────────────────────────┬───────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   TRACKING LAYER                             │
│              (CORE APP FUNCTIONALITY)                        │
│                                                              │
│    ┌─────────────────┐         ┌──────────────────┐         │
│    │  7. Nutrition   │         │  8. Workouts     │         │
│    │  - Food DB      │         │  - Exercise DB   │         │
│    │  - Food Logs    │         │  - Workout Logs  │         │
│    │  - Barcode Scan │         │  - Exercise Logs │         │
│    └─────────────────┘         └──────────────────┘         │
│                                                              │
│            9. Sleep Tracking (standalone)                    │
│           10. Activity Snapshots (standalone)                │
└──────────────────────────────────────┬───────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   TEMPLATES LAYER                            │
│              (REQUIRES TRACKING DATA)                        │
│                                                              │
│    11. Meal Templates  →  12. Workout Templates              │
│    13. Wellness Templates (requires meal + workout)          │
└──────────────────────────────────────┬───────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│                    GOALS LAYER                               │
│             (REQUIRES TRACKING DATA)                         │
│                                                              │
│       14. Goal Management → 15. Progress Tracking            │
└──────────────────────────────────────┬───────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   ANALYTICS LAYER                            │
│              (REQUIRES HISTORICAL DATA)                      │
│                                                              │
│       16. Basic Analytics → 17. Advanced Analytics           │
└──────────────────────────────────────┬───────────────────────┘
                                       ↓
┌─────────────────────────────────────────────────────────────┐
│                    AI LAYER                                  │
│              (MOST COMPLEX - REQUIRES WEBSOCKET)             │
│                                                              │
│    18. AI Consultation → 19. Template Creation               │
│                          20. AI Recommendations              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚨 CRITICAL: The Mandatory Path

**You CANNOT skip these. Everything else depends on them.**

### ✅ Foundation (Days 1-3)

| # | Feature | Complexity | Effort | Why Mandatory |
|---|---------|------------|--------|---------------|
| 1 | **Registration** | Simple | 0.5 day | No users = no app |
| 2 | **Login** | Simple | 0.5 day | No auth = can't call any endpoint |
| 3 | **Token Management** | Medium | 1 day | Tokens expire, need refresh flow |
| 4 | **Error Handling** | Medium | 1 day | Need consistent error UX |

**Endpoints:** 3 (register, login, refresh)  
**Deliverable:** Users can create accounts, sign in, stay signed in  
**Blocker:** Without this, literally nothing else works

---

## 📊 Feature Breakdown (Dependency Order)

### 🔐 1. Registration (FOUNDATION - MUST HAVE)

**Complexity:** ⭐ Simple  
**Effort:** 0.5 day  
**Priority:** 🔴 Must Have  
**Dependencies:** None  
**Blocks:** Everything

#### What You Need:
```
POST /api/v1/auth/register
```

#### Request:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "full_name": "John Doe",
  "date_of_birth": "1990-01-01"
}
```

#### Response:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "usr_abc123",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user"
    },
    "access_token": "eyJhbG...",
    "refresh_token": "eyJhbG...",
    "expires_in": 86400
  }
}
```

#### iOS Implementation Checklist:
- [ ] Create registration form (email, password, name, DOB)
- [ ] Validate email format locally
- [ ] Validate password strength (8+ chars, upper, lower, number)
- [ ] Validate age (13+ for COPPA compliance)
- [ ] Call registration endpoint
- [ ] Store tokens in Keychain (see Token Management)
- [ ] Handle validation errors (400)
- [ ] Handle duplicate email error (409)
- [ ] Navigate to onboarding/home on success

#### Error Scenarios:
- `400` - Invalid email format
- `400` - Password too weak
- `400` - Age < 13 (COPPA violation)
- `409` - Email already registered

#### Testing:
```bash
curl -X POST https://fit-iq-backend.fly.dev/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "full_name": "Test User",
    "date_of_birth": "1990-01-01"
  }'
```

---

### 🔑 2. Login (FOUNDATION - MUST HAVE)

**Complexity:** ⭐ Simple  
**Effort:** 0.5 day  
**Priority:** 🔴 Must Have  
**Dependencies:** Registration (need accounts first)  
**Blocks:** Everything

#### What You Need:
```
POST /api/v1/auth/login
```

#### Request:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

#### Response:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "usr_abc123",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "user"
    },
    "access_token": "eyJhbG...",
    "refresh_token": "eyJhbG...",
    "expires_in": 86400
  }
}
```

#### iOS Implementation Checklist:
- [ ] Create login form (email, password)
- [ ] Remember me option (store refresh token flag)
- [ ] Call login endpoint
- [ ] Store tokens in Keychain
- [ ] Store user info locally (UserDefaults or Core Data)
- [ ] Handle invalid credentials (401)
- [ ] Show "forgot password" option (if implemented)
- [ ] Navigate to home on success

#### Error Scenarios:
- `400` - Missing email or password
- `401` - Invalid credentials
- `404` - User not found

#### Testing:
```bash
curl -X POST https://fit-iq-backend.fly.dev/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!"
  }'
```

---

### 🔄 3. Token Management (FOUNDATION - MUST HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 1 day  
**Priority:** 🔴 Must Have  
**Dependencies:** Login (need tokens first)  
**Blocks:** Everything

#### What You Need:
```
POST /api/v1/auth/refresh  - Get new access token
POST /api/v1/auth/logout   - Invalidate refresh token
```

#### Token Lifecycle:
1. **Access Token (JWT)** - Expires in 24 hours, used for all API calls
2. **Refresh Token** - Expires in 30 days, used to get new access token
3. When access token expires (401) → Use refresh token → Get new access token
4. When refresh token expires → Force re-login

#### iOS Implementation Checklist:

**Storage (Keychain):**
- [ ] Store access token securely
- [ ] Store refresh token securely
- [ ] Store user ID
- [ ] Store token expiry timestamp

**Refresh Flow:**
- [ ] Detect 401 errors
- [ ] Call refresh endpoint with refresh token
- [ ] Update access token in Keychain
- [ ] Retry original request with new token
- [ ] If refresh fails (401) → Logout user

**Logout:**
- [ ] Call logout endpoint
- [ ] Clear all tokens from Keychain
- [ ] Clear user data
- [ ] Navigate to login screen

**Auto-refresh:**
- [ ] Check token expiry on app launch
- [ ] Proactively refresh if expiring soon (< 1 hour)

#### Refresh Request:
```json
{
  "refresh_token": "eyJhbG..."
}
```

#### Refresh Response:
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbG...",
    "refresh_token": "eyJhbG...",
    "expires_in": 86400
  }
}
```

#### Error Scenarios:
- `401` - Refresh token expired or invalid → Force re-login
- `400` - Missing refresh token

#### Code Example (Swift):
```swift
// Store tokens
func storeTokens(accessToken: String, refreshToken: String) {
    KeychainHelper.save(accessToken, for: "access_token")
    KeychainHelper.save(refreshToken, for: "refresh_token")
    UserDefaults.standard.set(Date().addingTimeInterval(86400), forKey: "token_expiry")
}

// Check if token is expired
func isTokenExpired() -> Bool {
    guard let expiry = UserDefaults.standard.object(forKey: "token_expiry") as? Date else {
        return true
    }
    return Date() >= expiry
}

// Refresh token
func refreshAccessToken() async throws {
    guard let refreshToken = KeychainHelper.load("refresh_token") else {
        throw AuthError.noRefreshToken
    }
    
    let response = try await authService.refresh(refreshToken: refreshToken)
    storeTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
}
```

---

### 🚨 4. Error Handling (FOUNDATION - MUST HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 1 day  
**Priority:** 🔴 Must Have  
**Dependencies:** None  
**Blocks:** User experience quality

#### What You Need:
Consistent error handling across all API calls.

#### Standard Error Response:
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "details": {
      "field": "email",
      "value": "not-an-email"
    }
  }
}
```

#### iOS Implementation Checklist:

**Error Types:**
- [ ] Network errors (no internet, timeout)
- [ ] Validation errors (400)
- [ ] Authentication errors (401)
- [ ] Authorization errors (403)
- [ ] Not found errors (404)
- [ ] Server errors (500)

**User-Friendly Messages:**
- [ ] Map error codes to readable messages
- [ ] Show alerts or toasts
- [ ] Provide actionable guidance
- [ ] Log errors for debugging

**Retry Logic:**
- [ ] Retry on 500 errors (exponential backoff)
- [ ] Don't retry on 400 errors (client fault)
- [ ] Retry on network failures

**Code Example:**
```swift
enum APIError: Error, LocalizedError {
    case networkError
    case validationError(String)
    case unauthorized
    case forbidden
    case notFound
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "No internet connection. Please check your network settings."
        case .validationError(let message):
            return message
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .serverError:
            return "Something went wrong. Please try again later."
        }
    }
}
```

---

### 👤 5. User Profile (CORE - MUST HAVE)

**Complexity:** ⭐ Simple  
**Effort:** 0.5 day  
**Priority:** 🔴 Must Have  
**Dependencies:** Login, Token Management  
**Blocks:** Personalization, BMI calculation, recommendations

#### What You Need:
```
GET /api/v1/profiles/{user_id}        - Get profile
PUT /api/v1/profiles/{user_id}        - Update profile
PUT /api/v1/profiles/{user_id}/physical - Update physical stats
```

#### Profile Data:
```json
{
  "id": "prof_123",
  "user_id": "usr_abc",
  "age": 30,
  "height_cm": 175.0,
  "weight_kg": 75.0,
  "bmi": 24.5,
  "body_fat_percent": 15.0,
  "resting_heart_rate": 60,
  "gender": "male",
  "activity_level": "moderately_active"
}
```

#### iOS Implementation Checklist:
- [ ] Create profile setup screen (onboarding)
- [ ] Input fields: age, height, weight, gender, activity level
- [ ] Optional: body fat %, resting HR
- [ ] Calculate BMI locally (for instant feedback)
- [ ] Call PUT endpoint to save
- [ ] Cache profile data locally
- [ ] Allow editing from settings
- [ ] Refresh on app launch (if stale)

#### Why It's Mandatory:
- BMI calculation requires height/weight
- Calorie recommendations require activity level
- AI coaching requires user context
- Age verification (already done in registration)

---

### ⚙️ 6. User Preferences (CORE - SHOULD HAVE)

**Complexity:** ⭐ Simple  
**Effort:** 0.5 day  
**Priority:** 🟡 Should Have  
**Dependencies:** Login  
**Blocks:** Unit display, goal tracking

#### What You Need:
```
GET /api/v1/preferences/{user_id}  - Get preferences
PUT /api/v1/preferences/{user_id}  - Update preferences
```

#### Preferences Data:
```json
{
  "user_id": "usr_abc",
  "units": "metric",
  "daily_calorie_goal": 2000,
  "daily_water_goal_ml": 2000,
  "theme": "dark",
  "language": "en",
  "notifications_enabled": true
}
```

#### iOS Implementation Checklist:
- [ ] Settings screen with toggles
- [ ] Unit system (metric/imperial)
- [ ] Calorie goals
- [ ] Water goals
- [ ] Theme (light/dark/system)
- [ ] Notification preferences
- [ ] Call PUT to save server-side
- [ ] Cache locally for offline access

#### Optional but Recommended:
This makes your app feel polished. Users expect customization.

---

### 🍎 7. Nutrition Tracking (CORE - DEPENDS ON FOCUS)

**Complexity:** ⭐⭐⭐ Medium  
**Effort:** 3-5 days  
**Priority:** 🔴 Must Have (if nutrition app) / 🟡 Should Have (if fitness app)  
**Dependencies:** Login, Profile  
**Blocks:** Meal templates, AI nutrition coaching

#### What You Need:
```
# Food Database (4,389 foods)
GET  /api/v1/foods/search?q=chicken        - Search foods
GET  /api/v1/foods/barcode/{barcode}       - Scan barcode
GET  /api/v1/foods/{id}                    - Get food details
POST /api/v1/foods                         - Create custom food
GET  /api/v1/foods/user/{user_id}          - User's custom foods

# Food Logging
POST   /api/v1/food-logs                   - Log a meal
GET    /api/v1/food-logs                   - Get logs (paginated)
DELETE /api/v1/food-logs/{id}              - Delete log
GET    /api/v1/food-logs/summary           - Daily nutrition summary

# AI Parsing (optional but cool)
POST /api/v1/nutrition/parse               - "2 eggs and toast"
```

#### iOS Implementation Checklist:

**Phase 1 - Basic Logging (2 days):**
- [ ] Food search screen
- [ ] Food details view (nutrition facts)
- [ ] Serving size picker
- [ ] Meal type selector (breakfast, lunch, dinner, snack)
- [ ] Log food button
- [ ] Food log list (today's meals)
- [ ] Delete food log

**Phase 2 - Barcode Scanning (1 day):**
- [ ] Integrate camera/barcode scanner
- [ ] Call barcode endpoint
- [ ] Handle not found (custom food entry)

**Phase 3 - Custom Foods (1 day):**
- [ ] Custom food entry form
- [ ] Nutrition label manual entry
- [ ] Save custom food
- [ ] Browse user's custom foods

**Phase 4 - Daily Summary (1 day):**
- [ ] Daily totals (calories, protein, carbs, fat)
- [ ] Progress rings/bars
- [ ] Goal comparison
- [ ] Macro breakdown chart

#### Food Search Response:
```json
{
  "success": true,
  "data": {
    "foods": [
      {
        "id": "food_123",
        "name": "Chicken Breast",
        "brand": "Generic",
        "calories": 165,
        "protein_g": 31,
        "carbs_g": 0,
        "fat_g": 3.6,
        "serving_size": "100g"
      }
    ],
    "total": 45,
    "page": 1,
    "page_size": 20
  }
}
```

#### Why It Matters:
- Core feature for nutrition-focused apps
- Required for AI meal recommendations
- Required for meal templates

#### Can You Skip This?
✅ YES - If your app focuses on workouts only  
❌ NO - If nutrition tracking is core value proposition

---

### 💪 8. Workout Tracking (CORE - DEPENDS ON FOCUS)

**Complexity:** ⭐⭐⭐ Medium  
**Effort:** 3-5 days  
**Priority:** 🔴 Must Have (if fitness app) / 🟡 Should Have (if nutrition app)  
**Dependencies:** Login, Profile  
**Blocks:** Workout templates, AI workout coaching

#### What You Need:
```
# Exercise Database (100+ exercises)
GET  /api/v1/exercises/search?q=squat      - Search exercises
GET  /api/v1/exercises/{id}                - Get exercise details
POST /api/v1/exercises                     - Create custom exercise
GET  /api/v1/exercises/user/{user_id}      - User's custom exercises

# Workout Logging
POST   /api/v1/workouts                    - Create workout
GET    /api/v1/workouts                    - Get workouts (paginated)
GET    /api/v1/workouts/{id}               - Get workout details
DELETE /api/v1/workouts/{id}               - Delete workout

# Exercise Logging (within workout)
POST   /api/v1/workouts/{id}/exercises     - Add exercise to workout
PUT    /api/v1/workouts/{workout_id}/exercises/{exercise_id}  - Update sets
DELETE /api/v1/workouts/{workout_id}/exercises/{exercise_id}  - Remove exercise
```

#### iOS Implementation Checklist:

**Phase 1 - Workout Creation (2 days):**
- [ ] Create workout screen
- [ ] Workout name/title input
- [ ] Exercise search/selector
- [ ] Add exercise to workout
- [ ] Exercise list in workout
- [ ] Save workout button

**Phase 2 - Exercise Logging (2 days):**
- [ ] Set/rep input for strength exercises
- [ ] Duration/distance input for cardio
- [ ] Rest timer between sets
- [ ] Edit/delete sets
- [ ] Exercise notes
- [ ] Finish workout button

**Phase 3 - Custom Exercises (1 day):**
- [ ] Custom exercise form
- [ ] Exercise category (strength, cardio, flexibility)
- [ ] Muscle groups selector
- [ ] Equipment needed
- [ ] Save custom exercise

**Phase 4 - Workout History (1 day):**
- [ ] List past workouts
- [ ] Workout details view
- [ ] Filter by date range
- [ ] Stats (total workouts, volume, PRs)

#### Workout Response:
```json
{
  "id": "workout_123",
  "user_id": "usr_abc",
  "title": "Upper Body Strength",
  "scheduled_at": "2025-01-27T10:00:00Z",
  "completed_at": "2025-01-27T11:30:00Z",
  "duration_minutes": 90,
  "notes": "Great session!",
  "exercises": [
    {
      "id": "we_456",
      "exercise_id": "ex_bench",
      "exercise_name": "Bench Press",
      "sets": 3,
      "reps": 10,
      "weight_kg": 80,
      "rest_seconds": 90
    }
  ]
}
```

#### Why It Matters:
- Core feature for fitness-focused apps
- Required for AI workout recommendations
- Required for workout templates
- Required for progressive overload tracking

#### Can You Skip This?
✅ YES - If your app focuses on nutrition only  
❌ NO - If workout tracking is core value proposition

---

### 😴 9. Sleep Tracking (SIMPLE - NICE TO HAVE)

**Complexity:** ⭐ Simple  
**Effort:** 0.5 day  
**Priority:** 🟢 Nice to Have  
**Dependencies:** Login  
**Blocks:** Nothing (standalone)

#### What You Need:
```
POST /api/v1/sleep              - Log sleep data
GET  /api/v1/sleep?user_id=X    - Get sleep history
```

#### Sleep Data:
```json
{
  "user_id": "usr_abc",
  "date": "2025-01-27",
  "hours_slept": 7.5,
  "quality": "good",
  "sleep_start": "2025-01-26T23:00:00Z",
  "sleep_end": "2025-01-27T06:30:00Z",
  "notes": "Woke up once"
}
```

#### iOS Implementation Checklist:
- [ ] Sleep log entry form
- [ ] Time picker (bedtime/wake time)
- [ ] Quality selector (poor/fair/good/excellent)
- [ ] Optional notes
- [ ] Sleep history list
- [ ] Weekly average calculation

#### Why It's Optional:
- Not required for core nutrition/fitness features
- Easy to add later
- Can integrate with HealthKit sleep data

---

### 📸 10. Activity Snapshots (SIMPLE - NICE TO HAVE)

**Complexity:** ⭐ Simple  
**Effort:** 1 day  
**Priority:** 🟢 Nice to Have  
**Dependencies:** Login  
**Blocks:** Nothing (standalone)

#### What You Need:
```
POST /api/v1/activity-snapshots           - Log HealthKit data
GET  /api/v1/activity-snapshots?user_id=X - Get snapshots
```

#### Snapshot Data:
```json
{
  "user_id": "usr_abc",
  "date": "2025-01-27",
  "steps": 8500,
  "active_calories": 450,
  "distance_km": 6.2,
  "activity_type": "walking",
  "duration_minutes": 75
}
```

#### iOS Implementation Checklist:
- [ ] Request HealthKit permissions
- [ ] Read daily activity data
- [ ] Send snapshot to backend
- [ ] Display activity history
- [ ] Show trends/charts

#### Why It's Optional:
- Not required for manual logging
- Can be added after core features
- Enhances user experience but not critical

---

### 🍽️ 11. Meal Templates (MEDIUM - SHOULD HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 2 days  
**Priority:** 🟡 Should Have  
**Dependencies:** Nutrition Tracking (#7)  
**Blocks:** AI meal recommendations

#### What You Need:
```
POST   /api/v1/meal-templates              - Create template
GET    /api/v1/meal-templates/{id}         - Get template
GET    /api/v1/meal-templates              - List user's templates
GET    /api/v1/meal-templates/public       - Browse 500+ public templates
PUT    /api/v1/meal-templates/{id}         - Update template
DELETE /api/v1/meal-templates/{id}         - Delete template
POST   /api/v1/meal-templates/{id}/foods   - Add food to template
POST   /api/v1/meal-templates/{id}/share   - Share publicly
POST   /api/v1/meal-templates/{id}/use     - Log entire template
```

#### iOS Implementation Checklist:
- [ ] Browse public templates (500+)
- [ ] Template details view
- [ ] "Use template" button (logs all foods)
- [ ] Create custom template
- [ ] Add foods to template
- [ ] Edit template
- [ ] Share template
- [ ] My templates list

#### Why It's Useful:
- Saves time (log entire meal at once)
- Browse community recipes
- Required for AI to suggest meal plans

#### Can You Skip This?
✅ YES - Initially, focus on basic logging  
❌ NO - If you want AI meal planning

---

### 🏋️ 12. Workout Templates (MEDIUM - SHOULD HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 2 days  
**Priority:** 🟡 Should Have  
**Dependencies:** Workout Tracking (#8)  
**Blocks:** AI workout recommendations

#### What You Need:
```
POST   /api/v1/workout-templates           - Create template
GET    /api/v1/workout-templates/{id}      - Get template
GET    /api/v1/workout-templates           - List user's templates
GET    /api/v1/workout-templates/public    - Browse public templates
PUT    /api/v1/workout-templates/{id}      - Update template
DELETE /api/v1/workout-templates/{id}      - Delete template
POST   /api/v1/workout-templates/{id}/use  - Start workout from template
```

#### iOS Implementation Checklist:
- [ ] Browse public templates
- [ ] Template details view
- [ ] "Start workout" button (creates workout from template)
- [ ] Create custom template
- [ ] Add exercises to template
- [ ] Edit template
- [ ] Share template
- [ ] My templates list

#### Why It's Useful:
- Saves time (start workout from template)
- Browse community programs
- Required for AI to suggest workout plans

#### Can You Skip This?
✅ YES - Initially, focus on basic logging  
❌ NO - If you want AI workout planning

---

### 🌟 13. Wellness Templates (MEDIUM - ADVANCED)

**Complexity:** ⭐⭐ Medium  
**Effort:** 1 day  
**Priority:** 🟢 Nice to Have  
**Dependencies:** Meal Templates (#11), Workout Templates (#12)  
**Blocks:** Nothing

#### What You Need:
```
POST /api/v1/wellness-templates            - Create wellness template
GET  /api/v1/wellness-templates/{id}       - Get template
GET  /api/v1/wellness-templates            - List templates
```

#### Wellness Template:
A wellness template combines meal + workout templates into a daily plan.

```json
{
  "id": "wellness_123",
  "name": "Weight Loss Day",
  "description": "1800 cal + HIIT workout",
  "meal_templates": [
    {
      "template_id": "meal_breakfast",
      "meal_type": "breakfast"
    },
    {
      "template_id": "meal_lunch",
      "meal_type": "lunch"
    }
  ],
  "workout_templates": [
    {
      "template_id": "workout_hiit",
      "time_of_day": "morning"
    }
  ]
}
```

#### iOS Implementation Checklist:
- [ ] Browse wellness templates
- [ ] Template details view
- [ ] "Use today" button (schedules everything)
- [ ] Create custom wellness template
- [ ] Add meal/workout templates to it

#### Why It's Optional:
- Requires both nutrition and workout features
- Advanced feature for engaged users
- Can be added after core features

---

### 🎯 14. Goal Management (MEDIUM - SHOULD HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 2 days  
**Priority:** 🟡 Should Have  
**Dependencies:** Nutrition (#7) and/or Workouts (#8)  
**Blocks:** Progress tracking

#### What You Need:
```
POST   /api/v1/goals               - Create goal
GET    /api/v1/goals/{id}          - Get goal details
GET    /api/v1/goals?user_id=X     - List user's goals
PUT    /api/v1/goals/{id}          - Update goal
DELETE /api/v1/goals/{id}          - Delete goal
PUT    /api/v1/goals/{id}/status   - Mark complete/paused
```

#### Goal Types:
- Weight goals (lose 10kg)
- Body composition (reach 15% body fat)
- Nutrition (eat 150g protein daily)
- Workout (workout 5x/week)
- Strength (bench 100kg)

#### iOS Implementation Checklist:
- [ ] Create goal screen
- [ ] Goal type selector
- [ ] Target value input
- [ ] Deadline picker
- [ ] Goal list with progress
- [ ] Mark goal complete
- [ ] Goal details view
- [ ] Progress chart

#### Why It's Useful:
- Motivates users
- Tracks long-term progress
- Required for AI goal coaching

---

### 📊 15. Progress Tracking (MEDIUM - SHOULD HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 1 day  
**Priority:** 🟡 Should Have  
**Dependencies:** Goals (#14), historical data  
**Blocks:** Nothing

#### What You Need:
```
GET /api/v1/progress/{user_id}?goal_id=X   - Progress toward goal
GET /api/v1/progress/{user_id}/weight      - Weight trend
GET /api/v1/progress/{user_id}/nutrition   - Nutrition trends
GET /api/v1/progress/{user_id}/workouts    - Workout trends
```

#### iOS Implementation Checklist:
- [ ] Progress dashboard
- [ ] Charts (line, bar)
- [ ] Date range selector
- [ ] Goal progress bars
- [ ] Trend analysis
- [ ] Export data

#### Why It's Useful:
- Visual feedback motivates users
- Shows what's working
- Required for AI insights

---

### 📈 16. Basic Analytics (MEDIUM - NICE TO HAVE)

**Complexity:** ⭐⭐ Medium  
**Effort:** 1 day  
**Priority:** 🟢 Nice to Have  
**Dependencies:** Historical data (nutrition, workouts)  
**Blocks:** Nothing

#### What You Need:
```
GET /api/v1/analytics/nutrition?user_id=X   - Nutrition insights
GET /api/v1/analytics/workouts?user_id=X    - Workout insights
GET /api/v1/analytics/summary?user_id=X     - Overall summary
```

#### Analytics Include:
- Average daily calories
- Macro breakdown trends
- Most logged foods
- Workout frequency
- Volume trends
- PRs (personal records)

#### iOS Implementation Checklist:
- [ ] Analytics tab/screen
- [ ] Summary cards (totals, averages)
- [ ] Charts (trends over time)
- [ ] Insights/recommendations
- [ ] Export reports

#### Why It's Optional:
- Not required for basic tracking
- Provides insights for engaged users
- Can be added incrementally

---

### 🤖 17. AI Consultation (COMPLEX - ADVANCED)

**Complexity:** ⭐⭐⭐ Complex  
**Effort:** 3-5 days  
**Priority:** 🟢 Nice to Have (but HIGH VALUE)  
**Dependencies:** Profile (#5), Nutrition (#7), Workouts (#8)  
**Blocks:** Nothing (but unlocks AI coaching)

#### What You Need:
```
# REST Endpoints
POST /api/v1/consultations              - Start consultation
GET  /api/v1/consultations/{id}         - Get consultation
GET  /api/v1/consultations?user_id=X    - List consultations

# WebSocket Streaming
WSS /ws/consultation?consultation_id=X  - Real-time AI chat
```

#### iOS Implementation Checklist:

**Phase 1 - Basic Chat (2 days):**
- [ ] Chat UI (messages list)
- [ ] Message input field
- [ ] Send button
- [ ] Create consultation endpoint call
- [ ] Display consultation history

**Phase 2 - WebSocket Streaming (2 days):**
- [ ] Integrate WebSocket library (Starscream)
- [ ] Connect to WebSocket
- [ ] Send user messages
- [ ] Receive AI responses (streaming)
- [ ] Display typing indicator
- [ ] Handle disconnections/reconnections

**Phase 3 - Context Integration (1 day):**
- [ ] Send user profile context
- [ ] Send recent nutrition logs
- [ ] Send recent workout logs
- [ ] Include goals in context

#### Why It's Complex:
- Requires WebSocket (not REST)
- Real-time streaming
- Managing connection state
- Context management
- Error handling (reconnects)

#### Why It's High Value:
- Differentiates your app
- Personalized AI coaching
- Can create templates for users
- Drives engagement

#### Can You Skip This?
✅ YES - Start with core tracking features  
⚠️ LATER - Add when you have 2-3 months of user data

---

### 🎨 18. AI Template Creation (COMPLEX - ADVANCED)

**Complexity:** ⭐⭐⭐ Complex  
**Effort:** 2 days  
**Priority:** 🟢 Nice to Have (requires AI Consultation)  
**Dependencies:** AI Consultation (#17), Templates (#11, #12, #13)  
**Blocks:** Nothing

#### What You Need:
AI creates templates during consultation, user approves/rejects them.

#### How It Works:
1. User chats with AI: "I want to lose weight"
2. AI creates meal template (1800 cal/day)
3. AI creates workout template (3x/week strength)
4. AI creates wellness template (combines both)
5. User approves templates
6. Templates saved to user's account
7. User can use templates anytime

#### iOS Implementation Checklist:
- [ ] Display proposed templates in chat
- [ ] Template preview card
- [ ] Approve/reject buttons
- [ ] Save approved templates
- [ ] "Use now" button
- [ ] View saved templates

#### Why It's Valuable:
- Personalized plans
- Saves users time
- Increases engagement
- Leverages AI capabilities

#### Can You Skip This?
✅ YES - Focus on manual template creation first  
⚠️ LATER - Add after AI consultation is stable

---

## ⏱️ Implementation Timeline

### Realistic 8-Week Plan (1 iOS Developer)

#### Week 1: Foundation ✅ MANDATORY
- Day 1-2: Registration + Login (1 day)
- Day 3-4: Token Management (1 day)
- Day 5: Error Handling (1 day)
- **Deliverable:** Users can sign up and sign in

#### Week 2: Profile & Setup ✅ MANDATORY
- Day 1-2: User Profile (1 day)
- Day 3: User Preferences (0.5 day)
- Day 4-5: Testing & polish (1.5 days)
- **Deliverable:** Users can complete onboarding

#### Week 3-4: Choose Your Path (Pick ONE)

**Option A - Nutrition Focus:**
- Week 3: Food search, barcode, logging (5 days)
- Week 4: Daily summary, custom foods (5 days)
- **Deliverable:** Full nutrition tracking

**Option B - Fitness Focus:**
- Week 3: Workout creation, exercise logging (5 days)
- Week 4: Workout history, custom exercises (5 days)
- **Deliverable:** Full workout tracking

**Option C - Both (requires more time):**
- Week 3: Basic nutrition (3 days) + basic workouts (2 days)
- Week 4: Enhanced nutrition (2 days) + enhanced workouts (3 days)
- **Deliverable:** Both features (less polish)

#### Week 5-6: Templates & Goals
- Week 5: Templates (meal/workout) (5 days)
- Week 6: Goals + Progress (5 days)
- **Deliverable:** Template system + goal tracking

#### Week 7: Analytics & Polish
- Analytics dashboard (2 days)
- Sleep tracking (1 day)
- Activity snapshots (1 day)
- Bug fixes (1 day)
- **Deliverable:** Complete app experience

#### Week 8: AI Integration (Optional)
- AI consultation chat (3 days)
- WebSocket streaming (2 days)
- **Deliverable:** AI coaching feature

---

## 🎯 Minimal Viable Product (MVP)

**What's the absolute minimum to launch?**

### MVP 1: Nutrition App (3 weeks)
✅ Registration + Login (1 day)  
✅ Token Management (1 day)  
✅ User Profile (1 day)  
✅ Food Logging (5 days)  
✅ Daily Summary (2 days)  
✅ Error Handling (1 day)  
✅ Testing + Polish (3 days)  

**Result:** Users can track what they eat

### MVP 2: Fitness App (3 weeks)
✅ Registration + Login (1 day)  
✅ Token Management (1 day)  
✅ User Profile (1 day)  
✅ Workout Logging (5 days)  
✅ Workout History (2 days)  
✅ Error Handling (1 day)  
✅ Testing + Polish (3 days)  

**Result:** Users can track workouts

### MVP 3: Comprehensive App (6 weeks)
✅ Foundation (3 days)  
✅ Profile (2 days)  
✅ Nutrition (5 days)  
✅ Workouts (5 days)  
✅ Goals (2 days)  
✅ Analytics (2 days)  
✅ Templates (3 days)  
✅ Testing + Polish (5 days)  

**Result:** Full-featured health tracking app

---

## 🚦 Decision Matrix

**Not sure what to build? Use this:**

| Your App Focus | Start With | Then Add | Later Add |
|---------------|------------|----------|-----------|
| **Nutrition Only** | Food logging (#7) | Meal templates (#11) | AI meal plans (#17) |
| **Fitness Only** | Workout logging (#8) | Workout templates (#12) | AI workout plans (#17) |
| **Weight Loss** | Food logging + Goals | Progress tracking | AI coaching |
| **Muscle Building** | Workout logging + Goals | Progress tracking | Progressive overload |
| **General Health** | Food + Workouts + Sleep | Analytics | AI wellness plans |
| **AI-First** | Foundation → Profile → Both nutrition & workouts → AI (#17) |

---

## 🎓 Pro Tips

### 1. Start Small
Don't try to build everything. Pick MVP 1 or MVP 2, ship it, get feedback.

### 2. Follow Dependencies
Never work on feature B if it requires feature A. You'll waste time.

### 3. Cache Everything
Cache profile, preferences, templates locally. Don't fetch every time.

### 4. Test Incrementally
Test each feature before moving on. Don't build 5 features then test.

### 5. Use Pagination
All list endpoints support pagination. Use it from day 1.

### 6. Handle Offline
Queue requests when offline, sync when back online.

### 7. Mock API First
Build UI with mock data, then connect real API. Parallel development.

### 8. Read OpenAPI Spec
Don't guess request/response formats. Read `docs/swagger.yaml`.

### 9. Ask for Help
Backend team is available. Swagger UI lets you test endpoints.

### 10. Ship Often
Ship weekly if possible. Get real user feedback early.

---

## 📞 Support

### Backend Endpoints
- **Health Check:** `https://fit-iq-backend.fly.dev/health`
- **Swagger UI:** `https://fit-iq-backend.fly.dev/swagger/index.html`

### Documentation
- **Full API Guide:** `docs/handoffs/FRONTEND_INTEGRATION_READY_2025_01_27.md`
- **OpenAPI Spec:** `docs/swagger.yaml`
- **Architecture:** `README.md`

### Questions?
1. Check Swagger documentation
2. Test endpoint via Swagger UI
3. Review request/response examples
4. Contact backend team

---

## 🎉 Summary

**The Golden Rule:** Authentication → Profile → Core Tracking → Templates → Goals → AI

**Start Here:**
1. ✅ Registration (0.5 day)
2. ✅ Login (0.5 day)
3. ✅ Token Management (1 day)
4. ✅ Error Handling (1 day)

**Then Choose:**
- Nutrition path (3 weeks to MVP)
- Fitness path (3 weeks to MVP)
- Both (6 weeks to MVP)

**Finally Add:**
- Templates (nice to have)
- Goals (engagement)
- Analytics (insights)
- AI (differentiation)

---

**Good luck building! The backend is stable, tested, and ready for you. 🚀**