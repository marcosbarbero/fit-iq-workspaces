//
//  HealthKitService.swift
//  FitIQCore
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import Foundation
import HealthKit

/// Concrete implementation of HealthKitServiceProtocol using HealthKit
///
/// This service provides complete HealthKit integration for querying, saving,
/// and observing health data. It wraps Apple's HKHealthStore to provide a clean,
/// testable interface that works across both FitIQ and Lume applications.
///
/// **Usage:**
/// ```swift
/// let healthStore = HKHealthStore()
/// let service = HealthKitService(healthStore: healthStore)
///
/// // Query step count for today
/// let metrics = try await service.query(
///     type: .stepCount,
///     from: Date().startOfDay,
///     to: Date(),
///     options: .hourly
/// )
///
/// // Save a weight measurement
/// let weight = HealthMetric.quantity(type: .bodyMass, value: 75.0, unit: "kg")
/// try await service.save(metric: weight)
///
/// // Observe real-time heart rate
/// for await metric in service.observeChanges(for: .heartRate) {
///     print("Heart rate: \(metric.value) bpm")
/// }
/// ```
///
/// **Architecture:** FitIQCore - Infrastructure Layer (Hexagonal Architecture)
///
/// **Thread Safety:** All methods are thread-safe and can be called from any thread
///
/// **Platform:** iOS, watchOS, macOS (Catalyst)
@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
public final class HealthKitService: HealthKitServiceProtocol, Sendable {

    // MARK: - Properties

    private let healthStore: HKHealthStore
    private let unitSystem: HealthKitTypeMapper.UnitSystem

    // MARK: - Initialization

    /// Creates a new HealthKit service
    ///
    /// - Parameters:
    ///   - healthStore: HKHealthStore instance (defaults to shared instance)
    ///   - unitSystem: User's preferred unit system (defaults to metric)
    public init(
        healthStore: HKHealthStore = HKHealthStore(),
        unitSystem: HealthKitTypeMapper.UnitSystem = .metric
    ) {
        self.healthStore = healthStore
        self.unitSystem = unitSystem
    }

    // MARK: - Query Operations

