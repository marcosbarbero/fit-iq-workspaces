# Lume AI Features - Quick Start Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-28  
**Status:** Ready to implement  
**Estimated Time:** 3 weeks

---

## 🎯 What You're Building

Three interconnected AI-powered wellness features:

1. **AI Insights** - Personalized wellness insights based on mood, journal, and goals
2. **Goals AI** - AI-powered goal suggestions and actionable tips
3. **AI Chat** - Interactive wellness coach with multi-persona support

---

## 📦 What's Already Done

✅ **Domain Layer - Entities** (4 files created):
- `AIInsight.swift` - Wellness insight entity with types, context, metadata
- `GoalSuggestion.swift` - AI goal recommendation with difficulty, duration, rationale
- `ChatMessage.swift` - Chat message and conversation entities with personas
- `Goal.swift` - Already existed, extended with AI support

✅ **Domain Layer - Ports** (3 files created):
- `AIInsightRepositoryProtocol.swift` - Persistence interface for insights
- `AIInsightServiceProtocol.swift` - Backend service interface for insights
- `GoalAIServiceProtocol.swift` - Backend service interface for goal AI

✅ **Documentation**:
- `LUME_IMPLEMENTATION_PLAN.md` - Complete implementation plan (1000+ lines)
- This quick start guide
- Integration guide at `docs/goals-insights-consultations/README.md`

---

## 🚀 Implementation Roadmap

### Week 1: Foundation (Days 1-5)

#### Day 1-2: Complete Domain Layer
**Goal**: Finish all domain ports and use cases

**Tasks**:
```
⏳ Create ChatRepositoryProtocol.swift
⏳ Create ChatServiceProtocol.swift
⏳ Create FetchAIInsightsUseCase.swift
⏳ Create GenerateGoalSuggestionsUseCase.swift
⏳ Create GetGoalTipsUseCase.swift
⏳ Create SendChatMessageUseCase.swift
⏳ Create GenerateInsightUseCase.swift
```

**Time**: 2 days  
**Output**: Complete domain layer with zero dependencies on frameworks

---

#### Day 3-4: SwiftData Models
**Goal**: Create persistence layer

**Tasks**:
```
⏳ Create Data/Persistence/SDAIInsight.swift
⏳ Create Data/Persistence/SDChatMessage.swift
⏳ Create Data/Persistence/SDChatConversation.swift
⏳ Update Data/Migration/SchemaVersioning.swift (add SchemaV6)
⏳ Create Data/Repositories/AIInsightRepository.swift
⏳ Create Data/Repositories/ChatRepository.swift
```

**Example**: See `LUME_IMPLEMENTATION_PLAN.md` section "Phase 2: SwiftData Models"

**Time**: 2 days  
**Output**: Working persistence layer with migrations

---

#### Day 5: Backend Services
**Goal**: Create API integration with Outbox pattern

**Tasks**:
```
⏳ Create Data/Services/AIInsightService.swift
⏳ Create Data/Services/GoalAIService.swift
⏳ Create Data/Services/ChatService.swift
⏳ Update Services/OutboxProcessorService.swift (add AI events)
```

**Backend**: `https://fit-iq-backend.fly.dev`

**Time**: 1 day  
**Output**: Backend integration working

---

### Week 2: Features (Days 6-10)

#### Day 6-7: ViewModels
**Goal**: Create business logic layer for UI

**Tasks**:
```
⏳ Create Presentation/ViewModels/AIInsightsViewModel.swift
⏳ Create Presentation/ViewModels/InsightDetailViewModel.swift
⏳ Create Presentation/ViewModels/GoalSuggestionsViewModel.swift
⏳ Create Presentation/ViewModels/GoalTipsViewModel.swift
⏳ Create Presentation/ViewModels/ChatViewModel.swift
```

**Time**: 2 days  
**Output**: Testable ViewModels with use case dependencies

---

#### Day 8-10: Views
**Goal**: Create beautiful, calm UI following Lume design system

**Tasks**:
```
⏳ Create Presentation/Views/AIFeatures/Insights/AIInsightsListView.swift
⏳ Create Presentation/Views/AIFeatures/Insights/InsightDetailView.swift
⏳ Create Presentation/Views/AIFeatures/Insights/InsightCardView.swift
⏳ Create Presentation/Views/AIFeatures/Goals/GoalSuggestionsView.swift
⏳ Create Presentation/Views/AIFeatures/Goals/GoalTipsView.swift
⏳ Create Presentation/Views/AIFeatures/Goals/GoalSuggestionCardView.swift
⏳ Create Presentation/Views/AIFeatures/Chat/ChatView.swift
⏳ Create Presentation/Views/AIFeatures/Chat/ChatMessageView.swift
⏳ Create Presentation/Views/AIFeatures/Chat/ChatInputView.swift
⏳ Create Presentation/Views/AIFeatures/Chat/QuickActionsView.swift
```

