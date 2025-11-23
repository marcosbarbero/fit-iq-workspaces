//
//  NutritionViewModel.swift
//  FitIQ
//
//  Updated: 2025-01-27
//  Integrated with real meal logging use cases
//

import Foundation
import Observation
import SwiftUI

// MARK: - UI Model (Adapter from Domain Model)

/// UI-friendly representation of MealLog for display
struct DailyMealLog: Identifiable {
    let id: UUID
    let description: String  // Natural language description of the meal (raw input)
    let time: Date
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let sugar: Int
    let fiber: Int
    let saturatedFat: Int
    let sodiumMg: Int
    let ironMg: Double
    let vitaminCmg: Int

    // Status information from domain model
    let status: MealLogStatus
    let syncStatus: SyncStatus
    let backendID: String?
    let rawInput: String
    let mealType: MealType  // Add meal type from domain

    // Parsed food items from the meal
    let items: [MealLogItem]

    var fullNutrientList: [(name: String, amount: String, color: Color)] {
        [
            ("Calories", "\(calories) kcal", .ascendBlue),
            ("Protein", "\(protein)g", .sustenanceYellow),
            ("Carbs", "\(carbs)g", .vitalityTeal),
            ("Fat", "\(fat)g", .serenityLavender),
            ("Fiber", "\(fiber)g", .growthGreen),
            ("Sugar", "\(sugar)g", .attentionOrange),
            ("Sat. Fat", "\(saturatedFat)g", .warningRed),
            ("Sodium", "\(sodiumMg)mg", .secondary),
            ("Iron", "\(String(format: "%.1f", ironMg))mg", .secondary),
            ("Vitamin C", "\(vitaminCmg)mg", .secondary),
        ]
    }

    // MARK: - UI Helper Properties

    /// Returns true if the meal is still being processed
    var isProcessing: Bool {
        status == .pending || status == .processing
    }

    /// Returns true if the meal analysis is complete
    var isCompleted: Bool {
        status == .completed
    }

    /// Returns true if the meal analysis failed
    var isFailed: Bool {
        status == .failed
    }

    /// Returns true if the meal is synced to backend
    var isSynced: Bool {
        syncStatus == .synced
    }

    /// Returns user-friendly status text for display
    var statusText: String {
        switch status {
        case .pending:
            return "Analyzing..."
        case .processing:
            return "Processing..."
        case .completed:
            return "Complete"
        case .failed:
            return "Failed"
        }
    }

