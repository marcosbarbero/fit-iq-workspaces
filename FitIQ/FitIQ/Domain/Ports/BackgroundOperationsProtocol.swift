//
//  BackgroundOperationsProtocol.swift
//  FitIQ
//
//  Created by Marcos Barbero on 12/10/2025.
//

import Foundation
import BackgroundTasks

public protocol BackgroundOperationsProtocol {
    /// Registers a background task with the system. The provided handler closure will be executed when the task runs.
    /// This should be called once at app launch for each task identifier.
    /// - Parameters:
    ///   - identifier: The unique identifier for the background task.
    ///   - handler: The closure to execute when the background task is launched by the system.
    func registerTask(forTaskWithIdentifier identifier: String, handler: @escaping (BGTask) -> Void)
    
    /// Schedules a background task to be performed by the system.
    /// - Parameters:
    ///   - identifier: The unique identifier for the background task.
    ///   - earliestBeginDate: The earliest date the system can begin the task. `nil` means as soon as possible.
    ///   - requiresNetworkConnectivity: A boolean indicating if network access is required for the task.
    ///   - requiresExternalPower: A boolean indicating if external power is required for the task.
    func scheduleTask(forTaskWithIdentifier identifier: String, earliestBeginDate: Date?, requiresNetworkConnectivity: Bool, requiresExternalPower: Bool) throws
}

