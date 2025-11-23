# Registration Fix and Implementation Roadmap

**Version:** 1.0.0  
**Date:** 2025-01-15  
**Status:** Registration Fixed, Core Features Ready for Implementation

---

## Overview

This document outlines the fix for the registration flow issue and provides a comprehensive roadmap for implementing the remaining Lume app features.

---

## Registration Fix Summary

### Problem Identified

After successful registration, users were not being properly transitioned to the logged-in view. Additionally, form fields were not being cleared after authentication operations, which could lead to:

1. Confusion about authentication state
2. "Account already exists" errors on subsequent registration attempts
3. Poor user experience during state transitions

### Solution Implemented

#### 1. Form Field Management

**File:** `lume/lume/Presentation/Authentication/AuthViewModel.swift`

**Changes:**
- Added `clearFormFields()` private method to reset all form state
- Clear fields after successful registration
- Clear fields after successful login
- Clear fields after logout

```swift
private func clearFormFields() {
    email = ""
    password = ""
    name = ""
    dateOfBirth = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    errorMessage = nil
}
```

#### 2. Auth Coordinator Improvements

**File:** `lume/lume/Presentation/Authentication/AuthCoordinatorView.swift`

**Changes:**
- Added `onChange` handler for `isAuthenticated` state
- Automatically reset to login view when user logs out
- Ensures clean state transitions

```swift
.onChange(of: viewModel.isAuthenticated) { _, newValue in
    if !newValue {
        showingRegistration = false
    }
}
```

### How It Works Now

**Successful Registration Flow:**
1. User fills out registration form
2. Taps "Create Account"
3. `AuthViewModel.register()` is called
4. Backend API creates user and returns token
5. Token is saved to Keychain
6. Form fields are cleared
7. `isAuthenticated` is set to `true`
8. `RootView` detects change and displays `MainTabView`
9. User sees the logged-in app immediately

**Successful Login Flow:**
1. User fills out login form
2. Taps "Sign In"
3. `AuthViewModel.login()` is called
4. Backend API returns token
5. Token is saved to Keychain
6. Form fields are cleared
7. `isAuthenticated` is set to `true`
8. `RootView` displays `MainTabView`

**Logout Flow:**
1. User taps "Sign Out" in Profile tab
2. `AuthViewModel.logout()` is called
3. Token is deleted from Keychain
4. Form fields are cleared
5. `isAuthenticated` is set to `false`
6. `RootView` displays `AuthCoordinatorView`
7. `AuthCoordinatorView` resets to login view (not registration)

---

## Domain Layer Complete

### Entities Created

All core domain entities have been implemented following Hexagonal Architecture principles:

#### 1. MoodEntry Entity
**File:** `lume/lume/Domain/Entities/MoodEntry.swift`

**Features:**
- Three mood types: high, ok, low
- Optional note field
- Note preview functionality
- Display names, emojis, and system images for each mood
- Full Codable and Equatable conformance

#### 2. JournalEntry Entity
**File:** `lume/lume/Domain/Entities/JournalEntry.swift`

**Features:**
- Rich text support
- Word and character counting
- Preview generation
- Modification tracking
- Formatted date display

#### 3. Goal Entity
**File:** `lume/lume/Domain/Entities/Goal.swift`

**Features:**
- Progress tracking (0.0 to 1.0)
- Target date support
- Status management (active, completed, paused, archived)
- Categories (general, physical, mental, emotional, social, spiritual, professional)
- Overdue detection
- Progress percentage calculation

### Domain Structure

