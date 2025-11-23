# Phase 5: AI Features Presentation Layer Implementation

**Status:** 🚧 In Progress (Part 1: AI Insights ✅ Complete)  
**Started:** 2025-01-28  
**Priority:** High  
**Dependencies:** Phase 4 (Backend & Use Cases) ✅ Complete

---

## Overview

Phase 5 focuses on building the presentation layer for AI-powered features: **Insights**, **Goals**, and **Chat**. This includes creating ViewModels, SwiftUI Views, navigation flows, and ensuring a warm, calm user experience consistent with Lume's design principles.

---

## Goals

1. **Build AI Insights Feature**
   - Display personalized wellness insights
   - Support filtering (unread, favorites, archived)
   - Enable read/favorite/archive actions
   - Show contextual data and suggestions

2. **Build Goals Feature**
   - Create and manage wellness goals
   - Display AI-powered suggestions and tips
   - Track progress with visual indicators
   - Support AI consultation for goal achievement

3. **Build AI Chat Feature**
   - Provide conversational AI support
   - Context-aware responses based on user data
   - Natural conversation flow
   - Typing indicators and smooth UX

4. **Ensure Design Consistency**
   - Follow Lume's warm, calm design principles
   - Use approved color palette and typography
   - Implement generous spacing and soft corners
   - Add smooth animations and transitions

---

## Architecture Principles

### MVVM Pattern
- **ViewModels:** Manage state, business logic coordination, loading states
- **Views:** Pure presentation, declarative SwiftUI
- **Models:** Domain entities (read-only in views)

### Dependency Injection
- ViewModels receive dependencies via `AppDependencies`
- Use cases injected into ViewModels
- No direct repository access from ViewModels

### State Management
- `@Observable` for ViewModels (iOS 17+)
- `@State` and `@Binding` for view-local state
- Async/await for all use case calls
- Proper error handling and loading states

---

## Implementation Plan

### Part 1: AI Insights Feature ✅ COMPLETE

#### 1.1 ViewModel - `AIInsightsViewModel` ✅

**Location:** `lume/Presentation/ViewModels/AIInsightsViewModel.swift` ✅ IMPLEMENTED

**Responsibilities:**
- Fetch and filter insights
- Generate new insights
- Manage insight actions (read, favorite, archive)
- Track loading and error states
- Handle real-time updates

**Properties:**
```swift
@Observable
class AIInsightsViewModel {
    // State
    var insights: [AIInsight] = []
    var filteredInsights: [AIInsight] = []
    var unreadCount: Int = 0
    var isLoading: Bool = false
    var isGenerating: Bool = false
    var errorMessage: String?
    
    // Filters
    var filterType: InsightType?
    var showUnreadOnly: Bool = false
    var showFavoritesOnly: Bool = false
    var showArchived: Bool = false
    
    // Dependencies (use cases)
    private let fetchInsightsUseCase: FetchAIInsightsUseCaseProtocol
    private let generateInsightUseCase: GenerateInsightUseCaseProtocol
    private let markAsReadUseCase: MarkInsightAsReadUseCaseProtocol
    private let toggleFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol
    private let archiveUseCase: ArchiveInsightUseCaseProtocol
    private let unarchiveUseCase: UnarchiveInsightUseCaseProtocol
    private let deleteUseCase: DeleteInsightUseCaseProtocol
}
```

**Methods:**
- `loadInsights()` - Fetch with current filters
- `generateNewInsights()` - Request AI generation
- `markAsRead(id:)` - Mark insight read
- `toggleFavorite(id:)` - Toggle favorite status
- `archive(id:)` - Archive insight
- `unarchive(id:)` - Unarchive insight
- `delete(id:)` - Delete insight
- `applyFilters()` - Filter insights based on criteria

#### 1.2 Views - AI Insights ✅

**Main View:** `AIInsightsListView` ✅ IMPLEMENTED
- Grid/list of insight cards
- Filter chips (type, unread, favorites)
- Pull-to-refresh
- Generate insights button
- Empty state

**Detail View:** `AIInsightDetailView` ✅ IMPLEMENTED
- Full insight content
- Contextual data display
- Suggestions list
- Action buttons (favorite, archive, share)
- Related insights

**Sheets:**
- `InsightFiltersSheet` ✅ IMPLEMENTED
- `GenerateInsightsSheet` ✅ IMPLEMENTED