**Design System**:
- Colors: `appBackground`, `surface`, `accentPrimary`, `accentSecondary`
- Typography: SF Pro Rounded (28pt, 22pt, 17pt, 15pt, 13pt)
- Spacing: 24pt margins, 16pt padding, 16pt corners
- Tone: Warm, calm, non-judgmental

**Time**: 3 days  
**Output**: Complete UI for all features

---

### Week 3: Integration & Testing (Days 11-15)

#### Day 11-12: Wire It All Together
**Goal**: Connect everything via dependency injection

**Tasks**:
```
⏳ Update DI/AppDependencies.swift
  - Add aiInsightRepository
  - Add aiInsightService
  - Add goalAIService
  - Add chatRepository
  - Add chatService
  - Add all use cases
  - Add ViewModel factory methods

⏳ Update Presentation/Views/Dashboard/DashboardView.swift
  - Add "AI Insights" card
  - Add "Goal Suggestions" button
  - Add "Chat" quick access

⏳ Update Presentation/Views/MainTabView.swift (if needed)
  - Add AI features tab (optional)
  - Or keep in Dashboard only
```

**Time**: 2 days  
**Output**: Fully integrated features in app

---

#### Day 13-15: Test & Polish
**Goal**: Production-ready quality

**Tasks**:
```
⏳ Unit tests for domain entities
⏳ Unit tests for use cases
⏳ Integration tests for repositories
⏳ UI tests for main flows
⏳ Test offline mode (Outbox pattern)
⏳ Test error scenarios
⏳ Polish animations
⏳ Test on real device
⏳ Performance optimization
⏳ Memory leak check
```

**Time**: 3 days  
**Output**: Production-ready AI features

---

## 📋 Prerequisites

### Backend Setup
1. **API Key**: Get from backend team
2. **Base URL**: `https://fit-iq-backend.fly.dev`
3. **Test Account**: Create test user for development

### iOS Setup
1. **Xcode 15+**
2. **iOS 17+ target**
3. **Swift 5.9+**
4. **SwiftUI + SwiftData**

### Dependencies
```swift
// Already in project
- URLSession (networking)
- SwiftUI (UI)
- SwiftData (persistence)
- Keychain (token storage)

// Need to add for chat
- Starscream (WebSocket) - Add via SPM
```

---

## 🎯 Critical Architecture Rules

### 1. Hexagonal Architecture
```
Presentation → Domain → Infrastructure
```
- Domain is pure Swift (no SwiftUI, no SwiftData)
- Domain defines protocols (ports)
- Infrastructure implements protocols
- Presentation depends only on Domain

### 2. SOLID Principles
- **Single Responsibility**: One class, one job
- **Open/Closed**: Extend via protocols, don't modify
- **Liskov Substitution**: Any implementation works
- **Interface Segregation**: Small, focused protocols
- **Dependency Inversion**: Depend on abstractions

### 3. Outbox Pattern
ALL external communication MUST use Outbox:
1. Create outbox event
2. Save to local database
3. Background processor sends to backend
4. Mark event as completed
5. Store result locally

Benefits: Offline support, no data loss, auto-retry

### 4. Dependency Injection
ALL dependencies via `AppDependencies`:
```swift
private(set) lazy var aiInsightService: AIInsightServiceProtocol = {
    AIInsightService(
        httpClient: httpClient,
        outboxRepository: outboxRepository,
        tokenStorage: tokenStorage
    )
}()

func makeAIInsightsViewModel() -> AIInsightsViewModel {
    AIInsightsViewModel(
        fetchInsightsUseCase: fetchAIInsightsUseCase,
        markAsReadUseCase: markInsightAsReadUseCase,
        toggleFavoriteUseCase: toggleInsightFavoriteUseCase
    )
}
```

---

## 🎨 Design Guidelines

### Colors (Lume Palette)
```swift
Color("appBackground")    // #F8F4EC - Main background
Color("surface")          // #E8DFD6 - Cards
Color("accentPrimary")    // #F2C9A7 - Primary actions
Color("accentSecondary")  // #D8C8EA - Secondary elements
Color("textPrimary")      // #3B332C - Main text
Color("textSecondary")    // #6E625A - Supporting text
```

### Typography
```swift
.font(.custom("SF Pro Rounded", size: 28))  // Title Large
.font(.custom("SF Pro Rounded", size: 22))  // Title Medium
.font(.custom("SF Pro Rounded", size: 17))  // Body
.font(.custom("SF Pro Rounded", size: 15))  // Body Small
.font(.custom("SF Pro Rounded", size: 13))  // Caption
```

### Spacing
```swift
.padding(.horizontal, 24)  // Screen margins
.padding(.vertical, 16)    // Vertical padding
.cornerRadius(16)          // Soft corners
```

