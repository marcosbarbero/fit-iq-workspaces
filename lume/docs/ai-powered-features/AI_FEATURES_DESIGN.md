# Lume AI Features Design
**Version:** 1.0.0  
**Last Updated:** 2025-01-15  
**Status:** Design Phase

---

## Overview

This document outlines the design and implementation plan for three interconnected AI-powered features in Lume:

1. **Goals Management** - Track wellness goals with AI assistance
2. **AI Insights** - Periodic evaluation and personalized advice
3. **AI Consultant** - Interactive chat bot for guidance and support

---

## Design Principles

### Core Values
- **Privacy First:** User data is sacred; transparent about what AI sees
- **Warm & Non-Judgmental:** AI feels like a supportive friend, not a critic
- **Context-Aware:** AI understands user's mood patterns and journal entries
- **Resilient:** Works offline, syncs when online (Outbox pattern)
- **Minimal & Calm:** No overwhelming UI, gentle notifications

### Technical Principles
- Follow Hexagonal Architecture
- All AI calls through Outbox pattern
- Domain layer owns business logic
- Infrastructure implements AI services
- ViewModels coordinate between layers

---

## Feature 1: Goals Management

### User Experience

#### Goal List View
```
┌─────────────────────────────┐
│  Goals                   +  │
├─────────────────────────────┤
│                             │
│  🎯 Active Goals (3)        │
│                             │
│  ┌─────────────────────┐   │
│  │ 🧘 Daily Meditation │   │
│  │ 15 min each morning │   │
│  │ ████████░░░░ 65%    │   │
│  │ 4 days remaining    │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 💪 Exercise 3x/week │   │
│  │ Build healthy habit │   │
│  │ ██████░░░░░░ 50%    │   │
│  │ Overdue by 2 days   │   │
│  └─────────────────────┘   │
│                             │
│  💡 Get AI Help             │
│                             │
│  📊 Completed (12)          │
│  📦 Archived (5)            │
└─────────────────────────────┘
```

#### Create/Edit Goal
```
┌─────────────────────────────┐
│  ← New Goal                 │
├─────────────────────────────┤
│                             │
│  Title                      │
│  [Daily Meditation        ] │
│                             │
│  Description                │
│  [Practice mindfulness    ] │
│  [for 15 minutes each     ] │
│  [morning                 ] │
│                             │
│  Category                   │
│  ⚪ General                 │
│  ⚪ Physical Health         │
│  🔵 Mental Health           │
│  ⚪ Emotional Well-being    │
│                             │
│  Target Date (Optional)     │
│  [Jan 30, 2025          ▼] │
│                             │
│  💬 Get AI Suggestions      │
│                             │
│         [Create Goal]       │
└─────────────────────────────┘
```

#### Goal Detail View
```
┌─────────────────────────────┐
│  ← 🧘 Daily Meditation      │
├─────────────────────────────┤
│                             │
│  Practice mindfulness for   │
│  15 minutes each morning    │
│                             │
│  Progress                   │
│  ████████░░░░ 65%          │
│                             │
│  [───────●───────] 65%     │
│                             │
│  📅 Target: Jan 30, 2025    │
│  ⏰ 4 days remaining         │
│                             │
│  Recent Activity            │
│  • Jan 14 - Meditated 15m   │
│  • Jan 13 - Meditated 15m   │
│  • Jan 11 - Missed          │
│                             │
│  💬 Ask AI for tips         │
│                             │
│  [Mark Complete] [Edit]     │
└─────────────────────────────┘
```

### Domain Layer

#### Entities
Already exists: `Goal.swift` with:
- `Goal` struct (id, userId, title, description, progress, status, category, dates)
- `GoalStatus` enum (active, completed, paused, archived)
- `GoalCategory` enum (general, physical, mental, emotional, social, spiritual, professional)

New entity needed:
```swift
struct GoalActivity: Identifiable, Codable {
    let id: UUID
    let goalId: UUID
    let timestamp: Date
    let activityType: ActivityType
    let note: String?
    let progressDelta: Double
}

enum ActivityType: String, Codable {
    case progressUpdate
    case statusChange
    case note
    case aiSuggestion
}
```

#### Use Cases

**CreateGoalUseCase**
```swift
protocol CreateGoalUseCaseProtocol {
    func execute(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal
}
```

