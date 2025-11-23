//
//  BackgroundSyncManager.swift
//  FitIQ
//
//  Created by Marcos Barbero on 15/10/2025.
//

import BackgroundTasks
import Foundation
import HealthKit
import UIKit  // Added for UIApplication.shared.applicationState

public final class BackgroundSyncManager: BackgroundSyncManagerProtocol {
    private let healthDataSyncService: HealthDataSyncOrchestrator
    private let backgroundOperations: BackgroundOperationsProtocol
    private var healthRepository: HealthRepositoryProtocol
    private let processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol
    private let processConsolidatedDailyHealthDataUseCase:
        ProcessConsolidatedDailyHealthDataUseCaseProtocol
    private let authManager: AuthManager

    private static let pendingHealthKitSyncTypesKey = "pendingHealthKitSyncTypes"

    // Property to manage debouncing of background task scheduling
    private var backgroundTaskScheduleDebounceTask: Task<Void, Never>?
    // Dedicated property to manage debouncing of foreground syncs
    private var foregroundSyncDebounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 1.0  // 1 second debounce window

    init(
        healthDataSyncService: HealthDataSyncOrchestrator,
        backgroundOperations: BackgroundOperationsProtocol,
        healthRepository: HealthRepositoryProtocol,
        processDailyHealthDataUseCase: ProcessDailyHealthDataUseCaseProtocol,
        processConsolidatedDailyHealthDataUseCase:
            ProcessConsolidatedDailyHealthDataUseCaseProtocol,
        authManager: AuthManager
    ) {
        self.healthDataSyncService = healthDataSyncService
        self.backgroundOperations = backgroundOperations
        self.healthRepository = healthRepository
        self.processDailyHealthDataUseCase = processDailyHealthDataUseCase
        self.processConsolidatedDailyHealthDataUseCase = processConsolidatedDailyHealthDataUseCase
        self.authManager = authManager
    }

    public func registerBackgroundTasks() {
        print("BackgroundSyncManager: Registering all background tasks.")

        self.registerHealthKitSyncTask()
        self.registerConsolidatedDailyHealthKitProcessingTask()  // NEW: Call the new registration method
        self.setOnDataUpdateHandler()
    }

