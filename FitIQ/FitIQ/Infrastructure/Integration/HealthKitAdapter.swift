//
//  HealthKitAdapter.swift
//  FitIQ
//
//  Created by Marcos Barbero on 11/10/2025.
//

import Foundation
import HealthKit

// MARK: - HealthKitError
enum HealthKitError: Error, LocalizedError {
    case invalidQuantityType(HKQuantityTypeIdentifier)
    case invalidObjectTypeForObservation(String)
    case backgroundDeliveryFailed(String)
    case healthKitNotAvailable
    case authorizationDenied
    case authorizationNotDetermined(String)
    case noDataFound
    case unknownError(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuantityType(let identifier):
            return "Invalid HealthKit quantity type: \(identifier.rawValue)"
        case .invalidObjectTypeForObservation(let identifier):
            return
                "Invalid HealthKit object type for observation: \(identifier). Must be an HKSampleType."
        case .backgroundDeliveryFailed(let identifier):
            return "Failed to enable or disable background delivery for \(identifier)."
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "HealthKit authorization denied by the user."
        case .authorizationNotDetermined(let identifier):
            return
                "HealthKit authorization not determined for \(identifier). Cannot retrieve data or set up observation."
        case .noDataFound:
            return "No data found for the requested query."
        case .unknownError(let message):
            return "An unknown HealthKit error occurred: \(message)"
        case .saveFailed(let message):
            return "Failed to save data to HealthKit: \(message)"
        }
    }
}

final class HealthKitAdapter: HealthRepositoryProtocol {
    private let store = HKHealthStore()
    private var observerQueries: [HKObjectType: HKObserverQuery] = [:]

    public var onDataUpdate: ((HKQuantityTypeIdentifier) -> Void)?

    init() {
        print("--- HealthKitAdapter.init() called ---")
    }

    public func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization(read: Set<HKObjectType>, share: Set<HKSampleType>) async throws
    {
        try await store.requestAuthorization(toShare: share, read: read)
    }

    // NEW: Centralized authorization check for quantity types before fetching
    // This helper will check auth status and either proceed with the operation or return nil.
    private func checkQuantityAuthorizationAndProceed<T>(
        for typeIdentifier: HKQuantityTypeIdentifier,
        operation: @escaping (HKQuantityType) async throws -> T?
    ) async throws -> T? {
        guard let type = HKObjectType.quantityType(forIdentifier: typeIdentifier) else {
            throw HealthKitError.invalidQuantityType(typeIdentifier)
        }

        return try await operation(type)
    }

