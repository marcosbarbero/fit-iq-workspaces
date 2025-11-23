# FitIQCore Shared Library Assessment

**Date:** 2025-11-22  
**Version:** 1.0  
**Purpose:** Identify common code for FitIQCore shared package

---

## 📋 Executive Summary

Based on analysis of the FitIQ project structure, we've identified **~60-80 Swift files** (~15,000 lines) as candidates for the FitIQCore shared package. This represents approximately **20-25% of the FitIQ codebase** that could be shared with the future Lume app.

### Key Findings

| Category | Files | Shared Potential | Priority |
|----------|-------|------------------|----------|
| **Authentication** | 8 | ✅ 100% Shared | 🔴 Critical |
| **Network Foundation** | 24 | ✅ 90% Shared | 🔴 Critical |
| **HealthKit Framework** | 24 | ✅ 80% Shared | 🟡 High |
| **Profile Management** | 23 | ✅ 70% Shared | 🟡 High |
| **SwiftData Utilities** | ~15 | ✅ 60% Shared | 🟢 Medium |
| **Common UI Components** | ~10 | ✅ 50% Shared | 🟢 Medium |
| **Error Handling** | ~8 | ✅ 100% Shared | 🟡 High |

---

## 🎯 Shared Library Structure

### Proposed FitIQCore Package Structure

```
FitIQCore/
├── Package.swift
├── Sources/
│   └── FitIQCore/
│       ├── Auth/                      # Authentication & Authorization
│       │   ├── Domain/
│       │   │   ├── AuthManager.swift
│       │   │   ├── AuthManagerProtocol.swift
│       │   │   └── AuthTokens.swift
│       │   └── Infrastructure/
│       │       ├── KeychainTokenStorage.swift
│       │       └── JWTTokenRefreshService.swift
│       │
│       ├── Profile/                   # User Profile Management
│       │   ├── Domain/
│       │   │   ├── UserProfile.swift
│       │   │   ├── ProfileManagerProtocol.swift
│       │   │   └── PhysicalAttributes.swift
│       │   └── Infrastructure/
│       │       └── SwiftDataProfileAdapter.swift
│       │
│       ├── Network/                   # API Client Foundation
│       │   ├── NetworkClientProtocol.swift
│       │   ├── URLSessionNetworkClient.swift
│       │   ├── NetworkRequest.swift
│       │   ├── NetworkError.swift
│       │   └── DTOs/
│       │       ├── UserDTO.swift
│       │       ├── AuthDTO.swift
│       │       └── ResponseWrapper.swift
│       │
│       ├── HealthKit/                 # HealthKit Integration
│       │   ├── HealthKitManagerProtocol.swift
│       │   ├── HealthKitManager.swift
│       │   ├── HealthKitAuthorization.swift
│       │   ├── HealthKitQueryBuilder.swift
│       │   └── HealthKitDataTypes.swift
│       │
│       ├── Persistence/               # SwiftData Utilities
│       │   ├── SwiftDataHelpers.swift
│       │   ├── RepositoryBase.swift
│       │   ├── FetchDescriptorBuilder.swift
│       │   └── SyncStatusEnum.swift
│       │
│       ├── Common/                    # Common Utilities
│       │   ├── Errors/
│       │   │   ├── AppError.swift
│       │   │   ├── ValidationError.swift
│       │   │   └── NetworkError.swift
│       │   ├── Extensions/
│       │   │   ├── Date+Extensions.swift
│       │   │   ├── String+Extensions.swift
│       │   │   └── Double+Extensions.swift
│       │   └── Utilities/
│       │       ├── Logger.swift
│       │       ├── DateFormatter.swift
│       │       └── ConfigManager.swift
│       │
│       └── UI/                        # Shared UI Components
│           ├── Components/
│           │   ├── LoadingButton.swift
│           │   ├── ErrorView.swift
│           │   └── FormField.swift
│           └── Modifiers/
│               ├── LoadingModifier.swift
│               └── ErrorModifier.swift
│
└── Tests/
    └── FitIQCoreTests/
        ├── Auth/
        ├── Network/
        └── HealthKit/
```

---

## 🔍 Detailed Analysis

