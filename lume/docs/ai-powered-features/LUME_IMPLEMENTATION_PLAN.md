# Lume AI Features Implementation Plan

**Version:** 1.0.0  
**Last Updated:** 2025-01-28  
**Status:** Ready for Implementation  
**Backend:** FitIQ Backend v0.23.0 (`fit-iq-backend.fly.dev`)

---

## 📋 Executive Summary

This document provides a complete implementation plan for integrating three AI-powered features into the Lume iOS wellness app:

1. **AI Insights** - Personalized wellness insights based on mood, journal, and goals
2. **Goals AI** - AI-powered goal suggestions and actionable tips
3. **AI Consultation** - Interactive chat bot with multi-persona support

All features follow Lume's **hexagonal architecture** and **SOLID principles**, using the **Outbox pattern** for backend communication.

---

## 🎯 Goals and Benefits

### User Benefits
- **AI Insights**: Get personalized wellness insights weekly/monthly based on patterns
- **Goal Suggestions**: Receive intelligent goal recommendations based on current state
- **Goal Tips**: Get actionable advice for achieving specific goals
- **AI Chat**: Interactive support for wellness journey with contextual conversations

### Technical Benefits
- Clean hexagonal architecture (Domain → Infrastructure → Presentation)
- Offline-first with Outbox pattern
- Type-safe dependency injection
- Testable and maintainable code
- Consistent with existing Lume patterns

---

## 🏗️ Architecture Overview

### Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (Views + ViewModels - SwiftUI, ObservableObject)           │
│                                                              │
│  AIInsightsListView    GoalSuggestionsView    ChatView      │
│  InsightDetailView     GoalTipsView                         │
│         ↓                     ↓                    ↓         │
│  AIInsightsViewModel   GoalAIViewModel   ChatViewModel      │
└─────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  (Entities + Use Cases + Ports - Pure Swift, no frameworks) │
│                                                              │
│  Entities:                                                   │
│  - AIInsight, GoalSuggestion, GoalTip                       │
│  - ChatMessage, ChatConversation                            │
│                                                              │
│  Ports (Protocols):                                         │
│  - AIInsightRepositoryProtocol                              │
│  - AIInsightServiceProtocol                                 │
│  - GoalAIServiceProtocol                                    │
│  - ChatRepositoryProtocol                                   │
│  - ChatServiceProtocol                                      │
│                                                              │
│  Use Cases:                                                 │
│  - FetchAIInsightsUseCase                                   │
│  - GenerateGoalSuggestionsUseCase                           │
│  - GetGoalTipsUseCase                                       │
│  - SendChatMessageUseCase                                   │
└─────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  (SwiftData + Repositories + Services + API)                │
│                                                              │
│  SwiftData Models:                                          │
│  - SDAIInsight, SDChatMessage, SDChatConversation          │
│                                                              │
│  Repositories:                                              │
│  - AIInsightRepository, ChatRepository                      │
│                                                              │
│  Services (with Outbox pattern):                            │
│  - AIInsightService, GoalAIService, ChatService             │
│                                                              │
│  API Clients:                                               │
│  - FitIQ Backend REST API + WebSocket                       │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Hexagonal Architecture**: Domain is the center, dependencies point inward
2. **SOLID Principles**: Every class has one responsibility, depends on abstractions
3. **Outbox Pattern**: All external communication goes through outbox for resilience
4. **Dependency Injection**: All dependencies injected via `AppDependencies`
5. **Async/Await**: Modern Swift concurrency throughout
6. **SwiftUI + SwiftData**: Modern Apple frameworks

---

## 📦 File Structure

