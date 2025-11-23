# FitIQ Workspace - AI Assistant Instructions

**Version:** 3.0.0  
**Last Updated:** 2025-01-27  
**Purpose:** Guidelines for AI assistants working on the unified FitIQ workspace (FitIQ app + Lume app + FitIQCore shared package)

---

## 🎯 Workspace Overview

This is an iOS workspace containing **three projects** that share a common architecture and backend:

### 1. FitIQ App - Fitness & Nutrition Intelligence
**Focus:** Quantitative health metrics
- Activity tracking (steps, heart rate)
- Body metrics (weight, BMI)
- Nutrition tracking (4,389+ foods, AI parsing)
- Workout management (100+ exercises)
- Sleep tracking
- Goal management
- AI Coach (fitness-focused)

**Target Users:** Gym-goers, athletes, fitness enthusiasts

---

### 2. Lume App - Wellness & Mood Intelligence
**Focus:** Qualitative mental health
- Mood tracking (iOS 18 HealthKit HKStateOfMind)
- Wellness templates
- Mindfulness practices
- Stress management
- Daily habits tracking
- Recovery optimization

**Target Users:** Mindfulness seekers, wellness-focused individuals

---

### 3. FitIQCore Package - Shared Infrastructure
**Purpose:** Common code shared by both apps
- Authentication (JWT, Keychain storage)
- API client foundation (NetworkClientProtocol, DTOs)
- HealthKit integration framework
- SwiftData persistence utilities
- Common UI components
- Error handling & validation
- Logging & analytics

**Type:** Swift Package (SPM)

---

## 🏗️ Architecture Principles

### Hexagonal Architecture (Ports & Adapters)

Both FitIQ and Lume follow the same clean architecture pattern:

```
Presentation Layer (ViewModels/Views)
    ↓ depends on ↓
Domain Layer (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure Layer (Repositories, Network, Services)
    ↑ depends on ↑
FitIQCore (Shared Package)
```

**Key Principles:**
- Domain layer is pure business logic (no external dependencies)
- Domain defines interfaces (ports via protocols)
- Infrastructure implements interfaces (adapters)
- Presentation depends only on domain abstractions
- FitIQCore provides shared infrastructure (authentication, API, HealthKit)
- Use dependency injection (via AppDependencies in each app)

---

## 📁 Workspace Structure