```
Domain/
├── Entities/
│   ├── User.swift ✅
│   ├── AuthToken.swift ✅
│   ├── MoodEntry.swift ✅ NEW
│   ├── JournalEntry.swift ✅ NEW
│   └── Goal.swift ✅ NEW
├── Ports/
│   ├── AuthRepositoryProtocol.swift ✅
│   ├── AuthServiceProtocol.swift ✅
│   ├── MoodRepositoryProtocol.swift ⏳ TODO
│   ├── JournalRepositoryProtocol.swift ⏳ TODO
│   └── GoalRepositoryProtocol.swift ⏳ TODO
└── UseCases/
    ├── RegisterUserUseCase.swift ✅
    ├── LoginUserUseCase.swift ✅
    ├── LogoutUserUseCase.swift ✅
    ├── RefreshTokenUseCase.swift ✅
    ├── SaveMoodUseCase.swift ⏳ TODO
    ├── FetchMoodsUseCase.swift ⏳ TODO
    ├── SaveJournalEntryUseCase.swift ⏳ TODO
    ├── FetchJournalEntriesUseCase.swift ⏳ TODO
    ├── CreateGoalUseCase.swift ⏳ TODO
    ├── UpdateGoalUseCase.swift ⏳ TODO
    └── FetchGoalsUseCase.swift ⏳ TODO
```

---

## Implementation Roadmap

### Phase 1: Data Layer (SwiftData Models)

**Priority:** HIGH  
**Estimated Time:** 2-3 hours

#### Tasks:

1. **Create SwiftData Models**
   ```
   Data/Persistence/
   ├── SDMoodEntry.swift
   ├── SDJournalEntry.swift
   └── SDGoal.swift
   ```

2. **Update ModelContainer Configuration**
   - Add new models to schema
   - Update `AppDependencies.swift`

3. **Create Repository Implementations**
   ```
   Data/Repositories/
   ├── MoodRepository.swift
   ├── JournalRepository.swift
   └── GoalRepository.swift
   ```

4. **Implement Outbox Integration**
   - Create outbox events for each operation
   - Ensure offline support

**Architecture Rules:**
- SwiftData models only in `Data/Persistence/`
- Repositories translate between SwiftData and Domain models
- All external communication via Outbox pattern
- Follow existing `AuthRepository` as template

---

### Phase 2: Use Cases (Business Logic)

**Priority:** HIGH  
**Estimated Time:** 2-3 hours

#### Mood Use Cases

```swift
protocol SaveMoodUseCase {
    func execute(mood: MoodKind, note: String?, date: Date) async throws -> MoodEntry
}

protocol FetchMoodsUseCase {
    func execute(days: Int) async throws -> [MoodEntry]
}
```

#### Journal Use Cases

```swift
protocol SaveJournalEntryUseCase {
    func execute(text: String, date: Date) async throws -> JournalEntry
}

protocol UpdateJournalEntryUseCase {
    func execute(_ entry: JournalEntry) async throws -> JournalEntry
}

protocol FetchJournalEntriesUseCase {
    func execute(from: Date, to: Date) async throws -> [JournalEntry]
}
```

#### Goal Use Cases

```swift
protocol CreateGoalUseCase {
    func execute(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal
}

protocol UpdateGoalUseCase {
    func execute(_ goal: Goal) async throws -> Goal
}

protocol UpdateGoalProgressUseCase {
    func execute(goalId: UUID, progress: Double) async throws -> Goal
}

protocol FetchGoalsUseCase {
    func execute(status: GoalStatus?) async throws -> [Goal]
}
```

**Implementation Guidelines:**
- Validate inputs in use cases
- Keep business rules in domain layer
- Call repository methods
- Follow existing use case patterns

---

### Phase 3: ViewModels (MVVM)

**Priority:** HIGH  
**Estimated Time:** 3-4 hours

#### Create ViewModels

```
Presentation/ViewModels/
├── MoodViewModel.swift
├── JournalViewModel.swift
└── GoalViewModel.swift
```

#### MoodViewModel Features

```swift
@Observable
final class MoodViewModel {
    var selectedMood: MoodKind?
    var note: String = ""
    var moodHistory: [MoodEntry] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    func saveMood() async
    func loadRecentMoods() async
    func deleteMood(_ id: UUID) async
}
```

#### JournalViewModel Features

```swift
@Observable
final class JournalViewModel {
    var entries: [JournalEntry] = []
    var currentEntry: JournalEntry?
    var isLoading: Bool = false
    var errorMessage: String?
    
    func createEntry() async
    func updateEntry(_ entry: JournalEntry) async
    func deleteEntry(_ id: UUID) async
    func loadEntries() async
}
```

#### GoalViewModel Features