```
lume/
├── Domain/
│   ├── Entities/
│   │   ├── AIInsight.swift               ✅ CREATED
│   │   ├── GoalSuggestion.swift          ✅ CREATED
│   │   ├── ChatMessage.swift             ✅ CREATED
│   │   └── Goal.swift                    ✅ EXISTS
│   ├── Ports/
│   │   ├── AIInsightRepositoryProtocol.swift      ✅ CREATED
│   │   ├── AIInsightServiceProtocol.swift         ✅ CREATED
│   │   ├── GoalAIServiceProtocol.swift            ✅ CREATED
│   │   ├── ChatRepositoryProtocol.swift           ⏳ TODO
│   │   └── ChatServiceProtocol.swift              ⏳ TODO
│   └── UseCases/
│       ├── FetchAIInsightsUseCase.swift           ⏳ TODO
│       ├── GenerateGoalSuggestionsUseCase.swift   ⏳ TODO
│       ├── GetGoalTipsUseCase.swift               ⏳ TODO
│       ├── SendChatMessageUseCase.swift           ⏳ TODO
│       └── GenerateInsightUseCase.swift           ⏳ TODO
├── Data/
│   ├── Persistence/
│   │   ├── SDAIInsight.swift                      ⏳ TODO
│   │   ├── SDChatMessage.swift                    ⏳ TODO
│   │   └── SDChatConversation.swift               ⏳ TODO
│   ├── Repositories/
│   │   ├── AIInsightRepository.swift              ⏳ TODO
│   │   └── ChatRepository.swift                   ⏳ TODO
│   └── Services/
│       ├── AIInsightService.swift                 ⏳ TODO
│       ├── GoalAIService.swift                    ⏳ TODO
│       └── ChatService.swift                      ⏳ TODO
├── Presentation/
│   ├── ViewModels/
│   │   ├── AIInsightsViewModel.swift              ⏳ TODO
│   │   ├── InsightDetailViewModel.swift           ⏳ TODO
│   │   ├── GoalSuggestionsViewModel.swift         ⏳ TODO
│   │   ├── GoalTipsViewModel.swift                ⏳ TODO
│   │   └── ChatViewModel.swift                    ⏳ TODO
│   └── Views/
│       ├── AIFeatures/
│       │   ├── Insights/
│       │   │   ├── AIInsightsListView.swift       ⏳ TODO
│       │   │   ├── InsightDetailView.swift        ⏳ TODO
│       │   │   └── InsightCardView.swift          ⏳ TODO
│       │   ├── Goals/
│       │   │   ├── GoalSuggestionsView.swift      ⏳ TODO
│       │   │   ├── GoalTipsView.swift             ⏳ TODO
│       │   │   └── GoalSuggestionCardView.swift   ⏳ TODO
│       │   └── Chat/
│       │       ├── ChatView.swift                 ⏳ TODO
│       │       ├── ChatMessageView.swift          ⏳ TODO
│       │       ├── ChatInputView.swift            ⏳ TODO
│       │       └── QuickActionsView.swift         ⏳ TODO
│       └── Dashboard/
│           └── DashboardView.swift                ✅ EXISTS (update needed)
├── DI/
│   └── AppDependencies.swift                      ✅ EXISTS (update needed)
└── Core/
    └── Configuration/
        └── AppConfiguration.swift                 ✅ EXISTS
```

---

## 🚀 Implementation Phases

### Phase 1: Domain Layer (Week 1, Days 1-2)
**Goal**: Define all domain entities, ports, and use cases

**Tasks**:
- ✅ Create `AIInsight` entity
- ✅ Create `GoalSuggestion` and `GoalTip` entities
- ✅ Create `ChatMessage` and `ChatConversation` entities
- ✅ Create `AIInsightRepositoryProtocol` and `AIInsightServiceProtocol`
- ✅ Create `GoalAIServiceProtocol`
- ⏳ Create `ChatRepositoryProtocol` and `ChatServiceProtocol`
- ⏳ Create all use cases

**Deliverable**: Complete domain layer with all entities, ports, and use cases

---

### Phase 2: Infrastructure - SwiftData Models (Week 1, Days 3-4)
**Goal**: Create SwiftData models and repositories

**Tasks**:
- Create `SDAIInsight` SwiftData model
- Create `SDChatMessage` and `SDChatConversation` SwiftData models
- Create `AIInsightRepository` implementation
- Create `ChatRepository` implementation
- Update schema versioning in `SchemaVersioning.swift`
- Add migration plan if needed

