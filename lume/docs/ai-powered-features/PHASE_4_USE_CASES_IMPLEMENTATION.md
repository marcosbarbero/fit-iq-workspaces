# Phase 4: Use Cases Implementation

**Date:** 2025-01-28  
**Status:** ✅ Complete  
**Phase:** Business Logic Layer Implementation

---

## Overview

Phase 4 implements the business logic layer for AI features through comprehensive use cases. This layer sits between the presentation layer (ViewModels) and the infrastructure layer (repositories and services), coordinating operations, validating input, and enforcing business rules.

---

## Architecture Context

```
Presentation Layer (ViewModels)
        ↓
    Use Cases (Business Logic) ← YOU ARE HERE
        ↓
Domain Layer (Ports/Protocols)
        ↓
Infrastructure Layer (Repositories + Services)
```

### Responsibilities

**Use Cases Handle:**
- Business logic and validation
- Coordination between multiple repositories
- Error handling and recovery
- Data transformation and enrichment
- Complex workflows

**Use Cases Do NOT Handle:**
- UI logic (presentation layer)
- Data persistence details (infrastructure layer)
- Network communication (infrastructure layer)
- Platform-specific code (infrastructure layer)

---

## Implemented Use Cases

### AI Insights Use Cases ✅

#### 1. GenerateInsightUseCase
**Purpose:** Generate AI-powered insights based on user context

**Features:**
- Builds comprehensive user context from mood, journal, and goal data
- Validates sufficient data for meaningful insights
- Calculates statistics (trends, patterns, averages)
- Saves generated insights to repository
- Supports type-specific generation (mood, goal, motivational)
- Prevents duplicate generation (24-hour cooldown)

**Context Building:**
- Mood statistics (30-day history, trends, top labels)
- Journal statistics (word counts, themes, frequency)
- Goal statistics (progress, stalled goals, completion rates)
- Date range tracking

**Usage:**
```swift
let useCase = GenerateInsightUseCase(
    repository: insightRepository,
    service: insightService,
    moodRepository: moodRepository,
    journalRepository: journalRepository,
    goalRepository: goalRepository
)

// Generate all types
let insights = try await useCase.generateAll()

// Generate specific type
let moodInsights = try await useCase.generate(type: .moodPattern)

// Force refresh (ignore recent insights)
let fresh = try await useCase.generateAll(forceRefresh: true)
```

**Validation:**
- Minimum 3 mood entries OR 2 journal entries OR 1 active goal
- Recent insights check (skip if generated within 24 hours)
- Non-empty generation results

---

#### 2. FetchAIInsightsUseCase ✅
**Purpose:** Fetch insights with filtering and backend sync

**Features:**
- Optional backend sync before fetch
- Multiple filter options (type, read status, favorites, archived)
- Sort by generation date (newest first)
- Convenience methods for common queries

**Usage:**
```swift
// Fetch active insights with sync
let active = try await fetchUseCase.fetchActive()

// Fetch unread only
let unread = try await fetchUseCase.fetchUnread()

// Fetch by type
let moodInsights = try await fetchUseCase.fetchByType(.moodPattern)

// Custom filter
let insights = try await fetchUseCase.execute(
    type: .goalSuggestion,
    unreadOnly: true,
    favoritesOnly: false,
    archivedStatus: false,
    syncFromBackend: true
)
```

---

#### 3. ManageInsightUseCase ✅
**Purpose:** Manage insight state (read, favorite, archive, delete)

**Sub-Use Cases:**
- `MarkInsightAsReadUseCase` - Mark as read with background sync
- `ToggleInsightFavoriteUseCase` - Toggle favorite status
- `ArchiveInsightUseCase` - Archive insight
- `UnarchiveInsightUseCase` - Restore from archive
- `DeleteInsightUseCase` - Permanently delete

**Pattern:**
```swift
// Mark as read
let updated = try await markAsReadUseCase.execute(id: insightId)

// Toggle favorite
let favorited = try await toggleFavoriteUseCase.execute(id: insightId)

// Archive
let archived = try await archiveUseCase.execute(id: insightId)

// Delete (backend first, then local)
try await deleteUseCase.execute(id: insightId)
```

**Background Sync:**
- Local updates happen immediately (optimistic UI)
- Backend sync happens asynchronously
- UI remains responsive even if sync fails

