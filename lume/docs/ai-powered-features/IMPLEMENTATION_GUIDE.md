# Lume AI Features - Implementation Quick Start Guide

**Version:** 1.0.0  
**Last Updated:** 2025-01-15

---

## Overview

This guide provides step-by-step instructions for implementing the three AI features in Lume:
1. Goals Management
2. AI Insights
3. AI Consultant Chat

Follow these steps in order for the smoothest implementation experience.

---

## Prerequisites

- [x] Backend API supports AI endpoints (or plan to use external AI service)
- [ ] AI API key secured in Keychain
- [ ] Updated `config.plist` with AI configuration
- [ ] Reviewed main design document: `AI_FEATURES_DESIGN.md`

---

## Week 1: Goals Foundation

### Day 1-2: Domain & Infrastructure

#### Step 1: Create SwiftData Models

**File:** `lume/Data/Persistence/SwiftData/SDGoal.swift`

```swift
import Foundation
import SwiftData

@Model
final class SDGoal {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var title: String
    var goalDescription: String
    var createdAt: Date
    var updatedAt: Date
    var targetDate: Date?
    var progress: Double
    var status: String
    var category: String
    
    init(from goal: Goal) {
        self.id = goal.id
        self.userId = goal.userId
        self.title = goal.title
        self.goalDescription = goal.description
        self.createdAt = goal.createdAt
        self.updatedAt = goal.updatedAt
        self.targetDate = goal.targetDate
        self.progress = goal.progress
        self.status = goal.status.rawValue
        self.category = goal.category.rawValue
    }
    
    func toDomain() -> Goal {
        Goal(
            id: id,
            userId: userId,
            title: title,
            description: goalDescription,
            createdAt: createdAt,
            updatedAt: updatedAt,
            targetDate: targetDate,
            progress: progress,
            status: GoalStatus(rawValue: status) ?? .active,
            category: GoalCategory(rawValue: category) ?? .general
        )
    }
}
```

#### Step 2: Implement Goal Repository

**File:** `lume/Data/Repositories/GoalRepository.swift`

```swift
import Foundation
import SwiftData

final class GoalRepository: GoalRepositoryProtocol {
    private let modelContext: ModelContext
    private let currentUserId: UUID
    
    init(modelContext: ModelContext, currentUserId: UUID) {
        self.modelContext = modelContext
        self.currentUserId = currentUserId
    }
    
    func create(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal {
        let goal = Goal(
            userId: currentUserId,
            title: title,
            description: description,
            targetDate: targetDate,
            category: category
        )
        
        let sdGoal = SDGoal(from: goal)
        modelContext.insert(sdGoal)
        try modelContext.save()
        
        return goal
    }
    
    func fetchAll() async throws -> [Goal] {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { $0.userId == currentUserId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }
    
    func fetchActive() async throws -> [Goal] {
        let descriptor = FetchDescriptor<SDGoal>(
            predicate: #Predicate { 
                $0.userId == currentUserId && $0.status == "active" 
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDomain() }
    }
    
    // Implement remaining methods...
}
```

#### Step 3: Create Use Cases

**File:** `lume/Domain/UseCases/Goals/CreateGoalUseCase.swift`

```swift
import Foundation

protocol CreateGoalUseCaseProtocol {
    func execute(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal
}

final class CreateGoalUseCase: CreateGoalUseCaseProtocol {
    private let goalRepository: GoalRepositoryProtocol
    
    init(goalRepository: GoalRepositoryProtocol) {
        self.goalRepository = goalRepository
    }
    
    func execute(
        title: String,
        description: String,
        category: GoalCategory,
        targetDate: Date?
    ) async throws -> Goal {
        // Validation
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GoalError.emptyTitle
        }
        
        // Create goal
        return try await goalRepository.create(
            title: title,
            description: description,
            category: category,
            targetDate: targetDate
        )
    }
}
```

### Day 3-4: Presentation Layer

#### Step 4: Create ViewModels

