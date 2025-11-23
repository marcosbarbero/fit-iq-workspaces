# Lume AI Features - Files Checklist

**Last Updated:** 2025-01-28  
**Total Files:** 37  
**Completed:** 7 (19%)  
**Remaining:** 30 (81%)

---

## ✅ Completed Files (7)

### Domain/Entities (4 files)
- ✅ `lume/lume/Domain/Entities/AIInsight.swift` (248 lines)
- ✅ `lume/lume/Domain/Entities/GoalSuggestion.swift` (292 lines)
- ✅ `lume/lume/Domain/Entities/ChatMessage.swift` (387 lines)
- ✅ `lume/lume/Domain/Entities/Goal.swift` (EXISTS - already in project)

### Domain/Ports (3 files)
- ✅ `lume/lume/Domain/Ports/AIInsightRepositoryProtocol.swift` (101 lines)
- ✅ `lume/lume/Domain/Ports/AIInsightServiceProtocol.swift` (158 lines)
- ✅ `lume/lume/Domain/Ports/GoalAIServiceProtocol.swift` (194 lines)

---

## ⏳ Phase 1: Domain Layer (8 files remaining)

### Domain/Ports (2 files)
- [ ] `lume/lume/Domain/Ports/ChatRepositoryProtocol.swift`
  - **Lines:** ~150
  - **Time:** 2 hours
  - **Description:** Protocol for chat persistence operations
  - **Methods:** CRUD for conversations and messages, filtering, search

- [ ] `lume/lume/Domain/Ports/ChatServiceProtocol.swift`
  - **Lines:** ~120
  - **Time:** 2 hours
  - **Description:** Protocol for chat backend service
  - **Methods:** REST API calls, WebSocket streaming, connection management

### Domain/UseCases (6 files)
- [ ] `lume/lume/Domain/UseCases/AI/FetchAIInsightsUseCase.swift`
  - **Lines:** ~120
  - **Time:** 2 hours
  - **Description:** Fetch and sync insights from backend
  - **Dependencies:** AIInsightRepository, AIInsightService

- [ ] `lume/lume/Domain/UseCases/AI/MarkInsightAsReadUseCase.swift`
  - **Lines:** ~80
  - **Time:** 1 hour
  - **Description:** Mark insight as read locally and sync to backend
  - **Dependencies:** AIInsightRepository, AIInsightService

- [ ] `lume/lume/Domain/UseCases/AI/ToggleInsightFavoriteUseCase.swift`
  - **Lines:** ~80
  - **Time:** 1 hour
  - **Description:** Toggle favorite status and sync
  - **Dependencies:** AIInsightRepository, AIInsightService

- [ ] `lume/lume/Domain/UseCases/Goals/GenerateGoalSuggestionsUseCase.swift`
  - **Lines:** ~150
  - **Time:** 3 hours
  - **Description:** Build context and generate AI goal suggestions
  - **Dependencies:** GoalAIService, MoodRepository, JournalRepository, GoalRepository

- [ ] `lume/lume/Domain/UseCases/Goals/GetGoalTipsUseCase.swift`
  - **Lines:** ~100
  - **Time:** 2 hours
  - **Description:** Get AI tips for specific goal
  - **Dependencies:** GoalAIService, GoalRepository

- [ ] `lume/lume/Domain/UseCases/Chat/SendChatMessageUseCase.swift`
  - **Lines:** ~120
  - **Time:** 2 hours
  - **Description:** Send message via Outbox pattern
  - **Dependencies:** ChatRepository, ChatService, OutboxRepository

---

## ⏳ Phase 2: Infrastructure - SwiftData (5 files)

### Data/Persistence (3 files)
- [ ] `lume/lume/Data/Persistence/SDAIInsight.swift`
  - **Lines:** ~200
  - **Time:** 4 hours
  - **Description:** SwiftData model for AI insights
  - **Features:** @Model, JSON encoding for arrays, toDomain() conversion

- [ ] `lume/lume/Data/Persistence/SDChatMessage.swift`
  - **Lines:** ~150
  - **Time:** 3 hours
  - **Description:** SwiftData model for chat messages
  - **Features:** @Model, metadata encoding, relationships

- [ ] `lume/lume/Data/Persistence/SDChatConversation.swift`
  - **Lines:** ~180
  - **Time:** 3 hours
  - **Description:** SwiftData model for conversations
  - **Features:** @Model, message relationships, context encoding

### Data/Migration (1 file)
- [ ] `lume/lume/Data/Migration/SchemaVersioning.swift` (UPDATE EXISTING)
  - **Changes:** Add SchemaV6 with new models
  - **Time:** 2 hours
  - **Description:** Update schema versioning and migration plan
  - **Tasks:** Define V6, add migration from V5 to V6