    fileprivate func registerHealthKitSyncTask() {
        backgroundOperations.registerTask(forTaskWithIdentifier: HealthKitSyncTaskID) {
            [weak self] task in
            guard let self = self else {
                task.setTaskCompleted(success: false)
                print("BGTask: Self was nil when handling \(HealthKitSyncTaskID).")
                return
            }

            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                print(
                    "BGTask: Expected BGProcessingTask but received \(type(of: task)) for \(HealthKitSyncTaskID)."
                )
                return
            }

            print("BGTask: \(HealthKitSyncTaskID) received for processing.")
            var success = true

            processingTask.expirationHandler = {
                print(
                    "BGTask: \(HealthKitSyncTaskID) expiration handler called. Marking as incomplete."
                )
                processingTask.setTaskCompleted(success: false)
            }

            Task {
                do {
                    print(
                        "BGTask: HealthKit sync task starting execution for \(HealthKitSyncTaskID)..."
                    )
                    let userDefaults = UserDefaults.standard
                    let pendingTypes =
                        userDefaults.array(
                            forKey: BackgroundSyncManager.pendingHealthKitSyncTypesKey) as? [String]
                        ?? []
                    if !pendingTypes.isEmpty {
                        print(
                            "BGTask: Found pending HealthKit types: \(Set(pendingTypes).joined(separator: ", ")). Triggering comprehensive sync."
                        )
                    } else {
                        print(
                            "BGTask: No pending HealthKit types found. Triggering comprehensive sync anyway to ensure up-to-date snapshot."
                        )
                    }

                    // This task will continue to use `syncAllDailyActivityData` for general, incremental daily updates
                    if let userID = self.authManager.currentUserProfileID {
                        self.healthDataSyncService.configure(withUserProfileID: userID)
                        await self.healthDataSyncService.syncAllDailyActivityData()
                        print(
                            "BGTask: HealthKit sync task completed comprehensive daily sync for user \(userID)."
                        )
                    } else {
                        print(
                            "BGTask: Cannot perform HealthKit sync in background task, user ID not available from AuthManager."
                        )
                        success = false
                    }

                    userDefaults.set([], forKey: BackgroundSyncManager.pendingHealthKitSyncTypesKey)  // Clear all pending types after comprehensive sync
                    print("BGTask: Successfully cleared pending types after comprehensive sync.")

                    try Task.checkCancellation()
                } catch is CancellationError {
                    print(
                        "BGTask: HealthKit sync task was cancelled (expiration handler or system reason)."
                    )
                    success = false
                } catch {
                    print(
                        "BGTask: Error processing HealthKit sync background task: \(error.localizedDescription)"
                    )
                    success = false
                }
                processingTask.setTaskCompleted(success: success)
                print("BGTask: \(HealthKitSyncTaskID) completed with success: \(success)")
            }
        }
    }

    // NEW: Renamed and updated method to register the consolidated daily processing task
    fileprivate func registerConsolidatedDailyHealthKitProcessingTask() {
        self.backgroundOperations.registerTask(
            forTaskWithIdentifier: ConsolidatedDailyHealthKitProcessingTaskID
        ) { [weak self] task in
            guard let self = self else {
                task.setTaskCompleted(success: false)
                print(
                    "BGTask: Self was nil when handling \(ConsolidatedDailyHealthKitProcessingTaskID)."
                )
                return
            }

            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                print(
                    "BGTask: Expected BGProcessingTask but received \(type(of: task)) for \(ConsolidatedDailyHealthKitProcessingTaskID)."
                )
                return
            }

            print(
                "BGTask: \(ConsolidatedDailyHealthKitProcessingTaskID) received for consolidated daily processing (previous day)."
            )
            var success = true
            processingTask.expirationHandler = {
                print(
                    "BGTask: \(ConsolidatedDailyHealthKitProcessingTaskID) expiration handler called. Marking as incomplete."
                )
                processingTask.setTaskCompleted(success: false)
            }

            Task {
                do {
                    print(
                        "BGTask: Delegating consolidated daily processing to ProcessConsolidatedDailyHealthDataUseCase..."
                    )
                    // This task now explicitly calls the new use case for finalizing previous day's data
                    try await self.processConsolidatedDailyHealthDataUseCase.execute()
                    print(
                        "BGTask: Consolidated daily health data processing via use case completed.")

                    try Task.checkCancellation()
                } catch is CancellationError {
                    print("BGTask: Consolidated daily energy processing task was cancelled.")
                    success = false
                } catch {
                    print(
                        "BGTask: Error during consolidated daily energy processing (via use case): \(error.localizedDescription)"
                    )
                    success = false
                }
                processingTask.setTaskCompleted(success: success)
                print(
                    "BGTask: \(ConsolidatedDailyHealthKitProcessingTaskID) completed with success: \(success)"
                )
            }
        }
    }

    fileprivate func setOnDataUpdateHandler() {
        self.healthRepository.onDataUpdate = { [weak self] typeIdentifier in
            guard let self = self else { return }

            // This part runs on a HealthKit background queue.
            // ONLY perform thread-safe operations here.

            let userDefaults = UserDefaults.standard
            var pendingTypes =
                userDefaults.array(forKey: BackgroundSyncManager.pendingHealthKitSyncTypesKey)
                as? [String] ?? []

            if !pendingTypes.contains(typeIdentifier.rawValue) {
                pendingTypes.append(typeIdentifier.rawValue)
                userDefaults.set(
                    pendingTypes, forKey: BackgroundSyncManager.pendingHealthKitSyncTypesKey)
                print(
                    "BackgroundSyncManager: Added \(typeIdentifier.rawValue) to pending HealthKit sync types. Current pending: \(pendingTypes.joined(separator: ", "))"
                )
            } else {
                print(
                    "BackgroundSyncManager: \(typeIdentifier.rawValue) is already in pending HealthKit sync types. Not adding again."
                )
            }

            // Always schedule a background task (debounced) regardless of app state.
            // This ensures data is eventually synced even if the app is killed or in the background.
            self.backgroundTaskScheduleDebounceTask?.cancel()
            print(
                "BackgroundSyncManager: Previous background task debounce cancelled (if any). Starting new debounce for \(self.debounceInterval) seconds to schedule BGTask."
            )

            self.backgroundTaskScheduleDebounceTask = Task {
                do {
                    try await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
                    try Task.checkCancellation()

                    print(
                        "BackgroundSyncManager: Debounce finished. Attempting to schedule HealthKitSyncTask \(HealthKitSyncTaskID)."
                    )
                    try self.backgroundOperations.scheduleTask(
                        forTaskWithIdentifier: HealthKitSyncTaskID,
                        earliestBeginDate: Date(),
                        requiresNetworkConnectivity: true,
                        requiresExternalPower: false
                    )
                    print(
                        "BackgroundSyncManager: Successfully scheduled (debounced) HealthKitSyncTask \(HealthKitSyncTaskID)."
                    )
                } catch is CancellationError {
                    print(
                        "BackgroundSyncManager: Debounced scheduling for HealthKitSyncTask was cancelled during sleep."
                    )
                } catch {
                    print(
                        "BackgroundSyncManager: Error (debounced) scheduling HealthKitSyncTask: \(error.localizedDescription)"
                    )
                }
            }

            // Handle immediate foreground sync on the main thread, with its own debounce.
            // Dispatch to the main queue for UI-related checks and foreground operations.
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState == .active {
                    print(
                        "BackgroundSyncManager: App is active. Scheduling debounced foreground sync."
                    )

                    self.foregroundSyncDebounceTask?.cancel()  // Cancel previous foreground debounce task
                    // Launch a new Task on the main actor to perform the debounced foreground sync
                    self.foregroundSyncDebounceTask = Task { @MainActor in
                        do {
                            try await Task.sleep(
                                nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
                            try Task.checkCancellation()

                            print(
                                "BackgroundSyncManager: Debounce finished for foreground sync. Performing immediate foreground sync."
                            )
                            // Ensure HealthDataSyncService is configured for the current user
                            if let userID = self.authManager.currentUserProfileID {
                                self.healthDataSyncService.configure(withUserProfileID: userID)
                                await self.healthDataSyncService.syncAllDailyActivityData()
                            } else {
                                print(
                                    "BackgroundSyncManager: Cannot perform foreground sync, user ID not available from AuthManager."
                                )
                            }
                        } catch is CancellationError {
                            print(
                                "BackgroundSyncManager: Debounced foreground sync was cancelled during sleep."
                            )
                        } catch {
                            print(
                                "BackgroundSyncManager: Error during debounced foreground sync: \(error.localizedDescription)"
                            )
                        }
                    }
                }
            }
        }
    }

    /// Initiates observation of relevant HealthKit data types.
    /// Note: The initial comprehensive sync is now triggered by AppDependencies.
    public func startHealthKitObservations() async throws {
        print("BackgroundSyncManager: Starting HealthKit observations...")
        let quantityTypesToObserve: [HKQuantityTypeIdentifier] = [
            .bodyMass, .height, .stepCount, .distanceWalkingRunning,
            .basalEnergyBurned,
            .activeEnergyBurned,
            .heartRate,
        ]

        await withTaskGroup(of: Void.self) { group in
            // Observe quantity types
            for typeIdentifier in quantityTypesToObserve {
                group.addTask {
                    guard let type = HKObjectType.quantityType(forIdentifier: typeIdentifier) else {
                        print(
                            "BackgroundSyncManager: Invalid quantity type identifier: \(typeIdentifier.rawValue)."
                        )
                        return
                    }
                    do {
                        try await self.healthRepository.startObserving(for: type)
                    } catch let error as HealthKitError {
                        print(
                            "BackgroundSyncManager: Failed to start observing \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )
                    } catch {
                        print(
                            "BackgroundSyncManager: An unexpected error occurred while observing \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )
                    }
                }
            }

            // Observe sleep analysis (category type)
            group.addTask {
                guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
                else {
                    print("BackgroundSyncManager: Failed to get sleep analysis type.")
                    return
                }
                do {
                    try await self.healthRepository.startObserving(for: sleepType)
                    print("BackgroundSyncManager: ✅ Started observing sleep analysis")
                } catch let error as HealthKitError {
                    print(
                        "BackgroundSyncManager: Failed to start observing sleep analysis: \(error.localizedDescription)"
                    )
                } catch {
                    print(
                        "BackgroundSyncManager: An unexpected error occurred while observing sleep analysis: \(error.localizedDescription)"
                    )
                }
            }
        }

        print(
            "BackgroundSyncManager: HealthKit observations initiation complete (some might have been skipped if unauthorized)."
        )
    }
}
