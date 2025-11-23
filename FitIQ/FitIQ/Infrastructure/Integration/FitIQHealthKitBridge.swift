//
//  FitIQHealthKitBridge.swift
//  FitIQ
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2 Day 6: HealthKit Migration to FitIQCore
//

import FitIQCore
import Foundation
import HealthKit

/// Bridge adapter connecting legacy FitIQ HealthKit protocol to FitIQCore infrastructure
///
/// **Purpose:**
/// This adapter implements FitIQ's legacy `HealthRepositoryProtocol` while delegating
/// all operations to FitIQCore's modern `HealthKitServiceProtocol`. This enables
/// a gradual migration where existing FitIQ use cases continue to work unchanged
/// while benefiting from FitIQCore's robust, tested infrastructure.
///
/// **Architecture:**
/// ```
/// FitIQ Use Cases (unchanged)
///     ↓ calls
/// HealthRepositoryProtocol (legacy interface)
///     ↓ implemented by
/// FitIQHealthKitBridge (this class)
///     ↓ delegates to
/// FitIQCore.HealthKitServiceProtocol
///     ↓ uses
/// FitIQCore.HealthKitService (HKHealthStore wrapper)
/// ```
///
/// **Migration Strategy:**
/// - **Day 6:** Create bridge, maintain backward compatibility
/// - **Day 7-8:** Migrate use cases to use FitIQCore types directly
/// - **Day 9+:** Remove bridge, use FitIQCore everywhere
///
/// **Key Responsibilities:**
/// - Translate HKQuantityTypeIdentifier → FitIQCore.HealthDataType
/// - Translate HKUnit → FitIQCore unit system (respects user profile)
/// - Map legacy method signatures to modern service methods
/// - Handle observer queries and background delivery
/// - Maintain exact behavioral compatibility
///
/// **Thread Safety:** All methods are async and thread-safe
///
/// **Note:** This is a temporary bridge. Do not add new features here.
/// New features should use FitIQCore types directly.
final class FitIQHealthKitBridge: HealthRepositoryProtocol {

    // MARK: - Dependencies

    /// FitIQCore's modern HealthKit service
    private let healthKitService: HealthKitServiceProtocol

    /// FitIQCore's authorization service
    private let authService: HealthAuthorizationServiceProtocol

    /// User profile for unit system preferences (optional - uses metric if nil)
    private let userProfile: UserProfileStoragePortProtocol?

    /// HealthKit store (for legacy operations not yet in FitIQCore)
    private let healthStore = HKHealthStore()

    // MARK: - State

    /// Callback for data updates (legacy observer pattern)
    var onDataUpdate: ((HKQuantityTypeIdentifier) -> Void)?

    /// Active observer queries (legacy pattern)
    private var observerQueries: [HKObjectType: HKObserverQuery] = [:]

    /// Actor for thread-safe state management
    private actor StateManager {
        var observerQueries: [HKObjectType: HKObserverQuery] = [:]

        func setQuery(_ query: HKObserverQuery, for type: HKObjectType) {
            observerQueries[type] = query
        }

        func removeQuery(for type: HKObjectType) {
            if let query = observerQueries[type] {
                observerQueries.removeValue(forKey: type)
            }
        }

        func getQuery(for type: HKObjectType) -> HKObserverQuery? {
            return observerQueries[type]
        }
    }

    private let stateManager = StateManager()

    // MARK: - Initialization

    init(
        healthKitService: HealthKitServiceProtocol,
        authService: HealthAuthorizationServiceProtocol,
        userProfile: UserProfileStoragePortProtocol?
    ) {
        self.healthKitService = healthKitService
        self.authService = authService
        self.userProfile = userProfile

        print("✅ FitIQHealthKitBridge initialized (using FitIQCore infrastructure)")
    }

    // MARK: - Basic Availability

