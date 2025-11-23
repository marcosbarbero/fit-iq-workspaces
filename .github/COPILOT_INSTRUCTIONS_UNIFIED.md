# FitIQ Workspace - Unified AI Assistant Instructions

**Version:** 1.1.0  
**Last Updated:** 2025-01-27  
**Purpose:** Unified guidelines for AI assistants working on the FitIQ workspace (FitIQ app + Lume app + FitIQCore shared package)

---

## 📖 Related Instruction Documents

This file provides a **quick reference and decision tree** for working across multiple projects. For detailed guidelines:

### Detailed Project-Specific Instructions
- **[copilot-instructions.md](./copilot-instructions.md)** - 📱 Complete FitIQ iOS app guidelines (2,000+ lines)
  - Use when: Working on FitIQ app implementation details
  - Contains: Architecture, patterns, use cases, repositories, testing, API integration

### Multi-Project Workspace
- **[copilot-instructions-workspace.md](./copilot-instructions-workspace.md)** - 🔧 Workspace-level guidelines
  - Use when: Managing dependencies between FitIQ, Lume, and FitIQCore
  - Contains: Cross-project patterns, shared workflows

### Usage Guide
- **[COPILOT_INSTRUCTIONS_README.md](./COPILOT_INSTRUCTIONS_README.md)** - 📚 How to use these documents
  - Use when: Unsure which instruction file to consult
  - Contains: Decision tree, scenarios, update guidelines

### This Document (COPILOT_INSTRUCTIONS_UNIFIED.md)
- **Scope:** Quick reference for all projects
- **Best For:** Determining which project to modify, common rules across all projects

---

## 📋 Table of Contents