```
FitIQ.xcworkspace/
│
├── FitIQCore/                    # Swift Package (Shared)
│   ├── Package.swift
│   ├── Sources/
│   │   └── FitIQCore/
│   │       ├── Auth/
│   │       │   ├── Domain/      # Auth entities, use cases
│   │       │   └── Infrastructure/ # Auth implementations
│   │       ├── Profile/
│   │       │   ├── Domain/
│   │       │   └── Infrastructure/
│   │       ├── Network/
│   │       │   ├── NetworkClientProtocol.swift
│   │       │   ├── URLSessionNetworkClient.swift
│   │       │   └── DTOs/        # Shared API response models
│   │       ├── HealthKit/
│   │       │   ├── HealthKitManagerProtocol.swift
│   │       │   └── HealthKitManager.swift
│   │       ├── Persistence/
│   │       │   ├── SwiftDataUtilities.swift
│   │       │   └── RepositoryHelpers.swift
│   │       ├── Common/
│   │       │   ├── Errors/
│   │       │   ├── Extensions/
│   │       │   └── Utilities/
│   │       └── UI/
│   │           └── Components/  # Shared UI components
│   └── Tests/
│       └── FitIQCoreTests/
│
├── FitIQ/                        # FitIQ App (Fitness & Nutrition)
│   ├── FitIQ.xcodeproj
│   ├── Presentation/
│   │   ├── ViewModels/          # @Observable ViewModels
│   │   │   ├── SummaryViewModel.swift
│   │   │   ├── NutritionViewModel.swift
│   │   │   ├── WorkoutViewModel.swift
│   │   │   └── ProfileViewModel.swift
│   │   └── UI/                  # SwiftUI Views
│   │       ├── Nutrition/
│   │       ├── Workout/
│   │       ├── BodyMass/
│   │       ├── Activity/
│   │       ├── Sleep/
│   │       ├── Goal/
│   │       └── Summary/
│   ├── Domain/
│   │   ├── Entities/            # SwiftData @Model (prefix: SD)
│   │   │   ├── Nutrition/       # SDMeal, SDFood, etc.
│   │   │   ├── Workout/         # SDWorkout, SDExercise, etc.
│   │   │   └── Activity/        # SDActivitySnapshot, etc.
│   │   ├── UseCases/            # Business logic
│   │   │   ├── Nutrition/
│   │   │   ├── Workout/
│   │   │   ├── Activity/
│   │   │   └── Goal/
│   │   └── Ports/               # Protocols
│   │       ├── NutritionRepositoryProtocol.swift
│   │       ├── WorkoutRepositoryProtocol.swift
│   │       └── ActivityRepositoryProtocol.swift
│   ├── Infrastructure/
│   │   ├── Repositories/        # SwiftData implementations
│   │   ├── Network/             # API clients
│   │   └── Services/            # Background services
│   ├── DI/
│   │   └── AppDependencies.swift
│   ├── Resources/
│   │   └── config.plist
│   └── FitIQApp.swift
│
└── Lume/                         # Lume App (Wellness & Mood)
    ├── Lume.xcodeproj
    ├── Presentation/
    │   ├── ViewModels/          # @Observable ViewModels
    │   │   ├── MoodViewModel.swift
    │   │   ├── WellnessViewModel.swift
    │   │   └── MindfulnessViewModel.swift
    │   └── UI/                  # SwiftUI Views
    │       ├── Mood/
    │       ├── Wellness/
    │       ├── Mindfulness/
    │       └── DailyHabits/
    ├── Domain/
    │   ├── Entities/            # SwiftData @Model (prefix: SD)
    │   │   ├── Mood/            # SDMoodEntry, etc.
    │   │   └── Wellness/        # SDWellnessTemplate, etc.
    │   ├── UseCases/            # Business logic
    │   │   ├── Mood/
    │   │   ├── Wellness/
    │   │   └── Mindfulness/
    │   └── Ports/               # Protocols
    │       ├── MoodRepositoryProtocol.swift
    │       └── WellnessRepositoryProtocol.swift
    ├── Infrastructure/
    │   ├── Repositories/        # SwiftData implementations
    │   ├── Network/             # API clients
    │   └── Services/            # Background services
    ├── DI/
    │   └── AppDependencies.swift
    ├── Resources/
    │   └── config.plist
    └── LumeApp.swift
```

---

## 🚨 CRITICAL: Read This First

### ⚠️ NEVER Do These Things

1. **❌ NEVER create or update UI/Views without explicit request**
   - Focus on Domain, UseCases, Repositories, Network, Services
   - **EXCEPTION:** Binding fields from view to save/persist/remote calls is ALLOWED
   - ViewModels are OK to create/modify
   - UI layout, styling, navigation = OFF LIMITS unless specifically requested

2. **❌ NEVER hardcode configuration**
   - API key MUST be in `config.plist`
   - Base URLs MUST be in `config.plist`
   - No hardcoded secrets in code
   - Both FitIQ and Lume have their own `config.plist`

3. **❌ NEVER modify `docs/api-spec.yaml`**
   - This file is symlinked to backend project (read-only)
   - It's the source of truth for API contracts
   - Reference it, don't change it

4. **❌ NEVER create infrastructure before domain**
   - Always start with domain entities and use cases
   - Then create ports (protocols)
   - Then create infrastructure implementations
   - Presentation depends on domain abstractions

5. **❌ NEVER skip examining existing code**
   - Review existing patterns in BOTH apps before implementing
   - Follow established naming conventions
   - Maintain consistency across workspace

