# FitIQ iOS - Next Steps & Priority Roadmap

**Date:** 2025-01-27  
**Current Status:** ✅ Phase 1 Complete - Authentication Working  
**Next Phase:** Phase 2 - User Profile Setup

---

## 🎉 Completed: Phase 1 - Foundation

### ✅ What's Done
- [x] API Configuration (config.plist)
- [x] User Registration Flow
- [x] User Login Flow
- [x] JWT Token Handling
- [x] Token Persistence (Keychain)
- [x] Profile Construction (workaround for missing /users/{id} endpoint)
- [x] Authentication State Management
- [x] Error Handling (API, Validation, Network)
- [x] Session Persistence

### 🏆 Achievement
**Users can register, login, and stay authenticated across app restarts!**

---

## 🎯 NEXT: Phase 2 - User Profile Setup (Week 2)

### Overview
Now that authentication works, users need to complete their profile during onboarding. This is **MANDATORY** before they can access the main app features.

### Priority Tasks

#### 🔴 HIGH PRIORITY - Week 2 (Days 1-5)

##### Task 1: User Profile Management (Days 1-2)
**Goal:** Allow users to view and update their profile information

**Backend Endpoints:**
- `GET /api/v1/users/{id}` - Get user profile (when implemented)
- `PUT /api/v1/users/{id}` - Update user profile
- `GET /api/v1/profiles/{user_id}` - Get health profile
- `PUT /api/v1/profiles/{user_id}` - Update health profile

**What to Build:**
1. **Domain Layer:**
   - Create `UpdateUserProfileUseCase`
   - Create `GetUserProfileUseCase`
   - Port: `UserProfileRepositoryProtocol`

2. **Infrastructure Layer:**
   - Create `UserProfileAPIClient`
   - Implement PUT /users/{id} endpoint integration
   - Implement GET/PUT /profiles/{user_id} for health data

3. **Presentation Layer:**
   - Create `ProfileSetupViewModel`
   - Update existing `ProfileView` to support editing
   - Form validation for profile fields

**Profile Fields:**
```swift
User Profile (/users/{id}):
- firstName: String
- lastName: String
- dateOfBirth: Date
- email: String (read-only)

Health Profile (/profiles/{user_id}):
- age: Int (calculated from DOB)
- heightCm: Double
- weightKg: Double
- gender: String? ("male", "female", "other")
- activityLevel: String? ("sedentary", "light", "moderate", "active", "very_active")
```

**UI Fields to Add:**
- Height (with unit selection: cm/ft)
- Weight (with unit selection: kg/lbs)
- Gender selector
- Activity level selector
- Date of Birth picker (if not captured in registration)

**Success Criteria:**
- [ ] User can view current profile
- [ ] User can edit firstName, lastName
- [ ] User can set height and weight
- [ ] User can select gender
- [ ] User can select activity level
- [ ] Profile saves to backend successfully
- [ ] Profile persists locally in SwiftData
- [ ] Validation errors display properly
- [ ] Loading states work correctly

##### Task 2: User Preferences (Days 3-4)
**Goal:** Allow users to set app preferences and fitness goals

**Backend Endpoints:**
- `GET /api/v1/preferences` - Get user preferences
- `PUT /api/v1/preferences` - Update preferences

**What to Build:**
1. **Domain Layer:**
   - Create `UpdateUserPreferencesUseCase`
   - Create `GetUserPreferencesUseCase`
   - Port: `UserPreferencesRepositoryProtocol`
   - Entity: `UserPreferences`

2. **Infrastructure Layer:**
   - Create `UserPreferencesAPIClient`
   - Implement GET/PUT /preferences integration

3. **Presentation Layer:**
   - Create `PreferencesViewModel`
   - Create `PreferencesView` (or add to settings)

