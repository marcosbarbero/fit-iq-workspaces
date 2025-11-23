import Charts  // Though not directly used in WorkoutView, it's used by DailyActivityGoalCard's MultiRingActivityGauge.
import Foundation
import SwiftUI

// MARK: - Mock Data Models (Unchanged)

struct Workout: Identifiable {
    let id: UUID
    var name: String
    var category: WorkoutCategory
    var durationMinutes: Int
    var equipmentNeeded: Bool
    var isHidden: Bool
    var isFavorite: Bool = false
    var isFeatured: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        category: WorkoutCategory,
        durationMinutes: Int,
        equipmentNeeded: Bool,
        isHidden: Bool,
        isFavorite: Bool = false,
        isFeatured: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.durationMinutes = durationMinutes
        self.equipmentNeeded = equipmentNeeded
        self.isHidden = isHidden
        self.isFavorite = isFavorite
        self.isFeatured = isFeatured
    }

    static let mockData: [Workout] = [
        Workout(
            name: "Morning Cardio Blast", category: .cardio, durationMinutes: 30,
            equipmentNeeded: false, isHidden: false, isFavorite: true, isFeatured: true),  // Example featured & favorite
        Workout(
            name: "Full Body Strength", category: .strength, durationMinutes: 60,
            equipmentNeeded: true, isHidden: false, isFavorite: true, isFeatured: true),  // Example featured & favorite
        Workout(
            name: "Yoga & Mobility Flow", category: .mobility, durationMinutes: 45,
            equipmentNeeded: false, isHidden: false, isFavorite: false, isFeatured: true),  // Example featured
        Workout(
            name: "Quick Core Destroyer", category: .strength, durationMinutes: 15,
            equipmentNeeded: false, isHidden: true, isFavorite: false, isFeatured: false),  // Hidden for filtering demo
        Workout(
            name: "Endurance Run Prep", category: .cardio, durationMinutes: 50,
            equipmentNeeded: true, isHidden: false, isFavorite: false, isFeatured: false),
        Workout(
            name: "HIIT Session", category: .cardio, durationMinutes: 40, equipmentNeeded: false,
            isHidden: false, isFavorite: false, isFeatured: false),
        Workout(
            name: "Powerlifting Prep", category: .strength, durationMinutes: 75,
            equipmentNeeded: true, isHidden: false, isFavorite: false, isFeatured: false),
        Workout(
            name: "Pilates Flow", category: .mobility, durationMinutes: 50, equipmentNeeded: false,
            isHidden: false, isFavorite: false, isFeatured: false),
    ]
}

enum WorkoutCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"
    case mobility = "Mobility"

    var id: String { self.rawValue }

    var iconName: String {
        switch self {
        case .all: return "line.horizontal.3.decrease.circle.fill"
        case .strength: return "figure.strengthtraining.functional"
        case .cardio: return "figure.run"
        case .mobility: return "figure.yoga"
        }
    }
}

// MARK: - Main View

struct WorkoutView: View {
    @EnvironmentObject var deps: AppDependencies
    @State private var viewModel: WorkoutViewModel

    init() {
        // Initialize with empty viewModel - will be updated in onAppear with deps
        _viewModel = State(initialValue: WorkoutViewModel())
    }

    @State private var selectedFilter: WorkoutCategory = .all
    @State private var searchText: String = ""

    // State for full-screen workout start
    @State private var runningWorkout: Workout? = nil
    @State private var showingWorkoutSession = false

    @State private var showingFilterSheet: Bool = false
    @State private var showingManageWorkoutsSheet: Bool = false  // Entry point for workout creation/management

    @State private var selectedCompletedWorkout: CompletedWorkout? = nil

    @State private var datePickerID = UUID()  // For forcing DatePicker dismissal in toolbar

    // MARK: - Refactored filteredWorkouts for compiler performance
    var filteredWorkouts: [Workout] {
        var results: [Workout] = []
        for workout in viewModel.workoutTemplates {
            if workout.isHidden { continue }

            let categoryMatches = selectedFilter == .all || workout.category == selectedFilter
            let textMatches =
                searchText.isEmpty || workout.name.localizedCaseInsensitiveContains(searchText)

            if categoryMatches && textMatches {
                results.append(workout)
            }
        }
        return results
    }

    // MARK: - FIX: Simplified and stabilized previewWorkouts sorting logic
    var previewWorkouts: [Workout] {
        var currentWorkouts = filteredWorkouts

        currentWorkouts.sort { w1, w2 in
            // Primary sort: Featured workouts come first
            if w1.isFeatured && !w2.isFeatured { return true }
            if !w1.isFeatured && w2.isFeatured { return false }

            // Secondary sort: Favorited workouts come next (among equally featured/unfeatured)
            if w1.isFavorite && !w2.isFavorite { return true }
            if !w1.isFavorite && w2.isFavorite { return false }

            // Tertiary sort: Alphabetical by name for stable ordering
            return w1.name < w2.name
        }

        // Take the top 3 after stable sorting
        return Array(currentWorkouts.prefix(3))
    }

