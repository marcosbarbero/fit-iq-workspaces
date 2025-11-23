//
//  OutboxProcessorService.swift
//  FitIQ
//
//  Created by AI Assistant on 31/01/2025.
//

import Combine
import FitIQCore
import Foundation

/// Service that processes outbox events to sync data with remote API
///
/// This replaces the event-based RemoteSyncService with a more robust
/// Outbox Pattern approach. Events are persisted in SwiftData and processed
/// in a reliable, crash-resistant manner.
///
/// Features:
/// - Persistent event queue (survives app crashes)
/// - Automatic retry with exponential backoff
/// - Batch processing with configurable concurrency
/// - Transaction-safe (event + data saved atomically)
/// - Observable processing state
public final class OutboxProcessorService {

    // MARK: - Properties

    private let outboxRepository: OutboxRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let localHealthDataStore: LocalHealthDataStorePort
    private let activitySnapshotRepository: ActivitySnapshotRepositoryProtocol
    private let remoteDataSync: RemoteHealthDataSyncPort
    private let authManager: AuthManager
    private let sleepRepository: SleepRepositoryProtocol
    private let sleepAPIClient: SleepAPIClientProtocol
    private let mealLogRepository: MealLogLocalStorageProtocol
    private let nutritionAPIClient: MealLogRemoteAPIProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let workoutAPIClient: WorkoutAPIClientProtocol
    private let workoutTemplateRepository: WorkoutTemplateRepositoryProtocol
    private let workoutTemplateAPIClient: WorkoutTemplateAPIClientProtocol

    private var isProcessing = false
    private var processingTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Configuration

    private let batchSize: Int
    private let processingInterval: TimeInterval
    private let cleanupInterval: TimeInterval
    private let maxConcurrentOperations: Int
    private let retryDelays: [TimeInterval]

    // MARK: - Initialization

    init(
        outboxRepository: OutboxRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        localHealthDataStore: LocalHealthDataStorePort,
        activitySnapshotRepository: ActivitySnapshotRepositoryProtocol,
        remoteDataSync: RemoteHealthDataSyncPort,
        authManager: AuthManager,
        sleepRepository: SleepRepositoryProtocol,
        sleepAPIClient: SleepAPIClientProtocol,
        mealLogRepository: MealLogLocalStorageProtocol,
        nutritionAPIClient: MealLogRemoteAPIProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        workoutAPIClient: WorkoutAPIClientProtocol,
        workoutTemplateRepository: WorkoutTemplateRepositoryProtocol,
        workoutTemplateAPIClient: WorkoutTemplateAPIClientProtocol,
        batchSize: Int = 10,
        processingInterval: TimeInterval = 0.1,  // 0.1s for near real-time processing
        cleanupInterval: TimeInterval = 300,  // 5 minutes (safety net for orphaned completed events)
        maxConcurrentOperations: Int = 3
    ) {
        self.outboxRepository = outboxRepository
        self.progressRepository = progressRepository
        self.localHealthDataStore = localHealthDataStore
        self.activitySnapshotRepository = activitySnapshotRepository
        self.remoteDataSync = remoteDataSync
        self.authManager = authManager
        self.sleepRepository = sleepRepository
        self.sleepAPIClient = sleepAPIClient
        self.mealLogRepository = mealLogRepository
        self.nutritionAPIClient = nutritionAPIClient
        self.workoutRepository = workoutRepository
        self.workoutAPIClient = workoutAPIClient
        self.workoutTemplateRepository = workoutTemplateRepository
        self.workoutTemplateAPIClient = workoutTemplateAPIClient
        self.batchSize = batchSize
        self.processingInterval = processingInterval
        self.cleanupInterval = cleanupInterval
        self.maxConcurrentOperations = maxConcurrentOperations

        // Exponential backoff: 1s, 5s, 30s, 2m, 10m
        self.retryDelays = [1, 5, 30, 120, 600]
    }

    // MARK: - Public API

