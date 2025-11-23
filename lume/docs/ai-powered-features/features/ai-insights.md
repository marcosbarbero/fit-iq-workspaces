# 🧠 AI Insights - iOS Integration Guide

**Feature:** AI-powered wellness insights  
**Complexity:** Medium  
**Time Estimate:** 2-3 days  
**Prerequisites:** Authentication, User Profile, at least one tracking feature (nutrition, workouts, mood, or journal)

---

## 📋 Overview

AI Insights provide automated, personalized wellness analysis based on user activity, nutrition, mood, and goals. The system generates insights at regular intervals (daily, weekly) or for special occasions (milestones, patterns).

### What You'll Build
- Insights list view with filtering and sorting
- Insight detail view with actions
- Mark insights as read/unread
- Favorite insights
- Archive insights
- Pull-to-refresh for new insights

### Insight Types
- **Daily**: End-of-day summaries with actionable tips
- **Weekly**: Comprehensive weekly analysis and patterns
- **Milestone**: Celebration of achievements
- **Pattern**: Discovery of correlations and trends

---

## 🔑 Key Concepts

### Data Flow
```
Backend generates insights automatically
         ↓
User fetches insights list
         ↓
User views insight detail
         ↓
User marks as read/favorite/archived
         ↓
Backend tracks engagement
```

### Encryption
All sensitive fields (title, content, summary, suggestions) are **encrypted at rest** on the backend. API responses contain decrypted data ready for display - no client-side decryption needed.

### Timing
- **Daily Insights**: Generated nightly (backend automation)
- **Weekly Insights**: Generated weekly (backend automation)
- **Milestone/Pattern**: Generated on significant events

---

## 🏗️ Swift Models

### 1. Insight Model

```swift
import Foundation

struct Insight: Codable, Identifiable {
    let id: String
    let userId: String
    let insightType: InsightType
    let title: String
    let content: String
    let summary: String?
    let suggestions: [String]?
    let dataContext: DataContext?
    let isRead: Bool
    let isFavorite: Bool
    let isArchived: Bool
    let generatedAt: Date
    let readAt: Date?
    let archivedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case insightType = "insight_type"
        case title
        case content
        case summary
        case suggestions
        case dataContext = "data_context"
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case isArchived = "is_archived"
        case generatedAt = "generated_at"
        case readAt = "read_at"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum InsightType: String, Codable, CaseIterable {
    case daily
    case weekly
    case milestone
    case pattern
    
    var displayName: String {
        switch self {
        case .daily: return "Daily Insight"
        case .weekly: return "Weekly Summary"
        case .milestone: return "Milestone"
        case .pattern: return "Pattern Discovery"
        }
    }
    
    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .milestone: return "star.fill"
        case .pattern: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct DataContext: Codable {
    let dateRange: DateRange?
    let metrics: MetricsSummary?
    let goals: [String]?
    let achievements: [String]?
    
    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
        case metrics
        case goals
        case achievements
    }
}

struct DateRange: Codable {
    let startDate: Date
    let endDate: Date
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct MetricsSummary: Codable {
    let workouts: Int?
    let calories: Double?
    let steps: Int?
    let sleepHours: Double?
    let moodScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case workouts
        case calories
        case steps
        case sleepHours = "sleep_hours"
        case moodScore = "mood_score"
    }
}
```

### 2. API Response Models

```swift
struct InsightResponse: Codable {
    let success: Bool
    let data: Insight
}

struct InsightsListResponse: Codable {
    let success: Bool
    let data: InsightsData
}

struct InsightsData: Codable {
    let insights: [Insight]
    let pagination: Pagination
}

struct Pagination: Codable {
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let totalCount: Int
    let hasNext: Bool
    let hasPrev: Bool
    
    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case totalPages = "total_pages"
        case totalCount = "total_count"
        case hasNext = "has_next"
        case hasPrev = "has_prev"
    }
}

struct UpdateInsightRequest: Codable {
    let isRead: Bool?
    let isFavorite: Bool?
    let isArchived: Bool?
    
    enum CodingKeys: String, CodingKey {
        case isRead = "is_read"
        case isFavorite = "is_favorite"
        case isArchived = "is_archived"
    }
}
```

---

## 🔌 API Service

### InsightsService.swift

