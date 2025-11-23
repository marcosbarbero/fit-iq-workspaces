# 🔗 Cross-Feature Integration Guide - iOS

**Feature:** Connecting AI Insights, Goals AI, and Consultations  
**Complexity:** Medium  
**Time Estimate:** 1-2 days  
**Prerequisites:** AI Insights, Goals AI, Enhanced Consultations implemented

---

## 📋 Overview

This guide shows how to integrate the three AI features (Insights, Goals AI, Consultations) to create a cohesive, intelligent wellness experience. Users can seamlessly move between features, with each one enhancing the others.

### Integration Points

```
AI Insights ↔ Goals AI ↔ Consultations
     ↓            ↓            ↓
  Analytics    Progress    All Features
```

### Key Integrations

1. **Insights → Goals**: Create goals from insight suggestions
2. **Insights → Consultations**: Discuss insights with AI coach
3. **Goals → Consultations**: Get help with specific goals
4. **Goals → Insights**: Track goal progress in insights
5. **Consultations → All**: AI can reference insights and goals in conversations

---

## 🎯 Integration Patterns

### Pattern 1: Context-Aware Navigation

Enable users to naturally flow between features based on context.

```swift
import SwiftUI

// Universal navigation coordinator
class AIFeaturesCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()
    
    // Navigate from insight to goal creation
    func createGoalFromInsight(_ insight: Insight) {
        // Extract goal suggestion from insight
        if let suggestion = insight.suggestions?.first {
            navigationPath.append(
                AIDestination.goalCreation(suggestion: suggestion)
            )
        }
    }
    
    // Start consultation about insight
    func discussInsight(_ insight: Insight) {
        navigationPath.append(
            AIDestination.consultation(
                persona: .wellnessSpecialist,
                contextType: .insight,
                contextId: insight.id,
                title: insight.title
            )
        )
    }
    
    // Start consultation about goal
    func discussGoal(_ goal: Goal) {
        navigationPath.append(
            AIDestination.consultation(
                persona: .generalWellness,
                contextType: .goal,
                contextId: goal.id,
                title: goal.title
            )
        )
    }
    
    // Get AI tips for goal
    func getGoalTips(_ goal: Goal) {
        navigationPath.append(
            AIDestination.goalTips(goalId: goal.id, title: goal.title)
        )
    }
}

enum AIDestination: Hashable {
    case goalCreation(suggestion: String)
    case consultation(persona: Persona, contextType: ContextType, contextId: String?, title: String?)
    case goalTips(goalId: String, title: String)
    case insightDetail(id: String)
}
```

### Pattern 2: Smart Action Buttons

Add contextual actions to each feature that link to others.

```swift
// In InsightDetailView
struct InsightActions: View {
    let insight: Insight
    @EnvironmentObject var coordinator: AIFeaturesCoordinator
    
    var body: some View {
        VStack(spacing: 12) {
            // Discuss with AI
            Button {
                coordinator.discussInsight(insight)
            } label: {
                Label("Discuss with AI Coach", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            // Create goal from suggestions
            if hasActionableGoals {
                Button {
                    coordinator.createGoalFromInsight(insight)
                } label: {
                    Label("Create Goal", systemImage: "target")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private var hasActionableGoals: Bool {
        insight.suggestions?.contains(where: { $0.contains("goal") || $0.contains("target") }) ?? false
    }
}

// In GoalDetailView
struct GoalActions: View {
    let goal: Goal
    @EnvironmentObject var coordinator: AIFeaturesCoordinator
    
    var body: some View {
        VStack(spacing: 12) {
            // Get AI tips
            Button {
                coordinator.getGoalTips(goal)
            } label: {
                Label("Get AI Tips", systemImage: "lightbulb.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            // Discuss with coach
            Button {
                coordinator.discussGoal(goal)
            } label: {
                Label("Chat with Coach", systemImage: "message.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
```

### Pattern 3: Unified AI Hub

Create a central hub for all AI features.