6. **❌ NEVER forget the SD prefix for SwiftData models**
   - All `@Model` classes MUST use prefix `SD`
   - Example: `SDMeal` (FitIQ), `SDMoodEntry` (Lume)
   - This is MANDATORY for schema clarity

7. **❌ NEVER duplicate code between apps**
   - If code is used by both apps, it belongs in FitIQCore
   - Only app-specific logic should be in FitIQ or Lume
   - Examples of shared code: Authentication, API client, HealthKit framework

8. **❌ NEVER break the dependency direction**
   - FitIQ depends on FitIQCore ✅
   - Lume depends on FitIQCore ✅
   - FitIQCore depends on FitIQ or Lume ❌ NEVER

9. **❌ NEVER place markdown files directly in project root folders**
   - All markdown files MUST be in `./docs` directories
   - Organize by domain/feature in subdirectories
   - Workspace-level: `/docs/split-strategy/`, `/docs/architecture/`
   - FitIQ: `/FitIQ/docs/features/`, `/FitIQ/docs/architecture/`
   - Lume: `/lume/docs/features/`, `/lume/docs/architecture/`
   - Exception: README.md in project root is REQUIRED

---

## ✅ ALWAYS Do These Things

### 1. Determine Which App/Package to Modify

Before making changes, ask:
- **Is it fitness/nutrition related?** → FitIQ app
- **Is it wellness/mood related?** → Lume app
- **Is it shared infrastructure?** → FitIQCore package
- **Is it used by both apps?** → FitIQCore package

### 2. Check FitIQCore First

Before implementing anything:
- Check if similar functionality exists in FitIQCore
- Review FitIQCore's Auth, Profile, Network, HealthKit modules
- Use existing FitIQCore APIs instead of duplicating
- Only add to FitIQCore if needed by both apps

### 3. Follow App-Specific Patterns

**For FitIQ:**
- Focus on quantitative metrics (numbers, measurements, goals)
- Use fitness/nutrition terminology
- Integrate with workout/meal databases
- Performance-focused UI (bold, energetic colors)

**For Lume:**
- Focus on qualitative experiences (feelings, states, habits)
- Use wellness/mindfulness terminology
- Integrate with iOS 18 HKStateOfMind
- Calm, soothing UI (soft colors, smooth animations)

### 4. Maintain Backend Unity

- Both apps use the SAME backend API
- Both apps use the SAME authentication flow (via FitIQCore)
- Both apps share the SAME user account
- API endpoints are shared: `/api/v1/progress`, `/api/v1/mood`, etc.

---

## 🔌 Backend Integration

### Shared Backend
**Base URL:** `https://fit-iq-backend.fly.dev/api/v1`  
**Authentication:** JWT tokens (via FitIQCore)  
**User Account:** Single account across both apps

### API Distribution

**FitIQ Endpoints (~100):**
- `/api/v1/progress` (steps, heart rate, weight, height)
- `/api/v1/foods`, `/api/v1/food-logs`, `/api/v1/meal-logs`
- `/api/v1/workouts`, `/api/v1/exercises`
- `/api/v1/sleep`
- `/api/v1/goals`
- `/api/v1/activity-snapshots`
- `/api/v1/analytics`

**Lume Endpoints (~25):**
- `/api/v1/mood` (mood tracking)
- `/api/v1/wellness/templates` (wellness templates)
- `/api/v1/progress` (for habits tracking)

**Shared (FitIQCore) (~8):**
- `/api/v1/auth/register`, `/api/v1/auth/login`, `/api/v1/auth/refresh`
- `/api/v1/users/me`, `/api/v1/users/me/physical`, `/api/v1/users/me/preferences`

---

## 📦 FitIQCore Package Guidelines

### When to Add to FitIQCore