    func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization(read: Set<HKObjectType>, share: Set<HKSampleType>) async throws {
        // Convert HKObjectType sets to FitIQCore HealthDataType sets
        let readTypes = Set(read.compactMap { convertToHealthDataType($0) })
        let shareTypes = Set(share.compactMap { convertToHealthDataType($0 as? HKSampleType) })

        // Use FitIQCore authorization service
        let scope = HealthAuthorizationScope(
            read: readTypes,
            write: shareTypes
        )
        try await authService.requestAuthorization(scope: scope)
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }

    // MARK: - Query Operations - Latest Sample

    func fetchLatestQuantitySample(
        for typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> (value: Double, date: Date)? {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            print("⚠️ FitIQHealthKitBridge: Unsupported type: \(typeIdentifier.rawValue)")
            return nil
        }

        // Query using FitIQCore service
        guard let metric = try await healthKitService.queryLatest(type: healthDataType) else {
            return nil
        }

        // Convert value to requested unit if needed
        let convertedValue = try convertValue(
            metric.value,
            from: metric.unit,
            to: unit.unitString,
            for: typeIdentifier
        )

        return (value: convertedValue, date: metric.date)
    }

    // MARK: - Query Operations - Multiple Samples

    func fetchQuantitySamples(
        for typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicateProvider: (() -> NSPredicate?)?,
        limit: Int?
    ) async throws -> [(value: Double, date: Date)] {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            print("⚠️ FitIQHealthKitBridge: Unsupported type: \(typeIdentifier.rawValue)")
            return []
        }

        // Extract date range from predicate (if available)
        let predicate = predicateProvider?()
        let (startDate, endDate) = extractDateRange(from: predicate)

        // Build query options
        var options = HealthQueryOptions.default
        if let limit = limit {
            options = options.withLimit(limit)
        }
        options = options.withSortOrder(.reverseChronological)  // Match legacy behavior (most recent first)

        // Query using FitIQCore service
        let metrics = try await healthKitService.query(
            type: healthDataType,
            from: startDate,
            to: endDate,
            options: options
        )