```swift
struct AIHubView: View {
    @StateObject private var coordinator = AIFeaturesCoordinator()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            TabView(selection: $selectedTab) {
                // Insights Tab
                InsightsListView()
                    .tabItem {
                        Label("Insights", systemImage: "lightbulb.fill")
                    }
                    .tag(0)
                
                // Goals Tab with AI
                GoalsListWithAIView()
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }
                    .tag(1)
                
                // Consultations Tab
                ConsultationsListView()
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(2)
            }
            .navigationDestination(for: AIDestination.self) { destination in
                navigationView(for: destination)
            }
            .environmentObject(coordinator)
        }
    }
    
    @ViewBuilder
    private func navigationView(for destination: AIDestination) -> some View {
        switch destination {
        case .goalCreation(let suggestion):
            CreateGoalView(initialSuggestion: suggestion)
            
        case .consultation(let persona, let contextType, let contextId, let title):
            ConsultationCreationView(
                persona: persona,
                contextType: contextType,
                contextId: contextId,
                title: title
            )
            
        case .goalTips(let goalId, let title):
            GoalTipsView(goalId: goalId, goalTitle: title)
            
        case .insightDetail(let id):
            InsightDetailView(insightId: id)
        }
    }
}
```

---

## 🔄 Data Synchronization

### Shared Data Manager

Coordinate data updates across features.

```swift
import Foundation
import Combine

@MainActor
class AIDataManager: ObservableObject {
    static let shared = AIDataManager()
    
    @Published var recentInsights: [Insight] = []
    @Published var activeGoals: [Goal] = []
    @Published var activeConsultations: [Consultation] = []
    
    // Services
    private let insightsService = InsightsService(apiKey: Config.apiKey)
    private let goalsService = GoalsService(apiKey: Config.apiKey)
    private let consultationService = ConsultationService(apiKey: Config.apiKey)
    
    private init() {
        setupRefreshTimer()
    }
    
    // MARK: - Load All Data
    
    func loadAllAIData() async {
        async let insights = loadRecentInsights()
        async let goals = loadActiveGoals()
        async let consultations = loadActiveConsultations()
        
        _ = await (insights, goals, consultations)
    }
    
    private func loadRecentInsights() async {
        do {
            let data = try await insightsService.listInsights(
                readStatus: false,
                archivedStatus: false,
                page: 1,
                pageSize: 5
            )
            recentInsights = data.insights
        } catch {
            print("Failed to load insights: \(error)")
        }
    }
    
    private func loadActiveGoals() async {
        do {
            let data = try await goalsService.listGoals(
                status: .active,
                page: 1,
                pageSize: 10
            )
            activeGoals = data.goals
        } catch {
            print("Failed to load goals: \(error)")
        }
    }
    
    private func loadActiveConsultations() async {
        do {
            let data = try await consultationService.listConsultations(
                isArchived: false,
                page: 1,
                pageSize: 5
            )
            activeConsultations = data.consultations
        } catch {
            print("Failed to load consultations: \(error)")
        }
    }
    
    // MARK: - Refresh Timer
    
    private func setupRefreshTimer() {
        Timer.publish(every: 300, on: .main, in: .common) // 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.loadAllAIData()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
```

---

## 🎨 Enhanced UI Components

### 1. AI Feature Card

Reusable card showing AI feature status.

```swift
struct AIFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if count > 0 {
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                        
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// Usage
struct AIOverviewView: View {
    @StateObject private var dataManager = AIDataManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AIFeatureCard(
                    icon: "lightbulb.fill",
                    title: "AI Insights",
                    subtitle: "Personalized wellness analysis",
                    color: .orange,
                    count: dataManager.recentInsights.filter { !$0.isRead }.count,
                    action: { /* Navigate to insights */ }
                )
                
                AIFeatureCard(
                    icon: "target",
                    title: "Smart Goals",
                    subtitle: "AI-powered goal suggestions",
                    color: .blue,
                    count: dataManager.activeGoals.count,
                    action: { /* Navigate to goals */ }
                )
                
                AIFeatureCard(
                    icon: "bubble.left.and.bubble.right",
                    title: "AI Coach",
                    subtitle: "Chat with wellness experts",
                    color: .purple,
                    count: dataManager.activeConsultations.count,
                    action: { /* Navigate to consultations */ }
                )
            }
            .padding()
        }
        .task {
            await dataManager.loadAllAIData()
        }
    }
}
```