```swift
import Foundation

class InsightsService {
    private let baseURL = "https://fit-iq-backend.fly.dev/api/v1"
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - List Insights
    
    func listInsights(
        insightType: InsightType? = nil,
        readStatus: Bool? = nil,
        favoritesOnly: Bool = false,
        archivedStatus: Bool? = false,
        sortBy: String = "created_at",
        sortOrder: String = "desc",
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> InsightsData {
        var components = URLComponents(string: "\(baseURL)/insights")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: sortBy),
            URLQueryItem(name: "sort_order", value: sortOrder),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let insightType = insightType {
            queryItems.append(URLQueryItem(name: "insight_type", value: insightType.rawValue))
        }
        
        if let readStatus = readStatus {
            queryItems.append(URLQueryItem(name: "read_status", value: "\(readStatus)"))
        }
        
        if favoritesOnly {
            queryItems.append(URLQueryItem(name: "favorites_only", value: "true"))
        }
        
        if let archivedStatus = archivedStatus {
            queryItems.append(URLQueryItem(name: "archived_status", value: "\(archivedStatus)"))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let apiResponse = try decoder.decode(InsightsListResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Get Single Insight
    
    func getInsight(id: String) async throws -> Insight {
        let url = URL(string: "\(baseURL)/insights/\(id)")!
        
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
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let apiResponse = try decoder.decode(InsightResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Mark as Read
    
    func markAsRead(id: String) async throws -> Insight {
        return try await updateInsight(id: id, request: UpdateInsightRequest(isRead: true, isFavorite: nil, isArchived: nil))
    }
    
    // MARK: - Toggle Favorite
    
    func toggleFavorite(id: String, isFavorite: Bool) async throws -> Insight {
        return try await updateInsight(id: id, request: UpdateInsightRequest(isRead: nil, isFavorite: isFavorite, isArchived: nil))
    }
    
    // MARK: - Archive Insight
    
    func archiveInsight(id: String) async throws -> Insight {
        return try await updateInsight(id: id, request: UpdateInsightRequest(isRead: nil, isFavorite: nil, isArchived: true))
    }
    
    // MARK: - Unarchive Insight
    
    func unarchiveInsight(id: String) async throws -> Insight {
        return try await updateInsight(id: id, request: UpdateInsightRequest(isRead: nil, isFavorite: nil, isArchived: false))
    }
    
    // MARK: - Update Insight (Generic)
    
    private func updateInsight(id: String, request: UpdateInsightRequest) async throws -> Insight {
        let url = URL(string: "\(baseURL)/insights/\(id)")!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let apiResponse = try decoder.decode(InsightResponse.self, from: data)
        
        return apiResponse.data
    }
    
    // MARK: - Delete Insight
    
    func deleteInsight(id: String) async throws {
        let url = URL(string: "\(baseURL)/insights/\(id)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 204 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Helper
    
    private func getAuthToken() -> String {
        // Retrieve JWT token from Keychain
        // Implementation depends on your auth storage strategy
        return KeychainManager.shared.getToken() ?? ""
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
```

---

## 🎨 SwiftUI Views

### 1. Insights List View