**UpdateGoalProgressUseCase**
```swift
protocol UpdateGoalProgressUseCaseProtocol {
    func execute(goalId: UUID, progress: Double, note: String?) async throws -> Goal
}
```

**FetchGoalsUseCase**
```swift
protocol FetchGoalsUseCaseProtocol {
    func executeAll() async throws -> [Goal]
    func executeActive() async throws -> [Goal]
    func executeByStatus(_ status: GoalStatus) async throws -> [Goal]
}
```

**CompleteGoalUseCase**
```swift
protocol CompleteGoalUseCaseProtocol {
    func execute(goalId: UUID) async throws -> Goal
}
```

**GetAIGoalSuggestionsUseCase**
```swift
protocol GetAIGoalSuggestionsUseCaseProtocol {
    func execute(
        category: GoalCategory?,
        userContext: UserContext
    ) async throws -> [GoalSuggestion]
}
```

#### Ports

Already exists: `GoalRepositoryProtocol` with full CRUD operations

New ports needed:
```swift
protocol AIGoalServiceProtocol {
    func generateGoalSuggestions(
        category: GoalCategory?,
        moodHistory: [MoodEntry],
        journalEntries: [JournalEntry]
    ) async throws -> [GoalSuggestion]
    
    func getGoalTips(
        goal: Goal,
        recentActivity: [GoalActivity]
    ) async throws -> [String]
}

protocol GoalActivityRepositoryProtocol {
    func create(_ activity: GoalActivity) async throws
    func fetchForGoal(_ goalId: UUID, limit: Int) async throws -> [GoalActivity]
}
```

### Presentation Layer

#### ViewModels

**GoalListViewModel**
```swift
@Observable
@MainActor
final class GoalListViewModel {
    var activeGoals: [Goal] = []
    var completedGoals: [Goal] = []
    var archivedGoals: [Goal] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showingCreateGoal: Bool = false
    var showingAIChat: Bool = false
    
    private let fetchGoalsUseCase: FetchGoalsUseCaseProtocol
    private let completeGoalUseCase: CompleteGoalUseCaseProtocol
    
    func loadGoals() async
    func refreshGoals() async
    func completeGoal(_ goal: Goal) async
    func deleteGoal(_ goal: Goal) async
}
```

**GoalDetailViewModel**
```swift
@Observable
@MainActor
final class GoalDetailViewModel {
    var goal: Goal
    var activities: [GoalActivity] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showingProgressUpdate: Bool = false
    var showingAITips: Bool = false
    
    private let updateProgressUseCase: UpdateGoalProgressUseCaseProtocol
    private let activityRepository: GoalActivityRepositoryProtocol
    private let aiGoalService: AIGoalServiceProtocol
    
    func loadActivities() async
    func updateProgress(_ progress: Double, note: String?) async
    func requestAITips() async
    func markComplete() async
}
```

**CreateGoalViewModel**
```swift
@Observable
@MainActor
final class CreateGoalViewModel {
    var title: String = ""
    var description: String = ""
    var selectedCategory: GoalCategory = .general
    var targetDate: Date?
    var hasTargetDate: Bool = false
    var aiSuggestions: [GoalSuggestion] = []
    var isLoadingSuggestions: Bool = false
    var isSaving: Bool = false
    var errorMessage: String?
    
    private let createGoalUseCase: CreateGoalUseCaseProtocol
    private let getAISuggestionsUseCase: GetAIGoalSuggestionsUseCaseProtocol
    
    func requestAISuggestions() async
    func applySuggestion(_ suggestion: GoalSuggestion)
    func createGoal() async throws
}
```

#### Views

**GoalListView** - Main goals screen
- Section headers (Active, Completed, Archived)
- Goal cards with progress bars
- Floating + button
- "Get AI Help" button → opens AI chat
- Pull to refresh

**GoalCardView** - Individual goal card component
- Icon + title
- Progress bar
- Status indicator
- Due date/overdue warning
- Tap to open detail view

**GoalDetailView** - Full goal details
- Title, description, category
- Interactive progress slider
- Recent activity timeline
- "Ask AI for tips" button
- Edit/Complete/Delete actions

**CreateGoalView** - Create/edit goal
- Form with title, description, category, target date
- "Get AI Suggestions" button
- Category picker with icons
- Date picker (optional)
- Save/Cancel actions