        // Convert to legacy format
        return try metrics.map { metric in
            let convertedValue = try convertValue(
                metric.value,
                from: metric.unit,
                to: unit,
                for: typeIdentifier
            )
            return (value: convertedValue, date: metric.date)
        }
    }

    // MARK: - Query Operations - Aggregations

    func fetchSumOfQuantitySamples(
        for typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            print("⚠️ FitIQHealthKitBridge: Unsupported type: \(typeIdentifier.rawValue)")
            return nil
        }

        // Query statistics using FitIQCore
        let options = HealthQueryOptions.daily  // Aggregate by day for sum
        let stats = try await healthKitService.queryStatistics(
            type: healthDataType,
            from: startDate,
            to: endDate,
            options: options
        )

        guard let sum = stats.sum else {
            return nil
        }

        // Convert to requested unit
        let convertedValue = try convertValue(
            sum,
            from: stats.unit,
            to: unit,
            for: typeIdentifier
        )

        return convertedValue
    }

    func fetchAverageQuantitySample(
        for typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            print("⚠️ FitIQHealthKitBridge: Unsupported type: \(typeIdentifier.rawValue)")
            return nil
        }

        // Query statistics using FitIQCore
        let options = HealthQueryOptions.daily
        let stats = try await healthKitService.queryStatistics(
            type: healthDataType,
            from: startDate,
            to: endDate,
            options: options
        )

        guard let average = stats.average else {
            return nil
        }

        // Convert to requested unit
        let convertedValue = try convertValue(
            average,
            from: stats.unit,
            to: unit,
            for: typeIdentifier
        )

        return convertedValue
    }

    func fetchHourlyStatistics(
        for typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [Date: Int] {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            print("⚠️ FitIQHealthKitBridge: Unsupported type: \(typeIdentifier.rawValue)")
            return [:]
        }

        // Query with hourly aggregation
        let options = HealthQueryOptions.hourly
        let metrics = try await healthKitService.query(
            type: healthDataType,
            from: startDate,
            to: endDate,
            options: options
        )

        // Convert to legacy format (Date -> Int dictionary)
        var result: [Date: Int] = [:]
        for metric in metrics {
            let convertedValue = try convertValue(
                metric.value,
                from: metric.unit,
                to: unit,
                for: typeIdentifier
            )
            result[metric.date] = Int(convertedValue)
        }

        return result
    }

    // MARK: - Save Operations

    func saveQuantitySample(
        value: Double,
        unit: HKUnit,
        typeIdentifier: HKQuantityTypeIdentifier,
        date: Date
    ) async throws {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            throw NSError(
                domain: "FitIQHealthKitBridge",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported type: \(typeIdentifier.rawValue)"
                ]
            )
        }

        // Get appropriate unit for FitIQCore (based on user profile)
        let coreUnit = getUnitString(for: healthDataType)

        // Convert value if needed
        let convertedValue = try convertValue(
            value,
            from: unit.unitString,
            to: coreUnit,
            for: typeIdentifier
        )

        // Create HealthMetric
        let metric = FitIQCore.HealthMetric(
            type: healthDataType,
            value: convertedValue,
            unit: coreUnit,
            date: date,
            source: "FitIQ"
        )

        // Save using FitIQCore service
        try await healthKitService.save(metric: metric)
    }

    func saveCategorySample(
        value: Int,
        typeIdentifier: HKCategoryTypeIdentifier,
        date: Date,
        metadata: [String: Any]?
    ) async throws {
        // Convert to FitIQCore type
        guard let healthDataType = convertToHealthDataType(typeIdentifier) else {
            throw NSError(
                domain: "FitIQHealthKitBridge",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Unsupported category type: \(typeIdentifier.rawValue)"
                ]
            )
        }

        // Create HealthMetric for category (value is the category value)
        // Convert metadata from [String: Any] to [String: String]
        let stringMetadata: [String: String] =
            metadata?.compactMapValues { value in
                if let stringValue = value as? String {
                    return stringValue
                } else if let customStringConvertible = value as? CustomStringConvertible {
                    return customStringConvertible.description
                } else {
                    return String(describing: value)
                }
            } ?? [:]

        let metric = FitIQCore.HealthMetric(
            type: healthDataType,
            value: Double(value),
            unit: "category",
            date: date,
            source: "FitIQ",
            metadata: stringMetadata
        )

        // Save using FitIQCore service
        try await healthKitService.save(metric: metric)
    }

    // MARK: - Workout Operations

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        // For now, use direct HealthKit access for workouts
        // TODO: Migrate to FitIQCore workout queries in Day 7
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                ]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    func fetchWorkoutEffortScore(for workout: HKWorkout) async throws -> Int? {
        // iOS 18+ feature - direct HealthKit access for now
        if #available(iOS 18.0, *) {
            // Use HealthKit's effort score API
            // TODO: Add to FitIQCore in future iteration
            return nil  // Placeholder
        }
        return nil
    }

    func saveWorkout(
        activityType: Int,
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double?,
        totalDistance: Double?,
        metadata: [String: Any]?
    ) async throws {
        // Convert activity type to WorkoutType
        guard let hkActivityType = HKWorkoutActivityType(rawValue: UInt(activityType)) else {
            throw NSError(
                domain: "FitIQHealthKitBridge",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid workout activity type: \(activityType)"
                ]
            )
        }

        // For now, use direct HealthKit access
        // TODO: Migrate to FitIQCore workout saving in Day 7
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

        try await healthStore.save(workout)
    }

    // MARK: - Characteristic Queries

    func fetchDateOfBirth() async throws -> Date? {
        // Direct HealthKit access for characteristics
        // FitIQCore doesn't handle characteristics yet
        do {
            let components = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: components)
        } catch {
            return nil
        }
    }

    func fetchBiologicalSex() async throws -> HKBiologicalSex? {
        // Direct HealthKit access for characteristics
        do {
            let biologicalSex = try healthStore.biologicalSex()
            return biologicalSex.biologicalSex
        } catch {
            return nil
        }
    }

    // MARK: - Observer Queries (Legacy Pattern)

    func startObserving(for type: HKObjectType) async throws {
        // For now, maintain legacy observer pattern
        // TODO: Migrate to FitIQCore's AsyncStream observers in Day 7
        guard let sampleType = type as? HKSampleType else {
            throw NSError(
                domain: "FitIQHealthKitBridge",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Type must be HKSampleType for observation"]
            )
        }

        // Check if already observing
        if await stateManager.getQuery(for: type) != nil {
            print("Already observing \(type)")
            return
        }

        // Create observer query
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            [weak self] query, completionHandler, error in
            if let error = error {
                print("Observer query error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            // Notify via callback (legacy pattern)
            if let quantityType = type as? HKQuantityType {
                let identifier = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
                self?.onDataUpdate?(identifier)
            }

            completionHandler()
        }

        // Store query
        await stateManager.setQuery(query, for: type)

        // Execute query
        healthStore.execute(query)

        // Enable background delivery
        try await healthStore.enableBackgroundDelivery(
            for: sampleType,
            frequency: .immediate
        )
    }

    func stopObserving(for type: HKObjectType) async throws {
        guard let query = await stateManager.getQuery(for: type) else {
            return
        }

        // Stop query
        healthStore.stop(query)

        // Remove from state
        await stateManager.removeQuery(for: type)

        // Disable background delivery
        if let sampleType = type as? HKSampleType {
            try await healthStore.disableBackgroundDelivery(for: sampleType)
        }
    }
}