    /// Returns status icon for display
    var statusIcon: String {
        switch status {
        case .pending, .processing:
            return "hourglass"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Returns status color for display
    var statusColor: Color {
        switch status {
        case .pending, .processing:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    /// Returns sync status icon
    var syncStatusIcon: String {
        switch syncStatus {
        case .pending:
            return "arrow.clockwise"
        case .synced:
            return "checkmark.icloud"
        case .failed:
            return "exclamationmark.icloud"
        case .syncing:
            return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        }
    }

    /// Maps from domain MealLog to UI DailyMealLog
    static func from(mealLog: MealLog) -> DailyMealLog {
        // TODO: When backend provides micronutrient data in MealLogItem,
        // calculate these values from mealLog.items
        // For now, using placeholder values for micronutrients not yet provided
        let saturatedFat = 0
        let sodiumMg = 0
        let ironMg = 0.0
        let vitaminCmg = 0

        return DailyMealLog(
            id: mealLog.id,
            description: mealLog.rawInput,  // Natural language description
            time: mealLog.loggedAt,
            calories: mealLog.totalCalories ?? 0,
            protein: Int(mealLog.totalProteinG ?? 0),
            carbs: Int(mealLog.totalCarbsG ?? 0),
            fat: Int(mealLog.totalFatG ?? 0),
            sugar: Int(mealLog.totalSugarG ?? 0),
            fiber: Int(mealLog.totalFiberG ?? 0),
            saturatedFat: saturatedFat,
            sodiumMg: sodiumMg,
            ironMg: ironMg,
            vitaminCmg: vitaminCmg,
            status: mealLog.status,
            syncStatus: mealLog.syncStatus,
            backendID: mealLog.backendID,
            rawInput: mealLog.rawInput,
            mealType: mealLog.mealType,  // Map meal type from domain
            items: mealLog.items  // Include parsed food items
        )
    }
}

// MARK: - ViewModel

@Observable
final class NutritionViewModel {

    // MARK: - State
    var selectedDate: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?

    var dailySummary: (kcal: Int, protein: Int, carbs: Int, fat: Int) = (0, 0, 0, 0)
    var meals: [DailyMealLog] = []

    // WebSocket connection state
    var isWebSocketConnected: Bool = false
    var isWebSocketConnecting: Bool = false

    var dailyTargets: (kcal: Int, protein: Int, carbs: Int, fat: Int) = (2500, 150, 250, 60)
    var netGoal: Int = 0  // Represents the desired calorie deficit or surplus

    // MARK: - Dependencies
    private let saveMealLogUseCase: SaveMealLogUseCase
    private let getMealLogsUseCase: GetMealLogsUseCase
    private let updateMealLogStatusUseCase: UpdateMealLogStatusUseCase
    private let syncPendingMealLogsUseCase: SyncPendingMealLogsUseCase
    private let deleteMealLogUseCase: DeleteMealLogUseCase
    private let webSocketService: MealLogWebSocketService
    private let authManager: AuthManager
    private let outboxProcessor: OutboxProcessorService
    private let saveWaterProgressUseCase: SaveWaterProgressUseCase
    private let nutritionSummaryViewModel: NutritionSummaryViewModel

    // MARK: - Polling State (Fallback when WebSocket unavailable)
    private var pollingTask: Task<Void, Never>?
    private var isPolling: Bool = false
    private let pollingInterval: TimeInterval = 5.0  // Poll every 5 seconds

    // MARK: - Background Sync State (For orphaned meals)
    private var backgroundSyncTask: Task<Void, Never>?
    private var isBackgroundSyncing: Bool = false
    private let backgroundSyncInterval: TimeInterval = 30.0  // Check every 30 seconds

    // MARK: - WebSocket Subscription Tracking
    private var completedSubscriptionId: UUID?
    private var failedSubscriptionId: UUID?

    // MARK: - Initialization
    init(
        saveMealLogUseCase: SaveMealLogUseCase,
        getMealLogsUseCase: GetMealLogsUseCase,
        updateMealLogStatusUseCase: UpdateMealLogStatusUseCase,
        syncPendingMealLogsUseCase: SyncPendingMealLogsUseCase,
        deleteMealLogUseCase: DeleteMealLogUseCase,
        webSocketService: MealLogWebSocketService,
        authManager: AuthManager,
        outboxProcessor: OutboxProcessorService,
        saveWaterProgressUseCase: SaveWaterProgressUseCase,
        nutritionSummaryViewModel: NutritionSummaryViewModel
    ) {
        self.saveMealLogUseCase = saveMealLogUseCase
        self.getMealLogsUseCase = getMealLogsUseCase
        self.updateMealLogStatusUseCase = updateMealLogStatusUseCase
        self.syncPendingMealLogsUseCase = syncPendingMealLogsUseCase
        self.deleteMealLogUseCase = deleteMealLogUseCase
        self.webSocketService = webSocketService
        self.authManager = authManager
        self.outboxProcessor = outboxProcessor
        self.saveWaterProgressUseCase = saveWaterProgressUseCase
        self.nutritionSummaryViewModel = nutritionSummaryViewModel

        Task {
            await connectWebSocket()
        }

        // Start background sync for orphaned meals
        startBackgroundSync()
    }

    deinit {
        // Cleanup: unsubscribe from WebSocket events
        if let completedId = completedSubscriptionId {
            webSocketService.unsubscribeFromCompleted(subscriptionId: completedId)
        }
        if let failedId = failedSubscriptionId {
            webSocketService.unsubscribeFromFailed(subscriptionId: failedId)
        }

        // Disconnect WebSocket
        webSocketService.disconnect()

        // Cancel polling task
        pollingTask?.cancel()
        print("NutritionViewModel: Deinitialized, polling stopped")
    }

    // MARK: - Actions

    /// Deletes a meal log by its ID
    @MainActor
    func deleteMealLog(id: UUID) async {
        print("NutritionViewModel: Deleting meal log \(id)")

        do {
            try await deleteMealLogUseCase.execute(id: id)

            // Remove from local UI state immediately
            meals.removeAll { $0.id == id }

            // Recalculate daily summary
            self.dailySummary = meals.reduce((kcal: 0, protein: 0, carbs: 0, fat: 0)) {
                result, meal in
                (
                    result.kcal + meal.calories,
                    result.protein + meal.protein,
                    result.carbs + meal.carbs,
                    result.fat + meal.fat
                )
            }

            print("NutritionViewModel: Successfully deleted meal log \(id)")
        } catch {
            errorMessage = "Failed to delete meal: \(error.localizedDescription)"
            print("NutritionViewModel: Error deleting meal log: \(error)")
        }
    }

    /// Loads meal logs for the currently selected date
    @MainActor
    func loadDataForSelectedDate() async {
        isLoading = true
        errorMessage = nil

        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        print("NutritionViewModel: Loading meals for \(selectedDate)")

        do {
            // ✅ LOCAL-FIRST: Always load from local storage
            // WebSocket updates will automatically refresh the view
            let mealLogs = try await getMealLogsUseCase.execute(
                status: nil,  // Show all meals regardless of status (pending, processing, completed, failed)
                syncStatus: nil,
                mealType: nil,
                startDate: startOfDay,
                endDate: endOfDay,
                limit: nil,
                useLocalOnly: true  // ✅ Always use local storage (updated by WebSocket)
            )

            // Map domain models to UI models
            self.meals = mealLogs.map { DailyMealLog.from(mealLog: $0) }

            // Calculate daily summary from loaded meals
            self.dailySummary = meals.reduce((kcal: 0, protein: 0, carbs: 0, fat: 0)) {
                result, meal in
                (
                    result.kcal + meal.calories,
                    result.protein + meal.protein,
                    result.carbs + meal.carbs,
                    result.fat + meal.fat
                )
            }

            print("NutritionViewModel: Successfully loaded \(meals.count) meals")
            print(
                "NutritionViewModel: Daily summary - Calories: \(dailySummary.kcal), Protein: \(dailySummary.protein)g, Carbs: \(dailySummary.carbs)g, Fat: \(dailySummary.fat)g"
            )

        } catch {
            errorMessage = error.localizedDescription
            print("NutritionViewModel: Failed to load meals: \(error)")

            // Set empty state on error
            self.meals = []
            self.dailySummary = (0, 0, 0, 0)
        }

        isLoading = false
    }

    /// Saves a new meal log
    @MainActor
    func saveMealLog(
        rawInput: String,
        mealType: MealType,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) async {
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a meal description"
            return
        }

        isLoading = true
        errorMessage = nil

        let startTime = Date()
        print("NutritionViewModel: 🍽️ Saving meal log at \(startTime)")
        print("  - Raw Input: \(rawInput)")
        print("  - Meal Type: \(mealType.rawValue)")
        print("  - Logged At: \(loggedAt)")

        do {
            // ✅ REAL API CALL: Save meal log
            let useCaseStart = Date()
            let localID = try await saveMealLogUseCase.execute(
                rawInput: rawInput,
                mealType: mealType,
                loggedAt: loggedAt,
                notes: notes
            )
            let useCaseDuration = Date().timeIntervalSince(useCaseStart)

            print(
                "NutritionViewModel: Meal log saved successfully with ID: \(localID) (use case: \(String(format: "%.3f", useCaseDuration))s)"
            )
            print("NutritionViewModel: Outbox Pattern will sync to backend")

            // ⚡ PRESENTATION LAYER: Trigger immediate outbox processing for real-time feel
            // This is OK here - presentation layer can orchestrate infrastructure concerns
            // Using async version to await completion for immediate UI feedback
            if let userUUID = authManager.currentUserProfileID {
                let triggerTime = Date()
                print(
                    "NutritionViewModel: ⚡ Triggering immediate outbox processing (async) at \(triggerTime)"
                )
                await outboxProcessor.triggerImmediateProcessingAsync(forUserID: userUUID)
                let triggerDuration = Date().timeIntervalSince(triggerTime)
                print(
                    "NutritionViewModel: ⚡ Immediate processing completed in \(String(format: "%.3f", triggerDuration))s"
                )
            }

            // Refresh meal list to show newly saved meal
            await loadDataForSelectedDate()

            // Always start polling for updates after meal submission
            // This ensures UI updates even if WebSocket connection is unreliable
            if !isPolling {
                print("NutritionViewModel: Starting polling after meal submission")
                startPolling()
            }

            let totalDuration = Date().timeIntervalSince(startTime)
            print(
                "NutritionViewModel: ✅ Meal save flow completed in \(String(format: "%.3f", totalDuration))s"
            )

        } catch {
            errorMessage = error.localizedDescription
            print("NutritionViewModel: Failed to save meal: \(error)")
        }

        isLoading = false
    }

    /// Save completed meal log from photo recognition with all structured data
    /// Bypasses text parsing to preserve exact macros and items from photo recognition
    @MainActor
    func saveCompletedMealLogFromPhoto(photoRecognition: PhotoRecognitionUIModel) async throws {
        print("NutritionViewModel: 💾 Saving completed meal log from photo recognition")
        print("NutritionViewModel: - Items: \(photoRecognition.recognizedItems.count)")
        print("NutritionViewModel: - Total calories: \(photoRecognition.totalCalories ?? 0)")
        print("NutritionViewModel: - Total protein: \(photoRecognition.totalProteinG ?? 0)g")
        print("NutritionViewModel: - Total carbs: \(photoRecognition.totalCarbsG ?? 0)g")
        print("NutritionViewModel: - Total fat: \(photoRecognition.totalFatG ?? 0)g")
        print(
            "NutritionViewModel: - Overall confidence: \(Int((photoRecognition.confidenceScore ?? 0) * 100))%"
        )

        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw NSError(
                domain: "NutritionViewModel", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Create raw input text for display purposes
        let rawInput = photoRecognition.recognizedItems.map { item in
            "\(item.quantity)\(item.unit) \(item.name)"
        }.joined(separator: ", ")

        // Create meal log items with all data from photo recognition
        let mealLogItems = photoRecognition.recognizedItems.enumerated().map { index, item in
            MealLogItem(
                id: item.id,
                mealLogID: UUID(),  // Will be set by repository
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                calories: Double(item.calories),
                protein: item.proteinG,
                carbs: item.carbsG,
                fat: item.fatG,
                foodType: .food,
                fiber: item.fiberG,
                sugar: item.sugarG,
                confidence: item.confidenceScore,  // Already in 0-1 range from API client
                parsingNotes: nil,
                orderIndex: index,
                createdAt: Date(),
                backendID: nil
            )
        }

        // Create completed meal log with all structured data
        let mealLog = MealLog(
            id: UUID(),
            userID: userID,
            rawInput: rawInput,
            mealType: photoRecognition.mealType,
            status: .completed,  // Already processed by photo recognition
            loggedAt: photoRecognition.loggedAt,
            items: mealLogItems,
            notes: photoRecognition.notes,
            totalCalories: photoRecognition.totalCalories ?? 0,
            totalProteinG: photoRecognition.totalProteinG ?? 0,
            totalCarbsG: photoRecognition.totalCarbsG ?? 0,
            totalFatG: photoRecognition.totalFatG ?? 0,
            totalFiberG: photoRecognition.totalFiberG ?? 0,
            totalSugarG: photoRecognition.totalSugarG ?? 0,
            createdAt: Date(),
            updatedAt: Date(),
            backendID: photoRecognition.backendID,
            syncStatus: .synced  // Already processed and synced during photo upload
        )

        // Save using use case (follows hexagonal architecture - ViewModel depends on use cases, not repositories)
        // Note: Photo meal logs are already processed by backend during upload, so no Outbox sync needed
        let localID = try await saveMealLogUseCase.executeWithCompletedMeal(mealLog: mealLog)

        print("NutritionViewModel: ✅ Completed meal log saved with ID: \(localID)")
        print("NutritionViewModel: - All macros and items preserved from photo recognition")
        print(
            "NutritionViewModel: - Overall confidence: \(Int((photoRecognition.confidenceScore ?? 0) * 100))% (stored in PhotoRecognition)"
        )
        print("NutritionViewModel: - No Outbox sync needed (already processed by backend)")

        // Refresh to show the meal
        await loadDataForSelectedDate()
    }

    /// Fetches all meals (for testing/debugging)
    @MainActor
    func fetchAllMeals() async {
        isLoading = true
        errorMessage = nil

        do {
            let allMealLogs = try await getMealLogsUseCase.execute(
                status: nil,
                syncStatus: nil,
                mealType: nil,
                startDate: nil,
                endDate: nil,
                limit: 100,
                useLocalOnly: true  // ✅ Local-first for debugging too
            )

            print("NutritionViewModel: Fetched \(allMealLogs.count) total meals")

        } catch {
            print("NutritionViewModel: Failed to fetch all meals: \(error)")
        }

        isLoading = false
    }

    // MARK: - WebSocket Integration

    /// Connect to WebSocket for real-time updates
    @MainActor
    private func connectWebSocket() async {
        guard !isWebSocketConnecting else {
            print("NutritionViewModel: WebSocket connection already in progress")
            return
        }

        // Unsubscribe from previous subscriptions to prevent duplicates
        if let completedId = completedSubscriptionId {
            webSocketService.unsubscribeFromCompleted(subscriptionId: completedId)
            print(
                "NutritionViewModel: ⚠️ Unsubscribed previous completed subscription: \(completedId)"
            )
            completedSubscriptionId = nil
        }
        if let failedId = failedSubscriptionId {
            webSocketService.unsubscribeFromFailed(subscriptionId: failedId)
            print("NutritionViewModel: ⚠️ Unsubscribed previous failed subscription: \(failedId)")
            failedSubscriptionId = nil
        }

        isWebSocketConnecting = true
        print("NutritionViewModel: Connecting to WebSocket for /ws/meal-logs...")

        do {
            // Connect via service with separate handlers for completed and failed events
            // Store subscription IDs to prevent duplicates
            let (completedId, failedId) = try await webSocketService.connect(
                onCompleted: { [weak self] payload in
                    await self?.handleMealLogCompleted(payload)
                },
                onFailed: { [weak self] payload in
                    await self?.handleMealLogFailed(payload)
                }
            )

            // Track subscription IDs
            completedSubscriptionId = completedId
            failedSubscriptionId = failedId

            isWebSocketConnected = true
            isWebSocketConnecting = false
            print("NutritionViewModel: ✅ WebSocket connected and subscribed to meal log events")
            print(
                "NutritionViewModel: 📋 Subscription IDs - Completed: \(completedId), Failed: \(failedId)"
            )

            // Stop polling if it was running as fallback
            if isPolling {
                print("NutritionViewModel: WebSocket connected, stopping polling fallback")
                stopPolling()
            }
        } catch {
            isWebSocketConnected = false
            isWebSocketConnecting = false
            print("NutritionViewModel: ❌ Failed to connect to WebSocket: \(error)")
            errorMessage = "Failed to connect to real-time updates"

            // WebSocket failed - start polling as fallback
            print("NutritionViewModel: Starting polling as fallback")
            startPolling()
        }
    }

    /// Handle meal log completed event from WebSocket
    @MainActor
    private func handleMealLogCompleted(_ payload: MealLogCompletedPayload) async {
        print("NutritionViewModel: 📩 Meal log completed")
        print("NutritionViewModel:    - ID: \(payload.id)")
        print("NutritionViewModel:    - Meal Type: \(payload.mealType)")
        print("NutritionViewModel:    - Items: \(payload.items.count)")
        print("NutritionViewModel:    - Total Calories: \(payload.totalCalories ?? 0)")
        print("NutritionViewModel:    - Total Protein: \(payload.totalProteinG ?? 0)g")
        print("NutritionViewModel:    - Total Carbs: \(payload.totalCarbsG ?? 0)g")
        print("NutritionViewModel:    - Total Fat: \(payload.totalFatG ?? 0)g")

        // Mark WebSocket as definitely connected (received message)
        isWebSocketConnected = true

        // Convert payload items to domain items (outside do block for water tracking)
        let domainItems = payload.items.map { item in
            MealLogItem(
                id: UUID(),  // Generate local UUID
                mealLogID: UUID(),  // Will be set by repository
                name: item.foodName,
                quantity: item.quantity,
                unit: item.unit,
                calories: Double(item.calories),
                protein: item.proteinG,
                carbs: item.carbsG,
                fat: item.fatG,
                foodType: FoodType(rawValue: item.foodType) ?? .food,
                fiber: item.fiberG,
                sugar: item.sugarG,
                confidence: item.confidenceScore,
                parsingNotes: item.parsingNotes,
                orderIndex: item.orderIndex,
                createdAt: Date(),
                backendID: item.id
            )
        }

        // Parse loggedAt from ISO8601 string to Date
        let loggedAtDate: Date = {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: payload.loggedAt) ?? Date()
        }()

        // ✅ UPDATE LOCAL STORAGE: Update the local meal log with backend processing results
        do {
            // Update the local meal log with completed status and items
            try await updateMealLogStatusUseCase.execute(
                backendID: payload.id,
                status: .completed,
                items: domainItems,
                totalCalories: payload.totalCalories,
                totalProteinG: payload.totalProteinG,
                totalCarbsG: payload.totalCarbsG,
                totalFatG: payload.totalFatG,
                totalFiberG: payload.totalFiberG,
                totalSugarG: payload.totalSugarG,
                errorMessage: nil
            )

            print("NutritionViewModel: ✅ Local meal log updated with backend data")
        } catch {
            print("NutritionViewModel: ❌ Failed to update local meal log: \(error)")
            errorMessage = "Failed to update meal: \(error.localizedDescription)"
        }

        print("NutritionViewModel: Refreshing meal list to show completed meal")

        // ✅ WATER INTAKE TRACKING: Check if any items are water and log to progress API
        await trackWaterIntake(from: domainItems, loggedAt: loggedAtDate)

        // Refresh the meal list to show updated meal with parsed items
        await loadDataForSelectedDate()

        // Stop polling since WebSocket is working
        if isPolling {
            print("NutritionViewModel: WebSocket working, stopping polling")
            stopPolling()
        }

        print("NutritionViewModel: ✅ Meal log completed - UI updated")
    }

    /// Track water intake from meal items with food_type = water
    @MainActor
    private func trackWaterIntake(from items: [MealLogItem], loggedAt: Date) async {
        print("NutritionViewModel: 💧 ========== trackWaterIntake CALLED ==========")
        print("NutritionViewModel: 💧 Total items: \(items.count)")
        print("NutritionViewModel: 💧 Logged at: \(loggedAt)")
        print("NutritionViewModel: 💧 Thread: \(Thread.current)")
        print(
            "NutritionViewModel: 💧 Call stack: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))"
        )

        // Filter water items
        let waterItems = items.filter { $0.foodType == .water }

        guard !waterItems.isEmpty else {
            print("NutritionViewModel: 💧 No water items to track")
            return
        }

        print("NutritionViewModel: 💧 Found \(waterItems.count) water item(s) to track")
        for (index, item) in waterItems.enumerated() {
            print("NutritionViewModel: 💧 Water item #\(index + 1):")
            print("NutritionViewModel: 💧   - Name: '\(item.name)'")
            print("NutritionViewModel: 💧   - Quantity (raw): \(item.quantity)")
            print("NutritionViewModel: 💧   - Unit (raw): '\(item.unit)'")
            print("NutritionViewModel: 💧   - Food Type: \(item.foodType)")
            print("NutritionViewModel: 💧   - Backend ID: \(item.backendID ?? "nil")")
        }

        // Calculate total water intake in liters
        // Use the separate quantity (Double) and unit (String) fields directly
        var totalWaterLiters: Double = 0.0

        for item in waterItems {
            let quantity = item.quantity
            let unit = item.unit.lowercased()

            print(
                "NutritionViewModel: 💧 Processing water item '\(item.name)': \(quantity) \(unit)"
            )

            var itemLiters: Double = 0.0

            // Convert to liters based on unit
            if unit == "l" || unit == "liter" || unit == "liters" {
                itemLiters = quantity  // Already in liters
                print("NutritionViewModel: 💧   Unit: L → \(String(format: "%.3f", itemLiters))L")
            } else if unit == "ml" || unit == "milliliter" || unit == "milliliters" {
                itemLiters = quantity / 1000.0  // Convert mL to L
                print("NutritionViewModel: 💧   Unit: mL → \(String(format: "%.3f", itemLiters))L")
            } else if unit == "cup" || unit == "cups" {
                itemLiters = quantity * 0.237  // 1 cup ≈ 237 mL
                print("NutritionViewModel: 💧   Unit: cup → \(String(format: "%.3f", itemLiters))L")
            } else if unit == "oz" || unit == "fl oz" || unit == "ounce" || unit == "ounces" {
                itemLiters = quantity * 0.0296  // 1 fl oz ≈ 29.6 mL
                print("NutritionViewModel: 💧   Unit: oz → \(String(format: "%.3f", itemLiters))L")
            } else if unit == "glass" || unit == "glasses" {
                itemLiters = quantity * 0.250  // Assume 1 glass ≈ 250 mL
                print(
                    "NutritionViewModel: 💧   Unit: glass → \(String(format: "%.3f", itemLiters))L")
            } else {
                // Default: assume mL if unit is unknown
                itemLiters = quantity / 1000.0
                print(
                    "NutritionViewModel: 💧   Unit: unknown (\(unit)), assuming mL → \(String(format: "%.3f", itemLiters))L"
                )
            }

            totalWaterLiters += itemLiters
            print(
                "NutritionViewModel: 💧   Running total: \(String(format: "%.3f", totalWaterLiters))L"
            )
        }

        guard totalWaterLiters > 0 else {
            print("NutritionViewModel: ⚠️ Total water intake is zero")
            return
        }

        print(
            "NutritionViewModel: 💧 ========================================")
        print(
            "NutritionViewModel: 💧 TOTAL WATER INTAKE CALCULATED: \(String(format: "%.3f", totalWaterLiters))L"
        )
        print(
            "NutritionViewModel: 💧 ========================================")

        // Save water intake to progress API
        do {
            print("NutritionViewModel: 💧 Calling SaveWaterProgressUseCase...")
            print(
                "NutritionViewModel: 💧   Input liters: \(String(format: "%.3f", totalWaterLiters))L"
            )
            print("NutritionViewModel: 💧   Date: \(loggedAt)")

            let localID = try await saveWaterProgressUseCase.execute(
                liters: totalWaterLiters,
                date: loggedAt
            )

            print("NutritionViewModel: ✅ Water intake saved to progress API")
            print("NutritionViewModel: ✅   Local ID: \(localID)")
            print(
                "NutritionViewModel: ✅   Amount saved: \(String(format: "%.3f", totalWaterLiters))L"
            )

            // ✅ REFRESH UI: Update NutritionSummaryViewModel with latest water intake from LOCAL storage
            print(
                "NutritionViewModel: 💧 Refreshing UI with latest water intake from local storage..."
            )
            let beforeRefresh = nutritionSummaryViewModel.waterIntakeLiters
            print(
                "NutritionViewModel: 💧   Water before refresh: \(String(format: "%.3f", beforeRefresh))L"
            )

            await nutritionSummaryViewModel.loadWaterIntake()

            let afterRefresh = nutritionSummaryViewModel.waterIntakeLiters
            print(
                "NutritionViewModel: 💧   Water after refresh: \(String(format: "%.3f", afterRefresh))L"
            )
            print(
                "NutritionViewModel: 💧   Difference: \(String(format: "%.3f", afterRefresh - beforeRefresh))L"
            )
            print(
                "NutritionViewModel: 💧 UI refresh complete. Display: \(nutritionSummaryViewModel.waterIntakeFormatted)"
            )
        } catch {
            print("NutritionViewModel: ❌ Failed to save water intake: \(error)")
            // Don't block meal processing on water tracking failure
        }

        print("NutritionViewModel: 💧 ========== trackWaterIntake COMPLETE ==========")
    }

    /// Handle meal log failed event from WebSocket
    @MainActor
    private func handleMealLogFailed(_ payload: MealLogFailedPayload) async {
        print("NutritionViewModel: ❌ Meal log failed")
        print("NutritionViewModel:    - ID: \(payload.mealLogId)")
        print("NutritionViewModel:    - Error: \(payload.error)")
        print("NutritionViewModel:    - Error Code: \(payload.errorCode)")

        if let details = payload.details {
            print("NutritionViewModel:    - Details: \(details)")
        }

        if let suggestions = payload.suggestions {
            print("NutritionViewModel:    - Suggestions:")
            for suggestion in suggestions {
                print("NutritionViewModel:      • \(suggestion)")
            }
        }

        // Mark WebSocket as definitely connected (received message)
        isWebSocketConnected = true

        // ✅ LOCAL-FIRST: Update local meal log status to failed
        // Show error message to user

        // Set error message from payload
        errorMessage = payload.error

        // Refresh the meal list to show failed meal with error
        await loadDataForSelectedDate()

        print("NutritionViewModel: ✅ Meal log failure handled - UI updated")

        // Stop polling since WebSocket is working
        if isPolling {
            print("NutritionViewModel: WebSocket working, stopping polling")
            stopPolling()
        }
    }

    /// Manually reconnect WebSocket (useful for testing or after auth token refresh)
    @MainActor
    func reconnectWebSocket() async {
        print("NutritionViewModel: Manually reconnecting WebSocket...")

        // Reset connection state
        isWebSocketConnected = false
        isWebSocketConnecting = false

        do {
            // Reconnect via service with separate handlers for completed and failed events
            isWebSocketConnecting = true
            try await webSocketService.reconnect(
                onCompleted: { [weak self] payload in
                    await self?.handleMealLogCompleted(payload)
                },
                onFailed: { [weak self] payload in
                    await self?.handleMealLogFailed(payload)
                }
            )

            isWebSocketConnected = true
            isWebSocketConnecting = false
            print("NutritionViewModel: ✅ WebSocket reconnected successfully")

            // Stop polling if it was running as fallback
            if isPolling {
                print("NutritionViewModel: WebSocket reconnected, stopping polling fallback")
                stopPolling()
            }
        } catch {
            isWebSocketConnected = false
            isWebSocketConnecting = false
            print("NutritionViewModel: ❌ Failed to reconnect WebSocket: \(error)")
            errorMessage = "Failed to reconnect to real-time updates"

            // Start polling as fallback
            if !isPolling {
                print("NutritionViewModel: Starting polling as fallback after reconnection failure")
                startPolling()
            }
        }
    }

    // MARK: - Polling (Fallback for when WebSocket unavailable)

    /// Start polling for meal updates (fallback when WebSocket unavailable)
    @MainActor
    private func startPolling() {
        guard !isPolling else {
            print("NutritionViewModel: ⏭️ Polling already active")
            return
        }

        print("NutritionViewModel: 🔄 Starting polling (interval: \(pollingInterval)s)")
        isPolling = true

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }

                // Wait for polling interval
                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))

                guard !Task.isCancelled else {
                    print("NutritionViewModel: Polling task cancelled")
                    break
                }

                // Check if WebSocket connected (stop polling if it is)
                if self.webSocketService.isConnected && self.isWebSocketConnected {
                    print("NutritionViewModel: WebSocket connected, stopping polling")
                    await self.stopPolling()
                    break
                }

                // Refresh meals to get latest data
                print("NutritionViewModel: 🔄 Polling: Refreshing meals...")
                await self.loadDataForSelectedDate()

                // Smart polling: Stop if no meals are in processing state
                let hasProcessingMeals = await MainActor.run {
                    self.meals.contains { $0.status == MealLogStatus.processing }
                }

                // Stop polling if no meals are processing
                if !hasProcessingMeals {
                    print("NutritionViewModel: No processing meals, stopping polling")
                    await self.stopPolling()
                    break
                }
            }