### Emotional Tone
- ✅ Warm, calm, cozy
- ✅ Non-judgmental, supportive
- ✅ Clear, direct, honest
- ❌ No pressure, no guilt
- ❌ No medical claims
- ❌ No extreme language

---

## 📚 Key Documents

### Already Created
1. **LUME_IMPLEMENTATION_PLAN.md** - Complete 1000+ line implementation guide
2. **This file** - Quick start guide
3. **Domain entities** - 4 files with all data models
4. **Domain ports** - 3 protocols for services

### Backend Documentation
- **Main Guide**: `docs/goals-insights-consultations/README.md`
- **AI Insights**: `docs/goals-insights-consultations/features/ai-insights.md`
- **Goals AI**: `docs/goals-insights-consultations/features/goals-ai.md`
- **Chat**: `docs/goals-insights-consultations/ai-consultation/consultations-enhanced.md`
- **Swagger**: `https://fit-iq-backend.fly.dev/swagger/index.html`

### Architecture
- **Lume Rules**: `.github/copilot-instructions.md`
- **Architecture Overview**: `docs/ARCHITECTURE_OVERVIEW.md`

---

## 🔥 Quick Commands

### Start Implementation
```bash
# Open Xcode
open lume/lume.xcodeproj

# Verify existing files
ls lume/lume/Domain/Entities/AI*.swift
ls lume/lume/Domain/Entities/Goal*.swift
ls lume/lume/Domain/Entities/Chat*.swift
ls lume/lume/Domain/Ports/AI*.swift
ls lume/lume/Domain/Ports/Goal*.swift

# Start with Day 1 tasks (create remaining ports)
# See LUME_IMPLEMENTATION_PLAN.md Phase 1
```

### Test Backend
```bash
# Health check
curl https://fit-iq-backend.fly.dev/health

# Swagger UI (open in browser)
open https://fit-iq-backend.fly.dev/swagger/index.html
```

### Run App
```bash
# Build and run
cmd+R in Xcode

# Or via command line
xcodebuild -project lume/lume.xcodeproj -scheme lume -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

---

## ⚠️ Common Pitfalls

### 1. ❌ Skipping Hexagonal Architecture
**Don't**: Import SwiftData in Domain layer  
**Do**: Keep Domain pure Swift, use protocols

### 2. ❌ Ignoring Outbox Pattern
**Don't**: Call backend directly from ViewModel  
**Do**: Use Outbox for all external communication

### 3. ❌ Hardcoding Dependencies
**Don't**: Create dependencies inside ViewModels  
**Do**: Inject via AppDependencies

### 4. ❌ Inconsistent Design
**Don't**: Use random colors and fonts  
**Do**: Use Lume design system consistently

### 5. ❌ Poor Error Handling
**Don't**: Crash or show technical errors  
**Do**: Show user-friendly messages, log details

---

## 🎯 Success Criteria

### Week 1 ✅
- [ ] All domain layer complete (entities, ports, use cases)
- [ ] All SwiftData models working
- [ ] Backend services integrated
- [ ] No compilation errors
- [ ] Schema migration working

### Week 2 ✅
- [ ] All ViewModels implemented
- [ ] All Views following Lume design system
- [ ] Navigation working
- [ ] Basic functionality working
- [ ] No crashes

### Week 3 ✅
- [ ] All tests passing (unit, integration, UI)
- [ ] Offline mode working (Outbox)
- [ ] Error handling robust
- [ ] Performance acceptable
- [ ] Memory leaks fixed
- [ ] Ready for production

---

## 🚀 Next Steps

1. **Read the full plan**: Open `LUME_IMPLEMENTATION_PLAN.md`
2. **Understand the architecture**: Review hexagonal architecture section
3. **Check backend docs**: Read `docs/goals-insights-consultations/README.md`
4. **Start Day 1**: Create remaining domain ports (ChatRepository, ChatService)
5. **Work incrementally**: One phase at a time, test as you go

---

## 💡 Pro Tips

1. **Test early, test often** - Don't wait until the end
2. **Follow existing patterns** - Look at Mood/Journal implementations
3. **Use preview providers** - Test Views in Xcode previews
4. **Keep commits small** - One feature at a time
5. **Ask for help** - Review code with team regularly

---

## 📞 Need Help?

### Resources
- **Implementation Plan**: See `LUME_IMPLEMENTATION_PLAN.md` for detailed steps
- **Backend API**: Check Swagger at `https://fit-iq-backend.fly.dev/swagger`
- **Architecture**: Review `.github/copilot-instructions.md`
- **Design**: Check existing Views for patterns

### Contacts
- Backend questions → Backend team
- Architecture questions → Tech lead
- Design questions → Product designer
- Product questions → Product manager

---

**You're ready to build! Start with Week 1, Day 1. Good luck! 🌟**