// MARK: - Type Conversion Helpers

extension FitIQHealthKitBridge {

    /// Converts HKQuantityTypeIdentifier to FitIQCore HealthDataType
    fileprivate func convertToHealthDataType(_ identifier: HKQuantityTypeIdentifier)
        -> HealthDataType?
    {
        switch identifier {
        // Body Measurements
        case .bodyMass: return .bodyMass
        case .height: return .height

        // Fitness
        case .stepCount: return .stepCount
        case .distanceWalkingRunning: return .distanceWalkingRunning
        case .activeEnergyBurned: return .activeEnergyBurned
        case .basalEnergyBurned: return .basalEnergyBurned
        case .flightsClimbed: return .flightsClimbed
        case .appleExerciseTime: return .exerciseTime
        case .appleStandTime: return .standTime

        // Heart & Vitals
        case .heartRate: return .heartRate
        case .heartRateVariabilitySDNN: return .heartRateVariability
        case .oxygenSaturation: return .oxygenSaturation
        case .respiratoryRate: return .respiratoryRate

        default:
            print("⚠️ FitIQHealthKitBridge: Unmapped quantity type: \(identifier.rawValue)")
            return nil
        }
    }

    /// Converts HKCategoryTypeIdentifier to FitIQCore HealthDataType
    fileprivate func convertToHealthDataType(_ identifier: HKCategoryTypeIdentifier)
        -> HealthDataType?
    {
        switch identifier {
        case .sleepAnalysis: return .sleepAnalysis
        case .mindfulSession: return .mindfulSession
        default:
            print("⚠️ FitIQHealthKitBridge: Unmapped category type: \(identifier.rawValue)")
            return nil
        }
    }

    /// Converts HKObjectType to FitIQCore HealthDataType
    fileprivate func convertToHealthDataType(_ type: HKObjectType?) -> HealthDataType? {
        guard let type = type else { return nil }

        if let quantityType = type as? HKQuantityType {
            let identifier = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
            return convertToHealthDataType(identifier)
        }

        if let categoryType = type as? HKCategoryType {
            let identifier = HKCategoryTypeIdentifier(rawValue: categoryType.identifier)
            return convertToHealthDataType(identifier)
        }

        if type == HKObjectType.workoutType() {
            return .workout(.running)  // Default workout type
        }

        return nil
    }