1. [Related Instruction Documents](#related-instruction-documents)
2. [Workspace Overview](#workspace-overview)
3. [Determining Which Project to Modify](#determining-which-project-to-modify)
4. [FitIQ App Rules](#fitiq-app-rules)
5. [Lume App Rules](#lume-app-rules)
6. [FitIQCore Package Rules](#fitiqcore-package-rules)
7. [Shared Architecture Principles](#shared-architecture-principles)
8. [Common Patterns](#common-patterns)
9. [Critical Rules (NEVER/ALWAYS)](#critical-rules)
10. [Additional Resources](#additional-resources)

---

## 🎯 Workspace Overview

This workspace contains **three projects** that share architecture and backend:

### Project Structure
```
FitIQ.xcworkspace/
├── FitIQ/           # Fitness & Nutrition App (iOS)
├── lume/            # Wellness & Mood App (iOS) [Phase 3]
└── FitIQCore/       # Shared Infrastructure Package [Phase 1 Complete ✅]
```

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
**Design:** Bold, energetic, performance-focused  
**Status:** ✅ Production (Phase 2 complete)

### 2. Lume App - Wellness & Mood Intelligence
**Focus:** Qualitative mental health
- Mood tracking (iOS 18 HealthKit HKStateOfMind)
- Wellness templates
- Mindfulness practices
- Stress management
- Daily habits tracking
- Recovery optimization

**Target Users:** Mindfulness seekers, wellness-focused individuals  
**Design:** Calm, soothing, mindfulness-focused  
**Status:** 🚧 Phase 3 (Planned)

### 3. FitIQCore Package - Shared Infrastructure
**Purpose:** Common code shared by both apps
- Authentication (JWT, Keychain storage)
- API client foundation
- HealthKit integration framework
- SwiftData persistence utilities
- Common UI components
- Error handling & validation

**Type:** Swift Package (SPM)  
**Status:** 🚧 Phase 1 (Planned)

---

## 🎯 Determining Which Project to Modify

**Before making changes, determine the target project:**

| Question | Answer → Target |
|----------|----------------|
| Is it fitness/nutrition related? | → **FitIQ app** |
| Is it wellness/mood related? | → **Lume app** |
| Is it shared infrastructure? | → **FitIQCore package** |
| Is it used by both apps? | → **FitIQCore package** |
| Is it authentication/profile? | → **FitIQCore package** |
| Is it API client foundation? | → **FitIQCore package** |

**Examples:**
- Add meal logging → FitIQ
- Add mood tracking → Lume
- Update JWT token refresh → FitIQCore
- Add workout templates → FitIQ
- Add mindfulness exercises → Lume
- Update HealthKit framework → FitIQCore

---

## 📱 FitIQ App Rules

### Location
`/FitIQ/`

### Scope
All fitness and nutrition features:
- Nutrition (meals, foods, calorie tracking)
- Workouts (exercises, templates, RPE)
- Body metrics (weight, BMI, body mass)
- Activity (steps, heart rate, activity snapshots)
- Sleep tracking
- Goal management
- AI Coach (fitness-focused)

### Architecture
Follow Hexagonal Architecture (Ports & Adapters):
```
Presentation/ (ViewModels/Views)
    ↓ depends on ↓
Domain/ (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure/ (Repositories, Network, Services)
```

### Critical FitIQ Rules

#### ✅ ALWAYS
- Use SD prefix for all SwiftData `@Model` classes (e.g., `SDMeal`, `SDWorkout`)
- Use Outbox Pattern for any outbound sync (progress tracking, user data)
- Examine existing code before implementing new features
- Follow existing patterns in `Domain/UseCases/`
- Register all dependencies in `AppDependencies.swift`
- Store configuration in `config.plist` (never hardcode)

#### ❌ NEVER
- Create or update UI/Views without explicit request (except field bindings)
- Hardcode configuration (API keys, URLs)
- Modify `docs/api-spec.yaml` (read-only, symlinked)
- Create infrastructure before domain (always domain-first)
- Forget SD prefix on SwiftData models
- Bypass repository for outbound sync (breaks Outbox Pattern)

### File Naming Conventions
- Entities: `SDMeal.swift`, `SDWorkout.swift` (SD prefix mandatory)
- Use Cases: `SaveMealUseCase.swift`, `LogWorkoutUseCase.swift`
- Ports: `NutritionRepositoryProtocol.swift`
- Repositories: `SwiftDataNutritionRepository.swift`
- ViewModels: `NutritionViewModel.swift` (with `@Observable`)

### Key Directories
```
FitIQ/
├── Presentation/
│   ├── ViewModels/
│   └── UI/
├── Domain/
│   ├── Entities/
│   ├── UseCases/
│   └── Ports/
├── Infrastructure/
│   ├── Repositories/
│   ├── Network/
│   └── Services/
├── DI/
│   └── AppDependencies.swift
└── docs/              # Organized documentation
```

### Documentation
All FitIQ documentation is in `FitIQ/docs/` with organized subdirectories.

---

## 🌸 Lume App Rules

### Location
`/lume/`

### Scope
All wellness and mental health features:
- Mood tracking (iOS 18 HKStateOfMind)
- Wellness templates
- Mindfulness practices
- Stress management
- Daily habits
- Recovery optimization

### Architecture
Same Hexagonal Architecture as FitIQ:
```
Presentation/ (ViewModels/Views)
    ↓ depends on ↓
Domain/ (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure/ (Repositories, Network, Services)
```

### Critical Lume Rules

#### ✅ ALWAYS
- Use SD prefix for all SwiftData `@Model` classes (e.g., `SDMoodEntry`, `SDWellnessTemplate`)
- Follow calm, mindfulness-focused design language
- Use soft colors (blues, greens, purples)
- Use smooth, flowing animations (not snappy)
- Register all dependencies in `AppDependencies.swift`

#### ❌ NEVER
- Duplicate code from FitIQ (move to FitIQCore if shared)
- Use aggressive/energetic design (that's FitIQ's style)
- Hardcode configuration
- Forget SD prefix on SwiftData models

### File Naming Conventions
- Entities: `SDMoodEntry.swift`, `SDWellnessTemplate.swift` (SD prefix mandatory)
- Use Cases: `SaveMoodUseCase.swift`, `CreateWellnessTemplateUseCase.swift`
- Ports: `MoodRepositoryProtocol.swift`
- Repositories: `SwiftDataMoodRepository.swift`
- ViewModels: `MoodViewModel.swift` (with `@Observable`)

### Key Directories
```
lume/
├── Presentation/
│   ├── ViewModels/
│   └── UI/
├── Domain/
│   ├── Entities/
│   ├── UseCases/
│   └── Ports/
├── Infrastructure/
│   ├── Repositories/
│   ├── Network/
│   └── Services/
├── DI/
│   └── AppDependencies.swift
└── docs/              # Organized documentation
```

### Documentation
All Lume documentation is in `lume/docs/` with organized subdirectories.

### Status
🚧 **Lume is in Phase 3 (planned)**. Most features are not yet implemented.

---

## 📦 FitIQCore Package Rules

### Location
`/FitIQCore/` (to be created)

### Scope
Shared infrastructure used by both FitIQ and Lume:
- Authentication (JWT, login, registration, token refresh)
- User profile management
- API client foundation (NetworkClientProtocol, DTOs)
- HealthKit integration framework
- SwiftData persistence utilities
- Common UI components (buttons, cards, form fields)
- Error handling & validation
- Logging & analytics

### Critical FitIQCore Rules

#### ✅ ALWAYS Add to FitIQCore if:
- Used by BOTH FitIQ and Lume
- Authentication/authorization logic
- Network client foundation
- HealthKit utilities
- SwiftData common patterns
- Shared UI components
- Error handling frameworks

#### ❌ NEVER Add to FitIQCore if:
- Only used by one app
- App-specific business logic
- App-specific entities (e.g., `SDMeal` in FitIQ, `SDMoodEntry` in Lume)
- App-specific views

### Dependency Direction
**CRITICAL:** Never break this dependency flow:
```
FitIQ → depends on → FitIQCore ✅
Lume → depends on → FitIQCore ✅
FitIQCore → depends on → FitIQ or Lume ❌ NEVER
```

### Module Structure
```swift
// FitIQCore/Sources/FitIQCore/Auth/AuthManager.swift
public protocol AuthManagerProtocol {
    func register(email: String, password: String) async throws -> User
    func login(email: String, password: String) async throws -> AuthTokens
}

public final class AuthManager: AuthManagerProtocol {
    // Implementation used by both apps
}
```

### File Naming Conventions
- Protocols: `AuthManagerProtocol.swift`, `NetworkClientProtocol.swift`
- Implementations: `AuthManager.swift`, `URLSessionNetworkClient.swift`
- DTOs: `UserDTO.swift`, `AuthTokensDTO.swift`

### Status
🚧 **FitIQCore is in Phase 1 (planned)**. Not yet created.

---

## 🏗️ Shared Architecture Principles

All three projects follow the same clean architecture:

### Hexagonal Architecture (Ports & Adapters)
```
Presentation Layer (ViewModels/Views)
    ↓ depends on ↓
Domain Layer (Entities, UseCases, Ports, Events)
    ↑ implemented by ↑
Infrastructure Layer (Repositories, Network, Services)
```

### Key Principles
1. **Domain is pure business logic** - No external dependencies
2. **Domain defines interfaces** - Ports via protocols
3. **Infrastructure implements interfaces** - Adapters
4. **Presentation depends on domain abstractions** - Not concrete implementations
5. **Dependency injection** - Via AppDependencies

### Implementation Order
```
1. Domain Entities (SwiftData @Model with SD prefix)
2. Domain Use Cases (protocols + implementations)
3. Domain Ports (protocols)
4. Infrastructure Adapters (concrete implementations)
5. Network Clients (if API integration needed)
6. Services (if external system integration needed)
7. ViewModels (@Observable, depends on use cases)
8. Register in AppDependencies
```

---

## 🔄 Common Patterns

### SwiftData Models (All Projects)
**CRITICAL:** All `@Model` classes MUST use `SD` prefix

```swift
// ✅ CORRECT
@Model
final class SDMeal {  // FitIQ
    var id: String
    var name: String
    var calories: Double
    var loggedAt: Date
}

@Model
final class SDMoodEntry {  // Lume
    var id: String
    var valence: Double
    var labels: [String]
    var recordedAt: Date
}

// ❌ WRONG - Missing SD prefix
@Model
final class Meal { /* ... */ }
```

### Repository Pattern (All Projects)
```swift
// 1. Domain Port (in Domain/Ports/)
protocol MealRepositoryProtocol {
    func save(_ meal: SDMeal) async throws
    func fetchAll() async throws -> [SDMeal]
}

// 2. Infrastructure Implementation (in Infrastructure/Repositories/)
final class SwiftDataMealRepository: MealRepositoryProtocol {
    private let modelContext: ModelContext
    
    func save(_ meal: SDMeal) async throws {
        modelContext.insert(meal)
        try modelContext.save()
    }
}
```

### Use Case Pattern (All Projects)
```swift
// Protocol
protocol SaveMealUseCase {
    func execute(name: String, calories: Double) async throws -> SDMeal
}

// Implementation
final class SaveMealUseCaseImpl: SaveMealUseCase {
    private let repository: MealRepositoryProtocol
    
    func execute(name: String, calories: Double) async throws -> SDMeal {
        // Validation
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
        
        // Create entity
        let meal = SDMeal(id: UUID().uuidString, name: name, calories: calories)
        
        // Persist
        try await repository.save(meal)
        
        return meal
    }
}
```

### Outbox Pattern (FitIQ & Lume)
**For reliable sync of progress tracking and user-generated data:**

```swift
// Use Case creates entry with .pending status
let progressEntry = ProgressEntry(
    id: UUID(),
    userID: userID,
    type: .weight,
    quantity: weightKg,
    syncStatus: .pending  // ✅ CRITICAL
)

// Repository automatically creates Outbox event
try await progressRepository.save(progressEntry: progressEntry, forUserID: userID)

// OutboxProcessorService syncs in background
// Automatic retry on failure, no data loss
```

---

## 🚨 Critical Rules

### ❌ NEVER Do These Things (ALL Projects)

1. **❌ NEVER create or update UI/Views without explicit request**
   - Focus on Domain, UseCases, Repositories, Network, Services
   - **EXCEPTION:** Binding fields from view to save/persist is ALLOWED
   - ViewModels are OK to create/modify

2. **❌ NEVER hardcode configuration**
   - API key MUST be in `config.plist`
   - Base URLs MUST be in `config.plist`
   - No hardcoded secrets in code

3. **❌ NEVER create infrastructure before domain**
   - Always start with domain entities and use cases
   - Then create ports (protocols)
   - Then create infrastructure implementations

4. **❌ NEVER forget the SD prefix for SwiftData models**
   - All `@Model` classes MUST use prefix `SD`
   - This is MANDATORY for schema clarity

5. **❌ NEVER duplicate code between apps**
   - If code is used by both apps, it belongs in FitIQCore
   - Only app-specific logic should be in FitIQ or Lume

6. **❌ NEVER break the dependency direction**
   - FitIQ depends on FitIQCore ✅
   - Lume depends on FitIQCore ✅
   - FitIQCore depends on FitIQ or Lume ❌ NEVER

7. **❌ NEVER place markdown files directly in project root folders**
   - All markdown files MUST be in `./docs` directories
   - Organize by domain/feature in subdirectories
   - Exception: README.md in project root is REQUIRED

### ✅ ALWAYS Do These Things (ALL Projects)

1. **✅ ALWAYS examine existing code first**
   - Review existing entities, use cases, repositories
   - Check `Domain/UseCases/` for similar patterns
   - Look at existing ports in `Domain/Ports/`
   - Review infrastructure adapters in `Infrastructure/`

2. **✅ ALWAYS use SD prefix for @Model classes**
   - `SDMeal` (FitIQ), `SDMoodEntry` (Lume)
   - This is non-negotiable

3. **✅ ALWAYS use Outbox Pattern for outbound sync**
   - Progress tracking (steps, heart rate, weight, mood)
   - Profile updates that need backend persistence
   - User-generated data that needs backend sync

4. **✅ ALWAYS check FitIQCore first**
   - Before implementing shared functionality
   - Use existing FitIQCore APIs if available

5. **✅ ALWAYS register dependencies in AppDependencies**
   - Don't forget dependency injection

6. **✅ ALWAYS store configuration in config.plist**
   - Never hardcode API keys, URLs, secrets

7. **✅ ALWAYS place documentation in organized subdirectories**
   - Use `/docs` with subdirectories by domain/feature
   - No loose markdown files in project roots or docs/ root
   - Workspace-level docs: `/docs/` (e.g., `/docs/split-strategy/`)
   - FitIQ docs: `/FitIQ/docs/` (e.g., `/FitIQ/docs/architecture/`)
   - Lume docs: `/lume/docs/` (e.g., `/lume/docs/features/`)

---

## 🔗 Backend Integration

### Shared Backend
**Base URL:** `https://fit-iq-backend.fly.dev/api/v1`  
**Authentication:** JWT tokens (via FitIQCore)  
**User Account:** Single account across both apps

Both FitIQ and Lume use the SAME backend API. Login in one app = logged in both apps.

### API Distribution
- **FitIQ Endpoints:** ~100 (nutrition, workouts, activity, sleep, goals)
- **Lume Endpoints:** ~25 (mood, wellness templates, habits)
- **Shared (FitIQCore):** ~8 (auth, user profile)

---

## 📚 Key Resources

### Documentation
- **Workspace Docs:** `docs/` (overall architecture, split strategy)
- **Split Strategy:** `docs/split-strategy/SPLIT_STRATEGY_QUICKSTART.md`
- **Product Assessment:** `FitIQ/docs/product-assessment/PRODUCT_ASSESSMENT.md`
- **FitIQ Docs:** `FitIQ/docs/` (FitIQ-specific documentation)
- **Lume Docs:** `lume/docs/` (Lume-specific documentation)

### API Documentation
- **Swagger UI:** https://fit-iq-backend.fly.dev/swagger/index.html
- **API Spec:** `FitIQ/docs/be-api-spec/swagger.yaml`

### Architecture
- **Architecture Diagram:** `FitIQ/docs/architecture/SPLIT_ARCHITECTURE_DIAGRAM.md`
- **FitIQ Patterns:** `FitIQ/docs/architecture/`
- **Integration Guides:** `FitIQ/docs/api-integration/`

---

## 🎓 Summary

### Three Projects, One Architecture
- **FitIQ:** Fitness & nutrition (production)
- **Lume:** Wellness & mood (planned)
- **FitIQCore:** Shared infrastructure (planned)

### Core Principles
1. **Hexagonal Architecture** - Clean separation of concerns
2. **SD Prefix** - All @Model classes use SD prefix
3. **Shared Infrastructure** - FitIQCore provides common code
4. **No Duplication** - Code used by both apps belongs in FitIQCore
5. **Backend Unity** - Single backend, single user account
6. **Independent Apps** - Each app has its own focus and design

### Critical Rules
- ✅ Shared code in FitIQCore
- ✅ Always use SD prefix for @Model
- ✅ Check FitIQCore before duplicating
- ✅ Follow app-specific design language
- ❌ Never duplicate between apps
- ❌ Never break dependency direction
- ❌ Never forget SD prefix
**Remember: Choose the right project, follow architecture, use SD prefix, never hardcode config, and always examine existing code first!**

---

## 📚 Additional Resources

### Instruction Documents
- [copilot-instructions.md](./copilot-instructions.md) - Detailed FitIQ app guidelines
- [copilot-instructions-workspace.md](./copilot-instructions-workspace.md) - Multi-project workspace
- [COPILOT_INSTRUCTIONS_README.md](./COPILOT_INSTRUCTIONS_README.md) - Usage guide

### FitIQCore Documentation
- [FitIQCore README](../FitIQCore/README.md) - Package documentation
- [Phase 1 Complete](../docs/split-strategy/FITIQCORE_PHASE1_COMPLETE.md) - Implementation summary
- [Integration Guide](../docs/split-strategy/FITIQ_INTEGRATION_GUIDE.md) - How to integrate
- [Implementation Status](../docs/split-strategy/IMPLEMENTATION_STATUS.md) - Overall progress

### Split Strategy
- [Shared Library Assessment](../docs/split-strategy/SHARED_LIBRARY_ASSESSMENT.md) - Analysis and roadmap
- [Split Strategy Cleanup](../docs/split-strategy/SPLIT_STRATEGY_CLEANUP_COMPLETE.md) - Planning phase

---

**Version:** 1.1.0  
**Status:** ✅ Active  
**Last Updated:** 2025-01-27  
**Latest Change:** Added cross-references to detailed instruction documents and updated FitIQCore status
**Purpose:** Unified instructions for FitIQ workspace development