**Components:**
- `InsightCard` ✅ IMPLEMENTED - Compact insight preview
- `FilterChip` ✅ IMPLEMENTED - Filter selection
- `InsightTypeFilterRow` ✅ IMPLEMENTED - Type selection in filters
- `FilterToggleRow` ✅ IMPLEMENTED - Status toggles
- `InsightTypeSelectionRow` ✅ IMPLEMENTED - Type selection for generation
- `ContextRow` ✅ IMPLEMENTED - Context data display
- `SuggestionCard` ✅ IMPLEMENTED - Suggestion display
- `ShareSheet` ✅ IMPLEMENTED - iOS share functionality

**Navigation:**
```
TabView (Insights Tab)
  → AIInsightsListView
    → AIInsightDetailView
    → InsightFiltersSheet
    → GenerateInsightsSheet
```

---

### Part 2: Goals Feature

#### 2.1 ViewModel - `GoalsViewModel`

**Location:** `lume/Presentation/ViewModels/GoalsViewModel.swift`

**Responsibilities:**
- Fetch and filter goals
- Create/update/delete goals
- Track progress
- Request AI suggestions and tips
- Manage goal states

**Properties:**
```swift
@Observable
class GoalsViewModel {
    // State
    var goals: [Goal] = []
    var filteredGoals: [Goal] = []
    var suggestions: [GoalSuggestion] = []
    var tips: [GoalTip] = []
    var isLoading: Bool = false
    var isLoadingSuggestions: Bool = false
    var errorMessage: String?
    
    // Filters
    var filterStatus: GoalStatus?
    var filterCategory: GoalCategory?
    
    // Selection
    var selectedGoal: Goal?
    
    // Dependencies (use cases)
    private let fetchGoalsUseCase: FetchGoalsUseCaseProtocol
    private let createGoalUseCase: CreateGoalUseCaseProtocol
    private let updateGoalUseCase: UpdateGoalUseCaseProtocol
    private let deleteGoalUseCase: DeleteGoalUseCaseProtocol
    private let generateSuggestionsUseCase: GenerateGoalSuggestionsUseCaseProtocol
    private let getTipsUseCase: GetGoalTipsUseCaseProtocol
}
```

**Methods:**
- `loadGoals()` - Fetch goals with filters
- `createGoal(title:description:category:targetDate:)` - Create new goal
- `updateGoal(id:...)` - Update goal details
- `updateProgress(id:progress:)` - Update progress
- `deleteGoal(id:)` - Delete goal
- `loadSuggestions()` - Get AI suggestions
- `loadTips(for:)` - Get AI tips for goal
- `applyFilters()` - Apply filter criteria

#### 2.2 Views - Goals

**Main View:** `GoalsListView`
- Active goals section
- Completed goals section
- Progress indicators
- Add goal button
- AI suggestions button
- Empty state

**Detail View:** `GoalDetailView`
- Goal information
- Progress chart/ring
- AI tips section
- Update progress button
- Edit/delete actions
- Related insights

**Creation View:** `CreateGoalView` / `EditGoalView`
- Title and description fields
- Category picker
- Target date picker
- AI suggestions integration
- Validation feedback

**Components:**
- `GoalCard` - Compact goal display with progress
- `GoalProgressRing` - Circular progress indicator
- `GoalCategoryBadge` - Category display
- `GoalTipCard` - AI tip display
- `GoalSuggestionCard` - AI suggestion display

**Navigation:**
```
TabView (Goals Tab)
  → GoalsListView
    → GoalDetailView
      → EditGoalView
    → CreateGoalView
      → GoalSuggestionsSheet
    → GoalFiltersSheet
```

---

### Part 3: AI Chat Feature

#### 3.1 ViewModel - `AIChatViewModel`

**Location:** `lume/Presentation/ViewModels/AIChatViewModel.swift`

**Responsibilities:**
- Fetch conversation history
- Send messages and receive responses
- Stream AI responses (if supported)
- Manage chat state
- Handle typing indicators

**Properties:**
```swift
@Observable
class AIChatViewModel {
    // State
    var messages: [ChatMessage] = []
    var currentInput: String = ""
    var isLoading: Bool = false
    var isSending: Bool = false
    var isTyping: Bool = false
    var errorMessage: String?
    
    // Conversation
    var conversationId: UUID?
    
    // Dependencies (use cases)
    private let fetchConversationUseCase: FetchAIConversationUseCaseProtocol
    private let sendMessageUseCase: SendChatMessageUseCaseProtocol
    private let deleteConversationUseCase: DeleteConversationUseCaseProtocol
}
```