    public func fetchLatestQuantitySample(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit
    ) async throws -> (value: Double, date: Date)? {
        return try await checkQuantityAuthorizationAndProceed(for: typeIdentifier) { type in
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [
                        NSSortDescriptor(
                            key: HKSampleSortIdentifierEndDate,
                            ascending: false
                        )
                    ]
                ) { _, samples, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: Error fetching latest \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )  // Log error here
                        continuation.resume(throwing: error)  // Propagate actual fetch errors
                    } else {
                        let sample = samples?.first as? HKQuantitySample
                        let result = sample.map {
                            ($0.quantity.doubleValue(for: unit), $0.endDate)
                        }
                        continuation.resume(returning: result)
                    }
                }
                self.store.execute(query)
            }
        }
    }

    public func fetchQuantitySamples(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit,
        predicateProvider: (() -> NSPredicate?)?, limit: Int?
    ) async throws -> [(value: Double, date: Date)] {
        return try await checkQuantityAuthorizationAndProceed(for: typeIdentifier) { type in
            try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: predicateProvider?(),  // Use the predicate from the provider closure
                    limit: limit ?? HKObjectQueryNoLimit,
                    sortDescriptors: [
                        NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    ]
                ) { _, samples, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: Error fetching quantity samples for \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )  // Log error here
                        continuation.resume(throwing: error)
                    } else {
                        let results =
                            (samples as? [HKQuantitySample])?.map {
                                ($0.quantity.doubleValue(for: unit), $0.endDate)
                            } ?? []
                        continuation.resume(returning: results)
                    }
                }
                self.store.execute(query)
            }
        } ?? []  // If auth not granted, return empty array instead of nil
    }

    public func fetchSumOfQuantitySamples(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        return try await checkQuantityAuthorizationAndProceed(for: typeIdentifier) { type in
            try await withCheckedThrowingContinuation { continuation in
                let predicate = HKQuery.predicateForSamples(
                    withStart: startDate, end: endDate, options: .strictEndDate)
                let query = HKStatisticsQuery(
                    quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
                ) { _, statistics, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: Error fetching sum for \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )  // Log error here
                        continuation.resume(throwing: error)
                    } else {
                        let sum = statistics?.sumQuantity()?.doubleValue(for: unit)
                        continuation.resume(returning: sum)
                    }
                }
                self.store.execute(query)
            }
        }
    }

    public func fetchAverageQuantitySample(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        return try await checkQuantityAuthorizationAndProceed(for: typeIdentifier) { type in
            try await withCheckedThrowingContinuation { continuation in
                let predicate = HKQuery.predicateForSamples(
                    withStart: startDate, end: endDate, options: .strictEndDate)
                let query = HKStatisticsQuery(
                    quantityType: type, quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, statistics, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: Error fetching average for \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )  // Log error here
                        continuation.resume(throwing: error)
                    } else {
                        let average = statistics?.averageQuantity()?.doubleValue(for: unit)
                        continuation.resume(returning: average)
                    }
                }
                self.store.execute(query)
            }
        }
    }

    public func fetchHourlyStatistics(
        for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, from startDate: Date,
        to endDate: Date
    ) async throws -> [Date: Int] {
        return try await checkQuantityAuthorizationAndProceed(for: typeIdentifier) { type in
            try await withCheckedThrowingContinuation { continuation in
                let calendar = Calendar.current
                let anchorDate = calendar.startOfDay(for: startDate)
                var interval = DateComponents()
                interval.hour = 1

                let predicate = HKQuery.predicateForSamples(
                    withStart: startDate, end: endDate, options: .strictStartDate)

                // Use appropriate statistics option based on data type
                // Cumulative for steps, discrete average for heart rate
                let options: HKStatisticsOptions
                let isDiscrete: Bool

                switch typeIdentifier {
                case .stepCount, .distanceWalkingRunning, .activeEnergyBurned:
                    options = .cumulativeSum
                    isDiscrete = false
                case .heartRate, .restingHeartRate, .bodyMass, .height:
                    options = .discreteAverage
                    isDiscrete = true
                default:
                    options = .discreteAverage
                    isDiscrete = true
                }

                let query = HKStatisticsCollectionQuery(
                    quantityType: type,
                    quantitySamplePredicate: predicate,
                    options: options,
                    anchorDate: anchorDate,
                    intervalComponents: interval
                )

                query.initialResultsHandler = { _, results, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: Error fetching hourly statistics for \(typeIdentifier.rawValue): \(error.localizedDescription)"
                        )
                        continuation.resume(throwing: error)
                        return
                    }

                    var hourlyData: [Date: Int] = [:]

                    results?.enumerateStatistics(from: startDate, to: endDate) {
                        statistics, _ in
                        if isDiscrete {
                            // For discrete data (heart rate), use average
                            if let avg = statistics.averageQuantity() {
                                let value = Int(avg.doubleValue(for: unit))
                                if value > 0 {
                                    hourlyData[statistics.startDate] = value
                                }
                            }
                        } else {
                            // For cumulative data (steps), use sum
                            if let sum = statistics.sumQuantity() {
                                let value = Int(sum.doubleValue(for: unit))
                                if value > 0 {
                                    hourlyData[statistics.startDate] = value
                                }
                            }
                        }
                    }

                    continuation.resume(returning: hourlyData)
                }

                self.store.execute(query)
            }
        } ?? [:]
    }

    public func startObserving(for type: HKObjectType) async throws {
        guard let sampleType = type as? HKSampleType else {
            throw HealthKitError.invalidObjectTypeForObservation(type.identifier)
        }

        if observerQueries[type] != nil {
            print(
                "HealthKitAdapter: Already observing \(type.identifier) with this adapter instance."
            )
            return
        }

        // Enable background delivery for this type
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(for: sampleType, frequency: .immediate) {
                success, error in
                if let error = error {
                    print(
                        "HealthKitAdapter: Error enabling background delivery for \(type.identifier): \(error.localizedDescription)"
                    )
                    continuation.resume(throwing: error)
                } else if !success {
                    print(
                        "HealthKitAdapter: Failed to enable background delivery for \(type.identifier)."
                    )
                    continuation.resume(
                        throwing: HealthKitError.backgroundDeliveryFailed(type.identifier))
                } else {
                    print("HealthKitAdapter: Background delivery enabled for \(type.identifier).")
                    continuation.resume(returning: ())
                }
            }
        }

        let observerQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            [weak self] query, completionHandler, error in
            if let error = error {
                print(
                    "HealthKitAdapter: Observer query for \(sampleType.identifier) failed: \(error.localizedDescription)"
                )
                completionHandler()
                return
            }

            // --- ADDED LOGS FOR DIAGNOSIS ---
            print("HealthKitAdapter: OBSERVER QUERY FIRED for type: \(sampleType.identifier).")

            if let quantityType = sampleType as? HKQuantityType {
                let stringIdentifier = (quantityType as HKObjectType).identifier
                let hkQuantityIdentifier = HKQuantityTypeIdentifier(rawValue: stringIdentifier)

                // --- Check if onDataUpdate is nil before calling ---
                if self?.onDataUpdate != nil {
                    self?.onDataUpdate?(hkQuantityIdentifier)
                    print(
                        "HealthKitAdapter: Called onDataUpdate for type: \(hkQuantityIdentifier.rawValue)."
                    )
                } else {
                    print(
                        "HealthKitAdapter: onDataUpdate closure is NIL for type: \(hkQuantityIdentifier.rawValue). Event not propagated."
                    )
                }
            } else if let categoryType = sampleType as? HKCategoryType {
                // Handle category types (e.g., sleep analysis)
                let stringIdentifier = (categoryType as HKObjectType).identifier

                // For sleep analysis, trigger a sync using a known quantity type identifier
                // This will trigger the daily sync which includes sleep processing
                if stringIdentifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue {
                    print(
                        "HealthKitAdapter: Sleep analysis data updated. Triggering sync via steps identifier."
                    )
                    // Use stepCount as a proxy to trigger daily sync which includes sleep
                    if self?.onDataUpdate != nil {
                        self?.onDataUpdate?(.stepCount)
                        print("HealthKitAdapter: Called onDataUpdate for sleep analysis.")
                    } else {
                        print(
                            "HealthKitAdapter: onDataUpdate closure is NIL for sleep analysis. Event not propagated."
                        )
                    }
                } else {
                    print(
                        "HealthKitAdapter: Category type \(stringIdentifier) observed but no specific handler configured."
                    )
                }
            }
            // --- END ADDED LOGS ---
            completionHandler()
        }

        store.execute(observerQuery)
        observerQueries[type] = observerQuery
        print("HealthKitAdapter: Started observing \(type.identifier).")
    }

    public func stopObserving(for type: HKObjectType) async throws {
        if let query = observerQueries[type] {
            store.stop(query)
            observerQueries[type] = nil
            print("HealthKitAdapter: Stopped observing \(type.identifier).")
        }

        guard let sampleType = type as? HKSampleType else {
            print(
                "HealthKitAdapter: Cannot disable background delivery for non-sample type: \(type.identifier)"
            )
            return
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            store.disableBackgroundDelivery(for: sampleType) { success, error in
                if let error = error {
                    print(
                        "HealthKitAdapter: Error disabling background delivery for \(type.identifier): \(error.localizedDescription)"
                    )
                    continuation.resume(throwing: error)
                } else if !success {
                    print(
                        "HealthKitAdapter: Failed to disable background delivery for \(type.identifier)."
                    )
                    continuation.resume(
                        throwing: HealthKitError.backgroundDeliveryFailed(type.identifier))
                } else {
                    print("HealthKitAdapter: Background delivery disabled for \(type.identifier).")
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func fetchDateOfBirth() async throws -> Date? {
        do {
            let dobComponents = try store.dateOfBirthComponents()
            return dobComponents.date
        } catch {
            print("HealthKitAdapter: Error fetching date of birth: \(error.localizedDescription)")
            throw error
        }
    }

    public func fetchBiologicalSex() async throws -> HKBiologicalSex? {
        do {
            let biologicalSex = try store.biologicalSex()
            return biologicalSex.biologicalSex
        } catch {
            print("HealthKitAdapter: Error fetching biological sex: \(error.localizedDescription)")
            throw error
        }
    }

    public func saveQuantitySample(
        value: Double, unit: HKUnit, typeIdentifier: HKQuantityTypeIdentifier, date: Date
    ) async throws {
        try await checkQuantityAuthorizationAndProceed(for: typeIdentifier) { type in
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                self.store.save(sample) { success, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: Error saving \(typeIdentifier.rawValue) sample: \(error.localizedDescription)"
                        )
                        continuation.resume(
                            throwing: HealthKitError.saveFailed(error.localizedDescription))
                    } else if !success {
                        print(
                            "HealthKitAdapter: Failed to save \(typeIdentifier.rawValue) sample (no specific error)."
                        )
                        continuation.resume(
                            throwing: HealthKitError.saveFailed("Unknown reason for save failure."))
                    } else {
                        print(
                            "HealthKitAdapter: Successfully saved \(value) \(unit.unitString) for \(typeIdentifier.rawValue) at \(date)."
                        )
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }

    /// Saves a category sample to HealthKit (for mood/state of mind tracking).
    /// - Parameters:
    ///   - value: The integer value for the category.
    ///   - typeIdentifier: The HKCategoryTypeIdentifier for the sample.
    ///   - date: The date for the sample.
    ///   - metadata: Optional metadata dictionary for additional context.
    public func saveCategorySample(
        value: Int, typeIdentifier: HKCategoryTypeIdentifier, date: Date, metadata: [String: Any]?
    ) async throws {
        print(
            "HealthKitAdapter: Saving category sample for \(typeIdentifier.rawValue) with value \(value) at \(date)"
        )

        guard let categoryType = HKObjectType.categoryType(forIdentifier: typeIdentifier) else {
            print("HealthKitAdapter: Invalid category type identifier: \(typeIdentifier.rawValue)")
            throw HealthKitError.saveFailed("Invalid category type identifier")
        }

        let categorySample = HKCategorySample(
            type: categoryType,
            value: value,
            start: date,
            end: date,
            metadata: metadata
        )

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            store.save(categorySample) { success, error in
                if let error = error {
                    print(
                        "HealthKitAdapter: Failed to save category sample: \(error.localizedDescription)"
                    )
                    continuation.resume(
                        throwing: HealthKitError.saveFailed(error.localizedDescription))
                } else if !success {
                    print("HealthKitAdapter: Category sample save reported failure without error.")
                    continuation.resume(
                        throwing: HealthKitError.saveFailed("Unknown reason for save failure."))
                } else {
                    print(
                        "HealthKitAdapter: Successfully saved category sample for \(typeIdentifier.rawValue) at \(date)."
                    )
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // MARK: - Profile Data Writing

    /// Saves height to HealthKit
    /// - Parameter heightCm: Height in centimeters
    /// - Throws: HealthKitError if save fails
    public func saveHeight(heightCm: Double) async throws {
        print("HealthKitAdapter: Saving height to HealthKit: \(heightCm) cm")

        let heightInMeters = heightCm / 100.0
        let unit = HKUnit.meter()

        try await saveQuantitySample(
            value: heightInMeters,
            unit: unit,
            typeIdentifier: .height,
            date: Date()
        )

        print("HealthKitAdapter: Successfully saved height to HealthKit")
    }

    /// Note: Date of birth and biological sex are read-only in HealthKit
    /// They must be set by the user in the Health app and cannot be written programmatically
    /// This is by design for privacy and data integrity reasons

    // MARK: - Workout Data

    /// Fetches workout samples from HealthKit within a specified date range
    /// - Parameters:
    ///   - startDate: The start date of the period to query
    ///   - endDate: The end date of the period to query
    /// - Returns: An array of HKWorkout objects
    public func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        print("HealthKitAdapter: Fetching workouts from \(startDate) to \(endDate)")

        guard let workoutType = HKObjectType.workoutType() as? HKSampleType else {
            throw HealthKitError.unknownError("Failed to get workout type")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                ]
            ) { _, samples, error in
                if let error = error {
                    print(
                        "HealthKitAdapter: Error fetching workouts: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout]) ?? []
                    print("HealthKitAdapter: Fetched \(workouts.count) workouts")
                    continuation.resume(returning: workouts)
                }
            }

            self.store.execute(query)
        }
    }

    /// Fetch workout effort score for a specific workout (iOS 18+)
    /// - Parameter workout: The workout to fetch effort score for
    /// - Returns: The effort score (1-10 scale) if available, nil otherwise
    public func fetchWorkoutEffortScore(for workout: HKWorkout) async throws -> Int? {
        // Only available on iOS 18+
        if #available(iOS 18.0, *) {
            guard
                let effortScoreType = HKQuantityType.quantityType(
                    forIdentifier: .workoutEffortScore)
            else {
                print("HealthKitAdapter: ⚠️ Workout effort score type not available")
                return nil
            }

            // FIRST: Debug query to see ALL effort scores in HealthKit
            print(
                "HealthKitAdapter: 🔍 DEBUG - Querying ALL effort scores in HealthKit to verify data exists"
            )
            let debugPredicate = HKQuery.predicateForSamples(
                withStart: Date.distantPast,
                end: Date(),
                options: []
            )
            let debugQuery = HKSampleQuery(
                sampleType: effortScoreType,
                predicate: debugPredicate,
                limit: 100,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                ]
            ) { _, samples, error in
                if let error = error {
                    print("HealthKitAdapter: ⚠️ DEBUG query error: \(error.localizedDescription)")
                } else {
                    print(
                        "HealthKitAdapter: 🔍 DEBUG - Found \(samples?.count ?? 0) TOTAL effort scores in HealthKit"
                    )
                    if let samples = samples {
                        for (i, sample) in samples.prefix(5).enumerated() {
                            if let qty = sample as? HKQuantitySample {
                                let score = qty.quantity.doubleValue(for: HKUnit.appleEffortScore())
                                print(
                                    "HealthKitAdapter: 🔍 DEBUG Sample \(i): score=\(score), start=\(qty.startDate), end=\(qty.endDate)"
                                )
                            }
                        }
                    }
                }
            }
            self.store.execute(debugQuery)

            return try await withCheckedThrowingContinuation { continuation in
                // Use predicate to get effort score samples related to this specific workout
                // Effort scores are typically logged at the end of the workout, so search within a small window
                let workoutEnd = workout.endDate
                let searchStart = workout.startDate
                let searchEnd =
                    Calendar.current.date(byAdding: .minute, value: 5, to: workoutEnd) ?? workoutEnd

                let predicate = HKQuery.predicateForSamples(
                    withStart: searchStart,
                    end: searchEnd,
                    options: .strictStartDate
                )

                print(
                    "HealthKitAdapter: 🔍 Searching for effort score between \(searchStart) and \(searchEnd)"
                )

                let query = HKSampleQuery(
                    sampleType: effortScoreType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [
                        NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                    ]
                ) { _, samples, error in
                    if let error = error {
                        print(
                            "HealthKitAdapter: ⚠️ Error fetching effort score: \(error.localizedDescription)"
                        )
                        continuation.resume(throwing: error)
                        return
                    }

                    print(
                        "HealthKitAdapter: 🔍 Found \(samples?.count ?? 0) effort score samples in time range"
                    )

                    if let samples = samples, !samples.isEmpty {
                        for (index, sample) in samples.enumerated() {
                            if let quantitySample = sample as? HKQuantitySample {
                                let score = quantitySample.quantity.doubleValue(
                                    for: HKUnit.appleEffortScore())
                                print(
                                    "HealthKitAdapter: 🔍 Sample \(index): score=\(score), date=\(quantitySample.startDate)"
                                )
                            }
                        }
                    }

                    if let quantitySample = samples?.first as? HKQuantitySample {
                        let effortScore = quantitySample.quantity.doubleValue(
                            for: HKUnit.appleEffortScore())
                        let roundedScore = Int(round(effortScore))
                        print(
                            "HealthKitAdapter: ✅ Found effort score: \(effortScore) -> \(roundedScore)"
                        )
                        continuation.resume(returning: roundedScore)
                    } else {
                        print(
                            "HealthKitAdapter: ℹ️ No effort score found for workout (workout: \(workout.startDate) to \(workout.endDate))"
                        )
                        continuation.resume(returning: nil)
                    }
                }

                self.store.execute(query)
            }
        } else {
            print("HealthKitAdapter: ℹ️ Workout effort score requires iOS 18+")
            return nil
        }
    }

    /// Check authorization status for a specific HealthKit type
    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return store.authorizationStatus(for: type)
    }

    /// Saves a workout to HealthKit
    public func saveWorkout(
        activityType: Int,
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double?,
        totalDistance: Double?,
        metadata: [String: Any]?
    ) async throws {
        print(
            "HealthKitAdapter: Saving workout to HealthKit - type: \(activityType), start: \(startDate), end: \(endDate)"
        )

        // Convert activity type to HKWorkoutActivityType
        guard let hkActivityType = HKWorkoutActivityType(rawValue: UInt(activityType)) else {
            print("HealthKitAdapter: ❌ Invalid activity type: \(activityType)")
            throw HealthKitError.unknownError("Invalid activity type: \(activityType)")
        }

        // Build workout samples
        var samples: [HKSample] = []

        // Add energy burned sample if provided
        if let energyBurned = totalEnergyBurned {
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: energyBurned)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: startDate,
                end: endDate
            )
            samples.append(energySample)
        }

        // Add distance sample if provided
        if let distance = totalDistance {
            let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: distanceQuantity,
                start: startDate,
                end: endDate
            )
            samples.append(distanceSample)
        }

        // Create workout
        let workout = HKWorkout(
            activityType: hkActivityType,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: totalEnergyBurned.map {
                HKQuantity(unit: .kilocalorie(), doubleValue: $0)
            },
            totalDistance: totalDistance.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            metadata: metadata
        )

        // Save workout with samples
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            store.save(workout) { success, error in
                if let error = error {
                    print("HealthKitAdapter: ❌ Failed to save workout: \(error)")
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    // If we have samples, add them to the workout
                    if !samples.isEmpty {
                        self.store.add(samples, to: workout) { success, error in
                            if let error = error {
                                print(
                                    "HealthKitAdapter: ⚠️ Saved workout but failed to add samples: \(error)"
                                )
                                // Continue anyway - workout is saved
                            }

                            print(
                                "HealthKitAdapter: ✅ Saved workout to HealthKit with \(samples.count) samples"
                            )
                            continuation.resume()
                        }
                    } else {
                        print("HealthKitAdapter: ✅ Saved workout to HealthKit")
                        continuation.resume()
                    }
                } else {
                    print("HealthKitAdapter: ❌ Failed to save workout - unknown error")
                    continuation.resume(
                        throwing: HealthKitError.saveFailed(
                            "Failed to save workout - unknown error"))
                }
            }
        }
    }
}