---

### Goal Use Cases ✅

#### 4. CreateGoalUseCase
**Purpose:** Create new goals with comprehensive validation

**Validation Rules:**
- **Title:** 3-100 characters, non-empty
- **Description:** 10-500 characters, meaningful content
- **Target Date:** Must be future, max 5 years ahead
- **Duplicate Check:** Prevents similar titles (>85% similarity)

**Features:**
- Offline-first (saves locally, syncs via Outbox)
- Duplicate detection with similarity algorithm
- Input sanitization (trimming whitespace)
- Default values (progress = 0.0, status = active)

**Usage:**
```swift
// Standard creation
let goal = try await createUseCase.execute(
    title: "Exercise 3 times per week",
    description: "Improve fitness through regular exercise",
    category: .health,
    targetDate: Date().addingTimeInterval(90 * 24 * 60 * 60)
)

// From suggestion
let goalFromSuggestion = try await createUseCase.createFromSuggestion(suggestion)

// Simple goal
let simple = try await createUseCase.createSimple(
    title: "Meditate daily",
    category: .mindfulness
)
```

**Error Handling:**
- Clear, user-friendly error messages
- Recovery suggestions included
- Validation errors prevent bad data

---

#### 5. UpdateGoalUseCase
**Purpose:** Update existing goals with validation and constraints

**Update Options:**
- Title and description
- Category
- Target date
- Progress (0.0 - 1.0)
- Status (active, completed, paused, archived)

**Validation Constraints:**
- Completed goals must have 100% progress
- Active goals at 100% should be marked completed
- All field validations from CreateGoalUseCase apply

**Convenience Methods:**
```swift
// Update progress only
let updated = try await updateUseCase.updateProgress(goalId: id, progress: 0.75)

// Complete goal (auto-sets progress to 1.0)
let completed = try await updateUseCase.complete(goalId: id)

// Pause goal
let paused = try await updateUseCase.pause(goalId: id)

// Resume paused goal
let resumed = try await updateUseCase.resume(goalId: id)

// Update details
let changed = try await updateUseCase.updateDetails(
    goalId: id,
    title: "New Title",
    description: "New Description"
)
```

---

#### 6. FetchGoalsUseCase
**Purpose:** Fetch goals with filtering, statistics, and smart queries

**Filtering Options:**
- By status (active, completed, paused, archived)
- By category (health, mindfulness, career, etc.)
- Combined filters (status + category)

**Smart Queries:**
```swift
// Stalled goals (active, <20% progress, >7 days old)
let stalled = try await fetchUseCase.fetchStalled()

// Near completion (active, ≥80% progress)
let nearCompletion = try await fetchUseCase.fetchNearCompletion()

// Upcoming (target date within 7 days)
let upcoming = try await fetchUseCase.fetchUpcoming()

// Overdue (past target date, still active)
let overdue = try await fetchUseCase.fetchOverdue()
```

**Statistics:**
```swift
let stats = try await fetchUseCase.getStatistics()
print(stats.description) // "5 active, 3 completed, 1 paused"
print(stats.averageProgress) // 0.65
print(stats.completionRate) // 0.375 (3/8)
print(stats.stalledCount) // 2
```

**Backend Sync:**
- Optional sync before fetch
- Continues with local data if sync fails
- Configurable per query

---

#### 7. GenerateGoalSuggestionsUseCase ✅
**Purpose:** Generate AI-powered goal suggestions based on user context

**Context Building:**
- 30-day mood history
- Recent journal entries
- Active and completed goals
- Category patterns

**Features:**
- Duplicate filtering (>70% similarity)
- Keyword extraction and matching
- Context-aware suggestions
- Personalized to user patterns

**Usage:**
```swift
let suggestions = try await generateSuggestionsUseCase.execute()

// Each suggestion includes:
// - Title and description
// - Category
// - Reasoning (why suggested)
// - Priority
```

---

#### 8. GetGoalTipsUseCase ✅
**Purpose:** Get AI-powered tips for achieving specific goals

**Features:**
- Context-aware tips (mood, journal, other goals)
- Priority sorting (high → low)
- Personalized based on user history
- Actionable and specific

