//
//  HealthAuthorizationScopeTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import XCTest

@testable import FitIQCore

final class HealthAuthorizationScopeTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithReadAndWrite() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        XCTAssertEqual(scope.readTypes.count, 2)
        XCTAssertEqual(scope.writeTypes.count, 1)
        XCTAssertTrue(scope.readTypes.contains(.stepCount))
        XCTAssertTrue(scope.readTypes.contains(.heartRate))
        XCTAssertTrue(scope.writeTypes.contains(.bodyMass))
    }

    func testInitReadOnly() {
        let scope = HealthAuthorizationScope(
            readOnly: [.stepCount, .heartRate, .bodyMass]
        )

        XCTAssertEqual(scope.readTypes.count, 3)
        XCTAssertEqual(scope.writeTypes.count, 0)
        XCTAssertTrue(scope.readTypes.contains(.stepCount))
        XCTAssertTrue(scope.readTypes.contains(.heartRate))
        XCTAssertTrue(scope.readTypes.contains(.bodyMass))
    }

    func testInitWriteOnly() {
        let scope = HealthAuthorizationScope(
            writeOnly: [.bodyMass, .workout(.running)]
        )

        XCTAssertEqual(scope.readTypes.count, 0)
        XCTAssertEqual(scope.writeTypes.count, 2)
        XCTAssertTrue(scope.writeTypes.contains(.bodyMass))
        XCTAssertTrue(scope.writeTypes.contains(.workout(.running)))
    }

    func testInitEmpty() {
        let scope = HealthAuthorizationScope(read: [], write: [])

        XCTAssertEqual(scope.readTypes.count, 0)
        XCTAssertEqual(scope.writeTypes.count, 0)
        XCTAssertTrue(scope.isEmpty)
    }

    // MARK: - Computed Properties Tests

    func testAllTypes() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass, .stepCount]  // stepCount in both
        )

        let allTypes = scope.allTypes

        // Should contain unique types from both sets
        XCTAssertTrue(allTypes.contains(.stepCount))
        XCTAssertTrue(allTypes.contains(.heartRate))
        XCTAssertTrue(allTypes.contains(.bodyMass))
        XCTAssertEqual(allTypes.count, 3)  // stepCount counted once
    }

    func testCanRead() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        XCTAssertTrue(scope.canRead(.stepCount))
        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertFalse(scope.canRead(.bodyMass))  // Only write permission
        XCTAssertFalse(scope.canRead(.height))  // No permission
    }

    func testCanWrite() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        XCTAssertTrue(scope.canWrite(.bodyMass))
        XCTAssertFalse(scope.canWrite(.stepCount))  // Only read permission
        XCTAssertFalse(scope.canWrite(.heartRate))  // Only read permission
        XCTAssertFalse(scope.canWrite(.height))  // No permission
    }

    func testIsEmpty() {
        let emptyScope = HealthAuthorizationScope(read: [], write: [])
        XCTAssertTrue(emptyScope.isEmpty)

        let nonEmptyScope1 = HealthAuthorizationScope(read: [.stepCount], write: [])
        XCTAssertFalse(nonEmptyScope1.isEmpty)

        let nonEmptyScope2 = HealthAuthorizationScope(read: [], write: [.bodyMass])
        XCTAssertFalse(nonEmptyScope2.isEmpty)

        let nonEmptyScope3 = HealthAuthorizationScope(
            read: [.stepCount],
            write: [.bodyMass]
        )
        XCTAssertFalse(nonEmptyScope3.isEmpty)
    }

    // MARK: - Predefined Scopes Tests

    func testFitnessScope() {
        let scope = HealthAuthorizationScope.fitness

        // Should request read permissions for fitness metrics
        XCTAssertTrue(scope.canRead(.stepCount))
        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertTrue(scope.canRead(.activeEnergyBurned))
        XCTAssertTrue(scope.canRead(.bodyMass))
        XCTAssertTrue(scope.canRead(.height))
        XCTAssertTrue(scope.canRead(.sleepAnalysis))

        // Should request write permissions for body mass and workouts
        XCTAssertTrue(scope.canWrite(.bodyMass))
        XCTAssertTrue(scope.canWrite(.workout(.running)))
        XCTAssertTrue(scope.canWrite(.workout(.cycling)))

        // Should NOT request mindfulness permissions
        XCTAssertFalse(scope.canRead(.mindfulSession))
        XCTAssertFalse(scope.canWrite(.mindfulSession))

        XCTAssertFalse(scope.isEmpty)
    }

    func testMindfulnessScope() {
        let scope = HealthAuthorizationScope.mindfulness

        // Should request read permissions for mindfulness metrics
        XCTAssertTrue(scope.canRead(.mindfulSession))
        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertTrue(scope.canRead(.heartRateVariability))
        XCTAssertTrue(scope.canRead(.respiratoryRate))
        XCTAssertTrue(scope.canRead(.oxygenSaturation))

        // Should request write permissions for mindful sessions
        XCTAssertTrue(scope.canWrite(.mindfulSession))
        XCTAssertTrue(scope.canWrite(.workout(.meditation)))
        XCTAssertTrue(scope.canWrite(.workout(.yoga)))

        // Should NOT request fitness-specific permissions
        XCTAssertFalse(scope.canRead(.stepCount))
        XCTAssertFalse(scope.canRead(.distanceWalkingRunning))

        XCTAssertFalse(scope.isEmpty)
    }

    func testBasicHealthScope() {
        let scope = HealthAuthorizationScope.basicHealth

        // Should request read permissions for basic health metrics
        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertTrue(scope.canRead(.respiratoryRate))
        XCTAssertTrue(scope.canRead(.oxygenSaturation))

        // Should NOT request write permissions
        XCTAssertFalse(scope.canWrite(.heartRate))
        XCTAssertFalse(scope.canWrite(.respiratoryRate))
        XCTAssertFalse(scope.canWrite(.oxygenSaturation))

        XCTAssertEqual(scope.writeTypes.count, 0)
        XCTAssertFalse(scope.isEmpty)
    }

    func testBodyMeasurementsScope() {
        let scope = HealthAuthorizationScope.bodyMeasurements

        // Should request read permissions for body measurements
        XCTAssertTrue(scope.canRead(.bodyMass))
        XCTAssertTrue(scope.canRead(.height))

        // Should request write permission for body mass
        XCTAssertTrue(scope.canWrite(.bodyMass))

        // Height should be read-only
        XCTAssertFalse(scope.canWrite(.height))

        XCTAssertFalse(scope.isEmpty)
    }

    func testActivityScope() {
        let scope = HealthAuthorizationScope.activity

        // Should request read permissions for activity metrics
        XCTAssertTrue(scope.canRead(.stepCount))
        XCTAssertTrue(scope.canRead(.distanceWalkingRunning))
        XCTAssertTrue(scope.canRead(.flightsClimbed))
        XCTAssertTrue(scope.canRead(.exerciseTime))
        XCTAssertTrue(scope.canRead(.standTime))
        XCTAssertTrue(scope.canRead(.activeEnergyBurned))

        // Should NOT request write permissions
        XCTAssertEqual(scope.writeTypes.count, 0)

        XCTAssertFalse(scope.isEmpty)
    }

    func testSleepScope() {
        let scope = HealthAuthorizationScope.sleep

        // Should request read permission for sleep
        XCTAssertTrue(scope.canRead(.sleepAnalysis))

        // Should NOT request write permissions
        XCTAssertFalse(scope.canWrite(.sleepAnalysis))
        XCTAssertEqual(scope.writeTypes.count, 0)

        XCTAssertFalse(scope.isEmpty)
    }

    // MARK: - Combining Scopes Tests

    func testMergedWith() {
        let scope1 = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        let scope2 = HealthAuthorizationScope(
            read: [.heartRate, .sleepAnalysis],  // heartRate in both
            write: [.workout(.running)]
        )

        let merged = scope1.merged(with: scope2)

        // Should contain all unique read types
        XCTAssertTrue(merged.canRead(.stepCount))
        XCTAssertTrue(merged.canRead(.heartRate))
        XCTAssertTrue(merged.canRead(.sleepAnalysis))

        // Should contain all unique write types
        XCTAssertTrue(merged.canWrite(.bodyMass))
        XCTAssertTrue(merged.canWrite(.workout(.running)))

        XCTAssertEqual(merged.readTypes.count, 3)
        XCTAssertEqual(merged.writeTypes.count, 2)
    }

    func testAddingRead() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount],
            write: [.bodyMass]
        )

        let newScope = scope.addingRead([.heartRate, .sleepAnalysis])

        // Original scope unchanged
        XCTAssertEqual(scope.readTypes.count, 1)

        // New scope has additional read types
        XCTAssertEqual(newScope.readTypes.count, 3)
        XCTAssertTrue(newScope.canRead(.stepCount))
        XCTAssertTrue(newScope.canRead(.heartRate))
        XCTAssertTrue(newScope.canRead(.sleepAnalysis))

        // Write types unchanged
        XCTAssertEqual(newScope.writeTypes.count, 1)
        XCTAssertTrue(newScope.canWrite(.bodyMass))
    }

    func testAddingWrite() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount],
            write: [.bodyMass]
        )

        let newScope = scope.addingWrite([.workout(.running), .workout(.cycling)])

        // Original scope unchanged
        XCTAssertEqual(scope.writeTypes.count, 1)

        // New scope has additional write types
        XCTAssertEqual(newScope.writeTypes.count, 3)
        XCTAssertTrue(newScope.canWrite(.bodyMass))
        XCTAssertTrue(newScope.canWrite(.workout(.running)))
        XCTAssertTrue(newScope.canWrite(.workout(.cycling)))

        // Read types unchanged
        XCTAssertEqual(newScope.readTypes.count, 1)
        XCTAssertTrue(newScope.canRead(.stepCount))
    }

    func testRemoving() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate, .bodyMass],
            write: [.bodyMass, .workout(.running)]
        )

        let newScope = scope.removing([.bodyMass, .heartRate])

        // Original scope unchanged
        XCTAssertEqual(scope.readTypes.count, 3)
        XCTAssertEqual(scope.writeTypes.count, 2)

        // New scope has types removed from both read and write
        XCTAssertTrue(newScope.canRead(.stepCount))
        XCTAssertFalse(newScope.canRead(.heartRate))  // Removed
        XCTAssertFalse(newScope.canRead(.bodyMass))  // Removed

        XCTAssertTrue(newScope.canWrite(.workout(.running)))
        XCTAssertFalse(newScope.canWrite(.bodyMass))  // Removed

        XCTAssertEqual(newScope.readTypes.count, 1)
        XCTAssertEqual(newScope.writeTypes.count, 1)
    }

    // MARK: - Equality Tests

    func testEquality() {
        let scope1 = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        let scope2 = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        let scope3 = HealthAuthorizationScope(
            read: [.stepCount],
            write: [.bodyMass]
        )

        XCTAssertEqual(scope1, scope2)
        XCTAssertNotEqual(scope1, scope3)
    }

    func testHashable() {
        let scope1 = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        let scope2 = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        var scopeSet: Set<HealthAuthorizationScope> = []
        scopeSet.insert(scope1)
        scopeSet.insert(scope2)  // Should not add duplicate

        XCTAssertEqual(scopeSet.count, 1)
        XCTAssertTrue(scopeSet.contains(scope1))
        XCTAssertTrue(scopeSet.contains(scope2))
    }

    // MARK: - Description Tests

    func testDescription() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate, .bodyMass],
            write: [.bodyMass, .workout(.running)]
        )

        let description = scope.description

        XCTAssertTrue(description.contains("HealthAuthorizationScope"))
        XCTAssertTrue(description.contains("read: 3 types"))
        XCTAssertTrue(description.contains("write: 2 types"))
    }

    func testDebugDescription() {
        let scope = HealthAuthorizationScope(
            read: [.stepCount, .heartRate],
            write: [.bodyMass]
        )

        let debugDescription = scope.debugDescription

        XCTAssertTrue(debugDescription.contains("HealthAuthorizationScope:"))
        XCTAssertTrue(debugDescription.contains("Read (2):"))
        XCTAssertTrue(debugDescription.contains("Write (1):"))
        XCTAssertTrue(
            debugDescription.contains("Step Count") || debugDescription.contains("Heart Rate"))
        XCTAssertTrue(debugDescription.contains("Body Mass"))
    }

    func testDebugDescriptionEmpty() {
        let scope = HealthAuthorizationScope(read: [], write: [])

        let debugDescription = scope.debugDescription

        XCTAssertTrue(debugDescription.contains("HealthAuthorizationScope:"))
        XCTAssertTrue(debugDescription.contains("(empty)"))
    }

    // MARK: - Sendable Tests

    func testScopeIsSendable() {
        // This test verifies that HealthAuthorizationScope conforms to Sendable
        // by using it in an async context
        Task {
            let scope = HealthAuthorizationScope.fitness
            XCTAssertFalse(scope.isEmpty)
        }
    }

    // MARK: - Real-World Scenario Tests

    func testFitIQTypicalScope() {
        // FitIQ would typically merge fitness + body measurements
        let scope = HealthAuthorizationScope.fitness
            .merged(with: .bodyMeasurements)

        XCTAssertTrue(scope.canRead(.stepCount))
        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertTrue(scope.canRead(.bodyMass))
        XCTAssertTrue(scope.canWrite(.bodyMass))
        XCTAssertTrue(scope.canWrite(.workout(.running)))
    }

    func testLumeTypicalScope() {
        // Lume would typically use mindfulness + basic health
        let scope = HealthAuthorizationScope.mindfulness
            .merged(with: .basicHealth)

        XCTAssertTrue(scope.canRead(.mindfulSession))
        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertTrue(scope.canRead(.heartRateVariability))
        XCTAssertTrue(scope.canWrite(.mindfulSession))
        XCTAssertTrue(scope.canWrite(.workout(.meditation)))

        // Should not have fitness-specific permissions
        XCTAssertFalse(scope.canRead(.stepCount))
        XCTAssertFalse(scope.canWrite(.workout(.running)))
    }

    func testGradualPermissionExpansion() {
        // Start with basic permissions
        var scope = HealthAuthorizationScope.basicHealth

        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertFalse(scope.canRead(.stepCount))

        // Add activity tracking
        scope = scope.addingRead([.stepCount, .distanceWalkingRunning])

        XCTAssertTrue(scope.canRead(.heartRate))
        XCTAssertTrue(scope.canRead(.stepCount))
        XCTAssertTrue(scope.canRead(.distanceWalkingRunning))

        // Add workout writing
        scope = scope.addingWrite([.workout(.running)])

        XCTAssertTrue(scope.canWrite(.workout(.running)))
    }
}
