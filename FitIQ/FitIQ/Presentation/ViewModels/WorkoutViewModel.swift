//
//  WorkoutViewModel.swift
//  FitIQ
//
//  Created by Marcos Barbero on 18/10/2025.
//

import Foundation
import Observation  // Essential for @Observable

enum WorkoutSource: String {
    case appLogged  // Logged via FitIQ (Editable/Deletable)
    case healthKitImport  // Imported from HealthKit (Read-Only)
}

// WorkoutLog (Mock History Data)
struct CompletedWorkout: Identifiable {
    let id = UUID()
    let date: Date
    let name: String
    let activityType: WorkoutActivityType
    let durationMinutes: Int
    let caloriesBurned: Int
    let source: WorkoutSource
    let effortRPE: Int
    let setsCompleted: Int
    let exercises: [String: String]
}

struct DailyActivityMetrics {
    // 1. Move Goal (Vitality Teal)
    let moveGoalKcal: Double = 500
    let currentMoveKcal: Double = 425

    // 2. Exercise Goal (Ascend Blue)
    let exerciseGoalMins: Double = 30
    let currentExerciseMins: Double = 45  // Over-achieved

    // 3. Stand Goal (Attention Orange)
    let standGoalHours: Double = 12  // 12 hours
    let currentStandHours: Double = 9

    // Streak data remains
    let streakDays: Int = 3
}

// WorkoutViewModel (New, assumes it's managed by AppContainer)
@Observable
final class WorkoutViewModel {
    var isLoading: Bool = false
    var isLoadingWorkouts: Bool = false
    var workoutError: String?

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - HealthKit Sync State

    var isSyncingFromHealthKit: Bool = false
    var lastSyncDate: Date?
    var syncSuccessMessage: String?

    // MARK: - Real Workout Data

    private var realWorkouts: [WorkoutEntry] = []
    private let getHistoricalWorkoutsUseCase: GetHistoricalWorkoutsUseCase?
    private let authManager: AuthManager?
    private let fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase?
    private let saveWorkoutUseCase: SaveWorkoutUseCase?

    // MARK: - Workout Template Management

    private let fetchWorkoutTemplatesUseCase: FetchWorkoutTemplatesUseCase?
    private let syncWorkoutTemplatesUseCase: SyncWorkoutTemplatesUseCase?
    private let createWorkoutTemplateUseCase: CreateWorkoutTemplateUseCase?
    private let startWorkoutSessionUseCase: StartWorkoutSessionUseCase?
    private let completeWorkoutSessionUseCase: CompleteWorkoutSessionUseCase?
    private let workoutTemplateRepository: WorkoutTemplateRepositoryProtocol?

    // NEW: Template Sharing ViewModel
    var sharingViewModel: WorkoutTemplateSharingViewModel?

    // Active workout session
    var activeSession: WorkoutSession?
    var isSyncingTemplates: Bool = false
    var lastTemplateSyncDate: Date?

    // Real workout templates from backend/local storage
    private var _realWorkoutTemplates: [WorkoutTemplate] = []

    // MARK: - Private backing store for all workout templates
    // Empty by default - real templates loaded from backend/local storage
    private var _allWorkoutTemplates: [Workout] = []

    // MARK: - CHANGE: Public computed property with new sorting logic
    // Sorts by isFeatured (highest priority), then isFavorite, then name.
    var workoutTemplates: [Workout] {
        // Convert real WorkoutTemplate entities to Workout for UI compatibility
        let realWorkouts = _realWorkoutTemplates.map { template in
            Workout(
                id: template.id,  // Use template ID for matching
                name: template.name,
                category: mapCategory(template.category),
                durationMinutes: template.estimatedDurationMinutes ?? 60,
                equipmentNeeded: false,  // Default, can be enhanced later
                isHidden: false,
                isFavorite: template.isFavorite,
                isFeatured: template.isFeatured
            )
        }

        // Use real templates (no fallback to mock data)
        let templates = realWorkouts

        return templates.sorted { w1, w2 in
            // 1. Prioritize featured workouts
            if w1.isFeatured && !w2.isFeatured { return true }
            if !w1.isFeatured && w2.isFeatured { return false }

            // 2. If featured status is the same, prioritize favorites
            if w1.isFavorite && !w2.isFavorite { return true }
            if !w1.isFavorite && w2.isFavorite { return false }

            // 3. If both featured and favorite status are the same, sort by name alphabetically
            return w1.name < w2.name
        }
    }