**Usage:**
```swift
let tips = try await getTipsUseCase.execute(goalId: goalId)

// Tips are sorted by priority
// Each tip includes:
// - Title and description
// - Priority level
// - Actionable advice
```

---

### Chat Use Cases ✅

#### 9. CreateConversationUseCase
**Purpose:** Create new chat conversations with validation

**Validation:**
- Title: 3-100 characters, non-empty
- Persona: Valid ChatPersona enum value

**Context Support:**
- Goal-related conversations
- Mood support conversations
- Insight discussions
- Quick check-ins

**Convenience Methods:**
```swift
// Default wellness conversation
let conversation = try await createUseCase.createDefault(title: "General Chat")

// Goal-focused
let goalChat = try await createUseCase.createForGoal(
    goalId: goalId,
    goalTitle: "Exercise more",
    persona: .motivational
)

// Mood support
let moodChat = try await createUseCase.createForMoodSupport(
    moodContext: moodSummary,
    persona: .supportive
)

// Insight discussion
let insightChat = try await createUseCase.createForInsight(
    insightId: insightId,
    insightType: "Mood Pattern",
    persona: .wellness
)

// Quick check-in
let checkIn = try await createUseCase.createQuickCheckIn()
```

**Real-Time:**
- Creates on backend immediately
- Then saves to local repository
- Provides instant feedback to user

---

#### 10. FetchConversationsUseCase
**Purpose:** Fetch conversations with filtering and statistics

**Filtering:**
```swift
// Active conversations
let active = try await fetchUseCase.fetchActive()

// Archived conversations
let archived = try await fetchUseCase.fetchArchived()

// By persona
let wellnessChats = try await fetchUseCase.fetchByPersona(.wellness)

// Recent (last 7 days)
let recent = try await fetchUseCase.fetchRecent()

// Related to goal
let goalChats = try await fetchUseCase.fetchForGoal(goalId)

// With unread messages
let unread = try await fetchUseCase.fetchWithUnreadMessages()

// Search by title
let results = try await fetchUseCase.search(query: "exercise")
```

**Statistics:**
```swift
let stats = try await fetchUseCase.getStatistics()
print(stats.description) // "8 active, 2 archived, 45 messages"
print(stats.averageMessagesPerConversation) // 5.6
print(stats.mostUsedPersona) // .wellness
```

---

#### 11. SendChatMessageUseCase ✅
**Purpose:** Send messages with real-time or streaming response

**Features:**
- Optimistic UI updates (save user message immediately)
- REST or WebSocket streaming
- Conversation validation
- Message length validation
- Error recovery (deletes failed message)

**Usage:**
```swift
// Standard send (REST API)
let message = try await sendUseCase.send(
    conversationId: conversationId,
    content: "How can I improve my mood?"
)

// Streaming send (WebSocket)
let streamingMessage = try await sendUseCase.sendStreaming(
    conversationId: conversationId,
    content: "Tell me about my progress"
)

// Full control
let controlled = try await sendUseCase.execute(
    conversationId: conversationId,
    content: "Hello",
    useStreaming: false
)
```

**Validation:**
- Non-empty message (trimmed)
- Max length check (ChatMessage.maxContentLength)
- Conversation exists check

**Error Recovery:**
- If backend send fails, user message is deleted
- User can retry without duplicates
- Clear error messages guide user

---

## Use Case Patterns

### 1. Validation Pattern

All use cases follow consistent validation:

```swift
func execute(...) async throws -> Result {
    // 1. Validate input
    try validateInput(...)
    
    // 2. Check business rules
    try checkBusinessConstraints(...)
    
    // 3. Perform operation
    let result = try await repository.operation(...)
    
    // 4. Return result
    return result
}
```

### 2. Offline-First Pattern

Goals use offline-first with Outbox:

```swift
// Save locally first (immediate UI update)
let saved = try await repository.save(entity)

// Backend sync happens automatically via Outbox pattern
// No waiting for network
return saved
```

### 3. Real-Time Pattern

Chat uses real-time communication:

```swift
// Send to backend immediately
let response = try await service.sendMessage(...)

// Save to local repository
let saved = try await repository.save(response)

return saved
```

### 4. Sync-Then-Fetch Pattern

Fetch use cases sync before returning:

```swift
// Optional sync from backend
if syncFromBackend {
    let backendData = try await service.fetch(...)
    for item in backendData {
        try await repository.save(item)
    }
}

// Fetch from local repository
let localData = try await repository.fetchAll()
return localData
```

### 5. Background Sync Pattern

Management use cases update locally first:

```swift
// Update locally (immediate)
let updated = try await repository.update(...)

// Sync to backend in background (don't wait)
Task {
    try await service.syncUpdate(...)
}

return updated
```

---

## Error Handling

### Error Types

Each use case defines specific errors:

```swift
enum CreateGoalError: Error, LocalizedError {
    case emptyTitle
    case titleTooShort
    case titleTooLong
    case duplicateGoal
    
    var errorDescription: String? {
        // User-friendly message
    }
    
    var recoverySuggestion: String? {
        // How to fix
    }
}
```

### Error Propagation

```swift
// Use cases catch and transform errors
do {
    let result = try await repository.operation()
    return result
} catch {
    // Log technical details
    print("⚠️ [UseCase] Operation failed: \(error)")
    
    // Throw user-friendly error
    throw UseCaseError.operationFailed
}
```

---

## Validation Rules

### Goals

| Field | Min | Max | Rules |
|-------|-----|-----|-------|
| Title | 3 chars | 100 chars | Non-empty, trimmed |
| Description | 10 chars | 500 chars | Meaningful content |
| Progress | 0.0 | 1.0 | Decimal (0-100%) |
| Target Date | Now | +5 years | Future date only |

**Business Rules:**
- Completed goals must have 100% progress
- 100% progress should be marked completed
- No duplicate titles (>85% similarity)

### Conversations

| Field | Min | Max | Rules |
|-------|-----|-----|-------|
| Title | 3 chars | 100 chars | Non-empty, trimmed |
| Message Content | 1 char | Variable | Non-empty, max length |

### Insights

**Generation Requirements:**
- Minimum 3 mood entries OR
- Minimum 2 journal entries OR
- Minimum 1 active goal

**Cooldown:**
- 24 hours between automatic generations
- Can be overridden with `forceRefresh: true`

---

## Coordination Examples

### Multi-Repository Coordination

```swift
// GenerateInsightUseCase coordinates 4 repositories
func buildContext() async throws -> Context {
    // Fetch from mood repository
    let moods = try await moodRepository.fetchRecent(days: 30)
    
    // Fetch from journal repository
    let journals = try await journalRepository.fetchRecent(limit: 30)
    
    // Fetch from goal repository
    let goals = try await goalRepository.fetchActive()
    
    // Combine into context
    return Context(moods: moods, journals: journals, goals: goals)
}
```

### Service + Repository Coordination

```swift
// FetchGoalsUseCase syncs then fetches
func execute() async throws -> [Goal] {
    // 1. Sync from backend service
    let backendGoals = try await goalService.fetchGoals()
    
    // 2. Save to local repository
    for goal in backendGoals {
        try await goalRepository.save(goal)
    }
    
    // 3. Fetch from repository (source of truth)
    return try await goalRepository.fetchAll()
}
```

---

## Testing Strategy

### Unit Tests

Each use case should have tests for:

```swift
class CreateGoalUseCaseTests: XCTestCase {
    // ✅ Success cases
    func testCreateGoalSuccess()
    func testCreateFromSuggestion()
    
    // ✅ Validation errors
    func testEmptyTitle()
    func testTitleTooShort()
    func testDuplicateGoal()
    
    // ✅ Business rules
    func testDuplicateDetection()
    func testSimilarityAlgorithm()
    
    // ✅ Edge cases
    func testWhitespaceHandling()
    func testUnicodeCharacters()
}
```

### Mock Dependencies

```swift
// Use case depends on protocols
let useCase = CreateGoalUseCase(
    goalRepository: MockGoalRepository(),
    outboxRepository: MockOutboxRepository()
)
```

---

## Performance Considerations

### Caching Strategy

- **Fetch Use Cases:** Cache in memory for 5 minutes
- **Statistics:** Cache for 1 minute (frequently requested)
- **Search:** No caching (query-dependent)

### Async Operations

- Use `async/await` for all I/O operations
- Background tasks with `Task { }` for non-blocking sync
- Proper cancellation support in long-running operations

### Batch Operations