    /// Starts processing outbox events for a specific user
    /// - Parameter userID: User ID to process events for
    public func startProcessing(forUserID userID: UUID) {
        // If already processing for a different user, stop first
        if isProcessing {
            print("OutboxProcessor: Already processing, restarting for new user \(userID)")
            stopProcessing()
        }

        isProcessing = true
        print("OutboxProcessor: 🚀 Starting outbox processor for user \(userID)")

        // Start periodic processing
        processingTask = Task { [weak self] in
            await self?.processLoop(userID: userID.uuidString)
        }

        // Start periodic cleanup
        cleanupTask = Task { [weak self] in
            await self?.cleanupLoop()
        }
    }

    /// Stops processing outbox events
    public func stopProcessing() {
        guard isProcessing else { return }

        print("OutboxProcessor: 🛑 Stopping outbox processor")
        isProcessing = false

        processingTask?.cancel()
        processingTask = nil

        cleanupTask?.cancel()
        cleanupTask = nil
    }

    /// Triggers immediate processing of pending events (skips waiting for next poll cycle)
    /// Use this after creating high-priority events (like meal logs) for instant feedback
    /// - Parameter userID: User ID to process events for
    public func triggerImmediateProcessing(forUserID userID: UUID) {
        guard isProcessing else {
            print("OutboxProcessor: ⚠️ Cannot trigger immediate processing - processor not started")
            return
        }

        let timestamp = Date()
        print(
            "OutboxProcessor: ⚡ Triggering immediate processing for user \(userID) at \(timestamp)")

        // Create a HIGH PRIORITY task to process immediately
        // This ensures the task runs as soon as possible without scheduler delays
        Task(priority: .high) { [weak self] in
            let startTime = Date()
            let schedulingDelay = startTime.timeIntervalSince(timestamp)
            print(
                "OutboxProcessor: 🚀 Immediate batch started at \(startTime) (scheduling delay: \(String(format: "%.3f", schedulingDelay))s)"
            )
            await self?.processBatch(userID: userID.uuidString)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print(
                "OutboxProcessor: ✅ Immediate batch completed in \(String(format: "%.3f", duration))s"
            )
        }
    }

    /// Async version of triggerImmediateProcessing that can be awaited for sequential execution
    /// Use this when you need to ensure processing completes before continuing
    /// - Parameter userID: User ID to process events for
    public func triggerImmediateProcessingAsync(forUserID userID: UUID) async {
        guard isProcessing else {
            print("OutboxProcessor: ⚠️ Cannot trigger immediate processing - processor not started")
            return
        }

        let timestamp = Date()
        print(
            "OutboxProcessor: ⚡ Triggering immediate processing (async) for user \(userID) at \(timestamp)"
        )

        let startTime = Date()
        print("OutboxProcessor: 🚀 Immediate batch started at \(startTime)")
        await processBatch(userID: userID.uuidString)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        print(
            "OutboxProcessor: ✅ Immediate batch completed in \(String(format: "%.3f", duration))s"
        )
    }

    // MARK: - Processing Loop
    /// Triggers immediate processing of pending outbox events (bypasses polling interval)
    ///
    /// Use this after creating a new outbox event to provide immediate feedback to the user
    /// instead of waiting for the next polling interval.
    ///
    /// - Parameter userID: User ID to process events for
    ///
    /// **Example:**
    /// ```swift

    /// Manually triggers processing (useful for testing or force sync)
    /// - Parameter userID: User ID to process events for
    public func triggerProcessing(forUserID userID: String) async {
        print("OutboxProcessor: 🔄 Manual trigger for user \(userID)")
        await processBatch(userID: userID)
    }

    // MARK: - Processing Loop

    private func processLoop(userID: String) async {
        print("OutboxProcessor: Process loop started")

        while !Task.isCancelled && isProcessing {
            do {
                // Process a batch
                await processBatch(userID: userID)

                // Wait before next iteration
                try await Task.sleep(nanoseconds: UInt64(processingInterval * 1_000_000_000))

            } catch is CancellationError {
                print("OutboxProcessor: Process loop cancelled")
                break
            } catch {
                print("OutboxProcessor: Error in process loop: \(error.localizedDescription)")
                // Continue processing despite errors
            }
        }

        print("OutboxProcessor: Process loop stopped")
    }