**File:** `lume/Presentation/Features/Goals/ViewModels/GoalListViewModel.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
final class GoalListViewModel {
    var activeGoals: [Goal] = []
    var completedGoals: [Goal] = []
    var archivedGoals: [Goal] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var showingCreateGoal: Bool = false
    
    private let fetchGoalsUseCase: FetchGoalsUseCaseProtocol
    private let completeGoalUseCase: CompleteGoalUseCaseProtocol
    
    init(
        fetchGoalsUseCase: FetchGoalsUseCaseProtocol,
        completeGoalUseCase: CompleteGoalUseCaseProtocol
    ) {
        self.fetchGoalsUseCase = fetchGoalsUseCase
        self.completeGoalUseCase = completeGoalUseCase
    }
    
    func loadGoals() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allGoals = try await fetchGoalsUseCase.executeAll()
            
            activeGoals = allGoals.filter { $0.status == .active }
            completedGoals = allGoals.filter { $0.status == .completed }
            archivedGoals = allGoals.filter { $0.status == .archived }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load goals: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func completeGoal(_ goal: Goal) async {
        do {
            _ = try await completeGoalUseCase.execute(goalId: goal.id)
            await loadGoals()
        } catch {
            errorMessage = "Failed to complete goal: \(error.localizedDescription)"
        }
    }
}
```

#### Step 5: Create Views

**File:** `lume/Presentation/Features/Goals/Views/GoalListView.swift`

```swift
import SwiftUI

struct GoalListView: View {
    @Bindable var viewModel: GoalListViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                LumeColors.appBackground
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Active Goals Section
                            if !viewModel.activeGoals.isEmpty {
                                GoalSectionView(
                                    title: "🎯 Active Goals",
                                    goals: viewModel.activeGoals,
                                    onGoalTap: { goal in
                                        // Navigate to detail
                                    }
                                )
                            }
                            
                            // AI Help Button
                            Button(action: {
                                // Open AI chat
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Get AI Help")
                                        .font(LumeTypography.body)
                                }
                                .foregroundColor(LumeColors.textPrimary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(LumeColors.accentSecondary)
                                .cornerRadius(20)
                            }
                            .padding(.horizontal)
                            
                            // Completed Goals
                            if !viewModel.completedGoals.isEmpty {
                                GoalSectionView(
                                    title: "✅ Completed",
                                    goals: viewModel.completedGoals,
                                    onGoalTap: { goal in }
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.showingCreateGoal = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(LumeColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateGoal) {
                CreateGoalView(viewModel: createGoalViewModel())
            }
            .task {
                await viewModel.loadGoals()
            }
        }
    }
}
```

**File:** `lume/Presentation/Features/Goals/Views/Components/GoalCardView.swift`

```swift
import SwiftUI

struct GoalCardView: View {
    let goal: Goal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: goal.category.systemImage)
                        .foregroundColor(LumeColors.accentPrimary)
                    
                    Text(goal.title)
                        .font(LumeTypography.titleMedium)
                        .foregroundColor(LumeColors.textPrimary)
                    
                    Spacer()
                    
                    if goal.isOverdue {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(LumeColors.moodLow)
                    }
                }
                
                if !goal.description.isEmpty {
                    Text(goal.description)
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                        .lineLimit(2)
                }
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LumeColors.surface)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LumeColors.accentPrimary)
                                .frame(width: geometry.size.width * goal.progress)
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("\(goal.progressPercentage)%")
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textSecondary)
                        
                        Spacer()
                        
                        if let daysRemaining = goal.daysRemaining {
                            Text("\(daysRemaining) days remaining")
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: LumeColors.textPrimary.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### Day 5: Integration

#### Step 6: Update AppDependencies

**File:** `lume/DI/AppDependencies.swift`

```swift
// Add to AppDependencies class

// MARK: - Goal Dependencies

private func makeGoalRepository() -> GoalRepositoryProtocol {
    GoalRepository(
        modelContext: modelContext,
        currentUserId: getCurrentUserId()
    )
}

func makeCreateGoalUseCase() -> CreateGoalUseCaseProtocol {
    CreateGoalUseCase(goalRepository: makeGoalRepository())
}

func makeFetchGoalsUseCase() -> FetchGoalsUseCaseProtocol {
    FetchGoalsUseCase(goalRepository: makeGoalRepository())
}