```swift
// Save multiple items efficiently
for item in items {
    do {
        try await repository.save(item)
    } catch {
        // Continue with next item
        print("Failed to save \(item.id)")
    }
}
```

---

## Dependencies

### Use Case Dependencies

```
GenerateInsightUseCase
├── AIInsightRepositoryProtocol
├── AIInsightServiceProtocol
├── MoodRepositoryProtocol
├── JournalRepositoryProtocol
└── GoalRepositoryProtocol

CreateGoalUseCase
├── GoalRepositoryProtocol
└── OutboxRepositoryProtocol

SendChatMessageUseCase
├── ChatRepositoryProtocol
└── ChatServiceProtocol
```

### Dependency Injection

```swift
// In AppDependencies.swift
class AppDependencies {
    // Use cases
    lazy var generateInsightUseCase: GenerateInsightUseCase = {
        GenerateInsightUseCase(
            repository: aiInsightRepository,
            service: aiInsightService,
            moodRepository: moodRepository,
            journalRepository: journalRepository,
            goalRepository: goalRepository
        )
    }()
    
    lazy var createGoalUseCase: CreateGoalUseCase = {
        CreateGoalUseCase(
            goalRepository: goalRepository,
            outboxRepository: outboxRepository
        )
    }()
}
```

---

## File Structure

```
lume/Domain/UseCases/
├── AI/
│   ├── GenerateInsightUseCase.swift           ✅
│   ├── FetchAIInsightsUseCase.swift           ✅
│   └── ManageInsightUseCase.swift             ✅
├── Goals/
│   ├── CreateGoalUseCase.swift                ✅
│   ├── UpdateGoalUseCase.swift                ✅
│   ├── FetchGoalsUseCase.swift                ✅
│   ├── GenerateGoalSuggestionsUseCase.swift   ✅
│   └── GetGoalTipsUseCase.swift               ✅
└── Chat/
    ├── CreateConversationUseCase.swift        ✅
    ├── FetchConversationsUseCase.swift        ✅
    └── SendChatMessageUseCase.swift           ✅
```

---

## Status Summary

| Use Case | Status | Tests | Docs |
|----------|--------|-------|------|
| GenerateInsightUseCase | ✅ | ⏳ | ✅ |
| FetchAIInsightsUseCase | ✅ | ⏳ | ✅ |
| ManageInsightUseCase | ✅ | ⏳ | ✅ |
| CreateGoalUseCase | ✅ | ⏳ | ✅ |
| UpdateGoalUseCase | ✅ | ⏳ | ✅ |
| FetchGoalsUseCase | ✅ | ⏳ | ✅ |
| GenerateGoalSuggestionsUseCase | ✅ | ⏳ | ✅ |
| GetGoalTipsUseCase | ✅ | ⏳ | ✅ |
| CreateConversationUseCase | ✅ | ⏳ | ✅ |
| FetchConversationsUseCase | ✅ | ⏳ | ✅ |
| SendChatMessageUseCase | ✅ | ⏳ | ✅ |

**Legend:**
- ✅ Complete
- ⏳ Pending
- ❌ Not started

---

## Next Steps

### Phase 5: Presentation Layer
- Create ViewModels for each feature
- Build SwiftUI views
- Implement navigation flows
- Add loading states and error handling

### Testing
- Write unit tests for all use cases
- Create mock implementations
- Test validation rules
- Test error scenarios

### Integration
- Wire up dependencies in AppDependencies
- Test end-to-end flows
- Verify offline-first behavior
- Test backend synchronization

---

## Key Achievements

✅ **Complete Business Logic Layer**
- 11 use cases implemented
- Comprehensive validation
- Error handling with recovery
- Consistent patterns

✅ **Architecture Compliance**
- Pure business logic (no UI, no platform code)
- Protocol-based dependencies
- Testable design
- SOLID principles

✅ **Feature Coverage**
- AI Insights: Generate, fetch, manage
- Goals: Create, update, fetch, AI suggestions, tips
- Chat: Create, fetch, send messages

✅ **Quality Attributes**
- Clear error messages
- Recovery suggestions
- Convenience methods
- Statistics and analytics

---

**Phase 4 Status: 100% Complete** ✅

All use cases are implemented, documented, and ready for integration with the presentation layer!