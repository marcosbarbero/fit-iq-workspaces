# 🎯 Goals AI - iOS Integration Guide

**Feature:** AI-powered goal suggestions and tips  
**Complexity:** Medium  
**Time Estimate:** 1-2 days  
**Prerequisites:** Authentication, User Profile, Goals API, at least one tracking feature

---

## 📋 Overview

Goals AI provides intelligent, personalized goal suggestions and contextual tips to help users achieve their wellness objectives. The system analyzes user data (activity, nutrition, physical profile, existing goals) to generate relevant, achievable recommendations.

### What You'll Build
- AI-generated goal suggestions view
- Goal tips detail view
- Integration with existing goals list
- Smart goal creation from suggestions
- Contextual tips for active goals

### AI Features
- **Goal Suggestions**: 3-5 personalized goal recommendations based on wellness data
- **Goal Tips**: 5-7 actionable tips for achieving specific goals
- **Context-Aware**: Leverages physical profile, activity metrics, nutrition patterns, and existing goals

---

## 🔑 Key Concepts

### Data Flow
```
User requests suggestions
         ↓
AI analyzes wellness data
         ↓
Returns 3-5 personalized goals
         ↓
User selects suggestion
         ↓
Goal created via Goals API
```

```
User views goal
         ↓
User requests tips
         ↓
AI analyzes goal + context
         ↓
Returns 5-7 actionable tips
         ↓
User implements tips
```

### AI Context
The AI uses:
- Physical profile (age, height, weight, BMI)
- Activity metrics (steps, workouts, calories)
- Nutrition patterns (daily intake, macros)
- Existing goals (to avoid duplicates)
- User preferences and history

### Goal Types
- **Activity**: Steps, workouts, cardio, strength
- **Nutrition**: Calorie targets, macros, hydration, meal planning
- **Wellness**: Sleep, stress management, mindfulness
- **Body Composition**: Weight, body fat, muscle gain

---

## 🏗️ Swift Models

### 1. Goal Suggestion Model

```swift
import Foundation

struct GoalSuggestion: Codable, Identifiable {
    let id = UUID() // Local ID for SwiftUI
    let title: String
    let description: String
    let goalType: String
    let targetValue: Double?
    let targetUnit: String?
    let rationale: String
    let estimatedDuration: Int? // in days
    let difficulty: Int // 1-5 scale
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case goalType = "goal_type"
        case targetValue = "target_value"
        case targetUnit = "target_unit"
        case rationale
        case estimatedDuration = "estimated_duration"
        case difficulty
    }
    
    var difficultyLabel: String {
        switch difficulty {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Challenging"
        case 5: return "Very Challenging"
        default: return "Moderate"
        }
    }
    
    var difficultyColor: Color {
        switch difficulty {
        case 1, 2: return .green
        case 3: return .orange
        case 4, 5: return .red
        default: return .orange
        }
    }
    
    var durationText: String {
        guard let duration = estimatedDuration else { return "Ongoing" }
        
        if duration < 7 {
            return "\(duration) days"
        } else if duration < 30 {
            let weeks = duration / 7
            return "\(weeks) week\(weeks > 1 ? "s" : "")"
        } else {
            let months = duration / 30
            return "\(months) month\(months > 1 ? "s" : "")"
        }
    }
}

struct GoalSuggestionsResponse: Codable {
    let success: Bool
    let data: SuggestionsData
}

struct SuggestionsData: Codable {
    let suggestions: [GoalSuggestion]
    let count: Int
}
```

### 2. Goal Tips Model

```swift
import Foundation

struct GoalTip: Codable, Identifiable {
    let id = UUID() // Local ID for SwiftUI
    let tip: String
    let category: String?
    let priority: String?
    
    var priorityLevel: Int {
        switch priority?.lowercased() {
        case "high": return 3
        case "medium": return 2
        case "low": return 1
        default: return 2
        }
    }
    
    var priorityColor: Color {
        switch priorityLevel {
        case 3: return .red
        case 2: return .orange
        case 1: return .green
        default: return .gray
        }
    }
    
    var categoryIcon: String {
        guard let category = category?.lowercased() else { return "lightbulb.fill" }
        
        switch category {
        case "nutrition": return "fork.knife"
        case "exercise": return "figure.run"
        case "sleep": return "bed.double.fill"
        case "mindset": return "brain.head.profile"
        case "habit": return "repeat"
        default: return "lightbulb.fill"
        }
    }
}

struct GoalTipsResponse: Codable {
    let success: Bool
    let data: TipsData
}

struct TipsData: Codable {
    let tips: [GoalTip]
    let goalId: String
    let goalTitle: String
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case tips
        case goalId = "goal_id"
        case goalTitle = "goal_title"
        case count
    }
}
```

