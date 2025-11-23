//
//  ProcessDailyHealthDataUseCaseProtocol.swift
//  FitIQ
//
//  Created by Marcos Barbero on 16/10/2025.
//

import Foundation

/// Defines the use case for processing daily HealthKit data, such as calculating summaries.
public protocol ProcessDailyHealthDataUseCaseProtocol {
    /// Executes the daily processing logic for HealthKit data.
    /// This typically involves fetching and synchronizing daily summaries for various types.
    func execute() async throws
}

