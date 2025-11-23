//
//  HealthRepositoryProtocol.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import HealthKit

protocol HealthRepositoryProtocol {
    // This closure will be called when an observer query detects new data.
    // The `HealthDataSyncService` can set this closure to call its `processNewHealthData` method.
    var onDataUpdate: ((HKQuantityTypeIdentifier) -> Void)? { get set }

    func isHealthDataAvailable() -> Bool

    func requestAuthorization(read: Set<HKObjectType>, share: Set<HKSampleType>) async throws

    /// Fetches the latest quantity sample for a given type identifier and unit.
    /// - Parameters:
    ///   - typeIdentifier: The `HKQuantityTypeIdentifier` of the sample to fetch.
    ///   - unit: The `HKUnit` to convert the quantity value to.
    /// - Returns: A tuple containing the `value` (Double) and `date` (Date) of the latest sample, or `nil` if no data is found.
    func fetchLatestQuantitySample(for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit)
        async throws -> (value: Double, date: Date)?

    /// Fetches quantity samples for a given type identifier, unit, and optional predicate.
    /// - Parameters:
    ///   - typeIdentifier: The `HKQuantityTypeIdentifier` of the samples to fetch.
    ///   - unit: The `HKUnit` to convert the quantity values to.
    ///   - predicateProvider: A `@Sendable` closure that returns an optional `NSPredicate` to filter the samples. The predicate will be evaluated within the adapter's context.
    ///   - limit: An optional maximum number of samples to return.
    /// - Returns: An array of tuples, each containing a `value` (Double) and `date` (Date) of a sample.
    func fetchQuantitySamples(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit,
        predicateProvider: (() -> NSPredicate?)?, limit: Int?
    ) async throws -> [(value: Double, date: Date)]

    /// Fetches the sum of quantity samples for a given type identifier within a specified date range.
    /// - Parameters:
    ///   - typeIdentifier: The `HKQuantityTypeIdentifier` of the samples to sum.
    ///   - unit: The `HKUnit` to convert the quantity values to before summing.
    ///   - startDate: The start date of the period to query.
    ///   - endDate: The end date of the period to query.
    /// - Returns: The cumulative sum of the quantity samples as a `Double`, or `nil` if no data is found.
    func fetchSumOfQuantitySamples(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date,
        to endDate: Date
    ) async throws -> Double?

    /// Fetches the average of quantity samples for a given type identifier within a specified date range.
    /// - Parameters:
    ///   - typeIdentifier: The `HKQuantityTypeIdentifier` of the samples to average.
    ///   - unit: The `HKUnit` to convert the quantity values to before averaging.
    ///   - startDate: The start date of the period to query.
    ///   - endDate: The end date of the period to query.
    /// - Returns: An average (mean) of the quantity samples as a `Double`, or `nil` if no data is found.
    func fetchAverageQuantitySample(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date,
        to endDate: Date
    ) async throws -> Double?

    /// Fetches hourly statistics for a given quantity type within a date range.
    /// - Parameters:
    ///   - typeIdentifier: The `HKQuantityTypeIdentifier` of the samples to aggregate.
    ///   - unit: The `HKUnit` to convert the quantity values to.
    ///   - startDate: The start date of the period to query.
    ///   - endDate: The end date of the period to query.
    /// - Returns: A dictionary mapping hour start dates to step counts for that hour.
    func fetchHourlyStatistics(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date,
        to endDate: Date
    ) async throws -> [Date: Int]

    /// Starts observing changes for a specific HealthKit object type in the background.
    /// When changes occur, the system will notify the app. The actual fetching of data
    /// will then be triggered by an `HKObserverQuery` handler (to be implemented in the adapter).
    /// - Parameter type: The `HKObjectType` to observe.
    func startObserving(for type: HKObjectType) async throws

    /// Stops observing changes for a specific HealthKit object type.
    /// - Parameter type: The `HKObjectType` to stop observing.
    func stopObserving(for type: HKObjectType) async throws

    /// Fetches the user's date of birth from HealthKit.
    /// - Returns: The user's date of birth, or `nil` if not available.
    func fetchDateOfBirth() async throws -> Date?

    /// Fetches the user's biological sex from HealthKit.
    /// - Returns: The user's biological sex as an `HKBiologicalSex` enum, or `nil` if not available.
    func fetchBiologicalSex() async throws -> HKBiologicalSex?

    /// Saves a quantity sample to HealthKit.
    /// - Parameters:
    ///   - value: The double value of the quantity.
    ///   - unit: The HKUnit for the quantity.
    ///   - typeIdentifier: The HKQuantityTypeIdentifier for the sample.
    ///   - date: The date for the sample.
    func saveQuantitySample(
        value: Double, unit: HKUnit, typeIdentifier: HKQuantityTypeIdentifier, date: Date)
        async throws

    /// Saves a category sample to HealthKit (for mood/state of mind tracking).
    /// - Parameters:
    ///   - value: The integer value for the category (for mood: 1-10 scale maps to HKCategoryValue).
    ///   - typeIdentifier: The HKCategoryTypeIdentifier for the sample.
    ///   - date: The date for the sample.
    ///   - metadata: Optional metadata dictionary for additional context (e.g., notes).
    func saveCategorySample(
        value: Int, typeIdentifier: HKCategoryTypeIdentifier, date: Date, metadata: [String: Any]?)
        async throws

    /// Fetches workout samples from HealthKit within a specified date range.
    /// - Parameters:
    ///   - startDate: The start date of the period to query.
    ///   - endDate: The end date of the period to query.
    /// - Returns: An array of `HKWorkout` objects.
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout]

    /// Fetch workout effort score for a specific workout (iOS 18+)
    /// - Parameter workout: The workout to fetch effort score for
    /// - Returns: The effort score (1-10 scale) if available, nil otherwise
    func fetchWorkoutEffortScore(for workout: HKWorkout) async throws -> Int?

    /// Check authorization status for a specific HealthKit type
    /// - Parameter type: The HealthKit object type to check
    /// - Returns: The authorization status
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    
    /// Saves a workout to HealthKit.
    /// - Parameters:
    ///   - activityType: The workout activity type (HKWorkoutActivityType raw value).
    ///   - startDate: When the workout started.
    ///   - endDate: When the workout ended.
    ///   - totalEnergyBurned: Optional total energy burned in calories.
    ///   - totalDistance: Optional total distance in meters.
    ///   - metadata: Optional metadata dictionary.
    func saveWorkout(
        activityType: Int,
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double?,
        totalDistance: Double?,
        metadata: [String: Any]?
    ) async throws
}