**GoalProgressUpdateView** - Quick progress update sheet
- Slider to adjust progress
- Optional note field
- Save button

### Infrastructure Layer

**GoalRepository** (SwiftData implementation)
- Implements `GoalRepositoryProtocol`
- Uses `@Model` for SwiftData persistence
- Translates between domain `Goal` and `SDGoal`

**AIGoalService** (API implementation)
- Implements `AIGoalServiceProtocol`
- Uses Outbox pattern for all AI calls
- Creates `SDOutboxEvent` for suggestions/tips
- Sends user context (mood, journal) securely

**GoalActivityRepository** (SwiftData implementation)
- Implements `GoalActivityRepositoryProtocol`
- Stores activity history locally

---

## Feature 2: AI Insights (Periodic Evaluation)

### User Experience

#### Dashboard Integration
```
┌─────────────────────────────┐
│  Dashboard                  │
├─────────────────────────────┤
│                             │
│  💡 Latest Insight          │
│  ┌─────────────────────┐   │
│  │ 🌟 Weekly Check-In  │   │
│  │                     │   │
│  │ You've been showing │   │
│  │ great consistency!  │   │
│  │ Your mood has been  │   │
│  │ trending positive.  │   │
│  │                     │   │
│  │ [Read More →]       │   │
│  └─────────────────────┘   │
│                             │
│  📊 Mood Chart              │
│  [chart visualization]      │
│                             │
│  📝 Recent Entries          │
│  [entries list]             │
└─────────────────────────────┘
```

#### Insight Detail View
```
┌─────────────────────────────┐
│  ← Weekly Check-In          │
├─────────────────────────────┤
│                             │
│  🌟 Jan 8-14, 2025          │
│                             │
│  You've been showing great  │
│  consistency with your mood │
│  tracking this week!        │
│                             │
│  📈 Positive Trends         │
│  • Logged mood 6/7 days     │
│  • 4 positive moods         │
│  • Journaled 5 times        │
│                             │
│  💭 Observations            │
│  Your journal entries show  │
│  you're finding joy in      │
│  small moments. Keep        │
│  nurturing this awareness.  │
│                             │
│  💡 Suggestions             │
│  • Consider setting a goal  │
│    around daily gratitude   │
│  • Your Friday moods tend   │
│    to be higher - what's    │
│    working well?            │
│                             │
│  [Ask AI About This]        │
└─────────────────────────────┘
```

#### Insights History View
```
┌─────────────────────────────┐
│  ← Insights History         │
├─────────────────────────────┤
│                             │
│  This Week                  │
│  ┌─────────────────────┐   │
│  │ 🌟 Weekly Check-In  │   │
│  │ Jan 8-14            │   │
│  │ Great consistency!  │   │
│  └─────────────────────┘   │
│                             │
│  Last Week                  │
│  ┌─────────────────────┐   │
│  │ 💡 Pattern Spotted  │   │
│  │ Jan 1-7             │   │
│  │ Morning routine...  │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ 🎯 Milestone        │   │
│  │ Dec 30              │   │
│  │ 30 days streak!     │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

### Domain Layer

#### Entities

```swift
struct AIInsight: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let createdAt: Date
    let insightType: InsightType
    let title: String
    let content: String
    let summary: String  // For card preview
    let periodStart: Date?
    let periodEnd: Date?
    let metrics: InsightMetrics?
    let suggestions: [String]
    var isRead: Bool
    var isFavorite: Bool
}

enum InsightType: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case milestone = "milestone"
    case pattern = "pattern"
    case suggestion = "suggestion"
    case celebration = "celebration"
    
    var displayName: String
    var icon: String
    var color: String
}

struct InsightMetrics: Codable, Equatable {
    let moodEntriesCount: Int
    let journalEntriesCount: Int
    let goalsActive: Int
    let goalsCompleted: Int
    let averageMoodScore: Double?
    let streakDays: Int?
}