**Preference Fields:**
```swift
UserPreferences:
- units: String ("metric" or "imperial")
- theme: String ("light", "dark", "system")
- notificationsEnabled: Bool
- dailyCalorieGoal: Int?
- dailyProteinGoal: Int?
- dailyCarbsGoal: Int?
- dailyFatGoal: Int?
- weeklyWorkoutGoal: Int?
```

**UI Components:**
- Unit system toggle (Metric/Imperial)
- Theme selector
- Notification preferences
- Daily macro goals (optional)
- Weekly workout goal (optional)

**Success Criteria:**
- [ ] User can view current preferences
- [ ] User can toggle metric/imperial units
- [ ] User can set macro goals
- [ ] User can set workout goals
- [ ] Preferences save to backend
- [ ] Preferences persist locally
- [ ] Units affect display throughout app

##### Task 3: Onboarding Flow (Day 5)
**Goal:** Guide new users through profile setup

**What to Build:**
1. **Onboarding Coordinator:**
   - Multi-step onboarding flow
   - Progress indicator
   - Skip/Complete logic

2. **Onboarding Steps:**
   ```
   Step 1: Welcome → Explain FitIQ features
   Step 2: Basic Info → firstName, lastName (if empty from registration)
   Step 3: Physical Stats → height, weight, gender
   Step 4: Activity Level → Select activity level
   Step 5: Goals → Set daily calorie/macro goals (optional)
   Step 6: Preferences → Units, theme
   Step 7: Permissions → HealthKit authorization
   ```

3. **Navigation Logic:**
   - After login: Check if `hasCompletedOnboarding`
   - If no → Show onboarding
   - If yes → Show main app
   - Save completion flag in UserDefaults

**Success Criteria:**
- [ ] New users see onboarding after registration
- [ ] Onboarding is skippable (with warning)
- [ ] All profile data collected during onboarding
- [ ] Completion flag saves properly
- [ ] Returning users skip onboarding
- [ ] Beautiful, intuitive UI/UX

---

## 📋 Implementation Guide for Phase 2

### Step-by-Step: Task 1 - User Profile

#### 1. Create Domain Entities

**File:** `FitIQ/Domain/Entities/HealthProfile.swift`
```swift
struct HealthProfile {
    let id: String
    let userId: String
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var gender: String?
    var activityLevel: String?
    let createdAt: Date
    let updatedAt: Date
}
```

#### 2. Create Use Case Protocol

**File:** `FitIQ/Domain/UseCases/UpdateUserProfileUseCase.swift`
```swift
protocol UpdateUserProfileUseCaseProtocol {
    func execute(userId: String, firstName: String?, lastName: String?) async throws -> UserProfile
}

protocol UpdateHealthProfileUseCaseProtocol {
    func execute(
        userId: String, 
        heightCm: Double?, 
        weightKg: Double?, 
        gender: String?, 
        activityLevel: String?
    ) async throws -> HealthProfile
}
```

#### 3. Create Infrastructure Port

**File:** `FitIQ/Domain/Ports/UserProfileAPIClientProtocol.swift`
```swift
protocol UserProfileAPIClientProtocol {
    func getUserProfile(userId: String) async throws -> UserProfile
    func updateUserProfile(userId: String, firstName: String?, lastName: String?) async throws -> UserProfile
    func getHealthProfile(userId: String) async throws -> HealthProfile
    func updateHealthProfile(userId: String, heightCm: Double?, weightKg: Double?, gender: String?, activityLevel: String?) async throws -> HealthProfile
}
```

#### 4. Implement API Client

**File:** `FitIQ/Infrastructure/Network/UserProfileAPIClient.swift`
```swift
final class UserProfileAPIClient: UserProfileAPIClientProtocol {
    private let networkClient: NetworkClientProtocol
    private let baseURL: String
    private let apiKey: String
    
    // Implement methods to call:
    // PUT /api/v1/users/{id}
    // GET /api/v1/profiles/{user_id}
    // PUT /api/v1/profiles/{user_id}
}
```

