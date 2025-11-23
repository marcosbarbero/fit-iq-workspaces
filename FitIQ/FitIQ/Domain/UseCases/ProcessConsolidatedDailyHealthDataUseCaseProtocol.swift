// Domain/Protocols/ProcessConsolidatedDailyHealthDataUseCaseProtocol.swift
import Foundation

/// Defines the use case for processing and finalizing a *full day's* HealthKit data.
/// This is intended for scheduled tasks that run after midnight to ensure complete data
/// for the entire preceding day.
public protocol ProcessConsolidatedDailyHealthDataUseCaseProtocol {
    /// Executes the consolidated daily processing logic for HealthKit data for a previous day.
    func execute() async throws
}