### 2. Context-Aware Quick Actions

Show relevant actions based on current context.

```swift
struct ContextualActionsView: View {
    let context: AIContext
    @EnvironmentObject var coordinator: AIFeaturesCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What would you like to do?")
                .font(.headline)
            
            ForEach(availableActions, id: \.title) { action in
                ContextualActionButton(action: action) {
                    handleAction(action)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var availableActions: [ContextualAction] {
        switch context {
        case .insight(let insight):
            return [
                ContextualAction(
                    title: "Discuss with AI",
                    icon: "bubble.left",
                    color: .purple
                ),
                ContextualAction(
                    title: "Create Goal",
                    icon: "target",
                    color: .blue
                )
            ]
            
        case .goal(let goal):
            return [
                ContextualAction(
                    title: "Get AI Tips",
                    icon: "lightbulb.fill",
                    color: .orange
                ),
                ContextualAction(
                    title: "Chat with Coach",
                    icon: "message.fill",
                    color: .purple
                )
            ]
            
        case .consultation:
            return [
                ContextualAction(
                    title: "View Insights",
                    icon: "lightbulb.fill",
                    color: .orange
                ),
                ContextualAction(
                    title: "My Goals",
                    icon: "target",
                    color: .blue
                )
            ]
        }
    }
    
    private func handleAction(_ action: ContextualAction) {
        switch (context, action.title) {
        case (.insight(let insight), "Discuss with AI"):
            coordinator.discussInsight(insight)
        case (.insight(let insight), "Create Goal"):
            coordinator.createGoalFromInsight(insight)
        case (.goal(let goal), "Get AI Tips"):
            coordinator.getGoalTips(goal)
        case (.goal(let goal), "Chat with Coach"):
            coordinator.discussGoal(goal)
        default:
            break
        }
    }
}

enum AIContext {
    case insight(Insight)
    case goal(Goal)
    case consultation(Consultation)
}

struct ContextualAction {
    let title: String
    let icon: String
    let color: Color
}

struct ContextualActionButton: View {
    let action: ContextualAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: action.icon)
                    .foregroundColor(action.color)
                
                Text(action.title)
                    .font(.subheadline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
```

### 3. AI Assistant Widget (Home Screen)

Quick access to AI features from home screen.

```swift
import WidgetKit
import SwiftUI

struct AIAssistantWidget: Widget {
    let kind: String = "AIAssistantWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AIAssistantWidgetView(entry: entry)
        }
        .configurationDisplayName("AI Assistant")
        .description("Quick access to your AI wellness features")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AIAssistantWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Assistant")
                    .font(.headline)
            }
            
            // Unread insights
            if entry.unreadInsights > 0 {
                Link(destination: URL(string: "fitiq://insights")!) {
                    WidgetActionRow(
                        icon: "lightbulb.fill",
                        title: "\(entry.unreadInsights) New Insights",
                        color: .orange
                    )
                }
            }
            
            // Active goals
            if entry.activeGoals > 0 {
                Link(destination: URL(string: "fitiq://goals")!) {
                    WidgetActionRow(
                        icon: "target",
                        title: "\(entry.activeGoals) Active Goals",
                        color: .blue
                    )
                }
            }
            
            // Quick chat
            Link(destination: URL(string: "fitiq://chat/new")!) {
                WidgetActionRow(
                    icon: "message.fill",
                    title: "Chat with Coach",
                    color: .purple
                )
            }
        }
        .padding()
    }
}

struct WidgetActionRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline)
            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
```