    public func query(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> [HealthMetric] {
        // Validate date range
        guard endDate >= startDate else {
            throw HealthKitError.invalidDateRange(start: startDate, end: endDate)
        }

        // Get HealthKit type
        let hkType = try HealthKitTypeMapper.toHKType(type)

        // Query based on sample type
        if let quantityType = hkType as? HKQuantityType {
            return try await queryQuantityType(
                quantityType,
                domainType: type,
                from: startDate,
                to: endDate,
                options: options
            )
        } else if let categoryType = hkType as? HKCategoryType {
            return try await queryCategoryType(
                categoryType,
                domainType: type,
                from: startDate,
                to: endDate,
                options: options
            )
        } else if hkType is HKWorkoutType {
            return try await queryWorkouts(
                from: startDate,
                to: endDate,
                options: options
            )
        } else {
            throw HealthKitError.typeNotAvailable(type)
        }
    }

    public func queryStatistics(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> HealthStatistics {
        // Must be a quantity type for statistics
        guard type.isQuantityType else {
            throw HealthKitError.invalidQueryOptions(
                reason: "Statistics only available for quantity types")
        }

        let hkType = try HealthKitTypeMapper.toHKType(type)
        guard let quantityType = hkType as? HKQuantityType else {
            throw HealthKitError.typeNotAvailable(type)
        }

        // Determine statistics options
        var statisticsOptions: HKStatisticsOptions = []
        if let aggregation = options.aggregation {
            switch aggregation {
            case .sum:
                statisticsOptions.insert(.cumulativeSum)
            case .average:
                statisticsOptions.insert(.discreteAverage)
            case .minimum:
                statisticsOptions.insert(.discreteMin)
            case .maximum:
                statisticsOptions.insert(.discreteMax)
            case .count:
                statisticsOptions.insert(.cumulativeSum)
            }
        } else {
            // Default to all statistics
            statisticsOptions = [.cumulativeSum, .discreteAverage, .discreteMin, .discreteMax]
        }

        // Create predicate
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: statisticsOptions
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(
                        throwing: HealthKitError.queryFailed(reason: error.localizedDescription))
                    return
                }

                guard let statistics = statistics else {
                    continuation.resume(
                        throwing: HealthKitError.noDataAvailable)
                    return
                }

                // Extract statistics
                let unit = HealthKitTypeMapper.defaultUnit(for: type, unitSystem: self.unitSystem)
                let unitString = HealthKitTypeMapper.unitString(
                    for: type, unitSystem: self.unitSystem)

                let sum = statistics.sumQuantity()?.doubleValue(for: unit)
                let average = statistics.averageQuantity()?.doubleValue(for: unit)
                let minimum = statistics.minimumQuantity()?.doubleValue(for: unit)
                let maximum = statistics.maximumQuantity()?.doubleValue(for: unit)
                let mostRecent = statistics.mostRecentQuantity()?.doubleValue(for: unit)

                let result = HealthStatistics(
                    type: type,
                    startDate: statistics.startDate,
                    endDate: statistics.endDate,
                    sum: sum,
                    average: average,
                    minimum: minimum,
                    maximum: maximum,
                    count: 0,  // Not available from HKStatistics
                    mostRecent: mostRecent,
                    unit: unitString
                )

                continuation.resume(returning: result)
            }

            self.healthStore.execute(query)
        }
    }

    // MARK: - Write Operations

    public func save(metric: HealthMetric) async throws {
        // Convert to HKSample
        let sample = try HealthKitSampleConverter.toHKSample(metric, unitSystem: unitSystem)

        // Save to HealthKit
        do {
            try await healthStore.save(sample)
        } catch {
            throw HealthKitError.saveFailed(reason: error.localizedDescription)
        }
    }

    public func saveBatch(metrics: [HealthMetric]) async throws {
        // Convert all metrics
        let samples = try HealthKitSampleConverter.toHKSamples(metrics, unitSystem: unitSystem)

        // Save batch
        do {
            try await healthStore.save(samples)
        } catch {
            throw HealthKitError.batchSaveFailed(
                successCount: 0,
                totalCount: metrics.count,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Delete Operations

    public func delete(metricID: UUID) async throws {
        // We need to find the sample by UUID
        // This requires querying for samples with the external UUID metadata
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeyExternalUUID,
            allowedValues: [metricID.uuidString]
        )

        // Query all sample types (this is a limitation - we don't know the type)
        // In practice, the app should track which type the metric belongs to
        throw HealthKitError.deleteFailed(
            reason: "Delete by ID requires knowing the sample type. Use deleteAll() instead.")
    }

    public func deleteAll(
        type: HealthDataType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Int {
        // Get HealthKit type
        let hkType = try HealthKitTypeMapper.toHKType(type)

        // Create predicate
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        // Query samples to delete
        let samples = try await querySamples(ofType: hkType, predicate: predicate, limit: nil)

        // Delete samples
        guard !samples.isEmpty else {
            return 0
        }

        do {
            try await healthStore.delete(samples)
            return samples.count
        } catch {
            throw HealthKitError.deleteFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Real-Time Observation

    public func observeChanges(for types: Set<HealthDataType>) -> AsyncStream<HealthMetric> {
        AsyncStream { continuation in
            // Convert to HK types
            guard let hkTypes = try? types.map({ try HealthKitTypeMapper.toHKType($0) }) else {
                continuation.finish()
                return
            }

            // Create observers for each type
            var queries: [HKObserverQuery] = []

            for (index, hkType) in hkTypes.enumerated() {
                let query = HKObserverQuery(sampleType: hkType, predicate: nil) {
                    _, completionHandler, error in

                    if let error = error {
                        print("Observer error: \(error.localizedDescription)")
                        completionHandler()
                        return
                    }

                    // Query latest sample
                    let domainType = types[types.index(types.startIndex, offsetBy: index)]
                    Task {
                        if let latest = try? await self.queryLatest(type: domainType) {
                            continuation.yield(latest)
                        }
                        completionHandler()
                    }
                }

                queries.append(query)
                self.healthStore.execute(query)
            }

            // Clean up on cancellation
            continuation.onTermination = { _ in
                for query in queries {
                    self.healthStore.stop(query)
                }
            }
        }
    }

    // MARK: - Background Delivery

    public func enableBackgroundDelivery(
        for type: HealthDataType,
        frequency: BackgroundDeliveryFrequency
    ) async throws {
        let hkType = try HealthKitTypeMapper.toHKType(type)

        let hkFrequency: HKUpdateFrequency
        switch frequency {
        case .immediate:
            hkFrequency = .immediate
        case .hourly:
            hkFrequency = .hourly
        case .daily:
            hkFrequency = .daily
        case .weekly:
            hkFrequency = .weekly
        }

        do {
            try await healthStore.enableBackgroundDelivery(for: hkType, frequency: hkFrequency)
        } catch {
            throw HealthKitError.backgroundDeliveryFailed(
                type, reason: error.localizedDescription)
        }
    }

    public func disableBackgroundDelivery(for type: HealthDataType) async throws {
        let hkType = try HealthKitTypeMapper.toHKType(type)

        do {
            try await healthStore.disableBackgroundDelivery(for: hkType)
        } catch {
            throw HealthKitError.backgroundDeliveryFailed(
                type, reason: error.localizedDescription)
        }
    }

    // MARK: - Anchored Queries

    public func queryNew(
        type: HealthDataType,
        since anchor: QueryAnchor?,
        limit: Int?
    ) async throws -> (metrics: [HealthMetric], newAnchor: QueryAnchor) {
        let hkType = try HealthKitTypeMapper.toHKType(type)

        // Convert anchor
        let hkAnchor: HKQueryAnchor?
        if let anchor = anchor {
            hkAnchor = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: HKQueryAnchor.self, from: anchor.data)
        } else {
            hkAnchor = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: hkType,
                predicate: nil,
                anchor: hkAnchor,
                limit: limit ?? HKObjectQueryNoLimit
            ) { _, addedSamples, _, newAnchor, error in
                if let error = error {
                    continuation.resume(
                        throwing: HealthKitError.queryFailed(reason: error.localizedDescription))
                    return
                }

                // Convert samples to metrics
                let samples = addedSamples ?? []
                do {
                    let metrics = try HealthKitSampleConverter.fromHKSamples(
                        samples, unitSystem: self.unitSystem)

                    // Convert new anchor
                    let anchorData =
                        try NSKeyedArchiver.archivedData(
                            withRootObject: newAnchor as Any, requiringSecureCoding: true)
                    let queryAnchor = QueryAnchor(data: anchorData)

                    continuation.resume(returning: (metrics, queryAnchor))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            self.healthStore.execute(query)
        }
    }

    // MARK: - Private Query Helpers

    private func queryQuantityType(
        _ quantityType: HKQuantityType,
        domainType: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> [HealthMetric] {
        // Create predicate
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        // Query samples
        let samples = try await querySamples(
            ofType: quantityType,
            predicate: predicate,
            limit: options.limit
        )

        // Convert to metrics
        let metrics = try HealthKitSampleConverter.fromHKSamples(samples, unitSystem: unitSystem)

        // Apply sorting
        let sorted = applySorting(metrics, sortOrder: options.sortOrder)

        return sorted
    }

    private func queryCategoryType(
        _ categoryType: HKCategoryType,
        domainType: HealthDataType,
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> [HealthMetric] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let samples = try await querySamples(
            ofType: categoryType,
            predicate: predicate,
            limit: options.limit
        )

        let metrics = try HealthKitSampleConverter.fromHKSamples(samples, unitSystem: unitSystem)
        let sorted = applySorting(metrics, sortOrder: options.sortOrder)

        return sorted
    }

    private func queryWorkouts(
        from startDate: Date,
        to endDate: Date,
        options: HealthQueryOptions
    ) async throws -> [HealthMetric] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let workoutType = HKWorkoutType.workoutType()
        let samples = try await querySamples(
            ofType: workoutType,
            predicate: predicate,
            limit: options.limit
        )

        let metrics = try HealthKitSampleConverter.fromHKSamples(samples, unitSystem: unitSystem)
        let sorted = applySorting(metrics, sortOrder: options.sortOrder)

        return sorted
    }

    private func querySamples(
        ofType sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int?
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit ?? HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(
                        throwing: HealthKitError.queryFailed(reason: error.localizedDescription))
                    return
                }

                continuation.resume(returning: samples ?? [])
            }

            self.healthStore.execute(query)
        }
    }

    private func applySorting(
        _ metrics: [HealthMetric],
        sortOrder: HealthQueryOptions.SortOrder
    ) -> [HealthMetric] {
        switch sortOrder {
        case .chronological:
            return metrics.sortedByDateAscending
        case .reverseChronological:
            return metrics.sortedByDateDescending
        case .ascending:
            return metrics.sorted { $0.value < $1.value }
        case .descending:
            return metrics.sorted { $0.value > $1.value }
        }
    }
}

// MARK: - Factory

@available(iOS 13.0, watchOS 6.0, macOS 13.0, *)
extension HealthKitService {
    /// Creates a shared instance of the health service
    public static let shared = HealthKitService()
}
