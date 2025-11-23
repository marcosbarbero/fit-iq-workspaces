# Journaling Feature - Implementation Sprint Plan

**Date:** 2025-01-15  
**Status:** 🚀 Ready to Execute  
**Timeline:** 2 weeks for critical + enhancements

---

## Executive Summary

This sprint plan addresses:
1. **Critical Gaps** - Mood linking, offline detection, testing
2. **Enhancements** - Entry templates (#7), Rich text (#8), AI insights (#10)
3. **Dashboard** - Statistics view similar to MoodTrackingView

**Backend Endpoints Available:**
- `/api/v1/journal/statistics` - Get journal statistics
- `/api/v1/prompts` or `/api/v1/journal/prompts` - Get AI writing prompts
- All CRUD endpoints already integrated ✅

---

## Sprint Overview

### Week 1: Critical Gaps
- Day 1-2: Mood Linking Implementation
- Day 3: Offline Detection & Network Monitoring
- Day 4: Journal Dashboard View
- Day 5: Testing & Bug Fixes

### Week 2: Enhancements
- Day 1-2: Entry Templates (#7)
- Day 3-4: Rich Text / Markdown Support (#8)
- Day 5: AI Insights & Prompts (#10)

---

## Day 1-2: Mood Linking Implementation

### Priority: 🔴 Critical
**Goal:** Make mood linking fully functional

### Current State
- ✅ UI shows prompt to link moods
- ✅ `linkedMoodId` field in JournalEntry
- ✅ Backend API supports mood linking
- ✅ Domain methods exist (`linkToMood()`, `unlinkFromMood()`)
- ❌ No linking logic in ViewModel
- ❌ No bidirectional navigation
- ❌ No visual indicator in detail view

### Implementation Tasks

#### 1. Add Mood Linking to JournalViewModel

```swift
// JournalViewModel.swift

import Foundation

@MainActor
class JournalViewModel: ObservableObject {
    // ... existing properties ...
    
    // MARK: - Mood Linking
    
    /// Link journal entry to a mood
    func linkToMood(_ moodId: UUID, for entry: JournalEntry) async {
        var updatedEntry = entry
        updatedEntry.linkToMood(moodId)
        await updateEntry(updatedEntry)
    }
    
    /// Unlink journal entry from mood
    func unlinkFromMood(for entry: JournalEntry) async {
        var updatedEntry = entry
        updatedEntry.unlinkFromMood()
        await updateEntry(updatedEntry)
    }
    
    /// Get recent moods for linking (within last 7 days)
    func getRecentMoodsForLinking() async -> [MoodEntry] {
        // This will require coordination with MoodViewModel
        // For now, return empty array - will implement with dependency injection
        return []
    }
}
```

#### 2. Update JournalEntryView for Mood Linking

```swift
// JournalEntryView.swift

// Add state variable
@State private var showingMoodLinkPicker = false
@State private var availableMoods: [MoodEntry] = []

// Add in toolbar
ToolbarItem(placement: .navigationBarTrailing) {
    if let existingEntry = existingEntry {
        Button {
            showingMoodLinkPicker = true
        } label: {
            Image(systemName: existingEntry.isLinkedToMood ? "link.circle.fill" : "link.circle")
                .foregroundColor(LumeColors.textPrimary)
        }
    }
}

// Add sheet
.sheet(isPresented: $showingMoodLinkPicker) {
    MoodLinkPickerView(
        currentMoodId: existingEntry?.linkedMoodId,
        onSelect: { moodId in
            if let entry = existingEntry {
                Task {
                    await viewModel.linkToMood(moodId, for: entry)
                }
            }
            showingMoodLinkPicker = false
        },
        onUnlink: {
            if let entry = existingEntry {
                Task {
                    await viewModel.unlinkFromMood(for: entry)
                }
            }
            showingMoodLinkPicker = false
        }
    )
}
```

#### 3. Create MoodLinkPickerView Component

```swift
// Components/MoodLinkPickerView.swift

import SwiftUI

struct MoodLinkPickerView: View {
    @Environment(\.dismiss) var dismiss
    let currentMoodId: UUID?
    let onSelect: (UUID) -> Void
    let onUnlink: () -> Void
    
    // TODO: Inject MoodViewModel to fetch recent moods
    @State private var recentMoods: [MoodEntry] = []
    
    var body: some View {
        NavigationStack {
            List {
                if let currentMoodId = currentMoodId {
                    Section {
                        Button(role: .destructive) {
                            onUnlink()
                        } label: {
                            HStack {
                                Image(systemName: "link.badge.minus")
                                Text("Unlink from Mood")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                Section("Recent Moods (Last 7 Days)") {
                    if recentMoods.isEmpty {
                        Text("No recent mood entries found")
                            .foregroundColor(LumeColors.textSecondary)
                            .font(LumeTypography.bodySmall)
                    } else {
                        ForEach(recentMoods) { mood in
                            MoodLinkRow(
                                mood: mood,
                                isSelected: mood.id == currentMoodId,
                                onTap: {
                                    onSelect(mood.id)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Link to Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
```

#### 4. Update JournalEntryDetailView to Show Linked Mood

```swift
// JournalEntryDetailView.swift

// Add after tags section
if entry.isLinkedToMood {
    VStack(alignment: .leading, spacing: 8) {
        Text("Linked Mood")
            .font(LumeTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(LumeColors.textSecondary)
        
        // TODO: Fetch and display mood details
        HStack {
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundColor(LumeColors.textSecondary)
            
            Text("Mood Entry")
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(LumeColors.textSecondary)
        }
        .padding(12)
        .background(LumeColors.surface)
        .cornerRadius(12)
    }
}
```

#### 5. Bidirectional Navigation Setup

```swift
// Create protocol for cross-feature navigation
protocol JournalMoodCoordinator {
    func getMoodEntry(id: UUID) async -> MoodEntry?
    func getRecentMoods(days: Int) async -> [MoodEntry]
    func getJournalEntries(linkedToMood: UUID) async -> [JournalEntry]
}

// Implement in AppDependencies
class AppMoodJournalCoordinator: JournalMoodCoordinator {
    private let moodRepository: MoodRepositoryProtocol
    private let journalRepository: JournalRepositoryProtocol
    
    init(moodRepository: MoodRepositoryProtocol, journalRepository: JournalRepositoryProtocol) {
        self.moodRepository = moodRepository
        self.journalRepository = journalRepository
    }
    
    func getMoodEntry(id: UUID) async -> MoodEntry? {
        // Fetch from repository
        return nil
    }
    
    func getRecentMoods(days: Int) async -> [MoodEntry] {
        // Fetch recent moods
        return []
    }
    
    func getJournalEntries(linkedToMood: UUID) async -> [JournalEntry] {
        do {
            return try await journalRepository.fetchLinkedToMood(linkedToMood)
        } catch {
            return []
        }
    }
}
```

### Testing Checklist
- [ ] Link journal entry to mood from editor
- [ ] Link journal entry to mood from detail view
- [ ] See linked mood indicator in entry card
- [ ] Navigate from journal to linked mood
- [ ] Navigate from mood to linked journal entries
- [ ] Unlink mood from journal
- [ ] Delete mood → verify journal link cleared (cascade)
- [ ] Delete journal → verify mood link cleared (cascade)
- [ ] Sync preserves mood links to backend

---

## Day 3: Offline Detection & Network Monitoring

### Priority: 🟡 High
**Goal:** Clear user feedback about offline state

### Implementation Tasks

#### 1. Add Network Monitoring to JournalViewModel

```swift
// JournalViewModel.swift

import Network

@MainActor
class JournalViewModel: ObservableObject {
    // ... existing properties ...
    
    @Published var isOffline = false
    private var networkMonitor: NWPathMonitor?
    
    init(...) {
        // ... existing init ...
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor?.cancel()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOffline = (path.status != .satisfied)
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global(qos: .background))
    }
    
    var syncStatusMessage: String {
        if isOffline {
            let count = statistics.pendingSyncCount
            return count > 0 
                ? "📡 Offline - \(count) \(count == 1 ? "entry" : "entries") waiting to sync"
                : "📡 Offline"
        } else if statistics.pendingSyncCount > 0 {
            return "⟳ Syncing \(statistics.pendingSyncCount) \(statistics.pendingSyncCount == 1 ? "entry" : "entries")..."
        } else {
            return ""
        }
    }
}
```

#### 2. Update JournalEntryCard Sync Indicator

```swift
// JournalEntryCard.swift

@ViewBuilder
private var syncStatusIndicator: some View {
    Button(action: { showingSyncInfo = true }) {
        if viewModel.isOffline && entry.needsSync {
            Image(systemName: "wifi.slash")
                .font(.system(size: 10))
                .foregroundColor(LumeColors.textSecondary.opacity(0.5))
        } else if !entry.isSynced && entry.needsSync {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#F2C9A7").opacity(0.7))
                .rotationEffect(.degrees(entry.isSynced ? 0 : 360))
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: entry.isSynced
                )
        } else if entry.isSynced {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#059669").opacity(0.7))
        }
    }
    .buttonStyle(.plain)
}
```

#### 3. Add Offline Banner to JournalListView

```swift
// JournalListView.swift

// Add at top of ZStack
if viewModel.isOffline && viewModel.statistics.pendingSyncCount > 0 {
    VStack {
        HStack {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14))
            
            Text(viewModel.syncStatusMessage)
                .font(LumeTypography.bodySmall)
            
            Spacer()
        }
        .foregroundColor(LumeColors.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LumeColors.surface.opacity(0.95))
                .shadow(color: LumeColors.textPrimary.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        
        Spacer()
    }
    .transition(.move(edge: .top).combined(with: .opacity))
    .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
    .zIndex(1)
}
```

### Testing Checklist
- [ ] Enable airplane mode → see offline banner
- [ ] Create entries while offline → see wifi.slash icon
- [ ] Disable airplane mode → banner disappears
- [ ] Entries sync automatically when online
- [ ] Banner shows correct entry count
- [ ] Toggle WiFi/cellular → correct detection

---

## Day 4: Journal Dashboard View

### Priority: 🟡 High
**Goal:** Statistics dashboard similar to MoodTrackingView

### Implementation Tasks

#### 1. Create JournalDashboardView

```swift
// Views/JournalDashboardView.swift

import SwiftUI
import Charts

struct JournalDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: JournalViewModel
    @State private var selectedPeriod: TimePeriod = .week
    
    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Time period selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TimePeriod.allCases) { period in
                            PeriodButton(
                                period: period,
                                isSelected: selectedPeriod == period
                            ) {
                                withAnimation {
                                    selectedPeriod = period
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(LumeColors.surface)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Stats Card
                        JournalSummaryCard(
                            stats: viewModel.dashboardStats(for: selectedPeriod),
                            period: selectedPeriod
                        )
                        
                        // Entry Type Distribution Chart
                        EntryTypeChartCard(
                            entries: viewModel.entries(for: selectedPeriod),
                            period: selectedPeriod
                        )
                        
                        // Writing Activity Chart
                        WritingActivityChartCard(
                            entries: viewModel.entries(for: selectedPeriod),
                            period: selectedPeriod
                        )
                        
                        // Top Tags Card
                        TopTagsCard(
                            tags: viewModel.topTags(for: selectedPeriod)
                        )
                        
                        // Streaks Card
                        StreaksCard(
                            currentStreak: viewModel.currentStreak,
                            longestStreak: viewModel.longestStreak
                        )
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Journal Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(LumeColors.textPrimary)
            }
        }
    }
}
```

#### 2. Add Dashboard Stats to JournalViewModel

```swift
// JournalViewModel.swift

struct DashboardStats {
    let totalEntries: Int
    let totalWords: Int
    let averageWordsPerEntry: Int
    let favoriteCount: Int
    let linkedMoodCount: Int
    let uniqueTags: Int
}

func dashboardStats(for period: TimePeriod) -> DashboardStats {
    let filteredEntries = entries(for: period)
    let totalWords = filteredEntries.reduce(0) { $0 + $1.wordCount }
    
    return DashboardStats(
        totalEntries: filteredEntries.count,
        totalWords: totalWords,
        averageWordsPerEntry: filteredEntries.isEmpty ? 0 : totalWords / filteredEntries.count,
        favoriteCount: filteredEntries.filter(\.isFavorite).count,
        linkedMoodCount: filteredEntries.filter(\.isLinkedToMood).count,
        uniqueTags: Set(filteredEntries.flatMap(\.tags)).count
    )
}

func entries(for period: TimePeriod) -> [JournalEntry] {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
    return entries.filter { $0.date >= cutoffDate }
}

func topTags(for period: TimePeriod, limit: Int = 10) -> [(String, Int)] {
    let periodEntries = entries(for: period)
    let tagCounts = Dictionary(
        periodEntries
            .flatMap { $0.tags }
            .map { ($0, 1) },
        uniquingKeysWith: +
    )
    return tagCounts.sorted { $0.value > $1.value }.prefix(limit).map { $0 }
}
```

#### 3. Add Dashboard Button to JournalListView Toolbar

```swift
// JournalListView.swift

ToolbarItemGroup(placement: .navigationBarTrailing) {
    // Dashboard button
    Button {
        showingDashboard = true
    } label: {
        Image(systemName: "chart.bar.fill")
            .foregroundColor(LumeColors.textPrimary)
    }
    
    // ... existing date picker and other buttons ...
}

.sheet(isPresented: $showingDashboard) {
    NavigationStack {
        JournalDashboardView(viewModel: viewModel)
    }
}
```

#### 4. Integrate Backend Statistics Endpoint

```swift
// JournalBackendService.swift

func fetchStatistics(accessToken: String) async throws -> JournalStatistics {
    let response: JournalStatisticsResponse = try await httpClient.get(
        path: "/api/v1/journal/statistics",
        accessToken: accessToken
    )
    return response.toStatistics()
}

struct JournalStatisticsResponse: Codable {
    let totalEntries: Int
    let currentStreak: Int
    let longestStreak: Int
    let totalWords: Int
    let entryTypeDistribution: [String: Int]
    let topTags: [TagCount]
    
    struct TagCount: Codable {
        let tag: String
        let count: Int
    }
    
    func toStatistics() -> JournalStatistics {
        JournalStatistics(
            totalEntries: totalEntries,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalWords: totalWords,
            entryTypeDistribution: entryTypeDistribution,
            topTags: topTags.map { ($0.tag, $0.count) }
        )
    }
}
```

### Testing Checklist
- [ ] Dashboard opens from toolbar
- [ ] All time periods display correctly
- [ ] Summary stats are accurate
- [ ] Charts render properly
- [ ] Top tags show correct counts
- [ ] Streaks calculated correctly

---

## Day 5: Testing & Bug Fixes

### Manual Testing Checklist

**Mood Linking**
- [ ] Link entry to mood
- [ ] Unlink entry from mood
- [ ] Navigate journal → mood
- [ ] Navigate mood → journal
- [ ] Delete mood with linked journal
- [ ] Delete journal with linked mood

**Offline Mode**
- [ ] Create entries offline
- [ ] Edit entries offline
- [ ] Delete entries offline
- [ ] Go online → verify sync
- [ ] Offline banner shows/hides correctly

**Dashboard**
- [ ] All stats accurate
- [ ] Charts render correctly
- [ ] Time periods switch smoothly
- [ ] Performance with 100+ entries

**Bug Fixes**
- Document any issues found
- Fix critical bugs
- Defer minor issues to backlog

---

## Week 2: Enhancements

## Day 1-2: Entry Templates (#7)

### Priority: 🟢 Low
**Goal:** Pre-built and custom entry templates

### Implementation Tasks

#### 1. Create Template Model

```swift
// Domain/Entities/EntryTemplate.swift

struct EntryTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var entryType: EntryType
    var contentTemplate: String
    var defaultTags: [String]
    var isCustom: Bool
    var createdAt: Date
    
    static let builtInTemplates: [EntryTemplate] = [
        EntryTemplate(
            id: UUID(),
            name: "Daily Gratitude",
            description: "Reflect on what you're grateful for",
            entryType: .gratitude,
            contentTemplate: "Today I'm grateful for:\n\n1. \n2. \n3. \n\nWhy this matters to me:\n",
            defaultTags: ["gratitude", "daily"],
            isCustom: false,
            createdAt: Date()
        ),
        EntryTemplate(
            id: UUID(),
            name: "Weekly Review",
            description: "Reflect on your week",
            entryType: .goalReview,
            contentTemplate: "## Wins This Week\n\n\n## Challenges\n\n\n## Lessons Learned\n\n\n## Next Week's Focus\n",
            defaultTags: ["review", "weekly"],
            isCustom: false,
            createdAt: Date()
        ),
        // ... more templates
    ]
}
```

#### 2. Template Selection UI

```swift
// Views/TemplateSelectionView.swift

struct TemplateSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (EntryTemplate) -> Void
    
    @State private var templates: [EntryTemplate] = EntryTemplate.builtInTemplates
    @State private var showingCustomTemplateEditor = false
    
    var body: some View {
        List {
            Section("Built-in Templates") {
                ForEach(templates.filter { !$0.isCustom }) { template in
                    TemplateRow(template: template) {
                        onSelect(template)
                        dismiss()
                    }
                }
            }
            
            Section("My Templates") {
                ForEach(templates.filter(\.isCustom)) { template in
                    TemplateRow(template: template) {
                        onSelect(template)
                        dismiss()
                    }
                }
                
                Button {
                    showingCustomTemplateEditor = true
                } label: {
                    Label("Create Template", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Choose Template")
    }
}
```

#### 3. Integrate Templates into Entry Creation

```swift
// JournalListView.swift

Button {
    showingTemplateSelection = true
} label: {
    // FAB
}

.sheet(isPresented: $showingTemplateSelection) {
    NavigationStack {
        TemplateSelectionView { template in
            // Create entry from template
            selectedTemplate = template
            showingNewEntry = true
        }
    }
}
```

---

## Day 3-4: Rich Text / Markdown Support (#8)

### Priority: 🟢 Low
**Goal:** Markdown rendering and formatting

### Implementation Tasks

#### 1. Add Markdown Package

```swift
// Package.swift or Xcode project

dependencies: [
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0")
]
```

#### 2. Markdown Editor with Toolbar

```swift
// Views/MarkdownEditorView.swift

import MarkdownUI

struct MarkdownEditorView: View {
    @Binding var text: String
    @State private var showPreview = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    FormatButton(icon: "bold", action: { insertMarkdown("**", "**") })
                    FormatButton(icon: "italic", action: { insertMarkdown("*", "*") })
                    FormatButton(icon: "strikethrough", action: { insertMarkdown("~~", "~~") })
                    FormatButton(icon: "list.bullet", action: { insertMarkdown("\n- ", "") })
                    FormatButton(icon: "list.number", action: { insertMarkdown("\n1. ", "") })
                    FormatButton(icon: "checkmark.square", action: { insertMarkdown("\n- [ ] ", "") })
                    
                    Divider()
                    
                    Button {
                        showPreview.toggle()
                    } label: {
                        Label(showPreview ? "Edit" : "Preview", 
                              systemImage: showPreview ? "pencil" : "eye")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(LumeColors.surface)
            
            // Editor or Preview
            if showPreview {
                ScrollView {
                    Markdown(text)
                        .markdownTheme(.lume)
                        .padding(20)
                }
            } else {
                TextEditor(text: $text)
                    .font(LumeTypography.body)
                    .padding(20)
            }
        }
    }
    
    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        text += prefix + suffix
    }
}
```

#### 3. Custom Markdown Theme

```swift
// Extensions/MarkdownTheme+Lume.swift

extension Theme {
    static let lume = Theme()
        .text {
            ForegroundColor(LumeColors.textPrimary)
            FontFamily(LumeTypography.bodyFont)
        }
        .heading1 { config in
            config.label
                .foregroundColor(LumeColors.textPrimary)
                .font(LumeTypography.titleLarge)
                .fontWeight(.bold)
        }
        // ... more styling
}
```

#### 4. Update Detail View for Markdown

```swift
// JournalEntryDetailView.swift

if entry.content.contains(markdownIndicators) {
    Markdown(entry.content)
        .markdownTheme(.lume)
} else {
    Text(entry.content)
        .font(LumeTypography.body)
        .foregroundColor(LumeColors.textPrimary)
}
```

---

## Day 5: AI Insights & Prompts (#10)

### Priority: 🟢 Low
**Goal:** Writing prompts and AI insights

### Implementation Tasks

#### 1. Add Prompts Service

```swift
// Services/Backend/JournalPromptsService.swift

protocol JournalPromptsServiceProtocol {
    func fetchDailyPrompt(accessToken: String) async throws -> WritingPrompt
    func fetchPrompts(category: String?, accessToken: String) async throws -> [WritingPrompt]
}

final class JournalPromptsService: JournalPromptsServiceProtocol {
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }
    
    func fetchDailyPrompt(accessToken: String) async throws -> WritingPrompt {
        let response: PromptResponse = try await httpClient.get(
            path: "/api/v1/journal/prompts/daily",
            accessToken: accessToken
        )
        return response.toPrompt()
    }
    
    func fetchPrompts(category: String?, accessToken: String) async throws -> [WritingPrompt] {
        var path = "/api/v1/journal/prompts"
        if let category = category {
            path += "?category=\(category)"
        }
        
        let response: PromptsResponse = try await httpClient.get(
            path: path,
            accessToken: accessToken
        )
        return response.prompts.map { $0.toPrompt() }
    }
}

struct WritingPrompt: Identifiable, Codable {
    let id: UUID
    let title: String
    let prompt: String
    let category: String
    let entryType: EntryType
    let suggestedTags: [String]
}
```

#### 2. Daily Prompt Card

```swift
// Components/DailyPromptCard.swift

struct DailyPromptCard: View {
    let prompt: WritingPrompt
    let onUse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#F2C9A7"))
                
                Text("Today's Prompt")
                    .font(LumeTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textSecondary)
                
                Spacer()
            }
            
            Text(prompt.prompt)
                .font(LumeTypography.body)
                .foregroundColor(LumeColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                onUse()
            } label: {
                Text("Use This Prompt")
                    .font(LumeTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(LumeColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#F2C9A7"))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LumeColors.surface)
                .shadow(color: LumeColors.textPrimary.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}
```

#### 3. Add to JournalListView

```swift
// JournalListView.swift

List {
    // Daily prompt card (at top)
    if let prompt = viewModel.dailyPrompt {
        DailyPromptCard(prompt: prompt) {
            // Create entry from prompt
            viewModel.createEntryFromPrompt(prompt)
            showingNewEntry = true
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // Statistics card
    StatisticsCard(viewModel: viewModel)
    
    // ... rest of list
}
```

#### 4. Sentiment Analysis (Future Enhancement)

```swift
// Services/SentimentAnalysisService.swift

// Use on-device ML for privacy
import NaturalLanguage

class SentimentAnalysisService {
    func analyzeSentiment(text: String) -> Sentiment {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(
            at: text.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )
        
        guard let score = sentiment?.rawValue,
              let numericScore = Double(score) else {
            return .neutral
        }
        
        switch numericScore {
        case ..<(-0.3): return .negative
        case (-0.3)...0.3: return .neutral
        default: return .positive
        }
    }
}

enum Sentiment {
    case positive, neutral, negative
}
```

---

## Testing & Validation

### Week 1 Testing
- [ ] Mood linking works end-to-end
- [ ] Offline detection accurate
- [ ] Dashboard stats correct
- [ ] All manual tests passing

### Week 2 Testing
- [ ] Templates create correct entries
- [ ] Custom templates save/load
- [ ] Markdown renders correctly
- [ ] Prompts load from backend
- [ ] Sentiment analysis accurate (if implemented)

---

## Success Criteria

### Week 1 Complete ✅
- [ ] Mood linking fully functional
- [ ] Offline banner implemented
- [ ] Dashboard view working
- [ ] No critical bugs
- [ ] All P0/P1 issues resolved

### Week 2 Complete ✅
- [ ] Entry templates available
- [ ] Markdown support working
- [ ] AI prompts integrated
- [ ] Feature complete for v1.0
- [ ] Ready for beta testing

---

## Post-Sprint

### Immediate Next Steps
1. Beta testing with 5-10 users
2. Collect feedback on new features
3. Performance optimization
4. Accessibility audit

### Future Enhancements
- Export/sharing features
- Advanced analytics
- Collaborative journaling
- Voice-to-text entries
- Photo attachments
- End-to-end encryption

---

**Status:** 📋 Ready to Execute  
**Timeline:** 2 weeks  
**Team:** 1-2 iOS developers  
**Confidence:** High - Clear implementation path

**Let's ship this! 🚀**