**Example SwiftData Model**:
```swift
@Model
final class SDAIInsight {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var insightType: String
    var title: String
    var content: String
    var summary: String?
    var suggestionsJSON: Data?  // JSON encoded [String]
    var dataContextJSON: Data?  // JSON encoded InsightDataContext
    var isRead: Bool
    var isFavorite: Bool
    var isArchived: Bool
    var generatedAt: Date
    var readAt: Date?
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(from insight: AIInsight) {
        self.id = insight.id
        self.userId = insight.userId
        self.insightType = insight.insightType.rawValue
        self.title = insight.title
        self.content = insight.content
        self.summary = insight.summary
        // Encode suggestions as JSON
        if let suggestions = insight.suggestions {
            self.suggestionsJSON = try? JSONEncoder().encode(suggestions)
        }
        // Encode context as JSON
        if let context = insight.dataContext {
            self.dataContextJSON = try? JSONEncoder().encode(context)
        }
        self.isRead = insight.isRead
        self.isFavorite = insight.isFavorite
        self.isArchived = insight.isArchived
        self.generatedAt = insight.generatedAt
        self.readAt = insight.readAt
        self.archivedAt = insight.archivedAt
        self.createdAt = insight.createdAt
        self.updatedAt = insight.updatedAt
    }
    
    func toDomain() throws -> AIInsight {
        var suggestions: [String]?
        if let json = suggestionsJSON {
            suggestions = try? JSONDecoder().decode([String].self, from: json)
        }
        
        var dataContext: InsightDataContext?
        if let json = dataContextJSON {
            dataContext = try? JSONDecoder().decode(InsightDataContext.self, from: json)
        }
        
        return AIInsight(
            id: id,
            userId: userId,
            insightType: InsightType(rawValue: insightType) ?? .weekly,
            title: title,
            content: content,
            summary: summary,
            suggestions: suggestions,
            dataContext: dataContext,
            isRead: isRead,
            isFavorite: isFavorite,
            isArchived: isArchived,
            generatedAt: generatedAt,
            readAt: readAt,
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
```

**Deliverable**: Working SwiftData persistence layer

---

### Phase 3: Infrastructure - Backend Services (Week 1, Day 5 - Week 2, Day 1)
**Goal**: Implement backend API services with Outbox pattern

**Tasks**:
- Create `AIInsightService` with Outbox pattern
- Create `GoalAIService` with REST API calls
- Create `ChatService` with WebSocket support
- Integrate with existing `OutboxProcessorService`
- Add authentication headers to all requests

**Backend Endpoints**:
```
AI Insights:
GET  /api/v1/ai/insights              - List insights
GET  /api/v1/ai/insights/{id}         - Get insight
PUT  /api/v1/ai/insights/{id}         - Update insight
POST /api/v1/ai/insights/{id}/read    - Mark as read
POST /api/v1/ai/insights/{id}/favorite - Toggle favorite
POST /api/v1/ai/insights/{id}/archive  - Archive insight
DEL  /api/v1/ai/insights/{id}         - Delete insight

Goals AI:
GET  /api/v1/goals/ai/suggestions     - Get goal suggestions
GET  /api/v1/goals/{id}/ai/tips       - Get goal tips

Chat:
GET  /api/v1/consultations                    - List conversations
POST /api/v1/consultations                    - Create conversation
GET  /api/v1/consultations/{id}/messages      - Get messages
POST /api/v1/consultations/{id}/messages      - Send message
WS   /api/v1/consultations/{id}/stream        - WebSocket chat
```

**Example Service with Outbox**:
```swift
class AIInsightService: AIInsightServiceProtocol {
    let httpClient: HTTPClient
    let outboxRepository: OutboxRepositoryProtocol
    let tokenStorage: TokenStorageProtocol
    
    func fetchInsights(
        type: InsightType?,
        readStatus: Bool?,
        favoritesOnly: Bool,
        archivedStatus: Bool?,
        page: Int,
        pageSize: Int
    ) async throws -> [AIInsight] {
        // Get auth token
        guard let token = try await tokenStorage.getToken() else {
            throw ServiceError.unauthorized
        }
        
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/api/v1/ai/insights")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let type = type {
            queryItems.append(URLQueryItem(name: "insight_type", value: type.rawValue))
        }
        if let readStatus = readStatus {
            queryItems.append(URLQueryItem(name: "is_read", value: "\(readStatus)"))
        }
        if favoritesOnly {
            queryItems.append(URLQueryItem(name: "is_favorite", value: "true"))
        }
        if let archivedStatus = archivedStatus {
            queryItems.append(URLQueryItem(name: "is_archived", value: "\(archivedStatus)"))
        }
        
        components.queryItems = queryItems
        
        // Make request
        let response = try await httpClient.request(
            url: components.url!,
            method: .get,
            headers: ["Authorization": "Bearer \(token.accessToken)"]
        )
        
        // Parse response
        let apiResponse = try JSONDecoder().decode(InsightsResponse.self, from: response)
        return apiResponse.data.insights.map { $0.toDomain() }
    }
}
```