    // Helper to map template category to WorkoutCategory enum
    private func mapCategory(_ category: String?) -> WorkoutCategory {
        guard let category = category?.lowercased() else { return .strength }
        switch category {
        case "strength": return .strength
        case "cardio": return .cardio
        case "flexibility": return .mobility
        case "sports": return .strength
        case "hiit": return .cardio
        case "hybrid": return .strength
        default: return .strength
        }
    }

    // MARK: - Get Full Template by ID

    /// Get the full WorkoutTemplate entity by ID (for detail view)
    func getWorkoutTemplate(byID id: UUID) -> WorkoutTemplate? {
        let template = _realWorkoutTemplates.first { $0.id == id }
        if let template = template {
            print(
                "WorkoutViewModel: ✅ Found template '\(template.name)' with \(template.exercises.count) exercises"
            )
        } else {
            print("WorkoutViewModel: ⚠️ Template not found with ID: \(id)")
            print("WorkoutViewModel: Available templates: \(_realWorkoutTemplates.map { $0.id })")
        }
        return template
    }

    init(
        getHistoricalWorkoutsUseCase: GetHistoricalWorkoutsUseCase? = nil,
        authManager: AuthManager? = nil,
        fetchHealthKitWorkoutsUseCase: FetchHealthKitWorkoutsUseCase? = nil,
        saveWorkoutUseCase: SaveWorkoutUseCase? = nil,
        fetchWorkoutTemplatesUseCase: FetchWorkoutTemplatesUseCase? = nil,
        syncWorkoutTemplatesUseCase: SyncWorkoutTemplatesUseCase? = nil,
        createWorkoutTemplateUseCase: CreateWorkoutTemplateUseCase? = nil,
        startWorkoutSessionUseCase: StartWorkoutSessionUseCase? = nil,
        completeWorkoutSessionUseCase: CompleteWorkoutSessionUseCase? = nil,
        workoutTemplateRepository: WorkoutTemplateRepositoryProtocol? = nil,
        sharingViewModel: WorkoutTemplateSharingViewModel? = nil
    ) {
        self.getHistoricalWorkoutsUseCase = getHistoricalWorkoutsUseCase
        self.authManager = authManager
        self.fetchHealthKitWorkoutsUseCase = fetchHealthKitWorkoutsUseCase
        self.saveWorkoutUseCase = saveWorkoutUseCase
        self.fetchWorkoutTemplatesUseCase = fetchWorkoutTemplatesUseCase
        self.syncWorkoutTemplatesUseCase = syncWorkoutTemplatesUseCase
        self.createWorkoutTemplateUseCase = createWorkoutTemplateUseCase
        self.startWorkoutSessionUseCase = startWorkoutSessionUseCase
        self.completeWorkoutSessionUseCase = completeWorkoutSessionUseCase
        self.workoutTemplateRepository = workoutTemplateRepository
        self.sharingViewModel = sharingViewModel
    }

    var activityGoals: DailyActivityMetrics = DailyActivityMetrics()

    var ringData: [ActivityRingSnapshot] {
        [
            // Order is important for visual nesting (Move usually the largest/outer)
            ActivityRingSnapshot(
                name: "Move",
                current: activityGoals.currentMoveKcal,
                goal: activityGoals.moveGoalKcal,
                unit: "kcal",
                color: .vitalityTeal
            ),
            ActivityRingSnapshot(
                name: "Exercise",
                current: activityGoals.currentExerciseMins,
                goal: activityGoals.exerciseGoalMins,
                unit: "min",
                color: .ascendBlue
            ),
            ActivityRingSnapshot(
                name: "Stand",
                current: activityGoals.currentStandHours,
                goal: activityGoals.standGoalHours,
                unit: "hrs",
                color: .attentionOrange
            ),
        ]
    }