**Methods:**
- `loadConversation()` - Fetch or create conversation
- `sendMessage()` - Send user message and get AI response
- `deleteConversation()` - Clear conversation history
- `retryMessage(id:)` - Retry failed message
- `scrollToBottom()` - Auto-scroll helper

#### 3.2 Views - AI Chat

**Main View:** `AIChatView`
- Message list (scrollable)
- Input field with send button
- Typing indicator
- Context-aware suggestions
- Clear conversation option

**Components:**
- `ChatMessageBubble` - Individual message display
- `ChatInputBar` - Input field with actions
- `TypingIndicator` - Animated typing dots
- `ChatSuggestionChip` - Quick action suggestions

**Navigation:**
```
TabView (Chat Tab)
  → AIChatView
    → ChatSettingsSheet (optional)
```

---

### Part 4: Integration & Polish

#### 4.1 AppDependencies Updates

Add factory methods for new ViewModels:

```swift
extension AppDependencies {
    func makeAIInsightsViewModel() -> AIInsightsViewModel {
        AIInsightsViewModel(
            fetchInsightsUseCase: fetchAIInsightsUseCase,
            generateInsightUseCase: generateInsightUseCase,
            markAsReadUseCase: markInsightAsReadUseCase,
            toggleFavoriteUseCase: toggleInsightFavoriteUseCase,
            archiveUseCase: archiveInsightUseCase,
            unarchiveUseCase: unarchiveInsightUseCase,
            deleteUseCase: deleteInsightUseCase
        )
    }
    
    func makeGoalsViewModel() -> GoalsViewModel { ... }
    func makeAIChatViewModel() -> AIChatViewModel { ... }
}
```

#### 4.2 MainTabView Updates

Add new tabs:
- Insights tab with SF Symbol: `lightbulb.fill`
- Goals tab with SF Symbol: `target`
- Chat tab with SF Symbol: `bubble.left.and.bubble.right.fill`

#### 4.3 Design System Components

Create reusable components in `lume/Presentation/DesignSystem/`:
- `LoadingView` - Consistent loading indicator
- `ErrorView` - Error display with retry
- `EmptyStateView` - Empty state with illustration
- `ActionButton` - Primary/secondary button styles
- `CardView` - Consistent card container
- `ChipView` - Filter/tag chips

#### 4.4 Animations & Transitions

- Smooth list animations on insert/delete
- Fade transitions between views
- Pull-to-refresh with custom animation
- Typing indicator animation
- Progress ring animation
- Skeleton loaders for content

---

## Design Guidelines

### Color Usage