Add code to FitIQCore if:
- ✅ Used by BOTH FitIQ and Lume
- ✅ Authentication/authorization logic
- ✅ Network client foundation
- ✅ HealthKit integration utilities
- ✅ SwiftData common patterns
- ✅ Shared UI components (buttons, cards, etc.)
- ✅ Error handling frameworks
- ✅ Logging/analytics

Do NOT add to FitIQCore if:
- ❌ Only used by one app
- ❌ App-specific business logic
- ❌ App-specific entities
- ❌ App-specific views

### FitIQCore Module Structure

```swift
// FitIQCore/Sources/FitIQCore/Auth/Domain/AuthManager.swift
public protocol AuthManagerProtocol {
    func register(email: String, password: String) async throws -> User
    func login(email: String, password: String) async throws -> AuthTokens
    func refreshToken() async throws -> AuthTokens
}

// Used by both FitIQ and Lume
public final class AuthManager: AuthManagerProtocol {
    private let networkClient: NetworkClientProtocol
    private let tokenStorage: TokenStorageProtocol
    
    public init(networkClient: NetworkClientProtocol, tokenStorage: TokenStorageProtocol) {
        self.networkClient = networkClient
        self.tokenStorage = tokenStorage
    }
    
    // Implementation...
}
```

---

## 🔄 Cross-App Integration

### Deep Linking

Both apps support deep linking to each other:

**FitIQ → Lume:**
```swift
// In FitIQ: Suggest mood logging after workout
Button("Log your mood") {
    if let url = URL(string: "lume://mood/log") {
        UIApplication.shared.open(url)
    }
}
```

**Lume → FitIQ:**
```swift
// In Lume: Suggest activity tracking
Button("View activity stats") {
    if let url = URL(string: "fitiq://activity/summary") {
        UIApplication.shared.open(url)
    }
}
```

### URL Schemes

- **FitIQ:** `fitiq://`
- **Lume:** `lume://`

Both must be configured in their respective `Info.plist` files.

---

## 🎨 Design Language

### FitIQ Design
- **Colors:** Bold blues, energetic oranges, performance-focused
- **Typography:** San Francisco (system), bold weights
- **Mood:** Energetic, motivational, goal-driven
- **Icons:** SF Symbols fitness/nutrition icons
- **Animations:** Quick, snappy, responsive

### Lume Design
- **Colors:** Soft blues, calming greens, gentle purples
- **Typography:** San Francisco (system), lighter weights
- **Mood:** Calm, peaceful, mindful
- **Icons:** SF Symbols wellness/nature icons
- **Animations:** Slow, smooth, flowing

### Shared Design (FitIQCore Components)
- **Colors:** Neutral (gray scale), adaptable to each app
- **Typography:** System defaults
- **Components:** Buttons, cards, form fields, error messages
- **Accessibility:** Full VoiceOver support, Dynamic Type

---

## 🔐 Authentication Flow

Both apps use FitIQCore for authentication:

```swift
// In FitIQ/AppDependencies.swift or Lume/AppDependencies.swift

import FitIQCore

final class AppDependencies {
    // FitIQCore provides AuthManager
    lazy var authManager: AuthManagerProtocol = AuthManager(
        networkClient: networkClient,
        tokenStorage: KeychainTokenStorage()
    )
    
    // App-specific dependencies
    lazy var nutritionRepository: NutritionRepositoryProtocol = ...
    lazy var moodRepository: MoodRepositoryProtocol = ...
}
```

**Key Points:**
- JWT tokens stored in Keychain (via FitIQCore)
- Token refresh handled automatically (via FitIQCore)
- User profile shared across apps (via backend)
- Login in one app = logged in both apps

---

## 📊 Data Sync Strategy

### Local-First Architecture

Both apps follow the same sync pattern:

```
User Action
    ↓
Domain Use Case
    ↓
1. Save to Local Storage (SwiftData)
2. Mark as pending_sync
    ↓
Background Sync Service
    ↓
Sync to Backend API
    ↓
Update sync status to synced
```