---

## 🔔 Notifications Integration

### Smart Notifications

Send contextual notifications that link features together.

```swift
import UserNotifications

class AINotificationManager {
    static let shared = AINotificationManager()
    
    private init() {}
    
    // Notify about new insight with action to create goal
    func notifyNewInsight(_ insight: Insight) {
        let content = UNMutableNotificationContent()
        content.title = "New AI Insight"
        content.body = insight.title
        content.categoryIdentifier = "INSIGHT_CATEGORY"
        content.userInfo = [
            "type": "insight",
            "insightId": insight.id,
            "hasGoalSuggestion": insight.suggestions?.isEmpty == false
        ]
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "insight_\(insight.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Notify about goal with tip to chat
    func notifyGoalProgress(_ goal: Goal, progress: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Goal Progress Update"
        content.body = "\(goal.title) is \(Int(progress * 100))% complete! Need tips?"
        content.categoryIdentifier = "GOAL_PROGRESS_CATEGORY"
        content.userInfo = [
            "type": "goal",
            "goalId": goal.id
        ]
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "goal_progress_\(goal.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Setup notification categories with actions
    func setupNotificationCategories() {
        // Insight actions
        let createGoalAction = UNNotificationAction(
            identifier: "CREATE_GOAL",
            title: "Create Goal",
            options: [.foreground]
        )
        let discussAction = UNNotificationAction(
            identifier: "DISCUSS_INSIGHT",
            title: "Discuss with AI",
            options: [.foreground]
        )
        let insightCategory = UNNotificationCategory(
            identifier: "INSIGHT_CATEGORY",
            actions: [createGoalAction, discussAction],
            intentIdentifiers: []
        )
        
        // Goal actions
        let getTipsAction = UNNotificationAction(
            identifier: "GET_TIPS",
            title: "Get Tips",
            options: [.foreground]
        )
        let chatAction = UNNotificationAction(
            identifier: "CHAT_GOAL",
            title: "Chat with Coach",
            options: [.foreground]
        )
        let goalCategory = UNNotificationCategory(
            identifier: "GOAL_PROGRESS_CATEGORY",
            actions: [getTipsAction, chatAction],
            intentIdentifiers: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            insightCategory,
            goalCategory
        ])
    }
}

// Handle notification actions
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "CREATE_GOAL":
            if let insightId = userInfo["insightId"] as? String {
                // Navigate to goal creation from insight
                deepLinkToGoalCreation(insightId: insightId)
            }
            
        case "DISCUSS_INSIGHT":
            if let insightId = userInfo["insightId"] as? String {
                // Navigate to consultation about insight
                deepLinkToConsultation(contextType: .insight, contextId: insightId)
            }
            
        case "GET_TIPS":
            if let goalId = userInfo["goalId"] as? String {
                // Navigate to goal tips
                deepLinkToGoalTips(goalId: goalId)
            }
            
        case "CHAT_GOAL":
            if let goalId = userInfo["goalId"] as? String {
                // Navigate to consultation about goal
                deepLinkToConsultation(contextType: .goal, contextId: goalId)
            }
            
        default:
            break
        }
        
        completionHandler()
    }
}
```

---

## 🔗 Deep Linking

### Universal Deep Link Handler

Handle deep links to navigate between features.