func makeCompleteGoalUseCase() -> CompleteGoalUseCaseProtocol {
    CompleteGoalUseCase(goalRepository: makeGoalRepository())
}

func makeGoalListViewModel() -> GoalListViewModel {
    GoalListViewModel(
        fetchGoalsUseCase: makeFetchGoalsUseCase(),
        completeGoalUseCase: makeCompleteGoalUseCase()
    )
}
```

#### Step 7: Replace Placeholder in MainTabView

**File:** `lume/Presentation/MainTabView.swift`

```swift
// Replace GoalsPlaceholderView with:

GoalListView(viewModel: dependencies.makeGoalListViewModel())
    .tabItem {
        Label("Goals", systemImage: "target")
    }
    .tag(2)
```

---

## Week 2: AI Infrastructure & Insights

### Day 1-2: AI Infrastructure

#### Step 8: Configure AI Service

**File:** `lume/config.plist`

```xml
<key>AI</key>
<dict>
    <key>Provider</key>
    <string>openai</string>
    <key>BaseURL</key>
    <string>https://api.openai.com/v1</string>
    <key>Model</key>
    <string>gpt-4</string>
    <key>MaxTokens</key>
    <integer>1000</integer>
</dict>
```

#### Step 9: Create AI Service Port

**File:** `lume/Domain/Ports/AIInsightServiceProtocol.swift`

```swift
import Foundation

protocol AIInsightServiceProtocol {
    func generateInsight(
        type: InsightType,
        context: UserContext
    ) async throws -> AIInsight
    
    func shouldGenerateInsight(type: InsightType) async throws -> Bool
}

struct UserContext: Codable {
    let moodHistory: [MoodEntry]
    let recentJournals: [JournalEntry]
    let activeGoals: [Goal]
    let completedGoals: [Goal]
}
```

#### Step 10: Implement UserContextBuilder

**File:** `lume/Domain/Services/UserContextBuilder.swift`

```swift
import Foundation

final class UserContextBuilder {
    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol
    private let goalRepository: GoalRepositoryProtocol
    
    init(
        moodRepository: MoodRepositoryProtocol,
        journalRepository: JournalRepositoryProtocol,
        goalRepository: GoalRepositoryProtocol
    ) {
        self.moodRepository = moodRepository
        self.journalRepository = journalRepository
        self.goalRepository = goalRepository
    }
    
    func buildContext(daysBack: Int = 30) async throws -> UserContext {
        let endDate = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBack,
            to: endDate
        )!
        
        let moods = try await moodRepository.fetchBetweenDates(
            startDate: startDate,
            endDate: endDate
        )
        
        let journals = try await journalRepository.fetchBetweenDates(
            startDate: startDate,
            endDate: endDate
        )
        
        let activeGoals = try await goalRepository.fetchActive()
        let completedGoals = try await goalRepository.fetchByStatus(.completed)
        
        return UserContext(
            moodHistory: moods,
            recentJournals: journals,
            activeGoals: activeGoals,
            completedGoals: completedGoals
        )
    }
}
```

#### Step 11: Implement AI Service with Outbox

**File:** `lume/Services/AI/AIInsightService.swift`

```swift
import Foundation

final class AIInsightService: AIInsightServiceProtocol {
    private let outboxRepository: OutboxRepositoryProtocol
    private let insightRepository: InsightRepositoryProtocol
    private let apiClient: APIClient
    
    func generateInsight(
        type: InsightType,
        context: UserContext
    ) async throws -> AIInsight {
        // Create outbox event
        let payload = try JSONEncoder().encode([
            "type": type.rawValue,
            "context": context
        ])
        
        let event = OutboxEvent(
            eventType: "ai.insight.generate",
            payload: payload,
            status: .pending
        )
        
        try await outboxRepository.save(event)
        
        // Outbox processor will handle sending to AI
        // For now, wait for processing (or return cached)
        
        return try await insightRepository.fetchLatest(type: type)
    }
    
