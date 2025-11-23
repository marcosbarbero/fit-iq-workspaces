//
//  HealthDataTypeTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import XCTest

@testable import FitIQCore

final class HealthDataTypeTests: XCTestCase {

    // MARK: - Equality Tests

    func testHealthDataTypeEquality() {
        // Quantity types
        XCTAssertEqual(HealthDataType.stepCount, HealthDataType.stepCount)
        XCTAssertEqual(HealthDataType.heartRate, HealthDataType.heartRate)
        XCTAssertNotEqual(HealthDataType.stepCount, HealthDataType.heartRate)

        // Category types
        XCTAssertEqual(HealthDataType.sleepAnalysis, HealthDataType.sleepAnalysis)
        XCTAssertEqual(HealthDataType.mindfulSession, HealthDataType.mindfulSession)
        XCTAssertNotEqual(HealthDataType.sleepAnalysis, HealthDataType.mindfulSession)

        // Workout types
        XCTAssertEqual(HealthDataType.workout(.running), HealthDataType.workout(.running))
        XCTAssertEqual(HealthDataType.workout(.meditation), HealthDataType.workout(.meditation))
        XCTAssertNotEqual(HealthDataType.workout(.running), HealthDataType.workout(.cycling))
    }

    // MARK: - Hashable Tests

    func testHealthDataTypeHashable() {
        let types: Set<HealthDataType> = [
            .stepCount,
            .heartRate,
            .bodyMass,
            .sleepAnalysis,
            .mindfulSession,
        ]

        XCTAssertEqual(types.count, 5)
        XCTAssertTrue(types.contains(.stepCount))
        XCTAssertTrue(types.contains(.heartRate))
        XCTAssertTrue(types.contains(.bodyMass))
        XCTAssertTrue(types.contains(.sleepAnalysis))
        XCTAssertTrue(types.contains(.mindfulSession))
        XCTAssertFalse(types.contains(.height))
    }

    func testWorkoutTypeHashable() {
        let workoutTypes: Set<HealthDataType> = [
            .workout(.running),
            .workout(.cycling),
            .workout(.meditation),
            .workout(.yoga),
        ]

        XCTAssertEqual(workoutTypes.count, 4)
        XCTAssertTrue(workoutTypes.contains(.workout(.running)))
        XCTAssertTrue(workoutTypes.contains(.workout(.meditation)))
        XCTAssertFalse(workoutTypes.contains(.workout(.swimming)))
    }

    // MARK: - Description Tests

    func testHealthDataTypeDescription() {
        XCTAssertEqual(HealthDataType.stepCount.description, "Step Count")
        XCTAssertEqual(HealthDataType.heartRate.description, "Heart Rate")
        XCTAssertEqual(HealthDataType.activeEnergyBurned.description, "Active Energy")
        XCTAssertEqual(HealthDataType.bodyMass.description, "Body Mass")
        XCTAssertEqual(HealthDataType.height.description, "Height")
        XCTAssertEqual(HealthDataType.sleepAnalysis.description, "Sleep")
        XCTAssertEqual(HealthDataType.mindfulSession.description, "Mindful Minutes")
    }

    func testWorkoutTypeDescription() {
        XCTAssertEqual(HealthDataType.workout(.running).description, "Workout (Running)")
        XCTAssertEqual(HealthDataType.workout(.meditation).description, "Workout (Meditation)")
        XCTAssertEqual(HealthDataType.workout(.yoga).description, "Workout (Yoga)")
        XCTAssertEqual(HealthDataType.workout(.cycling).description, "Workout (Cycling)")
    }

    func testWorkoutTypeDisplayNames() {
        XCTAssertEqual(HealthDataType.WorkoutType.running.displayName, "Running")
        XCTAssertEqual(HealthDataType.WorkoutType.meditation.displayName, "Meditation")
        XCTAssertEqual(
            HealthDataType.WorkoutType.traditionalStrengthTraining.displayName, "Strength Training")
        XCTAssertEqual(HealthDataType.WorkoutType.highIntensityIntervalTraining.displayName, "HIIT")
        XCTAssertEqual(HealthDataType.WorkoutType.yoga.displayName, "Yoga")
        XCTAssertEqual(HealthDataType.WorkoutType.tai_chi.displayName, "Tai Chi")
    }