```swift
import SwiftUI

class DeepLinkManager: ObservableObject {
    @Published var activeLink: DeepLink?
    
    func handle(url: URL) {
        guard url.scheme == "fitiq" else { return }
        
        let path = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        switch path {
        case "insights":
            if let insightId = queryItems.first(where: { $0.name == "id" })?.value {
                activeLink = .insight(id: insightId)
            } else {
                activeLink = .insightsList
            }
            
        case "goals":
            if let goalId = queryItems.first(where: { $0.name == "id" })?.value {
                if let action = queryItems.first(where: { $0.name == "action" })?.value {
                    switch action {
                    case "tips":
                        activeLink = .goalTips(goalId: goalId)
                    case "chat":
                        activeLink = .goalConsultation(goalId: goalId)
                    default:
                        activeLink = .goal(id: goalId)
                    }
                } else {
                    activeLink = .goal(id: goalId)
                }
            } else if queryItems.first(where: { $0.name == "suggestions" })?.value == "true" {
                activeLink = .goalSuggestions
            } else {
                activeLink = .goalsList
            }
            
        case "chat":
            if url.pathComponents.contains("new") {
                let persona = queryItems.first(where: { $0.name == "persona" })?.value
                let contextType = queryItems.first(where: { $0.name == "context" })?.value
                let contextId = queryItems.first(where: { $0.name == "contextId" })?.value
                
                activeLink = .newConsultation(
                    persona: persona.flatMap { Persona(rawValue: $0) },
                    contextType: contextType.flatMap { ContextType(rawValue: $0) },
                    contextId: contextId
                )
            } else if let consultationId = queryItems.first(where: { $0.name == "id" })?.value {
                activeLink = .consultation(id: consultationId)
            } else {
                activeLink = .consultationsList
            }
            
        default:
            activeLink = nil
        }
    }
}

enum DeepLink: Identifiable {
    case insight(id: String)
    case insightsList
    case goal(id: String)
    case goalsList
    case goalSuggestions
    case goalTips(goalId: String)
    case goalConsultation(goalId: String)
    case consultation(id: String)
    case consultationsList
    case newConsultation(persona: Persona?, contextType: ContextType?, contextId: String?)
    
    var id: String {
        switch self {
        case .insight(let id): return "insight_\(id)"
        case .insightsList: return "insights_list"
        case .goal(let id): return "goal_\(id)"
        case .goalsList: return "goals_list"
        case .goalSuggestions: return "goal_suggestions"
        case .goalTips(let goalId): return "goal_tips_\(goalId)"
        case .goalConsultation(let goalId): return "goal_consultation_\(goalId)"
        case .consultation(let id): return "consultation_\(id)"
        case .consultationsList: return "consultations_list"
        case .newConsultation: return "new_consultation"
        }
    }
}

// Usage in App
@main
struct FitIQApp: App {
    @StateObject private var deepLinkManager = DeepLinkManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handle(url: url)
                }
        }
    }
}
```

---

## 📊 Analytics & Tracking

### Cross-Feature Analytics

Track how users move between AI features.

```swift
import Foundation

class AIAnalytics {
    static let shared = AIAnalytics()
    
    private init() {}
    
    // Track feature interactions
    func trackFeatureTransition(from: AIFeature, to: AIFeature, context: String? = nil) {
        let event = AnalyticsEvent(
            name: "ai_feature_transition",
            parameters: [
                "from_feature": from.rawValue,
                "to_feature": to.rawValue,
                "context": context ?? "none",
                "timestamp": Date().ISO8601Format()
            ]
        )
        
        logEvent(event)
    }
    
    // Track insight actions
    func trackInsightAction(insightId: String, action: InsightAction) {
        let event = AnalyticsEvent(
            name: "insight_action",
            parameters: [
                "insight_id": insightId,
                "action": action.rawValue,
                "timestamp": Date().ISO8601Format()
            ]
        )
        
        logEvent(event)
    }
    
    // Track goal AI usage
    func trackGoalAIUsage(goalId: String, feature: GoalAIFeature) {
        let event = AnalyticsEvent(
            name: "goal_ai_usage",
            parameters: [
                "goal_id": goalId,
                "feature": feature.rawValue,
                "timestamp": Date().ISO8601Format()
            ]
        )
        
        logEvent(event)
    }
    
    // Track consultation context
    func trackConsultationStart(persona: Persona, contextType: ContextType, contextId: String?) {
        let event = AnalyticsEvent(
            name: "consultation_started",
            parameters: [
                "persona": persona.rawValue,
                "context_type": contextType.rawValue,
                "context_id": contextId ?? "none",
                "timestamp": Date().ISO8601Format()
            ]
        )
        
        logEvent(event)
    }
    
    private func logEvent(_ event: AnalyticsEvent) {
        // Send to analytics service (Firebase, Mixpanel, etc.)
        print("📊 Analytics: \(event.name) - \(event.parameters)")
    }
}

enum AIFeature: String {
    case insights
    case goals
    case consultations
}

enum InsightAction: String {
    case viewed
    case favorited
    case archived
    case discussedWithAI
    case createdGoal
}

enum GoalAIFeature: String {
    case suggestions
    case tips
    case consultation
}

struct AnalyticsEvent {
    let name: String
    let parameters: [String: String]
}
```

