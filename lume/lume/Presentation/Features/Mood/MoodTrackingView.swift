//
//  MoodTrackingView.swift
//  lume
//
//  Created by AI Assistant on 2024-12-16.
//

import SwiftUI

/// Main mood tracking view - displays mood history and allows logging new moods
struct MoodTrackingView: View {
    @Bindable var viewModel: MoodViewModel
    @State private var showingMoodEntry = false
    @State private var shouldReloadHistory = false

    @State private var showingDatePicker = false
    @State private var expandedCardId: UUID?
    @State private var editingEntry: MoodEntry?

    var body: some View {
        ZStack {
            LumeColors.appBackground
                .ignoresSafeArea()

            // Sync message banner
            if let syncMessage = viewModel.syncMessage {
                VStack {
                    Text(syncMessage)
                        .font(LumeTypography.bodySmall)
                        .foregroundColor(LumeColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LumeColors.surface)
                                .shadow(
                                    color: LumeColors.textPrimary.opacity(0.1),
                                    radius: 8,
                                    x: 0,
                                    y: 2
                                )
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.syncMessage)
                .zIndex(1)
            }

            if viewModel.moodHistory.isEmpty && !viewModel.isLoading {
                ScrollView {
                    EmptyMoodState(onLogMood: {
                        showingMoodEntry = true
                    })
                }
                .refreshable {
                    await viewModel.syncWithBackend()
                }
            } else {
                List {
                    ForEach(viewModel.moodHistory) { entry in
                        MoodHistoryCard(
                            entry: entry,
                            isExpanded: expandedCardId == entry.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedCardId = expandedCardId == entry.id ? nil : entry.id
                                }
                            },
                            onEdit: {
                                editingEntry = entry
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteMood(entry.id)
                                }
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteMood(entry.id)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            if let mood = entry.primaryMoodLabel {
                                Button {
                                    editingEntry = entry
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(Color(hex: mood.color))
                            }
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
                    await viewModel.syncWithBackend()
                }
            }

            // Floating Action Button (only show when history exists)
            if !viewModel.moodHistory.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingMoodEntry = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            .foregroundColor(LumeColors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                Circle()
                                    .fill(LumeColors.accentPrimary)
                            )
                            .shadow(
                                color: LumeColors.textPrimary.opacity(0.15),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("Mood")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
            }
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
                                color: LumeColors.textPrimary.opacity(0.05), radius: 8, x: 0, y: 2)
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
                            .background(LumeColors.accentPrimary)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(LumeColors.appBackground)
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingDatePicker = false
                        } label: {
                            Text("Done")
                                .foregroundColor(LumeColors.textPrimary)
                        }
                    }
                }
            }
        }

        .sheet(isPresented: $showingMoodEntry) {
            NavigationStack {
                LinearMoodSelectorView(
                    viewModel: viewModel,
                    onMoodSaved: {
                        showingMoodEntry = false
                        shouldReloadHistory = true
                    }
                )
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                LinearMoodSelectorView(
                    viewModel: viewModel,
                    onMoodSaved: {
                        editingEntry = nil
                        shouldReloadHistory = true
                    },
                    existingEntry: entry
                )
            }
        }
        .task {
            await viewModel.loadMoodsForSelectedDate()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await viewModel.loadMoodsForSelectedDate()
            }
        }
        .onChange(of: shouldReloadHistory) { _, newValue in
            if newValue {
                Task {
                    await viewModel.loadMoodsForSelectedDate()
                    shouldReloadHistory = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MoodTrackingView(
            viewModel: MoodViewModel(
                moodRepository: MockMoodRepository(),
                authRepository: MockAuthRepository(),
                syncMoodEntriesUseCase: MockSyncMoodEntriesUseCase()
            )
        )
    }
}