    // MARK: - Category Tests

    func testIsQuantityType() {
        // Should be quantity types
        XCTAssertTrue(HealthDataType.stepCount.isQuantityType)
        XCTAssertTrue(HealthDataType.heartRate.isQuantityType)
        XCTAssertTrue(HealthDataType.activeEnergyBurned.isQuantityType)
        XCTAssertTrue(HealthDataType.bodyMass.isQuantityType)
        XCTAssertTrue(HealthDataType.height.isQuantityType)
        XCTAssertTrue(HealthDataType.distanceWalkingRunning.isQuantityType)

        // Should NOT be quantity types
        XCTAssertFalse(HealthDataType.sleepAnalysis.isQuantityType)
        XCTAssertFalse(HealthDataType.mindfulSession.isQuantityType)
        XCTAssertFalse(HealthDataType.workout(.running).isQuantityType)
    }

    func testIsCategoryType() {
        // Should be category types
        XCTAssertTrue(HealthDataType.sleepAnalysis.isCategoryType)
        XCTAssertTrue(HealthDataType.mindfulSession.isCategoryType)

        // Should NOT be category types
        XCTAssertFalse(HealthDataType.stepCount.isCategoryType)
        XCTAssertFalse(HealthDataType.heartRate.isCategoryType)
        XCTAssertFalse(HealthDataType.bodyMass.isCategoryType)
        XCTAssertFalse(HealthDataType.workout(.running).isCategoryType)
    }

    func testIsWorkoutType() {
        // Should be workout types
        XCTAssertTrue(HealthDataType.workout(.running).isWorkoutType)
        XCTAssertTrue(HealthDataType.workout(.meditation).isWorkoutType)
        XCTAssertTrue(HealthDataType.workout(.yoga).isWorkoutType)

        // Should NOT be workout types
        XCTAssertFalse(HealthDataType.stepCount.isWorkoutType)
        XCTAssertFalse(HealthDataType.heartRate.isWorkoutType)
        XCTAssertFalse(HealthDataType.sleepAnalysis.isWorkoutType)
        XCTAssertFalse(HealthDataType.mindfulSession.isWorkoutType)
    }

    // MARK: - Predefined Sets Tests

    func testFitnessTypes() {
        let fitnessTypes = HealthDataType.fitnessTypes

        // Should include fitness-related types
        XCTAssertTrue(fitnessTypes.contains(.stepCount))
        XCTAssertTrue(fitnessTypes.contains(.heartRate))
        XCTAssertTrue(fitnessTypes.contains(.activeEnergyBurned))
        XCTAssertTrue(fitnessTypes.contains(.bodyMass))
        XCTAssertTrue(fitnessTypes.contains(.height))
        XCTAssertTrue(fitnessTypes.contains(.distanceWalkingRunning))
        XCTAssertTrue(fitnessTypes.contains(.exerciseTime))
        XCTAssertTrue(fitnessTypes.contains(.sleepAnalysis))

        // Should NOT include mindfulness-specific types
        XCTAssertFalse(fitnessTypes.contains(.mindfulSession))
    }

    func testMindfulnessTypes() {
        let mindfulnessTypes = HealthDataType.mindfulnessTypes

        // Should include mindfulness-related types
        XCTAssertTrue(mindfulnessTypes.contains(.mindfulSession))
        XCTAssertTrue(mindfulnessTypes.contains(.heartRate))
        XCTAssertTrue(mindfulnessTypes.contains(.heartRateVariability))
        XCTAssertTrue(mindfulnessTypes.contains(.respiratoryRate))
        XCTAssertTrue(mindfulnessTypes.contains(.oxygenSaturation))
        XCTAssertTrue(mindfulnessTypes.contains(.workout(.meditation)))
        XCTAssertTrue(mindfulnessTypes.contains(.workout(.yoga)))

        // Should NOT include fitness-specific types
        XCTAssertFalse(mindfulnessTypes.contains(.stepCount))
        XCTAssertFalse(mindfulnessTypes.contains(.distanceWalkingRunning))
    }