#### 5. Create ViewModel

**File:** `FitIQ/Presentation/ViewModels/ProfileSetupViewModel.swift`
```swift
@Observable
final class ProfileSetupViewModel {
    var firstName: String
    var lastName: String
    var heightCm: String
    var weightKg: String
    var gender: String?
    var activityLevel: String?
    var isLoading: Bool
    var errorMessage: String?
    
    private let updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol
    private let updateHealthProfileUseCase: UpdateHealthProfileUseCaseProtocol
    
    func saveProfile() async { ... }
}
```

#### 6. Update View

**File:** `FitIQ/Presentation/Views/ProfileSetupView.swift`
- Add form fields for all profile data
- Bind to ViewModel properties
- Handle save button action
- Display loading/error states

#### 7. Register in AppDependencies

**File:** `FitIQ/Infrastructure/Configuration/AppDependencies.swift`
```swift
// Add to AppDependencies:
let userProfileAPIClient: UserProfileAPIClientProtocol
let updateUserProfileUseCase: UpdateUserProfileUseCaseProtocol
let updateHealthProfileUseCase: UpdateHealthProfileUseCaseProtocol
let profileSetupViewModel: ProfileSetupViewModel
```

---

## 🚀 After Phase 2: Phase 3 - Core Tracking (Week 3-4)

Once user profiles are complete, implement core tracking features:

### Week 3: Nutrition Tracking
**Priority:** HIGH - This is the primary app feature

**Endpoints:**
- `GET /api/v1/foods/search?q={query}` - Search foods
- `POST /api/v1/food-logs` - Log food
- `GET /api/v1/food-logs?date={date}` - Get daily logs
- `GET /api/v1/nutrition/summary?date={date}` - Get daily summary

**Features to Build:**
1. Food search with database
2. Food logging (meal type, portion size)
3. Daily nutrition dashboard
4. Macro tracking (calories, protein, carbs, fat)
5. Custom food creation

### Week 4: Workout Tracking
**Priority:** HIGH - Secondary app feature

**Endpoints:**
- `GET /api/v1/exercises/search?q={query}` - Search exercises
- `POST /api/v1/workout-logs` - Log workout
- `GET /api/v1/workout-logs?date={date}` - Get workout history

**Features to Build:**
1. Exercise search
2. Workout logging (sets, reps, weight, duration)
3. Workout history
4. Custom exercises

---

## 📊 Current Progress Overview

```
✅ Phase 1: Foundation (Week 1) - COMPLETE
    ✅ Authentication & Registration
    ✅ Token Management
    ✅ Session Persistence

🔄 Phase 2: Profile Setup (Week 2) - IN PROGRESS
    ⬜ User Profile Management
    ⬜ User Preferences
    ⬜ Onboarding Flow

⬜ Phase 3: Core Tracking (Week 3-4)
    ⬜ Nutrition Tracking
    ⬜ Workout Tracking

⬜ Phase 4: Enhancement (Week 5-6)
    ⬜ Goals & Progress
    ⬜ Templates
    ⬜ Sleep Tracking
    ⬜ Activity Snapshots

⬜ Phase 5: AI Features (Week 7-8) - Optional
    ⬜ WebSocket Setup
    ⬜ Chat Interface
    ⬜ AI Consultations
```

---

## 🎯 Immediate Action Items (Start Now)

### Today - Profile Setup Foundation

1. **Create Domain Entities** (30 min)
   - [ ] Create `HealthProfile.swift`
   - [ ] Update `UserProfile.swift` if needed

2. **Create Use Case Protocols** (30 min)
   - [ ] `UpdateUserProfileUseCase.swift`
   - [ ] `UpdateHealthProfileUseCase.swift`
   - [ ] `GetHealthProfileUseCase.swift`

3. **Create Port Protocols** (30 min)
   - [ ] `UserProfileAPIClientProtocol.swift`
   - [ ] `HealthProfileRepositoryProtocol.swift`