            await MainActor.run {
                self!.isPolling = false
            }
        }
    }

    /// Stop polling
    @MainActor
    private func stopPolling() {
        guard isPolling else { return }

        print("NutritionViewModel: 🛑 Stopping polling")
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    // MARK: - Background Sync (For Orphaned Meals)

    /// Starts background sync to check for orphaned meals that never received WebSocket updates
    private func startBackgroundSync() {
        guard !isBackgroundSyncing else {
            print("NutritionViewModel: ⚠️ Background sync already running")
            return
        }

        print(
            "NutritionViewModel: 🔄 Starting background sync (interval: \(backgroundSyncInterval)s)")
        isBackgroundSyncing = true

        backgroundSyncTask = Task {
            while !Task.isCancelled {
                // Wait for the interval
                try? await Task.sleep(for: .seconds(backgroundSyncInterval))

                guard !Task.isCancelled else { break }

                // Sync pending meal logs
                await syncPendingMeals()
            }

            isBackgroundSyncing = false
            print("NutritionViewModel: 🛑 Background sync stopped")
        }
    }

    /// Stops background sync
    private func stopBackgroundSync() {
        guard isBackgroundSyncing else { return }

        print("NutritionViewModel: 🛑 Stopping background sync")
        backgroundSyncTask?.cancel()
        backgroundSyncTask = nil
        isBackgroundSyncing = false
    }

    /// Syncs pending/processing meal logs from backend
    @MainActor
    private func syncPendingMeals() async {
        do {
            print("NutritionViewModel: 🔄 Syncing pending meal logs from backend")

            let updatedCount = try await syncPendingMealLogsUseCase.execute()

            if updatedCount > 0 {
                print("NutritionViewModel: ✅ Synced \(updatedCount) meal log(s)")

                // Refresh UI to show updated meals
                await loadDataForSelectedDate()
            } else {
                print("NutritionViewModel: ℹ️ No pending meals to sync")
            }

        } catch {
            print("NutritionViewModel: ⚠️ Failed to sync pending meals: \(error)")
            // Don't show error to user (silent background sync)
        }
    }

    /// Manually triggers a sync of pending meals (for pull-to-refresh)
    @MainActor
    func manualSyncPendingMeals() async {
        print("NutritionViewModel: 🔄 Manual sync triggered")
        await syncPendingMeals()
    }
}
