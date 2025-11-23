//
//  JournalListView.swift
//  lume
//
//  Created by Marcos Barbero on 15/01/2025.
//

import SwiftUI

/// Main journal list view with search, filters, and entry management
struct JournalListView: View {
    @ObservedObject var viewModel: JournalViewModel
    @AppStorage("hasSeenSyncExplanation") private var hasSeenSyncExplanation = false

    @State private var showingNewEntry = false
    @State private var showingSearch = false
    @State private var showingFilters = false
    @State private var showingDatePicker = false
    @State private var selectedEntry: JournalEntry?
    @State private var editingEntry: JournalEntry?
    @State private var showingSyncExplanation = false
    @State private var showSyncedConfirmation = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LumeColors.appBackground
                .ignoresSafeArea()

            // Sync Status Banner
            if viewModel.isOffline || viewModel.statistics.pendingSyncCount > 0 || showSyncedConfirmation {
                VStack {
                    HStack(spacing: 8) {
                        // Icon based on state
                        if viewModel.isOffline {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 14))
                                .foregroundColor(LumeColors.textPrimary)
                        } else if viewModel.statistics.pendingSyncCount > 0 {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#2196F3"))
                        } else if showSyncedConfirmation {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#4CAF50"))
                        }

                        Text(syncStatusText)
                            .font(LumeTypography.bodySmall)
                            .foregroundColor(LumeColors.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LumeColors.surface.opacity(0.95))
                            .shadow(
                                color: LumeColors.textPrimary.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)
                .animation(.easeInOut(duration: 0.3), value: viewModel.statistics.pendingSyncCount)
                .animation(.easeInOut(duration: 0.3), value: showSyncedConfirmation)
                .zIndex(1)
            }