**Deliverable**: Working backend integration with Outbox pattern

---

### Phase 4: Presentation - ViewModels (Week 2, Days 2-3)
**Goal**: Create ViewModels for all features

**Tasks**:
- Create `AIInsightsViewModel`
- Create `InsightDetailViewModel`
- Create `GoalSuggestionsViewModel`
- Create `GoalTipsViewModel`
- Create `ChatViewModel`

**Example ViewModel**:
```swift
@MainActor
class AIInsightsViewModel: ObservableObject {
    @Published var insights: [AIInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: InsightType?
    @Published var showUnreadOnly = false
    @Published var showFavoritesOnly = false
    
    private let fetchInsightsUseCase: FetchAIInsightsUseCaseProtocol
    private let markAsReadUseCase: MarkInsightAsReadUseCaseProtocol
    private let toggleFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol
    
    init(
        fetchInsightsUseCase: FetchAIInsightsUseCaseProtocol,
        markAsReadUseCase: MarkInsightAsReadUseCaseProtocol,
        toggleFavoriteUseCase: ToggleInsightFavoriteUseCaseProtocol
    ) {
        self.fetchInsightsUseCase = fetchInsightsUseCase
        self.markAsReadUseCase = markAsReadUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
    }
    
    func loadInsights() async {
        isLoading = true
        errorMessage = nil
        
        do {
            insights = try await fetchInsightsUseCase.execute(
                type: selectedFilter,
                unreadOnly: showUnreadOnly,
                favoritesOnly: showFavoritesOnly
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func toggleFavorite(insight: AIInsight) async {
        do {
            let updated = try await toggleFavoriteUseCase.execute(id: insight.id)
            if let index = insights.firstIndex(where: { $0.id == insight.id }) {
                insights[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

**Deliverable**: Complete ViewModels for all features

---

### Phase 5: Presentation - Views (Week 2, Days 4-5)
**Goal**: Create SwiftUI views following Lume design system

**Tasks**:
- Create AI Insights views
- Create Goal Suggestions views
- Create Chat views
- Apply Lume color palette and typography
- Implement warm, calm design language

**Design Guidelines**:
```swift
// Colors (from Lume palette)
Color("appBackground")    // #F8F4EC
Color("surface")          // #E8DFD6
Color("accentPrimary")    // #F2C9A7
Color("accentSecondary")  // #D8C8EA
Color("textPrimary")      // #3B332C
Color("textSecondary")    // #6E625A

// Typography
.font(.custom("SF Pro Rounded", size: 28))  // Title Large
.font(.custom("SF Pro Rounded", size: 22))  // Title Medium
.font(.custom("SF Pro Rounded", size: 17))  // Body
.font(.custom("SF Pro Rounded", size: 15))  // Body Small
.font(.custom("SF Pro Rounded", size: 13))  // Caption

// Spacing
.padding(.horizontal, 24)  // Generous margins
.padding(.vertical, 16)
.cornerRadius(16)          // Soft corners
```

**Example View**:
```swift
struct AIInsightsListView: View {
    @StateObject var viewModel: AIInsightsViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("appBackground")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Filter bar
                        filterBar
                        