### 1. Authentication (CRITICAL - 100% Shared)

**Current Location:** `FitIQ/Infrastructure/Services/` and `FitIQ/Domain/Ports/`

**Files to Extract (~8 files):**
```
✅ AuthManager.swift
✅ AuthManagerProtocol.swift
✅ KeychainAuthTokenAdapter.swift
✅ AuthTokenPersistencePortProtocol.swift
✅ UserAuthAPIClient.swift
✅ CreateUserUseCase.swift
✅ AuthenticateUserUseCase.swift
✅ Domain models (User, AuthTokens)
```

**Why Shared:**
- Both FitIQ and Lume use the same authentication flow
- Single user account across both apps
- JWT tokens stored in Keychain (shared)
- Token refresh logic is identical

**Effort:** 2-3 person-days

---

### 2. Network Foundation (CRITICAL - 90% Shared)

**Current Location:** `FitIQ/Infrastructure/Network/`

**Files to Extract (~24 files):**
```
✅ URLSessionNetworkClient.swift
✅ NetworkClientProtocol.swift
✅ NetworkRequest.swift
✅ NetworkError.swift
✅ DTOs/ (shared response models)
   - UserDTO.swift
   - AuthDTO.swift
   - ResponseWrapper.swift
   - ErrorResponseDTO.swift
   - PhysicalAttributesDTO.swift
```

**App-Specific Network Clients (Keep in apps):**
```
❌ MealParsingAPIClient.swift (FitIQ only)
❌ WorkoutAPIClient.swift (FitIQ only)
❌ MoodAPIClient.swift (Lume only)
```

**Why Shared:**
- Both apps use the same backend API
- Common request/response handling
- Shared error handling
- Same authentication headers

**Effort:** 3-4 person-days

---

### 3. HealthKit Framework (HIGH - 80% Shared)

**Current Location:** `FitIQ/Infrastructure/Services/` and `FitIQ/Domain/Ports/`

**Files to Extract (~24 files):**
```
✅ HealthKitAdapter.swift (base framework)
✅ HealthKitManagerProtocol.swift
✅ HealthKitAuthorizationUseCase.swift
✅ UserHasHealthKitAuthorizationUseCase.swift
✅ HealthKitQueryBuilder.swift
✅ HealthKitDataTypes.swift
✅ HKQuantityType extensions
✅ HKSample extensions
```

**App-Specific HealthKit Logic (Keep in apps):**
```
❌ NutritionHealthKitSync.swift (FitIQ only)
❌ WorkoutHealthKitSync.swift (FitIQ only)
❌ MoodHealthKitSync.swift (Lume only - iOS 18 HKStateOfMind)
```

**Why Shared:**
- Both apps need HealthKit authorization
- Common query patterns
- Shared data types (steps, heart rate, sleep)
- Base framework is identical

**Effort:** 4-5 person-days

---

### 4. Profile Management (HIGH - 70% Shared)

**Current Location:** `FitIQ/Domain/Entities/`, `FitIQ/Infrastructure/Repositories/`

**Files to Extract (~23 files):**
```
✅ UserProfile entity (core fields)
✅ SwiftDataUserProfileAdapter.swift
✅ UserProfileStoragePortProtocol.swift
✅ PhysicalAttributes.swift
✅ ProfileManagerProtocol.swift
✅ UpdateProfileUseCase.swift
✅ GetUserProfileUseCase.swift
```

**App-Specific Profile Extensions (Keep in apps):**
```
❌ NutritionGoals.swift (FitIQ only)
❌ WorkoutPreferences.swift (FitIQ only)
❌ MindfulnessPreferences.swift (Lume only)
```

**Why Shared:**
- Single user profile across both apps
- Common fields (name, email, physical attributes)
- Same profile update API
- Shared profile storage

**Effort:** 3-4 person-days

---

### 5. SwiftData Utilities (MEDIUM - 60% Shared)

**Current Location:** `FitIQ/Infrastructure/Persistence/`

**Files to Extract (~15 files):**
```
✅ PersistenceHelper.swift
✅ ModelContextExtensions.swift
✅ FetchDescriptorBuilder.swift
✅ SyncStatus enum
✅ RepositoryBase protocol
✅ SwiftDataError.swift
```