```swift
@Observable
final class GoalViewModel {
    var goals: [Goal] = []
    var selectedGoal: Goal?
    var isLoading: Bool = false
    var errorMessage: String?
    
    func createGoal() async
    func updateGoal(_ goal: Goal) async
    func updateProgress(_ goalId: UUID, progress: Double) async
    func deleteGoal(_ id: UUID) async
    func loadGoals() async
}
```

**Guidelines:**
- Use `@Observable` macro
- Depend only on use cases
- Handle loading and error states
- Follow `AuthViewModel` pattern

---

### Phase 4: User Interface (SwiftUI Views)

**Priority:** MEDIUM  
**Estimated Time:** 6-8 hours

#### Mood Feature

```
Presentation/Features/Mood/
├── MoodTrackingView.swift (main view)
├── MoodSelectorView.swift (mood picker)
├── MoodHistoryView.swift (calendar/list)
└── MoodDetailView.swift (view single entry)
```

**Design Requirements:**
- Warm, calm interface
- Large, tappable mood buttons
- Optional note field
- Visual mood history (calendar or chart)
- Smooth animations

#### Journal Feature

```
Presentation/Features/Journal/
├── JournalListView.swift (all entries)
├── JournalEditorView.swift (create/edit)
└── JournalDetailView.swift (read-only view)
```

**Design Requirements:**
- Minimal, distraction-free editor
- Word count display
- Auto-save functionality
- Search/filter capability
- Rich text support (future)

#### Goals Feature

```
Presentation/Features/Goals/
├── GoalsListView.swift (all goals)
├── GoalDetailView.swift (view/edit goal)
├── GoalCreationView.swift (create new)
├── GoalProgressView.swift (update progress)
└── GoalCategoryPickerView.swift (category selection)
```

**Design Requirements:**
- Clear progress indicators
- Category-based organization
- Target date visualization
- AI consultation integration (future)
- Completion celebration

#### Profile Feature

```
Presentation/Features/Profile/
├── ProfileView.swift ✅ (basic implementation exists)
├── SettingsView.swift (app settings)
└── AccountView.swift (user account info)
```

**Enhancement Requirements:**
- Display user information
- Settings page (notifications, themes, etc.)
- Data export capability
- Privacy settings
- Help & support

---

### Phase 5: Backend Integration

**Priority:** MEDIUM  
**Estimated Time:** 4-5 hours

#### Create Backend Services

```
Services/
├── MoodService.swift
├── JournalService.swift
└── GoalService.swift
```

#### API Endpoints (Backend)

**Mood Endpoints:**
```
POST   /api/v1/mood
GET    /api/v1/mood?from={date}&to={date}
DELETE /api/v1/mood/{id}
```

**Journal Endpoints:**
```
POST   /api/v1/journal
PUT    /api/v1/journal/{id}
GET    /api/v1/journal?from={date}&to={date}
DELETE /api/v1/journal/{id}
```

**Goals Endpoints:**
```
POST   /api/v1/goals
PUT    /api/v1/goals/{id}
GET    /api/v1/goals?status={status}
DELETE /api/v1/goals/{id}
PATCH  /api/v1/goals/{id}/progress
```

**Implementation Requirements:**
- Follow existing `RemoteAuthService` pattern
- Use Outbox pattern for all operations
- Handle offline mode gracefully
- Implement proper error handling
- Add retry logic

---

### Phase 6: AI Integration (Future)

**Priority:** LOW  
**Estimated Time:** 8-10 hours

#### AI Features

1. **Goal Consulting**
   - Analyze goal progress
   - Provide motivational suggestions
   - Context-aware advice

2. **Journal Insights**
   - Identify patterns
   - Suggest reflection topics
   - Emotional trend analysis

3. **Mood Correlation**
   - Connect mood with activities
   - Identify triggers
   - Wellness recommendations

**Technical Approach:**
- Create `AIService` for backend communication
- Design prompts with wellness context
- Implement streaming responses
- Privacy-first design

---

## Testing Strategy

### Unit Tests

**Required Coverage:**
- All use cases
- All repositories
- All view models
- Domain entity logic

### Integration Tests