4. **Create DTOs** (30 min)
   - [ ] `UserProfileDTOs.swift`
   - [ ] `HealthProfileDTOs.swift`

5. **Implement API Client** (2-3 hours)
   - [ ] `UserProfileAPIClient.swift`
   - [ ] Implement GET /profiles/{user_id}
   - [ ] Implement PUT /profiles/{user_id}
   - [ ] Implement PUT /users/{id}

6. **Create ViewModel** (1-2 hours)
   - [ ] `ProfileSetupViewModel.swift`
   - [ ] Form validation logic
   - [ ] Save profile logic

7. **Update View** (2-3 hours)
   - [ ] Add profile form fields to existing ProfileView
   - [ ] Or create new ProfileSetupView
   - [ ] Form UI with all required fields
   - [ ] Validation feedback
   - [ ] Loading states

8. **Test End-to-End** (1 hour)
   - [ ] Complete profile setup flow
   - [ ] Verify data saves to backend
   - [ ] Verify data persists locally
   - [ ] Test error scenarios

---

## 📚 Resources

### Documentation
- **API Spec:** `docs/api-integration/`
- **Integration Handoff:** `docs/api-integration/IOS_INTEGRATION_HANDOFF.md`
- **Project Guidelines:** `.github/copilot-instructions.md`

### Existing Code to Reference
- **Use Case Pattern:** `Domain/UseCases/RegisterUserUseCase.swift`
- **API Client Pattern:** `Infrastructure/Network/UserAuthAPIClient.swift`
- **ViewModel Pattern:** `Presentation/ViewModels/RegistrationViewModel.swift`
- **Port Pattern:** `Domain/Ports/AuthRepositoryProtocol.swift`

### Backend API Documentation
- **Base URL:** `https://fit-iq-backend.fly.dev`
- **API Key:** In `config.plist`
- **Swagger:** (if available) `https://fit-iq-backend.fly.dev/swagger/index.html`

---

## 🔔 Important Notes

### Backend Endpoint Status
⚠️ **Known Issue:** `/api/v1/users/{id}` endpoint doesn't exist yet
- Registration and login work around this by constructing profiles from JWT
- For profile updates, check if PUT `/api/v1/users/{id}` is implemented
- If not, coordinate with backend team or focus on health profile (`/api/v1/profiles/{user_id}`)

### Data Persistence Strategy
- **Remote (Backend):** Source of truth for user data
- **Local (SwiftData):** Cache for offline access and performance
- **Sync Strategy:** 
  - Save to backend first
  - On success, update local cache
  - On error, show error, keep local data unchanged

### Unit Handling
- **Backend:** Always uses metric (cm, kg)
- **iOS App:** Support both metric and imperial
- **Conversion:** Handle in presentation layer
- **Storage:** Always store metric in backend

---

## ✅ Success Criteria for Phase 2

Phase 2 is complete when:
- [ ] User can view and update profile (firstName, lastName)
- [ ] User can set physical stats (height, weight, gender)
- [ ] User can select activity level
- [ ] User can set preferences (units, goals)
- [ ] All data saves to backend successfully
- [ ] All data persists locally
- [ ] Onboarding flow guides new users
- [ ] Returning users skip onboarding
- [ ] Profile data displays correctly throughout app
- [ ] Unit conversions work correctly
- [ ] Error handling is robust
- [ ] No crashes or data loss

---

## 🎉 Milestone Celebration

Once Phase 2 is complete, you will have:
- ✅ Full authentication system
- ✅ Complete user profile management
- ✅ Onboarding experience
- ✅ Foundation for all tracking features

**Next up:** Start tracking nutrition and workouts! 🍎💪

---

**Status:** 🚀 Ready to Start Phase 2  
**Estimated Time:** 5 days (Week 2)  
**Priority:** HIGH - Required before tracking features  
**Last Updated:** 2025-01-27