    private let primaryColor = Color.vitalityTeal  // Consistency with workout theme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: 1. Action Cards (Manage Workouts)
                    WorkoutActionCards(
                        showingManageWorkoutsSheet: $showingManageWorkoutsSheet,
                        color: primaryColor
                    )
                    .padding(.horizontal)
                    .disabled(
                        showingManageWorkoutsSheet || showingFilterSheet || runningWorkout != nil
                            || selectedCompletedWorkout != nil)

                    Divider().padding(.horizontal)

                    // MARK: 2. Daily Activity Goals
                    DailyActivityGoalCard(viewModel: viewModel)
                        .padding(.horizontal)

                    Divider().padding(.horizontal)

                    // MARK: 3. Routines & Templates (Extracted to WorkoutRoutinesSection)
                    WorkoutRoutinesSection(
                        viewModel: viewModel,
                        filteredWorkouts: filteredWorkouts,
                        previewWorkouts: previewWorkouts,
                        searchText: searchText,
                        selectedFilter: selectedFilter,
                        primaryColor: primaryColor,
                        showingManageWorkoutsSheet: $showingManageWorkoutsSheet,
                        runningWorkout: $runningWorkout,
                        selectedCompletedWorkout: $selectedCompletedWorkout
                    )

                    // MARK: 4. Completed Workout Sessions (Extracted to CompletedSessionsSection)
                    CompletedSessionsSection(
                        viewModel: viewModel,
                        selectedCompletedWorkout: $selectedCompletedWorkout,
                        primaryColor: primaryColor
                    )

                    Spacer()
                }
                .padding(.bottom, 100)  // Space for FAB
                .padding(.top, 10)
            }
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DatePicker(
                        "Filter Date", selection: $viewModel.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .id(datePickerID)
                    .onChange(of: viewModel.selectedDate) {
                        Task {
                            try? await Task.sleep(for: .milliseconds(50))
                            datePickerID = UUID()
                        }
                    }
                }
                // Removed reload button from toolbar - moved to ManageWorkouts and empty state
            }
            .onAppear {
                // Initialize viewModel with dependencies from AppDependencies
                viewModel = WorkoutViewModel(
                    getHistoricalWorkoutsUseCase: deps.getHistoricalWorkoutsUseCase,
                    authManager: deps.authManager,
                    fetchHealthKitWorkoutsUseCase: deps.fetchHealthKitWorkoutsUseCase,
                    saveWorkoutUseCase: deps.saveWorkoutUseCase,
                    fetchWorkoutTemplatesUseCase: deps.fetchWorkoutTemplatesUseCase,
                    syncWorkoutTemplatesUseCase: deps.syncWorkoutTemplatesUseCase,
                    createWorkoutTemplateUseCase: deps.createWorkoutTemplateUseCase,
                    startWorkoutSessionUseCase: deps.startWorkoutSessionUseCase,
                    completeWorkoutSessionUseCase: deps.completeWorkoutSessionUseCase,
                    workoutTemplateRepository: deps.workoutTemplateRepository
                )

                Task {
                    // Load real templates from local storage
                    await viewModel.loadRealTemplates()
                    // Also load completed workouts
                    await viewModel.loadWorkouts()
                }

                print(
                    "WorkoutView appeared. Initial states: manage=\(self.showingManageWorkoutsSheet), filter=\(self.showingFilterSheet), running=\(self.runningWorkout != nil), completed=\(self.selectedCompletedWorkout != nil)"
                )
            }
            .onChange(of: showingManageWorkoutsSheet) { oldValue, newValue in
                print(
                    "WorkoutView: showingManageWorkoutsSheet changed from \(oldValue) to \(newValue)"
                )
            }
            .onChange(of: viewModel.selectedDate) {
                // The `filteredCompletedWorkouts` computed property automatically updates.
            }

            ActionFAB(
                action: { self.showingFilterSheet = true }, color: primaryColor,
                systemImageName: "magnifyingglass"
            )
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        // Sheets
        .fullScreenCover(item: $runningWorkout) { item in
            WorkoutRunningView(workout: item)
        }
        .sheet(isPresented: $showingFilterSheet) {
            WorkoutCategoryFilterSheet(
                searchText: $searchText,
                selectedFilter: $selectedFilter
            )
        }
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(viewModel: viewModel)
        }
        .refreshable {
            // Pull-to-refresh: sync templates and workouts
            await viewModel.syncWorkoutTemplates()
            await viewModel.syncRecentWorkouts()
        }
        .sheet(item: $selectedCompletedWorkout) { workout in
            CompletedWorkoutDetailView(log: workout)
        }
        .sheet(
            isPresented: $showingManageWorkoutsSheet,
            onDismiss: {
                print("--- WorkoutView: ManageWorkoutsView dismissed (onDismiss callback) ---")
                self.showingManageWorkoutsSheet = false
                Task { await viewModel.loadTemplates() }
            }
        ) {
            if showingManageWorkoutsSheet {
                ManageWorkoutsView(
                    viewModel: viewModel,
                    onStartWorkout: { workout in
                        print("WorkoutView: ManageWorkoutsView requesting workout start.")
                        self.runningWorkout = workout
                        self.showingManageWorkoutsSheet = false
                    }
                )
                .onAppear {
                    print("--- WorkoutView: ManageWorkoutsView content appeared ---")
                }
                .onDisappear {
                    print("--- WorkoutView: ManageWorkoutsView content disappeared ---")
                }
            }
        }
    }
}