**Required Coverage:**
- Authentication flow
- Mood tracking flow
- Journal creation/editing
- Goal management
- Offline mode behavior

### UI Tests

**Required Coverage:**
- Registration/login flows
- Main navigation
- Feature interactions
- Error state handling

---

## Performance Considerations

### Data Management

1. **Pagination**
   - Load journal entries in batches
   - Implement infinite scroll
   - Cache loaded data

2. **Mood History**
   - Limit initial load to 30 days
   - Load more on demand
   - Aggregate older data

3. **Goals**
   - Load active goals first
   - Lazy load archived goals
   - Optimize SwiftData queries

### UI Performance

1. **Smooth Animations**
   - Use `.animation()` modifiers appropriately
   - Implement list virtualization
   - Optimize image loading

2. **Responsiveness**
   - Show loading states immediately
   - Implement optimistic UI updates
   - Background processing for heavy operations

---

## Security & Privacy

### Data Protection

1. **Sensitive Data**
   - Journal entries encrypted at rest
   - Mood data anonymized in analytics
   - Goals data user-owned

2. **Network Security**
   - HTTPS only
   - Certificate pinning (production)
   - Token rotation

3. **User Privacy**
   - No data sharing without consent
   - Explicit data deletion
   - Export functionality

---

## Deployment Checklist

### Pre-Launch

- [ ] All core features implemented
- [ ] Unit tests passing (80%+ coverage)
- [ ] UI tests passing
- [ ] Backend integration tested
- [ ] Offline mode verified
- [ ] Performance optimized
- [ ] Security audit completed
- [ ] Accessibility compliance (WCAG AA)
- [ ] Privacy policy in place
- [ ] Terms of service finalized

### Launch

- [ ] App Store screenshots
- [ ] App Store description
- [ ] Keywords optimized
- [ ] Review submission
- [ ] Marketing materials
- [ ] Support email configured
- [ ] Analytics implemented
- [ ] Crash reporting active

### Post-Launch

- [ ] Monitor user feedback
- [ ] Track crash reports
- [ ] Analyze usage patterns
- [ ] Plan feature iterations
- [ ] Address critical bugs
- [ ] Performance monitoring

---

## Current Status Summary

### ✅ Complete

- User authentication (register, login, logout)
- Token management (Keychain storage)
- Token refresh flow
- Registration form with COPPA compliance
- Modern, branded UI for authentication
- Outbox pattern implementation
- Domain entities for all features
- Hexagonal architecture foundation
- SOLID principles compliance
- Main tab navigation structure
- Profile view with logout

### ⏳ In Progress

- Data layer (SwiftData models)
- Repository implementations
- Use case implementations

### 📋 Pending

- Feature ViewModels
- Feature UI implementation
- Backend service integration
- AI consulting features
- Comprehensive testing
- Performance optimization

---

## Quick Start for Next Developer

### 1. Build and Run
```bash
cd lume
open lume.xcodeproj
# Build and run in Xcode
```

### 2. Test Authentication
- Register a new account
- Verify redirect to MainTabView
- Test logout functionality
- Verify login with existing account

### 3. Start Feature Implementation
- Begin with Phase 1 (Data Layer)
- Follow architecture guidelines
- Reference existing auth implementation
- Maintain warm, calm UX throughout

### 4. Key Files to Review
- `lume/.github/copilot-instructions.md` (architecture rules)
- `lume/lume/Presentation/Authentication/AuthViewModel.swift` (MVVM pattern)
- `lume/lume/Data/Repositories/AuthRepository.swift` (repository pattern)
- `lume/lume/Domain/UseCases/RegisterUserUseCase.swift` (use case pattern)

---

## Support & Resources

### Architecture
- Hexagonal Architecture principles
- SOLID principles
- MVVM pattern with SwiftUI

### Design
- Color palette in `LumeColors.swift`
- Typography in `LumeTypography.swift`
- Warm, calm, non-judgmental UX

### Backend
- Base URL: `fit-iq-backend.fly.dev`
- Configuration: `config.plist`
- API docs: `swagger.yaml`

---

**Last Updated:** 2025-01-15  
**Next Review:** After Phase 1 completion  
**Document Version:** 1.0.0