### 3. Create Goal Request (from suggestion)

```swift
struct CreateGoalRequest: Codable {
    let title: String
    let description: String?
    let goalType: String
    let targetValue: Double?
    let targetUnit: String?
    let startDate: String // ISO 8601 date
    let targetDate: String? // ISO 8601 date
    let isRecurring: Bool
    let frequency: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case goalType = "goal_type"
        case targetValue = "target_value"
        case targetUnit = "target_unit"
        case startDate = "start_date"
        case targetDate = "target_date"
        case isRecurring = "is_recurring"
        case frequency
    }
    
    static func from(suggestion: GoalSuggestion) -> CreateGoalRequest {
        let today = ISO8601DateFormatter().string(from: Date())
        var targetDate: String?
        
        if let duration = suggestion.estimatedDuration {
            let target = Calendar.current.date(byAdding: .day, value: duration, to: Date())!
            targetDate = ISO8601DateFormatter().string(from: target)
        }
        
        return CreateGoalRequest(
            title: suggestion.title,
            description: suggestion.description,
            goalType: suggestion.goalType,
            targetValue: suggestion.targetValue,
            targetUnit: suggestion.targetUnit,
            startDate: today,
            targetDate: targetDate,
            isRecurring: false,
            frequency: nil
        )
    }
}
```

---

## 🔌 API Service

### GoalsAIService.swift

```swift
import Foundation

class GoalsAIService {
    private let baseURL = "https://fit-iq-backend.fly.dev/api/v1"
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Get Goal Suggestions
    
    func getGoalSuggestions() async throws -> [GoalSuggestion] {
        let url = URL(string: "\(baseURL)/goals/suggestions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(GoalSuggestionsResponse.self, from: data)
        
        return apiResponse.data.suggestions
    }
    
    // MARK: - Get Goal Tips
    
    func getGoalTips(goalId: String) async throws -> TipsData {
        let url = URL(string: "\(baseURL)/goals/\(goalId)/tips")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw APIError.goalNotFound
            }
            if httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(GoalTipsResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Create Goal from Suggestion
    
    func createGoal(from suggestion: GoalSuggestion) async throws -> Goal {
        let url = URL(string: "\(baseURL)/goals")!
        let goalRequest = CreateGoalRequest.from(suggestion: suggestion)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(goalRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(GoalResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Helper
    
    private func getAuthToken() -> String {
        return KeychainManager.shared.getToken() ?? ""
    }
}

// MARK: - Extended Errors

extension APIError {
    static let rateLimitExceeded = APIError.customError("Rate limit exceeded. Please try again later.")
    static let goalNotFound = APIError.customError("Goal not found")
    
    static func customError(_ message: String) -> APIError {
        return .networkError(NSError(domain: "GoalsAI", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
    }
}
```

---

## 🎨 SwiftUI Views

### 1. Goal Suggestions View

```swift
import SwiftUI

struct GoalSuggestionsView: View {
    @StateObject private var viewModel = GoalSuggestionsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.suggestions.isEmpty {
                    emptyStateView
                } else {
                    suggestionsList
                }
            }
            .navigationTitle("AI Goal Suggestions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshSuggestions()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.loadSuggestions()
            }
            .alert("Goal Created", isPresented: $viewModel.showSuccess) {
                Button("View Goal", action: {
                    // Navigate to goals list
                    dismiss()
                })
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your new goal has been created successfully!")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var suggestionsList: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                ForEach(viewModel.suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        onAccept: {
                            Task {
                                await viewModel.acceptSuggestion(suggestion)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Personalized for You")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            Text("Based on your activity, nutrition, and wellness data, here are some goals that could help you progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyzing your wellness data...")
                .foregroundColor(.secondary)
            Text("This may take a few seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Unable to Generate Suggestions")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task {
                    await viewModel.refreshSuggestions()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Suggestions Available")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Keep tracking your activity and nutrition to get personalized goal suggestions!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}
```