    // History - computed from real workout data
    var completedWorkouts: [CompletedWorkout] {
        realWorkouts.map { workout in
            CompletedWorkout(
                date: workout.startedAt,
                name: workout.title ?? workout.activityType.commonName,
                activityType: workout.activityType,
                durationMinutes: workout.durationMinutes ?? 0,
                caloriesBurned: workout.caloriesBurned ?? 0,
                source: workout.isFromHealthKit ? .healthKitImport : .appLogged,
                effortRPE: workout.intensity ?? 0,  // 0 means no rating provided
                setsCompleted: 0,  // Not tracked for HealthKit workouts
                exercises: [:]  // Not tracked for HealthKit workouts
            )
        }
    }

    var filteredCompletedWorkouts: [CompletedWorkout] {
        let calendar = Calendar.current

        // Filter workouts for the selected date only
        return completedWorkouts.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    @MainActor
    func loadTemplates() async {
        print("WorkoutViewModel: Loading workout templates...")
        // Load real templates from local storage
        await loadRealTemplates()
    }

    @MainActor
    func loadWorkouts() async {
        guard let getHistoricalWorkoutsUseCase = getHistoricalWorkoutsUseCase,
            let authManager = authManager,
            authManager.currentUserProfileID != nil
        else {
            print(
                "WorkoutViewModel: Cannot load workouts - missing dependencies or not authenticated"
            )
            return
        }

        isLoadingWorkouts = true
        workoutError = nil

        do {
            // Fetch last 30 days of workouts
            let thirtyDaysAgo =
                Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            let workouts = try await getHistoricalWorkoutsUseCase.execute(
                from: thirtyDaysAgo,
                to: Date(),
                limit: 100
            )

            realWorkouts = workouts
            print("WorkoutViewModel: ✅ Loaded \(workouts.count) workouts from local DB")
        } catch {
            workoutError = error.localizedDescription
            print("WorkoutViewModel: ❌ Failed to load workouts: \(error.localizedDescription)")
        }

        isLoadingWorkouts = false
    }

    // MARK: - HealthKit Sync

    @MainActor
    func syncFromHealthKit(dateRange: Int = 7) async {
        guard let fetchHealthKitWorkoutsUseCase = fetchHealthKitWorkoutsUseCase,
            let saveWorkoutUseCase = saveWorkoutUseCase,
            let authManager = authManager,
            authManager.currentUserProfileID != nil
        else {
            workoutError = "Cannot sync - missing dependencies or not authenticated"
            print("WorkoutViewModel: ❌ Cannot sync from HealthKit - missing dependencies")
            return
        }

        isSyncingFromHealthKit = true
        workoutError = nil
        syncSuccessMessage = nil

        do {
            print("WorkoutViewModel: 🏋️ Starting HealthKit workout sync (last \(dateRange) days)")

            let endDate = Date()
            let startDate =
                Calendar.current.date(byAdding: .day, value: -dateRange, to: endDate) ?? endDate

            // 1. Fetch workouts from HealthKit
            let healthKitWorkouts = try await fetchHealthKitWorkoutsUseCase.execute(
                from: startDate,
                to: endDate
            )

            guard !healthKitWorkouts.isEmpty else {
                syncSuccessMessage = "No workouts found in HealthKit"
                print("WorkoutViewModel: ℹ️ No workouts found in HealthKit for date range")
                isSyncingFromHealthKit = false
                return
            }

            print("WorkoutViewModel: 📋 Fetched \(healthKitWorkouts.count) workouts from HealthKit")

            // 2. Save each workout (with deduplication)
            var successCount = 0
            var duplicateCount = 0
            var errorCount = 0

            for workout in healthKitWorkouts {
                do {
                    _ = try await saveWorkoutUseCase.execute(workoutEntry: workout)
                    successCount += 1
                } catch WorkoutRepositoryError.duplicateWorkout {
                    duplicateCount += 1
                } catch {
                    errorCount += 1
                    print(
                        "WorkoutViewModel: ❌ Failed to save workout: \(error.localizedDescription)")
                }
            }

            print(
                "WorkoutViewModel: ✅ Sync complete - Saved: \(successCount), Duplicates: \(duplicateCount), Errors: \(errorCount)"
            )

            // 3. Update UI state
            lastSyncDate = Date()

            if successCount > 0 {
                syncSuccessMessage =
                    "Synced \(successCount) workout\(successCount == 1 ? "" : "s") from HealthKit"

                // 4. Reload workouts to show new data
                await loadWorkouts()
            } else if duplicateCount > 0 {
                syncSuccessMessage = "All workouts already synced"
            } else if errorCount > 0 {
                workoutError = "Failed to sync \(errorCount) workout\(errorCount == 1 ? "" : "s")"
            }

        } catch {
            workoutError = "Sync failed: \(error.localizedDescription)"
            print("WorkoutViewModel: ❌ HealthKit sync failed: \(error.localizedDescription)")
        }

        isSyncingFromHealthKit = false
    }

    @MainActor
    func syncTodaysWorkouts() async {
        await syncFromHealthKit(dateRange: 1)
    }

    @MainActor
    func syncRecentWorkouts() async {
        await syncFromHealthKit(dateRange: 7)
    }

    func deleteWorkoutTemplate(id: UUID) {
        _allWorkoutTemplates.removeAll { $0.id == id }
        print("Successfully deleted workout template with ID: \(id)")
    }

    func updateWorkoutTemplate(updatedWorkout: Workout) {
        if let index = _allWorkoutTemplates.firstIndex(where: { $0.id == updatedWorkout.id }) {
            _allWorkoutTemplates[index] = updatedWorkout
            print("Successfully updated workout template: \(updatedWorkout.name)")
        }
    }

    @MainActor
    func toggleFavorite(for workoutID: UUID) {
        // Find and update the real template
        guard let index = _realWorkoutTemplates.firstIndex(where: { $0.id == workoutID }) else {
            print("WorkoutViewModel: ⚠️ Template not found for ID: \(workoutID)")
            return
        }

        // Toggle favorite status
        var updatedTemplate = _realWorkoutTemplates[index]
        updatedTemplate.isFavorite.toggle()
        _realWorkoutTemplates[index] = updatedTemplate

        print(
            "WorkoutViewModel: ⭐ Toggled favorite for '\(updatedTemplate.name)' to \(updatedTemplate.isFavorite)"
        )

        // Persist the change
        Task {
            do {
                guard let repository = self.workoutTemplateRepository else { return }
                // Save to local storage (SwiftData via repository)
                _ = try await repository.update(template: updatedTemplate)
                print("WorkoutViewModel: ✅ Persisted favorite status")
            } catch {
                print("WorkoutViewModel: ❌ Failed to persist favorite: \(error)")
            }
        }
    }

    // MARK: - NEW: Method to toggle featured status
    @MainActor
    func toggleFeatured(for workoutID: UUID) {
        // Find and update the real template
        guard let index = _realWorkoutTemplates.firstIndex(where: { $0.id == workoutID }) else {
            print("WorkoutViewModel: ⚠️ Template not found for ID: \(workoutID)")
            return
        }

        // Toggle featured status
        var updatedTemplate = _realWorkoutTemplates[index]
        updatedTemplate.isFeatured.toggle()
        _realWorkoutTemplates[index] = updatedTemplate

        print(
            "WorkoutViewModel: 🌟 Toggled featured for '\(updatedTemplate.name)' to \(updatedTemplate.isFeatured)"
        )

        // Persist the change
        Task {
            do {
                guard let repository = self.workoutTemplateRepository else { return }
                // Save to local storage (SwiftData via repository)
                _ = try await repository.update(template: updatedTemplate)
                print("WorkoutViewModel: ✅ Persisted featured status")
            } catch {
                print("WorkoutViewModel: ❌ Failed to persist featured: \(error)")
            }
        }
    }

    // MARK: - Workout Template Sync & Management

    @MainActor
    func syncWorkoutTemplates() async {
        guard let syncWorkoutTemplatesUseCase = syncWorkoutTemplatesUseCase else {
            print("WorkoutViewModel: ❌ syncWorkoutTemplatesUseCase not available")
            return
        }

        isSyncingTemplates = true
        workoutError = nil

        do {
            print("WorkoutViewModel: 🔄 Syncing workout templates from backend...")
            let count = try await syncWorkoutTemplatesUseCase.execute()

            lastTemplateSyncDate = Date()
            print("WorkoutViewModel: ✅ Synced \(count) templates from backend")

            // Reload templates from local storage
            await loadRealTemplates()

            syncSuccessMessage = "Synced \(count) workout template\(count == 1 ? "" : "s")"
        } catch {
            workoutError = "Template sync failed: \(error.localizedDescription)"
            print("WorkoutViewModel: ❌ Template sync failed: \(error.localizedDescription)")
        }

        isSyncingTemplates = false
    }

    @MainActor
    func loadRealTemplates() async {
        guard let fetchWorkoutTemplatesUseCase = fetchWorkoutTemplatesUseCase else {
            print("WorkoutViewModel: ℹ️ fetchWorkoutTemplatesUseCase not available, using mock data")
            return
        }

        do {
            print("WorkoutViewModel: 📋 Loading workout templates from local storage...")
            _realWorkoutTemplates = try await fetchWorkoutTemplatesUseCase.execute(
                source: nil,
                category: nil,
                difficulty: nil
            )
            print("WorkoutViewModel: ✅ Loaded \(_realWorkoutTemplates.count) templates")

            // Debug: Log exercise counts for each template
            for template in _realWorkoutTemplates {
                print(
                    "  - '\(template.name)': \(template.exercises.count) exercises (exerciseCount field: \(template.exerciseCount))"
                )
            }
        } catch {
            workoutError = "Failed to load templates: \(error.localizedDescription)"
            print("WorkoutViewModel: ❌ Failed to load templates: \(error.localizedDescription)")
        }
    }

    // MARK: - Workout Session Management

    @MainActor
    func startWorkout(template: WorkoutTemplate?, customName: String? = nil) async {
        guard let startWorkoutSessionUseCase = startWorkoutSessionUseCase else {
            print("WorkoutViewModel: ❌ startWorkoutSessionUseCase not available")
            return
        }

        do {
            let activityType: WorkoutActivityType = {
                if let template = template,
                    let category = template.category
                {
                    // Map category to activity type
                    switch category.lowercased() {
                    case "strength":
                        return .strengthTraining
                    case "cardio":
                        return .running
                    case "flexibility", "mobility":
                        return .yoga
                    default:
                        return .strengthTraining
                    }
                }
                return .strengthTraining
            }()

            print("WorkoutViewModel: 🏋️ Starting workout session...")
            activeSession = try await startWorkoutSessionUseCase.execute(
                template: template,
                name: customName,
                activityType: activityType
            )
            print("WorkoutViewModel: ✅ Started session: \(activeSession?.name ?? "Unknown")")
        } catch {
            workoutError = "Failed to start workout: \(error.localizedDescription)"
            print("WorkoutViewModel: ❌ Failed to start workout: \(error.localizedDescription)")
        }
    }

    @MainActor
    func completeWorkout(intensity: Int) async {
        guard let completeWorkoutSessionUseCase = completeWorkoutSessionUseCase,
            let session = activeSession
        else {
            print(
                "WorkoutViewModel: ❌ completeWorkoutSessionUseCase or activeSession not available")
            return
        }

        isLoading = true
        workoutError = nil

        do {
            print("WorkoutViewModel: ✅ Completing workout with intensity: \(intensity)")
            _ = try await completeWorkoutSessionUseCase.execute(
                session: session,
                intensity: intensity
            )

            // Clear active session
            activeSession = nil

            // Reload workouts to show new completed workout
            await loadWorkouts()

            syncSuccessMessage = "Workout completed and saved!"
            print("WorkoutViewModel: ✅ Workout completed successfully")
        } catch {
            workoutError = "Failed to complete workout: \(error.localizedDescription)"
            print("WorkoutViewModel: ❌ Failed to complete workout: \(error.localizedDescription)")
        }

        isLoading = false
    }

    @MainActor
    func cancelWorkout() {
        activeSession = nil
        print("WorkoutViewModel: ❌ Workout session cancelled")
    }
}