### Data/Repositories (1 file - AIInsight)
- [ ] `lume/lume/Data/Repositories/AIInsightRepository.swift`
  - **Lines:** ~300
  - **Time:** 4 hours
  - **Description:** Implementation of AIInsightRepositoryProtocol
  - **Methods:** All CRUD operations, filtering, sorting

---

## ⏳ Phase 2: Infrastructure - Repositories (1 file)

### Data/Repositories (1 file - Chat)
- [ ] `lume/lume/Data/Repositories/ChatRepository.swift`
  - **Lines:** ~350
  - **Time:** 5 hours
  - **Description:** Implementation of ChatRepositoryProtocol
  - **Methods:** Conversation and message CRUD, filtering, search

---

## ⏳ Phase 3: Infrastructure - Services (3 files)

### Data/Services (3 files)
- [ ] `lume/lume/Data/Services/AIInsightService.swift`
  - **Lines:** ~400
  - **Time:** 6 hours
  - **Description:** Backend service for AI insights with Outbox pattern
  - **Features:** REST API calls, authentication, Outbox integration, error handling

- [ ] `lume/lume/Data/Services/GoalAIService.swift`
  - **Lines:** ~300
  - **Time:** 4 hours
  - **Description:** Backend service for goal suggestions and tips
  - **Features:** REST API calls, DTO conversion, context building

- [ ] `lume/lume/Data/Services/ChatService.swift`
  - **Lines:** ~500
  - **Time:** 8 hours
  - **Description:** Backend service for chat with WebSocket
  - **Features:** REST API, WebSocket streaming, Outbox pattern, reconnection logic

---

## ⏳ Phase 4: Presentation - ViewModels (5 files)

### Presentation/ViewModels/AI (5 files)
- [ ] `lume/lume/Presentation/ViewModels/AI/AIInsightsViewModel.swift`
  - **Lines:** ~250
  - **Time:** 4 hours
  - **Description:** ViewModel for insights list
  - **Features:** Filtering, pagination, favorite/read actions, loading states

- [ ] `lume/lume/Presentation/ViewModels/AI/InsightDetailViewModel.swift`
  - **Lines:** ~150
  - **Time:** 2 hours
  - **Description:** ViewModel for single insight detail
  - **Features:** Mark as read, toggle favorite, archive, share

- [ ] `lume/lume/Presentation/ViewModels/Goals/GoalSuggestionsViewModel.swift`
  - **Lines:** ~200
  - **Time:** 3 hours
  - **Description:** ViewModel for goal suggestions
  - **Features:** Load suggestions, create goal from suggestion, refresh

- [ ] `lume/lume/Presentation/ViewModels/Goals/GoalTipsViewModel.swift`
  - **Lines:** ~150
  - **Time:** 2 hours
  - **Description:** ViewModel for goal tips
  - **Features:** Load tips for goal, filter by category/priority

- [ ] `lume/lume/Presentation/ViewModels/Chat/ChatViewModel.swift`
  - **Lines:** ~350
  - **Time:** 6 hours
  - **Description:** ViewModel for chat interface
  - **Features:** Send messages, WebSocket connection, persona selection, quick actions

---

## ⏳ Phase 5: Presentation - Views (10 files)

### Presentation/Views/AIFeatures/Insights (3 files)
- [ ] `lume/lume/Presentation/Views/AIFeatures/Insights/AIInsightsListView.swift`
  - **Lines:** ~300
  - **Time:** 5 hours
  - **Description:** Main insights list with filters
  - **Features:** Filter bar, insight cards, pull to refresh, empty state

- [ ] `lume/lume/Presentation/Views/AIFeatures/Insights/InsightDetailView.swift`
  - **Lines:** ~350
  - **Time:** 5 hours
  - **Description:** Full insight detail view
  - **Features:** Content display, suggestions list, context metrics, actions

- [ ] `lume/lume/Presentation/Views/AIFeatures/Insights/InsightCardView.swift`
  - **Lines:** ~150
  - **Time:** 2 hours
  - **Description:** Reusable insight card component
  - **Features:** Icon, title, summary, badges, tap action

### Presentation/Views/AIFeatures/Goals (3 files)
- [ ] `lume/lume/Presentation/Views/AIFeatures/Goals/GoalSuggestionsView.swift`
  - **Lines:** ~250
  - **Time:** 4 hours
  - **Description:** Goal suggestions list
  - **Features:** Suggestion cards, create goal action, refresh

- [ ] `lume/lume/Presentation/Views/AIFeatures/Goals/GoalTipsView.swift`
  - **Lines:** ~250
  - **Time:** 4 hours
  - **Description:** Tips for specific goal
  - **Features:** Tip list, category filtering, priority badges