// Workout Action Cards View (contains "Manage Workouts")
struct WorkoutActionCards: View {
    @Binding var showingManageWorkoutsSheet: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 15) {
            Button(action: {
                DispatchQueue.main.async {
                    print("ActionCard: 'Manage Workouts' button tapped.")
                    print(
                        "Pre-tap state: showingManageWorkoutsSheet = \(self.showingManageWorkoutsSheet)"
                    )
                    self.showingManageWorkoutsSheet = true
                    print(
                        "Post-tap state: showingManageWorkoutsSheet = \(self.showingManageWorkoutsSheet)"
                    )
                }
            }) {
                ActionCardContent(
                    title: "Manage Workouts", icon: "square.stack.3d.up.fill", color: color
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - NEW: Extracted Sub-Views for WorkoutView

struct WorkoutRoutinesSection: View {
    @Bindable var viewModel: WorkoutViewModel
    let filteredWorkouts: [Workout]
    let previewWorkouts: [Workout]
    let searchText: String
    let selectedFilter: WorkoutCategory
    let primaryColor: Color

    @Binding var showingManageWorkoutsSheet: Bool
    @Binding var runningWorkout: Workout?
    @Binding var selectedCompletedWorkout: CompletedWorkout?

    // Updated height for taller rows
    private let workoutRowHeight: CGFloat = 100

    // Edit mode for reordering
    @State private var isEditMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Title row with "See All" and "Reorder" buttons
            HStack(alignment: .center) {
                Text("Workout Routines")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                // Reorder button (only shown when there are pinned workouts)
                if !previewWorkouts.isEmpty {
                    Button {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(
                                systemName: isEditMode
                                    ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle"
                            )
                            .font(.caption)
                            Text(isEditMode ? "Done" : "Reorder")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isEditMode ? .growthGreen : primaryColor)
                    }
                }

                // "See All" button next to title (smaller, only shown when there are workouts)
                if !filteredWorkouts.isEmpty {
                    Button {
                        showingManageWorkoutsSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(primaryColor)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 5)

            // Show empty state by default (no pinned workouts initially)
            if previewWorkouts.isEmpty {
                // Empty state with action buttons
                VStack(spacing: 16) {
                    ContentUnavailableView {
                        Label("No Pinned Routines", systemImage: "pin.slash")
                    } description: {
                        Text("Pin your favorite workout templates to quickly access them here.")
                    }
                    .frame(minHeight: 120)

                    HStack(spacing: 12) {
                        Button {
                            showingManageWorkoutsSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.subheadline)
                                Text("Browse Routines")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await viewModel.syncWorkoutTemplates()
                            }
                        } label: {
                            HStack {
                                if viewModel.isSyncingTemplates {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.subheadline)
                                    Text("Sync")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(primaryColor)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSyncingTemplates)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, 20)
            } else {
                // Show pinned workouts with reorder capability
                List {
                    ForEach(previewWorkouts) { workout in
                        WorkoutRow(
                            workout: workout,
                            viewModel: viewModel,
                            onStart: {
                                runningWorkout = workout
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
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }
                    .onMove { indices, newOffset in
                        // Reorder functionality (note: this modifies the view model's internal array)
                        // In production, you'd want to persist the order
                        print("Reordering workouts from \(indices) to \(newOffset)")
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(previewWorkouts.count) * workoutRowHeight)
                .scrollDisabled(true)
                .environment(\.editMode, isEditMode ? .constant(.active) : .constant(.inactive))
            }
        }
    }
}

struct CompletedSessionsSection: View {
    @Bindable var viewModel: WorkoutViewModel
    @Binding var selectedCompletedWorkout: CompletedWorkout?
    let primaryColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Completed Sessions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                // Sync button
                Button {
                    Task {
                        await viewModel.syncRecentWorkouts()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isSyncingFromHealthKit {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                        Text("Sync")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(primaryColor)
                }
                .disabled(viewModel.isSyncingFromHealthKit)
            }
            .padding(.horizontal, 20)
            .padding(.top, 5)

            // Success message
            if let successMessage = viewModel.syncSuccessMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
            }

            // Error message
            if let errorMessage = viewModel.workoutError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }

            if viewModel.filteredCompletedWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts Logged",
                    systemImage: "figure.walk",
                    description: Text(
                        viewModel.isSyncingFromHealthKit
                            ? "Syncing from HealthKit..."
                            : "Start a workout or tap Sync to load from HealthKit")
                )
                .frame(minHeight: 150)
                .padding(.horizontal, 20)
            } else {
                ForEach(viewModel.filteredCompletedWorkouts) { log in
                    Button {
                        selectedCompletedWorkout = log
                    } label: {
                        CompletedWorkoutRow(log: log)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
