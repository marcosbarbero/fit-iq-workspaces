//
//  HealthQueryOptionsTests.swift
//  FitIQCoreTests
//
//  Created by FitIQ Team on 27/01/2025.
//  Part of Phase 2.2: HealthKit Extraction
//

import XCTest

@testable import FitIQCore

final class HealthQueryOptionsTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_WithAllParameters_CreatesOptions() {
        // Arrange
        let limit = 100
        let sortOrder = HealthQueryOptions.SortOrder.reverseChronological
        let aggregation = HealthQueryOptions.AggregationMethod.sum(.daily)
        let includeSource = true
        let includeDevice = true
        let includeMetadata = true
        let minimumValue = 50.0
        let maximumValue = 200.0
        let sourcesFilter: Set<String> = ["Apple Watch", "iPhone"]

        // Act
        let options = HealthQueryOptions(
            limit: limit,
            sortOrder: sortOrder,
            aggregation: aggregation,
            includeSource: includeSource,
            includeDevice: includeDevice,
            includeMetadata: includeMetadata,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            sourcesFilter: sourcesFilter
        )

        // Assert
        XCTAssertEqual(options.limit, limit)
        XCTAssertEqual(options.sortOrder, sortOrder)
        XCTAssertEqual(options.aggregation, aggregation)
        XCTAssertTrue(options.includeSource)
        XCTAssertTrue(options.includeDevice)
        XCTAssertTrue(options.includeMetadata)
        XCTAssertEqual(options.minimumValue, minimumValue)
        XCTAssertEqual(options.maximumValue, maximumValue)
        XCTAssertEqual(options.sourcesFilter, sourcesFilter)
    }

    func testInit_WithDefaults_CreatesDefaultOptions() {
        // Act
        let options = HealthQueryOptions()

        // Assert
        XCTAssertNil(options.limit)
        XCTAssertEqual(options.sortOrder, .chronological)
        XCTAssertNil(options.aggregation)
        XCTAssertFalse(options.includeSource)
        XCTAssertFalse(options.includeDevice)
        XCTAssertFalse(options.includeMetadata)
        XCTAssertNil(options.minimumValue)
        XCTAssertNil(options.maximumValue)
        XCTAssertNil(options.sourcesFilter)
    }

    // MARK: - Sort Order Tests

    func testSortOrder_AllCases_HaveDescriptions() {
        // Arrange & Act & Assert
        for sortOrder in HealthQueryOptions.SortOrder.allCases {
            XCTAssertFalse(sortOrder.description.isEmpty)
        }
    }

    func testSortOrder_Chronological_HasCorrectDescription() {
        // Arrange
        let sortOrder = HealthQueryOptions.SortOrder.chronological

        // Act
        let description = sortOrder.description

        // Assert
        XCTAssertEqual(description, "Oldest First")
    }

    func testSortOrder_ReverseChronological_HasCorrectDescription() {
        // Arrange
        let sortOrder = HealthQueryOptions.SortOrder.reverseChronological

        // Act
        let description = sortOrder.description

        // Assert
        XCTAssertEqual(description, "Newest First")
    }

    func testSortOrder_Ascending_HasCorrectDescription() {
        // Arrange
        let sortOrder = HealthQueryOptions.SortOrder.ascending

        // Act
        let description = sortOrder.description

        // Assert
        XCTAssertEqual(description, "Lowest First")
    }

    func testSortOrder_Descending_HasCorrectDescription() {
        // Arrange
        let sortOrder = HealthQueryOptions.SortOrder.descending

        // Act
        let description = sortOrder.description

        // Assert
        XCTAssertEqual(description, "Highest First")
    }

    // MARK: - Time Bucket Tests

    func testTimeBucket_AllCases_HaveDescriptions() {
        // Arrange & Act & Assert
        for bucket in HealthQueryOptions.AggregationMethod.TimeBucket.allCases {
            XCTAssertFalse(bucket.description.isEmpty)
        }
    }

    func testTimeBucket_Hourly_HasCorrectDuration() {
        // Arrange
        let bucket = HealthQueryOptions.AggregationMethod.TimeBucket.hourly

        // Act
        let duration = bucket.duration

        // Assert
        XCTAssertEqual(duration, 3600)
    }

    func testTimeBucket_Daily_HasCorrectDuration() {
        // Arrange
        let bucket = HealthQueryOptions.AggregationMethod.TimeBucket.daily

        // Act
        let duration = bucket.duration

        // Assert
        XCTAssertEqual(duration, 86400)
    }

    func testTimeBucket_Weekly_HasCorrectDuration() {
        // Arrange
        let bucket = HealthQueryOptions.AggregationMethod.TimeBucket.weekly

        // Act
        let duration = bucket.duration

        // Assert
        XCTAssertEqual(duration, 604800)
    }

    func testTimeBucket_Monthly_HasCorrectDuration() {
        // Arrange
        let bucket = HealthQueryOptions.AggregationMethod.TimeBucket.monthly

        // Act
        let duration = bucket.duration

        // Assert
        XCTAssertEqual(duration, 2_592_000)
    }

    // MARK: - Aggregation Method Tests

    func testAggregationMethod_Sum_HasCorrectTimeBucket() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.sum(.daily)

        // Act
        let bucket = aggregation.timeBucket

        // Assert
        XCTAssertEqual(bucket, .daily)
    }

    func testAggregationMethod_Average_HasCorrectTimeBucket() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.average(.hourly)

        // Act
        let bucket = aggregation.timeBucket

        // Assert
        XCTAssertEqual(bucket, .hourly)
    }

    func testAggregationMethod_Minimum_HasCorrectTimeBucket() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.minimum(.weekly)

        // Act
        let bucket = aggregation.timeBucket

        // Assert
        XCTAssertEqual(bucket, .weekly)
    }

    func testAggregationMethod_Maximum_HasCorrectTimeBucket() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.maximum(.monthly)

        // Act
        let bucket = aggregation.timeBucket

        // Assert
        XCTAssertEqual(bucket, .monthly)
    }

    func testAggregationMethod_Count_HasCorrectTimeBucket() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.count(.daily)

        // Act
        let bucket = aggregation.timeBucket

        // Assert
        XCTAssertEqual(bucket, .daily)
    }

    func testAggregationMethod_Sum_HasCorrectDescription() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.sum(.daily)

        // Act
        let description = aggregation.description

        // Assert
        XCTAssertEqual(description, "Sum (Daily)")
    }

    func testAggregationMethod_Average_HasCorrectDescription() {
        // Arrange
        let aggregation = HealthQueryOptions.AggregationMethod.average(.hourly)

        // Act
        let description = aggregation.description

        // Assert
        XCTAssertEqual(description, "Average (Hourly)")
    }

    // MARK: - Preset Configurations Tests

    func testDefault_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.default

        // Assert
        XCTAssertNil(options.limit)
        XCTAssertEqual(options.sortOrder, .chronological)
        XCTAssertNil(options.aggregation)
        XCTAssertFalse(options.includeSource)
        XCTAssertFalse(options.includeDevice)
        XCTAssertFalse(options.includeMetadata)
    }

    func testLatest_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.latest

        // Assert
        XCTAssertEqual(options.limit, 1)
        XCTAssertEqual(options.sortOrder, .reverseChronological)
    }

    func testHourly_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.hourly

        // Assert
        XCTAssertEqual(options.sortOrder, .chronological)
        XCTAssertEqual(options.aggregation, .sum(.hourly))
    }

    func testDaily_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.daily

        // Assert
        XCTAssertEqual(options.sortOrder, .chronological)
        XCTAssertEqual(options.aggregation, .sum(.daily))
    }

    func testWeekly_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.weekly

        // Assert
        XCTAssertEqual(options.sortOrder, .chronological)
        XCTAssertEqual(options.aggregation, .sum(.weekly))
    }

    func testDailyAverage_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.dailyAverage

        // Assert
        XCTAssertEqual(options.sortOrder, .chronological)
        XCTAssertEqual(options.aggregation, .average(.daily))
    }

    func testDetailed_HasCorrectConfiguration() {
        // Arrange & Act
        let options = HealthQueryOptions.detailed

        // Assert
        XCTAssertTrue(options.includeSource)
        XCTAssertTrue(options.includeDevice)
        XCTAssertTrue(options.includeMetadata)
    }

    func testTop_HasCorrectConfiguration() {
        // Arrange
        let count = 10

        // Act
        let options = HealthQueryOptions.top(count)

        // Assert
        XCTAssertEqual(options.limit, count)
        XCTAssertEqual(options.sortOrder, .descending)
    }

    func testRecent_HasCorrectConfiguration() {
        // Arrange
        let count = 5

        // Act
        let options = HealthQueryOptions.recent(count)

        // Assert
        XCTAssertEqual(options.limit, count)
        XCTAssertEqual(options.sortOrder, .reverseChronological)
    }

    // MARK: - Validation Tests

    func testValidate_WithValidOptions_ReturnsNoErrors() {
        // Arrange
        let options = HealthQueryOptions(
            limit: 100,
            sortOrder: .chronological,
            minimumValue: 50.0,
            maximumValue: 200.0,
            sourcesFilter: ["Apple Watch"]
        )

        // Act
        let errors = options.validate()

        // Assert
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_WithZeroLimit_ReturnsInvalidLimitError() {
        // Arrange
        let options = HealthQueryOptions(limit: 0)

        // Act
        let errors = options.validate()

        // Assert
        XCTAssertTrue(errors.contains(.invalidLimit))
    }

    func testValidate_WithNegativeLimit_ReturnsInvalidLimitError() {
        // Arrange
        let options = HealthQueryOptions(limit: -10)

        // Act
        let errors = options.validate()

        // Assert
        XCTAssertTrue(errors.contains(.invalidLimit))
    }

    func testValidate_WithMinGreaterThanMax_ReturnsInvalidValueRangeError() {
        // Arrange
        let options = HealthQueryOptions(
            minimumValue: 200.0,
            maximumValue: 100.0
        )

        // Act
        let errors = options.validate()

        // Assert
        XCTAssertTrue(errors.contains(.invalidValueRange))
    }

    func testValidate_WithEmptySourcesFilter_ReturnsEmptySourcesFilterError() {
        // Arrange
        let options = HealthQueryOptions(sourcesFilter: [])

        // Act
        let errors = options.validate()

        // Assert
        XCTAssertTrue(errors.contains(.emptySourcesFilter))
    }

    func testValidate_WithMultipleErrors_ReturnsAllErrors() {
        // Arrange
        let options = HealthQueryOptions(
            limit: -5,
            minimumValue: 200.0,
            maximumValue: 100.0,
            sourcesFilter: []
        )

        // Act
        let errors = options.validate()

        // Assert
        XCTAssertEqual(errors.count, 3)
        XCTAssertTrue(errors.contains(.invalidLimit))
        XCTAssertTrue(errors.contains(.invalidValueRange))
        XCTAssertTrue(errors.contains(.emptySourcesFilter))
    }

    // MARK: - CustomStringConvertible Tests

    func testDescription_WithAllOptions_IncludesAllInformation() {
        // Arrange
        let options = HealthQueryOptions(
            limit: 100,
            sortOrder: .reverseChronological,
            aggregation: .sum(.daily),
            includeSource: true,
            includeDevice: true,
            includeMetadata: true,
            minimumValue: 50.0,
            maximumValue: 200.0,
            sourcesFilter: ["Apple Watch", "iPhone"]
        )

        // Act
        let description = options.description

        // Assert
        XCTAssertTrue(description.contains("limit: 100"))
        XCTAssertTrue(description.contains("sort: Newest First"))
        XCTAssertTrue(description.contains("aggregation: Sum (Daily)"))
        XCTAssertTrue(description.contains("with source"))
        XCTAssertTrue(description.contains("with device"))
        XCTAssertTrue(description.contains("with metadata"))
        XCTAssertTrue(description.contains("min: 50"))
        XCTAssertTrue(description.contains("max: 200"))
        XCTAssertTrue(description.contains("sources:"))
    }

    func testDescription_WithMinimalOptions_IsSimple() {
        // Arrange
        let options = HealthQueryOptions()

        // Act
        let description = options.description

        // Assert
        XCTAssertTrue(description.contains("HealthQueryOptions"))
        XCTAssertTrue(description.contains("sort:"))
    }

    // MARK: - Builder Pattern Tests

    func testWithLimit_CreatesNewOptionsWithUpdatedLimit() {
        // Arrange
        let original = HealthQueryOptions(limit: 10)

        // Act
        let updated = original.withLimit(20)

        // Assert
        XCTAssertEqual(original.limit, 10)
        XCTAssertEqual(updated.limit, 20)
    }

    func testWithSortOrder_CreatesNewOptionsWithUpdatedSortOrder() {
        // Arrange
        let original = HealthQueryOptions(sortOrder: .chronological)

        // Act
        let updated = original.withSortOrder(.descending)

        // Assert
        XCTAssertEqual(original.sortOrder, .chronological)
        XCTAssertEqual(updated.sortOrder, .descending)
    }

    func testWithAggregation_CreatesNewOptionsWithUpdatedAggregation() {
        // Arrange
        let original = HealthQueryOptions(aggregation: .sum(.daily))

        // Act
        let updated = original.withAggregation(.average(.hourly))

        // Assert
        XCTAssertEqual(original.aggregation, .sum(.daily))
        XCTAssertEqual(updated.aggregation, .average(.hourly))
    }

    func testWithMetadata_EnablesAllMetadataFlags() {
        // Arrange
        let original = HealthQueryOptions()

        // Act
        let updated = original.withMetadata()

        // Assert
        XCTAssertFalse(original.includeSource)
        XCTAssertFalse(original.includeDevice)
        XCTAssertFalse(original.includeMetadata)
        XCTAssertTrue(updated.includeSource)
        XCTAssertTrue(updated.includeDevice)
        XCTAssertTrue(updated.includeMetadata)
    }

    func testWithValueRange_CreatesNewOptionsWithUpdatedRange() {
        // Arrange
        let original = HealthQueryOptions()

        // Act
        let updated = original.withValueRange(min: 50.0, max: 200.0)

        // Assert
        XCTAssertNil(original.minimumValue)
        XCTAssertNil(original.maximumValue)
        XCTAssertEqual(updated.minimumValue, 50.0)
        XCTAssertEqual(updated.maximumValue, 200.0)
    }

    func testWithSourcesFilter_CreatesNewOptionsWithUpdatedFilter() {
        // Arrange
        let original = HealthQueryOptions()
        let sources: Set<String> = ["Apple Watch"]

        // Act
        let updated = original.withSourcesFilter(sources)

        // Assert
        XCTAssertNil(original.sourcesFilter)
        XCTAssertEqual(updated.sourcesFilter, sources)
    }

    func testBuilderPattern_CanChainMultipleMethods() {
        // Arrange
        let original = HealthQueryOptions.default

        // Act
        let updated =
            original
            .withLimit(100)
            .withSortOrder(.descending)
            .withMetadata()
            .withValueRange(min: 50.0, max: 200.0)

        // Assert
        XCTAssertEqual(updated.limit, 100)
        XCTAssertEqual(updated.sortOrder, .descending)
        XCTAssertTrue(updated.includeSource)
        XCTAssertTrue(updated.includeDevice)
        XCTAssertTrue(updated.includeMetadata)
        XCTAssertEqual(updated.minimumValue, 50.0)
        XCTAssertEqual(updated.maximumValue, 200.0)
    }

    // MARK: - Codable Tests

    func testCodable_EncodesAndDecodesCorrectly() throws {
        // Arrange
        let original = HealthQueryOptions(
            limit: 100,
            sortOrder: .reverseChronological,
            aggregation: .sum(.daily),
            includeSource: true,
            includeDevice: true,
            includeMetadata: true,
            minimumValue: 50.0,
            maximumValue: 200.0,
            sourcesFilter: ["Apple Watch"]
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthQueryOptions.self, from: data)

        // Assert
        XCTAssertEqual(decoded.limit, original.limit)
        XCTAssertEqual(decoded.sortOrder, original.sortOrder)
        XCTAssertEqual(decoded.aggregation, original.aggregation)
        XCTAssertEqual(decoded.includeSource, original.includeSource)
        XCTAssertEqual(decoded.includeDevice, original.includeDevice)
        XCTAssertEqual(decoded.includeMetadata, original.includeMetadata)
        XCTAssertEqual(decoded.minimumValue, original.minimumValue)
        XCTAssertEqual(decoded.maximumValue, original.maximumValue)
        XCTAssertEqual(decoded.sourcesFilter, original.sourcesFilter)
    }

    func testCodable_AggregationSum_EncodesAndDecodes() throws {
        // Arrange
        let original = HealthQueryOptions(aggregation: .sum(.hourly))

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthQueryOptions.self, from: data)

        // Assert
        XCTAssertEqual(decoded.aggregation, .sum(.hourly))
    }

    func testCodable_AggregationAverage_EncodesAndDecodes() throws {
        // Arrange
        let original = HealthQueryOptions(aggregation: .average(.daily))

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthQueryOptions.self, from: data)

        // Assert
        XCTAssertEqual(decoded.aggregation, .average(.daily))
    }

    func testCodable_AggregationMinimum_EncodesAndDecodes() throws {
        // Arrange
        let original = HealthQueryOptions(aggregation: .minimum(.weekly))

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthQueryOptions.self, from: data)

        // Assert
        XCTAssertEqual(decoded.aggregation, .minimum(.weekly))
    }

    func testCodable_AggregationMaximum_EncodesAndDecodes() throws {
        // Arrange
        let original = HealthQueryOptions(aggregation: .maximum(.monthly))

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthQueryOptions.self, from: data)

        // Assert
        XCTAssertEqual(decoded.aggregation, .maximum(.monthly))
    }

    func testCodable_AggregationCount_EncodesAndDecodes() throws {
        // Arrange
        let original = HealthQueryOptions(aggregation: .count(.daily))

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HealthQueryOptions.self, from: data)

        // Assert
        XCTAssertEqual(decoded.aggregation, .count(.daily))
    }

    // MARK: - Hashable Tests

    func testHashable_SameOptionsAreEqual() {
        // Arrange
        let options1 = HealthQueryOptions(
            limit: 100,
            sortOrder: .chronological
        )
        let options2 = HealthQueryOptions(
            limit: 100,
            sortOrder: .chronological
        )

        // Act & Assert
        XCTAssertEqual(options1, options2)
        XCTAssertEqual(options1.hashValue, options2.hashValue)
    }

    func testHashable_DifferentOptionsAreNotEqual() {
        // Arrange
        let options1 = HealthQueryOptions(
            limit: 100,
            sortOrder: .chronological
        )
        let options2 = HealthQueryOptions(
            limit: 200,
            sortOrder: .chronological
        )

        // Act & Assert
        XCTAssertNotEqual(options1, options2)
    }

    // MARK: - Validation Error Description Tests

    func testValidationError_InvalidLimit_HasDescription() {
        // Arrange
        let error = HealthQueryOptions.ValidationError.invalidLimit

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
    }

    func testValidationError_InvalidValueRange_HasDescription() {
        // Arrange
        let error = HealthQueryOptions.ValidationError.invalidValueRange

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
    }

    func testValidationError_EmptySourcesFilter_HasDescription() {
        // Arrange
        let error = HealthQueryOptions.ValidationError.emptySourcesFilter

        // Act
        let description = error.errorDescription

        // Assert
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
    }
}