    func testAllQuantityTypes() {
        let quantityTypes = HealthDataType.allQuantityTypes

        // Should only contain quantity types
        for type in quantityTypes {
            XCTAssertTrue(type.isQuantityType, "\(type) should be a quantity type")
            XCTAssertFalse(type.isCategoryType, "\(type) should not be a category type")
            XCTAssertFalse(type.isWorkoutType, "\(type) should not be a workout type")
        }

        // Check specific types
        XCTAssertTrue(quantityTypes.contains(.stepCount))
        XCTAssertTrue(quantityTypes.contains(.heartRate))
        XCTAssertTrue(quantityTypes.contains(.bodyMass))
    }

    func testAllCategoryTypes() {
        let categoryTypes = HealthDataType.allCategoryTypes

        // Should only contain category types
        for type in categoryTypes {
            XCTAssertTrue(type.isCategoryType, "\(type) should be a category type")
            XCTAssertFalse(type.isQuantityType, "\(type) should not be a quantity type")
            XCTAssertFalse(type.isWorkoutType, "\(type) should not be a workout type")
        }

        // Check specific types
        XCTAssertTrue(categoryTypes.contains(.sleepAnalysis))
        XCTAssertTrue(categoryTypes.contains(.mindfulSession))
    }

    // MARK: - Workout Type Tests

    func testWorkoutTypeCaseIterable() {
        let allWorkoutTypes = HealthDataType.WorkoutType.allCases

        // Should have all defined workout types
        XCTAssertTrue(allWorkoutTypes.contains(.running))
        XCTAssertTrue(allWorkoutTypes.contains(.cycling))
        XCTAssertTrue(allWorkoutTypes.contains(.meditation))
        XCTAssertTrue(allWorkoutTypes.contains(.yoga))
        XCTAssertTrue(allWorkoutTypes.contains(.traditionalStrengthTraining))
        XCTAssertTrue(allWorkoutTypes.contains(.highIntensityIntervalTraining))

        // Verify count (should match number of cases defined)
        XCTAssertGreaterThan(allWorkoutTypes.count, 20)
    }

    func testWorkoutTypeRawValue() {
        XCTAssertEqual(HealthDataType.WorkoutType.running.rawValue, "running")
        XCTAssertEqual(HealthDataType.WorkoutType.meditation.rawValue, "meditation")
        XCTAssertEqual(HealthDataType.WorkoutType.tai_chi.rawValue, "taiChi")
        XCTAssertEqual(HealthDataType.WorkoutType.football.rawValue, "americanFootball")
    }

    // MARK: - Sendable Tests

    func testHealthDataTypeIsSendable() {
        // This test verifies that HealthDataType conforms to Sendable
        // by using it in an async context
        Task {
            let type: HealthDataType = .stepCount
            XCTAssertEqual(type, .stepCount)
        }
    }

    // MARK: - Edge Cases

    func testEmptySetOperations() {
        let emptySet: Set<HealthDataType> = []
        XCTAssertTrue(emptySet.isEmpty)
        XCTAssertEqual(emptySet.count, 0)
    }

    func testLargeSetOperations() {
        var largeSet: Set<HealthDataType> = []
        largeSet.insert(.stepCount)
        largeSet.insert(.heartRate)
        largeSet.insert(.activeEnergyBurned)
        largeSet.insert(.bodyMass)
        largeSet.insert(.height)
        largeSet.insert(.sleepAnalysis)
        largeSet.insert(.mindfulSession)
        largeSet.insert(.workout(.running))
        largeSet.insert(.workout(.meditation))

        XCTAssertEqual(largeSet.count, 9)
        XCTAssertTrue(largeSet.contains(.stepCount))
        XCTAssertTrue(largeSet.contains(.workout(.running)))
    }

    func testSetUnionWithPredefinedSets() {
        let combined = HealthDataType.fitnessTypes.union(HealthDataType.mindfulnessTypes)

        // Should contain types from both sets
        XCTAssertTrue(combined.contains(.stepCount))  // From fitness
        XCTAssertTrue(combined.contains(.mindfulSession))  // From mindfulness
        XCTAssertTrue(combined.contains(.heartRate))  // In both sets
    }
}
