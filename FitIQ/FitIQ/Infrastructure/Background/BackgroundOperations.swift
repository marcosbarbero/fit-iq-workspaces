//
//  BackgroundOperations.swift
//  FitIQ
//
//  Created by Marcos Barbero on 12/10/2025.
//

import Foundation
import BackgroundTasks
import os.lock

public let NotificationCheckTaskID = "com.marcosbarbero.HealthRestart.notificationcheck"
// Made public for use by BackgroundSyncManager and ScheduleDailyEnergyProcessingUseCase
public let HealthKitSyncTaskID = "com.marcosbarbero.FitIQ.healthkitsync"
// Original DailyHealthKitProcessingTaskID (used for more general daily processing if needed)
public let DailyHealthKitProcessingTaskID = "com.marcosbarbero.FitIQ.dailyEnergyProcessing"
// NEW: Dedicated Task ID for consolidated, finalized daily data processing (previous day)
public let ConsolidatedDailyHealthKitProcessingTaskID = "com.marcosbarbero.FitIQ.consolidatedDailyProcessing"


final class BackgroundOperations: BackgroundOperationsProtocol {
    
    // NEW: Static set to track registered task identifiers
    private static var registeredTaskIdentifiers: Set<String> = []
    private static let lock = OSAllocatedUnfairLock() // For thread-safe access to registeredTaskIdentifiers

    // Corrected registerTask: Added logging for the success/failure of BGTaskScheduler.shared.register
    func registerTask(forTaskWithIdentifier identifier: String, handler: @escaping (BGTask) -> Void) {
        // Use a lock for thread-safe access to the static set
        BackgroundOperations.lock.lock()
        defer { BackgroundOperations.lock.unlock() }

        // NEW: Check if the task is already registered
        if BackgroundOperations.registeredTaskIdentifiers.contains(identifier) {
            print("BackgroundOperations: Task '\(identifier)' handler already registered. Skipping re-registration.")
            return // Prevent re-registration
        }

        // Register the task handler with the system. This should only be called once per app launch.
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil // Use nil for queue, defaults to a system-provided background queue
        ) { task in
            // The handler closure is executed by BGTaskScheduler when the task is launched.
            handler(task)
            print("BackgroundOperations: Registered task handler for '\(identifier)' executed.")
        }
        
        if success {
            print("BackgroundOperations: Task '\(identifier)' registered with BGTaskScheduler SUCCESSFULLY.")
            // NEW: Add the identifier to our tracking set upon successful registration
            BackgroundOperations.registeredTaskIdentifiers.insert(identifier)
        } else {
            print("BackgroundOperations: FAILED to register task '\(identifier)' with BGTaskScheduler. Check Info.plist and capabilities.")
        }
    }
    
    // Updated scheduleTask to be more flexible with task request properties.
    func scheduleTask(forTaskWithIdentifier identifier: String, earliestBeginDate: Date?, requiresNetworkConnectivity: Bool, requiresExternalPower: Bool) throws {
        // Cancel any pending task with the same identifier before submitting a new one.
        // This ensures only one instance of a specific task type is scheduled at a time.
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = requiresExternalPower
            
        try BGTaskScheduler.shared.submit(request)
        print("BackgroundOperations: Scheduled background task '\(identifier)' with earliestBeginDate: \(earliestBeginDate?.description ?? "now"). Network: \(requiresNetworkConnectivity), Power: \(requiresExternalPower).")
    }
}