```swift
import SwiftUI

struct InsightsListView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedFilter: InsightType?
    @State private var showUnreadOnly = false
    @State private var showFavoritesOnly = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                filterBar
                
                // Content
                if viewModel.isLoading && viewModel.insights.isEmpty {
                    loadingView
                } else if viewModel.insights.isEmpty {
                    emptyStateView
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showFavoritesOnly.toggle() }) {
                            Label(showFavoritesOnly ? "Show All" : "Show Favorites", 
                                  systemImage: "star.fill")
                        }
                        
                        Button(action: { showUnreadOnly.toggle() }) {
                            Label(showUnreadOnly ? "Show All" : "Show Unread", 
                                  systemImage: "envelope.badge")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadInsights()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )
                
                ForEach(InsightType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        icon: type.icon,
                        isSelected: selectedFilter == type,
                        action: { selectedFilter = type }
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .onChange(of: selectedFilter) { _ in
            Task {
                await viewModel.filterBy(type: selectedFilter, 
                                        unreadOnly: showUnreadOnly,
                                        favoritesOnly: showFavoritesOnly)
            }
        }
        .onChange(of: showUnreadOnly) { _ in
            Task {
                await viewModel.filterBy(type: selectedFilter, 
                                        unreadOnly: showUnreadOnly,
                                        favoritesOnly: showFavoritesOnly)
            }
        }
        .onChange(of: showFavoritesOnly) { _ in
            Task {
                await viewModel.filterBy(type: selectedFilter, 
                                        unreadOnly: showUnreadOnly,
                                        favoritesOnly: showFavoritesOnly)
            }
        }
    }
    
    private var insightsList: some View {
        List {
            ForEach(viewModel.insights) { insight in
                NavigationLink(destination: InsightDetailView(insight: insight)) {
                    InsightRow(insight: insight)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task {
                            await viewModel.toggleFavorite(insight: insight)
                        }
                    } label: {
                        Label("Favorite", systemImage: insight.isFavorite ? "star.slash" : "star.fill")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.archiveInsight(insight: insight)
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
            
            // Pagination
            if viewModel.hasMorePages {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .onAppear {
                    Task {
                        await viewModel.loadNextPage()
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading insights...")
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Insights are generated automatically based on your activity. Check back later!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}
```

### 2. Insight Row

```swift
import SwiftUI

struct InsightRow: View {
    let insight: Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: insight.insightType.icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if !insight.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                if let summary = insight.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(insight.generatedAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if insight.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    if let suggestions = insight.suggestions, !suggestions.isEmpty {
                        Label("\(suggestions.count)", systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var iconColor: Color {
        switch insight.insightType {
        case .daily:
            return .orange
        case .weekly:
            return .blue
        case .milestone:
            return .yellow
        case .pattern:
            return .green
        }
    }
}
```

### 3. Insight Detail View

```swift
import SwiftUI

struct InsightDetailView: View {
    @StateObject private var viewModel: InsightDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(insight: Insight) {
        _viewModel = StateObject(wrappedValue: InsightDetailViewModel(insight: insight))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Content
                contentSection
                
                // Summary
                if let summary = viewModel.insight.summary {
                    summarySection(summary)
                }
                
                // Suggestions
                if let suggestions = viewModel.insight.suggestions, !suggestions.isEmpty {
                    suggestionsSection(suggestions)
                }
                
                // Context Data
                if let context = viewModel.insight.dataContext {
                    contextSection(context)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task {
                            await viewModel.toggleFavorite()
                        }
                    } label: {
                        Label(viewModel.insight.isFavorite ? "Unfavorite" : "Favorite",
                              systemImage: viewModel.insight.isFavorite ? "star.slash" : "star.fill")
                    }
                    
                    ShareLink(item: viewModel.insight.title)
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        Task {
                            await viewModel.archiveInsight()
                            dismiss()
                        }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.markAsRead()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: viewModel.insight.insightType.icon)
                    .font(.title)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.insight.insightType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.insight.generatedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.insight.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            Text(viewModel.insight.title)
                .font(.title2)
                .fontWeight(.bold)
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis")
                .font(.headline)
            
            Text(viewModel.insight.content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Key Takeaway", systemImage: "key.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(summary)
                .font(.body)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func suggestionsSection(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Action Steps", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text(suggestion)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func contextSection(_ context: DataContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Summary")
                .font(.headline)
            
            if let metrics = context.metrics {
                MetricsGrid(metrics: metrics)
            }
            
            if let achievements = context.achievements, !achievements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Achievements", systemImage: "trophy.fill")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                    
                    ForEach(achievements, id: \.self) { achievement in
                        Text("• \(achievement)")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var iconColor: Color {
        switch viewModel.insight.insightType {
        case .daily: return .orange
        case .weekly: return .blue
        case .milestone: return .yellow
        case .pattern: return .green
        }
    }
}

// MARK: - Metrics Grid

struct MetricsGrid: View {
    let metrics: MetricsSummary
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            if let workouts = metrics.workouts {
                MetricCard(title: "Workouts", value: "\(workouts)", icon: "figure.run")
            }
            
            if let steps = metrics.steps {
                MetricCard(title: "Steps", value: "\(steps)", icon: "figure.walk")
            }
            
            if let calories = metrics.calories {
                MetricCard(title: "Calories", value: "\(Int(calories))", icon: "flame.fill")
            }
            
            if let sleepHours = metrics.sleepHours {
                MetricCard(title: "Sleep", value: String(format: "%.1fh", sleepHours), icon: "bed.double.fill")
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}
```