### 2. Suggestion Card

```swift
import SwiftUI

struct SuggestionCard: View {
    let suggestion: GoalSuggestion
    let onAccept: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: goalTypeIcon)
                        .foregroundColor(.blue)
                    
                    Text(suggestion.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                // Metadata
                HStack(spacing: 12) {
                    Label(suggestion.durationText, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(suggestion.difficultyLabel, systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundColor(suggestion.difficultyColor)
                    
                    if let value = suggestion.targetValue, let unit = suggestion.targetUnit {
                        Label("\(Int(value)) \(unit)", systemImage: "target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Description
            Text(suggestion.description)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : 3)
            
            // Rationale (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Why this goal?", systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text(suggestion.rationale)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: { isExpanded.toggle() }) {
                    Label(isExpanded ? "Show Less" : "Learn More", 
                          systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: onAccept) {
                    Label("Start Goal", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    private var goalTypeIcon: String {
        switch suggestion.goalType.lowercased() {
        case "activity": return "figure.run"
        case "nutrition": return "fork.knife"
        case "wellness": return "heart.fill"
        case "body_composition": return "scalemass"
        default: return "target"
        }
    }
}
```

### 3. Goal Tips View

```swift
import SwiftUI

struct GoalTipsView: View {
    let goalId: String
    let goalTitle: String
    
    @StateObject private var viewModel: GoalTipsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(goalId: String, goalTitle: String) {
        self.goalId = goalId
        self.goalTitle = goalTitle
        _viewModel = StateObject(wrappedValue: GoalTipsViewModel(goalId: goalId))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.tips.isEmpty {
                emptyStateView
            } else {
                tipsContent
            }
        }
        .navigationTitle("AI Tips")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTips()
        }
    }
    
    // MARK: - Subviews
    
    private var tipsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal Header
                goalHeaderSection
                
                // Tips List
                VStack(alignment: .leading, spacing: 16) {
                    Label("Action Steps", systemImage: "list.star")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    ForEach(Array(viewModel.tips.enumerated()), id: \.element.id) { index, tip in
                        TipCard(tip: tip, number: index + 1)
                    }
                }
            }
            .padding()
        }
    }
    
    private var goalHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(goalTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Text("\(viewModel.tips.count) personalized tips to help you succeed")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Generating personalized tips...")
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Unable to Load Tips")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task {
                    await viewModel.loadTips()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Tips Available")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("We couldn't generate tips for this goal. Try again later!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Tip Card

struct TipCard: View {
    let tip: GoalTip
    let number: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let category = tip.category {
                        Label(category.capitalized, systemImage: tip.categoryIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let priority = tip.priority {
                        Text(priority.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(tip.priorityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(tip.priorityColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(tip.tip)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

### 4. Integration with Goals List

```swift
import SwiftUI

extension GoalsListView {
    // Add this button to your toolbar or header
    var aiSuggestionsButton: some View {
        Button {
            showingSuggestions = true
        } label: {
            Label("AI Suggestions", systemImage: "sparkles")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showingSuggestions) {
            GoalSuggestionsView()
        }
    }
}