            // Entry list or empty state
            if viewModel.entries.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.isLoading {
                            LoadingView()
                        } else if viewModel.hasActiveFilters || !viewModel.searchQuery.isEmpty {
                            NoResultsView(
                                searchQuery: viewModel.searchQuery,
                                onClear: {
                                    viewModel.clearFilters()
                                }
                            )
                        } else {
                            EmptyJournalState(
                                onCreateEntry: {
                                    showingNewEntry = true
                                }
                            )
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadEntries()
                }
            } else {
                List {
                    // Statistics card
                    StatisticsCard(viewModel: viewModel)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))

                    // Active filters indicator
                    if viewModel.hasActiveFilters {
                        ActiveFiltersView(viewModel: viewModel)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                    }

                    // Entry list
                    ForEach(viewModel.entries) { entry in
                        JournalEntryCard(
                            entry: entry,
                            onTap: {
                                selectedEntry = entry
                            },
                            onEdit: {
                                editingEntry = entry
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteEntry(entry)
                                }
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteEntry(entry)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingEntry = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color(hex: entry.entryType.colorHex))
                        }
                    }

                    // Spacer to prevent FAB from overlapping last entry
                    Color.clear
                        .frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .refreshable {
                    await viewModel.loadEntries()
                }
            }

            // Floating Action Button
            if !viewModel.entries.isEmpty || viewModel.hasActiveFilters {
                FloatingActionButton(
                    icon: "plus",
                    action: {
                        showingNewEntry = true
                    }
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Date picker button
                    Button {
                        showingDatePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .foregroundColor(LumeColors.textPrimary)
                            Text(viewModel.selectedDate, style: .date)
                                .font(LumeTypography.caption)
                                .foregroundColor(LumeColors.textSecondary)
                        }
                    }

                    // Search button
                    Button {
                        showingSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(LumeColors.textPrimary)
                    }

                    // Filter button
                    Button {
                        showingFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(LumeColors.textPrimary)

                            if viewModel.hasActiveFilters {
                                Circle()
                                    .fill(Color(hex: "#F2C9A7"))
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NavigationStack {
                JournalEntryView(
                    viewModel: viewModel,
                    existingEntry: nil
                )
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                JournalEntryView(
                    viewModel: viewModel,
                    existingEntry: entry
                )
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                JournalEntryDetailView(
                    entry: entry,
                    onEdit: {
                        selectedEntry = nil
                        editingEntry = entry
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteEntry(entry)
                            selectedEntry = nil
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingFilters) {
            FilterView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.light)
                    .tint(Color(hex: "#F2C9A7"))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LumeColors.surface)
                            .shadow(
                                color: LumeColors.textPrimary.opacity(0.05),
                                radius: 8,
                                x: 0,
                                y: 2
                            )
                    )
                    .padding(.horizontal, 20)

                    Spacer()

                    // Today button
                    Button {
                        viewModel.selectedDate = Date()
                        showingDatePicker = false
                    } label: {
                        Text("Today")
                            .font(LumeTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(LumeColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#F2C9A7"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .background(LumeColors.appBackground.ignoresSafeArea())
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showingDatePicker = false
                        }
                        .foregroundColor(LumeColors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSyncExplanation) {
            SyncExplanationSheet()
        }
        .task {
            await viewModel.loadEntries()

            // Show sync explanation on first entry creation
            if !hasSeenSyncExplanation && !viewModel.entries.isEmpty {
                // Wait a bit for the entry to appear
                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
                if viewModel.statistics.pendingSyncCount > 0 {
                    showingSyncExplanation = true
                    hasSeenSyncExplanation = true
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onChange(of: viewModel.statistics.pendingSyncCount) { oldValue, newValue in
            // Show synced confirmation when pending count goes to zero
            if oldValue > 0 && newValue == 0 && !viewModel.isOffline {
                showSyncedConfirmation = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    showSyncedConfirmation = false
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var syncStatusText: String {
        if showSyncedConfirmation {
            return "All changes synced ✓"
        } else {
            return viewModel.syncStatusMessage
        }
    }
}

// MARK: - Statistics Card

struct StatisticsCard: View {
    @ObservedObject var viewModel: JournalViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Journal")
                .font(LumeTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(LumeColors.textPrimary)

            HStack(spacing: 20) {
                StatItem(
                    icon: "doc.text",
                    value: "\(viewModel.statistics.totalEntries)",
                    label: "Entries"
                )

                StatItem(
                    icon: "calendar",
                    value: "\(viewModel.statistics.currentStreak)",
                    label: "Day Streak"
                )

                StatItem(
                    icon: "text.word.spacing",
                    value: formatWordCount(viewModel.statistics.totalWords),
                    label: "Words"
                )
            }
        }
        .padding(16)
        .background(LumeColors.surface)
        .cornerRadius(16)
        .shadow(color: LumeColors.textPrimary.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func formatWordCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(LumeColors.textSecondary)

                Text(value)
                    .font(LumeTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(LumeColors.textPrimary)
            }

            Text(label)
                .font(LumeTypography.caption)
                .foregroundColor(LumeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Filters View

struct ActiveFiltersView: View {
    @ObservedObject var viewModel: JournalViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Filters")
                    .font(LumeTypography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(LumeColors.textSecondary)

                Spacer()

                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("Clear All")
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(Color(hex: "#F2C9A7"))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let type = viewModel.filterType {
                        FilterChip(
                            label: type.displayName,
                            icon: type.icon,
                            onRemove: {
                                viewModel.filterType = nil
                            }
                        )
                    }

                    if let tag = viewModel.filterTag {
                        FilterChip(
                            label: "#\(tag)",
                            icon: "tag",
                            onRemove: {
                                viewModel.filterTag = nil
                            }
                        )
                    }

                    if viewModel.filterFavoritesOnly {
                        FilterChip(
                            label: "Favorites",
                            icon: "star.fill",
                            onRemove: {
                                viewModel.filterFavoritesOnly = false
                            }
                        )
                    }

                    if viewModel.filterLinkedToMood {
                        FilterChip(
                            label: "Linked to Mood",
                            icon: "link",
                            onRemove: {
                                viewModel.filterLinkedToMood = false
                            }
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(LumeColors.surface.opacity(0.5))
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))

            Text(label)
                .font(LumeTypography.bodySmall)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
            }
        }
        .foregroundColor(LumeColors.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LumeColors.surface)
        .cornerRadius(16)
    }
}

// MARK: - Empty States

struct EmptyJournalState: View {
    let onCreateEntry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(LumeColors.accentSecondary.opacity(0.6))

            VStack(spacing: 12) {
                Text("Start Your Journal")
                    .font(LumeTypography.titleLarge)
                    .foregroundColor(LumeColors.textPrimary)

                Text("Capture your thoughts, reflections,\nand gratitude in a safe space")
                    .font(LumeTypography.body)
                    .foregroundColor(LumeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: onCreateEntry) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))

                    Text("Write Your First Entry")
                        .font(LumeTypography.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(LumeColors.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(hex: "#F2C9A7"))
                .cornerRadius(24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

struct NoResultsView: View {
    let searchQuery: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(LumeColors.textSecondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Entries Found")
                    .font(LumeTypography.titleMedium)
                    .foregroundColor(LumeColors.textPrimary)

                if !searchQuery.isEmpty {
                    Text("No results for \"\(searchQuery)\"")
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                } else {
                    Text("Try adjusting your filters")
                        .font(LumeTypography.body)
                        .foregroundColor(LumeColors.textSecondary)
                }
            }

            Button(action: onClear) {
                Text("Clear Filters")
                    .font(LumeTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "#F2C9A7"))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(LumeColors.accentPrimary)

            Text("Loading entries...")
                .font(LumeTypography.bodySmall)
                .foregroundColor(LumeColors.textSecondary)
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(LumeColors.textPrimary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color(hex: "#F2C9A7"))
                        .shadow(color: LumeColors.textPrimary.opacity(0.15), radius: 12, x: 0, y: 4)
                )
        }
        .buttonStyle(FABButtonStyle())
    }
}

struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("With Entries") {
    let viewModel = JournalViewModel(
        journalRepository: MockJournalRepository(),
        moodRepository: MockMoodRepository()
    )

    NavigationStack {
        JournalListView(viewModel: viewModel)
    }
}

#Preview("Empty State") {
    let viewModel = JournalViewModel(
        journalRepository: MockJournalRepository(),
        moodRepository: MockMoodRepository()
    )

    NavigationStack {
        JournalListView(viewModel: viewModel)
    }
}

#Preview("With Filters") {
    let viewModel: JournalViewModel = {
        let vm = JournalViewModel(
            journalRepository: MockJournalRepository(),
            moodRepository: MockMoodRepository()
        )
        vm.filterFavoritesOnly = true
        vm.filterType = .gratitude
        return vm
    }()

    return NavigationStack {
        JournalListView(viewModel: viewModel)
    }
}