struct UserContext: Codable {
    let moodHistory: [MoodEntry]
    let recentJournals: [JournalEntry]
    let activeGoals: [Goal]
    let completedGoals: [Goal]
    let previousInsights: [AIInsight]
}
```

#### Use Cases

**GenerateAIInsightUseCase**
```swift
protocol GenerateAIInsightUseCaseProtocol {
    func execute(type: InsightType) async throws -> AIInsight
}
```

**FetchInsightsUseCase**
```swift
protocol FetchInsightsUseCaseProtocol {
    func executeRecent(limit: Int) async throws -> [AIInsight]
    func executeAll() async throws -> [AIInsight]
    func executeUnread() async throws -> [AIInsight]
}
```

**MarkInsightReadUseCase**
```swift
protocol MarkInsightReadUseCaseProtocol {
    func execute(insightId: UUID) async throws
}
```

#### Ports

```swift
protocol AIInsightServiceProtocol {
    func generateInsight(
        type: InsightType,
        context: UserContext
    ) async throws -> AIInsight
    
    func shouldGenerateInsight(type: InsightType) async throws -> Bool
}

protocol InsightRepositoryProtocol {
    func save(_ insight: AIInsight) async throws
    func fetchRecent(limit: Int) async throws -> [AIInsight]
    func fetchAll() async throws -> [AIInsight]
    func fetchUnread() async throws -> [AIInsight]
    func markRead(_ id: UUID) async throws
    func delete(_ id: UUID) async throws
}
```

### Presentation Layer

#### ViewModels

**InsightCardViewModel**
```swift
@Observable
@MainActor
final class InsightCardViewModel {
    var latestInsight: AIInsight?
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let fetchInsightsUseCase: FetchInsightsUseCaseProtocol
    
    func loadLatestInsight() async
    func markAsRead() async
}
```

**InsightsHistoryViewModel**
```swift
@Observable
@MainActor
final class InsightsHistoryViewModel {
    var insights: [AIInsight] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedInsight: AIInsight?
    
    private let fetchInsightsUseCase: FetchInsightsUseCaseProtocol
    private let markReadUseCase: MarkInsightReadUseCaseProtocol
    
    func loadInsights() async
    func refreshInsights() async
    func selectInsight(_ insight: AIInsight) async
}
```

#### Views

**InsightCardView** (Dashboard component)
- Shows latest insight
- Title + summary preview
- Icon based on insight type
- "Read More" button
- Unread indicator

**InsightDetailView** (Full insight)
- Full content
- Metrics visualization
- Suggestions list
- "Ask AI About This" → opens chat with context
- Share/Favorite actions

**InsightsHistoryView** (All insights)
- Grouped by time period
- Insight cards with type indicators
- Filter by type
- Search functionality

### Infrastructure Layer

**AIInsightService** (API implementation)
- Implements `AIInsightServiceProtocol`
- Uses Outbox pattern
- Builds UserContext from repositories
- Generates insights based on type
- Rate limiting (e.g., max 1 daily insight per day)

**InsightRepository** (SwiftData implementation)
- Implements `InsightRepositoryProtocol`
- Local storage for insights
- Caches generated insights

**InsightGenerationService** (Background service)
- Scheduled tasks (daily at 8pm, weekly on Sunday)
- Checks if insight should be generated
- Triggers generation use case
- Stores result locally
- Can trigger local notification

---

## Feature 3: AI Consultant (Chat Bot)

### User Experience

#### Chat Interface
```
┌─────────────────────────────┐
│  ← AI Consultant            │
├─────────────────────────────┤
│                             │
│  ┌─────────────────────┐   │
│  │ Hi! I'm here to     │   │
│  │ help you with your  │   │
│  │ wellness goals. 😊  │   │
│  └─────────────────────┘   │
│                             │
│           ┌─────────────┐   │
│           │ Help me set │   │
│           │ a new goal  │   │
│           └─────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ I'd be happy to!    │   │
│  │ What area of        │   │
│  │ wellness interests  │   │
│  │ you most?           │   │
│  │                     │   │
│  │ • Mental Health     │   │
│  │ • Physical Health   │   │
│  │ • Emotional Health  │   │
│  └─────────────────────┘   │
│                             │
│  [                      ] 🎤│
│  [Type your message...   ] │
└─────────────────────────────┘
```

#### Quick Actions
```
┌─────────────────────────────┐
│                             │
│  Quick Actions              │
│                             │
│  💪 Help me set a goal      │
│  📊 Review my progress      │
│  💡 Give me a suggestion    │
│  ❓ Answer a question       │
│  🎯 Improve an existing goal│
│                             │
└─────────────────────────────┘
```

#### Chat with Context
```
┌─────────────────────────────┐
│  ← Goal: Daily Meditation   │
├─────────────────────────────┤
│                             │
│  Context: Your goal is at   │
│  65% progress, 4 days left  │
│                             │
│  ┌─────────────────────┐   │
│  │ How can I help with │   │
│  │ your meditation     │   │
│  │ goal?               │   │
│  └─────────────────────┘   │
│                             │
│           ┌─────────────┐   │
│           │ I keep      │   │
│           │ missing days│   │
│           └─────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │ I understand. Let's │   │
│  │ think about this... │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