    func shouldGenerateInsight(type: InsightType) async throws -> Bool {
        // Check last generation time
        if let latest = try await insightRepository.fetchLatest(type: type) {
            let hoursSince = Date().timeIntervalSince(latest.createdAt) / 3600
            
            switch type {
            case .daily:
                return hoursSince >= 24
            case .weekly:
                return hoursSince >= 168
            default:
                return true
            }
        }
        
        return true
    }
}
```

### Day 3-4: Insights Implementation

#### Step 12: Create Insight Views

**File:** `lume/Presentation/Features/Dashboard/Components/InsightCardView.swift`

```swift
import SwiftUI

struct InsightCardView: View {
    let insight: AIInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: insight.insightType.icon)
                        .foregroundColor(LumeColors.accentSecondary)
                    
                    Text(insight.title)
                        .font(LumeTypography.titleMedium)
                        .foregroundColor(LumeColors.textPrimary)
                    
                    Spacer()
                    
                    if !insight.isRead {
                        Circle()
                            .fill(LumeColors.accentPrimary)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(insight.summary)
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .lineLimit(3)
                
                Text("Read More →")
                    .font(LumeTypography.bodySmall)
                    .foregroundColor(LumeColors.accentPrimary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: LumeColors.textPrimary.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

#### Step 13: Add to Dashboard

Update `DashboardView.swift` to include insight card at top.

### Day 5: Background Service

#### Step 14: Create Background Service

**File:** `lume/Services/Background/InsightGenerationService.swift`

```swift
import Foundation
import BackgroundTasks

final class InsightGenerationService {
    static let shared = InsightGenerationService()
    
    private let generateInsightUseCase: GenerateAIInsightUseCaseProtocol
    
    func scheduleNextGeneration() {
        // Daily insight at 8pm
        scheduleDailyTask()
        
        // Weekly insight on Sunday
        scheduleWeeklyTask()
    }
    
    private func scheduleDailyTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.lume.dailyInsight")
        request.earliestBeginDate = Calendar.current.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: Date().addingTimeInterval(86400)
        )
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    func handleDailyInsightTask(task: BGTask) {
        Task {
            do {
                _ = try await generateInsightUseCase.execute(type: .daily)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            
            scheduleNextGeneration()
        }
    }
}
```

---

## Week 3: AI Chat Bot

### Day 1-2: Chat Domain & Infrastructure

Follow similar pattern as Goals and Insights.

#### Step 15: Create Chat Entities

See `AI_FEATURES_DESIGN.md` for entity definitions.

#### Step 16: Implement Chat Service with Outbox

Similar to AI Insight Service but for conversational AI.

### Day 3-5: Chat UI

#### Step 17: Create Chat Views

Build message list, input field, quick actions sheet.

---

## Testing Checklist

### Unit Tests
- [ ] Goal repository CRUD operations
- [ ] Use case validation logic
- [ ] Context builder data aggregation
- [ ] AI service outbox event creation

### Integration Tests
- [ ] Goal creation flow
- [ ] Insight generation and display
- [ ] Chat message send/receive
- [ ] Background service scheduling

### UI Tests
- [ ] Navigate to Goals tab
- [ ] Create a new goal
- [ ] View insight details
- [ ] Send chat message
- [ ] Quick actions work

---

## Deployment Checklist

- [ ] AI API keys configured
- [ ] Background tasks registered in Info.plist
- [ ] Privacy policy updated with AI usage
- [ ] User consent flow implemented
- [ ] Cost monitoring in place
- [ ] Error tracking configured
- [ ] App Store review guidelines checked

---

## Troubleshooting

### Goals not saving
- Check SwiftData model context is valid
- Verify user ID is correct
- Check repository error logs

### Insights not generating
- Verify background tasks are registered
- Check outbox events are being processed
- Verify AI API credentials

### Chat not responding
- Check network connectivity
- Verify outbox processor is running
- Check AI service error responses

---

## Resources

- Main Design: `AI_FEATURES_DESIGN.md`
- Architecture: `.github/copilot-instructions.md`
- Backend API: `docs/backend-integration/`
- SwiftUI Patterns: Apple Developer Documentation

---

## Next Steps

After completing basic implementation:

1. Gather user feedback
2. Iterate on AI prompt engineering
3. Optimize performance
4. Add advanced features (voice, streaming, etc.)
5. Scale infrastructure

---

**Questions?** Review the main design document or consult with the team.