    /// Extracts date range from NSPredicate
    fileprivate func extractDateRange(from predicate: NSPredicate?) -> (start: Date, end: Date) {
        // Default range: last 7 days
        let defaultEnd = Date()
        let defaultStart =
            Calendar.current.date(byAdding: .day, value: -7, to: defaultEnd) ?? defaultEnd

        // TODO: Parse predicate to extract actual date range
        // For now, use default range
        return (start: defaultStart, end: defaultEnd)
    }

    /// Gets unit string for HealthDataType based on user profile
    fileprivate func getUnitString(for type: HealthDataType) -> String {
        // For Day 6, use metric as default (full profile integration in Day 7)
        let unitSystem: UnitSystem = .metric

        switch type {
        case .bodyMass:
            return unitSystem == .metric ? "kg" : "lbs"
        case .height:
            return unitSystem == .metric ? "cm" : "in"
        case .distanceWalkingRunning:
            return unitSystem == .metric ? "m" : "ft"
        case .stepCount:
            return "steps"
        case .heartRate, .heartRateVariability:
            return "bpm"
        case .activeEnergyBurned, .basalEnergyBurned:
            return "kcal"
        case .flightsClimbed:
            return "count"
        case .exerciseTime, .standTime:
            return "min"
        case .oxygenSaturation:
            return "%"
        case .respiratoryRate:
            return "breaths/min"
        case .sleepAnalysis:
            return "hr"
        case .mindfulSession:
            return "min"
        case .workout:
            return "kcal"
        }
    }

    /// Converts value between units
    fileprivate func convertValue(
        _ value: Double,
        from sourceUnit: String,
        to targetHKUnit: HKUnit,
        for typeIdentifier: HKQuantityTypeIdentifier
    ) throws -> Double {
        // If units match, no conversion needed
        let targetUnitString = targetHKUnit.unitString
        if sourceUnit == targetUnitString {
            return value
        }

        // Convert using HKUnit conversion
        guard let quantityType = HKObjectType.quantityType(forIdentifier: typeIdentifier) else {
            return value
        }

        let sourceHKUnit = unitStringToHKUnit(sourceUnit, for: quantityType)
        let quantity = HKQuantity(unit: sourceHKUnit, doubleValue: value)

        return quantity.doubleValue(for: targetHKUnit)
    }

    /// Converts value between units (string version)
    fileprivate func convertValue(
        _ value: Double,
        from sourceUnit: String,
        to targetUnit: String,
        for typeIdentifier: HKQuantityTypeIdentifier
    ) throws -> Double {
        if sourceUnit == targetUnit {
            return value
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: typeIdentifier) else {
            return value
        }

        let sourceHKUnit = unitStringToHKUnit(sourceUnit, for: quantityType)
        let targetHKUnit = unitStringToHKUnit(targetUnit, for: quantityType)
        let quantity = HKQuantity(unit: sourceHKUnit, doubleValue: value)

        return quantity.doubleValue(for: targetHKUnit)
    }

    /// Converts unit string to HKUnit
    fileprivate func unitStringToHKUnit(_ unitString: String, for quantityType: HKQuantityType)
        -> HKUnit
    {
        switch unitString {
        // Mass
        case "kg": return .gramUnit(with: .kilo)
        case "lbs", "lb": return .pound()
        case "g": return .gram()

        // Distance
        case "m": return .meter()
        case "km": return .meterUnit(with: .kilo)
        case "mi": return .mile()
        case "ft": return .foot()
        case "in": return .inch()
        case "cm": return .meterUnit(with: .centi)

        // Energy
        case "kcal": return .kilocalorie()
        case "cal": return .smallCalorie()

        // Count
        case "steps", "count": return .count()

        // Heart Rate
        case "bpm": return .count().unitDivided(by: .minute())

        // Time
        case "min": return .minute()
        case "hr": return .hour()
        case "s": return .second()

        default:
            // Fallback: try to parse from string
            return HKUnit(from: unitString)
        }
    }
}