extension GoalDetailView {
    // Add this to goal detail view
    var aiTipsButton: some View {
        NavigationLink(destination: GoalTipsView(goalId: goal.id, goalTitle: goal.title)) {
            Label("Get AI Tips", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
```

---

## 🧩 View Models

### 1. Goal Suggestions ViewModel

```swift
import Foundation
import Combine

@MainActor
class GoalSuggestionsViewModel: ObservableObject {
    @Published var suggestions: [GoalSuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    
    private let aiService = GoalsAIService(apiKey: Config.apiKey)
    
    func loadSuggestions() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            suggestions = try await aiService.getGoalSuggestions()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refreshSuggestions() async {
        suggestions = []
        await loadSuggestions()
    }
    
    func acceptSuggestion(_ suggestion: GoalSuggestion) async {
        do {
            _ = try await aiService.createGoal(from: suggestion)
            showSuccess = true
            
            // Remove accepted suggestion from list
            suggestions.removeAll { $0.id == suggestion.id }
        } catch {
            errorMessage = "Failed to create goal: \(error.localizedDescription)"
        }
    }
}
```

### 2. Goal Tips ViewModel

```swift
import Foundation

@MainActor
class GoalTipsViewModel: ObservableObject {
    @Published var tips: [GoalTip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let goalId: String
    private let aiService = GoalsAIService(apiKey: Config.apiKey)
    
    init(goalId: String) {
        self.goalId = goalId
    }
    
    func loadTips() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await aiService.getGoalTips(goalId: goalId)
            tips = data.tips
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

---

## 🧪 Testing Strategy

### Unit Tests

```swift
import XCTest
@testable import FitIQ

class GoalsAIServiceTests: XCTestCase {
    var service: GoalsAIService!
    
    override func setUp() {
        super.setUp()
        service = GoalsAIService(apiKey: "test-api-key")
    }
    
    func testGetGoalSuggestions() async throws {
        // Test successful suggestions
        let suggestions = try await service.getGoalSuggestions()
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertGreaterThanOrEqual(suggestions.count, 3)
        XCTAssertLessThanOrEqual(suggestions.count, 5)
    }
    
    func testSuggestionHasRequiredFields() async throws {
        let suggestions = try await service.getGoalSuggestions()
        let first = suggestions[0]
        
        XCTAssertFalse(first.title.isEmpty)
        XCTAssertFalse(first.description.isEmpty)
        XCTAssertFalse(first.rationale.isEmpty)
        XCTAssertGreaterThan(first.difficulty, 0)
        XCTAssertLessThanOrEqual(first.difficulty, 5)
    }
    
    func testGetGoalTips() async throws {
        // Test with valid goal ID
        let tips = try await service.getGoalTips(goalId: "test-goal-id")
        XCTAssertFalse(tips.tips.isEmpty)
        XCTAssertGreaterThanOrEqual(tips.count, 5)
        XCTAssertLessThanOrEqual(tips.count, 7)
    }
    
    func testCreateGoalFromSuggestion() async throws {
        // Get suggestion first
        let suggestions = try await service.getGoalSuggestions()
        let suggestion = suggestions[0]
        
        // Create goal from suggestion
        let goal = try await service.createGoal(from: suggestion)
        
        XCTAssertEqual(goal.title, suggestion.title)
        XCTAssertEqual(goal.goalType, suggestion.goalType)
        XCTAssertNotNil(goal.id)
    }
    
    func testRateLimitHandling() async throws {
        // Test multiple rapid requests
        do {
            for _ in 0..<10 {
                _ = try await service.getGoalSuggestions()
            }
        } catch APIError.rateLimitExceeded {
            // Expected behavior
            XCTAssertTrue(true)
        }
    }
}
```

### Integration Tests

```swift
// Test complete user flow
func testGoalSuggestionsEndToEnd() async throws {
    let service = GoalsAIService(apiKey: Config.apiKey)
    
    // 1. Get suggestions
    let suggestions = try await service.getGoalSuggestions()
    XCTAssertFalse(suggestions.isEmpty)
    
    // 2. Select first suggestion
    let suggestion = suggestions[0]
    
    // 3. Create goal from suggestion
    let goal = try await service.createGoal(from: suggestion)
    XCTAssertEqual(goal.title, suggestion.title)
    
    // 4. Get tips for new goal
    let tips = try await service.getGoalTips(goalId: goal.id)
    XCTAssertFalse(tips.tips.isEmpty)
}
```

---

## ✅ Implementation Checklist

### Phase 1: Models & Service (0.5 days)
- [ ] Create `GoalSuggestion` model with computed properties
- [ ] Create `GoalTip` model with category icons
- [ ] Create `CreateGoalRequest.from(suggestion:)` helper
- [ ] Implement `GoalsAIService` with 3 methods
- [ ] Add rate limit error handling
- [ ] Test with Swagger UI

### Phase 2: Suggestions UI (0.5 days)
- [ ] Create `GoalSuggestionsView`
- [ ] Create `SuggestionCard` component
- [ ] Implement expand/collapse for rationale
- [ ] Add accept/create functionality
- [ ] Create `GoalSuggestionsViewModel`
- [ ] Add loading/error/empty states
- [ ] Test suggestion flow

### Phase 3: Tips UI (0.5 days)
- [ ] Create `GoalTipsView`
- [ ] Create `TipCard` component
- [ ] Add category icons and priority indicators
- [ ] Create `GoalTipsViewModel`
- [ ] Test tips loading
- [ ] Add to goal detail view

### Phase 4: Integration & Testing (0.5 days)
- [ ] Add "AI Suggestions" button to goals list
- [ ] Add "Get Tips" button to goal detail
- [ ] Write unit tests for service
- [ ] Write integration tests
- [ ] Test with real backend
- [ ] Handle edge cases (no data, errors)

---

## 🚨 Common Issues & Solutions

### Issue 1: No Suggestions Generated
**Cause:** Insufficient user data for AI analysis  
**Solution:** User needs tracking data (workouts, nutrition, sleep). Display helpful message.

### Issue 2: Rate Limit Exceeded
**Cause:** Too many AI requests in short time  
**Solution:** Implement exponential backoff, cache suggestions locally for 24 hours.

### Issue 3: Goal Creation Fails After Accepting
**Cause:** Network error or validation issue  
**Solution:** Show clear error, allow retry, don't remove suggestion from list until success.

### Issue 4: Tips Don't Match Goal
**Cause:** Goal context not properly sent to AI  
**Solution:** Verify goal ID is correct, check goal hasn't been deleted.

---

## 💡 Best Practices

### 1. Cache Suggestions
```swift
// Cache suggestions for 24 hours to reduce API calls
@AppStorage("cachedSuggestions") private var cachedSuggestionsData: Data?
@AppStorage("suggestionsTimestamp") private var timestamp: Double = 0

func shouldRefreshSuggestions() -> Bool {
    let now = Date().timeIntervalSince1970
    let dayInSeconds: Double = 86400
    return now - timestamp > dayInSeconds
}
```

### 2. Offline Handling
```swift
// Save suggestions locally for offline viewing
func saveSuggestionsLocally(_ suggestions: [GoalSuggestion]) {
    // Use SwiftData or UserDefaults
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(suggestions) {
        UserDefaults.standard.set(data, forKey: "goalSuggestions")
    }
}
```

### 3. Loading States
```swift
// Show progress for AI generation (can take 5-10 seconds)
var loadingView: some View {
    VStack(spacing: 16) {
        ProgressView()
            .scaleEffect(1.5)
        Text("Analyzing your wellness data...")
        Text("This may take a few seconds")
            .font(.caption)
    }
}
```

### 4. Success Feedback
```swift
// Haptic feedback on goal creation
func acceptSuggestion() async {
    await createGoal()
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}
```

---

## 📊 Performance Considerations

### API Response Times
- **Goal Suggestions**: 5-10 seconds (AI processing)
- **Goal Tips**: 3-5 seconds (AI processing)

### Optimization Strategies
1. **Show loading immediately** - Don't wait for API
2. **Cache aggressively** - 24-hour cache for suggestions
3. **Prefetch tips** - Load tips when user opens goal detail
4. **Background refresh** - Update suggestions while user browses

---

## 🔗 Integration Points

### Prerequisites
- ✅ Authentication (JWT token)
- ✅ User Profile (physical stats)
- ✅ Goals API (create/read goals)
- ✅ At least one tracking feature (activity, nutrition, sleep)

### Related Features
- **Goals**: Create goals from suggestions
- **AI Insights**: Suggestions consider recent insights
- **Consultations**: Discuss goals with AI coach
- **Progress Tracking**: Tips based on current progress

---

## 📚 Additional Resources

- **Swagger Docs**: [swagger-goals-ai.yaml](../../swagger-goals-ai.yaml)
- **API Playground**: https://fit-iq-backend.fly.dev/swagger/index.html
- **Goals API Guide**: [goals.md](goals.md)
- **Error Handling**: [../getting-started/03-error-handling.md](../getting-started/03-error-handling.md)

---

## 🎯 Next Steps

After implementing Goals AI:

1. **Enhanced Consultations** - [../ai-consultation/consultations-enhanced.md](../ai-consultation/consultations-enhanced.md)
   - Discuss goals with AI coach
   - Get real-time advice

2. **AI Insights** - [ai-insights.md](ai-insights.md)
   - Insights can reference goals
   - Goal progress tracked in insights

3. **Cross-Feature Integration** - Link suggestions, tips, insights, and consultations

---

**Ready to build? Start with Phase 1 and work through the checklist!** 🚀