**App-Specific Persistence (Keep in apps):**
```
❌ SDMeal, SDWorkout (FitIQ entities)
❌ SDMoodEntry (Lume entities)
❌ SwiftDataNutritionRepository (FitIQ)
❌ SwiftDataMoodRepository (Lume)
```

**Why Shared:**
- Common SwiftData patterns
- Shared utilities (fetch, save, delete)
- Common sync status tracking
- Reduces boilerplate in apps

**Effort:** 2-3 person-days

---

### 6. Common UI Components (MEDIUM - 50% Shared)

**Current Location:** `FitIQ/Presentation/UI/Components/`

**Files to Extract (~10 files):**
```
✅ LoadingButton.swift
✅ ErrorView.swift
✅ FormField.swift
✅ Card.swift
✅ LoadingModifier.swift
✅ ErrorModifier.swift
```

**App-Specific UI (Keep in apps):**
```
❌ NutritionCard.swift (FitIQ only)
❌ WorkoutCard.swift (FitIQ only)
❌ MoodCard.swift (Lume only)
❌ App-specific navigation
```

**Why Shared:**
- Common UI patterns (loading, errors, forms)
- Consistency across apps
- Reduces duplication
- Neutral design (adaptable to each app's style)

**Effort:** 2-3 person-days

---

### 7. Error Handling (HIGH - 100% Shared)

**Current Location:** Various locations

**Files to Extract (~8 files):**
```
✅ AppError.swift
✅ ValidationError.swift
✅ NetworkError.swift
✅ HealthKitError.swift
✅ AuthError.swift
✅ ErrorHandlingProtocol.swift
```

**Why Shared:**
- Consistent error handling across apps
- Common error types
- Shared error presentation
- Unified logging

**Effort:** 1-2 person-days

---

## 📊 Migration Priority

### Phase 1: Critical Infrastructure (2-3 weeks)
**Must-haves for basic functionality**

1. ✅ **Authentication** (8 files, 2-3 days)
   - AuthManager
   - Keychain storage
   - JWT token refresh

2. ✅ **Network Foundation** (24 files, 3-4 days)
   - URLSessionNetworkClient
   - NetworkRequest/Response
   - Common DTOs

3. ✅ **Error Handling** (8 files, 1-2 days)
   - Common error types
   - Error presentation

**Deliverable:** FitIQCore v0.1 (basic auth + network)

---

### Phase 2: Health & Profile (2-3 weeks)
**Shared health and profile features**

4. ✅ **HealthKit Framework** (24 files, 4-5 days)
   - HealthKitAdapter
   - Authorization
   - Query builders

5. ✅ **Profile Management** (23 files, 3-4 days)
   - UserProfile entity
   - Profile storage
   - Profile API

**Deliverable:** FitIQCore v0.2 (+ HealthKit + Profile)

---

### Phase 3: Utilities & UI (1-2 weeks)
**Nice-to-have shared utilities**

6. ✅ **SwiftData Utilities** (15 files, 2-3 days)
   - Common patterns
   - Fetch descriptors
   - Sync status

7. ✅ **Common UI Components** (10 files, 2-3 days)
   - Loading buttons
   - Error views
   - Form fields

**Deliverable:** FitIQCore v1.0 (complete)

---

## 🛠️ Implementation Steps

### Step 1: Create FitIQCore Package
```bash
cd /path/to/fit-iq
mkdir FitIQCore
cd FitIQCore
swift package init --type library --name FitIQCore
```

### Step 2: Extract Authentication (Phase 1)
1. Copy auth-related files to `FitIQCore/Sources/FitIQCore/Auth/`
2. Update imports and access modifiers (public)
3. Create tests in `FitIQCore/Tests/FitIQCoreTests/Auth/`
4. Update `Package.swift` dependencies

### Step 3: Extract Network Foundation (Phase 1)
1. Copy network files to `FitIQCore/Sources/FitIQCore/Network/`
2. Extract shared DTOs
3. Create tests
4. Update dependencies

### Step 4: Integrate into FitIQ
1. Add FitIQCore as dependency in FitIQ
2. Update FitIQ imports
3. Remove duplicated code from FitIQ
4. Update AppDependencies to use FitIQCore

### Step 5: Test FitIQ with FitIQCore
1. Run FitIQ test suite
2. Manual QA
3. Verify no regressions

### Step 6: Repeat for Phases 2 & 3

---

## 📈 Benefits of Shared Library

### Code Reuse
- **~15,000 lines** shared between apps
- **60-80 files** don't need duplication
- **Single source of truth** for auth, network, HealthKit

### Maintainability
- **Fix once, benefit twice** - bugs fixed in one place
- **Consistent patterns** across both apps
- **Easier onboarding** for new developers

### Development Speed
- **Faster Lume development** - reuse infrastructure
- **Parallel development** - teams work independently
- **Reduced QA burden** - shared code tested once

### Architecture
- **Clear boundaries** - app-specific vs shared
- **Enforced separation** - can't accidentally mix code
- **Better dependency management** - explicit dependencies

---

## ⚠️ Risks & Mitigations

### Risk 1: Breaking Changes in FitIQ
**Mitigation:** 
- Comprehensive test coverage in FitIQCore
- Gradual migration (phase by phase)
- Maintain backward compatibility

### Risk 2: Over-generalization
**Mitigation:**
- Keep app-specific code in apps
- Only extract truly shared code
- Accept ~5% duplication for independence

### Risk 3: Dependency Hell
**Mitigation:**
- Use semantic versioning
- Pin FitIQCore versions in apps
- Clear upgrade path documentation

### Risk 4: Development Velocity
**Mitigation:**
- Phases allow incremental adoption
- FitIQ continues working during migration
- No big-bang refactoring

---

## 📝 Recommendations

### ✅ DO Extract to FitIQCore:
- Authentication & authorization
- Network client foundation
- HealthKit base framework
- User profile management
- Common error handling
- SwiftData utilities
- Neutral UI components

### ❌ DON'T Extract to FitIQCore:
- App-specific entities (SDMeal, SDMoodEntry)
- App-specific use cases
- App-specific repositories
- App-specific views
- Navigation logic
- App-specific API clients

### 🎯 Golden Rule:
**If it's used by BOTH apps and has no app-specific logic, extract it to FitIQCore.**

---

## 📊 Estimated Effort

| Phase | Duration | Files | Lines | Team |
|-------|----------|-------|-------|------|
| Phase 1: Critical | 2-3 weeks | ~40 | ~8,000 | 2 devs |
| Phase 2: Health & Profile | 2-3 weeks | ~47 | ~10,000 | 2 devs |
| Phase 3: Utilities & UI | 1-2 weeks | ~25 | ~5,000 | 1-2 devs |
| **Total** | **5-8 weeks** | **~112** | **~23,000** | **2-3 devs** |

**Note:** Includes extraction, testing, integration, and documentation.

---

## 🎓 Success Metrics

### Phase 1 Success:
- ✅ FitIQCore package compiles independently
- ✅ FitIQ uses FitIQCore for auth & network
- ✅ All FitIQ tests passing
- ✅ No regressions in FitIQ functionality

### Phase 2 Success:
- ✅ HealthKit authorization via FitIQCore
- ✅ Profile management via FitIQCore
- ✅ FitIQ maintains all features

### Phase 3 Success:
- ✅ FitIQCore v1.0 released
- ✅ Complete test coverage
- ✅ Documentation complete
- ✅ Ready for Lume integration

### Long-term Success:
- ✅ Lume development starts faster (reuses infrastructure)
- ✅ Bugs fixed in one place benefit both apps
- ✅ Code duplication < 5%
- ✅ Clear architecture boundaries

---

## 📚 Next Steps

1. **Review this assessment** with the team
2. **Get stakeholder buy-in** for the shared library approach
3. **Start Phase 1** (Auth + Network extraction)
4. **Create FitIQCore repository** (or package in monorepo)
5. **Set up CI/CD** for FitIQCore package
6. **Begin migration** following the phased approach

---

**Document Version:** 1.0  
**Status:** ✅ Ready for Review  
**Next Review:** After team discussion