**Insights:**
- Weekly/Monthly: `accentPrimary` (#F2C9A7)
- Goal Progress: `moodPositive` (#F5DFA8)
- Mood Pattern: `accentSecondary` (#D8C8EA)
- Achievement: `moodPositive` (#F5DFA8)

**Goals:**
- Active: `accentPrimary`
- Completed: `moodPositive`
- Paused: `textSecondary`
- Failed: `moodLow`

**Chat:**
- User messages: `accentPrimary` background
- AI messages: `surface` background
- System messages: `textSecondary`

### Typography

- **Section Headers:** `titleMedium` (22pt, SF Pro Rounded)
- **Card Titles:** `body` (17pt, SF Pro Rounded)
- **Body Text:** `bodySmall` (15pt, SF Pro Rounded)
- **Captions:** `caption` (13pt, SF Pro Rounded)

### Spacing

- **Screen Padding:** 20pt horizontal, 16pt vertical
- **Card Spacing:** 12pt between cards
- **Section Spacing:** 24pt between sections
- **Content Padding:** 16pt inside cards

### Interactions

- **Haptic Feedback:** Light impact on button taps
- **Touch Targets:** Minimum 44x44pt
- **Animations:** 0.3s ease-in-out
- **Loading States:** Show within 100ms

---

## Testing Strategy

### Unit Tests
- ViewModel state management
- Filter logic
- Error handling
- Use case integration

### UI Tests
- Navigation flows
- CRUD operations
- Filter/sort functionality
- Error recovery

### Manual Testing
- Real device testing
- Accessibility (VoiceOver, Dynamic Type)
- Dark mode support
- Loading state timing
- Animation smoothness

---

## Success Criteria

- ✅ All AI features accessible from main tabs
- ✅ Insights can be generated, viewed, and managed
- ✅ Goals can be created, updated, and tracked
- ✅ Chat provides natural conversation experience
- ✅ Design follows Lume's warm, calm principles
- ✅ No compilation errors or warnings
- ✅ Smooth animations and transitions
- ✅ Proper error handling throughout
- ✅ Loading states for all async operations
- ✅ Accessibility support (VoiceOver, Dynamic Type)

---

## Timeline Estimate

- **Part 1 (Insights):** 2-3 days
  - ViewModel: 4 hours
  - Views: 8 hours
  - Components: 4 hours
  
- **Part 2 (Goals):** 2-3 days
  - ViewModel: 4 hours
  - Views: 8 hours
  - Components: 4 hours
  
- **Part 3 (Chat):** 1-2 days
  - ViewModel: 3 hours
  - Views: 5 hours
  - Components: 2 hours
  
- **Part 4 (Integration & Polish):** 1 day
  - AppDependencies: 1 hour
  - MainTabView: 2 hours
  - Design System: 3 hours
  - Testing: 2 hours

**Total Estimate:** 6-9 days

---

## Current Status

### Completed
- ✅ Phase 4 (Backend & Use Cases)
- ✅ Domain models
- ✅ Repositories
- ✅ Use cases
- ✅ Backend services
- ✅ Schema definitions
- ✅ **Part 1: AI Insights Feature** (Complete 2025-01-28)
  - ✅ AIInsightsViewModel with full state management
  - ✅ AIInsightsListView with filtering and pull-to-refresh
  - ✅ AIInsightDetailView with actions and sharing
  - ✅ InsightFiltersSheet for advanced filtering
  - ✅ GenerateInsightsSheet for AI insight generation
  - ✅ All supporting components and views
  - ✅ AppDependencies integration with use cases
  - ✅ Preview support for all views

### In Progress
- 🚧 Part 2: Goals Feature (next)

### Pending
- ⏳ Part 3: Chat Feature
- ⏳ Part 4: Integration & Polish (MainTabView updates)

---

## Implementation Notes

### Part 1: AI Insights (Completed)
- ✅ Started with Insights as planned (most straightforward feature)
- ✅ Implemented full MVVM architecture with clean separation
- ✅ All 7 use cases properly integrated via AppDependencies
- ✅ Comprehensive filtering system (type, read status, favorites, archived)
- ✅ Pull-to-refresh and async loading states
- ✅ Full CRUD operations with proper error handling
- ✅ Empty states for all filter combinations
- ✅ Context data display for insights with metrics
- ✅ Suggestion cards with numbered display
- ✅ Share functionality for exporting insights
- ✅ Preview support for all components
- ✅ Follows Lume design principles (warm, calm, generous spacing)

### Next Steps
- Goals feature requires more complex state management
- Chat feature needs special attention to UX (typing indicators, streaming)
- Keep design system components reusable across all features
- Test on real devices early to validate animations and performance

---

## References

- Architecture: `lume/.github/copilot-instructions.md`
- Design System: Lume color palette and typography guidelines
- MVVM Pattern: iOS best practices
- Use Cases: `lume/Domain/UseCases/AI/`
- AI Insights Implementation: `lume/Presentation/Features/AIInsights/`
- AI Insights ViewModel: `lume/Presentation/ViewModels/AIInsightsViewModel.swift`

## Files Created (Part 1: AI Insights)

1. **ViewModels:**
   - `lume/Presentation/ViewModels/AIInsightsViewModel.swift` (508 lines)

2. **Views:**
   - `lume/Presentation/Features/AIInsights/AIInsightsListView.swift` (462 lines)
   - `lume/Presentation/Features/AIInsights/AIInsightDetailView.swift` (474 lines)
   - `lume/Presentation/Features/AIInsights/InsightFiltersSheet.swift` (243 lines)
   - `lume/Presentation/Features/AIInsights/GenerateInsightsSheet.swift` (244 lines)

3. **Dependencies:**
   - Updated `lume/DI/AppDependencies.swift` with 7 use cases and ViewModel factory

**Total Lines Added:** ~2,000 lines of production-ready SwiftUI code