---

## 🧩 View Models

### 1. Insights List ViewModel

```swift
import Foundation
import Combine

@MainActor
class InsightsViewModel: ObservableObject {
    @Published var insights: [Insight] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var hasMorePages = false
    
    private let service = InsightsService(apiKey: Config.apiKey)
    private var currentPage = 1
    private var totalPages = 1
    private var currentFilters: (type: InsightType?, unread: Bool, favorites: Bool) = (nil, false, false)
    
    func loadInsights() async {
        guard !isLoading else { return }
        
        isLoading = true
        currentPage = 1
        
        do {
            let data = try await service.listInsights(
                insightType: currentFilters.type,
                readStatus: currentFilters.unread ? false : nil,
                favoritesOnly: currentFilters.favorites,
                archivedStatus: false,
                page: currentPage
            )
            
            insights = data.insights
            totalPages = data.pagination.totalPages
            hasMorePages = data.pagination.hasNext
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func loadNextPage() async {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        currentPage += 1
        
        do {
            let data = try await service.listInsights(
                insightType: currentFilters.type,
                readStatus: currentFilters.unread ? false : nil,
                favoritesOnly: currentFilters.favorites,
                archivedStatus: false,
                page: currentPage
            )
            
            insights.append(contentsOf: data.insights)
            hasMorePages = data.pagination.hasNext
            
        } catch {
            currentPage -= 1 // Rollback on error
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func filterBy(type: InsightType?, unreadOnly: Bool, favoritesOnly: Bool) async {
        currentFilters = (type, unreadOnly, favoritesOnly)
        await loadInsights()
    }
    
    func refresh() async {
        await loadInsights()
    }
    
    func toggleFavorite(insight: Insight) async {
        do {
            let updated = try await service.toggleFavorite(id: insight.id, isFavorite: !insight.isFavorite)
            
            if let index = insights.firstIndex(where: { $0.id == insight.id }) {
                insights[index] = updated
            }
        } catch {
            errorMessage = "Failed to update favorite status"
            showError = true
        }
    }
    
    func archiveInsight(insight: Insight) async {
        do {
            _ = try await service.archiveInsight(id: insight.id)
            insights.removeAll { $0.id == insight.id }
        } catch {
            errorMessage = "Failed to archive insight"
            showError = true
        }
    }
}
```

### 2. Insight Detail ViewModel

```swift
import Foundation

@MainActor
class InsightDetailViewModel: ObservableObject {
    @Published var insight: Insight
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let service = InsightsService(apiKey: Config.apiKey)
    
    init(insight: Insight) {
        self.insight = insight
    }
    
    func markAsRead() async {
        guard !insight.isRead else { return }
        
        do {
            insight = try await service.markAsRead(id: insight.id)
        } catch {
            // Silently fail - not critical
            print("Failed to mark as read: \(error)")
        }
    }
    
    func toggleFavorite() async {
        do {
            insight = try await service.toggleFavorite(id: insight.id, isFavorite: !insight.isFavorite)
        } catch {
            errorMessage = "Failed to update favorite status"
            showError = true
        }
    }
    
    func archiveInsight() async {
        do {
            insight = try await service.archiveInsight(id: insight.id)
        } catch {
            errorMessage = "Failed to archive insight"
            showError = true
        }
    }
}
```

---

## 🧪 Testing Strategy

### Unit Tests

```swift
import XCTest
@testable import FitIQ

class InsightsServiceTests: XCTestCase {
    var service: InsightsService!
    
    override func setUp() {
        super.setUp()
        service = InsightsService(apiKey: "test-api-key")
    }
    
    func testListInsights() async throws {
        // Test successful list
        let data = try await service.listInsights()
        XCTAssertNotNil(data)
        XCTAssertNotNil(data.pagination)
    }
    
    func testFilterByType() async throws {
        // Test filtering by insight type
        let data = try await service.listInsights(insightType: .daily)
        XCTAssertTrue(data.insights.allSatisfy { $0.insightType == .daily })
    }
    
    func testMarkAsRead() async throws {
        // Test marking insight as read
        let insight = try await service.markAsRead(id: "test-id")
        XCTAssertTrue(insight.isRead)
        XCTAssertNotNil(insight.readAt)
    }
    
    func testToggleFavorite() async throws {
        // Test favoriting
        let insight = try await service.toggleFavorite(id: "test-id", isFavorite: true)
        XCTAssertTrue(insight.isFavorite)
    }
}
```