### Domain Layer

#### Entities

```swift
struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var context: ChatContext?
    var isActive: Bool
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sessionId: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var metadata: MessageMetadata?
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

struct MessageMetadata: Codable, Equatable {
    let tokens: Int?
    let model: String?
    let contextUsed: [String]?
    let suggestedActions: [String]?
}

struct ChatContext: Codable, Equatable {
    let contextType: ContextType
    let relatedId: UUID?  // Goal ID, Insight ID, etc.
    let summary: String
}

enum ContextType: String, Codable {
    case general = "general"
    case goalSetting = "goal_setting"
    case goalProgress = "goal_progress"
    case insightDiscussion = "insight_discussion"
    case moodReflection = "mood_reflection"
}

struct QuickAction: Identifiable, Codable {
    let id: UUID
    let title: String
    let prompt: String
    let icon: String
    let context: ChatContext?
}
```

#### Use Cases

**CreateChatSessionUseCase**
```swift
protocol CreateChatSessionUseCaseProtocol {
    func execute(context: ChatContext?) async throws -> ChatSession
}
```

**SendChatMessageUseCase**
```swift
protocol SendChatMessageUseCaseProtocol {
    func execute(
        sessionId: UUID,
        message: String
    ) async throws -> ChatMessage
}
```

**FetchChatHistoryUseCase**
```swift
protocol FetchChatHistoryUseCaseProtocol {
    func execute(sessionId: UUID) async throws -> [ChatMessage]
    func executeRecentSessions(limit: Int) async throws -> [ChatSession]
}
```

**GetQuickActionsUseCase**
```swift
protocol GetQuickActionsUseCaseProtocol {
    func execute() async throws -> [QuickAction]
}
```

#### Ports

```swift
protocol AIChatServiceProtocol {
    func sendMessage(
        message: String,
        sessionId: UUID,
        context: UserContext,
        chatContext: ChatContext?
    ) async throws -> String
    
    func generateQuickActions(
        userContext: UserContext
    ) async throws -> [QuickAction]
}

protocol ChatRepositoryProtocol {
    func createSession(_ session: ChatSession) async throws
    func saveMessage(_ message: ChatMessage) async throws
    func fetchSession(_ id: UUID) async throws -> ChatSession?
    func fetchMessages(sessionId: UUID) async throws -> [ChatMessage]
    func fetchRecentSessions(limit: Int) async throws -> [ChatSession]
    func updateSession(_ session: ChatSession) async throws
    func deleteSession(_ id: UUID) async throws
}
```

### Presentation Layer

#### ViewModels

**ChatViewModel**
```swift
@Observable
@MainActor
final class ChatViewModel {
    var session: ChatSession?
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String?
    var quickActions: [QuickAction] = []
    var showingQuickActions: Bool = false
    
    private let createSessionUseCase: CreateChatSessionUseCaseProtocol
    private let sendMessageUseCase: SendChatMessageUseCaseProtocol
    private let fetchHistoryUseCase: FetchChatHistoryUseCaseProtocol
    private let getQuickActionsUseCase: GetQuickActionsUseCaseProtocol
    
    func startSession(with context: ChatContext?) async
    func loadHistory() async
    func sendMessage() async
    func useQuickAction(_ action: QuickAction) async
    func loadQuickActions() async
}
```

**ChatHistoryViewModel**
```swift
@Observable
@MainActor
final class ChatHistoryViewModel {
    var sessions: [ChatSession] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let fetchHistoryUseCase: FetchChatHistoryUseCaseProtocol
    
    func loadSessions() async
    func deleteSession(_ session: ChatSession) async
}
```

#### Views

**ChatView** - Main chat interface
- Message list (scrollable, auto-scroll to bottom)
- Message bubbles (user vs assistant styling)
- Input field with send button
- Quick actions button
- Context banner (when chatting about specific goal/insight)