### Outbox Pattern (Progress Tracking)

Both apps use the Outbox Pattern for reliable sync:
- All progress entries (steps, heart rate, weight, mood) use Outbox
- Local save + create outbox event
- Background processor syncs to backend
- Automatic retry on failure
- No data loss on app crash

---

## 🧪 Testing Guidelines

### Unit Tests

**FitIQCore Tests:**
```swift
// FitIQCore/Tests/FitIQCoreTests/Auth/AuthManagerTests.swift
@testable import FitIQCore

final class AuthManagerTests: XCTestCase {
    var sut: AuthManager!
    var mockNetworkClient: MockNetworkClient!
    var mockTokenStorage: MockTokenStorage!
    
    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        mockTokenStorage = MockTokenStorage()
        sut = AuthManager(
            networkClient: mockNetworkClient,
            tokenStorage: mockTokenStorage
        )
    }
    
    func testLogin_ValidCredentials_ReturnsTokens() async throws {
        // Test implementation
    }
}
```

**App-Specific Tests:**
- FitIQ: Test nutrition, workout, activity use cases
- Lume: Test mood, wellness, mindfulness use cases
- Both: Mock FitIQCore dependencies

### Integration Tests

Test cross-app scenarios:
- Login in FitIQ, verify Lume has access
- Deep link from FitIQ to Lume
- Data sync between apps (via backend)

---

## 📝 Naming Conventions

### Files

**FitIQCore:**
- Protocols: `AuthManagerProtocol.swift`, `NetworkClientProtocol.swift`
- Implementations: `AuthManager.swift`, `URLSessionNetworkClient.swift`
- DTOs: `UserDTO.swift`, `AuthTokensDTO.swift`

**FitIQ:**
- Entities: `SDMeal.swift`, `SDWorkout.swift`, `SDActivitySnapshot.swift`
- Use Cases: `SaveMealUseCase.swift`, `LogWorkoutUseCase.swift`
- Repositories: `SwiftDataNutritionRepository.swift`

**Lume:**
- Entities: `SDMoodEntry.swift`, `SDWellnessTemplate.swift`
- Use Cases: `SaveMoodUseCase.swift`, `CreateWellnessTemplateUseCase.swift`
- Repositories: `SwiftDataMoodRepository.swift`

### Classes/Protocols

- **SwiftData Models:** `SDMeal` (FitIQ), `SDMoodEntry` (Lume) - MUST have SD prefix
- **Protocols:** `MealRepositoryProtocol`, `SaveMoodUseCase`
- **Implementations:** `SwiftDataMealRepository`, `SaveMoodUseCaseImpl`
- **ViewModels:** `NutritionViewModel` (FitIQ), `MoodViewModel` (Lume) - with `@Observable`

---

## 🚀 Implementation Workflow

### Adding a New Feature

1. **Determine Scope:**
   - FitIQ feature? Lume feature? Shared infrastructure?

2. **Check FitIQCore:**
   - Does FitIQCore already provide what you need?
   - Use existing FitIQCore APIs if available

3. **Domain First:**
   - Create entities (with SD prefix if @Model)
   - Create use case protocol
   - Implement use case

4. **Infrastructure:**
   - Create port protocol (if not in FitIQCore)
   - Implement repository/adapter
   - Create API client (if needed)

5. **Presentation:**
   - Create ViewModel
   - Add field bindings (if needed)

6. **Dependency Injection:**
   - Register in AppDependencies (FitIQ or Lume)
   - Wire dependencies

7. **Testing:**
   - Unit tests for use cases
   - Integration tests for repositories
   - UI tests for critical flows

---

## 🔍 Code Review Checklist

Before submitting changes:

- [ ] Correct app modified (FitIQ vs Lume vs FitIQCore)
- [ ] No code duplication between apps
- [ ] Shared code in FitIQCore (if needed by both)
- [ ] SD prefix on all @Model classes
- [ ] Hexagonal architecture followed
- [ ] No hardcoded configuration
- [ ] Backend API endpoints correct
- [ ] Authentication uses FitIQCore
- [ ] Dependencies injected properly
- [ ] Tests written and passing
- [ ] No UI changes (unless requested)
- [ ] Documentation updated

---

## 📚 Key Resources

### Workspace Documentation
- **Product Assessment:** `PRODUCT_ASSESSMENT.md`
- **Split Strategy:** `SPLIT_STRATEGY_QUICKSTART.md`
- **Architecture Diagrams:** `docs/SPLIT_ARCHITECTURE_DIAGRAM.md`

### API Documentation
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **API Spec:** `docs/be-api-spec/swagger.yaml`

### Integration Guides
- **iOS Integration:** `docs/IOS_INTEGRATION_HANDOFF.md`
- **API Integration:** `docs/api-integration/`

### Existing Code to Study

**FitIQCore:**
- (To be created in Phase 1 of split implementation)

**FitIQ:**
- `FitIQ/Domain/UseCases/Nutrition/SaveMealUseCase.swift`
- `FitIQ/Infrastructure/Repositories/SwiftDataNutritionRepository.swift`
- `FitIQ/Presentation/ViewModels/NutritionViewModel.swift`

**Lume:**
- (To be created in Phase 3 of split implementation)

---

## 💬 Communication Protocol

### When Stuck
1. Check if functionality exists in FitIQCore
2. Review similar code in the same app
3. Check the other app for patterns
4. Review architecture documentation
5. Ask specific questions with context

### When Suggesting Code
1. Specify which project (FitIQ, Lume, FitIQCore)
2. Show which layer (Domain/Infrastructure/Presentation)
3. Reference similar existing file
4. Follow exact naming conventions
5. Use SD prefix for @Model classes
6. Provide complete, working examples
7. Include where to register in AppDependencies

### When Uncertain
- Ask for clarification
- Don't make assumptions about app assignment
- Reference existing code
- Suggest checking with team

---

## 🎓 Summary

### Workspace Structure
- **FitIQCore:** Shared package (Auth, API, HealthKit, SwiftData utilities)
- **FitIQ:** Fitness & nutrition app (depends on FitIQCore)
- **Lume:** Wellness & mood app (depends on FitIQCore)

### Core Principles
1. **Hexagonal Architecture** - Domain defines interfaces, infrastructure implements
2. **SD Prefix** - All @Model classes use SD prefix
3. **Shared Infrastructure** - FitIQCore provides common code
4. **No Duplication** - Code used by both apps belongs in FitIQCore
5. **Backend Unity** - Single backend, single user account
6. **Independent Apps** - Each app has its own focus and design

### Implementation Flow
```
Determine App (FitIQ vs Lume vs FitIQCore)
    ↓
Check FitIQCore for Existing APIs
    ↓
Create Domain Entity (SD prefix if @Model)
    ↓
Create Use Case Protocol
    ↓
Implement Use Case
    ↓
Create Port Protocol (if not in FitIQCore)
    ↓
Implement Infrastructure Adapter
    ↓
Register in AppDependencies
    ↓
Create/Update ViewModel (if needed)
    ↓
Test
```

### Critical Rules
- ✅ Shared code in FitIQCore
- ✅ Always use SD prefix for @Model
- ✅ Check FitIQCore before duplicating
- ✅ Follow app-specific design language
- ❌ Never duplicate between apps
- ❌ Never break dependency direction
- ❌ Never forget SD prefix

---

**Remember: Three projects, one architecture, one backend, one user account. Keep shared code in FitIQCore, app-specific code in FitIQ or Lume!**

**Version:** 3.0.0  
**Status:** ✅ Ready for Workspace Development  
**Last Updated:** 2025-01-27  
**Latest Change:** Created unified workspace instructions for FitIQ + Lume + FitIQCore
