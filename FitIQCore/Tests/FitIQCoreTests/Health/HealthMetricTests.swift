//
//  HealthMetricTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import XCTest

@testable import FitIQCore

final class HealthMetricTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_WithAllParameters_CreatesMetric() {
        // Arrange
        let id = UUID()
        let type = HealthDataType.heartRate
        let value = 72.0
        let unit = "bpm"
        let date = Date()
        let startDate = Date().addingTimeInterval(-3600)
        let endDate = Date()
        let source = "Apple Watch"
        let device = "Apple Watch Series 8"
        let metadata = ["workoutType": "running"]

        // Act
        let metric = HealthMetric(
            id: id,
            type: type,
            value: value,
            unit: unit,
            date: date,
            startDate: startDate,
            endDate: endDate,
            source: source,
            device: device,
            metadata: metadata
        )

        // Assert
        XCTAssertEqual(metric.id, id)
        XCTAssertEqual(metric.type, type)
        XCTAssertEqual(metric.value, value)
        XCTAssertEqual(metric.unit, unit)
        XCTAssertEqual(metric.date, date)
        XCTAssertEqual(metric.startDate, startDate)
        XCTAssertEqual(metric.endDate, endDate)
        XCTAssertEqual(metric.source, source)
        XCTAssertEqual(metric.device, device)
        XCTAssertEqual(metric.metadata, metadata)
    }

    func testInit_WithMinimalParameters_CreatesMetric() {
        // Arrange
        let type = HealthDataType.stepCount
        let value = 10000.0
        let unit = "steps"
        let date = Date()

        // Act
        let metric = HealthMetric(
            type: type,
            value: value,
            unit: unit,
            date: date
        )

        // Assert
        XCTAssertEqual(metric.type, type)
        XCTAssertEqual(metric.value, value)
        XCTAssertEqual(metric.unit, unit)
        XCTAssertEqual(metric.date, date)
        XCTAssertNil(metric.startDate)
        XCTAssertNil(metric.endDate)
        XCTAssertNil(metric.source)
        XCTAssertNil(metric.device)
        XCTAssertTrue(metric.metadata.isEmpty)
    }

    func testInit_GeneratesUniqueIDs() {
        // Arrange & Act
        let metric1 = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )
        let metric2 = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )

        // Assert
        XCTAssertNotEqual(metric1.id, metric2.id)
    }

    // MARK: - Computed Properties Tests

    func testDuration_WithStartAndEndDates_ReturnsTimeInterval() {
        // Arrange
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)  // 1 hour later
        let metric = HealthMetric(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            date: endDate,
            startDate: startDate,
            endDate: endDate
        )

        // Act
        let duration = metric.duration

        // Assert
        XCTAssertNotNil(duration)
        XCTAssertEqual(duration!, 3600, accuracy: 1.0)
    }

    func testDuration_WithoutStartDate_ReturnsNil() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date(),
            endDate: Date()
        )

        // Act
        let duration = metric.duration

        // Assert
        XCTAssertNil(duration)
    }

    func testDuration_WithoutEndDate_ReturnsNil() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date(),
            startDate: Date()
        )

        // Act
        let duration = metric.duration

        // Assert
        XCTAssertNil(duration)
    }

    func testFormattedDuration_ForOneHour_ReturnsCorrectFormat() {
        // Arrange
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)
        let metric = HealthMetric(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            date: endDate,
            startDate: startDate,
            endDate: endDate
        )

        // Act
        let formatted = metric.formattedDuration

        // Assert
        XCTAssertEqual(formatted, "1h")
    }

    func testFormattedDuration_ForOneHourThirtyMinutes_ReturnsCorrectFormat() {
        // Arrange
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(5400)  // 1.5 hours
        let metric = HealthMetric(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            date: endDate,
            startDate: startDate,
            endDate: endDate
        )

        // Act
        let formatted = metric.formattedDuration

        // Assert
        XCTAssertEqual(formatted, "1h 30m")
    }

    func testFormattedDuration_ForFortyFiveMinutes_ReturnsCorrectFormat() {
        // Arrange
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(2700)  // 45 minutes
        let metric = HealthMetric(
            type: .workout(.yoga),
            value: 200.0,
            unit: "kcal",
            date: endDate,
            startDate: startDate,
            endDate: endDate
        )

        // Act
        let formatted = metric.formattedDuration

        // Assert
        XCTAssertEqual(formatted, "45 min")
    }

    func testFormattedDuration_WithoutDuration_ReturnsNil() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )

        // Act
        let formatted = metric.formattedDuration

        // Assert
        XCTAssertNil(formatted)
    }

    func testFormattedValue_ForQuantityType_IncludesOneDecimal() {
        // Arrange
        let metric = HealthMetric(
            type: .bodyMass,
            value: 75.5,
            unit: "kg",
            date: Date()
        )

        // Act
        let formatted = metric.formattedValue

        // Assert
        XCTAssertTrue(formatted.contains("75.5"))
        XCTAssertTrue(formatted.contains("kg"))
    }

    func testFormattedValue_ForStepCount_NoDecimal() {
        // Arrange
        let metric = HealthMetric(
            type: .stepCount,
            value: 10000.0,
            unit: "steps",
            date: Date()
        )

        // Act
        let formatted = metric.formattedValue

        // Assert
        XCTAssertTrue(formatted.contains("10,000") || formatted.contains("10000"))
        XCTAssertTrue(formatted.contains("steps"))
    }

    func testIsDurationBased_WithStartAndEndDates_ReturnsTrue() {
        // Arrange
        let metric = HealthMetric(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            date: Date(),
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date()
        )

        // Act & Assert
        XCTAssertTrue(metric.isDurationBased)
    }

    func testIsDurationBased_WithoutDates_ReturnsFalse() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )

        // Act & Assert
        XCTAssertFalse(metric.isDurationBased)
    }

    func testIsToday_ForTodaysDate_ReturnsTrue() {
        // Arrange
        let metric = HealthMetric(
            type: .stepCount,
            value: 10000.0,
            unit: "steps",
            date: Date()
        )

        // Act & Assert
        XCTAssertTrue(metric.isToday)
    }

    func testIsToday_ForYesterdaysDate_ReturnsFalse() {
        // Arrange
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let metric = HealthMetric(
            type: .stepCount,
            value: 10000.0,
            unit: "steps",
            date: yesterday
        )

        // Act & Assert
        XCTAssertFalse(metric.isToday)
    }

    // MARK: - Validation Tests

    func testValidate_WithValidData_ReturnsNoErrors() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_WithNaNValue_ReturnsInvalidValueError() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: Double.nan,
            unit: "bpm",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.invalidValue))
    }

    func testValidate_WithInfiniteValue_ReturnsInvalidValueError() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: Double.infinity,
            unit: "bpm",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.invalidValue))
    }

    func testValidate_WithNegativeValue_ReturnsNegativeValueError() {
        // Arrange
        let metric = HealthMetric(
            type: .stepCount,
            value: -100.0,
            unit: "steps",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.negativeValue))
    }

    func testValidate_WithFutureDate_ReturnsFutureDateError() {
        // Arrange
        let futureDate = Date().addingTimeInterval(86400)  // Tomorrow
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: futureDate
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.futureDate))
    }

    func testValidate_WithEndBeforeStart_ReturnsEndBeforeStartError() {
        // Arrange
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(3600)  // Start after end
        let metric = HealthMetric(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            date: endDate,
            startDate: startDate,
            endDate: endDate
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.endBeforeStart))
    }

    func testValidate_WithDurationTooLong_ReturnsDurationTooLongError() {
        // Arrange
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(86400 * 8)  // 8 days
        let metric = HealthMetric(
            type: .workout(.running),
            value: 5000.0,
            unit: "kcal",
            date: endDate,
            startDate: startDate,
            endDate: endDate
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.durationTooLong))
    }

    func testValidate_WorkoutWithoutDuration_ReturnsMissingDurationError() {
        // Arrange
        let metric = HealthMetric(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.missingDuration))
    }

    func testValidate_SleepAnalysisWithoutDuration_ReturnsMissingDurationError() {
        // Arrange
        let metric = HealthMetric(
            type: .sleepAnalysis,
            value: 8.0,
            unit: "hours",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.missingDuration))
    }

    func testValidate_MindfulSessionWithoutDuration_ReturnsMissingDurationError() {
        // Arrange
        let metric = HealthMetric(
            type: .mindfulSession,
            value: 10.0,
            unit: "minutes",
            date: Date()
        )

        // Act
        let errors = metric.validate()

        // Assert
        XCTAssertTrue(errors.contains(.missingDuration))
    }

    // MARK: - Codable Tests

    func testCodable_EncodesAndDecodes() throws {
        // Arrange
        let original = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date(),
            source: "Apple Watch",
            metadata: ["session": "workout"]
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthMetric.self, from: data)

        // Assert
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.unit, original.unit)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.metadata, original.metadata)
    }

    // MARK: - Comparable Tests

    func testComparable_OrdersByDate() {
        // Arrange
        let earlier = HealthMetric(
            type: .heartRate,
            value: 70.0,
            unit: "bpm",
            date: Date().addingTimeInterval(-3600)
        )
        let later = HealthMetric(
            type: .heartRate,
            value: 75.0,
            unit: "bpm",
            date: Date()
        )

        // Act & Assert
        XCTAssertLessThan(earlier, later)
        XCTAssertGreaterThan(later, earlier)
    }

    // MARK: - Factory Methods Tests

    func testQuantityFactory_CreatesSimpleMetric() {
        // Arrange & Act
        let metric = HealthMetric.quantity(
            type: .stepCount,
            value: 10000.0,
            unit: "steps"
        )

        // Assert
        XCTAssertEqual(metric.type, .stepCount)
        XCTAssertEqual(metric.value, 10000.0)
        XCTAssertEqual(metric.unit, "steps")
        XCTAssertNil(metric.startDate)
        XCTAssertNil(metric.endDate)
    }

    func testDurationFactory_CreatesDurationBasedMetric() {
        // Arrange
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)

        // Act
        let metric = HealthMetric.duration(
            type: .workout(.running),
            value: 500.0,
            unit: "kcal",
            startDate: startDate,
            endDate: endDate,
            metadata: ["intensity": "high"]
        )

        // Assert
        XCTAssertEqual(metric.type, .workout(.running))
        XCTAssertEqual(metric.value, 500.0)
        XCTAssertEqual(metric.unit, "kcal")
        XCTAssertEqual(metric.startDate, startDate)
        XCTAssertEqual(metric.endDate, endDate)
        XCTAssertEqual(metric.date, endDate)  // Uses end date as primary date
        XCTAssertEqual(metric.metadata["intensity"], "high")
    }

    // MARK: - Collection Extensions Tests

    func testInDateRange_FiltersCorrectly() {
        // Arrange
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let tomorrow = now.addingTimeInterval(86400)

        let metrics = [
            HealthMetric(type: .stepCount, value: 5000, unit: "steps", date: yesterday),
            HealthMetric(type: .stepCount, value: 10000, unit: "steps", date: now),
            HealthMetric(type: .stepCount, value: 8000, unit: "steps", date: tomorrow),
        ]

        // Act
        let filtered = metrics.inDateRange(from: yesterday, to: now)

        // Assert
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.value == 5000 })
        XCTAssertTrue(filtered.contains { $0.value == 10000 })
    }

    func testOfType_FiltersCorrectly() {
        // Arrange
        let metrics = [
            HealthMetric(type: .stepCount, value: 10000, unit: "steps", date: Date()),
            HealthMetric(type: .heartRate, value: 72, unit: "bpm", date: Date()),
            HealthMetric(type: .stepCount, value: 5000, unit: "steps", date: Date()),
        ]

        // Act
        let steps = metrics.ofType(.stepCount)

        // Assert
        XCTAssertEqual(steps.count, 2)
        XCTAssertTrue(steps.allSatisfy { $0.type == .stepCount })
    }

    func testSortedByDateDescending_SortsCorrectly() {
        // Arrange
        let metrics = [
            HealthMetric(
                type: .stepCount, value: 5000, unit: "steps", date: Date().addingTimeInterval(-7200)
            ),
            HealthMetric(type: .stepCount, value: 10000, unit: "steps", date: Date()),
            HealthMetric(
                type: .stepCount, value: 8000, unit: "steps", date: Date().addingTimeInterval(-3600)
            ),
        ]

        // Act
        let sorted = metrics.sortedByDateDescending

        // Assert
        XCTAssertEqual(sorted[0].value, 10000)  // Most recent
        XCTAssertEqual(sorted[1].value, 8000)
        XCTAssertEqual(sorted[2].value, 5000)  // Oldest
    }

    func testSortedByDateAscending_SortsCorrectly() {
        // Arrange
        let metrics = [
            HealthMetric(
                type: .stepCount, value: 5000, unit: "steps", date: Date().addingTimeInterval(-7200)
            ),
            HealthMetric(type: .stepCount, value: 10000, unit: "steps", date: Date()),
            HealthMetric(
                type: .stepCount, value: 8000, unit: "steps", date: Date().addingTimeInterval(-3600)
            ),
        ]

        // Act
        let sorted = metrics.sortedByDateAscending

        // Assert
        XCTAssertEqual(sorted[0].value, 5000)  // Oldest
        XCTAssertEqual(sorted[1].value, 8000)
        XCTAssertEqual(sorted[2].value, 10000)  // Most recent
    }

    func testTotal_CalculatesSum() {
        // Arrange
        let metrics = [
            HealthMetric(type: .stepCount, value: 5000, unit: "steps", date: Date()),
            HealthMetric(type: .stepCount, value: 3000, unit: "steps", date: Date()),
            HealthMetric(type: .stepCount, value: 2000, unit: "steps", date: Date()),
        ]

        // Act
        let total = metrics.total

        // Assert
        XCTAssertEqual(total, 10000.0)
    }

    func testAverage_CalculatesCorrectly() {
        // Arrange
        let metrics = [
            HealthMetric(type: .heartRate, value: 70, unit: "bpm", date: Date()),
            HealthMetric(type: .heartRate, value: 75, unit: "bpm", date: Date()),
            HealthMetric(type: .heartRate, value: 80, unit: "bpm", date: Date()),
        ]

        // Act
        let average = metrics.average

        // Assert
        XCTAssertEqual(average, 75.0)
    }

    func testAverage_EmptyCollection_ReturnsNil() {
        // Arrange
        let metrics: [HealthMetric] = []

        // Act
        let average = metrics.average

        // Assert
        XCTAssertNil(average)
    }

    func testMinimum_ReturnsLowestValue() {
        // Arrange
        let metrics = [
            HealthMetric(type: .heartRate, value: 70, unit: "bpm", date: Date()),
            HealthMetric(type: .heartRate, value: 60, unit: "bpm", date: Date()),
            HealthMetric(type: .heartRate, value: 80, unit: "bpm", date: Date()),
        ]

        // Act
        let min = metrics.minimum

        // Assert
        XCTAssertEqual(min, 60.0)
    }

    func testMaximum_ReturnsHighestValue() {
        // Arrange
        let metrics = [
            HealthMetric(type: .heartRate, value: 70, unit: "bpm", date: Date()),
            HealthMetric(type: .heartRate, value: 60, unit: "bpm", date: Date()),
            HealthMetric(type: .heartRate, value: 80, unit: "bpm", date: Date()),
        ]

        // Act
        let max = metrics.maximum

        // Assert
        XCTAssertEqual(max, 80.0)
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription_IncludesKeyInformation() {
        // Arrange
        let metric = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date(),
            source: "Apple Watch"
        )

        // Act
        let description = metric.description

        // Assert
        XCTAssertTrue(description.contains("Heart Rate"))
        XCTAssertTrue(description.contains("72"))
        XCTAssertTrue(description.contains("bpm"))
        XCTAssertTrue(description.contains("Apple Watch"))
    }

    // MARK: - Hashable Tests

    func testHashable_SameIDsAreEqual() {
        // Arrange
        let id = UUID()
        let metric1 = HealthMetric(
            id: id,
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )
        let metric2 = HealthMetric(
            id: id,
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )

        // Act & Assert
        XCTAssertEqual(metric1, metric2)
        XCTAssertEqual(metric1.hashValue, metric2.hashValue)
    }

    func testHashable_DifferentIDsAreNotEqual() {
        // Arrange
        let metric1 = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )
        let metric2 = HealthMetric(
            type: .heartRate,
            value: 72.0,
            unit: "bpm",
            date: Date()
        )

        // Act & Assert
        XCTAssertNotEqual(metric1, metric2)
    }
}