- [ ] `lume/lume/Presentation/Views/AIFeatures/Goals/GoalSuggestionCardView.swift`
  - **Lines:** ~200
  - **Time:** 3 hours
  - **Description:** Reusable goal suggestion card
  - **Features:** Difficulty badge, duration, rationale, create button

### Presentation/Views/AIFeatures/Chat (4 files)
- [ ] `lume/lume/Presentation/Views/AIFeatures/Chat/ChatView.swift`
  - **Lines:** ~350
  - **Time:** 6 hours
  - **Description:** Main chat interface
  - **Features:** Message list, input field, persona selector, quick actions

- [ ] `lume/lume/Presentation/Views/AIFeatures/Chat/ChatMessageView.swift`
  - **Lines:** ~200
  - **Time:** 3 hours
  - **Description:** Individual message bubble
  - **Features:** User/assistant styling, timestamp, avatar

- [ ] `lume/lume/Presentation/Views/AIFeatures/Chat/ChatInputView.swift`
  - **Lines:** ~150
  - **Time:** 2 hours
  - **Description:** Message input field with send button
  - **Features:** Text field, send button, character count, voice input (optional)

- [ ] `lume/lume/Presentation/Views/AIFeatures/Chat/QuickActionsView.swift`
  - **Lines:** ~150
  - **Time:** 2 hours
  - **Description:** Quick action buttons for common prompts
  - **Features:** Action buttons, icons, tap handlers

---

## ⏳ Phase 6: Integration (2 files)

### DI (1 file - update existing)
- [ ] `lume/lume/DI/AppDependencies.swift` (UPDATE EXISTING)
  - **Changes:** Add ~200 lines
  - **Time:** 4 hours
  - **Description:** Wire up all AI feature dependencies
  - **Tasks:** Add repositories, services, use cases, ViewModel factories

### Presentation/Views/Dashboard (1 file - update existing)
- [ ] `lume/lume/Presentation/Views/Dashboard/DashboardView.swift` (UPDATE EXISTING)
  - **Changes:** Add ~100 lines
  - **Time:** 2 hours
  - **Description:** Add AI feature cards and navigation
  - **Tasks:** Add insights card, goal suggestions button, chat access

---

## 📊 Summary by Phase

| Phase | Total Files | Lines | Estimated Time |
|-------|-------------|-------|----------------|
| Phase 1: Domain | 8 | ~950 | 1.5 days |
| Phase 2: SwiftData | 5 | ~1,130 | 2 days |
| Phase 3: Services | 3 | ~1,200 | 2.5 days |
| Phase 4: ViewModels | 5 | ~1,100 | 2 days |
| Phase 5: Views | 10 | ~2,350 | 4.5 days |
| Phase 6: Integration | 2 | ~300 | 0.5 days |
| **TOTAL** | **33** | **~7,030** | **13 days** |

**Plus Testing & Polish:** 3 days  
**GRAND TOTAL:** ~16 days (3+ weeks)

---

## 🎯 Priority Order

### Week 1 (Days 1-5)
1. Complete Phase 1: Domain Layer (2 ports + 6 use cases)
2. Complete Phase 2: SwiftData Models + Repositories
3. Start Phase 3: Backend Services

### Week 2 (Days 6-10)
4. Complete Phase 3: Backend Services
5. Complete Phase 4: ViewModels
6. Start Phase 5: Views (Insights first)

### Week 3 (Days 11-15)
7. Complete Phase 5: All Views
8. Complete Phase 6: Integration
9. Testing & Polish

---

## 🚀 Quick Commands

```bash
# Check completed files
ls -la lume/lume/Domain/Entities/AI*.swift
ls -la lume/lume/Domain/Entities/Goal*.swift
ls -la lume/lume/Domain/Entities/Chat*.swift
ls -la lume/lume/Domain/Ports/AI*.swift
ls -la lume/lume/Domain/Ports/Goal*.swift

# Count completed vs total
echo "Completed: 7 files"
echo "Remaining: 30 files"
echo "Progress: 19%"

# Start next file
# Create: lume/lume/Domain/Ports/ChatRepositoryProtocol.swift
```

---

## 📝 Notes

### File Organization
- All AI features grouped under `AIFeatures/` in Views
- Use cases organized by feature: `AI/`, `Goals/`, `Chat/`
- Services in `Data/Services/`
- Repositories in `Data/Repositories/`

### Naming Conventions
- Protocols end with `Protocol`
- SwiftData models start with `SD`
- ViewModels end with `ViewModel`
- Views end with `View`

### Dependencies
- Domain depends on nothing
- Infrastructure depends on Domain
- Presentation depends on Domain only
- All layers use protocols (ports)

---

**Last Updated:** 2025-01-28  
**Next File:** `ChatRepositoryProtocol.swift`  
**Progress:** 19% (7/37 files)