    private func processBatch(userID: String) async {
        let batchStartTime = Date()
        do {
            // Fetch pending events
            let fetchStart = Date()
            let pendingEvents = try await outboxRepository.fetchPendingEvents(
                forUserID: userID,
                limit: batchSize
            )
            let fetchDuration = Date().timeIntervalSince(fetchStart)

            guard !pendingEvents.isEmpty else {
                // No events to process
                return
            }

            print(
                "OutboxProcessor: 📦 Processing batch of \(pendingEvents.count) pending events (fetch: \(String(format: "%.3f", fetchDuration))s)"
            )

            // Log event types in batch
            let eventTypeCounts = Dictionary(grouping: pendingEvents) { $0.eventType }
                .mapValues { $0.count }
            for (type, count) in eventTypeCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                print("  - \(type.displayName): \(count) event(s)")
            }

            // Process events with concurrency limit
            await withTaskGroup(of: Void.self) { group in
                var activeCount = 0

                for event in pendingEvents {
                    // Wait if we've hit concurrency limit
                    while activeCount >= maxConcurrentOperations {
                        await group.next()
                        activeCount -= 1
                    }

                    // Add task to group
                    group.addTask { [weak self] in
                        await self?.processEvent(event)
                    }
                    activeCount += 1
                }

                // Wait for all tasks to complete
                await group.waitForAll()
            }

            let totalDuration = Date().timeIntervalSince(batchStartTime)
            print(
                "OutboxProcessor: ✅ Batch processing complete in \(String(format: "%.3f", totalDuration))s"
            )

        } catch {
            print("OutboxProcessor: ❌ Error processing batch: \(error.localizedDescription)")
        }
    }

    // MARK: - Event Processing

    private func processEvent(_ event: OutboxEvent) async {
        // Apply exponential backoff for retries
        if event.attemptCount > 0 {
            let delayIndex = min(event.attemptCount - 1, retryDelays.count - 1)
            let delay = retryDelays[delayIndex]

            print("OutboxProcessor: ⏱️ Retry delay: \(delay)s for event \(event.id)")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        let eventStartTime = Date()
        do {
            // Mark as processing
            try await outboxRepository.markAsProcessing(event.id)

            // Enhanced logging with event details
            print(
                "OutboxProcessor: 🔄 Processing [\(event.eventType.displayName)] - EventID: \(event.id) | EntityID: \(event.entityID) | Attempt: \(event.attemptCount + 1)/\(event.maxAttempts) | Started: \(eventStartTime)"
            )

            // Process based on event type
            switch event.eventType {
            case .progressEntry:
                try await processProgressEntry(event)
            case .physicalAttribute:
                try await processPhysicalAttribute(event)
            case .activitySnapshot:
                try await processActivitySnapshot(event)
            case .profileMetadata:
                try await processProfileMetadata(event)
            case .profilePhysical:
                try await processProfilePhysical(event)
            case .sleepSession:
                try await processSleepSession(event)
            case .mealLog:
                try await processMealLog(event)
            case .workout:
                try await processWorkout(event)
            case .workoutTemplate:
                try await processWorkoutTemplate(event)
            case .moodEntry, .journalEntry, .goal, .chatMessage:
                throw OutboxProcessorError.unsupportedEventType(event.eventType.rawValue)
            }

            // Delete event immediately after successful processing
            // This prevents the outbox table from growing exponentially
            try await outboxRepository.deleteEvent(event.id)

            let eventDuration = Date().timeIntervalSince(eventStartTime)
            print(
                "OutboxProcessor: ✅ Successfully processed & deleted [\(event.eventType.displayName)] - EventID: \(event.id) | EntityID: \(event.entityID) | Duration: \(String(format: "%.3f", eventDuration))s"
            )

        } catch {
            let errorMessage = error.localizedDescription
            print(
                "OutboxProcessor: ❌ Failed to process [\(event.eventType.displayName)] - EventID: \(event.id) | EntityID: \(event.entityID) | Error: \(errorMessage)"
            )

            try? await outboxRepository.markAsFailed(event.id, error: errorMessage)
        }
    }

    // MARK: - Event Type Handlers

    private func processProgressEntry(_ event: OutboxEvent) async throws {
        // DIAGNOSTIC: Check authentication state
        print("OutboxProcessor: 🔍 DIAGNOSTIC - Processing progress entry")
        print("  - Event ID: \(event.id)")
        print("  - Entity ID: \(event.entityID)")
        print("  - Event User ID: \(event.userID)")
        print(
            "  - AuthManager currentUserProfileID: \(authManager.currentUserProfileID?.uuidString ?? "nil")"
        )

        guard let userID = authManager.currentUserProfileID?.uuidString else {
            print("OutboxProcessor: ❌ AUTHENTICATION FAILED - currentUserProfileID is nil")
            print("  - This means authManager lost authentication state")
            print("  - Check if user is logged out or session expired")
            throw OutboxProcessorError.userNotAuthenticated
        }

        print("OutboxProcessor: ✅ Authentication OK - User ID: \(userID)")

        // Fetch the progress entry from local storage
        print("OutboxProcessor: 📥 Fetching progress entry from local storage...")
        let entries = try await progressRepository.fetchLocal(
            forUserID: userID,
            type: nil,
            syncStatus: nil,
            limit: nil  // Fetch ALL entries to ensure we can find any entity ID
        )

        print("OutboxProcessor: Found \(entries.count) total progress entries in local storage")

        guard let progressEntry = entries.first(where: { $0.id == event.entityID }) else {
            print(
                "OutboxProcessor: ❌ ENTITY NOT FOUND - Could not find progress entry with ID: \(event.entityID)"
            )
            print("  - Available entry IDs: \(entries.prefix(10).map { $0.id })")
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print("OutboxProcessor: ✅ Found progress entry: \(progressEntry.type.rawValue)")
        print("  - Quantity: \(progressEntry.quantity)")
        print("  - Date: \(progressEntry.date)")
        print("  - Time: \(progressEntry.time ?? "nil")")
        print("  - Backend ID: \(progressEntry.backendID ?? "nil")")
        print("  - Sync Status: \(progressEntry.syncStatus.rawValue)")
        print("OutboxProcessor: 🌐 Uploading progress entry to API...")

        // Combine date and time into a single timestamp
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents(
            [.year, .month, .day], from: progressEntry.date)

        var loggedAtDate = progressEntry.date
        if let time = progressEntry.time {
            let timeComponents = time.split(separator: ":").compactMap { Int($0) }
            if timeComponents.count >= 2 {
                var components = dateComponents
                components.hour = timeComponents[0]
                components.minute = timeComponents[1]
                components.second = timeComponents.count > 2 ? timeComponents[2] : 0
                if let combinedDate = calendar.date(from: components) {
                    loggedAtDate = combinedDate
                }
            }
        }

        // Upload to backend
        do {
            let backendEntry = try await progressRepository.logProgress(
                type: progressEntry.type,
                quantity: progressEntry.quantity,
                loggedAt: loggedAtDate,
                notes: progressEntry.notes
            )

            print("OutboxProcessor: ✅ API call succeeded!")
            print("  - Backend entry ID: \(backendEntry.backendID ?? "nil")")
            print("  - Backend created at: \(backendEntry.createdAt)")

            guard let backendID = backendEntry.backendID else {
                print(
                    "OutboxProcessor: ❌ MISSING BACKEND ID - API returned entry without backendID")
                print("  - Response: \(backendEntry)")
                throw OutboxProcessorError.missingBackendID
            }

            // Update local entry with backend ID
            print("OutboxProcessor: 💾 Updating local entry with backend ID...")
            try await progressRepository.updateBackendID(
                forLocalID: event.entityID,
                backendID: backendID,
                forUserID: userID
            )

            // Mark as synced
            print("OutboxProcessor: ✅ Marking entry as synced...")
            try await progressRepository.updateSyncStatus(
                forLocalID: event.entityID,
                status: .synced,
                forUserID: userID
            )

            print("OutboxProcessor: ✅✅✅ Progress entry FULLY SYNCED, backend ID: \(backendID)")
        } catch {
            print("OutboxProcessor: ❌ API CALL FAILED")
            print("  - Error type: \(type(of: error))")
            print("  - Error description: \(error.localizedDescription)")
            print("  - Full error: \(error)")
            throw error
        }
    }

    private func processPhysicalAttribute(_ event: OutboxEvent) async throws {
        guard let userID = authManager.currentUserProfileID else {
            throw OutboxProcessorError.userNotAuthenticated
        }

        // Fetch the physical attribute
        guard
            let sdAttribute = try await localHealthDataStore.fetchPhysicalAttribute(
                forLocalID: event.entityID, for: userID
            )
        else {
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print("OutboxProcessor: Uploading physical attribute: \(sdAttribute.type)")

        // Upload based on attribute type
        let backendID: String?
        switch sdAttribute.type {
        case .bodyMass:
            backendID = try await remoteDataSync.uploadBodyMass(
                kg: sdAttribute.value ?? 0,
                date: sdAttribute.createdAt,
                for: userID,
                localID: sdAttribute.id
            )
        case .bodyFatPercentage:
            backendID = try await remoteDataSync.uploadBodyFatPercentage(
                percentage: sdAttribute.value ?? 0,
                date: sdAttribute.createdAt,
                for: userID,
                localID: sdAttribute.id
            )
        case .bmi:
            backendID = try await remoteDataSync.uploadBMI(
                bmi: sdAttribute.value ?? 0,
                date: sdAttribute.createdAt,
                for: userID,
                localID: sdAttribute.id
            )
        case .height:
            // Height API not yet available
            print("OutboxProcessor: Skipping height sync (API not yet available)")
            return
        }

        // Update local entry with backend ID if received
        if let receivedBackendID = backendID {
            try await localHealthDataStore.updatePhysicalAttributeBackendID(
                forLocalID: event.entityID, newBackendID: receivedBackendID, for: userID
            )
            print("OutboxProcessor: ✅ Physical attribute synced, backend ID: \(receivedBackendID)")
        }
    }

    private func processActivitySnapshot(_ event: OutboxEvent) async throws {
        guard let userID = authManager.currentUserProfileID else {
            throw OutboxProcessorError.userNotAuthenticated
        }

        // Fetch the activity snapshot
        guard
            let activitySnapshot = try await activitySnapshotRepository.fetchActivitySnapshot(
                forLocalID: event.entityID, for: userID.uuidString
            )
        else {
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print("OutboxProcessor: Uploading activity snapshot")

        // Upload to backend
        let backendID = try await remoteDataSync.uploadActivitySnapshot(
            snapshot: activitySnapshot, for: userID
        )

        if let receivedBackendID = backendID {
            try await activitySnapshotRepository.updateActivitySnapshotBackendID(
                forLocalID: event.entityID, newBackendID: receivedBackendID, for: userID.uuidString
            )
            print("OutboxProcessor: ✅ Activity snapshot synced, backend ID: \(receivedBackendID)")
        }
    }

    private func processProfileMetadata(_ event: OutboxEvent) async throws {
        // TODO: Implement profile metadata sync
        print("OutboxProcessor: Profile metadata sync not yet implemented")
    }

    private func processProfilePhysical(_ event: OutboxEvent) async throws {
        // TODO: Implement physical profile sync
        print("OutboxProcessor: Physical profile sync not yet implemented")
    }

    private func processSleepSession(_ event: OutboxEvent) async throws {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw OutboxProcessorError.userNotAuthenticated
        }

        print(
            "OutboxProcessor: 💤 Processing [Sleep Session] - EventID: \(event.id) | EntityID: \(event.entityID)"
        )

        // Fetch the sleep session from local storage
        guard
            let sleepSession = try await sleepRepository.fetchSession(
                byID: event.entityID,
                forUserID: userID
            )
        else {
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print("OutboxProcessor: 📤 Uploading sleep session to /api/v1/sleep")
        print("  - Session ID: \(sleepSession.id)")
        print("  - Date: \(sleepSession.date)")
        print("  - Time: \(sleepSession.startTime) → \(sleepSession.endTime)")
        print(
            "  - Duration: \(sleepSession.timeInBedMinutes) min in bed, \(sleepSession.totalSleepMinutes) min sleep"
        )
        print("  - Efficiency: \(String(format: "%.1f", sleepSession.sleepEfficiency))%")
        print("  - Stages: \(sleepSession.stages?.count ?? 0)")
        print("  - Source: \(sleepSession.source ?? "manual")")

        // Convert domain model to API request
        let apiRequest = sleepSession.toAPIRequest()

        // Upload to backend
        do {
            let response = try await sleepAPIClient.postSleepSession(apiRequest)

            print("OutboxProcessor: ✅ Sleep session uploaded successfully")
            print("  - Backend ID: \(response.id)")
            print("  - Endpoint: POST /api/v1/sleep")

            // Update local session with backend ID and mark as synced
            try await sleepRepository.updateSyncStatus(
                forSessionID: event.entityID,
                syncStatus: .synced,
                backendID: response.id
            )

            print("OutboxProcessor: ✅ Sleep session \(event.entityID) marked as synced locally")

        } catch {
            // Check if it's a duplicate error (409 Conflict)
            if let sleepAPIError = error as? SleepAPIError,
                case .duplicateSession = sleepAPIError
            {
                print(
                    "OutboxProcessor: ⚠️ Sleep session is duplicate (409 Conflict) - marking as synced anyway"
                )

                // Mark as synced even though it's a duplicate
                try await sleepRepository.updateSyncStatus(
                    forSessionID: event.entityID,
                    syncStatus: .synced,
                    backendID: nil
                )

                return
            }

            // Re-throw other errors for retry logic
            throw error
        }
    }

    private func processMealLog(_ event: OutboxEvent) async throws {
        guard let userID = authManager.currentUserProfileID?.uuidString else {
            throw OutboxProcessorError.userNotAuthenticated
        }

        print(
            "OutboxProcessor: 🍽️ Processing [Meal Log] - EventID: \(event.id) | EntityID: \(event.entityID)"
        )

        // Check if this is a deletion operation
        var isDeleteOperation = false
        var deleteBackendID: String?

        if let metadata = event.metadata,
            case .generic(let dict) = metadata,
            let operation = dict["operation"],
            operation == "delete"
        {
            isDeleteOperation = true
            deleteBackendID = dict["backendID"]
        }

        if isDeleteOperation {
            // Handle deletion
            guard let backendID = deleteBackendID else {
                print("OutboxProcessor: ⚠️ Deletion event missing backendID")
                throw OutboxProcessorError.missingBackendID
            }

            print("OutboxProcessor: 🗑️ Deleting meal log from backend")
            print("  - Backend ID: \(backendID)")
            print("  - Endpoint: DELETE /api/v1/meal-logs/\(backendID)")

            do {
                try await nutritionAPIClient.deleteMealLog(backendID: backendID)
                print("OutboxProcessor: ✅ Meal log deleted from backend successfully")
            } catch {
                print("OutboxProcessor: ❌ Failed to delete meal log from backend: \(error)")
                // Don't throw - meal is already deleted locally, backend failure is acceptable
                print("OutboxProcessor: ℹ️ Local deletion already complete, ignoring backend error")
            }

            return
        }

        // Handle creation/update (existing logic)
        // Fetch the meal log from local storage
        guard
            let mealLog = try await mealLogRepository.fetchByID(
                event.entityID,
                forUserID: userID
            )
        else {
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print("OutboxProcessor: 📤 Uploading meal log to /api/v1/meal-logs/natural")
        print("  - Meal Log ID: \(mealLog.id)")
        print("  - Raw Input: \(mealLog.rawInput)")
        print("  - Meal Type: \(mealLog.mealType.rawValue)")
        print("  - Logged At: \(mealLog.loggedAt)")

        // Upload to backend
        do {
            let responseMealLog = try await nutritionAPIClient.submitMealLog(
                rawInput: mealLog.rawInput,
                mealType: mealLog.mealType.rawValue,
                loggedAt: mealLog.loggedAt,
                notes: mealLog.notes
            )

            print("OutboxProcessor: ✅ Meal log uploaded successfully")
            print("  - Backend ID: \(responseMealLog.backendID ?? "unknown")")
            print("  - Backend Status: \(responseMealLog.status.rawValue)")
            print("  - Endpoint: POST /api/v1/meal-logs/natural")

            // ✅ CRITICAL: Update local meal log with backend ID and STATUS
            // This immediately reflects backend state (processing → analyzing) without waiting for WebSocket
            if let backendID = responseMealLog.backendID {
                try await mealLogRepository.updateBackendID(
                    forLocalID: event.entityID,
                    backendID: backendID,
                    forUserID: userID
                )
            }

            // ✅ UPDATE STATUS: Sync backend status and data to local immediately
            // This provides instant UI feedback without waiting for WebSocket update
            try await mealLogRepository.updateStatus(
                forLocalID: event.entityID,
                status: responseMealLog.status,
                items: responseMealLog.items,
                totalCalories: responseMealLog.totalCalories,
                totalProteinG: responseMealLog.totalProteinG,
                totalCarbsG: responseMealLog.totalCarbsG,
                totalFatG: responseMealLog.totalFatG,
                totalFiberG: responseMealLog.totalFiberG,
                totalSugarG: responseMealLog.totalSugarG,
                errorMessage: responseMealLog.errorMessage,
                forUserID: userID
            )

            print(
                "OutboxProcessor: ✅ Meal log status updated to: \(responseMealLog.status.rawValue)")

            try await mealLogRepository.updateSyncStatus(
                forLocalID: event.entityID,
                syncStatus: .synced,
                forUserID: userID
            )

            print("OutboxProcessor: ✅ Meal log \(event.entityID) marked as synced locally")

        } catch {
            print("OutboxProcessor: ❌ Failed to upload meal log: \(error)")
            throw error
        }
    }

    private func processWorkout(_ event: OutboxEvent) async throws {
        print("OutboxProcessor: 🏋️ Processing workout event")
        print("  - EventID: \(event.id) | EntityID: \(event.entityID)")

        // 1. Fetch workout from local repository
        guard let workout = try await workoutRepository.fetchByID(event.entityID) else {
            print("OutboxProcessor: ❌ Workout not found for entity ID: \(event.entityID)")
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print(
            "OutboxProcessor: 📋 Fetched workout: \(workout.activityType.rawValue) at \(workout.startedAt)"
        )

        // 2. Convert to CreateWorkoutRequest DTO
        let request = CreateWorkoutRequest(
            activityType: workout.activityType,
            title: workout.title,
            notes: workout.notes,
            startedAt: workout.startedAt.toISO8601TimestampString(),
            endedAt: workout.endedAt?.toISO8601TimestampString(),
            durationMinutes: workout.durationMinutes,
            caloriesBurned: workout.caloriesBurned,
            distanceMeters: workout.distanceMeters,
            intensity: workout.intensity
        )

        // 3. Sync to backend
        let response = try await workoutAPIClient.createWorkout(request: request)

        print("OutboxProcessor: 🎉 Workout synced to backend with ID: \(response.id)")

        // 4. Update local workout with backend ID and mark as synced
        try await workoutRepository.updateSyncStatus(
            forID: event.entityID,
            syncStatus: .synced,
            backendID: response.id
        )

        print("OutboxProcessor: ✅ Updated local workout sync status")
    }

    private func processWorkoutTemplate(_ event: OutboxEvent) async throws {
        print("OutboxProcessor: 💪 Processing workout template event")
        print("  - EventID: \(event.id) | EntityID: \(event.entityID)")

        // 1. Fetch template from local repository via fetchByID (returns domain model)
        guard let template = try await workoutTemplateRepository.fetchByID(event.entityID) else {
            print("OutboxProcessor: ❌ Workout template not found for entity ID: \(event.entityID)")
            throw OutboxProcessorError.entityNotFound(event.entityID)
        }

        print(
            "OutboxProcessor: 📋 Fetched template: \(template.name) with \(template.exerciseCount) exercises"
        )

        // 2. Convert to CreateWorkoutTemplateRequest DTO
        let request = CreateWorkoutTemplateRequest(
            name: template.name,
            description: template.description,
            category: template.category,
            difficultyLevel: template.difficultyLevel?.rawValue,
            estimatedDurationMinutes: template.estimatedDurationMinutes,
            exercises: template.exercises.map { exercise in
                TemplateExerciseRequest(
                    exerciseId: exercise.exerciseID?.uuidString,
                    userExerciseId: exercise.userExerciseID?.uuidString,
                    orderIndex: exercise.orderIndex,
                    technique: exercise.technique,
                    techniqueDetails: exercise.techniqueDetails,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weightKg: exercise.weightKg,
                    durationSeconds: exercise.durationSeconds,
                    restSeconds: exercise.restSeconds,
                    rir: exercise.rir,
                    tempo: exercise.tempo,
                    notes: exercise.notes
                )
            }
        )

        // 3. Sync to backend
        let response = try await workoutTemplateAPIClient.createTemplate(request: request)

        print("OutboxProcessor: 🎉 Workout template synced to backend with ID: \(response.id)")

        // 4. Update local template with backend ID and mark as synced
        var updatedTemplate = template
        updatedTemplate.backendID = response.id.uuidString
        updatedTemplate.syncStatus = .synced
        _ = try await workoutTemplateRepository.update(template: updatedTemplate)

        print("OutboxProcessor: ✅ Updated local workout template sync status")
    }

    // MARK: - Cleanup Loop

    private func cleanupLoop() async {
        print("OutboxProcessor: Cleanup loop started")

        while !Task.isCancelled && isProcessing {
            do {
                // Wait before cleanup
                try await Task.sleep(nanoseconds: UInt64(cleanupInterval * 1_000_000_000))

                guard !Task.isCancelled else { break }

                // Delete ALL completed events (safety net - they should already be deleted immediately)
                // This catches any orphaned completed events that weren't deleted during processing
                let deletedCount = try await outboxRepository.deleteCompletedEvents(
                    olderThan: Date())  // Delete all completed events regardless of age

                if deletedCount > 0 {
                    print(
                        "OutboxProcessor: 🗑️ Safety cleanup: deleted \(deletedCount) orphaned completed events"
                    )
                }

                // Check for stale events
                let staleEvents = try await outboxRepository.getStaleEvents(forUserID: nil)
                if !staleEvents.isEmpty {
                    print(
                        "OutboxProcessor: ⚠️ Found \(staleEvents.count) stale events (pending > 5 minutes)"
                    )
                }

            } catch is CancellationError {
                print("OutboxProcessor: Cleanup loop cancelled")
                break
            } catch {
                print("OutboxProcessor: Error in cleanup loop: \(error.localizedDescription)")
                // Continue cleanup despite errors
            }
        }

        print("OutboxProcessor: Cleanup loop stopped")
    }
}

// MARK: - Errors

enum OutboxProcessorError: Error, LocalizedError {
    case invalidEventType(String)
    case unsupportedEventType(String)
    case userNotAuthenticated
    case entityNotFound(UUID)
    case missingBackendID
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .invalidEventType(let type):
            return "Invalid event type: \(type)"
        case .unsupportedEventType(let type):
            return "Unsupported event type for this processor: \(type)"
        case .userNotAuthenticated:
            return "User must be authenticated to process events"
        case .entityNotFound(let id):
            return "Entity not found: \(id)"
        case .missingBackendID:
            return "Backend ID missing in API response"
        case .notImplemented(let feature):
            return "Feature not yet implemented: \(feature)"
        }
    }
}