**ChatMessageView** - Individual message bubble
- Role-based styling (user: right-aligned, assistant: left-aligned)
- Timestamp
- Copy text action
- Markdown support for formatting

**QuickActionsSheet** - Bottom sheet with suggestions
- Grid of quick action buttons
- Contextual suggestions based on user state
- "Start New Chat" option

**ChatHistoryView** - Past conversations
- List of sessions with preview
- Search functionality
- Delete/Archive actions

### Infrastructure Layer

**AIChatService** (API implementation)
- Implements `AIChatServiceProtocol`
- Uses Outbox pattern for resilience
- Builds full context from user data
- Streaming support (future enhancement)
- Rate limiting and token management

**ChatRepository** (SwiftData implementation)
- Implements `ChatRepositoryProtocol`
- Stores sessions and messages locally
- Enables offline viewing of past chats

---

## Integration Points

### How Features Work Together

#### Dashboard → Insights → Chat
```
User opens Dashboard
    → Sees latest AI insight card
    → Taps "Read More"
    → Opens InsightDetailView
    → Taps "Ask AI About This"
    → Opens ChatView with insight context
```

#### Goals → Chat → Goal Creation
```
User opens Goals tab
    → Taps "Get AI Help"
    → Opens ChatView with goalSetting context
    → Chats about wellness goals
    → AI suggests specific goals
    → Taps suggested goal
    → Opens CreateGoalView with pre-filled data
```

#### Mood/Journal → Insights → Goals
```
Background service runs weekly
    → Fetches mood history
    → Fetches journal entries
    → Fetches goals
    → Generates AI insight
    → Stores insight locally
    → (Optional) Sends notification
    → User opens app
    → Sees new insight in Dashboard
    → Insight suggests new goal area
    → User taps to create goal
```

### Shared Context

All AI features share access to:
- Mood history (via `MoodRepositoryProtocol`)
- Journal entries (via `JournalRepositoryProtocol`)
- Goals (via `GoalRepositoryProtocol`)
- User profile

Context is built by `UserContextBuilder`:
```swift
struct UserContextBuilder {
    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol
    private let goalRepository: GoalRepositoryProtocol
    
    func buildContext(
        includeAllHistory: Bool = false
    ) async throws -> UserContext {
        // Fetch relevant data
        // Return UserContext
    }
}
```

---

## Technical Implementation

### Outbox Pattern for AI Calls

All AI interactions must use the Outbox pattern:

```swift
// Example: Generate AI Insight
func generateInsight(type: InsightType) async throws -> AIInsight {
    // 1. Create outbox event
    let payload = try JSONEncoder().encode([
        "type": type.rawValue,
        "context": buildUserContext()
    ])
    
    let event = SDOutboxEvent(
        eventType: "ai.insight.generate",
        payload: payload,
        status: "pending"
    )
    
    // 2. Save to outbox
    try await outboxRepository.save(event)
    
    // 3. Processor picks it up
    // 4. Calls AI service
    // 5. Stores result
    // 6. Marks event complete
    
    // 7. Fetch result
    return try await insightRepository.fetchLatest()
}
```

### Background Service

**InsightGenerationService**
- Runs on background thread
- Scheduled via `BackgroundTasks` framework
- Checks if insight should be generated (daily/weekly schedule)
- Triggers insight generation
- Handles errors gracefully

```swift
final class InsightGenerationService {
    func scheduleNextGeneration() {
        // Schedule daily at 8pm
        // Schedule weekly on Sunday
    }
    
    func generateDailyInsight() async {
        // Check if already generated today
        // Generate if needed
        // Optionally send notification
    }
    
    func generateWeeklyInsight() async {
        // Generate weekly summary
    }
}
```

### Security & Privacy

**Data Handling**
- Never send tokens/passwords to AI
- Anonymize data where possible
- Clear privacy policy about AI usage
- User consent required
- Option to disable AI features

**Token Management**
- Store AI API keys securely
- Rotate keys regularly
- Rate limit per user
- Cost monitoring

**Error Handling**
- Graceful degradation when AI unavailable
- Offline mode support
- Clear error messages
- Retry logic with exponential backoff

---

## UI/UX Considerations

### Design Consistency

