# Lume AI Features Quick Reference

**Version:** 1.0  
**Last Updated:** 2025-01-29

---

## Overview

Quick reference for implementing and using AI features in the Lume iOS app.

---

## Table of Contents

1. [Backend Services](#backend-services)
2. [Repositories](#repositories)
3. [Domain Entities](#domain-entities)
4. [Common Patterns](#common-patterns)
5. [Error Handling](#error-handling)
6. [Testing](#testing)

---

## Backend Services

### AIInsightBackendService

```swift
// Generate insight
let insight = try await aiInsightBackendService.generateInsight(
    type: .weekly,
    context: InsightGenerationContext(
        dateRangeStart: startDate,
        dateRangeEnd: endDate,
        includeGoals: true,
        includeMoods: true,
        includeJournals: true
    ),
    accessToken: token
)

// Fetch insights
let insights = try await aiInsightBackendService.fetchAllInsights(accessToken: token)
let unread = try await aiInsightBackendService.fetchUnreadInsights(accessToken: token)

// Update insight
try await aiInsightBackendService.markInsightAsRead(insightId: id, accessToken: token)
try await aiInsightBackendService.toggleInsightFavorite(insightId: id, isFavorite: true, accessToken: token)
```

### GoalBackendService

```swift
// CRUD operations
let backendId = try await goalBackendService.createGoal(goal, accessToken: token)
try await goalBackendService.updateGoal(goal, backendId: backendId, accessToken: token)
try await goalBackendService.deleteGoal(backendId: backendId, accessToken: token)

// Fetch goals
let goals = try await goalBackendService.fetchAllGoals(accessToken: token)
let active = try await goalBackendService.fetchActiveGoals(accessToken: token)
let category = try await goalBackendService.fetchGoalsByCategory(category: .physical, accessToken: token)

// AI features
let suggestions = try await goalBackendService.getAISuggestions(for: goalId, accessToken: token)
let tips = try await goalBackendService.getAITips(for: goalId, accessToken: token)
let analysis = try await goalBackendService.getProgressAnalysis(for: goalId, accessToken: token)
```

### ChatBackendService

```swift
// Create conversation
let conversation = try await chatBackendService.createConversation(
    title: "Wellness Chat",
    persona: .wellness,
    context: nil,
    accessToken: token
)

// Send message (REST)
let message = try await chatBackendService.sendMessage(
    message: "How can I improve my sleep?",
    conversationId: conversationId,
    accessToken: token
)

// WebSocket real-time chat
chatBackendService.setMessageHandler { message in
    print("New message: \(message.content)")
}

chatBackendService.setConnectionStatusHandler { status in
    print("Connection status: \(status)")
}

try await chatBackendService.connectWebSocket(conversationId: conversationId, accessToken: token)
try await chatBackendService.sendMessageViaWebSocket(message: "Hello!", conversationId: conversationId)

// Cleanup
chatBackendService.disconnectWebSocket()
```

---

## Repositories

### AIInsightRepository

```swift
// Fetch insights
let insights = try await aiInsightRepository.fetchAll()
let byType = try await aiInsightRepository.fetchByType(.weekly)
let unread = try await aiInsightRepository.fetchUnread()

// Generate insight
let insight = try await aiInsightRepository.generateInsight(
    type: .monthly,
    context: context
)

// Update insight
try await aiInsightRepository.markAsRead(insightId)
try await aiInsightRepository.toggleFavorite(insightId)
try await aiInsightRepository.archive(insightId)
```

### GoalRepository

```swift
// Create goal
let goal = try await goalRepository.create(
    title: "Exercise Daily",
    description: "30 minutes of exercise",
    category: .physical,
    targetDate: futureDate
)

// Fetch goals
let goals = try await goalRepository.fetchAll()
let active = try await goalRepository.fetchActive()
let completed = try await goalRepository.fetchCompleted()
let byCategory = try await goalRepository.fetchByCategory(.physical)

// Update goal
try await goalRepository.updateProgress(goalId, progress: 0.5)
try await goalRepository.updateStatus(goalId, status: .completed)

// AI features
let suggestions = try await goalRepository.getAISuggestions(for: goalId)
let tips = try await goalRepository.getAITips(for: goalId)
let analysis = try await goalRepository.getProgressAnalysis(for: goalId)
```

### ChatRepository

```swift
// Create conversation
let conversation = try await chatRepository.createConversation(
    title: "New Chat",
    persona: .wellness,
    context: nil
)

// Add message
let updatedConversation = try await chatRepository.addMessage(
    message,
    to: conversationId
)

// Fetch conversations
let conversations = try await chatRepository.fetchAllConversations()
let active = try await chatRepository.fetchActiveConversations()

// Fetch messages
let messages = try await chatRepository.fetchMessages(for: conversationId)
let recent = try await chatRepository.fetchRecentMessages(for: conversationId, limit: 20)
```

---

## Domain Entities

### AIInsight

```swift
let insight = AIInsight(
    id: UUID(),
    userId: userId,
    insightType: .weekly,
    title: "Your Week in Review",
    content: "Full insight text...",
    summary: "Brief summary",
    suggestions: ["Suggestion 1", "Suggestion 2"],
    dataContext: InsightDataContext(
        dateRange: DateRange(startDate: start, endDate: end),
        metrics: MetricsSummary(moodScore: 4.2, journalCount: 5)
    )
)

// Methods
insight.markAsRead()
insight.toggleFavorite()
insight.archive()
insight.unarchive()

// Properties
insight.hasSuggestions
insight.hasDataContext
insight.formattedGeneratedDate
```

### Goal

```swift
let goal = Goal(
    id: UUID(),
    userId: userId,
    title: "Exercise Regularly",
    description: "Exercise 30 minutes daily",
    category: .physical,
    targetDate: futureDate,
    progress: 0.3,
    status: .active
)

// Properties
goal.isComplete
goal.hasTargetDate
goal.isOverdue
goal.daysRemaining
goal.progressPercentage
goal.formattedTargetDate
```

### ChatConversation

```swift
let conversation = ChatConversation(
    id: UUID(),
    userId: userId,
    title: "Wellness Chat",
    persona: .wellness,
    messages: [],
    context: ConversationContext(
        relatedGoalIds: [goalId],
        moodContext: MoodContextSummary(recentMoodAverage: 4.0)
    )
)

// Methods
conversation.addMessage(message)
conversation.archive()
conversation.unarchive()
conversation.clearMessages()

// Properties
conversation.lastMessage
conversation.lastUserMessage
conversation.messageCount
conversation.hasMessages
```

### ChatMessage

```swift
let message = ChatMessage(
    id: UUID(),
    conversationId: conversationId,
    role: .user,
    content: "How can I improve my sleep?",
    timestamp: Date(),
    metadata: MessageMetadata(
        persona: .wellness,
        tokens: 150
    )
)

// Properties
message.isUserMessage
message.isAssistantMessage
message.formattedTimestamp
```

---

## Common Patterns

### Accessing Services via DI

```swift
// In your view or view model
@Environment(\.dependencies) private var dependencies

// Use services
let insights = try await dependencies.aiInsightRepository.fetchAll()
let goals = try await dependencies.goalRepository.fetchActive()
```

### Error Handling

```swift
do {
    let insight = try await aiInsightBackendService.generateInsight(
        type: .weekly,
        context: nil,
        accessToken: token
    )
    // Handle success
} catch HTTPError.unauthorized {
    // Token expired, refresh needed
} catch HTTPError.serverError(let code) {
    // Backend error
} catch {
    // Other errors
}
```

### Outbox Pattern (Goals)

```swift
// Repository automatically creates outbox event
let goal = try await goalRepository.create(
    title: "My Goal",
    description: "Description",
    category: .general,
    targetDate: nil
)

// Outbox processor syncs in background
// No need to manually call backend service
```

### WebSocket Real-Time Updates

```swift
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var connectionStatus: WebSocketConnectionStatus = .disconnected
    
    private let chatBackendService: ChatBackendServiceProtocol
    
    func connect(conversationId: UUID, token: String) async {
        // Set up handlers
        chatBackendService.setMessageHandler { [weak self] message in
            DispatchQueue.main.async {
                self?.messages.append(message)
            }
        }
        
        chatBackendService.setConnectionStatusHandler { [weak self] status in
            DispatchQueue.main.async {
                self?.connectionStatus = status
            }
        }
        
        // Connect
        try? await chatBackendService.connectWebSocket(
            conversationId: conversationId,
            accessToken: token
        )
    }
    
    func sendMessage(_ text: String, conversationId: UUID) async {
        try? await chatBackendService.sendMessageViaWebSocket(
            message: text,
            conversationId: conversationId
        )
    }
}
```

---

## Error Handling

### HTTP Errors

```swift
enum HTTPError: LocalizedError {
    case invalidResponse
    case decodingFailed(Error)
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case serverError(Int)
    case unknown(Int)
    case backendError(code: String, message: String, statusCode: Int)
}
```

### Repository Errors

```swift
// AIInsightRepositoryError
case fetchFailed(Error)
case generateFailed(Error)
case updateFailed(Error)
case deleteFailed(Error)
case insightNotFound(UUID)

// GoalRepositoryError
case createFailed(Error)
case updateFailed(Error)
case deleteFailed(Error)
case fetchFailed(Error)
case goalNotFound(UUID)

// ChatRepositoryError
case conversationNotFound(UUID)
case messageNotFound(UUID)
case createFailed(Error)
case updateFailed(Error)
case deleteFailed(Error)
case fetchFailed(Error)
```

### WebSocket Errors

```swift
enum WebSocketError: LocalizedError {
    case notConnected
    case connectionFailed
    case sendFailed
    case invalidMessage
    case unauthorized
}
```

### Best Practices

```swift
// Specific error handling
do {
    let goal = try await goalRepository.fetchById(goalId)
} catch GoalRepositoryError.goalNotFound(let id) {
    print("Goal not found: \(id)")
    showErrorMessage("Goal not found")
} catch GoalRepositoryError.fetchFailed(let error) {
    print("Fetch failed: \(error)")
    showErrorMessage("Failed to load goal")
} catch {
    print("Unexpected error: \(error)")
    showErrorMessage("Something went wrong")
}
```

---

## Testing

### Mock Services

```swift
// AI Insight Backend
let mockService = InMemoryAIInsightBackendService()
mockService.shouldFail = false

let insight = try await mockService.generateInsight(
    type: .weekly,
    context: nil,
    accessToken: "test-token"
)

// Goal Backend
let mockGoalService = InMemoryGoalBackendService()
let backendId = try await mockGoalService.createGoal(testGoal, accessToken: "test-token")

// Chat Backend
let mockChatService = InMemoryChatBackendService()
mockChatService.setMessageHandler { message in
    print("Mock message: \(message.content)")
}
```

### Testing Error Paths

```swift
func testErrorHandling() async throws {
    let mockService = InMemoryAIInsightBackendService()
    mockService.shouldFail = true
    
    do {
        _ = try await mockService.fetchAllInsights(accessToken: "test")
        XCTFail("Should have thrown error")
    } catch HTTPError.serverError {
        // Expected
    } catch {
        XCTFail("Unexpected error: \(error)")
    }
}
```

### Repository Tests

```swift
@MainActor
class GoalRepositoryTests: XCTestCase {
    var repository: GoalRepository!
    var mockBackendService: InMemoryGoalBackendService!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        // Setup in-memory container
        let container = try ModelContainer(
            for: SchemaVersioning.SchemaV6.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        modelContext = ModelContext(container)
        
        // Setup mock services
        mockBackendService = InMemoryGoalBackendService()
        
        // Create repository
        repository = GoalRepository(
            modelContext: modelContext,
            backendService: mockBackendService,
            tokenStorage: MockTokenStorage(),
            outboxRepository: MockOutboxRepository()
        )
    }
    
    func testCreateGoal() async throws {
        let goal = try await repository.create(
            title: "Test Goal",
            description: "Test Description",
            category: .general,
            targetDate: nil
        )
        
        XCTAssertEqual(goal.title, "Test Goal")
        XCTAssertFalse(mockBackendService.goals.isEmpty)
    }
}
```

---

## Configuration

### Backend URLs

Access via `AppConfiguration`:
```swift
let baseURL = AppConfiguration.shared.backendBaseURL
let wsURL = AppConfiguration.shared.webSocketURL
let apiKey = AppConfiguration.shared.apiKey
```

### Mock Mode

Toggle mock services:
```swift
// In AppMode.swift or similar
AppMode.useMockData = true  // Use mock services
AppMode.useMockData = false // Use real backend
```

---

## Tips & Best Practices

### 1. Always Use Repositories
❌ Don't access backend services directly from ViewModels
✅ Use repositories which handle persistence and sync

### 2. Handle Tokens Properly
```swift
guard let token = try await tokenStorage.getToken() else {
    throw AuthError.notAuthenticated
}
```

### 3. Use Outbox for Goals
Goals automatically queue events for sync. Don't manually sync.

### 4. Don't Use Outbox for Chat
Chat needs real-time updates. Use WebSocket directly.

### 5. Clean Up WebSocket Connections
```swift
deinit {
    chatBackendService.disconnectWebSocket()
}
```

### 6. Use Structured Concurrency
```swift
// Good
async let insights = repository.fetchInsights()
async let goals = repository.fetchGoals()
let (i, g) = try await (insights, goals)

// Better error handling
await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { try await loadInsights() }
    group.addTask { try await loadGoals() }
    try await group.waitForAll()
}
```

### 7. Test with Mock Services
Always test with mock services before hitting real backend.

### 8. Log Appropriately
```swift
print("✅ [Service] Success message")
print("⚠️ [Service] Warning message")
print("❌ [Service] Error message")
print("🔵 [MockService] Mock action")
```

---

## Quick Command Reference

### Generate Insight
```swift
try await aiInsightRepository.generateInsight(type: .weekly, context: nil)
```

### Create Goal with AI
```swift
let goal = try await goalRepository.create(title: "Goal", description: "Desc", category: .physical, targetDate: nil)
let suggestions = try await goalRepository.getAISuggestions(for: goal.id)
```

### Start Chat
```swift
let conversation = try await chatRepository.createConversation(title: "Chat", persona: .wellness, context: nil)
try await chatBackendService.connectWebSocket(conversationId: conversation.id, accessToken: token)
```

---

## Support

For more details, see:
- `PHASE_1_DOMAIN_COMPLETE.md` - Domain entities and protocols
- `PHASE_2_INFRASTRUCTURE_COMPLETE.md` - SwiftData and repositories
- `PHASE_3_BACKEND_SERVICES_COMPLETE.md` - Backend services
- `AI_FEATURES_STATUS.md` - Overall implementation status

---

**Last Updated:** 2025-01-29  
**Version:** 1.0