                        // Insights list
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if viewModel.insights.isEmpty {
                            emptyState
                        } else {
                            insightsList
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadInsights()
            }
        }
    }
    
    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: viewModel.selectedFilter == nil
                ) {
                    viewModel.selectedFilter = nil
                    Task { await viewModel.loadInsights() }
                }
                
                ForEach(InsightType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        icon: type.systemImage,
                        isSelected: viewModel.selectedFilter == type
                    ) {
                        viewModel.selectedFilter = type
                        Task { await viewModel.loadInsights() }
                    }
                }
            }
        }
    }
    
    var insightsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.insights) { insight in
                NavigationLink {
                    InsightDetailView(insight: insight)
                } label: {
                    InsightCardView(insight: insight)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(Color("accentPrimary"))
            
            Text("No insights yet")
                .font(.custom("SF Pro Rounded", size: 22))
                .foregroundColor(Color("textPrimary"))
            
            Text("Check back later for personalized wellness insights")
                .font(.custom("SF Pro Rounded", size: 15))
                .foregroundColor(Color("textSecondary"))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

**Deliverable**: Complete UI for all AI features

---

### Phase 6: Integration (Week 3, Days 1-2)
**Goal**: Wire everything together in AppDependencies

**Tasks**:
- Update `AppDependencies` with AI feature dependencies
- Add factory methods for all ViewModels
- Update schema versioning
- Add AI features to Dashboard
- Update MainTabView navigation

**AppDependencies Updates**:
```swift
extension AppDependencies {
    // MARK: - AI Insight Dependencies
    
    private(set) lazy var aiInsightRepository: AIInsightRepositoryProtocol = {
        AIInsightRepository(
            modelContext: modelContext,
            outboxRepository: outboxRepository
        )
    }()
    
    private(set) lazy var aiInsightService: AIInsightServiceProtocol = {
        AIInsightService(
            httpClient: httpClient,
            outboxRepository: outboxRepository,
            tokenStorage: tokenStorage
        )
    }()
    
    private(set) lazy var fetchAIInsightsUseCase: FetchAIInsightsUseCaseProtocol = {
        FetchAIInsightsUseCase(
            repository: aiInsightRepository,
            service: aiInsightService
        )
    }()
    
    func makeAIInsightsViewModel() -> AIInsightsViewModel {
        AIInsightsViewModel(
            fetchInsightsUseCase: fetchAIInsightsUseCase,
            markAsReadUseCase: markInsightAsReadUseCase,
            toggleFavoriteUseCase: toggleInsightFavoriteUseCase
        )
    }
    
    // MARK: - Goal AI Dependencies
    
    private(set) lazy var goalAIService: GoalAIServiceProtocol = {
        GoalAIService(
            httpClient: httpClient,
            tokenStorage: tokenStorage
        )
    }()
    
    private(set) lazy var generateGoalSuggestionsUseCase: GenerateGoalSuggestionsUseCaseProtocol = {
        GenerateGoalSuggestionsUseCase(
            service: goalAIService,
            moodRepository: moodRepository,
            journalRepository: journalRepository,
            goalRepository: goalRepository
        )
    }()
    
    func makeGoalSuggestionsViewModel() -> GoalSuggestionsViewModel {
        GoalSuggestionsViewModel(
            generateSuggestionsUseCase: generateGoalSuggestionsUseCase,
            createGoalUseCase: createGoalUseCase
        )
    }
    
    // MARK: - Chat Dependencies
    
    private(set) lazy var chatRepository: ChatRepositoryProtocol = {
        ChatRepository(modelContext: modelContext)
    }()
    
    private(set) lazy var chatService: ChatServiceProtocol = {
        ChatService(
            httpClient: httpClient,
            tokenStorage: tokenStorage,
            outboxRepository: outboxRepository
        )
    }()
    
    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            chatRepository: chatRepository,
            chatService: chatService,
            sendMessageUseCase: sendChatMessageUseCase
        )
    }
}
```

**Deliverable**: Fully integrated AI features in app

---

### Phase 7: Testing & Polish (Week 3, Days 3-5)
**Goal**: Test, fix bugs, polish UX

**Tasks**:
- Unit tests for use cases
- Integration tests for repositories
- UI tests for main flows
- Test offline functionality with Outbox pattern
- Polish animations and transitions
- Test error handling
- Performance optimization

**Test Coverage**:
- ✅ Domain entities (pure Swift, easy to test)
- ✅ Use cases with mocked repositories
- ✅ Repositories with in-memory SwiftData
- ✅ ViewModels with mocked use cases
- ✅ End-to-end flows with UI tests

**Deliverable**: Production-ready AI features

---

## 🔐 Security & Privacy

### API Key Management
- Store API key in `config.plist`
- Access via `AppConfiguration.shared.apiKey`
- Never log or expose in errors

### Token Management
- Use existing `TokenStorageProtocol` (Keychain)
- Auto-refresh tokens before expiration
- Handle 401 errors gracefully

### Data Privacy
- All user data encrypted in transit (HTTPS)
- SwiftData encrypts at rest (iOS default)
- Clear user consent for AI features
- Option to disable AI in settings

### WebSocket Security
- WSS (secure WebSocket) only
- Include auth token in connection
- Implement reconnection with exponential backoff
- Handle connection drops gracefully

---

## 📊 Success Metrics

### User Engagement
- % users who view AI insights (target: 70%+)
- % users who favorite insights (target: 30%+)
- % users who try goal suggestions (target: 40%+)
- % users who create goals from suggestions (target: 20%+)
- Chat sessions per week (target: 2+)

### Technical Metrics
- Outbox success rate (target: 99%+)
- API response time p95 (target: <2s)
- Crash-free sessions (target: 99.9%+)
- Offline functionality works (target: 100%)

### Quality Metrics
- User satisfaction with AI responses (target: 4+/5)
- Feature retention after 1 week (target: 60%+)
- Feature retention after 1 month (target: 40%+)

---

## 🚨 Known Challenges & Solutions

### Challenge 1: Large Context for AI
**Problem**: Sending too much data to AI service costs money and time  
**Solution**: 
- Build smart `UserContextBuilder` that summarizes data
- Limit context to last 30 days by default
- Send only relevant data for each insight type
- Cache insights locally to reduce API calls

### Challenge 2: WebSocket Reliability
**Problem**: Chat connections can drop  
**Solution**:
- Implement automatic reconnection with backoff
- Store messages locally before sending (Outbox)
- Show connection status to user
- Fall back to REST API if WebSocket fails

### Challenge 3: Schema Migration
**Problem**: Adding new SwiftData models requires migration  
**Solution**:
- Use Lume's existing `SchemaVersioning` system
- Create SchemaV6 with new models
- Add lightweight migration plan
- Test migration thoroughly

### Challenge 4: Offline Support
**Problem**: AI features require backend  
**Solution**:
- Cache insights locally with SwiftData
- Use Outbox pattern for requests
- Show cached data while offline
- Sync when connection restored

---

## 🎯 Acceptance Criteria

### Phase 1-2: Infrastructure Complete
- [ ] All domain entities created and tested
- [ ] All ports (protocols) defined
- [ ] All use cases implemented
- [ ] SwiftData models working with migrations
- [ ] Repositories persisting data correctly

### Phase 3: Backend Integration Complete
- [ ] AI Insights API working
- [ ] Goal Suggestions API working
- [ ] Goal Tips API working
- [ ] Chat WebSocket working
- [ ] Outbox pattern handling all requests
- [ ] Error handling for all API calls

### Phase 4-5: UI Complete
- [ ] AI Insights list view working
- [ ] Insight detail view working
- [ ] Goal Suggestions view working
- [ ] Goal Tips view working
- [ ] Chat view working
- [ ] All views follow Lume design system
- [ ] Navigation working correctly

### Phase 6: Integration Complete
- [ ] AppDependencies wired up
- [ ] All ViewModels injected correctly
- [ ] Features accessible from Dashboard
- [ ] Navigation between features working
- [ ] Data flowing correctly between layers

### Phase 7: Production Ready
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] UI tests for main flows passing
- [ ] No memory leaks
- [ ] Performance acceptable
- [ ] Error handling robust
- [ ] Offline mode working
- [ ] User documentation complete

---

## 📚 API Reference

### Backend Base URL
```
https://fit-iq-backend.fly.dev
```

### Authentication
All requests require Bearer token:
```
Authorization: Bearer <access_token>
```

### Endpoints Summary

#### AI Insights
```
GET    /api/v1/ai/insights
GET    /api/v1/ai/insights/{id}
PUT    /api/v1/ai/insights/{id}
POST   /api/v1/ai/insights/{id}/read
POST   /api/v1/ai/insights/{id}/favorite
POST   /api/v1/ai/insights/{id}/archive
DELETE /api/v1/ai/insights/{id}
```

#### Goals AI
```
GET    /api/v1/goals/ai/suggestions
GET    /api/v1/goals/{id}/ai/tips
```

#### Chat
```
GET    /api/v1/consultations
POST   /api/v1/consultations
GET    /api/v1/consultations/{id}/messages
POST   /api/v1/consultations/{id}/messages
WS     /api/v1/consultations/{id}/stream
```

### Response Format
All responses follow this structure:
```json
{
  "success": true,
  "data": { ... }
}
```

Errors:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

---

## 🎨 Design System Integration

### Colors
Use Lume's existing color palette:
- `appBackground` (#F8F4EC) - Main backgrounds
- `surface` (#E8DFD6) - Cards and elevated surfaces
- `accentPrimary` (#F2C9A7) - Primary actions
- `accentSecondary` (#D8C8EA) - Secondary elements
- `textPrimary` (#3B332C) - Main text
- `textSecondary` (#6E625A) - Supporting text

### Typography
Use SF Pro Rounded:
- Title Large: 28pt, bold
- Title Medium: 22pt, semibold
- Body: 17pt, regular
- Body Small: 15pt, regular
- Caption: 13pt, regular

### Spacing
- Screen padding: 24pt horizontal, 16pt vertical
- Card spacing: 12-16pt between cards
- Internal padding: 16pt inside cards
- Corner radius: 16pt for cards, 12pt for buttons

### Tone
- Warm and calm
- Non-judgmental
- Encouraging without pressure
- Clear and direct
- Use "you" and "your" (personal)

---

## 🔄 Migration Strategy

### Current Schema: SchemaV5
Existing models:
- SDUser, SDMoodEntry, SDJournalEntry, SDGoal, SDOutboxEvent

### New Schema: SchemaV6
Add models:
- SDAIInsight, SDChatMessage, SDChatConversation

### Migration Steps
1. Create SchemaV6 in `SchemaVersioning.swift`
2. Add new models to schema
3. Create lightweight migration (additive only)
4. Test migration on development device
5. Test migration on production-like data
6. Update `AppDependencies` to use SchemaV6

**Migration is additive** - no data loss, just adding tables.

---

## 📖 Documentation

### User Documentation Needed
- [ ] AI Insights feature guide
- [ ] Goal Suggestions guide
- [ ] Chat bot usage guide
- [ ] Privacy policy update (AI usage)
- [ ] FAQ for AI features

### Developer Documentation
- [x] This implementation plan
- [ ] API integration guide (reference FitIQ docs)
- [ ] Architecture decisions document
- [ ] Testing guide
- [ ] Troubleshooting guide

---

## 🚀 Deployment Checklist

### Pre-Launch
- [ ] All tests passing
- [ ] Performance benchmarked
- [ ] Memory leaks checked
- [ ] Error handling tested
- [ ] Offline mode tested
- [ ] Privacy policy updated
- [ ] User documentation complete

### Launch
- [ ] Feature flags enabled
- [ ] Analytics tracking added
- [ ] Monitoring dashboards ready
- [ ] Support team trained
- [ ] Rollback plan ready

### Post-Launch
- [ ] Monitor crash rates
- [ ] Monitor API usage
- [ ] Monitor user engagement
- [ ] Collect user feedback
- [ ] Iterate based on data

---

## 🎯 Next Steps

1. **Review this plan** with team
2. **Start Phase 1** - Complete domain layer
3. **Build incrementally** - One phase at a time
4. **Test continuously** - Don't wait until the end
5. **Gather feedback** - From users and stakeholders
6. **Iterate and improve** - Based on real usage

---

## 📞 Support & Resources

### Documentation
- FitIQ Integration Guide: `docs/goals-insights-consultations/README.md`
- Lume Architecture: `.github/copilot-instructions.md`
- Swagger API: `https://fit-iq-backend.fly.dev/swagger/index.html`

### Team Contacts
- Backend questions → Backend team
- Architecture questions → Tech lead
- UX questions → Product designer
- Product questions → Product manager

---

**Ready to build? Let's create an amazing AI-powered wellness experience! 🌟**