**Colors**
- Use existing Lume palette
- AI elements: Soft purple accent (`accentSecondary`)
- Positive insights: Warm yellow (`moodPositive`)
- Neutral: Sage green (`moodNeutral`)

**Typography**
- Insight titles: `titleMedium`
- Insight content: `body`
- Chat messages: `body`
- Timestamps: `caption`

**Components**
- Rounded corners (20pt)
- Generous padding (24pt)
- Soft shadows for elevation
- Smooth animations (0.3s ease)

### Accessibility

- VoiceOver support for all elements
- Dynamic Type support
- High contrast mode
- Haptic feedback for actions
- Clear focus indicators

### Performance

- Lazy loading for chat history
- Image/icon caching
- Optimistic UI updates
- Background processing for AI calls
- Memory management for large conversations

---

## Implementation Roadmap

### Phase 1: Goals Foundation (Week 1)
- [ ] Implement Goal repository (SwiftData)
- [ ] Create GoalViewModel and views
- [ ] Basic CRUD operations
- [ ] Goal list, detail, create/edit views
- [ ] Progress tracking
- [ ] Replace Goals placeholder in MainTabView

### Phase 2: AI Infrastructure (Week 1)
- [ ] Define AI service ports
- [ ] Implement Outbox pattern for AI
- [ ] Create UserContextBuilder
- [ ] Set up AI API integration
- [ ] Error handling and resilience

### Phase 3: AI Insights (Week 2)
- [ ] Implement Insight entities and repositories
- [ ] Create InsightViewModel and views
- [ ] Background service for generation
- [ ] Dashboard integration
- [ ] Insights history view

### Phase 4: AI Chat Bot (Week 2-3)
- [ ] Implement Chat entities and repositories
- [ ] Create ChatViewModel and views
- [ ] Quick actions system
- [ ] Context-aware conversations
- [ ] Chat history

### Phase 5: Integration & Polish (Week 3)
- [ ] Connect Goals ↔ Chat
- [ ] Connect Insights ↔ Chat
- [ ] Connect Dashboard ↔ Insights ↔ Goals
- [ ] Notification support
- [ ] Testing and bug fixes

### Phase 6: Testing & Documentation (Week 4)
- [ ] Unit tests for use cases
- [ ] Integration tests
- [ ] UI tests
- [ ] User documentation
- [ ] Privacy policy update

---

## Success Metrics

### User Engagement
- % of users who create at least one goal
- Average goals per user
- Goal completion rate
- Chat sessions per week
- Insight read rate

### Quality Metrics
- AI response quality (user feedback)
- Response time (p50, p95, p99)
- Error rate for AI calls
- User satisfaction (in-app rating)

### Technical Metrics
- Outbox processing success rate
- Background task completion rate
- API cost per user per month
- Local storage usage

---

## Future Enhancements

### Short Term
- Voice input for chat
- Share insights with friends
- Export goals as PDF
- Goal templates
- Collaborative goals

### Medium Term
- AI-powered mood prediction
- Habit tracking integration
- Reminders for goals
- Achievement badges
- Goal categories customization

### Long Term
- Multi-modal AI (image analysis of journal photos)
- Personalized AI voice
- Integration with health apps
- Community features
- Therapist collaboration tools

---

## Open Questions

1. **AI Provider:** Which AI service? (OpenAI, Anthropic, custom?)
2. **Cost Management:** How to handle API costs at scale?
3. **Offline AI:** Should we support on-device AI models?
4. **Notifications:** How aggressive should insight notifications be?
5. **Privacy:** How much context should we send to AI?
6. **Voice:** Should chat support voice input/output?
7. **Moderation:** How to handle inappropriate AI responses?
8. **Personalization:** How much to adapt AI tone to user?

---

## Conclusion

These three features form a cohesive AI-powered wellness system:

- **Goals** provide structure and tracking
- **Insights** offer reflection and awareness
- **Chat** provides guidance and support

Together they create a warm, supportive experience that helps users improve their wellness journey while maintaining Lume's core values of calm, warmth, and non-judgmental support.

The implementation follows Lume's architectural principles:
- Hexagonal Architecture for clean separation
- Outbox pattern for resilient AI communication
- Domain-driven design for clear business logic
- SwiftUI for modern, reactive UI
- SwiftData for local persistence

Next steps: Review with team, address open questions, begin Phase 1 implementation.