---

## 🧪 Testing Integration

### Integration Test Suite

```swift
import XCTest
@testable import FitIQ

class AIFeaturesIntegrationTests: XCTestCase {
    var dataManager: AIDataManager!
    var coordinator: AIFeaturesCoordinator!
    
    override func setUp() async throws {
        dataManager = AIDataManager.shared
        coordinator = AIFeaturesCoordinator()
    }
    
    // Test: Insight → Goal flow
    func testInsightToGoalFlow() async throws {
        // 1. Load insights
        await dataManager.loadAllAIData()
        XCTAssertFalse(dataManager.recentInsights.isEmpty)
        
        // 2. Get first insight
        let insight = dataManager.recentInsights[0]
        
        // 3. Navigate to goal creation
        coordinator.createGoalFromInsight(insight)
        
        // 4. Verify navigation occurred
        XCTAssertFalse(coordinator.navigationPath.isEmpty)
    }
    
    // Test: Goal → Tips → Consultation flow
    func testGoalToConsultationFlow() async throws {
        // 1. Load goals
        await dataManager.loadAllAIData()
        XCTAssertFalse(dataManager.activeGoals.isEmpty)
        
        // 2. Get first goal
        let goal = dataManager.activeGoals[0]
        
        // 3. Navigate to tips
        coordinator.getGoalTips(goal)
        XCTAssertFalse(coordinator.navigationPath.isEmpty)
        
        // 4. Navigate to consultation
        coordinator.discussGoal(goal)
        XCTAssertEqual(coordinator.navigationPath.count, 2)
    }
    
    // Test: Data synchronization
    func testDataSynchronization() async throws {
        // 1. Load all data
        await dataManager.loadAllAIData()
        
        // 2. Verify all data loaded
        XCTAssertNotNil(dataManager.recentInsights)
        XCTAssertNotNil(dataManager.activeGoals)
        XCTAssertNotNil(dataManager.activeConsultations)
    }
}
```

---

## ✅ Implementation Checklist

### Phase 1: Navigation & Coordination (0.5 days)
- [ ] Create `AIFeaturesCoordinator` class
- [ ] Define `AIDestination` enum
- [ ] Implement navigation helpers
- [ ] Add contextual action buttons to each feature
- [ ] Test navigation flows

### Phase 2: Data Management (0.5 days)
- [ ] Create `AIDataManager` singleton
- [ ] Implement data loading for all features
- [ ] Add refresh timer
- [ ] Test data synchronization
- [ ] Handle errors gracefully

### Phase 3: UI Components (0.5 days)
- [ ] Create `AIFeatureCard` component
- [ ] Build `AIOverviewView` hub
- [ ] Add contextual actions view
- [ ] Implement widget (optional)
- [ ] Test UI on different screen sizes

### Phase 4: Deep Linking & Notifications (0.5 days)
- [ ] Implement `DeepLinkManager`
- [ ] Set up URL scheme
- [ ] Configure notification categories
- [ ] Add notification actions
- [ ] Test deep linking flows
- [ ] Test notifications

---

## 🎯 User Journey Examples

### Journey 1: Insight → Goal → Tips → Achievement