### Integration Testing

```swift
// Test with real backend
func testInsightsEndToEnd() async throws {
    let service = InsightsService(apiKey: Config.apiKey)
    
    // 1. List insights
    let data = try await service.listInsights()
    XCTAssertFalse(data.insights.isEmpty)
    
    // 2. Get first insight
    let firstInsight = data.insights[0]
    let detailed = try await service.getInsight(id: firstInsight.id)
    XCTAssertEqual(detailed.id, firstInsight.id)
    
    // 3. Mark as read
    let read = try await service.markAsRead(id: firstInsight.id)
    XCTAssertTrue(read.isRead)
    
    // 4. Toggle favorite
    let favorited = try await service.toggleFavorite(id: firstInsight.id, isFavorite: true)
    XCTAssertTrue(favorited.isFavorite)
}
```

---

## ✅ Implementation Checklist

### Phase 1: Models & Service (1 day)
- [ ] Create `Insight` model with all fields
- [ ] Create `InsightType` enum
- [ ] Create `DataContext` and supporting models
- [ ] Create `InsightsService` with all endpoints
- [ ] Add authentication token management
- [ ] Test API calls with Swagger

### Phase 2: List View (1 day)
- [ ] Create `InsightsListView`
- [ ] Implement filtering by type
- [ ] Add unread/favorites filters
- [ ] Implement pagination
- [ ] Add pull-to-refresh
- [ ] Add swipe actions (favorite, archive)
- [ ] Create `InsightsViewModel`
- [ ] Test list loading and filtering

### Phase 3: Detail View (1 day)
- [ ] Create `InsightDetailView`
- [ ] Display content, summary, suggestions
- [ ] Show data context and metrics
- [ ] Implement mark as read on view
- [ ] Add favorite/archive actions
- [ ] Create `InsightDetailViewModel`
- [ ] Add share functionality
- [ ] Test detail view interactions

### Phase 4: Polish & Testing (0.5 days)
- [ ] Add loading states
- [ ] Add empty states
- [ ] Handle errors gracefully
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Test with real backend
- [ ] Performance optimization

---

## 🚨 Common Issues & Solutions

### Issue 1: Empty Insights List
**Cause:** Insights are generated by backend automation  
**Solution:** Ensure user has tracking data (workouts, nutrition, mood). Insights generation may take 24 hours.

### Issue 2: Decryption Errors
**Cause:** Backend handles all encryption/decryption  
**Solution:** No client-side decryption needed. If data looks encrypted, check backend logs.

### Issue 3: Pagination Not Loading
**Cause:** Not checking `hasNext` before loading  
**Solution:** Always check `pagination.hasNext` before loading next page

### Issue 4: Dates Not Displaying
**Cause:** Date decoding strategy mismatch  
**Solution:** Use `.iso8601` date decoding strategy

---

## 📚 Additional Resources

- **Swagger Docs**: [swagger-insights.yaml](../../swagger-insights.yaml)
- **API Playground**: https://fit-iq-backend.fly.dev/swagger/index.html
- **Date Handling Guide**: [../guides/date-handling.md](../guides/date-handling.md)
- **Pagination Guide**: [../guides/pagination.md](../guides/pagination.md)
- **Error Handling**: [../getting-started/03-error-handling.md](../getting-started/03-error-handling.md)

---

## 🎯 Next Steps

After implementing AI Insights:

1. **Goals AI Integration** - [goals-ai.md](goals-ai.md)
   - AI-generated goal suggestions
   - Contextual tips for existing goals

2. **Enhanced Consultations** - [../ai-consultation/01-overview.md](../ai-consultation/01-overview.md)
   - Discuss insights with AI coach
   - Get deeper analysis

3. **Cross-Feature Integration** - Link insights to goals, consultations, and tracking data

---

**Ready to build? Start with Phase 1 and work through the checklist incrementally!** 🚀