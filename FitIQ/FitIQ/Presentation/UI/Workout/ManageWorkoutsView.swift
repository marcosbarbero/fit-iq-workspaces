import SwiftUI

// MARK: - NEW FILE: ManageWorkoutsView.swift

struct ManageWorkoutsView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: WorkoutViewModel

    let onStartWorkout: (Workout) -> Void

    @State private var showingAddRoutineSheetInternal: Bool = false

    // Filtering state
    @State private var searchText: String = ""
    @State private var selectedDifficulty: String? = nil
    @State private var showingFilters: Bool = false

    // Computed filtered workouts
    private var filteredWorkouts: [Workout] {
        var results = viewModel.workoutTemplates

        // Search filter
        if !searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Difficulty filter (client-side on already-fetched templates)
        if let difficulty = selectedDifficulty {
            results = results.filter { workout in
                // Get the full template to check difficulty
                guard let template = viewModel.getWorkoutTemplate(byID: workout.id) else {
                    return false
                }
                return template.difficultyLevel?.rawValue.lowercased() == difficulty.lowercased()
            }
        }

        return results
    }

    private var hasActiveFilters: Bool {
        selectedDifficulty != nil || !searchText.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search workouts...", text: $searchText)
                            .autocorrectionDisabled(true)
                    }
                    .padding(12)
                    .background(Color(.systemFill))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Filter chips
                    if hasActiveFilters {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                if let difficulty = selectedDifficulty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.caption2)
                                        Text(difficulty.capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.vitalityTeal)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                }

                                Button {
                                    selectedDifficulty = nil
                                    searchText = ""
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Clear All")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemRed))
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }

                    // Workout list
                    if filteredWorkouts.isEmpty {
                        ContentUnavailableView {
                            Label("No Routines Found", systemImage: "magnifyingglass")
                        } description: {
                            VStack(spacing: 10) {
                                if hasActiveFilters {
                                    Text("Try adjusting your filters or search term.")
                                } else {
                                    Text(
                                        "Tap the '+' button to create your first workout routine or sync from the backend."
                                    )
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        List {
                            ForEach(filteredWorkouts) { workout in
                                WorkoutRow(
                                    workout: workout,
                                    viewModel: viewModel,
                                    onStart: {
                                        print(
                                            "ManageWorkoutsView: Starting workout '\(workout.name)'."
                                        )
                                        onStartWorkout(workout)
                                        dismiss()
                                    },
                                    onDelete: { workoutID in
                                        viewModel.deleteWorkoutTemplate(id: workoutID)
                                    },
                                    onToggleFavorite: { workoutID in
                                        viewModel.toggleFavorite(for: workoutID)
                                    },
                                    onToggleFeatured: { workoutID in
                                        viewModel.toggleFeatured(for: workoutID)
                                    }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(
                                    EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
                .navigationTitle("Manage Routines")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingFilters = true
                            } label: {
                                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                            }

                            Divider()

                            Button {
                                Task {
                                    await viewModel.syncWorkoutTemplates()
                                }
                            } label: {
                                Label("Sync Templates", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(viewModel.isSyncingTemplates)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.vitalityTeal)
                        }
                    }
                }
                .onAppear {
                    print("--- ManageWorkoutsView appeared ---")
                }
                .onDisappear {
                    print("--- ManageWorkoutsView content disappeared ---")
                }

                ActionFAB(
                    action: {
                        self.showingAddRoutineSheetInternal = true
                    }, color: .vitalityTeal, systemImageName: "plus.circle.fill"
                )
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheet(selectedDifficulty: $selectedDifficulty)
        }
        .sheet(
            isPresented: $showingAddRoutineSheetInternal,
            onDismiss: {
                Task { await viewModel.loadTemplates() }
            }
        ) {
            AddWorkoutView(
                viewModel: AddWorkoutViewModel(),
                onSave: {
                    Task {
                        await viewModel.loadTemplates()
                        self.showingAddRoutineSheetInternal = false
                    }
                }
            )
        }

    }
}

// Filter sheet
struct FilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDifficulty: String?

    private let difficulties = ["beginner", "intermediate", "advanced", "expert"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(difficulties, id: \.self) { difficulty in
                        Button {
                            selectedDifficulty = difficulty
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.vitalityTeal)
                                Text(difficulty.capitalized)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedDifficulty == difficulty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.vitalityTeal)
                                }
                            }
                        }
                    }

                    if selectedDifficulty != nil {
                        Button {
                            selectedDifficulty = nil
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("Clear Filter")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("Difficulty Level")
                } footer: {
                    Text("Filter templates by difficulty level. More filters coming soon.")
                        .font(.caption)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