```
1. User receives notification: "New AI Insight Available"
2. User taps notification → Opens InsightDetailView
3. User reads insight: "You're ready to increase workout frequency"
4. User taps "Create Goal" button
5. System navigates to CreateGoalView with pre-filled suggestion
6. User creates goal: "Work out 4 times per week"
7. User taps "Get AI Tips" button in goal detail
8. System shows 5-7 personalized tips
9. User follows tips and achieves goal
10. System generates milestone insight celebrating achievement
```

### Journey 2: Goal Struggle → Consultation → New Strategy

```
1. User has active goal: "Lose 5 lbs"
2. User isn't making progress
3. User taps "Chat with Coach" button
4. System opens ChatView with goal context pre-loaded
5. User asks: "Why am I not losing weight?"
6. AI analyzes goal + nutrition data + activity
7. AI suggests: "Your calorie intake looks good, but increase cardio"
8. AI creates workout template during conversation
9. User accepts template and adjusts routine
10. User starts making progress toward goal
```

### Journey 3: Weekly Review → Multiple Insights → Goals

```
1. User opens AI Hub on Sunday evening
2. System shows 3 new weekly insights
3. User reviews insights:
   - Nutrition insight: "Protein intake below target"
   - Activity insight: "Great job with 12,000 steps average!"
   - Sleep insight: "Sleep quality declining midweek"
4. User taps "Create Goals" from insights
5. System suggests 3 goals based on insights
6. User accepts 2 goals: Increase protein, Improve sleep
7. User taps "Get Tips" for each goal
8. User implements tips throughout week
9. Next week's insights show improvement
```

---

## 💡 Best Practices

### 1. Context Preservation
```swift
// Always preserve context when navigating
func navigateWithContext<T>(to destination: T, context: Any?) {
    // Store context for potential back navigation
    navigationContext[destination.id] = context
    navigationPath.append(destination)
}
```

### 2. Smart Suggestions
```swift
// Show relevant actions based on user state
func getSuggestedActions(for user: User) -> [AIAction] {
    var actions: [AIAction] = []
    
    // If user has unread insights
    if hasUnreadInsights {
        actions.append(.viewInsights)
    }
    
    // If user has goals without tips
    if hasGoalsWithoutTips {
        actions.append(.getGoalTips)
    }
    
    // If user hasn't chatted recently
    if shouldSuggestChat {
        actions.append(.startConsultation)
    }
    
    return actions
}
```

### 3. Graceful Degradation
```swift
// Handle offline scenarios
func handleOfflineMode() {
    // Show cached data
    showCachedInsights()
    
    // Disable AI features that require network
    disableNetworkFeatures([.suggestions, .consultations])
    
    // Queue actions for later
    queueActionForSync(.createGoal)
}
```

---

## 📚 Additional Resources

- **AI Insights Guide**: [features/ai-insights.md](features/ai-insights.md)
- **Goals AI Guide**: [features/goals-ai.md](features/goals-ai.md)
- **Consultations Guide**: [ai-consultation/consultations-enhanced.md](ai-consultation/consultations-enhanced.md)
- **Deep Linking**: [Apple Docs](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- **Widgets**: [Apple Docs](https://developer.apple.com/documentation/widgetkit)

---

## 🎯 Success Metrics

Track these metrics to measure integration success:

1. **Feature Transition Rate**: % of users who move between features
2. **Goal Creation from Insights**: % of insights that lead to goals
3. **Consultation Context Usage**: % of consultations with context
4. **Tip Adoption Rate**: % of tips that lead to action
5. **Cross-Feature Engagement**: Average features used per session

---

## 🎉 Summary

This integration creates a seamless AI ecosystem where:

- ✅ Insights naturally lead to goal creation
- ✅ Goals connect to personalized tips and coaching
- ✅ Consultations have full context of user's wellness journey
- ✅ Users can navigate intuitively between features
- ✅ Deep linking enables powerful notification experiences
- ✅ Data stays synchronized across all features

**The result is a cohesive, intelligent wellness platform that feels like a single unified experience!** 🚀